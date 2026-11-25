//
//  GeometryAPI.swift
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

// The functions of CGGeometry.h, in its order. CGRectNull has an infinite
// origin; CGRectInfinite is a rectangle as large as CGFloat holds, and stays
// itself under the operations that would otherwise move it.

private func isNull(_ rect: CGRect) -> Bool {
    rect.origin.x == .infinity || rect.origin.y == .infinity
}

private func isInfinite(_ rect: CGRect) -> Bool {
    CGRectEqualToRect(rect, CGRectInfinite)
}

@c @implementation public func CGRectGetMinX(_ rect: CGRect) -> Double {
    rect.silica.minX
}

@c @implementation public func CGRectGetMidX(_ rect: CGRect) -> Double {
    rect.silica.midX
}

@c @implementation public func CGRectGetMaxX(_ rect: CGRect) -> Double {
    rect.silica.maxX
}

@c @implementation public func CGRectGetMinY(_ rect: CGRect) -> Double {
    rect.silica.minY
}

@c @implementation public func CGRectGetMidY(_ rect: CGRect) -> Double {
    rect.silica.midY
}

@c @implementation public func CGRectGetMaxY(_ rect: CGRect) -> Double {
    rect.silica.maxY
}

@c @implementation public func CGRectGetWidth(_ rect: CGRect) -> Double {
    rect.silica.width
}

@c @implementation public func CGRectGetHeight(_ rect: CGRect) -> Double {
    rect.silica.height
}

@c @implementation public func CGPointEqualToPoint(_ point1: CGPoint, _ point2: CGPoint) -> Bool {
    point1.x == point2.x && point1.y == point2.y
}

@c @implementation public func CGSizeEqualToSize(_ size1: CGSize, _ size2: CGSize) -> Bool {
    size1.width == size2.width && size1.height == size2.height
}

/// Equal when both are null, or when their standardized forms match.
@c @implementation public func CGRectEqualToRect(_ rect1: CGRect, _ rect2: CGRect) -> Bool {
    if isNull(rect1) || isNull(rect2) { return isNull(rect1) && isNull(rect2) }
    return rect1.silica.standardized == rect2.silica.standardized
}

@c @implementation public func CGRectStandardize(_ rect: CGRect) -> CGRect {
    if isNull(rect) || isInfinite(rect) { return rect }
    return CGRect(rect.silica.standardized)
}

@c @implementation public func CGRectIsEmpty(_ rect: CGRect) -> Bool {
    isNull(rect) || rect.size.width == 0 || rect.size.height == 0
}

@c @implementation public func CGRectIsNull(_ rect: CGRect) -> Bool {
    isNull(rect)
}

@c @implementation public func CGRectIsInfinite(_ rect: CGRect) -> Bool {
    isInfinite(rect)
}

@c @implementation public func CGRectInset(_ rect: CGRect, _ dx: Double, _ dy: Double) -> CGRect {
    if isNull(rect) || isInfinite(rect) { return rect }
    let inset = rect.silica.insetBy(dx: dx, dy: dy)
    return inset.isNull ? CGRectNull : CGRect(inset)
}

@c @implementation public func CGRectIntegral(_ rect: CGRect) -> CGRect {
    if isNull(rect) || isInfinite(rect) { return rect }
    return CGRect(rect.silica.integral)
}

@c @implementation public func CGRectUnion(_ r1: CGRect, _ r2: CGRect) -> CGRect {
    if isInfinite(r1) || isInfinite(r2) { return CGRectInfinite }
    // with the null rectangle, the other one as it is
    if isNull(r1) { return r2 }
    if isNull(r2) { return r1 }
    return CGRect(r1.silica.union(r2.silica))
}

@c @implementation public func CGRectIntersection(_ r1: CGRect, _ r2: CGRect) -> CGRect {
    if isNull(r1) || isNull(r2) { return CGRectNull }
    if isInfinite(r1) { return CGRectStandardize(r2) }
    if isInfinite(r2) { return CGRectStandardize(r1) }
    let intersection = r1.silica.intersection(r2.silica)
    return intersection.isNull ? CGRectNull : CGRect(intersection)
}

@c @implementation public func CGRectOffset(_ rect: CGRect, _ dx: Double, _ dy: Double) -> CGRect {
    if isNull(rect) || isInfinite(rect) { return rect }
    return CGRect(rect.silica.offsetBy(dx: dx, dy: dy))
}

/// Cuts `amount` off the rectangle's `edge` into `slice`, and the rest into
/// `remainder`. The amount is kept between zero and the rectangle's side.
@c @implementation public func CGRectDivide(_ rect: CGRect, _ slice: UnsafeMutablePointer<CGRect>,
                                            _ remainder: UnsafeMutablePointer<CGRect>, _ amount: Double, _ edge: CGRectEdge) {
    if isNull(rect) {
        slice.pointee = CGRectNull
        remainder.pointee = CGRectNull
        return
    }
    let r = rect.silica.standardized
    let horizontal = edge == CGRectEdge(CGRectMinXEdge) || edge == CGRectEdge(CGRectMaxXEdge)
    let side = horizontal ? r.width : r.height
    let cut = min(max(amount, 0), side)
    switch edge {
    case CGRectEdge(CGRectMinXEdge):
        slice.pointee = CGRect(Rect(x: r.minX, y: r.minY, width: cut, height: r.height))
        remainder.pointee = CGRect(Rect(x: r.minX + cut, y: r.minY, width: r.width - cut, height: r.height))
    case CGRectEdge(CGRectMaxXEdge):
        slice.pointee = CGRect(Rect(x: r.maxX - cut, y: r.minY, width: cut, height: r.height))
        remainder.pointee = CGRect(Rect(x: r.minX, y: r.minY, width: r.width - cut, height: r.height))
    case CGRectEdge(CGRectMinYEdge):
        slice.pointee = CGRect(Rect(x: r.minX, y: r.minY, width: r.width, height: cut))
        remainder.pointee = CGRect(Rect(x: r.minX, y: r.minY + cut, width: r.width, height: r.height - cut))
    default:
        slice.pointee = CGRect(Rect(x: r.minX, y: r.maxY - cut, width: r.width, height: cut))
        remainder.pointee = CGRect(Rect(x: r.minX, y: r.minY, width: r.width, height: r.height - cut))
    }
}

@c @implementation public func CGRectContainsPoint(_ rect: CGRect, _ point: CGPoint) -> Bool {
    if isNull(rect) { return false }
    return rect.silica.contains(point.silica)
}

/// Whether the union is the first rectangle: the null rectangle contains itself.
@c @implementation public func CGRectContainsRect(_ rect1: CGRect, _ rect2: CGRect) -> Bool {
    CGRectEqualToRect(CGRectUnion(rect1, rect2), rect1)
}

/// Whether the rectangles overlap: two with area that only touch don't, but
/// an empty rectangle (a point or a line) inside or on another does.
@c @implementation public func CGRectIntersectsRect(_ rect1: CGRect, _ rect2: CGRect) -> Bool {
    let intersection = CGRectIntersection(rect1, rect2)
    if CGRectIsNull(intersection) { return false }
    return CGRectIsEmpty(intersection) == false || CGRectIsEmpty(rect1) || CGRectIsEmpty(rect2)
}

#endif
