//
//  Nintendo3DSContext.swift
//  Silica3DS
//
//  Created by Alsey Coleman Miller on 7/13/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

#if canImport(Foundation)
import Foundation
#endif
#if canImport(Silica)
import Silica
#endif

/// Software-rendered implementation of `CGContext` for the Nintendo 3DS.
///
/// The 3DS has no system vector graphics library, so this backend rasterizes
/// in pure Swift into a premultiplied RGBA bitmap. The bitmap can be read back
/// with `makeImage()` or copied into a GSP framebuffer with `present(into:)`
/// (the 3DS framebuffer is rotated 90° with column-major addressing).
///
/// Because the renderer is pure Swift, bitmap contexts also work — and are
/// tested — on every other platform.
///
/// - Note: Rendering is unantialiased at `scale: 1`; pass a higher scale to
///   supersample (rendering happens at `size * scale` and `makeImage()` /
///   `present(into:)` box-downsample).
/// - Note: Text rendering requires a font-providing backend; the 3DS backend
///   currently has none, so glyph drawing is a no-op.
public final class Nintendo3DSContext: CGContext {

    // MARK: - Properties

    public let size: CGSize

    /// The supersampling factor (device pixels per point).
    public let scale: Int

    /// The physical screen this context draws to, if created with `init(screen:scale:)`.
    public internal(set) var screen: Screen?

    /// Silica's top-left origin, y-down convention (matching the 3DS framebuffer).
    public var isFlipped: Bool { true }

