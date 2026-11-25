//
//  ColorAPI.swift
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

// The functions of CGColorSpace.h, CGColor.h and CGGradient.h.

// MARK: - Color Spaces

/// What a `CGColorSpaceRef` points to. Silica draws in sRGB: RGB spaces are
/// sRGB, gray is its gray, and CMYK converts naively. A pattern space's
/// colors are patterns, painted in its base space's colors if they're
/// stencils; an indexed space's are its base space's colors in its table.
internal final class ColorSpaceObject {

    enum Model: Int32 {
        case gray = 0
        case rgb = 1
        case cmyk = 2
        case indexed = 5
        case pattern = 6
    }

    let model: Model

    /// A pattern or indexed space's base space.
    let base: Retained?

    /// An indexed space's colors, a byte a component of the base space.
    let table: [UInt8]

    /// The ICC profile the space was made with.
    let profile: [UInt8]?

    init(model: Model, base: OpaquePointer? = nil, table: [UInt8] = [], profile: [UInt8]? = nil) {
        self.model = model
        self.base = base.map(Retained.init)
        self.table = table
        self.profile = profile
    }

    /// A new space of the same kind, with the same base, table and profile.
    func copy() -> ColorSpaceObject {
        ColorSpaceObject(model: model, base: base?.reference, table: table, profile: profile)
    }

    /// How many colors an indexed space's table holds.
    var colorTableCount: Int {
        guard model == .indexed, let base = baseSpace, base.numberOfComponents > 0 else { return 0 }
        return table.count / base.numberOfComponents
    }

    var baseSpace: ColorSpaceObject? {
        base.flatMap { object($0.reference, as: ColorSpaceObject.self) }
    }

    var numberOfComponents: Int {
        switch model {
        case .gray: return 1
        case .rgb: return 3
        case .cmyk: return 4
        case .indexed: return 1
        case .pattern: return baseSpace?.numberOfComponents ?? 0
        }
    }

    /// A color of components in this space and alpha, in sRGB: for a pattern
    /// space, the color a stencil is painted in.
    func color(_ components: [Double], alpha: Double) -> Silica.Color {
        func component(_ index: Int) -> Double { index < components.count ? components[index] : 0 }
        switch model {
        case .pattern:
            return baseSpace?.color(components, alpha: alpha) ?? Silica.Color(white: 0, alpha: alpha)
        case .indexed:
            guard let base = baseSpace, colorTableCount > 0 else { return Silica.Color(white: 0, alpha: alpha) }
            let index = min(max(Int(component(0).rounded()), 0), colorTableCount - 1)
            let count = base.numberOfComponents
            return base.color((0 ..< count).map { Double(table[index * count + $0]) / 255 }, alpha: alpha)
        case .gray:
            return Silica.Color(white: component(0), alpha: alpha)
        case .rgb:
            return Silica.Color(red: component(0), green: component(1), blue: component(2), alpha: alpha)
        case .cmyk:
            let k = component(3)
            return Silica.Color(red: (1 - component(0)) * (1 - k), green: (1 - component(1)) * (1 - k),
                                blue: (1 - component(2)) * (1 - k), alpha: alpha)
        }
    }

    // The spaces are shared, as Darwin's device spaces are.
    nonisolated(unsafe) static let deviceRGB = makeReference(ColorSpaceObject(model: .rgb))
    nonisolated(unsafe) static let deviceGray = makeReference(ColorSpaceObject(model: .gray))
    nonisolated(unsafe) static let deviceCMYK = makeReference(ColorSpaceObject(model: .cmyk))

    /// The shared spaces' objects.
    nonisolated(unsafe) static let rgb = object(deviceRGB, as: ColorSpaceObject.self)!
    nonisolated(unsafe) static let gray = object(deviceGray, as: ColorSpaceObject.self)!
}

@c @implementation public func CGColorSpaceGetTypeID() -> UInt {
    CoreGraphicsObjects.typeID(of: .colorSpace)
}

@c @implementation public func CGColorSpaceCreateDeviceRGB() -> SilicaCGColorSpaceRef {
    retain(ColorSpaceObject.deviceRGB)
    return ColorSpaceObject.deviceRGB
}

