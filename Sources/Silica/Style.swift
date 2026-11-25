//
//  Style.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 11/25/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

/// The shape at the ends of a stroked line.
@frozen
public enum LineCap: UInt8, Sendable {
    case butt
    case round
    case square
}

/// The shape where stroked lines meet.
@frozen
public enum LineJoin: UInt8, Sendable {
    case miter
    case round
    case bevel
}

/// Which regions a path encloses, for filling and clipping.
@frozen
public enum FillRule: UInt8, Sendable {

    /// Inside where the winding number is not zero.
    case winding

    /// Inside where a line from the point crosses the path an odd number of times.
    case evenOdd
}

/// How a path is painted.
@frozen
public enum DrawingMode: UInt8, Sendable {
    case fill
    case evenOddFill
    case stroke
    case fillStroke
    case evenOddFillStroke
}

/// How glyphs are painted.
@frozen
public enum TextDrawingMode: UInt8, Sendable {
    case fill
    case stroke
    case fillStroke
    case invisible
    case fillClip
    case strokeClip
    case fillStrokeClip
    case clip
}

/// How what's drawn combines with what's there, in CoreGraphics' order.
/// A mode a renderer can't do draws as `normal`.
@frozen
public enum BlendMode: UInt8, Sendable {
    case normal
    case multiply
    case screen
    case overlay
    case darken
    case lighten
    case colorDodge
    case colorBurn
    case softLight
    case hardLight
    case difference
    case exclusion
    case hue
    case saturation
    case color
    case luminosity
    case clear
    case copy
    case sourceIn
    case sourceOut
    case sourceAtop
    case destinationOver
    case destinationIn
    case destinationOut
    case destinationAtop
    case xor
    case plusDarker
    case plusLighter
}

/// How images are sampled when they're scaled.
@frozen
public enum InterpolationQuality: UInt8, Sendable {
    /// The renderer's choice: smooth.
    case `default`
    /// The nearest pixel: sharp edges, as pixel art wants.
    case none
    case low
    case medium
    case high
}

/// How a path is stroked.
public struct StrokeStyle: Equatable, Hashable, Sendable {

    public var lineWidth: Double

    public var lineCap: LineCap

    public var lineJoin: LineJoin

    public var miterLimit: Double

    /// Lengths of dashes and gaps, alternating. Empty for a solid line.
    public var dash: [Double]

    /// How far into the dash pattern the line starts.
    public var dashPhase: Double

    public init(lineWidth: Double = 1, lineCap: LineCap = .butt, lineJoin: LineJoin = .miter,
                miterLimit: Double = 10, dash: [Double] = [], dashPhase: Double = 0) {
        self.lineWidth = lineWidth
        self.lineCap = lineCap
        self.lineJoin = lineJoin
        self.miterLimit = miterLimit
        self.dash = dash
        self.dashPhase = dashPhase
    }
}

/// A shadow cast by what's drawn.
public struct Shadow: Equatable, Hashable, Sendable {

    /// The offset in the context's base space, unaffected by its transform:
    /// positive y is down.
    public var offset: Size

    /// The blur radius. Renderers that can't blur draw a sharp silhouette.
    public var blur: Double

    public var color: Color

    public init(offset: Size, blur: Double, color: Color = Color(white: 0, alpha: 1.0 / 3.0)) {
        self.offset = offset
        self.blur = blur
        self.color = color
    }
}

/// Colors at locations from 0 to 1.
public struct Gradient: Equatable, Hashable, Sendable {

    public struct Stop: Equatable, Hashable, Sendable {

        public var color: Color

        /// From 0, the start, to 1, the end.
        public var location: Double

        public init(color: Color, location: Double) {
            self.color = color
            self.location = location
        }
    }

    /// The stops, ordered by location.
    public var stops: [Stop]

    public init(stops: [Stop]) {
        self.stops = stops.sorted { $0.location < $1.location }
    }

    /// Colors spaced evenly from start to end.
    public init(colors: [Color]) {
        let last = Double(max(colors.count - 1, 1))
        self.stops = colors.enumerated().map { Stop(color: $0.element, location: Double($0.offset) / last) }
    }
}

/// Whether a gradient's end colors carry on past its ends.
public struct GradientOptions: OptionSet, Hashable, Sendable {

    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    /// The start color fills the space before the start.
    public static var drawsBeforeStartLocation: GradientOptions { GradientOptions(rawValue: 1 << 0) }

    /// The end color fills the space after the end.
    public static var drawsAfterEndLocation: GradientOptions { GradientOptions(rawValue: 1 << 1) }
}

/// Where lines of text sit across a rectangle.
@frozen
public enum TextAlignment: UInt8, Sendable {
    case leading
    case center
    case trailing
}
