//
//  Boundary.swift
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

// MARK: - Objects

/// What a `CGPathRef` points to: a path in Silica's terms.
public protocol CoreGraphicsPath: AnyObject {

    var path: Silica.Path { get set }
}

/// Makes the objects CoreGraphics' references point to.
///
/// A reference is a retained Swift object, passed as an opaque pointer. A
/// runtime that needs its own objects behind the references (Perry, whose
/// Core Foundation and Objective-C runtime retain and describe them) replaces
/// these factories before the first object is made, with objects that conform
/// to the same protocols.
public enum CoreGraphicsObjects {

    /// Makes a path object.
    nonisolated(unsafe) public static var makePath: (Silica.Path) -> any CoreGraphicsPath = { PathObject(path: $0) }

    /// The type identifier `CGPathGetTypeID()` returns.
    nonisolated(unsafe) public static var pathTypeID: UInt = 0x5349_4C50 // "SILP"
}

internal final class PathObject: CoreGraphicsPath {

    var path: Silica.Path

    init(path: Silica.Path) {
        self.path = path
    }
}

// MARK: - References

/// The object a reference points to, without retaining it.
internal func object(_ reference: OpaquePointer?) -> AnyObject? {
    guard let reference else { return nil }
    return Unmanaged<AnyObject>.fromOpaque(UnsafeRawPointer(reference)).takeUnretainedValue()
}

/// A reference to an object, retained once for the caller to release.
internal func retainedReference(_ object: AnyObject) -> OpaquePointer {
    OpaquePointer(Unmanaged.passRetained(object).toOpaque())
}

internal func retain(_ reference: OpaquePointer?) {
    guard let reference else { return }
    _ = Unmanaged<AnyObject>.fromOpaque(UnsafeRawPointer(reference)).retain()
}

internal func release(_ reference: OpaquePointer?) {
    guard let reference else { return }
    Unmanaged<AnyObject>.fromOpaque(UnsafeRawPointer(reference)).release()
}

internal func pathObject(_ reference: OpaquePointer?) -> (any CoreGraphicsPath)? {
    object(reference) as? any CoreGraphicsPath
}

/// A new path object's reference, retained for the caller.
internal func makePathReference(_ path: Silica.Path) -> OpaquePointer {
    retainedReference(CoreGraphicsObjects.makePath(path))
}

// MARK: - Geometry

extension CGPoint {

    init(_ point: Silica.Point) {
        self.init(x: point.x, y: point.y)
    }

    var silica: Silica.Point { Silica.Point(x: x, y: y) }
}

extension CGSize {

    init(_ size: Silica.Size) {
        self.init(width: size.width, height: size.height)
    }

    var silica: Silica.Size { Silica.Size(width: width, height: height) }
}

extension CGRect {

    init(_ rect: Silica.Rect) {
        self.init(origin: CGPoint(rect.origin), size: CGSize(rect.size))
    }

    var silica: Silica.Rect { Silica.Rect(origin: origin.silica, size: size.silica) }
}

extension CGAffineTransform {

    init(_ transform: Silica.AffineTransform) {
        self.init(a: transform.a, b: transform.b, c: transform.c, d: transform.d, tx: transform.tx, ty: transform.ty)
    }

    var silica: Silica.AffineTransform { Silica.AffineTransform(a: a, b: b, c: c, d: d, tx: tx, ty: ty) }
}

/// The transform a CoreGraphics function was handed, or the identity for NULL.
internal func transform(_ pointer: UnsafePointer<CGAffineTransform>?) -> Silica.AffineTransform {
    pointer?.pointee.silica ?? .identity
}

#endif
