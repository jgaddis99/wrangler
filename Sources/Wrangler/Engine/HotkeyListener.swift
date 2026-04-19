// Sources/Wrangler/Engine/HotkeyListener.swift
//
// Listens for global keyboard shortcuts using a CGEvent tap.
// Matches incoming key events against registered KeyCombo
// bindings and fires action callbacks. Runs the event tap
// on a background thread to avoid blocking the main thread.

import ApplicationServices
import CoreGraphics
import Foundation

final class HotkeyListener {

    typealias ActionHandler = (HotkeyBinding) -> Void

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var runLoop: CFRunLoop?
    private var thread: Thread?
    private let bindingsLock = NSLock()
    private var _bindings: [(KeyCombo, HotkeyBinding)] = []
    private var handler: ActionHandler?

    func start(handler: @escaping ActionHandler) {
        self.handler = handler
        stop()

        thread = Thread { [weak self] in
            self?.runEventTapWithRetry()
        }
        thread?.name = "com.jasong.Wrangler.HotkeyListener"
        thread?.qualityOfService = .userInteractive
        thread?.start()
    }

    func stop() {
        if let runLoop = runLoop {
            CFRunLoopStop(runLoop)
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        eventTap = nil
        runLoopSource = nil
        runLoop = nil
        thread = nil
    }

    func updateBindings(shortcuts: [ActionShortcut], customZones: [CustomZone] = [], overlayShortcut: KeyCombo? = nil, resetPinsShortcut: KeyCombo? = nil) {
        var newBindings: [(KeyCombo, HotkeyBinding)] = []

        if let resetCombo = resetPinsShortcut {
            newBindings.append((resetCombo, .resetPins))
        }

        if let overlayCombo = overlayShortcut {
            newBindings.append((overlayCombo, .overlay))
        }

        for shortcut in shortcuts {
            guard shortcut.enabled, let combo = shortcut.keyCombo else { continue }
            newBindings.append((combo, .predefined(shortcut.action)))
        }
        for zone in customZones {
            guard let combo = zone.keyCombo else { continue }
            newBindings.append((combo, .customZone(zone.id)))
        }

        bindingsLock.lock()
        _bindings = newBindings
        bindingsLock.unlock()
        wranglerLog("Wrangler: HotkeyListener has \(newBindings.count) bindings (\(shortcuts.filter { $0.enabled && $0.keyCombo != nil }.count) predefined, \(customZones.filter { $0.keyCombo != nil }.count) custom)")
    }

    private func currentBindings() -> [(KeyCombo, HotkeyBinding)] {
        bindingsLock.lock()
        defer { bindingsLock.unlock() }
        return _bindings
    }

    private func runEventTapWithRetry() {
        // Retry event tap creation every 2 seconds for up to 60 seconds.
        // Handles the case where the user grants permission after app start.
        for attempt in 1...30 {
            if AXIsProcessTrusted() {
                if attempt > 1 {
                    wranglerLog("Wrangler: Accessibility permission granted on attempt \(attempt)")
                }
                runEventTap()
                return
            }
            if attempt == 1 {
                wranglerLog("Wrangler: Waiting for accessibility permission (retrying for up to 60s)")
            }
            Thread.sleep(forTimeInterval: 2.0)
        }
        wranglerLog("Wrangler: Gave up waiting for accessibility permission after 60s")
    }

    private func runEventTap() {
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
            let listener = Unmanaged<HotkeyListener>.fromOpaque(refcon).takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = listener.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                return Unmanaged.passUnretained(event)
            }

            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = event.flags

            for (combo, binding) in listener.currentBindings() {
                if combo.matches(keyCode: keyCode, flags: flags) {
                    DispatchQueue.main.async {
                        listener.handler?(binding)
                    }
                    return nil // Consume the event
                }
            }

            return Unmanaged.passUnretained(event)
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: refcon
        ) else {
            wranglerLog("Wrangler: FAILED to create event tap. AXIsProcessTrusted=\(AXIsProcessTrusted())")
            return
        }
        wranglerLog("Wrangler: Event tap created successfully")

        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        self.runLoop = CFRunLoopGetCurrent()

        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        CFRunLoopRun()
    }

    deinit {
        stop()
    }
}
