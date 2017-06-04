//
//  Image.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/11/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import struct Foundation.Data
import Cairo

/// Represents bitmap images and bitmap image masks, based on sample data that you supply. 
/// A bitmap (or sampled) image is a rectangular array of pixels, 
/// with each pixel representing a single sample or data point in a source image.
public final class Image {
    
    // MARK: - Properties
    
    public let mask: Bool
    
    public let width: UInt
    
    public let height: UInt
    
    public let bitsPerComponent: UInt
    
    public let bitsPerPixel: UInt
    
    public let bytesPerRow: UInt
    
    public let shouldInterpolate: Bool
    
    public let bitmapInfo: BitmapInfo
    
    public let renderingIntent: ColorRenderingIntent
    
    public let colorspace: ColorSpace
    
    public let data: Data
    
    // MARK: - Internal Properties
    
    /// The crop rect for this cropped image.
    private var crop: Rect?
    
    /// The cached Cairo surface for this image.
    private var surfaceCache: Cairo.Surface.Image?
    
    // MARK: - Initialization
    
    public init?(width: UInt,
         height: UInt,
         bitsPerComponent: UInt,
         bitsPerPixel: UInt,
         bytesPerRow: UInt,
         colorspace: ColorSpace,
         bitmapInfo: BitmapInfo,
         data: Data,
         shouldInterpolate: Bool,
         renderingIntent: ColorRenderingIntent) {
        
        let numberOfComponents: UInt = bitmapInfo.alpha == .alphaOnly ? 0 : UInt(colorspace.numberOfComponents)
        
        let hasAlpha: Bool
        
        switch bitmapInfo.alpha {
            
        case .none,
             .noneSkipLast,
             .noneSkipFirst:
            
            hasAlpha = false
            
        case .premultipliedLast,
             .premultipliedFirst,
             .last,
             .first,
             .alphaOnly:
            
            hasAlpha = true
        }
        
        let numberOfComponentsIncludingAlpha: UInt = numberOfComponents + (hasAlpha ? 1 : 0)
        
        // sanity checks
        guard (bitsPerComponent < 1 || bitsPerComponent > 32) == false // Unsupported bitsPerComponent
            && (bitmapInfo.floatComponents && bitsPerComponent != 32) == false // Only 32 bits supported for float components
            && (bitsPerPixel < bitsPerComponent * numberOfComponentsIncludingAlpha) == false // Too few bitsPerPixel
            else { return nil }
        
        self.mask = false
        self.width = width
        self.height = height
        self.bitsPerComponent = bitsPerComponent
        self.bitsPerPixel = bitsPerPixel
        self.bytesPerRow = bytesPerRow
        self.data = data
        self.shouldInterpolate = shouldInterpolate
        self.bitmapInfo = bitmapInfo
        self.colorspace = colorspace
        self.renderingIntent = renderingIntent
        self.crop = nil
        self.surfaceCache = nil
    }
    
    /// Creates a bitmap image using the data contained within a subregion of an existing bitmap image.
    ///
    /// - Parameter image: The image to extract the subimage from.
    ///
    /// - Parameter rect: A rectangle whose coordinates specify the area to create an image from.
    ///
    /// - Returns: An `Image` that specifies a subimage of the provided image. 
    /// If the `rect` parameter defines an area that is not in the image, returns `nil`.
    public convenience init?(image: Image, in rect: Rect) {
        
        self.init(width: image.width,
                     height: image.height,
                     bitsPerComponent: image.bitsPerComponent,
                     bitsPerPixel: image.bitsPerPixel,
                     bytesPerRow: image.bytesPerRow,
                     colorspace: image.colorspace,
                     bitmapInfo: image.bitmapInfo,
                     data: image.data,
                     shouldInterpolate: image.shouldInterpolate,
                     renderingIntent: image.renderingIntent)
        
        // set crop rect
        let sourceRect = Rect(x: 0, y: 0, width: Double(image.width), height: Double(image.height))
        self.crop = rect.integral.intersection(sourceRect)
        
        /// hold reference to original surface
        if let originalSurface = image.surfaceCache {
            
            self.surfaceCache = originalSurface
        }
    }
    
    // MARK: - Methods
    
    /// Generates a copy of the image.
    public var copy: Image {
        
        return Image(width: width,
                     height: height,
                     bitsPerComponent: bitsPerComponent,
                     bitsPerPixel: bitsPerPixel,
                     bytesPerRow: bytesPerRow,
                     colorspace: colorspace,
                     bitmapInfo: bitmapInfo,
                     data: data,
                     shouldInterpolate: shouldInterpolate,
                     renderingIntent: renderingIntent)!
    }
    
    public var surface: Cairo.Surface {
        
        // return existing surface
        if let surface = self.surfaceCache {
            
            return surface
        }
        
        // create new surface
        let inMemorySurface = Surface.Image(format: .argb32, width: Int(width), height: Int(height))!
        
        inMemorySurface.flush()
        
        // destination value
        //inMemorySurface.
        
        // cache and return value
        self.surfaceCache = inMemorySurface
        
        return inMemorySurface
    }
    
    internal var sourceRect: Rect {
        
        return crop ?? Rect(x: 0, y: 0, width: Double(width), height: Double(height))
    }
}
