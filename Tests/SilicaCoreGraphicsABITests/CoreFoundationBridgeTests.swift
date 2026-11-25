//
//  CoreFoundationBridgeTests.swift
//  SilicaCoreGraphicsABITests
//
//  Created by Alsey Coleman Miller on 11/25/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

// libCoreGraphics is for platforms other than Darwin.
#if !canImport(Darwin)

import XCTest
import CSilicaCoreGraphics
import SilicaCoreGraphicsABI

/// The functions that take or return Core Foundation's objects, with a
/// bridge whose strings, data and arrays are Swift objects, as a runtime
/// like Perry's bridges its own.
final class CoreFoundationBridgeTests: XCTestCase {

    final class FakeString { let value: String; init(_ value: String) { self.value = value } }
    final class FakeData { let bytes: [UInt8]; init(_ bytes: [UInt8]) { self.bytes = bytes } }

    /// An array retaining CoreGraphics references, as a CFArray does.
    final class FakeArray {
        let values: [UnsafeRawPointer]
        init(_ values: [UnsafeRawPointer]) {
            self.values = values
            values.forEach { _ = Unmanaged<AnyObject>.fromOpaque($0).retain() }
        }
        deinit {
            values.forEach { Unmanaged<AnyObject>.fromOpaque($0).release() }
        }
    }

    static func make(_ object: AnyObject) -> UnsafeRawPointer {
        UnsafeRawPointer(Unmanaged.passRetained(object).toOpaque())
    }

    static func take<T: AnyObject>(_ pointer: UnsafeRawPointer, as type: T.Type) -> T? {
        Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue() as? T
    }

    static func cf(_ string: String) -> OpaquePointer {
        OpaquePointer(make(FakeString(string)))
    }

    static func string(_ reference: OpaquePointer?) -> String? {
        reference.flatMap { take(UnsafeRawPointer($0), as: FakeString.self)?.value }
    }

    /// The constants the runtime has, by name.
    nonisolated(unsafe) static var constants: [String: UnsafeRawPointer] = [:]

    override func setUp() {
        super.setUp()
        CoreGraphicsObjects.coreFoundation = CoreFoundationBridge(
            string: { Self.take($0, as: FakeString.self)?.value },
            makeString: { Self.make(FakeString($0)) },
            data: { Self.take($0, as: FakeData.self)?.bytes },
            makeData: { Self.make(FakeData($0)) },
            filePath: { Self.take($0, as: FakeString.self)?.value },
            array: { Self.take($0, as: FakeArray.self)?.values },
            makeArray: { Self.make(FakeArray($0)) },
            constant: { Self.constants[$0] }
        )
    }

    // MARK: Named Spaces

    func testNamedSpaces() {
        let srgb = CGColorSpaceCreateWithName(Self.cf("kCGColorSpaceSRGB"))
        XCTAssertEqual(CGColorSpaceGetModel(srgb), 1)
        XCTAssertEqual(Self.string(CGColorSpaceGetName(srgb)), "kCGColorSpaceSRGB")
        // the name is kept, so it's the same each time
        XCTAssertEqual(CGColorSpaceGetName(srgb), CGColorSpaceGetName(srgb))
        XCTAssertEqual(Self.string(CGColorSpaceCopyName(srgb)), "kCGColorSpaceSRGB")
        let gray = CGColorSpaceCreateWithName(Self.cf("kCGColorSpaceGenericGrayGamma2_2"))
        XCTAssertEqual(CGColorSpaceGetModel(gray), 0)
        let cmyk = CGColorSpaceCreateWithName(Self.cf("kCGColorSpaceGenericCMYK"))
        XCTAssertEqual(CGColorSpaceGetNumberOfComponents(cmyk), 4)
        XCTAssertNil(CGColorSpaceCreateWithName(Self.cf("nope")))
        // the device spaces have names, as Darwin's do
        let device = CGColorSpaceCreateDeviceRGB()
        XCTAssertEqual(Self.string(CGColorSpaceGetName(device)), "kCGColorSpaceDeviceRGB")
        XCTAssertEqual(CGColorSpaceCreateWithName(Self.cf("kCGColorSpaceDeviceRGB")), device)
    }

    func testRuntimeConstantNames() {
        let constant = Self.make(FakeString("kCGColorSpaceDisplayP3"))
        Self.constants["kCGColorSpaceDisplayP3"] = constant
        defer { Self.constants = [:] }
        let p3 = CGColorSpaceCreateWithName(Self.cf("kCGColorSpaceDisplayP3"))
        XCTAssertEqual(CGColorSpaceGetName(p3), OpaquePointer(constant))
    }

