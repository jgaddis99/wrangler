// Sources/Wrangler/Views/SettingsView.swift
//
// Main settings window with a tabbed interface for General,
// Displays, Shortcuts, and Zones configuration panes.

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

            DisplaysTab(configManager: configManager, displayDetector: displayDetector)
                .tabItem {
                    Label("Displays", systemImage: "display.2")
                }

            ShortcutsTab(configManager: configManager)
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }

            ZonesTab(configManager: configManager)
                .tabItem {
                    Label("Zones", systemImage: "square.grid.3x3")
                }
        }
        .frame(minWidth: 560, minHeight: 520)
    }
}
