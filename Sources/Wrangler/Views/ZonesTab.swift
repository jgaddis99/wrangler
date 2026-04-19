// Sources/Wrangler/Views/ZonesTab.swift
//
// Custom zones management tab: displays saved zones with their
// display, grid position, shortcut binding, rename, and delete.
// Compact card layout with inline editing.

import SwiftUI

struct ZonesTab: View {
    @ObservedObject var configManager: ConfigManager

    private let labelWidth: CGFloat = 150

    var body: some View {
        VStack(spacing: 0) {
            if configManager.config.customZones.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "rectangle.3.group")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("No custom zones saved yet")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Text("Open the grid overlay (Ctrl+Alt+Space) and right-click drag to save a zone.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                }
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Saved Zones")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Spacer()
                        Text("\(configManager.config.customZones.count) zone\(configManager.config.customZones.count == 1 ? "" : "s")")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }

                    VStack(spacing: 0) {
                        ForEach(Array(configManager.config.customZones.enumerated()), id: \.element.id) { idx, zone in
                            if idx > 0 {
                                Divider().padding(.horizontal, 10)
                            }
                            zoneRow(for: zone)
                        }
                    }
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                    )

                    HStack {
                        Spacer()
                        Button(role: .destructive) {
                            configManager.config.customZones.removeAll()
                            configManager.save()
                        } label: {
                            Text("Delete All Zones")
                                .font(.system(size: 11))
                        }
                        .disabled(configManager.config.customZones.isEmpty)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)

                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func zoneRow(for zone: CustomZone) -> some View {
        HStack(spacing: 6) {
            // Zone color indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.accentColor)
                .frame(width: 4, height: 28)

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
                .font(.system(size: 12, weight: .medium))
                .frame(width: labelWidth, alignment: .leading)

                Text("\(zone.displayName) — Col \(zone.column)–\(zone.column + zone.columnSpan - 1), Row \(zone.row)–\(zone.row + zone.rowSpan - 1)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
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
            .frame(width: 130)

            Button(action: {
                configManager.config.customZones.removeAll { $0.id == zone.id }
                configManager.save()
            }) {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
                    .imageScale(.small)
            }
            .buttonStyle(.borderless)
            .help("Delete this zone")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }
}
