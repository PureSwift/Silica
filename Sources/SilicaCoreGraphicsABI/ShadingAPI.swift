//
//  ShadingAPI.swift
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

// The functions of CGFunction.h and CGShading.h.

// MARK: - Functions

/// What a `CGFunctionRef` points to: a callback from inputs to outputs, each
/// clipped to its interval.
internal final class FunctionObject {

    let info: UnsafeMutableRawPointer?
    let domainDimension: Int
    let rangeDimension: Int
    /// Two values an input, or nil for none clipped.
    let domain: [Double]?
    /// Two values an output, or nil for none clipped.
    let range: [Double]?
    let evaluate: CGFunctionEvaluateCallback?
    let releaseInfo: CGFunctionReleaseInfoCallback?

    init(info: UnsafeMutableRawPointer?, domainDimension: Int, domain: [Double]?, rangeDimension: Int, range: [Double]?,
         callbacks: CGFunctionCallbacks) {
        self.info = info
        self.domainDimension = domainDimension
        self.rangeDimension = rangeDimension
        self.domain = domain
        self.range = range
        self.evaluate = callbacks.evaluate
        self.releaseInfo = callbacks.releaseInfo
    }

    deinit {
        releaseInfo?(info)
    }

    /// The outputs of inputs, each clipped to its interval.
    func callAsFunction(_ input: [Double]) -> [Double] {
        var input = input + [Double](repeating: 0, count: max(0, domainDimension - input.count))
        if let domain {
            for index in 0 ..< domainDimension {
                input[index] = min(max(input[index], domain[index * 2]), domain[index * 2 + 1])
            }
        }
        var output = [Double](repeating: 0, count: rangeDimension)
        if let evaluate, rangeDimension > 0 {
            input.withUnsafeBufferPointer { input in
                output.withUnsafeMutableBufferPointer { output in
                    evaluate(info, input.baseAddress!, output.baseAddress!)
                }
            }
        }
        if let range {
            for index in 0 ..< rangeDimension {
                output[index] = min(max(output[index], range[index * 2]), range[index * 2 + 1])
            }
        }
        return output
    }
}

@c @implementation public func CGFunctionGetTypeID() -> UInt {
    CoreGraphicsObjects.typeID(of: .function)
}

@c @implementation public func CGFunctionCreate(_ info: UnsafeMutableRawPointer?, _ domainDimension: Int,
                                                _ domain: UnsafePointer<Double>?, _ rangeDimension: Int,
                                                _ range: UnsafePointer<Double>?,
                                                _ callbacks: UnsafePointer<CGFunctionCallbacks>?) -> SilicaCGFunctionRef? {
    guard let callbacks = callbacks?.pointee, domainDimension >= 0, rangeDimension >= 0 else { return nil }
    let domainValues = domain.map { domain in (0 ..< domainDimension * 2).map { domain[$0] } }
    let rangeValues = range.map { range in (0 ..< rangeDimension * 2).map { range[$0] } }
    return makeReference(FunctionObject(info: info, domainDimension: domainDimension, domain: domainValues,
                                        rangeDimension: rangeDimension, range: rangeValues, callbacks: callbacks))
}

@c @implementation public func CGFunctionRetain(_ function: SilicaCGFunctionRef?) -> SilicaCGFunctionRef? {
    retain(function)
    return function
}

@c @implementation public func CGFunctionRelease(_ function: SilicaCGFunctionRef?) {
    release(function)
}

// MARK: - Shadings

/// What a `CGShadingRef` points to: a function's colors along a line or
/// between circles.
internal final class ShadingObject {

    enum Geometry {
        case axial(start: Silica.Point, end: Silica.Point)
        case radial(start: Silica.Point, startRadius: Double, end: Silica.Point, endRadius: Double)
    }

    let space: Retained
    let colorSpace: ColorSpaceObject
    let geometry: Geometry
    let function: Retained
    let options: GradientOptions

