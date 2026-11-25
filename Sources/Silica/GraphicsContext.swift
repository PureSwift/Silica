//
//  GraphicsContext.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 11/25/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

/// A two-dimensional drawing destination, with CoreGraphics' methods.
///
/// Code written for `CGContext` ports by dropping the prefix from its types.
/// Where it differs:
///
/// - The origin is the top left and y points down, in points, as in UIKit,
///   SwiftUI and Silica's backends, unless the context is made with
///   `origin: .bottomLeft`.
/// - An image draws upright, filling its rectangle as SwiftUI draws it.
/// - Arcs keep CoreGraphics' arithmetic: with y down, `clockwise: true` looks
///   counterclockwise, as it does in a flipped `CGContext`.
/// - The transform, the current path and the graphics state are kept here,
///   so reading them never asks the renderer.
///
/// SwiftUI's own spellings are here too: `fill(_:with:)`, `stroke(_:with:)`,
/// `clip(to:)`, `opacity` and `drawLayer(_:)`. This context is a reference,
/// so a change is scoped with `saveGState()` or `drawLayer(_:)` rather than
/// by copying it.
public class GraphicsContext {

    /// Where the origin is, and which way y points.
    @frozen
    public enum Origin: Sendable {

        /// The origin at the top left, y pointing down.
        case topLeft

        /// The origin at the bottom left, y pointing up, as in a CoreGraphics
        /// bitmap context. Text and images still draw upright.
        case bottomLeft
    }

    // MARK: - Properties

    /// What the context draws through.
    public let renderer: any Renderer

    public let origin: Origin

    /// The text matrix, which positions and shapes glyphs. Not part of the
    /// graphics state, as in CoreGraphics.
    public var textMatrix: AffineTransform = .identity

    internal var state = State()

    internal var stack: [State] = []

    /// The current path, in base space: transformed when each element was added.
    internal var basePath = Path()

    // MARK: - Initialization

    /// A context drawing through a renderer.
    public init(_ renderer: any Renderer, origin: Origin = .topLeft) {
        self.renderer = renderer
        self.origin = origin
        let size = renderer.size
        state.clipBounds = Rect(origin: .zero, size: size)
        if origin == .bottomLeft {
            renderer.concatenate(AffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: size.height))
        }
        // the renderer's defaults are the context's
        renderer.setFillColor(state.fillColor)
        renderer.setStrokeColor(state.strokeColor)
        renderer.setStrokeStyle(state.strokeStyle)
    }

    // MARK: - Document

    /// The size of the destination, in points.
    public var size: Size { renderer.size }

    public func beginPage() {
        renderer.beginPage()
    }

    public func endPage() {
        renderer.endPage()
    }

    /// Finishes the destination (e.g. writes the PDF trailer). Nothing may be drawn after.
    public func finish() throws(SilicaError) {
        try renderer.finish()
    }

    /// What's drawn so far as an image, or nil for a destination that isn't a bitmap.
    public func makeImage() -> Image? {
        renderer.makeImage()
    }
}

// MARK: - State

internal extension GraphicsContext {

    struct State {
        var ctm: AffineTransform = .identity
        var fillColor: Color = .black
        var strokeColor: Color = .black
        var strokeStyle = StrokeStyle()
        var alpha: Double = 1
        var blendMode: BlendMode = .normal
        var shadow: Shadow?
        var shouldAntialias = true
        var interpolationQuality: InterpolationQuality = .default
        var font: Font?
        var characterSpacing: Double = 0
        var textDrawingMode: TextDrawingMode = .fill
        /// The clip's bounding box, in base space.
        var clipBounds: Rect = .null
    }

    /// The flip from the renderer's y-down user space to this context's base
    /// space, which is its own inverse.
    var baseFlip: AffineTransform? {
        origin == .bottomLeft ? AffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: 0) : nil
    }
}

public extension GraphicsContext {

    // MARK: - Graphics State

    /// Pushes a copy of the graphics state.
    func saveGState() {
        stack.append(state)
        renderer.saveState()
    }

