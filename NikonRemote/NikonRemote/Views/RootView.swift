import SwiftUI

struct RootView: View {
    @EnvironmentObject private var manager: CameraManager

    var body: some View {
        TabView {
            ConnectionView()
                .tabItem { Label("连接", systemImage: "antenna.radiowaves.left.and.right") }
            RemoteView()
                .tabItem { Label("遥控", systemImage: "camera") }
            TransferView()
                .tabItem { Label("传输", systemImage: "arrow.down.circle") }
        }
    }
}
