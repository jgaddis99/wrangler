// Sources/Wrangler/Views/ZonesTab.swift
//
// Custom zones management tab: displays saved zones with their
// display, grid position, shortcut binding, and delete action.

import SwiftUI

struct ZonesTab: View {
    @ObservedObject var configManager: ConfigManager

    /// Matches the label width used in ShortcutsTab for visual consistency.
    private let labelWidth: CGFloat = 160

    var body: some View {
        Form {
            if configManager.config.customZones.isEmpty {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "rectangle.3.group")
                            .font(.system(size: 28))
                            .foregroundStyle(.secondary)
                        Text("No custom zones saved yet")
                            .font(.body)
                            .foregroundStyle(.secondary)
                        Text("Right-click and drag on the grid overlay to save a zone.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
            } else {
                Section("Saved Zones") {
                    ForEach(configManager.config.customZones) { zone in
                        zoneRow(for: zone)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func zoneRow(for zone: CustomZone) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "rectangle.dashed")
                .frame(width: 24, alignment: .center)
                .foregroundColor(.accentColor)
                .imageScale(.medium)

            VStack(alignment: .leading, spacing: 2) {
                Text(zone.name)
                    .frame(width: labelWidth, alignment: .leading)
                Text("\(zone.displayName) — Col \(zone.column)–\(zone.column + zone.columnSpan - 1), Row \(zone.row)–\(zone.row + zone.rowSpan - 1)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: labelWidth, alignment: .leading)
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
            .frame(width: 140)

            Button(action: {
                configManager.config.customZones.removeAll { $0.id == zone.id }
                configManager.save()
            }) {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .help("Delete this zone")
        }
        .padding(.vertical, 2)
    }
}
