//
//  AffineTransformAPI.swift
//  SilicaCoreGraphicsABI
//
//  Created by Alsey Coleman Miller on 11/25/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

// Apple's CoreGraphics is loaded with Foundation on Darwin, and clashes with
// these headers: libCoreGraphics is for other platforms.
#if !canImport(Darwin)

import CSilicaCoreGraphics
import Silica

// The functions of CGAffineTransform.h, in its order.

@c @implementation public func CGAffineTransformMake(_ a: Double, _ b: Double, _ c: Double, _ d: Double,
                                                     _ tx: Double, _ ty: Double) -> CGAffineTransform {
    CGAffineTransform(a: a, b: b, c: c, d: d, tx: tx, ty: ty)
}

@c @implementation public func CGAffineTransformMakeTranslation(_ tx: Double, _ ty: Double) -> CGAffineTransform {
    CGAffineTransform(Silica.AffineTransform(translationX: tx, y: ty))
}

@c @implementation public func CGAffineTransformMakeScale(_ sx: Double, _ sy: Double) -> CGAffineTransform {
    CGAffineTransform(Silica.AffineTransform(scaleX: sx, y: sy))
}

@c @implementation public func CGAffineTransformMakeRotation(_ angle: Double) -> CGAffineTransform {
    CGAffineTransform(Silica.AffineTransform(rotationAngle: angle))
}

@c @implementation public func CGAffineTransformIsIdentity(_ t: CGAffineTransform) -> Bool {
    t.silica.isIdentity
}

@c @implementation public func CGAffineTransformEqualToTransform(_ t1: CGAffineTransform, _ t2: CGAffineTransform) -> Bool {
    t1.silica == t2.silica
}

@c @implementation public func CGAffineTransformTranslate(_ t: CGAffineTransform, _ tx: Double, _ ty: Double) -> CGAffineTransform {
    CGAffineTransform(t.silica.translatedBy(x: tx, y: ty))
}

@c @implementation public func CGAffineTransformScale(_ t: CGAffineTransform, _ sx: Double, _ sy: Double) -> CGAffineTransform {
    CGAffineTransform(t.silica.scaledBy(x: sx, y: sy))
}

@c @implementation public func CGAffineTransformRotate(_ t: CGAffineTransform, _ angle: Double) -> CGAffineTransform {
    CGAffineTransform(t.silica.rotated(by: angle))
}

@c @implementation public func CGAffineTransformInvert(_ t: CGAffineTransform) -> CGAffineTransform {
    CGAffineTransform(t.silica.inverted())
}

@c @implementation public func CGAffineTransformConcat(_ t1: CGAffineTransform, _ t2: CGAffineTransform) -> CGAffineTransform {
    CGAffineTransform(t1.silica.concatenating(t2.silica))
}

@c @implementation public func CGPointApplyAffineTransform(_ point: CGPoint, _ t: CGAffineTransform) -> CGPoint {
    CGPoint(point.silica.applying(t.silica))
}

@c @implementation public func CGSizeApplyAffineTransform(_ size: CGSize, _ t: CGAffineTransform) -> CGSize {
    CGSize(size.silica.applying(t.silica))
}

@c @implementation public func CGRectApplyAffineTransform(_ rect: CGRect, _ t: CGAffineTransform) -> CGRect {
    if CGRectIsNull(rect) || CGRectIsInfinite(rect) { return rect }
    return CGRect(rect.silica.applying(t.silica))
}

#endif
