import Foundation
import UIKit

/// 参数选项
struct CameraParamOption: Identifiable, Equatable {
    let id: String
    let label: String
    let value: PTPValue
}

/// 曝光参数（带候选值列表）
struct CameraParam: Identifiable {
    let id = UUID()
    let code: UInt32
    let name: String
    let dataType: PTPDataType
    let options: [CameraParamOption]
    var selectedID: String

    func option(id: String) -> CameraParamOption? {
        options.first { $0.id == id }
    }
}

/// 传输记录
struct TransferItem: Identifiable {
    enum Kind: String {
        case photo = "照片"
        case video = "视频"
    }
    enum Status {
        case downloading
        case saved
        case failed(String)
    }

    let id = UUID()
    let handle: UInt32
    let filename: String
    let size: Int
    let kind: Kind
    var status: Status
    var progress: Double = 0
}

/// 应用中央管理器（所有 UI 状态的来源）
@MainActor
final class CameraManager: ObservableObject {

    enum ConnectionState: Equatable {
        case idle
        case connecting
        case connected
        case failed(String)
    }

    // MARK: - 发布状态
    @Published var state: ConnectionState = .idle
    @Published var cameraModel = ""
    @Published var cameraName = ""
    @Published var batteryLevel: String = "--"

    @Published var params: [CameraParam] = []

    @Published var transferItems: [TransferItem] = []
    @Published var autoDownloadEnabled = false
    @Published var isBusy = false

    let discovery = CameraDiscovery()

    // MARK: - 内部状态
    private var session: PTPIPSession?
    private var camera: NikonCamera?
    private let workQueue = DispatchQueue(label: "camera.work", qos: .userInitiated)
    private var downloadedHandles: Set<UInt32> = []
    private var lastStatus: String = ""

    // MARK: - 连接

    private var connectToken = UUID()

    func connect(to candidate: CameraCandidate) {
        disconnect()

        let token = UUID()
        connectToken = token
        state = .connecting
        isBusy = true

        let guid = Self.persistedGUID()
        let deviceName = UIDevice.current.name

        Task {
            var newSession: PTPIPSession?
            do {
                newSession = try await runOnWorkQueue {
                    try PTPIPSession.connect(host: candidate.host,
                                             useInitiationPacket: false,
                                             deviceName: deviceName,
                                             guid: guid)
                }
                guard let newSession else { throw PTPError.connectionClosed }

                try await runOnWorkQueue {
                    _ = try newSession.transaction(op: .openSession, params: [newSession.sessionID])
                }
                let info = try await runOnWorkQueue {
                    let (_, data) = try newSession.transaction(op: .getDeviceInfo, expectsData: true)
                    return try PTPDeviceInfo.parse(data)
                }

                guard token == self.connectToken else {
                    newSession.close()
                    return
                }

                let cam = NikonCamera(session: newSession, deviceInfo: info)
                self.session = newSession
                self.camera = cam
                self.cameraModel = info.modelDisplay
                self.cameraName = info.modelDisplay

                // 事件处理（自动下载）
                newSession.onEvent = { [weak self] code, params in
                    Task { @MainActor in
                        self?.handleEvent(code, params: params)
                    }
                }
                newSession.onDisconnect = { [weak self] in
                    Task { @MainActor in
                        self?.handleDisconnect()
                    }
                }

                // 初始枚举
                try await runOnWorkQueue { try cam.loadStorages() }
                await loadExposureParams()
                await refreshBattery()

                state = .connected
            } catch {
                newSession?.close()
                if token == self.connectToken {
                    self.session = nil
                    self.camera = nil
                    state = .failed(error.localizedDescription)
                }
            }
            if token == self.connectToken {
                isBusy = false
            }
        }
    }

    func disconnect() {
        connectToken = UUID()
        session?.close()
        session = nil
        camera = nil
        state = .idle
        params = []
        cameraModel = ""
        cameraName = ""
        isBusy = false
    }

