//
//  Font.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/9/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Cairo
import CCairo
import FontConfig
import struct Foundation.CGFloat
import struct Foundation.CGSize
import struct Foundation.CGPoint

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
    
    public init?(name: String, configuration: FontConfiguration = .current) {
        
        if let cachedFont = CGFont.cache[name] {
            
            self = cachedFont
            
        } else {
            
            // create new font
            guard let pattern = FontConfig.Pattern(cgFont: name, configuration: configuration),
                let family = pattern.family
                else { return nil }
            
            let face = FontFace(pattern: pattern)
            
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

// MARK: - Font Config Pattern

internal extension FontConfig.Pattern {
    
    convenience init?(cgFont name: String, configuration: FontConfiguration = .current) {
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
