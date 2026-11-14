//
//  CairoConvertible.swift
//  SilicaCairo
//
//  Created by Alsey Coleman Miller on 5/9/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

#if canImport(Cairo)

import Cairo
import CCairo
import Foundation
import Silica

public protocol CairoConvertible {

    associatedtype CairoType

    init(cairo: CairoType)

    func toCairo() -> CairoType
}

// MARK: - CGAffineTransform

extension CGAffineTransform: CairoConvertible {

    public typealias CairoType = Cairo.Matrix

    @inline(__always)
    public init(cairo matrix: CairoType) {

        // Cairo maps x' = xx·x + xy·y + x0 and y' = yx·x + yy·y + y0,
        // while CoreGraphics maps x' = a·x + c·y + tx and y' = b·x + d·y + ty.
        self.init(a: CGFloat(matrix.xx),
                  b: CGFloat(matrix.yx),
                  c: CGFloat(matrix.xy),
                  d: CGFloat(matrix.yy),
                  tx: CGFloat(matrix.x0),
                  ty: CGFloat(matrix.y0))
    }

    @inline(__always)
    public func toCairo() -> CairoType {

        var matrix = Matrix()

        matrix.xx = Double(a)
        matrix.xy = Double(c)
        matrix.yx = Double(b)
        matrix.yy = Double(d)
        matrix.x0 = Double(tx)
        matrix.y0 = Double(ty)

        return matrix
    }
}

// MARK: - CGLineCap

extension CGLineCap: CairoConvertible {

    public typealias CairoType = cairo_line_cap_t

    public init(cairo: CairoType) {

        self.init(rawValue: cairo.rawValue)!
    }

    public func toCairo() -> CairoType {

        return CairoType(rawValue: rawValue)
    }
}

// MARK: - CGLineJoin

extension CGLineJoin: CairoConvertible {

    public typealias CairoType = cairo_line_join_t

    public init(cairo: CairoType) {

        self.init(rawValue: cairo.rawValue)!
    }

    public func toCairo() -> CairoType {

        return CairoType(rawValue: rawValue)
    }
}

// MARK: - CGColor

internal extension Cairo.Pattern {

    convenience init(color: CGColor) {

        self.init(color: (Double(color.red),
                          Double(color.green),
                          Double(color.blue),
                          Double(color.alpha)))

        assert(status.rawValue == 0, "Error creating Cairo.Pattern from Silica.Color: \(status)")
    }
}

#endif
