// Sources/Wrangler/Views/DisplaysTab.swift
//
// Displays settings tab: shows detected monitors with per-display
// grid configuration using dropdown pickers and a wallpaper-backed
// grid preview matching the overlay appearance.

import SwiftUI

struct DisplaysTab: View {
    @ObservedObject var configManager: ConfigManager
    @ObservedObject var displayDetector: DisplayDetector

    private let gapValues: [Int] = [0, 2, 4, 8, 12, 16, 20]

    var body: some View {
        VStack(spacing: 0) {
            if displayDetector.displays.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "display.trianglebadge.exclamationmark")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No displays detected")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                VStack(spacing: 10) {
                    ForEach(displayDetector.displays) { display in
                        displayCard(for: display)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            syncDisplayConfigs()
        }
    }

    @ViewBuilder
    private func displayCard(for display: DisplayDetector.DetectedDisplay) -> some View {
        let binding = displayConfigBinding(for: display)

        VStack(alignment: .leading, spacing: 4) {
            // Section header with display name
            HStack(spacing: 6) {
                Text(display.name.uppercased())
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("\(Int(display.frame.width))\u{00D7}\(Int(display.frame.height))")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                if display.isMain {
                    Text("PRIMARY")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }

            // Card content
            HStack(alignment: .center, spacing: 16) {
                // Controls column
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Columns")
                            .font(.system(size: 12))
                            .frame(width: 62, alignment: .leading)
                        Picker("", selection: binding.columns) {
                            ForEach(1...6, id: \.self) { n in
                                Text("\(n)").tag(n)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 60)
                        .onChange(of: binding.wrappedValue.columns) { _, _ in configManager.save() }
                    }

                    HStack {
                        Text("Rows")
                            .font(.system(size: 12))
                            .frame(width: 62, alignment: .leading)
                        Picker("", selection: binding.rows) {
                            ForEach(1...6, id: \.self) { n in
                                Text("\(n)").tag(n)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 60)
                        .onChange(of: binding.wrappedValue.rows) { _, _ in configManager.save() }
                    }

                    HStack {
                        Text("Gap")
                            .font(.system(size: 12))
                            .frame(width: 62, alignment: .leading)
                        Picker("", selection: binding.gap) {
                            ForEach(gapValues, id: \.self) { g in
                                Text("\(g) px").tag(g)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 70)
                        .onChange(of: binding.wrappedValue.gap) { _, _ in configManager.save() }
                    }
                }

                Spacer()

                // Grid preview with wallpaper
                GridPreviewView(
                    columns: binding.wrappedValue.columns,
                    rows: binding.wrappedValue.rows,
                    gap: binding.wrappedValue.gap,
                    displaySize: display.frame.size,
                    displayID: display.id
                )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
    }

    private func displayConfigBinding(for display: DisplayDetector.DetectedDisplay) -> Binding<DisplayConfig> {
        Binding(
            get: {
                configManager.config.displays.first { $0.displayID == display.id }
                    ?? DisplayConfig(displayID: display.id, name: display.name)
            },
            set: { newValue in
                if let index = configManager.config.displays.firstIndex(where: { $0.displayID == display.id }) {
                    configManager.config.displays[index] = newValue
                } else {
                    configManager.config.displays.append(newValue)
                }
            }
        )
    }

    private func syncDisplayConfigs() {
        for display in displayDetector.displays {
            if !configManager.config.displays.contains(where: { $0.displayID == display.id }) {
                configManager.config.displays.append(
                    DisplayConfig(displayID: display.id, name: display.name)
                )
            }
        }
        // Remove configs for disconnected displays
        configManager.config.displays.removeAll { config in
            !displayDetector.displays.contains { $0.id == config.displayID }
        }
        configManager.save()
    }
}
