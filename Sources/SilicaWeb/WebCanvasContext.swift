//
//  WebCanvasContext.swift
//  SilicaWeb
//
//  Created by Alsey Coleman Miller on 7/13/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

#if canImport(JavaScriptKit)

#if canImport(Foundation)
import Foundation
#endif

import JavaScriptKit
import Silica

/// Web Canvas API (`CanvasRenderingContext2D`) backed implementation of `CGContext`,
/// bridged through JavaScriptKit. Compatible with Embedded Swift.
///
/// The web canvas is already a top-left origin, y-down coordinate system, so no
/// base flip is required.
///
/// The current transformation matrix is tracked on the Swift side: path points are
/// transformed into device space at add time (matching Cairo and Quartz semantics)
/// and strokes are rendered under the CTM so pen geometry transforms correctly.
///
/// - Note: The canvas is sized in device pixels; callers that render at a display
///   scale other than 1:1 (e.g. `devicePixelRatio`) should apply it with `scaleBy`.
/// - Note: Shape antialiasing cannot be disabled in the Web Canvas API;
///   `shouldAntialias` only controls image smoothing.
public final class WebCanvasContext: Silica.CGContext {

    // MARK: - Properties

    public let size: CGSize

    /// The web canvas is natively top-left origin, y-down.
    public var isFlipped: Bool { true }

    /// The underlying canvas (`HTMLCanvasElement` or `OffscreenCanvas`).
    public let canvas: JSObject

    /// The underlying 2D rendering context of `canvas`.
    public let context: JSObject

