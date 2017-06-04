//
//  ImageSourcePNG.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/11/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

#if os(macOS)
    import Darwin.C.math
#elseif os(Linux)
    import Glibc
#endif

import struct Foundation.Data
import CPNG

public final class ImageSourcePNG: ImageSource {
    
    // MARK: - Class Properties
    
    public static let typeIdentifier = "public.png"
    
    public static var warning: (String) -> () = { debugPrint("ImageSourcePNG Warning: " + $0) }
    
     // MARK: - Properties
    
    public let data: Data
    
    private var currentPosition = 0
    
    // MARK: - Initialization
    
    public init?(data: Data) {
        
        let headerSize = 8
        
        // get first 8 bytes (file header)
        var bytes = Array(data[0 ..< headerSize])
        
        // check if data has PNG header
        guard png_sig_cmp(&bytes, 0, headerSize) == 0
            else { return nil }
        
        self.data = data
    }
    
    // MARK: - Methods
    
    public func createImage(at index: Int) -> Image? {
        
        var pngRead: png_structp? = nil
        var pngInfo: png_infop? = nil
        var pngEndInfo: png_infop? = nil
        
        defer { png_destroy_read_struct(&pngRead, &pngInfo, &pngEndInfo) }
        
        // create read handle
        pngRead = png_create_read_struct(PNG_LIBPNG_VER_STRING, nil, pngFatalError, pngWarning)
        
        guard pngRead != nil
            else { return nil }
        
        // get info
        pngInfo = png_create_info_struct(pngRead)
        
        guard pngInfo != nil
            else { return nil }
        
        // get info
        pngEndInfo = png_create_info_struct(pngRead)
        
        guard pngEndInfo != nil
            else { return nil }
        
        let dataProvider = DataProvider(data: data)
        
        let unmanaged = Unmanaged.passUnretained(dataProvider)
        
        let objectPointer = unmanaged.toOpaque()
        
        png_set_read_fn(pngRead, objectPointer, pngReader)
        
        png_read_info(pngRead, pngInfo);
        
        let width = UInt(png_get_image_width(pngRead, pngInfo))
        let height = UInt(png_get_image_height(pngRead, pngInfo))
        let bytesPerRow = UInt(png_get_rowbytes(pngRead, pngInfo))
        let type = CInt(png_get_color_type(pngRead, pngInfo))
        let channels = UInt(png_get_channels(pngRead, pngInfo)) // includes alpha
        let depth = UInt(png_get_bit_depth(pngRead, pngInfo))
        
        let alpha: Bool
        let colorspace: ColorSpace
        
        switch type {
            
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
                
            } else {
                
                alpha = false
            }
            
            colorspace = .genericRGB
            
        default:
            
            // just to satisfy compiler
            alpha = false
            colorspace = .genericRGB
            
            // invalid image
            return nil
        }
        
        // create row buffer bound to image data
        
        var imageData = Data(count: Int(height * bytesPerRow))
        
        let rowPointers = png_bytepp.allocate(capacity: Int(height))
        
        // only dealloc list of pointers, the individual pointers are managed by `Data`
        defer { rowPointers.deallocate(capacity: Int(height)) }
        
        imageData.withUnsafeMutableBytes { (mutableBytes: UnsafeMutablePointer<png_byte>) in
            
            for index in 0 ..< Int(height) {
                
                let offset = index * Int(bytesPerRow)
                
                let rowBuffer = mutableBytes.advanced(by: offset)
                
                rowPointers[index] = rowBuffer
            }
        }
        
        png_read_image(pngRead, rowPointers)
        
        // generate bitmap info
        let bitmapInfo = BitmapInfo(floatComponents: false, alpha: alpha ? .last : .none, byteOrder: .default)
        
        // create image
        let image = Image(width: width,
                          height: height,
                          bitsPerComponent: depth,
                          bitsPerPixel: channels * depth,
                          bytesPerRow: bytesPerRow,
                          colorspace: colorspace,
                          bitmapInfo: bitmapInfo,
                          data: imageData as Data,
                          shouldInterpolate: true,
                          renderingIntent: .default)
        
        return image
    }
}

// MARK: - Supporting Types

private extension ImageSourcePNG {
    
    final class DataProvider {
        
        let data: Data
        private(set) var position: Int
        
        init(data: Data) {
            self.data = data
            self.position = 0
        }
        
        func copyBytes(to pointer: UnsafeMutablePointer<UInt8>, length: Int) {
            
            var size = length
            
            if (position + size) > data.count {
                
                size = data.count - position;
            }
            
            let byteRange = Range<Data.Index>(position ..< position + size)
            
            let _ = data.copyBytes(to: pointer, from: byteRange)
            
            position += size
        }
    }
}

// MARK: - Private Functions

@inline(__always)
private func pngString(_ msg: png_const_charp?) -> String {
    
    let message: String
    
    if let cString = msg {
        
        message = String(cString: cString)
        
    } else {
        
        message = ""
    }
    
    return message
}

private func pngFatalError(_ png_ptr: png_structp?, _ error_msg: png_const_charp?) {
    
    let message = pngString(error_msg)
    
    fatalError("libpng error: " + message)
}

private func pngWarning(_ png_ptr: png_structp?, _ error_msg: png_const_charp?) {
    
    let message = pngString(error_msg)
    
    ImageSourcePNG.warning(message)
}

private func pngReader(_ pngRead: png_structp?, _ dataPointer: png_bytep?, _ length: png_size_t) {
    
    let userPointer = png_get_io_ptr(pngRead)!
    
    let unmanaged = Unmanaged<ImageSourcePNG.DataProvider>.fromOpaque(userPointer)
    
    let dataProvider = unmanaged.takeUnretainedValue()
    
    dataProvider.copyBytes(to: dataPointer!, length: length)
}
