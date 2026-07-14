//
//  NSStringDrawing.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 5/30/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

#if canImport(Foundation)
import Foundation
#endif

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

    #if canImport(Foundation)
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

        let wraps = options.contains(.usesLineFragmentOrigin)

        var textFrame = self.contentFrame(for: CGRect(origin: CGPoint(), size: size), textMatrix: context.textMatrix, attributes: textAttributes, wraps: wraps)

        let font = textAttributes.font

        let descender = font.cgFont.descent * font.pointSize


        textFrame.size.height = textFrame.size.height - descender
        //textFrame.size.height -= descender // Swift 3 error

        return textFrame
    }
    #endif

    func draw(in rect: CGRect, context: Silica.CGContext, attributes: TextAttributes = TextAttributes()) {

        // set context values
        context.setTextAttributes(attributes)

        // word-wrap into lines that fit the bounding rect's width
        let lines = self.wrappedLines(maxWidth: rect.width, attributes: attributes, textMatrix: context.textMatrix)

        let lineHeight = attributes.font.pointSize

        for (index, line) in lines.enumerated() {

            let lineWidth = attributes.font.cgFont.singleLineWidth(text: line, fontSize: attributes.font.pointSize, textMatrix: context.textMatrix)

            var x = rect.origin.x

            switch attributes.paragraphStyle.alignment {

            case .left: break // always left by default

            case .center: x = rect.origin.x + (rect.width - lineWidth) / 2

            case .right: x = rect.origin.x + (rect.width - lineWidth)
            }

            context.textPosition = CGPoint(x: x, y: rect.origin.y + (CGFloat(index) * lineHeight))

            context.show(text: line)
        }
    }

    func contentFrame(for bounds: CGRect, textMatrix: CGAffineTransform = .identity, attributes: TextAttributes = TextAttributes(), wraps: Bool = true) -> CGRect {

        // assume horizontal layout (not rendering non-latin languages)

        // calculate frame

        let lines = wraps ? self.wrappedLines(maxWidth: bounds.width, attributes: attributes, textMatrix: textMatrix) : [self]

        let textWidth = lines
            .map { attributes.font.cgFont.singleLineWidth(text: $0, fontSize: attributes.font.pointSize, textMatrix: textMatrix) }
            .max() ?? 0

        let textHeight = attributes.font.pointSize * CGFloat(lines.count)

        var textRect = CGRect(x: bounds.origin.x,
                              y: bounds.origin.y,
                              width: textWidth,
                              height: textHeight) // height == font.size * number of lines

        switch attributes.paragraphStyle.alignment {

        case .left: break // always left by default

        case .center: textRect.origin.x = (bounds.width - textRect.width) / 2

        case .right: textRect.origin.x = bounds.width - textRect.width
        }

        return textRect
    }

    /// Breaks the string into lines that fit within `maxWidth`, wrapping at word boundaries.
    ///
    /// Explicit `"\n"` characters always force a line break. A `maxWidth <= 0` disables
    /// wrapping (matches the historical single-line behavior for unbounded / zero-size rects).
    func wrappedLines(maxWidth: CGFloat, attributes: TextAttributes, textMatrix: CGAffineTransform) -> [String] {

        guard maxWidth > 0, self.isEmpty == false
            else { return [self] }

        let font = attributes.font.cgFont
        let fontSize = attributes.font.pointSize

        var resultLines: [String] = []

        for paragraph in self.split(separator: "\n", omittingEmptySubsequences: false) {

            guard paragraph.isEmpty == false else {
                resultLines.append("")
                continue
            }

            var currentLine = ""

            for word in paragraph.split(separator: " ", omittingEmptySubsequences: false) {

                let candidate = currentLine.isEmpty ? String(word) : currentLine + " " + String(word)

                let candidateWidth = font.singleLineWidth(text: candidate, fontSize: fontSize, textMatrix: textMatrix)

                if candidateWidth <= maxWidth || currentLine.isEmpty {

                    currentLine = candidate

                } else {

                    resultLines.append(currentLine)
                    currentLine = String(word)
                }
            }

            resultLines.append(currentLine)
        }

        return resultLines
    }
}

// MARK: - Supporting Types

public struct TextAttributes {
    
    public init() { }
    
    public var font = UIFont(name: "Helvetica", size: 17)!
    
    public var color = UIColor.black
    
    public var paragraphStyle = ParagraphStyle()
}

#if canImport(Foundation)
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
#endif

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
