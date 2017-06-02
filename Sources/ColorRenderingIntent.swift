//
//  ColorRenderingIntent.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 6/2/17.
//
//

/// The rendering intent specifies how Silica should handle colors
/// that are not located within the gamut of the destination color space of a graphics context. 
/// It determines the exact method used to map colors from one color space to another. 
///
/// If you do not explicitly set the rendering intent,
/// the graphics context uses the relative colorimetric rendering intent, 
/// except when drawing sampled images.
public enum ColorRenderingIntent {
    
    /// The default rendering intent for the graphics context.
    case `default`
    
    /// Map colors outside of the gamut of the output device 
    /// to the closest possible match inside the gamut of the output device. 
    /// This can produce a clipping effect, where two different color values
    /// in the gamut of the graphics context are mapped to the same color value 
    /// in the output device’s gamut. 
    ///
    /// Unlike the relative colorimetric, absolute colorimetric does not modify colors inside the gamut of the output device.
    case absoluteColorimetric
    
    /// Map colors outside of the gamut of the output device 
    /// to the closest possible match inside the gamut of the output device. 
    /// This can produce a clipping effect, where two different color values 
    /// in the gamut of the graphics context are mapped to the same color value
    /// in the output device’s gamut. 
    /// 
    /// The relative colorimetric shifts all colors (including those within the gamut) 
    /// to account for the difference between the white point of the graphics context 
    /// and the white point of the output device.
    case relativeColorimetric
    
    /// Preserve the visual relationship between colors by compressing the gamut of the graphics context
    /// to fit inside the gamut of the output device. 
    /// Perceptual intent is good for photographs and other complex, detailed images.
    case perceptual
    
    /// Preserve the relative saturation value of the colors when converting into the gamut of the output device. 
    /// The result is an image with bright, saturated colors. 
    /// Saturation intent is good for reproducing images with low detail, such as presentation charts and graphs.
    case saturation
}
