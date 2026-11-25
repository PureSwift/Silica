//
//  QuartzRenderer.swift
//  SilicaQuartz
//
//  Created by Alsey Coleman Miller on 7/13/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

#if canImport(CoreGraphics)

import CoreGraphics
import CoreText
import Foundation
import Silica

/// A renderer drawing with Apple's Core Graphics (Quartz): into a PDF, a
/// bitmap, or a context a view hands over.
///
/// Quartz's origin is at the bottom left with y pointing up, so the renderer
/// installs a vertical flip as the base transform of every page. Quartz keeps
/// the whole graphics state itself.
public final class QuartzRenderer: Renderer {

    // MARK: - Properties

    public let size: Size

    /// Device pixels per point.
    public let scale: Double

    /// The Quartz context drawn with.
    public let nativeContext: CoreGraphics.CGContext

    private let destination: Destination

    private var isPageOpen = false

    private var isFinished = false

    /// The state set so far, set again on each new PDF page, which starts
    /// with Quartz's defaults.
    private var state = State()

    private var stack: [State] = []

    private enum Destination {
        case pdf
        case bitmap
        case external
    }

    // MARK: - Initialization

    /// A PDF at a file URL, `size` points a page.
    public init(pdf url: URL, size: Size) throws(SilicaError) {
        var mediaBox = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        guard let context = CoreGraphics.CGContext(url as CFURL, mediaBox: &mediaBox, nil)
            else { throw SilicaError.invalidContext }
        self.nativeContext = context
        self.size = size
        self.scale = 1
        self.destination = .pdf
        QuartzBackend.registerIfNeeded()
        beginPage()
    }

    /// A bitmap `size` points across, `scale` pixels per point.
    public init(bitmap size: Size, scale: Double = 1) throws(SilicaError) {
        guard let context = CoreGraphics.CGContext(
            data: nil,
            width: Int(ceil(size.width * scale)),
            height: Int(ceil(size.height * scale)),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw SilicaError.invalidContext }
        self.nativeContext = context
        self.size = size
        self.scale = scale
        self.destination = .bitmap
        QuartzBackend.registerIfNeeded()
        installBaseTransform()
    }

    /// A Quartz context someone else made (e.g. a view's), `size` points
    /// across, in Quartz's default orientation: y up from the bottom left.
    public init(_ context: CoreGraphics.CGContext, size: Size, scale: Double = 1) {
        self.nativeContext = context
        self.size = size
        self.scale = scale
        self.destination = .external
        QuartzBackend.registerIfNeeded()
        installBaseTransform()
    }

    deinit {
        try? finish()
    }

    // MARK: - Graphics State

    public func saveState() {
        ensurePage()
        nativeContext.saveGState()
        stack.append(state)
    }

    public func restoreState() {
        guard let saved = stack.popLast() else { return }
        nativeContext.restoreGState()
        state = saved
    }

    public func concatenate(_ transform: Silica.AffineTransform) {
        ensurePage()
        nativeContext.concatenate(transform.toCoreGraphics())
    }

    public func setAlpha(_ alpha: Double) {
        state.alpha = alpha
        nativeContext.setAlpha(alpha)
    }

    public func setBlendMode(_ mode: BlendMode) {
        state.blendMode = mode
        nativeContext.setBlendMode(mode.toCoreGraphics())
    }

    public func setShouldAntialias(_ shouldAntialias: Bool) {
        state.shouldAntialias = shouldAntialias
        nativeContext.setShouldAntialias(shouldAntialias)
    }

    public func setFillColor(_ color: Color) {
        state.fillColor = color
        nativeContext.setFillColor(color.toCoreGraphics())
    }

    public func setStrokeColor(_ color: Color) {
        state.strokeColor = color
        nativeContext.setStrokeColor(color.toCoreGraphics())
    }

    public func setStrokeStyle(_ style: StrokeStyle) {
        state.strokeStyle = style
        nativeContext.setLineWidth(style.lineWidth)
        nativeContext.setLineCap(style.lineCap.toCoreGraphics())
        nativeContext.setLineJoin(style.lineJoin.toCoreGraphics())
        nativeContext.setMiterLimit(style.miterLimit)
        nativeContext.setLineDash(phase: style.dashPhase, lengths: style.dash.map { CGFloat($0) })
    }

    public func setInterpolationQuality(_ quality: InterpolationQuality) {
        state.interpolationQuality = quality
        let native: CGInterpolationQuality
        switch quality {
        case .default: native = .default
        case .none: native = .none
        case .low: native = .low
        case .medium: native = .medium
        case .high: native = .high
        }
        nativeContext.interpolationQuality = native
    }

    public func setShadow(_ shadow: Shadow?) {
        state.shadow = shadow
        guard let shadow else {
            nativeContext.setShadow(offset: .zero, blur: 0, color: nil)
            return
        }
        // Quartz's shadow offsets are in device space, which is y-up
        nativeContext.setShadow(offset: CGSize(width: shadow.offset.width * scale, height: -shadow.offset.height * scale),
                                blur: shadow.blur * scale,
                                color: shadow.color.toCoreGraphics())
    }

