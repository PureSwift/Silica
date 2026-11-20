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
import struct Foundation.CGFloat
import Silica

/// Cairo / FontConfig backed font.
public final class CairoFontHandle: CGFontHandle {

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

        let face = FontFace(pattern: pattern)

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

        let face = FontFace(pattern: pattern)
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

    // MARK: - CGFontHandle

    public var fullName: String { scaledFont.fullName }

    public var unitsPerEm: Int { scaledFont.unitsPerEm }

    public var ascent: CGFloat { CGFloat(scaledFont.ascent) / CGFloat(scaledFont.unitsPerEm) }

    public var descent: CGFloat { CGFloat(scaledFont.descent) / CGFloat(scaledFont.unitsPerEm) }

    public var capHeight: CGFloat { CGFloat(scaledFont.capHeight) / CGFloat(scaledFont.unitsPerEm) }

    public func glyph(for scalar: Unicode.Scalar) -> Silica.CGGlyph {

        return scaledFont[UInt(scalar.value)]
    }

    public func advances(for glyphs: [Silica.CGGlyph]) -> [CGFloat] {

        let unitsPerEm = CGFloat(scaledFont.unitsPerEm)

        // A font of pictures only (color emoji) has no outlines to measure: its glyphs are a little wider than an em.
        guard unitsPerEm > 0 else { return glyphs.map { _ in 1.2 } }

        return scaledFont.advances(for: glyphs).map {
            let advance = CGFloat($0) / unitsPerEm
            return advance.isFinite ? advance : 1.2
        }
    }
}

// MARK: - CGFont Extensions

public extension CGFont {

    /// Creates a font with the specified name, resolved via FontConfig and loaded by Cairo.
    init?(name: String, configuration: FontConfiguration = .process) {

        guard let handle = CairoFontHandle(name: name, configuration: configuration)
            else { return nil }

        // Default font is Verdana, make sure the name is correct
        let defaultFontName = "Verdana"

        guard name == defaultFontName || handle.fullName != defaultFontName
            else { return nil }

        self.init(name: name, family: handle.familyName, handle: handle)
    }

    /// Creates a font from a font file, loaded by Cairo.
    init?(file path: String) {

        guard let handle = CairoFontHandle(file: path)
            else { return nil }

        self.init(name: handle.fullName, family: handle.familyName, handle: handle)
    }

    /// The font file the font was loaded from, and its face's index there.
    var file: (path: String, index: Int)? { (handle as? CairoFontHandle)?.file }

    /// The Cairo scaled font, if this font was loaded by the Cairo backend.
    var scaledFont: Cairo.ScaledFont {

        guard let handle = self.handle as? CairoFontHandle
            else { fatalError("Font \(name) was not loaded by the Cairo backend") }

        return handle.scaledFont
    }
}

// MARK: - Font Config

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
