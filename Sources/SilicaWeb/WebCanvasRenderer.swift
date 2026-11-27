//
//  WebCanvasRenderer.swift
//  SilicaWeb
//
//  Created by Alsey Coleman Miller on 7/13/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

#if (!SWIFT_PACKAGE || Web) && canImport(JavaScriptKit)

#if !canImport(Darwin) && canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif

import JavaScriptKit
import Silica

/// A renderer drawing with the Web Canvas API (`CanvasRenderingContext2D`) on
/// an `HTMLCanvasElement` or an `OffscreenCanvas`, bridged through
/// JavaScriptKit. Compatible with Embedded Swift.
///
/// The canvas is already y-down with its origin at the top left, so no flip
/// is needed: the base transform is a scale of `scale` pixels per point.
///
/// The canvas keeps the whole graphics state (the transform, the clip, the
/// colors, the stroke style, the alpha, the blend mode, the shadow and image
/// smoothing), so `saveState()` and `restoreState()` are `save()` and
/// `restore()`. A copy of the state is kept here as well, to set up the
/// canvases of transparency layers.
///
/// Where the canvas differs from the `Renderer` contract:
///
/// - Shape antialiasing can't be turned off: `setShouldAntialias(_:)` only
///   controls image smoothing (`imageSmoothingEnabled`).
/// - `BlendMode.clear` and `.plusDarker` have no canvas equivalent and draw
///   as `.normal`. The Porter-Duff modes the canvas does have (`copy`,
///   `sourceIn`, `sourceOut`, `destinationIn`, `destinationAtop`) also clear
///   what's outside the shape drawn, within the clip, as the canvas defines them.
/// - Canvas gradients always extend past their ends. An unextended end of a
///   linear gradient is cut off exactly. A radial gradient is cut off when
///   one circle lies inside the other; otherwise it extends at both ends.
/// - Glyphs are Unicode scalar values (see `WebFontHandle`), drawn with
///   `fillText` and `strokeText`.
public final class WebCanvasRenderer: Renderer {

    // MARK: - Properties

    public let size: Size

    /// Device pixels per point.
    public let scale: Double

    /// The canvas drawn on (`HTMLCanvasElement` or `OffscreenCanvas`).
    public let canvas: JSObject

    /// The 2D rendering context of `canvas`.
    public let context: JSObject

    // MARK: - Private Properties

    private var state = State()

    /// States saved by `saveState()` and `beginTransparencyLayer(in:)`.
    private var stack: [State] = []

    /// The transparency layers begun, innermost last. Drawing goes to the
    /// innermost layer's context.
    private var layers: [Layer] = []

    /// The 2D context drawing goes to.
    private var target: JSObject { layers.last?.context ?? context }

    // MARK: - Initialization

    /// A renderer drawing on a canvas (`HTMLCanvasElement` or `OffscreenCanvas`),
    /// `scale` pixels per point.
    ///
    /// The canvas' 2D context is reset to the renderer's initial state, with
    /// the transform a scale of `scale`.
    ///
    /// - Parameter size: The size of the drawing destination in points;
    ///   defaults to the canvas' pixel dimensions divided by `scale`.
    public init(canvas: JSObject, size: Size? = nil, scale: Double = 1) throws(SilicaError) {
        guard scale > 0, scale.isFinite,
              let context = canvas.getContext!("2d").object
            else { throw SilicaError.invalidContext }
        self.canvas = canvas
        self.context = context
        self.scale = scale
        self.size = size ?? Size(width: (canvas.width.number ?? 0) / scale,
                                 height: (canvas.height.number ?? 0) / scale)
        state.ctm = Silica.AffineTransform(scaleX: scale, y: scale)
        apply(state, to: context)
        WebBackend.registerIfNeeded()
    }

    /// A bitmap `size` points across, `scale` pixels per point, on an
    /// `OffscreenCanvas` (or a detached `HTMLCanvasElement` where
    /// `OffscreenCanvas` is unavailable).
    public convenience init(bitmap size: Size, scale: Double = 1) throws(SilicaError) {
        let width = (size.width * scale).rounded(.up)
        let height = (size.height * scale).rounded(.up)
        guard width > 0, height > 0, width.isFinite, height.isFinite
            else { throw SilicaError.invalidContext }
        guard let canvas = WebCanvasRenderer.makeCanvas(width: Int(width), height: Int(height))
            else { throw SilicaError.noMemory }
        try self.init(canvas: canvas, size: size, scale: scale)
    }

