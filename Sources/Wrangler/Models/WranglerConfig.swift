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
    var shortcuts: [ActionShortcut] = [
        ActionShortcut(action: .snapLeft, keyCombo: KeyCombo(keyCode: 0x7B, control: true, option: true, shift: false, command: false), enabled: true),     // Ctrl+Opt+←
        ActionShortcut(action: .snapRight, keyCombo: KeyCombo(keyCode: 0x7C, control: true, option: true, shift: false, command: false), enabled: true),    // Ctrl+Opt+→
        ActionShortcut(action: .snapTopHalf, keyCombo: KeyCombo(keyCode: 0x7E, control: true, option: true, shift: false, command: false), enabled: true),  // Ctrl+Opt+↑
        ActionShortcut(action: .snapBottomHalf, keyCombo: KeyCombo(keyCode: 0x7D, control: true, option: true, shift: false, command: false), enabled: true), // Ctrl+Opt+↓
        ActionShortcut(action: .snapTopLeft, keyCombo: KeyCombo(keyCode: 0x7B, control: true, option: true, shift: true, command: false), enabled: true),   // Ctrl+Opt+Shift+←  (top-left like ← + ↑)
        ActionShortcut(action: .snapTopRight, keyCombo: KeyCombo(keyCode: 0x7C, control: true, option: true, shift: true, command: false), enabled: true),  // Ctrl+Opt+Shift+→
        ActionShortcut(action: .snapBottomLeft, keyCombo: KeyCombo(keyCode: 0x7B, control: false, option: true, shift: true, command: true), enabled: true), // Opt+Shift+Cmd+←
        ActionShortcut(action: .snapBottomRight, keyCombo: KeyCombo(keyCode: 0x7C, control: false, option: true, shift: true, command: true), enabled: true), // Opt+Shift+Cmd+→
        ActionShortcut(action: .maximize, keyCombo: KeyCombo(keyCode: 0x24, control: true, option: true, shift: false, command: false), enabled: true),     // Ctrl+Opt+Return
        ActionShortcut(action: .center, keyCombo: KeyCombo(keyCode: 0x08, control: true, option: true, shift: false, command: false), enabled: true),       // Ctrl+Opt+C
        ActionShortcut(action: .nextDisplay, keyCombo: KeyCombo(keyCode: 0x7C, control: true, option: false, shift: false, command: true), enabled: true),  // Ctrl+Cmd+→
        ActionShortcut(action: .previousDisplay, keyCombo: KeyCombo(keyCode: 0x7B, control: true, option: false, shift: false, command: true), enabled: true), // Ctrl+Cmd+←
    ]
}
