//
//  ContextAPI.swift
//  SilicaCoreGraphicsABI
//
//  Created by Alsey Coleman Miller on 11/25/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

// Apple's CoreGraphics is loaded with Foundation on Darwin, and clashes with
// these headers: libCoreGraphics is for other platforms. Contexts draw with
// Silica's Cairo renderer.
#if !canImport(Darwin) && canImport(Cairo)

import Cairo
import CSilicaCoreGraphics
import Silica
import SilicaCairo

#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#endif

// The functions of CGContext.h and CGBitmapContext.h.

// MARK: - Bitmap Memory

/// A bitmap context's memory, and the Cairo surface drawn into it.
///
/// Memory already in Cairo's layout is drawn into directly. Any other format
/// is kept in step with a surface of Cairo's own: before each painting, the
/// rows of memory the program has changed since the last are copied into the
/// surface; after it, the surface is copied back. A copy of the memory as it
/// last was in step tells which rows the program changed.
internal final class BitmapStorage {

    let width: Int
    let height: Int
    let bytesPerRow: Int
    let format: PixelFormat
    let data: UnsafeMutableRawPointer
    let surface: Cairo.Surface.Image
    let renderer: CairoRenderer
    let isDirect: Bool
    private var mirror: [UInt8]
    private let onRelease: () -> Void

    init?(width: Int, height: Int, bytesPerRow: Int, format: PixelFormat, data: UnsafeMutableRawPointer, onRelease: @escaping () -> Void) {
        let direct = format.isCairoNative && bytesPerRow == width * 4
        let surface: Cairo.Surface.Image
        do {
            if direct {
                surface = try Cairo.Surface.Image(mutableBytes: data.assumingMemoryBound(to: UInt8.self),
                                                  format: format.alpha == .skip ? .rgb24 : .argb32,
                                                  width: width, height: height, stride: bytesPerRow)
            } else {
                surface = try Cairo.Surface.Image(format: .argb32, width: width, height: height)
            }
        } catch {
            return nil
        }
        guard let renderer = try? CairoRenderer(surface: surface, size: Silica.Size(width: Double(width), height: Double(height)))
            else { return nil }
        self.width = width
        self.height = height
        self.bytesPerRow = bytesPerRow
        self.format = format
        self.data = data
        self.surface = surface
        self.renderer = renderer
        self.isDirect = direct
        self.onRelease = onRelease
        self.mirror = []
        if direct == false {
            // the memory's contents start the surface
            mirror = [UInt8](repeating: 0, count: bytesPerRow * height)
            pull(all: true)
        }
    }

    deinit {
        onRelease()
    }

    /// Copies the rows of memory the program changed into the surface.
    func pull(all: Bool = false) {
        guard isDirect == false else { return }
        surface.flush()
        let stride = surface.stride
        let changed = mirror.withUnsafeBytes { mirror in
            (0 ..< height).filter { row in
                all || memcmp(data + row * bytesPerRow, mirror.baseAddress! + row * bytesPerRow, width * format.bytesPerPixel) != 0
            }
        }
        guard changed.isEmpty == false else { return }
        _ = surface.withUnsafeMutableBytes { pixels in
            for row in changed {
                let source = data + row * bytesPerRow
                let target = UnsafeMutableRawPointer(pixels + row * stride)
                for x in 0 ..< width {
                    let (r, g, b, a) = format.read(source + x * format.bytesPerPixel)
                    let word = UInt32(a) << 24 | UInt32(r) << 16 | UInt32(g) << 8 | UInt32(b)
                    target.storeBytes(of: word, toByteOffset: x * 4, as: UInt32.self)
                }
            }
        }
        surface.markDirty()
        mirror.withUnsafeMutableBytes { mirror in
            for row in changed {
                memcpy(mirror.baseAddress! + row * bytesPerRow, data + row * bytesPerRow, width * format.bytesPerPixel)
            }
        }
    }

    /// Copies the surface back into memory.
    func push() {
        guard isDirect == false else { return }
        surface.flush()
        let stride = surface.stride
        _ = surface.withUnsafeMutableBytes { pixels in
            for row in 0 ..< height {
                let source = UnsafeRawPointer(pixels + row * stride)
                let target = data + row * bytesPerRow
                for x in 0 ..< width {
                    let word = source.load(fromByteOffset: x * 4, as: UInt32.self)
                    format.write((UInt8(truncatingIfNeeded: word >> 16), UInt8(truncatingIfNeeded: word >> 8),
                                  UInt8(truncatingIfNeeded: word), UInt8(truncatingIfNeeded: word >> 24)),
                                 to: target + x * format.bytesPerPixel)
                }
            }
        }
        mirror.withUnsafeMutableBytes { mirror in
            memcpy(mirror.baseAddress!, data, bytesPerRow * height)
        }
    }

    /// The memory as it is now.
    func snapshot() -> [UInt8] {
        if isDirect {
            surface.flush()
        }
        return [UInt8](UnsafeRawBufferPointer(start: data, count: bytesPerRow * height))
    }
}

