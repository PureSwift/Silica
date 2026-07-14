//
//  CoreGraphicsContext.swift
//  SilicaCoreGraphics
//
//  Created by Alsey Coleman Miller on 7/13/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

#if canImport(CoreGraphics)

import CoreGraphics
import CoreText
import Foundation
import Silica

/// Apple CoreGraphics (Quartz) backed implementation of `CGContext`.
///
/// Silica uses a top-left origin, y-down coordinate system (UIKit convention),
/// while Quartz uses a bottom-left origin, y-up system. This backend installs a
/// vertical flip as the base transform of every page, so Silica drawing code
/// produces identical output on every backend.
public final class CoreGraphicsContext: Silica.CGContext {

    // MARK: - Properties

    public let size: CGSize

    /// Silica's top-left origin convention (the backend installs a vertical
    /// flip over Quartz's native bottom-left space).
    public var isFlipped: Bool { true }

    /// The underlying Quartz context.
    public let nativeContext: CoreGraphics.CGContext

    public var textMatrix = CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0)

    // MARK: - Private Properties

    private let destination: Destination

    private var internalState: State = State()

    private var isPageOpen = false

    private var isFinished = false

    /// The user → device transform immediately after page setup (the flip).
    private var baseTransform = CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0)

    private enum Destination {
        case pdf
        case bitmap
        case external
    }

    // MARK: - Initialization

    /// Creates a PDF drawing destination at the specified file URL.
    public init(pdf url: URL, size: CGSize) throws(SilicaError) {

        var mediaBox = CGRect(origin: .zero, size: size)

        guard let context = CoreGraphics.CGContext(url as CFURL, mediaBox: &mediaBox, nil)
            else { throw SilicaError.invalidContext }

        self.nativeContext = context
        self.size = size
        self.destination = .pdf

        CoreGraphicsBackend.registerIfNeeded()

        // open the first page
        beginPage()
    }

    /// Creates a bitmap drawing destination of the specified size.
    public init(bitmap size: CGSize) throws(SilicaError) {

        guard let context = CoreGraphics.CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw SilicaError.invalidContext }

        self.nativeContext = context
        self.size = size
        self.destination = .bitmap

        CoreGraphicsBackend.registerIfNeeded()

        installFlip()
    }

    /// Wraps an existing Quartz context (e.g. obtained from `NSGraphicsContext`).
    ///
    /// The context is assumed to be in Quartz's default y-up orientation;
    /// the initializer installs a vertical flip so that Silica drawing uses
    /// a top-left origin.
    public init(_ context: CoreGraphics.CGContext, size: CGSize) {

        self.nativeContext = context
        self.size = size
        self.destination = .external

        CoreGraphicsBackend.registerIfNeeded()

        installFlip()
    }

    private func installFlip() {

        nativeContext.translateBy(x: 0, y: size.height)
        nativeContext.scaleBy(x: 1, y: -1)
        baseTransform = nativeContext.ctm
    }

    /// Opens a page lazily for drawing that occurs after `endPage()`.
    @inline(__always)
    private func ensurePage() {

        if destination == .pdf, isPageOpen == false, isFinished == false {
            beginPage()
        }
    }

    // MARK: - Defining Pages

    public func beginPage() {

        guard destination == .pdf, isFinished == false
            else { return }

        if isPageOpen {
            nativeContext.endPDFPage()
        }

        nativeContext.beginPDFPage(nil)
        installFlip()
        isPageOpen = true
    }

    public func endPage() {

        guard destination == .pdf, isPageOpen
            else { return }

        nativeContext.endPDFPage()
        isPageOpen = false
    }

    public func finish() throws(SilicaError) {

        guard isFinished == false
            else { return }

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

    deinit {
        try? finish()
    }

    // MARK: - Transforming the Coordinate Space

    public var currentTransform: CGAffineTransform {

        return nativeContext.ctm.concatenating(baseTransform.inverted())
    }

    public func scaleBy(x: CGFloat, y: CGFloat) {

        nativeContext.scaleBy(x: x, y: y)
    }

    public func translateBy(x: CGFloat, y: CGFloat) {

        nativeContext.translateBy(x: x, y: y)
    }

    public func rotateBy(_ angle: CGFloat) {

        nativeContext.rotate(by: angle)
    }

    public func concatenate(_ transform: CGAffineTransform) {

        nativeContext.concatenate(transform)
    }

    // MARK: - Saving and Restoring the Graphics State

    public func save() throws(SilicaError) {

        ensurePage()
        nativeContext.saveGState()

        let newState = internalState.copy
        newState.next = internalState
        internalState = newState
    }

    public func restore() throws(SilicaError) {

        guard let restoredState = internalState.next
            else { throw .invalidRestore }

        nativeContext.restoreGState()
        internalState = restoredState
    }

    // MARK: - Graphics State Attributes

    public var shouldAntialias: Bool {

        get { return internalState.shouldAntialias }

        set {
            internalState.shouldAntialias = newValue
            nativeContext.setShouldAntialias(newValue)
        }
    }

    public var lineWidth: CGFloat {

        get { return internalState.lineWidth }

        set {
            internalState.lineWidth = newValue
            nativeContext.setLineWidth(newValue)
        }
    }

    public var lineJoin: CGLineJoin {

        get { return internalState.lineJoin }

        set {
            internalState.lineJoin = newValue
            nativeContext.setLineJoin(newValue.toCoreGraphics())
        }
    }

    public var lineCap: CGLineCap {

        get { return internalState.lineCap }

        set {
            internalState.lineCap = newValue
            nativeContext.setLineCap(newValue.toCoreGraphics())
        }
    }

    public var miterLimit: CGFloat {

        get { return internalState.miterLimit }

        set {
            internalState.miterLimit = newValue
            nativeContext.setMiterLimit(newValue)
        }
    }

    public var lineDash: (phase: CGFloat, lengths: [CGFloat]) {

        get { return internalState.lineDash }

        set {
            internalState.lineDash = newValue
            nativeContext.setLineDash(phase: newValue.phase, lengths: newValue.lengths)
        }
    }

    public var tolerance: CGFloat {

        get { return internalState.tolerance }

        set {
            internalState.tolerance = newValue
            nativeContext.setFlatness(newValue)
        }
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
            nativeContext.setAlpha(newValue)
        }
    }

    public func setShadow(offset: CGSize, radius: CGFloat, color: CGColor) {

        internalState.shadow = (offset: offset, radius: radius, color: color)

        // Quartz shadow offsets are specified in the base (unflipped, y-up) space.
        nativeContext.setShadow(offset: CGSize(width: offset.width, height: -offset.height),
                                blur: radius,
                                color: color.toCoreGraphics())
    }

    // MARK: - Constructing Paths

    public var path: CGPath {

        var elements = [PathElement]()

        guard let nativePath = nativeContext.path
            else { return CGPath() }

        nativePath.applyWithBlock { pointer in

            let element = pointer.pointee

            switch element.type {

            case .moveToPoint:
                elements.append(.moveToPoint(element.points[0]))

            case .addLineToPoint:
                elements.append(.addLineToPoint(element.points[0]))

            case .addQuadCurveToPoint:
                elements.append(.addQuadCurveToPoint(element.points[0], element.points[1]))

            case .addCurveToPoint:
                elements.append(.addCurveToPoint(element.points[0], element.points[1], element.points[2]))

            case .closeSubpath:
                elements.append(.closeSubpath)

            @unknown default:
                assertionFailure("Unknown path element type \(element.type)")
            }
        }

        return CGPath(elements: elements)
    }

    public var currentPoint: CGPoint? {

        guard nativeContext.isPathEmpty == false
            else { return nil }

        return nativeContext.currentPointOfPath
    }

    public func beginPath() {

        ensurePage()
        nativeContext.beginPath()
    }

    public func closePath() {

        nativeContext.closePath()
    }

    public func move(to point: CGPoint) {

        ensurePage()
        nativeContext.move(to: point)
    }

    public func addLine(to point: CGPoint) {

        ensurePage()
        nativeContext.addLine(to: point)
    }

    public func addCurve(to end: CGPoint, control1: CGPoint, control2: CGPoint) {

        ensurePage()
        nativeContext.addCurve(to: end, control1: control1, control2: control2)
    }

    public func addArc(center: CGPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat, clockwise: Bool) {

        ensurePage()

        // Both Silica (following Cairo) and Quartz define the clockwise flag as a
        // decreasing-angle sweep, so it maps directly (and appears counterclockwise
        // in Silica's flipped coordinate system, exactly like UIKit).
        nativeContext.addArc(center: center,
                             radius: radius,
                             startAngle: startAngle,
                             endAngle: endAngle,
                             clockwise: clockwise)
    }

    public func addRect(_ rect: CGRect) {

        ensurePage()
        nativeContext.addRect(rect)
    }

    // MARK: - Painting Paths

    public func strokePath() {

        ensurePage()
        applyStrokeColor()
        nativeContext.strokePath()
    }

    public func fillPath(evenOdd: Bool, preserve: Bool) {

        ensurePage()
        applyFillColor()

        let preservedPath = preserve ? nativeContext.path : nil

        nativeContext.fillPath(using: evenOdd ? .evenOdd : .winding)

        if let preservedPath = preservedPath {
            nativeContext.addPath(preservedPath)
        }
    }

    public func clear() {

        ensurePage()
        nativeContext.clip()
    }

    public func clip(evenOdd: Bool) {

        ensurePage()
        nativeContext.clip(using: evenOdd ? .evenOdd : .winding)
    }

    // MARK: - Transparency Layers

    public func beginTransparencyLayer(in rect: CGRect?, auxiliaryInfo: [String: Any]?) {

        ensurePage()

        // Quartz composites the layer using the context alpha at begin time,
        // and resets alpha and shadow for drawing inside the layer.
        // Mirror that in the Silica-level state.
        let newState = internalState.copy
        newState.next = internalState
        newState.alpha = 1.0
        newState.shadow = nil
        internalState = newState

        if let rect = rect {
            nativeContext.beginTransparencyLayer(in: rect, auxiliaryInfo: nil)
        } else {
            nativeContext.beginTransparencyLayer(auxiliaryInfo: nil)
        }
    }

    public func endTransparencyLayer() {

        nativeContext.endTransparencyLayer()

        if let restoredState = internalState.next {
            internalState = restoredState
        }
    }

    // MARK: - Drawing Images

    public func draw(_ image: CGImage, in rect: CGRect) {

        ensurePage()

        guard let nativeImage = image.toCoreGraphics()
            else { assertionFailure("Unable to convert image"); return }

        // Silica's `draw(_:in:)` follows Apple's y-up image convention (callers flip
        // the CTM to draw upright in the y-down coordinate system, as UIKit code does),
        // so under the flipped base transform Quartz's native behavior matches Cairo's.
        nativeContext.saveGState()
        nativeContext.interpolationQuality = .default
        nativeContext.draw(nativeImage, in: rect)
        nativeContext.restoreGState()
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
    public func draw(glyphs: [(glyph: CGGlyph, position: CGPoint)]) {

        guard let font = internalState.font,
            fontSize > 0.0 && glyphs.isEmpty == false
            else { return }

        guard let handle = font.handle as? CoreTextFontHandle
            else { assertionFailure("Font \(font.name) was not loaded by the CoreGraphics backend"); return }

        ensurePage()

        let sizedFont = handle.font(size: fontSize)

        nativeContext.saveGState()

        applyFillColor()
        applyStrokeColor()
        nativeContext.setTextDrawingMode(internalState.textMode.toCoreGraphics())

        // Un-mirror glyph shapes under the flipped base transform, then apply the
        // linear components of Silica's text matrix (translation is baked into positions).
        let flip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: 0)
        let linear = CGAffineTransform(a: textMatrix.a, b: textMatrix.b,
                                       c: textMatrix.c, d: textMatrix.d,
                                       tx: 0, ty: 0)
        let textTransform = flip.concatenating(linear)
        nativeContext.textMatrix = textTransform

        // Glyph positions pass through the text matrix when rendered, so
        // pre-apply its inverse to place each baseline origin in user space.
        let inverse = textTransform.inverted()

        let glyphIndices = glyphs.map { $0.glyph }
        let positions = glyphs.map { element -> CGPoint in
            let point = element.position
            return CGPoint(x: inverse.a * point.x + inverse.c * point.y + inverse.tx,
                           y: inverse.b * point.x + inverse.d * point.y + inverse.ty)
        }

        CTFontDrawGlyphs(sizedFont, glyphIndices, positions, glyphs.count, nativeContext)

        nativeContext.restoreGState()
    }

    // MARK: - Bitmap Contexts

    public func makeImage() -> CGImage? {

        guard let nativeImage = nativeContext.makeImage()
            else { return nil }

        return CGImage(nativeImage)
    }

    // MARK: - Private Methods

    private func applyFillColor() {

        nativeContext.setFillColor((internalState.fill ?? .black).toCoreGraphics())
    }

    private func applyStrokeColor() {

        nativeContext.setStrokeColor((internalState.stroke ?? .black).toCoreGraphics())
    }
}

// MARK: - State

internal extension CoreGraphicsContext {

    /// Mirror of graphics state values that Quartz does not expose getters for,
    /// plus Silica-level text state.
    fileprivate final class State {

        var next: State?
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

// MARK: - CoreGraphics Conversion

internal extension Silica.CGColor {

    func toCoreGraphics() -> CoreGraphics.CGColor {

        // Device RGB avoids color management differences with the Cairo backend.
        return CoreGraphics.CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(),
                                    components: [red, green, blue, alpha])
            ?? CoreGraphics.CGColor(gray: 0, alpha: 1)
    }
}

internal extension Silica.CGLineCap {

    func toCoreGraphics() -> CoreGraphics.CGLineCap {

        switch self {
        case .butt: return .butt
        case .round: return .round
        case .square: return .square
        }
    }
}

internal extension Silica.CGLineJoin {

    func toCoreGraphics() -> CoreGraphics.CGLineJoin {

        switch self {
        case .miter: return .miter
        case .round: return .round
        case .bevel: return .bevel
        }
    }
}

internal extension Silica.CGTextDrawingMode {

    func toCoreGraphics() -> CoreGraphics.CGTextDrawingMode {

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

#endif // canImport(CoreGraphics)
