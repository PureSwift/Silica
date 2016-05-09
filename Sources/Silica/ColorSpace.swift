//
//  ColorSpace.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/9/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

public struct ColorSpace: Equatable {
    
    // MARK: - Properties
    
    public let componentCount: Int
}

// MARK: - Equatable

public func == (lhs: ColorSpace, rhs: ColorSpace) -> Bool {
    
    
}

// MARK: - Supporting Types

public enum ColorRenderingIntent {
    
    case Default
    case AbsoluteColorimetric
    case RelativeColorimetric
    case Perceptual
    case Saturation
}