/// A renderer that keeps a bitmap's memory in step with its surface around
/// each painting.
internal final class SyncedRenderer: Renderer {

    let storage: BitmapStorage

    var base: CairoRenderer { storage.renderer }

    init(_ storage: BitmapStorage) {
        self.storage = storage
        if case .gray = storage.format.layout {
            isGray = true
        } else {
            isGray = false
        }
    }

    /// Whether the memory is gray: colors are made gray before they're drawn,
    /// so they blend in gray, as CoreGraphics blends them.
    let isGray: Bool

    private func paint(_ color: Silica.Color) -> Silica.Color {
        guard isGray else { return color }
        // a whole byte's level, which Cairo stores exactly
        let level = (grayLevel(red: color.red, green: color.green, blue: color.blue) * 255).rounded() / 255
        return Silica.Color(white: level, alpha: color.alpha)
    }

    private func paint(_ gradient: Gradient) -> Gradient {
        guard isGray else { return gradient }
        return Gradient(stops: gradient.stops.map { Gradient.Stop(color: paint($0.color), location: $0.location) })
    }

    private func painting(_ body: () -> Void) {
        storage.pull()
        body()
        storage.push()
    }

    var size: Silica.Size { base.size }
    func saveState() { base.saveState() }
    func restoreState() { base.restoreState() }
    func concatenate(_ transform: Silica.AffineTransform) { base.concatenate(transform) }
    func setAlpha(_ alpha: Double) { base.setAlpha(alpha) }
    func setBlendMode(_ mode: Silica.BlendMode) { base.setBlendMode(mode) }
    func setShouldAntialias(_ shouldAntialias: Bool) { base.setShouldAntialias(shouldAntialias) }
    func setFillColor(_ color: Silica.Color) { base.setFillColor(paint(color)) }
    func setStrokeColor(_ color: Silica.Color) { base.setStrokeColor(paint(color)) }
    func setStrokeStyle(_ style: StrokeStyle) { base.setStrokeStyle(style) }
    func setShadow(_ shadow: Shadow?) { base.setShadow(shadow.map { Shadow(offset: $0.offset, blur: $0.blur, color: paint($0.color)) }) }
    func setInterpolationQuality(_ quality: InterpolationQuality) { base.setInterpolationQuality(quality) }
    func fill(_ path: Silica.Path, rule: FillRule) { painting { base.fill(path, rule: rule) } }
    func stroke(_ path: Silica.Path) { painting { base.stroke(path) } }
    func clip(to path: Silica.Path, rule: FillRule) { base.clip(to: path, rule: rule) }
    func clear(_ rect: Silica.Rect) { painting { base.clear(rect) } }
    func draw(_ image: Silica.Image, in rect: Silica.Rect) { painting { base.draw(image, in: rect) } }
    func drawLinearGradient(_ gradient: Gradient, start: Silica.Point, end: Silica.Point, options: GradientOptions) {
        painting { base.drawLinearGradient(paint(gradient), start: start, end: end, options: options) }
    }
    func drawRadialGradient(_ gradient: Gradient, startCenter: Silica.Point, startRadius: Double,
                            endCenter: Silica.Point, endRadius: Double, options: GradientOptions) {
        painting { base.drawRadialGradient(paint(gradient), startCenter: startCenter, startRadius: startRadius,
                                           endCenter: endCenter, endRadius: endRadius, options: options) }
    }
    func beginTransparencyLayer(in rect: Silica.Rect?) { painting { base.beginTransparencyLayer(in: rect) } }
    func endTransparencyLayer() { painting { base.endTransparencyLayer() } }
    func draw(_ glyphs: [Glyph], at positions: [Silica.Point], font: Silica.Font,
              textMatrix: Silica.AffineTransform, mode: TextDrawingMode) {
        painting { base.draw(glyphs, at: positions, font: font, textMatrix: textMatrix, mode: mode) }
    }
    func beginPage() { base.beginPage() }
    func endPage() { base.endPage() }
    func finish() throws(SilicaError) { try base.finish() }
    func makeImage() -> Silica.Image? { base.makeImage() }
}

// MARK: - Contexts

/// What a `CGContextRef` points to: a Silica context, y up, drawing into a bitmap.
internal final class ContextObject {

    /// What CoreGraphics keeps in the graphics state that Silica doesn't.
    struct State {
        var fillSpace: ColorSpaceObject.Model = .rgb
        var strokeSpace: ColorSpaceObject.Model = .rgb
        var renderingIntent: Int32 = 0
        var shouldAntialias = true
    }

    let context: GraphicsContext
    let bitmap: BitmapStorage
    let space: Retained?
    var state = State()
    var stack: [State] = []
    /// Not part of the graphics state.
    var allowsAntialiasing = true

    init(bitmap: BitmapStorage, space: OpaquePointer?) {
        let renderer: any Renderer = bitmap.isDirect ? bitmap.renderer : SyncedRenderer(bitmap)
        self.context = GraphicsContext(renderer, origin: .bottomLeft)
        self.bitmap = bitmap
        self.space = space.map(Retained.init)
    }

