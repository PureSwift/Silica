//
//  LayerAPI.swift
//  SilicaCoreGraphicsABI
//
//  Created by Alsey Coleman Miller on 11/25/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

// Apple's CoreGraphics is loaded with Foundation on Darwin, and clashes with
// these headers: libCoreGraphics is for other platforms. Layers draw with
// Silica's Cairo renderer, as contexts do.
#if !canImport(Darwin) && canImport(Cairo)

import CSilicaCoreGraphics
import Silica
import SilicaCairo

// The functions of CGLayer.h.

/// What a `CGLayerRef` points to: a bitmap context of its own, in Cairo's
/// layout, drawn into once and composited from its surface.
internal final class LayerObject {

    let size: Silica.Size

    /// The layer's context.
    let context: Retained

    init(size: Silica.Size, context: OpaquePointer) {
        self.size = size
        self.context = Retained(context)
    }

    var contextObject: ContextObject {
        object(context.reference, as: ContextObject.self)!
    }
}

@c @implementation public func CGLayerGetTypeID() -> UInt {
    CoreGraphicsObjects.typeID(of: .layer)
}

/// A pixel a unit of the size, as a layer of a bitmap context is.
@c @implementation public func CGLayerCreateWithContext(_ context: SilicaCGContextRef?, _ size: CGSize,
                                                        _ auxiliaryInfo: UnsafeRawPointer?) -> SilicaCGLayerRef? {
    guard contextObject(context) != nil, size.width > 0, size.height > 0, size.width.isFinite, size.height.isFinite else { return nil }
    let width = Int(size.width.rounded(.up)), height = Int(size.height.rounded(.up))
    guard let reference = makeBitmapContext(nil, width, height, 8, width * 4, ColorSpaceObject.deviceRGB,
                                            cairoNativeBitmapInfo, nil) else { return nil }
    defer { release(reference) }
    return makeReference(LayerObject(size: size.silica, context: reference))
}

@c @implementation public func CGLayerRetain(_ layer: SilicaCGLayerRef?) -> SilicaCGLayerRef? {
    retain(layer)
    return layer
}

@c @implementation public func CGLayerRelease(_ layer: SilicaCGLayerRef?) {
    release(layer)
}

@c @implementation public func CGLayerGetSize(_ layer: SilicaCGLayerRef?) -> CGSize {
    guard let layer = object(layer, as: LayerObject.self) else { return CGSizeZero }
    return CGSize(layer.size)
}

@c @implementation public func CGLayerGetContext(_ layer: SilicaCGLayerRef?) -> SilicaCGContextRef? {
    object(layer, as: LayerObject.self)?.context.reference
}

@c @implementation public func CGContextDrawLayerInRect(_ context: SilicaCGContextRef?, _ rect: CGRect, _ layer: SilicaCGLayerRef?) {
    guard let target = contextObject(context), let layer = object(layer, as: LayerObject.self) else { return }
    let rect = rect.silica.standardized
    guard rect.width > 0, rect.height > 0 else { return }
    let storage = layer.contextObject.bitmap
    storage.surface.flush()
    // the layer's pixels a unit of its size, upright, as an image draws
    let drawn = Silica.Rect(x: rect.minX, y: rect.minY, width: rect.width * Double(storage.width) / layer.size.width,
                            height: rect.height * Double(storage.height) / layer.size.height)
    let flip = Silica.AffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: drawn.minY + drawn.maxY)
    target.paintDirectly { renderer in
        renderer.saveState()
        renderer.concatenate(flip)
        renderer.draw(surface: storage.surface, width: storage.width, height: storage.height, in: drawn)
        renderer.restoreState()
    }
}

@c @implementation public func CGContextDrawLayerAtPoint(_ context: SilicaCGContextRef?, _ point: CGPoint, _ layer: SilicaCGLayerRef?) {
    guard let layerObject = object(layer, as: LayerObject.self) else { return }
    CGContextDrawLayerInRect(context, CGRect(origin: point, size: CGSize(layerObject.size)), layer)
}

#endif
