#!/usr/bin/env swift
// Generates Wrangler app icon PNGs at required sizes.
// Draws a cowboy rope/lasso wrapping around a window grid.

import AppKit

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let s = size  // shorthand
    let margin = s * 0.06

    // Background: deep purple gradient rounded rect
    let bgRect = CGRect(x: margin, y: margin, width: s - margin * 2, height: s - margin * 2)
    let cornerRadius = s * 0.22
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    // Gradient
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let colors = [
        CGColor(red: 0.18, green: 0.10, blue: 0.42, alpha: 1.0),  // Deep purple top
        CGColor(red: 0.10, green: 0.06, blue: 0.24, alpha: 1.0),  // Darker purple bottom
    ]
    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0, 1])!
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()
    ctx.drawLinearGradient(gradient, start: CGPoint(x: s/2, y: s - margin), end: CGPoint(x: s/2, y: margin), options: [])
    ctx.restoreGState()

    // Grid: 3 columns x 2 rows of subtle cells
    let gridLeft = s * 0.16
    let gridTop = s * 0.22
    let gridRight = s * 0.84
    let gridBottom = s * 0.78
    let gridW = gridRight - gridLeft
    let gridH = gridBottom - gridTop
    let cols = 3
    let rows = 2
    let cellW = gridW / CGFloat(cols)
    let cellH = gridH / CGFloat(rows)
    let cellGap = s * 0.012

    // Draw grid cells
    for col in 0..<cols {
        for row in 0..<rows {
            let x = gridLeft + CGFloat(col) * cellW + cellGap
            let y = gridTop + CGFloat(row) * cellH + cellGap
            let w = cellW - cellGap * 2
            let h = cellH - cellGap * 2
            let cellRect = CGRect(x: x, y: y, width: w, height: h)
            let cellPath = CGPath(roundedRect: cellRect, cornerWidth: s * 0.015, cornerHeight: s * 0.015, transform: nil)

            // Cell fill
            ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.08))
            ctx.addPath(cellPath)
            ctx.fillPath()

            // Cell border
            ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.15))
            ctx.setLineWidth(s * 0.004)
            ctx.addPath(cellPath)
            ctx.strokePath()
        }
    }

    // Highlight one cell (center-left) with accent color
    let hlCol = 0
    let hlRow = 0
    let hlX = gridLeft + CGFloat(hlCol) * cellW + cellGap
    let hlY = gridTop + CGFloat(hlRow) * cellH + cellGap
    let hlW = cellW * 2 - cellGap * 2  // Span 2 columns
    let hlH = cellH - cellGap * 2
    let hlRect = CGRect(x: hlX, y: hlY, width: hlW, height: hlH)
    let hlPath = CGPath(roundedRect: hlRect, cornerWidth: s * 0.02, cornerHeight: s * 0.02, transform: nil)
    ctx.setFillColor(CGColor(red: 0.29, green: 0.56, blue: 0.85, alpha: 0.35))
    ctx.addPath(hlPath)
    ctx.fillPath()
    ctx.setStrokeColor(CGColor(red: 0.29, green: 0.56, blue: 0.85, alpha: 0.7))
    ctx.setLineWidth(s * 0.006)
    ctx.addPath(hlPath)
    ctx.strokePath()

    // Lasso rope: golden/tan colored loop swirling around the grid
    let ropeColor = CGColor(red: 0.85, green: 0.68, blue: 0.30, alpha: 1.0)
    let ropeWidth = s * 0.022

    ctx.setStrokeColor(ropeColor)
    ctx.setLineWidth(ropeWidth)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)

    // Main lasso loop — an oval/loop shape that wraps around the grid
    let ropePath = CGMutablePath()
    // Start from top-right, loop around
    ropePath.move(to: CGPoint(x: s * 0.82, y: s * 0.18))
    ropePath.addCurve(
        to: CGPoint(x: s * 0.88, y: s * 0.50),
        control1: CGPoint(x: s * 0.92, y: s * 0.25),
        control2: CGPoint(x: s * 0.94, y: s * 0.40)
    )
    ropePath.addCurve(
        to: CGPoint(x: s * 0.70, y: s * 0.82),
        control1: CGPoint(x: s * 0.86, y: s * 0.65),
        control2: CGPoint(x: s * 0.80, y: s * 0.78)
    )
    ropePath.addCurve(
        to: CGPoint(x: s * 0.30, y: s * 0.82),
        control1: CGPoint(x: s * 0.58, y: s * 0.88),
        control2: CGPoint(x: s * 0.42, y: s * 0.88)
    )
    ropePath.addCurve(
        to: CGPoint(x: s * 0.14, y: s * 0.55),
        control1: CGPoint(x: s * 0.18, y: s * 0.78),
        control2: CGPoint(x: s * 0.12, y: s * 0.68)
    )
    ropePath.addCurve(
        to: CGPoint(x: s * 0.35, y: s * 0.22),
        control1: CGPoint(x: s * 0.16, y: s * 0.40),
        control2: CGPoint(x: s * 0.24, y: s * 0.28)
    )
    ropePath.addCurve(
        to: CGPoint(x: s * 0.65, y: s * 0.20),
        control1: CGPoint(x: s * 0.45, y: s * 0.17),
        control2: CGPoint(x: s * 0.55, y: s * 0.16)
    )
    ropePath.addCurve(
        to: CGPoint(x: s * 0.78, y: s * 0.35),
        control1: CGPoint(x: s * 0.72, y: s * 0.22),
        control2: CGPoint(x: s * 0.76, y: s * 0.28)
    )

    ctx.addPath(ropePath)
    ctx.strokePath()

    // Rope tail going off to top-right
    let tailPath = CGMutablePath()
    tailPath.move(to: CGPoint(x: s * 0.82, y: s * 0.18))
    tailPath.addCurve(
        to: CGPoint(x: s * 0.90, y: s * 0.08),
        control1: CGPoint(x: s * 0.85, y: s * 0.14),
        control2: CGPoint(x: s * 0.88, y: s * 0.10)
    )
    ctx.addPath(tailPath)
    ctx.strokePath()

    // Small knot/loop at the tail end
    ctx.setLineWidth(ropeWidth * 0.8)
    let knotCenter = CGPoint(x: s * 0.91, y: s * 0.06)
    let knotRadius = s * 0.025
    ctx.addEllipse(in: CGRect(x: knotCenter.x - knotRadius, y: knotCenter.y - knotRadius, width: knotRadius * 2, height: knotRadius * 2))
    ctx.strokePath()

    // Rope highlight for depth
    ctx.setStrokeColor(CGColor(red: 0.95, green: 0.85, blue: 0.55, alpha: 0.4))
    ctx.setLineWidth(ropeWidth * 0.4)
    let highlightPath = CGMutablePath()
    highlightPath.move(to: CGPoint(x: s * 0.84, y: s * 0.20))
    highlightPath.addCurve(
        to: CGPoint(x: s * 0.87, y: s * 0.40),
        control1: CGPoint(x: s * 0.90, y: s * 0.26),
        control2: CGPoint(x: s * 0.91, y: s * 0.34)
    )
    ctx.addPath(highlightPath)
    ctx.strokePath()

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

// Generate at all required sizes
let icon = drawIcon(size: 1024)
let basePath = "Sources/Wrangler/Resources/Assets.xcassets/AppIcon.appiconset"

savePNG(icon, to: "\(basePath)/icon_128.png", size: 128)
savePNG(icon, to: "\(basePath)/icon_256.png", size: 256)
savePNG(icon, to: "\(basePath)/icon_512.png", size: 512)
savePNG(icon, to: "\(basePath)/icon_1024.png", size: 1024)

// Update Contents.json
let contentsJSON = """
{
  "images" : [
    { "filename" : "icon_128.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_256.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_512.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_1024.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
"""
try! contentsJSON.write(toFile: "\(basePath)/Contents.json", atomically: true, encoding: .utf8)
print("Updated Contents.json")
print("Done! Rebuild to see the new icon.")
