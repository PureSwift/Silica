//
//  NSStringDrawing.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/30/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Foundation

public typealias NSParagraphStyle = NSMutableParagraphStyle
public typealias NSStringDrawingContext = Void

/// Encapsulates the paragraph or ruler attributes.
public final class NSMutableParagraphStyle {
    
    // MARK: - Properties
    
    /// The text alignment
    public var alignment = NSTextAlignment()
    
    // MARK: - Initialization
    
    public init() { }
    
    public static func `default`() -> NSMutableParagraphStyle {
        return NSMutableParagraphStyle()
    }
}

extension NSMutableParagraphStyle {
    
    public func toCacao() -> ParagraphStyle {
        
        var paragraphStyle = ParagraphStyle()
        
        paragraphStyle.alignment = alignment.toCacao()
        
        return paragraphStyle
    }
}

public enum NSTextAlignment: Int {
    
    case left
    case center
    case right
    case justified
    case natural
    
    public init() { self = .left }
}

extension NSTextAlignment {
    
    public func toCacao() -> TextAlignment {
        
        switch self {
            
        case .left: return .left
        case .center: return .center
        case .right: return .right
            
        default: return .left
        }
    }
}

public enum NSLineBreakMode: Int {
    
    /// Wrap at word boundaries, default
    case byWordWrapping = 0
    case byCharWrapping
    case byClipping
    case byTruncatingHead
    case byTruncatingTail
    case byTruncatingMiddle
    
    public init() { self = .byWordWrapping }
}

/*
extension NSLineBreakMode: CacaoConvertible {
    
    
}*/

/// Rendering options for a string when it is drawn.
public struct NSStringDrawingOptions: OptionSet, ExpressibleByIntegerLiteral {
    
    public var rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public init(integerLiteral value: Int) {
        self.rawValue = value
    }
    
    public init() {
        self = .usesLineFragmentOrigin
    }
}

public extension NSStringDrawingOptions {
    
    static var usesLineFragmentOrigin: NSStringDrawingOptions { NSStringDrawingOptions(rawValue: (1 << 0)) }
    static var usesFontLeading: NSStringDrawingOptions { NSStringDrawingOptions(rawValue: (1 << 1)) }
    static var usesDeviceMetrics: NSStringDrawingOptions { NSStringDrawingOptions(rawValue: (1 << 3)) }
    static var truncatesLastVisibleLine: NSStringDrawingOptions { NSStringDrawingOptions(rawValue: (1 << 5)) }
    
}
    
/// Expects `UIFont` value.
public let NSFontAttributeName = "NSFontAttributeName"
    
/// Expects `UIColor` value.
public let NSForegroundColorAttributeName = "NSForegroundColorAttributeName"
    
/// Expects `NSMutableParagraphStyle` value.
public let NSParagraphStyleAttributeName = "NSParagraphStyleAttributeName"

public extension String {
    
    /// UIKit compatility drawing
    func draw(in rect: CGRect, withAttributes attributes: [String: Any]) {
        
        guard let context = UIGraphicsGetCurrentContext()
            else { return }
        
        // get values from attributes
        let textAttributes = TextAttributes(UIKit: attributes)
        
        self.draw(in: rect, context: context, attributes: textAttributes)
    }
    
    func boundingRect(with size: CGSize, options: NSStringDrawingOptions = NSStringDrawingOptions(), attributes: [String: Any], context: NSStringDrawingContext? = nil) -> CGRect {
        
        guard let context = UIGraphicsGetCurrentContext()
            else { return CGRect.zero }
        
        let textAttributes = TextAttributes(UIKit: attributes)
        
        var textFrame = self.contentFrame(for: CGRect(origin: CGPoint(), size: size), textMatrix: context.textMatrix, attributes: textAttributes)
        
        let font = textAttributes.font
        
        let descender = (CGFloat(font.cgFont.scaledFont.descent) * font.pointSize) / CGFloat(font.cgFont.scaledFont.unitsPerEm)
        
        
        textFrame.size.height = textFrame.size.height - descender
        //textFrame.size.height -= descender // Swift 3 error
        
        return textFrame
    }
    
    func draw(in rect: CGRect, context: Silica.CGContext, attributes: TextAttributes = TextAttributes()) {
        
        // set context values
        context.setTextAttributes(attributes)
        
        // render
        let textRect = self.contentFrame(for: rect, textMatrix: context.textMatrix, attributes: attributes)
        
        context.textPosition = textRect.origin
        
        context.show(text: self)
    }
    
    func contentFrame(for bounds: CGRect, textMatrix: CGAffineTransform = .identity, attributes: TextAttributes = TextAttributes()) -> CGRect {
        
        // assume horizontal layout (not rendering non-latin languages)
        
        // calculate frame
        
        let textWidth = attributes.font.cgFont.singleLineWidth(text: self, fontSize: attributes.font.pointSize, textMatrix: textMatrix)
        
        let lines: CGFloat = 1.0
        
        let textHeight = attributes.font.pointSize * lines
        
        var textRect = CGRect(x: bounds.origin.x,
                              y: bounds.origin.y,
                              width: textWidth,
                              height: textHeight) // height == font.size
        
        switch attributes.paragraphStyle.alignment {
            
        case .left: break // always left by default
            
        case .center: textRect.origin.x = (bounds.width - textRect.width) / 2
            
        case .right: textRect.origin.x = bounds.width - textRect.width
        }
        
        return textRect
    }
}

// MARK: - Supporting Types

public struct TextAttributes {
    
    public init() { }
    
    public var font = UIFont(name: "Helvetica", size: 17)!
    
    public var color = UIColor.black
    
    public var paragraphStyle = ParagraphStyle()
}

public extension TextAttributes {
    
    init(UIKit attributes: [String: Any]) {
        
        var textAttributes = TextAttributes()
        
        if let font = attributes[NSFontAttributeName] as? UIFont {
            
            textAttributes.font = font
        }
        
        if let textColor = (attributes[NSForegroundColorAttributeName] as? UIColor) {
            
            textAttributes.color = textColor
        }
        
        if let paragraphStyle = attributes[NSParagraphStyleAttributeName] as? NSParagraphStyle {
            
            textAttributes.paragraphStyle = paragraphStyle.toCacao()
        }
        
        self = textAttributes
    }
}

public struct ParagraphStyle {
    
    public init() { }
    
    public var alignment = TextAlignment()
}

public enum TextAlignment {
    
    public init() { self = .left }
    
    case left
    case center
    case right
}

// MARK: - Extensions

public extension CGContext {
    
    func setTextAttributes(_ attributes: TextAttributes) {
        
        self.fontSize = attributes.font.pointSize
        self.setFont(attributes.font.cgFont)
        self.fillColor = attributes.color.cgColor
    }
}
