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
#if canImport(Cairo)
import Cairo
import CCairo
#endif

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
        // 8 bits a component, of integers, packed
        guard bitsPerComponent == 8, bitmapInfo & 0xF00 == 0, bitmapInfo & 0xF0000 == 0 else { return nil }
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

/// What a `CGImageRef` points to: pixels of a format, rows from the top, or
/// an image mask's samples.
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

    /// An image mask's bits a sample, or nil for an image.
    let maskBits: Int?

    /// The mask an image is masked by.
    let mask: ImageObject?

    /// The decode array, where `CGImageGetDecode` points.
    let decode: UnsafeMutableBufferPointer<Double>?

    /// Each color component's lowest and highest sample values where the
    /// image is transparent: all of them must be within theirs.
    let maskingColors: [Double]?

    init(width: Int, height: Int, bitsPerComponent: Int, bytesPerRow: Int, format: PixelFormat,
         space: OpaquePointer?, data: [UInt8], shouldInterpolate: Bool = true, renderingIntent: Int32 = 0,
         maskBits: Int? = nil, mask: ImageObject? = nil, decode: [Double]? = nil, maskingColors: [Double]? = nil) {
        self.maskingColors = maskingColors
        self.width = width
        self.height = height
        self.bitsPerComponent = bitsPerComponent
        self.bytesPerRow = bytesPerRow
        self.format = format
        self.space = space.map(Retained.init)
        self.data = data
        self.shouldInterpolate = shouldInterpolate
        self.renderingIntent = renderingIntent
        self.maskBits = maskBits
        self.mask = mask
        self.decode = decode.map { values in
            let buffer = UnsafeMutableBufferPointer<Double>.allocate(capacity: values.count)
            _ = buffer.initialize(from: values)
            return buffer
        }
    }

    deinit {
        decode?.deallocate()
    }

    var isMask: Bool { maskBits != nil }

    /// How much of each pixel the image lets through as a mask, a byte a
    /// pixel, rows from the top: an image mask where its samples are 0 (after
    /// decoding), a gray image as its gray, an alpha-only image as its alpha.
    lazy var coverage: [UInt8] = {
        var bytes = [UInt8](repeating: 0, count: width * height)
        if let bits = maskBits {
            let maximum = Double((1 << bits) - 1)
            let low = decode?[0] ?? 0, high = decode?[1] ?? 1
            for y in 0 ..< height {
                for x in 0 ..< width {
                    let bit = x * bits
                    let byte = data[y * bytesPerRow + bit / 8]
                    let sample = Int(byte) >> (8 - bits - bit % 8) & ((1 << bits) - 1)
                    let value = low + Double(sample) / maximum * (high - low)
                    bytes[y * width + x] = UInt8((min(max(1 - value, 0), 1) * 255).rounded())
                }
            }
            return bytes
        }
        data.withUnsafeBytes { source in
            for y in 0 ..< height {
                for x in 0 ..< width {
                    let (r, g, b, a) = format.read(source.baseAddress! + y * bytesPerRow + x * format.bytesPerPixel)
                    let value: UInt8
                    switch format.layout {
                    case .alphaOnly: value = a
                    case .gray: value = r
                    case .rgb: value = UInt8((grayLevel(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255) * 255).rounded())
                    }
                    bytes[y * width + x] = value
                }
            }
        }
        return bytes
    }()

    /// A provider of the pixels, made once.
    lazy var provider: Retained = {
        let reference = makeReference(DataProviderObject(bytes: data))
        let retained = Retained(reference)
        release(reference)
        return retained
    }()

    /// The image as Silica draws it: premultiplied RGBA, made once. An image
    /// mask is black where it lets through; a masked image, transparent where
    /// its mask doesn't.
    lazy var silica: Silica.Image = {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        if isMask {
            for (index, alpha) in coverage.enumerated() {
                pixels[index * 4 + 3] = alpha
            }
            return Silica.Image(width: width, height: height, data: Data(pixels))
        }
        data.withUnsafeBytes { source in
            for y in 0 ..< height {
                for x in 0 ..< width {
                    let (r, g, b, a) = format.read(source.baseAddress! + y * bytesPerRow + x * format.bytesPerPixel)
                    let offset = (y * width + x) * 4
                    pixels[offset] = r; pixels[offset + 1] = g; pixels[offset + 2] = b; pixels[offset + 3] = a
                }
            }
        }
        if let ranges = maskingColors {
            // the image has no alpha, so its pixels are its samples
            for offset in Swift.stride(from: 0, to: pixels.count, by: 4) {
                let samples: [UInt8]
                switch format.layout {
                case .gray: samples = [pixels[offset]]
                default: samples = [pixels[offset], pixels[offset + 1], pixels[offset + 2]]
                }
                let masked = samples.enumerated().allSatisfy { index, sample in
                    Double(sample) >= ranges[index * 2] && Double(sample) <= ranges[index * 2 + 1]
                }
                if masked {
                    for component in offset ..< offset + 4 { pixels[component] = 0 }
                }
            }
        }
        if let mask {
            // the mask's nearest sample, scaled to the image
            let coverage = mask.coverage
            for y in 0 ..< height {
                let maskY = min(y * mask.height / height, mask.height - 1)
                for x in 0 ..< width {
                    let maskX = min(x * mask.width / width, mask.width - 1)
                    let scale = Int(coverage[maskY * mask.width + maskX])
                    let offset = (y * width + x) * 4
                    for component in offset ..< offset + 4 {
                        pixels[component] = UInt8((Int(pixels[component]) * scale + 127) / 255)
                    }
                }
            }
        }
        return Silica.Image(width: width, height: height, data: Data(pixels))
    }()

    #if canImport(Cairo)
    /// The coverage as a Cairo alpha surface, to clip to.
    func maskSurface() -> Cairo.Surface.Image? {
        guard let surface = try? Cairo.Surface.Image(format: .a8, width: width, height: height) else { return nil }
        let stride = surface.stride
        let coverage = self.coverage
        _ = surface.withUnsafeMutableBytes { pixels in
            for y in 0 ..< height {
                for x in 0 ..< width {
                    pixels[y * stride + x] = coverage[y * width + x]
                }
            }
        }
        surface.markDirty()
        return surface
    }
    #endif
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
    // two values a color component
    let components = alphaOnly ? 1 : object(space, as: ColorSpaceObject.self)?.numberOfComponents ?? 0
    let decodeValues = decode.map { decode in (0 ..< components * 2).map { decode[$0] } }
    // the last row needs only its pixels
    let needed = bytesPerRow * (height - 1) + width * format.bytesPerPixel
    guard provider.count >= needed else { return nil }
    let data = provider.withUnsafeBytes { bytes in
        [UInt8](bytes.prefix(min(bytes.count, bytesPerRow * height))) + [UInt8](repeating: 0, count: max(0, bytesPerRow * height - bytes.count))
    }
    return makeReference(ImageObject(width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow,
                                     format: format, space: space, data: data, shouldInterpolate: shouldInterpolate,
                                     renderingIntent: intent, decode: decodeValues))
}

