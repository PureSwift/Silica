//
//  SilicaBackend.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 7/13/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

#if !canImport(Darwin) && canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif

/// A rendering backend: what draws without a context of its own, such as
/// fonts by name (`Font(name:size:)`), PNG decoding (`Image(png:)`) and
/// bitmaps (`BitmapContext`).
public protocol SilicaBackendProtocol {

    /// A platform font by name (e.g. `"TimesNewRoman-Bold"`).
    static func fontFace(named name: String) -> (any FontFace)?

    /// Decodes PNG data into an image.
    static func decodePNG(_ data: Data) -> Image?

    /// Encodes an image as PNG data.
    static func encodePNG(_ image: Image) -> Data?

    /// A bitmap renderer `size` points across, with `scale` pixels per point.
    static func makeBitmapRenderer(size: Size, scale: Double) -> (any Renderer)?
}

/// The registered default rendering backend.
///
/// A backend registers itself when its first renderer is made, or with its
/// `register()` method (e.g. `CairoBackend.register()`).
public enum SilicaBackend {

    /// Entry points of a registered backend. Embedded Swift has no
    /// existential metatypes, so the backend is kept as these.
    public struct Backend {

        /// The backend's name, which keys the font cache.
        public let name: String

        public let fontFace: (String) -> (any FontFace)?

        public let decodePNG: (Data) -> Image?

        public let encodePNG: (Image) -> Data?

        public let makeBitmapRenderer: (Size, Double) -> (any Renderer)?
    }

    /// The default backend.
    nonisolated(unsafe) public static var `default`: Backend?

    /// Fonts loaded so far, by backend and name.
    nonisolated(unsafe) internal static var fontFaces: [String: any FontFace] = [:]

    /// Makes a backend the default.
    public static func register<T: SilicaBackendProtocol>(_ backend: T.Type, name: String) {
        `default` = Backend(
            name: name,
            fontFace: { T.fontFace(named: $0) },
            decodePNG: { T.decodePNG($0) },
            encodePNG: { T.encodePNG($0) },
            makeBitmapRenderer: { T.makeBitmapRenderer(size: $0, scale: $1) }
        )
    }

    /// Makes a backend the default if there isn't one.
    public static func registerIfNeeded<T: SilicaBackendProtocol>(_ backend: T.Type, name: String) {
        guard `default` == nil else { return }
        register(backend, name: name)
    }

    /// A font by name from the default backend, loaded once.
    public static func fontFace(named name: String) -> (any FontFace)? {
        guard let backend = `default` else { return nil }
        let key = backend.name + "/" + name
        if let face = fontFaces[key] {
            return face
        }
        guard let face = backend.fontFace(name) else { return nil }
        fontFaces[key] = face
        return face
    }

    /// Decodes PNG data with the default backend.
    public static func decodePNG(_ data: Data) -> Image? {
        `default`?.decodePNG(data)
    }

    /// Encodes an image as PNG with the default backend.
    public static func encodePNG(_ image: Image) -> Data? {
        `default`?.encodePNG(image)
    }

    /// A bitmap renderer from the default backend.
    public static func makeBitmapRenderer(size: Size, scale: Double) -> (any Renderer)? {
        `default`?.makeBitmapRenderer(size, scale)
    }
}
