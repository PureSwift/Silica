//
//  CGContext.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/9/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Silica

public typealias CGContext = CGContextRef

public typealias CGContextRef = Silica.Context

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

public func CGContextSetLineWidth(_ context: CGContext, lineWidth: CGFloat) {
    
    context.lineWidth = lineWidth
}



