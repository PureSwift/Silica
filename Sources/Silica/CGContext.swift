//
//  CGContext.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/8/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Android)
import Android
#endif

import Foundation

/// An abstract two-dimensional drawing destination, modeled after the Quartz 2D drawing API.
///
/// Concrete implementations are provided by the rendering backend libraries
/// (e.g. `CairoContext`, `CoreGraphicsContext`, `AndroidCanvasContext`).
///
/// Silica uses a top-left origin, y-down coordinate system (UIKit convention) on every backend.
public protocol CGContext: AnyObject {

    // MARK: - Document

    /// The size of the drawing surface, in points.
    var size: CGSize { get }

    /// Starts a new page in a page-based (e.g. PDF) graphics context.
    func beginPage()

    /// Ends the current page in a page-based (e.g. PDF) graphics context.
    func endPage()

    /// Finalizes the drawing destination (e.g. writes the PDF trailer).
    ///
    /// No drawing may be performed after calling this method.
    func finish() throws(SilicaError)

    // MARK: - Transforming the Coordinate Space

    /// Returns the current transformation matrix.
    var currentTransform: CGAffineTransform { get }

    /// Changes the scale of the user coordinate system in a context.
    func scaleBy(x: CGFloat, y: CGFloat)

    /// Changes the origin of the user coordinate system in a context.
    func translateBy(x: CGFloat, y: CGFloat)

    /// Rotates the user coordinate system in a context.
    func rotateBy(_ angle: CGFloat)

    /// Transforms the user coordinate system in a context using a specified matrix.
    func concatenate(_ transform: CGAffineTransform)

    // MARK: - Saving and Restoring the Graphics State

    /// Pushes a copy of the current graphics state onto the graphics state stack for the context.
    func save() throws(SilicaError)

    /// Sets the current graphics state to the state most recently saved.
    func restore() throws(SilicaError)

    // MARK: - Graphics State Attributes

    var shouldAntialias: Bool { get set }

    var lineWidth: CGFloat { get set }

    var lineJoin: CGLineJoin { get set }

    var lineCap: CGLineCap { get set }

    var miterLimit: CGFloat { get set }

    var lineDash: (phase: CGFloat, lengths: [CGFloat]) { get set }

    var tolerance: CGFloat { get set }

    var fillColor: CGColor { get set }

    var strokeColor: CGColor { get set }

    var alpha: CGFloat { get set }

    /// Enables shadowing in a graphics context.
    ///
    /// The offset is specified in the default user space (top-left origin, y-down).
    func setShadow(offset: CGSize, radius: CGFloat, color: CGColor)

    // MARK: - Constructing Paths

    /// Returns a `CGPath` built from the current path information in the graphics context.
    var path: CGPath { get }

    /// The current point of the current path, if any.
    var currentPoint: CGPoint? { get }

    /// Creates a new empty path in a graphics context.
    func beginPath()

    /// Closes and terminates the current path’s subpath.
    func closePath()

    /// Begins a new subpath at the specified point.
    func move(to point: CGPoint)

    /// Appends a straight line segment from the current point to the specified point.
    func addLine(to point: CGPoint)

    /// Adds a cubic Bézier curve to the current path, with the specified end point and control points.
    func addCurve(to end: CGPoint, control1: CGPoint, control2: CGPoint)

    /// Adds an arc of a circle to the current path, specified with a radius and angles.
    func addArc(center: CGPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat, clockwise: Bool)

    /// Adds a rectangular path to the current path.
    func addRect(_ rect: CGRect)

    // MARK: - Painting Paths

    /// Paints a line along the current path.
    func strokePath()

    /// Paints the area within the current path.
    ///
    /// - Parameter evenOdd: Uses the even-odd fill rule instead of the winding (non-zero) rule.
    /// - Parameter preserve: Keeps the current path after filling.
    func fillPath(evenOdd: Bool, preserve: Bool)

    func clear()

    /// Modifies the current clipping path, using the specified fill rule.
    func clip(evenOdd: Bool)

    // MARK: - Transparency Layers

    func beginTransparencyLayer(in rect: CGRect?, auxiliaryInfo: [String: Any]?)

    func endTransparencyLayer()

    // MARK: - Drawing Images

    /// Draws an image into a graphics context.
    func draw(_ image: CGImage, in rect: CGRect)

    // MARK: - Drawing Text

