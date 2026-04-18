// Sources/Wrangler/Models/ActionShortcut.swift
//
// Binds a WranglerAction to an optional KeyCombo with
// an enable/disable toggle. The shortcuts list in config
// has one entry per action.

import Foundation

struct ActionShortcut: Codable, Identifiable, Equatable {
    let action: WranglerAction
    var keyCombo: KeyCombo?
    var enabled: Bool

    var id: String { action.rawValue }
}
