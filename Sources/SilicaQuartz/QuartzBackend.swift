//
//  QuartzBackend.swift
//  SilicaQuartz
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
/// The Quartz rendering backend: fonts from Core Text, PNG codecs from
/// ImageIO, and bitmaps from Core Graphics.
public enum QuartzBackend: SilicaBackendProtocol {

    /// Makes Quartz the default rendering backend.
    public static func register() {
        SilicaBackend.register(QuartzBackend.self, name: "Quartz")
    }

    internal static func registerIfNeeded() {
        SilicaBackend.registerIfNeeded(QuartzBackend.self, name: "Quartz")
    }

    // MARK: - SilicaBackendProtocol

    public static func fontFace(named name: String) -> (any FontFace)? {
        CoreTextFontHandle(name: name)
    }

    public static func decodePNG(_ data: Data) -> Silica.Image? {
        guard let source = ImageIO.CGImageSourceCreateWithData(data as CFData, nil),
            let nativeImage = ImageIO.CGImageSourceCreateImageAtIndex(source, 0, nil)
            else { return nil }
        return Silica.Image(nativeImage)
    }

    public static func encodePNG(_ image: Silica.Image) -> Data? {
        guard let nativeImage = image.toCoreGraphics(),
            let data = CFDataCreateMutable(nil, 0),
            let destination = ImageIO.CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil)
            else { return nil }
        ImageIO.CGImageDestinationAddImage(destination, nativeImage, nil)
        guard ImageIO.CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    public static func makeBitmapRenderer(size: Size, scale: Double) -> (any Renderer)? {
        try? QuartzRenderer(bitmap: size, scale: scale)
    }
}

public extension Silica.Image {

    /// An image of a Quartz image's pixels,
    /// normalizing the pixel format to premultiplied RGBA.
    convenience init?(_ nativeImage: CoreGraphics.CGImage, scale: Double = 1) {

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

        self.init(width: width, height: height, bytesPerRow: bytesPerRow, data: data, scale: scale)
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
