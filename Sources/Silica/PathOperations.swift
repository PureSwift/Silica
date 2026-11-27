//
//  PathOperations.swift
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

// Paths made from others, as CGPath's copies and SwiftUI's operations make
// them. Curves become lines no farther than 0.05 from them, except in
// `flattened(threshold:)`, which takes its own distance.

public extension Path {

    // MARK: - Lines

    /// The path with its curves as lines no farther than `threshold` from them.
    func flattened(threshold: Double) -> Path {
        var path = Path()
        for subpath in subpaths(tolerance: max(threshold, 1e-6)) {
            path.move(to: subpath.points[0])
            for point in subpath.points.dropFirst() {
                path.addLine(to: point)
            }
            if subpath.closed {
                path.closeSubpath()
            }
        }
        return path
    }

    /// The dashes of the path's lines: lengths of dashes and gaps, alternating,
    /// from `phase` into them.
    func dashed(phase: Double, lengths: [Double]) -> Path {
        let subpaths = self.subpaths(tolerance: PathBoolean.tolerance)
        guard lengths.contains(where: { $0 > 0 }), lengths.allSatisfy({ $0 >= 0 }) else { return self }
        var dashes: [[Point]] = []
        for subpath in subpaths {
            let points = subpath.closed ? subpath.points + [subpath.points[0]] : subpath.points
            dashes.append(contentsOf: PathStroker.dashed(points, phase: phase, lengths: lengths))
        }
        return PathBoolean.path(polylines: dashes)
    }

    /// The outline of the area the path's stroke covers, in the style: its
    /// width, caps, joins, miter limit and dashes. Without a width, the path
    /// itself, as CoreGraphics strokes it.
    func strokedPath(_ style: StrokeStyle) -> Path {
        guard style.lineWidth > 0 else { return self }
        let pieces = PathStroker.pieces(subpaths(tolerance: PathBoolean.tolerance), style: style)
        return PathBoolean.path(rings: PathBoolean.rings(pieces, [], rule: .winding, operation: nil))
    }

    // MARK: - Areas

    /// The area either path fills.
    func union(_ other: Path, using rule: FillRule = .winding) -> Path {
        combined(with: other, rule: rule, operation: .union)
    }

    /// The area both paths fill.
    func intersection(_ other: Path, using rule: FillRule = .winding) -> Path {
        combined(with: other, rule: rule, operation: .intersection)
    }

    /// The area this path fills and the other doesn't.
    func subtracting(_ other: Path, using rule: FillRule = .winding) -> Path {
        combined(with: other, rule: rule, operation: .subtraction)
    }

    /// The area one path fills and the other doesn't.
    func symmetricDifference(_ other: Path, using rule: FillRule = .winding) -> Path {
        combined(with: other, rule: rule, operation: .symmetricDifference)
    }

    /// The area the path fills, outlined without overlaps: rings that run
    /// counterclockwise around it (with y up) and clockwise around its holes.
    func normalized(using rule: FillRule = .winding) -> Path {
        PathBoolean.path(rings: PathBoolean.rings(polygons, [], rule: rule, operation: nil))
    }

    /// Whether the areas the paths fill overlap.
    func intersects(_ other: Path, using rule: FillRule = .winding) -> Bool {
        PathBoolean.rings(polygons, other.polygons, rule: rule, operation: .intersection).isEmpty == false
    }

    /// The area the path fills as its separate pieces: each an outline and
    /// the holes in it, largest first.
    func componentsSeparated(using rule: FillRule = .winding) -> [Path] {
        let rings = PathBoolean.rings(polygons, [], rule: rule, operation: nil)
        let outlines = rings.filter { PathBoolean.area(of: $0) > 0 }
            .sorted { PathBoolean.area(of: $0) > PathBoolean.area(of: $1) }
        let holes = rings.filter { PathBoolean.area(of: $0) < 0 }
        var components = outlines.map { [$0] }
        for hole in holes {
            // the smallest outline around it
            let inside = outlines.indices.filter { PathBoolean.contains(outlines[$0], hole[0]) }
            guard let owner = inside.min(by: { PathBoolean.area(of: outlines[$0]) < PathBoolean.area(of: outlines[$1]) }) else { continue }
            components[owner].append(hole)
        }
        return components.map { PathBoolean.path(rings: $0) }
    }

    // MARK: - Lines and Areas

    /// The parts of the path's lines inside the area the other fills.
    func lineIntersection(_ other: Path, using rule: FillRule = .winding) -> Path {
        PathBoolean.path(polylines: PathBoolean.lines(subpaths(tolerance: PathBoolean.tolerance), other.polygons,
                                                      rule: rule, inside: true))
    }

    /// The parts of the path's lines outside the area the other fills.
    func lineSubtraction(_ other: Path, using rule: FillRule = .winding) -> Path {
        PathBoolean.path(polylines: PathBoolean.lines(subpaths(tolerance: PathBoolean.tolerance), other.polygons,
                                                      rule: rule, inside: false))
    }
}

