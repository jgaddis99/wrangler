// Sources/Wrangler/Views/DisplaysTab.swift
//
// Displays settings tab: shows detected monitors with per-display
// grid configuration (columns, rows, gap) and a visual preview
// of the grid layout.

import SwiftUI

struct DisplaysTab: View {
    @ObservedObject var configManager: ConfigManager
    @ObservedObject var displayDetector: DisplayDetector

    /// Consistent width for stepper labels so they align vertically.
    private let stepperLabelWidth: CGFloat = 70

    var body: some View {
        Form {
            if displayDetector.displays.isEmpty {
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "display.trianglebadge.exclamationmark")
                            .foregroundStyle(.secondary)
                            .imageScale(.large)
                        Text("No displays detected")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            } else {
                ForEach(displayDetector.displays) { display in
                    displaySection(for: display)
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            syncDisplayConfigs()
        }
    }

    @ViewBuilder
    private func displaySection(for display: DisplayDetector.DetectedDisplay) -> some View {
        let binding = displayConfigBinding(for: display)

        Section {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(display.name)
                            .font(.headline)
                        Text("\(Int(display.frame.width))\u{00D7}\(Int(display.frame.height))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Columns")
                            .frame(width: stepperLabelWidth, alignment: .leading)
                        Stepper(
                            "\(binding.wrappedValue.columns)",
                            value: binding.columns,
                            in: 1...12
                        )
                        .onChange(of: binding.wrappedValue.columns) { _, _ in configManager.save() }
                    }
                    .help("Number of vertical grid divisions")

                    HStack {
                        Text("Rows")
                            .frame(width: stepperLabelWidth, alignment: .leading)
                        Stepper(
                            "\(binding.wrappedValue.rows)",
                            value: binding.rows,
                            in: 1...12
                        )
                        .onChange(of: binding.wrappedValue.rows) { _, _ in configManager.save() }
                    }
                    .help("Number of horizontal grid divisions")

                    HStack {
                        Text("Gap")
                            .frame(width: stepperLabelWidth, alignment: .leading)
                        Stepper(
                            "\(binding.wrappedValue.gap) px",
                            value: binding.gap,
                            in: 0...50
                        )
                        .onChange(of: binding.wrappedValue.gap) { _, _ in configManager.save() }
                    }
                    .help("Pixel gap between snapped windows")

                    Text("\(binding.wrappedValue.columns)\u{00D7}\(binding.wrappedValue.rows) grid")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                GridPreviewView(
                    columns: binding.wrappedValue.columns,
                    rows: binding.wrappedValue.rows,
                    gap: binding.wrappedValue.gap,
                    displaySize: display.frame.size
                )
            }
            .padding(.vertical, 4)
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
