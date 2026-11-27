//
//  AffineTransform.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/8/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

#if !canImport(Darwin) && canImport(FoundationEssentials)
#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(ucrt)
import ucrt
#endif
#elseif canImport(Foundation)
import Foundation
#endif

/// An affine transformation matrix, as CoreGraphics has it:
/// `x' = a·x + c·y + tx` and `y' = b·x + d·y + ty`.
public struct AffineTransform: Equatable, Hashable, Sendable {

    public var a: Double
    public var b: Double
    public var c: Double
    public var d: Double
    public var tx: Double
    public var ty: Double

    public init(a: Double, b: Double, c: Double, d: Double, tx: Double, ty: Double) {
        self.a = a
        self.b = b
        self.c = c
        self.d = d
        self.tx = tx
        self.ty = ty
    }

    public static var identity: AffineTransform { AffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0) }

    public init(translationX tx: Double, y ty: Double) {
        self.init(a: 1, b: 0, c: 0, d: 1, tx: tx, ty: ty)
    }

    public init(scaleX sx: Double, y sy: Double) {
        self.init(a: sx, b: 0, c: 0, d: sy, tx: 0, ty: 0)
    }

    public init(rotationAngle angle: Double) {
        let sine = sin(angle)
        let cosine = cos(angle)
        self.init(a: cosine, b: sine, c: -sine, d: cosine, tx: 0, ty: 0)
    }
}

public extension AffineTransform {

    var isIdentity: Bool { self == .identity }

    /// The transform's matrix without its translation.
    var linear: AffineTransform { AffineTransform(a: a, b: b, c: c, d: d, tx: 0, ty: 0) }

    /// `self`, then `other`, as CGAffineTransformConcat has it.
    func concatenating(_ other: AffineTransform) -> AffineTransform {
        AffineTransform(a: a * other.a + b * other.c,
                        b: a * other.b + b * other.d,
                        c: c * other.a + d * other.c,
                        d: c * other.b + d * other.d,
                        tx: tx * other.a + ty * other.c + other.tx,
                        ty: tx * other.b + ty * other.d + other.ty)
    }

    /// A translation applied before this transform.
    func translatedBy(x: Double, y: Double) -> AffineTransform {
        AffineTransform(translationX: x, y: y).concatenating(self)
    }

    /// A scale applied before this transform.
    func scaledBy(x: Double, y: Double) -> AffineTransform {
        AffineTransform(scaleX: x, y: y).concatenating(self)
    }

    /// A rotation applied before this transform.
    func rotated(by angle: Double) -> AffineTransform {
        AffineTransform(rotationAngle: angle).concatenating(self)
    }

    /// The determinant of the linear part. Zero when the transform can't be inverted.
    var determinant: Double { a * d - b * c }

    /// The inverse, or `self` when it can't be inverted, as CGAffineTransformInvert does.
    func inverted() -> AffineTransform {
        invertedIfPossible() ?? self
    }

    /// The inverse, or nil when the transform can't be inverted.
    func invertedIfPossible() -> AffineTransform? {
        let determinant = self.determinant
        guard determinant != 0, determinant.isFinite else { return nil }
        return AffineTransform(a: d / determinant,
                               b: -b / determinant,
                               c: -c / determinant,
                               d: a / determinant,
                               tx: (c * ty - d * tx) / determinant,
                               ty: (b * tx - a * ty) / determinant)
    }
}

// MARK: - Applying

public extension Point {

    func applying(_ t: AffineTransform) -> Point {
        Point(x: t.a * x + t.c * y + t.tx, y: t.b * x + t.d * y + t.ty)
    }
}

public extension Size {

    /// The size transformed by the linear part, as CGSizeApplyAffineTransform does.
    func applying(_ t: AffineTransform) -> Size {
        Size(width: t.a * width + t.c * height, height: t.b * width + t.d * height)
    }
}

public extension Vector {

    func applying(_ t: AffineTransform) -> Vector {
        Vector(dx: t.a * dx + t.c * dy, dy: t.b * dx + t.d * dy)
    }
}

public extension Rect {

    /// The smallest rectangle that contains the transformed corners.
    func applying(_ t: AffineTransform) -> Rect {
        if isNull { return self }
        let corners = [Point(x: minX, y: minY), Point(x: maxX, y: minY),
                       Point(x: maxX, y: maxY), Point(x: minX, y: maxY)].map { $0.applying(t) }
        var minX = corners[0].x, maxX = corners[0].x, minY = corners[0].y, maxY = corners[0].y
        for corner in corners.dropFirst() {
            minX = min(minX, corner.x)
            maxX = max(maxX, corner.x)
            minY = min(minY, corner.y)
            maxY = max(maxY, corner.y)
        }
        return Rect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
