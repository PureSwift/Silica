//
//  CGPoint.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 6/16/17.
//

import struct Foundation.CGFloat
import struct Foundation.CGPoint

public extension CGPoint {
    
    init(x: Double, y: Double) {
        
        self.x = CGFloat(x)
        self.y = CGFloat(y)
    }
}
