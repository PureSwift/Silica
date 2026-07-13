//
//  CoreTextFontTests.swift
//  SilicaCoreGraphicsTests
//
//  Created by Alsey Coleman Miller on 7/13/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

#if canImport(CoreGraphics)

import XCTest
import SilicaCoreGraphics

final class CoreTextFontTests: XCTestCase {

    override func setUp() {
        super.setUp()
        CoreGraphicsBackend.register()
    }

    func testCreateFont() {

        let fontNames = [
            ("TimesNewRoman", "Times New Roman"),
            ("TimesNewRoman-Bold", "Times New Roman"),
            ("ComicSansMS", "Comic Sans MS"),
            ("AmericanTypewriter-Bold", "American Typewriter"),
            ("Helvetica", "Helvetica")
        ]

        for (fontName, expectedFamily) in fontNames {

            guard let font = Silica.CGFont(name: fontName)
                else { XCTFail("Could not create font \(fontName)"); continue }

            XCTAssertEqual(font.name, fontName)
            XCTAssertEqual(font.family, expectedFamily)
            XCTAssertGreaterThan(font.unitsPerEm, 0)
            XCTAssertGreaterThan(font.ascent, 0)
            XCTAssertLessThan(font.descent, 0)

            // glyph lookup and advances
            let glyph = font.glyph(for: "A")
            XCTAssertNotEqual(glyph, 0, "Missing glyph for 'A' in \(fontName)")

            let advances = font.handle.advances(for: [glyph])
            XCTAssertEqual(advances.count, 1)
            XCTAssertGreaterThan(advances[0], 0)
        }
    }

    func testUnknownFont() {

        XCTAssertNil(Silica.CGFont(name: "ThisFontDoesNotExist-Bold"))
    }
}

#endif // canImport(CoreGraphics)
