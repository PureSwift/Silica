//
//  CairoFontHandle.swift
//  SilicaCairo
//
//  Created by Alsey Coleman Miller on 7/13/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

#if canImport(Cairo)

import Cairo
import CCairo
import FontConfig
import Silica

/// Cairo / FontConfig backed font.
public final class CairoFontHandle: Silica.FontFace {

    // MARK: - Properties

    public let scaledFont: Cairo.ScaledFont

    public let familyName: String

    /// The font file the face was loaded from, and the face's index in it.
    public let file: (path: String, index: Int)?

    // MARK: - Initialization

    public init?(name: String, configuration: FontConfiguration = .process) {

        // create new font
        guard let pattern = FontConfig.Pattern(cgFont: name, configuration: configuration),
            let family = pattern.family
            else { return nil }

        let face = Cairo.FontFace(pattern: pattern)

        let options = FontOptions()
        options.hintMetrics = .off
        options.hintStyle = CAIRO_HINT_STYLE_NONE

        do {
            self.scaledFont = try ScaledFont(
                face: face,
                matrix: .identity,
                currentTransformation: .identity,
                options: options
            )
        }
        catch .noMemory {
            assertionFailure("Insufficient memory to perform the operation.")
            return nil
        }
        catch {
            return nil
        }

        self.familyName = family
        self.file = configuration.match(pattern).flatMap { matched in
            matched.string(for: FontConfig.Pattern.Key(rawValue: "file")).map {
                ($0, Int(matched.integer(for: FontConfig.Pattern.Key(rawValue: "index")) ?? 0))
            }
        }
    }

    /// A font from a font file, as fonts made from data are loaded.
    public init?(file path: String) {

        let pattern = FontConfig.Pattern()
        guard pattern.setString(path, for: FontConfig.Pattern.Key(rawValue: "file")),
            pattern.setInteger(0, for: FontConfig.Pattern.Key(rawValue: "index"))
            else { return nil }

        let face = Cairo.FontFace(pattern: pattern)
        guard face.status == .success else { return nil }

        let options = FontOptions()
        options.hintMetrics = .off
        options.hintStyle = CAIRO_HINT_STYLE_NONE

        guard let scaledFont = try? ScaledFont(
            face: face,
            matrix: .identity,
            currentTransformation: .identity,
            options: options
        ), scaledFont.status == .success else { return nil }

        self.scaledFont = scaledFont
        self.familyName = scaledFont.fullName
        self.file = (path, 0)
    }

    // MARK: - FontFace

    public var fullName: String { scaledFont.fullName }

    public var unitsPerEm: Int { scaledFont.unitsPerEm }

    public var ascent: Double { Double(scaledFont.ascent) / Double(scaledFont.unitsPerEm) }

    public var descent: Double { Double(scaledFont.descent) / Double(scaledFont.unitsPerEm) }

    public var capHeight: Double { Double(scaledFont.capHeight) / Double(scaledFont.unitsPerEm) }

    public var xHeight: Double { Double(scaledFont.xHeight) / Double(scaledFont.unitsPerEm) }

    public func glyph(for scalar: Unicode.Scalar) -> Glyph {

        return scaledFont[UInt(scalar.value)]
    }

    public func advances(for glyphs: [Glyph]) -> [Double] {

        let unitsPerEm = Double(scaledFont.unitsPerEm)

        // A font of pictures only (color emoji) has no outlines to measure: its glyphs are a little wider than an em.
        guard unitsPerEm > 0 else { return glyphs.map { _ in 1.2 } }

        return scaledFont.advances(for: glyphs).map {
            let advance = Double($0) / unitsPerEm
            return advance.isFinite ? advance : 1.2
        }
    }
}

// MARK: - Font Extensions

public extension Silica.Font {

    /// A font by name, resolved by FontConfig and loaded by Cairo.
    init?(cairoName name: String, size: Double, configuration: FontConfiguration = .process) {
        guard let face = CairoFontHandle(named: name, configuration: configuration) else { return nil }
        self.init(face: face, size: size)
    }

    /// A font from a font file, loaded by Cairo.
    init?(file path: String, size: Double) {
        guard let face = CairoFontHandle(file: path) else { return nil }
        self.init(face: face, size: size)
    }

    /// The font file the font was loaded from, and its face's index there.
    var file: (path: String, index: Int)? { (face as? CairoFontHandle)?.file }
}

public extension CairoFontHandle {

    /// A font by name, resolved by FontConfig, or nil when FontConfig
    /// substitutes its default for a font it doesn't have.
    convenience init?(named name: String, configuration: FontConfiguration = .process) {
        self.init(name: name, configuration: configuration)
        // FontConfig's default font is Verdana: a font of another name that resolves to it wasn't found
        let defaultFontName = "Verdana"
        guard name == defaultFontName || fullName != defaultFontName else { return nil }
    }
}


public extension FontConfiguration {

    /// FontConfig's configuration for the process, kept for good. (`current` makes a new object each time it is read, and each gives up
    /// a reference to the configuration as it goes that it never took. The
    /// configuration is destroyed, and the next font made loads another,
    /// without the fonts an app has added and with every font file read
    /// again.)
    nonisolated(unsafe) static let process: FontConfiguration = .current
}

// MARK: - Font Config Pattern

internal extension FontConfig.Pattern {

    convenience init?(cgFont name: String, configuration: FontConfiguration = .process) {
        self.init()

        let separator: Character = "-"

        let traits: String?

        let family: String

        let components = name.split(separator: separator, maxSplits: 2, omittingEmptySubsequences: true)

        if components.count == 2  {
            family = String(components[0])
            traits = String(components[1])
        } else {
            family = name
            traits = nil
        }

        self.family = family
        assert(self.family == family)

        // FontConfig assumes Medium Roman Regular, add / replace additional traits
        if let traits = traits {

            if traits.contains("Bold") {
                self.weight = .bold
            }

            if traits.contains("Italic") {
                self.slant = .italic
            }

            if traits.contains("Oblique") {
                self.slant = .oblique
            }

            if traits.contains("Condensed") {
                self.width = .condensed
            }
        }

        guard configuration.substitute(pattern: self, kind: FcMatchPattern)
            else { return nil }

        self.defaultSubstitutions()

        guard configuration.match(self) != nil
            else { return nil }

    }
}

#endif // canImport(Cairo)
