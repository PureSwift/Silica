//
//  AffineTransform.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/8/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Cairo
import CCairo
import struct Foundation.CGFloat
import struct Foundation.CGPoint
import struct Foundation.CGSize
import struct Foundation.CGRect

/// Affine Transform
public struct CGAffineTransform {
    
    // MARK: - Properties
    
    public var a, b, c, d: CGFloat
    
    public var t: (x: CGFloat, y: CGFloat)
    
    // MARK: - Initialization
    
    public init(a: CGFloat, b: CGFloat, c: CGFloat, d: CGFloat, t: (x: CGFloat, y: CGFloat)) {
        
        self.a = a
        self.b = b
        self.c = c
        self.d = d
        self.t = t
    }
    
    init(a: CGFloat, b: CGFloat, c: CGFloat, d: CGFloat, tx: CGFloat, ty: CGFloat) {
        
        self.init(a: a, b: b, c: c, d: d, t: (tx, ty))
    }
    
    public static let identity = CGAffineTransform(a: 1, b: 0, c: 0, d: 1, t: (x: 0, y: 0))
}

// MARK: - Geometry Math

// Immutable math

public protocol CGAffineTransformMath {
    
    func applying(_ transform: CGAffineTransform) -> Self
}

// Mutable versions

public extension CGAffineTransformMath {
    
    @inline(__always)
    mutating func apply(_ transform: CGAffineTransform) {
        
        self = self.applying(transform)
    }
}

// Implementations

extension CGPoint: CGAffineTransformMath {
    
    @inline(__always)
    public func applying(_ t: CGAffineTransform) -> CGPoint {
        
        return CGPoint(x: t.a * x + t.c * y + t.t.x,
                       y: t.b * x + t.d * y + t.t.y)
    }
}

extension CGSize: CGAffineTransformMath {
    
    @inline(__always)
    public func applying( _ transform: CGAffineTransform) -> CGSize  {
        
        var newSize = CGSize(width:  transform.a * width + transform.c * height,
                             height: transform.b * width + transform.d * height)
        
        if newSize.width < 0 { newSize.width = -newSize.width }
        if newSize.height < 0 { newSize.height = -newSize.height }
        
        return newSize
    }
}

// MARK: - Cairo Conversion

extension CGAffineTransform: CairoConvertible {
    
    public typealias CairoType = Cairo.Matrix
    
    @inline(__always)
    public init(cairo matrix: CairoType) {
        
        self.init(a: CGFloat(matrix.xx),
                  b: CGFloat(matrix.xy),
                  c: CGFloat(matrix.yx),
                  d: CGFloat(matrix.yy),
                  t: (x: CGFloat(matrix.x0), y: CGFloat(matrix.y0)))
    }
    
    @inline(__always)
    public func toCairo() -> CairoType {
        
        var matrix = Matrix()
        
        matrix.xx = Double(a)
        matrix.xy = Double(b)
        matrix.yx = Double(c)
        matrix.yy = Double(d)
        matrix.x0 = Double(t.x)
        matrix.y0 = Double(t.y)
        
        return matrix
    }
}
