//
//  UIImage.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 6/3/17.
//
//

import Silica

public final class UIImage {
    
    public let cgImage: CGImage
    
    public init(cgImage: CGImage) {
        
        self.cgImage = cgImage
    }
    
    public var size: CGSize {
        
        return Size(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
    }
}