    func updateAntialiasing() {
        context.shouldAntialias = state.shouldAntialias && allowsAntialiasing
    }
}

private func contextObject(_ reference: SilicaCGContextRef?) -> ContextObject? {
    object(reference, as: ContextObject.self)
}

@c @implementation public func CGContextGetTypeID() -> UInt {
    CoreGraphicsObjects.typeID(of: .context)
}

@c @implementation public func CGContextRetain(_ c: SilicaCGContextRef?) -> SilicaCGContextRef? {
    retain(c)
    return c
}

@c @implementation public func CGContextRelease(_ c: SilicaCGContextRef?) {
    release(c)
}

@c @implementation public func CGContextBeginPage(_ c: SilicaCGContextRef?, _ mediaBox: UnsafePointer<CGRect>?) { }

@c @implementation public func CGContextEndPage(_ c: SilicaCGContextRef?) { }

@c @implementation public func CGContextFlush(_ c: SilicaCGContextRef?) { }

@c @implementation public func CGContextSynchronize(_ c: SilicaCGContextRef?) { }

@c @implementation public func CGContextSynchronizeAttributes(_ c: SilicaCGContextRef?) { }

// MARK: Graphics State

@c @implementation public func CGContextSaveGState(_ c: SilicaCGContextRef?) {
    guard let target = contextObject(c) else { return }
    target.stack.append(target.state)
    target.context.saveGState()
}

@c @implementation public func CGContextRestoreGState(_ c: SilicaCGContextRef?) {
    guard let target = contextObject(c), let saved = target.stack.popLast() else { return }
    target.state = saved
    target.context.restoreGState()
}

// MARK: Transform

@c @implementation public func CGContextScaleCTM(_ c: SilicaCGContextRef?, _ sx: Double, _ sy: Double) {
    contextObject(c)?.context.scaleBy(x: sx, y: sy)
}

@c @implementation public func CGContextTranslateCTM(_ c: SilicaCGContextRef?, _ tx: Double, _ ty: Double) {
    contextObject(c)?.context.translateBy(x: tx, y: ty)
}

@c @implementation public func CGContextRotateCTM(_ c: SilicaCGContextRef?, _ angle: Double) {
    contextObject(c)?.context.rotate(by: angle)
}

@c @implementation public func CGContextConcatCTM(_ c: SilicaCGContextRef?, _ transform: CGAffineTransform) {
    contextObject(c)?.context.concatenate(transform.silica)
}

@c @implementation public func CGContextGetCTM(_ c: SilicaCGContextRef?) -> CGAffineTransform {
    CGAffineTransform(contextObject(c)?.context.ctm ?? .identity)
}

// MARK: Attributes

@c @implementation public func CGContextSetLineWidth(_ c: SilicaCGContextRef?, _ width: Double) {
    contextObject(c)?.context.lineWidth = width
}

@c @implementation public func CGContextSetLineCap(_ c: SilicaCGContextRef?, _ cap: CGLineCap) {
    contextObject(c)?.context.lineCap = LineCap(rawValue: UInt8(clamping: cap)) ?? .butt
}

@c @implementation public func CGContextSetLineJoin(_ c: SilicaCGContextRef?, _ join: CGLineJoin) {
    contextObject(c)?.context.lineJoin = LineJoin(rawValue: UInt8(clamping: join)) ?? .miter
}

@c @implementation public func CGContextSetMiterLimit(_ c: SilicaCGContextRef?, _ limit: Double) {
    contextObject(c)?.context.miterLimit = limit
}

@c @implementation public func CGContextSetLineDash(_ c: SilicaCGContextRef?, _ phase: Double, _ lengths: UnsafePointer<Double>?, _ count: Int) {
    let dash = lengths.map { lengths in (0 ..< max(count, 0)).map { lengths[$0] } } ?? []
    contextObject(c)?.context.setLineDash(phase: phase, lengths: dash)
}

/// Silica flattens curves to fit the device itself.
@c @implementation public func CGContextSetFlatness(_ c: SilicaCGContextRef?, _ flatness: Double) { }

@c @implementation public func CGContextSetAlpha(_ c: SilicaCGContextRef?, _ alpha: Double) {
    contextObject(c)?.context.alpha = min(max(alpha, 0), 1)
}

@c @implementation public func CGContextSetBlendMode(_ c: SilicaCGContextRef?, _ mode: CGBlendMode) {
    contextObject(c)?.context.blendMode = Silica.BlendMode(rawValue: UInt8(clamping: mode)) ?? .normal
}

@c @implementation public func CGContextSetShouldAntialias(_ c: SilicaCGContextRef?, _ shouldAntialias: Bool) {
    guard let target = contextObject(c) else { return }
    target.state.shouldAntialias = shouldAntialias
    target.updateAntialiasing()
}

@c @implementation public func CGContextSetAllowsAntialiasing(_ c: SilicaCGContextRef?, _ allowsAntialiasing: Bool) {
    guard let target = contextObject(c) else { return }
    target.allowsAntialiasing = allowsAntialiasing
    target.updateAntialiasing()
}

