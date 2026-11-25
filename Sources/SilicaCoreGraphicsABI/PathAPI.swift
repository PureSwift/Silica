//
//  PathAPI.swift
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

// The functions of CGPath.h, in its order.

/// What a `CGPathRef` points to.
internal final class PathObject {

    var path: Silica.Path

    init(path: Silica.Path) {
        self.path = path
    }
}

/// A new path's reference, retained for the caller.
internal func makePathReference(_ path: Silica.Path) -> OpaquePointer {
    makeReference(PathObject(path: path))
}

@c @implementation public func CGPathGetTypeID() -> UInt {
    CoreGraphicsObjects.typeID(of: .path)
}

// MARK: - Creating

@c @implementation public func CGPathCreateMutable() -> SilicaCGMutablePathRef {
    makePathReference(Silica.Path())
}

@c @implementation public func CGPathCreateCopy(_ path: SilicaCGPathRef?) -> SilicaCGPathRef? {
    guard let object = object(path, as: PathObject.self) else { return nil }
    return makePathReference(object.path)
}

@c @implementation public func CGPathCreateCopyByTransformingPath(_ path: SilicaCGPathRef?,
                                                                  _ transform: UnsafePointer<CGAffineTransform>?) -> SilicaCGPathRef? {
    guard let object = object(path, as: PathObject.self) else { return nil }
    return makePathReference(object.path.applying(SilicaCoreGraphicsABI.transform(transform)))
}

@c @implementation public func CGPathCreateMutableCopy(_ path: SilicaCGPathRef?) -> SilicaCGMutablePathRef? {
    guard let object = object(path, as: PathObject.self) else { return nil }
    return makePathReference(object.path)
}

@c @implementation public func CGPathCreateMutableCopyByTransformingPath(_ path: SilicaCGPathRef?,
                                                                        _ transform: UnsafePointer<CGAffineTransform>?) -> SilicaCGMutablePathRef? {
    guard let object = object(path, as: PathObject.self) else { return nil }
    return makePathReference(object.path.applying(SilicaCoreGraphicsABI.transform(transform)))
}

@c @implementation public func CGPathCreateWithRect(_ rect: CGRect, _ transform: UnsafePointer<CGAffineTransform>?) -> SilicaCGPathRef {
    var path = Silica.Path()
    path.addRect(rect.silica)
    return makePathReference(path.applying(SilicaCoreGraphicsABI.transform(transform)))
}

@c @implementation public func CGPathCreateWithEllipseInRect(_ rect: CGRect, _ transform: UnsafePointer<CGAffineTransform>?) -> SilicaCGPathRef {
    var path = Silica.Path()
    path.addEllipse(in: rect.silica)
    return makePathReference(path.applying(SilicaCoreGraphicsABI.transform(transform)))
}

@c @implementation public func CGPathCreateWithRoundedRect(_ rect: CGRect, _ cornerWidth: Double, _ cornerHeight: Double,
                                                           _ transform: UnsafePointer<CGAffineTransform>?) -> SilicaCGPathRef {
    var path = Silica.Path()
    path.addRoundedRect(in: rect.silica, cornerSize: Size(width: cornerWidth, height: cornerHeight))
    return makePathReference(path.applying(SilicaCoreGraphicsABI.transform(transform)))
}

@c @implementation public func CGPathRetain(_ path: SilicaCGPathRef?) -> SilicaCGPathRef? {
    retain(path)
    return path
}

@c @implementation public func CGPathRelease(_ path: SilicaCGPathRef?) {
    release(path)
}

@c @implementation public func CGPathEqualToPath(_ path1: SilicaCGPathRef?, _ path2: SilicaCGPathRef?) -> Bool {
    if path1 == path2 { return true }
    guard let first = object(path1, as: PathObject.self), let second = object(path2, as: PathObject.self) else { return false }
    return first.path == second.path
}

// MARK: - Building

/// Adds elements built in the path's space, transformed by `m`.
private func build(_ path: SilicaCGMutablePathRef?, _ m: UnsafePointer<CGAffineTransform>?, _ body: (inout Silica.Path) -> Void) {
    guard let object = object(path, as: PathObject.self) else { return }
    var added = Silica.Path()
    // continue from the current point, untransformed, so arcs and lines join it
    let current = object.path.currentPoint
    let inverse = transform(m).invertedIfPossible()
    if let current, let inverse {
        added.move(to: current.applying(inverse))
    }
    let seeded = added.elements.count
    body(&added)
    object.path.addPath(Silica.Path(elements: Array(added.elements.dropFirst(seeded))), transform: transform(m))
}

