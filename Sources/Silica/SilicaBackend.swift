//
//  SilicaBackend.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 7/13/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

#if canImport(Foundation)
import struct Foundation.Data
#endif

/// A rendering backend providing fonts and image decoding for operations
/// performed without an explicit graphics context
/// (e.g. `CGFont(name:)`, `UIFont(name:size:)`, `CGImageSourcePNG(data:)`).
public protocol SilicaBackendProtocol {

    /// Loads the platform font with the specified Silica font name (e.g. `"TimesNewRoman-Bold"`).
    static func font(named name: String) -> CGFont?

    /// Decodes PNG data into a bitmap image.
    static func decodePNG(_ data: Data) -> CGImage?

    /// Encodes a bitmap image as PNG data.
    static func encodePNG(_ image: CGImage) -> Data?
}

#if canImport(Foundation)

/// Global rendering backend registration.
public enum SilicaBackend {

    /// The default rendering backend.
    ///
    /// Backend libraries register themselves when a graphics context is created,
    /// or explicitly via their `register()` method (e.g. `CairoBackend.register()`).
    nonisolated(unsafe) public static var `default`: (any SilicaBackendProtocol.Type)?
}

#else

/// Global rendering backend registration.
///
/// Embedded Swift does not support protocol metatype existentials, so the
/// registered backend is stored as a set of entry points instead.
public enum SilicaBackend {

    /// Entry points of a registered rendering backend.
    public struct Backend {

        /// Backend name, used to key the font cache.
        public let name: String

        public let font: (String) -> CGFont?

        public let decodePNG: (Data) -> CGImage?

        public let encodePNG: (CGImage) -> Data?
    }

    /// The default rendering backend.
    ///
    /// Backend libraries register themselves when a graphics context is created,
    /// or explicitly via their `register()` method (e.g. `WebBackend.register()`).
    nonisolated(unsafe) public static var `default`: Backend?

    /// Registers the specified backend type as the default rendering backend.
    public static func register<T: SilicaBackendProtocol>(_ backend: T.Type, name: String) {

        `default` = Backend(
            name: name,
            font: { T.font(named: $0) },
            decodePNG: { T.decodePNG($0) },
            encodePNG: { T.encodePNG($0) }
        )
    }
}

#endif
