// Sources/Wrangler/Views/ZonesTab.swift
//
// Custom zones management tab: displays saved zones with their
// display, grid position, shortcut binding, and delete action.
// Uses a compact card layout consistent with the other tabs.

import SwiftUI

struct ZonesTab: View {
    @ObservedObject var configManager: ConfigManager

    /// Matches the label width used in ShortcutsTab for visual consistency.
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
                    Text("Right-click and drag on the grid overlay to save a zone.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Saved Zones")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.bottom, 4)

                    VStack(spacing: 0) {
                        ForEach(Array(configManager.config.customZones.enumerated()), id: \.element.id) { idx, zone in
                            if idx > 0 {
                                Divider()
                                    .padding(.horizontal, 10)
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
            Image(systemName: "rectangle.dashed")
                .frame(width: 20, alignment: .center)
                .foregroundColor(.accentColor)
                .imageScale(.small)

            VStack(alignment: .leading, spacing: 1) {
                Text(zone.name)
                    .font(.system(size: 12))
                    .lineLimit(1)
                Text("\(zone.displayName) \u{2014} Col \(zone.column)\u{2013}\(zone.column + zone.columnSpan - 1), Row \(zone.row)\u{2013}\(zone.row + zone.rowSpan - 1)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: labelWidth, alignment: .leading)

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
