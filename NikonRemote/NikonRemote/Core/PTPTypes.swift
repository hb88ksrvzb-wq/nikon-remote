import Foundation

/// 错误类型
enum PTPError: Error, LocalizedError {
    case notConnected
    case timeout
    case connectionClosed
    case badData(String)
    case camera(String, UInt16)
    case unsupported(String)

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "尚未连接相机"
        case .timeout:
            return "等待相机响应超时"
        case .connectionClosed:
            return "与相机的连接已断开"
        case .badData(let msg):
            return "数据解析错误: \(msg)"
        case .camera(let msg, let code):
            return "相机返回错误 \(String(format: "0x%04X", code)): \(msg)"
        case .unsupported(let msg):
            return "不支持: \(msg)"
        }
    }
}

/// PTP-IP 包类型
enum PTPIPPacketType: UInt32 {
    case initCommandRequest = 1
    case initCommandAck = 2
    case initEventRequest = 3
    case initEventAck = 4
    case initFail = 5
    case commandRequest = 6
    case commandResponse = 7
    case event = 8
    case startDataPacket = 9
    case dataPacket = 10
    case cancelTransaction = 11
    case endDataPacket = 12
    case ping = 13
    case pong = 14
}

/// PTP/IP 命令请求中的数据阶段方向。
/// 线格式与 gphoto2 一致：发数据 = 2，收数据/无数据 = 1。
enum PTPIPDataPhase: UInt32 {
    case none = 0
    case incoming = 1
    case outgoing = 2

    static func forTransaction(hasOutgoingData: Bool, expectsIncomingData: Bool) -> PTPIPDataPhase {
        precondition(!(hasOutgoingData && expectsIncomingData), "一个 PTP 事务只能有一个数据方向")
        if hasOutgoingData { return .outgoing }
        if expectsIncomingData { return .incoming }
        return .none
    }
}

/// PTP 操作码
enum PTPOperation: UInt16 {
    case getDeviceInfo = 0x1001
    case openSession = 0x1002
    case closeSession = 0x1003
    case getStorageIDs = 0x1004
    case getStorageInfo = 0x1005
    case getObjectHandles = 0x1007
    case getObjectInfo = 0x1008
    case getObject = 0x1009
    case getThumb = 0x100A
    case deleteObject = 0x100B
    case initiateCapture = 0x100E
    case terminateCapture = 0x1010
    case getDevicePropDesc = 0x1014
    case getDevicePropValue = 0x1015
    case setDevicePropValue = 0x1016
    case resetDevicePropValue = 0x1017
    case getPartialObject = 0x101B
    case nikonStartMovieRecInCard = 0x920A
    case nikonEndMovieRec = 0x920B

    var name: String {
        switch self {
        case .getDeviceInfo: return "GetDeviceInfo"
        case .openSession: return "OpenSession"
        case .closeSession: return "CloseSession"
        case .getStorageIDs: return "GetStorageIDs"
        case .getStorageInfo: return "GetStorageInfo"
        case .getObjectHandles: return "GetObjectHandles"
        case .getObjectInfo: return "GetObjectInfo"
        case .getObject: return "GetObject"
        case .getThumb: return "GetThumb"
        case .deleteObject: return "DeleteObject"
        case .initiateCapture: return "InitiateCapture"
        case .terminateCapture: return "TerminateCapture"
        case .getDevicePropDesc: return "GetDevicePropDesc"
        case .getDevicePropValue: return "GetDevicePropValue"
        case .setDevicePropValue: return "SetDevicePropValue"
        case .resetDevicePropValue: return "ResetDevicePropValue"
        case .getPartialObject: return "GetPartialObject"
        case .nikonStartMovieRecInCard: return "StartMovieRec"
        case .nikonEndMovieRec: return "EndMovieRec"
        }
    }
}

