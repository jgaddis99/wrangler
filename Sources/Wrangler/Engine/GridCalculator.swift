// Sources/Wrangler/Engine/GridCalculator.swift
//
// Pure math for calculating window frames from grid positions.
// Given a display's visible frame, grid dimensions, and a target
// position with optional span, computes the exact CGRect.

import CoreGraphics

enum GridCalculator {

    static func calculateFrame(
        for position: GridPosition,
        in displayFrame: CGRect,
        gridColumns: Int,
        gridRows: Int,
        gap: Int
    ) -> CGRect {
        let gapF = CGFloat(gap)
        let totalGapX = gapF * CGFloat(gridColumns - 1)
        let totalGapY = gapF * CGFloat(gridRows - 1)
        let cellWidth = (displayFrame.width - totalGapX) / CGFloat(gridColumns)
        let cellHeight = (displayFrame.height - totalGapY) / CGFloat(gridRows)

        let x = displayFrame.origin.x + CGFloat(position.column) * (cellWidth + gapF)
        let y = displayFrame.origin.y + CGFloat(position.row) * (cellHeight + gapF)
        let width = cellWidth * CGFloat(position.columnSpan) + gapF * CGFloat(position.columnSpan - 1)
        let height = cellHeight * CGFloat(position.rowSpan) + gapF * CGFloat(position.rowSpan - 1)

        return CGRect(x: x, y: y, width: width, height: height)
    }

    static func gridPosition(
        for action: WranglerAction,
        gridColumns: Int,
        gridRows: Int
    ) -> GridPosition? {
        let halfCols = gridColumns / 2
        let halfRows = gridRows / 2

        switch action {
        case .snapLeft:
            return GridPosition(column: 0, row: 0, columnSpan: halfCols, rowSpan: gridRows)
        case .snapRight:
            return GridPosition(column: halfCols, row: 0, columnSpan: gridColumns - halfCols, rowSpan: gridRows)
        case .snapTopHalf:
            return GridPosition(column: 0, row: 0, columnSpan: gridColumns, rowSpan: halfRows)
        case .snapBottomHalf:
            return GridPosition(column: 0, row: halfRows, columnSpan: gridColumns, rowSpan: gridRows - halfRows)
        case .snapTopLeft:
            return GridPosition(column: 0, row: 0, columnSpan: halfCols, rowSpan: halfRows)
        case .snapTopRight:
            return GridPosition(column: halfCols, row: 0, columnSpan: gridColumns - halfCols, rowSpan: halfRows)
        case .snapBottomLeft:
            return GridPosition(column: 0, row: halfRows, columnSpan: halfCols, rowSpan: gridRows - halfRows)
        case .snapBottomRight:
            return GridPosition(column: halfCols, row: halfRows, columnSpan: gridColumns - halfCols, rowSpan: gridRows - halfRows)
        case .maximize:
            return GridPosition(column: 0, row: 0, columnSpan: gridColumns, rowSpan: gridRows)
        case .center, .nextDisplay, .previousDisplay:
            return nil
        }
    }

    static func centerFrame(windowSize: CGSize, in displayFrame: CGRect) -> CGRect {
        let x = displayFrame.origin.x + (displayFrame.width - windowSize.width) / 2
        let y = displayFrame.origin.y + (displayFrame.height - windowSize.height) / 2
        return CGRect(x: x, y: y, width: windowSize.width, height: windowSize.height)
    }
}
