//
//  WebFontHandle.swift
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

/// CSS font backed by canvas `measureText` metrics.
///
/// The Web Canvas API exposes neither glyph indices nor font tables, so glyph
/// indices are Unicode scalar values (scalars outside the Basic Multilingual
/// Plane map to glyph 0) and metrics are measured at a nominal em size.
///
/// - Note: Like the other backends, unknown family names fall back to the
///   platform default (`sans-serif`), so font creation does not fail for
///   unrecognized names.
public final class WebFontHandle: CGFontHandle {

    // MARK: - Constants

    /// Nominal em size used for measuring.
    internal static let nominalSize: CGFloat = 1000

    // MARK: - Properties

    public let familyName: String

    /// CSS `font-family` list (resolved family plus fallbacks).
    public let cssFamily: String

    /// CSS `font` prefix for style and weight (e.g. `"italic bold "`).
    public let cssTraits: String

    // MARK: - Private Properties

    /// Measuring 2D context, configured at the nominal size.
    private let measuringContext: JSObject

    private let internalMetrics: (ascent: CGFloat, descent: CGFloat, capHeight: CGFloat)

    /// Measured em-normalized advances.
    private var advanceCache = [CGGlyph: CGFloat]()

    // MARK: - Initialization

    /// Resolves a Silica font name (e.g. `"TimesNewRoman-Bold"`).
    public init?(name: String) {

        // parse "Family-Traits"
        let separator: Character = "-"
        let components = name.split(separator: separator, maxSplits: 2, omittingEmptySubsequences: true)

        let family: String
        let traits: String?

        if components.count == 2 {
            family = String(components[0])
            traits = String(components[1])
        } else {
            family = name
            traits = nil
        }

        var isBold = false
        var isItalic = false

        if let traits = traits {
            isBold = contains(traits, substring: "Bold")
            isItalic = contains(traits, substring: "Italic") || contains(traits, substring: "Oblique")
        }

        self.familyName = family
        self.cssTraits = (isItalic ? "italic " : "") + (isBold ? "bold " : "")

        // Silica font names are PostScript-like ("TimesNewRoman"), while CSS
        // matches display names ("Times New Roman"), so offer both spellings.
        var families = ["\"\(family)\""]

        let spaced = WebFontHandle.camelCaseSplit(family)

        if spaced != family {
            families.append("\"\(spaced)\"")
        }

        families.append("sans-serif")

        self.cssFamily = families.joined(separator: ", ")

        guard let canvas = WebCanvasContext.makeCanvas(width: 1, height: 1),
            let context = canvas.getContext!("2d").object
            else { return nil }

        context.font = .string(cssTraits + "\(Int(WebFontHandle.nominalSize))px " + cssFamily)
        self.measuringContext = context

        // font metrics from TextMetrics
        guard let metrics = context.measureText!("Hg").object
            else { return nil }

        let nominal = WebFontHandle.nominalSize

        // fall back to the actual bounding box on engines without font metrics
        let ascent = metrics.fontBoundingBoxAscent.number
            ?? metrics.actualBoundingBoxAscent.number
            ?? 0.8 * Double(nominal)

        let descent = metrics.fontBoundingBoxDescent.number
            ?? metrics.actualBoundingBoxDescent.number
            ?? 0.2 * Double(nominal)

        let capHeight = context.measureText!("H").object?.actualBoundingBoxAscent.number
            ?? 0.7 * Double(nominal)

        // Silica descent is negative below the baseline (FreeType convention).
        self.internalMetrics = (ascent: CGFloat(ascent) / nominal,
                                descent: -CGFloat(descent) / nominal,
                                capHeight: CGFloat(capHeight) / nominal)
    }

    // MARK: - CGFontHandle

    /// The family name (CSS exposes no full font name).
    public var fullName: String { familyName }

    public var unitsPerEm: Int { Int(WebFontHandle.nominalSize) }

    public var ascent: CGFloat { internalMetrics.ascent }

    public var descent: CGFloat { internalMetrics.descent }

    public var capHeight: CGFloat { internalMetrics.capHeight }

    public func glyph(for scalar: Unicode.Scalar) -> CGGlyph {

        // glyph indices are Unicode scalar values
        return scalar.value <= UInt32(CGGlyph.max) ? CGGlyph(scalar.value) : 0
    }

    public func advances(for glyphs: [CGGlyph]) -> [CGFloat] {

        return glyphs.map { glyph in

            if let cached = advanceCache[glyph] {
                return cached
            }

            let width = measuringContext.measureText!(text(for: glyph)).object?.width.number ?? 0
            let advance = CGFloat(width) / WebFontHandle.nominalSize

            advanceCache[glyph] = advance
            return advance
        }
    }

    // MARK: - Methods

    /// The string rendered for the specified glyph index.
    internal func text(for glyph: CGGlyph) -> String {

        guard let scalar = Unicode.Scalar(UInt16(glyph))
            else { return "" }

        return String(Character(scalar))
    }

    /// CSS `font` value at the specified size.
    internal func cssFont(size: CGFloat) -> String {

        return cssTraits + cssNumber(size) + "px " + cssFamily
    }

    // MARK: - Private Methods

    /// Splits a camel-case name into words (`"TimesNewRoman"` → `"Times New Roman"`).
    private static func camelCaseSplit(_ name: String) -> String {

        var result = ""
        var previousWasLowercase = false

        for character in name {

            let isUppercase = character.isASCII && character >= "A" && character <= "Z"

            if isUppercase && previousWasLowercase {
                result.append(" ")
            }

            previousWasLowercase = !isUppercase
            result.append(character)
        }

        return result
    }
}

#endif // canImport(JavaScriptKit)