    // MARK: - Painting

    public func fill(_ path: Silica.Path, rule: FillRule) {
        ensurePage()
        nativeContext.beginPath()
        nativeContext.addPath(path.toCoreGraphics())
        nativeContext.fillPath(using: rule.toCoreGraphics())
    }

    public func stroke(_ path: Silica.Path) {
        ensurePage()
        nativeContext.beginPath()
        nativeContext.addPath(path.toCoreGraphics())
        nativeContext.strokePath()
    }

    public func clip(to path: Silica.Path, rule: FillRule) {
        ensurePage()
        nativeContext.beginPath()
        nativeContext.addPath(path.toCoreGraphics())
        nativeContext.clip(using: rule.toCoreGraphics())
    }

    public func resetClip() {
        ensurePage()
        nativeContext.resetClip()
    }

    public func clear(_ rect: Rect) {
        ensurePage()
        nativeContext.clear(rect.toCoreGraphics())
    }

    public func draw(_ image: Silica.Image, in rect: Rect) {
        ensurePage()
        guard let nativeImage = image.toCoreGraphics() else { return }
        // Quartz draws an image's first row at the top of the rect when y is
        // up: flipped around the rect, it's upright when y is down
        nativeContext.saveGState()
        nativeContext.translateBy(x: 0, y: rect.minY + rect.maxY)
        nativeContext.scaleBy(x: 1, y: -1)
        nativeContext.draw(nativeImage, in: rect.toCoreGraphics())
        nativeContext.restoreGState()
    }

    public func drawLinearGradient(_ gradient: Gradient, start: Point, end: Point, options: GradientOptions) {
        ensurePage()
        guard let nativeGradient = gradient.toCoreGraphics() else { return }
        nativeContext.drawLinearGradient(nativeGradient, start: start.toCoreGraphics(), end: end.toCoreGraphics(),
                                         options: options.toCoreGraphics())
    }

    public func drawRadialGradient(_ gradient: Gradient, startCenter: Point, startRadius: Double,
                                   endCenter: Point, endRadius: Double, options: GradientOptions) {
        ensurePage()
        guard let nativeGradient = gradient.toCoreGraphics() else { return }
        nativeContext.drawRadialGradient(nativeGradient, startCenter: startCenter.toCoreGraphics(), startRadius: startRadius,
                                         endCenter: endCenter.toCoreGraphics(), endRadius: endRadius,
                                         options: options.toCoreGraphics())
    }

    public func beginTransparencyLayer(in rect: Rect?) {
        ensurePage()
        // Quartz composites with the alpha, shadow and blend mode at the
        // start, and resets them inside
        stack.append(state)
        state.alpha = 1
        state.shadow = nil
        state.blendMode = .normal
        if let rect {
            nativeContext.beginTransparencyLayer(in: rect.toCoreGraphics(), auxiliaryInfo: nil)
        } else {
            nativeContext.beginTransparencyLayer(auxiliaryInfo: nil)
        }
    }

    public func endTransparencyLayer() {
        guard let saved = stack.popLast() else { return }
        nativeContext.endTransparencyLayer()
        state = saved
    }

    public func draw(_ glyphs: [Glyph], at positions: [Point], font: Silica.Font, textMatrix: Silica.AffineTransform, mode: TextDrawingMode) {
        guard let face = font.face as? CoreTextFontHandle, font.size > 0, glyphs.isEmpty == false else { return }
        ensurePage()
        nativeContext.saveGState()
        nativeContext.setTextDrawingMode(mode.toCoreGraphics())
        // glyphs are upright when y is up: flipped, then the text matrix
        let flip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: 0)
        let textTransform = flip.concatenating(textMatrix.linear.toCoreGraphics())
        nativeContext.textMatrix = textTransform
        // positions pass through the text matrix: place each baseline origin in user space
        let inverse = textTransform.inverted()
        let points = positions.map { CGPoint(x: $0.x, y: $0.y).applying(inverse) }
        CTFontDrawGlyphs(face.font(size: font.size), glyphs, points, glyphs.count, nativeContext)
        nativeContext.restoreGState()
    }

    // MARK: - Document

    public func beginPage() {
        guard destination == .pdf, isFinished == false else { return }
        if isPageOpen {
            nativeContext.endPDFPage()
        }
        nativeContext.beginPDFPage(nil)
        isPageOpen = true
        installBaseTransform()
        // a page starts with Quartz's defaults
        setFillColor(state.fillColor)
        setStrokeColor(state.strokeColor)
        setStrokeStyle(state.strokeStyle)
        setAlpha(state.alpha)
        setBlendMode(state.blendMode)
        setShouldAntialias(state.shouldAntialias)
        setShadow(state.shadow)
        setInterpolationQuality(state.interpolationQuality)
    }

    public func endPage() {
        guard destination == .pdf, isPageOpen else { return }
        nativeContext.endPDFPage()
        isPageOpen = false
    }

    public func finish() throws(SilicaError) {
        guard isFinished == false else { return }
        switch destination {
        case .pdf:
            if isPageOpen {
                nativeContext.endPDFPage()
                isPageOpen = false
            }
            nativeContext.closePDF()
        case .bitmap, .external:
            nativeContext.flush()
        }
        isFinished = true
    }

    public func makeImage() -> Silica.Image? {
        guard destination == .bitmap, let nativeImage = nativeContext.makeImage() else { return nil }
        return Silica.Image(nativeImage, scale: scale)
    }
}