@c @implementation public func CGPathMoveToPoint(_ path: SilicaCGMutablePathRef?, _ m: UnsafePointer<CGAffineTransform>?, _ x: Double, _ y: Double) {
    object(path, as: PathObject.self)?.path.elements.append(.move(to: Point(x: x, y: y).applying(transform(m))))
}

/// Ignored without a current point, as in CoreGraphics.
@c @implementation public func CGPathAddLineToPoint(_ path: SilicaCGMutablePathRef?, _ m: UnsafePointer<CGAffineTransform>?, _ x: Double, _ y: Double) {
    guard let object = object(path, as: PathObject.self), object.path.currentPoint != nil else { return }
    object.path.elements.append(.line(to: Point(x: x, y: y).applying(transform(m))))
}

@c @implementation public func CGPathAddQuadCurveToPoint(_ path: SilicaCGMutablePathRef?, _ m: UnsafePointer<CGAffineTransform>?,
                                                         _ cpx: Double, _ cpy: Double, _ x: Double, _ y: Double) {
    guard let object = object(path, as: PathObject.self), object.path.currentPoint != nil else { return }
    let t = transform(m)
    object.path.elements.append(.quadCurve(to: Point(x: x, y: y).applying(t), control: Point(x: cpx, y: cpy).applying(t)))
}

@c @implementation public func CGPathAddCurveToPoint(_ path: SilicaCGMutablePathRef?, _ m: UnsafePointer<CGAffineTransform>?,
                                                     _ cp1x: Double, _ cp1y: Double, _ cp2x: Double, _ cp2y: Double,
                                                     _ x: Double, _ y: Double) {
    guard let object = object(path, as: PathObject.self), object.path.currentPoint != nil else { return }
    let t = transform(m)
    object.path.elements.append(.curve(to: Point(x: x, y: y).applying(t),
                                       control1: Point(x: cp1x, y: cp1y).applying(t),
                                       control2: Point(x: cp2x, y: cp2y).applying(t)))
}

@c @implementation public func CGPathCloseSubpath(_ path: SilicaCGMutablePathRef?) {
    object(path, as: PathObject.self)?.path.closeSubpath()
}

@c @implementation public func CGPathAddRect(_ path: SilicaCGMutablePathRef?, _ m: UnsafePointer<CGAffineTransform>?, _ rect: CGRect) {
    build(path, m) { $0.addRect(rect.silica) }
}

@c @implementation public func CGPathAddRects(_ path: SilicaCGMutablePathRef?, _ m: UnsafePointer<CGAffineTransform>?,
                                              _ rects: UnsafePointer<CGRect>?, _ count: Int) {
    guard let rects, count > 0 else { return }
    build(path, m) { built in
        for index in 0 ..< count {
            built.addRect(rects[index].silica)
        }
    }
}

@c @implementation public func CGPathAddLines(_ path: SilicaCGMutablePathRef?, _ m: UnsafePointer<CGAffineTransform>?,
                                              _ points: UnsafePointer<CGPoint>?, _ count: Int) {
    guard let points, count > 0 else { return }
    build(path, m) { built in
        built.addLines((0 ..< count).map { points[$0].silica })
    }
}

@c @implementation public func CGPathAddEllipseInRect(_ path: SilicaCGMutablePathRef?, _ m: UnsafePointer<CGAffineTransform>?, _ rect: CGRect) {
    build(path, m) { $0.addEllipse(in: rect.silica) }
}

@c @implementation public func CGPathAddRoundedRect(_ path: SilicaCGMutablePathRef?, _ transform: UnsafePointer<CGAffineTransform>?,
                                                    _ rect: CGRect, _ cornerWidth: Double, _ cornerHeight: Double) {
    build(path, transform) { $0.addRoundedRect(in: rect.silica, cornerSize: Size(width: cornerWidth, height: cornerHeight)) }
}

