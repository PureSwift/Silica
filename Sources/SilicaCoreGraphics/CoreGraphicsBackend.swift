//
//  CoreGraphicsBackend.swift
//  SilicaCoreGraphics
//
//  Created by Alsey Coleman Miller on 7/13/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

#if canImport(CoreGraphics)

import CoreGraphics
import ImageIO
import Foundation
import Silica

/// Apple CoreGraphics (Quartz) rendering backend.
public enum CoreGraphicsBackend: SilicaBackendProtocol {

    /// Registers CoreGraphics as the default rendering backend.
    public static func register() {

        SilicaBackend.default = CoreGraphicsBackend.self
    }

    internal static func registerIfNeeded() {

        guard SilicaBackend.default == nil else { return }
        register()
    }

    // MARK: - SilicaBackendProtocol

    public static func font(named name: String) -> Silica.CGFont? {

        guard let handle = CoreTextFontHandle(name: name)
            else { return nil }

        return Silica.CGFont(name: name, family: handle.familyName, handle: handle)
    }

    public static func decodePNG(_ data: Data) -> Silica.CGImage? {

        guard let source = ImageIO.CGImageSourceCreateWithData(data as CFData, nil),
            let nativeImage = ImageIO.CGImageSourceCreateImageAtIndex(source, 0, nil)
            else { return nil }

        return Silica.CGImage(nativeImage)
    }

    public static func encodePNG(_ image: Silica.CGImage) -> Data? {

        guard let nativeImage = image.toCoreGraphics(),
            let data = CFDataCreateMutable(nil, 0),
            let destination = ImageIO.CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil)
            else { return nil }

        ImageIO.CGImageDestinationAddImage(destination, nativeImage, nil)

        guard ImageIO.CGImageDestinationFinalize(destination)
            else { return nil }

        return data as Data
    }
}

// MARK: - CGImage Conversion

public extension Silica.CGImage {

    /// Creates a Silica bitmap image from a Quartz image,
    /// normalizing the pixel format to premultiplied RGBA.
    convenience init?(_ nativeImage: CoreGraphics.CGImage) {

        let width = nativeImage.width
        let height = nativeImage.height
        let bytesPerRow = width * 4

        var data = Data(count: bytesPerRow * height)

        let rendered: Bool = data.withUnsafeMutableBytes { (buffer: UnsafeMutableRawBufferPointer) in

            guard let context = CoreGraphics.CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }

            context.draw(nativeImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }

        guard rendered
            else { return nil }

        self.init(width: width, height: height, bytesPerRow: bytesPerRow, data: data)
    }

    /// Converts to a Quartz image (zero-copy; the pixel formats match).
    func toCoreGraphics() -> CoreGraphics.CGImage? {

        guard let dataProvider = CGDataProvider(data: data as CFData)
            else { return nil }

        return CoreGraphics.CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: dataProvider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }
}

#endif // canImport(CoreGraphics)