    func testLinearizedAndExtended() {
        let srgb = CGColorSpaceCreateWithName(Self.cf("kCGColorSpaceSRGB"))
        let linear = CGColorSpaceCreateLinearized(srgb)
        XCTAssertEqual(Self.string(CGColorSpaceGetName(linear)), "kCGColorSpaceLinearSRGB")
        let extended = CGColorSpaceCreateExtended(linear)
        XCTAssertEqual(Self.string(CGColorSpaceGetName(extended)), "kCGColorSpaceExtendedLinearSRGB")
        let gray = CGColorSpaceCreateWithName(Self.cf("kCGColorSpaceGenericGrayGamma2_2"))
        XCTAssertEqual(Self.string(CGColorSpaceGetName(CGColorSpaceCreateLinearized(gray))),
                       "kCGColorSpaceLinearGray")
        XCTAssertNil(CGColorSpaceCreateLinearized(CGColorSpaceCreateDeviceRGB()))
    }

    func testPropertyLists() {
        // a device space's is the name of the space it is
        let device = CGColorSpaceCreateDeviceRGB()
        let list = CGColorSpaceCopyPropertyList(device)!
        XCTAssertEqual(Self.take(list, as: FakeString.self)?.value, "kCGColorSpaceSRGB")
        let space = CGColorSpaceCreateWithPropertyList(list)
        XCTAssertEqual(Self.string(CGColorSpaceGetName(space)), "kCGColorSpaceSRGB")
        // an ICC space's is its profile
        var profile = [UInt8](repeating: 0, count: 128)
        profile.replaceSubrange(16 ..< 20, with: Array("GRAY".utf8))
        let icc = CGColorSpaceCreateWithICCData(Self.make(FakeData(profile)))
        XCTAssertEqual(CGColorSpaceGetModel(icc), 0)
        let data = CGColorSpaceCopyPropertyList(icc)!
        XCTAssertEqual(Self.take(data, as: FakeData.self)?.bytes, profile)
        XCTAssertEqual(CGColorSpaceGetModel(CGColorSpaceCreateWithPropertyList(data)), 0)
        let copied = CGColorSpaceCopyICCData(icc)
        XCTAssertEqual(copied.flatMap { Self.take(UnsafeRawPointer($0), as: FakeData.self)?.bytes }, profile)
    }

    // MARK: Colors

    func testConstantColors() {
        let white = CGColorGetConstantColor(Self.cf("kCGColorWhite"))
        XCTAssertNotNil(white)
        XCTAssertEqual(white, CGColorGetConstantColor(Self.cf("kCGColorWhite")))
        XCTAssertEqual(CGColorGetNumberOfComponents(white), 2)
        let space = CGColorGetColorSpace(white)
        XCTAssertEqual(Self.string(CGColorSpaceGetName(space)), "kCGColorSpaceGenericGrayGamma2_2")
        let clear = CGColorGetConstantColor(Self.cf("kCGColorClear"))
        XCTAssertEqual(CGColorGetAlpha(clear), 0)
        XCTAssertNil(CGColorGetConstantColor(Self.cf("kCGColorRed")))
    }

    func testGradientOfColors() {
        let red = CGColorCreateGenericRGB(1, 0, 0, 1)
        let blue = CGColorCreateGenericRGB(0, 0, 1, 1)
        let colors = OpaquePointer(Self.make(FakeArray([UnsafeRawPointer(red), UnsafeRawPointer(blue)])))
        XCTAssertNotNil(CGGradientCreateWithColors(nil, colors, nil))
        let empty = OpaquePointer(Self.make(FakeArray([])))
        XCTAssertNil(CGGradientCreateWithColors(nil, empty, nil))
    }

    // MARK: Paths

    func testSeparateComponents() {
        let path = CGPathCreateMutable()
        CGPathAddRect(path, nil, CGRect(origin: CGPoint(x: 0, y: 0), size: CGSize(width: 10, height: 10)))
        CGPathAddRect(path, nil, CGRect(origin: CGPoint(x: 20, y: 0), size: CGSize(width: 5, height: 5)))
        let array = CGPathCreateSeparateComponents(path, false)!
        let components = Self.take(UnsafeRawPointer(array), as: FakeArray.self)!.values
        XCTAssertEqual(components.count, 2)
        let largest = CGPathGetPathBoundingBox(OpaquePointer(components[0]))
        XCTAssertEqual(largest.size.width, 10, accuracy: 0.001)
    }

    func testNamesWithoutBridge() {
        CoreGraphicsObjects.coreFoundation = nil
        XCTAssertNil(CGColorSpaceGetName(CGColorSpaceCreateDeviceRGB()))
        XCTAssertNil(CGColorGetConstantColor(nil))
    }
}

#endif
