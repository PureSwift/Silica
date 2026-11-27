//
//  PathBoolean.swift
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

/// Boolean operations on the areas paths fill, on their outlines flattened
/// to polygons.
///
/// Every edge of both outlines is split where it meets another, and each
/// piece is kept where the result is inside on one side of it and outside on
/// the other: turned so the inside is on its left, the kept pieces join into
/// rings that fill the result with either rule.
internal enum PathBoolean {

    enum Operation {
        case union
        case intersection
        case subtraction
        case symmetricDifference
    }

    /// How far a curve's lines may be from it.
    static let tolerance = 0.05

    struct Edge {
        var start: Point
        var end: Point
    }

    // MARK: Areas

    /// The rings filling where `operation` of the areas `a` and `b` fill is
    /// inside, or, without an operation, where `a` alone is: its outline
    /// without overlaps.
    static func rings(_ a: [[Point]], _ b: [[Point]], rule: FillRule, operation: Operation?) -> [[Point]] {
        let edgesA = edges(of: a), edgesB = edges(of: b)
        let all = edgesA + edgesB
        guard all.isEmpty == false else { return [] }
        let extent = self.extent(of: all)
        guard extent.isFinite else { return [] }
        let epsilon = max(extent, 1) * 1e-9
        let welder = Welder(epsilon: epsilon)
        // the pieces, once each whichever way they run
        var seen = Set<EdgeKey>()
        var pieces: [Edge] = []
        for edge in split(all, epsilon: epsilon) {
            let start = welder.weld(edge.start), end = welder.weld(edge.end)
            guard start != end else { continue }
            let key = EdgeKey(start, end)
            guard seen.insert(key).inserted else { continue }
            pieces.append(Edge(start: start, end: end))
        }
        func inside(_ point: Point) -> Bool {
            let inA = isInside(winding(point, edgesA), rule)
            guard let operation else { return inA }
            let inB = isInside(winding(point, edgesB), rule)
            switch operation {
            case .union: return inA || inB
            case .intersection: return inA && inB
            case .subtraction: return inA && inB == false
            case .symmetricDifference: return inA != inB
            }
        }
        var kept: [Edge] = []
        for piece in pieces {
            let dx = piece.end.x - piece.start.x, dy = piece.end.y - piece.start.y
            let length = (dx * dx + dy * dy).squareRoot()
            guard length > 0 else { continue }
            // a point just to each side of the piece's middle
            let offset = min(length * 0.25, max(extent * 1e-6, epsilon * 10))
            let middle = Point(x: (piece.start.x + piece.end.x) / 2, y: (piece.start.y + piece.end.y) / 2)
            let normal = Point(x: -dy / length * offset, y: dx / length * offset)
            let left = inside(Point(x: middle.x + normal.x, y: middle.y + normal.y))
            let right = inside(Point(x: middle.x - normal.x, y: middle.y - normal.y))
            guard left != right else { continue }
            kept.append(left ? piece : Edge(start: piece.end, end: piece.start))
        }
        return chain(kept, epsilon: epsilon)
    }

    /// The parts of the lines of `a`'s subpaths (closed or open) inside the
    /// area `b` fills, or outside it.
    static func lines(_ a: [(points: [Point], closed: Bool)], _ b: [[Point]], rule: FillRule, inside keepsInside: Bool) -> [[Point]] {
        let edgesB = edges(of: b)
        var all: [Edge] = []
        for subpath in a {
            all.append(contentsOf: polylineEdges(subpath.points, closed: subpath.closed))
        }
        let extent = self.extent(of: all + edgesB)
        guard extent.isFinite else { return [] }
        let epsilon = max(extent, 1) * 1e-9
        var result: [[Point]] = []
        for subpath in a {
            let lineEdges = polylineEdges(subpath.points, closed: subpath.closed)
            guard lineEdges.isEmpty == false else { continue }
            // each edge split where it meets the area's outline, in order
            var polylines: [[Point]] = []
            var current: [Point] = []
            for edge in lineEdges {
                for piece in split(edge, by: edgesB, epsilon: epsilon) {
                    let middle = Point(x: (piece.start.x + piece.end.x) / 2, y: (piece.start.y + piece.end.y) / 2)
                    if isInside(winding(middle, edgesB), rule) == keepsInside {
                        if current.isEmpty { current = [piece.start] }
                        current.append(piece.end)
                    } else if current.isEmpty == false {
                        polylines.append(current)
                        current = []
                    }
                }
            }
            if current.isEmpty == false {
                // a closed subpath's last line runs on into its first
                if subpath.closed, let first = polylines.first, first.first == current.last, polylines.isEmpty == false {
                    polylines[0] = current + first.dropFirst()
                } else {
                    polylines.append(current)
                }
            }
            result.append(contentsOf: polylines)
        }
        return result
    }

