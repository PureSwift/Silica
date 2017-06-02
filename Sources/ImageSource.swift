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
public protocol ImageSource: class, RandomAccessCollection {
    
    associatedtype Index = Int
    associatedtype Indices = DefaultRandomAccessIndices<Self>
    associatedtype Iterator = IndexingIterator<Self>
    
    static var typeIdentifier: String { get }
    
    init?(data: Data)
        
    func createImage(at index: Int) throws -> Image
}

public extension ImageSource {
    
    public var count: Int { return 1 } // only formats like GIF have multiple images
    
    public subscript (index: Int) -> Image {
        
        return try! createImage(at: index)
    }
    
    public subscript(bounds: Range<Self.Index>) -> RandomAccessSlice<Self> {
        
        return RandomAccessSlice<Self>(base: self, bounds: bounds)
    }
    
    /// The start `Index`.
    public var startIndex: Int {
        
        return 0
    }
    
    /// The end `Index`.
    ///
    /// This is the "one-past-the-end" position, and will always be equal to the `count`.
    public var endIndex: Int {
        return count
    }
    
    public func index(before i: Int) -> Int {
        return i - 1
    }
    
    public func index(after i: Int) -> Int {
        return i + 1
    }
    
    public func makeIterator() -> IndexingIterator<Self> {
        
        return IndexingIterator(_elements: self)
    }
}
