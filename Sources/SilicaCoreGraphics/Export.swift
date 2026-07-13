//
//  Export.swift
//  SilicaCoreGraphics
//
//  Created by Alsey Coleman Miller on 7/13/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

@_exported import Silica

#if canImport(CoreGraphics)

// Foundation re-exports Apple's CoreGraphics on Darwin, making unqualified
// references to CG* types ambiguous between Silica and CoreGraphics.
// These module-local aliases resolve every unqualified reference to Silica's types;
// Apple's types are always referenced fully qualified (e.g. `CoreGraphics.CGContext`).
public typealias CGContext = Silica.CGContext
public typealias CGColor = Silica.CGColor
public typealias CGPath = Silica.CGPath
public typealias CGFont = Silica.CGFont
public typealias CGImage = Silica.CGImage
public typealias CGGlyph = Silica.CGGlyph
public typealias CGLineCap = Silica.CGLineCap
public typealias CGLineJoin = Silica.CGLineJoin
public typealias CGTextDrawingMode = Silica.CGTextDrawingMode
public typealias PathElement = Silica.PathElement

#endif