@c @implementation public func CGPathAddRelativeArc(_ path: SilicaCGMutablePathRef?, _ matrix: UnsafePointer<CGAffineTransform>?,
                                                    _ x: Double, _ y: Double, _ radius: Double,
                                                    _ startAngle: Double, _ delta: Double) {
    build(path, matrix) {
        $0.addArc(center: Point(x: x, y: y), radius: radius, startAngle: startAngle,
                  endAngle: startAngle + delta, clockwise: delta < 0)
    }
}

@c @implementation public func CGPathAddArc(_ path: SilicaCGMutablePathRef?, _ m: UnsafePointer<CGAffineTransform>?,
                                            _ x: Double, _ y: Double, _ radius: Double,
                                            _ startAngle: Double, _ endAngle: Double, _ clockwise: Bool) {
    build(path, m) {
        $0.addArc(center: Point(x: x, y: y), radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: clockwise)
    }
}

@c @implementation public func CGPathAddArcToPoint(_ path: SilicaCGMutablePathRef?, _ m: UnsafePointer<CGAffineTransform>?,
                                                   _ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double, _ radius: Double) {
    guard let object = object(path, as: PathObject.self), object.path.currentPoint != nil else { return }
    build(path, m) {
        $0.addArc(tangent1End: Point(x: x1, y: y1), tangent2End: Point(x: x2, y: y2), radius: radius)
    }
}

@c @implementation public func CGPathAddPath(_ path1: SilicaCGMutablePathRef?, _ m: UnsafePointer<CGAffineTransform>?, _ path2: SilicaCGPathRef?) {
    guard let target = object(path1, as: PathObject.self), let source = object(path2, as: PathObject.self) else { return }
    target.path.addPath(source.path, transform: transform(m))
}

// MARK: - Examining

@c @implementation public func CGPathIsEmpty(_ path: SilicaCGPathRef?) -> Bool {
    object(path, as: PathObject.self)?.path.isEmpty ?? true
}

/// One rectangle: a move, three or four lines along the axes, and a close.
@c @implementation public func CGPathIsRect(_ path: SilicaCGPathRef?, _ rect: UnsafeMutablePointer<CGRect>?) -> Bool {
    guard let elements = object(path, as: PathObject.self)?.path.elements else { return false }
    var points: [Point] = []
    for (index, element) in elements.enumerated() {
        switch element {
        case let .move(point) where index == 0:
            points.append(point)
        case let .line(point) where index > 0:
            points.append(point)
        case .closeSubpath where index == elements.count - 1:
            break
        default:
            return false
        }
    }
    if points.count == 5, points[4] == points[0] {
        points.removeLast()
    }
    guard points.count == 4 else { return false }
    // each side along an axis, alternating
    for index in 0 ..< 4 {
        let a = points[index], b = points[(index + 1) % 4], c = points[(index + 2) % 4]
        let horizontal = a.y == b.y && a.x != b.x
        let vertical = a.x == b.x && a.y != b.y
        guard horizontal || vertical else { return false }
        let nextHorizontal = b.y == c.y && b.x != c.x
        guard horizontal != nextHorizontal else { return false }
    }
    let xs = points.map(\.x), ys = points.map(\.y)
    rect?.pointee = CGRect(origin: CGPoint(x: xs.min()!, y: ys.min()!),
                           size: CGSize(width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!))
    return true
}

@c @implementation public func CGPathGetCurrentPoint(_ path: SilicaCGPathRef?) -> CGPoint {
    guard let point = object(path, as: PathObject.self)?.path.currentPoint else { return CGPointZero }
    return CGPoint(point)
}

@c @implementation public func CGPathGetBoundingBox(_ path: SilicaCGPathRef?) -> CGRect {
    guard let object = object(path, as: PathObject.self), object.path.isEmpty == false else { return CGRectNull }
    return CGRect(object.path.controlPointBounds)
}

@c @implementation public func CGPathGetPathBoundingBox(_ path: SilicaCGPathRef?) -> CGRect {
    guard let object = object(path, as: PathObject.self), object.path.isEmpty == false else { return CGRectNull }
    return CGRect(object.path.boundingRect)
}

@c @implementation public func CGPathContainsPoint(_ path: SilicaCGPathRef?, _ m: UnsafePointer<CGAffineTransform>?,
                                                   _ point: CGPoint, _ eoFill: Bool) -> Bool {
    guard let object = object(path, as: PathObject.self) else { return false }
    return object.path.contains(point.silica.applying(transform(m)), using: eoFill ? .evenOdd : .winding)
}

