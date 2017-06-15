//
//  LineCap.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/9/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Cairo
import CCairo

public enum CGLineCap: UInt32 {
    
    case butt
    case round
    case square
    
    public init() { self = .butt }
}

// MARK: - Cairo Conversion

extension CGLineCap: CairoConvertible {
    
    public typealias CairoType = cairo_line_cap_t
    
    public init(cairo: CairoType) {
        
        self.init(rawValue: cairo.rawValue)!
    }
    
    public func toCairo() -> CairoType {
        
        return CairoType(rawValue: rawValue)
    }
}
