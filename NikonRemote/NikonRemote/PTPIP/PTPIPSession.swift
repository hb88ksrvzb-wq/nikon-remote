import Foundation
import Darwin

/// PTP/IP 会话。管理 15740（命令/数据）与 15741（事件）两条 TCP 连接，
/// 负责握手、命令事务（含数据收发）、事件回调。
final class PTPIPSession {

    // MARK: - 常量
    static let defaultCommandPort = 15740
    static let defaultEventPort = 15741
    private static let blockSize = 65536
    private static let defaultTimeout: TimeInterval = 8

    // MARK: - 状态
    private let commandFD: Int32
    private let eventFD: Int32
    let sessionID: UInt32
    private var nextTransactionID: UInt32 = 1

    private let stateLock = NSLock()
    private var isClosed = false

    // 单飞行中命令
    private var inFlightTID: UInt32 = 0
    private var waitSemaphore: DispatchSemaphore?
    private var responseSlot: PTPIPResponse?
    private var responseError: PTPError?
    private var dataBuffer: [UInt8] = []

    private let readQueue: DispatchQueue
    private let eventQueue: DispatchQueue

    var onEvent: ((PTPEventCode, [UInt32]) -> Void)?
    var onDisconnect: (() -> Void)?

    // MARK: - 连接建立

    /// 建立 PTP/IP 连接并完成握手。
    /// - Parameters:
    ///   - host: 相机 IP
    ///   - commandPort: 命令端口
    ///   - eventPort: 事件端口
    ///   - useInitiationPacket: 是否先发送 1280 字节初始化包（默认关，兜底开关）
    ///   - deviceName: 本机名称（发送给相机的 UTF-16LE 名称）
    ///   - guid: 16 字节 GUID（持久化，方便相机识别）
    static func connect(host: String,
                        commandPort: Int = PTPIPSession.defaultCommandPort,
                        eventPort: Int = PTPIPSession.defaultEventPort,
                        useInitiationPacket: Bool = false,
                        deviceName: String,
                        guid: [UInt8]) throws -> PTPIPSession {
        guard guid.count == 16 else {
            throw PTPError.badData("GUID 必须是 16 字节")
        }

        var cmdFD: Int32 = -1
        var eventFD: Int32 = -1

        do {
            cmdFD = try POSIXSocket.openSocket()
            try POSIXSocket.connect(fd: cmdFD, host: host, port: commandPort)

            if useInitiationPacket {
                try writeInitiationPacket(fd: cmdFD)
                _ = try readInitiationPacket(fd: cmdFD)
            }

            try writeInitCommandRequest(fd: cmdFD, deviceName: deviceName, guid: guid)
            let ack = try readInitCommandAck(fd: cmdFD)
            let sessionID = ack.sessionID

            // 事件通道（相机可能未就绪，重试几次）
            var connected = false
            for attempt in 0..<5 {
                do {
                    eventFD = try POSIXSocket.openSocket()
                    try POSIXSocket.connect(fd: eventFD, host: host, port: eventPort)
                    connected = true
                    break
                } catch {
                    if eventFD >= 0 { close(eventFD); eventFD = -1 }
                    if attempt < 4 { Thread.sleep(forTimeInterval: 0.15) } else { throw error }
                }
            }
            guard connected, eventFD >= 0 else {
                throw PTPError.connectionClosed
            }

            try writeInitEventRequest(fd: eventFD, sessionID: sessionID)
            try readInitEventAck(fd: eventFD)

            return PTPIPSession(commandFD: cmdFD, eventFD: eventFD, sessionID: sessionID)
        } catch {
            if cmdFD >= 0 { close(cmdFD) }
            if eventFD >= 0 { close(eventFD) }
            throw error
        }
    }

    private init(commandFD: Int32, eventFD: Int32, sessionID: UInt32) {
        self.commandFD = commandFD
        self.eventFD = eventFD
        self.sessionID = sessionID
        let rq = DispatchQueue(label: "ptp.ip.command", qos: .userInitiated)
        let eq = DispatchQueue(label: "ptp.ip.event", qos: .userInitiated)
        self.readQueue = rq
        self.eventQueue = eq
        rq.async { [weak self] in self?.commandReadLoop() }
        eq.async { [weak self] in self?.eventReadLoop() }
    }

