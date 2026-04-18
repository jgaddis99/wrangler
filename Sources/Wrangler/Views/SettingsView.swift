// Sources/Wrangler/Views/SettingsView.swift
//
// Main settings window with a tabbed interface for General,
// Displays, and Shortcuts configuration panes.

import SwiftUI

struct SettingsView: View {
    @ObservedObject var configManager: ConfigManager
    @ObservedObject var displayDetector: DisplayDetector

    var body: some View {
        TabView {
            GeneralTab(configManager: configManager)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            Text("Displays (coming next)")
                .tabItem {
                    Label("Displays", systemImage: "display.2")
                }

            Text("Shortcuts (coming next)")
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
        }
        .frame(width: 520, height: 420)
    }
}
