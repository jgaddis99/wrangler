// Sources/Wrangler/Views/SettingsView.swift
//
// Placeholder for the tabbed settings window.
// Will be replaced with full implementation in Task 11.

import SwiftUI

struct SettingsView: View {
    @ObservedObject var configManager: ConfigManager
    @ObservedObject var displayDetector: DisplayDetector

    var body: some View {
        Text("Settings placeholder")
            .frame(width: 500, height: 400)
    }
}
