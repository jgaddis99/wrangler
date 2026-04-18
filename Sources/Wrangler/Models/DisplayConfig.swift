// Sources/Wrangler/Models/DisplayConfig.swift
//
// Per-display configuration defining the grid layout.
// Each connected display gets its own column/row count
// and gap setting. Identified by CGDirectDisplayID.

import Foundation

struct DisplayConfig: Codable, Identifiable, Equatable {
    let displayID: UInt32
    var name: String
    var columns: Int
    var rows: Int
    var gap: Int

    var id: UInt32 { displayID }

    init(displayID: UInt32, name: String, columns: Int = 4, rows: Int = 4, gap: Int = 0) {
        self.displayID = displayID
        self.name = name
        self.columns = max(1, columns)
        self.rows = max(1, rows)
        self.gap = max(0, gap)
    }
}
