// Sources/Wrangler/Views/GridOverlayView.swift
//
// Custom NSView that draws scaled display previews with grid lines.
// Handles mouse drag to select grid zones. Maps panel coordinates
// back to real display IDs and grid positions.

import AppKit

protocol GridOverlayViewDelegate: AnyObject {
    func gridOverlayView(_ view: GridOverlayView, didSelectZone position: GridPosition, onDisplay displayID: UInt32)
    func gridOverlayView(_ view: GridOverlayView, didRightClickZone position: GridPosition, onDisplay displayID: UInt32)
    func gridOverlayView(_ view: GridOverlayView, dragUpdated position: GridPosition, onDisplay displayID: UInt32)
    func gridOverlayViewDragEnded(_ view: GridOverlayView)
}

final class GridOverlayView: NSView {

    weak var delegate: GridOverlayViewDelegate?

    private var displays: [DisplayDetector.DetectedDisplay] = []
    private var configs: [DisplayConfig] = []
    private var displayRects: [(displayID: UInt32, rect: NSRect, columns: Int, rows: Int)] = []

    // Drag state
    private var isDragging = false
    private var isRightClick = false
    private var isShiftDrag = false
    private var dragDisplayID: UInt32?
    private var dragStartCell: (col: Int, row: Int)?
    private var dragCurrentCell: (col: Int, row: Int)?

    private let padding: CGFloat = 20
    private let displayGap: CGFloat = 10

    static let maxPanelWidth: CGFloat = 800
    static let headerHeight: CGFloat = 40

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

            // No Y-inversion needed since isFlipped handles top-left origin
            let rect = NSRect(
                x: offsetX + (display.frame.origin.x - minX) * scale,
                y: offsetY + (display.frame.origin.y - minY) * scale,
                width: display.frame.width * scale,
                height: display.frame.height * scale
            )
            displayRects.append((displayID: display.id, rect: rect, columns: columns, rows: rows))
        }
    }

    override func layout() {
        super.layout()
        recalculateLayout()
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
        let point = NSPoint(x: (rect.width - textSize.width) / 2, y: rect.origin.y + (rect.height - textSize.height) / 2)
        str.draw(at: point)
    }

    private func drawDisplay(_ entry: (displayID: UInt32, rect: NSRect, columns: Int, rows: Int)) {
        let rect = entry.rect

        // Display background
        NSColor(white: 0.15, alpha: 1.0).setFill()
        let bgPath = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
        bgPath.fill()

        // Display border
        NSColor(white: 0.3, alpha: 1.0).setStroke()
        bgPath.lineWidth = 1
        bgPath.stroke()

        // Grid cells
        let cellW = rect.width / CGFloat(entry.columns)
        let cellH = rect.height / CGFloat(entry.rows)

        // Draw grid lines
        NSColor(white: 0.35, alpha: 1.0).setStroke()
        for col in 1..<entry.columns {
            let x = rect.origin.x + CGFloat(col) * cellW
            let path = NSBezierPath()
            path.move(to: NSPoint(x: x, y: rect.origin.y))
            path.line(to: NSPoint(x: x, y: rect.maxY))
            path.lineWidth = 0.5
            path.stroke()
        }
        for row in 1..<entry.rows {
            let y = rect.origin.y + CGFloat(row) * cellH
            let path = NSBezierPath()
            path.move(to: NSPoint(x: rect.origin.x, y: y))
            path.line(to: NSPoint(x: rect.maxX, y: y))
            path.lineWidth = 0.5
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
            NSColor.systemBlue.withAlphaComponent(0.3).setFill()
            let selPath = NSBezierPath(roundedRect: selRect, xRadius: 2, yRadius: 2)
            selPath.fill()
            NSColor.systemBlue.withAlphaComponent(0.7).setStroke()
            selPath.lineWidth = 2
            selPath.stroke()
        }
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        isShiftDrag = event.modifierFlags.contains(.shift)
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
