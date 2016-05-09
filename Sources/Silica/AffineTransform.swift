//
//  AffineTransform.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/8/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

public struct AffineTransform {
    
    // MARK: - Properties
    
    public var a, b, c, d: Double
    
    public var t: (x: Double, y: Double)
    
    // MARK: - Initialization
    
    public init(a: Double, b: Double, c: Double, d: Double, t: (x: Double, y: Double)) {
        
        self.a = a
        self.b = b
        self.c = c
        self.d = d
        self.t = t
    }
    
    public static let identity = AffineTransform(a: 1, b: 0, c: 0, d: 1, t: (x: 0, y: 0))
}