@c @implementation public func CGColorSpaceCreateDeviceGray() -> SilicaCGColorSpaceRef {
    retain(ColorSpaceObject.deviceGray)
    return ColorSpaceObject.deviceGray
}

@c @implementation public func CGColorSpaceCreateDeviceCMYK() -> SilicaCGColorSpaceRef {
    retain(ColorSpaceObject.deviceCMYK)
    return ColorSpaceObject.deviceCMYK
}

@c @implementation public func CGColorSpaceRetain(_ space: SilicaCGColorSpaceRef?) -> SilicaCGColorSpaceRef? {
    retain(space)
    return space
}

@c @implementation public func CGColorSpaceRelease(_ space: SilicaCGColorSpaceRef?) {
    release(space)
}

@c @implementation public func CGColorSpaceGetModel(_ space: SilicaCGColorSpaceRef?) -> CGColorSpaceModel {
    guard let space = object(space, as: ColorSpaceObject.self) else { return CGColorSpaceModel(kCGColorSpaceModelUnknown) }
    return space.model.rawValue
}

@c @implementation public func CGColorSpaceGetNumberOfComponents(_ space: SilicaCGColorSpaceRef?) -> Int {
    object(space, as: ColorSpaceObject.self)?.numberOfComponents ?? 0
}

// MARK: Calibrated, ICC and Indexed Spaces

@c @implementation public func CGColorSpaceCreateCalibratedGray(_ whitePoint: UnsafePointer<Double>?, _ blackPoint: UnsafePointer<Double>?,
                                                                _ gamma: Double) -> SilicaCGColorSpaceRef? {
    guard whitePoint != nil else { return nil }
    return makeReference(ColorSpaceObject(model: .gray))
}

@c @implementation public func CGColorSpaceCreateCalibratedRGB(_ whitePoint: UnsafePointer<Double>?, _ blackPoint: UnsafePointer<Double>?,
                                                               _ gamma: UnsafePointer<Double>?,
                                                               _ matrix: UnsafePointer<Double>?) -> SilicaCGColorSpaceRef? {
    guard whitePoint != nil else { return nil }
    return makeReference(ColorSpaceObject(model: .rgb))
}

/// The model of a count of components: gray, RGB or CMYK.
private func model(components: Int) -> ColorSpaceObject.Model? {
    switch components {
    case 1: return .gray
    case 3: return .rgb
    case 4: return .cmyk
    default: return nil
    }
}

/// The model an ICC profile's header names.
private func model(profile: [UInt8]) -> ColorSpaceObject.Model? {
    guard profile.count >= 20 else { return nil }
    let signature = profile[16 ..< 20].reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
    switch signature {
    case 0x4752_4159: return .gray // "GRAY"
    case 0x5247_4220: return .rgb // "RGB "
    case 0x434D_594B: return .cmyk // "CMYK"
    default: return nil
    }
}

@c @implementation public func CGColorSpaceCreateICCBased(_ nComponents: Int, _ range: UnsafePointer<Double>?,
                                                          _ profile: SilicaCGDataProviderRef?,
                                                          _ alternate: SilicaCGColorSpaceRef?) -> SilicaCGColorSpaceRef? {
    let bytes = object(profile, as: DataProviderObject.self)?.bytes
    if let model = model(components: nComponents) {
        return makeReference(ColorSpaceObject(model: model, profile: bytes))
    }
    guard let alternate = object(alternate, as: ColorSpaceObject.self) else { return nil }
    return makeReference(alternate.copy())
}

/// A profile's space, from a CFDataRef where Core Foundation is bridged.
@c @implementation public func CGColorSpaceCreateWithICCData(_ data: UnsafeRawPointer?) -> SilicaCGColorSpaceRef? {
    guard let data, let bridge = CoreGraphicsObjects.coreFoundation, let bytes = bridge.data(data),
          let model = model(profile: bytes) else { return nil }
    return makeReference(ColorSpaceObject(model: model, profile: bytes))
}

