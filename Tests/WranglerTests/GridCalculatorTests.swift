// Tests/WranglerTests/GridCalculatorTests.swift
//
// Tests for grid math: frame calculation from grid position,
// action-to-position mapping, and edge cases (gaps, odd grids).

import XCTest
@testable import Wrangler

final class GridCalculatorTests: XCTestCase {

    let standardDisplay = CGRect(x: 0, y: 0, width: 1920, height: 1080)

    // MARK: - Frame Calculation

    func testSingleCellNoGap() {
        let frame = GridCalculator.calculateFrame(
            for: GridPosition(column: 0, row: 0),
            in: standardDisplay,
            gridColumns: 4, gridRows: 4, gap: 0
        )
        XCTAssertEqual(frame.origin.x, 0)
        XCTAssertEqual(frame.origin.y, 0)
        XCTAssertEqual(frame.width, 480)
        XCTAssertEqual(frame.height, 270)
    }

    func testSingleCellWithOffset() {
        let frame = GridCalculator.calculateFrame(
            for: GridPosition(column: 2, row: 1),
            in: standardDisplay,
            gridColumns: 4, gridRows: 4, gap: 0
        )
        XCTAssertEqual(frame.origin.x, 960)
        XCTAssertEqual(frame.origin.y, 270)
        XCTAssertEqual(frame.width, 480)
        XCTAssertEqual(frame.height, 270)
    }

    func testMultiCellSpan() {
        // Left half: 2 columns, full height
        let frame = GridCalculator.calculateFrame(
            for: GridPosition(column: 0, row: 0, columnSpan: 2, rowSpan: 4),
            in: standardDisplay,
            gridColumns: 4, gridRows: 4, gap: 0
        )
        XCTAssertEqual(frame.origin.x, 0)
        XCTAssertEqual(frame.origin.y, 0)
        XCTAssertEqual(frame.width, 960)
        XCTAssertEqual(frame.height, 1080)
    }

    func testMaximize() {
        let frame = GridCalculator.calculateFrame(
            for: GridPosition(column: 0, row: 0, columnSpan: 4, rowSpan: 4),
            in: standardDisplay,
            gridColumns: 4, gridRows: 4, gap: 0
        )
        XCTAssertEqual(frame, standardDisplay)
    }

    func testGapBetweenCells() {
        let frame = GridCalculator.calculateFrame(
            for: GridPosition(column: 0, row: 0),
            in: standardDisplay,
            gridColumns: 2, gridRows: 2, gap: 10
        )
        // Width: (1920 - 10) / 2 = 955
        XCTAssertEqual(frame.width, 955)
        // Height: (1080 - 10) / 2 = 535
        XCTAssertEqual(frame.height, 535)
    }

    func testGapSecondCell() {
        let frame = GridCalculator.calculateFrame(
            for: GridPosition(column: 1, row: 0),
            in: standardDisplay,
            gridColumns: 2, gridRows: 2, gap: 10
        )
        // x: 0 + 955 + 10 = 965
        XCTAssertEqual(frame.origin.x, 965)
        XCTAssertEqual(frame.width, 955)
    }

    func testGapWithSpan() {
        // Spanning 2 cells with a gap: width includes the gap between spanned cells
        let frame = GridCalculator.calculateFrame(
            for: GridPosition(column: 0, row: 0, columnSpan: 2, rowSpan: 1),
            in: standardDisplay,
            gridColumns: 2, gridRows: 2, gap: 10
        )
        // Full width: 955 + 10 + 955 = 1920
        XCTAssertEqual(frame.width, 1920)
    }

    func testDisplayOffset() {
        // Second monitor offset
        let display = CGRect(x: 1920, y: 0, width: 1920, height: 1080)
        let frame = GridCalculator.calculateFrame(
            for: GridPosition(column: 0, row: 0),
            in: display,
            gridColumns: 2, gridRows: 2, gap: 0
        )
        XCTAssertEqual(frame.origin.x, 1920)
        XCTAssertEqual(frame.origin.y, 0)
    }