/// CoreGraphics' values: default 0, none 1, low 2, high 3, medium 4.
@c @implementation public func CGContextSetInterpolationQuality(_ c: SilicaCGContextRef?, _ quality: CGInterpolationQuality) {
    let qualities: [InterpolationQuality] = [.default, .none, .low, .high, .medium]
    contextObject(c)?.context.interpolationQuality = qualities.indices.contains(Int(quality)) ? qualities[Int(quality)] : .default
}

@c @implementation public func CGContextGetInterpolationQuality(_ c: SilicaCGContextRef?) -> CGInterpolationQuality {
    switch contextObject(c)?.context.interpolationQuality ?? .default {
    case .default: return CGInterpolationQuality(kCGInterpolationDefault)
    case .none: return CGInterpolationQuality(kCGInterpolationNone)
    case .low: return CGInterpolationQuality(kCGInterpolationLow)
    case .medium: return CGInterpolationQuality(kCGInterpolationMedium)
    case .high: return CGInterpolationQuality(kCGInterpolationHigh)
    }
}

@c @implementation public func CGContextSetRenderingIntent(_ c: SilicaCGContextRef?, _ intent: CGColorRenderingIntent) {
    contextObject(c)?.state.renderingIntent = intent
}

// MARK: Paths

@c @implementation public func CGContextBeginPath(_ c: SilicaCGContextRef?) {
    contextObject(c)?.context.beginPath()
}

@c @implementation public func CGContextMoveToPoint(_ c: SilicaCGContextRef?, _ x: Double, _ y: Double) {
    contextObject(c)?.context.move(to: Silica.Point(x: x, y: y))
}

/// Without a current point, a line or curve is ignored, as in CoreGraphics.
private func withCurrentPoint(_ c: SilicaCGContextRef?, _ body: (GraphicsContext) -> Void) {
    guard let target = contextObject(c), target.context.isPathEmpty == false else { return }
    body(target.context)
}

@c @implementation public func CGContextAddLineToPoint(_ c: SilicaCGContextRef?, _ x: Double, _ y: Double) {
    withCurrentPoint(c) { $0.addLine(to: Silica.Point(x: x, y: y)) }
}

@c @implementation public func CGContextAddCurveToPoint(_ c: SilicaCGContextRef?, _ cp1x: Double, _ cp1y: Double,
                                                        _ cp2x: Double, _ cp2y: Double, _ x: Double, _ y: Double) {
    withCurrentPoint(c) {
        $0.addCurve(to: Silica.Point(x: x, y: y), control1: Silica.Point(x: cp1x, y: cp1y), control2: Silica.Point(x: cp2x, y: cp2y))
    }
}

@c @implementation public func CGContextAddQuadCurveToPoint(_ c: SilicaCGContextRef?, _ cpx: Double, _ cpy: Double, _ x: Double, _ y: Double) {
    withCurrentPoint(c) { $0.addQuadCurve(to: Silica.Point(x: x, y: y), control: Silica.Point(x: cpx, y: cpy)) }
}

@c @implementation public func CGContextClosePath(_ c: SilicaCGContextRef?) {
    contextObject(c)?.context.closePath()
}

@c @implementation public func CGContextAddRect(_ c: SilicaCGContextRef?, _ rect: CGRect) {
    contextObject(c)?.context.addRect(rect.silica)
}

@c @implementation public func CGContextAddRects(_ c: SilicaCGContextRef?, _ rects: UnsafePointer<CGRect>?, _ count: Int) {
    guard let rects else { return }
    contextObject(c)?.context.addRects((0 ..< max(count, 0)).map { rects[$0].silica })
}

@c @implementation public func CGContextAddLines(_ c: SilicaCGContextRef?, _ points: UnsafePointer<CGPoint>?, _ count: Int) {
    guard let points, count > 0 else { return }
    contextObject(c)?.context.addLines(between: (0 ..< count).map { points[$0].silica })
}

@c @implementation public func CGContextAddEllipseInRect(_ c: SilicaCGContextRef?, _ rect: CGRect) {
    contextObject(c)?.context.addEllipse(in: rect.silica)
}

@c @implementation public func CGContextAddArc(_ c: SilicaCGContextRef?, _ x: Double, _ y: Double, _ radius: Double,
                                               _ startAngle: Double, _ endAngle: Double, _ clockwise: Int32) {
    contextObject(c)?.context.addArc(center: Silica.Point(x: x, y: y), radius: radius, startAngle: startAngle,
                               endAngle: endAngle, clockwise: clockwise != 0)
}

@c @implementation public func CGContextAddArcToPoint(_ c: SilicaCGContextRef?, _ x1: Double, _ y1: Double,
                                                      _ x2: Double, _ y2: Double, _ radius: Double) {
    withCurrentPoint(c) {
        $0.addArc(tangent1End: Silica.Point(x: x1, y: y1), tangent2End: Silica.Point(x: x2, y: y2), radius: radius)
    }
}

