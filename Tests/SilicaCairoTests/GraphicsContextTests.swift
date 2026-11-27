//
//  GraphicsContextTests.swift
//  SilicaCairoTests
//
//  Created by Alsey Coleman Miller on 7/14/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

#if Cairo && canImport(Cairo)

import XCTest
import Foundation
import Cairo
import SilicaCairo

final class GraphicsContextTests: XCTestCase {

    override func setUp() {
        super.setUp()
        CairoBackend.register()
    }

    // MARK: - Utilities

    private func makeContext(width: Double, height: Double, scale: Double = 1, origin: GraphicsContext.Origin = .topLeft) throws -> GraphicsContext {
        let renderer = try CairoRenderer(bitmap: Size(width: width, height: height), scale: scale)
        let context = GraphicsContext(renderer, origin: origin)
        // white background
        context.fill(Path(Rect(x: 0, y: 0, width: width, height: height)), with: .white)
        return context
    }

    /// One pixel as (red, green, blue, alpha), 0...255, premultiplied.
    private func pixel(_ image: Silica.Image, _ x: Int, _ y: Int) -> (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        let offset = y * image.bytesPerRow + x * 4
        return (image.data[offset], image.data[offset + 1], image.data[offset + 2], image.data[offset + 3])
    }

    private func pixel(_ context: GraphicsContext, _ x: Int, _ y: Int) throws -> (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        pixel(try XCTUnwrap(context.makeImage()), x, y)
    }

    // MARK: - Painting

    func testFillStrokeStrokes() throws {
        let context = try makeContext(width: 40, height: 40)
        context.fillColor = .red
        context.strokeColor = .blue
        context.lineWidth = 4
        context.addRect(Rect(x: 10, y: 10, width: 20, height: 20))
        context.drawPath(using: .fillStroke)

        let interior = try pixel(context, 20, 20)
        XCTAssertGreaterThan(interior.red, 200)
        XCTAssertLessThan(interior.blue, 50)

        let border = try pixel(context, 10, 20)
        XCTAssertGreaterThan(border.blue, 200)
        XCTAssertLessThan(border.red, 50)
        XCTAssertTrue(context.isPathEmpty)
    }

    func testPathAddedBeforeTransformKeepsItsPlace() throws {
        let context = try makeContext(width: 40, height: 40)
        // as in CoreGraphics, a path is placed when it's added
        context.addRect(Rect(x: 0, y: 0, width: 10, height: 10))
        context.translateBy(x: 20, y: 20)
        context.fillColor = .red
        context.fillPath()

        XCTAssertGreaterThan(try pixel(context, 5, 5).red, 200)
        XCTAssertLessThan(try pixel(context, 5, 5).green, 50)
        XCTAssertGreaterThan(try pixel(context, 25, 25).green, 200) // still white
    }

    func testFillWithColorLeavesState() throws {
        let context = try makeContext(width: 20, height: 20)
        context.fillColor = .blue
        context.addRect(Rect(x: 0, y: 0, width: 5, height: 5))
        context.fill(Path(Rect(x: 10, y: 10, width: 10, height: 10)), with: .red)
        XCTAssertEqual(context.fillColor, .blue)
        XCTAssertFalse(context.isPathEmpty)
        XCTAssertGreaterThan(try pixel(context, 15, 15).red, 200)
    }

    func testConcatenatedRotationDrawsInPlace() throws {
        let context = try makeContext(width: 40, height: 40)
        // a quarter turn then a shift right: (x, y) maps to (30 - y, x),
        // so a 20×5 rect at the origin becomes a 5×20 bar at x 25..30.
        context.concatenate(AffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 30, ty: 0))
        context.fill(Path(Rect(x: 0, y: 0, width: 20, height: 5)), with: .red)

