//
//  CoreTextFontTests.swift
//  SilicaQuartzTests
//
//  Created by Alsey Coleman Miller on 7/13/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

#if canImport(CoreGraphics)

import XCTest
import SilicaQuartz

final class CoreTextFontTests: XCTestCase {

    override func setUp() {
        super.setUp()
        QuartzBackend.register()
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
            guard let font = Silica.Font(name: fontName, size: 12)
                else { XCTFail("Could not create font \(fontName)"); continue }
            XCTAssertEqual(font.familyName, expectedFamily)
            XCTAssertGreaterThan(font.face.unitsPerEm, 0)
            XCTAssertGreaterThan(font.ascent, 0)
            XCTAssertGreaterThan(font.descent, 0)

            let glyph = font.glyph(for: "A")
            XCTAssertNotEqual(glyph, 0, "Missing glyph for 'A' in \(fontName)")
            let advances = font.advances(for: [glyph])
            XCTAssertEqual(advances.count, 1)
            XCTAssertGreaterThan(advances[0], 0)
        }
    }

    func testUnknownFont() {
        XCTAssertNil(Silica.Font(name: "ThisFontDoesNotExist-Bold", size: 12))
    }
}

#endif // canImport(CoreGraphics)