    /// Restores the graphics state pushed last. Without one, does nothing.
    func restoreGState() {
        guard let saved = stack.popLast() else { return }
        state = saved
        renderer.restoreState()
    }

    // MARK: - Transform

    /// The current transformation matrix: from user space to base space.
    var ctm: AffineTransform { state.ctm }

    func concatenate(_ transform: AffineTransform) {
        state.ctm = transform.concatenating(state.ctm)
        renderer.concatenate(transform)
    }

    func translateBy(x: Double, y: Double) {
        concatenate(AffineTransform(translationX: x, y: y))
    }

    func scaleBy(x: Double, y: Double) {
        concatenate(AffineTransform(scaleX: x, y: y))
    }

    func rotate(by angle: Double) {
        concatenate(AffineTransform(rotationAngle: angle))
    }

    // MARK: - Stroke

    var strokeStyle: StrokeStyle {
        get { state.strokeStyle }
        set {
            state.strokeStyle = newValue
            renderer.setStrokeStyle(newValue)
        }
    }

    var lineWidth: Double {
        get { state.strokeStyle.lineWidth }
        set { strokeStyle.lineWidth = newValue }
    }

    var lineCap: LineCap {
        get { state.strokeStyle.lineCap }
        set { strokeStyle.lineCap = newValue }
    }

    var lineJoin: LineJoin {
        get { state.strokeStyle.lineJoin }
        set { strokeStyle.lineJoin = newValue }
    }

    var miterLimit: Double {
        get { state.strokeStyle.miterLimit }
        set { strokeStyle.miterLimit = newValue }
    }

    func setLineWidth(_ width: Double) {
        lineWidth = width
    }

    func setLineCap(_ cap: LineCap) {
        lineCap = cap
    }

    func setLineJoin(_ join: LineJoin) {
        lineJoin = join
    }

    func setMiterLimit(_ limit: Double) {
        miterLimit = limit
    }

    func setLineDash(phase: Double, lengths: [Double]) {
        var style = strokeStyle
        style.dash = lengths
        style.dashPhase = phase
        strokeStyle = style
    }

    var strokeColor: Color {
        get { state.strokeColor }
        set {
            state.strokeColor = newValue
            renderer.setStrokeColor(newValue)
        }
    }

    func setStrokeColor(_ color: Color) {
        strokeColor = color
    }

    func setStrokeColor(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        strokeColor = Color(red: red, green: green, blue: blue, alpha: alpha)
    }

    // MARK: - Fill

    var fillColor: Color {
        get { state.fillColor }
        set {
            state.fillColor = newValue
            renderer.setFillColor(newValue)
        }
    }

    func setFillColor(_ color: Color) {
        fillColor = color
    }

    func setFillColor(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        fillColor = Color(red: red, green: green, blue: blue, alpha: alpha)
    }

    /// The opacity everything is drawn with, from 0 to 1.
    var alpha: Double {
        get { state.alpha }
        set {
            state.alpha = newValue
            renderer.setAlpha(newValue)
        }
    }

    /// SwiftUI's name for `alpha`.
    var opacity: Double {
        get { alpha }
        set { alpha = newValue }
    }

    func setAlpha(_ alpha: Double) {
        self.alpha = alpha
    }

    var blendMode: BlendMode {
        get { state.blendMode }
        set {
            state.blendMode = newValue
            renderer.setBlendMode(newValue)
        }
    }

    func setBlendMode(_ mode: BlendMode) {
        blendMode = mode
    }

    var shadow: Shadow? {
        get { state.shadow }
        set {
            state.shadow = newValue
            guard var shadow = newValue else {
                renderer.setShadow(nil)
                return
            }
            // the renderer's base space is y-down
            if origin == .bottomLeft {
                shadow.offset.height = -shadow.offset.height
            }
            renderer.setShadow(shadow)
        }
    }

    /// Casts a shadow. The offset is in base space, unaffected by the
    /// transform: positive y is down unless the origin is at the bottom left.
    func setShadow(offset: Size, blur: Double, color: Color = Color(white: 0, alpha: 1.0 / 3.0)) {
        shadow = Shadow(offset: offset, blur: blur, color: color)
    }

