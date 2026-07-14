//
//  Color.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/9/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

#if canImport(Foundation)
import struct Foundation.CGFloat
#endif

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
    
    public static var clear: CGColor { CGColor(red: 0, green: 0, blue: 0, alpha: 0) }
    
    public static var black: CGColor { CGColor(red: 0, green: 0, blue: 0) }
    
    public static var white: CGColor { CGColor(red: 1, green: 1, blue: 1) }
    
    public static var red: CGColor { CGColor(red: 1, green: 0, blue: 0) }
    
    public static var green: CGColor { CGColor(red: 0, green: 1, blue: 0) }
    
    public static var blue: CGColor { CGColor(red: 0, green: 0, blue: 1) }
}

// MARK: - Equatable

public func == (lhs: CGColor, rhs: CGColor) -> Bool {
    
    return lhs.red == rhs.red
        && lhs.green == rhs.green
        && lhs.blue == rhs.blue
        && lhs.alpha == rhs.alpha
}

// MARK: - CoreGraphics API

public func CGColorCreateGenericGray(_ grey: CGFloat, _ alpha: CGFloat) -> CGColor {
    
    return CGColor(grey: grey, alpha: alpha)
}


