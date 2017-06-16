//
//  CGSize.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 6/16/17.
//

import struct Foundation.CGFloat
import struct Foundation.CGSize

public extension CGSize {
    
#if os(Linux)
    
    public static var zero: CGSize { return CGSize() }
    
#endif

}
