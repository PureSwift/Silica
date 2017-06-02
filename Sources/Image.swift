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
    
    public let width: Int
    
    public let height: Int
    
    public let bitsPerPixel: Int
    
    public let bytesPerRow: Int
    
    public let shouldInterpolate: Bool
    
    public let bitmapInfo: BitmapInfo
    
    // MARK: - Internal Properties
    
    internal let surface: Cairo.Surface
    
    init(width: Int,
         height: Int,
         bitsPerComponent: Int,
         bitsPerPixel: Int,
         bytesPerRow: Int,
         colorSpace: ColorSpace,
         bitmapInfo: BitmapInfo,
         data: Data,
         shouldInterpolate: Bool) {
        
        fatalError()
    }
}
