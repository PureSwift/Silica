//
//  UIRectCorner.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 6/15/17.
//

/// The corners of a rectangle.
///
/// The specified constants reflect the corners of a rectangle that has not been modified by an affine transform and is drawn in
/// the default coordinate system (where the origin is in the upper-left corner and positive values extend down and to the right).
public struct UIRectCorner: OptionSet {
    
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

public extension UIRectCorner {
    
    static var topLeft: UIRectCorner        { UIRectCorner(rawValue: 1 << 0) }
    static var topRight: UIRectCorner       { UIRectCorner(rawValue: 1 << 1) }
    static var bottomLeft: UIRectCorner     { UIRectCorner(rawValue: 1 << 2) }
    static var bottomRight: UIRectCorner    { UIRectCorner(rawValue: 1 << 3) }
    static var allCorners: UIRectCorner     { UIRectCorner(rawValue: ~0) }
}
