//
//  ImageAPI.swift
//  SilicaCoreGraphicsABI
//
//  Created by Alsey Coleman Miller on 11/25/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

// Apple's CoreGraphics is loaded with Foundation on Darwin, and clashes with
// these headers: libCoreGraphics is for other platforms.
#if !canImport(Darwin)

import CSilicaCoreGraphics
import Silica
import struct Foundation.Data

#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#endif

// The functions of CGImage.h, and the pixel formats images and bitmap contexts share.

// MARK: - Pixel Formats

/// How a bitmap's pixels lie in memory, 8 bits a component.
internal struct PixelFormat: Equatable {

    enum Alpha: Equatable {
        /// No alpha: opaque.
        case none
        /// A byte that's ignored: opaque.
        case skip
        /// Alpha, with the colors multiplied by it.
        case premultiplied
        /// Alpha, with the colors as they are.
        case straight
    }

    enum Layout: Equatable {
        /// Color components and alpha, each a byte at its offset in the pixel.
        case rgb(red: Int, green: Int, blue: Int, alpha: Int?)
        /// A gray byte, then alpha if there is any.
        case gray(alpha: Int?)
        /// Alpha alone.
        case alphaOnly
    }

    let bitmapInfo: UInt32

    let bitsPerPixel: Int

    let layout: Layout

    let alpha: Alpha

    /// The format of a CoreGraphics bitmap, or nil for one Silica doesn't read
    /// or write.
    init?(bitsPerComponent: Int, bitsPerPixel: Int, model: ColorSpaceObject.Model?, bitmapInfo: UInt32) {
        guard bitsPerComponent == 8, bitmapInfo & 0xF00 == 0 else { return nil }
        let alphaInfo = bitmapInfo & 0x1F
        let byteOrder = bitmapInfo & 0x7000
        self.bitmapInfo = bitmapInfo
        self.bitsPerPixel = bitsPerPixel
        switch alphaInfo {
        case 0: alpha = .none
        case 1, 2: alpha = .premultiplied
        case 3, 4: alpha = .straight
        case 5, 6: alpha = .skip
        case 7: alpha = .premultiplied
        default: return nil
        }
        if alphaInfo == 7 {
            guard bitsPerPixel == 8 else { return nil }
            layout = .alphaOnly
            return
        }
        switch model {
        case .rgb?:
            if alphaInfo == 0 {
                guard bitsPerPixel == 24, byteOrder == 0 else { return nil }
                layout = .rgb(red: 0, green: 1, blue: 2, alpha: nil)
                return
            }
            guard bitsPerPixel == 32, byteOrder == 0 || byteOrder == 0x2000 || byteOrder == 0x4000 else { return nil }
            // in the order named, alpha first (A R G B) or last (R G B A): the bytes of a big-endian
            // word, which the default byte order is
            let first = alphaInfo == 2 || alphaInfo == 4 || alphaInfo == 6
            var offsets = first ? [1, 2, 3, 0] : [0, 1, 2, 3]
            // a little-endian word reverses the bytes
            if byteOrder == 0x2000 {
                offsets = offsets.map { 3 - $0 }
            }
            layout = .rgb(red: offsets[0], green: offsets[1], blue: offsets[2], alpha: offsets[3])
        case .gray?:
            switch (alphaInfo, bitsPerPixel) {
            case (0, 8): layout = .gray(alpha: nil)
            case (1, 16), (3, 16), (5, 16): layout = .gray(alpha: 1)
            case (2, 16), (4, 16), (6, 16):
                // alpha first: the gray byte after it; Silica reads the gray at offset 1
                layout = .gray(alpha: 0)
            default: return nil
            }
        default:
            return nil
        }
    }

    var bytesPerPixel: Int { bitsPerPixel / 8 }

    var alphaInfo: UInt32 { bitmapInfo & 0x1F }

    /// Whether this is Cairo's own layout: premultiplied (or skipped) alpha
    /// and color in a 32-bit word of the host's byte order, 0xAARRGGBB.
    var isCairoNative: Bool {
        guard alpha == .premultiplied || alpha == .skip,
              case let .rgb(red, green, blue, alpha?) = layout else { return false }
        let native = 1.littleEndian == 1 ? (red: 2, green: 1, blue: 0, alpha: 3) : (red: 1, green: 2, blue: 3, alpha: 0)
        return red == native.red && green == native.green && blue == native.blue && alpha == native.alpha
    }

    /// A pixel as premultiplied red, green, blue and alpha.
    func read(_ pixel: UnsafeRawPointer) -> (UInt8, UInt8, UInt8, UInt8) {
        let bytes = pixel.assumingMemoryBound(to: UInt8.self)
        var red: UInt8, green: UInt8, blue: UInt8, opacity: UInt8
        switch layout {
        case let .rgb(r, g, b, a):
            red = bytes[r]; green = bytes[g]; blue = bytes[b]
            opacity = a.map { bytes[$0] } ?? 255
        case let .gray(a):
            let grayOffset = a == 0 ? 1 : 0
            red = bytes[grayOffset]; green = red; blue = red
            opacity = a.map { bytes[$0] } ?? 255
        case .alphaOnly:
            return (0, 0, 0, bytes[0])
        }
        switch alpha {
        case .none, .skip:
            opacity = 255
        case .straight:
            red = premultiply(red, opacity); green = premultiply(green, opacity); blue = premultiply(blue, opacity)
        case .premultiplied:
            break
        }
        return (red, green, blue, opacity)
    }