    var shouldAntialias: Bool {
        get { state.shouldAntialias }
        set {
            state.shouldAntialias = newValue
            renderer.setShouldAntialias(newValue)
        }
    }

    func setShouldAntialias(_ shouldAntialias: Bool) {
        self.shouldAntialias = shouldAntialias
    }

    /// How images are sampled when they're scaled.
    var interpolationQuality: InterpolationQuality {
        get { state.interpolationQuality }
        set {
            state.interpolationQuality = newValue
            renderer.setInterpolationQuality(newValue)
        }
    }

    func setInterpolationQuality(_ quality: InterpolationQuality) {
        interpolationQuality = quality
    }

    // MARK: - Path

    /// The current path, in user space.
    var path: Path {
        guard let inverse = state.ctm.invertedIfPossible() else { return Path() }
        return basePath.applying(inverse)
    }

    var isPathEmpty: Bool { basePath.isEmpty }

    /// The current point, in user space.
    var currentPoint: Point? {
        guard let point = basePath.currentPoint, let inverse = state.ctm.invertedIfPossible() else { return nil }
        return point.applying(inverse)
    }

    /// The current path's bounding box, in user space.
    var boundingBoxOfPath: Rect {
        path.boundingRect
    }

    /// Whether a user-space point is inside the current path.
    func pathContains(_ point: Point, using rule: FillRule = .winding) -> Bool {
        basePath.contains(point.applying(state.ctm), using: rule)
    }

    func beginPath() {
        basePath = Path()
    }

    func closePath() {
        basePath.closeSubpath()
    }

    func move(to point: Point) {
        basePath.move(to: point.applying(state.ctm))
    }

    func addLine(to point: Point) {
        addToPath { $0.addLine(to: point) }
    }

    func addLines(between points: [Point]) {
        addToPath { $0.addLines(points) }
    }

    func addCurve(to point: Point, control1: Point, control2: Point) {
        addToPath { $0.addCurve(to: point, control1: control1, control2: control2) }
    }

    func addQuadCurve(to point: Point, control: Point) {
        addToPath { $0.addQuadCurve(to: point, control: control) }
    }