    deinit {
        closeSockets()
    }

    private func closeSockets() {
        stateLock.lock()
        let already = isClosed
        isClosed = true
        stateLock.unlock()
        guard !already else { return }
        close(commandFD)
        close(eventFD)
    }

    // MARK: - 命令事务

    /// 执行一个 PTP 命令事务。
    /// - Parameters:
    ///   - op: 操作码
    ///   - params: 参数
    ///   - sendData: 若有值则作为数据发送给相机。
    ///   - expectsData: 相机是否会向客户端返回数据。
    /// - Returns: 响应与返回的数据（可能为空）
    func transaction(op: PTPOperation,
                     params: [UInt32] = [],
                     sendData: [UInt8]? = nil,
                     expectsData: Bool = false,
                     timeout: TimeInterval = PTPIPSession.defaultTimeout) throws -> (response: PTPIPResponse, data: [UInt8]) {

        guard !(sendData != nil && expectsData) else {
            throw PTPError.badData("一个 PTP 事务不能同时发送和接收数据")
        }

        stateLock.lock()
        guard !isClosed else {
            stateLock.unlock()
            throw PTPError.notConnected
        }
        guard inFlightTID == 0 else {
            stateLock.unlock()
            throw PTPError.badData("已有命令在处理中")
        }
        let tid = nextTransactionID
        nextTransactionID += 1
        inFlightTID = tid
        responseSlot = nil
        responseError = nil
        dataBuffer = []
        let sem = DispatchSemaphore(value: 0)
        waitSemaphore = sem
        stateLock.unlock()

        defer {
            stateLock.lock()
            inFlightTID = 0
            waitSemaphore = nil
            stateLock.unlock()
        }

        // 注意：waitSemaphore 必须在发送命令之前设置，
        // 否则读循环可能在 waitSemaphore 就绪前就收到响应并丢弃它。
        do {
            let dataPhase = PTPIPDataPhase.forTransaction(hasOutgoingData: sendData != nil,
                                                           expectsIncomingData: expectsData)
            try writeCommandRequest(op: op, params: params, transid: tid, dataphase: dataPhase.rawValue)
            if let sendData {
                try writeStartDataPacket(transid: tid, totalSize: sendData.count)
                if sendData.isEmpty {
                    try writeDataPacket(transid: tid, data: [], isEnd: true)
                }
                var offset = 0
                while offset < sendData.count {
                    let end = min(offset + PTPIPSession.blockSize, sendData.count)
                    let chunk = Array(sendData[offset..<end])
                    let isLast = end >= sendData.count
                    try writeDataPacket(transid: tid, data: chunk, isEnd: isLast)
                    offset = end
                }
            }
        } catch {
            signalResponseError(error as? PTPError ?? .connectionClosed)
            throw error
        }

        let deadline = DispatchTime.now() + timeout
        _ = sem.wait(timeout: deadline)

        stateLock.lock()
        let resp = responseSlot
        let err = responseError
        let data = dataBuffer
        stateLock.unlock()

        if let err { throw err }
        guard let resp else { throw PTPError.timeout }
        if !resp.isOK {
            throw PTPError.camera(resp.code.name, resp.rawCode)
        }
        return (resp, data)
    }

    private func signalResponseError(_ error: PTPError) {
        stateLock.lock()
        if waitSemaphore != nil {
            responseError = error
            waitSemaphore?.signal()
        }
        stateLock.unlock()
    }

    private func signalResponse(_ resp: PTPIPResponse, data: [UInt8]) {
        stateLock.lock()
        if waitSemaphore != nil, inFlightTID == resp.transactionID {
            responseSlot = resp
            dataBuffer = data
            waitSemaphore?.signal()
        }
        stateLock.unlock()
    }

    // MARK: - 命令读取循环

