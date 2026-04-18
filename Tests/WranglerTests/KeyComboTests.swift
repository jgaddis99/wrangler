// Tests for KeyCombo display string formatting and equality.

import XCTest
@testable import Wrangler

final class KeyComboTests: XCTestCase {

    func testDisplayStringWithAllModifiers() {
        let combo = KeyCombo(keyCode: 0x00, control: true, option: true, shift: true, command: true)
        let display = combo.displayString
        XCTAssertTrue(display.contains("\u{2303}"))
        XCTAssertTrue(display.contains("\u{2325}"))
        XCTAssertTrue(display.contains("\u{21E7}"))
        XCTAssertTrue(display.contains("\u{2318}"))
    }

    func testDisplayStringControlOptionOnly() {
        let combo = KeyCombo(keyCode: 0x7B, control: true, option: true, shift: false, command: false)
        let display = combo.displayString
        XCTAssertTrue(display.contains("\u{2303}"))
        XCTAssertTrue(display.contains("\u{2325}"))
        XCTAssertFalse(display.contains("\u{21E7}"))
        XCTAssertFalse(display.contains("\u{2318}"))
        // 0x7B = left arrow
        XCTAssertTrue(display.contains("\u{2190}"))
    }

    func testEquality() {
        let a = KeyCombo(keyCode: 0x7B, control: true, option: true, shift: false, command: false)
        let b = KeyCombo(keyCode: 0x7B, control: true, option: true, shift: false, command: false)
        let c = KeyCombo(keyCode: 0x7C, control: true, option: true, shift: false, command: false)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testModifierFlags() {
        let combo = KeyCombo(keyCode: 0x00, control: true, option: false, shift: true, command: false)
        let flags = combo.modifierFlags
        XCTAssertTrue(flags.contains(.maskControl))
        XCTAssertFalse(flags.contains(.maskAlternate))
        XCTAssertTrue(flags.contains(.maskShift))
        XCTAssertFalse(flags.contains(.maskCommand))
    }
}
