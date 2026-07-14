//
//  LineCap.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/9/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

public enum CGLineCap: UInt32 {

    case butt
    case round
    case square

    public init() { self = .butt }
}
