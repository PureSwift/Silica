//
//  ColorSpace.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 6/2/17.
//
//

//import cLCMS

public final class ColorSpace {
    
    public let name: String
    
    private let profile: OpaquePointer
    
    public init() {
        
        fatalError()
    }
    
    public var numberOfComponents: Int {
        
        return 0 // _cmsChannelsOf(cmsGetColorSpace(profile))
    }
}

// MARK: - Singletons

public extension ColorSpace {
    
    static let genericGray: ColorSpace = ColorSpace()
    
    static let genericRGB: ColorSpace = ColorSpace()
}

// MARK: - Supporting Types

public extension ColorSpace {
    
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
