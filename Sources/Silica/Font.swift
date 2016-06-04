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

/// Silica's `Font` type.
public struct Font: Equatable, Hashable {
    
    /// Private font cache.
    private static var cache = [String: Font]()
    
    // MARK: - Properties
    
    /// Same as full name.
    public let name: String
    
    /// Font family name.
    public let family: String
    
    // MARK: - Internal Properties
    
    public let scaledFont: Cairo.ScaledFont
    
    // MARK: - Initialization
    
    public init?(name: String) {
        
        if let cachedFont = Font.cache[name] {
            
            self = cachedFont
            
        } else {
            
            // create new font
            guard let (fontConfigPattern, family) = FcPattern(name: name)
                else { return nil }
            
            let face = FontFace(fontConfigPattern: fontConfigPattern)
            
            let options = FontOptions()
            options.hintMetrics = CAIRO_HINT_METRICS_OFF
            options.hintStyle = CAIRO_HINT_STYLE_NONE
            
            self.name = name
            self.family = family
            self.scaledFont = ScaledFont(face: face, matrix: Matrix.identity, currentTransformation: Matrix.identity, options: options)
            
            // Default font is Verdana, make sure the name is correct
            let defaultFontName = "Verdana"
            
            guard name == defaultFontName || scaledFont.fullName != defaultFontName
                else { return nil }
            
            // cache
            Font.cache[name] = self
        }
    }
}

// MARK: - Equatable

public func == (lhs: Font, rhs: Font) -> Bool {
    
    // quick and easy way
    return lhs.name == rhs.name
}

// MARK: - Hashable

public extension Font {
    
    var hashValue: Int {
        
        return name.hashValue
    }
}

// MARK: - Text Math

public extension Font {
    
    func advances(for glyphs: [FontIndex], fontSize: Double, textMatrix: AffineTransform = AffineTransform.identity, characterSpacing: Double = 0.0) -> [Size] {
        
        // only horizontal layout is supported
        
        // calculate advances
        let glyphSpaceToTextSpace = fontSize / Double(scaledFont.unitsPerEm)
        
        return scaledFont.advances(for: glyphs).map { Size(width: (Double($0) * glyphSpaceToTextSpace) + characterSpacing, height: 0).applied(transform: textMatrix) }
    }
    
    func positions(for advances: [Size], textMatrix: AffineTransform = AffineTransform.identity) -> [Point] {
        
        var glyphPositions = [Point](repeating: Point(), count: advances.count)
        
        // first position is {0, 0}
        for i in 1 ..< glyphPositions.count {
            
            let textSpaceAdvance = advances[i-1].applied(transform: textMatrix)
            
            glyphPositions[i] = Point(x: glyphPositions[i-1].x + textSpaceAdvance.width,
                                      y: glyphPositions[i-1].y + textSpaceAdvance.height)
        }
        
        return glyphPositions
    }
    
    func singleLineWidth(text: String, fontSize: Double, textMatrix: AffineTransform = AffineTransform.identity) -> Double {
        
        let glyphs = text.unicodeScalars.map { scaledFont[UInt($0.value)] }
        
        let textWidth = advances(for: glyphs, fontSize: fontSize, textMatrix: textMatrix).reduce(Double(0), combine: { $0.0 +  $0.1.width })
        
        return textWidth
    }
}

// MARK: - Private

/// Initialize a pointer to a `FcPattern` object created from the specified PostScript font name.
private func FcPattern(name: String) -> (pointer: OpaquePointer, family: String)? {
    
    guard let pattern = FcPatternCreate()
        else { return nil }
    
    /// hacky way to cleanup, `defer` will copy initial value of `Bool` so this is needed.
    /// ARC will cleanup for us
    final class ErrorCleanup {
        
        var shouldCleanup = true
        
        let cleanup: () -> ()
        
        deinit { if shouldCleanup { cleanup() } }
        
        init(cleanup: () -> ()) {
            
            self.cleanup = cleanup
        }
    }
    
    let cleanup = ErrorCleanup(cleanup: { FcPatternDestroy(pattern) })
    
    let separator = "-".withCString { (pointer) in return pointer[0] }
    
    let traits: String?
    
    let family: String
    
    if let traitsCString = strchr(name, CInt(separator)) {
        
        let trimmedCString = traitsCString.advanced(by: 1)
        
        // should free memory, but crashes
        // defer { free(traitsCString) }
        
        let traitsString = String(cString: trimmedCString)
        
        let familyLength = name.utf8.count - traitsString.utf8.count - 1 // for separator
        
        family = name.substring(range: 0 ..< familyLength)!
        
        traits = traitsString
        
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
    
    guard FcConfigSubstitute(nil, pattern, FcMatchPattern) != 0
        else { return nil }
    
    FcDefaultSubstitute(pattern)
    
    var result = FcResult(0)
    
    guard FcFontMatch(nil, pattern, &result) != nil
        else { return nil }
    
    // success
    cleanup.shouldCleanup = false
    
    return (pattern, family)
}

// MARK: - String Extensions

internal extension String {
    
    func substring(range: Range<Int>) -> String? {
        let indexRange = utf8.index(utf8.startIndex, offsetBy: range.lowerBound) ..< utf8.index(utf8.startIndex, offsetBy: range.upperBound)
        return String(utf8[indexRange])
    }
}

internal extension String {
    
    func contains(_ other: String) -> Bool {
        
        return strstr(self, other) != nil
    }
}