    func addArc(center: Point, radius: Double, startAngle: Double, endAngle: Double, clockwise: Bool) {
        addToPath { $0.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: clockwise) }
    }

    func addArc(tangent1End: Point, tangent2End: Point, radius: Double) {
        addToPath { $0.addArc(tangent1End: tangent1End, tangent2End: tangent2End, radius: radius) }
    }

    func addRect(_ rect: Rect) {
        addToPath { $0.addRect(rect) }
    }

    func addRects(_ rects: [Rect]) {
        addToPath { $0.addRects(rects) }
    }

    func addEllipse(in rect: Rect) {
        addToPath { $0.addEllipse(in: rect) }
    }

    func addPath(_ path: Path) {
        basePath.addPath(path, transform: state.ctm)
    }

    // MARK: - Painting

    /// Fills the current path, then clears it.
    func fillPath(using rule: FillRule = .winding) {
        if let path = userPath() {
            renderer.fill(path, rule: rule)
        }
        beginPath()
    }

    /// Strokes the current path, then clears it.
    func strokePath() {
        if let path = userPath() {
            renderer.stroke(path)
        }
        beginPath()
    }

    /// Paints the current path, then clears it.
    func drawPath(using mode: DrawingMode = .fill) {
        if let path = userPath() {
            switch mode {
            case .fill:
                renderer.fill(path, rule: .winding)
            case .evenOddFill:
                renderer.fill(path, rule: .evenOdd)
            case .stroke:
                renderer.stroke(path)
            case .fillStroke:
                renderer.fill(path, rule: .winding)
                renderer.stroke(path)
            case .evenOddFillStroke:
                renderer.fill(path, rule: .evenOdd)
                renderer.stroke(path)
            }
        }
        beginPath()
    }

    /// Fills a rectangle, and clears the current path.
    func fill(_ rect: Rect) {
        renderer.fill(Path(rect), rule: .winding)
        beginPath()
    }

    func fill(_ rects: [Rect]) {
        renderer.fill(Path { $0.addRects(rects) }, rule: .winding)
        beginPath()
    }

    /// Strokes a rectangle, and clears the current path.
    func stroke(_ rect: Rect) {
        renderer.stroke(Path(rect))
        beginPath()
    }

    func stroke(_ rect: Rect, width: Double) {
        saveGState()
        lineWidth = width
        stroke(rect)
        restoreGState()
    }

    func fillEllipse(in rect: Rect) {
        renderer.fill(Path(ellipseIn: rect), rule: .winding)
        beginPath()
    }

    func strokeEllipse(in rect: Rect) {
        renderer.stroke(Path(ellipseIn: rect))
        beginPath()
    }

    /// Strokes lines between pairs of points.
    func strokeLineSegments(between points: [Point]) {
        var path = Path()
        var index = 0
        while index + 1 < points.count {
            path.move(to: points[index])
            path.addLine(to: points[index + 1])
            index += 2
        }
        renderer.stroke(path)
        beginPath()
    }

    /// Clears a rectangle to transparent, within the clip.
    func clear(_ rect: Rect) {
        renderer.clear(rect)
    }

    // MARK: - Clipping

    /// Intersects the clip with the current path, then clears the path.
    func clip(using rule: FillRule = .winding) {
        if let path = userPath() {
            clip(toUserPath: path, rule: rule)
        }
        beginPath()
    }

    /// Intersects the clip with a rectangle.
    func clip(to rect: Rect) {
        clip(toUserPath: Path(rect), rule: .winding)
    }

    func clip(to rects: [Rect]) {
        clip(toUserPath: Path { $0.addRects(rects) }, rule: .winding)
    }

    /// Sets the clip back to the whole destination, until the graphics state
    /// is restored.
    func resetClip() {
        state.clipBounds = Rect(origin: .zero, size: size)
        renderer.resetClip()
    }

    /// The clip's bounding box, in user space.
    var clipBoundingBox: Rect {
        guard let inverse = state.ctm.invertedIfPossible() else { return .null }
        return state.clipBounds.applying(inverse)
    }

    // MARK: - Gradients

    func drawLinearGradient(_ gradient: Gradient, start: Point, end: Point, options: GradientOptions = []) {
        renderer.drawLinearGradient(gradient, start: start, end: end, options: options)
    }

    func drawRadialGradient(_ gradient: Gradient, startCenter: Point, startRadius: Double,
                            endCenter: Point, endRadius: Double, options: GradientOptions = []) {
        renderer.drawRadialGradient(gradient, startCenter: startCenter, startRadius: startRadius,
                                    endCenter: endCenter, endRadius: endRadius, options: options)
    }

    // MARK: - Transparency Layers

    /// Draws what follows into a layer, composited at `endTransparencyLayer()`
    /// with the alpha, shadow and blend mode now. Inside, they start reset.
    func beginTransparencyLayer() {
        beginTransparencyLayer(in: nil)
    }

    /// A transparency layer clipped to a rectangle.
    func beginTransparencyLayer(in rect: Rect?) {
        stack.append(state)
        state.alpha = 1
        state.shadow = nil
        state.blendMode = .normal
        if let rect {
            state.clipBounds = state.clipBounds.intersection(rect.applying(state.ctm))
        }
        renderer.beginTransparencyLayer(in: rect)
    }

    func endTransparencyLayer() {
        guard let saved = stack.popLast() else { return }
        state = saved
        renderer.endTransparencyLayer()
    }

    // MARK: - Images

    /// Draws an image scaled to fill a rectangle, upright.
    func draw(_ image: Image, in rect: Rect) {
        guard origin == .bottomLeft else {
            renderer.draw(image, in: rect)
            return
        }
        // the renderer draws upright when y points down
        renderer.saveState()
        renderer.concatenate(AffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: rect.minY + rect.maxY))
        renderer.draw(image, in: rect)
        renderer.restoreState()
    }

    // MARK: - SwiftUI

    /// Fills a path with a color, leaving the fill color and current path as they are.
    func fill(_ path: Path, with color: Color, rule: FillRule = .winding) {
        renderer.setFillColor(color)
        renderer.fill(path, rule: rule)
        renderer.setFillColor(state.fillColor)
    }

    /// Strokes a path with a color and a line width, leaving the stroke state as it is.
    func stroke(_ path: Path, with color: Color, lineWidth: Double = 1) {
        var style = state.strokeStyle
        style.lineWidth = lineWidth
        stroke(path, with: color, style: style)
    }

    /// Strokes a path with a color and a style, leaving the stroke state as it is.
    func stroke(_ path: Path, with color: Color, style: StrokeStyle) {
        renderer.setStrokeColor(color)
        renderer.setStrokeStyle(style)
        renderer.stroke(path)
        renderer.setStrokeColor(state.strokeColor)
        renderer.setStrokeStyle(state.strokeStyle)
    }

    /// Intersects the clip with a path in user space.
    func clip(to path: Path, rule: FillRule = .winding) {
        clip(toUserPath: path, rule: rule)
    }

    /// Draws `body` in a layer of its own, composited with the alpha, shadow
    /// and blend mode now. Changes to the state inside last until it ends.
    func drawLayer(_ body: (GraphicsContext) throws -> Void) rethrows {
        saveGState()
        beginTransparencyLayer()
        defer {
            endTransparencyLayer()
            restoreGState()
        }
        try body(self)
    }
}

