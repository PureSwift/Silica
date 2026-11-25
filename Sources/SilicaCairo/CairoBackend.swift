//
//  CairoBackend.swift
//  SilicaCairo
//
//  Created by Alsey Coleman Miller on 7/13/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

#if canImport(Cairo)

import struct Foundation.Data
import Cairo
import Silica

/// The Cairo rendering backend: fonts from FontConfig, PNG codecs and bitmaps from Cairo.
public enum CairoBackend: SilicaBackendProtocol {

    /// Makes Cairo the default rendering backend.
    public static func register() {
        SilicaBackend.register(CairoBackend.self, name: "Cairo")
    }

    internal static func registerIfNeeded() {
        SilicaBackend.registerIfNeeded(CairoBackend.self, name: "Cairo")
    }

    // MARK: - SilicaBackendProtocol

    public static func fontFace(named name: String) -> (any Silica.FontFace)? {
        CairoFontHandle(named: name)
    }

    public static func decodePNG(_ data: Data) -> Silica.Image? {
        guard let decoded = try? Cairo.Surface.Image(png: data) else { return nil }
        // PNGs decode to RGB24 or A8 surfaces too
        guard let normalized = try? Cairo.Surface.Image(format: .argb32, width: decoded.width, height: decoded.height)
            else { return nil }
        let context = Cairo.Context(surface: normalized)
        context.source = Pattern(surface: decoded)
        context.paint()
        normalized.flush()
        return Silica.Image(cairo: normalized)
    }

    public static func encodePNG(_ image: Silica.Image) -> Data? {
        guard let surface = try? Cairo.Surface.Image(image) else { return nil }
        return try? surface.writePNG()
    }

    public static func makeBitmapRenderer(size: Size, scale: Double) -> (any Renderer)? {
        try? CairoRenderer(bitmap: size, scale: scale)
    }
}

#endif