    /// A canvas of `width` by `height` pixels: an `OffscreenCanvas`, or a
    /// detached `HTMLCanvasElement` where `OffscreenCanvas` is unavailable.
    internal static func makeCanvas(width: Int, height: Int) -> JSObject? {
        if let offscreenCanvas = JSObject.global.OffscreenCanvas.function {
            return offscreenCanvas.new(width, height)
        }
        // fall back to a detached canvas element
        let document = JSObject.global.document
        guard document.isUndefined == false, document.isNull == false,
              let canvas = document.createElement("canvas").object
            else { return nil }
        canvas.width = .number(Double(width))
        canvas.height = .number(Double(height))
        return canvas
    }

    // MARK: - Graphics State

    public func saveState() {
        stack.append(state)
        _ = target.save!()
    }

    public func restoreState() {
        // a state saved outside the innermost layer is restored when it ends
        let minimum = layers.last.map { $0.depth + 1 } ?? 0
        guard stack.count > minimum, let saved = stack.popLast() else { return }
        state = saved
        _ = target.restore!()
    }

    public func concatenate(_ transform: Silica.AffineTransform) {
        state.ctm = transform.concatenating(state.ctm)
        _ = target.transform!(transform.a, transform.b, transform.c, transform.d, transform.tx, transform.ty)
    }

    public func setAlpha(_ alpha: Double) {
        state.alpha = alpha
        target.globalAlpha = .number(alpha)
    }

    public func setBlendMode(_ mode: BlendMode) {
        state.blendMode = mode
        target.globalCompositeOperation = .string(mode.canvasCompositeOperation)
    }

    /// Controls image smoothing only: the canvas always antialiases shapes.
    public func setShouldAntialias(_ shouldAntialias: Bool) {
        state.shouldAntialias = shouldAntialias
        target.imageSmoothingEnabled = .boolean(shouldAntialias)
    }

    public func setFillColor(_ color: Color) {
        state.fillColor = color
        target.fillStyle = .string(cssColor(color))
    }

    public func setStrokeColor(_ color: Color) {
        state.strokeColor = color
        target.strokeStyle = .string(cssColor(color))
    }

    public func setStrokeStyle(_ style: StrokeStyle) {
        state.strokeStyle = style
        applyStrokeStyle(style, to: target)
    }

    public func setShadow(_ shadow: Shadow?) {
        state.shadow = shadow
        applyShadow(shadow, to: target)
    }

    // MARK: - Painting

    public func fill(_ path: Silica.Path, rule: FillRule) {
        let context = target
        setPath(path, on: context)
        _ = context.fill!(rule.canvasValue)
    }

    public func stroke(_ path: Silica.Path) {
        let context = target
        setPath(path, on: context)
        _ = context.stroke!()
    }

    public func clip(to path: Silica.Path, rule: FillRule) {
        let context = target
        setPath(path, on: context)
        _ = context.clip!(rule.canvasValue)
    }

    public func clear(_ rect: Rect) {
        // `clearRect` is transformed and clipped, and ignores the alpha,
        // shadow and composite operation
        _ = target.clearRect!(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height)
    }

    public func draw(_ image: Silica.Image, in rect: Rect) {
        guard image.width > 0, image.height > 0, rect.isEmpty == false,
              let imageCanvas = image.makeWebCanvas()
            else { return }
        // the canvas draws images upright in its y-down space
        let rect = rect.standardized
        _ = target.drawImage!(imageCanvas, rect.origin.x, rect.origin.y, rect.size.width, rect.size.height)
    }

