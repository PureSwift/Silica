//
//  SoftwareRasterizer.swift
//  Silica3DS
//
//  Created by Alsey Coleman Miller on 7/13/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

#if canImport(Foundation)
import Foundation
#endif
#if canImport(Silica)
import Silica
#endif

// MARK: - Surface

/// A premultiplied RGBA8 pixel surface (rows top-to-bottom).
internal final class SoftwareSurface {

    let width: Int
    let height: Int
    var data: [UInt8]

    init(width: Int, height: Int) {
        self.width = max(0, width)
        self.height = max(0, height)
        self.data = [UInt8](repeating: 0, count: self.width * self.height * 4)
    }
}

// MARK: - Color

/// A premultiplied RGBA color at 8 bits per component.
internal struct RasterColor {

    let red: UInt8
    let green: UInt8
    let blue: UInt8
    let alpha: UInt8

    init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(_ color: CGColor) {

        func clamp(_ value: CGFloat) -> CGFloat { max(0, min(1, value)) }

        let alpha = clamp(color.alpha)

        self.red   = UInt8((clamp(color.red) * alpha * 255).rounded())
        self.green = UInt8((clamp(color.green) * alpha * 255).rounded())
        self.blue  = UInt8((clamp(color.blue) * alpha * 255).rounded())
        self.alpha = UInt8((alpha * 255).rounded())
    }
}

// MARK: - Rasterizer

/// A minimal scanline rasterizer for filling polygons with the winding or
/// even-odd rule, used by `Nintendo3DSContext` (the Nintendo 3DS has no
/// system vector graphics library).
///
/// Geometry is flattened to line segments; sampling is one sample per pixel
/// center (no antialiasing — render at a higher `scale` and downsample for
/// smoother output).
internal enum SoftwareRasterizer {

    // MARK: Flattening

    static let defaultTolerance: CGFloat = 0.2

    /// Flattens path elements into polylines (one per subpath).
    static func flatten(_ elements: [PathElement], tolerance: CGFloat = defaultTolerance) -> [(points: [CGPoint], closed: Bool)] {

        var subpaths = [(points: [CGPoint], closed: Bool)]()
        var current = [CGPoint]()
        var start = CGPoint()

        func endSubpath(closed: Bool) {
            if current.count > 1 {
                subpaths.append((current, closed))
            }
            current.removeAll(keepingCapacity: true)
        }

        for element in elements {

            switch element {

            case let .moveToPoint(point):
                endSubpath(closed: false)
                start = point
                current = [point]

            case let .addLineToPoint(point):
                if current.isEmpty { current = [start] }
                current.append(point)

            case let .addQuadCurveToPoint(control, end):
                if current.isEmpty { current = [start] }
                let origin = current[current.count - 1]
                // promote to cubic
                let control1 = CGPoint(x: (origin.x / 3.0) + (2.0 * control.x / 3.0),
                                       y: (origin.y / 3.0) + (2.0 * control.y / 3.0))
                let control2 = CGPoint(x: (2.0 * control.x / 3.0) + (end.x / 3.0),
                                       y: (2.0 * control.y / 3.0) + (end.y / 3.0))
                flattenCubic(origin, control1, control2, end, tolerance, 0, into: &current)

            case let .addCurveToPoint(control1, control2, end):
                if current.isEmpty { current = [start] }
                let origin = current[current.count - 1]
                flattenCubic(origin, control1, control2, end, tolerance, 0, into: &current)

            case .closeSubpath:
                if current.count > 1 {
                    current.append(start)
                    endSubpath(closed: true)
                } else {
                    current.removeAll(keepingCapacity: true)
                }
                current = [start]
            }
        }

        endSubpath(closed: false)

        return subpaths
    }

    private static func flattenCubic(_ p0: CGPoint, _ c1: CGPoint, _ c2: CGPoint, _ p1: CGPoint,
                                     _ tolerance: CGFloat, _ depth: Int, into points: inout [CGPoint]) {

        if depth > 16 || cubicFlatness(p0, c1, c2, p1) <= tolerance {
            points.append(p1)
            return
        }

        // subdivide at t = 0.5 (de Casteljau)
        func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        }

