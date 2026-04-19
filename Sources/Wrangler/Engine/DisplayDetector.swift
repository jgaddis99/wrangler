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

    enum DisplayDirection { case left, right, up, down }

    /// Find the adjacent display in a given direction based on physical arrangement.
    /// Uses NSScreen frame positions to determine which display is above/below/left/right.
    func adjacentDisplay(from displayID: UInt32, direction: DisplayDirection) -> UInt32? {
        guard let current = displays.first(where: { $0.id == displayID }) else { return nil }
        let others = displays.filter { $0.id != displayID }
        guard !others.isEmpty else { return nil }

        switch direction {
        case .up:
            // Find displays whose bottom edge is near the current display's top edge
            // In NSScreen coords: higher Y = physically higher (bottom-left origin)
            return others
                .filter { $0.frame.minY >= current.frame.maxY - 50 }
                .min(by: { abs($0.frame.midX - current.frame.midX) < abs($1.frame.midX - current.frame.midX) })?
                .id
        case .down:
            return others
                .filter { $0.frame.maxY <= current.frame.minY + 50 }
                .min(by: { abs($0.frame.midX - current.frame.midX) < abs($1.frame.midX - current.frame.midX) })?
                .id
        case .left:
            return others
                .filter { $0.frame.maxX <= current.frame.minX + 50 }
                .min(by: { abs($0.frame.midY - current.frame.midY) < abs($1.frame.midY - current.frame.midY) })?
                .id
        case .right:
            return others
                .filter { $0.frame.minX >= current.frame.maxX - 50 }
                .min(by: { abs($0.frame.midY - current.frame.midY) < abs($1.frame.midY - current.frame.midY) })?
                .id
        }
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