    /// Paints a gradient along a line, within the clip. An end the options
    /// don't extend is cut off by the line through it, across the gradient.
    public func drawLinearGradient(_ gradient: Gradient, start: Point, end: Point, options: GradientOptions) {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = (dx * dx + dy * dy).squareRoot()
        guard length > 0, length.isFinite, let bounds = userBounds(),
              let canvasGradient = target.createLinearGradient!(start.x, start.y, end.x, end.y).object
            else { return }
        addStops(gradient, to: canvasGradient)
        // the band between the lines across the gradient through its ends,
        // widened past the canvas at an end the options extend
        let along = (x: dx / length, y: dy / length)
        let across = (x: -along.y, y: along.x)
        let reach = bounds.width + bounds.height + abs(start.x - bounds.midX) + abs(start.y - bounds.midY) + length
        let from = options.contains(.drawsBeforeStartLocation) ? -reach : 0
        let to = options.contains(.drawsAfterEndLocation) ? length + reach : length
        func corner(_ distance: Double, _ side: Double) -> Point {
            Point(x: start.x + along.x * distance + across.x * side,
                  y: start.y + along.y * distance + across.y * side)
        }
        let corners = [corner(from, reach), corner(to, reach), corner(to, -reach), corner(from, -reach)]
        paint(canvasGradient, rule: .winding) { context in
            _ = context.moveTo!(corners[0].x, corners[0].y)
            for point in corners.dropFirst() {
                _ = context.lineTo!(point.x, point.y)
            }
            _ = context.closePath!()
        }
    }

    /// Paints a gradient between two circles, within the clip. When one circle
    /// lies inside the other, an end the options don't extend is cut off;
    /// otherwise the gradient extends at both ends, as the canvas draws it.
    public func drawRadialGradient(_ gradient: Gradient, startCenter: Point, startRadius: Double,
                                   endCenter: Point, endRadius: Double, options: GradientOptions) {
        // the canvas throws for negative radii
        guard startRadius >= 0, endRadius >= 0, startRadius.isFinite, endRadius.isFinite,
              let bounds = userBounds(),
              let canvasGradient = target.createRadialGradient!(startCenter.x, startCenter.y, startRadius,
                                                                 endCenter.x, endCenter.y, endRadius).object
            else { return }
        addStops(gradient, to: canvasGradient)
        let before = options.contains(.drawsBeforeStartLocation)
        let after = options.contains(.drawsAfterEndLocation)
        let dx = endCenter.x - startCenter.x
        let dy = endCenter.y - startCenter.y
        let distance = (dx * dx + dy * dy).squareRoot()
        // the circle outside, the circle inside, and whether each extends
        let nested: (outer: (center: Point, radius: Double, extends: Bool),
                     inner: (center: Point, radius: Double, extends: Bool))?
        if before && after {
            nested = nil
        } else if distance + startRadius <= endRadius {
            nested = ((endCenter, endRadius, after), (startCenter, startRadius, before))
        } else if distance + endRadius <= startRadius {
            nested = ((startCenter, startRadius, before), (endCenter, endRadius, after))
        } else {
            nested = nil
        }
        paint(canvasGradient, rule: .evenOdd) { context in
            guard let nested else {
                addRect(bounds, on: context)
                return
            }
            if nested.outer.extends {
                addRect(bounds, on: context)
            } else {
                addCircle(center: nested.outer.center, radius: nested.outer.radius, on: context)
            }
            // even-odd cuts the inner circle out
            if nested.inner.extends == false, nested.inner.radius > 0 {
                addCircle(center: nested.inner.center, radius: nested.inner.radius, on: context)
            }
        }
    }

    public func beginTransparencyLayer(in rect: Rect?) {
        let pixels = pixelSize
        let layer: Layer
        if let layerCanvas = WebCanvasRenderer.makeCanvas(width: max(pixels.width, 1), height: max(pixels.height, 1)),
           let layerContext = layerCanvas.getContext!("2d").object {
            layer = Layer(canvas: layerCanvas, context: layerContext, depth: stack.count)
        } else {
            // without a canvas, draw straight on, with the state reset inside
            let context = target
            _ = context.save!()
            layer = Layer(canvas: nil, context: context, depth: stack.count)
        }
        stack.append(state)
        layers.append(layer)
        state.alpha = 1
        state.shadow = nil
        state.blendMode = .normal
        apply(state, to: layer.context)
        if let rect {
            _ = layer.context.beginPath!()
            addRect(rect, on: layer.context)
            _ = layer.context.clip!()
        }
    }