/// PTP 响应码
enum PTPResponseCode: UInt16 {
    case undefined = 0x2000
    case ok = 0x2001
    case generalError = 0x2002
    case sessionNotOpen = 0x2003
    case invalidTransactionID = 0x2004
    case operationNotSupported = 0x2005
    case parameterNotSupported = 0x2006
    case incompleteTransfer = 0x2007
    case invalidStorageID = 0x2008
    case invalidObjectHandle = 0x2009
    case devicePropNotSupported = 0x200A
    case invalidObjectFormatCode = 0x200B
    case storeFull = 0x200C
    case objectWriteProtected = 0x200D
    case storeReadOnly = 0x200E
    case accessDenied = 0x200F
    case objectDoesNotExist = 0x2010
    case objectGenerationMismatch = 0x2011
    case noStorageAvailable = 0x2012
    case specificationByFormatUnsupported = 0x2013
    case noValidObjectInfo = 0x2014
    case invalidCodeFormat = 0x2015
    case unknownVendorCode = 0x2016
    case captureAlreadyTerminated = 0x2018
    case deviceBusy = 0x2019
    case invalidParentObject = 0x201A
    case invalidDevicePropFormat = 0x201B
    case invalidDevicePropValue = 0x201C
    case invalidParameter = 0x201D
    case sessionAlreadyOpen = 0x201E
    case transactionCanceled = 0x201F
    case specificationOfDestinationUnsupported = 0x2020

    var name: String {
        switch self {
        case .ok: return "OK"
        case .generalError: return "GeneralError"
        case .sessionNotOpen: return "SessionNotOpen"
        case .invalidTransactionID: return "InvalidTransactionID"
        case .operationNotSupported: return "OperationNotSupported"
        case .parameterNotSupported: return "ParameterNotSupported"
        case .devicePropNotSupported: return "DevicePropNotSupported"
        case .invalidObjectHandle: return "InvalidObjectHandle"
        case .invalidStorageID: return "InvalidStorageID"
        case .storeFull: return "StoreFull"
        case .accessDenied: return "AccessDenied"
        case .objectDoesNotExist: return "ObjectDoesNotExist"
        case .noStorageAvailable: return "NoStorageAvailable"
        case .deviceBusy: return "DeviceBusy"
        case .invalidDevicePropValue: return "InvalidDevicePropValue"
        case .invalidParameter: return "InvalidParameter"
        case .sessionAlreadyOpen: return "SessionAlreadyOpen"
        case .transactionCanceled: return "TransactionCanceled"
        default: return "0x\(String(rawValue, radix: 16))"
        }
    }
}

/// PTP 事件码
enum PTPEventCode: UInt16 {
    case objectAdded = 0x4002
    case objectRemoved = 0x4003
    case storeAdded = 0x4004
    case storeRemoved = 0x4005
    case devicePropChanged = 0x4006
    case objectInfoChanged = 0x4007
    case deviceInfoChanged = 0x4008
    case requestObjectTransfer = 0x4009
    case storeFull = 0x400A
    case deviceReset = 0x400B
    case storageInfoChanged = 0x400C
    case captureComplete = 0x400D
    case unreportedStatus = 0x400E
    case nikonObjectAddedInSDRAM = 0xC101
    case nikonCaptureCompleteRecInSdram = 0xC102
    case nikonAdvancedTransfer = 0xC103
    case nikonPreviewImageAdded = 0xC104
    case nikonMovieRecordInterrupted = 0xC105
    case nikonMovieRecordComplete = 0xC108
    case nikonMovieRecordStarted = 0xC10A
    case nikonLiveViewStateChanged = 0xC10C
}

/// PTP 数据类型码
enum PTPDataType: UInt16 {
    case int8 = 0x0001
    case uint8 = 0x0002
    case int16 = 0x0003
    case uint16 = 0x0004
    case int32 = 0x0005
    case uint32 = 0x0006
    case int64 = 0x0007
    case uint64 = 0x0008
    case string = 0xFFFF

    var isArray: Bool {
        rawValue & 0x4000 != 0
    }

    var baseType: PTPDataType {
        PTPDataType(rawValue: rawValue & ~0x4000) ?? .uint16
    }

    var byteCount: Int {
        switch baseType {
        case .int8, .uint8: return 1
        case .int16, .uint16: return 2
        case .int32, .uint32: return 4
        case .int64, .uint64: return 8
        default: return 0
        }
    }
}

/// PTP 属性值
enum PTPValue: Equatable {
    case int8(Int8)
    case uint8(UInt8)
    case int16(Int16)
    case uint16(UInt16)
    case int32(Int32)
    case uint32(UInt32)
    case int64(Int64)
    case uint64(UInt64)
    case string(String)
    case uint16Array([UInt16])
    case uint32Array([UInt32])

