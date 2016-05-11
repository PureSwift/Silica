//
//  Path.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/8/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

public struct Path {
    
    public var elements: [Element]
}

// MARK: - Supporting Types

public extension Path {
    
    public struct Element {
        
        public var type: ElementType
        
        public var points: (Point, Point, Point)
        
        public init(type: ElementType, points: (Point, Point, Point)) {
            
            self.type = type
            self.points = points
        }
    }
}

/// The type of element found in a path.
public extension Path {
    
    public enum ElementType {
        
        case MoveToPoint
        case AddLineToPoint
        case AddQuadCurveToPoint
        case AddCurveToPoint
        case CloseSubpath
    }
}