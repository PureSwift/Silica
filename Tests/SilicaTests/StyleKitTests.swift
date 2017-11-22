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
    
    static let allTests = [("testSimpleShapes", testSimpleShapes),
                           ("testAdvancedShapes", testAdvancedShapes),
                           ("testImagePNG", testImagePNG)]
    
    private func draw(_ drawingMethod: () -> (), _ name: String, _ size: CGSize) {
        
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
        
        draw(TestStyleKit.drawSimpleShapes, "simpleShapes", CGSize(width: 240, height: 120))
    }
    
    func testAdvancedShapes() {
        
        draw(TestStyleKit.drawAdvancedShapes, "advancedShapes", CGSize(width: 240, height: 120))
    }
    
    func testImagePNG() {
        
        do { try TestAssetManager.shared.fetchAssets() }
        
        catch { XCTFail("Could not get test assets (\(error))"); return }
        
        draw(TestStyleKit.drawImagePNG, "imagePNG", CGSize(width: 240, height: 180))
    }
}


