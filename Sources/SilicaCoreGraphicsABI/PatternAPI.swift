//
//  PatternAPI.swift
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
#if (!SWIFT_PACKAGE || Cairo) && canImport(Cairo)
import Cairo
import SilicaCairo
#endif

// The functions of CGPattern.h, and the patterns and tiled images contexts paint.

/// What a `CGPatternRef` points to: a cell, the callback that draws it, and
/// how it repeats.
internal final class PatternObject {

    let info: UnsafeMutableRawPointer?
    let bounds: Silica.Rect
    /// From pattern space to the base space of the context painted.
    let matrix: Silica.AffineTransform
    let xStep: Double
    let yStep: Double
    let tiling: Int32
    let isColored: Bool
    let drawPattern: CGPatternDrawPatternCallback?
    let releaseInfo: CGPatternReleaseInfoCallback?

    init(info: UnsafeMutableRawPointer?, bounds: Silica.Rect, matrix: Silica.AffineTransform, xStep: Double, yStep: Double,
         tiling: Int32, isColored: Bool, callbacks: CGPatternCallbacks) {
        self.info = info
        self.bounds = bounds
        self.matrix = matrix
        self.xStep = xStep
        self.yStep = yStep
        self.tiling = tiling
        self.isColored = isColored
        self.drawPattern = callbacks.drawPattern
        self.releaseInfo = callbacks.releaseInfo
    }

    deinit {
        releaseInfo?(info)
    }

    /// The distance from a cell to the next, across and up: the step, or the
    /// cell's size where the step is zero.
    var step: Silica.Size {
        Silica.Size(width: xStep != 0 ? abs(xStep) : bounds.width, height: yStep != 0 ? abs(yStep) : bounds.height)
    }
}

@c @implementation public func CGPatternGetTypeID() -> UInt {
    CoreGraphicsObjects.typeID(of: .pattern)
}

@c @implementation public func CGPatternCreate(_ info: UnsafeMutableRawPointer?, _ bounds: CGRect, _ matrix: CGAffineTransform,
                                               _ xStep: Double, _ yStep: Double, _ tiling: CGPatternTiling, _ isColored: Bool,
                                               _ callbacks: UnsafePointer<CGPatternCallbacks>?) -> SilicaCGPatternRef? {
    guard let callbacks = callbacks?.pointee else { return nil }
    return makeReference(PatternObject(info: info, bounds: bounds.silica.standardized, matrix: matrix.silica, xStep: xStep,
                                       yStep: yStep, tiling: tiling, isColored: isColored, callbacks: callbacks))
}

@c @implementation public func CGPatternRetain(_ pattern: SilicaCGPatternRef?) -> SilicaCGPatternRef? {
    retain(pattern)
    return pattern
}

@c @implementation public func CGPatternRelease(_ pattern: SilicaCGPatternRef?) {
    release(pattern)
}

// Patterns paint with Cairo, where contexts draw.
#if (!SWIFT_PACKAGE || Cairo) && canImport(Cairo)

// MARK: - Tiles

/// The bitmap info of a bitmap in Cairo's own layout, which a Cairo surface
/// draws into directly.
internal let cairoNativeBitmapInfo: UInt32 = 1.littleEndian == 1
    ? CGBitmapInfo(kCGImageAlphaPremultipliedFirst) | CGBitmapInfo(kCGBitmapByteOrder32Little)
    : CGBitmapInfo(kCGImageAlphaPremultipliedFirst)

/// A Cairo surface of premultiplied RGBA pixels, rows from the top.
internal func makeSurface(rgba image: Silica.Image) -> Cairo.Surface.Image? {
    guard image.width > 0, image.height > 0,
          let surface = try? Cairo.Surface.Image(format: .argb32, width: image.width, height: image.height) else { return nil }
    let stride = surface.stride
    image.data.withUnsafeBytes { source in
        _ = surface.withUnsafeMutableBytes { pixels in
            for y in 0 ..< image.height {
                let row = UnsafeMutableRawPointer(pixels + y * stride)
                for x in 0 ..< image.width {
                    let offset = y * image.bytesPerRow + x * 4
                    let word = UInt32(source[offset + 3]) << 24 | UInt32(source[offset]) << 16
                        | UInt32(source[offset + 1]) << 8 | UInt32(source[offset + 2])
                    row.storeBytes(of: word, toByteOffset: x * 4, as: UInt32.self)
                }
            }
        }
    }
    surface.markDirty()
    return surface
}