// MARK: - Applying

@c @implementation public func CGPathApply(_ path: SilicaCGPathRef?, _ info: UnsafeMutableRawPointer?, _ function: CGPathApplierFunction?) {
    guard let object = object(path, as: PathObject.self), let function else { return }
    forEachElement(of: object.path) { function(info, $0) }
}

/// Calls the block through the blocks ABI: a block is a pointer to its
/// class, two 32-bit integers, then the function it calls with itself first.
/// Swift's own block bridging crashes some compilers in `@implementation`.
@c(CGPathApplyWithBlock) public func applyWithBlock(_ path: SilicaCGPathRef?, _ block: UnsafeRawPointer?) {
    guard let block, let object = object(path, as: PathObject.self) else { return }
    typealias Invoke = @convention(c) (UnsafeRawPointer, UnsafePointer<CGPathElement>) -> Void
    let invoke = block.load(fromByteOffset: MemoryLayout<UnsafeRawPointer>.size + 8, as: Invoke.self)
    forEachElement(of: object.path) { invoke(block, $0) }
}

/// Each of a path's elements as CoreGraphics hands them out, valid while `body` runs.
private func forEachElement(of path: Silica.Path, _ body: (UnsafePointer<CGPathElement>) -> Void) {
    for element in path.elements {
        let type: CGPathElementType
        var points: [CGPoint]
        switch element {
        case let .move(point):
            type = CGPathElementType(kCGPathElementMoveToPoint)
            points = [CGPoint(point)]
        case let .line(point):
            type = CGPathElementType(kCGPathElementAddLineToPoint)
            points = [CGPoint(point)]
        case let .quadCurve(point, control):
            type = CGPathElementType(kCGPathElementAddQuadCurveToPoint)
            points = [CGPoint(control), CGPoint(point)]
        case let .curve(point, control1, control2):
            type = CGPathElementType(kCGPathElementAddCurveToPoint)
            points = [CGPoint(control1), CGPoint(control2), CGPoint(point)]
        case .closeSubpath:
            type = CGPathElementType(kCGPathElementCloseSubpath)
            // no points, but a pointer to point at
            points = [CGPointZero]
        }
        points.withUnsafeMutableBufferPointer { buffer in
            var element = CGPathElement(type: type, points: buffer.baseAddress!)
            body(&element)
        }
    }
}

// MARK: - Paths of Paths

private func path(_ reference: SilicaCGPathRef?) -> Silica.Path? {
    object(reference, as: PathObject.self)?.path
}

private func rule(_ evenOdd: Bool) -> FillRule {
    evenOdd ? .evenOdd : .winding
}

@c @implementation public func CGPathCreateCopyByFlattening(_ path: SilicaCGPathRef?, _ flatteningThreshold: Double) -> SilicaCGPathRef? {
    guard let path = SilicaCoreGraphicsABI.path(path) else { return nil }
    return makePathReference(path.flattened(threshold: flatteningThreshold))
}

@c @implementation public func CGPathCreateCopyByDashingPath(_ path: SilicaCGPathRef?, _ transform: UnsafePointer<CGAffineTransform>?,
                                                             _ phase: Double, _ lengths: UnsafePointer<Double>?,
                                                             _ count: Int) -> SilicaCGPathRef? {
    guard let path = SilicaCoreGraphicsABI.path(path) else { return nil }
    let dash = lengths.map { lengths in (0 ..< max(count, 0)).map { lengths[$0] } } ?? []
    return makePathReference(path.dashed(phase: phase, lengths: dash).applying(SilicaCoreGraphicsABI.transform(transform)))
}

@c @implementation public func CGPathCreateCopyByStrokingPath(_ path: SilicaCGPathRef?, _ transform: UnsafePointer<CGAffineTransform>?,
                                                              _ lineWidth: Double, _ lineCap: CGLineCap, _ lineJoin: CGLineJoin,
                                                              _ miterLimit: Double) -> SilicaCGPathRef? {
    guard let path = SilicaCoreGraphicsABI.path(path) else { return nil }
    let style = StrokeStyle(lineWidth: lineWidth, lineCap: LineCap(rawValue: UInt8(clamping: lineCap)) ?? .butt,
                            lineJoin: LineJoin(rawValue: UInt8(clamping: lineJoin)) ?? .miter, miterLimit: miterLimit)
    return makePathReference(path.strokedPath(style).applying(SilicaCoreGraphicsABI.transform(transform)))
}