    /// Writes a pixel of premultiplied red, green, blue and alpha.
    func write(_ value: (UInt8, UInt8, UInt8, UInt8), to pixel: UnsafeMutableRawPointer) {
        let bytes = pixel.assumingMemoryBound(to: UInt8.self)
        var (red, green, blue, opacity) = value
        if alpha == .straight {
            red = unpremultiply(red, opacity); green = unpremultiply(green, opacity); blue = unpremultiply(blue, opacity)
        }
        switch layout {
        case let .rgb(r, g, b, a):
            bytes[r] = red; bytes[g] = green; bytes[b] = blue
            // an ignored byte gets the coverage, as CoreGraphics writes it
            if let a { bytes[a] = opacity }
        case let .gray(a):
            let gray = UInt8((grayLevel(red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255) * 255).rounded())
            bytes[a == 0 ? 1 : 0] = gray
            if let a { bytes[a] = opacity }
        case .alphaOnly:
            bytes[0] = opacity
        }
    }
}

/// The gray of an sRGB color, as CoreGraphics converts it: its luminance in
/// linear light (with D50-adapted coefficients), encoded as sRGB is.
internal func grayLevel(red: Double, green: Double, blue: Double) -> Double {
    func linear(_ value: Double) -> Double {
        value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }
    let luminance = 0.2225 * linear(red) + 0.7169 * linear(green) + 0.0606 * linear(blue)
    let encoded = luminance <= 0.0031308 ? luminance * 12.92 : 1.055 * pow(luminance, 1 / 2.4) - 0.055
    return min(max(encoded, 0), 1)
}

private func premultiply(_ component: UInt8, _ alpha: UInt8) -> UInt8 {
    UInt8((Int(component) * Int(alpha) + 127) / 255)
}

private func unpremultiply(_ component: UInt8, _ alpha: UInt8) -> UInt8 {
    guard alpha > 0 else { return 0 }
    return UInt8(min(255, (Int(component) * 255 + Int(alpha) / 2) / Int(alpha)))
}

// MARK: - Images

/// What a `CGImageRef` points to: pixels of a format, rows from the top.
internal final class ImageObject {

    let width: Int
    let height: Int
    let bitsPerComponent: Int
    let bytesPerRow: Int
    let format: PixelFormat
    let space: Retained?
    let data: [UInt8]
    let shouldInterpolate: Bool
    let renderingIntent: Int32

    init(width: Int, height: Int, bitsPerComponent: Int, bytesPerRow: Int, format: PixelFormat,
         space: OpaquePointer?, data: [UInt8], shouldInterpolate: Bool = true, renderingIntent: Int32 = 0) {
        self.width = width
        self.height = height
        self.bitsPerComponent = bitsPerComponent
        self.bytesPerRow = bytesPerRow
        self.format = format
        self.space = space.map(Retained.init)
        self.data = data
        self.shouldInterpolate = shouldInterpolate
        self.renderingIntent = renderingIntent
    }

    /// A provider of the pixels, made once.
    lazy var provider: Retained = {
        let reference = makeReference(DataProviderObject(bytes: data))
        let retained = Retained(reference)
        release(reference)
        return retained
    }()

    /// The image as Silica draws it: premultiplied RGBA, made once.
    lazy var silica: Silica.Image = {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        data.withUnsafeBytes { source in
            for y in 0 ..< height {
                for x in 0 ..< width {
                    let (r, g, b, a) = format.read(source.baseAddress! + y * bytesPerRow + x * format.bytesPerPixel)
                    let offset = (y * width + x) * 4
                    pixels[offset] = r; pixels[offset + 1] = g; pixels[offset + 2] = b; pixels[offset + 3] = a
                }
            }
        }
        return Silica.Image(width: width, height: height, data: Data(pixels))
    }()
}

@c @implementation public func CGImageGetTypeID() -> UInt {
    CoreGraphicsObjects.typeID(of: .image)
}

@c @implementation public func CGImageRetain(_ image: SilicaCGImageRef?) -> SilicaCGImageRef? {
    retain(image)
    return image
}

@c @implementation public func CGImageRelease(_ image: SilicaCGImageRef?) {
    release(image)
}

