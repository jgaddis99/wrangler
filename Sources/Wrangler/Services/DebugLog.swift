// Sources/Wrangler/Services/DebugLog.swift
//
// Simple file-based debug logger that writes to /tmp/wrangler.log.
// Useful for diagnosing issues since macOS GUI apps don't show
// print() output in the terminal.

import Foundation

func wranglerLog(_ message: String) {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let line = "[\(timestamp)] \(message)\n"
    let url = URL(fileURLWithPath: "/tmp/wrangler.log")

    if let handle = try? FileHandle(forWritingTo: url) {
        handle.seekToEndOfFile()
        handle.write(line.data(using: .utf8)!)
        handle.closeFile()
    } else {
        try? line.data(using: .utf8)?.write(to: url)
    }
}