        let ab = mid(p0, c1), bc = mid(c1, c2), cd = mid(c2, p1)
        let abc = mid(ab, bc), bcd = mid(bc, cd)
        let split = mid(abc, bcd)

        flattenCubic(p0, ab, abc, split, tolerance, depth + 1, into: &points)
        flattenCubic(split, bcd, cd, p1, tolerance, depth + 1, into: &points)
    }

    /// Maximum distance of the control points from the chord.
    private static func cubicFlatness(_ p0: CGPoint, _ c1: CGPoint, _ c2: CGPoint, _ p1: CGPoint) -> CGFloat {

        func distance(_ point: CGPoint) -> CGFloat {
            let dx = p1.x - p0.x
            let dy = p1.y - p0.y
            let lengthSquared = dx * dx + dy * dy
            guard lengthSquared > 0 else {
                let px = point.x - p0.x, py = point.y - p0.y
                return (px * px + py * py).squareRoot()
            }
            // distance from the infinite line through p0-p1
            return abs(dy * (point.x - p0.x) - dx * (point.y - p0.y)) / lengthSquared.squareRoot()
        }

        return max(distance(c1), distance(c2))
    }

    // MARK: Filling

    private struct Edge {
        let yTop: CGFloat
        let yBottom: CGFloat
        let xAtTop: CGFloat
        let slope: CGFloat  // dx / dy
        let winding: Int
    }

    private static func edges(of polygons: [[CGPoint]]) -> [Edge] {

        var edges = [Edge]()

        for polygon in polygons {

            guard polygon.count > 1 else { continue }

            var previous = polygon[polygon.count - 1]  // implicit close

            for point in polygon {

                defer { previous = point }

                let p0 = previous, p1 = point

                guard p0.y != p1.y else { continue }  // horizontal edges never cross a scanline

                if p0.y < p1.y {
                    edges.append(Edge(yTop: p0.y, yBottom: p1.y, xAtTop: p0.x,
                                      slope: (p1.x - p0.x) / (p1.y - p0.y), winding: 1))
                } else {
                    edges.append(Edge(yTop: p1.y, yBottom: p0.y, xAtTop: p1.x,
                                      slope: (p0.x - p1.x) / (p0.y - p1.y), winding: -1))
                }
            }
        }

        return edges
    }

    /// Computes the filled spans for one scanline (sampled at `y`).
    private static func spans(edges: [Edge], y: CGFloat, evenOdd: Bool) -> [(start: CGFloat, end: CGFloat)] {

        var crossings = [(x: CGFloat, winding: Int)]()

        for edge in edges where edge.yTop <= y && y < edge.yBottom {
            crossings.append((edge.xAtTop + (y - edge.yTop) * edge.slope, edge.winding))
        }

        guard crossings.count > 1 else { return [] }

        crossings.sort { $0.x < $1.x }

        var result = [(start: CGFloat, end: CGFloat)]()

        if evenOdd {
            var index = 0
            while index + 1 < crossings.count {
                result.append((crossings[index].x, crossings[index + 1].x))
                index += 2
            }
        } else {
            var winding = 0
            var spanStart: CGFloat = 0
            for crossing in crossings {
                let previous = winding
                winding += crossing.winding
                if previous == 0 && winding != 0 {
                    spanStart = crossing.x
                } else if previous != 0 && winding == 0 {
                    result.append((spanStart, crossing.x))
                }
            }
        }

        return result
    }

    /// Fills polygons into the surface with the given color, respecting an
    /// optional clip mask (one byte of coverage per pixel).
    static func fill(_ polygons: [[CGPoint]],
                     evenOdd: Bool,
                     into surface: SoftwareSurface,
                     color: RasterColor,
                     clip: [UInt8]?) {

        guard surface.width > 0, surface.height > 0 else { return }

        let allEdges = edges(of: polygons)

        guard allEdges.isEmpty == false else { return }

        let yMinimum = max(0, Int(allEdges.map { $0.yTop }.min()!.rounded(.down)))
        let yMaximum = min(surface.height - 1, Int(allEdges.map { $0.yBottom }.max()!.rounded(.up)))

        guard yMinimum <= yMaximum else { return }

        surface.data.withUnsafeMutableBufferPointer { buffer in

            for pixelY in yMinimum ... yMaximum {

                let sampleY = CGFloat(pixelY) + 0.5

                for span in spans(edges: allEdges, y: sampleY, evenOdd: evenOdd) {

                    // pixels whose center lies inside [start, end)
                    let first = max(0, Int((span.start - 0.5).rounded(.up)))
                    let last = min(surface.width, Int((span.end - 0.5).rounded(.up)))

                    guard first < last else { continue }

                    for pixelX in first ..< last {

                        let coverage = clip?[pixelY * surface.width + pixelX] ?? 255

                        guard coverage > 0 else { continue }

                        blend(color, coverage: coverage,
                              into: buffer, at: (pixelY * surface.width + pixelX) * 4)
                    }
                }
            }
        }
    }

    /// Rasterizes polygons into a coverage mask (255 inside, 0 outside).
    static func mask(_ polygons: [[CGPoint]],
                     evenOdd: Bool,
                     width: Int,
                     height: Int) -> [UInt8] {

        var mask = [UInt8](repeating: 0, count: width * height)

        guard width > 0, height > 0 else { return mask }

        let allEdges = edges(of: polygons)

        guard allEdges.isEmpty == false else { return mask }

        let yMinimum = max(0, Int(allEdges.map { $0.yTop }.min()!.rounded(.down)))
        let yMaximum = min(height - 1, Int(allEdges.map { $0.yBottom }.max()!.rounded(.up)))

        guard yMinimum <= yMaximum else { return mask }

        for pixelY in yMinimum ... yMaximum {

            let sampleY = CGFloat(pixelY) + 0.5

            for span in spans(edges: allEdges, y: sampleY, evenOdd: evenOdd) {

                let first = max(0, Int((span.start - 0.5).rounded(.up)))
                let last = min(width, Int((span.end - 0.5).rounded(.up)))

                guard first < last else { continue }

                for pixelX in first ..< last {
                    mask[pixelY * width + pixelX] = 255
                }
            }
        }

        return mask
    }

    // MARK: Blending

    /// Premultiplied source-over blend of a color scaled by `coverage`.
    @inline(__always)
    static func blend(_ color: RasterColor, coverage: UInt8, into buffer: UnsafeMutableBufferPointer<UInt8>, at offset: Int) {

        let coverage16 = UInt16(coverage)

        let sourceRed = UInt16(color.red) * coverage16 / 255
        let sourceGreen = UInt16(color.green) * coverage16 / 255
        let sourceBlue = UInt16(color.blue) * coverage16 / 255
        let sourceAlpha = UInt16(color.alpha) * coverage16 / 255

        let inverse = 255 - sourceAlpha

        buffer[offset]     = UInt8(sourceRed + UInt16(buffer[offset]) * inverse / 255)
        buffer[offset + 1] = UInt8(sourceGreen + UInt16(buffer[offset + 1]) * inverse / 255)
        buffer[offset + 2] = UInt8(sourceBlue + UInt16(buffer[offset + 2]) * inverse / 255)
        buffer[offset + 3] = UInt8(sourceAlpha + UInt16(buffer[offset + 3]) * inverse / 255)
    }

    /// Composites `source` onto `destination` (same dimensions) with a global alpha.
    static func composite(_ source: SoftwareSurface, onto destination: SoftwareSurface, alpha: CGFloat) {

        precondition(source.width == destination.width && source.height == destination.height)

        let globalAlpha = UInt16((max(0, min(1, alpha)) * 255).rounded())

        destination.data.withUnsafeMutableBufferPointer { output in
            source.data.withUnsafeBufferPointer { input in

                for offset in stride(from: 0, to: input.count, by: 4) {

                    let sourceAlpha = UInt16(input[offset + 3]) * globalAlpha / 255

                    guard sourceAlpha > 0 else { continue }

                    let sourceRed = UInt16(input[offset]) * globalAlpha / 255
                    let sourceGreen = UInt16(input[offset + 1]) * globalAlpha / 255
                    let sourceBlue = UInt16(input[offset + 2]) * globalAlpha / 255

                    let inverse = 255 - sourceAlpha

                    output[offset]     = UInt8(sourceRed + UInt16(output[offset]) * inverse / 255)
                    output[offset + 1] = UInt8(sourceGreen + UInt16(output[offset + 1]) * inverse / 255)
                    output[offset + 2] = UInt8(sourceBlue + UInt16(output[offset + 2]) * inverse / 255)
                    output[offset + 3] = UInt8(sourceAlpha + UInt16(output[offset + 3]) * inverse / 255)
                }
            }
        }
    }

    // MARK: Stroking

    /// Converts subpaths (already flattened) into stroke outline polygons.
    ///
    /// Every polygon is normalized to a consistent orientation so that filling
    /// their union with the nonzero winding rule yields the stroked region.
    static func strokePolygons(_ subpaths: [(points: [CGPoint], closed: Bool)],
                               width: CGFloat,
                               cap: CGLineCap,
                               join: CGLineJoin,
                               miterLimit: CGFloat,
                               dash: (phase: CGFloat, lengths: [CGFloat])) -> [[CGPoint]] {

        let halfWidth = max(width, 0) / 2

        guard halfWidth > 0 else { return [] }

        var polygons = [[CGPoint]]()

        for subpath in subpaths {

            let polylines: [[CGPoint]]

            if dash.lengths.isEmpty || dash.lengths.allSatisfy({ $0 <= 0 }) {
                polylines = [subpath.points]
            } else {
                polylines = dashed(subpath.points, phase: dash.phase, lengths: dash.lengths)
            }

            let isClosed = subpath.closed && polylines.count == 1

            for polyline in polylines {

                guard polyline.count > 1 else { continue }

                // segment quads
                for index in 0 ..< polyline.count - 1 {

                    let p0 = polyline[index]
                    let p1 = polyline[index + 1]

                    guard let normal = normal(from: p0, to: p1, length: halfWidth) else { continue }

                    polygons.append(normalized([
                        CGPoint(x: p0.x + normal.dx, y: p0.y + normal.dy),
                        CGPoint(x: p1.x + normal.dx, y: p1.y + normal.dy),
                        CGPoint(x: p1.x - normal.dx, y: p1.y - normal.dy),
                        CGPoint(x: p0.x - normal.dx, y: p0.y - normal.dy)
                    ]))
                }

                // joins at interior vertices (and the seam vertex of closed subpaths)
                var jointIndices = Array(1 ..< polyline.count - 1)
                if isClosed { jointIndices.append(0) }

                for index in jointIndices {

                    let vertex = polyline[index]
                    let before = index == 0 ? polyline[polyline.count - 2] : polyline[index - 1]
                    let after = index == 0 ? polyline[1] : polyline[index + 1]

                    polygons.append(contentsOf: joinPolygons(at: vertex, from: before, to: after,
                                                             halfWidth: halfWidth, join: join, miterLimit: miterLimit))
                }

                // caps at open ends
                if isClosed == false {

                    let start = polyline[0]
                    let end = polyline[polyline.count - 1]

                    if let capPolygon = capPolygon(at: start, towards: polyline[1], halfWidth: halfWidth, cap: cap) {
                        polygons.append(capPolygon)
                    }

                    if let capPolygon = capPolygon(at: end, towards: polyline[polyline.count - 2], halfWidth: halfWidth, cap: cap) {
                        polygons.append(capPolygon)
                    }
                }
            }
        }

        return polygons
    }

    private static func normal(from p0: CGPoint, to p1: CGPoint, length: CGFloat) -> (dx: CGFloat, dy: CGFloat)? {

        let dx = p1.x - p0.x
        let dy = p1.y - p0.y
        let magnitude = (dx * dx + dy * dy).squareRoot()

        guard magnitude > 0 else { return nil }

        return (dx: -dy / magnitude * length, dy: dx / magnitude * length)
    }

    private static func joinPolygons(at vertex: CGPoint, from before: CGPoint, to after: CGPoint,
                                     halfWidth: CGFloat, join: CGLineJoin, miterLimit: CGFloat) -> [[CGPoint]] {

        switch join {

        case .round:
            return [circle(at: vertex, radius: halfWidth)]

        case .bevel:
            return bevelPolygons(at: vertex, from: before, to: after, halfWidth: halfWidth)

        case .miter:

            guard let normal1 = normal(from: before, to: vertex, length: halfWidth),
                let normal2 = normal(from: vertex, to: after, length: halfWidth)
                else { return [] }

            // outer side of the turn: the side where the two offset lines diverge
            let direction1 = CGPoint(x: vertex.x - before.x, y: vertex.y - before.y)
            let direction2 = CGPoint(x: after.x - vertex.x, y: after.y - vertex.y)
            let cross = direction1.x * direction2.y - direction1.y * direction2.x

            guard cross != 0 else { return [] }  // collinear: no join needed

            // normals point to the left of travel; the outer side is the
            // right side when turning left, and vice versa
            let side: CGFloat = cross > 0 ? -1 : 1

            let outer1 = CGPoint(x: vertex.x + normal1.dx * side, y: vertex.y + normal1.dy * side)
            let outer2 = CGPoint(x: vertex.x + normal2.dx * side, y: vertex.y + normal2.dy * side)

            // miter length check: 1 / sin(θ/2) vs miter limit
            let bisectorX = normal1.dx * side + normal2.dx * side
            let bisectorY = normal1.dy * side + normal2.dy * side
            let bisectorLength = (bisectorX * bisectorX + bisectorY * bisectorY).squareRoot()

            guard bisectorLength > 0 else { return [] }

            // half-angle between the offset directions
            let cosineHalf = bisectorLength / (2 * halfWidth)

            guard cosineHalf > 0 else { return [] }

            let miterLength = halfWidth / cosineHalf

            guard miterLength <= miterLimit * halfWidth else {
                return bevelPolygons(at: vertex, from: before, to: after, halfWidth: halfWidth)
            }

            let miterPoint = CGPoint(x: vertex.x + bisectorX / bisectorLength * miterLength,
                                     y: vertex.y + bisectorY / bisectorLength * miterLength)

            return [normalized([vertex, outer1, miterPoint, outer2])]
        }
    }

    private static func bevelPolygons(at vertex: CGPoint, from before: CGPoint, to after: CGPoint, halfWidth: CGFloat) -> [[CGPoint]] {

        guard let normal1 = normal(from: before, to: vertex, length: halfWidth),
            let normal2 = normal(from: vertex, to: after, length: halfWidth)
            else { return [] }

        // triangles on both sides; the inner one is covered by the segment
        // quads already, and normalized orientation keeps the union correct
        return [
            normalized([
                vertex,
                CGPoint(x: vertex.x + normal1.dx, y: vertex.y + normal1.dy),
                CGPoint(x: vertex.x + normal2.dx, y: vertex.y + normal2.dy)
            ]),
            normalized([
                vertex,
                CGPoint(x: vertex.x - normal1.dx, y: vertex.y - normal1.dy),
                CGPoint(x: vertex.x - normal2.dx, y: vertex.y - normal2.dy)
            ])
        ]
    }

    private static func capPolygon(at end: CGPoint, towards neighbor: CGPoint, halfWidth: CGFloat, cap: CGLineCap) -> [CGPoint]? {

        switch cap {

        case .butt:
            return nil

        case .round:
            return circle(at: end, radius: halfWidth)

        case .square:

            guard let normal = normal(from: neighbor, to: end, length: halfWidth) else { return nil }

            // outward direction of the cap
            let dx = end.x - neighbor.x
            let dy = end.y - neighbor.y
            let magnitude = (dx * dx + dy * dy).squareRoot()

            guard magnitude > 0 else { return nil }

            let outX = dx / magnitude * halfWidth
            let outY = dy / magnitude * halfWidth

            return normalized([
                CGPoint(x: end.x + normal.dx, y: end.y + normal.dy),
                CGPoint(x: end.x + normal.dx + outX, y: end.y + normal.dy + outY),
                CGPoint(x: end.x - normal.dx + outX, y: end.y - normal.dy + outY),
                CGPoint(x: end.x - normal.dx, y: end.y - normal.dy)
            ])
        }
    }

    private static func circle(at center: CGPoint, radius: CGFloat, segments: Int = 16) -> [CGPoint] {

        var points = [CGPoint]()
        points.reserveCapacity(segments)

        for index in 0 ..< segments {
            let angle = 2 * CGFloat.pi * CGFloat(index) / CGFloat(segments)
            points.append(CGPoint(x: center.x + radius * CGFloat(cos(Double(angle))),
                                  y: center.y + radius * CGFloat(sin(Double(angle)))))
        }

        return points
    }

    /// Normalizes polygon orientation (positive signed area) so overlapping
    /// stroke pieces never cancel under the nonzero winding rule.
    private static func normalized(_ polygon: [CGPoint]) -> [CGPoint] {

        var area: CGFloat = 0
        var previous = polygon[polygon.count - 1]

        for point in polygon {
            area += (previous.x * point.y) - (point.x * previous.y)
            previous = point
        }

        return area >= 0 ? polygon : polygon.reversed()
    }

    // MARK: Dashing

    /// Splits a polyline into "on" polylines according to a dash pattern.
    private static func dashed(_ points: [CGPoint], phase: CGFloat, lengths: [CGFloat]) -> [[CGPoint]] {

        let pattern = lengths.map { max(0, $0) }
        let patternLength = pattern.reduce(0, +)

        guard patternLength > 0, points.count > 1 else { return [points] }

        var result = [[CGPoint]]()
        var current = [CGPoint]()

        // position within the pattern
        var patternIndex = 0
        var remaining = pattern[0]
        var isOn = true

        var offset = phase.truncatingRemainder(dividingBy: patternLength)
        if offset < 0 { offset += patternLength }

        while offset > 0 {
            let consumed = min(offset, remaining)
            offset -= consumed
            remaining -= consumed
            if remaining <= 0 {
                patternIndex = (patternIndex + 1) % pattern.count
                remaining = pattern[patternIndex]
                isOn.toggle()
            }
        }

        if isOn { current.append(points[0]) }

        for index in 0 ..< points.count - 1 {

            var p0 = points[index]
            let p1 = points[index + 1]

            var segmentLength = ((p1.x - p0.x) * (p1.x - p0.x) + (p1.y - p0.y) * (p1.y - p0.y)).squareRoot()

            while segmentLength > 0 {

                if remaining >= segmentLength {
                    remaining -= segmentLength
                    segmentLength = 0
                    if isOn { current.append(p1) }
                } else {
                    let t = remaining / segmentLength
                    let split = CGPoint(x: p0.x + (p1.x - p0.x) * t, y: p0.y + (p1.y - p0.y) * t)
                    if isOn { current.append(split) }
                    segmentLength -= remaining
                    p0 = split
                    remaining = 0
                }

                if remaining <= 0 {
                    if isOn, current.count > 1 { result.append(current) }
                    current.removeAll(keepingCapacity: true)
                    patternIndex = (patternIndex + 1) % pattern.count
                    remaining = pattern[patternIndex]
                    isOn.toggle()
                    if isOn, segmentLength > 0 { current.append(p0) }
                }
            }
        }

        if isOn, current.count > 1 { result.append(current) }

        return result
    }
}