    public var textMatrix = CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0)

    // MARK: - Private Properties

    /// Base surface plus any open transparency layers.
    private var surfaceStack: [SoftwareSurface]

    private var currentSurface: SoftwareSurface { surfaceStack[surfaceStack.count - 1] }

    private var internalState: State = State()

    /// Current path in (scaled) device space, mirrored for the `path` accessor.
    private var deviceElements = [PathElement]()

    private var deviceCurrentPoint: CGPoint?

    private var deviceSubpathStart: CGPoint?

    private var layerAlphas = [CGFloat]()

    private let pixelWidth: Int

    private let pixelHeight: Int

    // MARK: - Initialization

    /// Creates a software bitmap drawing destination of the specified size.
    public init(bitmap size: CGSize, scale: Int = 1) throws(SilicaError) {

        let scale = max(1, scale)
        let pixelWidth = Int(size.width) * scale
        let pixelHeight = Int(size.height) * scale

        guard pixelWidth > 0, pixelHeight > 0
            else { throw SilicaError.invalidContext }

        self.size = size
        self.scale = scale
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.surfaceStack = [SoftwareSurface(width: pixelWidth, height: pixelHeight)]

        #if canImport(Foundation)
        Nintendo3DSBackend.registerIfNeeded()
        #endif
    }

    // MARK: - Defining Pages

    /// Bitmap destinations are not page based.
    public func beginPage() { }

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

        let cosine = CGFloat(cos(Double(angle)))
        let sine = CGFloat(sin(Double(angle)))

        concatenate(CGAffineTransform(a: cosine, b: sine, c: -sine, d: cosine, tx: 0, ty: 0))
    }

    public func concatenate(_ transform: CGAffineTransform) {

        internalState.ctm = transform.multiplied(by: internalState.ctm)
    }

    /// The user → device transform, including the supersampling scale.
    private var deviceTransform: CGAffineTransform {

        let scale = CGFloat(self.scale)

        return internalState.ctm.multiplied(by: CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: 0, ty: 0))
    }

    // MARK: - Saving and Restoring the Graphics State

    public func save() throws(SilicaError) {

        let newState = internalState.copy
        newState.next = internalState
        internalState = newState
    }

    public func restore() throws(SilicaError) {

        guard let restoredState = internalState.next
            else { throw .invalidRestore }

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

        let inverse = deviceTransform.inverse

        return CGPath(elements: deviceElements.map { $0.applying(inverse) })
    }

    public var currentPoint: CGPoint? {

        guard let devicePoint = deviceCurrentPoint
            else { return nil }

        return devicePoint.applying(deviceTransform.inverse)
    }

    public func beginPath() {

        deviceElements.removeAll(keepingCapacity: true)
        deviceCurrentPoint = nil
        deviceSubpathStart = nil
    }

    public func closePath() {

        deviceElements.append(.closeSubpath)
        deviceCurrentPoint = deviceSubpathStart
    }

    public func move(to point: CGPoint) {

        let device = point.applying(deviceTransform)

        deviceElements.append(.moveToPoint(device))
        deviceCurrentPoint = device
        deviceSubpathStart = device
    }

    public func addLine(to point: CGPoint) {

        let device = point.applying(deviceTransform)

        deviceElements.append(.addLineToPoint(device))
        deviceCurrentPoint = device
    }

    public func addCurve(to end: CGPoint, control1: CGPoint, control2: CGPoint) {

        let deviceControl1 = control1.applying(deviceTransform)
        let deviceControl2 = control2.applying(deviceTransform)
        let deviceEnd = end.applying(deviceTransform)

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
            return CGPoint(x: center.x + CGFloat(radius * cos(angle)),
                           y: center.y + CGFloat(radius * sin(angle)))
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
        let k = (4.0 / 3.0) * tan(delta / 4.0)

        var angle1 = start

        for _ in 0 ..< segments {

            let angle2 = angle1 + delta

            let p1 = point(at: angle1)
            let p2 = point(at: angle2)

            let control1 = CGPoint(x: p1.x - CGFloat(k * radius * sin(angle1)),
                                   y: p1.y + CGFloat(k * radius * cos(angle1)))
            let control2 = CGPoint(x: p2.x + CGFloat(k * radius * sin(angle2)),
                                   y: p2.y - CGFloat(k * radius * cos(angle2)))

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

        defer { beginPath() }

        guard let color = strokeRasterColor()
            else { return }

        let polygons = strokeOutline()

        drawShadowPass(of: polygons, evenOdd: false)

        SoftwareRasterizer.fill(polygons, evenOdd: false,
                                into: currentSurface, color: color, clip: internalState.clip)
    }

    public func fillPath(evenOdd: Bool, preserve: Bool) {

        defer { if preserve == false { beginPath() } }

        guard let color = fillRasterColor()
            else { return }

        let polygons = fillPolygons()

        drawShadowPass(of: polygons, evenOdd: evenOdd)

        SoftwareRasterizer.fill(polygons, evenOdd: evenOdd,
                                into: currentSurface, color: color, clip: internalState.clip)
    }

    public func clear() {

        clip(evenOdd: false)
    }

    public func clip(evenOdd: Bool) {

        defer { beginPath() }

        let mask = SoftwareRasterizer.mask(fillPolygons(), evenOdd: evenOdd,
                                           width: pixelWidth, height: pixelHeight)

        if var existing = internalState.clip {
            for index in 0 ..< existing.count {
                existing[index] = min(existing[index], mask[index])
            }
            internalState.clip = existing
        } else {
            internalState.clip = mask
        }
    }

    // MARK: - Transparency Layers

    public func beginTransparencyLayer(in rect: CGRect?, auxiliaryInfo: CGAuxiliaryInfo?) {

        layerAlphas.append(internalState.alpha)

        let newState = internalState.copy
        newState.next = internalState
        newState.alpha = 1.0
        newState.shadow = nil

        if let rect = rect {
            // clip the layer to the user-space rect
            let devicePolygon = [
                CGPoint(x: rect.minX, y: rect.minY).applying(deviceTransform),
                CGPoint(x: rect.maxX, y: rect.minY).applying(deviceTransform),
                CGPoint(x: rect.maxX, y: rect.maxY).applying(deviceTransform),
                CGPoint(x: rect.minX, y: rect.maxY).applying(deviceTransform)
            ]
            let mask = SoftwareRasterizer.mask([devicePolygon], evenOdd: false,
                                               width: pixelWidth, height: pixelHeight)
            if let existing = newState.clip {
                var combined = existing
                for index in 0 ..< combined.count {
                    combined[index] = min(combined[index], mask[index])
                }
                newState.clip = combined
            } else {
                newState.clip = mask
            }
        }

        internalState = newState

        surfaceStack.append(SoftwareSurface(width: pixelWidth, height: pixelHeight))
    }

    public func endTransparencyLayer() {

        guard surfaceStack.count > 1,
            let layerAlpha = layerAlphas.popLast()
            else { return }

        let layer = surfaceStack.removeLast()

        if let restoredState = internalState.next {
            internalState = restoredState
        }

        SoftwareRasterizer.composite(layer, onto: currentSurface, alpha: layerAlpha)
    }

    // MARK: - Drawing Images

    public func draw(_ image: CGImage, in rect: CGRect) {

        guard rect.width != 0, rect.height != 0, image.width > 0, image.height > 0
            else { return }

        // Silica's `draw(_:in:)` follows Apple's y-up image convention (callers
        // flip the CTM to draw upright, as UIKit code does): the image's first
        // row maps to the rect's maxY edge.
        let transform = deviceTransform
        let corners = [
            CGPoint(x: rect.minX, y: rect.minY).applying(transform),
            CGPoint(x: rect.maxX, y: rect.minY).applying(transform),
            CGPoint(x: rect.maxX, y: rect.maxY).applying(transform),
            CGPoint(x: rect.minX, y: rect.maxY).applying(transform)
        ]

        let minX = max(0, Int(corners.map { $0.x }.min()!.rounded(.down)))
        let maxX = min(pixelWidth - 1, Int(corners.map { $0.x }.max()!.rounded(.up)))
        let minY = max(0, Int(corners.map { $0.y }.min()!.rounded(.down)))
        let maxY = min(pixelHeight - 1, Int(corners.map { $0.y }.max()!.rounded(.up)))

        guard minX <= maxX, minY <= maxY
            else { return }

        let inverse = transform.inverse
        let clip = internalState.clip

        image.data.withUnsafeBytes { (source: UnsafeRawBufferPointer) in

            let sourceBytes = source.baseAddress!.assumingMemoryBound(to: UInt8.self)

            currentSurface.data.withUnsafeMutableBufferPointer { destination in

                for pixelY in minY ... maxY {
                    for pixelX in minX ... maxX {

                        let coverage = clip?[pixelY * pixelWidth + pixelX] ?? 255

                        guard coverage > 0 else { continue }

                        // device pixel center → user space → image UV
                        let device = CGPoint(x: CGFloat(pixelX) + 0.5, y: CGFloat(pixelY) + 0.5)
                        let user = device.applying(inverse)

                        let u = (user.x - rect.minX) / rect.width
                        // y-up image convention: v = 0 at the rect's maxY edge
                        let v = (rect.maxY - user.y) / rect.height

                        guard u >= 0, u < 1, v >= 0, v < 1 else { continue }

                        let sourceX = min(image.width - 1, Int(u * CGFloat(image.width)))
                        let sourceY = min(image.height - 1, Int(v * CGFloat(image.height)))
                        let sourceOffset = sourceY * image.bytesPerRow + sourceX * 4

                        let color = RasterColor(red: sourceBytes[sourceOffset],
                                                green: sourceBytes[sourceOffset + 1],
                                                blue: sourceBytes[sourceOffset + 2],
                                                alpha: sourceBytes[sourceOffset + 3])

                        SoftwareRasterizer.blend(color, coverage: coverage,
                                                 into: destination,
                                                 at: (pixelY * pixelWidth + pixelX) * 4)
                    }
                }
            }
        }
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

    /// Glyph rendering is unavailable: the 3DS backend has no font source yet.
    public func draw(glyphs: [(glyph: CGGlyph, position: CGPoint)]) {

        // no font-providing backend on the 3DS
    }

    // MARK: - Bitmap Contexts

    public func makeImage() -> CGImage? {

        let width = pixelWidth / scale
        let height = pixelHeight / scale
        let bytesPerRow = width * 4

        var data = Data(repeating: 0, count: bytesPerRow * height)

        let samples = scale * scale
        let surface = surfaceStack[0]

        data.withUnsafeMutableBytes { (destination: UnsafeMutableRawBufferPointer) in

            let output = destination.baseAddress!.assumingMemoryBound(to: UInt8.self)

            surface.data.withUnsafeBufferPointer { input in

                for y in 0 ..< height {
                    for x in 0 ..< width {

                        // box-average the scale × scale block
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
                        output[offset]     = UInt8(sums.0 / samples)
                        output[offset + 1] = UInt8(sums.1 / samples)
                        output[offset + 2] = UInt8(sums.2 / samples)
                        output[offset + 3] = UInt8(sums.3 / samples)
                    }
                }
            }
        }

        return CGImage(width: width, height: height, bytesPerRow: bytesPerRow, data: data)
    }

    // MARK: - Private Methods

    /// The current device-space path as fill polygons.
    private func fillPolygons() -> [[CGPoint]] {

        return SoftwareRasterizer.flatten(deviceElements).map { $0.points }
    }

    /// The current path stroked with the graphics-state pen, in device space.
    ///
    /// Stroke geometry is computed in user space (so the pen transforms with
    /// the CTM, matching Cairo) and the outline transformed to device space.
    private func strokeOutline() -> [[CGPoint]] {

        let transform = deviceTransform
        let inverse = transform.inverse

        let userSubpaths = SoftwareRasterizer.flatten(deviceElements.map { $0.applying(inverse) })

        let outline = SoftwareRasterizer.strokePolygons(userSubpaths,
                                                        width: internalState.lineWidth,
                                                        cap: internalState.lineCap,
                                                        join: internalState.lineJoin,
                                                        miterLimit: internalState.miterLimit,
                                                        dash: internalState.lineDash)

        return outline.map { polygon in polygon.map { $0.applying(transform) } }
    }

    private func fillRasterColor() -> RasterColor? {

        let color = internalState.fill ?? CGColor.black
        guard color.alpha > 0 else { return nil }
        return RasterColor(color)
    }

    private func strokeRasterColor() -> RasterColor? {

        let color = internalState.stroke ?? CGColor.black
        guard color.alpha > 0 else { return nil }
        return RasterColor(color)
    }

    /// Draws the shadow pass: the shape silhouette in the shadow color at the
    /// shadow offset (no blur, matching the Cairo and Android backends).
    private func drawShadowPass(of polygons: [[CGPoint]], evenOdd: Bool) {

        guard let shadow = internalState.shadow, shadow.color.alpha > 0
            else { return }

        // the shadow offset is specified in user space
        let transform = deviceTransform
        let dx = transform.a * shadow.offset.width + transform.c * shadow.offset.height
        let dy = transform.b * shadow.offset.width + transform.d * shadow.offset.height

        let offsetPolygons = polygons.map { polygon in
            polygon.map { CGPoint(x: $0.x + dx, y: $0.y + dy) }
        }

        SoftwareRasterizer.fill(offsetPolygons, evenOdd: evenOdd,
                                into: currentSurface, color: RasterColor(shadow.color),
                                clip: internalState.clip)
    }
}

// MARK: - State

internal extension Nintendo3DSContext {

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
        var clip: [UInt8]?

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
            copy.clip = clip

            return copy
        }
    }
}