    public func endTransparencyLayer() {
        guard let layer = layers.last else { return }
        // states saved inside the layer and not restored
        while stack.count > layer.depth + 1 {
            stack.removeLast()
            _ = layer.context.restore!()
        }
        layers.removeLast()
        if let saved = stack.popLast() {
            state = saved
        }
        guard let layerCanvas = layer.canvas else {
            _ = layer.context.restore!()
            return
        }
        // the parent context is as it was when the layer began, so it
        // composites with the alpha, shadow and blend mode then; the layer
        // lines up with the canvas in device pixels
        let context = target
        _ = context.save!()
        _ = context.setTransform!(1, 0, 0, 1, 0, 0)
        _ = context.drawImage!(layerCanvas, 0, 0)
        _ = context.restore!()
    }

    /// Draws glyphs, which are Unicode scalar values, with `fillText` and
    /// `strokeText`. The text matrix's linear part transforms each glyph
    /// around its baseline origin.
    public func draw(_ glyphs: [Glyph], at positions: [Point], font: Silica.Font, textMatrix: Silica.AffineTransform, mode: TextDrawingMode) {
        guard let face = font.face as? WebFontHandle, font.size > 0, glyphs.isEmpty == false else { return }
        let fills: Bool
        let strokes: Bool
        switch mode {
        case .fill, .fillClip:
            fills = true; strokes = false
        case .stroke, .strokeClip:
            fills = false; strokes = true
        case .fillStroke, .fillStrokeClip:
            fills = true; strokes = true
        case .invisible, .clip:
            return
        }
        let context = target
        _ = context.save!()
        context.font = .string(face.cssFont(size: font.size))
        context.textBaseline = .string("alphabetic")
        context.textAlign = .string("left")
        let linear = textMatrix.linear
        for (glyph, position) in zip(glyphs, positions) {
            let text = face.text(for: glyph)
            guard text.isEmpty == false else { continue }
            // the glyph's text space: the linear part, moved to its origin
            let matrix = Silica.AffineTransform(a: linear.a, b: linear.b, c: linear.c, d: linear.d,
                                                tx: position.x, ty: position.y).concatenating(state.ctm)
            setTransform(matrix, on: context)
            if fills {
                _ = context.fillText!(text, 0, 0)
            }
            if strokes {
                _ = context.strokeText!(text, 0, 0)
            }
        }
        _ = context.restore!()
    }

    // MARK: - Document

    /// Does nothing: a canvas isn't page-based.
    public func beginPage() { }

    /// Does nothing: a canvas isn't page-based.
    public func endPage() { }

    /// Does nothing: the canvas shows what's drawn as it's drawn.
    public func finish() throws(SilicaError) { }

    /// What's drawn on the canvas, read back with `getImageData`.
    public func makeImage() -> Silica.Image? {
        let pixels = pixelSize
        guard pixels.width > 0, pixels.height > 0,
              let imageData = context.getImageData!(0, 0, pixels.width, pixels.height).object
            else { return nil }
        return Silica.Image(imageData, scale: scale)
    }
}

// MARK: - Private

private extension WebCanvasRenderer {

    struct State {
        /// From user space to device pixels, with the base scale.
        var ctm: Silica.AffineTransform = .identity
        var fillColor: Color = .black
        var strokeColor: Color = .black
        var strokeStyle = StrokeStyle()
        var alpha: Double = 1
        var blendMode: BlendMode = .normal
        var shadow: Shadow?
        var shouldAntialias = true
    }

    struct Layer {
        /// The layer's canvas, or nil when it draws straight on its parent.
        let canvas: JSObject?
        let context: JSObject
        /// The number of states saved when the layer began.
        let depth: Int
    }

    /// The canvas' size in pixels.
    var pixelSize: (width: Int, height: Int) {
        func pixels(_ value: JSValue) -> Int {
            guard let number = value.number, number.isFinite, number > 0 else { return 0 }
            return Int(number)
        }
        return (pixels(canvas.width), pixels(canvas.height))
    }

    /// The canvas in user space: the bounds of its pixels under the inverse
    /// transform, or nil when the transform can't be inverted.
    func userBounds() -> Rect? {
        let pixels = pixelSize
        guard let inverse = state.ctm.invertedIfPossible() else { return nil }
        let device = Rect(x: 0, y: 0, width: Double(max(pixels.width, 1)), height: Double(max(pixels.height, 1)))
        return device.applying(inverse)
    }