    // MARK: - 参数

    private let apertureCandidates: [PTPDevicePropCode] = [.fNumber, .nikon1FNumber, .nikon1FNumber2, .nikonApertureSetting]
    private let shutterCandidates: [PTPDevicePropCode] = [.exposureTime, .nikonExposureTime, .nikon1ShutterSpeed, .nikon1ShutterSpeed2]
    private let isoCandidates: [PTPDevicePropCode] = [.exposureIndex, .nikonISOControlSensitivity, .nikonExposureIndexEx, .nikon1ISO]
    private let wbCandidates: [PTPDevicePropCode] = [.whiteBalance]

    private func loadExposureParams() async {
        guard let camera else { return }
        var result: [CameraParam] = []
        do {
            result = try await runOnWorkQueue {
                var params: [CameraParam] = []
                for (category, codes, label) in [
                    ("光圈", self.apertureCandidates, "光圈"),
                    ("快门", self.shutterCandidates, "快门速度"),
                    ("ISO", self.isoCandidates, "ISO"),
                    ("白平衡", self.wbCandidates, "白平衡"),
                ] {
                    _ = category
                    if let param = self.buildParam(codes: codes, name: label, camera: camera) {
                        params.append(param)
                    }
                }
                return params
            }
        } catch {
            // 枚举失败不阻塞连接
        }
        params = result
    }

    nonisolated private func buildParam(codes: [PTPDevicePropCode], name: String, camera: NikonCamera) -> CameraParam? {
        for code in codes {
            guard let desc = try? camera.devicePropDesc(code: code.rawValue) else { continue }
            let options = Self.options(for: desc)
            guard !options.isEmpty else { continue }
            let currentID = options.first(where: { $0.value == desc.currentValue })?.id ?? options.first!.id
            return CameraParam(code: code.rawValue,
                               name: name,
                               dataType: desc.dataType,
                               options: options,
                               selectedID: currentID)
        }
        return nil
    }

    /// 由属性描述生成可选值列表（优先枚举值，其次范围值）
    nonisolated static func options(for desc: PTPDevicePropDesc) -> [CameraParamOption] {
        var result: [CameraParamOption] = []
        if !desc.enumValues.isEmpty {
            for (i, value) in desc.enumValues.enumerated() {
                result.append(CameraParamOption(id: "enum-\(i)", label: label(for: value, dataType: desc.dataType, code: desc.code), value: value))
            }
        } else if let minV = desc.rangeMin, let maxV = desc.rangeMax, let stepV = desc.rangeStep {
            let minVal = minV.uint32Value ?? 0
            let maxVal = maxV.uint32Value ?? minVal
            let step = Swift.max(1, stepV.uint32Value ?? 1)
            let count = step == 0 ? 0 : ((maxVal - minVal) / step) + 1
            // 范围过大会撑爆界面，最多生成 400 项
            guard count > 0, count <= 400 else { return [] }
            var value = minVal
            for _ in 0..<Int(count) {
                let v: PTPValue = desc.dataType == .int16 ? .int16(Int16(truncatingIfNeeded: value)) : .uint32(value)
                result.append(CameraParamOption(id: "range-\(value)", label: label(for: v, dataType: desc.dataType, code: desc.code), value: v))
                value = value &+ step
            }
        }
        return result
    }

