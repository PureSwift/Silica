//
//  CGPath.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/9/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

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
    case moveToPoint
    
    /// The path element that adds a line from the current point to a new point.
    /// The element holds a single point for the destination.
    case addLineToPoint
    
    /// The path element that adds a quadratic curve from the current point to the specified point.
    /// The element holds a control point and a destination point.
    case addQuadCurveToPoint
    
    /// The path element that adds a cubic curve from the current point to the specified point.
    /// The element holds two control points and a destination point.
    case addCurveToPoint
    
    /// The path element that closes and completes a subpath. The element does not contain any points.
    case closeSubpath
}

// MARK: - Silica Conversion

public extension CGPathElement {
    
    init(_ element: Silica.Path.Element) {
        
        switch element {
            
        case let .moveToPoint(point):
            
            self.type = .moveToPoint
            self.points = (point, CGPoint(), CGPoint())
            
        case let .addLineToPoint(point):
            
            self.type = .addLineToPoint
            self.points = (point, CGPoint(), CGPoint())
            
        case let .addQuadCurveToPoint(control, destination):
            
            self.type = .addQuadCurveToPoint
            self.points = (control, destination, CGPoint())
            
        case let .addCurveToPoint(control1, control2, destination):
            
            self.type = .addCurveToPoint
            self.points = (control1, control2, destination)
            
        case .closeSubpath:
            
            self.type = .closeSubpath
            self.points = (CGPoint(), CGPoint(), CGPoint())
        }
    }
}

public extension Silica.Path.Element {
    
    init(_ element: CGPathElement) {
        
        switch element.type {
            
        case .moveToPoint: self = .moveToPoint(element.points.0)
            
        case .addLineToPoint: self = .addLineToPoint(element.points.0)
            
        case .addQuadCurveToPoint: self = .addQuadCurveToPoint(element.points.0, element.points.1)
            
        case .addCurveToPoint: self = .addCurveToPoint(element.points.0, element.points.1, element.points.2)
            
        case .closeSubpath: self = .closeSubpath
        }
    }
}
