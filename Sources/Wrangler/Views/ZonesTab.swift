// Sources/Wrangler/Views/ZonesTab.swift
//
// Custom zones management tab: displays saved zones with their
// display, grid position, shortcut binding, rename, and delete.
// Uses SettingsListCard for consistent card styling across tabs.

import AppKit
import SwiftUI

struct ZonesTab: View {
    @ObservedObject var configManager: ConfigManager

    private let labelWidth: CGFloat = 140

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                // MARK: - Custom Zones
                if configManager.config.customZones.isEmpty {
                    SettingsCard("Custom Zones") {
                        HStack {
                            Spacer()
                            VStack(spacing: 4) {
                                Image(systemName: "rectangle.3.group")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.tertiary)
                                Text("No custom zones saved yet")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                Text("Open the grid overlay and right-click drag to save a zone.")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .multilineTextAlignment(.center)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                } else {
                    SettingsListCard(
                        "Custom Zones",
                        trailing: AnyView(
                            HStack(spacing: 8) {
                                Text("\(configManager.config.customZones.count) zone\(configManager.config.customZones.count == 1 ? "" : "s")")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                                Button(role: .destructive) {
                                    configManager.config.customZones.removeAll()
                                    configManager.save()
                                } label: {
                                    Text("Delete All")
                                        .font(.system(size: 10))
                                }
                                .controlSize(.small)
                            }
                        )
                    ) {
                        ForEach(Array(configManager.config.customZones.enumerated()), id: \.element.id) { idx, zone in
                            if idx > 0 {
                                Divider().padding(.horizontal, 8)
                            }
                            zoneRow(for: zone)
                        }
                    }
                }

                // MARK: - Pinned Apps
                if configManager.config.appPins.isEmpty {
                    SettingsCard("Pinned Apps") {
                        HStack {
                            Spacer()
                            VStack(spacing: 4) {
                                Image(systemName: "pin")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.tertiary)
                                Text("No apps pinned")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                Text("Pin an app to always restore it to a specific position.")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                } else {
                    SettingsListCard(
                        "Pinned Apps",
                        trailing: AnyView(
                            Button(action: { pinCurrentApp() }) {
                                Label("Pin Current App", systemImage: "plus")
                                    .font(.system(size: 10))
                            }
                            .controlSize(.small)
                        )
                    ) {
                        ForEach(Array(configManager.config.appPins.enumerated()), id: \.element.id) { idx, pin in
                            if idx > 0 {
                                Divider().padding(.horizontal, 8)
                            }
                            pinRow(for: pin)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func zoneRow(for zone: CustomZone) -> some View {
        HStack(spacing: 6) {
            // Zone color indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.accentColor)
                .frame(width: 3, height: 24)

            VStack(alignment: .leading, spacing: 1) {
                // Editable name
                TextField("Zone name", text: Binding(
                    get: { zone.name },
                    set: { newValue in
                        if let idx = configManager.config.customZones.firstIndex(where: { $0.id == zone.id }) {
                            configManager.config.customZones[idx].name = newValue
                            configManager.save()
                        }
                    }
                ))
                .textFieldStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .frame(width: labelWidth, alignment: .leading)

                Text("\(zone.displayName) \u{2014} Col \(zone.column)\u{2013}\(zone.column + zone.columnSpan - 1), Row \(zone.row)\u{2013}\(zone.row + zone.rowSpan - 1)")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            ShortcutRecorderView(keyCombo: Binding(
                get: { zone.keyCombo },
                set: { newValue in
                    if let idx = configManager.config.customZones.firstIndex(where: { $0.id == zone.id }) {
                        configManager.config.customZones[idx].keyCombo = newValue
                        configManager.save()
                    }
                }
            ))
            .frame(width: 120)

            Button(action: {
                configManager.config.customZones.removeAll { $0.id == zone.id }
                configManager.save()
            }) {
                Image(systemName: "trash")
                    .foregroundStyle(.red.opacity(0.7))
                    .imageScale(.small)
            }
            .buttonStyle(.borderless)
            .help("Delete this zone")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func pinRow(for pin: AppPin) -> some View {
        HStack(spacing: 6) {
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: pin.bundleID) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
                    .resizable()
                    .frame(width: 18, height: 18)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(pin.appName)
                    .font(.system(size: 11, weight: .medium))
                Text("\(pin.displayName) \u{2014} Col \(pin.column)\u{2013}\(pin.column + pin.columnSpan - 1), Row \(pin.row)\u{2013}\(pin.row + pin.rowSpan - 1)")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Button(action: {
                configManager.config.appPins.removeAll { $0.id == pin.id }
                configManager.save()
            }) {
                Image(systemName: "trash")
                    .foregroundStyle(.red.opacity(0.7))
                    .imageScale(.small)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private func pinCurrentApp() {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleID = frontApp.bundleIdentifier else { return }

        // Don't pin Wrangler itself
        guard bundleID != Bundle.main.bundleIdentifier else { return }

        // Check if already pinned
        if configManager.config.appPins.contains(where: { $0.bundleID == bundleID }) {
            return
        }

        let display = NSScreen.screens.first
        let displayID = display?.displayID ?? 0
        let displayName = display?.localizedName ?? "Unknown"
        let displayConfig = configManager.config.displays.first { $0.displayID == displayID }

        let pin = AppPin(
            bundleID: bundleID,
            appName: frontApp.localizedName ?? "Unknown",
            displayID: displayID,
            displayName: displayName,
            column: 0,
            row: 0,
            columnSpan: displayConfig?.columns ?? 4,
            rowSpan: displayConfig?.rows ?? 4
        )
        configManager.config.appPins.append(pin)
        configManager.save()
    }
}
