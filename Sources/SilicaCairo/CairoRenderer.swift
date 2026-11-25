//
//  CairoRenderer.swift
//  SilicaCairo
//
//  Created by Alsey Coleman Miller on 5/8/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

#if canImport(Cairo)

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

import Cairo
import CCairo
import Foundation
import Silica

/// A renderer drawing with Cairo: into a PDF, a bitmap, or any Cairo surface.
///
/// Cairo keeps the transform, the clip, the stroke style, the blend mode and
/// antialiasing in its own graphics state. The colors, the alpha and the
/// shadow are kept here, since Cairo paints with a single source.
public final class CairoRenderer: Renderer {

    // MARK: - Properties

    public let surface: Cairo.Surface

    public let size: Size

    /// Device pixels per point.
    public let scale: Double

    /// The Cairo context drawn with.
    public let context: Cairo.Context

    private var state = State()

    private var stack: [State] = []

    // MARK: - Initialization

    /// A renderer drawing into a surface `size` points across, `scale` device units per point.
    public init(surface: Cairo.Surface, size: Size, scale: Double = 1) throws(SilicaError) {
        let context = Cairo.Context(surface: surface)
        if let error = CairoError(context.status) {
            throw SilicaError(error)
        }
        // Cairo defaults to a line width of 2
        context.lineWidth = 1
        if scale != 1 {
            context.scale(x: scale, y: scale)
        }
        self.surface = surface
        self.size = size
        self.scale = scale
        self.context = context
        CairoBackend.registerIfNeeded()
    }

    /// A PDF at a file URL, `size` points a page.
    public convenience init(pdf url: URL, size: Size) throws(SilicaError) {
        let surface: Cairo.Surface.PDF
        do {
            surface = try Cairo.Surface.PDF(filename: url.path, width: size.width, height: size.height)
        } catch {
            throw SilicaError(error)
        }
        try self.init(surface: surface, size: size)
    }

    /// A bitmap `size` points across, `scale` pixels per point.
    public convenience init(bitmap size: Size, scale: Double = 1) throws(SilicaError) {
        let surface: Cairo.Surface.Image
        do {
            surface = try Cairo.Surface.Image(format: .argb32,
                                              width: Int(ceil(size.width * scale)),
                                              height: Int(ceil(size.height * scale)))
        } catch {
            throw SilicaError(error)
        }
        try self.init(surface: surface, size: size, scale: scale)
    }

    // MARK: - Graphics State

    public func saveState() {
        context.save()
        stack.append(state)
        state.masks = []
    }

    public func restoreState() {
        guard let saved = stack.popLast() else { return }
        paintMasks()
        context.restore()
        state = saved
    }

    public func concatenate(_ transform: Silica.AffineTransform) {
        context.transform(transform.toCairo())
    }

    public func setAlpha(_ alpha: Double) {
        state.alpha = alpha
    }

    public func setBlendMode(_ mode: BlendMode) {
        context.operator = mode.toCairo()
    }

    public func setShouldAntialias(_ shouldAntialias: Bool) {
        context.antialias = shouldAntialias ? CAIRO_ANTIALIAS_DEFAULT : CAIRO_ANTIALIAS_NONE
    }

    public func setFillColor(_ color: Color) {
        state.fillColor = color
    }

    public func setStrokeColor(_ color: Color) {
        state.strokeColor = color
    }

    public func setStrokeStyle(_ style: StrokeStyle) {
        context.lineWidth = style.lineWidth
        context.lineCap = style.lineCap.toCairo()
        context.lineJoin = style.lineJoin.toCairo()
        context.miterLimit = style.miterLimit
        context.lineDash = (style.dashPhase, style.dash)
    }

    public func setShadow(_ shadow: Shadow?) {
        state.shadow = shadow
    }

    public func setInterpolationQuality(_ quality: InterpolationQuality) {
        state.interpolationQuality = quality
    }

    // MARK: - Painting

