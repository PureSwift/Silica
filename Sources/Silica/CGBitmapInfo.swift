//
//  BitmapInfo.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/11/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

/// Component information for a bitmap image.
///
/// Applications that store pixel data in memory using ARGB format must take care in how they read data. 
/// If the code is not written correctly, it’s possible to misread the data which leads to colors or alpha that appear wrong.
/// The byte order constants specify the byte ordering of pixel formats.
public struct CGBitmapInfo {
    
    /// The components of a bitmap are floating-point values.
    public var floatComponents: Bool
    
    /// Alpha information that specifies whether a bitmap contains an alpha channel
    /// and how the alpha channel is generated.
    public var alpha: Alpha
    
    /// /// The byte ordering of pixel formats.
    public var byteOrder: ByteOrder
    
    public init(floatComponents: Bool = false, alpha: Alpha = .none, byteOrder: ByteOrder = .default) {
        
        self.floatComponents = floatComponents
        self.alpha = alpha
        self.byteOrder = byteOrder
    }
}

// MARK: - Equatable

extension CGBitmapInfo: Equatable {
    
    public static func == (lhs: CGBitmapInfo, rhs: CGBitmapInfo) -> Bool {
        
        return lhs.floatComponents == rhs.floatComponents
            && lhs.alpha == rhs.alpha
            && lhs.byteOrder == rhs.byteOrder
    }
}

// MARK: - Supporting Types

public extension CGBitmapInfo {
    
    /// Alpha information that specifies whether a bitmap contains an alpha channel
    /// and how the alpha channel is generated.
    ///
    /// Specifies (1) whether a bitmap contains an alpha channel,
    /// (2) where the alpha bits are located in the image data, 
    /// and (3) whether the alpha value is premultiplied.
    ///
    /// Alpha blending is accomplished by combining the color components of the source image
    /// with the color components of the destination image using the linear interpolation formula,
    /// where “source” is one color component of one pixel of the new paint 
    /// and “destination” is one color component of the background image.
    ///
    /// - Note: Silica supports premultiplied alpha only for images.
    /// You should not premultiply any other color values specified in Silica.
    enum Alpha {
        
        /// There is no alpha channel.
        case none
        
        /// The alpha component is stored in the least significant bits of each pixel and the color components
        /// have already been multiplied by this alpha value. For example, premultiplied RGBA.
        case premultipliedLast
        
        /// The alpha component is stored in the most significant bits of each pixel and the color components
        /// have already been multiplied by this alpha value. For example, premultiplied ARGB.
        case premultipliedFirst
        
        /// The alpha component is stored in the least significant bits of each pixel. For example, non-premultiplied RGBA.
        case last
        
        /// The alpha component is stored in the most significant bits of each pixel. For example, non-premultiplied ARGB.
        case first
        
        /// There is no alpha channel.
        case noneSkipLast
        
        /// There is no alpha channel. 
        /// If the total size of the pixel is greater than the space required for the number of color components 
        /// in the color space, the most significant bits are ignored.
        case noneSkipFirst
        
        /// There is no color data, only an alpha channel.
        case alphaOnly
    }
    
    /// The byte ordering of pixel formats.
    enum ByteOrder {
        
        /// The default byte order.
        case `default`
        
        /// 16-bit, big endian format.
        case big16
        
        /// 16-bit, little endian format.
        case little16
        
        /// 32-bit, big endian format.
        case big32
        
        /// 32-bit, little endian format.
        case little32
    }
}

