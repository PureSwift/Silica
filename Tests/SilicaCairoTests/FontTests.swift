//
//  FontTests.swift
//  SilicaCairoTests
//
//  Created by Alsey Coleman Miller on 6/6/17.
//
//

#if canImport(Cairo)

import XCTest
@testable import SilicaCairo
import FontConfig

final class FontTests: XCTestCase {

    override func setUp() {
        super.setUp()
        CairoBackend.register()
    }

    func testCreateFont() {

        #if os(Linux)
        var fontNames = [
            ("LiberationSerif", "Liberation Serif", FontWeight.regular),
            ("LiberationSerif-Bold", "Liberation Serif", .bold)
        ]
        #else
        var fontNames = [
            ("TimesNewRoman", "Times New Roman", FontWeight.regular),
            ("TimesNewRoman-Bold", "Times New Roman", .bold)
        ]
        #endif

        #if os(macOS)
        fontNames += [("MicrosoftSansSerif", "Microsoft Sans Serif", .regular),
                      ("MicrosoftSansSerif-Bold", "Microsoft Sans Serif", .bold)]
        #endif

        for (fontName, expectedFullName, weight) in fontNames {

            guard let font = Silica.Font(name: fontName, size: 12),
                let face = font.face as? CairoFontHandle,
                let pattern = FontConfig.Pattern(cgFont: fontName)
                else { XCTFail("Could not create font \(fontName)"); return }

            XCTAssertEqual(expectedFullName, face.scaledFont.fullName)
            XCTAssertEqual(pattern.family, font.familyName)
            XCTAssertEqual(pattern.weight, weight)
        }
    }

    func testMetricsScaleWithSize() throws {
        let font = try XCTUnwrap(["LiberationSerif", "TimesNewRoman", "DejaVuSerif"]
            .lazy.compactMap { Silica.Font(name: $0, size: 10) }.first)
        let double = font.withSize(20)
        XCTAssertEqual(double.ascent, font.ascent * 2, accuracy: 1e-9)
        XCTAssertGreaterThan(font.descent, 0)
        XCTAssertEqual(double.width(of: "Silica"), font.width(of: "Silica") * 2, accuracy: 1e-6)
    }

    func testLinesBreakAtSpaces() throws {
        let font = try XCTUnwrap(["LiberationSerif", "TimesNewRoman", "DejaVuSerif"]
            .lazy.compactMap { Silica.Font(name: $0, size: 12) }.first)
        let lines = font.lines(of: "one two three four", maxWidth: font.width(of: "three four") + 1)
        XCTAssertEqual(lines, ["one two", "three four"])
        XCTAssertEqual(font.lines(of: "a\nb", maxWidth: 0), ["a", "b"])
    }
}

#endif // canImport(Cairo)
