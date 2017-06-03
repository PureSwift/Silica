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
    
    private func draw(_ drawingMethod: () -> (), _ name: String, _ size: Size) {
        
        let filename = outputDirectory + name + ".pdf"
        
        let frame = Rect(size: size)
        
        let surface = Surface(pdf: filename, width: frame.width, height: frame.height)
        
        let context = try! Silica.Context(surface: surface, size: frame.size)
        
        UIGraphicsPushContext(CGContext(context))
        
        drawingMethod()
        
        UIGraphicsPopContext()
        
        print("Wrote to \(filename)")
    }
    
    func testSimpleShapes() {
        
        draw(TestStyleKit.drawSimpleShapes, "simpleShapes", Size(width: 240, height: 120))
    }
    
    func testAdvancedShapes() {
        
        draw(TestStyleKit.drawAdvancedShapes, "advancedShapes", Size(width: 240, height: 120))
    }
    
    func testImagePNG() {
        
        draw(TestStyleKit.drawImagePNG, "imagePNG", Size(width: 240, height: 120))
    }
}

let outputDirectory: String = {
    
    let outputDirectory = NSTemporaryDirectory() + "SilicaTests" + "/"
    
    var isDirectory: ObjCBool = false
    
    if FileManager.default.fileExists(atPath: outputDirectory, isDirectory: &isDirectory) == false {
        
        try! FileManager.default.createDirectory(atPath: outputDirectory, withIntermediateDirectories: false)
    }
    
    return outputDirectory
}()
