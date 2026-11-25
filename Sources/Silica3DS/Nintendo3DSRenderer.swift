//
//  Nintendo3DSRenderer.swift
//  Silica3DS
//
//  Created by Alsey Coleman Miller on 7/13/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#elseif canImport(WASILibc)
import WASILibc
#endif

#if canImport(Foundation)
import struct Foundation.Data
#endif
#if canImport(Silica)
import Silica
#endif

/// A renderer that rasterizes in pure Swift, for the Nintendo 3DS.
///
/// The 3DS has no system vector graphics library, so this renderer draws
/// into a premultiplied RGBA bitmap. Read it back with `makeImage()`, or copy
/// it into a GSP framebuffer with `present(into:)` (the 3DS framebuffer is
/// rotated 90° with column-major addressing).
///
/// The renderer is pure Swift, so it also works, and is tested, on every
/// other platform.
///
/// - Note: Edges aren't antialiased at `scale: 1`. A higher scale supersamples:
///   drawing happens at `size * scale`, and `makeImage()` and
///   `present(into:)` average each block of samples.
/// - Note: There are no fonts on this backend, so glyphs draw nothing.
///   Blend modes other than normal draw as normal, and shadows aren't blurred.
public final class Nintendo3DSRenderer: Renderer {

    // MARK: - Properties

    public let size: Size

    /// Samples per point on each axis.
    public let scale: Int

    /// The physical screen this renderer draws to, if made with `init(screen:scale:)`.
    public internal(set) var screen: Screen?

    /// The bitmap, then a surface for each transparency layer begun.
    private var surfaceStack: [SoftwareSurface]

    private var currentSurface: SoftwareSurface { surfaceStack[surfaceStack.count - 1] }

    private var state = State()

    private var stack: [State] = []

    private var layers: [Layer] = []

    private let pixelWidth: Int

    private let pixelHeight: Int

    // MARK: - Initialization

    /// A bitmap `size` points across, `scale` samples per point on each axis.
    public init(bitmap size: Size, scale: Int = 1) throws(SilicaError) {
        let scale = max(1, scale)
        let pixelWidth = Int(size.width) * scale
        let pixelHeight = Int(size.height) * scale
        guard pixelWidth > 0, pixelHeight > 0 else { throw SilicaError.invalidContext }
        self.size = size
        self.scale = scale
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.surfaceStack = [SoftwareSurface(width: pixelWidth, height: pixelHeight)]
        Nintendo3DSBackend.registerIfNeeded()
    }

    // MARK: - Graphics State

    public func saveState() {
        stack.append(state)
    }

    public func restoreState() {
        guard let saved = stack.popLast() else { return }
        state = saved
    }

    public func concatenate(_ transform: AffineTransform) {
        state.ctm = transform.concatenating(state.ctm)
    }

    public func setAlpha(_ alpha: Double) {
        state.alpha = alpha
    }

    public func setBlendMode(_ mode: BlendMode) {
        state.blendMode = mode
    }

    public func setShouldAntialias(_ shouldAntialias: Bool) {
        // edges are never antialiased: supersample instead
    }

    public func setFillColor(_ color: Color) {
        state.fillColor = color
    }

    public func setStrokeColor(_ color: Color) {
        state.strokeColor = color
    }

    public func setStrokeStyle(_ style: StrokeStyle) {
        state.strokeStyle = style
    }

    public func setShadow(_ shadow: Shadow?) {
        state.shadow = shadow
    }

    // MARK: - Painting

    public func fill(_ path: Path, rule: FillRule) {
        let polygons = SoftwareRasterizer.flatten(path.applying(deviceTransform).elements).map { $0.points }
        paint(polygons, evenOdd: rule == .evenOdd, color: state.fillColor)
    }