    public func fill(_ path: Silica.Path, rule: FillRule) {
        withShadow {
            setPath(path)
            context.fillRule = rule.toCairo()
            context.source = pattern(state.fillColor)
            context.fill()
        }
    }

    public func stroke(_ path: Silica.Path) {
        withShadow {
            setPath(path)
            context.source = pattern(state.strokeColor)
            context.stroke()
        }
    }

    public func clip(to path: Silica.Path, rule: FillRule) {
        setPath(path)
        context.fillRule = rule.toCairo()
        context.clip()
        context.fillRule = CAIRO_FILL_RULE_WINDING
    }

    public func clear(_ rect: Rect) {
        context.save()
        context.newPath()
        addRect(rect)
        context.clip()
        context.operator = CAIRO_OPERATOR_CLEAR
        context.paint()
        context.restore()
    }

    public func draw(_ image: Silica.Image, in rect: Rect) {
        guard image.width > 0, image.height > 0, let surface = try? Cairo.Surface.Image(image)
            else { return }
        draw(surface: surface, width: image.width, height: image.height, in: rect)
    }

    public func drawLinearGradient(_ gradient: Gradient, start: Point, end: Point, options: GradientOptions) {
        let pattern = Pattern(linear: (origin: (start.x, start.y), destination: (end.x, end.y)))
        paint(gradient, with: pattern, options: options)
    }

    public func drawRadialGradient(_ gradient: Gradient, startCenter: Point, startRadius: Double,
                                   endCenter: Point, endRadius: Double, options: GradientOptions) {
        let pattern = Pattern(radial: (start: (center: (startCenter.x, startCenter.y), radius: startRadius),
                                       end: (center: (endCenter.x, endCenter.y), radius: endRadius)))
        paint(gradient, with: pattern, options: options)
    }

    public func beginTransparencyLayer(in rect: Rect?) {
        context.save()
        if let rect {
            context.newPath()
            addRect(rect)
            context.clip()
        }
        let layer = Layer(alpha: state.alpha, shadow: state.shadow, blendMode: context.operator)
        stack.append(state)
        state.layers.append(layer)
        state.alpha = 1
        state.shadow = nil
        state.masks = []
        context.operator = CAIRO_OPERATOR_OVER
        context.pushGroup()
    }

    public func endTransparencyLayer() {
        guard let layer = state.layers.last, let saved = stack.popLast() else { return }
        paintMasks()
        let group = context.popGroup()
        // the group pattern lines up with device space under an identity matrix
        group.matrix = .identity
        context.restore()
        state = saved
        context.save()
        context.matrix = .identity
        context.operator = layer.blendMode
        state.shadow = layer.shadow
        withShadow {
            context.source = group
            context.paint(alpha: layer.alpha)
        }
        state.shadow = saved.shadow
        context.restore()
    }

    public func draw(_ glyphs: [Glyph], at positions: [Point], font: Silica.Font, textMatrix: Silica.AffineTransform, mode: TextDrawingMode) {
        guard let face = font.face as? CairoFontHandle, font.size > 0, glyphs.isEmpty == false else { return }
        var cairoGlyphs = zip(glyphs, positions).map { glyph, position in
            cairo_glyph_t(index: UInt(glyph), x: position.x, y: position.y)
        }
        var fontMatrix = Matrix.identity
        fontMatrix.scale(x: font.size, y: font.size)
        fontMatrix.multiply(a: fontMatrix, b: textMatrix.linear.toCairo())
        context.fontFace = face.scaledFont.face
        context.setFont(matrix: fontMatrix)
        let count = Int32(cairoGlyphs.count)
        withShadow {
            switch mode {
            case .fill, .fillClip:
                context.source = pattern(state.fillColor)
                context.withUnsafePointer { cairo_show_glyphs($0, &cairoGlyphs, count) }
            case .stroke, .strokeClip:
                context.newPath()
                context.withUnsafePointer { cairo_glyph_path($0, &cairoGlyphs, count) }
                context.source = pattern(state.strokeColor)
                context.stroke()
            case .fillStroke, .fillStrokeClip:
                context.newPath()
                context.withUnsafePointer { cairo_glyph_path($0, &cairoGlyphs, count) }
                context.source = pattern(state.fillColor)
                context.fillPreserve()
                context.source = pattern(state.strokeColor)
                context.stroke()
            case .invisible, .clip:
                break
            }
        }
    }