    public var textMatrix = CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0)

    // MARK: - Private Properties

    private var internalState: State = State()

    /// The current path, in device space.
    private var deviceElements = [PathElement]()

    private var deviceCurrentPoint: CGPoint?

    private var deviceSubpathStart: CGPoint?

    /// Transparency layer stack; drawing goes to the top layer's context.
    private var layers = [Layer]()

    /// The 2D context all drawing operations currently target.
    private var target: JSObject { layers.last?.context ?? context }

    // MARK: - Initialization

    /// Wraps an existing canvas (`HTMLCanvasElement` or `OffscreenCanvas`).
    ///
    /// - Parameter size: The size of the drawing surface in points;
    ///   defaults to the canvas' pixel dimensions.
    public init(canvas: JSObject, size: CGSize? = nil) throws(SilicaError) {

        guard let context = canvas.getContext!("2d").object
            else { throw SilicaError.invalidContext }

        self.canvas = canvas
        self.context = context
        self.size = size ?? CGSize(width: canvas.width.number ?? 0,
                                   height: canvas.height.number ?? 0)

        WebBackend.registerIfNeeded()
    }

    /// Creates a bitmap drawing destination of the specified size, backed by an
    /// `OffscreenCanvas` (or an `HTMLCanvasElement` where `OffscreenCanvas` is unavailable).
    public convenience init(size: CGSize) throws(SilicaError) {

        guard let canvas = WebCanvasContext.makeCanvas(width: Int(size.width), height: Int(size.height))
            else { throw SilicaError.noMemory }

        try self.init(canvas: canvas, size: size)
    }

    internal static func makeCanvas(width: Int, height: Int) -> JSObject? {

        if let offscreenCanvas = JSObject.global.OffscreenCanvas.function {
            return offscreenCanvas.new(width, height)
        }

        // fall back to a detached canvas element
        let document = JSObject.global.document

        guard let canvas = document.createElement("canvas").object
            else { return nil }

        canvas.width = .number(Double(width))
        canvas.height = .number(Double(height))

        return canvas
    }

    // MARK: - Defining Pages

    public func beginPage() { } // not a page-based destination

    public func endPage() { }

    public func finish() throws(SilicaError) { }

    // MARK: - Transforming the Coordinate Space

    public var currentTransform: CGAffineTransform {

        return internalState.ctm
    }

    public func scaleBy(x: CGFloat, y: CGFloat) {

        concatenate(CGAffineTransform(a: x, b: 0, c: 0, d: y, tx: 0, ty: 0))
    }

    public func translateBy(x: CGFloat, y: CGFloat) {

        concatenate(CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: x, ty: y))
    }

    public func rotateBy(_ angle: CGFloat) {

        let cosine = JSMath.cos(angle)
        let sine = JSMath.sin(angle)

        concatenate(CGAffineTransform(a: cosine, b: sine, c: -sine, d: cosine, tx: 0, ty: 0))
    }

    public func concatenate(_ transform: CGAffineTransform) {

        // new = transform * ctm (transform applied first, in user space)
        internalState.ctm = transform.multiplied(by: internalState.ctm)
    }

    // MARK: - Saving and Restoring the Graphics State

    public func save() throws(SilicaError) {

        _ = target.save!()

        let newState = internalState.copy
        newState.next = internalState
        internalState = newState
    }

    public func restore() throws(SilicaError) {

        guard let restoredState = internalState.next
            else { throw .invalidRestore }

        _ = target.restore!()
        internalState = restoredState
    }

    // MARK: - Graphics State Attributes

    public var shouldAntialias: Bool {

        get { return internalState.shouldAntialias }

        set { internalState.shouldAntialias = newValue }
    }

    public var lineWidth: CGFloat {

        get { return internalState.lineWidth }

        set { internalState.lineWidth = newValue }
    }

    public var lineJoin: CGLineJoin {

        get { return internalState.lineJoin }

        set { internalState.lineJoin = newValue }
    }

    public var lineCap: CGLineCap {

        get { return internalState.lineCap }

        set { internalState.lineCap = newValue }
    }

    public var miterLimit: CGFloat {

        get { return internalState.miterLimit }

        set { internalState.miterLimit = newValue }
    }

    public var lineDash: (phase: CGFloat, lengths: [CGFloat]) {

        get { return internalState.lineDash }

        set { internalState.lineDash = newValue }
    }

    public var tolerance: CGFloat {

        get { return internalState.tolerance }

        set { internalState.tolerance = newValue }
    }

    public var fillColor: CGColor {

        get { return internalState.fill ?? CGColor.black }

        set { internalState.fill = newValue }
    }

    public var strokeColor: CGColor {

        get { return internalState.stroke ?? CGColor.black }

        set { internalState.stroke = newValue }
    }

    public var alpha: CGFloat {

        get { return internalState.alpha }

        set {

            internalState.alpha = newValue

            // match the Cairo backend: setting alpha overwrites the color alpha
            internalState.fill?.alpha = newValue
            internalState.stroke?.alpha = newValue
        }
    }

    public func setShadow(offset: CGSize, radius: CGFloat, color: CGColor) {

        internalState.shadow = (offset: offset, radius: radius, color: color)
    }

    // MARK: - Constructing Paths

    public var path: CGPath {

        let inverse = internalState.ctm.inverse

        return CGPath(elements: deviceElements.map { $0.applying(inverse) })
    }

    public var currentPoint: CGPoint? {

        guard let devicePoint = deviceCurrentPoint
            else { return nil }

        return devicePoint.applying(internalState.ctm.inverse)
    }

    public func beginPath() {

        deviceElements.removeAll()
        deviceCurrentPoint = nil
        deviceSubpathStart = nil
    }

    public func closePath() {

        deviceElements.append(.closeSubpath)
        deviceCurrentPoint = deviceSubpathStart
    }

    public func move(to point: CGPoint) {

        let device = point.applying(internalState.ctm)

        deviceElements.append(.moveToPoint(device))
        deviceCurrentPoint = device
        deviceSubpathStart = device
    }

    public func addLine(to point: CGPoint) {

        let device = point.applying(internalState.ctm)

        deviceElements.append(.addLineToPoint(device))
        deviceCurrentPoint = device
    }

    public func addCurve(to end: CGPoint, control1: CGPoint, control2: CGPoint) {

        let deviceControl1 = control1.applying(internalState.ctm)
        let deviceControl2 = control2.applying(internalState.ctm)
        let deviceEnd = end.applying(internalState.ctm)

        deviceElements.append(.addCurveToPoint(deviceControl1, deviceControl2, deviceEnd))
        deviceCurrentPoint = deviceEnd
    }

    public func addArc(center: CGPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat, clockwise: Bool) {

        // Match Cairo's angle normalization: arcs sweep from the start angle to the
        // end angle in increasing direction (decreasing when clockwise).
        let start = Double(startAngle)
        var end = Double(endAngle)

        if clockwise {
            while end > start { end -= 2.0 * .pi }
        } else {
            while end < start { end += 2.0 * .pi }
        }

        let radius = Double(radius)

        func point(at angle: Double) -> CGPoint {
            return CGPoint(x: center.x + CGFloat(radius * JSMath.cos(angle)),
                           y: center.y + CGFloat(radius * JSMath.sin(angle)))
        }

        let startPoint = point(at: start)

        // Cairo adds a line from the current point to the arc start (or moves to it).
        if deviceCurrentPoint != nil {
            addLine(to: startPoint)
        } else {
            move(to: startPoint)
        }

        let total = end - start

        guard total != 0, radius > 0
            else { return }

        // subdivide into segments of at most 90°, lowered to cubic Béziers
        let segments = max(1, Int((abs(total) / (Double.pi / 2.0)).rounded(.up)))
        let delta = total / Double(segments)
        let k = (4.0 / 3.0) * JSMath.tan(delta / 4.0)

        var angle1 = start

        for _ in 0 ..< segments {

            let angle2 = angle1 + delta

            let p1 = point(at: angle1)
            let p2 = point(at: angle2)

            let control1 = CGPoint(x: p1.x - CGFloat(k * radius * JSMath.sin(angle1)),
                                   y: p1.y + CGFloat(k * radius * JSMath.cos(angle1)))
            let control2 = CGPoint(x: p2.x + CGFloat(k * radius * JSMath.sin(angle2)),
                                   y: p2.y - CGFloat(k * radius * JSMath.cos(angle2)))

            addCurve(to: p2, control1: control1, control2: control2)

            angle1 = angle2
        }
    }

    public func addRect(_ rect: CGRect) {

        move(to: CGPoint(x: rect.minX, y: rect.minY))
        addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        closePath()
    }

    // MARK: - Painting Paths

    public func strokePath() {

        if let shadow = internalState.shadow {
            drawShadow(shadow) { context in
                self.strokeUnderTransform(context)
            }
        }

        applyStrokeStyle(target)
        strokeUnderTransform(target)
        resetPath()
    }

    public func fillPath(evenOdd: Bool, preserve: Bool) {

        let fillRule = evenOdd ? "evenodd" : "nonzero"

        if let shadow = internalState.shadow {
            drawShadow(shadow) { context in
                _ = context.fill!(self.makePath2D(self.deviceElements), fillRule)
            }
        }

        target.fillStyle = .string(cssColor(internalState.fill ?? .black))
        _ = target.fill!(makePath2D(deviceElements), fillRule)

        if preserve == false {
            resetPath()
        }
    }

    public func clear() {

        clip(evenOdd: false)
    }

    public func clip(evenOdd: Bool) {

        _ = target.clip!(makePath2D(deviceElements), evenOdd ? "evenodd" : "nonzero")
        resetPath()
    }

    // MARK: - Transparency Layers

    public func beginTransparencyLayer(in rect: CGRect?, auxiliaryInfo: CGAuxiliaryInfo?) {

        let width = Int(canvas.width.number ?? Double(size.width))
        let height = Int(canvas.height.number ?? Double(size.height))

        guard let layerCanvas = WebCanvasContext.makeCanvas(width: width, height: height),
            let layerContext = layerCanvas.getContext!("2d").object
            else { assertionFailure("Unable to create transparency layer"); return }

        // transform the user-space bounds into device space
        var deviceRect: CGRect?

        if let rect = rect {
            let corners = [
                CGPoint(x: rect.minX, y: rect.minY).applying(internalState.ctm),
                CGPoint(x: rect.maxX, y: rect.minY).applying(internalState.ctm),
                CGPoint(x: rect.minX, y: rect.maxY).applying(internalState.ctm),
                CGPoint(x: rect.maxX, y: rect.maxY).applying(internalState.ctm)
            ]
            let minX = corners.map { $0.x }.min()!
            let minY = corners.map { $0.y }.min()!
            let maxX = corners.map { $0.x }.max()!
            let maxY = corners.map { $0.y }.max()!
            deviceRect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        }

        layers.append(Layer(canvas: layerCanvas,
                            context: layerContext,
                            alpha: internalState.alpha,
                            bounds: deviceRect))

        let newState = internalState.copy
        newState.next = internalState
        newState.alpha = 1.0
        newState.shadow = nil
        internalState = newState
    }

    public func endTransparencyLayer() {

        guard let layer = layers.popLast()
            else { return }

        if let restoredState = internalState.next {
            internalState = restoredState
        }

        // composite the layer at the captured alpha
        _ = target.save!()
        target.globalAlpha = .number(Double(layer.alpha))

        if let bounds = layer.bounds {
            _ = target.beginPath!()
            _ = target.rect!(Double(bounds.minX), Double(bounds.minY), Double(bounds.width), Double(bounds.height))
            _ = target.clip!()
        }

        _ = target.drawImage!(layer.canvas, 0, 0)
        _ = target.restore!()
    }

    // MARK: - Drawing Images

    public func draw(_ image: CGImage, in rect: CGRect) {

        guard let imageCanvas = image.makeWebCanvas()
            else { assertionFailure("Unable to convert image"); return }

        // Silica's `draw(_:in:)` follows Apple's y-up image convention (callers
        // flip the CTM to draw upright, as UIKit code does), so mirror the image
        // vertically about the rect's centerline.
        _ = target.save!()
        setTransform(target, internalState.ctm)
        _ = target.transform!(1, 0, 0, -1, 0, Double(rect.minY + rect.maxY))

        target.imageSmoothingEnabled = .boolean(internalState.shouldAntialias)
        _ = target.drawImage!(imageCanvas, Double(rect.minX), Double(rect.minY), Double(rect.width), Double(rect.height))

        _ = target.restore!()
    }

    // MARK: - Drawing Text

    public var font: CGFont? {

        return internalState.font
    }

    public func setFont(_ font: CGFont) {

        internalState.font = font
    }

    public var fontSize: CGFloat {

        get { return internalState.fontSize }

        set { internalState.fontSize = newValue }
    }

    public var characterSpacing: CGFloat {

        get { return internalState.characterSpacing }

        set { internalState.characterSpacing = newValue }
    }

    public var textDrawingMode: CGTextDrawingMode {

        get { return internalState.textMode }

        set { internalState.textMode = newValue }
    }

    /// Primitive glyph rendering; positions are user-space baseline origins.
    ///
    /// The Web Canvas API exposes no glyph-level drawing, so glyph indices are
    /// Unicode scalar values (see `WebFontHandle`) rendered with `fillText`.
    /// The linear components of the text matrix (scale / rotation of glyph
    /// shapes) are not supported.
    public func draw(glyphs: [(glyph: CGGlyph, position: CGPoint)]) {

        guard let font = internalState.font,
            fontSize > 0.0 && glyphs.isEmpty == false
            else { return }

        guard let handle = font.handle as? WebFontHandle
            else { assertionFailure("Font \(font.name) was not loaded by the Web backend"); return }

        guard internalState.textMode != .invisible
            else { return }

        _ = target.save!()
        setTransform(target, internalState.ctm)

        target.font = .string(handle.cssFont(size: fontSize))
        target.textBaseline = .string("alphabetic")

        let fill: Bool
        let stroke: Bool

        switch internalState.textMode {
        case .stroke, .strokeClip:
            fill = false; stroke = true
        case .fillStroke, .fillStrokeClip:
            fill = true; stroke = true
        default:
            fill = true; stroke = false
        }

        if fill {
            target.fillStyle = .string(cssColor(internalState.fill ?? .black))
        }

        if stroke {
            target.strokeStyle = .string(cssColor(internalState.stroke ?? .black))
            target.lineWidth = .number(Double(internalState.lineWidth))
        }

        for element in glyphs {

            let text = handle.text(for: element.glyph)

            if fill {
                _ = target.fillText!(text, Double(element.position.x), Double(element.position.y))
            }

            if stroke {
                _ = target.strokeText!(text, Double(element.position.x), Double(element.position.y))
            }
        }

        _ = target.restore!()
    }

    // MARK: - Bitmap Contexts

    public func makeImage() -> CGImage? {

        let width = Int(canvas.width.number ?? 0)
        let height = Int(canvas.height.number ?? 0)

        guard width > 0, height > 0,
            let imageData = context.getImageData!(0, 0, width, height).object
            else { return nil }

        return CGImage(imageData)
    }

    // MARK: - Private Methods

    private func resetPath() {

        beginPath()
    }

    /// Creates a `Path2D` from the specified path elements.
    private func makePath2D(_ elements: [PathElement]) -> JSObject {

        let path = JSObject.global.Path2D.function!.new()

        for element in elements {

            switch element {

            case let .moveToPoint(point):
                _ = path.moveTo!(Double(point.x), Double(point.y))

            case let .addLineToPoint(point):
                _ = path.lineTo!(Double(point.x), Double(point.y))

            case let .addQuadCurveToPoint(control, destination):
                _ = path.quadraticCurveTo!(Double(control.x), Double(control.y),
                                          Double(destination.x), Double(destination.y))

            case let .addCurveToPoint(control1, control2, destination):
                _ = path.bezierCurveTo!(Double(control1.x), Double(control1.y),
                                       Double(control2.x), Double(control2.y),
                                       Double(destination.x), Double(destination.y))

            case .closeSubpath:
                _ = path.closePath!()
            }
        }

        return path
    }

    private func setTransform(_ context: JSObject, _ transform: CGAffineTransform) {

        _ = context.setTransform!(Double(transform.a), Double(transform.b),
                                 Double(transform.c), Double(transform.d),
                                 Double(transform.tx), Double(transform.ty))
    }

    private func applyStrokeStyle(_ context: JSObject) {

        context.strokeStyle = .string(cssColor(internalState.stroke ?? .black))
        context.lineWidth = .number(Double(internalState.lineWidth))
        context.miterLimit = .number(Double(internalState.miterLimit))

        switch internalState.lineCap {
        case .butt: context.lineCap = .string("butt")
        case .round: context.lineCap = .string("round")
        case .square: context.lineCap = .string("square")
        }

        switch internalState.lineJoin {
        case .miter: context.lineJoin = .string("miter")
        case .round: context.lineJoin = .string("round")
        case .bevel: context.lineJoin = .string("bevel")
        }

        let dash = internalState.lineDash
        let segments = JSObject.global.Array.function!.new()

        for length in dash.lengths {
            _ = segments.push!(Double(length))
        }

        _ = context.setLineDash!(segments)
        context.lineDashOffset = .number(Double(dash.phase))
    }

    /// Strokes the current device-space path with the pen transformed by the CTM,
    /// reproducing Cairo's stroke semantics (including non-uniform scales).
    private func strokeUnderTransform(_ context: JSObject) {

        let ctm = internalState.ctm

        // transform the device path back into user space
        let inverse = ctm.inverse
        let userPath = makePath2D(deviceElements.map { $0.applying(inverse) })

        _ = context.save!()
        setTransform(context, ctm)
        _ = context.stroke!(userPath)
        _ = context.restore!()
    }

    /// Draws the shadow pass: the shape silhouette in the shadow color at the
    /// shadow offset (no blur, matching the Cairo backend's emulation).
    private func drawShadow(_ shadow: (offset: CGSize, radius: CGFloat, color: CGColor),
                            _ draw: (JSObject) -> ()) {

        let ctm = internalState.ctm

        // the offset is specified in user space
        let deviceOffset = CGSize(width: ctm.a * shadow.offset.width + ctm.c * shadow.offset.height,
                                  height: ctm.b * shadow.offset.width + ctm.d * shadow.offset.height)

        _ = target.save!()
        _ = target.translate!(Double(deviceOffset.width), Double(deviceOffset.height))

        let shadowColor = cssColor(shadow.color)
        target.fillStyle = .string(shadowColor)
        target.strokeStyle = .string(shadowColor)

        draw(target)

        _ = target.restore!()
    }
}