@c @implementation public func CGContextAddPath(_ c: SilicaCGContextRef?, _ path: SilicaCGPathRef?) {
    guard let path = object(path, as: PathObject.self) else { return }
    contextObject(c)?.context.addPath(path.path)
}

@c @implementation public func CGContextCopyPath(_ c: SilicaCGContextRef?) -> SilicaCGPathRef? {
    guard let target = contextObject(c) else { return nil }
    return makePathReference(target.context.path)
}

@c @implementation public func CGContextIsPathEmpty(_ c: SilicaCGContextRef?) -> Bool {
    contextObject(c)?.context.isPathEmpty ?? true
}

@c @implementation public func CGContextGetPathCurrentPoint(_ c: SilicaCGContextRef?) -> CGPoint {
    guard let point = contextObject(c)?.context.currentPoint else { return CGPointZero }
    return CGPoint(point)
}

@c @implementation public func CGContextGetPathBoundingBox(_ c: SilicaCGContextRef?) -> CGRect {
    guard let target = contextObject(c), target.context.isPathEmpty == false else { return CGRectNull }
    return CGRect(target.context.path.controlPointBounds)
}

/// Whether the point is inside the current path filled with the mode's rule.
/// The stroked area isn't tested.
@c @implementation public func CGContextPathContainsPoint(_ c: SilicaCGContextRef?, _ point: CGPoint, _ mode: CGPathDrawingMode) -> Bool {
    guard let target = contextObject(c) else { return false }
    let evenOdd = mode == CGPathDrawingMode(kCGPathEOFill) || mode == CGPathDrawingMode(kCGPathEOFillStroke)
    return target.context.pathContains(point.silica, using: evenOdd ? .evenOdd : .winding)
}

// MARK: Painting

@c @implementation public func CGContextDrawPath(_ c: SilicaCGContextRef?, _ mode: CGPathDrawingMode) {
    guard let target = contextObject(c), let drawing = Silica.DrawingMode(rawValue: UInt8(clamping: mode)) else { return }
    target.context.drawPath(using: drawing)
}

@c @implementation public func CGContextFillPath(_ c: SilicaCGContextRef?) {
    contextObject(c)?.context.fillPath(using: .winding)
}

@c @implementation public func CGContextEOFillPath(_ c: SilicaCGContextRef?) {
    contextObject(c)?.context.fillPath(using: .evenOdd)
}

@c @implementation public func CGContextStrokePath(_ c: SilicaCGContextRef?) {
    contextObject(c)?.context.strokePath()
}

@c @implementation public func CGContextFillRect(_ c: SilicaCGContextRef?, _ rect: CGRect) {
    contextObject(c)?.context.fill(rect.silica)
}

@c @implementation public func CGContextFillRects(_ c: SilicaCGContextRef?, _ rects: UnsafePointer<CGRect>?, _ count: Int) {
    guard let rects else { return }
    contextObject(c)?.context.fill((0 ..< max(count, 0)).map { rects[$0].silica })
}

@c @implementation public func CGContextStrokeRect(_ c: SilicaCGContextRef?, _ rect: CGRect) {
    contextObject(c)?.context.stroke(rect.silica)
}

@c @implementation public func CGContextStrokeRectWithWidth(_ c: SilicaCGContextRef?, _ rect: CGRect, _ width: Double) {
    contextObject(c)?.context.stroke(rect.silica, width: width)
}

@c @implementation public func CGContextClearRect(_ c: SilicaCGContextRef?, _ rect: CGRect) {
    contextObject(c)?.context.clear(rect.silica)
}

@c @implementation public func CGContextFillEllipseInRect(_ c: SilicaCGContextRef?, _ rect: CGRect) {
    contextObject(c)?.context.fillEllipse(in: rect.silica)
}

@c @implementation public func CGContextStrokeEllipseInRect(_ c: SilicaCGContextRef?, _ rect: CGRect) {
    contextObject(c)?.context.strokeEllipse(in: rect.silica)
}

@c @implementation public func CGContextStrokeLineSegments(_ c: SilicaCGContextRef?, _ points: UnsafePointer<CGPoint>?, _ count: Int) {
    guard let points else { return }
    contextObject(c)?.context.strokeLineSegments(between: (0 ..< max(count, 0)).map { points[$0].silica })
}

// MARK: Clipping

@c @implementation public func CGContextClip(_ c: SilicaCGContextRef?) {
    contextObject(c)?.context.clip(using: .winding)
}

@c @implementation public func CGContextEOClip(_ c: SilicaCGContextRef?) {
    contextObject(c)?.context.clip(using: .evenOdd)
}

@c @implementation public func CGContextClipToRect(_ c: SilicaCGContextRef?, _ rect: CGRect) {
    contextObject(c)?.context.clip(to: rect.silica)
}

@c @implementation public func CGContextClipToRects(_ c: SilicaCGContextRef?, _ rects: UnsafePointer<CGRect>?, _ count: Int) {
    guard let rects else { return }
    contextObject(c)?.context.clip(to: (0 ..< max(count, 0)).map { rects[$0].silica })
}

