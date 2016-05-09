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
    
    // MARK: - Private Methods
    
    private func setColor()
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
        var shadow: (color: Color, offset: Size, radius: Double)?
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


