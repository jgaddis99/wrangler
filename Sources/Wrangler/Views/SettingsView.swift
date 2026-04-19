// Sources/Wrangler/Views/SettingsView.swift
//
// Main settings window with a tabbed interface for General,
// Displays, Shortcuts, Zones, and About configuration panes.
// Fixed frame ensures all content fits without scrolling.

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
                    Label("Shortcuts", systemImage: "command")
                }

            ZonesTab(configManager: configManager)
                .tabItem {
                    Label("Zones", systemImage: "square.grid.3x3")
                }

            AboutTab()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 580, height: 620)
    }
}

// MARK: - Shared Settings Section Style

/// Reusable section card used across all settings tabs for visual consistency.
struct SettingsCard<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            VStack(alignment: .leading, spacing: 6) {
                content
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
    }
}

/// Reusable list-style card used for rows of items (shortcuts, zones).
struct SettingsListCard<Content: View>: View {
    let title: String
    let trailing: AnyView?
    let content: Content

    init(_ title: String, trailing: AnyView? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.trailing = trailing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                if let trailing = trailing {
                    Spacer()
                    trailing
                }
            }
            VStack(spacing: 0) {
                content
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
    }
}
