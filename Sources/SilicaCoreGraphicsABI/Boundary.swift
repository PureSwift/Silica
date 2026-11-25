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

/// The objects CoreGraphics' references point to.
///
/// A reference (`CGPathRef`, `CGContextRef`, …) is a retained object, passed
/// as an opaque pointer. Each kind of reference has an object of its own
/// class here. A runtime that needs objects of its own behind the references
/// (Perry, whose Core Foundation and Objective-C runtime retain and describe
/// them) sets `wrap` and `unwrap` before the first reference is made: `wrap`
/// puts each new object inside one of its own, and `unwrap` takes it back out.
public enum CoreGraphicsObjects {

    /// What a new reference points to, holding the object: the object itself by default.
    nonisolated(unsafe) public static var wrap: (AnyObject) -> AnyObject = { $0 }

    /// The object inside what a reference points to, or nil if it holds none.
    nonisolated(unsafe) public static var unwrap: (AnyObject) -> AnyObject? = { $0 }

    /// The kinds of objects, which `CG…GetTypeID()` tell apart.
    public enum Kind: UInt, CaseIterable, Sendable {
        case path
        case colorSpace
        case color
        case gradient
        case image
        case context
        case dataProvider
        case font
    }

    /// Core Foundation, for the functions that take or return its objects
    /// (`CFStringRef`, `CFDataRef`, `CFURLRef`). Silica has none: a runtime
    /// that does (Perry) sets this, and without it those functions return
    /// NULL or zero.
    nonisolated(unsafe) public static var coreFoundation: CoreFoundationBridge?

    /// The first type identifier: each kind's is this plus its raw value.
    nonisolated(unsafe) public static var typeIDBase: UInt = 0x5349_4C00 // "SIL"

    /// The type identifier of a kind of object.
    public static func typeID(of kind: Kind) -> UInt {
        typeIDBase + kind.rawValue
    }

    /// The kind of an object made here, as `wrap` receives it.
    public static func kind(of object: AnyObject) -> Kind? {
        switch object {
        case is PathObject: return .path
        case is ColorSpaceObject: return .colorSpace
        case is ColorObject: return .color
        case is GradientObject: return .gradient
        case is ImageObject: return .image
        case is DataProviderObject: return .dataProvider
        #if canImport(Cairo)
        // contexts draw with Cairo, where there is Cairo
        case is ContextObject: return .context
        case is FontObject: return .font
        #endif
        default: return nil
        }
    }
}

/// Core Foundation's objects, as a runtime that has them converts them.
public struct CoreFoundationBridge {

    /// The string a `CFStringRef` holds.
    public var string: (UnsafeRawPointer) -> String?

    /// A new `CFStringRef`, retained for the caller.
    public var makeString: (String) -> UnsafeRawPointer?

    /// The bytes a `CFDataRef` holds.
    public var data: (UnsafeRawPointer) -> [UInt8]?

    /// A new `CFDataRef`, retained for the caller.
    public var makeData: ([UInt8]) -> UnsafeRawPointer?

    /// The file path of a file `CFURLRef`.
    public var filePath: (UnsafeRawPointer) -> String?

    public init(string: @escaping (UnsafeRawPointer) -> String?,
                makeString: @escaping (String) -> UnsafeRawPointer?,
                data: @escaping (UnsafeRawPointer) -> [UInt8]?,
                makeData: @escaping ([UInt8]) -> UnsafeRawPointer?,
                filePath: @escaping (UnsafeRawPointer) -> String?) {
        self.string = string
        self.makeString = makeString
        self.data = data
        self.makeData = makeData
        self.filePath = filePath
    }
}

/// The string of a Core Foundation string, where there's a bridge.
internal func string(_ reference: OpaquePointer?) -> String? {
    guard let reference, let bridge = CoreGraphicsObjects.coreFoundation else { return nil }
    return bridge.string(UnsafeRawPointer(reference))
}

/// A new Core Foundation string, where there's a bridge.
internal func makeCFString(_ string: String?) -> OpaquePointer? {
    guard let string, let bridge = CoreGraphicsObjects.coreFoundation, let made = bridge.makeString(string) else { return nil }
    return OpaquePointer(made)
}

/// A new Core Foundation data object, where there's a bridge.
internal func makeCFData(_ bytes: [UInt8]?) -> OpaquePointer? {
    guard let bytes, let bridge = CoreGraphicsObjects.coreFoundation, let made = bridge.makeData(bytes) else { return nil }
    return OpaquePointer(made)
}

// MARK: - References

/// The object a reference points to, of a kind, without retaining it.
internal func object<T: AnyObject>(_ reference: OpaquePointer?, as type: T.Type = T.self) -> T? {
    guard let reference else { return nil }
    let target = Unmanaged<AnyObject>.fromOpaque(UnsafeRawPointer(reference)).takeUnretainedValue()
    return CoreGraphicsObjects.unwrap(target) as? T
}

/// A new reference to an object, retained once for the caller to release.
internal func makeReference(_ object: AnyObject) -> OpaquePointer {
    OpaquePointer(Unmanaged.passRetained(CoreGraphicsObjects.wrap(object)).toOpaque())
}

internal func retain(_ reference: OpaquePointer?) {
    guard let reference else { return }
    _ = Unmanaged<AnyObject>.fromOpaque(UnsafeRawPointer(reference)).retain()
}

internal func release(_ reference: OpaquePointer?) {
    guard let reference else { return }
    Unmanaged<AnyObject>.fromOpaque(UnsafeRawPointer(reference)).release()
}

/// A reference an object keeps to another, owning it: the reference it was
/// handed, retained, so the object a caller later gets back is the same one.
internal final class Retained {

    let reference: OpaquePointer

    init(_ reference: OpaquePointer) {
        retain(reference)
        self.reference = reference
    }

    deinit {
        release(reference)
    }
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
