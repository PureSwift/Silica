//
//  Context.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/8/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

#if os(macOS)
    import Darwin.C.math
#elseif os(Linux)
    import Glibc
#endif

import Cairo
import CCairo
import Foundation

public final class CGContext {
    
    // MARK: - Properties
    
    public let surface: Cairo.Surface
    
    public let size: CGSize
    
    public var textMatrix = CGAffineTransform.identity
    
    // MARK: - Private Properties
    
    private let internalContext: Cairo.Context
    
    private var internalState: State = State()
    
    // MARK: - Initialization
    
    public init(surface: Cairo.Surface, size: CGSize) throws {
        
        let context = Cairo.Context(surface: surface)
        
        if let error = context.status.toError() {
            
            throw error
        }
                
        // Cairo defaults to line width 2.0
        context.lineWidth = 1.0
        
        self.size = size
        self.internalContext = context
        self.surface = surface
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
    
    @inline(__always)
    public func setLineDash(phase: CGFloat, lengths: [CGFloat]) {
        
        self.lineDash = (phase, lengths)
    }
    
    public var tolerance: CGFloat {
        
        get { return CGFloat(internalContext.tolerance) }
        
        set { internalContext.tolerance = Double(newValue) }
    }
    
    /// Returns a `Path` built from the current path information in the graphics context.
    public var path: CGPath {
        
        var path = CGPath()
        
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
            
            path.elements.append(element)
            
            // increment
            index += length
        }
        
        return path
    }
    
    public var fillColor: CGColor {
        
        get { return internalState.fill?.color ?? CGColor.black }
        
        set { internalState.fill = (newValue, Cairo.Pattern(color: newValue)) }
    }
    
    public var strokeColor: CGColor {
        
        get { return internalState.stroke?.color ?? CGColor.black }
        
        set { internalState.stroke = (newValue, Cairo.Pattern(color: newValue)) }
    }
    
