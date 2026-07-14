//
//  EmbeddedShims.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 7/13/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

#if !canImport(Foundation)

// Foundation-free stand-ins for the Core Graphics geometry types and `Data`,
// used when building for Embedded Swift (e.g. Embedded WebAssembly).

/// The basic type for floating-point scalar values.
public typealias CGFloat = Double

public extension CGFloat {

    /// The native type used to store the CGFloat.
    typealias NativeType = Double

    /// The native value.
    var native: NativeType { self }
}

/// Byte buffer type standing in for `Foundation.Data`.
public typealias Data = [UInt8]

// MARK: - Geometry

/// A structure that contains a point in a two-dimensional coordinate system.
public struct CGPoint: Equatable, Hashable, Sendable {

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

/// A structure that contains width and height values.
public struct CGSize: Equatable, Hashable, Sendable {

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

/// A structure that contains the location and dimensions of a rectangle.
public struct CGRect: Equatable, Hashable, Sendable {

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

    public var minX: CGFloat { size.width < 0 ? origin.x + size.width : origin.x }
    public var midX: CGFloat { origin.x + size.width / 2 }
    public var maxX: CGFloat { size.width < 0 ? origin.x : origin.x + size.width }

    public var minY: CGFloat { size.height < 0 ? origin.y + size.height : origin.y }
    public var midY: CGFloat { origin.y + size.height / 2 }
    public var maxY: CGFloat { size.height < 0 ? origin.y : origin.y + size.height }

    public var width: CGFloat { abs(size.width) }
    public var height: CGFloat { abs(size.height) }

    /// A rectangle with positive width and height and its origin at `(minX, minY)`.
    public var standardized: CGRect {
        CGRect(x: minX, y: minY, width: width, height: height)
    }

    public var isEmpty: Bool { size.width == 0 || size.height == 0 }

    public func contains(_ point: CGPoint) -> Bool {
        point.x >= minX && point.x < maxX && point.y >= minY && point.y < maxY
    }

    public func contains(_ rect: CGRect) -> Bool {
        rect.minX >= minX && rect.maxX <= maxX && rect.minY >= minY && rect.maxY <= maxY
    }

    public func offsetBy(dx: CGFloat, dy: CGFloat) -> CGRect {
        CGRect(x: origin.x + dx, y: origin.y + dy, width: size.width, height: size.height)
    }

    public func insetBy(dx: CGFloat, dy: CGFloat) -> CGRect {
        let standardized = self.standardized
        return CGRect(x: standardized.origin.x + dx,
                      y: standardized.origin.y + dy,
                      width: standardized.size.width - 2 * dx,
                      height: standardized.size.height - 2 * dy)
    }
}

// MARK: - Math

/// Returns the square root of the specified value.
public func sqrt(_ value: Double) -> Double {
    value.squareRoot()
}

/// Returns the smallest integral value that is not less than the specified value.
public func ceil(_ value: Double) -> Double {
    value.rounded(.up)
}

/// Returns the largest integral value that is not greater than the specified value.
public func floor(_ value: Double) -> Double {
    value.rounded(.down)
}

/// Returns the principal value of the arc tangent of `y/x`,
/// using the signs of both arguments to determine the quadrant of the result.
public func atan2(_ y: Double, _ x: Double) -> Double {

    if x.isNaN || y.isNaN { return .nan }

    if x > 0 {
        return atan(y / x)
    } else if x < 0 {
        return y < 0 || (y == 0 && y.sign == .minus)
            ? atan(y / x) - .pi
            : atan(y / x) + .pi
    } else {
        // x == 0
        if y > 0 { return .pi / 2 }
        if y < 0 { return -.pi / 2 }
        // atan2(±0, ±0)
        return x.sign == .minus
            ? (y.sign == .minus ? -.pi : .pi)
            : (y.sign == .minus ? -0.0 : 0.0)
    }
}

/// Returns the principal value of the arc tangent of the specified value.
public func atan(_ x: Double) -> Double {

    if x.isNaN { return .nan }
    if x < 0 || (x == 0 && x.sign == .minus) { return -atan(-x) }
    if x > 1 { return .pi / 2 - atan(1 / x) }
    if x.isInfinite { return .pi / 2 }

    // halve the angle three times: atan(x) = 2·atan(x / (1 + √(1 + x²)))
    var value = x
    var scale = 1.0

    for _ in 0 ..< 3 {
        value = value / (1 + (1 + value * value).squareRoot())
        scale *= 2
    }

    // Maclaurin series on the reduced argument (|value| ≤ tan(π/32) ≈ 0.0985)
    let square = value * value
    var term = value
    var sum = value
    var divisor = 1.0

    for _ in 0 ..< 8 {
        term *= -square
        divisor += 2
        sum += term / divisor
    }

    return scale * sum
}

#endif // !canImport(Foundation)
