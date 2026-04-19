// Sources/Wrangler/Views/GridOverlayView.swift
//
// Custom NSView that draws scaled display previews with grid lines.
// Handles mouse drag to select grid zones. Maps panel coordinates
// back to real display IDs and grid positions.

import AppKit

protocol GridOverlayViewDelegate: AnyObject {
    func gridOverlayView(_ view: GridOverlayView, didSelectZone position: GridPosition, onDisplay displayID: UInt32)
    func gridOverlayView(_ view: GridOverlayView, didBatchSelectZone position: GridPosition, onDisplay displayID: UInt32)
    func gridOverlayView(_ view: GridOverlayView, didRightClickZone position: GridPosition, onDisplay displayID: UInt32)
    func gridOverlayView(_ view: GridOverlayView, dragUpdated position: GridPosition, onDisplay displayID: UInt32)
    func gridOverlayViewDragEnded(_ view: GridOverlayView)
    func gridOverlayView(_ view: GridOverlayView, hoveredDisplay displayID: UInt32?)
}

final class GridOverlayView: NSView {

    weak var delegate: GridOverlayViewDelegate?

    private var displays: [DisplayDetector.DetectedDisplay] = []
    private var configs: [DisplayConfig] = []
    private var displayRects: [(displayID: UInt32, name: String, rect: NSRect, columns: Int, rows: Int)] = []

    // Drag state
    private var isDragging = false
    private var isRightClick = false
    private var isShiftDrag = false
    private var isCmdDrag = false
    private var dragDisplayID: UInt32?
    private var dragStartCell: (col: Int, row: Int)?
    private var dragCurrentCell: (col: Int, row: Int)?

    // Hover state
    private var hoveredDisplayID: UInt32?
    private var trackingArea: NSTrackingArea?

    private let padding: CGFloat = 20
    private let displayGap: CGFloat = 10

    static let maxPanelWidth: CGFloat = 800
    static let headerHeight: CGFloat = 55

    // Use top-left origin to match the rest of our coordinate system.
    // This makes hitTestGrid work correctly without manual Y-inversion.
    override var isFlipped: Bool { true }

