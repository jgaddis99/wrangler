// Sources/Wrangler/Views/SnapPreviewWindow.swift
//
// A transparent borderless window that provides visual feedback
// on the actual display. Supports two modes: filled zone preview
// (during grid drag) and border-only rim highlight (on monitor hover).

import AppKit

enum PreviewStyle {
    case zoneFill    // Semi-transparent blue fill for snap zone preview
    case monitorRim  // Glowing border-only for monitor identification
}

final class SnapPreviewWindow: NSWindow {

    private let previewView = SnapPreviewView()

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

        contentView = previewView
    }

    func showPreview(frame: CGRect, style: PreviewStyle = .zoneFill) {
        previewView.style = style
        // Convert AX coordinates (top-left origin) to NSWindow coordinates (bottom-left origin)
        guard let mainScreen = NSScreen.screens.first else { return }
        let screenHeight = mainScreen.frame.height
        let nsY = screenHeight - frame.origin.y - frame.height
        let nsFrame = NSRect(x: frame.origin.x, y: nsY, width: frame.width, height: frame.height)

        setFrame(nsFrame, display: true)
        previewView.needsDisplay = true
        orderFront(nil)
    }

    func hidePreview() {
        orderOut(nil)
    }
}

final class SnapPreviewView: NSView {

    var style: PreviewStyle = .zoneFill

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        switch style {
        case .zoneFill:
            drawZoneFill()
        case .monitorRim:
            drawMonitorRim()
        }
    }

    private func drawZoneFill() {
        NSColor.controlAccentColor.withAlphaComponent(0.15).setFill()
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6)
        path.fill()

        NSColor.controlAccentColor.withAlphaComponent(0.6).setStroke()
        path.lineWidth = 2
        path.stroke()
    }

    private func drawMonitorRim() {
        // Glowing border around the full monitor edge
        let borderWidth: CGFloat = 4
        let inset = bounds.insetBy(dx: borderWidth / 2, dy: borderWidth / 2)

        // Outer glow
        NSColor.controlAccentColor.withAlphaComponent(0.3).setStroke()
        let glowPath = NSBezierPath(rect: bounds.insetBy(dx: 1, dy: 1))
        glowPath.lineWidth = borderWidth + 4
        glowPath.stroke()

        // Main border
        NSColor.controlAccentColor.withAlphaComponent(0.8).setStroke()
        let borderPath = NSBezierPath(rect: inset)
        borderPath.lineWidth = borderWidth
        borderPath.stroke()

        // Inner subtle glow
        NSColor.controlAccentColor.withAlphaComponent(0.15).setStroke()
        let innerPath = NSBezierPath(rect: bounds.insetBy(dx: borderWidth + 2, dy: borderWidth + 2))
        innerPath.lineWidth = 2
        innerPath.stroke()
    }
}
