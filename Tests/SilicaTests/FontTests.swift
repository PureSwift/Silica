//
//  FontTests.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 6/1/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import XCTest
@testable import Silica

final class FontTests: XCTestCase {
        
    func testCreateFont() {
        
        #if os(Linux)
        var fontNames = [
            ("LiberationSerif", "Liberation Serif"),
            ("LiberationSerif-Bold", "Liberation Serif")
        ]

        #else
        var fontNames = [
            ("TimesNewRoman", "Times New Roman"),
            ("TimesNewRoman-Bold", "Times New Roman")
        ]
        #endif
        
        #if os(macOS)
        fontNames += [("MicrosoftSansSerif", "Microsoft Sans Serif"),
                      ("MicrosoftSansSerif-Bold", "Microsoft Sans Serif")]
        #endif
        
        for (fontName, expectedFullName) in fontNames {
            
            guard let font = Silica.CGFont(name: fontName)
                else { XCTFail("Could not create font \(fontName)"); return }
            
            XCTAssertEqual(font.name, font.name)
            XCTAssertEqual(expectedFullName, font.scaledFont.fullName)
        }
    }
}
