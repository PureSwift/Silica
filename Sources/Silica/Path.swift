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
    
    public typealias Element = PathElement
    
    public var elements: [Element]
    
    public init(elements: [Element] = []) {
        
        self.elements = elements
    }
}

// MARK: - Supporting Types

/// A path element.
public enum PathElement {
    
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

// MARK: - Extensions

public extension Path {
    
    mutating func add(rect: Rect) {
        
        let newElements: [Element] = [.MoveToPoint(Point(x: rect.minX, y: rect.minY)),
                                      .AddLineToPoint(Point(x: rect.maxX, y: rect.minY)),
                                      .AddLineToPoint(Point(x: rect.maxX, y: rect.maxY)),
                                      .AddLineToPoint(Point(x: rect.minX, y: rect.maxY)),
                                      .CloseSubpath]
        
        elements.append(contentsOf: newElements)
    }
    
    mutating func add(ellipseInRect rect: Rect) {
        
        var p = Point()
        var p1 = Point()
        var p2 = Point()
        
        let hdiff = rect.width / 2 * KAPPA
        let vdiff = rect.height / 2 * KAPPA
        
        p = Point(x: rect.origin.x + rect.width / 2, y: rect.origin.y + rect.height)
        elements.append(.MoveToPoint(p))
        
        p = Point(x: rect.origin.x, y: rect.origin.y + rect.height / 2)
        p1 = Point(x: rect.origin.x + rect.width / 2 - hdiff, y: rect.origin.y + rect.height)
        p2 = Point(x: rect.origin.x, y: rect.origin.y + rect.height / 2 + vdiff)
        elements.append(.AddCurveToPoint(p1, p2, p))
        
        p = Point(x: rect.origin.x + rect.size.width / 2, y: rect.origin.y)
        p1 = Point(x: rect.origin.x, y: rect.origin.y + rect.size.height / 2 - vdiff)
        p2 = Point(x: rect.origin.x + rect.size.width / 2 - hdiff, y: rect.origin.y)
        elements.append(.AddCurveToPoint(p1, p2, p))
        
        p = Point(x: rect.origin.x + rect.size.width, y: rect.origin.y + rect.size.height / 2)
        p1 = Point(x: rect.origin.x + rect.size.width / 2 + hdiff, y: rect.origin.y)
        p2 = Point(x: rect.origin.x + rect.size.width, y: rect.origin.y + rect.size.height / 2 - vdiff)
        elements.append(.AddCurveToPoint(p1, p2, p))
        
        p = Point(x: rect.origin.x + rect.size.width / 2, y: rect.origin.y + rect.size.height)
        p1 = Point(x: rect.origin.x + rect.size.width, y: rect.origin.y + rect.size.height / 2 + vdiff)
        p2 = Point(x: rect.origin.x + rect.size.width / 2 + hdiff, y: rect.origin.y + rect.size.height)
        elements.append(.AddCurveToPoint(p1, p2, p))
    }
}

// This magic number is 4 *(sqrt(2) -1)/3
private let KAPPA = 0.5522847498
