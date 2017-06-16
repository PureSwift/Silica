//
//  Rect.swift
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

import struct Foundation.CGFloat
import struct Foundation.CGPoint
import struct Foundation.CGSize
import struct Foundation.CGRect

public extension CGRect {
    
#if os(Linux)
    
    public init(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        
        self.origin = CGPoint(x: x, y: y)
        self.size = CGSize(width: width, height: height)
    }
    
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
    
    /// Returns a rectangle with a positive width and height.
    public var standardized: CGRect {
        
        var rect = self
        
        if (rect.size.width < 0) {
            rect.origin.x += rect.size.width
            rect.size.width = -rect.size.width
        }
        
        if (rect.size.height < 0) {
            rect.origin.y += rect.size.height
            rect.size.height = -rect.size.height
        }
        
        return rect;
    }
    
    /// Returns the smallest rectangle that results from converting the source rectangle values to integers.
    public var integral: CGRect {
        
        var rect = self.standardized
        
        rect.size.width = ceil(rect.origin.x + rect.size.width)
        rect.size.height = ceil(rect.origin.y + rect.size.height)
        rect.origin.x = floor(rect.origin.x)
        rect.origin.y = floor(rect.origin.y)
        rect.size.width -= rect.origin.x
        rect.size.height -= rect.origin.y
        
        return rect;
    }
    
    /// Returns whether a rectangle has zero width or height, or is a null rectangle.
    public var isEmpty: Bool {
        
        return size.width == 0 || size.height == 0
    }
    
    // MARK: - Methods
    
    public func contains(_ point: CGPoint) -> Bool {
        
        return (point.x >= minX && point.x <= maxX)
            && (point.y >= minY && point.y <= maxY)
    }
    
    /// Returns the intersection of two rectangles.
    public func intersection(_ other: CGRect) -> CGRect? {
        
        var r1 = self
        var r2 = other
        
        var rect = CGRect()
        
        guard r1.isEmpty == false else { return r2 }
        guard r2.isEmpty == false else { return r1 }
        
        r1 = r1.standardized
        r2 = r2.standardized
        
        guard (r1.origin.x + r1.size.width <= r2.origin.x ||
            r2.origin.x + r2.size.width <= r1.origin.x ||
            r1.origin.y + r1.size.height <= r2.origin.y ||
            r2.origin.y + r2.size.height <= r1.origin.y) == false
            else { return nil }
        
        rect.origin.x = (r1.origin.x > r2.origin.x ? r1.origin.x : r2.origin.x)
        rect.origin.y = (r1.origin.y > r2.origin.y ? r1.origin.y : r2.origin.y)
        
        if (r1.origin.x + r1.size.width < r2.origin.x + r2.size.width) {
            rect.size.width = r1.origin.x + r1.size.width - rect.origin.x
        } else {
            rect.size.width = r2.origin.x + r2.size.width - rect.origin.x
        }
        
        
        if (r1.origin.y + r1.size.height < r2.origin.y + r2.size.height) {
            rect.size.height = r1.origin.y + r1.size.height - rect.origin.y
        } else {
            rect.size.height = r2.origin.y + r2.size.height - rect.origin.y
        }
        
        return rect;
    }

#endif
}
