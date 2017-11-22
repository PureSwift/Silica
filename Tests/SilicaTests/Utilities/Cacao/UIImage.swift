//
//  UIImage.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 6/3/17.
//
//

import Foundation
import Silica

public final class UIImage {
    
    public let cgImage: Silica.CGImage
    
    public init(cgImage: Silica.CGImage) {
        
        self.cgImage = cgImage
    }
    
    public var size: CGSize {
        
        return CGSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
    }
}
