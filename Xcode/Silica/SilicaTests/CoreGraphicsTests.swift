//
//  CoreGraphicsTests.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/11/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import XCTest
import Cairo
import Silica
import SwiftCoreGraphics

final class CoreGraphicsTests: XCTestCase {

    func testRandomPaths() {
        
        let size = Size(width: 400, height: 400)
        
        let surface = Cairo.Surface(format: ImageFormat.ARGB32, width: Int(size.width), height: Int(size.height))
        
        let context = try! Silica.Context(surface: surface, size: size)
        
        func drawRandom() {
            
            
        }
    }

}

let outputDirectory: String = {
    
    let outputDirectory = NSTemporaryDirectory() + "SilicaTests" + "/"
    
    var isDirectory: ObjCBool = false
    
    if NSFileManager.default().fileExists(atPath: outputDirectory, isDirectory: &isDirectory) == false {
        
        try! NSFileManager.default().createDirectory(atPath: outputDirectory, withIntermediateDirectories: false)
    }
    
    return outputDirectory
}()

let PI: Double = 3.14159265358979323846