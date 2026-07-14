//
//  FontTests.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 6/1/16.
//  Copyright © 2016 PureSwift. All rights reserved.
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
            
            guard let font = Silica.CGFont(name: fontName),
                let pattern = FontConfig.Pattern(cgFont: fontName)
                else { XCTFail("Could not create font \(fontName)"); return }
            
            XCTAssertEqual(font.name, font.name)
            XCTAssertEqual(expectedFullName, font.scaledFont.fullName)
            XCTAssertEqual(pattern.family, font.family)
            XCTAssertEqual(pattern.weight, weight)
        }
    }
}

#endif // canImport(Cairo)
