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

// MARK: - CSS Values

/// Formats a floating-point value with up to three decimal places
/// without relying on `Double` description (unavailable in Embedded Swift).
internal func cssNumber(_ value: Double) -> String {

    // out-of-range values would trap converting to `Int`
    guard value.isFinite, value.magnitude < 1e12 else { return "0" }

    if value < 0 { return "-" + cssNumber(-value) }

    let scaled = Int((value * 1000).rounded())
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
internal func cssColor(_ color: Color) -> String {

    func clamped(_ value: Double) -> Double {
        value.isNaN ? 0 : max(0, min(1, value))
    }

    func component(_ value: Double) -> Int {
        Int((clamped(value) * 255).rounded())
    }

    return "rgba(\(component(color.red)),\(component(color.green)),\(component(color.blue)),\(cssNumber(clamped(color.alpha))))"
}

internal extension BlendMode {

    /// The canvas `globalCompositeOperation` for the blend mode. Modes the
    /// canvas lacks (`clear`, `plusDarker`) composite as `source-over`.
    var canvasCompositeOperation: String {
        switch self {
        case .normal: return "source-over"
        case .multiply: return "multiply"
        case .screen: return "screen"
        case .overlay: return "overlay"
        case .darken: return "darken"
        case .lighten: return "lighten"
        case .colorDodge: return "color-dodge"
        case .colorBurn: return "color-burn"
        case .softLight: return "soft-light"
        case .hardLight: return "hard-light"
        case .difference: return "difference"
        case .exclusion: return "exclusion"
        case .hue: return "hue"
        case .saturation: return "saturation"
        case .color: return "color"
        case .luminosity: return "luminosity"
        case .clear: return "source-over"
        case .copy: return "copy"
        case .sourceIn: return "source-in"
        case .sourceOut: return "source-out"
        case .sourceAtop: return "source-atop"
        case .destinationOver: return "destination-over"
        case .destinationIn: return "destination-in"
        case .destinationOut: return "destination-out"
        case .destinationAtop: return "destination-atop"
        case .xor: return "xor"
        case .plusDarker: return "source-over"
        case .plusLighter: return "lighter"
        }
    }
}

internal extension LineCap {

    /// The canvas `lineCap` value.
    var canvasValue: String {
        switch self {
        case .butt: return "butt"
        case .round: return "round"
        case .square: return "square"
        }
    }
}

internal extension LineJoin {

    /// The canvas `lineJoin` value.
    var canvasValue: String {
        switch self {
        case .miter: return "miter"
        case .round: return "round"
        case .bevel: return "bevel"
        }
    }
}

internal extension FillRule {

    /// The canvas fill rule argument.
    var canvasValue: String {
        switch self {
        case .winding: return "nonzero"
        case .evenOdd: return "evenodd"
        }
    }
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

#endif // canImport(JavaScriptKit)