@c @implementation public func CGImageMaskCreate(_ width: Int, _ height: Int, _ bitsPerComponent: Int, _ bitsPerPixel: Int,
                                                 _ bytesPerRow: Int, _ provider: SilicaCGDataProviderRef?,
                                                 _ decode: UnsafePointer<Double>?, _ shouldInterpolate: Bool) -> SilicaCGImageRef? {
    guard width > 0, height > 0, [1, 2, 4, 8].contains(bitsPerComponent), bitsPerPixel == bitsPerComponent,
          bytesPerRow >= (width * bitsPerPixel + 7) / 8,
          let provider = object(provider, as: DataProviderObject.self) else { return nil }
    let needed = bytesPerRow * (height - 1) + (width * bitsPerPixel + 7) / 8
    guard provider.count >= needed else { return nil }
    let data = provider.withUnsafeBytes { bytes in
        [UInt8](bytes.prefix(min(bytes.count, bytesPerRow * height))) + [UInt8](repeating: 0, count: max(0, bytesPerRow * height - bytes.count))
    }
    // a mask's pixels as an alpha-only format's, for what reads them as bytes
    let format = PixelFormat(bitsPerComponent: 8, bitsPerPixel: 8, model: nil, bitmapInfo: CGBitmapInfo(kCGImageAlphaOnly))!
    return makeReference(ImageObject(width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow,
                                     format: format, space: nil, data: data, shouldInterpolate: shouldInterpolate,
                                     maskBits: bitsPerPixel, decode: decode.map { [$0[0], $0[1]] }))
}

