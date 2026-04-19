// Sources/Wrangler/Models/HotkeyBinding.swift
//
// Unified binding type for the hotkey listener. Wraps both
// predefined WranglerAction shortcuts and custom zone UUIDs
// so both can be registered in a single binding list. The
// .overlay case triggers the grid overlay panel toggle.

import Foundation

enum HotkeyBinding: Equatable {
    case predefined(WranglerAction)
    case customZone(UUID)
    case overlay
    case resetPins
}
