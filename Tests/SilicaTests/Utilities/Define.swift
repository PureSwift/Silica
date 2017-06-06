//
//  Define.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 6/6/17.
//
//

import Foundation

struct TestPath {
    
    static let unitTests: String = try! createDirectory(at: NSTemporaryDirectory() + "SilicaTests" + "/")
    
    static let assets: String = try! createDirectory(at: unitTests + "TestAssets" + "/")
    
    static let testData: String = try! createDirectory(at: unitTests + "TestData" + "/", removeContents: true)
    
    private static func createDirectory(at filePath: String, removeContents: Bool = false) throws -> String {
        
        var isDirectory: ObjCBool = false
        
        if FileManager.default.fileExists(atPath: filePath, isDirectory: &isDirectory) == false {
            
            try! FileManager.default.createDirectory(atPath: filePath, withIntermediateDirectories: false)
        }
        
        if removeContents {
            
            // remove all files in directory (previous test cache)
            let contents = try! FileManager.default.contentsOfDirectory(atPath: filePath)
            
            contents.forEach { try! FileManager.default.removeItem(atPath: filePath + $0) }
        }
        
        return filePath
    }
}

extension TestAssetManager {
    
    static var shared: TestAssetManager {
        
        struct Static {
            static let value = TestAssetManager(assets: testAssets, cacheDirectory: URL(fileURLWithPath: TestPath.assets))
        }
        
        return Static.value
    }
}

private let testAssets: [TestAsset] = [
    TestAsset(url: URL(string: "https://httpbin.org/image/png")!, filename: "png.png"),
    TestAsset(url: URL(string: "http://www.schaik.com/pngsuite/basn0g01.png")!, filename: "basn0g01.png"),
    TestAsset(url: URL(string: "http://www.schaik.com/pngsuite/basn0g02.png")!, filename: "basn0g02.png"),
    TestAsset(url: URL(string: "http://www.schaik.com/pngsuite/basn0g04.png")!, filename: "basn0g04.png"),
    TestAsset(url: URL(string: "http://www.schaik.com/pngsuite/basn0g08.png")!, filename: "basn0g08.png"),
    TestAsset(url: URL(string: "http://www.schaik.com/pngsuite/basn0g16.png")!, filename: "basn0g16.png")
]