// MARK: - Private

private extension QuartzRenderer {

    struct State {
        var fillColor: Color = .black
        var strokeColor: Color = .black
        var strokeStyle = StrokeStyle()
        var alpha: Double = 1
        var blendMode: BlendMode = .normal
        var shouldAntialias = true
        var shadow: Shadow?
        var interpolationQuality: InterpolationQuality = .default
    }

    /// The flip to y-down and the scale, under everything drawn.
    func installBaseTransform() {
        nativeContext.translateBy(x: 0, y: size.height * scale)
        nativeContext.scaleBy(x: scale, y: -scale)
    }

    /// Opens a page for drawing after `endPage()`.
    func ensurePage() {
        if destination == .pdf, isPageOpen == false, isFinished == false {
            beginPage()
        }
    }
}

// MARK: - Conversion

internal extension Point {

    func toCoreGraphics() -> CGPoint { CGPoint(x: x, y: y) }
}

internal extension Rect {

    func toCoreGraphics() -> CGRect { CGRect(x: origin.x, y: origin.y, width: size.width, height: size.height) }
}

public extension Silica.AffineTransform {

    func toCoreGraphics() -> CGAffineTransform {
        CGAffineTransform(a: a, b: b, c: c, d: d, tx: tx, ty: ty)
    }

    init(_ transform: CGAffineTransform) {
        self.init(a: transform.a, b: transform.b, c: transform.c, d: transform.d, tx: transform.tx, ty: transform.ty)
    }
}

public extension Silica.Path {

    /// The path as a Quartz path.
    func toCoreGraphics() -> CGPath {
        let path = CGMutablePath()
        for element in elements {
            switch element {
            case let .move(point):
                path.move(to: point.toCoreGraphics())
            case let .line(point):
                path.addLine(to: point.toCoreGraphics())
            case let .quadCurve(point, control):
                path.addQuadCurve(to: point.toCoreGraphics(), control: control.toCoreGraphics())
            case let .curve(point, control1, control2):
                path.addCurve(to: point.toCoreGraphics(), control1: control1.toCoreGraphics(), control2: control2.toCoreGraphics())
            case .closeSubpath:
                path.closeSubpath()
            }
        }
        return path
    }
}

internal extension Color {

    func toCoreGraphics() -> CGColor {
        // device RGB avoids color management differences with the other backends
        CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [red, green, blue, alpha])
            ?? CGColor(gray: 0, alpha: 1)
    }
}

internal extension Gradient {

    func toCoreGraphics() -> CGGradient? {
        CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                   colors: stops.map { $0.color.toCoreGraphics() } as CFArray,
                   locations: stops.map { CGFloat($0.location) })
    }
}

internal extension GradientOptions {

    func toCoreGraphics() -> CGGradientDrawingOptions {
        var options: CGGradientDrawingOptions = []
        if contains(.drawsBeforeStartLocation) { options.insert(.drawsBeforeStartLocation) }
        if contains(.drawsAfterEndLocation) { options.insert(.drawsAfterEndLocation) }
        return options
    }
}

internal extension FillRule {

    func toCoreGraphics() -> CGPathFillRule {
        switch self {
        case .winding: return .winding
        case .evenOdd: return .evenOdd
        }
    }
}

internal extension LineCap {

    func toCoreGraphics() -> CGLineCap {
        switch self {
        case .butt: return .butt
        case .round: return .round
        case .square: return .square
        }
    }
}

internal extension LineJoin {

    func toCoreGraphics() -> CGLineJoin {
        switch self {
        case .miter: return .miter
        case .round: return .round
        case .bevel: return .bevel
        }
    }
}

internal extension TextDrawingMode {

    func toCoreGraphics() -> CGTextDrawingMode {
        switch self {
        case .fill: return .fill
        case .stroke: return .stroke
        case .fillStroke: return .fillStroke
        case .invisible: return .invisible
        case .fillClip: return .fillClip
        case .strokeClip: return .strokeClip
        case .fillStrokeClip: return .fillStrokeClip
        case .clip: return .clip
        }
    }
}

internal extension BlendMode {

    func toCoreGraphics() -> CGBlendMode {
        CGBlendMode(rawValue: Int32(rawValue)) ?? .normal
    }
}

#endif // canImport(CoreGraphics)
