// Sources/Wrangler/Models/GridPosition.swift
//
// Represents a window's position within a display grid.
// Supports spanning multiple columns and rows for zones
// like "left half" (2 columns on a 4-column grid).

import Foundation

struct GridPosition: Equatable {
    let column: Int
    let row: Int
    let columnSpan: Int
    let rowSpan: Int

    init(column: Int, row: Int, columnSpan: Int = 1, rowSpan: Int = 1) {
        self.column = column
        self.row = row
        self.columnSpan = max(1, columnSpan)
        self.rowSpan = max(1, rowSpan)
    }
}