    // MARK: Rings

    /// The signed area of a ring: positive when it runs counterclockwise with y up.
    static func area(of ring: [Point]) -> Double {
        guard ring.count > 2 else { return 0 }
        var area = 0.0
        var previous = ring[ring.count - 1]
        for point in ring {
            area += previous.x * point.y - point.x * previous.y
            previous = point
        }
        return area / 2
    }

    /// The ring turned to run counterclockwise with y up.
    static func counterclockwise(_ ring: [Point]) -> [Point] {
        area(of: ring) >= 0 ? ring : ring.reversed()
    }

    /// Whether a point is inside a ring.
    static func contains(_ ring: [Point], _ point: Point) -> Bool {
        winding(point, edges(of: [ring])) != 0
    }

    static func path(rings: [[Point]]) -> Path {
        var path = Path()
        for ring in rings where ring.count > 1 {
            path.move(to: ring[0])
            for point in ring.dropFirst() {
                path.addLine(to: point)
            }
            path.closeSubpath()
        }
        return path
    }

    static func path(polylines: [[Point]]) -> Path {
        var path = Path()
        for polyline in polylines where polyline.count > 1 {
            path.move(to: polyline[0])
            for point in polyline.dropFirst() {
                path.addLine(to: point)
            }
        }
        return path
    }

    // MARK: Edges

    static func edges(of rings: [[Point]]) -> [Edge] {
        rings.flatMap { polylineEdges($0, closed: true) }
    }

    static func polylineEdges(_ points: [Point], closed: Bool) -> [Edge] {
        guard points.count > 1 else { return [] }
        var edges: [Edge] = []
        for index in 0 ..< points.count - 1 where points[index] != points[index + 1] {
            edges.append(Edge(start: points[index], end: points[index + 1]))
        }
        if closed, let first = points.first, let last = points.last, first != last {
            edges.append(Edge(start: last, end: first))
        }
        return edges
    }

    /// How many times the edges wind around a point, counterclockwise with y up.
    static func winding(_ point: Point, _ edges: [Edge]) -> Int {
        var winding = 0
        for edge in edges {
            let a = edge.start, b = edge.end
            if a.y <= point.y {
                if b.y > point.y, cross(a, b, point) > 0 { winding += 1 }
            } else if b.y <= point.y, cross(a, b, point) < 0 {
                winding -= 1
            }
        }
        return winding
    }

    static func isInside(_ winding: Int, _ rule: FillRule) -> Bool {
        switch rule {
        case .winding: return winding != 0
        case .evenOdd: return winding % 2 != 0
        }
    }

    static func extent(of edges: [Edge]) -> Double {
        var extent = 0.0
        for edge in edges {
            extent = max(extent, abs(edge.start.x), abs(edge.start.y), abs(edge.end.x), abs(edge.end.y))
        }
        return extent
    }
}

// MARK: - Splitting

private extension PathBoolean {

    /// The edges, each split where it meets another.
    static func split(_ edges: [Edge], epsilon: Double) -> [Edge] {
        var cuts = [[Double]](repeating: [], count: edges.count)
        for i in edges.indices {
            for j in edges.indices where j > i {
                guard let (first, second) = intersections(edges[i], edges[j], epsilon: epsilon) else { continue }
                cuts[i].append(contentsOf: first)
                cuts[j].append(contentsOf: second)
            }
        }
        return edges.indices.flatMap { pieces(of: edges[$0], at: cuts[$0]) }
    }

