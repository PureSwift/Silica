//
//  CGContext.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 10/5/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

/// CoreGraphics compatible wrapper for `Silica.Context`.
public final class CGContext {
    
    public let silicaContext: Silica.Context
    
    public init(_ context: Silica.Context) {
        
        self.silicaContext = context
    }
    
    @inline(__always)
    public func beginTransparencyLayer(auxiliaryInfo: [String: Any]?) {
        
        try! silicaContext.beginTransparencyLayer()
    }
    
    @inline(__always)
    public func endTransparencyLayer() {
        
        try! silicaContext.endTransparencyLayer()
    }
    
    @inline(__always)
    public func saveGState() {
        
        try! silicaContext.save()
    }
    
    @inline(__always)
    public func restoreGState() {
        
        try! silicaContext.restore()
    }
    
    @inline(__always)
    public func clip(to rect: CGRect) {
        
        silicaContext.clip(to: rect)
    }
    
    @inline(__always)
    public func translateBy(x: CGFloat, y: CGFloat) {
        
        silicaContext.translate(x: x, y: y)
    }
    
    @inline(__always)
    public func scaleBy(x: CGFloat, y: CGFloat) {
        
        silicaContext.scale(x: x, y: y)
    }
    
    @inline(__always)
    public func draw(_ image: CGImage, in rect: CGRect) {
        
        silicaContext.draw(image, in: rect)
    }
}
