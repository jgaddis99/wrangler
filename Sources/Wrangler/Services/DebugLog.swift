// Sources/Wrangler/Services/DebugLog.swift
//
// Logging wrapper. Uses os.log in production, writes to
// /tmp/wrangler.log only in debug builds.

import Foundation
import os.log

private let logger = Logger(subsystem: "com.jasong.Wrangler", category: "App")

func wranglerLog(_ message: String) {
    #if DEBUG
    logger.debug("\(message)")
    // Also write to file for terminal-less debugging
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
    #endif
}
