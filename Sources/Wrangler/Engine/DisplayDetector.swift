// Sources/Wrangler/Engine/DisplayDetector.swift
//
// Monitors connected displays using NSScreen and publishes
// changes. Converts NSScreen data into DisplayConfig models
// with human-readable names from CoreGraphics display info.

import AppKit
import Combine
import CoreGraphics

final class DisplayDetector: ObservableObject {

    @Published private(set) var displays: [DetectedDisplay] = []

    private var cancellable: AnyCancellable?

    struct DetectedDisplay: Identifiable, Equatable {
        let id: UInt32
        let name: String
        let frame: CGRect
        let visibleFrame: CGRect
        let isMain: Bool
    }

    init() {
        refresh()
        cancellable = NotificationCenter.default.publisher(
            for: NSApplication.didChangeScreenParametersNotification
        )
        .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
        .sink { [weak self] _ in
            self?.refresh()
        }
    }

    func refresh() {
        displays = NSScreen.screens.enumerated().map { index, screen in
            let displayID = screen.displayID
            let name = screen.localizedName
            return DetectedDisplay(
                id: displayID,
                name: name,
                frame: screen.frame,
                visibleFrame: screen.visibleFrame,
                isMain: index == 0
            )
        }
    }

    func visibleFrame(for displayID: UInt32) -> CGRect? {
        guard let nsFrame = displays.first(where: { $0.id == displayID })?.visibleFrame else { return nil }
        return CoordinateConverter.axFrame(from: nsFrame)
    }

    func nextDisplay(after displayID: UInt32) -> UInt32? {
        guard let index = displays.firstIndex(where: { $0.id == displayID }) else { return nil }
        let nextIndex = (index + 1) % displays.count
        return displays[nextIndex].id
    }

    func previousDisplay(before displayID: UInt32) -> UInt32? {
        guard let index = displays.firstIndex(where: { $0.id == displayID }) else { return nil }
        let prevIndex = (index - 1 + displays.count) % displays.count
        return displays[prevIndex].id
    }
}

extension NSScreen {
    var displayID: UInt32 {
        guard let screenNumber = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return 0
        }
        return screenNumber.uint32Value
    }
}

/// Convert NSScreen visibleFrame (bottom-left origin) to AXUIElement coordinates (top-left origin).
enum CoordinateConverter {
    static func axFrame(from nsFrame: CGRect) -> CGRect {
        guard let mainScreen = NSScreen.screens.first else { return nsFrame }
        let screenHeight = mainScreen.frame.height
        let axY = screenHeight - nsFrame.origin.y - nsFrame.height
        return CGRect(x: nsFrame.origin.x, y: axY, width: nsFrame.width, height: nsFrame.height)
    }
}
