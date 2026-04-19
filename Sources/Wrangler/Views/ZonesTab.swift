// Sources/Wrangler/Views/ZonesTab.swift
//
// Custom zones management tab: displays saved zones with their
// display, grid position, shortcut binding, and delete action.

import SwiftUI

struct ZonesTab: View {
    @ObservedObject var configManager: ConfigManager

    var body: some View {
        Form {
            if configManager.config.customZones.isEmpty {
                Section {
                    Text("No custom zones saved yet.")
                        .foregroundColor(.secondary)
                    Text("Right-click drag on the grid overlay to save a zone.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            } else {
                Section("Saved Zones") {
                    ForEach(configManager.config.customZones) { zone in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(zone.name).font(.body)
                                Text("\(zone.displayName) — Col \(zone.column)-\(zone.column + zone.columnSpan - 1), Row \(zone.row)-\(zone.row + zone.rowSpan - 1)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
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
                            .frame(width: 130)
                            Button(action: {
                                configManager.config.customZones.removeAll { $0.id == zone.id }
                                configManager.save()
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
