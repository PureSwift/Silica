//
//  Path.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/8/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import CCairo

/// A graphics path is a mathematical description of a series of shapes or lines.
public struct Path {
    
    public var elements: [Element]
    
    public init(elements: [Element] = []) {
        
        self.elements = elements
    }
}

// MARK: - Supporting Types

public extension Path {
    
    /// A path element.
    public enum Element {
        
        /// The path element that starts a new subpath. The element holds a single point for the destination.
        case MoveToPoint(Point)
        
        /// The path element that adds a line from the current point to a new point.
        /// The element holds a single point for the destination.
        case AddLineToPoint(Point)
        
        /// The path element that adds a quadratic curve from the current point to the specified point.
        /// The element holds a control point and a destination point.
        case AddQuadCurveToPoint(Point, Point)
        
        /// The path element that adds a cubic curve from the current point to the specified point.
        /// The element holds two control points and a destination point.
        case AddCurveToPoint(Point, Point, Point)
        
        /// The path element that closes and completes a subpath. The element does not contain any points.
        case CloseSubpath
    }
}

// MARK: - Extensions

public extension Path {
    
    mutating func add(rect: Rect) {
        
        let newElements: [Element] = [.MoveToPoint(Point(x: rect.minX, y: rect.minY)),
                                      .AddLineToPoint(Point(x: rect.maxX, y: rect.minY)),
                                      .AddLineToPoint(Point(x: rect.maxX, y: rect.maxY)),
                                      .AddLineToPoint(Point(x: rect.minX, y: rect.maxY)),
                                      .CloseSubpath]
        
        self.elements.append(contentsOf: newElements)
    }
}