@c @implementation public func CGPathCreateCopyByNormalizing(_ path: SilicaCGPathRef?, _ evenOddFillRule: Bool) -> SilicaCGPathRef? {
    guard let path = SilicaCoreGraphicsABI.path(path) else { return nil }
    return makePathReference(path.normalized(using: rule(evenOddFillRule)))
}

/// A path of a path and a mask, or nil without both.
private func combine(_ path: SilicaCGPathRef?, _ mask: SilicaCGPathRef?,
                     _ body: (Silica.Path, Silica.Path) -> Silica.Path) -> SilicaCGPathRef? {
    guard let path = SilicaCoreGraphicsABI.path(path), let mask = SilicaCoreGraphicsABI.path(mask) else { return nil }
    return makePathReference(body(path, mask))
}

@c @implementation public func CGPathCreateCopyByUnioningPath(_ path: SilicaCGPathRef?, _ maskPath: SilicaCGPathRef?,
                                                              _ evenOddFillRule: Bool) -> SilicaCGPathRef? {
    combine(path, maskPath) { $0.union($1, using: rule(evenOddFillRule)) }
}

@c @implementation public func CGPathCreateCopyByIntersectingPath(_ path: SilicaCGPathRef?, _ maskPath: SilicaCGPathRef?,
                                                                  _ evenOddFillRule: Bool) -> SilicaCGPathRef? {
    combine(path, maskPath) { $0.intersection($1, using: rule(evenOddFillRule)) }
}

@c @implementation public func CGPathCreateCopyBySubtractingPath(_ path: SilicaCGPathRef?, _ maskPath: SilicaCGPathRef?,
                                                                 _ evenOddFillRule: Bool) -> SilicaCGPathRef? {
    combine(path, maskPath) { $0.subtracting($1, using: rule(evenOddFillRule)) }
}

@c @implementation public func CGPathCreateCopyBySymmetricDifferenceOfPath(_ path: SilicaCGPathRef?, _ maskPath: SilicaCGPathRef?,
                                                                           _ evenOddFillRule: Bool) -> SilicaCGPathRef? {
    combine(path, maskPath) { $0.symmetricDifference($1, using: rule(evenOddFillRule)) }
}

@c @implementation public func CGPathCreateCopyOfLineByIntersectingPath(_ path: SilicaCGPathRef?, _ maskPath: SilicaCGPathRef?,
                                                                        _ evenOddFillRule: Bool) -> SilicaCGPathRef? {
    combine(path, maskPath) { $0.lineIntersection($1, using: rule(evenOddFillRule)) }
}

@c @implementation public func CGPathCreateCopyOfLineBySubtractingPath(_ path: SilicaCGPathRef?, _ maskPath: SilicaCGPathRef?,
                                                                       _ evenOddFillRule: Bool) -> SilicaCGPathRef? {
    combine(path, maskPath) { $0.lineSubtraction($1, using: rule(evenOddFillRule)) }
}

/// A CFArray of the pieces' paths, where Core Foundation is bridged.
@c @implementation public func CGPathCreateSeparateComponents(_ path: SilicaCGPathRef?, _ evenOddFillRule: Bool) -> SilicaCFArrayRef? {
    guard let path = SilicaCoreGraphicsABI.path(path), let bridge = CoreGraphicsObjects.coreFoundation else { return nil }
    let references = path.componentsSeparated(using: rule(evenOddFillRule)).map(makePathReference)
    // the array keeps its own references
    defer { references.forEach(release) }
    return bridge.makeArray(references.map { UnsafeRawPointer($0) }).map(OpaquePointer.init)
}

@c @implementation public func CGPathIntersectsPath(_ path1: SilicaCGPathRef?, _ path2: SilicaCGPathRef?, _ evenOddFillRule: Bool) -> Bool {
    guard let first = SilicaCoreGraphicsABI.path(path1), let second = SilicaCoreGraphicsABI.path(path2) else { return false }
    return first.intersects(second, using: rule(evenOddFillRule))
}

#endif