    // MARK: - Document

    public func beginPage() {
        context.copyPage()
    }

    public func endPage() {
        context.showPage()
    }

    public func finish() throws(SilicaError) {
        surface.finish()
        if let error = CairoError(surface.status) {
            throw SilicaError(error)
        }
    }

    public func makeImage() -> Silica.Image? {
        guard let imageSurface = surface as? Cairo.Surface.Image else { return nil }
        return Silica.Image(cairo: imageSurface, scale: scale)
    }
}

// MARK: - Cairo Extras

public extension CairoRenderer {

    /// Draws an ARGB32 surface of `width` by `height` pixels upright into
    /// `rect`, as `draw(_:in:)` draws an image: for callers that keep the
    /// surface, so drawing the same image again converts nothing.
    func draw(surface: Cairo.Surface.Image, width: Int, height: Int, in rect: Rect) {
        let pattern = Pattern(surface: surface)
        var matrix = Matrix.identity
        matrix.translate(x: rect.origin.x, y: rect.origin.y)
        matrix.scale(x: rect.size.width / Double(width), y: rect.size.height / Double(height))
        matrix.invert()
        pattern.matrix = matrix
        pattern.extend = .pad
        let filter: cairo_filter_t
        switch state.interpolationQuality {
        case .none: filter = CAIRO_FILTER_NEAREST
        case .low: filter = CAIRO_FILTER_FAST
        case .default, .medium: filter = CAIRO_FILTER_GOOD
        case .high: filter = CAIRO_FILTER_BEST
        }
        pattern.withUnsafePointer { cairo_pattern_set_filter($0, filter) }
        withShadow {
            context.save()
            context.source = pattern
            context.newPath()
            addRect(rect)
            context.clip()
            context.paint(alpha: state.alpha)
            context.restore()
        }
    }

    /// Clips what's drawn until the graphics state is restored to an
    /// alpha-only surface of `width` by `height` pixels in `rect`, as
    /// CGContextClipToMask does: what's drawn goes to a group, painted through
    /// the mask on restore. Outside the rectangle nothing is drawn. The mask
    /// is drawn into a device-sized surface now, since the transform may change.
    func beginMask(_ mask: Cairo.Surface.Image, width: Int, height: Int, in rect: Rect) {
        guard let device = try? Cairo.Surface.Image(format: .a8,
                                                    width: max(Int(ceil(size.width * scale)), 1),
                                                    height: max(Int(ceil(size.height * scale)), 1))
        else { return }
        let painter = Cairo.Context(surface: device)
        painter.matrix = context.matrix
        let pattern = Pattern(surface: mask)
        var matrix = Matrix.identity
        matrix.translate(x: rect.origin.x, y: rect.origin.y)
        matrix.scale(x: rect.size.width / Double(width), y: rect.size.height / Double(height))
        matrix.invert()
        pattern.matrix = matrix
        pattern.extend = .none
        painter.source = pattern
        painter.addRectangle(x: rect.origin.x, y: rect.origin.y, width: rect.size.width, height: rect.size.height)
        painter.clip()
        painter.paint()
        device.flush()
        context.pushGroup()
        state.masks.append(device)
    }

    /// Flushes drawing to the surface's memory.
    func flush() {
        surface.flush()
    }

    /// Tells Cairo the surface's memory changed outside it.
    func markDirty() {
        surface.withUnsafePointer { cairo_surface_mark_dirty($0) }
    }
}

// MARK: - Private

private extension CairoRenderer {

    struct Layer {
        var alpha: Double
        var shadow: Shadow?
        var blendMode: cairo_operator_t
    }

