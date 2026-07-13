//
//  CGCompatTests.swift
//  Silica
//
//  Pixel-asserting tests for the CoreGraphics compatibility additions:
//  drawPath(.fillStroke), makeImage(), CGMutablePath, and the opt-in
//  bottom-left-origin (raw CoreGraphics) context mode.
//

import XCTest
import Foundation
import Cairo
@testable import Silica

final class CGCompatTests: XCTestCase {

    // MARK: - Utilities

    private func makeBitmapContext(width: Int, height: Int, flipped: Bool = true) throws -> (Silica.CGContext, Cairo.Surface.Image) {
        let surface = try Cairo.Surface.Image(format: .argb32, width: width, height: height)
        let context = try Silica.CGContext(
            surface: surface,
            size: CGSize(width: width, height: height),
            flipped: flipped
        )
        // white background
        context.fillColor = .white
        context.addRect(CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        context.fillPath()
        return (context, surface)
    }

    /// Reads one pixel as (red, green, blue) 0...255 from an ARGB32 surface.
    private func pixel(_ surface: Cairo.Surface.Image, _ x: Int, _ y: Int) -> (red: UInt8, green: UInt8, blue: UInt8) {
        surface.flush()
        let stride = surface.stride
        var result: (UInt8, UInt8, UInt8) = (0, 0, 0)
        surface.withUnsafeMutableBytes { bytes in
            let offset = y * stride + x * 4
            // ARGB32 premultiplied, native little endian: B G R A
            result = (bytes[offset + 2], bytes[offset + 1], bytes[offset])
        }
        return result
    }

    // MARK: - drawPath(.fillStroke)

    func testFillStrokeActuallyStrokes() throws {
        let (context, surface) = try makeBitmapContext(width: 40, height: 40)

        context.fillColor = CGColor(red: 1, green: 0, blue: 0)
        context.strokeColor = CGColor(red: 0, green: 0, blue: 1)
        context.lineWidth = 4
        context.addRect(CGRect(x: 10, y: 10, width: 20, height: 20))
        context.drawPath(using: .fillStroke)

        // interior is filled red
        let interior = pixel(surface, 20, 20)
        XCTAssertGreaterThan(interior.red, 200)
        XCTAssertLessThan(interior.blue, 50)

        // the path border is stroked blue (previously .fillStroke never stroked)
        let border = pixel(surface, 10, 20)
        XCTAssertGreaterThan(border.blue, 200)
        XCTAssertLessThan(border.red, 50)
    }

    // MARK: - makeImage()

    func testMakeImageSnapshotsBitmapContext() throws {
        let (context, surface) = try makeBitmapContext(width: 20, height: 20)

        context.fillColor = CGColor(red: 1, green: 0, blue: 0)
        context.addRect(CGRect(x: 0, y: 0, width: 20, height: 20))
        context.fillPath()

        guard let image = context.makeImage() else {
            XCTFail("makeImage() returned nil for a bitmap context")
            return
        }
        XCTAssertEqual(image.width, 20)
        XCTAssertEqual(image.height, 20)

        // the snapshot is a copy: drawing afterwards must not change it
        context.fillColor = .white
        context.addRect(CGRect(x: 0, y: 0, width: 20, height: 20))
        context.fillPath()
        surface.flush()

        let snapshot = pixel(image.surface, 10, 10)
        XCTAssertGreaterThan(snapshot.red, 200)
        XCTAssertLessThan(snapshot.green, 50)
    }

    func testMakeImageReturnsNilForPDFContext() throws {
        let filename = NSTemporaryDirectory() + "CGCompatTests-\(UUID()).pdf"
        let surface = try Cairo.Surface.PDF(filename: filename, width: 100, height: 100)
        let context = try Silica.CGContext(surface: surface, size: CGSize(width: 100, height: 100))
        XCTAssertNil(context.makeImage())
    }

    // MARK: - CGMutablePath

    func testMutablePathBuildsElements() {
        let path = Silica.CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 10, y: 0))
        path.addLine(to: CGPoint(x: 10, y: 10))
        path.closeSubpath()
        XCTAssertEqual(path.elements.count, 4)
    }

    func testMutableCopyIsIndependent() {
        let path = Silica.CGMutablePath()
        path.addRect(CGRect(x: 0, y: 0, width: 10, height: 10))
        let copy = path.mutableCopy()
        copy.addRect(CGRect(x: 20, y: 20, width: 10, height: 10))
        XCTAssertEqual(path.elements.count, 5)
        XCTAssertEqual(copy.elements.count, 10)
    }

    // MARK: - Bottom-left origin (raw CoreGraphics mode)

    func testBottomLeftOriginPlacesOriginRectAtBottom() throws {
        let (context, surface) = try makeBitmapContext(width: 40, height: 40, flipped: false)

        // a rect at the origin lands at the BOTTOM of the image in
        // bottom-left-origin (raw CoreGraphics) coordinates
        context.fillColor = CGColor(red: 1, green: 0, blue: 0)
        context.addRect(CGRect(x: 0, y: 0, width: 10, height: 10))
        context.fillPath()

        let bottom = pixel(surface, 5, 35)
        XCTAssertGreaterThan(bottom.red, 200)
        XCTAssertLessThan(bottom.green, 50)

        let top = pixel(surface, 5, 5)
        XCTAssertGreaterThan(top.red, 200)
        XCTAssertGreaterThan(top.green, 200)  // still white
    }

    func testBottomLeftOriginTextDrawsUprightFromBaseline() throws {
        guard let font = ["LiberationSerif", "TimesNewRoman", "DejaVuSerif", "Helvetica"]
            .lazy.compactMap({ Silica.CGFont(name: $0) }).first else {
            throw XCTSkip("no test font available")
        }

        let width = 60, height = 60
        let (context, surface) = try makeBitmapContext(width: width, height: height, flipped: false)

        context.fillColor = .black
        context.setFont(font)
        context.fontSize = 24
        context.textPosition = CGPoint(x: 10, y: 20)  // baseline, in y-up coordinates
        context.show(text: "T")
        surface.flush()

        func inkExists(inDeviceRows rows: Range<Int>) -> Bool {
            for y in rows {
                for x in 0 ..< width {
                    let value = pixel(surface, x, y)
                    if value.red < 128 { return true }
                }
            }
            return false
        }

        // "T" (no descender) at baseline y=20 with 24pt size: glyph ink
        // sits ABOVE the baseline in user space, i.e. device rows above
        // row height-20 = 40. Mirrored (broken) rendering would put ink
        // below the baseline instead.
        XCTAssertTrue(inkExists(inDeviceRows: 20 ..< 38), "expected upright glyph ink above the baseline")
        XCTAssertFalse(inkExists(inDeviceRows: 44 ..< 60), "found ink below the baseline: glyphs are mirrored")
    }
}