    var uint32Value: UInt32? {
        switch self {
        case .uint8(let v): return UInt32(v)
        case .int8(let v): return UInt32(bitPattern: Int32(v))
        case .uint16(let v): return UInt32(v)
        case .int16(let v): return UInt32(bitPattern: Int32(v))
        case .uint32(let v): return v
        case .int32(let v): return UInt32(bitPattern: v)
        case .uint64(let v): return UInt32(truncatingIfNeeded: v)
        case .int64(let v): return UInt32(truncatingIfNeeded: v)
        default: return nil
        }
    }

    var stringValue: String {
        switch self {
        case .uint16(let v): return "\(v)"
        case .int16(let v): return "\(v)"
        case .uint32(let v): return "\(v)"
        case .int32(let v): return "\(v)"
        case .uint8(let v): return "\(v)"
        case .int8(let v): return "\(v)"
        case .uint64(let v): return "\(v)"
        case .int64(let v): return "\(v)"
        case .string(let s): return s
        case .uint16Array(let a): return a.map { "\($0)" }.joined(separator: ",")
        case .uint32Array(let a): return a.map { "\($0)" }.joined(separator: ",")
        }
    }

    /// 按目标 PTP 数据类型编码数值，防止范围值以错误字宽发送。
    func encode(for dataType: PTPDataType) throws -> [UInt8] {
        var out: [UInt8] = []
        switch dataType {
        case .int8: ByteWriter.append(try signedValue(as: Int8.self), to: &out)
        case .uint8: ByteWriter.append(try unsignedValue(as: UInt8.self), to: &out)
        case .int16: ByteWriter.append(try signedValue(as: Int16.self), to: &out)
        case .uint16: ByteWriter.append(try unsignedValue(as: UInt16.self), to: &out)
        case .int32: ByteWriter.append(try signedValue(as: Int32.self), to: &out)
        case .uint32: ByteWriter.append(try unsignedValue(as: UInt32.self), to: &out)
        case .int64: ByteWriter.append(try signedValue(as: Int64.self), to: &out)
        case .uint64: ByteWriter.append(try unsignedValue(as: UInt64.self), to: &out)
        case .string:
            guard case .string(let value) = self else {
                throw PTPError.badData("PTP 字符串属性不是字符串值")
            }
            ByteWriter.appendPTPString(value, to: &out)
        default:
            switch self {
            case .uint16Array(let values):
                ByteWriter.append(UInt32(values.count), to: &out)
                for value in values { ByteWriter.append(value, to: &out) }
            case .uint32Array(let values):
                ByteWriter.append(UInt32(values.count), to: &out)
                for value in values { ByteWriter.append(value, to: &out) }
            default:
                throw PTPError.badData("不支持的 PTP 数组属性值")
            }
        }
        return out
    }

    private func unsignedValue<T: FixedWidthInteger & UnsignedInteger>(as type: T.Type) throws -> T {
        let value: UInt64
        switch self {
        case .uint8(let v): value = UInt64(v)
        case .uint16(let v): value = UInt64(v)
        case .uint32(let v): value = UInt64(v)
        case .uint64(let v): value = v
        case .int8(let v) where v >= 0: value = UInt64(v)
        case .int16(let v) where v >= 0: value = UInt64(v)
        case .int32(let v) where v >= 0: value = UInt64(v)
        case .int64(let v) where v >= 0: value = UInt64(v)
        default: throw PTPError.badData("属性值不能编码为无符号整数")
        }
        guard value <= UInt64(T.max) else {
            throw PTPError.badData("属性值超出目标无符号类型范围")
        }
        return T(value)
    }

    private func signedValue<T: FixedWidthInteger & SignedInteger>(as type: T.Type) throws -> T {
        let value: Int64
        switch self {
        case .int8(let v): value = Int64(v)
        case .int16(let v): value = Int64(v)
        case .int32(let v): value = Int64(v)
        case .int64(let v): value = v
        case .uint8(let v): value = Int64(v)
        case .uint16(let v): value = Int64(v)
        case .uint32(let v): value = Int64(v)
        case .uint64(let v) where v <= UInt64(Int64.max): value = Int64(v)
        default: throw PTPError.badData("属性值不能编码为有符号整数")
        }
        guard value >= Int64(T.min), value <= Int64(T.max) else {
            throw PTPError.badData("属性值超出目标有符号类型范围")
        }
        return T(value)
    }
}

