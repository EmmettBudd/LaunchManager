import AppKit
import SwiftUI

extension Notification.Name {
    static let showAbout = Notification.Name("showAbout")
    static let refreshCurrentModule = Notification.Name("refreshCurrentModule")
    static let openModuleSettings = Notification.Name("openModuleSettings")
}

@main
struct LaunchManagerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 700, minHeight: 450)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(after: .toolbar) {
                Button {
                    NotificationCenter.default.post(name: .refreshCurrentModule, object: nil)
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: .command)
            }
            CommandGroup(replacing: .appSettings) {
                Button("设置…") {
                    NotificationCenter.default.post(name: .openModuleSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(replacing: .appInfo) {
                Button("关于 LaunchManager") {
                    NotificationCenter.default.post(name: .showAbout, object: nil)
                }
            }
            CommandGroup(replacing: .help) {
                Button("LaunchManager 帮助") {
                    if let url = URL(string: "https://www.launchmanager.dev/help") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }
}
