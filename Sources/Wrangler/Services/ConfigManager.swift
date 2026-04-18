// Sources/Wrangler/Services/ConfigManager.swift
//
// Reads and writes WranglerConfig as JSON to the app's
// Application Support directory. Creates the directory
// on first write. Published as an ObservableObject for
// SwiftUI binding.

import Combine
import Foundation

final class ConfigManager: ObservableObject {

    @Published var config: WranglerConfig

    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!.appendingPathComponent("Wrangler", isDirectory: true)

        self.fileURL = appSupport.appendingPathComponent("config.json")
        self.config = Self.load(from: fileURL) ?? WranglerConfig()
    }

    func save() {
        let directory = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        guard let data = try? JSONEncoder().encode(config) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func resetToDefaults() {
        config = WranglerConfig()
        save()
    }

    private static func load(from url: URL) -> WranglerConfig? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WranglerConfig.self, from: data)
    }
}
