import SwiftUI

struct ConnectionView: View {
    @EnvironmentObject private var manager: CameraManager
    @State private var manualIP = ""
    @State private var cameraSSID = ""
    @State private var cameraPassword = ""

    var body: some View {
        NavigationView {
            List {
                Section {
                    statusRow
                }

                Section("发现到的相机") {
                    if manager.discovery.cameras.isEmpty {
                        Text(manager.discovery.isSearching ? "正在搜索相机…" : "未发现相机")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(manager.discovery.cameras) { camera in
                            Button {
                                manager.connect(to: camera)
                            } label: {
                                HStack {
                                    Image(systemName: "camera.fill")
                                        .foregroundColor(.accentColor)
                                    VStack(alignment: .leading) {
                                        Text(camera.name)
                                            .foregroundColor(.primary)
                                        Text("\(camera.host):\(camera.port)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if manager.state == .connecting {
                                        ProgressView()
                                    }
                                }
                            }
                            .disabled(isConnected)
                        }
                    }
                }

                Section("手动连接") {
                    HStack {
                        TextField("相机 IP（如 192.168.1.1）", text: $manualIP)
                            .keyboardType(.numbersAndPunctuation)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        Button("连接") {
                            connectManual()
                        }
                        .disabled(manualIP.trimmingCharacters(in: .whitespaces).isEmpty || isConnected)
                    }
                }

                Section("相机 Wi-Fi 辅助") {
                    TextField("相机 Wi-Fi 名称（SSID）", text: $cameraSSID)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    HStack {
                        SecureField("Wi-Fi 密码", text: $cameraPassword)
                        Button("自动加入") {
                            autoJoin()
                        }
                    }
                }

                Section("使用说明") {
                    Text("1. 相机菜单开启 Wi-Fi「遥控拍摄」\n2. iPhone 加入相机创建的 Wi-Fi（或使用上方辅助）\n3. 在「手动连接」填入相机 IP 或等待自动发现\n4. 相机与手机在同一网络即可遥控")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("尼康遥控")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(manager.discovery.isSearching ? "停止搜索" : "刷新") {
                        if manager.discovery.isSearching {
                            manager.discovery.stop()
                        } else {
                            manager.discovery.start()
                        }
                    }
                }
            }
            .onAppear {
                manager.discovery.start()
            }
            .onDisappear {
                manager.discovery.stop()
            }
        }
        .navigationViewStyle(.stack)
    }

    private var isConnected: Bool {
        manager.state == .connected || manager.state == .connecting
    }

    private var statusRow: some View {
        HStack {
            switch manager.state {
            case .idle:
                Image(systemName: "circle.dashed").foregroundColor(.gray)
                Text("未连接")
            case .connecting:
                ProgressView()
                Text("正在连接…")
            case .connected:
                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                VStack(alignment: .leading) {
                    Text("已连接")
                    if !manager.cameraModel.isEmpty {
                        Text("\(manager.cameraModel) · 电量 \(manager.batteryLevel)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            case .failed(let msg):
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                Text(msg).lineLimit(3)
            }
            Spacer()
            if manager.state == .connected {
                Button("断开") {
                    manager.disconnect()
                }
            }
        }
    }

    private func connectManual() {
        let ip = manualIP.trimmingCharacters(in: .whitespaces)
        guard !ip.isEmpty else { return }
        manager.connect(to: .manual(ip: ip))
    }

    private func autoJoin() {
        let ssid = cameraSSID.trimmingCharacters(in: .whitespaces)
        guard !ssid.isEmpty else { return }
        WifiJoiner.join(ssid: ssid, password: cameraPassword.isEmpty ? nil : cameraPassword) { _, error in
            if let error {
                print("自动加入失败: \(error.localizedDescription)")
            }
        }
    }
}
