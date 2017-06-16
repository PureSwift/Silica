//
//  DrawingMode.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/9/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

/// Options for rendering text.
public enum CGTextDrawingMode: CInt {
    
    case fill
    case stroke
    case fillStroke
    case invisible
    case fillClip
    case strokeClip
    case fillStrokeClip
    case clip
    
    public init() { self = .fill }
}

/// Options for rendering a path.
public enum CGDrawingMode {
    
    /// Render the area contained within the path using the non-zero winding number rule.
    case fill
    
    /// Render the area within the path using the even-odd rule.
    case evenOddFill
    
    public static let eoFill = CGDrawingMode.evenOddFill
    
    /// Render a line along the path.
    case stroke
    
    /// First fill and then stroke the path, using the nonzero winding number rule.
    case fillStroke
    
    /// First fill and then stroke the path, using the even-odd rule.
    case evenOddFillStroke
    
    public static let eoFillStroke = CGDrawingMode.evenOddFillStroke
    
    public init() { self = .fill }
}
