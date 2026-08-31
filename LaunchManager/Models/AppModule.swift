import Foundation
import SwiftUI

enum AppModule: String, CaseIterable, Identifiable, Codable, Hashable {
    case agents
    case crontab
    case services
    case loginItems

    var id: String { rawValue }

    var sidebarSelection: SidebarSelection {
        switch self {
        case .agents: return .agents
        case .crontab: return .crontab
        case .services: return .services
        case .loginItems: return .loginItems
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .agents: return "Launch Agents"
        case .crontab: return "Crontab"
        case .services: return "Services"
        case .loginItems: return "Login Items"
        }
    }

    var systemImage: String {
        switch self {
        case .agents: return "list.bullet.rectangle"
        case .crontab: return "clock"
        case .services: return "bolt.fill"
        case .loginItems: return "key.fill"
        }
    }

    var settingsDescription: LocalizedStringKey {
        switch self {
        case .agents: return "扫描 LaunchAgent / LaunchDaemon 与 Homebrew 服务"
        case .crontab: return "扫描用户与系统 Crontab"
        case .services: return "扫描本地监听端口与开发服务"
        case .loginItems: return "说明页 · 跳转系统设置"
        }
    }
}

enum AppLinks {
    static let helpURL = URL(string: "https://www.launchmanager.dev/help")!
}
