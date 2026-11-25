//
//  Path.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/8/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

#if canImport(Foundation)
import Foundation
#endif

/// The outline of a shape: lines and quadratic and cubic Bézier curves.
///
/// A value type, as SwiftUI's is. Rectangles, rounded rectangles, ellipses
/// and arcs are added as lines and curves.
public struct Path: Equatable, Hashable, Sendable {

    /// The path's elements, in the order they were added.
    public var elements: [Element]

    public init() {
        self.elements = []
    }

    public init(elements: [Element]) {
        self.elements = elements
    }

    /// A path built by `body`.
    public init(_ body: (inout Path) -> Void) {
        self.init()
        body(&self)
    }

    /// A rectangle.
    public init(_ rect: Rect) {
        self.init()
        addRect(rect)
    }

    /// An ellipse that fits the rectangle.
    public init(ellipseIn rect: Rect) {
        self.init()
        addEllipse(in: rect)
    }

    /// A rectangle with rounded corners.
    public init(roundedRect rect: Rect, cornerSize: Size) {
        self.init()
        addRoundedRect(in: rect, cornerSize: cornerSize)
    }

    /// A rectangle with rounded corners of the same radius.
    public init(roundedRect rect: Rect, cornerRadius: Double) {
        self.init(roundedRect: rect, cornerSize: Size(width: cornerRadius, height: cornerRadius))
    }
}

// MARK: - Element

public extension Path {

    /// An element of a path.
    @frozen
    enum Element: Equatable, Hashable, Sendable {

        /// Starts a subpath at a point.
        case move(to: Point)

        /// A line from the current point.
        case line(to: Point)

        /// A quadratic curve from the current point.
        case quadCurve(to: Point, control: Point)

        /// A cubic curve from the current point.
        case curve(to: Point, control1: Point, control2: Point)

        /// Closes the subpath with a line back to where it started.
        case closeSubpath
    }
}

public extension Path.Element {

    /// The element with each of its points transformed.
    func applying(_ transform: AffineTransform) -> Path.Element {
        switch self {
        case let .move(point):
            return .move(to: point.applying(transform))
        case let .line(point):
            return .line(to: point.applying(transform))
        case let .quadCurve(point, control):
            return .quadCurve(to: point.applying(transform), control: control.applying(transform))
        case let .curve(point, control1, control2):
            return .curve(to: point.applying(transform), control1: control1.applying(transform), control2: control2.applying(transform))
        case .closeSubpath:
            return .closeSubpath
        }
    }
}

// MARK: - Building

public extension Path {

    /// Starts a new subpath at a point.
    mutating func move(to point: Point) {
        elements.append(.move(to: point))
    }

    /// Adds a line from the current point.
    mutating func addLine(to point: Point) {
        startIfNeeded(at: point)
        elements.append(.line(to: point))
    }

    /// Adds a quadratic Bézier curve from the current point.
    mutating func addQuadCurve(to point: Point, control: Point) {
        startIfNeeded(at: control)
        elements.append(.quadCurve(to: point, control: control))
    }

    /// Adds a cubic Bézier curve from the current point.
    mutating func addCurve(to point: Point, control1: Point, control2: Point) {
        startIfNeeded(at: control1)
        elements.append(.curve(to: point, control1: control1, control2: control2))
    }

    /// Closes the current subpath.
    mutating func closeSubpath() {
        guard elements.isEmpty == false else { return }
        if case .closeSubpath = elements.last { return }
        elements.append(.closeSubpath)
    }

    /// Adds lines through the points, starting a new subpath at the first.
    mutating func addLines(_ points: [Point]) {
        guard let first = points.first else { return }
        move(to: first)
        for point in points.dropFirst() {
            elements.append(.line(to: point))
        }
    }

    /// Adds a closed rectangle as a new subpath.
    mutating func addRect(_ rect: Rect) {
        elements.append(.move(to: Point(x: rect.origin.x, y: rect.origin.y)))
        elements.append(.line(to: Point(x: rect.origin.x + rect.size.width, y: rect.origin.y)))
        elements.append(.line(to: Point(x: rect.origin.x + rect.size.width, y: rect.origin.y + rect.size.height)))
        elements.append(.line(to: Point(x: rect.origin.x, y: rect.origin.y + rect.size.height)))
        elements.append(.closeSubpath)
    }

