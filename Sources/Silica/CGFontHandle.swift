//
//  CGFontHandle.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 7/13/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

#if canImport(Foundation)
import struct Foundation.CGFloat
#endif

/// A platform font loaded by a rendering backend.
///
/// Metrics are normalized to the em square, so a value of `1.0` equals the font size.
/// This allows backends without font-unit integer metrics (e.g. Android) to conform.
public protocol CGFontHandle: AnyObject {

    /// Full name of the font (e.g. "Times New Roman").
    var fullName: String { get }

    /// Font family name (e.g. "Times New Roman").
    var familyName: String { get }

    /// Number of font units per em.
    var unitsPerEm: Int { get }

    /// Ascent above the baseline, as a fraction of the em (positive above the baseline).
    var ascent: CGFloat { get }

    /// Descent below the baseline, as a fraction of the em (negative below the baseline).
    var descent: CGFloat { get }

    /// Cap height, as a fraction of the em.
    var capHeight: CGFloat { get }

    /// Returns the glyph index for the specified Unicode scalar.
    func glyph(for scalar: Unicode.Scalar) -> CGGlyph

    /// Horizontal advances for the specified glyphs, as fractions of the em.
    func advances(for glyphs: [CGGlyph]) -> [CGFloat]
}
