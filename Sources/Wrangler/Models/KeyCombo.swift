// Sources/Wrangler/Models/KeyCombo.swift
//
// Represents a keyboard shortcut as a key code plus modifier flags.
// Provides human-readable display strings using standard macOS
// modifier symbols and key name lookup from Carbon key codes.

import CoreGraphics
import Foundation

struct KeyCombo: Codable, Equatable, Hashable {
    let keyCode: UInt16
    let control: Bool
    let option: Bool
    let shift: Bool
    let command: Bool

    var modifierFlags: CGEventFlags {
        var flags = CGEventFlags()
        if control { flags.insert(.maskControl) }
        if option { flags.insert(.maskAlternate) }
        if shift { flags.insert(.maskShift) }
        if command { flags.insert(.maskCommand) }
        return flags
    }

    var displayString: String {
        var parts: [String] = []
        if control { parts.append("\u{2303}") }
        if option { parts.append("\u{2325}") }
        if shift { parts.append("\u{21E7}") }
        if command { parts.append("\u{2318}") }
        parts.append(Self.keyName(for: keyCode))
        return parts.joined()
    }

    func matches(keyCode: UInt16, flags: CGEventFlags) -> Bool {
        guard self.keyCode == keyCode else { return false }
        let relevantMask: CGEventFlags = [.maskControl, .maskAlternate, .maskShift, .maskCommand]
        let incomingModifiers = flags.intersection(relevantMask)
        return incomingModifiers == modifierFlags.intersection(relevantMask)
    }

    static func keyName(for keyCode: UInt16) -> String {
        switch keyCode {
        case 0x00: return "A"
        case 0x01: return "S"
        case 0x02: return "D"
        case 0x03: return "F"
        case 0x04: return "H"
        case 0x05: return "G"
        case 0x06: return "Z"
        case 0x07: return "X"
        case 0x08: return "C"
        case 0x09: return "V"
        case 0x0B: return "B"
        case 0x0C: return "Q"
        case 0x0D: return "W"
        case 0x0E: return "E"
        case 0x0F: return "R"
        case 0x10: return "Y"
        case 0x11: return "T"
        case 0x12: return "1"
        case 0x13: return "2"
        case 0x14: return "3"
        case 0x15: return "4"
        case 0x17: return "5"
        case 0x16: return "6"
        case 0x1A: return "7"
        case 0x1C: return "8"
        case 0x19: return "9"
        case 0x1D: return "0"
        case 0x1E: return "]"
        case 0x1F: return "O"
        case 0x20: return "U"
        case 0x21: return "["
        case 0x22: return "I"
        case 0x23: return "P"
        case 0x25: return "L"
        case 0x26: return "J"
        case 0x28: return "K"
        case 0x2C: return "/"
        case 0x2D: return "N"
        case 0x2E: return "M"
        case 0x24: return "\u{21A9}"
        case 0x30: return "\u{21E5}"
        case 0x31: return "Space"
        case 0x33: return "\u{232B}"
        case 0x35: return "\u{238B}"
        case 0x7B: return "\u{2190}"
        case 0x7C: return "\u{2192}"
        case 0x7D: return "\u{2193}"
        case 0x7E: return "\u{2191}"
        case 0x72: return "Help"
        case 0x73: return "Home"
        case 0x74: return "\u{21DE}"
        case 0x75: return "\u{2326}"
        case 0x77: return "End"
        case 0x79: return "\u{21DF}"
        case 0x60: return "F5"
        case 0x61: return "F6"
        case 0x62: return "F7"
        case 0x63: return "F3"
        case 0x64: return "F8"
        case 0x65: return "F9"
        case 0x67: return "F11"
        case 0x69: return "F13"
        case 0x6B: return "F14"
        case 0x6D: return "F10"
        case 0x6F: return "F12"
        case 0x71: return "F15"
        case 0x76: return "F4"
        case 0x78: return "F2"
        case 0x7A: return "F1"
        default: return "Key(\(keyCode))"
        }
    }
}
