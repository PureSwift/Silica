//
//  GeometryTests.swift
//  SilicaTests
//
//  Created by Alsey Coleman Miller on 11/25/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

import XCTest
import Silica

final class GeometryTests: XCTestCase {

    func testRectAccessorsWithNegativeSize() {
        let rect = Rect(x: 10, y: 10, width: -4, height: -6)
        XCTAssertEqual(rect.minX, 6)
        XCTAssertEqual(rect.maxX, 10)
        XCTAssertEqual(rect.minY, 4)
        XCTAssertEqual(rect.maxY, 10)
        XCTAssertEqual(rect.standardized, Rect(x: 6, y: 4, width: 4, height: 6))
    }

    func testRectIntersectionAndUnion() {
        let a = Rect(x: 0, y: 0, width: 10, height: 10)
        let b = Rect(x: 5, y: 5, width: 10, height: 10)
        XCTAssertEqual(a.intersection(b), Rect(x: 5, y: 5, width: 5, height: 5))
        XCTAssertEqual(a.union(b), Rect(x: 0, y: 0, width: 15, height: 15))
        XCTAssertTrue(a.intersection(Rect(x: 20, y: 20, width: 1, height: 1)).isNull)
    }

    func testConcatenationOrder() {
        // scale, then translate: (1, 1) → (2, 2) → (12, 2)
        let transform = AffineTransform(scaleX: 2, y: 2).concatenating(AffineTransform(translationX: 10, y: 0))
        XCTAssertEqual(Point(x: 1, y: 1).applying(transform), Point(x: 12, y: 2))
        // translatedBy applies the translation first: (1, 1) → (11, 1) → (22, 2)
        let translated = AffineTransform(scaleX: 2, y: 2).translatedBy(x: 10, y: 0)
        XCTAssertEqual(Point(x: 1, y: 1).applying(translated), Point(x: 22, y: 2))
    }

    func testInversion() throws {
        let transform = AffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 30, ty: 5)
        let inverse = try XCTUnwrap(transform.invertedIfPossible())
        let point = Point(x: 3, y: 4)
        let roundTrip = point.applying(transform).applying(inverse)
        XCTAssertEqual(roundTrip.x, point.x, accuracy: 1e-12)
        XCTAssertEqual(roundTrip.y, point.y, accuracy: 1e-12)
        XCTAssertNil(AffineTransform(scaleX: 0, y: 1).invertedIfPossible())
    }

    func testRotation() {
        let point = Point(x: 1, y: 0).applying(AffineTransform(rotationAngle: .pi / 2))
        XCTAssertEqual(point.x, 0, accuracy: 1e-12)
        XCTAssertEqual(point.y, 1, accuracy: 1e-12)
    }

    func testGradientSortsStops() {
        let gradient = Gradient(stops: [Gradient.Stop(color: .white, location: 1), Gradient.Stop(color: .black, location: 0)])
        XCTAssertEqual(gradient.stops.map(\.location), [0, 1])
        XCTAssertEqual(Gradient(colors: [.red, .green, .blue]).stops.map(\.location), [0, 0.5, 1])
    }
}