/// A Cairo source repeating a tile: the tile's pixels lie in device space by
/// `tileToDevice`, from its top left.
internal func repeating(_ tile: Cairo.Surface.Image, tileToDevice: Silica.AffineTransform) -> CairoRenderer.Source? {
    guard let deviceToTile = tileToDevice.invertedIfPossible() else { return nil }
    let pattern = Cairo.Pattern(surface: tile)
    pattern.extend = .repeat
    return CairoRenderer.Source(pattern: pattern, deviceMatrix: deviceToTile.toCairo())
}

extension PatternObject {

    /// The pattern's cell, drawn once at the device's resolution into a tile
    /// a step across, and where the tile lies in pattern space: from its top
    /// left pixel, a cell's origin. The cell draws in `color` unless it sets
    /// its own, as Apple's stencils do, and the tile's opacity is times `alpha`.
    func makeTile(color: Silica.Color?, alpha: Double) -> (surface: Cairo.Surface.Image, tileToPattern: Silica.AffineTransform)? {
        let step = self.step
        guard step.width > 0, step.height > 0, step.width.isFinite, step.height.isFinite else { return nil }
        // a pixel of the tile a pixel of the device
        let scaleX = (matrix.a * matrix.a + matrix.b * matrix.b).squareRoot()
        let scaleY = (matrix.c * matrix.c + matrix.d * matrix.d).squareRoot()
        let width = min(max(Int((step.width * scaleX - 1e-6).rounded(.up)), 1), 4096)
        let height = min(max(Int((step.height * scaleY - 1e-6).rounded(.up)), 1), 4096)
        let pixelsX = Double(width) / step.width, pixelsY = Double(height) / step.height
        guard let reference = makeBitmapContext(nil, width, height, 8, width * 4, ColorSpaceObject.deviceRGB,
                                                cairoNativeBitmapInfo, nil),
              let tile = object(reference, as: ContextObject.self) else { return nil }
        defer { release(reference) }
        // the tile context's user space is pattern space, the tile a step from the cell's origin
        tile.context.scaleBy(x: pixelsX, y: pixelsY)
        tile.context.translateBy(x: -bounds.minX, y: -bounds.minY)
        if let color {
            tile.context.fillColor = color
            tile.context.strokeColor = color
        }
        let fundamental = Silica.Rect(origin: bounds.origin, size: step)
        // cells that spill past a step draw into the tiles beside them
        let reachX = min(Int((bounds.width / step.width).rounded(.up)), 8)
        let reachY = min(Int((bounds.height / step.height).rounded(.up)), 8)
        if let drawPattern {
            for row in -reachY ... reachY {
                for column in -reachX ... reachX {
                    let offset = Silica.Size(width: Double(column) * step.width, height: Double(row) * step.height)
                    let cell = bounds.offsetBy(dx: offset.width, dy: offset.height)
                    let overlap = cell.intersection(fundamental)
                    guard overlap.isNull == false, overlap.width > 0, overlap.height > 0 else { continue }
                    CGContextSaveGState(reference)
                    CGContextTranslateCTM(reference, offset.width, offset.height)
                    CGContextClipToRect(reference, CGRect(bounds))
                    drawPattern(info, reference)
                    CGContextRestoreGState(reference)
                }
            }
        }
        // copied out, painted as the pattern is
        let storage = tile.bitmap
        storage.surface.flush()
        guard let surface = try? Cairo.Surface.Image(format: .argb32, width: width, height: height) else { return nil }
        let stride = surface.stride
        _ = surface.withUnsafeMutableBytes { pixels in
            for y in 0 ..< height {
                let source = UnsafeRawPointer(storage.data + y * storage.bytesPerRow)
                let target = UnsafeMutableRawPointer(pixels + y * stride)
                for x in 0 ..< width {
                    let word = source.load(fromByteOffset: x * 4, as: UInt32.self)
                    target.storeBytes(of: scale(word, by: alpha), toByteOffset: x * 4, as: UInt32.self)
                }
            }
        }
        surface.markDirty()
        // tile pixels from the top left, to pattern space, y up
        let tileToPattern = Silica.AffineTransform(a: 1 / pixelsX, b: 0, c: 0, d: -1 / pixelsY,
                                                   tx: bounds.minX, ty: bounds.minY + Double(height) / pixelsY)
        return (surface, tileToPattern)
    }
}

