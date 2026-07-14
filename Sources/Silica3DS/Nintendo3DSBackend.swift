//
//  Nintendo3DSBackend.swift
//  Silica3DS
//
//  Created by Alsey Coleman Miller on 7/13/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

#if canImport(Foundation)

import struct Foundation.Data
import Silica

/// Nintendo 3DS software rendering backend.
public enum Nintendo3DSBackend: SilicaBackendProtocol {

    /// Registers the 3DS software renderer as the default rendering backend.
    public static func register() {

        SilicaBackend.default = Nintendo3DSBackend.self
    }

    internal static func registerIfNeeded() {

        guard SilicaBackend.default == nil else { return }
        register()
    }

    // MARK: - SilicaBackendProtocol

    /// The 3DS backend has no font source yet
    /// (the system font would require `fontGetSystemFont` via libctru).
    public static func font(named name: String) -> Silica.CGFont? {

        return nil
    }

    /// The 3DS backend has no PNG codec yet.
    public static func decodePNG(_ data: Data) -> Silica.CGImage? {

        return nil
    }

    /// The 3DS backend has no PNG codec yet.
    public static func encodePNG(_ image: Silica.CGImage) -> Data? {

        return nil
    }
}

#endif // canImport(Foundation)
