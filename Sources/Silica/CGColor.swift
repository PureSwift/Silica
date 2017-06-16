//
//  Color.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/9/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import struct Foundation.CGFloat
import Cairo

public struct CGColor: Equatable {
    
    // MARK: - Properties
    
    public var red: CGFloat
    
    public var green: CGFloat
    
    public var blue: CGFloat
    
    public var alpha: CGFloat
    
    // MARK: - Initialization
    
    public init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat = 1.0) {
        
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
    
    public init(grey: CGFloat, alpha: CGFloat = 1.0) {
        
        self.red = grey
        self.green = grey
        self.blue = grey
        self.alpha = alpha
    }
    
    // MARK: - Singletons
    
    public static let clear = CGColor(red: 0, green: 0, blue: 0, alpha: 0)
    
    public static let black = CGColor(red: 0, green: 0, blue: 0)
    
    public static let white = CGColor(red: 1, green: 1, blue: 1)
    
    public static let red = CGColor(red: 1, green: 0, blue: 0)
    
    public static let green = CGColor(red: 0, green: 1, blue: 0)
    
    public static let blue = CGColor(red: 0, green: 0, blue: 1)
}

// MARK: - Equatable

public func == (lhs: CGColor, rhs: CGColor) -> Bool {
    
    return lhs.red == rhs.red
        && lhs.green == rhs.green
        && lhs.blue == rhs.blue
        && lhs.alpha == rhs.alpha
}

// MARK: - Internal Cairo Conversion

internal extension Cairo.Pattern {
    
    convenience init(color: CGColor) {
        
        self.init(color: (Double(color.red),
                          Double(color.green),
                          Double(color.blue),
                          Double(color.alpha)))
        
        assert(status.rawValue == 0, "Error creating Cairo.Pattern from Silica.Color: \(status)")
    }
}

// MARK: - CoreGraphics API

public func CGColorCreateGenericGray(_ grey: CGFloat, _ alpha: CGFloat) -> CGColor {
    
    return CGColor(grey: grey, alpha: alpha)
}


