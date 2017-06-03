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
    
    static let allTests = [("testCreateFont", testCreateFont)]
    
    func testCreateFont() {
        
        let fontNames = [
            ("MicrosoftSansSerif", "Microsoft Sans Serif"),
            ("MicrosoftSansSerif-Bold", "Microsoft Sans Serif"),
            ("TimesNewRoman", "Times New Roman"),
            ("TimesNewRoman-Bold", "Times New Roman")
        ]
        
        for (fontName, expectedFullName) in fontNames {
            
            guard let font = Silica.Font(name: fontName)
                else { XCTFail("Could not create font"); return }
            
            XCTAssert(font.name == font.name)
            XCTAssert(expectedFullName == font.scaledFont.fullName, "\(expectedFullName) == \(font.scaledFont.fullName)")
        }
    }
}
