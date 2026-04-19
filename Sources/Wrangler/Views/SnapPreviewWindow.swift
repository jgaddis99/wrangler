// Sources/Wrangler/Views/SnapPreviewWindow.swift
//
// A transparent borderless window that shows a semi-transparent
// rectangle on the actual display during grid overlay drag.
// Provides visual feedback of exactly where the window will land.

import AppKit

final class SnapPreviewWindow: NSWindow {

    init() {
        super.init(
            contentRect: .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        level = .floating
        ignoresMouseEvents = true
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .stationary]

        let previewView = SnapPreviewView()
        contentView = previewView
    }

    func showPreview(frame: CGRect) {
        // Convert AX coordinates (top-left origin) to NSWindow coordinates (bottom-left origin)
        guard let mainScreen = NSScreen.screens.first else { return }
        let screenHeight = mainScreen.frame.height
        let nsY = screenHeight - frame.origin.y - frame.height
        let nsFrame = NSRect(x: frame.origin.x, y: nsY, width: frame.width, height: frame.height)

        setFrame(nsFrame, display: true)
        orderFront(nil)
    }

    func hidePreview() {
        orderOut(nil)
    }
}

final class SnapPreviewView: NSView {

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.systemBlue.withAlphaComponent(0.2).setFill()
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6)
        path.fill()

        NSColor.systemBlue.withAlphaComponent(0.6).setStroke()
        path.lineWidth = 2
        path.stroke()
    }
}