    /// An edge split where it meets any of the others.
    static func split(_ edge: Edge, by others: [Edge], epsilon: Double) -> [Edge] {
        var cuts: [Double] = []
        for other in others {
            if let (first, _) = intersections(edge, other, epsilon: epsilon) {
                cuts.append(contentsOf: first)
            }
        }
        return pieces(of: edge, at: cuts)
    }

    static func pieces(of edge: Edge, at cuts: [Double]) -> [Edge] {
        let points = [edge.start] + cuts.sorted().map { point(on: edge, at: $0) } + [edge.end]
        var pieces: [Edge] = []
        for index in 0 ..< points.count - 1 where points[index] != points[index + 1] {
            pieces.append(Edge(start: points[index], end: points[index + 1]))
        }
        return pieces
    }

    static func point(on edge: Edge, at t: Double) -> Point {
        Point(x: edge.start.x + (edge.end.x - edge.start.x) * t, y: edge.start.y + (edge.end.y - edge.start.y) * t)
    }

    /// Where two edges meet, as fractions along each strictly inside it: a
    /// crossing, or the ends of an overlap.
    static func intersections(_ e: Edge, _ f: Edge, epsilon: Double) -> ([Double], [Double])? {
        // their boxes must touch
        guard min(e.start.x, e.end.x) <= max(f.start.x, f.end.x) + epsilon,
              min(f.start.x, f.end.x) <= max(e.start.x, e.end.x) + epsilon,
              min(e.start.y, e.end.y) <= max(f.start.y, f.end.y) + epsilon,
              min(f.start.y, f.end.y) <= max(e.start.y, e.end.y) + epsilon else { return nil }
        let r = Point(x: e.end.x - e.start.x, y: e.end.y - e.start.y)
        let s = Point(x: f.end.x - f.start.x, y: f.end.y - f.start.y)
        let lengthR = (r.x * r.x + r.y * r.y).squareRoot(), lengthS = (s.x * s.x + s.y * s.y).squareRoot()
        guard lengthR > 0, lengthS > 0 else { return nil }
        let qp = Point(x: f.start.x - e.start.x, y: f.start.y - e.start.y)
        let denominator = r.x * s.y - r.y * s.x
        let marginR = epsilon / lengthR, marginS = epsilon / lengthS
        func inside(_ t: Double, _ margin: Double) -> Bool { t > margin && t < 1 - margin }
        if abs(denominator) > 1e-12 * lengthR * lengthS {
            let t = (qp.x * s.y - qp.y * s.x) / denominator
            let u = (qp.x * r.y - qp.y * r.x) / denominator
            guard t >= -marginR, t <= 1 + marginR, u >= -marginS, u <= 1 + marginS else { return nil }
            return (inside(t, marginR) ? [t] : [], inside(u, marginS) ? [u] : [])
        }
        // parallel: they meet only if they're on one line
        guard abs(qp.x * r.y - qp.y * r.x) / lengthR <= epsilon else { return nil }
        func along(_ point: Point, _ origin: Point, _ direction: Point, _ length: Double) -> Double {
            ((point.x - origin.x) * direction.x + (point.y - origin.y) * direction.y) / (length * length)
        }
        let first = [along(f.start, e.start, r, lengthR), along(f.end, e.start, r, lengthR)].filter { inside($0, marginR) }
        let second = [along(e.start, f.start, s, lengthS), along(e.end, f.start, s, lengthS)].filter { inside($0, marginS) }
        return (first, second)
    }
}

// MARK: - Joining

private extension PathBoolean {