private extension Path {

    /// Each subpath as a polygon, closed as a fill closes it.
    var polygons: [[Point]] {
        flattened(tolerance: PathBoolean.tolerance)
    }

    func combined(with other: Path, rule: FillRule, operation: PathBoolean.Operation) -> Path {
        PathBoolean.path(rings: PathBoolean.rings(polygons, other.polygons, rule: rule, operation: operation))
    }
}

// MARK: - Stroking

/// The polygons a stroke covers: one for each line, join and cap, each
/// running counterclockwise, so their union filled with the winding rule is
/// the stroke.
internal enum PathStroker {

    static func pieces(_ subpaths: [(points: [Point], closed: Bool)], style: StrokeStyle) -> [[Point]] {
        let halfWidth = max(style.lineWidth, 0) / 2
        guard halfWidth > 0 else { return [] }
        let dashes = style.dash.contains(where: { $0 > 0 }) && style.dash.allSatisfy({ $0 >= 0 })
        var pieces: [[Point]] = []
        for subpath in subpaths {
            var points = deduplicated(subpath.points)
            let closed = subpath.closed
            if closed, points.count > 1, points.first == points.last {
                points.removeLast()
            }
            guard points.count > 1 else { continue }
            if dashes {
                let line = closed ? points + [points[0]] : points
                for dash in dashed(line, phase: style.dashPhase, lengths: style.dash) {
                    pieces.append(contentsOf: polyline(deduplicated(dash), closed: false, halfWidth: halfWidth, style: style))
                }
            } else {
                pieces.append(contentsOf: polyline(points, closed: closed, halfWidth: halfWidth, style: style))
            }
        }
        return pieces
    }

    /// Splits a polyline into its dashes.
    static func dashed(_ points: [Point], phase: Double, lengths: [Double]) -> [[Point]] {
        let pattern = lengths.map { max(0, $0) }
        let patternLength = pattern.reduce(0, +)
        guard patternLength > 0, points.count > 1 else { return [points] }
        var result: [[Point]] = []
        var current: [Point] = []
        var index = 0
        var remaining = pattern[0]
        var isOn = true
        // where the phase is in the pattern
        var offset = phase.truncatingRemainder(dividingBy: patternLength)
        if offset < 0 { offset += patternLength }
        while offset > 0 {
            let consumed = min(offset, remaining)
            offset -= consumed
            remaining -= consumed
            if remaining <= 0 {
                index = (index + 1) % pattern.count
                remaining = pattern[index]
                isOn.toggle()
            }
        }
        if isOn { current.append(points[0]) }
        for segment in 0 ..< points.count - 1 {
            var start = points[segment]
            let end = points[segment + 1]
            var length = distance(start, end)
            while length > 0 {
                if remaining >= length {
                    remaining -= length
                    length = 0
                    if isOn { current.append(end) }
                } else {
                    let t = remaining / length
                    let split = Point(x: start.x + (end.x - start.x) * t, y: start.y + (end.y - start.y) * t)
                    if isOn { current.append(split) }
                    length -= remaining
                    start = split
                    remaining = 0
                }
                if remaining <= 0 {
                    if isOn, current.count > 1 { result.append(current) }
                    current.removeAll(keepingCapacity: true)
                    index = (index + 1) % pattern.count
                    remaining = pattern[index]
                    isOn.toggle()
                    if isOn, length > 0 { current.append(start) }
                }
            }
        }
        if isOn, current.count > 1 { result.append(current) }
        return result
    }
}

private extension PathStroker {

    static func polyline(_ points: [Point], closed: Bool, halfWidth: Double, style: StrokeStyle) -> [[Point]] {
        guard points.count > 1 else { return [] }
        var pieces: [[Point]] = []
        let count = points.count
        let segments = closed ? count : count - 1
        for index in 0 ..< segments {
            let start = points[index], end = points[(index + 1) % count]
            guard let n = normal(start, end, halfWidth) else { continue }
            pieces.append(PathBoolean.counterclockwise([
                Point(x: start.x + n.x, y: start.y + n.y),
                Point(x: end.x + n.x, y: end.y + n.y),
                Point(x: end.x - n.x, y: end.y - n.y),
                Point(x: start.x - n.x, y: start.y - n.y),
            ]))
        }
        let joints = closed ? Array(0 ..< count) : Array(1 ..< count - 1)
        for index in joints {
            let before = points[(index + count - 1) % count], vertex = points[index], after = points[(index + 1) % count]
            if let join = join(at: vertex, from: before, to: after, halfWidth: halfWidth, style: style) {
                pieces.append(join)
            }
        }
        if closed == false {
            if let cap = cap(at: points[0], from: points[1], halfWidth: halfWidth, cap: style.lineCap) {
                pieces.append(cap)
            }
            if let cap = cap(at: points[count - 1], from: points[count - 2], halfWidth: halfWidth, cap: style.lineCap) {
                pieces.append(cap)
            }
        }
        return pieces
    }

