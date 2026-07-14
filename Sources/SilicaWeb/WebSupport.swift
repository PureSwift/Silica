//
//  WebSupport.swift
//  SilicaWeb
//
//  Created by Alsey Coleman Miller on 7/13/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

#if canImport(JavaScriptKit)

#if canImport(Foundation)
import Foundation
#endif

import JavaScriptKit
import Silica

// MARK: - Math

/// Trigonometry via the JavaScript `Math` object.
///
/// Embedded Swift provides no libm, so the host's implementation is used instead.
internal enum JSMath {

    static func cos(_ value: Double) -> Double {
        JSObject.global.Math.cos(value).number ?? 0
    }

    static func sin(_ value: Double) -> Double {
        JSObject.global.Math.sin(value).number ?? 0
    }

    static func tan(_ value: Double) -> Double {
        JSObject.global.Math.tan(value).number ?? 0
    }
}

// MARK: - CSS Values

/// Formats a floating-point value with up to three decimal places
/// without relying on `Double` description (unavailable in Embedded Swift).
internal func cssNumber(_ value: CGFloat) -> String {

    let doubleValue = Double(value)

    if doubleValue < 0 { return "-" + cssNumber(CGFloat(-doubleValue)) }

    let scaled = Int((doubleValue * 1000).rounded())
    let whole = scaled / 1000
    var fraction = scaled % 1000

    if fraction == 0 { return "\(whole)" }

    var digits = ""

    for divisor in [100, 10, 1] {
        digits += "\(fraction / divisor)"
        fraction %= divisor
    }

    while digits.hasSuffix("0") { digits.removeLast() }

    return "\(whole)." + digits
}

/// CSS `rgba()` value for the specified color.
internal func cssColor(_ color: CGColor) -> String {

    func component(_ value: CGFloat) -> Int {
        return Int((max(0, min(1, Double(value))) * 255).rounded())
    }

    return "rgba(\(component(color.red)),\(component(color.green)),\(component(color.blue)),\(cssNumber(max(0, min(1, color.alpha)))))"
}

// MARK: - String

/// Naive substring search (`String.contains(_: String)` requires Foundation).
internal func contains(_ string: String, substring: String) -> Bool {

    guard substring.isEmpty == false
        else { return true }

    var start = string.startIndex

    while start < string.endIndex {

        var stringIndex = start
        var substringIndex = substring.startIndex

        while substringIndex < substring.endIndex,
            stringIndex < string.endIndex,
            string[stringIndex] == substring[substringIndex] {

            string.formIndex(after: &stringIndex)
            substring.formIndex(after: &substringIndex)
        }

        if substringIndex == substring.endIndex {
            return true
        }

        string.formIndex(after: &start)
    }

    return false
}

// MARK: - Base64

/// Decodes a base64 string (used to read `canvas.toDataURL` output without Foundation).
internal func decodeBase64(_ string: Substring) -> [UInt8]? {

    func value(of character: Character) -> UInt8? {

        guard let ascii = character.asciiValue else { return nil }

        switch ascii {
        case UInt8(ascii: "A") ... UInt8(ascii: "Z"): return ascii - UInt8(ascii: "A")
        case UInt8(ascii: "a") ... UInt8(ascii: "z"): return ascii - UInt8(ascii: "a") + 26
        case UInt8(ascii: "0") ... UInt8(ascii: "9"): return ascii - UInt8(ascii: "0") + 52
        case UInt8(ascii: "+"): return 62
        case UInt8(ascii: "/"): return 63
        default: return nil
        }
    }

    var bytes = [UInt8]()
    bytes.reserveCapacity(string.count * 3 / 4)

    var buffer: UInt32 = 0
    var bitCount = 0

    for character in string {

        if character == "=" { break }

        guard let sextet = value(of: character)
            else { return nil }

        buffer = (buffer << 6) | UInt32(sextet)
        bitCount += 6

        if bitCount >= 8 {
            bitCount -= 8
            bytes.append(UInt8((buffer >> UInt32(bitCount)) & 0xFF))
        }
    }

    return bytes
}

// MARK: - Geometry Helpers

internal extension CGAffineTransform {

    /// The result of applying `self` first, then `other`.
    func multiplied(by other: CGAffineTransform) -> CGAffineTransform {

        return CGAffineTransform(
            a: a * other.a + b * other.c,
            b: a * other.b + b * other.d,
            c: c * other.a + d * other.c,
            d: c * other.b + d * other.d,
            tx: tx * other.a + ty * other.c + other.tx,
            ty: tx * other.b + ty * other.d + other.ty
        )
    }

    var inverse: CGAffineTransform {

        let determinant = a * d - b * c

        guard determinant != 0
            else { return self }

        return CGAffineTransform(
            a: d / determinant,
            b: -b / determinant,
            c: -c / determinant,
            d: a / determinant,
            tx: (c * ty - d * tx) / determinant,
            ty: (b * tx - a * ty) / determinant
        )
    }
}

internal extension PathElement {

    func applying(_ transform: CGAffineTransform) -> PathElement {

        switch self {

        case let .moveToPoint(point):
            return .moveToPoint(point.applying(transform))

        case let .addLineToPoint(point):
            return .addLineToPoint(point.applying(transform))

        case let .addQuadCurveToPoint(control, destination):
            return .addQuadCurveToPoint(control.applying(transform), destination.applying(transform))

        case let .addCurveToPoint(control1, control2, destination):
            return .addCurveToPoint(control1.applying(transform), control2.applying(transform), destination.applying(transform))

        case .closeSubpath:
            return .closeSubpath
        }
    }
}

#endif // canImport(JavaScriptKit)