@c @implementation public func CGContextGetClipBoundingBox(_ c: SilicaCGContextRef?) -> CGRect {
    guard let target = contextObject(c) else { return CGRectNull }
    let bounds = target.context.clipBoundingBox
    return bounds.isNull ? CGRectNull : CGRect(bounds)
}

// MARK: Colors

@c @implementation public func CGContextSetFillColorWithColor(_ c: SilicaCGContextRef?, _ color: SilicaCGColorRef?) {
    guard let target = contextObject(c), let color = object(color, as: ColorObject.self) else { return }
    target.state.fillSpace = color.colorSpace.model
    target.context.fillColor = color.silica
}

@c @implementation public func CGContextSetStrokeColorWithColor(_ c: SilicaCGContextRef?, _ color: SilicaCGColorRef?) {
    guard let target = contextObject(c), let color = object(color, as: ColorObject.self) else { return }
    target.state.strokeSpace = color.colorSpace.model
    target.context.strokeColor = color.silica
}

/// Sets the space, and the color to the space's black.
@c @implementation public func CGContextSetFillColorSpace(_ c: SilicaCGContextRef?, _ space: SilicaCGColorSpaceRef?) {
    guard let target = contextObject(c), let space = object(space, as: ColorSpaceObject.self) else { return }
    target.state.fillSpace = space.model
    target.context.fillColor = .black
}

@c @implementation public func CGContextSetStrokeColorSpace(_ c: SilicaCGContextRef?, _ space: SilicaCGColorSpaceRef?) {
    guard let target = contextObject(c), let space = object(space, as: ColorSpaceObject.self) else { return }
    target.state.strokeSpace = space.model
    target.context.strokeColor = .black
}

private func color(_ components: UnsafePointer<Double>, in model: ColorSpaceObject.Model) -> Silica.Color {
    let space = ColorSpaceObject(model: model)
    let values = (0 ..< space.numberOfComponents + 1).map { components[$0] }
    return space.color(Array(values.dropLast()), alpha: values.last!)
}

@c @implementation public func CGContextSetFillColor(_ c: SilicaCGContextRef?, _ components: UnsafePointer<Double>?) {
    guard let target = contextObject(c), let components else { return }
    target.context.fillColor = color(components, in: target.state.fillSpace)
}

@c @implementation public func CGContextSetStrokeColor(_ c: SilicaCGContextRef?, _ components: UnsafePointer<Double>?) {
    guard let target = contextObject(c), let components else { return }
    target.context.strokeColor = color(components, in: target.state.strokeSpace)
}

@c @implementation public func CGContextSetGrayFillColor(_ c: SilicaCGContextRef?, _ gray: Double, _ alpha: Double) {
    guard let target = contextObject(c) else { return }
    target.state.fillSpace = .gray
    target.context.fillColor = Silica.Color(white: gray, alpha: alpha)
}

@c @implementation public func CGContextSetGrayStrokeColor(_ c: SilicaCGContextRef?, _ gray: Double, _ alpha: Double) {
    guard let target = contextObject(c) else { return }
    target.state.strokeSpace = .gray
    target.context.strokeColor = Silica.Color(white: gray, alpha: alpha)
}

@c @implementation public func CGContextSetRGBFillColor(_ c: SilicaCGContextRef?, _ red: Double, _ green: Double, _ blue: Double, _ alpha: Double) {
    guard let target = contextObject(c) else { return }
    target.state.fillSpace = .rgb
    target.context.fillColor = Silica.Color(red: red, green: green, blue: blue, alpha: alpha)
}

@c @implementation public func CGContextSetRGBStrokeColor(_ c: SilicaCGContextRef?, _ red: Double, _ green: Double, _ blue: Double, _ alpha: Double) {
    guard let target = contextObject(c) else { return }
    target.state.strokeSpace = .rgb
    target.context.strokeColor = Silica.Color(red: red, green: green, blue: blue, alpha: alpha)
}

// MARK: Shadows

/// A shadow in black at a third's opacity, as CoreGraphics' default.
@c @implementation public func CGContextSetShadow(_ c: SilicaCGContextRef?, _ offset: CGSize, _ blur: Double) {
    contextObject(c)?.context.setShadow(offset: offset.silica, blur: blur)
}

/// No shadow with a NULL color.
@c @implementation public func CGContextSetShadowWithColor(_ c: SilicaCGContextRef?, _ offset: CGSize, _ blur: Double, _ color: SilicaCGColorRef?) {
    guard let target = contextObject(c) else { return }
    guard let color = object(color, as: ColorObject.self) else {
        target.context.shadow = nil
        return
    }
    target.context.setShadow(offset: offset.silica, blur: blur, color: color.silica)
}

// MARK: Gradients