/// 从数据流中按 dataType 解析一个属性值
enum PTPValueParser {
    static func parse(_ dataType: PTPDataType, reader: inout ByteReader) throws -> PTPValue {
        if dataType.isArray {
            let count = Int(try reader.readUInt32())
            let base = dataType.baseType
            switch base {
            case .int8:
                var a: [UInt8] = []
                for _ in 0..<count { a.append(try reader.readUInt8()) }
                return .uint8(0) // arrays rarely used for props; return as uint32Array below for the common cases
            case .uint16:
                var a: [UInt16] = []
                for _ in 0..<count { a.append(try reader.readUInt16()) }
                return .uint16Array(a)
            case .uint32:
                var a: [UInt32] = []
                for _ in 0..<count { a.append(try reader.readUInt32()) }
                return .uint32Array(a)
            default:
                var a: [UInt32] = []
                for _ in 0..<count { a.append(try reader.readUInt32()) }
                return .uint32Array(a)
            }
        }

        switch dataType {
        case .int8: return .int8(try reader.readInt8())
        case .uint8: return .uint8(try reader.readUInt8())
        case .int16: return .int16(try reader.readInt16())
        case .uint16: return .uint16(try reader.readUInt16())
        case .int32: return .int32(try reader.readInt32())
        case .uint32: return .uint32(try reader.readUInt32())
        case .int64: return .int64(try reader.readInt64())
        case .uint64: return .uint64(try reader.readUInt64())
        case .string: return .string(try reader.readPTPString())
        default: throw PTPError.badData("未知数据类型 0x\(String(dataType.rawValue, radix: 16))")
        }
    }
}

/// PTP 设备属性码（注意：尼康 Z 系列使用 32 位属性码）
enum PTPDevicePropCode: UInt32 {
    case batteryLevel = 0x5001
    case functionalMode = 0x5002
    case imageSize = 0x5003
    case compressionSetting = 0x5004
    case whiteBalance = 0x5005
    case fNumber = 0x5007
    case focalLength = 0x5008
    case focusDistance = 0x5009
    case focusMode = 0x500A
    case exposureMeteringMode = 0x500B
    case flashMode = 0x500C
    case exposureTime = 0x500D
    case exposureProgramMode = 0x500E
    case exposureIndex = 0x500F
    case exposureBiasCompensation = 0x5010
    case dateTime = 0x5011
    case captureDelay = 0x5012
    case stillCaptureMode = 0x5013
    case contrast = 0x5014
    case sharpness = 0x5015
    case digitalZoom = 0x5016
    case effectMode = 0x5017
    case burstNumber = 0x5018
    case timingPreviewMode = 0x5019
    case focusLock = 0x501A

    // 尼康扩展
    case nikonShootingMode = 0xD030
    case nikonRemoteMode = 0xD035
    case nikonVideoMode = 0xD036
    case nikonISOControlSensitivity = 0xD0B5
    case nikonExposureIndexEx = 0xD0B4
    case nikonExposureTime = 0xD100
    case nikonApertureSetting = 0xD087
    case nikon1ISO = 0xF002
    case nikon1FNumber = 0xF003
    case nikon1ShutterSpeed = 0xF004
    case nikon1FNumber2 = 0xF006
    case nikon1ShutterSpeed2 = 0xF007

    var name: String {
        switch self {
        case .batteryLevel: return "电量"
        case .functionalMode: return "功能模式"
        case .imageSize: return "影像尺寸"
        case .compressionSetting: return "压缩设置"
        case .whiteBalance: return "白平衡"
        case .fNumber: return "光圈"
        case .focalLength: return "焦距"
        case .focusDistance: return "对焦距离"
        case .focusMode: return "对焦模式"
        case .exposureMeteringMode: return "测光模式"
        case .flashMode: return "闪光模式"
        case .exposureTime: return "快门速度"
        case .exposureProgramMode: return "曝光程序"
        case .exposureIndex: return "ISO"
        case .exposureBiasCompensation: return "曝光补偿"
        case .dateTime: return "日期时间"
        case .captureDelay: return "拍摄延迟"
        case .stillCaptureMode: return "拍摄模式"
        case .contrast: return "对比度"
        case .sharpness: return "锐度"
        case .digitalZoom: return "数码变焦"
        case .effectMode: return "特效模式"
        case .burstNumber: return "连拍张数"
        case .timingPreviewMode: return "定时预览"
        case .focusLock: return "对焦锁定"
        case .nikonShootingMode: return "拍摄模式(尼康)"
        case .nikonRemoteMode: return "遥控模式"
        case .nikonVideoMode: return "视频模式"
        case .nikonISOControlSensitivity: return "ISO感光度"
        case .nikonExposureIndexEx: return "ISO扩展"
        case .nikonExposureTime: return "快门速度(尼康)"
        case .nikonApertureSetting: return "光圈(尼康)"
        case .nikon1ISO: return "ISO(N1)"
        case .nikon1FNumber: return "光圈(N1)"
        case .nikon1ShutterSpeed: return "快门(N1)"
        case .nikon1FNumber2: return "光圈(N1-2)"
        case .nikon1ShutterSpeed2: return "快门(N1-2)"
        }
    }
}

