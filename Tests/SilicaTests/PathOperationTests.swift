//
//  PathOperationTests.swift
//  SilicaTests
//
//  Created by Alsey Coleman Miller on 11/25/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

import XCTest
import Silica

final class PathOperationTests: XCTestCase {

    let square = Path(Rect(x: 0, y: 0, width: 10, height: 10))
    let overlapping = Path(Rect(x: 5, y: 5, width: 10, height: 10))
    let far = Path(Rect(x: 50, y: 50, width: 5, height: 5))

    func assertBox(_ path: Path, _ expected: Rect, file: StaticString = #filePath, line: UInt = #line) {
        let box = path.boundingRect
        XCTAssertEqual(box.minX, expected.minX, accuracy: 0.01, file: file, line: line)
        XCTAssertEqual(box.minY, expected.minY, accuracy: 0.01, file: file, line: line)
        XCTAssertEqual(box.width, expected.width, accuracy: 0.01, file: file, line: line)
        XCTAssertEqual(box.height, expected.height, accuracy: 0.01, file: file, line: line)
    }

    func testUnion() {
        let union = square.union(overlapping)
        assertBox(union, Rect(x: 0, y: 0, width: 15, height: 15))
        XCTAssertTrue(union.contains(Point(x: 7, y: 7)))
        XCTAssertTrue(union.contains(Point(x: 12, y: 12)))
        XCTAssertFalse(union.contains(Point(x: 12, y: 2)))
        // one outline, without the overlap's edges
        XCTAssertEqual(union.elements.filter { if case .move = $0 { return true }; return false }.count, 1)
    }

    func testIntersectionAndSubtraction() {
        let intersection = square.intersection(overlapping)
        assertBox(intersection, Rect(x: 5, y: 5, width: 5, height: 5))
        let subtraction = square.subtracting(overlapping)
        XCTAssertFalse(subtraction.contains(Point(x: 7, y: 7)))
        XCTAssertTrue(subtraction.contains(Point(x: 2, y: 8)))
        let difference = square.symmetricDifference(overlapping)
        XCTAssertFalse(difference.contains(Point(x: 7, y: 7)))
        XCTAssertTrue(difference.contains(Point(x: 12, y: 12)))
        XCTAssertTrue(square.intersection(far).isEmpty)
        XCTAssertTrue(square.intersects(overlapping))
        XCTAssertFalse(square.intersects(far))
    }

    func testNormalizedAndComponents() {
        var holed = square
        holed.addRect(Rect(x: 3, y: 3, width: 4, height: 4))
        let normalized = holed.normalized(using: .evenOdd)
        // the hole stays a hole when filled with the winding rule
        XCTAssertFalse(normalized.contains(Point(x: 5, y: 5), using: .winding))
        XCTAssertTrue(normalized.contains(Point(x: 1, y: 1), using: .winding))
        var both = holed
        both.addRect(Rect(x: 20, y: 0, width: 5, height: 5))
        let components = both.componentsSeparated(using: .evenOdd)
        XCTAssertEqual(components.count, 2)
        assertBox(components[0], Rect(x: 0, y: 0, width: 10, height: 10))
        XCTAssertFalse(components[0].contains(Point(x: 5, y: 5)))
        assertBox(components[1], Rect(x: 20, y: 0, width: 5, height: 5))
    }

    func testLines() {
        var across = Path()
        across.move(to: Point(x: -5, y: 5))
        across.addLine(to: Point(x: 15, y: 5))
        let inside = across.lineIntersection(square)
        assertBox(inside, Rect(x: 0, y: 5, width: 10, height: 0))
        let outside = across.lineSubtraction(square)
        XCTAssertEqual(outside.elements.filter { if case .move = $0 { return true }; return false }.count, 2)
    }

    func testStroke() {
        var line = Path()
        line.move(to: Point(x: 0, y: 0))
        line.addLine(to: Point(x: 10, y: 0))
        assertBox(line.strokedPath(StrokeStyle(lineWidth: 4)), Rect(x: 0, y: -2, width: 10, height: 4))
        assertBox(line.strokedPath(StrokeStyle(lineWidth: 4, lineCap: .square)), Rect(x: -2, y: -2, width: 14, height: 4))
        let round = line.strokedPath(StrokeStyle(lineWidth: 4, lineCap: .round))
        XCTAssertTrue(round.contains(Point(x: 11.5, y: 0)))
        XCTAssertFalse(round.contains(Point(x: 11.8, y: 1.8)))
        let outline = square.strokedPath(StrokeStyle(lineWidth: 2))
        assertBox(outline, Rect(x: -1, y: -1, width: 12, height: 12))
        XCTAssertFalse(outline.contains(Point(x: 5, y: 5)))
        XCTAssertTrue(outline.contains(Point(x: -0.9, y: -0.9)))
        let dashed = line.strokedPath(StrokeStyle(lineWidth: 2, dash: [2, 2]))
        XCTAssertTrue(dashed.contains(Point(x: 1, y: 0)))
        XCTAssertFalse(dashed.contains(Point(x: 3, y: 0)))
    }

    func testDashedAndFlattened() {
        var line = Path()
        line.move(to: Point(x: 0, y: 0))
        line.addLine(to: Point(x: 10, y: 0))
        let dashed = line.dashed(phase: 1, lengths: [2, 2])
        XCTAssertEqual(dashed.elements.filter { if case .move = $0 { return true }; return false }.count, 3)
        assertBox(dashed, Rect(x: 0, y: 0, width: 9, height: 0))
        let flattened = Path(ellipseIn: Rect(x: 0, y: 0, width: 10, height: 10)).flattened(threshold: 0.5)
        XCTAssertFalse(flattened.elements.contains { if case .curve = $0 { return true }; return false })
        assertBox(flattened, Rect(x: 0, y: 0, width: 10, height: 10))
    }
}
