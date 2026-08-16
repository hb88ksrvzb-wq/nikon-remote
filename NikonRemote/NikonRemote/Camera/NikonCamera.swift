import Foundation

/// 尼康相机高层操作封装（基于 PTP/PTP-IP）。
final class NikonCamera {

    let session: PTPIPSession
    let deviceInfo: PTPDeviceInfo
    private(set) var storages: [UInt32] = []

    init(session: PTPIPSession, deviceInfo: PTPDeviceInfo) {
        self.session = session
        self.deviceInfo = deviceInfo
    }

    var modelName: String { deviceInfo.modelDisplay }

    // MARK: - 存储

    func loadStorages() throws {
        let (_, data) = try session.transaction(op: .getStorageIDs, expectsData: true)
        var reader = ByteReader(data)
        storages = try reader.readUInt32Array()
    }

    func storageInfo(_ storageID: UInt32) throws -> PTPStorageInfo {
        let (_, data) = try session.transaction(op: .getStorageInfo, params: [storageID], expectsData: true)
        return try PTPStorageInfo.parse(data)
    }

    // MARK: - 对象（照片/视频）

    /// 列出存储中的对象句柄。storageID 传 nil 表示全部存储。
    func objectHandles(storageID: UInt32? = nil, objectFormatCode: UInt32 = 0) throws -> [UInt32] {
        let storage = storageID ?? 0xFFFFFFFF
        let (_, data) = try session.transaction(op: .getObjectHandles, params: [storage, objectFormatCode, 0], expectsData: true)
        var reader = ByteReader(data)
        return try reader.readUInt32Array()
    }

    func objectInfo(handle: UInt32) throws -> PTPObjectInfo {
        let (_, data) = try session.transaction(op: .getObjectInfo, params: [handle], expectsData: true)
        return try PTPObjectInfo.parse(handle: handle, data)
    }

    /// 下载对象（照片/视频原始数据）。
    func downloadObject(handle: UInt32) throws -> (info: PTPObjectInfo, data: [UInt8]) {
        let info = try objectInfo(handle: handle)
        guard info.objectSize > 0 else {
            throw PTPError.camera("对象大小为 0", 0)
        }
        let (_, data) = try session.transaction(op: .getObject, params: [handle], expectsData: true, timeout: 60)
        return (info, data)
    }

    func deleteObject(handle: UInt32) throws {
        _ = try session.transaction(op: .deleteObject, params: [0xFFFFFFFF, handle])
    }

    // MARK: - 设备属性

    func devicePropDesc(code: UInt32) throws -> PTPDevicePropDesc? {
        let (_, data) = try session.transaction(op: .getDevicePropDesc, params: [code], expectsData: true)
        return try PTPDevicePropDesc.parse(data)
    }

    func devicePropValue(code: UInt32) throws -> PTPValue? {
        let (_, data) = try session.transaction(op: .getDevicePropValue, params: [code], expectsData: true)
        // 无法从响应得知类型；若调用方已缓存 desc 请用 getDevicePropDesc
        // 这里返回原始 UINT32（多数曝光属性适用）
        guard data.count >= 4 else { return nil }
        var reader = ByteReader(data)
        return try .uint32(reader.readUInt32())
    }

    /// 设置设备属性值。value 必须与 desc.dataType 匹配。
    func setDevicePropValue(code: UInt32, value: PTPValue, dataType: PTPDataType) throws {
        let bytes = try value.encode(for: dataType)
        _ = try session.transaction(op: .setDevicePropValue, params: [code], sendData: bytes)
    }

    func resetDevicePropValue(code: UInt32) throws {
        _ = try session.transaction(op: .resetDevicePropValue, params: [code])
    }

    // MARK: - 拍摄

    /// 触发快门。存储 ID 传 0xFFFFFFFF，格式码 0。
    func initiateCapture() throws {
        _ = try session.transaction(op: .initiateCapture, params: [0xFFFFFFFF, 0])
    }

    func terminateCapture() throws {
        _ = try session.transaction(op: .terminateCapture)
    }

    /// 开始视频录制（写入存储卡）。
    func startMovieRecording() throws {
        _ = try session.transaction(op: .nikonStartMovieRecInCard)
    }

    /// 停止视频录制。
    func endMovieRecording() throws {
        _ = try session.transaction(op: .nikonEndMovieRec)
    }

    // MARK: - 会话

    func closeSession() throws {
        _ = try session.transaction(op: .closeSession)
        session.close()
    }

    func disconnect() {
        session.close()
    }
}