@c @implementation public func CGImageCreate(_ width: Int, _ height: Int, _ bitsPerComponent: Int, _ bitsPerPixel: Int,
                                             _ bytesPerRow: Int, _ space: SilicaCGColorSpaceRef?, _ bitmapInfo: CGBitmapInfo,
                                             _ provider: SilicaCGDataProviderRef?, _ decode: UnsafePointer<Double>?,
                                             _ shouldInterpolate: Bool, _ intent: CGColorRenderingIntent) -> SilicaCGImageRef? {
    guard width > 0, height > 0, let provider = object(provider, as: DataProviderObject.self) else { return nil }
    let alphaOnly = bitmapInfo & 0x1F == 7
    let model = object(space, as: ColorSpaceObject.self)?.model
    guard alphaOnly || model != nil,
          let format = PixelFormat(bitsPerComponent: bitsPerComponent, bitsPerPixel: bitsPerPixel,
                                   model: alphaOnly ? nil : model, bitmapInfo: bitmapInfo),
          bytesPerRow >= width * format.bytesPerPixel else { return nil }
    // the last row needs only its pixels
    let needed = bytesPerRow * (height - 1) + width * format.bytesPerPixel
    guard provider.count >= needed else { return nil }
    let data = provider.withUnsafeBytes { bytes in
        [UInt8](bytes.prefix(min(bytes.count, bytesPerRow * height))) + [UInt8](repeating: 0, count: max(0, bytesPerRow * height - bytes.count))
    }
    return makeReference(ImageObject(width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow,
                                     format: format, space: space, data: data, shouldInterpolate: shouldInterpolate,
                                     renderingIntent: intent))
}

/// The same image: images don't change, so the copy is the image, retained.
@c @implementation public func CGImageCreateCopy(_ image: SilicaCGImageRef?) -> SilicaCGImageRef? {
    retain(image)
    return image
}

@c @implementation public func CGImageCreateWithImageInRect(_ image: SilicaCGImageRef?, _ rect: CGRect) -> SilicaCGImageRef? {
    guard let source = object(image, as: ImageObject.self) else { return nil }
    let bounds = Silica.Rect(x: 0, y: 0, width: Double(source.width), height: Double(source.height))
    let crop = rect.silica.standardized.integral.intersection(bounds)
    guard crop.isNull == false, crop.width > 0, crop.height > 0 else { return nil }
    let x = Int(crop.minX), y = Int(crop.minY), width = Int(crop.width), height = Int(crop.height)
    let rowBytes = width * source.format.bytesPerPixel
    var data = [UInt8]()
    data.reserveCapacity(rowBytes * height)
    for row in y ..< y + height {
        let start = row * source.bytesPerRow + x * source.format.bytesPerPixel
        data.append(contentsOf: source.data[start ..< start + rowBytes])
    }
    return makeReference(ImageObject(width: width, height: height, bitsPerComponent: source.bitsPerComponent, bytesPerRow: rowBytes,
                                     format: source.format, space: source.space?.reference, data: data,
                                     shouldInterpolate: source.shouldInterpolate, renderingIntent: source.renderingIntent))
}

@c @implementation public func CGImageGetWidth(_ image: SilicaCGImageRef?) -> Int {
    object(image, as: ImageObject.self)?.width ?? 0
}

@c @implementation public func CGImageGetHeight(_ image: SilicaCGImageRef?) -> Int {
    object(image, as: ImageObject.self)?.height ?? 0
}

@c @implementation public func CGImageGetBitsPerComponent(_ image: SilicaCGImageRef?) -> Int {
    object(image, as: ImageObject.self)?.bitsPerComponent ?? 0
}

@c @implementation public func CGImageGetBitsPerPixel(_ image: SilicaCGImageRef?) -> Int {
    object(image, as: ImageObject.self)?.format.bitsPerPixel ?? 0
}

@c @implementation public func CGImageGetBytesPerRow(_ image: SilicaCGImageRef?) -> Int {
    object(image, as: ImageObject.self)?.bytesPerRow ?? 0
}

@c @implementation public func CGImageGetColorSpace(_ image: SilicaCGImageRef?) -> SilicaCGColorSpaceRef? {
    object(image, as: ImageObject.self)?.space?.reference
}

@c @implementation public func CGImageGetAlphaInfo(_ image: SilicaCGImageRef?) -> CGImageAlphaInfo {
    object(image, as: ImageObject.self)?.format.alphaInfo ?? 0
}

@c @implementation public func CGImageGetBitmapInfo(_ image: SilicaCGImageRef?) -> CGBitmapInfo {
    object(image, as: ImageObject.self)?.format.bitmapInfo ?? 0
}

@c @implementation public func CGImageGetByteOrderInfo(_ image: SilicaCGImageRef?) -> CGImageByteOrderInfo {
    (object(image, as: ImageObject.self)?.format.bitmapInfo ?? 0) & 0x7000
}

@c @implementation public func CGImageGetShouldInterpolate(_ image: SilicaCGImageRef?) -> Bool {
    object(image, as: ImageObject.self)?.shouldInterpolate ?? false
}

@c @implementation public func CGImageGetRenderingIntent(_ image: SilicaCGImageRef?) -> CGColorRenderingIntent {
    object(image, as: ImageObject.self)?.renderingIntent ?? 0
}

/// A provider of the image's pixels, which the image keeps.
@c @implementation public func CGImageGetDataProvider(_ image: SilicaCGImageRef?) -> SilicaCGDataProviderRef? {
    object(image, as: ImageObject.self)?.provider.reference
}

/// Silica's images are never masks yet.
@c @implementation public func CGImageIsMask(_ image: SilicaCGImageRef?) -> Bool {
    false
}

#endif
