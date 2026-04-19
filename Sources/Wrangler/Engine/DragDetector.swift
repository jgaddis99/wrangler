// Sources/Wrangler/Engine/DragDetector.swift
//
// Detects when the user starts dragging a window using the
// Accessibility API observer system. Fires a callback when
// a drag is detected and when it ends, enabling auto-show
// of the grid overlay.

import AppKit
import ApplicationServices
import Foundation

final class DragDetector {

    typealias DragHandler = (Bool) -> Void  // true = drag started, false = drag ended

    private var observer: AXObserver?
    private var handler: DragHandler?
    private var moveCount = 0
    private var moveTimer: Timer?
    private var isTracking = false
    private let moveThreshold = 3  // Number of move events to consider it a drag
    private var workspaceObserver: NSObjectProtocol?

    func start(handler: @escaping DragHandler) {
        self.handler = handler
        startObserving()

        // Re-register on app switch so we observe the new frontmost window.
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.reobserve()
        }
    }

    func stop() {
        stopObserving()
        if let obs = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            workspaceObserver = nil
        }
        handler = nil
    }

    deinit {
        stop()
    }

    private func startObserving() {
        // Observe the frontmost app's focused window
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }
        let pid = frontApp.processIdentifier

        var obs: AXObserver?
        let result = AXObserverCreate(pid, { (observer, element, notification, refcon) in
            guard let refcon = refcon else { return }
            let detector = Unmanaged<DragDetector>.fromOpaque(refcon).takeUnretainedValue()
            DispatchQueue.main.async {
                detector.handleWindowMoved()
            }
        }, &obs)

        guard result == .success, let observer = obs else { return }
        self.observer = observer

        // Observe the focused WINDOW, not the app element.
        // kAXMovedNotification only fires on window elements.
        let appElement = AXUIElementCreateApplication(pid)
        var focusedWindow: CFTypeRef?
        AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)

        let refcon = Unmanaged.passRetained(self).toOpaque()
        if let window = focusedWindow {
            let windowElement = unsafeBitCast(window, to: AXUIElement.self)
            AXObserverAddNotification(observer, windowElement, kAXMovedNotification as CFString, refcon)
            AXObserverAddNotification(observer, windowElement, kAXResizedNotification as CFString, refcon)
        }

        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
    }

    private func stopObserving() {
        if let observer = observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
            // Balance the passRetained call in startObserving
            Unmanaged.passUnretained(self).release()
        }
        observer = nil
        moveTimer?.invalidate()
        moveTimer = nil
    }

    private func handleWindowMoved() {
        moveCount += 1

        if moveCount >= moveThreshold && !isTracking {
            isTracking = true
            handler?(true) // Drag started
        }

        // Reset the "drag ended" timer
        moveTimer?.invalidate()
        moveTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.dragEnded()
        }
    }

    private func dragEnded() {
        if isTracking {
            isTracking = false
            handler?(false) // Drag ended
        }
        moveCount = 0
    }

    /// Call when the frontmost app changes to re-register the observer
    func reobserve() {
        stopObserving()
        startObserving()
    }
}
