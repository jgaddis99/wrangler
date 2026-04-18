// Sources/Wrangler/Models/WranglerConfig.swift
//
// Top-level configuration model for the Wrangler app.
// Contains general settings, per-display grid configs,
// and action-to-shortcut bindings. Serialized as JSON.

import Foundation

enum WindowTarget: String, Codable {
    case frontMost
    case underCursor
}

struct GeneralConfig: Codable, Equatable {
    var launchAtLogin: Bool = false
    var windowTarget: WindowTarget = .frontMost
    var globalShortcut: KeyCombo? = nil
    var hideMenuBarIcon: Bool = false
}

struct WranglerConfig: Codable, Equatable {
    var general: GeneralConfig = GeneralConfig()
    var displays: [DisplayConfig] = []
    var shortcuts: [ActionShortcut] = WranglerAction.allCases.map {
        ActionShortcut(action: $0, keyCombo: nil, enabled: true)
    }
}