    /// The wedge outside the turn at a vertex, shaped by the join.
    static func join(at vertex: Point, from before: Point, to after: Point, halfWidth: Double, style: StrokeStyle) -> [Point]? {
        guard let n1 = normal(before, vertex, halfWidth), let n2 = normal(vertex, after, halfWidth) else { return nil }
        let d1 = Point(x: vertex.x - before.x, y: vertex.y - before.y)
        let d2 = Point(x: after.x - vertex.x, y: after.y - vertex.y)
        let turn = d1.x * d2.y - d1.y * d2.x
        let dot = d1.x * d2.x + d1.y * d2.y
        // straight on: nothing to join
        guard abs(turn) > 1e-12 * (d1.x * d1.x + d1.y * d1.y + d2.x * d2.x + d2.y * d2.y) || dot < 0 else { return nil }
        // the outside of a left turn is on the right
        let side: Double = turn > 0 ? -1 : 1
        let outer1 = Point(x: vertex.x + n1.x * side, y: vertex.y + n1.y * side)
        let outer2 = Point(x: vertex.x + n2.x * side, y: vertex.y + n2.y * side)
        switch style.lineJoin {
        case .bevel:
            return PathBoolean.counterclockwise([vertex, outer1, outer2])
        case .round:
            let start = atan2(outer1.y - vertex.y, outer1.x - vertex.x)
            var sweep = atan2(outer2.y - vertex.y, outer2.x - vertex.x) - start
            // the short way around: counterclockwise outside a left turn, clockwise outside a right one
            while sweep > .pi { sweep -= 2 * .pi }
            while sweep <= -.pi { sweep += 2 * .pi }
            if abs(abs(sweep) - .pi) < 1e-9 {
                sweep = side < 0 ? .pi : -.pi
            }
            return PathBoolean.counterclockwise([vertex] + arc(around: vertex, radius: halfWidth, from: start, sweep: sweep))
        case .miter:
            let bisector = Point(x: (n1.x + n2.x) * side, y: (n1.y + n2.y) * side)
            let length = (bisector.x * bisector.x + bisector.y * bisector.y).squareRoot()
            // the miter is 1 / cos(half the angle between the normals) of the width
            let cosineHalf = length / (2 * halfWidth)
            guard cosineHalf > 0, 1 / cosineHalf <= style.miterLimit else {
                return PathBoolean.counterclockwise([vertex, outer1, outer2])
            }
            let reach = halfWidth / cosineHalf
            let tip = Point(x: vertex.x + bisector.x / length * reach, y: vertex.y + bisector.y / length * reach)
            return PathBoolean.counterclockwise([vertex, outer1, tip, outer2])
        }
    }

    /// The cap past an open end, coming from its neighbor.
    static func cap(at end: Point, from neighbor: Point, halfWidth: Double, cap: LineCap) -> [Point]? {
        guard let n = normal(neighbor, end, halfWidth) else { return nil }
        let length = distance(neighbor, end)
        let out = Point(x: (end.x - neighbor.x) / length * halfWidth, y: (end.y - neighbor.y) / length * halfWidth)
        switch cap {
        case .butt:
            return nil
        case .square:
            return PathBoolean.counterclockwise([
                Point(x: end.x + n.x, y: end.y + n.y),
                Point(x: end.x + n.x + out.x, y: end.y + n.y + out.y),
                Point(x: end.x - n.x + out.x, y: end.y - n.y + out.y),
                Point(x: end.x - n.x, y: end.y - n.y),
            ])
        case .round:
            // half a circle, from the left of the line around the end to its right
            let start = atan2(n.y, n.x)
            return PathBoolean.counterclockwise(arc(around: end, radius: halfWidth, from: start, sweep: -.pi))
        }
    }

    /// Points along an arc, both ends included, no farther than the tolerance from it.
    static func arc(around center: Point, radius: Double, from start: Double, sweep: Double) -> [Point] {
        // a chord's sagitta is about radius · angle² / 8
        let step = (8 * PathBoolean.tolerance / max(radius, PathBoolean.tolerance)).squareRoot()
        let count = max(1, Int((abs(sweep) / step).rounded(.up)))
        return (0 ... count).map { index in
            let angle = start + sweep * Double(index) / Double(count)
            return Point(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
        }
    }

    /// The normal to the left of a line, `length` long.
    static func normal(_ start: Point, _ end: Point, _ length: Double) -> Point? {
        let magnitude = distance(start, end)
        guard magnitude > 0 else { return nil }
        return Point(x: -(end.y - start.y) / magnitude * length, y: (end.x - start.x) / magnitude * length)
    }

    static func deduplicated(_ points: [Point]) -> [Point] {
        var result: [Point] = []
        for point in points where result.last != point {
            result.append(point)
        }
        return result
    }
}

private func distance(_ a: Point, _ b: Point) -> Double {
    ((b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y)).squareRoot()
}
