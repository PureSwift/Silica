//
//  LineJoin.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/9/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

public enum CGLineJoin: UInt32 {

    case miter
    case round
    case bevel

    public init() { self = .miter }
}
