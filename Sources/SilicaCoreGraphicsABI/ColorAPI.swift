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
/// sRGB, gray is its gray, and CMYK converts naively.
internal final class ColorSpaceObject {

    enum Model: Int32 {
        case gray = 0
        case rgb = 1
        case cmyk = 2
    }

    let model: Model

    init(model: Model) {
        self.model = model
    }

    var numberOfComponents: Int {
        switch model {
        case .gray: return 1
        case .rgb: return 3
        case .cmyk: return 4
        }
    }

    /// A color of components in this space and alpha, in sRGB.
    func color(_ components: [Double], alpha: Double) -> Silica.Color {
        func component(_ index: Int) -> Double { index < components.count ? components[index] : 0 }
        switch model {
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

// MARK: - Colors

/// What a `CGColorRef` points to: components in a space, then alpha.
internal final class ColorObject {

    let space: Retained

    let colorSpace: ColorSpaceObject

    /// The components and alpha, where `CGColorGetComponents` points.
    let components: UnsafeMutableBufferPointer<Double>

    init(space reference: SilicaCGColorSpaceRef, components: [Double]) {
        self.space = Retained(reference)
        self.colorSpace = object(reference, as: ColorSpaceObject.self)!
        self.components = UnsafeMutableBufferPointer.allocate(capacity: components.count)
        _ = self.components.initialize(from: components)
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
    return makeColorReference(space: color.space.reference, components: Array(color.components))
}

@c @implementation public func CGColorCreateCopyWithAlpha(_ color: SilicaCGColorRef?, _ alpha: Double) -> SilicaCGColorRef? {
    guard let color = object(color, as: ColorObject.self) else { return nil }
    return makeColorReference(space: color.space.reference, components: Array(color.components.dropLast()) + [alpha])
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

@c @implementation public func CGGradientRetain(_ gradient: SilicaCGGradientRef?) -> SilicaCGGradientRef? {
    retain(gradient)
    return gradient
}

@c @implementation public func CGGradientRelease(_ gradient: SilicaCGGradientRef?) {
    release(gradient)
}

#endif
