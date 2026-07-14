# Silica

Pure Swift CoreGraphics (Quartz2D) implementation

Silica provides a CoreGraphics-compatible drawing API (plus a small UIKit shim) for porting UIKit and CoreGraphics drawing code across platforms. The public API is identical on every platform; rendering is performed by interchangeable backend libraries, each producing the same vector (PDF) output.

## Backends

| Platform | Library | Context | Renderer |
|----------|---------|---------|----------|
| macOS | `SilicaCoreGraphics` | `CoreGraphicsContext` | Apple CoreGraphics / CoreText / ImageIO |
| Linux (and macOS) | `SilicaCairo` | `CairoContext` | [Cairo](https://github.com/PureSwift/Cairo) / [FontConfig](https://github.com/PureSwift/FontConfig) / FreeType |
| Android | `SilicaAndroid` | `AndroidCanvasContext` | `android.graphics.Canvas` via [PureSwift/Android](https://github.com/PureSwift/Android) (JNI) |
| WebAssembly | `SilicaWeb` | `WebCanvasContext` | Web Canvas API (`CanvasRenderingContext2D`) via [JavaScriptKit](https://github.com/swiftwasm/JavaScriptKit), including Embedded Swift |

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
CairoBackend.register() // or CoreGraphicsBackend / AndroidBackend / WebBackend
```

## Coordinate System

Silica uses a top-left origin, y-down coordinate system (UIKit convention) on every backend:

- **Cairo** and **Android Canvas** are natively y-down; no conversion is performed.
- **Apple CoreGraphics** is natively y-up with a bottom-left origin, so `CoreGraphicsContext` installs a vertical flip as the base transform of every page. Text, images, arcs, and shadows account for the flip internally.

Like UIKit, `draw(_ image:in:)` follows Apple's y-up image convention: drawing code flips the CTM around the destination rect to draw images upright, and clockwise arcs appear counterclockwise.

The Cairo backend also supports an opt-in bottom-left origin mode matching a raw CoreGraphics bitmap context — `CairoContext(surface:size:flipped: false)` — where text draws upright from the baseline (see `isFlipped`).

## Platform Notes

### macOS

The Cairo backend also builds and runs on macOS (`brew install cairo fontconfig freetype`), which is how the test suite compares both backends' output of identical drawing code.

### Android

- Requires **API 31+** at runtime for glyph rendering (`Canvas.drawGlyphs`, `TextRunShaper`).
- `finish()` is **mandatory** for PDF contexts — the document is only written to disk when it is called.
- JNI-backed objects must be used from a JVM-attached thread; create, use, and finish a context on the same thread.
- The linear (scale/rotation) components of the text matrix are not applied to glyph shapes.
- Unknown font names fall back to the system typeface (Android provides no font-matching failure signal).

### WebAssembly

The `SilicaWeb` backend draws onto an `HTMLCanvasElement` or `OffscreenCanvas` through the Web Canvas API and builds with both the regular (`swift-<version>-RELEASE_wasm`) and **Embedded Swift** (`swift-<version>-RELEASE_wasm-embedded`) WebAssembly SDKs — the core `Silica` module is Foundation-free when compiled for Embedded Swift:

```swift
import JavaScriptKit
import SilicaWeb

let canvas = JSObject.global.document.createElement("canvas")
let context = try WebCanvasContext(canvas: canvas.object!)
// ... CoreGraphics style drawing code ...
```

```sh
swift build --swift-sdk swift-6.3.3-RELEASE_wasm-embedded --target SilicaWeb
```

See [`Examples/WebCanvasDemo`](Examples/WebCanvasDemo) for a complete browser app built with the [PackageToJS](https://swiftpackageindex.com/swiftwasm/JavaScriptKit/main/documentation/javascriptkit/packagetojs) plugin (`swift package --swift-sdk <sdk-id> js`). It renders the same `TestStyleKit` (PaintCode-generated) drawing methods that `SilicaCairoTests` renders to PDF with the Cairo backend, plus a showcase panel of paths, arcs, transforms, transparency layers, clipping, and bitmap round-tripping:

```sh
cd Examples/WebCanvasDemo
swift package --swift-sdk swift-6.3.3-RELEASE_wasm js --use-cdn   # regular SDK

# the Embedded SDK build needs the Unicode data tables linked (see Package.swift)
# and skips the two panels that use `String.draw(in:withAttributes:)` ([String: Any])
SILICA_WASM_EMBEDDED=1 swift package --swift-sdk swift-6.3.3-RELEASE_wasm-embedded js --use-cdn

npx serve .   # then open index.html
```

Web platform notes:

- Page-based (PDF) output is not supported; `WebCanvasContext` is a bitmap destination.
- Glyph indices are Unicode scalar values (the Canvas API exposes no font tables), rendered with `fillText`; metrics come from `measureText`. Scalars outside the Basic Multilingual Plane map to glyph 0.
- `decodePNG` is unavailable (the web only decodes images asynchronously); create a `CGImage` from an `ImageData` object instead, or draw `HTMLImageElement`/`ImageBitmap` directly onto the canvas. `encodePNG` requires a DOM document (`canvas.toDataURL`).
- Shape antialiasing cannot be disabled; `shouldAntialias` only controls image smoothing.
- Font names resolve as CSS font families (with camel-case expansion, e.g. `"TimesNewRoman-Bold"` → `"Times New Roman"`, bold), falling back to `sans-serif`.
- Executables built with the Embedded Swift SDK must link the Unicode data tables: `.linkedLibrary("swiftUnicodeDataTables", .when(platforms: [.wasi]))`.

### Rendering Differences

- **Shadows**: CoreGraphics renders true Gaussian-blurred shadows; the Cairo and Android backends emulate shadows without blur (a silhouette at the shadow offset).
- **Fonts**: font resolution is fuzzy on Linux (FontConfig) and Android (Typeface), but strict on macOS (CoreText descriptor matching by PostScript name or family name, with camel-case expansion, e.g. `"TimesNewRoman-Bold"` → family *Times New Roman*, bold).
- Global alpha applies to images on the CoreGraphics backend but not on the Cairo backend.

## Dependencies

- Linux/macOS (Cairo backend): `cairo`, `fontconfig`, `freetype` system libraries.
- Android: [PureSwift/Android](https://github.com/PureSwift/Android) (pulled automatically; only built when compiling for Android).
- macOS (CoreGraphics backend): system frameworks only.
- WebAssembly: [JavaScriptKit](https://github.com/swiftwasm/JavaScriptKit) (pulled automatically; only built when compiling for WebAssembly).
