//
//  GSPFramebuffer.swift
//  Silica3DS
//
//  Created by Alsey Coleman Miller on 7/13/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

#if canImport(Foundation)
import Foundation
#endif
#if canImport(Silica)
import Silica
#endif

/// Pixel formats of the 3DS GSP framebuffers.
public enum GSPFramebufferFormat {

    /// 24-bit BGR (`GSP_BGR8_OES`, the default framebuffer format).
    case bgr8

    /// 32-bit RGBA (`GSP_RGBA8_OES`).
    case rgba8

    /// 16-bit RGB565 (`GSP_RGB565_OES`).
    case rgb565

    public var bytesPerPixel: Int {
        switch self {
        case .bgr8: return 3
        case .rgba8: return 4
        case .rgb565: return 2
        }
    }
}

public extension Nintendo3DSContext {

    /// Copies the rendered contents into a Nintendo 3DS GSP framebuffer.
    ///
    /// 3DS framebuffers are rotated 90°: for a logical `width × height` screen
    /// (e.g. 400×240 for the top screen), the framebuffer is `height` pixels
    /// wide with column-major addressing — the logical pixel `(x, y)` lives at
    /// byte offset `((x * height) + (height - 1 - y)) * bytesPerPixel`.
    ///
    /// The buffer must hold at least `width × height × bytesPerPixel` bytes
    /// for this context's size. Pixels are composited against black
    /// (framebuffers have no alpha).
    func present(into framebuffer: UnsafeMutableRawPointer, format: GSPFramebufferFormat = .bgr8) {

        guard let image = makeImage()
            else { return }

        let width = image.width
        let height = image.height
        let bytesPerPixel = format.bytesPerPixel

        let destination = framebuffer.assumingMemoryBound(to: UInt8.self)

        image.data.withUnsafeBytes { (source: UnsafeRawBufferPointer) in

            let bytes = source.baseAddress!.assumingMemoryBound(to: UInt8.self)

            for y in 0 ..< height {
                for x in 0 ..< width {

                    let sourceOffset = y * image.bytesPerRow + x * 4

                    // premultiplied over an opaque black background
                    let red = bytes[sourceOffset]
                    let green = bytes[sourceOffset + 1]
                    let blue = bytes[sourceOffset + 2]

                    let destinationOffset = ((x * height) + (height - 1 - y)) * bytesPerPixel

                    switch format {

                    case .bgr8:
                        destination[destinationOffset]     = blue
                        destination[destinationOffset + 1] = green
                        destination[destinationOffset + 2] = red

                    case .rgba8:
                        destination[destinationOffset]     = bytes[sourceOffset + 3]
                        destination[destinationOffset + 1] = blue
                        destination[destinationOffset + 2] = green
                        destination[destinationOffset + 3] = red

                    case .rgb565:
                        // rrrrrggggggbbbbb, per libctru's RGB565 macro
                        let value = (UInt16(red >> 3) << 11) | (UInt16(green >> 2) << 5) | UInt16(blue >> 3)
                        destination[destinationOffset]     = UInt8(value & 0xFF)
                        destination[destinationOffset + 1] = UInt8(value >> 8)
                    }
                }
            }
        }
    }
}

public extension Nintendo3DSContext {

    /// A physical 3DS screen.
    enum Screen: Sendable {

        /// The 400×240 top screen.
        case top

        /// The 320×240 bottom screen.
        case bottom

        public var size: CGSize {
            switch self {
            case .top: return CGSize(width: 400, height: 240)
            case .bottom: return CGSize(width: 320, height: 240)
            }
        }
    }
}

#if canImport(CTRU)

// Active when building with Embedded Swift against devkitPro's libctru
// (see ports/3DS), which exposes <3ds.h> to Swift as the `CTRU` module.

import CTRU

internal extension Nintendo3DSContext.Screen {

    var gfxScreen: gfxScreen_t {
        switch self {
        case .top: return GFX_TOP
        case .bottom: return GFX_BOTTOM
        }
    }
}

public extension Nintendo3DSContext {

    /// Creates a software drawing destination for a 3DS screen.
    ///
    /// Call `present()` after drawing to copy the contents into the current
    /// GSP framebuffer and flush it to the display.
    convenience init(screen: Screen, scale: Int = 1) throws(SilicaError) {

        try self.init(bitmap: screen.size, scale: scale)
        self.screen = screen
    }

    /// Presents the rendered contents on the associated screen.
    func present() {

        guard let screen = self.screen
            else { assertionFailure("Not a screen context"); return }

        guard let framebuffer = gfxGetFramebuffer(screen.gfxScreen, GFX_LEFT, nil, nil)
            else { return }

        present(into: UnsafeMutableRawPointer(framebuffer), format: .bgr8)

        gfxFlushBuffers()
        gfxScreenSwapBuffers(screen.gfxScreen, true)
        // gspWaitForVBlank() is a function-like macro the Clang importer can't
        // surface; call what it expands to directly.
        gspWaitForEvent(GSPGPU_EVENT_VBlank0, true)
    }
}

#endif // canImport(CTRU)
