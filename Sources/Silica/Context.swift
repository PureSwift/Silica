//
//  Context.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/8/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Cairo
import CCairo

public final class Context {
    
    // MARK: - Properties
    
    public let surface: Cairo.Surface
    
    public let size: Size
    
    public let scaleFactor: Float = 1.0
    
    // MARK: - Private Properties
    
    private let internalContext: Cairo.Context
    
    private var internalState: State = State()
    
    private var textMatrix = AffineTransform.identity
    
    // MARK: - Initialization
    
    public init(surface: Cairo.Surface, size: Size) throws {
        
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
    public var currentTransform: AffineTransform {
        
        return AffineTransform(cairo: internalContext.matrix)
    }
    
    public var currentPoint: Point? {
        
        guard let point = internalContext.currentPoint
            else { return nil }
        
        return Point(x: point.x, y: point.y)
    }
    
    public var shouldAntialias: Bool {
        
        get { return internalContext.antialias != CAIRO_ANTIALIAS_NONE }
        
        set { internalContext.antialias = newValue ? CAIRO_ANTIALIAS_DEFAULT : CAIRO_ANTIALIAS_NONE }
    }
    
    public var lineWidth: Double {
        
        get { return internalContext.lineWidth }
        
        set { internalContext.lineWidth = newValue }
    }
    
    public var lineJoin: LineJoin {
        
        get { return LineJoin(cairo: internalContext.lineJoin) }
        
        set { internalContext.lineJoin = newValue.toCairo() }
    }
    
    public var lineCap: LineCap {
        
        get { return LineCap(cairo: internalContext.lineCap) }
        
        set { internalContext.lineCap = newValue.toCairo() }
    }
    
    public var miterLimit: Double {
        
        get { return internalContext.miterLimit }
        
        set { internalContext.miterLimit = newValue }
    }
    
    public var lineDash: (phase: Double, lengths: [Double]) {
        
        get { return internalContext.lineDash }
        
        set { internalContext.lineDash = newValue }
    }
    
    public var tolerance: Double {
        
        get { return internalContext.tolerance }
        
        set { internalContext.tolerance = newValue }
    }
    
    /// Returns a `Path` built from the current path information in the graphics context.
    public var path: Path {
        
        var path = Path()
        
        let cairoPath = internalContext.copyPath()
        
        var index = 0
        
        while index < cairoPath.count {
            
            let header = cairoPath[index].header
            
            let length = Int(header.length)
            
            let data = Array(cairoPath.data[index + 1 ..< length])
            
            let element: Path.Element
            
            switch header.type {
                
            case CAIRO_PATH_MOVE_TO:
                
                let point = Point(x: data[0].point.x, y: data[0].point.y)
                
                element = Path.Element.MoveToPoint(point)
                
            case CAIRO_PATH_LINE_TO:
                
                let point = Point(x: data[0].point.x, y: data[0].point.y)
                
                element = Path.Element.AddLineToPoint(point)
                
            case CAIRO_PATH_CURVE_TO:
                
                let control1 = Point(x: data[0].point.x, y: data[0].point.y)
                let control2 = Point(x: data[1].point.x, y: data[1].point.y)
                let destination = Point(x: data[2].point.x, y: data[2].point.y)
                
                element = Path.Element.AddCurveToPoint(control1, control2, destination)
                
            case CAIRO_PATH_CLOSE_PATH:
                
                element = Path.Element.CloseSubpath
                
            default: fatalError("Unknown Cairo Path data: \(header.type.rawValue)")
            }
            
            path.elements.append(element)
            
            // increment
            index += length
        }
        
        return path
    }
    
    public var fillColor: Color {
        
        get { return internalState.fill?.color ?? Color.black }
        
        set { internalState.fill = (newValue, Cairo.Pattern(color: newValue)) }
    }
    
    public var strokeColor: Color {
        
        get { return internalState.stroke?.color ?? Color.black }
        
        set { internalState.stroke = (newValue, Cairo.Pattern(color: newValue)) }
    }
    
    public var alpha: Double {
        
        get { return internalState.alpha }
        
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
    
    // MARK: - Methods
    
    // MARK: Defining Pages
    
    public func beginPage() {
        
        internalContext.copyPage()
    }
    
    public func endPage() {
        
        internalContext.showPage()
    }
    
    // MARK: Transforming the Coordinate Space
    
    public func scale(x: Double, y: Double) {
        
        internalContext.scale(x: x, y: y)
    }
    
    public func translate(x: Double, y: Double) {
        
        internalContext.translate(x: x, y: y)
    }
    
    public func rotate(_ angle: Double) {
        
        internalContext.rotate(angle)
    }
    
    public func transform(_ transform: AffineTransform) {
        
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
    
    // MARK: Setting Graphics State Attributes
    
    public func setShadow(offset: Size, radius: Double, color: Color) {
        
        let colorPattern = Pattern(color: color)
        
        internalState.shadow = (offset: offset, radius: radius, color: color, pattern: colorPattern)
    }
    
    // MARK: Constructing Paths
    
    public func beginPath() {
        
        internalContext.newPath()
    }
    
    public func closePath() {
        
        internalContext.closePath()
    }
    
    public func move(to point: Point) {
        
        internalContext.move(to: (x: point.x, y: point.y))
    }
    
    public func line(to point: Point) {
        
        internalContext.line(to: (x: point.x, y: point.y))
    }
    
    public func curve(to points: (Point, Point), end: Point) {
        
        internalContext.curve(to: ((x: points.0.x, y: points.0.y), (x: points.1.x, y: points.1.y), (x: end.x, y: end.y)))
    }
    
    public func quadCurve(to point: Point, end: Point) {
        
        let currentPoint = self.currentPoint ?? Point()
        
        let first = Point(x: (currentPoint.x / 3.0) + (2.0 * point.x / 3.0),
                          y: (currentPoint.y / 3.0) + (2.0 * point.y / 3.0))
        
        let second = Point(x: (2.0 * currentPoint.x / 3.0) + (end.x / 3.0),
                           y: (2.0 * currentPoint.y / 3.0) + (end.y / 3.0))
        
        curve(to: (first, second), end: end)
    }
    
    public func arc(center: Point, radius: Double, angle: (start: Double, end: Double), negative: Bool) {
        
        internalContext.addArc(center: (x: center.x, y: center.y), radius: radius, angle: angle, negative: negative)
    }
    
    public func arc(to points: (Point, Point), radius: Double) {
        
        let currentPoint = self.currentPoint ?? Point()
        
        // arguments
        let x0 = currentPoint.x
        let y0 = currentPoint.y
        let x1 = points.0.x
        let y1 = points.0.y
        let x2 = points.1.x
        let y2 = points.1.y
        
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
            
            line(to: points.0)
            return
        }
        
        let n0x: Double
        let n0y: Double
        let n2x: Double
        let n2y: Double
        
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
        
        let center = Point(x: x1 + radius * (t * dx0 + n0x), y: y1 + radius * (t * dy0 + n0y))
        let angle = (start: atan2(-n0y, -n0x), end: atan2(-n2y, -n2x))
        
        self.arc(center: center, radius: radius, angle: angle, negative: (san < 0))
    }
    
    public func add(rect: Rect) {
        
        internalContext.addRectangle(x: rect.origin.x, y: rect.origin.y, width: rect.size.width, height: rect.size.height)
    }
    
    public func add(path: Path) {
        
        for element in path.elements {
            
            switch element {
                
            case let .MoveToPoint(point): move(to: point)
                
            case let .AddLineToPoint(point): line(to: point)
                
            case let .AddQuadCurveToPoint(control, destination): quadCurve(to: control, end: destination)
            
            case let .AddCurveToPoint(control1, control2, destination): curve(to: (control1, control2), end: destination)
            
            case .CloseSubpath: closePath()
            }
        }
    }
    
    // MARK: - Painting Paths
    
    /// Paints a line along the current path.
    public func stroke() throws {
        
        if internalState.shadow != nil {
            
            startShadow()
        }
        
        internalContext.source = internalState.stroke?.pattern ?? DefaultPattern
        
        internalContext.stroke()
        
        if internalState.shadow != nil {
            
            endShadow()
        }
        
        if let error = internalContext.status.toError() {
            
            throw error
        }
    }
    
    public func fill(evenOdd: Bool = false) throws {
        
        try fillPath(evenOdd: evenOdd, preserve: false)
    }
    
    public func clear() throws {
        
        internalContext.source = internalState.fill?.pattern ?? DefaultPattern
        
        internalContext.clip()
        internalContext.clipPreserve()
        
        if let error = internalContext.status.toError() {
            
            throw error
        }
    }
    
    public func draw(_ mode: DrawingMode = DrawingMode()) throws {
        
        switch mode {
        case .Fill: try fillPath(evenOdd: false, preserve: false)
        case .EvenOddFill: try fillPath(evenOdd: true, preserve: false)
        case .FillStroke: try fillPath(evenOdd: false, preserve: true)
        case .EvenOddFillStroke: try fillPath(evenOdd: true, preserve: true)
        case .Stroke: try stroke()
        }
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
        
        let alphaSurface = Surface(format: .A8,
                                   width: Int(ceil(size.width + 2 * radius)),
                                   height: Int(ceil(size.height + 2 * radius)))
        
        let alphaContext = Cairo.Context(surface: alphaSurface)
        
        alphaContext.source = pattern
        
        alphaContext.paint()
        
        alphaSurface.flush()
        
        internalContext.source = internalState.shadow!.pattern
        
        internalContext.mask(surface: alphaSurface, at: (internalState.shadow!.offset.width, internalState.shadow!.offset.height))
        
        // draw content
        internalContext.source = pattern
        internalContext.paint()
        
        internalContext.restore()
    }
}

// MARK: - Private

/// Default black pattern
private let DefaultPattern = Cairo.Pattern(color: (red: 0, green: 0, blue: 0))

private extension Silica.Context {
    
    /// To save non-Cairo state variables
    private final class State {
        
        var next: State?
        var alpha: Double = 1.0
        var fill: (color: Color, pattern: Cairo.Pattern)?
        var stroke: (color: Color, pattern: Cairo.Pattern)?
        var shadow: (offset: Size, radius: Double, color: Color, pattern: Cairo.Pattern)?
        var font: Font?
        var fontSize: Double = 0.0
        var characterSpacing: Double = 0.0
        var textMode = TextDrawingMode()
        
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


