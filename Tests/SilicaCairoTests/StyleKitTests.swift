//
//  StyleKitTests.swift
//  SilicaCairoTests
//
//  Created by Alsey Coleman Miller on 6/6/17.
//
//

#if canImport(Cairo)

import XCTest
import Foundation
import SilicaCairo
import SilicaTestSupport

final class StyleKitTests: XCTestCase {

    override func setUp() {
        super.setUp()
        CairoBackend.register()
    }

    private func draw(_ name: String, _ size: Size, _ drawing: (GraphicsContext) -> Void) throws {
        let url = URL(fileURLWithPath: TestPath.testData + name + ".pdf")
        let context = GraphicsContext(try CairoRenderer(pdf: url, size: size))
        drawing(context)
        try context.finish()
        print("Wrote to \(url.path)")
    }

    func testSimpleShapes() throws {
        try draw("simpleShapes", Size(width: 240, height: 120)) { TestStyleKit.drawSimpleShapes(in: $0) }
    }

    func testAdvancedShapes() throws {
        try draw("advancedShapes", Size(width: 240, height: 120)) { TestStyleKit.drawAdvancedShapes(in: $0) }
    }

    func testImagePNG() async throws {
        try await TestAssetManager.shared.fetchAssets()
        try draw("imagePNG", Size(width: 240, height: 180)) { TestStyleKit.drawImagePNG(in: $0) }
    }

    func testDrawSwiftLogo() throws {
        try draw("SwiftLogo", Size(width: 200, height: 200)) {
            TestStyleKit.drawSwiftLogo(in: $0, frame: Rect(x: 0, y: 0, width: 200, height: 200))
        }
    }

    func testDrawSwiftLogoWithText() throws {
        try draw("SwiftLogoWithText", Size(width: 164 * 2, height: 48 * 2)) {
            TestStyleKit.drawSwiftLogoWithText(in: $0, frame: Rect(x: 0, y: 0, width: 164 * 2, height: 48 * 2))
        }
    }

    func testDrawSingleLineText() throws {
        try draw("singleLineText", Size(width: 240, height: 120)) { TestStyleKit.drawSingleLineText(in: $0) }
    }

    func testDrawMultilineText() throws {
        try draw("multilineText", Size(width: 240, height: 180)) { TestStyleKit.drawMultiLineText(in: $0) }
    }

    func testContentMode() throws {
        let bounds = Rect(x: 0, y: 0, width: 320, height: 240)
        let testData: [((GraphicsContext, Rect) -> Void, Size)] = [
            ({ TestStyleKit.drawSwiftLogo(in: $0, frame: $1) }, Size(width: 32, height: 32)),
            ({ TestStyleKit.drawSwiftLogoWithText(in: $0, frame: $1) }, Size(width: 32 * (41 / 12), height: 32)),
        ]
        for (index, (drawing, intrinsicContentSize)) in testData.enumerated() {
            for contentMode in ContentMode.allCases {
                let frame = Rect(contentMode: contentMode, bounds: bounds, size: intrinsicContentSize)
                try draw("testContentMode_\(index + 1)_\(contentMode)", bounds.size) { drawing($0, frame) }
            }
        }
    }
}

#endif // canImport(Cairo)
