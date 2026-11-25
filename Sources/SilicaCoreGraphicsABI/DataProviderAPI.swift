//
//  DataProviderAPI.swift
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

#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#endif

// The functions of CGDataProvider.h.

/// What a `CGDataProviderRef` points to: bytes, read when it's made, or
/// someone else's, used where they are until the provider goes.
internal final class DataProviderObject {

    let info: UnsafeMutableRawPointer?

    private let storage: [UInt8]
    private let external: UnsafeRawBufferPointer?
    private let onRelease: () -> Void

    /// Bytes of its own.
    init(bytes: [UInt8], info: UnsafeMutableRawPointer? = nil, onRelease: @escaping () -> Void = { }) {
        self.storage = bytes
        self.external = nil
        self.info = info
        self.onRelease = onRelease
    }

    /// Someone else's bytes.
    init(external: UnsafeRawBufferPointer, info: UnsafeMutableRawPointer?, onRelease: @escaping () -> Void) {
        self.storage = []
        self.external = external
        self.info = info
        self.onRelease = onRelease
    }

    deinit {
        onRelease()
    }

    var count: Int { external?.count ?? storage.count }

    func withUnsafeBytes<T>(_ body: (UnsafeRawBufferPointer) -> T) -> T {
        if let external { return body(external) }
        return storage.withUnsafeBytes(body)
    }

    /// A copy of the bytes.
    var bytes: [UInt8] {
        withUnsafeBytes { [UInt8]($0) }
    }
}

@c @implementation public func CGDataProviderGetTypeID() -> UInt {
    CoreGraphicsObjects.typeID(of: .dataProvider)
}

@c @implementation public func CGDataProviderCreateSequential(_ info: UnsafeMutableRawPointer?,
                                                              _ callbacks: UnsafePointer<CGDataProviderSequentialCallbacks>?) -> SilicaCGDataProviderRef? {
    guard let callbacks = callbacks?.pointee, let getBytes = callbacks.getBytes else { return nil }
    var bytes: [UInt8] = []
    var buffer = [UInt8](repeating: 0, count: 1 << 16)
    while true {
        let read = buffer.withUnsafeMutableBytes { getBytes(info, $0.baseAddress!, $0.count) }
        guard read > 0 else { break }
        bytes.append(contentsOf: buffer[0 ..< min(read, buffer.count)])
    }
    let releaseInfo = callbacks.releaseInfo
    return makeReference(DataProviderObject(bytes: bytes, info: info) { releaseInfo?(info) })
}

@c @implementation public func CGDataProviderCreateDirect(_ info: UnsafeMutableRawPointer?, _ size: off_t,
                                                          _ callbacks: UnsafePointer<CGDataProviderDirectCallbacks>?) -> SilicaCGDataProviderRef? {
    guard let callbacks = callbacks?.pointee, size >= 0 else { return nil }
    let count = Int(size)
    var bytes = [UInt8](repeating: 0, count: count)
    if let getBytePointer = callbacks.getBytePointer, let pointer = getBytePointer(info) {
        bytes.withUnsafeMutableBytes { _ = memcpy($0.baseAddress!, pointer, count) }
        callbacks.releaseBytePointer?(info, pointer)
    } else if let getBytesAtPosition = callbacks.getBytesAtPosition {
        var offset = 0
        while offset < count {
            let read = bytes.withUnsafeMutableBytes { getBytesAtPosition(info, $0.baseAddress! + offset, off_t(offset), count - offset) }
            guard read > 0 else { break }
            offset += read
        }
    } else {
        return nil
    }
    let releaseInfo = callbacks.releaseInfo
    return makeReference(DataProviderObject(bytes: bytes, info: info) { releaseInfo?(info) })
}

@c @implementation public func CGDataProviderCreateWithData(_ info: UnsafeMutableRawPointer?, _ data: UnsafeRawPointer?, _ size: Int,
                                                            _ releaseData: CGDataProviderReleaseDataCallback?) -> SilicaCGDataProviderRef? {
    guard let data, size >= 0 else { return nil }
    // the info is only for the callback: CGDataProviderGetInfo doesn't give it, as on Darwin
    return makeReference(DataProviderObject(external: UnsafeRawBufferPointer(start: data, count: size), info: nil) {
        releaseData?(info, data, size)
    })
}

@c @implementation public func CGDataProviderCreateWithFilename(_ filename: UnsafePointer<CChar>?) -> SilicaCGDataProviderRef? {
    guard let filename, let bytes = readFile(String(cString: filename)) else { return nil }
    return makeReference(DataProviderObject(bytes: bytes))
}

@c @implementation public func CGDataProviderCreateWithCFData(_ data: SilicaCFDataRef?) -> SilicaCGDataProviderRef? {
    guard let data, let bridge = CoreGraphicsObjects.coreFoundation, let bytes = bridge.data(UnsafeRawPointer(data)) else { return nil }
    return makeReference(DataProviderObject(bytes: bytes))
}

@c @implementation public func CGDataProviderCreateWithURL(_ url: SilicaCFURLRef?) -> SilicaCGDataProviderRef? {
    guard let url, let bridge = CoreGraphicsObjects.coreFoundation, let path = bridge.filePath(UnsafeRawPointer(url)),
          let bytes = readFile(path) else { return nil }
    return makeReference(DataProviderObject(bytes: bytes))
}

@c @implementation public func CGDataProviderRetain(_ provider: SilicaCGDataProviderRef?) -> SilicaCGDataProviderRef? {
    retain(provider)
    return provider
}

@c @implementation public func CGDataProviderRelease(_ provider: SilicaCGDataProviderRef?) {
    release(provider)
}

@c @implementation public func CGDataProviderCopyData(_ provider: SilicaCGDataProviderRef?) -> SilicaCFDataRef? {
    makeCFData(object(provider, as: DataProviderObject.self)?.bytes)
}

@c @implementation public func CGDataProviderGetInfo(_ provider: SilicaCGDataProviderRef?) -> UnsafeMutableRawPointer? {
    object(provider, as: DataProviderObject.self)?.info
}

/// A file's bytes, or nil if it can't be read.
internal func readFile(_ path: String) -> [UInt8]? {
    guard let file = fopen(path, "rb") else { return nil }
    defer { fclose(file) }
    var bytes: [UInt8] = []
    var buffer = [UInt8](repeating: 0, count: 1 << 16)
    while true {
        let read = buffer.withUnsafeMutableBytes { fread($0.baseAddress!, 1, $0.count, file) }
        guard read > 0 else { break }
        bytes.append(contentsOf: buffer[0 ..< read])
    }
    return ferror(file) == 0 ? bytes : nil
}

#endif
