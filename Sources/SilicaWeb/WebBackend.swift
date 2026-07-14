//
//  WebBackend.swift
//  SilicaWeb
//
//  Created by Alsey Coleman Miller on 7/13/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

#if canImport(JavaScriptKit)

#if canImport(Foundation)
import Foundation
#endif

import JavaScriptKit
import Silica

/// Web Canvas rendering backend.
public enum WebBackend: SilicaBackendProtocol {

    /// Registers the Web Canvas API as the default rendering backend.
    public static func register() {

        #if canImport(Foundation)
        SilicaBackend.default = WebBackend.self
        #else
        SilicaBackend.register(WebBackend.self, name: "Web")
        #endif
    }

    internal static func registerIfNeeded() {

        guard SilicaBackend.default == nil else { return }
        register()
    }

    // MARK: - SilicaBackendProtocol

    public static func font(named name: String) -> Silica.CGFont? {

        guard let handle = WebFontHandle(name: name)
            else { return nil }

        return Silica.CGFont(name: name, family: handle.familyName, handle: handle)
    }

    /// PNG decoding is not supported: the Web platform only exposes
    /// asynchronous image decoding (`createImageBitmap`).
    ///
    /// Draw `HTMLImageElement`/`ImageBitmap` objects onto a `WebCanvasContext`'s
    /// canvas directly, or create a `CGImage` from an `ImageData` object instead.
    public static func decodePNG(_ data: Data) -> Silica.CGImage? {

        return nil
    }

    /// Encodes a bitmap image as PNG data via `canvas.toDataURL`.
    ///
    /// - Note: Requires a DOM document; returns `nil` in worker contexts, where
    ///   only the asynchronous `OffscreenCanvas.convertToBlob` is available.
    public static func encodePNG(_ image: Silica.CGImage) -> Data? {

        let document = JSObject.global.document

        guard document.isUndefined == false && document.isNull == false,
            let canvas = document.createElement("canvas").object
            else { return nil }

        canvas.width = .number(Double(image.width))
        canvas.height = .number(Double(image.height))

        guard let context = canvas.getContext!("2d").object,
            let imageData = image.makeImageData()
            else { return nil }

        _ = context.putImageData!(imageData, 0, 0)

        guard let dataURL = canvas.toDataURL!("image/png").string,
            let separator = dataURL.firstIndex(of: ","),
            let bytes = decodeBase64(dataURL[dataURL.index(after: separator)...])
            else { return nil }

        return Data(bytes)
    }
}

// MARK: - CGImage Conversion

public extension Silica.CGImage {

    /// Creates a Silica bitmap image from an `ImageData` object,
    /// normalizing the pixel format to premultiplied RGBA.
    convenience init?(_ imageData: JSObject) {

        let width = Int(imageData.width.number ?? 0)
        let height = Int(imageData.height.number ?? 0)

        guard width > 0, height > 0,
            let dataObject = imageData.data.object
            else { return nil }

        // ImageData is non-premultiplied RGBA, rows top-to-bottom
        let pixels = JSTypedArray<UInt8>(unsafelyWrapping: dataObject)

        var bytes = [UInt8](repeating: 0, count: width * height * 4)

        pixels.withUnsafeBytes { buffer in

            let count = min(buffer.count, bytes.count)

            for index in stride(from: 0, to: count, by: 4) {

                let alpha = buffer[index + 3]

                func premultiply(_ component: UInt8) -> UInt8 {
                    return UInt8((UInt16(component) * UInt16(alpha) + 127) / 255)
                }

                bytes[index]     = premultiply(buffer[index])
                bytes[index + 1] = premultiply(buffer[index + 1])
                bytes[index + 2] = premultiply(buffer[index + 2])
                bytes[index + 3] = alpha
            }
        }

        self.init(width: width, height: height, bytesPerRow: width * 4, data: Data(bytes))
    }

    /// Converts to an `ImageData` object (non-premultiplied RGBA).
    func makeImageData() -> JSObject? {

        guard let imageDataClass = JSObject.global.ImageData.function
            else { return nil }

        var bytes = [UInt8](repeating: 0, count: width * height * 4)

        for y in 0 ..< height {

            let sourceRow = y * bytesPerRow
            let destinationRow = y * width * 4

            for x in 0 ..< width {

                let source = sourceRow + x * 4
                let destination = destinationRow + x * 4

                let red   = data[data.startIndex + source]
                let green = data[data.startIndex + source + 1]
                let blue  = data[data.startIndex + source + 2]
                let alpha = data[data.startIndex + source + 3]

                // un-premultiply
                func unpremultiply(_ component: UInt8) -> UInt8 {
                    guard alpha > 0 else { return 0 }
                    return UInt8(min(255, (UInt32(component) * 255 + UInt32(alpha) / 2) / UInt32(alpha)))
                }

                bytes[destination]     = unpremultiply(red)
                bytes[destination + 1] = unpremultiply(green)
                bytes[destination + 2] = unpremultiply(blue)
                bytes[destination + 3] = alpha
            }
        }

        let typedArray = JSTypedArray<UInt8>(bytes)

        guard let clamped = JSObject.global.Uint8ClampedArray.function?.new(typedArray)
            else { return nil }

        return imageDataClass.new(clamped, width, height)
    }

    /// Renders the image into a new canvas (for `drawImage`).
    internal func makeWebCanvas() -> JSObject? {

        guard let canvas = WebCanvasContext.makeCanvas(width: width, height: height),
            let context = canvas.getContext!("2d").object,
            let imageData = makeImageData()
            else { return nil }

        _ = context.putImageData!(imageData, 0, 0)

        return canvas
    }
}

#endif // canImport(JavaScriptKit)
