// Sources/Wrangler/Views/GridOverlayPanel.swift
//
// Non-activating floating NSPanel that hosts the GridOverlayView.
// Does not steal focus from the window being snapped. Shows all
// connected displays with grid overlays for click-drag zone selection.

import AppKit

final class GridOverlayPanel: NSPanel {

    let overlayView: GridOverlayView

    init(displays: [DisplayDetector.DetectedDisplay], configs: [DisplayConfig]) {
        overlayView = GridOverlayView(displays: displays, configs: configs)

        // Calculate panel size from display arrangement
        let panelSize = GridOverlayView.calculatePanelSize(for: displays)

        super.init(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        title = ""
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        isFloatingPanel = true
        level = .floating
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        backgroundColor = NSColor(white: 0.1, alpha: 0.95)

        contentView = overlayView
        center()
    }

    func updateDisplays(_ displays: [DisplayDetector.DetectedDisplay], configs: [DisplayConfig]) {
        overlayView.updateDisplays(displays, configs: configs)
        let panelSize = GridOverlayView.calculatePanelSize(for: displays)
        setContentSize(panelSize)
    }

    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 0x35 { // Escape
            hideOverlay()
        } else {
            super.keyDown(with: event)
        }
    }

    func showOverlay() {
        overlayView.clearSelection()
        // ARCHITECT FIX: Do NOT call NSApp.activate() — it defeats non-activating panel behavior.
        // The panel should float without stealing focus from the window being managed.
        makeKeyAndOrderFront(nil)
    }

    func hideOverlay() {
        orderOut(nil)
    }
}
