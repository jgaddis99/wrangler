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
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        backgroundColor = .clear
        let visualEffect = NSVisualEffectView(frame: .zero)
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.autoresizingMask = [.width, .height]
        contentView = visualEffect
        visualEffect.addSubview(overlayView)
        overlayView.frame = visualEffect.bounds
        overlayView.autoresizingMask = [.width, .height]
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
        orderFront(nil)
    }

    func hideOverlay() {
        orderOut(nil)
    }

    // Dismissed by Escape key or Ctrl+Alt+Space toggle.
    // No resignKey override — it causes recursion crashes with borderless panels.
}
