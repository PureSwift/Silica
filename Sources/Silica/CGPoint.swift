//
//  CGPoint.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 6/16/17.
//

import struct Foundation.CGFloat
import struct Foundation.CGPoint

public extension CGPoint {
    
#if os(Linux)
    
    public static var zero: CGPoint { return CGPoint() }
    
#endif
    
}
