import SwiftUI

@main
struct NikonRemoteApp: App {
    @StateObject private var manager = CameraManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(manager)
                .onAppear {
                    PhotoLibrarySaver.requestAuthorization { _ in }
                }
        }
    }
}
