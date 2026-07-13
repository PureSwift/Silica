//
//  CairoContext.swift
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

/// Cairo-backed implementation of `CGContext`.
public final class CairoContext: CGContext {

    // MARK: - Properties

    public let surface: Cairo.Surface

    public let size: CGSize

    /// Whether the context uses a top-left origin with the y axis pointing
    /// down (`true`, the default — matching UIKit-vended CoreGraphics
    /// contexts and Silica's UIKit layer), or a bottom-left origin with the
    /// y axis pointing up (`false` — matching a raw CoreGraphics bitmap
    /// context; text draws upright from the baseline, like CoreGraphics).
    public let isFlipped: Bool

    public var textMatrix = CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0)

    // MARK: - Private Properties

    private let internalContext: Cairo.Context

    private var internalState: State = State()

    // MARK: - Initialization

    public init(surface: Cairo.Surface, size: CGSize, flipped: Bool = true) throws(SilicaError) {

        let context = Cairo.Context(surface: surface)

        if let error = CairoError(context.status) {
            throw SilicaError(error)
        }

        // Cairo defaults to line width 2.0
        context.lineWidth = 1.0

        if flipped == false {
            // raw CoreGraphics convention: origin bottom-left, y up
            context.translate(x: 0, y: Double(size.height))
            context.scale(x: 1, y: -1)
        }

        self.size = size
        self.isFlipped = flipped
        self.internalContext = context
        self.surface = surface

        CairoBackend.registerIfNeeded()
    }

    /// Creates a PDF drawing destination at the specified file URL.
    public convenience init(pdf url: URL, size: CGSize) throws(SilicaError) {

        let surface: Cairo.Surface.PDF

        do {
            surface = try Cairo.Surface.PDF(filename: url.path,
                                            width: Double(size.width),
                                            height: Double(size.height))
        }
        catch {
            throw SilicaError(error)
        }

        try self.init(surface: surface, size: size)
    }

    /// Creates a bitmap drawing destination of the specified size.
    public convenience init(bitmap size: CGSize) throws(SilicaError) {

        let surface: Cairo.Surface.Image

        do {
            surface = try Cairo.Surface.Image(format: .argb32,
                                              width: Int(size.width),
                                              height: Int(size.height))
        }
        catch {
            throw SilicaError(error)
        }

        try self.init(surface: surface, size: size)
    }

    // MARK: - Accessors

    /// Returns the current transformation matrix.
    public var currentTransform: CGAffineTransform {
        return CGAffineTransform(cairo: internalContext.matrix)
    }

    public var currentPoint: CGPoint? {

        guard let point = internalContext.currentPoint
            else { return nil }

        return CGPoint(x: CGFloat(point.x), y: CGFloat(point.y))
    }

    public var shouldAntialias: Bool {

        get { return internalContext.antialias != CAIRO_ANTIALIAS_NONE }

        set { internalContext.antialias = newValue ? CAIRO_ANTIALIAS_DEFAULT : CAIRO_ANTIALIAS_NONE }
    }

    public var lineWidth: CGFloat {

        get { return CGFloat(internalContext.lineWidth) }

        set { internalContext.lineWidth = Double(newValue) }
    }

    public var lineJoin: CGLineJoin {

        get { return CGLineJoin(cairo: internalContext.lineJoin) }

        set { internalContext.lineJoin = newValue.toCairo() }
    }

    public var lineCap: CGLineCap {

        get { return CGLineCap(cairo: internalContext.lineCap) }

        set { internalContext.lineCap = newValue.toCairo() }
    }

    public var miterLimit: CGFloat {

        get { return CGFloat(internalContext.miterLimit) }

        set { internalContext.miterLimit = Double(newValue) }
    }

    public var lineDash: (phase: CGFloat, lengths: [CGFloat]) {

        get {
            let cairoValue = internalContext.lineDash

            return (CGFloat(cairoValue.phase), cairoValue.lengths.map({ CGFloat($0) }))
        }

        set {
            internalContext.lineDash = (Double(newValue.phase), newValue.lengths.map({ Double($0) })) }
    }

    public var tolerance: CGFloat {

        get { return CGFloat(internalContext.tolerance) }

        set { internalContext.tolerance = Double(newValue) }
    }

    /// Returns a `Path` built from the current path information in the graphics context.
    public var path: CGPath {

        var elements = [PathElement]()

        let cairoPath = internalContext.copyPath()

        var index = 0

        while index < cairoPath.count {

            let header = cairoPath[index].header

            let length = Int(header.length)

            let data = Array(cairoPath.data[index + 1 ..< length])

            let element: PathElement

            switch header.type {

            case CAIRO_PATH_MOVE_TO:

                let point = CGPoint(x: CGFloat(data[0].point.x),
                                    y: CGFloat(data[0].point.y))

                element = PathElement.moveToPoint(point)

            case CAIRO_PATH_LINE_TO:

                let point = CGPoint(x: CGFloat(data[0].point.x),
                                    y: CGFloat(data[0].point.y))

                element = PathElement.addLineToPoint(point)

            case CAIRO_PATH_CURVE_TO:

                let control1 = CGPoint(x: CGFloat(data[0].point.x),
                                       y: CGFloat(data[0].point.y))
                let control2 = CGPoint(x: CGFloat(data[1].point.x),
                                       y: CGFloat(data[1].point.y))
                let destination = CGPoint(x: CGFloat(data[2].point.x),
                                          y: CGFloat(data[2].point.y))

                element = PathElement.addCurveToPoint(control1, control2, destination)

            case CAIRO_PATH_CLOSE_PATH:

                element = PathElement.closeSubpath

            default: fatalError("Unknown Cairo Path data: \(header.type.rawValue)")
            }

            elements.append(element)

            // increment
            index += length
        }

        return CGPath(elements: elements)
    }

    public var fillColor: CGColor {

        get { return internalState.fill?.color ?? CGColor.black }

        set { internalState.fill = (newValue, Cairo.Pattern(color: newValue)) }
    }

    public var strokeColor: CGColor {

        get { return internalState.stroke?.color ?? CGColor.black }

        set { internalState.stroke = (newValue, Cairo.Pattern(color: newValue)) }
    }

    public var alpha: CGFloat {

        get { return CGFloat(internalState.alpha) }

        set {

            // store new value
            internalState.alpha = newValue

            // update stroke
            if var stroke = internalState.stroke {

                stroke.color.alpha = newValue
                stroke.pattern = Pattern(color: stroke.color)

                internalState.stroke = stroke
            }

            // update fill
            if var fill = internalState.fill {

                fill.color.alpha = newValue
                fill.pattern = Pattern(color: fill.color)

                internalState.fill = fill
            }
        }
    }

    public var font: CGFont? {

        return internalState.font
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

    // MARK: - Methods

    // MARK: Defining Pages

    public func beginPage() {

        internalContext.copyPage()
    }

    public func endPage() {

        internalContext.showPage()
    }

    /// Finalizes the underlying surface (e.g. writes the PDF trailer).
    public func finish() throws(SilicaError) {

        surface.finish()

        if let error = CairoError(surface.status) {
            throw SilicaError(error)
        }
    }

    // MARK: Transforming the Coordinate Space

    public func scaleBy(x: CGFloat, y: CGFloat) {

        internalContext.scale(x: Double(x), y: Double(y))
    }

    public func translateBy(x: CGFloat, y: CGFloat) {

        internalContext.translate(x: Double(x), y: Double(y))
    }

    public func rotateBy(_ angle: CGFloat) {

        internalContext.rotate(Double(angle))
    }

    /// Transforms the user coordinate system in a context using a specified matrix.
    public func concatenate(_ transform: CGAffineTransform) {

        internalContext.transform(transform.toCairo())
    }

    // MARK: Saving and Restoring the Graphics State

    public func save() throws(SilicaError) {
        internalContext.save()
        if let error = CairoError(internalContext.status) {
            throw SilicaError(error)
        }
        let newState = internalState.copy
        newState.next = internalState
        internalState = newState
    }

    public func restore() throws(SilicaError) {

        guard let restoredState = internalState.next
            else { throw .invalidRestore }

        internalContext.restore()

        if let error = CairoError(internalContext.status) {
            throw SilicaError(error)
        }

        // success

        internalState = restoredState
    }

    // MARK: Setting Graphics State Attributes

    public func setShadow(offset: CGSize, radius: CGFloat, color: CGColor) {

        let colorPattern = Pattern(color: color)

        internalState.shadow = (offset: offset, radius: radius, color: color, pattern: colorPattern)
    }

    // MARK: Constructing Paths

    /// Creates a new empty path in a graphics context.
    public func beginPath() {

        internalContext.newPath()
    }

    /// Closes and terminates the current path’s subpath.
    public func closePath() {

        internalContext.closePath()
    }

    /// Begins a new subpath at the specified point.
    public func move(to point: CGPoint) {

        internalContext.move(to: (x: Double(point.x), y: Double(point.y)))
    }

    /// Appends a straight line segment from the current point to the specified point.
    public func addLine(to point: CGPoint) {

        internalContext.line(to: (x: Double(point.x), y: Double(point.y)))
    }

    /// Adds a cubic Bézier curve to the current path, with the specified end point and control points.
    public func addCurve(to end: CGPoint, control1: CGPoint, control2: CGPoint) {

        internalContext.curve(to: ((x: Double(control1.x), y: Double(control1.y)),
                                   (x: Double(control2.x), y: Double(control2.y)),
                                   (x: Double(end.x), y: Double(end.y))))
    }

    /// Adds an arc of a circle to the current path, specified with a radius and angles.
    public func addArc(center: CGPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat, clockwise: Bool) {

        internalContext.addArc(center: (x: Double(center.x), y: Double(center.y)),
                               radius: Double(radius),
                               angle: (Double(startAngle), Double(endAngle)),
                               negative: clockwise)
    }

    /// Adds a rectangular path to the current path.
    public func addRect(_ rect: CGRect) {

        internalContext.addRectangle(x: Double(rect.origin.x),
                                     y: Double(rect.origin.y),
                                     width: Double(rect.size.width),
                                     height: Double(rect.size.height))
    }

    // MARK: Painting Paths

    /// Paints a line along the current path.
    public func strokePath() {

        if internalState.shadow != nil {

            startShadow()
        }

        internalContext.source = internalState.stroke?.pattern ?? .default

        internalContext.stroke()

        if internalState.shadow != nil {

            endShadow()
        }
    }

    /// Paints the area within the current path.
    public func fillPath(evenOdd: Bool, preserve: Bool) {

        if internalState.shadow != nil {

            startShadow()
        }

        internalContext.source = internalState.fill?.pattern ?? .default

        internalContext.fillRule = evenOdd ? CAIRO_FILL_RULE_EVEN_ODD : CAIRO_FILL_RULE_WINDING

        internalContext.fillPreserve()

        if preserve == false {

            internalContext.newPath()
        }

        if internalState.shadow != nil {

            endShadow()
        }

        assert(CairoError(internalContext.status) == nil, "Cairo error: \(internalContext.status)")
    }

    public func clear() {

        internalContext.source = internalState.fill?.pattern ?? .default

        internalContext.clip()
        internalContext.clipPreserve()
    }

    public func clip(evenOdd: Bool) {

        if evenOdd {

            internalContext.fillRule = CAIRO_FILL_RULE_EVEN_ODD
        }

        internalContext.clip()

        if evenOdd {

            internalContext.fillRule = CAIRO_FILL_RULE_WINDING
        }
    }

    // MARK: Transparency Layers

    public func beginTransparencyLayer(in rect: CGRect?, auxiliaryInfo: [String: Any]?) {

        // in case we clip (for the rect)
        internalContext.save()

        if let rect = rect {

            internalContext.newPath()
            addRect(rect)
            internalContext.clip()
        }

        saveGState()
        alpha = 1.0
        internalState.shadow = nil

        internalContext.pushGroup()
    }

    public func endTransparencyLayer() {

        let group = internalContext.popGroup()

        // undo change to alpha and shadow state
        restoreGState()

        // paint contents
        internalContext.source = group
        internalContext.paint(alpha: Double(internalState.alpha))

        // undo clipping (if any)
        internalContext.restore()
    }

    // MARK: Drawing an Image to a Graphics Context

    /// Draws an image into a graphics context.
    public func draw(_ image: CGImage, in rect: CGRect) {

        guard let imageSurface = try? Cairo.Surface.Image(image)
            else { assertionFailure("Unable to convert image to Cairo surface"); return }

        internalContext.save()

        let sourceRect = CGRect(x: 0, y: 0, width: CGFloat(image.width), height: CGFloat(image.height))

        let pattern = Pattern(surface: imageSurface)

        var patternMatrix = Matrix.identity

        patternMatrix.translate(x: Double(rect.origin.x),
                                y: Double(rect.origin.y))

        patternMatrix.scale(x: Double(rect.size.width / sourceRect.size.width),
                            y: Double(rect.size.height / sourceRect.size.height))

        patternMatrix.scale(x: 1, y: -1)

        patternMatrix.translate(x: 0, y: Double(-sourceRect.size.height))

        patternMatrix.invert()

        pattern.matrix = patternMatrix

        pattern.extend = .pad

        internalContext.operator = CAIRO_OPERATOR_OVER

        internalContext.source = pattern

        internalContext.addRectangle(x: Double(rect.origin.x),
                                     y: Double(rect.origin.y),
                                     width: Double(rect.size.width),
                                     height: Double(rect.size.height))

        internalContext.fill()

        internalContext.restore()
    }

    // MARK: Drawing Text

    public func setFont(_ font: CGFont) {

        internalContext.fontFace = font.scaledFont.face
        internalState.font = font
    }

    /// Uses the Cairo toy text API.
    public func show(toyText text: String) {

        let oldPoint = internalContext.currentPoint

        internalContext.move(to: (0, 0))

        // calculate text matrix

        var cairoTextMatrix = Matrix.identity

        // see draw(glyphs:) — keep glyphs upright in a bottom-left-origin context
        cairoTextMatrix.scale(x: Double(fontSize), y: isFlipped ? Double(fontSize) : -Double(fontSize))

        cairoTextMatrix.multiply(a: cairoTextMatrix, b: textMatrix.toCairo())

        internalContext.setFont(matrix: cairoTextMatrix)

        internalContext.source = internalState.fill?.pattern ?? .default

        internalContext.show(text: text)

        let distance = internalContext.currentPoint ?? (0, 0)

        textPosition = CGPoint(x: textPosition.x + CGFloat(distance.x), y: textPosition.y + CGFloat(distance.y))

        if let oldPoint = oldPoint {

            internalContext.move(to: oldPoint)

        } else {

            internalContext.newPath()
        }
    }

    /// Primitive glyph rendering; positions are user-space baseline origins.
    public func draw(glyphs: [(glyph: CGGlyph, position: CGPoint)]) {

        guard let font = internalState.font,
            fontSize > 0.0 && glyphs.isEmpty == false
            else { return }

        let cairoGlyphs: [cairo_glyph_t] = glyphs.map { element in

            var cairoGlyph = cairo_glyph_t()

            cairoGlyph.index = UInt(element.glyph)

            cairoGlyph.x = Double(element.position.x)

            cairoGlyph.y = Double(element.position.y)

            return cairoGlyph
        }

        var cairoTextMatrix = Matrix.identity

        // in a bottom-left-origin context the CTM's y flip would mirror
        // glyphs; a negative font y scale keeps them upright (CoreGraphics
        // behavior)
        cairoTextMatrix.scale(x: Double(fontSize), y: isFlipped ? Double(fontSize) : -Double(fontSize))

        let silicaTextMatrix = Matrix(a: Double(textMatrix.a),
                                      b: Double(textMatrix.b),
                                      c: Double(textMatrix.c),
                                      d: Double(textMatrix.d),
                                      t: (0, 0))

        cairoTextMatrix.multiply(a: cairoTextMatrix, b: silicaTextMatrix)

        internalContext.fontFace = font.scaledFont.face

        internalContext.setFont(matrix: cairoTextMatrix)

        internalContext.source = internalState.fill?.pattern ?? .default

        // show glyphs
        cairoGlyphs.forEach { internalContext.show(glyph: $0) }
    }

    // MARK: Bitmap Contexts

    public func makeImage() -> CGImage? {

        guard let imageSurface = surface as? Cairo.Surface.Image
            else { return nil }

        return CGImage(cairo: imageSurface)
    }

    // MARK: - Private Functions

    private func startShadow() {

        internalContext.pushGroup()
    }

    private func endShadow() {

        let pattern = internalContext.popGroup()

        internalContext.save()

        let radius = internalState.shadow!.radius

        let alphaSurface = try! Surface.Image(format: .a8,
                                        width: Int(ceil(size.width + 2 * radius)),
                                        height: Int(ceil(size.height + 2 * radius)))

        let alphaContext = Cairo.Context(surface: alphaSurface)

        alphaContext.source = pattern

        alphaContext.paint()

        alphaSurface.flush()

        internalContext.source = internalState.shadow!.pattern

        internalContext.mask(surface: alphaSurface,
                             at: (Double(internalState.shadow!.offset.width),
                                  Double(internalState.shadow!.offset.height)))

        // draw content
        internalContext.source = pattern
        internalContext.paint()

        internalContext.restore()
    }
}