private func gradientOptions(_ options: CGGradientDrawingOptions) -> GradientOptions {
    var result: GradientOptions = []
    if options & CGGradientDrawingOptions(kCGGradientDrawsBeforeStartLocation) != 0 { result.insert(.drawsBeforeStartLocation) }
    if options & CGGradientDrawingOptions(kCGGradientDrawsAfterEndLocation) != 0 { result.insert(.drawsAfterEndLocation) }
    return result
}

@c @implementation public func CGContextDrawLinearGradient(_ c: SilicaCGContextRef?, _ gradient: SilicaCGGradientRef?,
                                                           _ startPoint: CGPoint, _ endPoint: CGPoint, _ options: CGGradientDrawingOptions) {
    guard let target = contextObject(c), let gradient = object(gradient, as: GradientObject.self) else { return }
    target.context.drawLinearGradient(gradient.gradient, start: startPoint.silica, end: endPoint.silica, options: gradientOptions(options))
}

@c @implementation public func CGContextDrawRadialGradient(_ c: SilicaCGContextRef?, _ gradient: SilicaCGGradientRef?,
                                                           _ startCenter: CGPoint, _ startRadius: Double,
                                                           _ endCenter: CGPoint, _ endRadius: Double, _ options: CGGradientDrawingOptions) {
    guard let target = contextObject(c), let gradient = object(gradient, as: GradientObject.self) else { return }
    target.context.drawRadialGradient(gradient.gradient, startCenter: startCenter.silica, startRadius: startRadius,
                                      endCenter: endCenter.silica, endRadius: endRadius, options: gradientOptions(options))
}

// MARK: Transparency Layers

@c @implementation public func CGContextBeginTransparencyLayer(_ c: SilicaCGContextRef?, _ auxiliaryInfo: UnsafeRawPointer?) {
    contextObject(c)?.context.beginTransparencyLayer()
}

@c @implementation public func CGContextBeginTransparencyLayerWithRect(_ c: SilicaCGContextRef?, _ rect: CGRect, _ auxInfo: UnsafeRawPointer?) {
    contextObject(c)?.context.beginTransparencyLayer(in: rect.silica)
}

@c @implementation public func CGContextEndTransparencyLayer(_ c: SilicaCGContextRef?) {
    contextObject(c)?.context.endTransparencyLayer()
}

// MARK: Images

@c @implementation public func CGContextDrawImage(_ c: SilicaCGContextRef?, _ rect: CGRect, _ image: SilicaCGImageRef?) {
    guard let target = contextObject(c), let image = object(image, as: ImageObject.self) else { return }
    target.context.draw(image.silica, in: rect.silica)
}

// MARK: Device Space

/// From user space to device space: a bitmap's pixels, from its top left.
private func deviceTransform(_ target: ContextObject) -> Silica.AffineTransform {
    target.context.ctm.concatenating(Silica.AffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: Double(target.bitmap.height)))
}

@c @implementation public func CGContextConvertPointToDeviceSpace(_ c: SilicaCGContextRef?, _ point: CGPoint) -> CGPoint {
    guard let target = contextObject(c) else { return point }
    return CGPoint(point.silica.applying(deviceTransform(target)))
}

@c @implementation public func CGContextConvertPointToUserSpace(_ c: SilicaCGContextRef?, _ point: CGPoint) -> CGPoint {
    guard let target = contextObject(c) else { return point }
    return CGPoint(point.silica.applying(deviceTransform(target).inverted()))
}

@c @implementation public func CGContextConvertSizeToDeviceSpace(_ c: SilicaCGContextRef?, _ size: CGSize) -> CGSize {
    guard let target = contextObject(c) else { return size }
    return CGSize(size.silica.applying(deviceTransform(target)))
}

@c @implementation public func CGContextConvertSizeToUserSpace(_ c: SilicaCGContextRef?, _ size: CGSize) -> CGSize {
    guard let target = contextObject(c) else { return size }
    return CGSize(size.silica.applying(deviceTransform(target).inverted()))
}

@c @implementation public func CGContextConvertRectToDeviceSpace(_ c: SilicaCGContextRef?, _ rect: CGRect) -> CGRect {
    guard let target = contextObject(c) else { return rect }
    return CGRect(rect.silica.applying(deviceTransform(target)))
}

@c @implementation public func CGContextConvertRectToUserSpace(_ c: SilicaCGContextRef?, _ rect: CGRect) -> CGRect {
    guard let target = contextObject(c) else { return rect }
    return CGRect(rect.silica.applying(deviceTransform(target).inverted()))
}

// MARK: - Bitmap Contexts

