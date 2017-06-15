//
//  LineJoin.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/9/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Cairo
import CCairo

public enum CGLineJoin: UInt32 {
    
    case miter
    case round
    case bevel
    
    public init() { self = .miter }
}

// MARK: - Cairo Conversion

extension CGLineJoin: CairoConvertible {
    
    public typealias CairoType = cairo_line_join_t
    
    public init(cairo: CairoType) {
        
        self.init(rawValue: cairo.rawValue)!
    }
    
    public func toCairo() -> CairoType {
        
        return CairoType(rawValue: rawValue)
    }
}
