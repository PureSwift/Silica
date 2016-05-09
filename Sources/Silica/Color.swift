//
//  Color.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/9/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Cairo

public struct Color: Equatable {
    
    // MARK: - Properties
    
    public var red: Double
    
    public var green: Double
    
    public var blue: Double
    
    public var alpha: Double
    
    // MARK: - Initialization
    
    public init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
    
    public init(grey: Double, alpha: Double = 1.0) {
        
        self.red = grey
        self.green = grey
        self.blue = grey
        self.alpha = alpha
    }
}

// MARK: - Equatable

public func == (lhs: Color, rhs: Color) -> Bool {
    
    return lhs.red == rhs.red
        && lhs.green == rhs.green
        && lhs.blue == rhs.blue
        && lhs.alpha == rhs.alpha
}

// MARK: - Internal Cairo Conversion

internal extension Cairo.Pattern {
    
    convenience init(color: Color) {
        
        self.init(color: (color.red, color.green, color.blue, color.alpha))
        
        assert(status.rawValue == 0, "Error creating Cairo.Pattern from Silica.Color: \(status)")
    }
}