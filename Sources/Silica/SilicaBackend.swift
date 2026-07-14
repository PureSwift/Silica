//
//  SilicaBackend.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 7/13/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

import struct Foundation.Data

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

/// Global rendering backend registration.
public enum SilicaBackend {

    /// The default rendering backend.
    ///
    /// Backend libraries register themselves when a graphics context is created,
    /// or explicitly via their `register()` method (e.g. `CairoBackend.register()`).
    nonisolated(unsafe) public static var `default`: (any SilicaBackendProtocol.Type)?
}