    public func stroke(_ path: Path) {
        // the pen is shaped in user space, so it transforms with the CTM
        let style = state.strokeStyle
        let outline = SoftwareRasterizer.strokePolygons(SoftwareRasterizer.flatten(path.elements),
                                                        width: style.lineWidth,
                                                        cap: style.lineCap,
                                                        join: style.lineJoin,
                                                        miterLimit: style.miterLimit,
                                                        dash: (style.dashPhase, style.dash))
        let transform = deviceTransform
        paint(outline.map { polygon in polygon.map { $0.applying(transform) } }, evenOdd: false, color: state.strokeColor)
    }

    public func clip(to path: Path, rule: FillRule) {
        let polygons = SoftwareRasterizer.flatten(path.applying(deviceTransform).elements).map { $0.points }
        let mask = SoftwareRasterizer.mask(polygons, evenOdd: rule == .evenOdd, width: pixelWidth, height: pixelHeight)
        state.clip = intersect(state.clip, mask)
    }

    public func resetClip() {
        state.clip = nil
    }

    public func clear(_ rect: Rect) {
        let mask = intersect(state.clip, SoftwareRasterizer.mask([devicePolygon(of: rect)], evenOdd: false,
                                                                 width: pixelWidth, height: pixelHeight))
        currentSurface.data.withUnsafeMutableBufferPointer { buffer in
            for index in 0 ..< mask.count where mask[index] > 0 {
                let keep = UInt16(255 - mask[index])
                for channel in 0 ..< 4 {
                    buffer[index * 4 + channel] = UInt8(UInt16(buffer[index * 4 + channel]) * keep / 255)
                }
            }
        }
    }

    public func draw(_ image: Image, in rect: Rect) {
        guard rect.width != 0, rect.height != 0, image.width > 0, image.height > 0 else { return }
        let transform = deviceTransform
        let inverse = transform.inverted()
        let alpha = UInt16((min(max(state.alpha, 0), 1) * 255).rounded())
        forEachPixel(in: devicePolygon(of: rect)) { pixelX, pixelY, coverage, destination in
            // the pixel's center in user space, then in the image: first row at the top
            let user = Point(x: Double(pixelX) + 0.5, y: Double(pixelY) + 0.5).applying(inverse)
            let u = (user.x - rect.minX) / rect.width
            let v = (user.y - rect.minY) / rect.height
            guard u >= 0, u < 1, v >= 0, v < 1 else { return }
            let sourceX = min(image.width - 1, Int(u * Double(image.width)))
            let sourceY = min(image.height - 1, Int(v * Double(image.height)))
            let offset = sourceY * image.bytesPerRow + sourceX * 4
            let color = RasterColor(red: UInt8(UInt16(image.data[offset]) * alpha / 255),
                                    green: UInt8(UInt16(image.data[offset + 1]) * alpha / 255),
                                    blue: UInt8(UInt16(image.data[offset + 2]) * alpha / 255),
                                    alpha: UInt8(UInt16(image.data[offset + 3]) * alpha / 255))
            SoftwareRasterizer.blend(color, coverage: coverage, into: destination, at: (pixelY * pixelWidth + pixelX) * 4)
        }
    }

