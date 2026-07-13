//
//  Export.swift
//  SilicaCairo
//
//  Created by Alsey Coleman Miller on 7/13/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

@_exported import Silica

// On Darwin platforms, Foundation re-exports CoreGraphics, making unqualified
// references to CG* types ambiguous between Silica and Apple's CoreGraphics.
// These module-local aliases resolve every unqualified reference to Silica's types.
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