/// 曝光三要素候选属性码
struct ExposureProps {
    let aperture: [PTPDevicePropCode] = [.fNumber, .nikon1FNumber, .nikon1FNumber2, .nikonApertureSetting]
    let shutter: [PTPDevicePropCode] = [.exposureTime, .nikonExposureTime, .nikon1ShutterSpeed, .nikon1ShutterSpeed2]
    let iso: [PTPDevicePropCode] = [.exposureIndex, .nikonISOControlSensitivity, .nikonExposureIndexEx, .nikon1ISO]
    let whiteBalance: [PTPDevicePropCode] = [.whiteBalance]
    let exposureBias: [PTPDevicePropCode] = [.exposureBiasCompensation]
    let programMode: [PTPDevicePropCode] = [.exposureProgramMode]
}

/// 设备属性描述数据集
struct PTPDevicePropDesc {
    let code: UInt32
    let dataType: PTPDataType
    let getSet: UInt8
    let defaultValue: PTPValue?
    let currentValue: PTPValue?
    let formFlag: UInt8
    let enumValues: [PTPValue]
    let rangeMin: PTPValue?
    let rangeMax: PTPValue?
    let rangeStep: PTPValue?

    static func parse(_ data: [UInt8]) throws -> PTPDevicePropDesc {
        var reader = ByteReader(data)
        // 线格式为 16 位属性码（gphoto2 ptp_unpack_DPD 用 dtoh16a 读取；32 位只是其内部结构体表示）
        let code = UInt32(try reader.readUInt16())
        let dataType = try PTPDataType(rawValue: reader.readUInt16()) ?? .uint16
        let getSet = try reader.readUInt8()
        let defaultValue = try PTPValueParser.parse(dataType, reader: &reader)
        let currentValue = try PTPValueParser.parse(dataType, reader: &reader)
        let formFlag = try reader.readUInt8()

        var enumValues: [PTPValue] = []
        var rangeMin: PTPValue? = nil
        var rangeMax: PTPValue? = nil
        var rangeStep: PTPValue? = nil

        switch formFlag {
        case 0x01: // Range
            rangeMin = try PTPValueParser.parse(dataType, reader: &reader)
            rangeMax = try PTPValueParser.parse(dataType, reader: &reader)
            rangeStep = try PTPValueParser.parse(dataType, reader: &reader)
        case 0x02: // Enum
            let count = Int(try reader.readUInt16())
            for _ in 0..<count {
                enumValues.append(try PTPValueParser.parse(dataType, reader: &reader))
            }
        default:
            break
        }

        return PTPDevicePropDesc(code: code,
                                 dataType: dataType,
                                 getSet: getSet,
                                 defaultValue: defaultValue,
                                 currentValue: currentValue,
                                 formFlag: formFlag,
                                 enumValues: enumValues,
                                 rangeMin: rangeMin,
                                 rangeMax: rangeMax,
                                 rangeStep: rangeStep)
    }
}

/// 对象信息数据集
struct PTPObjectInfo {
    let storageID: UInt32
    let objectFormat: UInt16
    let protectionStatus: UInt16
    let objectSize: UInt32
    let thumbFormat: UInt16
    let thumbSize: UInt32
    let thumbPixWidth: UInt32
    let thumbPixHeight: UInt32
    let imagePixWidth: UInt32
    let imagePixHeight: UInt32
    let imageBitDepth: UInt32
    let parentObject: UInt32
    let associationType: UInt16
    let associationDesc: UInt32
    let sequenceNumber: UInt32
    let filename: String
    let captureDate: String
    let modificationDate: String
    let keywords: String

