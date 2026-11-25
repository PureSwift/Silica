//
//  PathTests.swift
//  SilicaTests
//
//  Created by Alsey Coleman Miller on 11/25/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

import XCTest
import Silica

final class PathTests: XCTestCase {

    func testBuildsElements() {
        var path = Path()
        path.move(to: Point(x: 0, y: 0))
        path.addLine(to: Point(x: 10, y: 0))
        path.addLine(to: Point(x: 10, y: 10))
        path.closeSubpath()
        XCTAssertEqual(path.elements, [
            .move(to: Point(x: 0, y: 0)),
            .line(to: Point(x: 10, y: 0)),
            .line(to: Point(x: 10, y: 10)),
            .closeSubpath,
        ])
        XCTAssertEqual(path.currentPoint, Point(x: 0, y: 0))
    }

    func testCopiesAreIndependent() {
        let path = Path(Rect(x: 0, y: 0, width: 10, height: 10))
        var copy = path
        copy.addRect(Rect(x: 20, y: 20, width: 10, height: 10))
        XCTAssertEqual(path.elements.count, 5)
        XCTAssertEqual(copy.elements.count, 10)
    }

    func testLineWithoutCurrentPointStartsSubpath() {
        var path = Path()
        path.addLine(to: Point(x: 5, y: 5))
        XCTAssertEqual(path.elements.first, .move(to: Point(x: 5, y: 5)))
    }

    func testArcEndsAtEndAngle() throws {
        var path = Path()
        let center = Point(x: 50, y: 50)
        path.addArc(center: center, radius: 10, startAngle: 0, endAngle: .pi, clockwise: false)
        XCTAssertEqual(path.elements.first, .move(to: Point(x: 60, y: 50)))
        let end = try XCTUnwrap(path.currentPoint)
        XCTAssertEqual(end.x, 40, accuracy: 1e-9)
        XCTAssertEqual(end.y, 50, accuracy: 1e-9)
        // a half turn counterclockwise in angle passes through y = 60 (down)
        let bounds = path.boundingRect
        XCTAssertEqual(bounds.maxY, 60, accuracy: 1e-3)
        XCTAssertEqual(bounds.minY, 50, accuracy: 1e-3)
    }

    func testClockwiseArcGoesTheOtherWay() {
        var path = Path()
        path.addArc(center: Point(x: 50, y: 50), radius: 10, startAngle: 0, endAngle: .pi, clockwise: true)
        let bounds = path.boundingRect
        XCTAssertEqual(bounds.minY, 40, accuracy: 1e-3)
        XCTAssertEqual(bounds.maxY, 50, accuracy: 1e-3)
    }

    func testEllipseBoundsAreTight() {
        let rect = Rect(x: 10, y: 20, width: 30, height: 40)
        let path = Path(ellipseIn: rect)
        let bounds = path.boundingRect
        XCTAssertEqual(bounds.minX, rect.minX, accuracy: 1e-6)
        XCTAssertEqual(bounds.maxX, rect.maxX, accuracy: 1e-6)
        XCTAssertEqual(bounds.minY, rect.minY, accuracy: 1e-6)
        XCTAssertEqual(bounds.maxY, rect.maxY, accuracy: 1e-6)
    }

    func testEmptyPathBoundsAreNull() {
        XCTAssertTrue(Path().boundingRect.isNull)
        XCTAssertTrue(Path().controlPointBounds.isNull)
    }

    func testContainsWithFillRules() {
        var path = Path(Rect(x: 0, y: 0, width: 30, height: 30))
        path.addRect(Rect(x: 10, y: 10, width: 10, height: 10))
        let hole = Point(x: 15, y: 15)
        XCTAssertTrue(path.contains(hole, using: .winding))
        XCTAssertFalse(path.contains(hole, using: .evenOdd))
        XCTAssertTrue(path.contains(Point(x: 5, y: 5), using: .evenOdd))
        XCTAssertFalse(path.contains(Point(x: 40, y: 5)))
    }

    func testContainsCurvedShape() {
        let circle = Path(ellipseIn: Rect(x: 0, y: 0, width: 100, height: 100))
        XCTAssertTrue(circle.contains(Point(x: 50, y: 50)))
        XCTAssertFalse(circle.contains(Point(x: 3, y: 3)))
    }

    func testRoundedRectClampsRadius() {
        let path = Path(roundedRect: Rect(x: 0, y: 0, width: 20, height: 10), cornerRadius: 50)
        let bounds = path.boundingRect
        XCTAssertEqual(bounds.width, 20, accuracy: 1e-6)
        XCTAssertEqual(bounds.height, 10, accuracy: 1e-6)
    }

    func testArcToTangents() throws {
        var path = Path()
        path.move(to: Point(x: 0, y: 0))
        path.addArc(tangent1End: Point(x: 10, y: 0), tangent2End: Point(x: 10, y: 10), radius: 5)
        let end = try XCTUnwrap(path.currentPoint)
        XCTAssertEqual(end.x, 10, accuracy: 1e-9)
        XCTAssertEqual(end.y, 5, accuracy: 1e-9)
    }

    func testApplyingTransform() {
        let path = Path(Rect(x: 0, y: 0, width: 10, height: 10))
            .applying(AffineTransform(translationX: 5, y: 7))
        XCTAssertEqual(path.boundingRect, Rect(x: 5, y: 7, width: 10, height: 10))
    }
}
