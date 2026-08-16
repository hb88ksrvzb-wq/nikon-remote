import Foundation

/// 可连接的相机
struct CameraCandidate: Identifiable, Equatable {
    let id: String
    let name: String
    let host: String
    let port: Int
    let eventPort: Int

    static func manual(ip: String) -> CameraCandidate {
        CameraCandidate(id: "manual-\(ip)",
                        name: "手动 \(ip)",
                        host: ip,
                        port: PTPIPSession.defaultCommandPort,
                        eventPort: PTPIPSession.defaultEventPort)
    }
}

/// 通过 Bonjour 发现 `_ptp._tcp` 服务的相机，并支持手动 IP。
final class CameraDiscovery: NSObject, ObservableObject {

    @Published var cameras: [CameraCandidate] = []
    @Published var isSearching = false

    private var browser: NetServiceBrowser?
    private var services: [NetService] = []
    private var resolved: [String: CameraCandidate] = [:]

    override init() {
        super.init()
    }

    func start() {
        guard !isSearching else { return }
        isSearching = true
        cameras = []
        resolved = [:]
        let b = NetServiceBrowser()
        b.delegate = self
        b.searchForServices(ofType: "_ptp._tcp", inDomain: "local.")
        browser = b
    }

    func stop() {
        isSearching = false
        browser?.stop()
        browser = nil
        services = []
    }

    func resolve(_ service: NetService) {
        service.delegate = self
        service.resolve(withTimeout: 8)
    }
}

extension CameraDiscovery: NetServiceBrowserDelegate {

    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        isSearching = true
    }

    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        isSearching = false
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        isSearching = false
    }

    func netServiceBrowser(_ browser: NetServiceBrowser,
                           didFind service: NetService,
                           moreComing: Bool) {
        services.append(service)
        resolve(service)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser,
                           didRemove service: NetService,
                           moreComing: Bool) {
        services.removeAll { $0 == service }
        resolved[service.name] = nil
        refresh()
    }
}

extension CameraDiscovery: NetServiceDelegate {

    func netServiceDidResolveAddress(_ sender: NetService) {
        guard let host = sender.hostName,
              let port = sender.port as Int? else { return }
        // hostName 可能是 .local 名称，转成 IP 更稳妥
        let ip = Self.resolveIP(host) ?? host
        resolved[sender.name] = CameraCandidate(id: sender.name,
                                                name: sender.name,
                                                host: ip,
                                                port: port == 0 ? PTPIPSession.defaultCommandPort : port,
                                                eventPort: PTPIPSession.defaultEventPort)
        refresh()
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        // 解析失败，保留主机名尝试连接
        if let host = sender.hostName {
            resolved[sender.name] = CameraCandidate(id: sender.name,
                                                    name: sender.name,
                                                    host: host,
                                                    port: PTPIPSession.defaultCommandPort,
                                                    eventPort: PTPIPSession.defaultEventPort)
            refresh()
        }
    }

    private func refresh() {
        let list = resolved.values.sorted { $0.name < $1.name }
        DispatchQueue.main.async { [weak self] in
            self?.cameras = list
        }
    }

    /// 解析主机名到 IP 字符串。
    static func resolveIP(_ hostname: String) -> String? {
        var hints = addrinfo()
        hints.ai_family = AF_INET
        hints.ai_socktype = SOCK_STREAM
        var res: UnsafeMutablePointer<addrinfo>? = nil
        let rc = getaddrinfo(hostname, nil, &hints, &res)
        defer {
            if res != nil { freeaddrinfo(res) }
        }
        guard rc == 0, let resPtr = res else { return nil }
        guard let sa = resPtr.pointee.ai_addr else { return nil }
        let addr = sa.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr }
        var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        return inet_ntop(AF_INET, &addr, &buf, socklen_t(buf.count)).map { String(cString: $0) }
    }
}
