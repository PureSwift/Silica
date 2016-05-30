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
public final class Font {
    
    // MARK: - Properties
    
    /// Same as full name.
    public let name: String
    
    /// Font family name.
    public let family: String
    
    // MARK: - Internal Properties
    
    internal let internalFont: Cairo.ScaledFont
    
    // MARK: - Initialization
    
    public init?(name: String) {
        
        // create or fetch from cache
        guard let (fontConfigPattern, family) = FontConfigPatternCache[name] ?? FcPattern(name: name)
            else { return nil }
        
        // cache new FcPattern
        if FontConfigPatternCache[name] == nil {
            
            FontConfigPatternCache[name] = (fontConfigPattern, family)
        }
        
        let face = FontFace(fontConfigPattern: fontConfigPattern)
        
        let options = FontOptions()
        options.hintMetrics = CAIRO_HINT_METRICS_OFF
        options.hintStyle = CAIRO_HINT_STYLE_NONE
        
        self.name = name
        self.family = family
        self.internalFont = ScaledFont(face: face, matrix: Matrix.identity, currentTransformation: Matrix.identity, options: options)
    }
}

// MARK: - Private

private var FontConfigPatternCache = [String: (pointer: OpaquePointer, family: String)]()

/// Initialize a pointer to a `FcPattern` object created from the specified PostScript font name.
private func FcPattern(name: String) -> (pointer: OpaquePointer, family: String)? {
    
    guard var pattern = FcPatternCreate()
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
        
        defer { free(traitsCString) }
        
        let traitsString = String(utf8String: trimmedCString)!
        
        let traitsLength = traitsString.utf8.count
        
        let familyLength = name.utf8.count - traitsLength
        
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