    /// The edges joined end to start into rings, turning as far left as they
    /// can where several leave a point, so each ring goes around one face.
    static func chain(_ edges: [Edge], epsilon: Double) -> [[Point]] {
        var outgoing: [PointKey: [Int]] = [:]
        for (index, edge) in edges.enumerated() {
            outgoing[PointKey(edge.start), default: []].append(index)
        }
        var used = [Bool](repeating: false, count: edges.count)
        var rings: [[Point]] = []
        for first in edges.indices where used[first] == false {
            used[first] = true
            var ring = [edges[first].start]
            var current = first
            while true {
                let edge = edges[current]
                if edge.end == ring[0] { break }
                let candidates = (outgoing[PointKey(edge.end)] ?? []).filter { used[$0] == false }
                guard let next = candidates.max(by: { turn(edge, edges[$0]) < turn(edge, edges[$1]) }) else { break }
                ring.append(edge.end)
                used[next] = true
                current = next
            }
            let simplified = simplify(ring, epsilon: epsilon)
            if simplified.count > 2, abs(area(of: simplified)) > epsilon * epsilon {
                rings.append(simplified)
            }
        }
        return rings
    }

    /// The angle from one edge's direction to the next's, positive to the left.
    static func turn(_ edge: Edge, _ next: Edge) -> Double {
        let d = Point(x: edge.end.x - edge.start.x, y: edge.end.y - edge.start.y)
        let v = Point(x: next.end.x - next.start.x, y: next.end.y - next.start.y)
        return atan2(d.x * v.y - d.y * v.x, d.x * v.x + d.y * v.y)
    }

    /// The ring without points along the line between their neighbors.
    static func simplify(_ ring: [Point], epsilon: Double) -> [Point] {
        var points = ring
        var changed = true
        while changed, points.count > 2 {
            changed = false
            var index = 0
            while index < points.count, points.count > 2 {
                let previous = points[(index + points.count - 1) % points.count]
                let point = points[index]
                let next = points[(index + 1) % points.count]
                let dx = next.x - previous.x, dy = next.y - previous.y
                let length = (dx * dx + dy * dy).squareRoot()
                let distance = length > 0 ? abs(cross(previous, next, point)) / length : 0
                let between = (point.x - previous.x) * (next.x - point.x) + (point.y - previous.y) * (next.y - point.y) >= 0
                if point == previous || (distance <= epsilon && between) {
                    points.remove(at: index)
                    changed = true
                } else {
                    index += 1
                }
            }
        }
        return points
    }
}

// MARK: - Points

/// A point's exact coordinates, to look it up by.
private struct PointKey: Hashable {

    let x: UInt64
    let y: UInt64

    init(_ point: Point) {
        // 0 and -0 are one point
        x = (point.x == 0 ? 0 : point.x).bitPattern
        y = (point.y == 0 ? 0 : point.y).bitPattern
    }
}

/// An edge whichever way it runs.
private struct EdgeKey: Hashable {

    let first: PointKey
    let second: PointKey

    init(_ a: Point, _ b: Point) {
        let keyA = PointKey(a), keyB = PointKey(b)
        if (a.x, a.y) < (b.x, b.y) {
            first = keyA
            second = keyB
        } else {
            first = keyB
            second = keyA
        }
    }
}

/// Points within a distance of one made earlier become it, so the ends of
/// pieces split from different edges meet exactly.
private final class Welder {

    let epsilon: Double

    private var cells: [Cell: [Point]] = [:]

    private struct Cell: Hashable {
        let x: Int64
        let y: Int64
    }

    init(epsilon: Double) {
        self.epsilon = epsilon
    }

    private var size: Double { epsilon * 4 }

    private func cell(_ point: Point) -> Cell {
        Cell(x: Int64((point.x / size).rounded(.down)), y: Int64((point.y / size).rounded(.down)))
    }

    func weld(_ point: Point) -> Point {
        let home = cell(point)
        for dx in -1 ... 1 {
            for dy in -1 ... 1 {
                for candidate in cells[Cell(x: home.x + Int64(dx), y: home.y + Int64(dy))] ?? [] {
                    if abs(candidate.x - point.x) <= epsilon, abs(candidate.y - point.y) <= epsilon {
                        return candidate
                    }
                }
            }
        }
        cells[home, default: []].append(point)
        return point
    }
}

private func cross(_ a: Point, _ b: Point, _ p: Point) -> Double {
    (b.x - a.x) * (p.y - a.y) - (p.x - a.x) * (b.y - a.y)
}
