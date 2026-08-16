import SwiftUI

struct TransferView: View {
    @EnvironmentObject private var manager: CameraManager

    var body: some View {
        NavigationView {
            List {
                Section {
                    Toggle("自动上传新照片/视频", isOn: $manager.autoDownloadEnabled)
                        .disabled(manager.state != .connected)

                    Button {
                        Task { await manager.downloadAll() }
                    } label: {
                        HStack {
                            Text("立即下载全部文件")
                            Spacer()
                            if manager.isBusy {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(manager.state != .connected || manager.isBusy)
                } header: {
                    Text("传输设置")
                } footer: {
                    Text("自动上传仅在前台有效：拍摄后新文件会以原始格式（NEF/MOV 等）保存到系统相册，不压缩。")
                }

                if manager.transferItems.isEmpty {
                    Section {
                        Text("暂无传输记录")
                            .foregroundColor(.secondary)
                    }
                } else {
                    Section("传输记录") {
                        ForEach(manager.transferItems) { item in
                            TransferRow(item: item)
                        }
                    }
                }
            }
            .navigationTitle("照片传输")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
    }
}

struct TransferRow: View {
    let item: TransferItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.kind == .video ? "video" : "photo")
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.filename)
                    .font(.subheadline)
                    .lineLimit(1)
                Text("\(item.kind.rawValue) · \(ByteCountFormatter.string(fromByteCount: Int64(item.size), countStyle: .file))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            switch item.status {
            case .downloading:
                ProgressView()
            case .saved:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .failed(let msg):
                Text(msg)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .lineLimit(2)
                    .frame(maxWidth: 160, alignment: .trailing)
            }
        }
    }
}
