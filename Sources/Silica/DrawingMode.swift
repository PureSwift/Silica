//
//  DrawingMode.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/9/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

/// Options for rendering text.
public enum TextDrawingMode: CInt {
    
    case Fill
    case Stroke
    case FillStroke
    case Invisible
    case FillClip
    case StrokeClip
    case FillStrokeClip
    case Clip
    
    public init() { self = .Fill }
}

/// Options for rendering a path.
public enum DrawingMode {
    
    /// Render the area contained within the path using the non-zero winding number rule.
    case Fill
    
    /// Render the area within the path using the even-odd rule.
    case EvenOddFill
    
    /// Render a line along the path.
    case Stroke
    
    /// First fill and then stroke the path, using the nonzero winding number rule.
    case FillStroke
    
    /// First fill and then stroke the path, using the even-odd rule.
    case EvenOddFillStroke
    
    public init() { self = .Fill }
}