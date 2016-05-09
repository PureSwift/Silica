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

// MARK: - Cairo Conversion

extension AffineTransform: CairoConvertible {
    
    public typealias CairoType = Cairo.Matrix
    
    public init(cairo matrix: CairoType) {
        
        self.init(a: matrix.xx, b: matrix.xy, c: matrix.yx, d: matrix.yy, t: (x: matrix.x0, y: matrix.y0))
    }
    
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