// MARK: - Text

public extension GraphicsContext {

    /// The font text is drawn with.
    var font: Font? {
        get { state.font }
        set { state.font = newValue }
    }

    func setFont(_ font: Font) {
        state.font = font
    }

    /// Sets the size of the current font.
    func setFontSize(_ size: Double) {
        state.font = state.font?.withSize(size)
    }

    /// Space added after each glyph, in text space.
    var characterSpacing: Double {
        get { state.characterSpacing }
        set { state.characterSpacing = newValue }
    }

    func setCharacterSpacing(_ spacing: Double) {
        characterSpacing = spacing
    }

    /// How glyphs are painted. The clipping modes paint as their fill and
    /// stroke parts, and don't clip.
    var textDrawingMode: TextDrawingMode {
        get { state.textDrawingMode }
        set { state.textDrawingMode = newValue }
    }

    func setTextDrawingMode(_ mode: TextDrawingMode) {
        textDrawingMode = mode
    }

    /// Where the next glyph's baseline origin is, in user space: the text
    /// matrix's translation.
    var textPosition: Point {
        get { Point(x: textMatrix.tx, y: textMatrix.ty) }
        set {
            textMatrix.tx = newValue.x
            textMatrix.ty = newValue.y
        }
    }

    /// Draws glyphs at positions in text space, as CGContextShowGlyphsAtPositions does.
    func showGlyphs(_ glyphs: [Glyph], at positions: [Point]) {
        guard let font = state.font, glyphs.isEmpty == false else { return }
        let points = positions.map { $0.applying(textMatrix) }
        drawGlyphs(glyphs, at: points, font: font, matrix: textMatrix)
    }

    /// Draws glyphs from the text position, each after the last one's advance
    /// and the character spacing, and moves the text position past them.
    func showGlyphs(_ glyphs: [Glyph]) {
        guard let font = state.font, glyphs.isEmpty == false else { return }
        var x = 0.0
        var positions: [Point] = []
        for advance in font.advances(for: glyphs) {
            positions.append(Point(x: x, y: 0))
            x += advance + state.characterSpacing
        }
        showGlyphs(glyphs, at: positions)
        textPosition = Point(x: 0, y: 0).applying(AffineTransform(translationX: x, y: 0).concatenating(textMatrix))
    }

    /// Draws a line of text with the font and the fill color, the anchor's
    /// point of its box at `point`: the box spans the text's width, and from
    /// the font's ascent above the baseline to its descent below.
    func draw(_ text: String, at point: Point, anchor: UnitPoint = .topLeading) {
        guard let font = state.font else { return }
        let layout = font.layout(text, characterSpacing: state.characterSpacing)
        let height = font.ascent + font.descent
        let x = point.x - anchor.x * layout.width
        drawLine(layout.runs, at: Point(x: x, y: baseline(top: point.y, anchor: anchor.y, height: height, font: font)))
    }