    @inline(__always)
    public func setAlpha(_ alpha: CGFloat) {
        self.alpha = alpha
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
    
    public var fontSize: CGFloat {
        
        get { return internalState.fontSize }
        
        set { internalState.fontSize = newValue }
    }
    
    public var characterSpacing: CGFloat {
        
        get { return internalState.characterSpacing }
        
        set { internalState.characterSpacing = newValue }
    }
    
    @inline(__always)
    public func setTextDrawingMode(_ newValue: CGTextDrawingMode) {
        
        self.textDrawingMode = newValue
    }
    
    public var textDrawingMode: CGTextDrawingMode {
        
        get { return internalState.textMode }
        
        set { internalState.textMode = newValue }
    }
    
    public var textPosition: CGPoint {
        
        get { return CGPoint(x: textMatrix.tx, y: textMatrix.ty) }
        
        set {
            textMatrix.tx = newValue.x
            textMatrix.ty = newValue.y
        }
    }
    
    // MARK: - Methods
    
    // MARK: Defining Pages
    
    public func beginPage() {
        
        internalContext.copyPage()
    }
    
    public func endPage() {
        
        internalContext.showPage()
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
    
    public func save() throws {
        
        internalContext.save()
        
        if let error = internalContext.status.toError() {
            
            throw error
        }
        
        let newState = internalState.copy
        
        newState.next = internalState
        
        internalState = newState
    }
    
    @inline(__always)
    public func saveGState() {
        
        try! save()
    }
    
    public func restore() throws {

        guard let restoredState = internalState.next
            else { throw CAIRO_STATUS_INVALID_RESTORE.toError()! }
        
        internalContext.restore()
        
        if let error = internalContext.status.toError() {
            
            throw error
        }
        
        // success
        
        internalState = restoredState
    }
    
    @inline(__always)
    public func restoreGState() {
        
        try! restore()
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
    func addCurve(to end: CGPoint, control1: CGPoint, control2: CGPoint) {
        
        internalContext.curve(to: ((x: Double(control1.x), y: Double(control1.y)),
                                   (x: Double(control2.x), y: Double(control2.y)),
                                   (x: Double(end.x), y: Double(end.y))))
    }
    
    /// Adds a quadratic Bézier curve to the current path, with the specified end point and control point.
    public func addQuadCurve(to end: CGPoint, control point: CGPoint) {
        
        let currentPoint = self.currentPoint ?? CGPoint()
        
        let first = CGPoint(x: (currentPoint.x / 3.0) + (2.0 * point.x / 3.0),
                            y: (currentPoint.y / 3.0) + (2.0 * point.y / 3.0))
        
        let second = CGPoint(x: (2.0 * currentPoint.x / 3.0) + (end.x / 3.0),
                             y: (2.0 * currentPoint.y / 3.0) + (end.y / 3.0))
        
        addCurve(to: end, control1: first, control2: second)
    }
    
    /// Adds an arc of a circle to the current path, specified with a radius and angles.
    public func addArc(center: CGPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat, clockwise: Bool) {
        
        internalContext.addArc(center: (x: Double(center.x), y: Double(center.y)),
                               radius: Double(radius),
                               angle: (Double(startAngle), Double(endAngle)),
                               negative: clockwise)
    }
    
    /// Adds an arc of a circle to the current path, specified with a radius and two tangent lines.
    public func addArc(tangent1End: CGPoint, tangent2End: CGPoint, radius: CGFloat) {
        
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
    
    /// Adds a rectangular path to the current path.
    public func addRect(_ rect: CGRect) {
        
        internalContext.addRectangle(x: Double(rect.origin.x),
                                     y: Double(rect.origin.y),
                                     width: Double(rect.size.width),
                                     height: Double(rect.size.height))
    }
    
    /// Adds a previously created path object to the current path in a graphics context.
    public func addPath(_ path: CGPath) {
        
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
    
    // MARK: - Painting Paths
    
    /// Paints a line along the current path.
    public func strokePath() {
        
        if internalState.shadow != nil {
            
            startShadow()
        }
        
        internalContext.source = internalState.stroke?.pattern ?? DefaultPattern
        
        internalContext.stroke()
        
        if internalState.shadow != nil {
            
            endShadow()
        }
    }
    
    /// Paints the area within the current path, as determined by the specified fill rule.
    public func fillPath(using rule: CGPathFillRule = .winding) {
        
        let evenOdd: Bool
        
        switch rule {
        case .evenOdd: evenOdd = true
        case .winding: evenOdd = false
        }
        
        try! fillPath(evenOdd: evenOdd, preserve: false)
    }
    
    public func clear() {
        
        internalContext.source = internalState.fill?.pattern ?? DefaultPattern
        
        internalContext.clip()
        internalContext.clipPreserve()
    }
    
    public func drawPath(using mode: CGDrawingMode = CGDrawingMode()) {
        
        switch mode {
        case .fill: try! fillPath(evenOdd: false, preserve: false)
        case .evenOddFill: try! fillPath(evenOdd: true, preserve: false)
        case .fillStroke: try! fillPath(evenOdd: false, preserve: true)
        case .evenOddFillStroke: try! fillPath(evenOdd: true, preserve: true)
        case .stroke: strokePath()
        }
    }
    
    public func clip(evenOdd: Bool = false) {
        
        if evenOdd {
            
            internalContext.fillRule = CAIRO_FILL_RULE_EVEN_ODD
        }
        
        internalContext.clip()
        
        if evenOdd {
            
            internalContext.fillRule = CAIRO_FILL_RULE_WINDING
        }
    }
    
    @inline(__always)
    public func clip(to rect: CGRect) {
        
        beginPath()
        addRect(rect)
        clip()
    }
    
    // MARK: - Using Transparency Layers
    
    public func beginTransparencyLayer(in rect: CGRect? = nil, auxiliaryInfo: [String: Any]? = nil) {
        
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
    
    // MARK: - Drawing an Image to a Graphics Context
    
    /// Draws an image into a graphics context.
    public func draw(_ image: CGImage, in rect: CGRect) {
        
        internalContext.save()
        
        let imageSurface = image.surface
        
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
    
    // MARK: - Drawing Text
    
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
        
        cairoTextMatrix.scale(x: Double(fontSize), y: Double(fontSize))
        
        cairoTextMatrix.multiply(a: cairoTextMatrix, b: textMatrix.toCairo())
        
        internalContext.setFont(matrix: cairoTextMatrix)
        
        internalContext.source = internalState.fill?.pattern ?? DefaultPattern
        
        internalContext.show(text: text)
        
        let distance = internalContext.currentPoint ?? (0, 0)
        
        textPosition = CGPoint(x: textPosition.x + CGFloat(distance.x), y: textPosition.y + CGFloat(distance.y))
        
        if let oldPoint = oldPoint {
            
            internalContext.move(to: oldPoint)
            
        } else {
            
            internalContext.newPath()
        }
    }
    
    public func show(text: String) {
        
        guard let font = internalState.font?.scaledFont,
            fontSize > 0.0 && text.isEmpty == false
            else { return }
        
        let glyphs = text.unicodeScalars.map { font[UInt($0.value)] }
        
        show(glyphs: glyphs)
    }
    
    public func show(glyphs: [FontIndex]) {
        
        guard let font = internalState.font,
            fontSize > 0.0 && glyphs.isEmpty == false
            else { return }
        
        let advances = font.advances(for: glyphs, fontSize: fontSize, textMatrix: textMatrix, characterSpacing: characterSpacing)
        
        show(glyphs: unsafeBitCast(glyphs.merge(advances), to: [(glyph: FontIndex, advance: CGSize)].self))
    }
    
    public func show(glyphs glyphAdvances: [(glyph: FontIndex, advance: CGSize)]) {
        
        guard let font = internalState.font,
            fontSize > 0.0 && glyphAdvances.isEmpty == false
            else { return }
        
        let advances = glyphAdvances.map { $0.advance }
        let glyphs = glyphAdvances.map { $0.glyph }
        let positions = font.positions(for: advances, textMatrix: textMatrix)
        
        // render
        show(glyphs: unsafeBitCast(glyphs.merge(positions), to: [(glyph: FontIndex, position: CGPoint)].self))
        
        // advance text position
        advances.forEach {
            textPosition.x += $0.width
            textPosition.y += $0.height
        }
    }
    
    public func show(glyphs glyphPositions: [(glyph: FontIndex, position: CGPoint)]) {
        
        guard let font = internalState.font?.scaledFont,
            fontSize > 0.0 && glyphPositions.isEmpty == false
            else { return }
        
        // actual rendering
        
        let cairoGlyphs: [cairo_glyph_t] = glyphPositions.indexedMap { (index, element) in
            
            var cairoGlyph = cairo_glyph_t()
            
            cairoGlyph.index = UInt(element.glyph)
            
            let userSpacePoint = element.position.applying(textMatrix)
            
            cairoGlyph.x = Double(userSpacePoint.x)
            
            cairoGlyph.y = Double(userSpacePoint.y)
            
            return cairoGlyph
        }
        
        var cairoTextMatrix = Matrix.identity
        
        cairoTextMatrix.scale(x: Double(fontSize), y: Double(fontSize))
        
        let ascender = (Double(font.ascent) * Double(fontSize)) / Double(font.unitsPerEm)
        
        let silicaTextMatrix = Matrix(a: Double(textMatrix.a),
                                      b: Double(textMatrix.b),
                                      c: Double(textMatrix.c),
                                      d: Double(textMatrix.d),
                                      t: (0, ascender))
        
        cairoTextMatrix.multiply(a: cairoTextMatrix, b: silicaTextMatrix)
        
        internalContext.setFont(matrix: cairoTextMatrix)
        
        internalContext.source = internalState.fill?.pattern ?? DefaultPattern
        
        // show glyphs
        cairoGlyphs.forEach { internalContext.show(glyph: $0) }
    }
    
    // MARK: - Private Functions
    
    private func fillPath(evenOdd: Bool, preserve: Bool) throws {
        
        if internalState.shadow != nil {
            
            startShadow()
        }
        
        internalContext.source = internalState.fill?.pattern ?? DefaultPattern
        
        internalContext.fillRule = evenOdd ? CAIRO_FILL_RULE_EVEN_ODD : CAIRO_FILL_RULE_WINDING
        
        internalContext.fillPreserve()
        
        if preserve == false {
            
            internalContext.newPath()
        }
        
        if internalState.shadow != nil {
            
            endShadow()
        }
        
        if let error = internalContext.status.toError() {
            
            throw error
        }
    }
    
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
fileprivate let DefaultPattern = Cairo.Pattern(color: (red: 0, green: 0, blue: 0))

fileprivate extension Silica.CGContext {
    
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

// MARK: - Internal Extensions

internal extension Collection {
        
    func indexedMap<T>(_ transform: (Index, Iterator.Element) throws -> T) rethrows -> [T] {
        
        let count: Int = numericCast(self.count)
        if count == 0 {
            return []
        }
        
        var result = ContiguousArray<T>()
        result.reserveCapacity(count)
        
        var i = self.startIndex
        
        for _ in 0..<count {
            result.append(try transform(i, self[i]))
            formIndex(after: &i)
        }
        
        //_expectEnd(i, self)
        return Array(result)
    }
    
    @inline(__always)
    func merge<C: Collection, T>
        (_ other: C) -> [(Iterator.Element, T)]
        where C.Iterator.Element == T, C.IndexDistance == IndexDistance, C.Index == Index {
        
        precondition(self.count == other.count, "The collection to merge must be of the same size")
        
        return self.indexedMap { ($1, other[$0]) }
    }
}

#if os(macOS) && Xcode
    
    import Foundation
    import AppKit
    
    public extension Silica.CGContext {
        
        @objc(debugQuickLookObject)
        public var debugQuickLookObject: AnyObject {
            
            return surface.debugQuickLookObject
        }
    }
    
#endif
