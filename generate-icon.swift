#!/usr/bin/env swift
// Generates Wrangler app icon — grid cells being pulled into formation.
// Concept: scattered/messy cells on the left morphing into an organized
// grid on the right, representing windows being "wrangled" into order.

import AppKit

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let s = size
    let margin = s * 0.06

    // Background: deep teal/dark gradient rounded rect
    let bgRect = CGRect(x: margin, y: margin, width: s - margin * 2, height: s - margin * 2)
    let cornerRadius = s * 0.22
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let colors = [
        CGColor(red: 0.08, green: 0.16, blue: 0.24, alpha: 1.0),  // Dark teal top
        CGColor(red: 0.04, green: 0.08, blue: 0.14, alpha: 1.0),  // Darker bottom
    ]
    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0, 1])!
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()
    ctx.drawLinearGradient(gradient, start: CGPoint(x: s/2, y: s - margin), end: CGPoint(x: s/2, y: margin), options: [])
    ctx.restoreGState()

    // The concept: 9 cells in a 3x3 grid, but the left/top ones are scattered
    // and rotated (messy), transitioning to perfectly aligned on the right/bottom.
    // Shows the "wrangling" in progress.

    let gridLeft = s * 0.14
    let gridTop = s * 0.14
    let cellSize = s * 0.22
    let cellGap = s * 0.03
    let cellRadius = s * 0.025

    struct CellInfo {
        let targetCol: Int
        let targetRow: Int
        let offsetX: CGFloat  // displacement from grid position
        let offsetY: CGFloat
        let rotation: CGFloat  // degrees
        let opacity: CGFloat
        let isSettled: Bool    // true = in final position
    }

    // Cells: bottom-right are settled, top-left are scattered
    let cells: [CellInfo] = [
        // Top row: most scattered
        CellInfo(targetCol: 0, targetRow: 0, offsetX: -s*0.06, offsetY: -s*0.08, rotation: -15, opacity: 0.4, isSettled: false),
        CellInfo(targetCol: 1, targetRow: 0, offsetX: s*0.03,  offsetY: -s*0.05, rotation: 8,   opacity: 0.5, isSettled: false),
        CellInfo(targetCol: 2, targetRow: 0, offsetX: s*0.01,  offsetY: -s*0.02, rotation: -3,  opacity: 0.7, isSettled: false),
        // Middle row: partially settled
        CellInfo(targetCol: 0, targetRow: 1, offsetX: -s*0.04, offsetY: s*0.02,  rotation: 10,  opacity: 0.5, isSettled: false),
        CellInfo(targetCol: 1, targetRow: 1, offsetX: 0,        offsetY: 0,        rotation: 0,   opacity: 0.9, isSettled: true),
        CellInfo(targetCol: 2, targetRow: 1, offsetX: 0,        offsetY: 0,        rotation: 0,   opacity: 1.0, isSettled: true),
        // Bottom row: settled
        CellInfo(targetCol: 0, targetRow: 2, offsetX: -s*0.02, offsetY: s*0.01,  rotation: 5,   opacity: 0.7, isSettled: false),
        CellInfo(targetCol: 1, targetRow: 2, offsetX: 0,        offsetY: 0,        rotation: 0,   opacity: 1.0, isSettled: true),
        CellInfo(targetCol: 2, targetRow: 2, offsetX: 0,        offsetY: 0,        rotation: 0,   opacity: 1.0, isSettled: true),
    ]

    // Motion lines / trails for scattered cells
    ctx.setStrokeColor(CGColor(red: 0.3, green: 0.7, blue: 0.9, alpha: 0.15))
    ctx.setLineWidth(s * 0.004)
    ctx.setLineCap(.round)
    for cell in cells where !cell.isSettled {
        let targetX = gridLeft + CGFloat(cell.targetCol) * (cellSize + cellGap) + cellSize / 2
        let targetY = gridTop + CGFloat(cell.targetRow) * (cellSize + cellGap) + cellSize / 2
        let currentX = targetX + cell.offsetX
        let currentY = targetY + cell.offsetY

        // Draw a subtle trail from current to target
        ctx.move(to: CGPoint(x: currentX, y: currentY))
        ctx.addLine(to: CGPoint(x: targetX, y: targetY))
        ctx.strokePath()
    }

    // Draw each cell
    for cell in cells {
        let targetX = gridLeft + CGFloat(cell.targetCol) * (cellSize + cellGap)
        let targetY = gridTop + CGFloat(cell.targetRow) * (cellSize + cellGap)
        let drawX = targetX + cell.offsetX
        let drawY = targetY + cell.offsetY

        ctx.saveGState()

        // Rotate around cell center
        if cell.rotation != 0 {
            let centerX = drawX + cellSize / 2
            let centerY = drawY + cellSize / 2
            ctx.translateBy(x: centerX, y: centerY)
            ctx.rotate(by: cell.rotation * .pi / 180)
            ctx.translateBy(x: -centerX, y: -centerY)
        }

        let cellRect = CGRect(x: drawX, y: drawY, width: cellSize, height: cellSize)
        let cellPath = CGPath(roundedRect: cellRect, cornerWidth: cellRadius, cornerHeight: cellRadius, transform: nil)

        if cell.isSettled {
            // Settled cells: brighter, solid
            ctx.setFillColor(CGColor(red: 0.2, green: 0.55, blue: 0.8, alpha: cell.opacity * 0.4))
            ctx.addPath(cellPath)
            ctx.fillPath()
            ctx.setStrokeColor(CGColor(red: 0.3, green: 0.7, blue: 0.95, alpha: cell.opacity * 0.8))
            ctx.setLineWidth(s * 0.005)
            ctx.addPath(cellPath)
            ctx.strokePath()
        } else {
            // Scattered cells: more transparent, slightly different hue
            ctx.setFillColor(CGColor(red: 0.25, green: 0.45, blue: 0.7, alpha: cell.opacity * 0.25))
            ctx.addPath(cellPath)
            ctx.fillPath()
            ctx.setStrokeColor(CGColor(red: 0.35, green: 0.6, blue: 0.85, alpha: cell.opacity * 0.5))
            ctx.setLineWidth(s * 0.004)
            ctx.addPath(cellPath)
            ctx.strokePath()
        }

        ctx.restoreGState()
    }

    // Accent: small directional arrows showing movement toward grid
    let arrowColor = CGColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 0.5)
    ctx.setStrokeColor(arrowColor)
    ctx.setLineWidth(s * 0.006)
    ctx.setLineCap(.round)

    // Arrow pointing from scattered cell toward its target
    func drawArrow(from: CGPoint, toward: CGPoint, length: CGFloat) {
        let dx = toward.x - from.x
        let dy = toward.y - from.y
        let dist = sqrt(dx * dx + dy * dy)
        guard dist > 0 else { return }
        let nx = dx / dist
        let ny = dy / dist

        let arrowStart = CGPoint(x: from.x + nx * length * 0.2, y: from.y + ny * length * 0.2)
        let arrowEnd = CGPoint(x: from.x + nx * length, y: from.y + ny * length)

        ctx.move(to: arrowStart)
        ctx.addLine(to: arrowEnd)
        ctx.strokePath()

        // Arrowhead
        let headLen = length * 0.3
        let headAngle: CGFloat = 0.5
        let h1 = CGPoint(
            x: arrowEnd.x - headLen * (nx * cos(headAngle) - ny * sin(headAngle)),
            y: arrowEnd.y - headLen * (ny * cos(headAngle) + nx * sin(headAngle))
        )
        let h2 = CGPoint(
            x: arrowEnd.x - headLen * (nx * cos(headAngle) + ny * sin(headAngle)),
            y: arrowEnd.y - headLen * (ny * cos(headAngle) - nx * sin(headAngle))
        )
        ctx.move(to: h1)
        ctx.addLine(to: arrowEnd)
        ctx.addLine(to: h2)
        ctx.strokePath()
    }

    // Draw arrows for the most scattered cells
    for cell in cells where !cell.isSettled && abs(cell.offsetX) + abs(cell.offsetY) > s * 0.04 {
        let targetX = gridLeft + CGFloat(cell.targetCol) * (cellSize + cellGap) + cellSize / 2
        let targetY = gridTop + CGFloat(cell.targetRow) * (cellSize + cellGap) + cellSize / 2
        let currentX = targetX + cell.offsetX
        let currentY = targetY + cell.offsetY
        drawArrow(from: CGPoint(x: currentX, y: currentY), toward: CGPoint(x: targetX, y: targetY), length: s * 0.04)
    }

    image.unlockFocus()
    return image
}

func savePNG(_ image: NSImage, to path: String, size: Int) {
    let resized = NSImage(size: NSSize(width: size, height: size))
    resized.lockFocus()
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    resized.unlockFocus()

    guard let tiff = resized.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to generate PNG for size \(size)")
        return
    }
    try! png.write(to: URL(fileURLWithPath: path))
    print("Wrote \(path) (\(size)x\(size))")
}

let icon = drawIcon(size: 1024)
let basePath = "Sources/Wrangler/Resources/Assets.xcassets/AppIcon.appiconset"

savePNG(icon, to: "\(basePath)/icon_128.png", size: 128)
savePNG(icon, to: "\(basePath)/icon_256.png", size: 256)
savePNG(icon, to: "\(basePath)/icon_512.png", size: 512)
savePNG(icon, to: "\(basePath)/icon_1024.png", size: 1024)
print("Done!")
