//
//  QuartzStyleKitTests.swift
//  SilicaQuartzTests
//
//  Created by Alsey Coleman Miller on 7/13/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

#if canImport(CoreGraphics)

import XCTest
import Foundation
import CoreGraphics
import SilicaQuartz
import SilicaCairo
import SilicaTestSupport

final class QuartzStyleKitTests: XCTestCase {

    override func setUp() {
        super.setUp()
        QuartzBackend.register()
    }

    @discardableResult
    private func draw(_ name: String, _ size: Size, _ drawing: (GraphicsContext) -> Void) throws -> URL {
        let url = URL(fileURLWithPath: TestPath.testData + name + ".pdf")
        let context = GraphicsContext(try QuartzRenderer(pdf: url, size: size))
        drawing(context)
        try context.finish()
        try validatePDF(url, size: size)
        return url
    }

    private func validatePDF(_ url: URL, size: Size, file: StaticString = #filePath, line: UInt = #line) throws {
        let document = try XCTUnwrap(CGPDFDocument(url as CFURL), "Cannot open PDF \(url.path)", file: file, line: line)
        XCTAssertEqual(document.numberOfPages, 1, file: file, line: line)
        let page = try XCTUnwrap(document.page(at: 1), file: file, line: line)
        XCTAssertEqual(page.getBoxRect(.mediaBox).size, CGSize(width: size.width, height: size.height), file: file, line: line)
    }

    func testSimpleShapes() throws {
        try draw("quartz_simpleShapes", Size(width: 240, height: 120)) { TestStyleKit.drawSimpleShapes(in: $0) }
    }

    func testAdvancedShapes() throws {
        try draw("quartz_advancedShapes", Size(width: 240, height: 120)) { TestStyleKit.drawAdvancedShapes(in: $0) }
    }

    func testImagePNG() async throws {
        try await TestAssetManager.shared.fetchAssets()
        try draw("quartz_imagePNG", Size(width: 240, height: 180)) { TestStyleKit.drawImagePNG(in: $0) }
    }

    func testDrawSwiftLogo() throws {
        try draw("quartz_SwiftLogo", Size(width: 200, height: 200)) {
            TestStyleKit.drawSwiftLogo(in: $0, frame: Rect(x: 0, y: 0, width: 200, height: 200))
        }
    }

    func testDrawSwiftLogoWithText() throws {
        try draw("quartz_SwiftLogoWithText", Size(width: 164 * 2, height: 48 * 2)) {
            TestStyleKit.drawSwiftLogoWithText(in: $0, frame: Rect(x: 0, y: 0, width: 164 * 2, height: 48 * 2))
        }
    }

    func testDrawSingleLineText() throws {
        try draw("quartz_singleLineText", Size(width: 240, height: 120)) { TestStyleKit.drawSingleLineText(in: $0) }
    }

    func testDrawMultilineText() throws {
        try draw("quartz_multilineText", Size(width: 240, height: 180)) { TestStyleKit.drawMultiLineText(in: $0) }
    }

    // MARK: - Parity

    /// The share of pixels whose channels differ by more than `tolerance`.
    private func difference(_ a: Silica.Image, _ b: Silica.Image, tolerance: Int = 48) -> Double {
        XCTAssertEqual(a.width, b.width)
        XCTAssertEqual(a.height, b.height)
        var differing = 0
        for y in 0 ..< a.height {
            for x in 0 ..< a.width {
                let i = y * a.bytesPerRow + x * 4, j = y * b.bytesPerRow + x * 4
                for channel in 0 ..< 4 where abs(Int(a.data[i + channel]) - Int(b.data[j + channel])) > tolerance {
                    differing += 1
                    break
                }
            }
        }
        return Double(differing) / Double(a.width * a.height)
    }

