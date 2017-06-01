//
//  CairoConvertible.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/9/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

public protocol CairoConvertible {
    
    associatedtype CairoType
    
    init(cairo: CairoType)
    
    func toCairo() -> CairoType
}