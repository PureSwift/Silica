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
    
    public let colorSpace: ColorSpace
    
    public let components: [Double]
    
    // MARK: - Initialization
    
    public init?(colorSpace: ColorSpace, components: [Double]) {
        
        guard components.count == colorSpace.componentCount
            else { return nil }
        
        self.colorSpace = colorSpace
        self.components = components
    }
    
    // MARK: - Methods
    
    public func transformed(to colorSpace: ColorSpace) -> Color {
        
        
    }
}

// MARK: - Equatable

public func == (lhs: Color, rhs: Color) -> Bool {
    
    return lhs.colorSpace == rhs.colorSpace
        && lhs.components == rhs.components
}

// MARK: - Internal Cairo Conversion

internal extension Color {
    
    func toPattern(alpha: Double) throws -> Cairo.Pattern {
        
        
    }
}