import AppKit
import ServiceManagement
import SwiftUI

enum LoginItemsSettings {
    static func openSystemSettings() {
        if #available(macOS 13.0, *) {
            SMAppService.openSystemSettingsLoginItems()
        } else if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}

struct LoginItemsGuideView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("登录项仅可在 macOS 系统设置中管理。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                LoginItemsSettings.openSystemSettings()
            } label: {
                Label("打开登录项设置", systemImage: "arrow.up.forward.app")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Login Items")
    }
}
