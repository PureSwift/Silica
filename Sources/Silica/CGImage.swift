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
public final class CGImage {
    
    // MARK: - Properties
    
    public var width: Int {
        
        return surface.width
    }
    
    public var height: Int {
        
        return surface.height
    }
    
    /// The cached Cairo surface for this image.
    internal let surface: Cairo.Surface.Image
    
    // MARK: - Initialization
    
    internal init(surface: Cairo.Surface.Image) {
        
        self.surface = surface
    }
}