    // MARK: - Action to GridPosition Mapping

    func testSnapLeftMapsToLeftHalf() {
        let pos = GridCalculator.gridPosition(for: .snapLeft, gridColumns: 4, gridRows: 4)
        XCTAssertNotNil(pos)
        XCTAssertEqual(pos?.column, 0)
        XCTAssertEqual(pos?.row, 0)
        XCTAssertEqual(pos?.columnSpan, 2)
        XCTAssertEqual(pos?.rowSpan, 4)
    }

    func testSnapRightMapsToRightHalf() {
        let pos = GridCalculator.gridPosition(for: .snapRight, gridColumns: 4, gridRows: 4)
        XCTAssertNotNil(pos)
        XCTAssertEqual(pos?.column, 2)
        XCTAssertEqual(pos?.columnSpan, 2)
        XCTAssertEqual(pos?.rowSpan, 4)
    }

    func testSnapTopLeftMapsToQuarter() {
        let pos = GridCalculator.gridPosition(for: .snapTopLeft, gridColumns: 4, gridRows: 4)
        XCTAssertNotNil(pos)
        XCTAssertEqual(pos?.column, 0)
        XCTAssertEqual(pos?.row, 0)
        XCTAssertEqual(pos?.columnSpan, 2)
        XCTAssertEqual(pos?.rowSpan, 2)
    }

    func testMaximizeMapsToFullGrid() {
        let pos = GridCalculator.gridPosition(for: .maximize, gridColumns: 4, gridRows: 4)
        XCTAssertNotNil(pos)
        XCTAssertEqual(pos?.columnSpan, 4)
        XCTAssertEqual(pos?.rowSpan, 4)
    }

    func testCenterReturnsNil() {
        let pos = GridCalculator.gridPosition(for: .center, gridColumns: 4, gridRows: 4)
        XCTAssertNil(pos)
    }

    func testNextDisplayReturnsNil() {
        let pos = GridCalculator.gridPosition(for: .nextDisplay, gridColumns: 4, gridRows: 4)
        XCTAssertNil(pos)
    }

    func testOddGridSnapLeft() {
        // 3 columns: left half = floor(3/2) = 1 column
        let pos = GridCalculator.gridPosition(for: .snapLeft, gridColumns: 3, gridRows: 3)
        XCTAssertEqual(pos?.columnSpan, 1)
        // Right half starts at 1, spans 2
        let posR = GridCalculator.gridPosition(for: .snapRight, gridColumns: 3, gridRows: 3)
        XCTAssertEqual(posR?.column, 1)
        XCTAssertEqual(posR?.columnSpan, 2)
    }

    // MARK: - 1x1 Grid Edge Case

    func testOneByOneGridSnapLeft() {
        let pos = GridCalculator.gridPosition(for: .snapLeft, gridColumns: 1, gridRows: 1)
        XCTAssertNotNil(pos)
        XCTAssertEqual(pos?.columnSpan, 1)
        XCTAssertEqual(pos?.rowSpan, 1)
    }

    // MARK: - Out-of-Bounds Clamping

    func testOutOfBoundsColumnClamped() {
        let frame = GridCalculator.calculateFrame(
            for: GridPosition(column: 10, row: 10, columnSpan: 5, rowSpan: 5),
            in: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            gridColumns: 4, gridRows: 4, gap: 0
        )
        // Should clamp to valid range, not produce off-screen frame
        XCTAssertTrue(frame.maxX <= 1920)
        XCTAssertTrue(frame.maxY <= 1080)
    }

    // MARK: - Center Calculation

    func testCenterFrame() {
        let windowSize = CGSize(width: 800, height: 600)
        let frame = GridCalculator.centerFrame(
            windowSize: windowSize,
            in: standardDisplay
        )
        XCTAssertEqual(frame.origin.x, 560) // (1920 - 800) / 2
        XCTAssertEqual(frame.origin.y, 240) // (1080 - 600) / 2
        XCTAssertEqual(frame.width, 800)
        XCTAssertEqual(frame.height, 600)
    }
}