    /// 参数值格式化
    nonisolated static func label(for value: PTPValue, dataType: PTPDataType, code: UInt32) -> String {
        switch PTPDevicePropCode(rawValue: code) {
        case .fNumber, .nikon1FNumber, .nikon1FNumber2, .nikonApertureSetting:
            if let u = value.uint32Value {
                if u == 0xFFFF { return "自动" }
                let f = Double(u) / 65536.0
                return String(format: "f/%.1f", f)
            }
        case .exposureTime, .nikonExposureTime, .nikon1ShutterSpeed, .nikon1ShutterSpeed2:
            if let u = value.uint32Value {
                if u == 0xFFFF { return "自动" }
                let secs = Double(u) / 65536.0
                return Self.shutterString(secs)
            }
        case .exposureIndex, .nikonISOControlSensitivity, .nikonExposureIndexEx, .nikon1ISO:
            if let u = value.uint32Value {
                if u == 0xFFFF { return "自动" }
                if u > 10000 { // A6080 编码
                    return "\(Int(Double(u) / 65536.0))"
                }
                return "\(u)"
            }
        case .whiteBalance:
            if let u = value.uint32Value {
                return Self.whiteBalanceName(u)
            }
        default:
            break
        }

        switch value {
        case .string(let s): return s
        case .uint16(let v): return "\(v)"
        case .int16(let v): return "\(v)"
        case .uint32(let v): return "\(v)"
        case .int32(let v): return "\(v)"
        case .uint8(let v): return "\(v)"
        default: return value.stringValue
        }
    }

    nonisolated static func shutterString(_ seconds: Double) -> String {
        if seconds <= 0 { return "—" }
        if seconds >= 1 {
            if seconds == seconds.rounded() {
                return "\(Int(seconds))s"
            }
            return String(format: "%.1fs", seconds)
        }
        let denom = Int((1.0 / seconds).rounded())
        return "1/\(denom)"
    }

    nonisolated static func whiteBalanceName(_ code: UInt32) -> String {
        switch code {
        case 0x0001, 0x8000: return "自动"
        case 0x0002: return "日光"
        case 0x0003: return "荧光灯"
        case 0x0004: return "白炽灯"
        case 0x0005: return "闪光"
        case 0x0006: return "阴天"
        case 0x0007: return "阴影"
        case 0x0009: return "色温"
        case 0x8010: return "手动预设"
        default: return "\(code)"
        }
    }

    func setParam(_ param: CameraParam, optionID: String) {
        guard let camera,
              let option = param.options.first(where: { $0.id == optionID }) else { return }

        // 更新 UI 立即
        if let idx = params.firstIndex(where: { $0.id == param.id }) {
            params[idx].selectedID = optionID
        }

        let code = param.code
        let dataType = param.dataType
        let value = option.value
        Task {
            do {
                try await runOnWorkQueue {
                    try camera.setDevicePropValue(code: code, value: value, dataType: dataType)
                }
                lastStatus = "已设置 \(param.name)"
            } catch {
                lastStatus = "设置 \(param.name) 失败: \(error.localizedDescription)"
            }
        }
    }

    func refreshBattery() async {
        guard let camera else { return }
        do {
            if let desc = try await runOnWorkQueue({ try camera.devicePropDesc(code: PTPDevicePropCode.batteryLevel.rawValue) }),
               let cur = desc.currentValue,
               let raw = cur.uint32Value {
                batteryLevel = "\(raw)%"
            } else {
                batteryLevel = "--"
            }
        } catch {
            batteryLevel = "--"
        }
    }

    // MARK: - 拍摄

    func capture() {
        guard let camera else { return }
        isBusy = true
        Task {
            do {
                try await runOnWorkQueue { try camera.initiateCapture() }
                lastStatus = "已触发快门"
            } catch {
                lastStatus = "拍摄失败: \(error.localizedDescription)"
            }
            isBusy = false
        }
    }

    func toggleMovie() {
        guard let camera else { return }
        isBusy = true
        Task {
            do {
                if isRecording {
                    try await runOnWorkQueue { try camera.endMovieRecording() }
                    isRecording = false
                    lastStatus = "已停止录像"
                } else {
                    try await runOnWorkQueue { try camera.startMovieRecording() }
                    isRecording = true
                    lastStatus = "已开始录像"
                }
            } catch {
                lastStatus = "录像操作失败: \(error.localizedDescription)"
            }
            isBusy = false
        }
    }

    @Published var isRecording = false

    // MARK: - 传输