@c @implementation public func CGColorSpaceCopyICCData(_ space: SilicaCGColorSpaceRef?) -> SilicaCFDataRef? {
    makeCFData(object(space, as: ColorSpaceObject.self)?.profile)
}

/// NULL, as for Apple's device spaces: only named spaces have linear forms.
@c @implementation public func CGColorSpaceCreateLinearized(_ space: SilicaCGColorSpaceRef?) -> SilicaCGColorSpaceRef? {
    nil
}

/// NULL, as for Apple's device spaces: only named spaces have extended forms.
@c @implementation public func CGColorSpaceCreateExtended(_ space: SilicaCGColorSpaceRef?) -> SilicaCGColorSpaceRef? {
    nil
}

@c @implementation public func CGColorSpaceCreateIndexed(_ baseSpace: SilicaCGColorSpaceRef?, _ lastIndex: Int,
                                                         _ colorTable: UnsafePointer<UInt8>?) -> SilicaCGColorSpaceRef? {
    guard let baseSpace, let base = object(baseSpace, as: ColorSpaceObject.self),
          base.model == .gray || base.model == .rgb || base.model == .cmyk,
          lastIndex >= 0, lastIndex <= 255, let colorTable else { return nil }
    let count = (lastIndex + 1) * base.numberOfComponents
    return makeReference(ColorSpaceObject(model: .indexed, base: baseSpace, table: (0 ..< count).map { colorTable[$0] }))
}

@c @implementation public func CGColorSpaceGetColorTableCount(_ space: SilicaCGColorSpaceRef?) -> Int {
    object(space, as: ColorSpaceObject.self)?.colorTableCount ?? 0
}

@c @implementation public func CGColorSpaceGetColorTable(_ space: SilicaCGColorSpaceRef?, _ table: UnsafeMutablePointer<UInt8>?) {
    guard let space = object(space, as: ColorSpaceObject.self), let table else { return }
    for (index, byte) in space.table.enumerated() {
        table[index] = byte
    }
}

// MARK: Pattern Spaces

@c @implementation public func CGColorSpaceCreatePattern(_ baseSpace: SilicaCGColorSpaceRef?) -> SilicaCGColorSpaceRef? {
    if let baseSpace {
        // a pattern's colors aren't patterns
        guard let base = object(baseSpace, as: ColorSpaceObject.self), base.model != .pattern else { return nil }
    }
    return makeReference(ColorSpaceObject(model: .pattern, base: baseSpace))
}

@c @implementation public func CGColorSpaceGetBaseColorSpace(_ space: SilicaCGColorSpaceRef?) -> SilicaCGColorSpaceRef? {
    object(space, as: ColorSpaceObject.self)?.base?.reference
}

@c @implementation public func CGColorSpaceCopyBaseColorSpace(_ space: SilicaCGColorSpaceRef?) -> SilicaCGColorSpaceRef? {
    guard let base = object(space, as: ColorSpaceObject.self)?.base?.reference else { return nil }
    retain(base)
    return base
}

// MARK: - Colors

/// What a `CGColorRef` points to: components in a space, then alpha, or a
/// pattern and the components it's painted with.
internal final class ColorObject {

    let space: Retained

    let colorSpace: ColorSpaceObject

    /// The components and alpha, where `CGColorGetComponents` points.
    let components: UnsafeMutableBufferPointer<Double>

    /// A pattern color's pattern.
    let pattern: Retained?

    init(space reference: SilicaCGColorSpaceRef, components: [Double], pattern: OpaquePointer? = nil) {
        self.space = Retained(reference)
        self.colorSpace = object(reference, as: ColorSpaceObject.self)!
        self.components = UnsafeMutableBufferPointer.allocate(capacity: components.count)
        _ = self.components.initialize(from: components)
        self.pattern = pattern.map(Retained.init)
    }

    deinit {
        components.deallocate()
    }

    var alpha: Double { components.last ?? 1 }

    /// The color in sRGB.
    var silica: Silica.Color {
        colorSpace.color(Array(components.dropLast()), alpha: alpha)
    }
}

/// A new color's reference in a space, from its components and alpha.
internal func makeColorReference(space: SilicaCGColorSpaceRef, components: [Double]) -> SilicaCGColorRef {
    makeReference(ColorObject(space: space, components: components))
}

