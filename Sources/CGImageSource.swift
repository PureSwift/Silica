//
//  CGImageSource.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 6/1/17.
//
//

import Foundation

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
public func CGImageSourceGetType<T: ImageSource>(_ imageSource: T) -> String {
    
    return T.typeIdentifier
}

public func CGImageSourceCopyTypeIdentifiers() -> [String] {
    
    return [ImageSourcePNG.typeIdentifier]
}