    /// Sets every attribute of a state on a 2D context.
    func apply(_ state: State, to context: JSObject) {
        setTransform(state.ctm, on: context)
        context.globalAlpha = .number(state.alpha)
        context.globalCompositeOperation = .string(state.blendMode.canvasCompositeOperation)
        context.imageSmoothingEnabled = .boolean(state.shouldAntialias)
        context.fillStyle = .string(cssColor(state.fillColor))
        context.strokeStyle = .string(cssColor(state.strokeColor))
        applyStrokeStyle(state.strokeStyle, to: context)
        applyShadow(state.shadow, to: context)
    }

    func setTransform(_ transform: Silica.AffineTransform, on context: JSObject) {
        _ = context.setTransform!(transform.a, transform.b, transform.c, transform.d, transform.tx, transform.ty)
    }

    /// The canvas ignores a line width or miter limit that isn't positive, and
    /// a dash with a negative length, keeping the value before.
    func applyStrokeStyle(_ style: StrokeStyle, to context: JSObject) {
        context.lineWidth = .number(style.lineWidth)
        context.lineCap = .string(style.lineCap.canvasValue)
        context.lineJoin = .string(style.lineJoin.canvasValue)
        context.miterLimit = .number(style.miterLimit)
        _ = context.setLineDash!(style.dash)
        context.lineDashOffset = .number(style.dashPhase)
    }

    /// The shadow's offset is in base space, y down; the canvas' is in device
    /// pixels, and neither is transformed.
    func applyShadow(_ shadow: Shadow?, to context: JSObject) {
        guard let shadow else {
            context.shadowColor = .string("rgba(0,0,0,0)")
            context.shadowOffsetX = .number(0)
            context.shadowOffsetY = .number(0)
            context.shadowBlur = .number(0)
            return
        }
        context.shadowColor = .string(cssColor(shadow.color))
        context.shadowOffsetX = .number(shadow.offset.width * scale)
        context.shadowOffsetY = .number(shadow.offset.height * scale)
        context.shadowBlur = .number(max(shadow.blur, 0) * scale)
    }

    /// Makes a path the context's current path.
    func setPath(_ path: Silica.Path, on context: JSObject) {
        _ = context.beginPath!()
        for element in path.elements {
            switch element {
            case let .move(point):
                _ = context.moveTo!(point.x, point.y)
            case let .line(point):
                _ = context.lineTo!(point.x, point.y)
            case let .quadCurve(point, control):
                _ = context.quadraticCurveTo!(control.x, control.y, point.x, point.y)
            case let .curve(point, control1, control2):
                _ = context.bezierCurveTo!(control1.x, control1.y, control2.x, control2.y, point.x, point.y)
            case .closeSubpath:
                _ = context.closePath!()
            }
        }
    }

    func addRect(_ rect: Rect, on context: JSObject) {
        _ = context.rect!(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height)
    }

    func addCircle(center: Point, radius: Double, on context: JSObject) {
        _ = context.moveTo!(center.x + radius, center.y)
        _ = context.arc!(center.x, center.y, radius, 0, 2 * Double.pi)
        _ = context.closePath!()
    }

    /// Color stops at locations clamped to 0...1, where the canvas throws
    /// outside. The alpha applies when painting, as `globalAlpha`.
    func addStops(_ gradient: Gradient, to canvasGradient: JSObject) {
        for stop in gradient.stops {
            let location = stop.location.isNaN ? 0 : max(0, min(1, stop.location))
            _ = canvasGradient.addColorStop!(location, cssColor(stop.color))
        }
    }

    /// Fills the path `addPath` adds with a gradient. Gradients cast no
    /// shadow, as with the Cairo backend.
    func paint(_ canvasGradient: JSObject, rule: FillRule, _ addPath: (JSObject) -> Void) {
        let context = target
        _ = context.save!()
        applyShadow(nil, to: context)
        context.fillStyle = .object(canvasGradient)
        _ = context.beginPath!()
        addPath(context)
        _ = context.fill!(rule.canvasValue)
        _ = context.restore!()
    }
}

#endif // canImport(JavaScriptKit)
