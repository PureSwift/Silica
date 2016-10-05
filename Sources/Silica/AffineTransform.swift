//
//  AffineTransform.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/8/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Cairo
import CCairo

public struct AffineTransform {
    
    // MARK: - Properties
    
    public var a, b, c, d: Double
    
    public var t: (x: Double, y: Double)
    
    // MARK: - Initialization
    
    public init(a: Double, b: Double, c: Double, d: Double, t: (x: Double, y: Double)) {
        
        self.a = a
        self.b = b
        self.c = c
        self.d = d
        self.t = t
    }
    
    public static let identity = AffineTransform(a: 1, b: 0, c: 0, d: 1, t: (x: 0, y: 0))
}

// MARK: - Geometry Math

// Immutable math

public protocol AffineTransformMath {
    
    func applying(_ transform: AffineTransform) -> Self
}

// Mutable versions

public extension AffineTransformMath {
    
    @inline(__always)
    mutating func apply(_ transform: AffineTransform) {
        
        self = self.applying(transform)
    }
}

// Implementations

extension Point: AffineTransformMath {
    
    @inline(__always)
    public func applying(_ t: AffineTransform) -> Point {
        
        return Point(x: t.a * x + t.c * y + t.t.x, y: t.b * x + t.d * y + t.t.y)
    }
}

extension Size: AffineTransformMath {
    
    @inline(__always)
    public func applying( _ transform: AffineTransform) -> Size  {
        
        var newSize = Size(width:  transform.a * width + transform.c * height, height: transform.b * width + transform.d * height)
        
        if newSize.width < 0 { newSize.width = -newSize.width }
        if newSize.height < 0 { newSize.height = -newSize.height }
        
        return newSize
    }
}

// MARK: - Cairo Conversion

extension AffineTransform: CairoConvertible {
    
    public typealias CairoType = Cairo.Matrix
    
    @inline(__always)
    public init(cairo matrix: CairoType) {
        
        self.init(a: matrix.xx, b: matrix.xy, c: matrix.yx, d: matrix.yy, t: (x: matrix.x0, y: matrix.y0))
    }
    
    @inline(__always)
    public func toCairo() -> CairoType {
        
        var matrix = Matrix()
        
        matrix.xx = a
        matrix.xy = b
        matrix.yx = c
        matrix.yy = d
        matrix.x0 = t.x
        matrix.y0 = t.y
        
        return matrix
    }
}