    private func commandReadLoop() {
        while true {
            stateLock.lock()
            let closed = isClosed
            let inFlight = inFlightTID != 0
            stateLock.unlock()
            if closed { return }
            // 无命令在途时不阻塞读取，避免空闲超时误判断连
            if !inFlight {
                Thread.sleep(forTimeInterval: 0.05)
                continue
            }

            guard let packet = readPacket(fd: commandFD, timeout: 15) else {
                stateLock.lock()
                let alreadyClosed = isClosed
                isClosed = true
                stateLock.unlock()
                if !alreadyClosed {
                    signalResponseError(.connectionClosed)
                    DispatchQueue.main.async { [weak self] in self?.onDisconnect?() }
                }
                return
            }

            handleCommandPacket(packet)
        }
    }

    private func handleCommandPacket(_ packet: PTPIPPacket) {
        switch packet.type {
        case .commandResponse:
            guard let resp = PTPIPResponse.parse(packet.payload) else {
                signalResponseError(.badData("无法解析命令响应"))
                return
            }
            stateLock.lock()
            let data = dataBuffer
            stateLock.unlock()
            signalResponse(resp, data: data)

        case .startDataPacket:
            stateLock.lock()
            dataBuffer = []
            stateLock.unlock()

        case .dataPacket, .endDataPacket:
            guard packet.payload.count >= 4 else { break }
            let tid = UInt32(packet.payload[0])
                | (UInt32(packet.payload[1]) << 8)
                | (UInt32(packet.payload[2]) << 16)
                | (UInt32(packet.payload[3]) << 24)
            stateLock.lock()
            if tid == inFlightTID {
                dataBuffer.append(contentsOf: packet.payload.dropFirst(4))
            }
            stateLock.unlock()

        case .ping:
            _ = writePacket(type: .pong, payload: [], fd: commandFD)

        case .initFail:
            signalResponseError(.camera("相机拒绝握手", UInt16(packet.payload.first ?? 0)))

        default:
            break
        }
    }

    // MARK: - 事件读取循环

    private func eventReadLoop() {
        while true {
            stateLock.lock()
            let closed = isClosed
            stateLock.unlock()
            if closed { return }

            guard let packet = readPacket(fd: eventFD, timeout: nil) else {
                stateLock.lock()
                let alreadyClosed = isClosed
                isClosed = true
                stateLock.unlock()
                if !alreadyClosed {
                    DispatchQueue.main.async { [weak self] in self?.onDisconnect?() }
                }
                return
            }

            switch packet.type {
            case .event:
                guard let event = PTPIPEvent.parse(packet.payload) else { continue }
                DispatchQueue.main.async { [weak self] in
                    self?.onEvent?(event.code, event.params)
                }
            case .ping:
                _ = writePacket(type: .pong, payload: [], fd: eventFD)
            default:
                break
            }
        }
    }

    // MARK: - 底层读写

    private struct PTPIPPacket {
        let type: PTPIPPacketType
        let payload: [UInt8]
    }

    /// 读取一个完整 PTP/IP 包（8 字节头 + payload）。
    /// - Parameter timeout: 每次读等待上限（nil = 无限阻塞，用于事件通道）
    private func readPacket(fd: Int32, timeout: TimeInterval?) -> PTPIPPacket? {
        var header = [UInt8](repeating: 0, count: 8)
        guard readFull(fd: fd, into: &header, count: 8, timeout: timeout) else { return nil }
        let length = UInt32(header[0]) | (UInt32(header[1]) << 8) | (UInt32(header[2]) << 16) | (UInt32(header[3]) << 24)
        guard length >= 8, length <= 512 * 1024 * 1024 else { return nil }
        let typeRaw = UInt32(header[4]) | (UInt32(header[5]) << 8) | (UInt32(header[6]) << 16) | (UInt32(header[7]) << 24)
        guard let type = PTPIPPacketType(rawValue: typeRaw) else { return nil }
        let payloadCount = Int(length) - 8
        var payload = [UInt8](repeating: 0, count: payloadCount)
        guard readFull(fd: fd, into: &payload, count: payloadCount, timeout: timeout) else { return nil }
        return PTPIPPacket(type: type, payload: payload)
    }

    @discardableResult
    private func writePacket(type: PTPIPPacketType, payload: [UInt8], fd: Int32) -> Bool {
        var header = [UInt8]()
        ByteWriter.append(UInt32(8 + payload.count), to: &header)
        ByteWriter.append(type.rawValue, to: &header)
        var data = header
        data.append(contentsOf: payload)
        return writeFull(fd: fd, data: data)
    }

