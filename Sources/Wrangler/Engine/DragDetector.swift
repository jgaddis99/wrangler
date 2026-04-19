// Sources/Wrangler/Engine/DragDetector.swift
//
// Detects when the user starts dragging a window using the
// Accessibility API observer system. Fires a callback when
// a drag is detected and when it ends, enabling auto-show
// of the grid overlay. Full implementation in a later task.

import Foundation

final class DragDetector {

    typealias DragHandler = (Bool) -> Void

    func start(handler: @escaping DragHandler) {
        // Stub — full implementation coming in Task 6
        wranglerLog("Wrangler: DragDetector start (stub)")
    }

    func stop() {
        // Stub — full implementation coming in Task 6
    }
}