// MARK: - Geometry Helpers

internal extension CGAffineTransform {

    /// The result of applying `self` first, then `other`.
    func multiplied(by other: CGAffineTransform) -> CGAffineTransform {

        return CGAffineTransform(
            a: a * other.a + b * other.c,
            b: a * other.b + b * other.d,
            c: c * other.a + d * other.c,
            d: c * other.b + d * other.d,
            tx: tx * other.a + ty * other.c + other.tx,
            ty: tx * other.b + ty * other.d + other.ty
        )
    }

    var inverse: CGAffineTransform {

        let determinant = a * d - b * c

        guard determinant != 0
            else { return self }

        return CGAffineTransform(
            a: d / determinant,
            b: -b / determinant,
            c: -c / determinant,
            d: a / determinant,
            tx: (c * ty - d * tx) / determinant,
            ty: (b * tx - a * ty) / determinant
        )
    }
}

internal extension PathElement {

    func applying(_ transform: CGAffineTransform) -> PathElement {

        switch self {

        case let .moveToPoint(point):
            return .moveToPoint(point.applying(transform))

        case let .addLineToPoint(point):
            return .addLineToPoint(point.applying(transform))

        case let .addQuadCurveToPoint(control, destination):
            return .addQuadCurveToPoint(control.applying(transform), destination.applying(transform))

        case let .addCurveToPoint(control1, control2, destination):
            return .addCurveToPoint(control1.applying(transform), control2.applying(transform), destination.applying(transform))

        case .closeSubpath:
            return .closeSubpath
        }
    }
}
