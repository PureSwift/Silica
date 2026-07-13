//
//  Image.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 5/11/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import struct Foundation.Data

/// Represents bitmap images and bitmap image masks, based on sample data that you supply.
/// A bitmap (or sampled) image is a rectangular array of pixels,
/// with each pixel representing a single sample or data point in a source image.
///
/// Pixel data is stored as 8-bit premultiplied RGBA, rows top-to-bottom.
public final class CGImage {

    // MARK: - Properties

    /// The width of the image, in pixels.
    public let width: Int

    /// The height of the image, in pixels.
    public let height: Int

    /// The number of bytes per row of the pixel data.
    public let bytesPerRow: Int

    /// 8-bit premultiplied RGBA pixel data, rows top-to-bottom.
    public let data: Data

    // MARK: - Initialization

    public init(width: Int, height: Int, bytesPerRow: Int, data: Data) {

        precondition(bytesPerRow >= width * 4, "Rows must fit \(width) RGBA pixels")
        precondition(data.count >= bytesPerRow * height, "Insufficient pixel data")

        self.width = width
        self.height = height
        self.bytesPerRow = bytesPerRow
        self.data = data
    }

    public convenience init(width: Int, height: Int, data: Data) {

        self.init(width: width, height: height, bytesPerRow: width * 4, data: data)
    }
}