    mutating func addRects(_ rects: [Rect]) {
        rects.forEach { addRect($0) }
    }

    /// Adds a closed ellipse that fits the rectangle, as four cubic curves.
    mutating func addEllipse(in rect: Rect) {
        let rx = rect.width / 2
        let ry = rect.height / 2
        let cx = rect.midX
        let cy = rect.midY
        let ox = rx * kappa
        let oy = ry * kappa
        // clockwise in y-down coordinates from the right-hand point, as CoreGraphics does
        elements.append(.move(to: Point(x: cx + rx, y: cy)))
        elements.append(.curve(to: Point(x: cx, y: cy + ry), control1: Point(x: cx + rx, y: cy + oy), control2: Point(x: cx + ox, y: cy + ry)))
        elements.append(.curve(to: Point(x: cx - rx, y: cy), control1: Point(x: cx - ox, y: cy + ry), control2: Point(x: cx - rx, y: cy + oy)))
        elements.append(.curve(to: Point(x: cx, y: cy - ry), control1: Point(x: cx - rx, y: cy - oy), control2: Point(x: cx - ox, y: cy - ry)))
        elements.append(.curve(to: Point(x: cx + rx, y: cy), control1: Point(x: cx + ox, y: cy - ry), control2: Point(x: cx + rx, y: cy - oy)))
        elements.append(.closeSubpath)
    }

    /// Adds a closed rectangle with rounded corners. Radii larger than half
    /// the rectangle's side are reduced to it.
    mutating func addRoundedRect(in rect: Rect, cornerSize: Size) {
        let rect = rect.standardized
        let rx = min(max(cornerSize.width, 0), rect.width / 2)
        let ry = min(max(cornerSize.height, 0), rect.height / 2)
        guard rx > 0, ry > 0 else {
            addRect(rect)
            return
        }
        let ox = rx * kappa
        let oy = ry * kappa
        let minX = rect.minX, maxX = rect.maxX, minY = rect.minY, maxY = rect.maxY
        elements.append(.move(to: Point(x: minX + rx, y: minY)))
        elements.append(.line(to: Point(x: maxX - rx, y: minY)))
        elements.append(.curve(to: Point(x: maxX, y: minY + ry), control1: Point(x: maxX - rx + ox, y: minY), control2: Point(x: maxX, y: minY + ry - oy)))
        elements.append(.line(to: Point(x: maxX, y: maxY - ry)))
        elements.append(.curve(to: Point(x: maxX - rx, y: maxY), control1: Point(x: maxX, y: maxY - ry + oy), control2: Point(x: maxX - rx + ox, y: maxY)))
        elements.append(.line(to: Point(x: minX + rx, y: maxY)))
        elements.append(.curve(to: Point(x: minX, y: maxY - ry), control1: Point(x: minX + rx - ox, y: maxY), control2: Point(x: minX, y: maxY - ry + oy)))
        elements.append(.line(to: Point(x: minX, y: minY + ry)))
        elements.append(.curve(to: Point(x: minX + rx, y: minY), control1: Point(x: minX, y: minY + ry - oy), control2: Point(x: minX + rx - ox, y: minY)))
        elements.append(.closeSubpath)
    }

