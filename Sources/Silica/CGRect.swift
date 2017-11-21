//
//  CGRect.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/10/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

#if os(macOS)
    import Darwin.C.math
#elseif os(Linux)
    import Glibc
#endif

import Foundation

#if os(Linux)
public extension CGRect {
    
    // MARK: - Accessors
    
    public var x: CGFloat {
        
        get { return origin.x }
        
        set { origin.x = newValue }
    }
    
    public var y: CGFloat {
        
        get { return origin.y }
        
        set { origin.y = newValue }
    }
    
    public var width: CGFloat {
        
        get { return size.width }
        
        set { size.width = newValue }
    }
    
    public var height: CGFloat {
        
        get { return size.height }
        
        set { size.height = newValue }
    }
    
    public var minX: CGFloat {
        
        return (size.width < 0) ? origin.x + size.width : origin.x
    }
    
    public var midX: CGFloat {
        
        return origin.x + (size.width / 2.0)
    }
    
    public var maxX: CGFloat {
        
        return (size.width < 0) ? origin.x : origin.x + size.width
    }
    
    public var minY: CGFloat {
        
        return (size.height < 0) ? origin.y + size.height : origin.y
    }
    
    public var midY: CGFloat {
        
        return origin.y + (size.height / 2.0)
    }
    
    public var maxY: CGFloat {
        
        return (size.height < 0) ? origin.y : origin.y + size.height
    }
}
#endif

