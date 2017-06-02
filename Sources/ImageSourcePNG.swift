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
    
    fileprivate var currentError: Error?
    
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
        currentError = nil
        
        let unmanaged = Unmanaged.passUnretained(self)
        
        let pointer = unmanaged.toOpaque()
        
        guard var pngRead = png_create_read_struct(PNG_LIBPNG_VER_STRING, pointer, pngErrorHandler, nil)
            else { throw currentError! }
        
        guard var pngInfo = png_create_info_struct(pngRead)
            else { png_destroy_read_struct(&pngRead, nil, nil); }
        
        defer { png_destroy_read_struct(&pngRead, &pngInfo, nil) }
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
    }
}

