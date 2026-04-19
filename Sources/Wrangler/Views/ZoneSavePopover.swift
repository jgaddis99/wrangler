// Sources/Wrangler/Views/ZoneSavePopover.swift
//
// A small floating panel for naming a custom zone and assigning
// a keyboard shortcut. Appears after right-click-drag or
// Shift+drag on the grid overlay.

import AppKit
import SwiftUI

final class ZoneSavePopover {

    typealias SaveHandler = (String, KeyCombo?) -> Void

    static func show(
        relativeTo point: NSPoint,
        displayName: String,
        gridSummary: String,
        onSave: @escaping SaveHandler
    ) {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Save Custom Zone"
        panel.level = .floating
        panel.isFloatingPanel = true

        let view = ZoneSaveView(
            displayName: displayName,
            gridSummary: gridSummary,
            onSave: { name, combo in
                onSave(name, combo)
                panel.close()
            },
            onCancel: {
                panel.close()
            }
        )
        panel.contentView = NSHostingView(rootView: view)
        panel.setFrameOrigin(NSPoint(x: point.x - 150, y: point.y - 180))
        panel.makeKeyAndOrderFront(nil)
    }
}

struct ZoneSaveView: View {
    let displayName: String
    let gridSummary: String
    let onSave: (String, KeyCombo?) -> Void
    let onCancel: () -> Void

    @State private var zoneName: String = ""
    @State private var keyCombo: KeyCombo?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(displayName) — \(gridSummary)")
                .font(.caption)
                .foregroundColor(.secondary)

            TextField("e.g., Code Editor Left", text: $zoneName)
                .textFieldStyle(.roundedBorder)

            HStack {
                Text("Shortcut:")
                    .fontWeight(.medium)
                ShortcutRecorderView(keyCombo: $keyCombo)
                    .frame(width: 140)
            }

            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { onSave(zoneName, keyCombo) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(zoneName.isEmpty)
            }
        }
        .padding()
        .frame(width: 280)
    }
}
