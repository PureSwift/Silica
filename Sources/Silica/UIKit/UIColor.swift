//
//  UIColor.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/12/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Foundation

public final class UIColor {
    
    // MARK: - Properties
    
    public let cgColor: Silica.CGColor
    
    // MARK: - Initialization
    
    public init(cgColor color: Silica.CGColor) {
        
        self.cgColor = color
    }
    
    /// An initialized color object. The color information represented by this object is in the device RGB colorspace.
    public init(red: CGFloat,
                green: CGFloat,
                blue: CGFloat,
                alpha: CGFloat = 1.0) {
        
        self.cgColor = Silica.CGColor(red: red, green: green, blue: blue, alpha: alpha)
    }
    
    // MARK: - Methods
    
    // MARK: Retrieving Color Information
    
    public func getRed(_ red: inout CGFloat,
                       green: inout CGFloat,
                       blue: inout CGFloat,
                       alpha: inout CGFloat) -> Bool {
        
        red = cgColor.red
        green = cgColor.green
        blue = cgColor.blue
        alpha = cgColor.alpha
        
        return true
    }
    
    // MARK: Drawing
    
    /// Sets the color of subsequent stroke and fill operations to the color that the receiver represents.
    public func set() {
        setFill()
        setStroke()
    }
    
    /// Sets the color of subsequent fill operations to the color that the receiver represents.
    public func setFill() {
        UIGraphicsGetCurrentContext()?.fillColor = self.cgColor
    }
    
    /// Sets the color of subsequent stroke operations to the color that the receiver represents.
    public func setStroke() {
        UIGraphicsGetCurrentContext()?.strokeColor = self.cgColor
    }
    
    // MARK: - Singletons
    
    public static var red: UIColor { UIColor(cgColor: .red) }
    
    public static var green: UIColor { UIColor(cgColor: .green) }
    
    public static var blue: UIColor { UIColor(cgColor: .blue) }
    
    public static var white: UIColor { UIColor(cgColor: .white) }
    
    public static var black: UIColor { UIColor(cgColor: .black) }
}
