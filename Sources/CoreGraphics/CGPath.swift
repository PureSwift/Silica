//
//  CGPath.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/9/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica

public struct CGPathElement {
    
    public var type: CGPathElementType
    
    public var points: (CGPoint, CGPoint, CGPoint)
    
    public init(type: CGPathElementType, points: (CGPoint, CGPoint, CGPoint)) {
        
        self.type = type
        self.points = points
    }
}

/// The type of element found in a path.
public enum CGPathElementType {
    
    /// The path element that starts a new subpath. The element holds a single point for the destination.
    case MoveToPoint
    
    /// The path element that adds a line from the current point to a new point.
    /// The element holds a single point for the destination.
    case AddLineToPoint
    
    /// The path element that adds a quadratic curve from the current point to the specified point.
    /// The element holds a control point and a destination point.
    case AddQuadCurveToPoint
    
    /// The path element that adds a cubic curve from the current point to the specified point.
    /// The element holds two control points and a destination point.
    case AddCurveToPoint
    
    /// The path element that closes and completes a subpath. The element does not contain any points.
    case CloseSubpath
}

// MARK: - Silica Conversion

public extension CGPathElement {
    
    init(_ element: Silica.Path.Element) {
        
        switch element {
            
        case let .MoveToPoint(point):
            
            self.type = .MoveToPoint
            self.points = (point, CGPoint(), CGPoint())
            
        case let .AddLineToPoint(point):
            
            self.type = .AddLineToPoint
            self.points = (point, CGPoint(), CGPoint())
            
        case let .AddQuadCurveToPoint(control, destination):
            
            self.type = .AddQuadCurveToPoint
            self.points = (control, destination, CGPoint())
            
        case let .AddCurveToPoint(control1, control2, destination):
            
            self.type = .AddCurveToPoint
            self.points = (control1, control2, destination)
            
        case .CloseSubpath:
            
            self.type = .CloseSubpath
            self.points = (CGPoint(), CGPoint(), CGPoint())
        }
    }
}

public extension Silica.Path.Element {
    
    init(_ element: CGPathElement) {
        
        switch element.type {
            
        case .MoveToPoint: self = .MoveToPoint(element.points.0)
            
        case .AddLineToPoint: self = .AddLineToPoint(element.points.0)
            
        case .AddQuadCurveToPoint: self = .AddQuadCurveToPoint(element.points.0, element.points.1)
            
        case .AddCurveToPoint: self = .AddCurveToPoint(element.points.0, element.points.1, element.points.2)
            
        case .CloseSubpath: self = .CloseSubpath
        }
    }
}