//
//  CoreGraphicsStyleKitTests.swift
//  SilicaCoreGraphicsTests
//
//  Created by Alsey Coleman Miller on 7/13/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

#if canImport(CoreGraphics)

import XCTest
import Foundation
import CoreGraphics
import SilicaCoreGraphics
import SilicaCairo
import SilicaTestSupport

final class CoreGraphicsStyleKitTests: XCTestCase {

    override func setUp() {
        super.setUp()
        CoreGraphicsBackend.register()
    }

    private func draw(_ drawingMethod: @autoclosure () -> (), _ name: String, _ size: CGSize) -> String {

        let filename = TestPath.testData + name + ".pdf"

        let frame = CGRect(origin: .zero, size: size)

        let context = try! CoreGraphicsContext(pdf: URL(fileURLWithPath: filename), size: frame.size)

        UIGraphicsPushContext(context)

        drawingMethod()

        UIGraphicsPopContext()

        try! context.finish()

        print("Wrote to \(filename)")

        return filename
    }

    private func validatePDF(_ filename: String, size: CGSize, file: StaticString = #filePath, line: UInt = #line) {

        guard let document = CGPDFDocument(URL(fileURLWithPath: filename) as CFURL)
            else { XCTFail("Cannot open PDF \(filename)", file: file, line: line); return }

        XCTAssertEqual(document.numberOfPages, 1, file: file, line: line)

        guard let page = document.page(at: 1)
            else { XCTFail("Missing page in \(filename)", file: file, line: line); return }

        let mediaBox = page.getBoxRect(.mediaBox)

        XCTAssertEqual(mediaBox.size, size, "Unexpected page size in \(filename)", file: file, line: line)
    }

    func testSimpleShapes() {

        let size = CGSize(width: 240, height: 120)
        let filename = draw(TestStyleKit.drawSimpleShapes(), "cg_simpleShapes", size)
        validatePDF(filename, size: size)
    }

    func testAdvancedShapes() {

        let size = CGSize(width: 240, height: 120)
        let filename = draw(TestStyleKit.drawAdvancedShapes(), "cg_advancedShapes", size)
        validatePDF(filename, size: size)
    }

    func testImagePNG() async throws {

        try await TestAssetManager.shared.fetchAssets()

        let size = CGSize(width: 240, height: 180)
        let filename = draw(TestStyleKit.drawImagePNG(), "cg_imagePNG", size)
        validatePDF(filename, size: size)
    }

    func testDrawSwiftLogo() {

        let size = CGSize(width: 200, height: 200)
        let filename = draw(TestStyleKit.drawSwiftLogo(frame: CGRect(origin: .zero, size: size)), "cg_SwiftLogo", size)
        validatePDF(filename, size: size)
    }

    func testDrawSwiftLogoWithText() {

        let size = CGSize(width: 164 * 2, height: 48 * 2)
        let filename = draw(TestStyleKit.drawSwiftLogoWithText(frame: CGRect(origin: .zero, size: size)), "cg_SwiftLogoWithText", size)
        validatePDF(filename, size: size)
    }

    func testDrawSingleLineText() {

        let size = CGSize(width: 240, height: 120)
        let filename = draw(TestStyleKit.drawSingleLineText(), "cg_singleLineText", size)
        validatePDF(filename, size: size)
    }

    func testDrawMultilineText() {

        let size = CGSize(width: 240, height: 180)
        let filename = draw(TestStyleKit.drawMultiLineText(), "cg_multilineText", size)
        validatePDF(filename, size: size)
    }

    /// Renders the same content through the CoreGraphics and Cairo backends
    /// and verifies both produce valid PDFs with identical page geometry.
    func testCrossBackendParity() throws {

        let size = CGSize(width: 200, height: 200)
        let frame = CGRect(origin: .zero, size: size)

        // CoreGraphics backend
        let cgFilename = TestPath.testData + "parity_coregraphics.pdf"
        CoreGraphicsBackend.register()
        let cgContext = try CoreGraphicsContext(pdf: URL(fileURLWithPath: cgFilename), size: size)
        UIGraphicsPushContext(cgContext)
        TestStyleKit.drawSwiftLogo(frame: frame)
        UIGraphicsPopContext()
        try cgContext.finish()

        // Cairo backend
        let cairoFilename = TestPath.testData + "parity_cairo.pdf"
        CairoBackend.register()
        let cairoContext = try CairoContext(pdf: URL(fileURLWithPath: cairoFilename), size: size)
        UIGraphicsPushContext(cairoContext)
        TestStyleKit.drawSwiftLogo(frame: frame)
        UIGraphicsPopContext()
        try cairoContext.finish()

        // restore default for remaining tests
        CoreGraphicsBackend.register()

        // both must be valid single-page PDFs with the same page box
        guard let cgDocument = CGPDFDocument(URL(fileURLWithPath: cgFilename) as CFURL),
            let cairoDocument = CGPDFDocument(URL(fileURLWithPath: cairoFilename) as CFURL)
            else { XCTFail("Cannot open rendered PDFs"); return }

        XCTAssertEqual(cgDocument.numberOfPages, cairoDocument.numberOfPages)

        guard let cgPage = cgDocument.page(at: 1),
            let cairoPage = cairoDocument.page(at: 1)
            else { XCTFail("Missing pages"); return }

        XCTAssertEqual(cgPage.getBoxRect(.mediaBox).size, cairoPage.getBoxRect(.mediaBox).size)
    }
}

#endif // canImport(CoreGraphics)
