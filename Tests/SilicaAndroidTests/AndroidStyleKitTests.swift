//
//  AndroidStyleKitTests.swift
//  SilicaAndroidTests
//
//  Created by Alsey Coleman Miller on 7/13/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

#if canImport(AndroidGraphics) && os(Android)

import XCTest
import Foundation
import SilicaAndroid
import SilicaTestSupport

/// Renders the shared StyleKit content through the Android Canvas backend.
///
/// These tests require an Android emulator or device (API 31+).
final class AndroidStyleKitTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AndroidBackend.register()
    }

    private func draw(_ drawingMethod: @autoclosure () -> (), _ name: String, _ size: CGSize) throws -> String {

        let filename = TestPath.testData + name + ".pdf"

        let frame = CGRect(origin: .zero, size: size)

        let context = try AndroidCanvasContext(pdf: URL(fileURLWithPath: filename), size: frame.size)

        UIGraphicsPushContext(context)

        drawingMethod()

        UIGraphicsPopContext()

        try context.finish()

        print("Wrote to \(filename)")

        return filename
    }

    private func validatePDF(_ filename: String, file: StaticString = #filePath, line: UInt = #line) throws {

        let data = try Data(contentsOf: URL(fileURLWithPath: filename))

        XCTAssertGreaterThan(data.count, 4, file: file, line: line)
        XCTAssertEqual(String(decoding: data.prefix(4), as: UTF8.self), "%PDF", file: file, line: line)
    }

    func testSimpleShapes() throws {

        let filename = try draw(TestStyleKit.drawSimpleShapes(), "android_simpleShapes", CGSize(width: 240, height: 120))
        try validatePDF(filename)
    }

    func testAdvancedShapes() throws {

        let filename = try draw(TestStyleKit.drawAdvancedShapes(), "android_advancedShapes", CGSize(width: 240, height: 120))
        try validatePDF(filename)
    }

    func testDrawSwiftLogo() throws {

        let size = CGSize(width: 200, height: 200)
        let filename = try draw(TestStyleKit.drawSwiftLogo(frame: CGRect(origin: .zero, size: size)), "android_SwiftLogo", size)
        try validatePDF(filename)
    }

    func testDrawSingleLineText() throws {

        let filename = try draw(TestStyleKit.drawSingleLineText(), "android_singleLineText", CGSize(width: 240, height: 120))
        try validatePDF(filename)
    }
}

#endif // canImport(AndroidGraphics) && os(Android)