    public func drawLinearGradient(_ gradient: Gradient, start: Point, end: Point, options: GradientOptions) {
        let dx = end.x - start.x, dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return }
        paintGradient(gradient, options: options) { point in
            ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared
        }
    }

    public func drawRadialGradient(_ gradient: Gradient, startCenter: Point, startRadius: Double,
                                   endCenter: Point, endRadius: Double, options: GradientOptions) {
        // the largest t where the circle between the two at t contains the point
        let cdx = endCenter.x - startCenter.x, cdy = endCenter.y - startCenter.y, dr = endRadius - startRadius
        let a = cdx * cdx + cdy * cdy - dr * dr
        paintGradient(gradient, options: options) { point in
            let px = point.x - startCenter.x, py = point.y - startCenter.y
            let b = px * cdx + py * cdy + startRadius * dr
            let c = px * px + py * py - startRadius * startRadius
            if abs(a) < 1e-12 {
                guard b != 0 else { return nil }
                let t = c / (2 * b)
                return startRadius + t * dr >= 0 ? t : nil
            }
            let discriminant = b * b - a * c
            guard discriminant >= 0 else { return nil }
            let root = sqrt(discriminant)
            for t in [(b + root) / a, (b - root) / a].sorted(by: >) where startRadius + t * dr >= 0 {
                return t
            }
            return nil
        }
    }

    public func beginTransparencyLayer(in rect: Rect?) {
        layers.append(Layer(alpha: state.alpha, shadow: state.shadow))
        stack.append(state)
        state.alpha = 1
        state.shadow = nil
        state.blendMode = .normal
        if let rect {
            state.clip = intersect(state.clip, SoftwareRasterizer.mask([devicePolygon(of: rect)], evenOdd: false,
                                                                       width: pixelWidth, height: pixelHeight))
        }
        surfaceStack.append(SoftwareSurface(width: pixelWidth, height: pixelHeight))
    }

    public func endTransparencyLayer() {
        guard surfaceStack.count > 1, let layer = layers.popLast(), let saved = stack.popLast() else { return }
        let surface = surfaceStack.removeLast()
        state = saved
        SoftwareRasterizer.composite(surface, onto: currentSurface, alpha: layer.alpha)
    }

    /// Draws nothing: there are no fonts on the 3DS backend yet.
    public func draw(_ glyphs: [Glyph], at positions: [Point], font: Font, textMatrix: AffineTransform, mode: TextDrawingMode) { }

    // MARK: - Document

    public func beginPage() { }

    public func endPage() { }

    public func finish() throws(SilicaError) { }

    /// The bitmap, one pixel per point: each block of samples averaged.
    public func makeImage() -> Image? {
        let width = pixelWidth / scale
        let height = pixelHeight / scale
        let bytesPerRow = width * 4
        var data = [UInt8](repeating: 0, count: bytesPerRow * height)
        let samples = scale * scale
        let input = surfaceStack[0].data
        for y in 0 ..< height {
            for x in 0 ..< width {
                var sums: (Int, Int, Int, Int) = (0, 0, 0, 0)
                for sampleY in 0 ..< scale {
                    for sampleX in 0 ..< scale {
                        let offset = ((y * scale + sampleY) * pixelWidth + (x * scale + sampleX)) * 4
                        sums.0 += Int(input[offset])
                        sums.1 += Int(input[offset + 1])
                        sums.2 += Int(input[offset + 2])
                        sums.3 += Int(input[offset + 3])
                    }
                }
                let offset = y * bytesPerRow + x * 4
                data[offset] = UInt8(sums.0 / samples)
                data[offset + 1] = UInt8(sums.1 / samples)
                data[offset + 2] = UInt8(sums.2 / samples)
                data[offset + 3] = UInt8(sums.3 / samples)
            }
        }
        #if canImport(Foundation)
        return Image(width: width, height: height, bytesPerRow: bytesPerRow, data: Data(data))
        #else
        return Image(width: width, height: height, bytesPerRow: bytesPerRow, data: data)
        #endif
    }
}

// MARK: - Private

private extension Nintendo3DSRenderer {

    struct State {
        var ctm: AffineTransform = .identity
        var fillColor: Color = .black
        var strokeColor: Color = .black
        var strokeStyle = StrokeStyle()
        var alpha: Double = 1
        var blendMode: BlendMode = .normal
        var shadow: Shadow?
        /// Coverage per sample, or nil for no clip.
        var clip: [UInt8]?
    }

    struct Layer {
        var alpha: Double
        var shadow: Shadow?
    }

    /// From user space to samples.
    var deviceTransform: AffineTransform {
        state.ctm.concatenating(AffineTransform(scaleX: Double(scale), y: Double(scale)))
    }

    func devicePolygon(of rect: Rect) -> [Point] {
        let transform = deviceTransform
        return [Point(x: rect.minX, y: rect.minY), Point(x: rect.maxX, y: rect.minY),
                Point(x: rect.maxX, y: rect.maxY), Point(x: rect.minX, y: rect.maxY)].map { $0.applying(transform) }
    }

