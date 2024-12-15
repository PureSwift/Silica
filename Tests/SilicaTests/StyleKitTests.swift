//
//  StyleKitTests.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/11/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import XCTest
import Foundation
import Cairo
@testable import Silica

final class StyleKitTests: XCTestCase {
    
    private func draw(_ drawingMethod: @autoclosure () -> (), _ name: String, _ size: CGSize) {
        
        let filename = TestPath.testData + name + ".pdf"
        
        let frame = CGRect(origin: .zero, size: size)
        
        let surface = try! Surface.PDF(filename: filename, width: Double(frame.width), height: Double(frame.height))
        
        let context = try! Silica.CGContext(surface: surface, size: frame.size)
        
        UIGraphicsPushContext(context)
        
        drawingMethod()
        
        UIGraphicsPopContext()
        
        print("Wrote to \(filename)")
    }
    
    func testSimpleShapes() {
        
        draw(TestStyleKit.drawSimpleShapes(), "simpleShapes", CGSize(width: 240, height: 120))
    }
    
    func testAdvancedShapes() {
        
        draw(TestStyleKit.drawAdvancedShapes(), "advancedShapes", CGSize(width: 240, height: 120))
    }
    
    func testImagePNG() async throws {
        
        try await TestAssetManager.shared.fetchAssets()
        
        draw(TestStyleKit.drawImagePNG(), "imagePNG", CGSize(width: 240, height: 180))
    }
    
    func testDrawSwiftLogo() {
        
        draw(TestStyleKit.drawSwiftLogo(frame: CGRect(origin: .zero, size: CGSize(width: 200, height: 200))), "SwiftLogo", CGSize(width: 200, height: 200))
    }
    
    func testDrawSwiftLogoWithText() {
        
        draw(TestStyleKit.drawSwiftLogoWithText(frame: CGRect(origin: .zero, size: CGSize(width: 164 * 2, height: 48 * 2))), "SwiftLogoWithText", CGSize(width: 164 * 2, height: 48 * 2))
    }
    
    func testDrawSingleLineText() {
        
        draw(TestStyleKit.drawSingleLineText(), "singleLineText", CGSize(width: 240, height: 120))
    }
    
    func testDrawMultilineText() {
        
        draw(TestStyleKit.drawMultiLineText(), "multilineText", CGSize(width: 240, height: 180))
    }
    
    func testContentMode() {
        
        let bounds = CGRect(origin: .zero, size: CGSize(width: 320, height: 240))
        let testData: [((CGRect) -> (), CGSize)] = [
            (TestStyleKit.drawSwiftLogo, CGSize(width: 32, height: 32)),
            (TestStyleKit.drawSwiftLogoWithText, CGSize(width: 32 * (41 / 12), height: 32))
        ]
        for (index, (drawingFunction, intrinsicContentSize)) in testData.enumerated() {
            let imageNumber = index + 1
            for contentMode in UIViewContentMode.allCases {
                let frame = CGRect(contentMode: contentMode, bounds: bounds, size: intrinsicContentSize)
                print("Draw image \(imageNumber) with content mode \(contentMode). \(frame)")
                draw(drawingFunction(frame), "testContentMode_\(imageNumber)_\(contentMode)", bounds.size)
            }
        }
        
    }
}