    /// Adds an arc of a circle, with a line to its start from the current
    /// point, if there is one.
    ///
    /// Angles are in radians from the positive x axis toward the positive y
    /// axis. With `clockwise` the angle decreases from `startAngle` to
    /// `endAngle`, as in CoreGraphics; with y pointing down, that looks
    /// counterclockwise on screen, as it does in a flipped `CGContext` and in
    /// SwiftUI's `Path`.
    mutating func addArc(center: Point, radius: Double, startAngle: Double, endAngle: Double, clockwise: Bool) {
        guard radius >= 0, radius.isFinite, startAngle.isFinite, endAngle.isFinite else { return }
        let start = Point(x: center.x + radius * cos(startAngle), y: center.y + radius * sin(startAngle))
        if currentPoint == nil {
            move(to: start)
        } else {
            addLine(to: start)
        }
        guard radius > 0 else { return }

        // Cairo's arithmetic: the end angle moves by whole turns until it is
        // past the start angle in the direction of travel.
        var end = endAngle
        if clockwise {
            while end > startAngle { end -= 2 * .pi }
        } else {
            while end < startAngle { end += 2 * .pi }
        }
        let sweep = end - startAngle
        guard sweep != 0 else { return }

        // at most a quarter turn per curve
        let segments = max(1, Int(ceil(abs(sweep) / (.pi / 2) - 1e-9)))
        let step = sweep / Double(segments)
        let handle = 4.0 / 3.0 * tan(step / 4)
        var angle = startAngle
        for _ in 0 ..< segments {
            let next = angle + step
            let cos0 = cos(angle), sin0 = sin(angle)
            let cos1 = cos(next), sin1 = sin(next)
            let control1 = Point(x: center.x + radius * (cos0 - handle * sin0), y: center.y + radius * (sin0 + handle * cos0))
            let control2 = Point(x: center.x + radius * (cos1 + handle * sin1), y: center.y + radius * (sin1 - handle * cos1))
            let point = Point(x: center.x + radius * cos1, y: center.y + radius * sin1)
            elements.append(.curve(to: point, control1: control1, control2: control2))
            angle = next
        }
    }

    /// Adds an arc of a circle tangent to the line from the current point to
    /// `tangent1End` and to the line from there to `tangent2End`, with a line
    /// to the arc's start, as CGContextAddArcToPoint does.
    mutating func addArc(tangent1End: Point, tangent2End: Point, radius: Double) {
        guard let current = currentPoint else {
            move(to: tangent1End)
            return
        }
        let x0 = current.x, y0 = current.y
        let x1 = tangent1End.x, y1 = tangent1End.y
        let x2 = tangent2End.x, y2 = tangent2End.y

        let dx0 = x0 - x1, dy0 = y0 - y1
        let dx2 = x2 - x1, dy2 = y2 - y1
        let length0 = sqrt(dx0 * dx0 + dy0 * dy0)
        let length2 = sqrt(dx2 * dx2 + dy2 * dy2)
        let cross = dx2 * dy0 - dx0 * dy2

        // a degenerate corner, or the points on a line: a line to the corner
        guard length0 != 0, length2 != 0, cross != 0, radius > 0 else {
            addLine(to: tangent1End)
            return
        }

        let n0x: Double, n0y: Double, n2x: Double, n2y: Double
        if cross < 0 {
            n0x = -dy0 / length0
            n0y = dx0 / length0
            n2x = dy2 / length2
            n2y = -dx2 / length2
        } else {
            n0x = dy0 / length0
            n0y = -dx0 / length0
            n2x = -dy2 / length2
            n2y = dx2 / length2
        }

        let t = (dx2 * n2y - dx2 * n0y - dy2 * n2x + dy2 * n0x) / cross
        let center = Point(x: x1 + radius * (t * dx0 + n0x), y: y1 + radius * (t * dy0 + n0y))
        addArc(center: center,
               radius: radius,
               startAngle: atan2(-n0y, -n0x),
               endAngle: atan2(-n2y, -n2x),
               clockwise: cross < 0)
    }

    /// Adds another path's elements, transformed.
    mutating func addPath(_ path: Path, transform: AffineTransform = .identity) {
        if transform.isIdentity {
            elements.append(contentsOf: path.elements)
        } else {
            elements.append(contentsOf: path.elements.map { $0.applying(transform) })
        }
    }

    /// A line or curve with no current point starts a subpath where it begins.
    private mutating func startIfNeeded(at point: Point) {
        if currentPoint == nil {
            move(to: point)
        }
    }
}

// 4·(√2 − 1)/3: the handle length of a quarter circle as a cubic curve.
private let kappa = 0.5522847498307936

