// Sources/Wrangler/Engine/WindowManager.swift
//
// Wraps the macOS Accessibility API (AXUIElement) to read
// and write window positions and sizes. Provides methods to
// get the focused window, move it, resize it, and determine
// which display it currently occupies.

import AppKit
import ApplicationServices

enum WindowManagerError: Error {
    case noFocusedWindow
    case accessibilityDenied
    case attributeReadFailed
    case attributeWriteFailed
}

final class WindowManager {

    func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    func getFocusedWindow() -> Result<AXUIElement, WindowManagerError> {
        guard AXIsProcessTrusted() else {
            return .failure(.accessibilityDenied)
        }

        let systemWide = AXUIElementCreateSystemWide()
        var focusedApp: CFTypeRef?
        let appResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedApplicationAttribute as CFString,
            &focusedApp
        )
        guard appResult == .success, let focusedApp else {
            return .failure(.noFocusedWindow)
        }
        // CFTypeRef → AXUIElement: nil already excluded; cast is safe for CF types
        let app = unsafeBitCast(focusedApp, to: AXUIElement.self)

        var focusedWindow: CFTypeRef?
        let winResult = AXUIElementCopyAttributeValue(
            app,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindow
        )
        guard winResult == .success, let focusedWindow else {
            return .failure(.noFocusedWindow)
        }
        // CFTypeRef → AXUIElement: nil already excluded; cast is safe for CF types
        let window = unsafeBitCast(focusedWindow, to: AXUIElement.self)

        return .success(window)
    }

    func getWindowFrame(_ window: AXUIElement) -> CGRect? {
        guard let position = getWindowPosition(window),
              let size = getWindowSize(window) else {
            return nil
        }
        return CGRect(origin: position, size: size)
    }

    func setWindowFrame(_ window: AXUIElement, frame: CGRect) {
        // Set size first to avoid OS clamping when position moves near screen edge
        setWindowSize(window, size: frame.size)
        setWindowPosition(window, position: frame.origin)
    }

    func displayID(for window: AXUIElement) -> UInt32? {
        guard let position = getWindowPosition(window) else { return nil }
        let point = CGPoint(x: position.x + 1, y: position.y + 1)

        var displayID: CGDirectDisplayID = 0
        var displayCount: UInt32 = 0
        let result = CGGetDisplaysWithPoint(point, 1, &displayID, &displayCount)
        guard result == .success, displayCount > 0 else { return nil }
        return displayID
    }

    /// Get all regular windows of the app with the given PID.
    func getAllWindows(forPID pid: pid_t) -> [AXUIElement] {
        guard AXIsProcessTrusted() else { return [] }

        let app = AXUIElementCreateApplication(pid)

        var windowList: CFTypeRef?
        let winResult = AXUIElementCopyAttributeValue(
            app, kAXWindowsAttribute as CFString, &windowList
        )
        guard winResult == .success, let windowList else { return [] }
        guard let windows = windowList as? [AXUIElement] else { return [] }

        // Filter to standard windows (exclude dialogs, sheets, etc.)
        return windows.filter { window in
            var role: CFTypeRef?
            AXUIElementCopyAttributeValue(window, kAXRoleAttribute as CFString, &role)
            guard let role = role as? String else { return false }
            return role == kAXWindowRole
        }
    }

    // MARK: - Private

    private func getWindowPosition(_ window: AXUIElement) -> CGPoint? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &value)
        guard result == .success, let val = value else { return nil }
        // CFTypeRef → AXValue: nil already excluded; cast is safe for CF types
        let axValue = unsafeBitCast(val, to: AXValue.self)
        var point = CGPoint.zero
        AXValueGetValue(axValue, .cgPoint, &point)
        return point
    }

    private func getWindowSize(_ window: AXUIElement) -> CGSize? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &value)
        guard result == .success, let val = value else { return nil }
        // CFTypeRef → AXValue: nil already excluded; cast is safe for CF types
        let axValue = unsafeBitCast(val, to: AXValue.self)
        var size = CGSize.zero
        AXValueGetValue(axValue, .cgSize, &size)
        return size
    }

    private func setWindowPosition(_ window: AXUIElement, position: CGPoint) {
        var pos = position
        guard let value = AXValueCreate(.cgPoint, &pos) else { return }
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
    }

    private func setWindowSize(_ window: AXUIElement, size: CGSize) {
        var sz = size
        guard let value = AXValueCreate(.cgSize, &sz) else { return }
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value)
    }
}
