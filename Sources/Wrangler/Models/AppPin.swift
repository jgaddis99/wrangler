// Sources/Wrangler/Models/AppPin.swift
//
// Pins an application to a specific grid zone on a specific display.
// When the user triggers "Reset All Pins", every pinned app's windows
// move to their designated zone.

import Foundation

struct AppPin: Codable, Identifiable, Equatable {
    let id: UUID
    var bundleID: String          // e.g., "com.tinyspeck.slackmacgap"
    var appName: String           // e.g., "Slack"
    var displayID: UInt32
    var displayName: String       // fallback for display ID changes
    var column: Int
    var row: Int
    var columnSpan: Int
    var rowSpan: Int

    init(
        id: UUID = UUID(),
        bundleID: String,
        appName: String,
        displayID: UInt32,
        displayName: String,
        column: Int,
        row: Int,
        columnSpan: Int,
        rowSpan: Int
    ) {
        self.id = id
        self.bundleID = bundleID
        self.appName = appName
        self.displayID = displayID
        self.displayName = displayName
        self.column = column
        self.row = row
        self.columnSpan = max(1, columnSpan)
        self.rowSpan = max(1, rowSpan)
    }

    var gridPosition: GridPosition {
        GridPosition(column: column, row: row, columnSpan: columnSpan, rowSpan: rowSpan)
    }
}
