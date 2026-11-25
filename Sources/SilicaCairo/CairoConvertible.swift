//
//  CairoConvertible.swift
//  SilicaCairo
//
//  Created by Alsey Coleman Miller on 1/31/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

#if canImport(Cairo)

import Cairo
import CCairo
import Foundation
import Silica

public extension AffineTransform {

    /// The transform of a Cairo matrix.
    init(cairo matrix: Cairo.Matrix) {
        // Cairo maps x' = xx·x + xy·y + x0 and y' = yx·x + yy·y + y0,
        // CoreGraphics x' = a·x + c·y + tx and y' = b·x + d·y + ty.
        self.init(a: matrix.xx, b: matrix.yx, c: matrix.xy, d: matrix.yy, tx: matrix.x0, ty: matrix.y0)
    }

    /// The transform as a Cairo matrix.
    func toCairo() -> Cairo.Matrix {
        var matrix = Matrix()
        matrix.xx = a
        matrix.xy = c
        matrix.yx = b
        matrix.yy = d
        matrix.x0 = tx
        matrix.y0 = ty
        return matrix
    }
}

internal extension LineCap {

    func toCairo() -> cairo_line_cap_t {
        switch self {
        case .butt: return CAIRO_LINE_CAP_BUTT
        case .round: return CAIRO_LINE_CAP_ROUND
        case .square: return CAIRO_LINE_CAP_SQUARE
        }
    }
}

internal extension LineJoin {

    func toCairo() -> cairo_line_join_t {
        switch self {
        case .miter: return CAIRO_LINE_JOIN_MITER
        case .round: return CAIRO_LINE_JOIN_ROUND
        case .bevel: return CAIRO_LINE_JOIN_BEVEL
        }
    }
}

internal extension FillRule {

    func toCairo() -> cairo_fill_rule_t {
        switch self {
        case .winding: return CAIRO_FILL_RULE_WINDING
        case .evenOdd: return CAIRO_FILL_RULE_EVEN_ODD
        }
    }
}

internal extension BlendMode {

    /// Cairo's operator for the mode. Plus darker has none, and draws as normal.
    func toCairo() -> cairo_operator_t {
        switch self {
        case .normal: return CAIRO_OPERATOR_OVER
        case .multiply: return CAIRO_OPERATOR_MULTIPLY
        case .screen: return CAIRO_OPERATOR_SCREEN
        case .overlay: return CAIRO_OPERATOR_OVERLAY
        case .darken: return CAIRO_OPERATOR_DARKEN
        case .lighten: return CAIRO_OPERATOR_LIGHTEN
        case .colorDodge: return CAIRO_OPERATOR_COLOR_DODGE
        case .colorBurn: return CAIRO_OPERATOR_COLOR_BURN
        case .softLight: return CAIRO_OPERATOR_SOFT_LIGHT
        case .hardLight: return CAIRO_OPERATOR_HARD_LIGHT
        case .difference: return CAIRO_OPERATOR_DIFFERENCE
        case .exclusion: return CAIRO_OPERATOR_EXCLUSION
        case .hue: return CAIRO_OPERATOR_HSL_HUE
        case .saturation: return CAIRO_OPERATOR_HSL_SATURATION
        case .color: return CAIRO_OPERATOR_HSL_COLOR
        case .luminosity: return CAIRO_OPERATOR_HSL_LUMINOSITY
        case .clear: return CAIRO_OPERATOR_CLEAR
        case .copy: return CAIRO_OPERATOR_SOURCE
        case .sourceIn: return CAIRO_OPERATOR_IN
        case .sourceOut: return CAIRO_OPERATOR_OUT
        case .sourceAtop: return CAIRO_OPERATOR_ATOP
        case .destinationOver: return CAIRO_OPERATOR_DEST_OVER
        case .destinationIn: return CAIRO_OPERATOR_DEST_IN
        case .destinationOut: return CAIRO_OPERATOR_DEST_OUT
        case .destinationAtop: return CAIRO_OPERATOR_DEST_ATOP
        case .xor: return CAIRO_OPERATOR_XOR
        case .plusDarker: return CAIRO_OPERATOR_OVER
        case .plusLighter: return CAIRO_OPERATOR_ADD
        }
    }
}

internal extension Cairo.Pattern {

    convenience init(color: Color) {
        self.init(color: (color.red, color.green, color.blue, color.alpha))
    }
}

#endif
