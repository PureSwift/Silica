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

/// Cairo rendering backend.
public enum CairoBackend: SilicaBackendProtocol {

    /// Registers Cairo as the default rendering backend.
    public static func register() {

        SilicaBackend.default = CairoBackend.self
    }

    internal static func registerIfNeeded() {

        guard SilicaBackend.default == nil else { return }
        register()
    }

    // MARK: - SilicaBackendProtocol

    public static func font(named name: String) -> Silica.CGFont? {

        return CGFont(name: name, configuration: .current)
    }

    public static func decodePNG(_ data: Data) -> Silica.CGImage? {

        guard let decoded = try? Cairo.Surface.Image(png: data)
            else { return nil }

        // normalize to ARGB32 (PNG decoding may produce RGB24 or A8 surfaces)
        guard let normalized = try? Cairo.Surface.Image(format: .argb32,
                                                        width: decoded.width,
                                                        height: decoded.height)
            else { return nil }

        let context = Cairo.Context(surface: normalized)
        context.source = Pattern(surface: decoded)
        context.paint()
        normalized.flush()

        return CGImage(cairo: normalized)
    }
}

#endif
