//
//  Rect.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/10/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

/// A structure that contains the location and dimensions of a rectangle.
public struct Rect: Equatable {
    
    /// A point that specifies the coordinates of the rectangle’s origin.
    public var origin: Point
    
    /// A size that specifies the height and width of the rectangle.
    public var size: Size
    
    public init(origin: Point = Point(), size: Size = Size()) {
        
        self.origin = origin
        self.size = size
    }
}

public func == (lhs: Rect, rhs: Rect) -> Bool {
    
    return lhs.origin == rhs.origin && lhs.size == rhs.size
}