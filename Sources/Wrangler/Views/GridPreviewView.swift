// Sources/Wrangler/Views/GridPreviewView.swift
//
// Visual preview of a display's grid layout with the actual desktop
// wallpaper as background, matching the appearance of the grid overlay.
// Falls back to a dark gradient when the wallpaper is unavailable.

import AppKit
import SwiftUI

struct GridPreviewView: View {
    let columns: Int
    let rows: Int
    let gap: Int
    let displaySize: CGSize
    let displayID: UInt32

    private let previewWidth: CGFloat = 220

    var body: some View {
        let aspectRatio = displaySize.height / displaySize.width
        let previewHeight = previewWidth * aspectRatio

        GridPreviewRepresentable(
            columns: columns,
            rows: rows,
            gap: gap,
            displaySize: displaySize,
            displayID: displayID,
            previewWidth: previewWidth,
            previewHeight: previewHeight
        )
        .frame(width: previewWidth, height: previewHeight)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
    }
}

// MARK: - NSView-backed preview for wallpaper drawing

private struct GridPreviewRepresentable: NSViewRepresentable {
    let columns: Int
    let rows: Int
    let gap: Int
    let displaySize: CGSize
    let displayID: UInt32
    let previewWidth: CGFloat
    let previewHeight: CGFloat

    func makeNSView(context: Context) -> GridPreviewNSView {
        let view = GridPreviewNSView()
        view.update(
            columns: columns, rows: rows, gap: gap,
            displaySize: displaySize, displayID: displayID,
            previewWidth: previewWidth, previewHeight: previewHeight
        )
        return view
    }

    func updateNSView(_ nsView: GridPreviewNSView, context: Context) {
        nsView.update(
            columns: columns, rows: rows, gap: gap,
            displaySize: displaySize, displayID: displayID,
            previewWidth: previewWidth, previewHeight: previewHeight
        )
    }
}

final class GridPreviewNSView: NSView {
    private var columns: Int = 4
    private var rows: Int = 4
    private var gap: Int = 0
    private var displaySize: CGSize = .zero
    private var displayID: UInt32 = 0
    private var previewWidth: CGFloat = 220
    private var previewHeight: CGFloat = 140

    func update(columns: Int, rows: Int, gap: Int,
                displaySize: CGSize, displayID: UInt32,
                previewWidth: CGFloat, previewHeight: CGFloat) {
        self.columns = columns
        self.rows = rows
        self.gap = gap
        self.displaySize = displaySize
        self.displayID = displayID
        self.previewWidth = previewWidth
        self.previewHeight = previewHeight
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let rect = bounds

        // Draw wallpaper background (matching GridOverlayView behavior)
        var drewWallpaper = false
        if let screen = NSScreen.screens.first(where: { $0.displayID == displayID }) {
            if let wallpaperURL = NSWorkspace.shared.desktopImageURL(for: screen),
               let image = NSImage(contentsOf: wallpaperURL) {
                image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 0.7)
                // Slight dark overlay for contrast with grid lines
                NSColor(white: 0, alpha: 0.15).setFill()
                NSBezierPath(rect: rect).fill()
                drewWallpaper = true
            }
        }

        if !drewWallpaper {
            // Fallback gradient
            let gradient = NSGradient(
                starting: NSColor(white: 0.18, alpha: 1.0),
                ending: NSColor(white: 0.12, alpha: 1.0)
            )
            gradient?.draw(in: rect, angle: -90)
        }

        // Draw grid lines (dashed, matching the overlay style)
        let cellW = rect.width / CGFloat(columns)
        let cellH = rect.height / CGFloat(rows)

        NSColor.white.withAlphaComponent(0.2).setStroke()
        for col in 1..<columns {
            let x = CGFloat(col) * cellW
            let path = NSBezierPath()
            path.move(to: NSPoint(x: x, y: 0))
            path.line(to: NSPoint(x: x, y: rect.height))
            path.lineWidth = 1.0
            path.setLineDash([3, 3], count: 2, phase: 0)
            path.stroke()
        }
        for row in 1..<rows {
            let y = CGFloat(row) * cellH
            let path = NSBezierPath()
            path.move(to: NSPoint(x: 0, y: y))
            path.line(to: NSPoint(x: rect.width, y: y))
            path.lineWidth = 1.0
            path.setLineDash([3, 3], count: 2, phase: 0)
            path.stroke()
        }

        // Draw cell highlight fill for a subtle grid effect
        let gapF = CGFloat(gap) * (previewWidth / displaySize.width)
        let totalGapX = gapF * CGFloat(columns - 1)
        let totalGapY = gapF * CGFloat(rows - 1)
        let gappedCellW = (rect.width - totalGapX) / CGFloat(columns)
        let gappedCellH = (rect.height - totalGapY) / CGFloat(rows)

        if gap > 0 {
            for col in 0..<columns {
                for row in 0..<rows {
                    let x = CGFloat(col) * (gappedCellW + gapF)
                    let y = CGFloat(row) * (gappedCellH + gapF)
                    let cellRect = NSRect(x: x, y: y, width: gappedCellW, height: gappedCellH)
                    let cellPath = NSBezierPath(roundedRect: cellRect, xRadius: 2, yRadius: 2)
                    NSColor.white.withAlphaComponent(0.06).setFill()
                    cellPath.fill()
                }
            }
        }

        // Grid label at bottom-center
        let label = "\(columns)\u{00D7}\(rows)"
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white.withAlphaComponent(0.7),
            .font: NSFont.systemFont(ofSize: 10, weight: .medium),
        ]
        let str = NSAttributedString(string: label, attributes: attrs)
        let strSize = str.size()
        let labelBg = NSRect(
            x: (rect.width - strSize.width) / 2 - 4,
            y: 4,
            width: strSize.width + 8,
            height: strSize.height + 4
        )
        NSColor(white: 0, alpha: 0.5).setFill()
        NSBezierPath(roundedRect: labelBg, xRadius: 3, yRadius: 3).fill()
        str.draw(at: NSPoint(x: (rect.width - strSize.width) / 2, y: 6))
    }
}
