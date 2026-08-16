import Foundation
import NetworkExtension

/// 自动连接相机 Wi-Fi（需要 Hotspot Configuration 权限）。
/// 若自动连接失败，引导用户到系统设置手动连接。
enum WifiJoiner {

    /// 尝试自动加入指定 Wi-Fi。
    /// - Parameters:
    ///   - ssid: 网络名称
    ///   - password: 密码（无密码传 nil）
    ///   - completion: 完成回调（isAuto: 是否走自动连接，error: 错误）
    static func join(ssid: String, password: String?, completion: @escaping (Bool, Error?) -> Void) {
        let configuration: NEHotspotConfiguration
        if let password, !password.isEmpty {
            configuration = NEHotspotConfiguration(ssid: ssid, passphrase: password, isWPA3: false)
        } else {
            configuration = NEHotspotConfiguration(ssid: ssid)
        }
        configuration.joinOnce = true
        NEHotspotConfigurationManager.shared.apply(configuration) { error in
            if let error {
                // 用户可能拒绝，或已连接其他网络；提示手动连接
                completion(true, error)
            } else {
                completion(true, nil)
            }
        }
    }

    /// 移除已保存的热点配置（下次加入时需重新授权）。
    static func forget(ssid: String) {
        NEHotspotConfigurationManager.shared.removeConfiguration(forSSID: ssid)
    }

    static func forgetAll() {
        NEHotspotConfigurationManager.shared.removeAllConfigurations()
    }
}