// MARK: - Supporting Types

internal extension WebCanvasContext {

    struct Layer {

        let canvas: JSObject

        let context: JSObject

        /// Global alpha captured when the layer began, applied when compositing.
        let alpha: CGFloat

        /// Device-space bounds the composite is clipped to.
        let bounds: CGRect?
    }

    fileprivate final class State {

        var next: State?
        var ctm = CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0)
        var alpha: CGFloat = 1.0
        var fill: CGColor?
        var stroke: CGColor?
        var shadow: (offset: CGSize, radius: CGFloat, color: CGColor)?
        var font: CGFont?
        var fontSize: CGFloat = 0.0
        var characterSpacing: CGFloat = 0.0
        var textMode = CGTextDrawingMode()
        var shouldAntialias = true
        var lineWidth: CGFloat = 1.0
        var lineCap = CGLineCap()
        var lineJoin = CGLineJoin()
        var miterLimit: CGFloat = 10.0
        var lineDash: (phase: CGFloat, lengths: [CGFloat]) = (0.0, [])
        var tolerance: CGFloat = 0.1

        init() { }

        var copy: State {

            let copy = State()

            copy.next = next
            copy.ctm = ctm
            copy.alpha = alpha
            copy.fill = fill
            copy.stroke = stroke
            copy.shadow = shadow
            copy.font = font
            copy.fontSize = fontSize
            copy.characterSpacing = characterSpacing
            copy.textMode = textMode
            copy.shouldAntialias = shouldAntialias
            copy.lineWidth = lineWidth
            copy.lineCap = lineCap
            copy.lineJoin = lineJoin
            copy.miterLimit = miterLimit
            copy.lineDash = lineDash
            copy.tolerance = tolerance

            return copy
        }
    }
}

#endif // canImport(JavaScriptKit)
