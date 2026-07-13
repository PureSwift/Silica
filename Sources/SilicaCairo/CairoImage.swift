//
//  CairoImage.swift
//  SilicaCairo
//
//  Created by Alsey Coleman Miller on 7/13/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

#if canImport(Cairo)

import Cairo
import Foundation
import Silica

// MARK: - CGImage to Cairo

internal extension Cairo.Surface.Image {

    /// Creates an ARGB32 Cairo image surface from a Silica bitmap image
    /// (premultiplied RGBA, rows top-to-bottom).
    convenience init(_ image: CGImage) throws(CairoError) {

        try self.init(format: .argb32, width: image.width, height: image.height)

        let destinationStride = self.stride
        let sourceBytesPerRow = image.bytesPerRow
        let width = image.width
        let height = image.height

        image.data.withUnsafeBytes { (source: UnsafeRawBufferPointer) in

            let sourceBytes = source.baseAddress!.assumingMemoryBound(to: UInt8.self)

            _ = self.withUnsafeMutableBytes { (destination: UnsafeMutablePointer<UInt8>) in

                for y in 0 ..< height {

                    let sourceRow = sourceBytes + (y * sourceBytesPerRow)
                    let destinationRow = destination + (y * destinationStride)

                    for x in 0 ..< width {

                        let red   = sourceRow[x * 4]
                        let green = sourceRow[x * 4 + 1]
                        let blue  = sourceRow[x * 4 + 2]
                        let alpha = sourceRow[x * 4 + 3]

                        // Cairo ARGB32 is a native-endian 32-bit value (0xAARRGGBB).
                        #if _endian(big)
                        destinationRow[x * 4]     = alpha
                        destinationRow[x * 4 + 1] = red
                        destinationRow[x * 4 + 2] = green
                        destinationRow[x * 4 + 3] = blue
                        #else
                        destinationRow[x * 4]     = blue
                        destinationRow[x * 4 + 1] = green
                        destinationRow[x * 4 + 2] = red
                        destinationRow[x * 4 + 3] = alpha
                        #endif
                    }
                }
            }
        }

        self.markDirty()
    }
}

// MARK: - Cairo to CGImage

internal extension CGImage {

    /// Creates a Silica bitmap image from an ARGB32 Cairo image surface.
    convenience init?(cairo surface: Cairo.Surface.Image) {

        guard surface.format == .argb32
            else { return nil }

        surface.flush()

        let width = surface.width
        let height = surface.height
        let sourceStride = surface.stride
        let bytesPerRow = width * 4

        var data = Data(count: bytesPerRow * height)

        let copied: Void? = data.withUnsafeMutableBytes { (destination: UnsafeMutableRawBufferPointer) in

            let destinationBytes = destination.baseAddress!.assumingMemoryBound(to: UInt8.self)

            return surface.withUnsafeMutableBytes { (source: UnsafeMutablePointer<UInt8>) in

                for y in 0 ..< height {

                    let sourceRow = source + (y * sourceStride)
                    let destinationRow = destinationBytes + (y * bytesPerRow)

                    for x in 0 ..< width {

                        #if _endian(big)
                        let alpha = sourceRow[x * 4]
                        let red   = sourceRow[x * 4 + 1]
                        let green = sourceRow[x * 4 + 2]
                        let blue  = sourceRow[x * 4 + 3]
                        #else
                        let blue  = sourceRow[x * 4]
                        let green = sourceRow[x * 4 + 1]
                        let red   = sourceRow[x * 4 + 2]
                        let alpha = sourceRow[x * 4 + 3]
                        #endif

                        destinationRow[x * 4]     = red
                        destinationRow[x * 4 + 1] = green
                        destinationRow[x * 4 + 2] = blue
                        destinationRow[x * 4 + 3] = alpha
                    }
                }
            }
        }

        guard copied != nil
            else { return nil }

        self.init(width: width, height: height, bytesPerRow: bytesPerRow, data: data)
    }
}

#endif
