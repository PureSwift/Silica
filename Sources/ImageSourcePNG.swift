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
        
        final class Reference<T> {
            
            var value: T?
        }
        
        let error = Reference<Error>()
        
        guard let pngStruct = png_create_read_struct(PNG_LIBPNG_VER_STRING, nil, pngErrorHandler, pngWarningHandler)
            else {  }
        
        
    }
}

// MARK: - Private Functions

// dont use directly with libpng
@inline(__always)
private func pngError(_ type: ImageSourcePNG.ErrorType, _ png_ptr: png_structp?, _ error_msg: png_const_charp?) {
    
    let message: String
    
    if let cString = error_msg {
        
        message = String(cString: cString)
        
    } else {
        
        message = ""
    }
    
    let error = ImageSourcePNG.Error(message: message, type: type)
    
    
}

private func pngErrorHandler(_ png_ptr: png_structp?, _ error_msg: png_const_charp?) {
    
    pngError(.fatal, png_ptr, error_msg)
}

private func pngWarningHandler(_ png_ptr: png_structp?, _ error_msg: png_const_charp?) {
    
    pngError(.warning, png_ptr, error_msg)
}

// MARK: - Supporting Types

public extension ImageSourcePNG {
    
    public struct Error: Swift.Error {
        
        public let message: String
        
        public let type: ErrorType
    }
    
    public enum ErrorType: Int {
        
        case warning
        case fatal
    }
}

