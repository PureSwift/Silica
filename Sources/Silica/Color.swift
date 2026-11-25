//
//  Color.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/8/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

/// A color in sRGB, with an opacity. Components are not premultiplied.
public struct Color: Equatable, Hashable, Sendable {

    public var red: Double

    public var green: Double

    public var blue: Double

    /// The opacity, from 0 (transparent) to 1 (opaque).
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// A gray: `white` from 0 (black) to 1 (white).
    public init(white: Double, alpha: Double = 1) {
        self.init(red: white, green: white, blue: white, alpha: alpha)
    }
}

public extension Color {

    /// The color with its opacity multiplied by `opacity`.
    func opacity(_ opacity: Double) -> Color {
        var color = self
        color.alpha *= opacity
        return color
    }

    /// The components clamped to 0...1.
    var clamped: Color {
        Color(red: min(max(red, 0), 1), green: min(max(green, 0), 1),
              blue: min(max(blue, 0), 1), alpha: min(max(alpha, 0), 1))
    }

    static var clear: Color { Color(red: 0, green: 0, blue: 0, alpha: 0) }
    static var black: Color { Color(white: 0) }
    static var white: Color { Color(white: 1) }
    static var gray: Color { Color(white: 0.5) }
    static var red: Color { Color(red: 1, green: 0, blue: 0) }
    static var green: Color { Color(red: 0, green: 1, blue: 0) }
    static var blue: Color { Color(red: 0, green: 0, blue: 1) }
}
