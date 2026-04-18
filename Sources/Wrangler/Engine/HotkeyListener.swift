// Sources/Wrangler/Engine/HotkeyListener.swift
//
// Listens for global keyboard shortcuts using a CGEvent tap.
// Matches incoming key events against registered KeyCombo
// bindings and fires action callbacks. Runs the event tap
// on a background thread to avoid blocking the main thread.

import CoreGraphics
import Foundation

final class HotkeyListener {

    typealias ActionHandler = (WranglerAction) -> Void

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var runLoop: CFRunLoop?
    private var thread: Thread?
    private let bindingsLock = NSLock()
    private var _bindings: [(KeyCombo, WranglerAction)] = []
    private var handler: ActionHandler?

    func start(handler: @escaping ActionHandler) {
        self.handler = handler
        stop()

        thread = Thread { [weak self] in
            self?.runEventTap()
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

    func updateBindings(shortcuts: [ActionShortcut]) {
        let newBindings = shortcuts.compactMap { shortcut -> (KeyCombo, WranglerAction)? in
            guard shortcut.enabled, let combo = shortcut.keyCombo else { return nil }
            return (combo, shortcut.action)
        }
        bindingsLock.lock()
        _bindings = newBindings
        bindingsLock.unlock()
    }

    private func currentBindings() -> [(KeyCombo, WranglerAction)] {
        bindingsLock.lock()
        defer { bindingsLock.unlock() }
        return _bindings
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

            for (combo, action) in listener.currentBindings() {
                if combo.matches(keyCode: keyCode, flags: flags) {
                    DispatchQueue.main.async {
                        listener.handler?(action)
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
            print("Wrangler: Failed to create event tap. Accessibility permission required.")
            return
        }

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
