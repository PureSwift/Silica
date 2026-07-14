//
//  Nintendo3DSTests.swift
//  Silica3DSTests
//
//  Created by Alsey Coleman Miller on 7/13/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

import XCTest
import Foundation
import Silica3DS
import SilicaTestSupport

/// Pixel tests for the Nintendo 3DS software renderer.
///
/// The renderer is pure Swift, so these run on every host platform.
final class Nintendo3DSTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Nintendo3DSBackend.register()
    }

    // MARK: - Utilities

    private func makeContext(width: Int, height: Int, scale: Int = 1) throws -> Nintendo3DSContext {
        let context = try Nintendo3DSContext(bitmap: CGSize(width: width, height: height), scale: scale)
        // white background
        context.fillColor = .white
        context.addRect(CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        context.fillPath()
        return context
    }

    private func pixel(_ image: Silica.CGImage, _ x: Int, _ y: Int) -> (red: UInt8, green: UInt8, blue: UInt8) {
        let offset = y * image.bytesPerRow + x * 4
        return (image.data[offset], image.data[offset + 1], image.data[offset + 2])
    }

    private func pixel(_ context: Nintendo3DSContext, _ x: Int, _ y: Int) -> (red: UInt8, green: UInt8, blue: UInt8) {
        return pixel(context.makeImage()!, x, y)
    }

    // MARK: - Fills

    func testFillRect() throws {
        let context = try makeContext(width: 40, height: 40)

        context.fillColor = CGColor(red: 1, green: 0, blue: 0)
        context.addRect(CGRect(x: 10, y: 10, width: 20, height: 20))
        context.fillPath()

        let interior = pixel(context, 20, 20)
        XCTAssertGreaterThan(interior.red, 200)
        XCTAssertLessThan(interior.green, 50)

        let outside = pixel(context, 5, 5)
        XCTAssertGreaterThan(outside.green, 200)  // still white
    }

    func testEvenOddFill() throws {
        let context = try makeContext(width: 40, height: 40)

        // two nested rects: even-odd leaves a hole
        context.fillColor = CGColor(red: 0, green: 0, blue: 1)
        context.addRect(CGRect(x: 5, y: 5, width: 30, height: 30))
        context.addRect(CGRect(x: 15, y: 15, width: 10, height: 10))
        context.fillPath(using: .evenOdd)

        let ring = pixel(context, 10, 20)
        XCTAssertGreaterThan(ring.blue, 200)

        let hole = pixel(context, 20, 20)
        XCTAssertGreaterThan(hole.red, 200)  // white shows through
        XCTAssertGreaterThan(hole.green, 200)
    }

    func testWindingFill() throws {
        let context = try makeContext(width: 40, height: 40)

        // same nested rects wound identically: nonzero fills the hole
        context.fillColor = CGColor(red: 0, green: 0, blue: 1)
        context.addRect(CGRect(x: 5, y: 5, width: 30, height: 30))
        context.addRect(CGRect(x: 15, y: 15, width: 10, height: 10))
        context.fillPath(using: .winding)

        let center = pixel(context, 20, 20)
        XCTAssertGreaterThan(center.blue, 200)
    }

    func testCircleFill() throws {
        let context = try makeContext(width: 40, height: 40)

        context.fillColor = CGColor(red: 0, green: 1, blue: 0)
        context.addArc(center: CGPoint(x: 20, y: 20), radius: 10, startAngle: 0, endAngle: 2 * .pi, clockwise: false)
        context.fillPath()

        let center = pixel(context, 20, 20)
        XCTAssertGreaterThan(center.green, 200)
        XCTAssertLessThan(center.red, 50)

        let corner = pixel(context, 5, 5)
        XCTAssertGreaterThan(corner.red, 200)  // outside the circle: white
    }

    // MARK: - Transforms

    func testTranslatedFill() throws {
        let context = try makeContext(width: 40, height: 40)

        context.saveGState()
        context.translateBy(x: 20, y: 20)
        context.fillColor = CGColor(red: 1, green: 0, blue: 0)
        context.addRect(CGRect(x: 0, y: 0, width: 10, height: 10))
        context.fillPath()
        context.restoreGState()

        let inside = pixel(context, 25, 25)
        XCTAssertGreaterThan(inside.red, 200)
        XCTAssertLessThan(inside.green, 50)

        let origin = pixel(context, 5, 5)
        XCTAssertGreaterThan(origin.green, 200)  // untouched
    }

    func testScaledStrokeWidth() throws {
        let context = try makeContext(width: 60, height: 60)

        // a 2pt stroke under 5x scale must paint ~10 device pixels wide
        context.saveGState()
        context.scaleBy(x: 5, y: 5)
        context.strokeColor = CGColor(red: 0, green: 0, blue: 1)
        context.lineWidth = 2
        context.beginPath()
        context.move(to: CGPoint(x: 1, y: 6))
        context.addLine(to: CGPoint(x: 11, y: 6))
        context.strokePath()
        context.restoreGState()

        // the stroke centerline is at y = 30 (device); ±5 device pixels
        XCTAssertGreaterThan(pixel(context, 30, 27).blue, 200)
        XCTAssertGreaterThan(pixel(context, 30, 33).blue, 200)
        XCTAssertGreaterThan(pixel(context, 30, 30).blue, 200)
        // outside the pen
        XCTAssertGreaterThan(pixel(context, 30, 20).red, 200)
    }

    // MARK: - Strokes

    func testStrokeRect() throws {
        let context = try makeContext(width: 40, height: 40)

        context.strokeColor = CGColor(red: 0, green: 0, blue: 1)
        context.lineWidth = 4
        context.addRect(CGRect(x: 10, y: 10, width: 20, height: 20))
        context.strokePath()

        // border stroked
        XCTAssertGreaterThan(pixel(context, 10, 20).blue, 200)
        XCTAssertGreaterThan(pixel(context, 30, 20).blue, 200)
        XCTAssertGreaterThan(pixel(context, 20, 10).blue, 200)
        // corners (miter join, default)
        XCTAssertGreaterThan(pixel(context, 11, 11).blue, 200)
        // interior not filled
        XCTAssertGreaterThan(pixel(context, 20, 20).red, 200)
        XCTAssertGreaterThan(pixel(context, 20, 20).green, 200)
    }

    func testDashedStroke() throws {
        let context = try makeContext(width: 40, height: 40)

        context.strokeColor = CGColor(red: 1, green: 0, blue: 0)
        context.lineWidth = 4
        context.setLineDash(phase: 0, lengths: [6, 6])
        context.beginPath()
        context.move(to: CGPoint(x: 2, y: 20))
        context.addLine(to: CGPoint(x: 38, y: 20))
        context.strokePath()

        // "on" segment at the start
        XCTAssertGreaterThan(pixel(context, 4, 20).red, 200)
        XCTAssertLessThan(pixel(context, 4, 20).green, 50)
        // "off" gap around x = 2 + 6 + 3 = 11
        XCTAssertGreaterThan(pixel(context, 11, 20).green, 200)
        // next "on" segment around x = 2 + 12 + 3 = 17
        XCTAssertGreaterThan(pixel(context, 17, 20).red, 200)
        XCTAssertLessThan(pixel(context, 17, 20).green, 50)
    }

    func testFillStroke() throws {
        let context = try makeContext(width: 40, height: 40)

        context.fillColor = CGColor(red: 1, green: 0, blue: 0)
        context.strokeColor = CGColor(red: 0, green: 0, blue: 1)
        context.lineWidth = 4
        context.addRect(CGRect(x: 10, y: 10, width: 20, height: 20))
        context.drawPath(using: .fillStroke)

        let interior = pixel(context, 20, 20)
        XCTAssertGreaterThan(interior.red, 200)
        XCTAssertLessThan(interior.blue, 50)

        let border = pixel(context, 10, 20)
        XCTAssertGreaterThan(border.blue, 200)
        XCTAssertLessThan(border.red, 50)
    }

    // MARK: - Clipping

    func testClip() throws {
        let context = try makeContext(width: 40, height: 40)

        context.saveGState()
        context.beginPath()
        context.addRect(CGRect(x: 0, y: 0, width: 20, height: 40))
        context.clip()

        context.fillColor = CGColor(red: 1, green: 0, blue: 0)
        context.addRect(CGRect(x: 0, y: 0, width: 40, height: 40))
        context.fillPath()
        context.restoreGState()

        // left half clipped in
        XCTAssertGreaterThan(pixel(context, 10, 20).red, 200)
        XCTAssertLessThan(pixel(context, 10, 20).green, 50)
        // right half clipped out
        XCTAssertGreaterThan(pixel(context, 30, 20).green, 200)

        // clip restored: full-width fill covers everything
        context.fillColor = CGColor(red: 0, green: 0, blue: 1)
        context.addRect(CGRect(x: 0, y: 0, width: 40, height: 40))
        context.fillPath()
        XCTAssertGreaterThan(pixel(context, 30, 20).blue, 200)
    }

    // MARK: - Alpha & Layers

    func testTransparencyLayer() throws {
        let context = try makeContext(width: 40, height: 40)

        context.setAlpha(0.5)
        context.beginTransparencyLayer(auxiliaryInfo: nil)

        // inside the layer alpha resets to 1
        context.fillColor = CGColor(red: 1, green: 0, blue: 0)
        context.addRect(CGRect(x: 0, y: 0, width: 40, height: 40))
        context.fillPath()

        context.endTransparencyLayer()

        // composited at 50% over white: red stays high, green/blue about half
        let blended = pixel(context, 20, 20)
        XCTAssertGreaterThan(blended.red, 200)
        XCTAssertGreaterThan(blended.green, 90)
        XCTAssertLessThan(blended.green, 165)
    }

    // MARK: - Shadows

    func testShadow() throws {
        let context = try makeContext(width: 40, height: 40)

        context.setShadow(offset: CGSize(width: 8, height: 8), radius: 0, color: CGColor(red: 0, green: 0, blue: 1))
        context.fillColor = CGColor(red: 1, green: 0, blue: 0)
        context.addRect(CGRect(x: 5, y: 5, width: 15, height: 15))
        context.fillPath()

        // shape
        XCTAssertGreaterThan(pixel(context, 10, 10).red, 200)
        // shadow silhouette at the offset, outside the shape
        let shadow = pixel(context, 25, 25)
        XCTAssertGreaterThan(shadow.blue, 200)
        XCTAssertLessThan(shadow.red, 50)
    }

    // MARK: - Images

    func testDrawImage() throws {
        let context = try makeContext(width: 40, height: 40)

        // 1×2 image: red on the top row, blue on the bottom row
        var data = Data(count: 8)
        data[0] = 255; data[3] = 255            // top: red
        data[6] = 255; data[7] = 255            // bottom: blue
        let image = Silica.CGImage(width: 1, height: 2, bytesPerRow: 4, data: data)

        // draw with the UIKit-style pre-flip (as PaintCode/TestStyleKit do)
        context.saveGState()
        context.translateBy(x: 0, y: 40)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(x: 0, y: 0, width: 40, height: 40))
        context.restoreGState()

        // upright result: red on top, blue on bottom
        XCTAssertGreaterThan(pixel(context, 20, 10).red, 200)
        XCTAssertLessThan(pixel(context, 20, 10).blue, 50)
        XCTAssertGreaterThan(pixel(context, 20, 30).blue, 200)
        XCTAssertLessThan(pixel(context, 20, 30).red, 50)
    }

    // MARK: - Supersampling

    func testSupersampledEdgeIsSmoothed() throws {
        let context = try Nintendo3DSContext(bitmap: CGSize(width: 4, height: 4), scale: 2)

        // half-pixel-covering rect: at scale 2, one device column of two is filled
        context.fillColor = CGColor(red: 1, green: 0, blue: 0)
        context.addRect(CGRect(x: 0, y: 0, width: 0.5, height: 4))
        context.fillPath()

        let image = context.makeImage()!
        let edge = pixel(image, 0, 0)

        // averaged coverage: roughly half intensity
        XCTAssertGreaterThan(edge.red, 90)
        XCTAssertLessThan(edge.red, 165)
    }

    // MARK: - Framebuffer

    func testGSPFramebufferSwizzle() throws {
        let width = 4, height = 3
        let context = try Nintendo3DSContext(bitmap: CGSize(width: width, height: height))

        // single red pixel at logical (0, 0)
        context.fillColor = CGColor(red: 1, green: 0, blue: 0)
        context.addRect(CGRect(x: 0, y: 0, width: 1, height: 1))
        context.fillPath()

        var framebuffer = [UInt8](repeating: 0, count: width * height * 3)

        framebuffer.withUnsafeMutableBytes { buffer in
            context.present(into: buffer.baseAddress!, format: .bgr8)
        }

        // logical (x, y) → offset ((x * height) + (height - 1 - y)) * 3, bytes B G R
        let offset = ((0 * height) + (height - 1 - 0)) * 3
        XCTAssertEqual(framebuffer[offset], 0)        // blue
        XCTAssertEqual(framebuffer[offset + 1], 0)    // green
        XCTAssertEqual(framebuffer[offset + 2], 255)  // red

        // logical (3, 2) is black (unfilled): offset ((3 * 3) + 0) * 3 = 27
        XCTAssertEqual(framebuffer[27], 0)
        XCTAssertEqual(framebuffer[29], 0)
    }

    // MARK: - StyleKit

    func testStyleKitSimpleShapes() throws {
        let size = CGSize(width: 240, height: 120)
        let context = try Nintendo3DSContext(bitmap: size)

        // white background
        context.fillColor = .white
        context.addRect(CGRect(origin: .zero, size: size))
        context.fillPath()

        UIGraphicsPushContext(context)
        TestStyleKit.drawSimpleShapes()
        UIGraphicsPopContext()

        // red square at (top-left region), per the shared StyleKit drawing
        let square = pixel(context, 20, 20)
        XCTAssertGreaterThan(square.red, 180)
        XCTAssertLessThan(square.green, 100)

        // green pentagon interior (second shape, around x ≈ 105)
        let pentagon = pixel(context, 105, 25)
        XCTAssertGreaterThan(pentagon.green, 120)
        XCTAssertLessThan(pentagon.red, 150)
    }

    func testStyleKitSwiftLogo() throws {
        let size = CGSize(width: 200, height: 200)
        let context = try Nintendo3DSContext(bitmap: size, scale: 2)

        context.fillColor = .white
        context.addRect(CGRect(origin: .zero, size: size))
        context.fillPath()

        UIGraphicsPushContext(context)
        TestStyleKit.drawSwiftLogo(frame: CGRect(origin: .zero, size: size))
        UIGraphicsPopContext()

        // the logo background is Swift orange/red at the center
        let background = pixel(context, 30, 100)
        XCTAssertGreaterThan(background.red, 150)
        XCTAssertLessThan(background.blue, 120)

        // the bird is white near the center
        let bird = pixel(context, 100, 100)
        XCTAssertGreaterThan(bird.red, 200)
        XCTAssertGreaterThan(bird.green, 200)
        XCTAssertGreaterThan(bird.blue, 200)
    }
}