    init(displays: [DisplayDetector.DetectedDisplay], configs: [DisplayConfig]) {
        super.init(frame: .zero)
        updateDisplays(displays, configs: configs)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    func updateDisplays(_ displays: [DisplayDetector.DetectedDisplay], configs: [DisplayConfig]) {
        self.displays = displays
        self.configs = configs
        recalculateLayout()
        needsDisplay = true
    }

    func clearSelection() {
        isDragging = false
        dragStartCell = nil
        dragCurrentCell = nil
        dragDisplayID = nil
        needsDisplay = true
    }

    // MARK: - Layout

    static func calculatePanelSize(for displays: [DisplayDetector.DetectedDisplay]) -> NSSize {
        guard !displays.isEmpty else { return NSSize(width: 400, height: 300) }

        // Find the bounding box of all displays in real coordinates
        let allFrames = displays.map(\.frame)
        let minX = allFrames.map(\.minX).min()!
        let minY = allFrames.map(\.minY).min()!
        let maxX = allFrames.map(\.maxX).max()!
        let maxY = allFrames.map(\.maxY).max()!

        let totalWidth = maxX - minX
        let totalHeight = maxY - minY
        let aspect = totalHeight / totalWidth

        let panelWidth = min(maxPanelWidth, totalWidth * 0.3)
        let panelHeight = panelWidth * aspect + headerHeight + 40
        return NSSize(width: panelWidth + 40, height: max(panelHeight, 200))
    }

    private func recalculateLayout() {
        displayRects = []
        guard !displays.isEmpty else { return }

        let allFrames = displays.map(\.frame)
        let minX = allFrames.map(\.minX).min()!
        let minY = allFrames.map(\.minY).min()!
        let maxX = allFrames.map(\.maxX).max()!
        let maxY = allFrames.map(\.maxY).max()!

        let totalWidth = maxX - minX
        let totalHeight = maxY - minY

        let availableWidth = bounds.width - padding * 2
        let availableHeight = bounds.height - padding * 2 - Self.headerHeight
        let scale = min(availableWidth / totalWidth, availableHeight / totalHeight)

        let scaledTotalWidth = totalWidth * scale
        let scaledTotalHeight = totalHeight * scale
        let offsetX = padding + (availableWidth - scaledTotalWidth) / 2
        // With isFlipped=true, Y increases downward — header is at top, displays below
        let offsetY = Self.headerHeight + padding + (availableHeight - scaledTotalHeight) / 2

        for display in displays {
            let config = configs.first { $0.displayID == display.id }
            let columns = config?.columns ?? 4
            let rows = config?.rows ?? 4

            // Y-inversion needed: NSScreen puts bottom monitor at y=0, but in our
            // flipped view (top-left origin) we want the top monitor drawn at the top.
            let rect = NSRect(
                x: offsetX + (display.frame.origin.x - minX) * scale,
                y: offsetY + (maxY - display.frame.origin.y - display.frame.height) * scale,
                width: display.frame.width * scale,
                height: display.frame.height * scale
            )
            displayRects.append((displayID: display.id, name: display.name, rect: rect, columns: columns, rows: rows))
        }
    }

    override func layout() {
        super.layout()
        recalculateLayout()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeAlways, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let newHover = hitTestGrid(point)?.displayID
        if newHover != hoveredDisplayID {
            hoveredDisplayID = newHover
            delegate?.gridOverlayView(self, hoveredDisplay: hoveredDisplayID)
            needsDisplay = true
        }
    }

    override func mouseExited(with event: NSEvent) {
        hoveredDisplayID = nil
        delegate?.gridOverlayView(self, hoveredDisplay: nil)
        needsDisplay = true
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Draw header with focused app name (at top of view since isFlipped=true)
        let headerRect = NSRect(x: 0, y: 0, width: bounds.width, height: Self.headerHeight)
        drawHeader(in: headerRect)

        // Draw each display
        for entry in displayRects {
            drawDisplay(entry)
        }
    }

    private func drawHeader(in rect: NSRect) {
        let appName = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white,
            .font: NSFont.systemFont(ofSize: 16, weight: .semibold)
        ]
        let str = NSAttributedString(string: appName, attributes: attrs)
        let textSize = str.size()
        let point = NSPoint(x: (rect.width - textSize.width) / 2, y: rect.origin.y + 8)
        str.draw(at: point)

        let subtitleAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white.withAlphaComponent(0.5),
            .font: NSFont.systemFont(ofSize: 11, weight: .regular)
        ]
        let subtitle = NSAttributedString(string: "Drag to snap  \u{00B7}  \u{2318}+drag to tile all  \u{00B7}  Right-click to save zone", attributes: subtitleAttrs)
        let subtitleSize = subtitle.size()
        let subtitlePoint = NSPoint(x: (rect.width - subtitleSize.width) / 2, y: point.y + textSize.height + 2)
        subtitle.draw(at: subtitlePoint)
    }

    private func drawDisplay(_ entry: (displayID: UInt32, name: String, rect: NSRect, columns: Int, rows: Int)) {
        let rect = entry.rect

        // Try to draw desktop wallpaper as background
        var drewWallpaper = false
        if let screen = NSScreen.screens.first(where: { $0.displayID == entry.displayID }) {
            if let wallpaperURL = NSWorkspace.shared.desktopImageURL(for: screen),
               let image = NSImage(contentsOf: wallpaperURL) {
                // Save graphics state and flip vertically for correct image orientation
                // (isFlipped=true on the view inverts image drawing)
                NSGraphicsContext.saveGraphicsState()
                let transform = NSAffineTransform()
                transform.translateX(by: 0, yBy: rect.origin.y + rect.height)
                transform.scaleX(by: 1, yBy: -1)
                transform.translateX(by: 0, yBy: -rect.origin.y)
                transform.concat()
                image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 0.6)
                NSGraphicsContext.restoreGraphicsState()
                drewWallpaper = true
            }
        }

        // Fallback: dark background
        if !drewWallpaper {
            NSColor(white: 0.15, alpha: 1.0).setFill()
            let bgPath = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
            bgPath.fill()
        }

        // Display border — highlight when hovered
        let isHovered = hoveredDisplayID == entry.displayID
        let borderColor = isHovered ? NSColor.controlAccentColor : NSColor(white: 0.4, alpha: 1.0)
        let borderWidth: CGFloat = isHovered ? 3.0 : 1.5
        borderColor.setStroke()
        let borderPath = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
        borderPath.lineWidth = borderWidth
        borderPath.stroke()

        // Display name label
        let nameAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white.withAlphaComponent(0.8),
            .font: NSFont.systemFont(ofSize: 10, weight: .medium)
        ]
        let nameStr = NSAttributedString(string: entry.name, attributes: nameAttrs)
        let nameSize = nameStr.size()
        // Draw name at bottom-center of the display preview
        let namePoint = NSPoint(
            x: rect.origin.x + (rect.width - nameSize.width) / 2,
            y: rect.maxY - nameSize.height - 4
        )
        // Semi-transparent background behind text for readability
        let labelBg = NSRect(x: namePoint.x - 4, y: namePoint.y - 2, width: nameSize.width + 8, height: nameSize.height + 4)
        NSColor(white: 0, alpha: 0.5).setFill()
        NSBezierPath(roundedRect: labelBg, xRadius: 3, yRadius: 3).fill()
        nameStr.draw(at: namePoint)

        // Grid cells
        let cellW = rect.width / CGFloat(entry.columns)
        let cellH = rect.height / CGFloat(entry.rows)

        // Draw grid lines (dashed)
        NSColor.white.withAlphaComponent(0.12).setStroke()
        for col in 1..<entry.columns {
            let x = rect.origin.x + CGFloat(col) * cellW
            let path = NSBezierPath()
            path.move(to: NSPoint(x: x, y: rect.origin.y))
            path.line(to: NSPoint(x: x, y: rect.maxY))
            path.lineWidth = 1.0
            path.setLineDash([4, 4], count: 2, phase: 0)
            path.stroke()
        }
        for row in 1..<entry.rows {
            let y = rect.origin.y + CGFloat(row) * cellH
            let path = NSBezierPath()
            path.move(to: NSPoint(x: rect.origin.x, y: y))
            path.line(to: NSPoint(x: rect.maxX, y: y))
            path.lineWidth = 1.0
            path.setLineDash([4, 4], count: 2, phase: 0)
            path.stroke()
        }

        // Draw selection highlight
        if let startCell = dragStartCell, let currentCell = dragCurrentCell, dragDisplayID == entry.displayID {
            let minCol = min(startCell.col, currentCell.col)
            let maxCol = max(startCell.col, currentCell.col)
            let minRow = min(startCell.row, currentCell.row)
            let maxRow = max(startCell.row, currentCell.row)

            let selRect = NSRect(
                x: rect.origin.x + CGFloat(minCol) * cellW,
                y: rect.origin.y + CGFloat(minRow) * cellH,
                width: CGFloat(maxCol - minCol + 1) * cellW,
                height: CGFloat(maxRow - minRow + 1) * cellH
            )
            NSColor.controlAccentColor.withAlphaComponent(0.3).setFill()
            let selPath = NSBezierPath(roundedRect: selRect, xRadius: 2, yRadius: 2)
            selPath.fill()
            NSColor.controlAccentColor.withAlphaComponent(0.7).setStroke()
            selPath.lineWidth = 2
            selPath.stroke()
        }
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        isShiftDrag = event.modifierFlags.contains(.shift)
        isCmdDrag = event.modifierFlags.contains(.command)
        isRightClick = false
        startDrag(at: point)
    }

    override func rightMouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        isRightClick = true
        isShiftDrag = false
        startDrag(at: point)
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        updateDrag(at: point)
    }

    override func rightMouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        updateDrag(at: point)
    }

    override func mouseUp(with event: NSEvent) {
        endDrag()
    }

    override func rightMouseUp(with event: NSEvent) {
        endDrag()
    }

    private func startDrag(at point: NSPoint) {
        guard let (displayID, col, row) = hitTestGrid(point) else { return }
        isDragging = true
        dragDisplayID = displayID
        dragStartCell = (col, row)
        dragCurrentCell = (col, row)
        needsDisplay = true
    }

    private func updateDrag(at point: NSPoint) {
        guard isDragging, let displayID = dragDisplayID else { return }

        // Only update if still within the same display
        if let (hitDisplay, col, row) = hitTestGrid(point), hitDisplay == displayID {
            dragCurrentCell = (col, row)

            let position = currentGridPosition()
            if let position = position {
                delegate?.gridOverlayView(self, dragUpdated: position, onDisplay: displayID)
            }
        }
        needsDisplay = true
    }

    private func endDrag() {
        guard isDragging, let displayID = dragDisplayID, let position = currentGridPosition() else {
            clearSelection()
            return
        }

        if isRightClick || isShiftDrag {
            delegate?.gridOverlayView(self, didRightClickZone: position, onDisplay: displayID)
        } else if isCmdDrag {
            delegate?.gridOverlayView(self, didBatchSelectZone: position, onDisplay: displayID)
        } else {
            delegate?.gridOverlayView(self, didSelectZone: position, onDisplay: displayID)
        }

        delegate?.gridOverlayViewDragEnded(self)
        clearSelection()
    }

    private func currentGridPosition() -> GridPosition? {
        guard let start = dragStartCell, let current = dragCurrentCell else { return nil }
        let minCol = min(start.col, current.col)
        let maxCol = max(start.col, current.col)
        let minRow = min(start.row, current.row)
        let maxRow = max(start.row, current.row)
        return GridPosition(
            column: minCol, row: minRow,
            columnSpan: maxCol - minCol + 1,
            rowSpan: maxRow - minRow + 1
        )
    }

    private func hitTestGrid(_ point: NSPoint) -> (displayID: UInt32, col: Int, row: Int)? {
        for entry in displayRects {
            if entry.rect.contains(point) {
                let cellW = entry.rect.width / CGFloat(entry.columns)
                let cellH = entry.rect.height / CGFloat(entry.rows)
                let col = Int((point.x - entry.rect.origin.x) / cellW)
                let row = Int((point.y - entry.rect.origin.y) / cellH)
                let clampedCol = min(max(0, col), entry.columns - 1)
                let clampedRow = min(max(0, row), entry.rows - 1)
                return (entry.displayID, clampedCol, clampedRow)
            }
        }
        return nil
    }
}
