//
//  CoreTextFontHandle.swift
//  SilicaCoreGraphics
//
//  Created by Alsey Coleman Miller on 7/13/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

#if canImport(CoreGraphics)

import CoreGraphics
import CoreText
import Foundation
import Silica

/// CoreText backed font.
public final class CoreTextFontHandle: CGFontHandle {

    // MARK: - Properties

    /// The underlying CoreText font, at a size of 1.0 (so metrics are em-normalized).
    public let ctFont: CTFont

    public let familyName: String

    // MARK: - Initialization

    public init(ctFont: CTFont) {

        self.ctFont = ctFont
        self.familyName = CTFontCopyFamilyName(ctFont) as String
    }

    /// Resolves a Silica font name (e.g. `"TimesNewRoman-Bold"`).
    ///
    /// Resolution order:
    /// 1. Exact PostScript name (e.g. `"ComicSansMS"`, `"AmericanTypewriter-Bold"`).
    /// 2. `Family-Traits` parsing, matching the family name as written and with
    ///    camel-case expansion (`"TimesNewRoman"` → `"Times New Roman"`), applying
    ///    Bold / Italic / Oblique / Condensed symbolic traits.
    public convenience init?(name: String) {

        guard let ctFont = CoreTextFontHandle.resolve(name: name)
            else { return nil }

        self.init(ctFont: ctFont)
    }

    private static func resolve(name: String) -> CTFont? {

        // 1. exact PostScript name
        let postScriptDescriptor = CTFontDescriptorCreateWithAttributes(
            [kCTFontNameAttribute: name] as CFDictionary
        )

        if let matched = CTFontDescriptorCreateMatchingFontDescriptor(postScriptDescriptor, nil) {

            let font = CTFontCreateWithFontDescriptor(matched, 1.0, nil)

            // verify the match (CoreText may substitute a fallback font)
            if (CTFontCopyPostScriptName(font) as String).caseInsensitiveCompare(name) == .orderedSame {
                return font
            }
        }

        // 2. family name + traits
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

        var symbolicTraits = CTFontSymbolicTraits()

        if let traits = traits {

            if traits.contains("Bold") {
                symbolicTraits.insert(.traitBold)
            }

            if traits.contains("Italic") || traits.contains("Oblique") {
                symbolicTraits.insert(.traitItalic)
            }

            if traits.contains("Condensed") {
                symbolicTraits.insert(.traitCondensed)
            }
        }

        for candidateFamily in [family, family.expandingCamelCase] {

            var attributes: [CFString: Any] = [kCTFontFamilyNameAttribute: candidateFamily]

            if symbolicTraits.isEmpty == false {
                attributes[kCTFontTraitsAttribute] = [kCTFontSymbolicTrait: symbolicTraits.rawValue] as CFDictionary
            }

            let descriptor = CTFontDescriptorCreateWithAttributes(attributes as CFDictionary)

            guard let matched = CTFontDescriptorCreateMatchingFontDescriptor(descriptor, nil)
                else { continue }

            let font = CTFontCreateWithFontDescriptor(matched, 1.0, nil)

            // verify the family matches (CoreText may substitute a fallback font)
            if (CTFontCopyFamilyName(font) as String).caseInsensitiveCompare(candidateFamily) == .orderedSame {
                return font
            }
        }

        return nil
    }

    // MARK: - Methods

    /// Returns the font at the specified point size.
    public func font(size: CGFloat) -> CTFont {

        return CTFontCreateCopyWithAttributes(ctFont, size, nil, nil)
    }

    // MARK: - CGFontHandle

    public var fullName: String { CTFontCopyFullName(ctFont) as String }

    public var unitsPerEm: Int { Int(CTFontGetUnitsPerEm(ctFont)) }

    public var ascent: CGFloat { CTFontGetAscent(ctFont) }

    public var descent: CGFloat { -CTFontGetDescent(ctFont) }

    public var capHeight: CGFloat { CTFontGetCapHeight(ctFont) }

    public func glyph(for scalar: Unicode.Scalar) -> Silica.CGGlyph {

        let characters = Array(String(scalar).utf16)
        var glyphs = [CoreGraphics.CGGlyph](repeating: 0, count: characters.count)

        CTFontGetGlyphsForCharacters(ctFont, characters, &glyphs, characters.count)

        return glyphs[0]
    }

    public func advances(for glyphs: [Silica.CGGlyph]) -> [CGFloat] {

        var advances = [CGSize](repeating: .zero, count: glyphs.count)

        // the font has a size of 1.0, so advances are already em-normalized
        CTFontGetAdvancesForGlyphs(ctFont, .horizontal, glyphs, &advances, glyphs.count)

        return advances.map { $0.width }
    }
}

// MARK: - Camel Case Expansion

internal extension String {

    /// Inserts spaces at lowercase-to-uppercase boundaries
    /// (e.g. `"TimesNewRoman"` → `"Times New Roman"`, `"ComicSansMS"` → `"Comic Sans MS"`).
    var expandingCamelCase: String {

        var result = ""
        var previous: Character?

        for character in self {

            if let previous = previous,
                previous.isLowercase && character.isUppercase {
                result.append(" ")
            }

            result.append(character)
            previous = character
        }

        return result
    }
}

#endif // canImport(CoreGraphics)
