import SwiftUI

@main
struct BetterSleepWatchApp: App {
    @WKExtensionDelegateAdaptor(ExtensionDelegate.self) var extensionDelegate
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                WatchAppView()
            }
        }
    }
}