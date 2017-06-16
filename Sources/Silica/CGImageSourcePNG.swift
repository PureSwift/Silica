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
import Cairo

public final class CGImageSourcePNG: CGImageSource {
    
    // MARK: - Class Properties
    
    public static let typeIdentifier = "public.png"
        
     // MARK: - Properties
    
    public let surface: Cairo.Surface.Image
    
    // MARK: - Initialization
    
    public init?(data: Data) {
        
        guard let surface = try? Cairo.Surface.Image(png: data)
            else { return nil }
        
        self.surface = surface
    }
    
    // MARK: - Methods
    
    public func createImage(at index: Int) -> CGImage? {
        
        let image = CGImage(surface: surface)
        
        return image
    }
}
