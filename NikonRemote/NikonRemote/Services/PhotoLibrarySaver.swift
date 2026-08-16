import Foundation
import Photos

/// 将原始文件（NEF/JPEG/MOV 等）原样保存到系统相册，无损。
enum PhotoLibrarySaver {

    enum MediaKind {
        case photo
        case video
    }

    /// 请求添加权限。
    static func requestAuthorization(_ completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            completion(status == .authorized)
        }
    }

    /// 把文件保存到相册。fileURL 的扩展名必须正确（NEF/MOV 等），Photos 会原样保留原始数据。
    /// - Parameters:
    ///   - fileURL: 本地文件地址
    ///   - kind: 媒体类型
    static func save(fileURL: URL, kind: MediaKind, completion: @escaping (Bool, Error?) -> Void) {
        var placeholder: PHObjectPlaceholder?
        PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            switch kind {
            case .photo:
                request.addResource(with: .photo, fileURL: fileURL, options: nil)
            case .video:
                request.addResource(with: .video, fileURL: fileURL, options: nil)
            }
            placeholder = request.placeholderForCreatedAsset
        } completionHandler: { success, error in
            completion(success, error)
        }
    }

    /// 将字节数组写入临时文件并返回 URL。
    static func writeTempFile(data: [UInt8], filename: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
        let safeName = filename.replacingOccurrences(of: "/", with: "_")
        let url = dir.appendingPathComponent("NikonTransfer_\(UUID().uuidString)_\(safeName)")
        try Data(data).write(to: url)
        return url
    }
}
