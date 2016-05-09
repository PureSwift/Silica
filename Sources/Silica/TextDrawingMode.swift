//
//  TextDrawingMode.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/9/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

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