    func intersect(_ clip: [UInt8]?, _ mask: [UInt8]) -> [UInt8] {
        guard var clip else { return mask }
        for index in 0 ..< clip.count {
            clip[index] = min(clip[index], mask[index])
        }
        return clip
    }

    /// Fills polygons in a color with the alpha, after their shadow, within the clip.
    func paint(_ polygons: [[Point]], evenOdd: Bool, color: Color) {
        if let shadow = state.shadow, shadow.color.alpha > 0 {
            // the offset is in base space, unaffected by the transform
            let dx = shadow.offset.width * Double(scale), dy = shadow.offset.height * Double(scale)
            let offset = polygons.map { polygon in polygon.map { Point(x: $0.x + dx, y: $0.y + dy) } }
            SoftwareRasterizer.fill(offset, evenOdd: evenOdd, into: currentSurface,
                                    color: RasterColor(shadow.color.opacity(state.alpha)), clip: state.clip)
        }
        let color = color.opacity(state.alpha)
        guard color.alpha > 0 else { return }
        SoftwareRasterizer.fill(polygons, evenOdd: evenOdd, into: currentSurface, color: RasterColor(color), clip: state.clip)
    }

    /// Visits each sample in a device polygon that the clip lets through.
    func forEachPixel(in polygon: [Point], _ body: (Int, Int, UInt8, UnsafeMutableBufferPointer<UInt8>) -> Void) {
        let area = intersect(state.clip, SoftwareRasterizer.mask([polygon], evenOdd: false, width: pixelWidth, height: pixelHeight))
        currentSurface.data.withUnsafeMutableBufferPointer { destination in
            for pixelY in 0 ..< pixelHeight {
                for pixelX in 0 ..< pixelWidth {
                    let coverage = area[pixelY * pixelWidth + pixelX]
                    guard coverage > 0 else { continue }
                    body(pixelX, pixelY, coverage, destination)
                }
            }
        }
    }

    /// Paints every sample in the clip with the gradient's color at the
    /// sample's `t`, or nothing where `t` is nil or past an end that isn't extended.
    func paintGradient(_ gradient: Gradient, options: GradientOptions, t: (Point) -> Double?) {
        guard let first = gradient.stops.first, let last = gradient.stops.last,
              let inverse = deviceTransform.invertedIfPossible() else { return }
        let all = [Point(x: 0, y: 0), Point(x: Double(pixelWidth), y: 0),
                   Point(x: Double(pixelWidth), y: Double(pixelHeight)), Point(x: 0, y: Double(pixelHeight))]
        forEachPixel(in: all) { pixelX, pixelY, coverage, destination in
            let user = Point(x: Double(pixelX) + 0.5, y: Double(pixelY) + 0.5).applying(inverse)
            guard var value = t(user) else { return }
            if value < 0 {
                guard options.contains(.drawsBeforeStartLocation) else { return }
                value = 0
            } else if value > 1 {
                guard options.contains(.drawsAfterEndLocation) else { return }
                value = 1
            }
            let color: Color
            if value <= first.location {
                color = first.color
            } else if value >= last.location {
                color = last.color
            } else {
                var index = 1
                while gradient.stops[index].location < value { index += 1 }
                let a = gradient.stops[index - 1], b = gradient.stops[index]
                let span = b.location - a.location
                let f = span > 0 ? (value - a.location) / span : 0
                color = Color(red: a.color.red + (b.color.red - a.color.red) * f,
                              green: a.color.green + (b.color.green - a.color.green) * f,
                              blue: a.color.blue + (b.color.blue - a.color.blue) * f,
                              alpha: a.color.alpha + (b.color.alpha - a.color.alpha) * f)
            }
            SoftwareRasterizer.blend(RasterColor(color.opacity(state.alpha)), coverage: coverage,
                                     into: destination, at: (pixelY * pixelWidth + pixelX) * 4)
        }
    }
}
