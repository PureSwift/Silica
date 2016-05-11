//
//  Point.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/10/16.
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