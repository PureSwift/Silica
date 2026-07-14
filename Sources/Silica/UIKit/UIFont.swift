//
//  UIFont.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/31/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

#if canImport(Foundation)
import struct Foundation.CGFloat
#endif

public final class UIFont {
    
    // MARK: - Properties
    
    public let cgFont: CGFont
    
    // MARK: Font Name Attributes
    
    public var fontName: String { return cgFont.name }
    
    public var familyName: String { return cgFont.family }
    
    // MARK: Font Metrics
    
    public let pointSize: CGFloat
    
    public lazy var descender: CGFloat = self.cgFont.descent * self.pointSize

    public lazy var ascender: CGFloat = self.cgFont.ascent * self.pointSize
    
    // MARK: - Initialization
    
    public init?(name: String, size: CGFloat) {
        
        guard let cgFont = CGFont(name: name)
            else { return nil }
        
        self.cgFont = cgFont
        self.pointSize = size
    }
}

// MARK: - Extensions

public extension UIFont {
    
    static func systemFont(ofSize size: CGFloat) -> UIFont {
        return UIFont(name: "HelveticaNeu", size: size)!
    }
    
    static func boldSystemFont(ofSize size: CGFloat) -> UIFont {
        return UIFont(name: "HelveticaNeu-Bold", size: size)!
    }
}

// MARK: - Equatable

extension UIFont: Equatable {
    
    public static func == (lhs: UIFont, rhs: UIFont) -> Bool {
        return lhs.fontName == rhs.fontName
            && lhs.pointSize == rhs.pointSize
    }
}

// MARK: - Hashable

extension UIFont: Hashable {
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(fontName)
        hasher.combine(pointSize)
    }
}
