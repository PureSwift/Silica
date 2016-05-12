//
//  CGRect.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/9/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica

public typealias CGRect = Silica.Rect

public extension CGRect {
    
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