//
//  Font.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/9/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Cairo
import CCairo
import CFontConfig
import Foundation
#if os(macOS)
import struct CoreGraphics.CGAffineTransform
#endif

/// Silica's `Font` type.
public struct CGFont {
    
    /// Private font cache.
    internal nonisolated(unsafe) static var cache = [String: CGFont]()
    
    // MARK: - Properties
    
    /// Same as full name.
    public let name: String
    
    /// Font family name.
    public let family: String
    
    // MARK: - Internal Properties
    
    public let scaledFont: Cairo.ScaledFont
    
    // MARK: - Initialization
    
    public init?(name: String) {
        
        if let cachedFont = CGFont.cache[name] {
            
            self = cachedFont
            
        } else {
            
            // create new font
            guard let (fontConfigPattern, family) = FcPattern(name: name)
                else { return nil }
            
            let face = FontFace(fontConfigPattern: fontConfigPattern)
            
            let options = FontOptions()
            options.hintMetrics = .off
            options.hintStyle = CAIRO_HINT_STYLE_NONE
            
            self.name = name
            self.family = family
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
            
            // Default font is Verdana, make sure the name is correct
            let defaultFontName = "Verdana"
            
            guard name == defaultFontName || scaledFont.fullName != defaultFontName
                else { return nil }
            
            // cache
            CGFont.cache[name] = self
        }
    }
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

// MARK: - Text Math

public extension CGFont {
    
    func advances(for glyphs: [FontIndex], fontSize: CGFloat, textMatrix: CGAffineTransform = .identity, characterSpacing: CGFloat = 0.0) -> [CGSize] {
        
        // only horizontal layout is supported
        
        // calculate advances
        let glyphSpaceToTextSpace = fontSize / CGFloat(scaledFont.unitsPerEm)
        
        return scaledFont.advances(for: glyphs).map { CGSize(width: (CGFloat($0) * glyphSpaceToTextSpace) + characterSpacing, height: 0).applying(textMatrix) }
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
        
        let glyphs = text.unicodeScalars.map { scaledFont[UInt($0.value)] }
        
        let textWidth = advances(for: glyphs, fontSize: fontSize, textMatrix: textMatrix).reduce(CGFloat(0), { $0 + $1.width })
        
        return textWidth
    }
}

// MARK: - Private

/// Initialize a pointer to a `FcPattern` object created from the specified PostScript font name.
internal func FcPattern(name: String) -> (pointer: OpaquePointer, family: String)? {
    
    guard let pattern = FcPatternCreate()
        else { return nil }
    
    /// hacky way to cleanup, `defer` will copy initial value of `Bool` so this is needed.
    /// ARC will cleanup for us
    final class ErrorCleanup {
        
        var shouldCleanup = true
        
        let cleanup: () -> ()
        
        deinit { if shouldCleanup { cleanup() } }
        
        init(cleanup: @escaping () -> ()) {
            
            self.cleanup = cleanup
        }
    }
    
    let cleanup = ErrorCleanup(cleanup: { FcPatternDestroy(pattern) })
    
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
    
    guard FcPatternAddString(pattern, FC_FAMILY, family) != 0
        else { return nil }
    
    // FontConfig assumes Medium Roman Regular, add / replace additional traits
    if let traits = traits {
        
        if traits.contains("Bold") {
            
            guard FcPatternAddInteger(pattern, FC_WEIGHT, FC_WEIGHT_BOLD) != 0
                else { return nil }
        }
        
        if traits.contains("Italic") {
            
            guard FcPatternAddInteger(pattern, FC_SLANT, FC_SLANT_ITALIC) != 0
                else { return nil }
        }
        
        if traits.contains("Oblique") {
            
            guard FcPatternAddInteger(pattern, FC_SLANT, FC_SLANT_OBLIQUE) != 0
                else { return nil }
        }
        
        if traits.contains("Condensed") {
            
            guard FcPatternAddInteger(pattern, FC_WIDTH, FC_WIDTH_CONDENSED) != 0
                else { return nil }
        }
    }
    
    let matchPattern = FcMatchKind(rawValue: 0) // FcMatchPattern
    
    guard FcConfigSubstitute(nil, pattern, matchPattern) != 0
        else { return nil }
    
    FcDefaultSubstitute(pattern)
    
    var result = FcResult(0)
    
    guard FcFontMatch(nil, pattern, &result) != nil
        else { return nil }
    
    // success
    cleanup.shouldCleanup = false
    
    return (pattern, family)
}
