// Sources/Wrangler/Views/SettingsView.swift
//
// Main settings window with a tabbed interface for General,
// Displays, Shortcuts, and Zones configuration panes.
// Uses a taller frame to eliminate scrolling.

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
        .tabViewStyle(.automatic)
        .frame(minWidth: 580, minHeight: 600)
    }
}