    struct State {
        var fillColor: Color = .black
        var strokeColor: Color = .black
        var alpha: Double = 1
        var shadow: Shadow?
        var interpolationQuality: InterpolationQuality = .default
        /// The transparency layers begun, innermost last.
        var layers: [Layer] = []
        /// Masks clipped to since the state was saved: each began a group that
        /// restoring paints through it.
        var masks: [Cairo.Surface.Image] = []
    }

    /// A color with the alpha applied.
    func pattern(_ color: Color) -> Cairo.Pattern {
        Pattern(color: color.opacity(state.alpha))
    }

    func addRect(_ rect: Rect) {
        context.addRectangle(x: rect.origin.x, y: rect.origin.y, width: rect.size.width, height: rect.size.height)
    }

    /// Makes a path Cairo's current path.
    func setPath(_ path: Silica.Path) {
        context.newPath()
        var current = Point()
        var subpathStart = Point()
        for element in path.elements {
            switch element {
            case let .move(point):
                context.move(to: (point.x, point.y))
                current = point
                subpathStart = point
            case let .line(point):
                context.line(to: (point.x, point.y))
                current = point
            case let .quadCurve(point, control):
                // the cubic with the same curve
                let control1 = Point(x: current.x + 2 / 3 * (control.x - current.x), y: current.y + 2 / 3 * (control.y - current.y))
                let control2 = Point(x: point.x + 2 / 3 * (control.x - point.x), y: point.y + 2 / 3 * (control.y - point.y))
                context.curve(to: ((control1.x, control1.y), (control2.x, control2.y), (point.x, point.y)))
                current = point
            case let .curve(point, control1, control2):
                context.curve(to: ((control1.x, control1.y), (control2.x, control2.y), (point.x, point.y)))
                current = point
            case .closeSubpath:
                context.closePath()
                current = subpathStart
            }
        }
    }

    func paint(_ gradient: Gradient, with pattern: Cairo.Pattern, options: GradientOptions) {
        for stop in gradient.stops {
            let color = stop.color.opacity(state.alpha)
            pattern.addColorStop(stop.location, red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
        }
        // Cairo extends both ends or neither
        pattern.extend = options.isEmpty ? .none : .pad
        context.source = pattern
        context.paint()
    }

    /// Paints what was drawn since each mask was clipped to, through the mask.
    func paintMasks() {
        for mask in state.masks.reversed() {
            context.popGroupToSource()
            context.save()
            context.matrix = .identity
            context.mask(surface: mask, at: (0, 0))
            context.restore()
        }
        state.masks = []
    }

    /// Draws with the shadow, if there is one: what `body` draws goes to a
    /// group, painted after its silhouette in the shadow color at the offset.
    /// Cairo has no blur, so the shadow is sharp.
    func withShadow(_ body: () -> Void) {
        guard let shadow = state.shadow else {
            body()
            return
        }
        context.pushGroup()
        body()
        let group = context.popGroup()
        group.matrix = .identity
        context.save()
        context.matrix = .identity
        let width = Int(ceil(size.width * scale)), height = Int(ceil(size.height * scale))
        if let silhouette = try? Surface.Image(format: .a8, width: max(width, 1), height: max(height, 1)) {
            let painter = Cairo.Context(surface: silhouette)
            painter.source = group
            painter.paint()
            silhouette.flush()
            context.source = Pattern(color: shadow.color.opacity(state.alpha))
            context.mask(surface: silhouette, at: (shadow.offset.width * scale, shadow.offset.height * scale))
        }
        context.source = group
        context.paint()
        context.restore()
    }
}

// MARK: - Error Mapping

internal extension SilicaError {

    init(_ error: CairoError) {
        switch error {
        case .noMemory: self = .noMemory
        case .invalidRestore: self = .invalidRestore
        case .read: self = .readError
        case .write: self = .writeError
        default: self = .backend(code: Int32(error.rawValue), description: String(describing: error))
        }
    }
}

#endif // canImport(Cairo)