    /// The current text matrix.
    var textMatrix: CGAffineTransform { get set }

    /// The current font.
    var font: CGFont? { get }

    /// Sets the platform font in a graphics context.
    func setFont(_ font: CGFont)

    var fontSize: CGFloat { get set }

    var characterSpacing: CGFloat { get set }

    var textDrawingMode: CGTextDrawingMode { get set }

    /// Primitive glyph rendering.
    ///
    /// Positions are baseline origins in user space; the current font, font size and
    /// the linear (non-translation) components of the text matrix determine the glyph shapes.
    func draw(glyphs: [(glyph: CGGlyph, position: CGPoint)])

    // MARK: - Bitmap Contexts

    /// Returns the rendered contents of a bitmap context as an image, or `nil` for vector destinations.
    func makeImage() -> CGImage?
}

// MARK: - Derived Operations

public extension CGContext {

    // MARK: Saving and Restoring the Graphics State

    /// Pushes a copy of the current graphics state onto the graphics state stack for the context.
    func saveGState() {
        try! save()
    }

    /// Sets the current graphics state to the state most recently saved.
    func restoreGState() {
        try! restore()
    }

    // MARK: Graphics State Attributes

    @inline(__always)
    func setAlpha(_ alpha: CGFloat) {
        self.alpha = alpha
    }

    @inline(__always)
    func setLineDash(phase: CGFloat, lengths: [CGFloat]) {
        self.lineDash = (phase, lengths)
    }

    @inline(__always)
    func setTextDrawingMode(_ newValue: CGTextDrawingMode) {
        self.textDrawingMode = newValue
    }

    // MARK: Constructing Paths

    /// Adds a quadratic Bézier curve to the current path, with the specified end point and control point.
    func addQuadCurve(to end: CGPoint, control point: CGPoint) {

        let currentPoint = self.currentPoint ?? CGPoint()

        let first = CGPoint(x: (currentPoint.x / 3.0) + (2.0 * point.x / 3.0),
                            y: (currentPoint.y / 3.0) + (2.0 * point.y / 3.0))

        let second = CGPoint(x: (2.0 * currentPoint.x / 3.0) + (end.x / 3.0),
                             y: (2.0 * currentPoint.y / 3.0) + (end.y / 3.0))

        addCurve(to: end, control1: first, control2: second)
    }

    /// Adds an arc of a circle to the current path, specified with a radius and two tangent lines.
    func addArc(tangent1End: CGPoint, tangent2End: CGPoint, radius: CGFloat) {

        let points: (CGPoint, CGPoint) = (tangent1End, tangent2End)

        let currentPoint = self.currentPoint ?? CGPoint()

        // arguments
        let x0 = currentPoint.x.native
        let y0 = currentPoint.y.native
        let x1 = points.0.x.native
        let y1 = points.0.y.native
        let x2 = points.1.x.native
        let y2 = points.1.y.native

        // calculated
        let dx0 = x0 - x1
        let dy0 = y0 - y1
        let dx2 = x2 - x1
        let dy2 = y2 - y1
        let xl0 = sqrt((dx0 * dx0) + (dy0 * dy0))

        guard xl0 != 0 else { return }

        let xl2 = sqrt((dx2 * dx2) + (dy2 * dy2))
        let san = (dx2 * dy0) - (dx0 * dy2)

        guard san != 0 else {

            addLine(to: points.0)
            return
        }

        let n0x: CGFloat.NativeType
        let n0y: CGFloat.NativeType
        let n2x: CGFloat.NativeType
        let n2y: CGFloat.NativeType

        if san < 0 {
            n0x = -dy0 / xl0
            n0y = dx0 / xl0
            n2x = dy2 / xl2
            n2y = -dx2 / xl2

        } else {
            n0x = dy0 / xl0
            n0y = -dx0 / xl0
            n2x = -dy2 / xl2
            n2y = dx2 / xl2
        }

        let t = (dx2*n2y - dx2*n0y - dy2*n2x + dy2*n0x) / san

        let center = CGPoint(x: CGFloat(x1 + radius.native * (t * dx0 + n0x)),
                             y: CGFloat(y1 + radius.native * (t * dy0 + n0y)))
        let angle = (start: atan2(-n0y, -n0x), end: atan2(-n2y, -n2x))

        self.addArc(center: center,
                    radius: radius,
                    startAngle: CGFloat(angle.start),
                    endAngle: CGFloat(angle.end),
                    clockwise: (san < 0))
    }

