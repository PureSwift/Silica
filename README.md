# Silica

Pure Swift CoreGraphics (Quartz2D) implementation

Silica provides a CoreGraphics-compatible drawing API (plus a small UIKit shim) for porting UIKit and CoreGraphics drawing code across platforms. The public API is identical on every platform; rendering is performed by interchangeable backend libraries, each producing the same vector (PDF) output.

## Backends

| Platform | Library | Context | Renderer |
|----------|---------|---------|----------|
| macOS | `SilicaCoreGraphics` | `CoreGraphicsContext` | Apple CoreGraphics / CoreText / ImageIO |
| Linux (and macOS) | `SilicaCairo` | `CairoContext` | [Cairo](https://github.com/PureSwift/Cairo) / [FontConfig](https://github.com/PureSwift/FontConfig) / FreeType |
| Android | `SilicaAndroid` | `AndroidCanvasContext` | `android.graphics.Canvas` via [PureSwift/Android](https://github.com/PureSwift/Android) (JNI) |

The `Silica` library contains the shared API: the `CGContext` protocol and its derived drawing operations, the data types (`CGPath`, `CGColor`, `CGImage`, `CGFont`, `CGAffineTransform`, …) and the UIKit compatibility layer (`UIBezierPath`, `UIColor`, `UIFont`, `UIImage`, `NSString` drawing). Drawing code only needs `import Silica`; the backend library is imported where the graphics context is created.

## Usage

```swift
import Silica
import SilicaCoreGraphics // or SilicaCairo / SilicaAndroid

// each backend provides the same factory initializers
let context = try CoreGraphicsContext(pdf: url, size: CGSize(width: 200, height: 200))
// let context = try CairoContext(pdf: url, size: ...)
// let context = try AndroidCanvasContext(pdf: url, size: ...)

UIGraphicsPushContext(context)
// ... UIKit / CoreGraphics style drawing code ...
UIGraphicsPopContext()

try context.finish() // writes the PDF trailer
```

Each backend also offers `init(bitmap:)` for raster contexts (`makeImage()` returns the rendered `CGImage`) and an initializer wrapping a natively provided drawing target (`Cairo.Surface`, `CoreGraphics.CGContext`, `android.graphics.Canvas`).

Fonts and PNG decoding without an explicit context (`CGFont(name:)`, `UIFont(name:size:)`, `CGImageSourcePNG(data:)`) use the registered default backend. A backend registers itself when its first context is created, or explicitly:

```swift
CairoBackend.register() // or CoreGraphicsBackend / AndroidBackend
```

## Coordinate System

Silica uses a top-left origin, y-down coordinate system (UIKit convention) on every backend:

- **Cairo** and **Android Canvas** are natively y-down; no conversion is performed.
- **Apple CoreGraphics** is natively y-up with a bottom-left origin, so `CoreGraphicsContext` installs a vertical flip as the base transform of every page. Text, images, arcs, and shadows account for the flip internally.

Like UIKit, `draw(_ image:in:)` follows Apple's y-up image convention: drawing code flips the CTM around the destination rect to draw images upright, and clockwise arcs appear counterclockwise.

## Platform Notes

### macOS

The Cairo backend also builds and runs on macOS (`brew install cairo fontconfig freetype`), which is how the test suite compares both backends' output of identical drawing code.

### Android

- Requires **API 31+** at runtime for glyph rendering (`Canvas.drawGlyphs`, `TextRunShaper`).
- `finish()` is **mandatory** for PDF contexts — the document is only written to disk when it is called.
- JNI-backed objects must be used from a JVM-attached thread; create, use, and finish a context on the same thread.
- The linear (scale/rotation) components of the text matrix are not applied to glyph shapes.
- Unknown font names fall back to the system typeface (Android provides no font-matching failure signal).

### Rendering Differences

- **Shadows**: CoreGraphics renders true Gaussian-blurred shadows; the Cairo and Android backends emulate shadows without blur (a silhouette at the shadow offset).
- **Fonts**: font resolution is fuzzy on Linux (FontConfig) and Android (Typeface), but strict on macOS (CoreText descriptor matching by PostScript name or family name, with camel-case expansion, e.g. `"TimesNewRoman-Bold"` → family *Times New Roman*, bold).
- Global alpha applies to images on the CoreGraphics backend but not on the Cairo backend.

## Dependencies

- Linux/macOS (Cairo backend): `cairo`, `fontconfig`, `freetype` system libraries.
- Android: [PureSwift/Android](https://github.com/PureSwift/Android) (pulled automatically; only built when compiling for Android).
- macOS (CoreGraphics backend): system frameworks only.