    private func writeCommandRequest(op: PTPOperation, params: [UInt32], transid: UInt32, dataphase: UInt32) throws {
        var payload = [UInt8]()
        ByteWriter.append(dataphase, to: &payload)
        ByteWriter.append(op.rawValue, to: &payload)
        ByteWriter.append(transid, to: &payload)
        for p in params {
            ByteWriter.append(p, to: &payload)
        }
        guard writePacket(type: .commandRequest, payload: payload, fd: commandFD) else {
            throw PTPError.connectionClosed
        }
    }

    private func writeStartDataPacket(transid: UInt32, totalSize: Int) throws {
        var payload = [UInt8]()
        ByteWriter.append(transid, to: &payload)
        ByteWriter.append(UInt64(totalSize), to: &payload)
        guard writePacket(type: .startDataPacket, payload: payload, fd: commandFD) else {
            throw PTPError.connectionClosed
        }
    }

    private func writeDataPacket(transid: UInt32, data: [UInt8], isEnd: Bool) throws {
        var payload = [UInt8]()
        ByteWriter.append(transid, to: &payload)
        payload.append(contentsOf: data)
        guard writePacket(type: isEnd ? .endDataPacket : .dataPacket, payload: payload, fd: commandFD) else {
            throw PTPError.connectionClosed
        }
    }

    // MARK: - 握手包

    private static func writeInitiationPacket(fd: Int32) throws {
        var packet = [UInt8](repeating: 0, count: 1280)
        packet[0] = 0x01
        packet[8] = 0x01
        try writeFullThrowing(fd: fd, data: packet)
    }

    private static func readInitiationPacket(fd: Int32) throws -> [UInt8] {
        var buf = [UInt8](repeating: 0, count: 1280)
        guard readFull(fd: fd, into: &buf, count: 1280, timeout: 10) else {
            throw PTPError.connectionClosed
        }
        return buf
    }

    private static func writeInitCommandRequest(fd: Int32, deviceName: String, guid: [UInt8]) throws {
        var payload = [UInt8]()
        payload.append(contentsOf: guid)
        ByteWriter.appendUTF16LE(deviceName, to: &payload)
        // 版本
        ByteWriter.append(UInt16(0x0000), to: &payload) // minor
        ByteWriter.append(UInt16(0x0001), to: &payload) // major
        try writePacketThrowing(fd: fd, type: .initCommandRequest, payload: payload)
    }

    private static func writePacketThrowing(fd: Int32, type: PTPIPPacketType, payload: [UInt8]) throws {
        var header = [UInt8]()
        ByteWriter.append(UInt32(8 + payload.count), to: &header)
        ByteWriter.append(type.rawValue, to: &header)
        var data = header
        data.append(contentsOf: payload)
        try writeFullThrowing(fd: fd, data: data)
    }

    private struct InitCommandAck {
        let sessionID: UInt32
        let cameraGUID: [UInt8]
        let cameraName: String
    }

    private static func readInitCommandAck(fd: Int32) throws -> InitCommandAck {
        var header = [UInt8](repeating: 0, count: 8)
        guard readFull(fd: fd, into: &header, count: 8, timeout: 10) else {
            throw PTPError.connectionClosed
        }
        let length = UInt32(header[0]) | (UInt32(header[1]) << 8) | (UInt32(header[2]) << 16) | (UInt32(header[3]) << 24)
        let typeRaw = UInt32(header[4]) | (UInt32(header[5]) << 8) | (UInt32(header[6]) << 16) | (UInt32(header[7]) << 24)
        guard length >= 8, length <= 65536 else { throw PTPError.badData("握手响应长度异常") }

        var payload = [UInt8](repeating: 0, count: Int(length) - 8)
        guard readFull(fd: fd, into: &payload, count: payload.count, timeout: 10) else {
            throw PTPError.connectionClosed
        }

        if typeRaw == PTPIPPacketType.initFail.rawValue {
            throw PTPError.camera("相机拒绝了连接请求(忙碌或已被占用)", 0)
        }
        guard typeRaw == PTPIPPacketType.initCommandAck.rawValue else {
            throw PTPError.badData("握手响应类型错误: \(typeRaw)")
        }
        guard payload.count >= 20 else { throw PTPError.badData("握手响应数据不足") }

        let sessionID = UInt32(payload[0]) | (UInt32(payload[1]) << 8) | (UInt32(payload[2]) << 16) | (UInt32(payload[3]) << 24)
        let cameraGUID = Array(payload[4..<20])

        // UTF-16LE 相机名
        var units: [UInt16] = []
        var i = 20
        while i + 1 < payload.count {
            let u = UInt16(payload[i]) | (UInt16(payload[i + 1]) << 8)
            if u == 0 { break }
            units.append(u)
            i += 2
        }
        let cameraName = String(utf16CodeUnits: units, count: units.count)

        return InitCommandAck(sessionID: sessionID, cameraGUID: cameraGUID, cameraName: cameraName)
    }

