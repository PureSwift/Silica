//
//  CGAffineTransform.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/9/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

public extension CGAffineTransform {
    
    init(a: CGFloat, b: CGFloat, c: CGFloat, d: CGFloat, tx: CGFloat, ty: CGFloat) {
        
        self.init(a: a, b: b, c: c, d: d, t: (tx, ty))
    }
}