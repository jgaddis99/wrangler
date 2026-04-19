// Sources/Wrangler/Models/CustomZone.swift
//
// A user-defined grid zone on a specific display. Stores the
// grid position (column, row, span) and an optional keyboard
// shortcut binding. Persisted in WranglerConfig.

import Foundation

struct CustomZone: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var displayID: UInt32
    var column: Int
    var row: Int
    var columnSpan: Int
    var rowSpan: Int
    var keyCombo: KeyCombo?

    init(
        id: UUID = UUID(),
        name: String,
        displayID: UInt32,
        column: Int,
        row: Int,
        columnSpan: Int,
        rowSpan: Int,
        keyCombo: KeyCombo? = nil
    ) {
        self.id = id
        self.name = name
        self.displayID = displayID
        self.column = column
        self.row = row
        self.columnSpan = max(1, columnSpan)
        self.rowSpan = max(1, rowSpan)
        self.keyCombo = keyCombo
    }

    var gridPosition: GridPosition {
        GridPosition(column: column, row: row, columnSpan: columnSpan, rowSpan: rowSpan)
    }
}