    private static func writeInitEventRequest(fd: Int32, sessionID: UInt32) throws {
        var payload = [UInt8]()
        ByteWriter.append(sessionID, to: &payload)
        try writePacketThrowing(fd: fd, type: .initEventRequest, payload: payload)
    }

    private static func readInitEventAck(fd: Int32) throws {
        var header = [UInt8](repeating: 0, count: 8)
        guard readFull(fd: fd, into: &header, count: 8, timeout: 10) else {
            throw PTPError.connectionClosed
        }
        let length = UInt32(header[0]) | (UInt32(header[1]) << 8) | (UInt32(header[2]) << 16) | (UInt32(header[3]) << 24)
        let typeRaw = UInt32(header[4]) | (UInt32(header[5]) << 8) | (UInt32(header[6]) << 16) | (UInt32(header[7]) << 24)
        guard length >= 8, length <= 65536 else { throw PTPError.badData("事件握手长度异常") }

        var payload = [UInt8](repeating: 0, count: Int(length) - 8)
        guard readFull(fd: fd, into: &payload, count: payload.count, timeout: 10) else {
            throw PTPError.connectionClosed
        }
        if typeRaw == PTPIPPacketType.initFail.rawValue {
            throw PTPError.camera("相机拒绝事件通道", 0)
        }
        guard typeRaw == PTPIPPacketType.initEventAck.rawValue else {
            throw PTPError.badData("事件握手响应类型错误: \(typeRaw)")
        }
    }

    // MARK: - 断开

    func close() {
        closeSockets()
    }
}

// MARK: - 响应 / 事件解析

struct PTPIPResponse {
    /// 原始响应码（可能为厂商私有码）
    let rawCode: UInt16
    let transactionID: UInt32
    let params: [UInt32]

    var code: PTPResponseCode {
        PTPResponseCode(rawValue: rawCode) ?? .generalError
    }

    var isOK: Bool { rawCode == PTPResponseCode.ok.rawValue }

    static func parse(_ payload: [UInt8]) -> PTPIPResponse? {
        guard payload.count >= 6 else { return nil }
        let codeRaw = UInt16(payload[0]) | (UInt16(payload[1]) << 8)
        let tid = UInt32(payload[2]) | (UInt32(payload[3]) << 8) | (UInt32(payload[4]) << 16) | (UInt32(payload[5]) << 24)
        var params: [UInt32] = []
        var i = 6
        while i + 4 <= payload.count {
            let p = UInt32(payload[i]) | (UInt32(payload[i + 1]) << 8) | (UInt32(payload[i + 2]) << 16) | (UInt32(payload[i + 3]) << 24)
            params.append(p)
            i += 4
        }
        return PTPIPResponse(rawCode: codeRaw, transactionID: tid, params: params)
    }
}

struct PTPIPEvent {
    let code: PTPEventCode
    let transactionID: UInt32
    let params: [UInt32]

    static func parse(_ payload: [UInt8]) -> PTPIPEvent? {
        guard payload.count >= 6 else { return nil }
        let codeRaw = UInt16(payload[0]) | (UInt16(payload[1]) << 8)
        let tid = UInt32(payload[2]) | (UInt32(payload[3]) << 8) | (UInt32(payload[4]) << 16) | (UInt32(payload[5]) << 24)
        var params: [UInt32] = []
        var i = 6
        while i + 4 <= payload.count {
            let p = UInt32(payload[i]) | (UInt32(payload[i + 1]) << 8) | (UInt32(payload[i + 2]) << 16) | (UInt32(payload[i + 3]) << 24)
            params.append(p)
            i += 4
        }
        guard let code = PTPEventCode(rawValue: codeRaw) else { return nil }
        return PTPIPEvent(code: code, transactionID: tid, params: params)
    }
}

