//
//  CGPoint.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 6/16/17.
//

import struct Foundation.CGFloat
import struct Foundation.CGPoint

#if os(Linux)
public extension CGPoint {
    
    #if swift(>=4)
    #elseif swift(>=3.0.2)
    public static var zero: CGPoint { return CGPoint() }
    #endif
}
#endif
