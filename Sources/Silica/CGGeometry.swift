//
//  CGGeometry.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 7/13/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

#if !canImport(Foundation)

// Minimal geometry and math support for Embedded Swift targets
// (e.g. the Nintendo 3DS port), where Foundation is unavailable.

public typealias CGFloat = Double

public extension Double {

    /// `Foundation.CGFloat` compatibility.
    typealias NativeType = Double

    /// `Foundation.CGFloat` compatibility.
    @inline(__always)
    var native: Double { self }
}

public struct CGPoint: Equatable {

    public var x: CGFloat
    public var y: CGFloat

    public init() {
        self.init(x: 0, y: 0)
    }

    public init(x: CGFloat, y: CGFloat) {
        self.x = x
        self.y = y
    }

    public static var zero: CGPoint { CGPoint() }
}

public struct CGSize: Equatable {

    public var width: CGFloat
    public var height: CGFloat

    public init() {
        self.init(width: 0, height: 0)
    }

    public init(width: CGFloat, height: CGFloat) {
        self.width = width
        self.height = height
    }

    public static var zero: CGSize { CGSize() }
}

public struct CGRect: Equatable {

    public var origin: CGPoint
    public var size: CGSize

    public init() {
        self.init(origin: CGPoint(), size: CGSize())
    }

    public init(origin: CGPoint, size: CGSize) {
        self.origin = origin
        self.size = size
    }

    public init(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        self.init(origin: CGPoint(x: x, y: y), size: CGSize(width: width, height: height))
    }

    public static var zero: CGRect { CGRect() }

    public var width: CGFloat { abs(size.width) }
    public var height: CGFloat { abs(size.height) }

    public var minX: CGFloat { size.width < 0 ? origin.x + size.width : origin.x }
    public var minY: CGFloat { size.height < 0 ? origin.y + size.height : origin.y }
    public var maxX: CGFloat { minX + width }
    public var maxY: CGFloat { minY + height }
    public var midX: CGFloat { minX + width / 2 }
    public var midY: CGFloat { minY + height / 2 }
}

// libm, provided by the platform C library (e.g. devkitARM's newlib, linked
// with -lm).

@_silgen_name("sin")
public func sin(_ x: Double) -> Double

@_silgen_name("cos")
public func cos(_ x: Double) -> Double

@_silgen_name("tan")
public func tan(_ x: Double) -> Double

@_silgen_name("atan2")
public func atan2(_ y: Double, _ x: Double) -> Double

@_silgen_name("sqrt")
public func sqrt(_ x: Double) -> Double

#endif // !canImport(Foundation)
