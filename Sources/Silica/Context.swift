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
    
    public var scaleFactor: Float = 1.0
    
    // MARK: - Private Properties
    
    private let internalContext: Cairo.Context
    
    private var alpha: Double = 1.0
    
    private var fontSize: Double = 0.0
    
    private var matrix = AffineTransform.identity
    
    // MARK: - Initialization
    
    public init(surface: Cairo.Surface, size: Size) throws {
        
        let context = Cairo.Context(surface: surface)
        
        if let error = context.status.toError() {
            
            throw error
        }
        
        self.size = size
        self.surface = surface
        self.internalContext = context
        
        // Cairo defaults to line width 2.0
        context.lineWidth = 1.0
        
        // Perform the flip transformation
        //context.scale(x: 1, y: -1)
        //context.translate()
    }
    
    // MARK: - Methods
    
    public func beginPage() {
        
        
    }
    
    
}

// MARK: - Constants

private let DefaultPattern = Cairo.Pattern(color: (red: 0, green: 0, blue: 0))