// MARK: - POSIX socket 封装

enum POSIXSocket {
    static func openSocket() throws -> Int32 {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        if fd < 0 {
            throw PTPError.connectionClosed
        }
        // 先置为非阻塞用于 connect（connect 成功后恢复阻塞）
        _ = POSIXSocket.setBlocking(fd, blocking: false)
        return fd
    }

    static func connect(fd: Int32, host: String, port: Int) throws {
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(port).bigEndian

        let ipResult = host.withCString { cs -> Int32 in
            inet_pton(AF_INET, cs, &addr.sin_addr)
        }
        if ipResult != 1 {
            throw PTPError.badData("无效 IP 地址: \(host)")
        }

        let result = withUnsafePointer(to: &addr) { ptr -> Int32 in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { saPtr in
                connect(fd, saPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        if result < 0 {
            let err = errno
            if err == EINPROGRESS {
                // 等待可写
                var fds = fd_set()
                FD_ZERO(&fds)
                FD_SET(fd, &fds)
                var timeout = timeval(tv_sec: 5, tv_usec: 0)
                let sel = select(fd + 1, nil, &fds, nil, &timeout)
                if sel <= 0 {
                    throw PTPError.timeout
                }
                var sockErr: Int32 = 0
                var len = socklen_t(MemoryLayout<Int32>.size)
                if getsockopt(fd, SOL_SOCKET, SO_ERROR, &sockErr, &len) != 0 || sockErr != 0 {
                    throw PTPError.connectionClosed
                }
            } else {
                throw PTPError.connectionClosed
            }
        }
        // 连接成功后恢复为阻塞模式，使 SO_RCVTIMEO/SO_SNDTIMEO 生效
        _ = POSIXSocket.setBlocking(fd, blocking: true)
    }

    /// 设置/清除 O_NONBLOCK。
    static func setBlocking(_ fd: Int32, blocking: Bool) -> Bool {
        let flags = fcntl(fd, F_GETFL, 0)
        if flags < 0 { return false }
        let newFlags = blocking ? (flags & ~O_NONBLOCK) : (flags | O_NONBLOCK)
        return fcntl(fd, F_SETFL, newFlags) >= 0
    }
}

// MARK: - 读写辅助

/// 读取恰好 count 字节。timeout 非 nil 时，每次 read 前用 select 等待数据。
private func readFull(fd: Int32, into buffer: inout [UInt8], count: Int, timeout: TimeInterval?) -> Bool {
    var total = 0
    while total < count {
        if let timeout {
            var fds = fd_set()
            FD_ZERO(&fds)
            FD_SET(fd, &fds)
            var tv = timeval(tv_sec: Int(timeout), tv_usec: 0)
            let sel = select(fd + 1, &fds, nil, nil, &tv)
            if sel <= 0 { return false }
        }
        let n = buffer.withUnsafeMutableBytes { (raw: UnsafeMutableRawBufferPointer) -> Int in
            let base = raw.baseAddress!.advanced(by: total)
            return Darwin.read(fd, base, count - total)
        }
        if n < 0 {
            if errno == EINTR { continue }
            return false
        }
        if n == 0 { return false }
        total += n
    }
    return true
}

private func writeFull(fd: Int32, data: [UInt8]) -> Bool {
    var total = 0
    while total < data.count {
        let n = data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> Int in
            let base = raw.baseAddress!.advanced(by: total)
            return Darwin.write(fd, base, data.count - total)
        }
        if n < 0 {
            if errno == EINTR { continue }
            return false
        }
        if n == 0 { return false }
        total += n
    }
    return true
}

private func writeFullThrowing(fd: Int32, data: [UInt8]) throws {
    if !writeFull(fd: fd, data: data) {
        throw PTPError.connectionClosed
    }
}
