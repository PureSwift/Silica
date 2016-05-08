//
//  Geometry.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/8/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

/// A structure that contains a point in a two-dimensional coordinate system.
public struct Point {
    
    public var x: Double
    
    public var y: Double
    
    public init(x: Double = 0, y: Double = 0) {
        
        self.x = x
        self.y = y
    }
}

/// A structure that contains width and height values.
public struct Size {
    
    public var width: Double
    
    public var height: Double
    
    public init(width: Double = 0, height: Double = 0) {
        
        self.width = width
        self.height = height
    }
}

/// A structure that contains the location and dimensions of a rectangle.
public struct Rect {
    
    /// A point that specifies the coordinates of the rectangle’s origin.
    public var origin: Point
    
    /// A size that specifies the height and width of the rectangle.
    public var size: Size
    
    public init(origin: Point = Point(), size: Size = Size()) {
        
        self.origin = origin
        self.size = size
    }
}