@c @implementation public func CGColorGetTypeID() -> UInt {
    CoreGraphicsObjects.typeID(of: .color)
}

@c @implementation public func CGColorCreate(_ space: SilicaCGColorSpaceRef?, _ components: UnsafePointer<Double>?) -> SilicaCGColorRef? {
    guard let space, let colorSpace = object(space, as: ColorSpaceObject.self), let components else { return nil }
    let count = colorSpace.numberOfComponents + 1
    return makeColorReference(space: space, components: (0 ..< count).map { components[$0] })
}

@c @implementation public func CGColorCreateGenericGray(_ gray: Double, _ alpha: Double) -> SilicaCGColorRef {
    makeColorReference(space: ColorSpaceObject.deviceGray, components: [gray, alpha])
}

@c @implementation public func CGColorCreateGenericRGB(_ red: Double, _ green: Double, _ blue: Double, _ alpha: Double) -> SilicaCGColorRef {
    makeColorReference(space: ColorSpaceObject.deviceRGB, components: [red, green, blue, alpha])
}

@c @implementation public func CGColorCreateSRGB(_ red: Double, _ green: Double, _ blue: Double, _ alpha: Double) -> SilicaCGColorRef {
    makeColorReference(space: ColorSpaceObject.deviceRGB, components: [red, green, blue, alpha])
}

@c @implementation public func CGColorCreateCopy(_ color: SilicaCGColorRef?) -> SilicaCGColorRef? {
    guard let color = object(color, as: ColorObject.self) else { return nil }
    return makeReference(ColorObject(space: color.space.reference, components: Array(color.components),
                                     pattern: color.pattern?.reference))
}

@c @implementation public func CGColorCreateCopyWithAlpha(_ color: SilicaCGColorRef?, _ alpha: Double) -> SilicaCGColorRef? {
    guard let color = object(color, as: ColorObject.self) else { return nil }
    return makeReference(ColorObject(space: color.space.reference, components: Array(color.components.dropLast()) + [alpha],
                                     pattern: color.pattern?.reference))
}

/// The color in another space: sRGB's components, its gray, or CMYK naively.
@c @implementation public func CGColorCreateCopyByMatchingToColorSpace(_ space: SilicaCGColorSpaceRef?, _ intent: CGColorRenderingIntent,
                                                                      _ color: SilicaCGColorRef?,
                                                                      _ options: UnsafeRawPointer?) -> SilicaCGColorRef? {
    guard let space, let target = object(space, as: ColorSpaceObject.self),
          let source = object(color, as: ColorObject.self), source.pattern == nil else { return nil }
    let color = source.silica
    let components: [Double]
    switch target.model {
    case .rgb:
        components = [color.red, color.green, color.blue]
    case .gray:
        components = [grayLevel(red: color.red, green: color.green, blue: color.blue)]
    case .cmyk:
        let black = 1 - max(color.red, color.green, color.blue)
        let scale = black < 1 ? 1 / (1 - black) : 0
        components = [(1 - color.red - black) * scale, (1 - color.green - black) * scale, (1 - color.blue - black) * scale, black]
    case .indexed, .pattern:
        return nil
    }
    return makeColorReference(space: space, components: components + [color.alpha])
}

@c @implementation public func CGColorRetain(_ color: SilicaCGColorRef?) -> SilicaCGColorRef? {
    retain(color)
    return color
}

@c @implementation public func CGColorRelease(_ color: SilicaCGColorRef?) {
    release(color)
}

/// Equal in the same space with the same components.
@c @implementation public func CGColorEqualToColor(_ color1: SilicaCGColorRef?, _ color2: SilicaCGColorRef?) -> Bool {
    if color1 == color2 { return true }
    guard let first = object(color1, as: ColorObject.self), let second = object(color2, as: ColorObject.self) else { return false }
    return first.colorSpace.model == second.colorSpace.model && Array(first.components) == Array(second.components)
        && first.pattern?.reference == second.pattern?.reference
}

