//
//  Image.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/11/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

#if canImport(Foundation)
import Foundation
#endif

/// A bitmap: 8-bit premultiplied RGBA pixels in sRGB, rows from the top.
public final class Image {

    /// The width, in pixels.
    public let width: Int

    /// The height, in pixels.
    public let height: Int

    /// The number of bytes in a row of pixels.
    public let bytesPerRow: Int

    /// Premultiplied RGBA, 8 bits each, rows from the top.
    public let data: Data

    /// Pixels per point.
    public let scale: Double

    public init(width: Int, height: Int, bytesPerRow: Int, data: Data, scale: Double = 1) {
        precondition(bytesPerRow >= width * 4, "Rows must fit their RGBA pixels")
        precondition(data.count >= bytesPerRow * height, "Insufficient pixel data")
        precondition(scale > 0, "The scale must be positive")
        self.width = width
        self.height = height
        self.bytesPerRow = bytesPerRow
        self.data = data
        self.scale = scale
    }

    public convenience init(width: Int, height: Int, data: Data, scale: Double = 1) {
        self.init(width: width, height: height, bytesPerRow: width * 4, data: data, scale: scale)
    }

    /// Decodes PNG data with the registered default backend.
    public convenience init?(png data: Data, scale: Double = 1) {
        guard let image = SilicaBackend.decodePNG(data) else { return nil }
        self.init(width: image.width, height: image.height, bytesPerRow: image.bytesPerRow, data: image.data, scale: scale)
    }
}

public extension Image {

    /// The size in points.
    var size: Size { Size(width: Double(width) / scale, height: Double(height) / scale) }

    /// The image encoded as PNG by the registered default backend.
    func pngData() -> Data? {
        SilicaBackend.encodePNG(self)
    }
}
