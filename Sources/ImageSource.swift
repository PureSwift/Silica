//
//  ImageSource.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 6/1/17.
//
//

import struct Foundation.Data

/// This object abstracts the data-reading task. 
/// An image source can read image data from a `URL` or `Data`.
public protocol ImageSource: class, Collection {
    
    static var typeIdentifier: String { get }
    
    init?(data: Data)
    
    var count: Int { get }
    
    func createImage(at index: Int) throws -> Image
}

public extension ImageSource {
    
    public var count: Int { return 1 } // only formats like GIF have multiple images
    
    public subscript (index: Int) -> Image {
        
        return try! createImage(at: index)
    }
}