@c @implementation public func CGColorGetNumberOfComponents(_ color: SilicaCGColorRef?) -> Int {
    object(color, as: ColorObject.self)?.components.count ?? 0
}

@c @implementation public func CGColorGetComponents(_ color: SilicaCGColorRef?) -> UnsafePointer<Double>? {
    guard let color = object(color, as: ColorObject.self) else { return nil }
    return UnsafePointer(color.components.baseAddress)
}

@c @implementation public func CGColorGetAlpha(_ color: SilicaCGColorRef?) -> Double {
    object(color, as: ColorObject.self)?.alpha ?? 0
}

@c @implementation public func CGColorGetColorSpace(_ color: SilicaCGColorRef?) -> SilicaCGColorSpaceRef? {
    object(color, as: ColorObject.self)?.space.reference
}

@c @implementation public func CGColorCreateWithPattern(_ space: SilicaCGColorSpaceRef?, _ pattern: SilicaCGPatternRef?,
                                                        _ components: UnsafePointer<Double>?) -> SilicaCGColorRef? {
    guard let space, let colorSpace = object(space, as: ColorSpaceObject.self), colorSpace.model == .pattern,
          let pattern, object(pattern, as: PatternObject.self) != nil, let components else { return nil }
    let count = colorSpace.numberOfComponents + 1
    return makeReference(ColorObject(space: space, components: (0 ..< count).map { components[$0] }, pattern: pattern))
}

@c @implementation public func CGColorGetPattern(_ color: SilicaCGColorRef?) -> SilicaCGPatternRef? {
    object(color, as: ColorObject.self)?.pattern?.reference
}

// MARK: - Gradients

/// What a `CGGradientRef` points to.
internal final class GradientObject {

    let gradient: Silica.Gradient

    init(gradient: Silica.Gradient) {
        self.gradient = gradient
    }
}

@c @implementation public func CGGradientGetTypeID() -> UInt {
    CoreGraphicsObjects.typeID(of: .gradient)
}

@c @implementation public func CGGradientCreateWithColorComponents(_ space: SilicaCGColorSpaceRef?, _ components: UnsafePointer<Double>?,
                                                                   _ locations: UnsafePointer<Double>?, _ count: Int) -> SilicaCGGradientRef? {
    guard let colorSpace = object(space, as: ColorSpaceObject.self), let components, count > 0 else { return nil }
    let stride = colorSpace.numberOfComponents + 1
    let stops = (0 ..< count).map { index -> Silica.Gradient.Stop in
        let values = (0 ..< stride).map { components[index * stride + $0] }
        let location = locations?[index] ?? (count > 1 ? Double(index) / Double(count - 1) : 0)
        return Silica.Gradient.Stop(color: colorSpace.color(Array(values.dropLast()), alpha: values.last!), location: location)
    }
    return makeReference(GradientObject(gradient: Silica.Gradient(stops: stops)))
}

/// Colors from a CFArray of CGColorRefs, where Core Foundation is bridged.
@c @implementation public func CGGradientCreateWithColors(_ space: SilicaCGColorSpaceRef?, _ colors: SilicaCFArrayRef?,
                                                         _ locations: UnsafePointer<Double>?) -> SilicaCGGradientRef? {
    guard let colors, let bridge = CoreGraphicsObjects.coreFoundation, let values = bridge.array(UnsafeRawPointer(colors)) else { return nil }
    let objects = values.compactMap { object(OpaquePointer($0), as: ColorObject.self) }
    guard objects.isEmpty == false, objects.count == values.count else { return nil }
    let count = objects.count
    let stops = objects.enumerated().map { index, color in
        Silica.Gradient.Stop(color: color.silica, location: locations?[index] ?? (count > 1 ? Double(index) / Double(count - 1) : 0))
    }
    return makeReference(GradientObject(gradient: Silica.Gradient(stops: stops)))
}

@c @implementation public func CGGradientRetain(_ gradient: SilicaCGGradientRef?) -> SilicaCGGradientRef? {
    retain(gradient)
    return gradient
}

@c @implementation public func CGGradientRelease(_ gradient: SilicaCGGradientRef?) {
    release(gradient)
}

#endif
