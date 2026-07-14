//
//  Font.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/9/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

#if canImport(Foundation)
import struct Foundation.CGFloat
import struct Foundation.CGSize
import struct Foundation.CGPoint
#endif

/// Silica's `Font` type.
public struct CGFont {

    #if canImport(Foundation)
    /// Private font cache.
    internal nonisolated(unsafe) static var cache = [String: CGFont]()
    #endif

    // MARK: - Properties

    /// Same as full name.
    public let name: String

    /// Font family name.
    public let family: String

    /// The backend font implementation.
    public let handle: any CGFontHandle

    // MARK: - Initialization

    /// Creates a font from a backend font handle.
    public init(name: String, family: String, handle: any CGFontHandle) {

        self.name = name
        self.family = family
        self.handle = handle
    }

    #if canImport(Foundation)
    /// Creates a font with the specified name using the default rendering backend.
    public init?(name: String) {

        guard let backend = SilicaBackend.default
            else { return nil }

        // cache fonts per backend, since multiple backends may coexist in one process
        #if canImport(Foundation)
        let cacheKey = "\(backend)/\(name)"
        #else
        let cacheKey = backend.name + "/" + name
        #endif

        if let cachedFont = CGFont.cache[cacheKey] {
            self = cachedFont
            return
        }

        #if canImport(Foundation)
        guard let font = backend.font(named: name)
            else { return nil }
        #else
        guard let font = backend.font(name)
            else { return nil }
        #endif

        CGFont.cache[cacheKey] = font
        self = font
    }
    #endif
}

// MARK: - Equatable

extension CGFont: Equatable {

    public static func == (lhs: CGFont, rhs: CGFont) -> Bool {
        lhs.name == rhs.name
    }
}

// MARK: - Hashable

extension CGFont: Hashable {

    public func hash(into hasher: inout Hasher) {
        name.hash(into: &hasher)
    }
}

// MARK: - Identifiable

extension CGFont: Identifiable {

    public var id: String { name }
}

// MARK: - Metrics

public extension CGFont {

    /// Number of font units per em.
    var unitsPerEm: Int { handle.unitsPerEm }

    /// Ascent above the baseline, as a fraction of the em (positive above the baseline).
    var ascent: CGFloat { handle.ascent }

    /// Descent below the baseline, as a fraction of the em (negative below the baseline).
    var descent: CGFloat { handle.descent }

    /// Cap height, as a fraction of the em.
    var capHeight: CGFloat { handle.capHeight }

    /// Returns the glyph index for the specified Unicode scalar.
    func glyph(for scalar: Unicode.Scalar) -> CGGlyph { handle.glyph(for: scalar) }
}

// MARK: - Text Math

public extension CGFont {

    func advances(for glyphs: [CGGlyph], fontSize: CGFloat, textMatrix: CGAffineTransform = .identity, characterSpacing: CGFloat = 0.0) -> [CGSize] {

        // only horizontal layout is supported

        // calculate advances (em-normalized advances scaled to font size)
        return handle.advances(for: glyphs).map { CGSize(width: ($0 * fontSize) + characterSpacing, height: 0).applying(textMatrix) }
    }

    func positions(for advances: [CGSize], textMatrix: CGAffineTransform = .identity) -> [CGPoint] {

        var glyphPositions = [CGPoint](repeating: CGPoint(), count: advances.count)

        // first position is {0, 0}
        for i in 1 ..< glyphPositions.count {

            let textSpaceAdvance = advances[i-1].applying(textMatrix)

            glyphPositions[i] = CGPoint(x: glyphPositions[i-1].x + textSpaceAdvance.width,
                                      y: glyphPositions[i-1].y + textSpaceAdvance.height)
        }

        return glyphPositions
    }

    func singleLineWidth(text: String, fontSize: CGFloat, textMatrix: CGAffineTransform = .identity) -> CGFloat {

        let glyphs = text.unicodeScalars.map { handle.glyph(for: $0) }

        let textWidth = advances(for: glyphs, fontSize: fontSize, textMatrix: textMatrix).reduce(CGFloat(0), { $0 + $1.width })

        return textWidth
    }
}
