//
//  Nintendo3DSBackend.swift
//  Silica3DS
//
//  Created by Alsey Coleman Miller on 7/13/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

#if canImport(Foundation)
import struct Foundation.Data
#endif
#if canImport(Silica)
import Silica
#endif

/// The Nintendo 3DS rendering backend: bitmaps from the software rasterizer.
/// It has no fonts or PNG codecs yet.
public enum Nintendo3DSBackend: SilicaBackendProtocol {

    /// Makes the 3DS software renderer the default rendering backend.
    public static func register() {
        SilicaBackend.register(Nintendo3DSBackend.self, name: "Nintendo3DS")
    }

    internal static func registerIfNeeded() {
        SilicaBackend.registerIfNeeded(Nintendo3DSBackend.self, name: "Nintendo3DS")
    }

    // MARK: - SilicaBackendProtocol

    /// None yet: the system font would need `fontGetSystemFont` from libctru.
    public static func fontFace(named name: String) -> (any FontFace)? {
        nil
    }

    /// None yet: there's no PNG codec.
    public static func decodePNG(_ data: Data) -> Image? {
        nil
    }

    /// None yet: there's no PNG codec.
    public static func encodePNG(_ image: Image) -> Data? {
        nil
    }

    /// A bitmap supersampled at the scale, rounded up.
    public static func makeBitmapRenderer(size: Size, scale: Double) -> (any Renderer)? {
        try? Nintendo3DSRenderer(bitmap: size, scale: Int(scale.rounded(.up)))
    }
}
