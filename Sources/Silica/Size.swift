//
//  Size.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/10/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

/// A structure that contains width and height values.
public struct Size {
    
    public var width: Double
    
    public var height: Double
    
    public init(width: Double = 0, height: Double = 0) {
        
        self.width = width
        self.height = height
    }
}