    /// Draws text with the font and the fill color, broken into lines that
    /// fit the rectangle's width, from its top. Lines below the rectangle
    /// aren't drawn.
    func draw(_ text: String, in rect: Rect, alignment: TextAlignment = .leading) {
        guard let font = state.font else { return }
        let rect = rect.standardized
        let down = origin == .topLeft
        var top = down ? rect.minY : rect.maxY
        for (index, line) in font.lines(of: text, maxWidth: rect.width).enumerated() {
            let bottom = down ? top + font.ascent + font.descent : top - font.ascent - font.descent
            if index > 0, down ? bottom > rect.maxY : bottom < rect.minY { break }
            let layout = font.layout(line, characterSpacing: state.characterSpacing)
            let x: Double
            switch alignment {
            case .leading: x = rect.minX
            case .center: x = rect.midX - layout.width / 2
            case .trailing: x = rect.maxX - layout.width
            }
            drawLine(layout.runs, at: Point(x: x, y: down ? top + font.ascent : top - font.ascent))
            top = down ? top + font.lineHeight : top - font.lineHeight
        }
    }

    /// The size text takes with the font, broken into lines that fit
    /// `maxWidth` when it's over 0.
    func size(of text: String, maxWidth: Double = 0) -> Size {
        guard let font = state.font else { return .zero }
        let lines = maxWidth > 0 ? font.lines(of: text, maxWidth: maxWidth) : text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let width = lines.map { font.width(of: $0) }.max() ?? 0
        let height = lines.isEmpty ? 0 : font.ascent + font.descent + Double(lines.count - 1) * font.lineHeight
        return Size(width: width, height: height)
    }
}

// MARK: - Private

private extension GraphicsContext {

    /// Adds elements built in user space, from the current point, to the path.
    func addToPath(_ body: (inout Path) -> Void) {
        var path = Path()
        let inverse = state.ctm.invertedIfPossible()
        if let point = basePath.currentPoint, let inverse {
            path.move(to: point.applying(inverse))
        }
        let seeded = path.elements.count
        body(&path)
        basePath.addPath(Path(elements: Array(path.elements.dropFirst(seeded))), transform: state.ctm)
    }

    /// The current path in user space, or nil when there's nothing to draw:
    /// it's empty, or the transform can't be inverted.
    func userPath() -> Path? {
        guard basePath.isEmpty == false, let inverse = state.ctm.invertedIfPossible() else { return nil }
        return basePath.applying(inverse)
    }

    func clip(toUserPath path: Path, rule: FillRule) {
        state.clipBounds = state.clipBounds.intersection(path.boundingRect.applying(state.ctm))
        renderer.clip(to: path, rule: rule)
    }

    /// The baseline of a line whose box has the anchor's height fraction at `top`.
    func baseline(top: Double, anchor: Double, height: Double, font: Font) -> Double {
        switch origin {
        case .topLeft: return top - anchor * height + font.ascent
        case .bottomLeft: return top + anchor * height - font.ascent
        }
    }

    func drawLine(_ runs: [GlyphRun], at origin: Point) {
        for run in runs {
            let positions = run.positions.map { Point(x: origin.x + $0.x, y: origin.y + $0.y) }
            drawGlyphs(run.glyphs, at: positions, font: run.font, matrix: .identity)
        }
    }

    func drawGlyphs(_ glyphs: [Glyph], at positions: [Point], font: Font, matrix: AffineTransform) {
        let mode: TextDrawingMode
        switch state.textDrawingMode {
        case .fill, .fillClip: mode = .fill
        case .stroke, .strokeClip: mode = .stroke
        case .fillStroke, .fillStrokeClip: mode = .fillStroke
        case .invisible, .clip: return
        }
        var textMatrix = matrix.linear
        if let flip = baseFlip {
            textMatrix = flip.concatenating(textMatrix)
        }
        renderer.draw(glyphs, at: positions, font: font, textMatrix: textMatrix, mode: mode)
    }
}
