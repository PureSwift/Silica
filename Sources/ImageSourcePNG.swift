//
//  ImageSourcePNG.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/11/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import struct Foundation.Data
import CPNG

public final class ImageSourcePNG: ImageSource {
    
    public static let typeIdentifier = "public.png"
    
    private let data: Data
    
    fileprivate var currentError = Error()
    
    public init?(data: Data) {
        
        let headerSize = 8
        
        // get first 8 bytes (file header)
        var bytes = Array(data[0 ..< headerSize])
        
        // check if data has PNG header
        guard png_sig_cmp(&bytes, 0, headerSize) == 0
            else { return nil }
        
        self.data = data
    }
    
    public func createImage(at index: Int) throws -> Image {
        
        // reset error
        currentError = Error()
        
        let unmanaged = Unmanaged.passUnretained(self)
        
        let objectPointer = unmanaged.toOpaque()
        
        var pngRead: png_structp? = nil
        var pngInfo: png_infop? = nil
        var pngEndInfo: png_infop? = nil
        
        defer { png_destroy_read_struct(&pngRead, &pngInfo, &pngEndInfo) }
        
        // create read handle
        pngRead = png_create_read_struct(PNG_LIBPNG_VER_STRING, objectPointer, pngErrorHandler, nil)
        
        guard pngRead != nil
            else { throw currentError }
        
        // get info
        pngInfo = png_create_info_struct(pngRead)
        
        guard pngInfo != nil
            else { throw currentError }
        
        // get info
        pngEndInfo = png_create_info_struct(pngRead)
        
        guard pngEndInfo != nil
            else { throw currentError }
        
        let width = png_get_image_width(pngRead, pngInfo)
        let height = Int(png_get_image_height(pngRead, pngInfo))
        let bytesPerRow = Int(png_get_rowbytes(pngRead, pngInfo))
        let type = CInt(png_get_color_type(pngRead, pngInfo))
        let channels = png_get_channels(pngRead, pngInfo) // includes alpha
        let depth = png_get_bit_depth(pngRead, pngInfo)
        
        let alpha: Bool
        let colorspace: ColorSpace
        
        switch CInt(type) {
            
        case PNG_COLOR_TYPE_GRAY_ALPHA:
            
            alpha = true
            colorspace = .genericGray
            
        case PNG_COLOR_TYPE_GRAY:
            
            alpha = false
            colorspace = .genericGray
            
        case PNG_COLOR_TYPE_RGB_ALPHA:
            
            alpha = true
            colorspace = .genericRGB
            
        case PNG_COLOR_TYPE_RGB:
            
            alpha = false
            colorspace = .genericRGB
            
        case PNG_COLOR_TYPE_PALETTE:
            
            png_set_palette_to_rgb(pngRead)
            
            if png_get_valid(pngRead, pngInfo, png_uint_32(PNG_INFO_tRNS)) != 0 {
                
                alpha = true
                png_set_tRNS_to_alpha(pngRead)
            }
            
            colorspace = .genericRGB
            
        default:
            
            alpha = false
            colorspace = .genericRGB
            
            throw currentError
        }
        
        let imageData = Data(count: height * bytesPerRow)
        
        
    }
}

// MARK: - Private Functions

// dont use directly with libpng
@inline(__always)
private func pngErrorHandler(_ png_ptr: png_structp?, _ error_msg: png_const_charp?) {
    
    let message: String
    
    if let cString = error_msg {
        
        message = String(cString: cString)
        
    } else {
        
        message = ""
    }
    
    // create error
    let error = ImageSourcePNG.Error(message: message)
    
    // get reference to image source
    let pointer = png_get_error_ptr(png_ptr)!
    
    let unmanaged = Unmanaged<ImageSourcePNG>.fromOpaque(pointer)
    
    let imageSource = unmanaged.takeUnretainedValue()
    
    // assign error to object
    imageSource.currentError = error
}

// MARK: - Supporting Types

public extension ImageSourcePNG {
    
    public struct Error: Swift.Error {
        
        public let message: String
        
        fileprivate init(message: String = "") {
            
            self.message = message
        }
    }
}

