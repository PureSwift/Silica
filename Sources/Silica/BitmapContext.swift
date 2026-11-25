//
//  BitmapContext.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 11/25/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

#if canImport(Foundation)
import Foundation
#endif

/// A context drawing into pixels off screen, from the registered default backend.
public final class BitmapContext: GraphicsContext {

    /// Pixels per point.
    public let scale: Double

    /// A bitmap `width` by `height` points, `scale` pixels per point.
    /// Nil without a default backend, or when it refuses the size.
    public init?(width: Double, height: Double, scale: Double = 1, origin: Origin = .topLeft) {
        guard width > 0, height > 0, scale > 0,
              let renderer = SilicaBackend.makeBitmapRenderer(size: Size(width: width, height: height), scale: scale)
        else { return nil }
        self.scale = scale
        super.init(renderer, origin: origin)
    }

    /// Premultiplied RGBA, 8 bits each, rows from the top: `width * scale`
    /// by `height * scale` pixels, rounded up.
    public var pixels: Data? {
        makeImage()?.data
    }

    /// The bitmap as PNG.
    public func png() -> Data? {
        makeImage()?.pngData()
    }
}
