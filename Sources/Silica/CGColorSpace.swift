//
//  ColorSpace.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 6/2/17.
//
//
/*
import struct Foundation.Data
import CLCMS
import LittleCMS

/// A profile that specifies how to interpret a color value for display.
public final class ColorSpace {
    
    // MARK: - Properties
    
    /// The underlying LittleCMS profile
    public let profile: LittleCMS.Profile
    
    // MARK: - Initialization
    
    public required init(profile: LittleCMS.Profile) {
        
        self.profile = profile
    }
    
    public init?(data: Data) {
        
        guard let profile = Profile(data: data)
            else { return nil }
        
        self.profile = profile
    }
    
    // MARK: - Accessors
    
    public var numberOfComponents: UInt {
        
        return profile.signature.numberOfComponents
    }
    
    public var model: Model {
        
        let signature = profile.signature
        
        switch signature {
            
        case cmsSigGrayData:
            return .monochrome
        case cmsSigRgbData:
            return .rgb
        case cmsSigCmykData:
            return .cmyk
        case cmsSigLabData:
            return .lab
        default:
            return .unknown
        }
    }
}

// MARK: - Singletons

public extension ColorSpace {
    
    /// Device-independent RGB color space.
    static let genericRGB: ColorSpace =  ColorSpace(profile: Profile(sRGB: nil)!)
}

// MARK: - Supporting Types

public extension ColorSpace {
    
    // CoreGraphics API
    
    /// Models for color spaces.
    public enum Model {
        
        /// An unknown color space model.
        case unknown
        
        /// A monochrome color space model.
        case monochrome
        
        /// An RGB color space model.
        case rgb
        
        /// A CMYK color space model.
        case cmyk
        
        /// A Lab color space model.
        case lab
        
        /// A DeviceN color space model.
        case deviceN
        
        /// An indexed color space model.
        case indexed
        
        /// A pattern color space model.
        case pattern
    }
}
*/