// MARK: - Geometry

public extension Path {

    var isEmpty: Bool { elements.isEmpty }

    /// Where the next element starts: the end of the last one, or the start of
    /// the subpath after a close. Nil for an empty path.
    var currentPoint: Point? {
        var point: Point?
        var subpathStart: Point?
        for element in elements {
            switch element {
            case let .move(to):
                point = to
                subpathStart = to
            case let .line(to), let .quadCurve(to, _), let .curve(to, _, _):
                point = to
            case .closeSubpath:
                point = subpathStart
            }
        }
        return point
    }

    /// The path with every point transformed.
    func applying(_ transform: AffineTransform) -> Path {
        if transform.isIdentity { return self }
        return Path(elements: elements.map { $0.applying(transform) })
    }

    /// The smallest rectangle containing every point and control point, as
    /// CGPathGetBoundingBox has it. `Rect.null` for an empty path.
    var controlPointBounds: Rect {
        var bounds = Bounds()
        for element in elements {
            switch element {
            case let .move(point), let .line(point):
                bounds.add(point)
            case let .quadCurve(point, control):
                bounds.add(control)
                bounds.add(point)
            case let .curve(point, control1, control2):
                bounds.add(control1)
                bounds.add(control2)
                bounds.add(point)
            case .closeSubpath:
                break
            }
        }
        return bounds.rect
    }

    /// The smallest rectangle containing the path's lines and curves, as
    /// CGPathGetPathBoundingBox has it. `Rect.null` for an empty path.
    var boundingRect: Rect {
        var bounds = Bounds()
        var current = Point()
        var subpathStart = Point()
        for element in elements {
            switch element {
            case let .move(point):
                bounds.add(point)
                current = point
                subpathStart = point
            case let .line(point):
                bounds.add(point)
                current = point
            case let .quadCurve(point, control):
                bounds.add(point)
                for t in quadraticExtrema(current.x, control.x, point.x) + quadraticExtrema(current.y, control.y, point.y) {
                    bounds.add(quadraticPoint(current, control, point, t))
                }
                current = point
            case let .curve(point, control1, control2):
                bounds.add(point)
                for t in cubicExtrema(current.x, control1.x, control2.x, point.x) + cubicExtrema(current.y, control1.y, control2.y, point.y) {
                    bounds.add(cubicPoint(current, control1, control2, point, t))
                }
                current = point
            case .closeSubpath:
                current = subpathStart
            }
        }
        return bounds.rect
    }

    /// Whether a point is inside the path, filled with the rule. Each
    /// subpath is closed for this, as a fill closes it.
    func contains(_ point: Point, using rule: FillRule = .winding) -> Bool {
        var winding = 0
        for polygon in flattened(tolerance: 0.05) {
            guard polygon.count > 1 else { continue }
            for index in polygon.indices {
                let a = polygon[index]
                let b = polygon[(index + 1) % polygon.count]
                if a.y <= point.y {
                    if b.y > point.y, cross(a, b, point) > 0 { winding += 1 }
                } else if b.y <= point.y, cross(a, b, point) < 0 {
                    winding -= 1
                }
            }
        }
        switch rule {
        case .winding: return winding != 0
        case .evenOdd: return winding % 2 != 0
        }
    }

