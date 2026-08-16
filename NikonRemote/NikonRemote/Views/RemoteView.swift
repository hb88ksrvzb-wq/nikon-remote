import SwiftUI

struct RemoteView: View {
    @EnvironmentObject private var manager: CameraManager

    var body: some View {
        NavigationView {
            Group {
                if manager.state == .connected {
                    controls
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "camera.badge.ellipsis")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("尚未连接相机")
                            .foregroundColor(.secondary)
                        Text("请先在「连接」页连接尼康相机")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("遥控拍摄")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
    }

    private var controls: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 拍摄按钮区
                VStack(spacing: 16) {
                    ShutterButton {
                        manager.capture()
                    }
                    .disabled(manager.isBusy)

                    Button {
                        manager.toggleMovie()
                    } label: {
                        HStack {
                            Image(systemName: manager.isRecording ? "stop.circle.fill" : "video.fill")
                            Text(manager.isRecording ? "停止录像" : "开始录像")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(manager.isRecording ? Color.red.opacity(0.15) : Color.gray.opacity(0.15))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .disabled(manager.isBusy)
                }

                // 参数区
                if !manager.params.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(manager.params) { param in
                            ParamRow(param: param) { optionID in
                                manager.setParam(param, optionID: optionID)
                            }
                        }
                    }
                } else {
                    Text("未读取到可调参数（请将相机设为 M 手动档）")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                Text("提示：完整手动控制请在相机上使用 M 档")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
}

/// 快门按钮
struct ShutterButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .strokeBorder(Color.accentColor, lineWidth: 6)
                    .frame(width: 88, height: 88)
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 66, height: 66)
                Circle()
                    .fill(Color.white)
                    .frame(width: 8, height: 8)
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

/// 参数行：名称 + 横向可滚动选项
struct ParamRow: View {
    let param: CameraParam
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(param.name)
                .font(.subheadline.weight(.semibold))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(param.options) { option in
                        Button {
                            onSelect(option.id)
                        } label: {
                            Text(option.label)
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(param.selectedID == option.id ? Color.accentColor : Color.gray.opacity(0.12))
                                .foregroundColor(param.selectedID == option.id ? .white : .primary)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