    /// 下载全部文件（手动触发，忽略已下载去重）。
    func downloadAll() async {
        guard let camera else { return }
        isBusy = true
        do {
            let handles = try await runOnWorkQueue { try camera.objectHandles() }
            for h in handles {
                await downloadHandle(h, force: true)
            }
        } catch {
            lastStatus = "列出文件失败: \(error.localizedDescription)"
        }
        isBusy = false
    }

    /// 下载指定句柄（串行执行）。
    @discardableResult
    func downloadHandle(_ handle: UInt32, force: Bool = false) async -> Bool {
        guard let camera else { return false }
        if downloadedHandles.contains(handle) && !force { return true }
        downloadedHandles.insert(handle)

        var info: PTPObjectInfo?
        var data: [UInt8] = []
        do {
            let result = try await runOnWorkQueue {
                try camera.downloadObject(handle: handle)
            }
            info = result.info
            data = result.data
        } catch {
            lastStatus = "下载失败(\(String(format: "0x%X", handle))): \(error.localizedDescription)"
            return false
        }

        guard let info else { return false }
        let isVideo = info.isVideo

        let item = TransferItem(handle: handle,
                                filename: info.filename,
                                size: info.objectSize > 0 ? Int(info.objectSize) : data.count,
                                kind: isVideo ? .video : .photo,
                                status: .downloading)
        transferItems.insert(item, at: 0)

        do {
            let url = try PhotoLibrarySaver.writeTempFile(data: data, filename: info.filename)
            let kind: PhotoLibrarySaver.MediaKind = isVideo ? .video : .photo
            try await saveToPhotos(url: url, kind: kind, itemID: item.id)
            updateTransfer(itemID: item.id) { $0.status = .saved }
            lastStatus = "已保存 \(info.filename)"
            return true
        } catch {
            updateTransfer(itemID: item.id) { $0.status = .failed(error.localizedDescription) }
            lastStatus = "保存失败: \(error.localizedDescription)"
            return false
        }
    }

    private func saveToPhotos(url: URL, kind: PhotoLibrarySaver.MediaKind, itemID: UUID) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            PhotoLibrarySaver.save(fileURL: url, kind: kind) { success, error in
                if success {
                    cont.resume()
                } else {
                    cont.resume(throwing: error ?? PTPError.badData("保存到相册失败"))
                }
            }
        }
    }

    private func updateTransfer(itemID: UUID, _ mutate: (inout TransferItem) -> Void) {
        if let idx = transferItems.firstIndex(where: { $0.id == itemID }) {
            mutate(&transferItems[idx])
        }
    }

    // MARK: - 事件与断连

    private func handleEvent(_ code: PTPEventCode, params: [UInt32]) {
        switch code {
        case .objectAdded, .nikonObjectAddedInSDRAM:
            if let handle = params.first, autoDownloadEnabled {
                Task {
                    await downloadHandle(handle)
                }
            }
        case .nikonMovieRecordStarted:
            isRecording = true
        case .nikonMovieRecordComplete, .nikonMovieRecordInterrupted:
            isRecording = false
        default:
            break
        }
    }

    private func handleDisconnect() {
        state = .idle
        session = nil
        camera = nil
        params = []
        lastStatus = "与相机连接已断开"
    }

    // MARK: - 工具

    /// 在串行工作队列上执行阻塞 PTP 操作。
    func runOnWorkQueue<T>(_ block: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { cont in
            workQueue.async {
                do {
                    cont.resume(returning: try block())
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }

    private static func persistedGUID() -> [UInt8] {
        let key = "ptp.ptpip.guid"
        if let data = UserDefaults.standard.data(forKey: key), data.count == 16 {
            return [UInt8](data)
        }
        var guid = (0..<16).map { _ in UInt8.random(in: 0...255) }
        guid[6] = (guid[6] & 0x0F) | 0x40 // version 4
        guid[8] = (guid[8] & 0x3F) | 0x80 // variant
        UserDefaults.standard.set(Data(guid), forKey: key)
        return guid
    }
}
