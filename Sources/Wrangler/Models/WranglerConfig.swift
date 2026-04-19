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
    var overlayShortcut: KeyCombo? = KeyCombo(keyCode: 0x31, control: true, option: true, shift: false, command: false) // Ctrl+Alt+Space
    var autoShowOverlay: Bool = true
    var showLivePreview: Bool = true
    var autoHideOverlayDelay: Double = 3.0
}

struct WranglerConfig: Codable, Equatable {
    var general: GeneralConfig = GeneralConfig()
    var displays: [DisplayConfig] = []
    var customZones: [CustomZone] = []
    // Default shortcuts use Ctrl+Alt (⌃⌥) as the base modifier for cross-keyboard compat.
    // Quarters use UIJK keys which form a spatial 2x2 grid on the keyboard: U I / J K
    // Display switching uses Ctrl+Cmd (⌃⌘) = Ctrl+Win on Windows keyboards.
    var shortcuts: [ActionShortcut] = [
        // Halves: Ctrl+Alt+Arrow (Ctrl+Alt+Arrow on Windows KB)
        ActionShortcut(action: .snapLeft, keyCombo: KeyCombo(keyCode: 0x7B, control: true, option: true, shift: false, command: false), enabled: true),
        ActionShortcut(action: .snapRight, keyCombo: KeyCombo(keyCode: 0x7C, control: true, option: true, shift: false, command: false), enabled: true),
        ActionShortcut(action: .snapTopHalf, keyCombo: KeyCombo(keyCode: 0x7E, control: true, option: true, shift: false, command: false), enabled: true),
        ActionShortcut(action: .snapBottomHalf, keyCombo: KeyCombo(keyCode: 0x7D, control: true, option: true, shift: false, command: false), enabled: true),
        // Quarters: Ctrl+Alt+U/I/J/K (same physical keys on Windows KB)
        ActionShortcut(action: .snapTopLeft, keyCombo: KeyCombo(keyCode: 0x20, control: true, option: true, shift: false, command: false), enabled: true),
        ActionShortcut(action: .snapTopRight, keyCombo: KeyCombo(keyCode: 0x22, control: true, option: true, shift: false, command: false), enabled: true),
        ActionShortcut(action: .snapBottomLeft, keyCombo: KeyCombo(keyCode: 0x26, control: true, option: true, shift: false, command: false), enabled: true),
        ActionShortcut(action: .snapBottomRight, keyCombo: KeyCombo(keyCode: 0x28, control: true, option: true, shift: false, command: false), enabled: true),
        // Actions: Ctrl+Alt+key
        ActionShortcut(action: .maximize, keyCombo: KeyCombo(keyCode: 0x24, control: true, option: true, shift: false, command: false), enabled: true),
        ActionShortcut(action: .center, keyCombo: KeyCombo(keyCode: 0x08, control: true, option: true, shift: false, command: false), enabled: true),
        // Display switching: Ctrl+Cmd+Arrow (Ctrl+Win+Arrow on Windows KB)
        ActionShortcut(action: .nextDisplay, keyCombo: KeyCombo(keyCode: 0x7C, control: true, option: false, shift: false, command: true), enabled: true),
        ActionShortcut(action: .previousDisplay, keyCombo: KeyCombo(keyCode: 0x7B, control: true, option: false, shift: false, command: true), enabled: true),
    ]
}
