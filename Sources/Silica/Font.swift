//
//  Font.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/9/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

/// The index of a glyph in a font.
public typealias Glyph = UInt16

/// A platform font a rendering backend loaded, at no particular size.
///
/// Metrics are fractions of the em, so 1 is the font's size. Backends
/// without integer font units (Android, the web) can conform.
public protocol FontFace: AnyObject {

    /// The font's full name (e.g. "Times New Roman Bold").
    var fullName: String { get }

    /// The font's family name (e.g. "Times New Roman").
    var familyName: String { get }

    /// Font units per em.
    var unitsPerEm: Int { get }

    /// The ascent above the baseline: positive.
    var ascent: Double { get }

    /// The descent below the baseline: negative.
    var descent: Double { get }

    /// The space between lines.
    var leading: Double { get }

    /// The height of capital letters.
    var capHeight: Double { get }

    /// The height of lowercase letters.
    var xHeight: Double { get }

    /// The glyph for a character, or 0 when the font has none.
    func glyph(for scalar: Unicode.Scalar) -> Glyph

    /// The glyphs' horizontal advances.
    func advances(for glyphs: [Glyph]) -> [Double]
}

public extension FontFace {

    var leading: Double { 0 }

    var xHeight: Double { capHeight * 0.7 }
}

/// A font at a size.
public struct Font {

    /// The platform font.
    public let face: any FontFace

    /// The size in points: the height of the em.
    public var size: Double

    public init(face: any FontFace, size: Double) {
        self.face = face
        self.size = size
    }

    /// The font with the name (a PostScript or family name, e.g.
    /// `"TimesNewRoman-Bold"`), from the registered default backend.
    public init?(name: String, size: Double) {
        guard let face = SilicaBackend.fontFace(named: name) else { return nil }
        self.init(face: face, size: size)
    }

    /// The same font at another size.
    public func withSize(_ size: Double) -> Font {
        Font(face: face, size: size)
    }
}

extension Font: Equatable {

    public static func == (lhs: Font, rhs: Font) -> Bool {
        lhs.face === rhs.face && lhs.size == rhs.size
    }
}

// MARK: - Metrics

public extension Font {

    var name: String { face.fullName }

    var familyName: String { face.familyName }

    /// The ascent above the baseline, in points.
    var ascent: Double { face.ascent * size }

    /// The descent below the baseline, in points: positive.
    var descent: Double { -face.descent * size }

    /// The space between lines, in points.
    var leading: Double { face.leading * size }

    var capHeight: Double { face.capHeight * size }

    var xHeight: Double { face.xHeight * size }

    /// From one baseline to the next, in points.
    var lineHeight: Double { ascent + descent + leading }

    /// The glyph for a character, or 0 when the font has none.
    func glyph(for scalar: Unicode.Scalar) -> Glyph {
        face.glyph(for: scalar)
    }

    /// The glyphs' horizontal advances, in points.
    func advances(for glyphs: [Glyph]) -> [Double] {
        face.advances(for: glyphs).map { $0 * size }
    }
}

// MARK: - Layout

/// Glyphs of one font, placed on a line.
public struct GlyphRun {

    public var font: Font

    public var glyphs: [Glyph]

    /// Each glyph's baseline origin, from the line's origin.
    public var positions: [Point]

    public init(font: Font, glyphs: [Glyph], positions: [Point]) {
        self.font = font
        self.glyphs = glyphs
        self.positions = positions
    }
}

public extension Font {

    /// A line of text as runs of glyphs, from a baseline origin at zero, and
    /// its width. A character the font lacks (an emoji, a symbol) is drawn
    /// from a fallback font that has it.
    ///
    /// Characters map to glyphs one by one: scripts that shape aren't laid out.
    func layout(_ text: String, characterSpacing: Double = 0) -> (runs: [GlyphRun], width: Double) {
        let scalars = Array(text.unicodeScalars)
        var runs: [GlyphRun] = []
        var x = 0.0
        var run = GlyphRun(font: self, glyphs: [], positions: [])
        func flush() {
            if run.glyphs.isEmpty == false { runs.append(run) }
        }
        for (index, scalar) in scalars.enumerated() {
            // Selectors and joiners shape the characters beside them, and draw nothing themselves.
            if scalar.value == 0xFE0F || scalar.value == 0xFE0E || scalar.value == 0x200D { continue }
            var font = self
            var glyph = face.glyph(for: scalar)
            let asEmoji = index + 1 < scalars.count && scalars[index + 1].value == 0xFE0F
            if glyph == 0 || asEmoji, let fallback = Font.fallback(for: scalar, size: size) {
                font = fallback.font
                glyph = fallback.glyph
            }
            if font.face !== run.font.face {
                flush()
                run = GlyphRun(font: font, glyphs: [], positions: [])
            }
            run.glyphs.append(glyph)
            run.positions.append(Point(x: x, y: 0))
            x += (font.face.advances(for: [glyph]).first ?? 0) * size + characterSpacing
        }
        flush()
        return (runs, x)
    }

    /// The width of a line of text, in points.
    func width(of text: String) -> Double {
        layout(text).width
    }

    /// Lines of text that fit `maxWidth`, broken at spaces where they can be
    /// and between characters where a word alone is too long. Newlines
    /// always break.
    func lines(of text: String, maxWidth: Double) -> [String] {
        var lines: [String] = []
        for paragraph in text.split(separator: "\n", omittingEmptySubsequences: false) {
            var line = ""
            for word in paragraph.split(separator: " ", omittingEmptySubsequences: false) {
                let candidate = line.isEmpty ? String(word) : line + " " + String(word)
                if maxWidth <= 0 || width(of: candidate) <= maxWidth {
                    line = candidate
                    continue
                }
                if line.isEmpty == false {
                    lines.append(line)
                }
                // a word too long for a line is broken between characters
                line = ""
                for character in word {
                    let next = line + String(character)
                    if line.isEmpty == false, width(of: next) > maxWidth {
                        lines.append(line)
                        line = String(character)
                    } else {
                        line = next
                    }
                }
            }
            lines.append(line)
        }
        return lines
    }

    /// A font at the size with a glyph for a character the drawing font
    /// lacks, and that glyph: the color emoji font, then fonts of symbols and
    /// of many scripts.
    static func fallback(for scalar: Unicode.Scalar, size: Double) -> (font: Font, glyph: Glyph)? {
        for name in ["Noto Color Emoji", "Noto Sans Symbols2", "Noto Sans Symbols", "DejaVu Sans", "Noto Sans CJK SC"] {
            guard let font = Font(name: name, size: size) else { continue }
            let glyph = font.glyph(for: scalar)
            if glyph != 0 { return (font, glyph) }
        }
        return nil
    }
}
