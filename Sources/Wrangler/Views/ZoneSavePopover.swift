// Sources/Wrangler/Views/ZoneSavePopover.swift
//
// A small floating panel for naming a custom zone and assigning
// a keyboard shortcut. Appears after right-click-drag or
// Shift+drag on the grid overlay. Full implementation in a later task.

import AppKit

final class ZoneSavePopover {

    typealias SaveHandler = (String, KeyCombo?) -> Void

    static func show(
        relativeTo point: NSPoint,
        displayName: String,
        gridSummary: String,
        onSave: @escaping SaveHandler
    ) {
        // Stub — full implementation coming in Task 5
        wranglerLog("Wrangler: ZoneSavePopover show (stub)")
    }
}