    init(space reference: OpaquePointer, geometry: Geometry, function: OpaquePointer, extendStart: Bool, extendEnd: Bool) {
        self.space = Retained(reference)
        self.colorSpace = object(reference, as: ColorSpaceObject.self)!
        self.geometry = geometry
        self.function = Retained(function)
        var options: GradientOptions = []
        if extendStart { options.insert(.drawsBeforeStartLocation) }
        if extendEnd { options.insert(.drawsAfterEndLocation) }
        self.options = options
    }

    /// The function sampled across its domain's first interval, as a
    /// gradient; made once.
    lazy var gradient: Gradient = {
        let function = object(self.function.reference, as: FunctionObject.self)!
        let low = function.domain?[0] ?? 0, high = function.domain?[1] ?? 1
        let components = colorSpace.numberOfComponents
        let samples = 256
        let stops = (0 ..< samples).map { index -> Gradient.Stop in
            let location = Double(index) / Double(samples - 1)
            let output = function([low + location * (high - low)])
            let values = Array(output.prefix(components)) + [Double](repeating: 0, count: max(0, components - output.count))
            let alpha = output.count > components ? output[components] : 1
            return Gradient.Stop(color: colorSpace.color(values, alpha: alpha), location: location)
        }
        return Gradient(stops: stops)
    }()
}

private func makeShading(_ space: SilicaCGColorSpaceRef?, _ function: SilicaCGFunctionRef?, _ geometry: ShadingObject.Geometry,
                         _ extendStart: Bool, _ extendEnd: Bool) -> SilicaCGShadingRef? {
    guard let space, let colorSpace = object(space, as: ColorSpaceObject.self), colorSpace.model != .pattern,
          let function, let functionObject = object(function, as: FunctionObject.self),
          functionObject.domainDimension == 1,
          functionObject.rangeDimension >= colorSpace.numberOfComponents else { return nil }
    return makeReference(ShadingObject(space: space, geometry: geometry, function: function,
                                       extendStart: extendStart, extendEnd: extendEnd))
}

@c @implementation public func CGShadingGetTypeID() -> UInt {
    CoreGraphicsObjects.typeID(of: .shading)
}

@c @implementation public func CGShadingCreateAxial(_ space: SilicaCGColorSpaceRef?, _ start: CGPoint, _ end: CGPoint,
                                                    _ function: SilicaCGFunctionRef?, _ extendStart: Bool,
                                                    _ extendEnd: Bool) -> SilicaCGShadingRef? {
    makeShading(space, function, .axial(start: start.silica, end: end.silica), extendStart, extendEnd)
}

@c @implementation public func CGShadingCreateRadial(_ space: SilicaCGColorSpaceRef?, _ start: CGPoint, _ startRadius: Double,
                                                     _ end: CGPoint, _ endRadius: Double, _ function: SilicaCGFunctionRef?,
                                                     _ extendStart: Bool, _ extendEnd: Bool) -> SilicaCGShadingRef? {
    makeShading(space, function, .radial(start: start.silica, startRadius: startRadius, end: end.silica, endRadius: endRadius),
                extendStart, extendEnd)
}

@c @implementation public func CGShadingRetain(_ shading: SilicaCGShadingRef?) -> SilicaCGShadingRef? {
    retain(shading)
    return shading
}

@c @implementation public func CGShadingRelease(_ shading: SilicaCGShadingRef?) {
    release(shading)
}

// Contexts draw with Cairo, where there is Cairo.
#if canImport(Cairo)

@c @implementation public func CGContextDrawShading(_ c: SilicaCGContextRef?, _ shading: SilicaCGShadingRef?) {
    guard let target = contextObject(c), let shading = object(shading, as: ShadingObject.self) else { return }
    switch shading.geometry {
    case let .axial(start, end):
        target.context.drawLinearGradient(shading.gradient, start: start, end: end, options: shading.options)
    case let .radial(start, startRadius, end, endRadius):
        target.context.drawRadialGradient(shading.gradient, startCenter: start, startRadius: startRadius,
                                          endCenter: end, endRadius: endRadius, options: shading.options)
    }
}

#endif

#endif