/// A premultiplied pixel, 0xAARRGGBB, with its opacity times the alpha.
private func scale(_ word: UInt32, by alpha: Double) -> UInt32 {
    guard alpha < 1 else { return word }
    let scale = max(alpha, 0)
    return (0 ..< 4).reduce(UInt32(0)) { result, index in
        let shift = UInt32(index * 8)
        let component = Double((word >> shift) & 0xFF) * scale
        return result | UInt32(min(component, 255).rounded()) << shift
    }
}

// MARK: - Painting Patterns

extension ContextObject {

    /// From base space to device space: a bitmap's pixels, from its top left.
    var baseToDevice: Silica.AffineTransform {
        Silica.AffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: Double(bitmap.height))
    }

    /// Paints with the renderer drawing into the bitmap, keeping the bitmap's
    /// memory in step around it.
    func paintDirectly(_ body: (CairoRenderer) -> Void) {
        bitmap.pull()
        body(bitmap.renderer)
        bitmap.push()
    }

    /// Fills (or strokes) with a pattern from now, in the space's colors for a
    /// stencil: `components` are its components and alpha, or alpha alone.
    func setPattern(_ pattern: PatternObject, space: ColorSpaceObject, components: [Double], stroke: Bool) {
        let alpha = components.last ?? 1
        // a stencil's color, opaque: its alpha is the pattern's
        let stencil = pattern.isColored ? nil : space.color(Array(components.dropLast()), alpha: 1)
        // the color, for anything that paints no pattern, and the pattern in its place
        let color = (stencil ?? .black).opacity(alpha)
        if stroke {
            context.strokeColor = color
        } else {
            context.fillColor = color
        }
        guard let tile = pattern.makeTile(color: stencil, alpha: alpha) else { return }
        let phase = Silica.AffineTransform(translationX: state.patternPhase.width, y: state.patternPhase.height)
        let tileToDevice = tile.tileToPattern.concatenating(pattern.matrix).concatenating(phase).concatenating(baseToDevice)
        guard let source = repeating(tile.surface, tileToDevice: tileToDevice) else { return }
        if stroke {
            bitmap.renderer.setStrokeSource(source)
        } else {
            bitmap.renderer.setFillSource(source)
        }
    }
}

private func setPattern(_ c: SilicaCGContextRef?, _ pattern: SilicaCGPatternRef?, _ components: UnsafePointer<Double>?, stroke: Bool) {
    guard let target = contextObject(c), let pattern = object(pattern, as: PatternObject.self) else { return }
    let space = stroke ? target.state.strokeSpace : target.state.fillSpace
    let count = pattern.isColored ? 1 : (space.baseSpace?.numberOfComponents ?? 0) + 1
    let values = components.map { components in (0 ..< count).map { components[$0] } } ?? [1]
    target.setPattern(pattern, space: space, components: values, stroke: stroke)
}

@c @implementation public func CGContextSetFillPattern(_ c: SilicaCGContextRef?, _ pattern: SilicaCGPatternRef?,
                                                       _ components: UnsafePointer<Double>?) {
    setPattern(c, pattern, components, stroke: false)
}

@c @implementation public func CGContextSetStrokePattern(_ c: SilicaCGContextRef?, _ pattern: SilicaCGPatternRef?,
                                                         _ components: UnsafePointer<Double>?) {
    setPattern(c, pattern, components, stroke: true)
}

@c @implementation public func CGContextSetPatternPhase(_ c: SilicaCGContextRef?, _ phase: CGSize) {
    contextObject(c)?.state.patternPhase = phase.silica
}

@c @implementation public func CGContextDrawTiledImage(_ c: SilicaCGContextRef?, _ rect: CGRect, _ image: SilicaCGImageRef?) {
    guard let target = contextObject(c), let image = object(image, as: ImageObject.self) else { return }
    let rect = rect.silica.standardized
    guard rect.width > 0, rect.height > 0, let surface = makeSurface(rgba: image.silica) else { return }
    // the image's pixels from its top left, upright in the rectangle
    let tileToUser = Silica.AffineTransform(a: rect.width / Double(image.width), b: 0, c: 0, d: -rect.height / Double(image.height),
                                            tx: rect.minX, ty: rect.maxY)
    let tileToDevice = tileToUser.concatenating(target.context.ctm).concatenating(target.baseToDevice)
    guard let source = repeating(surface, tileToDevice: tileToDevice) else { return }
    target.paintDirectly { $0.paint(source) }
}

#endif

#endif
