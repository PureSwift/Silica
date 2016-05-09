//
//  CGContext.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/9/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica

// MARK: - Typealiases

public typealias CGContext = CGContextRef
public typealias CGContextRef = Silica.Context
public typealias CGFloat = Double
public typealias CGLineJoin = Silica.LineJoin
public typealias CGLineCap = Silica.LineCap

// MARK: - CGContext Functions

public func CGContextBeginPage(_ context: CGContext, _ mediaBox: UnsafePointer<CGRect>? = nil) {
    
    // ignore media box
    assert(mediaBox == nil, "mediaBox not implemented")
    
    context.beginPage()
}

public func CGContextEndPage(_ context: CGContext) {
    
    context.endPage()
}

public func CGContextScaleCTM(_ context: CGContext, _ sx: CGFloat, _ sy: CGFloat) {
    
    context.scale(x: sx, y: sy)
}

public func CGContextTranslateCTM(_ context: CGContext, _ tx: CGFloat, _ ty: CGFloat) {
    
    context.translate(x: tx, y: ty)
}

public func CGContextRotateCTM(_ context: CGContext, _ angle: CGFloat) {
    
    context.rotate(angle)
}

public func CGContextConcatCTM(_ context: CGContext, _ transform: CGAffineTransform) {
    
    context.transform(transform)
}

public func CGContextGetCTM(_ context: CGContext) -> CGAffineTransform {
    
    return context.currentTransform
}

public func CGContextSaveGState(_ context: CGContext) {
    
    try! context.save()
}

public func CGContextRestoreGState(_ context: CGContext) {
    
    try! context.restore()
}

public func CGContextSetShouldAntialias(_ context: CGContext, _ shouldAntialias: Bool) {
    
    context.shouldAntialias = shouldAntialias
}

public func CGContextSetLineWidth(_ context: CGContext, _ lineWidth: CGFloat) {
    
    context.lineWidth = lineWidth
}

public func CGContextSetLineJoin(_ context: CGContext, _ lineJoin: CGLineJoin) {
    
    context.lineJoin = lineJoin
}

public func CGContextSetLineCap(_ context: CGContext, _ lineCap: LineCap) {
    
    context.lineCap = lineCap
}

public func CGContextSetLineDash(_ context: CGContext, _ phase: CGFloat, _ lengths: UnsafePointer<CGFloat>, _ count: Int) {
    
    var lengthsArray = [CGFloat](repeating: 0, count: count)
    
    for i in 0 ..< count {
        
        lengthsArray[i] = lengths[i]
    }
    
    context.lineDash = (phase: phase, lengths: lengthsArray)
}

public func CGContextSetFlatness(_ context: CGContext, _ flatness: CGFloat) {
    
    context.tolerance = flatness
}

public func CGContextSetShadow(_ context: CGContext, _ offset: CGSize, _ radius: CGFloat) {
    
    let defaultShadowColor = CGColorCreateGenericGray(0, 0.3)
    
    CGContextSetShadowWithColor(context, offset, radius, defaultShadowColor)
}

public func CGContextSetShadowWithColor(_ context: CGContext, _ offset: CGSize, _ radius: CGFloat, _ color: CGColor) {
    
    
}


