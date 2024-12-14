//
//  ImageSource.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 6/1/17.
//
//

import struct Foundation.Data

/// This object abstracts the data-reading task. 
/// An image source can read image data from a `Data` instance.
public protocol CGImageSource: AnyObject {
    
    static var typeIdentifier: String { get }
        
    init?(data: Data)
        
    func createImage(at index: Int) -> CGImage?
}

// MARK: - CoreGraphics

public enum CGImageSourceOption: String {
    
    case typeIdentifierHint = "kCGImageSourceTypeIdentifierHint"
    case shouldAllowFloat = "kCGImageSourceShouldAllowFloat"
    case shouldCache = "kCGImageSourceShouldCache"
    case createThumbnailFromImageIfAbsent = "kCGImageSourceCreateThumbnailFromImageIfAbsent"
    case createThumbnailFromImageAlways = "kCGImageSourceCreateThumbnailFromImageAlways"
    case createThumbnailWithTransform = "kCGImageSourceCreateThumbnailWithTransform"
    case thumbnailMaxPixelSize = "kCGImageSourceThumbnailMaxPixelSize"
}

public func CGImageSourceCreateWithData(_ data: Data, _ options: [CGImageSourceOption: Any]?) {
    
    
}

@inline(__always)
public func CGImageSourceGetType<T: CGImageSource>(_ imageSource: T) -> String {
    T.typeIdentifier
}

public func CGImageSourceCopyTypeIdentifiers() -> [String] {
    [CGImageSourcePNG.typeIdentifier]
}