    var isAssociation: Bool { associationType != 0 }

    /// 文件扩展名（大写）
    var fileExtension: String {
        let lower = (filename as NSString).pathExtension.lowercased()
        guard !lower.isEmpty else { return "bin" }
        return lower
    }

    /// 判断是否为视频（供存相册使用）
    var isVideo: Bool {
        let ext = fileExtension
        return ["mov", "mp4", "avi"].contains(ext)
    }

    /// 判断是否为照片（NEF/JPEG/TIFF 等）
    var isPhoto: Bool {
        !isVideo && !isAssociation
    }

    static func parse(handle: UInt32, _ data: [UInt8]) throws -> PTPObjectInfo {
        var reader = ByteReader(data)
        return PTPObjectInfo(storageID: try reader.readUInt32(),
                             objectFormat: try reader.readUInt16(),
                             protectionStatus: try reader.readUInt16(),
                             objectSize: try reader.readUInt32(),
                             thumbFormat: try reader.readUInt16(),
                             thumbSize: try reader.readUInt32(),
                             thumbPixWidth: try reader.readUInt32(),
                             thumbPixHeight: try reader.readUInt32(),
                             imagePixWidth: try reader.readUInt32(),
                             imagePixHeight: try reader.readUInt32(),
                             imageBitDepth: try reader.readUInt32(),
                             parentObject: try reader.readUInt32(),
                             associationType: try reader.readUInt16(),
                             associationDesc: try reader.readUInt32(),
                             sequenceNumber: try reader.readUInt32(),
                             filename: try reader.readPTPString(),
                             captureDate: try reader.readPTPString(),
                             modificationDate: try reader.readPTPString(),
                             keywords: try reader.readPTPString())
    }
}

/// 设备信息数据集
struct PTPDeviceInfo {
    let standardVersion: UInt16
    let vendorExtensionID: UInt32
    let vendorExtensionVersion: UInt16
    let vendorExtensionDesc: String
    let functionalMode: UInt16
    let operationsSupported: [UInt16]
    let eventsSupported: [UInt16]
    let devicePropertiesSupported: [UInt16]
    let captureFormats: [UInt16]
    let imageFormats: [UInt16]
    let manufacturer: String
    let model: String
    let deviceVersion: String
    let serialNumber: String

    static func parse(_ data: [UInt8]) throws -> PTPDeviceInfo {
        var reader = ByteReader(data)
        return PTPDeviceInfo(standardVersion: try reader.readUInt16(),
                             vendorExtensionID: try reader.readUInt32(),
                             vendorExtensionVersion: try reader.readUInt16(),
                             vendorExtensionDesc: try reader.readPTPString(),
                             functionalMode: try reader.readUInt16(),
                             operationsSupported: try reader.readUInt16Array(),
                             eventsSupported: try reader.readUInt16Array(),
                             devicePropertiesSupported: try reader.readUInt16Array(),
                             captureFormats: try reader.readUInt16Array(),
                             imageFormats: try reader.readUInt16Array(),
                             manufacturer: try reader.readPTPString(),
                             model: try reader.readPTPString(),
                             deviceVersion: try reader.readPTPString(),
                             serialNumber: try reader.readPTPString())
    }

    var modelDisplay: String {
        let m = model.trimmingCharacters(in: .whitespacesAndNewlines)
        return m.isEmpty ? "尼康相机" : m
    }
}

/// 存储信息数据集
struct PTPStorageInfo {
    let storageType: UInt16
    let filesystemType: UInt16
    let accessCapability: UInt16
    let maxCapability: UInt64
    let freeSpaceInBytes: UInt64
    let freeSpaceInImages: UInt32
    let storageDescription: String
    let volumeLabel: String

    static func parse(_ data: [UInt8]) throws -> PTPStorageInfo {
        var reader = ByteReader(data)
        return PTPStorageInfo(storageType: try reader.readUInt16(),
                              filesystemType: try reader.readUInt16(),
                              accessCapability: try reader.readUInt16(),
                              maxCapability: try reader.readUInt64(),
                              freeSpaceInBytes: try reader.readUInt64(),
                              freeSpaceInImages: try reader.readUInt32(),
                              storageDescription: try reader.readPTPString(),
                              volumeLabel: try reader.readPTPString())
    }
}
