//
//  Geometry.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 11/25/26.
//  Copyright © 2026 PureSwift. All rights reserved.
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

/// A point in a two-dimensional coordinate system.
public struct Point: Equatable, Hashable, Sendable {

    public var x: Double

    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public init() {
        self.init(x: 0, y: 0)
    }

    public static var zero: Point { Point() }
}

/// A width and a height.
public struct Size: Equatable, Hashable, Sendable {

    public var width: Double

    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    public init() {
        self.init(width: 0, height: 0)
    }

    public static var zero: Size { Size() }
}

/// A two-dimensional vector.
public struct Vector: Equatable, Hashable, Sendable {

    public var dx: Double

    public var dy: Double

    public init(dx: Double, dy: Double) {
        self.dx = dx
        self.dy = dy
    }

    public init() {
        self.init(dx: 0, dy: 0)
    }

    public static var zero: Vector { Vector() }
}

/// A rectangle: an origin and a size.
///
/// A size may be negative; the `min` and `max` accessors and `standardized`
/// account for it, as CoreGraphics' do.
public struct Rect: Equatable, Hashable, Sendable {

    public var origin: Point

    public var size: Size

    public init(origin: Point, size: Size) {
        self.origin = origin
        self.size = size
    }

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.init(origin: Point(x: x, y: y), size: Size(width: width, height: height))
    }

    public init() {
        self.init(origin: .zero, size: .zero)
    }

    public static var zero: Rect { Rect() }

    /// The rectangle with no position, which is the result of intersecting
    /// rectangles that don't overlap.
    public static var null: Rect {
        Rect(x: .infinity, y: .infinity, width: 0, height: 0)
    }
}

// MARK: - Rect Accessors

public extension Rect {

    var minX: Double { size.width < 0 ? origin.x + size.width : origin.x }
    var midX: Double { origin.x + size.width / 2 }
    var maxX: Double { size.width < 0 ? origin.x : origin.x + size.width }

    var minY: Double { size.height < 0 ? origin.y + size.height : origin.y }
    var midY: Double { origin.y + size.height / 2 }
    var maxY: Double { size.height < 0 ? origin.y : origin.y + size.height }

    var width: Double { abs(size.width) }
    var height: Double { abs(size.height) }

    var center: Point { Point(x: midX, y: midY) }

    /// The same rectangle with a positive width and height.
    var standardized: Rect { Rect(x: minX, y: minY, width: width, height: height) }

    /// Whether the rectangle has no area.
    var isEmpty: Bool { isNull || size.width == 0 || size.height == 0 }

    /// Whether the rectangle is `Rect.null`.
    var isNull: Bool { origin.x.isInfinite || origin.y.isInfinite }

    func contains(_ point: Point) -> Bool {
        point.x >= minX && point.x < maxX && point.y >= minY && point.y < maxY
    }

    func contains(_ rect: Rect) -> Bool {
        rect.minX >= minX && rect.maxX <= maxX && rect.minY >= minY && rect.maxY <= maxY
    }

    func intersects(_ rect: Rect) -> Bool {
        intersection(rect).isNull == false
    }

    func offsetBy(dx: Double, dy: Double) -> Rect {
        var rect = standardized
        rect.origin.x += dx
        rect.origin.y += dy
        return rect
    }

    func insetBy(dx: Double, dy: Double) -> Rect {
        let rect = standardized
        let width = rect.size.width - 2 * dx
        let height = rect.size.height - 2 * dy
        guard width >= 0, height >= 0 else { return .null }
        return Rect(x: rect.origin.x + dx, y: rect.origin.y + dy, width: width, height: height)
    }

    /// The smallest rectangle that contains both rectangles.
    func union(_ rect: Rect) -> Rect {
        if isNull { return rect.standardized }
        if rect.isNull { return standardized }
        let minX = min(self.minX, rect.minX)
        let minY = min(self.minY, rect.minY)
        return Rect(x: minX, y: minY, width: max(self.maxX, rect.maxX) - minX, height: max(self.maxY, rect.maxY) - minY)
    }

    /// The overlap of both rectangles, or `Rect.null`.
    func intersection(_ rect: Rect) -> Rect {
        if isNull || rect.isNull { return .null }
        let minX = max(self.minX, rect.minX)
        let minY = max(self.minY, rect.minY)
        let maxX = min(self.maxX, rect.maxX)
        let maxY = min(self.maxY, rect.maxY)
        guard maxX >= minX, maxY >= minY else { return .null }
        return Rect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// The smallest rectangle with integral coordinates that contains this one.
    var integral: Rect {
        if isNull { return self }
        let minX = floor(self.minX)
        let minY = floor(self.minY)
        return Rect(x: minX, y: minY, width: ceil(maxX) - minX, height: ceil(maxY) - minY)
    }
}

// MARK: - UnitPoint

/// A point in a rectangle's own coordinates, from 0 to 1 on each axis:
/// where text anchors at a point, or a gradient starts within its bounds.
public struct UnitPoint: Equatable, Hashable, Sendable {

    public var x: Double

    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public static var zero: UnitPoint { UnitPoint(x: 0, y: 0) }
    public static var center: UnitPoint { UnitPoint(x: 0.5, y: 0.5) }
    public static var leading: UnitPoint { UnitPoint(x: 0, y: 0.5) }
    public static var trailing: UnitPoint { UnitPoint(x: 1, y: 0.5) }
    public static var top: UnitPoint { UnitPoint(x: 0.5, y: 0) }
    public static var bottom: UnitPoint { UnitPoint(x: 0.5, y: 1) }
    public static var topLeading: UnitPoint { UnitPoint(x: 0, y: 0) }
    public static var topTrailing: UnitPoint { UnitPoint(x: 1, y: 0) }
    public static var bottomLeading: UnitPoint { UnitPoint(x: 0, y: 1) }
    public static var bottomTrailing: UnitPoint { UnitPoint(x: 1, y: 1) }
}