        let inside = try pixel(context, 27, 15)
        XCTAssertGreaterThan(inside.red, 200)
        XCTAssertLessThan(inside.green, 50)
        XCTAssertGreaterThan(try pixel(context, 33, 15).green, 200)
    }

    func testSaveAndRestore() throws {
        let context = try makeContext(width: 20, height: 20)
        context.fillColor = .red
        context.saveGState()
        context.fillColor = .blue
        context.translateBy(x: 10, y: 0)
        context.restoreGState()
        XCTAssertEqual(context.fillColor, .red)
        XCTAssertEqual(context.ctm, .identity)
        // restoring without a save does nothing
        context.restoreGState()
        context.fill(Rect(x: 0, y: 0, width: 5, height: 5))
        XCTAssertGreaterThan(try pixel(context, 2, 2).red, 200)
    }

    func testClipLimitsDrawing() throws {
        let context = try makeContext(width: 20, height: 20)
        context.clip(to: Rect(x: 0, y: 0, width: 10, height: 20))
        context.fill(Path(Rect(x: 0, y: 0, width: 20, height: 20)), with: .red)
        XCTAssertGreaterThan(try pixel(context, 5, 5).red, 200)
        XCTAssertGreaterThan(try pixel(context, 15, 5).green, 200)
        XCTAssertEqual(context.clipBoundingBox, Rect(x: 0, y: 0, width: 10, height: 20))
    }

    func testAlphaMultipliesColors() throws {
        let context = try makeContext(width: 10, height: 10)
        context.alpha = 0.5
        context.fill(Path(Rect(x: 0, y: 0, width: 10, height: 10)), with: .black)
        let value = try pixel(context, 5, 5)
        XCTAssertEqual(Int(value.red), 128, accuracy: 2)
    }

    func testLinearGradient() throws {
        let context = try makeContext(width: 100, height: 10)
        context.drawLinearGradient(Gradient(colors: [.black, .white]), start: Point(x: 0, y: 0), end: Point(x: 100, y: 0))
        XCTAssertLessThan(try pixel(context, 2, 5).red, 20)
        XCTAssertEqual(Int(try pixel(context, 50, 5).red), 128, accuracy: 6)
        XCTAssertGreaterThan(try pixel(context, 97, 5).red, 235)
    }

    func testBlendMode() throws {
        let context = try makeContext(width: 10, height: 10)
        context.fill(Path(Rect(x: 0, y: 0, width: 10, height: 10)), with: Color(white: 0.5))
        context.blendMode = .multiply
        context.fill(Path(Rect(x: 0, y: 0, width: 10, height: 10)), with: Color(white: 0.5))
        XCTAssertEqual(Int(try pixel(context, 5, 5).red), 64, accuracy: 3)
    }

    func testTransparencyLayerCompositesWithAlpha() throws {
        let context = try makeContext(width: 10, height: 10)
        context.alpha = 0.5
        context.beginTransparencyLayer()
        // overlapping shapes inside the layer don't darken each other
        context.fill(Path(Rect(x: 0, y: 0, width: 10, height: 10)), with: .black)
        context.fill(Path(Rect(x: 0, y: 0, width: 10, height: 10)), with: .black)
        context.endTransparencyLayer()
        XCTAssertEqual(Int(try pixel(context, 5, 5).red), 128, accuracy: 2)
        XCTAssertEqual(context.alpha, 0.5)
    }

    func testShadowIsOffsetInBaseSpace() throws {
        let context = try makeContext(width: 40, height: 40)
        context.scaleBy(x: 2, y: 2)
        context.setShadow(offset: Size(width: 10, height: 10), blur: 0, color: .blue)
        context.fill(Path(Rect(x: 0, y: 0, width: 5, height: 5)), with: .red)
        XCTAssertGreaterThan(try pixel(context, 5, 5).red, 200)
        // the shadow is 10 points down and right of the 10×10 square, unscaled
        let shadow = try pixel(context, 17, 17)
        XCTAssertGreaterThan(shadow.blue, 200)
        XCTAssertLessThan(shadow.red, 50)
    }

    func testClearRect() throws {
        let context = try makeContext(width: 10, height: 10)
        context.clear(Rect(x: 0, y: 0, width: 5, height: 10))
        XCTAssertEqual(try pixel(context, 2, 5).alpha, 0)
        XCTAssertEqual(try pixel(context, 7, 5).alpha, 255)
    }

    // MARK: - Images

    func testImageDrawsUpright() throws {
        // a 1×2 image: red on top, blue below
        let image = Silica.Image(width: 1, height: 2, data: Data([255, 0, 0, 255, 0, 0, 255, 255]))
        let context = try makeContext(width: 10, height: 20)
        context.draw(image, in: Rect(x: 0, y: 0, width: 10, height: 20))
        XCTAssertGreaterThan(try pixel(context, 5, 2).red, 200)
        XCTAssertGreaterThan(try pixel(context, 5, 17).blue, 200)
    }

    func testImageDrawsUprightWithBottomLeftOrigin() throws {
        let image = Silica.Image(width: 1, height: 2, data: Data([255, 0, 0, 255, 0, 0, 255, 255]))
        let context = try makeContext(width: 10, height: 20, origin: .bottomLeft)
        context.draw(image, in: Rect(x: 0, y: 0, width: 10, height: 20))
        XCTAssertGreaterThan(try pixel(context, 5, 2).red, 200)
        XCTAssertGreaterThan(try pixel(context, 5, 17).blue, 200)
    }

    func testMakeImageIsASnapshot() throws {
        let context = try makeContext(width: 20, height: 20)
        context.fill(Path(Rect(x: 0, y: 0, width: 20, height: 20)), with: .red)
        let image = try XCTUnwrap(context.makeImage())
        XCTAssertEqual(image.width, 20)
        XCTAssertEqual(image.height, 20)
        context.fill(Path(Rect(x: 0, y: 0, width: 20, height: 20)), with: .white)
        XCTAssertGreaterThan(pixel(image, 10, 10).red, 200)
        XCTAssertLessThan(pixel(image, 10, 10).green, 50)
    }

    func testMakeImageIsNilForPDF() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory() + "GraphicsContextTests-\(UUID()).pdf")
        let context = GraphicsContext(try CairoRenderer(pdf: url, size: Size(width: 100, height: 100)))
        XCTAssertNil(context.makeImage())
        try context.finish()
    }

    func testBitmapContextScale() throws {
        let context = try XCTUnwrap(BitmapContext(width: 10, height: 10, scale: 2))
        context.fill(Path(Rect(x: 0, y: 0, width: 5, height: 5)), with: .red)
        let image = try XCTUnwrap(context.makeImage())
        XCTAssertEqual(image.width, 20)
        XCTAssertEqual(image.size, Size(width: 10, height: 10))
        XCTAssertGreaterThan(pixel(image, 9, 9).red, 200)
        XCTAssertEqual(pixel(image, 11, 11).alpha, 0)
        XCTAssertNotNil(context.png())
    }

    // MARK: - Bottom-left Origin

    func testBottomLeftOriginPlacesOriginRectAtBottom() throws {
        let context = try makeContext(width: 40, height: 40, origin: .bottomLeft)
        context.fill(Path(Rect(x: 0, y: 0, width: 10, height: 10)), with: .red)
        XCTAssertGreaterThan(try pixel(context, 5, 35).red, 200)
        XCTAssertLessThan(try pixel(context, 5, 35).green, 50)
        XCTAssertGreaterThan(try pixel(context, 5, 5).green, 200)
    }

    // MARK: - Text

    private func testFont(size: Double) throws -> Silica.Font {
        guard let font = ["LiberationSerif", "TimesNewRoman", "DejaVuSerif", "Helvetica"]
            .lazy.compactMap({ Silica.Font(name: $0, size: size) }).first
        else { throw XCTSkip("no test font available") }
        return font
    }

    private func hasInk(_ image: Silica.Image, rows: Range<Int>) -> Bool {
        for y in rows {
            for x in 0 ..< image.width where pixel(image, x, y).red < 128 {
                return true
            }
        }
        return false
    }

    func testGlyphsDrawUprightFromBaseline() throws {
        let context = try makeContext(width: 60, height: 60)
        context.font = try testFont(size: 24)
        context.fillColor = .black
        context.textPosition = Point(x: 10, y: 40)
        context.showGlyphs([context.font!.glyph(for: "T")])
        let image = try XCTUnwrap(context.makeImage())
        // "T" has no descender: its ink is above the baseline
        XCTAssertTrue(hasInk(image, rows: 20 ..< 38))
        XCTAssertFalse(hasInk(image, rows: 42 ..< 60))
        XCTAssertGreaterThan(context.textPosition.x, 10)
    }

    func testGlyphsDrawUprightWithBottomLeftOrigin() throws {
        let context = try makeContext(width: 60, height: 60, origin: .bottomLeft)
        context.font = try testFont(size: 24)
        context.fillColor = .black
        context.textPosition = Point(x: 10, y: 20) // the baseline, 20 up from the bottom
        context.showGlyphs([context.font!.glyph(for: "T")])
        let image = try XCTUnwrap(context.makeImage())
        XCTAssertTrue(hasInk(image, rows: 20 ..< 38))
        XCTAssertFalse(hasInk(image, rows: 44 ..< 60))
    }

    func testTextAtPointAnchors() throws {
        let context = try makeContext(width: 100, height: 60)
        let font = try testFont(size: 20)
        context.font = font
        context.fillColor = .black
        context.draw("HH", at: Point(x: 50, y: 30), anchor: .center)
        let image = try XCTUnwrap(context.makeImage())
        let half = Int(font.width(of: "HH") / 2)
        // ink is centered on the point: within half the text's width each side
        var columns: [Int] = []
        for x in 0 ..< image.width where (0 ..< image.height).contains(where: { pixel(image, x, $0).red < 128 }) {
            columns.append(x)
        }
        let first = try XCTUnwrap(columns.first), last = try XCTUnwrap(columns.last)
        XCTAssertGreaterThanOrEqual(first, 50 - half - 1)
        XCTAssertLessThanOrEqual(last, 50 + half + 1)
        XCTAssertEqual(Double(first + last) / 2, 50, accuracy: 3)
        XCTAssertFalse(hasInk(image, rows: 0 ..< 10))
        XCTAssertTrue(hasInk(image, rows: 25 ..< 35))
    }

    func testTextInRectWraps() throws {
        let context = try makeContext(width: 100, height: 100)
        context.font = try testFont(size: 12)
        let size = context.size(of: "word word word word word word", maxWidth: 60)
        XCTAssertLessThanOrEqual(size.width, 60)
        XCTAssertGreaterThan(size.height, context.font!.lineHeight)
    }
}

#endif // canImport(Cairo)
