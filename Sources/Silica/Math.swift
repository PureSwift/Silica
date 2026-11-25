//
//  Math.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 7/13/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

#if !canImport(Foundation)

// Foundation-free stand-ins for `Data` and the math functions, used when
// building for Embedded Swift (e.g. Embedded WebAssembly).

/// Byte buffer type standing in for `Foundation.Data`.
public typealias Data = [UInt8]

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

/// Returns the sine of the specified angle, in radians.
public func sin(_ x: Double) -> Double {

    // range-reduce to [-pi, pi]
    var value = x.truncatingRemainder(dividingBy: 2 * .pi)
    if value > .pi { value -= 2 * .pi }
    if value < -.pi { value += 2 * .pi }

    // Maclaurin series on the reduced argument
    let square = value * value
    var term = value
    var sum = value
    var n = 1.0

    for _ in 0 ..< 8 {
        n += 2
        term *= -square / ((n - 1) * n)
        sum += term
    }

    return sum
}

/// Returns the cosine of the specified angle, in radians.
public func cos(_ x: Double) -> Double {
    sin(x + .pi / 2)
}

/// Returns the tangent of the specified angle, in radians.
public func tan(_ x: Double) -> Double {
    sin(x) / cos(x)
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

#endif
