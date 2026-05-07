import SwiftUI

@main
struct LegadoReaderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(BookStore())
                .environmentObject(SourceStore())
                .environmentObject(ReaderSettings())
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // 配置数据库
        DatabaseManager.shared.setup()
        return true
    }
}
