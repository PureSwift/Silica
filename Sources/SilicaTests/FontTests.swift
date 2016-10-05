//
//  FontTests.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 6/1/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import XCTest
import Silica
import Cairo

final class FontTests: XCTestCase {
    
    static let allTests: [(String, (FontTests) -> () throws -> Void)] = [("testCreateSimpleFont", testCreateSimpleFont), ("testCreateTraitFont", testCreateTraitFont)]
    
    func testCreateSimpleFont() {
        
        guard let font = Silica.Font(name: "MicrosoftSansSerif")
            else { XCTFail("Could not create font"); return }
        
        let expectedFullName = "Microsoft Sans Serif"
        
        XCTAssert(font.name == font.name)
        XCTAssert(expectedFullName == font.scaledFont.fullName, "\(expectedFullName) == \(font.scaledFont.fullName)")
    }
    
    func testCreateTraitFont() {
        
        guard let font = Silica.Font(name: "MicrosoftSansSerif-Bold")
            else { XCTFail("Could not create font"); return }
        
        let expectedFullName = "Microsoft Sans Serif"
        
        XCTAssert(font.name == font.name)
        XCTAssert(expectedFullName == font.scaledFont.fullName, "\(expectedFullName) == \(font.scaledFont.fullName)")
    }
}