    /// Adds a previously created path object to the current path in a graphics context.
    func addPath(_ path: CGPath) {

        for element in path.elements {

            switch element {

            case let .moveToPoint(point): move(to: point)

            case let .addLineToPoint(point): addLine(to: point)

            case let .addQuadCurveToPoint(control, destination): addQuadCurve(to: destination, control: control)

            case let .addCurveToPoint(control1, control2, destination): addCurve(to: destination, control1: control1, control2: control2)

            case .closeSubpath: closePath()
            }
        }
    }

    // MARK: Painting Paths

    /// Paints the area within the current path, as determined by the specified fill rule.
    func fillPath(using rule: CGPathFillRule = .winding) {

        let evenOdd: Bool

        switch rule {
        case .evenOdd: evenOdd = true
        case .winding: evenOdd = false
        }

        fillPath(evenOdd: evenOdd, preserve: false)
    }

    func drawPath(using mode: CGDrawingMode = CGDrawingMode()) {

        switch mode {
        case .fill: fillPath(evenOdd: false, preserve: false)
        case .evenOddFill: fillPath(evenOdd: true, preserve: false)
        case .fillStroke: fillPath(evenOdd: false, preserve: true)
        case .evenOddFillStroke: fillPath(evenOdd: true, preserve: true)
        case .stroke: strokePath()
        }
    }

    /// Modifies the current clipping path, using the winding (non-zero) fill rule.
    func clip() {
        clip(evenOdd: false)
    }

    @inline(__always)
    func clip(to rect: CGRect) {

        beginPath()
        addRect(rect)
        clip()
    }

    // MARK: Transparency Layers

    func beginTransparencyLayer(auxiliaryInfo: [String: Any]? = nil) {
        beginTransparencyLayer(in: nil, auxiliaryInfo: auxiliaryInfo)
    }

    func beginTransparencyLayer(in rect: CGRect) {
        beginTransparencyLayer(in: rect, auxiliaryInfo: nil)
    }

    // MARK: Drawing Text

    /// The location at which text is drawn, in user space coordinates.
    var textPosition: CGPoint {

        get { return CGPoint(x: textMatrix.tx, y: textMatrix.ty) }

        set {
            var textMatrix = self.textMatrix
            textMatrix.tx = newValue.x
            textMatrix.ty = newValue.y
            self.textMatrix = textMatrix
        }
    }

    func show(text: String) {

        guard let font = self.font,
            fontSize > 0.0 && text.isEmpty == false
            else { return }

        let glyphs = text.unicodeScalars.map { font.glyph(for: $0) }

        show(glyphs: glyphs)
    }

    func show(glyphs: [CGGlyph]) {

        guard let font = self.font,
            fontSize > 0.0 && glyphs.isEmpty == false
            else { return }

        let advances = font.advances(for: glyphs, fontSize: fontSize, textMatrix: textMatrix, characterSpacing: characterSpacing)

        show(glyphs: zip(glyphs, advances).map { (glyph: $0, advance: $1) })
    }

    func show(glyphs glyphAdvances: [(glyph: CGGlyph, advance: CGSize)]) {

        guard let font = self.font,
            fontSize > 0.0 && glyphAdvances.isEmpty == false
            else { return }

        let advances = glyphAdvances.map { $0.advance }
        let glyphs = glyphAdvances.map { $0.glyph }
        let positions = font.positions(for: advances, textMatrix: textMatrix)

        // render
        show(glyphs: zip(glyphs, positions).map { (glyph: $0, position: $1) })

        // advance text position
        advances.forEach {
            textPosition.x += $0.width
            textPosition.y += $0.height
        }
    }

    /// Draws glyphs at the specified positions in text space.
    func show(glyphs glyphPositions: [(glyph: CGGlyph, position: CGPoint)]) {

        guard let font = self.font,
            fontSize > 0.0 && glyphPositions.isEmpty == false
            else { return }

        // Convert text-space positions to user-space baseline origins.
        let ascender = font.ascent * fontSize

        let baselineGlyphs = glyphPositions.map { element -> (glyph: CGGlyph, position: CGPoint) in

            var position = element.position.applying(textMatrix)
            position.y += ascender
            return (element.glyph, position)
        }

        draw(glyphs: baselineGlyphs)
    }
}
