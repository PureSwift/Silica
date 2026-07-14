//
//  UIImage.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 6/3/17.
//
//

#if canImport(Foundation)
import Foundation
#endif

/// UIKit compatibility layer for UIImage
public final class UIImage {
    
    public let cgImage: Silica.CGImage
    
    public init(cgImage: Silica.CGImage) {
        self.cgImage = cgImage
    }
    
    public var size: CGSize {
        return CGSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
    }

    /// Returns a data object that contains the image in PNG format.
    public func pngData() -> Data? {
        return SilicaBackend.default?.encodePNG(cgImage)
    }
}
