import SwiftUI

@main
struct LifeWallApp: App {
    @StateObject private var store = WallStore()

    init() {
        // 照片说明用的手写楷体是系统可下载字体，第一次启动时在后台下载
        FontLoader.loadHandwriting()
    }

    var body: some Scene {
        WindowGroup {
            WallView()
                .environmentObject(store)
        }
    }
}