    /// Each subpath as a polygon: curves become lines no farther than
    /// `tolerance` from them. A closed subpath doesn't repeat its first point.
    func flattened(tolerance: Double = 0.1) -> [[Point]] {
        var polygons: [[Point]] = []
        var polygon: [Point] = []
        var current = Point()
        var subpathStart = Point()
        func finish() {
            if polygon.isEmpty == false { polygons.append(polygon) }
            polygon = []
        }
        for element in elements {
            switch element {
            case let .move(point):
                finish()
                polygon = [point]
                current = point
                subpathStart = point
            case let .line(point):
                if polygon.isEmpty { polygon = [current] }
                polygon.append(point)
                current = point
            case let .quadCurve(point, control):
                if polygon.isEmpty { polygon = [current] }
                let steps = curveSteps(current, control, point, tolerance: tolerance)
                for step in 1 ... steps {
                    polygon.append(quadraticPoint(current, control, point, Double(step) / Double(steps)))
                }
                current = point
            case let .curve(point, control1, control2):
                if polygon.isEmpty { polygon = [current] }
                let steps = max(curveSteps(current, control1, control2, tolerance: tolerance),
                                curveSteps(control1, control2, point, tolerance: tolerance))
                for step in 1 ... steps {
                    polygon.append(cubicPoint(current, control1, control2, point, Double(step) / Double(steps)))
                }
                current = point
            case .closeSubpath:
                if let first = polygon.first, let last = polygon.last, first == last, polygon.count > 1 {
                    polygon.removeLast()
                }
                finish()
                current = subpathStart
            }
        }
        finish()
        return polygons
    }
}

// MARK: - Curve Math

private struct Bounds {

    var minX = Double.infinity, minY = Double.infinity
    var maxX = -Double.infinity, maxY = -Double.infinity

    mutating func add(_ point: Point) {
        minX = min(minX, point.x)
        minY = min(minY, point.y)
        maxX = max(maxX, point.x)
        maxY = max(maxY, point.y)
    }

    var rect: Rect {
        guard minX <= maxX else { return .null }
        return Rect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

private func cross(_ a: Point, _ b: Point, _ p: Point) -> Double {
    (b.x - a.x) * (p.y - a.y) - (p.x - a.x) * (b.y - a.y)
}

private func quadraticPoint(_ p0: Point, _ p1: Point, _ p2: Point, _ t: Double) -> Point {
    let u = 1 - t
    return Point(x: u * u * p0.x + 2 * u * t * p1.x + t * t * p2.x,
                 y: u * u * p0.y + 2 * u * t * p1.y + t * t * p2.y)
}

private func cubicPoint(_ p0: Point, _ p1: Point, _ p2: Point, _ p3: Point, _ t: Double) -> Point {
    let u = 1 - t
    let a = u * u * u, b = 3 * u * u * t, c = 3 * u * t * t, d = t * t * t
    return Point(x: a * p0.x + b * p1.x + c * p2.x + d * p3.x,
                 y: a * p0.y + b * p1.y + c * p2.y + d * p3.y)
}

/// Where a quadratic's coordinate has its turning point, if inside (0, 1).
private func quadraticExtrema(_ a: Double, _ b: Double, _ c: Double) -> [Double] {
    let denominator = a - 2 * b + c
    guard denominator != 0 else { return [] }
    let t = (a - b) / denominator
    return t > 0 && t < 1 ? [t] : []
}

/// Where a cubic's coordinate has its turning points, inside (0, 1).
private func cubicExtrema(_ p0: Double, _ p1: Double, _ p2: Double, _ p3: Double) -> [Double] {
    // the derivative's coefficients, divided by 3
    let a = -p0 + 3 * p1 - 3 * p2 + p3
    let b = 2 * (p0 - 2 * p1 + p2)
    let c = p1 - p0
    var roots: [Double] = []
    if abs(a) < 1e-12 {
        if b != 0 { roots.append(-c / b) }
    } else {
        let discriminant = b * b - 4 * a * c
        if discriminant >= 0 {
            let root = sqrt(discriminant)
            roots.append((-b + root) / (2 * a))
            roots.append((-b - root) / (2 * a))
        }
    }
    return roots.filter { $0 > 0 && $0 < 1 }
}

/// How many lines a curve needs to stay within the tolerance of it.
private func curveSteps(_ p0: Point, _ p1: Point, _ p2: Point, tolerance: Double) -> Int {
    let dx = p0.x - 2 * p1.x + p2.x
    let dy = p0.y - 2 * p1.y + p2.y
    let deviation = sqrt(dx * dx + dy * dy)
    guard deviation > 0, tolerance > 0 else { return 1 }
    return min(256, max(1, Int(ceil(sqrt(deviation / (8 * tolerance)) * 2))))
}
