//
//  Rect.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/10/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

/// A structure that contains the location and dimensions of a rectangle.
public struct Rect: Equatable {
    
    // MARK: - Properties
    
    /// A point that specifies the coordinates of the rectangle’s origin.
    public var origin: Point
    
    /// A size that specifies the height and width of the rectangle.
    public var size: Size
    
    // MARK: - Initialization
    
    public init(origin: Point = Point(), size: Size = Size()) {
        
        self.origin = origin
        self.size = size
    }
    
    public init(x: Double, y: Double, width: Double, height: Double) {
        
        self.origin = Point(x: x, y: y)
        self.size = Size(width: width, height: height)
    }
    
    // MARK: - Accessors
    
    public var x: Double {
        
        get { return origin.x }
        
        set { origin.x = newValue }
    }
    
    public var y: Double {
        
        get { return origin.y }
        
        set { origin.y = newValue }
    }
    
    public var width: Double {
        
        get { return size.width }
        
        set { size.width = newValue }
    }
    
    public var height: Double {
        
        get { return size.height }
        
        set { size.height = newValue }
    }
    
    public var minX: Double {
        
        return (size.width < 0) ? origin.x + size.width : origin.x
    }
    
    public var midX: Double {
        
        return origin.x + (size.width / 2.0)
    }
    
    public var maxX: Double {
        
        return (size.width < 0) ? origin.x : origin.x + size.width
    }
    
    public var minY: Double {
        
        return (size.height < 0) ? origin.y + size.height : origin.y
    }
    
    public var midY: Double {
        
        return origin.y + (size.height / 2.0)
    }
    
    public var maxY: Double {
        
        return (size.height < 0) ? origin.y : origin.y + size.height
    }
    
    // MARK: - Methods
    
    public func contains(_ point: Point) -> Bool {
        
        return (point.x >= minX && point.x <= maxX)
            && (point.y >= minY && point.y <= maxY)
    }
}

// MARK: - Equatable

public func == (lhs: Rect, rhs: Rect) -> Bool {
    
    return lhs.origin == rhs.origin && lhs.size == rhs.size
}
