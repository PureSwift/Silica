//
//  CGSize.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 6/16/17.
//

import struct Foundation.CGFloat
import struct Foundation.CGSize

#if os(Linux)
    public extension CGSize {
        
        #if swift(>=4)
        #elseif swift(>=3.0.2)
        public static var zero: CGSize { return CGSize() }
        #endif
    }
#endif