private func makeBitmapContext(_ data: UnsafeMutableRawPointer?, _ width: Int, _ height: Int, _ bitsPerComponent: Int,
                               _ bytesPerRow: Int, _ space: SilicaCGColorSpaceRef?, _ bitmapInfo: UInt32,
                               _ release: ((UnsafeMutableRawPointer) -> Void)?) -> SilicaCGContextRef? {
    guard width > 0, height > 0, width < 1 << 15, height < 1 << 15 else { return nil }
    let model = object(space, as: ColorSpaceObject.self)?.model
    let alphaInfo = bitmapInfo & 0x1F
    // the bits a pixel takes: four bytes of RGB, a byte of gray, or a byte of alpha
    let bitsPerPixel: Int
    switch (model, alphaInfo) {
    case (_, 7): bitsPerPixel = 8
    case (.rgb?, 1), (.rgb?, 2), (.rgb?, 5), (.rgb?, 6): bitsPerPixel = 32
    case (.gray?, 0): bitsPerPixel = 8
    default: return nil
    }
    guard let format = PixelFormat(bitsPerComponent: bitsPerComponent, bitsPerPixel: bitsPerPixel,
                                   model: alphaInfo == 7 ? nil : model, bitmapInfo: bitmapInfo) else { return nil }
    let minimumRow = width * format.bytesPerPixel
    // rows of their own memory are a multiple of 32 bytes, as CoreGraphics makes them
    let rowBytes = bytesPerRow == 0 ? (minimumRow + 31) & ~31 : bytesPerRow
    guard rowBytes >= minimumRow else { return nil }
    let memory: UnsafeMutableRawPointer
    let onRelease: () -> Void
    if let data {
        memory = data
        onRelease = { release?(data) }
    } else {
        guard let allocated = calloc(rowBytes, height) else { return nil }
        memory = allocated
        onRelease = { free(allocated) }
    }
    guard let storage = BitmapStorage(width: width, height: height, bytesPerRow: rowBytes, format: format,
                                      data: memory, onRelease: onRelease) else {
        onRelease()
        return nil
    }
    return makeReference(ContextObject(bitmap: storage, space: space))
}

@c @implementation public func CGBitmapContextCreate(_ data: UnsafeMutableRawPointer?, _ width: Int, _ height: Int,
                                                     _ bitsPerComponent: Int, _ bytesPerRow: Int,
                                                     _ space: SilicaCGColorSpaceRef?, _ bitmapInfo: UInt32) -> SilicaCGContextRef? {
    makeBitmapContext(data, width, height, bitsPerComponent, bytesPerRow, space, bitmapInfo, nil)
}

@c @implementation public func CGBitmapContextCreateWithData(_ data: UnsafeMutableRawPointer?, _ width: Int, _ height: Int,
                                                             _ bitsPerComponent: Int, _ bytesPerRow: Int,
                                                             _ space: SilicaCGColorSpaceRef?, _ bitmapInfo: UInt32,
                                                             _ releaseCallback: CGBitmapContextReleaseDataCallback?,
                                                             _ releaseInfo: UnsafeMutableRawPointer?) -> SilicaCGContextRef? {
    makeBitmapContext(data, width, height, bitsPerComponent, bytesPerRow, space, bitmapInfo) { memory in
        releaseCallback?(releaseInfo, memory)
    }
}

private func bitmap(_ c: SilicaCGContextRef?) -> BitmapStorage? {
    contextObject(c)?.bitmap
}

@c @implementation public func CGBitmapContextGetData(_ context: SilicaCGContextRef?) -> UnsafeMutableRawPointer? {
    guard let storage = bitmap(context) else { return nil }
    if storage.isDirect { storage.surface.flush() }
    return storage.data
}

@c @implementation public func CGBitmapContextGetWidth(_ context: SilicaCGContextRef?) -> Int {
    bitmap(context)?.width ?? 0
}

@c @implementation public func CGBitmapContextGetHeight(_ context: SilicaCGContextRef?) -> Int {
    bitmap(context)?.height ?? 0
}

@c @implementation public func CGBitmapContextGetBitsPerComponent(_ context: SilicaCGContextRef?) -> Int {
    bitmap(context) == nil ? 0 : 8
}

@c @implementation public func CGBitmapContextGetBitsPerPixel(_ context: SilicaCGContextRef?) -> Int {
    bitmap(context)?.format.bitsPerPixel ?? 0
}

@c @implementation public func CGBitmapContextGetBytesPerRow(_ context: SilicaCGContextRef?) -> Int {
    bitmap(context)?.bytesPerRow ?? 0
}

@c @implementation public func CGBitmapContextGetColorSpace(_ context: SilicaCGContextRef?) -> SilicaCGColorSpaceRef? {
    contextObject(context)?.space?.reference
}

@c @implementation public func CGBitmapContextGetAlphaInfo(_ context: SilicaCGContextRef?) -> CGImageAlphaInfo {
    bitmap(context)?.format.alphaInfo ?? 0
}

@c @implementation public func CGBitmapContextGetBitmapInfo(_ context: SilicaCGContextRef?) -> CGBitmapInfo {
    bitmap(context)?.format.bitmapInfo ?? 0
}

@c @implementation public func CGBitmapContextCreateImage(_ context: SilicaCGContextRef?) -> SilicaCGImageRef? {
    guard let target = contextObject(context) else { return nil }
    let storage = target.bitmap
    return makeReference(ImageObject(width: storage.width, height: storage.height, bitsPerComponent: 8,
                                     bytesPerRow: storage.bytesPerRow, format: storage.format,
                                     space: target.space?.reference, data: storage.snapshot()))
}

#endif