// MARK: - Private

/// Default black pattern
internal extension Cairo.Pattern {

    nonisolated(unsafe) static var `default`: Cairo.Pattern = Cairo.Pattern(color: (red: 0, green: 0, blue: 0))
}

internal extension CairoContext {

    /// To save non-Cairo state variables
    fileprivate final class State {

        var next: State?
        var alpha: CGFloat = 1.0
        var fill: (color: CGColor, pattern: Cairo.Pattern)?
        var stroke: (color: CGColor, pattern: Cairo.Pattern)?
        var shadow: (offset: CGSize, radius: CGFloat, color: CGColor, pattern: Cairo.Pattern)?
        var font: CGFont?
        var fontSize: CGFloat = 0.0
        var characterSpacing: CGFloat = 0.0
        var textMode = CGTextDrawingMode()

        init() { }

        var copy: State {

            let copy = State()

            copy.next = next
            copy.alpha = alpha
            copy.fill = fill
            copy.stroke = stroke
            copy.shadow = shadow
            copy.font = font
            copy.fontSize = fontSize
            copy.characterSpacing = characterSpacing
            copy.textMode = textMode

            return copy
        }
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

#if os(macOS) && Xcode

import Foundation
import AppKit

public extension CairoContext {

    @objc(debugQuickLookObject)
    var debugQuickLookObject: AnyObject {
        return surface.debugQuickLookObject
    }
}

#endif

#endif // canImport(Cairo)
