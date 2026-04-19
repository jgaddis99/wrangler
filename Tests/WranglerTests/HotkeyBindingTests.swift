// Tests for HotkeyBinding enum equality across all cases:
// predefined actions, custom zone UUIDs, and overlay toggle.

import XCTest
@testable import Wrangler

final class HotkeyBindingTests: XCTestCase {

    func testPredefinedEquality() {
        let a = HotkeyBinding.predefined(.snapLeft)
        let b = HotkeyBinding.predefined(.snapLeft)
        let c = HotkeyBinding.predefined(.snapRight)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testCustomZoneEquality() {
        let id = UUID()
        let a = HotkeyBinding.customZone(id)
        let b = HotkeyBinding.customZone(id)
        let c = HotkeyBinding.customZone(UUID())
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testOverlayEquality() {
        XCTAssertEqual(HotkeyBinding.overlay, HotkeyBinding.overlay)
    }

    func testDifferentCasesNotEqual() {
        let id = UUID()
        XCTAssertNotEqual(HotkeyBinding.predefined(.maximize), HotkeyBinding.customZone(id))
        XCTAssertNotEqual(HotkeyBinding.overlay, HotkeyBinding.predefined(.center))
        XCTAssertNotEqual(HotkeyBinding.overlay, HotkeyBinding.customZone(id))
    }
}
