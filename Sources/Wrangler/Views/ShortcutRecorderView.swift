// Sources/Wrangler/Views/ShortcutRecorderView.swift
//
// A button-style control that captures a keyboard shortcut
// when clicked. Listens for key events via NSEvent local
// monitor and converts them to a KeyCombo.

import AppKit
import SwiftUI

struct ShortcutRecorderView: NSViewRepresentable {

    @Binding var keyCombo: KeyCombo?

    func makeNSView(context: Context) -> ShortcutRecorderButton {
        let button = ShortcutRecorderButton()
        button.onRecord = { combo in
            keyCombo = combo
        }
        button.currentCombo = keyCombo
        return button
    }

    func updateNSView(_ nsView: ShortcutRecorderButton, context: Context) {
        nsView.currentCombo = keyCombo
        nsView.updateTitle()
    }
}

final class ShortcutRecorderButton: NSButton {

    var onRecord: ((KeyCombo?) -> Void)?
    var currentCombo: KeyCombo?
    private var isRecording = false
    private var eventMonitor: Any?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        updateTitle()
        target = self
        action = #selector(toggleRecording)
    }

    func updateTitle() {
        if isRecording {
            title = "Press shortcut..."
        } else {
            title = currentCombo?.displayString ?? "Record Shortcut"
        }
    }

    @objc private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        updateTitle()

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self else { return event }

            if event.keyCode == 0x35 { // Escape: cancel
                self.stopRecording()
                return nil
            }

            if event.keyCode == 0x33 { // Delete: clear shortcut
                self.currentCombo = nil
                self.onRecord?(nil)
                self.stopRecording()
                return nil
            }

            let combo = KeyCombo(
                keyCode: event.keyCode,
                control: event.modifierFlags.contains(.control),
                option: event.modifierFlags.contains(.option),
                shift: event.modifierFlags.contains(.shift),
                command: event.modifierFlags.contains(.command)
            )

            // Require at least one modifier
            guard combo.control || combo.option || combo.command else {
                return nil
            }

            self.currentCombo = combo
            self.onRecord?(combo)
            self.stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        updateTitle()
    }

    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