/// The image in a space of as many components.
@c @implementation public func CGImageCreateCopyWithColorSpace(_ image: SilicaCGImageRef?, _ space: SilicaCGColorSpaceRef?) -> SilicaCGImageRef? {
    guard let source = object(image, as: ImageObject.self), source.isMask == false, let space,
          let target = object(space, as: ColorSpaceObject.self),
          let current = source.space.flatMap({ object($0.reference, as: ColorSpaceObject.self) }),
          target.numberOfComponents == current.numberOfComponents,
          target.model == current.model || (target.model != .indexed && target.model != .pattern) else { return nil }
    return makeReference(ImageObject(width: source.width, height: source.height, bitsPerComponent: source.bitsPerComponent,
                                     bytesPerRow: source.bytesPerRow, format: source.format, space: space, data: source.data,
                                     shouldInterpolate: source.shouldInterpolate, renderingIntent: source.renderingIntent,
                                     mask: source.mask, decode: source.decode.map(Array.init),
                                     maskingColors: source.maskingColors))
}

/// An image without alpha, transparent where its color is in the ranges.
@c @implementation public func CGImageCreateWithMaskingColors(_ image: SilicaCGImageRef?, _ components: UnsafePointer<Double>?) -> SilicaCGImageRef? {
    guard let source = object(image, as: ImageObject.self), source.isMask == false, source.mask == nil,
          source.maskingColors == nil, let components,
          source.format.alpha == .none || source.format.alpha == .skip,
          let space = source.space.flatMap({ object($0.reference, as: ColorSpaceObject.self) }) else { return nil }
    let ranges = (0 ..< space.numberOfComponents * 2).map { components[$0] }
    return makeReference(ImageObject(width: source.width, height: source.height, bitsPerComponent: source.bitsPerComponent,
                                     bytesPerRow: source.bytesPerRow, format: source.format, space: source.space?.reference,
                                     data: source.data, shouldInterpolate: source.shouldInterpolate,
                                     renderingIntent: source.renderingIntent, decode: source.decode.map(Array.init),
                                     maskingColors: ranges))
}

/// An image masked by an image mask, or by a gray (or alpha-only) image.
@c @implementation public func CGImageCreateWithMask(_ image: SilicaCGImageRef?, _ mask: SilicaCGImageRef?) -> SilicaCGImageRef? {
    guard let source = object(image, as: ImageObject.self), source.isMask == false,
          let mask = object(mask, as: ImageObject.self), mask.mask == nil else { return nil }
    if mask.isMask == false {
        switch mask.format.layout {
        case .gray(alpha: nil), .alphaOnly: break
        default: return nil
        }
    }
    return makeReference(ImageObject(width: source.width, height: source.height, bitsPerComponent: source.bitsPerComponent,
                                     bytesPerRow: source.bytesPerRow, format: source.format, space: source.space?.reference,
                                     data: source.data, shouldInterpolate: source.shouldInterpolate,
                                     renderingIntent: source.renderingIntent, mask: mask,
                                     decode: source.decode.map(Array.init)))
}

/// The same image: images don't change, so the copy is the image, retained.
@c @implementation public func CGImageCreateCopy(_ image: SilicaCGImageRef?) -> SilicaCGImageRef? {
    retain(image)
    return image
}

@c @implementation public func CGImageCreateWithImageInRect(_ image: SilicaCGImageRef?, _ rect: CGRect) -> SilicaCGImageRef? {
    // a mask's samples aren't whole bytes, nor is a masked image's mask cropped with it
    guard let source = object(image, as: ImageObject.self), source.isMask == false, source.mask == nil else { return nil }
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
                                     shouldInterpolate: source.shouldInterpolate, renderingIntent: source.renderingIntent,
                                     decode: source.decode.map(Array.init)))
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
    guard let image = object(image, as: ImageObject.self) else { return 0 }
    return image.maskBits ?? image.format.bitsPerPixel
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

@c @implementation public func CGImageIsMask(_ image: SilicaCGImageRef?) -> Bool {
    object(image, as: ImageObject.self)?.isMask ?? false
}

@c @implementation public func CGImageGetPixelFormatInfo(_ image: SilicaCGImageRef?) -> CGImagePixelFormatInfo {
    (object(image, as: ImageObject.self)?.format.bitmapInfo ?? 0) & 0xF0000
}

