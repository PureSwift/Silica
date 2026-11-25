//
//  ContentMode.swift
//  SilicaTestSupport
//
//  Created by Alsey Coleman Miller on 11/25/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

import Silica

/// How content of a size is laid out in bounds, as UIKit's content modes do.
public enum ContentMode: CaseIterable, Sendable {
    case scaleToFill
    case scaleAspectFit
    case scaleAspectFill
    case center
    case top
    case bottom
    case left
    case right
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

public extension Rect {

    /// Where content of `size` goes in `bounds` for a content mode.
    init(contentMode: ContentMode, bounds: Rect, size: Size) {
        switch contentMode {
        case .scaleToFill:
            self.init(origin: .zero, size: bounds.size)
        case .scaleAspectFit, .scaleAspectFill:
            let widthRatio = bounds.width / size.width
            let heightRatio = bounds.height / size.height
            let fit = contentMode == .scaleAspectFit
            var newSize = bounds.size
            if fit ? widthRatio < heightRatio : widthRatio > heightRatio {
                newSize.height = bounds.size.width / size.width * size.height
            } else if fit ? heightRatio < widthRatio : heightRatio > widthRatio {
                newSize.width = bounds.size.height / size.height * size.width
            }
            newSize = Size(width: newSize.width.rounded(.up), height: newSize.height.rounded(.up))
            let origin = fit ? bounds.origin : .zero
            self.init(x: origin.x + (bounds.size.width - newSize.width) / 2,
                      y: origin.y + (bounds.size.height - newSize.height) / 2,
                      width: newSize.width, height: newSize.height)
        default:
            let free = Size(width: bounds.size.width - size.width, height: bounds.size.height - size.height)
            let x: Double, y: Double
            switch contentMode {
            case .top: (x, y) = (free.width / 2, 0)
            case .bottom: (x, y) = (free.width / 2, free.height)
            case .left: (x, y) = (0, free.height / 2)
            case .right: (x, y) = (free.width, free.height / 2)
            case .topLeft: (x, y) = (0, 0)
            case .topRight: (x, y) = (free.width, 0)
            case .bottomLeft: (x, y) = (0, free.height)
            case .bottomRight: (x, y) = (free.width, free.height)
            default: (x, y) = (free.width / 2, free.height / 2)
            }
            self.init(x: x, y: y, width: size.width, height: size.height)
        }
    }
}