    /// Renders the same drawing to bitmaps with Quartz and with Cairo: the
    /// pixels match but for antialiasing at edges.
    private func assertParity(_ size: Size, maximumDifference: Double = 0.03, file: StaticString = #filePath, line: UInt = #line,
                              _ drawing: (GraphicsContext) -> Void) throws {
        let quartz = GraphicsContext(try QuartzRenderer(bitmap: size))
        drawing(quartz)
        let cairo = GraphicsContext(try CairoRenderer(bitmap: size))
        drawing(cairo)
        let share = difference(try XCTUnwrap(quartz.makeImage()), try XCTUnwrap(cairo.makeImage()))
        XCTAssertLessThan(share, maximumDifference, file: file, line: line)
    }

    func testParitySimpleShapes() throws {
        try assertParity(Size(width: 240, height: 120)) { TestStyleKit.drawSimpleShapes(in: $0) }
    }

    func testParityAdvancedShapes() throws {
        try assertParity(Size(width: 240, height: 120)) { TestStyleKit.drawAdvancedShapes(in: $0) }
    }

    func testParitySwiftLogo() throws {
        try assertParity(Size(width: 200, height: 200)) {
            TestStyleKit.drawSwiftLogo(in: $0, frame: Rect(x: 0, y: 0, width: 200, height: 200))
        }
    }

    func testParityTransformsClipsAndArcs() throws {
        try assertParity(Size(width: 100, height: 100)) { context in
            context.fill(Path(Rect(x: 0, y: 0, width: 100, height: 100)), with: .white)
            context.saveGState()
            context.translateBy(x: 50, y: 50)
            context.rotate(by: .pi / 6)
            context.clip(to: Rect(x: -30, y: -30, width: 60, height: 60))
            context.addArc(center: .zero, radius: 40, startAngle: 0, endAngle: .pi * 1.5, clockwise: false)
            context.closePath()
            context.fillColor = .red
            context.fillPath()
            context.restoreGState()
            context.lineWidth = 4
            context.lineCap = .round
            context.strokeColor = .blue
            context.addArc(center: Point(x: 50, y: 50), radius: 45, startAngle: 0, endAngle: .pi, clockwise: true)
            context.strokePath()
        }
    }

    func testParityGradientsAndLayers() throws {
        try assertParity(Size(width: 100, height: 100)) { context in
            context.drawLinearGradient(Gradient(colors: [.red, .blue]), start: Point(x: 0, y: 0), end: Point(x: 100, y: 0),
                                       options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            context.alpha = 0.5
            context.beginTransparencyLayer()
            context.fill(Path(ellipseIn: Rect(x: 10, y: 10, width: 60, height: 60)), with: .green)
            context.fill(Path(ellipseIn: Rect(x: 30, y: 30, width: 60, height: 60)), with: .green)
            context.endTransparencyLayer()
        }
    }

    func testParityImage() throws {
        // red, green / blue, white: each backend draws it upright
        let image = Silica.Image(width: 2, height: 2, data: Data([255, 0, 0, 255, 0, 255, 0, 255,
                                                                  0, 0, 255, 255, 255, 255, 255, 255]))
        let size = Size(width: 40, height: 40)
        let renderers: [any Renderer] = [try QuartzRenderer(bitmap: size), try CairoRenderer(bitmap: size)]
        for renderer in renderers {
            let context = GraphicsContext(renderer)
            context.draw(image, in: Rect(x: 0, y: 0, width: 40, height: 40))
            let result = try XCTUnwrap(context.makeImage())
            func pixel(_ x: Int, _ y: Int) -> [UInt8] {
                let offset = y * result.bytesPerRow + x * 4
                return Array(result.data[offset ..< offset + 3])
            }
            XCTAssertGreaterThan(pixel(5, 5)[0], 200, "\(renderer)")
            XCTAssertGreaterThan(pixel(35, 5)[1], 200, "\(renderer)")
            XCTAssertGreaterThan(pixel(5, 35)[2], 200, "\(renderer)")
            XCTAssertGreaterThan(pixel(35, 35).min() ?? 0, 240, "\(renderer)")
        }
    }
}

#endif // canImport(CoreGraphics)