/// Silica reads no image files with ImageIO.
@c @implementation public func CGImageGetUTType(_ image: SilicaCGImageRef?) -> SilicaCFStringRef? {
    nil
}

@c @implementation public func CGImageGetDecode(_ image: SilicaCGImageRef?) -> UnsafePointer<Double>? {
    object(image, as: ImageObject.self)?.decode.flatMap { UnsafePointer($0.baseAddress) }
}

// MARK: - PNG

// Cairo reads PNGs, where there is Cairo.
#if canImport(Cairo)

/// The bytes a PNG is read from, as Cairo reads them.
private final class PNGReader {

    let bytes: [UInt8]
    var offset = 0

    init(bytes: [UInt8]) {
        self.bytes = bytes
    }
}

/// A PNG's image: RGBA, its alpha not premultiplied, or RGB with a skipped
/// byte where it's opaque, as Cairo decodes it.
@c @implementation public func CGImageCreateWithPNGDataProvider(_ source: SilicaCGDataProviderRef?, _ decode: UnsafePointer<Double>?,
                                                                _ shouldInterpolate: Bool,
                                                                _ intent: CGColorRenderingIntent) -> SilicaCGImageRef? {
    guard let provider = object(source, as: DataProviderObject.self) else { return nil }
    let reader = PNGReader(bytes: provider.bytes)
    let surface = withExtendedLifetime(reader) {
        cairo_image_surface_create_from_png_stream({ closure, data, length in
            let reader = Unmanaged<PNGReader>.fromOpaque(closure!).takeUnretainedValue()
            let count = Int(length)
            guard let data, reader.offset + count <= reader.bytes.count else { return CAIRO_STATUS_READ_ERROR }
            reader.bytes.withUnsafeBufferPointer { bytes in
                data.update(from: bytes.baseAddress! + reader.offset, count: count)
            }
            reader.offset += count
            return CAIRO_STATUS_SUCCESS
        }, Unmanaged.passUnretained(reader).toOpaque())
    }
    guard let surface else { return nil }
    defer { cairo_surface_destroy(surface) }
    let cairoFormat = cairo_image_surface_get_format(surface)
    guard cairo_surface_status(surface) == CAIRO_STATUS_SUCCESS,
          cairoFormat == CAIRO_FORMAT_ARGB32 || cairoFormat == CAIRO_FORMAT_RGB24 else { return nil }
    cairo_surface_flush(surface)
    let width = Int(cairo_image_surface_get_width(surface)), height = Int(cairo_image_surface_get_height(surface))
    let stride = Int(cairo_image_surface_get_stride(surface))
    guard width > 0, height > 0, let pixels = cairo_image_surface_get_data(surface) else { return nil }
    let opaque = cairoFormat == CAIRO_FORMAT_RGB24
    let bitmapInfo = opaque ? CGBitmapInfo(kCGImageAlphaNoneSkipLast) : CGBitmapInfo(kCGImageAlphaLast)
    guard let format = PixelFormat(bitsPerComponent: 8, bitsPerPixel: 32, model: .rgb, bitmapInfo: bitmapInfo) else { return nil }
    var data = [UInt8](repeating: 0, count: width * height * 4)
    for y in 0 ..< height {
        let row = UnsafeRawPointer(pixels + y * stride)
        for x in 0 ..< width {
            let word = row.load(fromByteOffset: x * 4, as: UInt32.self)
            let alpha = opaque ? 255 : UInt8(truncatingIfNeeded: word >> 24)
            let offset = (y * width + x) * 4
            data[offset] = UInt8(truncatingIfNeeded: word >> 16)
            data[offset + 1] = UInt8(truncatingIfNeeded: word >> 8)
            data[offset + 2] = UInt8(truncatingIfNeeded: word)
            data[offset + 3] = alpha
            if opaque == false {
                for component in offset ..< offset + 3 {
                    data[component] = unpremultiply(data[component], alpha)
                }
            }
        }
    }
    return makeReference(ImageObject(width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, format: format,
                                     space: ColorSpaceObject.deviceRGB, data: data, shouldInterpolate: shouldInterpolate,
                                     renderingIntent: intent, decode: decode.map { decode in (0 ..< 6).map { decode[$0] } }))
}

#endif

#endif
