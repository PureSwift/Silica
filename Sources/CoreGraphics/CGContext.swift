//
//  CGContext.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/9/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica

// MARK: - Typealiases

public typealias CGContext = Silica.Context
public typealias CGFloat = Double
public typealias CGLineJoin = Silica.LineJoin
public typealias CGLineCap = Silica.LineCap
public typealias CGTextDrawingMode = Silica.TextDrawingMode

// MARK: - CGContext Functions

public func CGContextGetPathCurrentPoint(_ context: CGContext) -> CGPoint {
    
    return context.currentPoint ?? CGPoint()
}

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
    
    context.setShadow(offset: offset, radius: radius, color: color)
}

public func CGContextMoveToPoint(_ context: CGContext, _ x: CGFloat, _ y: CGFloat) {
    
    context.move(to: Point(x: x, y: y))
}

public func CGContextAddLineToPoint(_ context: CGContext, _ x: CGFloat, _ y: CGFloat) {
    
    context.line(to: Point(x: x, y: y))
}

public func CGContextAddLines(_ context: CGContext, _ points: UnsafePointer<CGPoint>, _ count: Int) {
    
    guard count > 0 else { return }
    
    CGContextMoveToPoint (context, points[0].x, points[0].y)
    
    for i in 1 ..< count {
        
        CGContextAddLineToPoint (context, points[i].x, points[i].y)
    }
}

public func CGContextAddCurveToPoint(_ context: CGContext, _ cp1x: CGFloat, _ cp1y: CGFloat, _ cp2x: CGFloat, _ cp2y: CGFloat, _ x: CGFloat, _ y: CGFloat) {
    
    context.curve(to: (Point(x: cp1x, y: cp1y), Point(x: cp2x, y: cp2y)), end: Point(x: x, y: y))
}

public func CGContextAddQuadCurveToPoint(_ context: CGContext, _ cpx: CGFloat, _ cpy: CGFloat, _ x: CGFloat, _ y: CGFloat) {
    
    context.quadCurve(to: Point(x: cpx, y: cpy), end: Point(x: x, y: y))
}

public func CGContextAddRect(_ context: CGContext, _ rect: CGRect) {
    
    context.add(rect: rect)
}

public func CGContextAddRects(_ context: CGContext, _ rects: UnsafePointer<CGRect>, _ count: Int) {
    
    for i in 0 ..< count {
        
        CGContextAddRect(context, rects[i])
    }
}

public func CGContextAddArc(_ context: CGContext, _ x: CGFloat, _ y: CGFloat, _ radius: CGFloat, _ startAngle: CGFloat, _ endAngle: CGFloat, _ clockwise: Int32) {
    
    let negative = clockwise != 0
    
    context.arc(center: Point(x: x, y: y), radius: radius, angle: (start: startAngle, end: endAngle), negative: negative)
}

public func CGContextAddArcToPoint(_ context: CGContext, _ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat, _ radius: CGFloat) {
    
    context.arc(to: (first: Point(x: x1, y: y1), second: Point(x: x2, y: y2)), radius: radius)
}

public func CGContextAddPath(_ context: CGContext, _ path: CGPath) {
    
    context.add(path: path)
}

public func CGContextStrokePath(_ context: CGContext) {
    
    context.stroke()
}

public func CGContextFillPath(_ context: CGContext) {
    
    
}

public func CGContextClearPath(_ context: CGContext) {
    
    
}

public func CGContextEOFillPath(_ context: CGContext) {
    
    
}

public func CGContextDrawPath(_ context: CGContext, _ mode: CGPathDrawingMode) {
    
    
}


