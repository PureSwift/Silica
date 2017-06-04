//
//  ImageConversion.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 6/2/17.
//
//

import struct Foundation.Data
import Cairo
//import LittleCMS

internal extension Image {
    
    static func convert(sourceData: Data,
                        width: UInt,
                        height: UInt,
                        bitsPerComponent: (destination: UInt, source: UInt),
                        bitsPerPixel: (destination: UInt, source: UInt),
                        bytesPerRow: (destination: UInt, source: UInt),
                        bitmapInfo: (destination: BitmapInfo, source: BitmapInfo),
                        colorSpace: (destination: ColorSpace, source: ColorSpace),
                        renderingIntent: ColorRenderingIntent) -> Data {
        
        // get image format
        guard let sourceFormat = ImageFormat(bitsPerComponent: bitsPerComponent.source,
                                             bitsPerPixel: bitsPerPixel.source,
                                             bitmapInfo: bitmapInfo.source,
                                             colorspace: colorSpace.source)
            else { fatalError("Invalid source format") }
        
        guard let destinationFormat = ImageFormat(bitsPerComponent: bitsPerComponent.destination,
                                                  bitsPerPixel: bitsPerPixel.destination,
                                                  bitmapInfo: bitmapInfo.destination,
                                                  colorspace: colorSpace.destination)
            else { fatalError("Invalid destination format") }
        
        // no conversion if equal
        guard (bitsPerComponent.source == bitsPerComponent.destination
            && bitsPerPixel.source == bitsPerPixel.destination
            && bytesPerRow.source == bytesPerRow.destination
            && bitmapInfo.source == bitmapInfo.destination
            && colorSpace.source == colorSpace.destination) == false
            else { return sourceData }
        
        // transform data
        
        
        return Data()
    }
}

// MARK: - Supporting Types

fileprivate extension Image {
    
    enum ComponentFormat {
        
        case bpc8
        case bpc16
        case bpc32
        case bpcFloat32
    }
    
    struct ImageFormat {
        
        var componentFormat: ComponentFormat
        var colorComponents: UInt
        var hasAlpha: Bool
        var isAlphaPremultiplied: Bool
        var isAlphaLast: Bool
        var needs32Swap: Bool
        
        fileprivate init?(bitsPerComponent: UInt, bitsPerPixel: UInt, bitmapInfo: BitmapInfo, colorspace: ColorSpace) {
            
            switch bitsPerComponent {
            case 8: self.componentFormat = .bpc8
            case 16: self.componentFormat = .bpc16
            case 32: self.componentFormat = bitmapInfo.floatComponents ? .bpcFloat32 : .bpc32
            default: return nil
            }
            
            let actualComponents = bitsPerPixel / bitsPerComponent
            
            self.colorComponents = colorspace.numberOfComponents
            self.hasAlpha = bitmapInfo.alpha != .none && actualComponents > colorspace.numberOfComponents
            self.isAlphaPremultiplied = bitmapInfo.alpha == .premultipliedFirst || bitmapInfo.alpha == .premultipliedLast
            self.isAlphaLast = bitmapInfo.alpha == .premultipliedLast || bitmapInfo.alpha == .last
            self.needs32Swap = bitmapInfo.byteOrder == .little32
        }
    }
}
