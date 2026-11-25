# Silica

Pure Swift 2D vector graphics

Silica is a 2D drawing API in idiomatic Swift, with CoreGraphics' model and method names and none of its `CG` prefixes, drawn by interchangeable backends: Cairo, Apple's Quartz, the Web Canvas, Android's Canvas, and a pure-Swift rasterizer. The same drawing code produces the same output (PDF or pixels) on every platform.

```swift
import SilicaCairo // or SilicaQuartz, Silica3DS, SilicaWeb, AndroidSilica

let context = GraphicsContext(try CairoRenderer(pdf: url, size: Size(width: 200, height: 200)))

context.setFillColor(Color(red: 0.95, green: 0.32, blue: 0.21))
context.addEllipse(in: Rect(x: 20, y: 20, width: 160, height: 160))
context.fillPath()

context.font = Font(name: "Helvetica-Bold", size: 24)
context.fillColor = .white
context.draw("Silica", at: Point(x: 100, y: 100), anchor: .center)

try context.finish() // writes the PDF
```

## Backends

| Platform | Library | Renderer | Draws with |
|----------|---------|----------|------------|
| Apple platforms | `SilicaQuartz` | `QuartzRenderer` | Apple Core Graphics / Core Text / ImageIO |
| Linux (and macOS) | `SilicaCairo` | `CairoRenderer` | [Cairo](https://github.com/PureSwift/Cairo) / [FontConfig](https://github.com/PureSwift/FontConfig) / FreeType |
| Android | `AndroidSilica`, in [PureSwift/Android](https://github.com/PureSwift/Android) | `AndroidCanvasContext`, until it moves to `Renderer` | `android.graphics.Canvas` (JNI) |
| Nintendo 3DS (experimental) | `Silica3DS` | `Nintendo3DSRenderer` | Built-in pure-Swift software rasterizer |
| WebAssembly | `SilicaWeb` | `WebCanvasRenderer` | Web Canvas API (`CanvasRenderingContext2D`) via [JavaScriptKit](https://github.com/swiftwasm/JavaScriptKit), including Embedded Swift |

The `Silica` module is the API, and has no dependencies:

- **Geometry**: `Point`, `Size`, `Rect`, `Vector`, `UnitPoint` and `AffineTransform`, in `Double`.
- **`Path`**: a value type of lines and quadratic and cubic curves, with rectangles, rounded rectangles, ellipses and arcs added as curves. It answers `boundingRect`, `contains(_:using:)`, `currentPoint` and `applying(_:)` itself.
- **Styles**: `Color` (sRGB), `Gradient`, `StrokeStyle`, `Shadow`, `LineCap`, `LineJoin`, `FillRule`, `DrawingMode`, `BlendMode`.
- **`Font`** (a platform font at a size) and **`Image`** (premultiplied RGBA pixels).
- **`GraphicsContext`**: a class with CoreGraphics' methods (`saveGState()`, `translateBy(x:y:)`, `addArc(center:radius:startAngle:endAngle:clockwise:)`, `fillPath(using:)`, `drawLinearGradient(_:start:end:options:)`, `beginTransparencyLayer()`, …), and SwiftUI's spellings that cost nothing (`fill(_:with:)`, `stroke(_:with:style:)`, `clip(to:)`, `opacity`, `drawLayer(_:)`). It keeps the transform, the current path and the graphics state in Swift, so reading them never asks the backend.
- **`Renderer`**: the protocol a backend implements. Each method is one drawing command (fill a path, stroke a path, clip, draw an image, glyphs, a gradient, a layer), so a recorded drawing replays into a renderer one command at a time.
- **`BitmapContext`**: a context drawing off screen with the registered default backend.

Code written for `CGContext` ports by dropping the prefix from its types; `CGFloat` is `Double`.

Each renderer has `init(pdf:size:)` (where its platform makes PDFs), `init(bitmap:scale:)` for pixels (`makeImage()` returns them), and an initializer wrapping the platform's own drawing target (`Cairo.Surface`, `CoreGraphics.CGContext`, `android.graphics.Canvas`, an HTML canvas).

Fonts by name (`Font(name:size:)`), PNG decoding (`Image(png:)`) and `BitmapContext` use the registered default backend. A backend registers itself when its first renderer is made, or explicitly:

```swift
CairoBackend.register() // or QuartzBackend / Nintendo3DSBackend / WebBackend / AndroidBackend
```

### Foundation's `AffineTransform`

Foundation has an `AffineTransform` too, so in a file that imports both Foundation and Silica the name is ambiguous. Write `Silica.AffineTransform`, or declare `typealias AffineTransform = Silica.AffineTransform` once in your module.

## Coordinate System

The origin is at the top left and y points down, in points, on every backend, as in UIKit and SwiftUI:

- **Cairo**, **Android Canvas** and the **Web Canvas** are natively y-down; no conversion is performed.
- **Quartz** is natively y-up from the bottom left, so `QuartzRenderer` installs a vertical flip as the base transform of every page. Text, images and shadows account for the flip.

An image draws upright, filling its rectangle as SwiftUI draws it. Arcs keep CoreGraphics' arithmetic: with y down, `clockwise: true` looks counterclockwise, as it does in a flipped `CGContext` and in SwiftUI's `Path`. Glyphs are positioned by their baseline, as in CoreGraphics.

`GraphicsContext(renderer, origin: .bottomLeft)` puts the origin at the bottom left with y up, as in a CoreGraphics bitmap context; text and images still draw upright.

## Package Traits

Silica's `Cairo` and `Web` traits build the Cairo and web renderers, and are on by default. A package that needs only the `Silica` module turns them off, and the Cairo, FontConfig and JavaScriptKit packages aren't fetched:

```swift
.package(url: "https://github.com/PureSwift/Silica.git", from: "4.0.0", traits: [])
```

## Platform Notes

### macOS

The Cairo backend also builds and runs on macOS (`brew install cairo fontconfig freetype`), which is how the test suite compares both backends' output of identical drawing code.

### Android

The Android backend is `AndroidSilica`, a product of [PureSwift/Android](https://github.com/PureSwift/Android); its README has the platform notes.

### Nintendo 3DS

The 3DS has no system vector graphics library, so `Silica3DS` rasterizes in pure Swift into an RGBA bitmap (scanline fills with both winding rules, stroking with caps/joins/dashes, clip masks, transparency layers, blur-less shadows, and optional supersampling). The renderer is platform-neutral: bitmap contexts build and are pixel-tested on every host.

`ports/3DS` builds a homebrew `.3dsx` demo with **Embedded Swift** (`armv6-none-none-eabi`, Swift 6.3.2+) against devkitPro's libctru, following the same structure as [junkbot-swift](https://github.com/colemancda/junkbot-swift)'s 3DS port — verified running in the Azahar emulator. `present()` copies the rendered bitmap into the GSP framebuffer (rotated 90°, column-major). Text and PNG codecs are unavailable on this backend, and non-ASCII string comparison traps (the embedded Unicode tables are soft-float; the 3DS ABI is hard-float).

### WebAssembly

The `SilicaWeb` backend draws onto an `HTMLCanvasElement` or `OffscreenCanvas` through the Web Canvas API and builds with both the regular (`swift-<version>-RELEASE_wasm`) and **Embedded Swift** (`swift-<version>-RELEASE_wasm-embedded`) WebAssembly SDKs — the core `Silica` module is Foundation-free when compiled for Embedded Swift:

```swift
import JavaScriptKit
import SilicaWeb

let canvas = JSObject.global.document.createElement("canvas")
let context = GraphicsContext(try WebCanvasRenderer(canvas: canvas.object!))
// ... drawing code ...
```

```sh
swift build --swift-sdk swift-6.3.3-RELEASE_wasm-embedded --target SilicaWeb
```

See [`Examples/WebCanvasDemo`](Examples/WebCanvasDemo) for a complete browser app built with the [PackageToJS](https://swiftpackageindex.com/swiftwasm/JavaScriptKit/main/documentation/javascriptkit/packagetojs) plugin (`swift package --swift-sdk <sdk-id> js`). It renders the same `TestStyleKit` (PaintCode-generated) drawing methods that `SilicaCairoTests` renders to PDF with the Cairo backend, plus a showcase panel of paths, arcs, transforms, transparency layers, clipping, and bitmap round-tripping:

```sh
cd Examples/WebCanvasDemo
swift package --swift-sdk swift-6.3.3-RELEASE_wasm js --use-cdn   # regular SDK

# the Embedded SDK build needs the Unicode data tables linked (see Package.swift)
SILICA_WASM_EMBEDDED=1 swift package --swift-sdk swift-6.3.3-RELEASE_wasm-embedded js --use-cdn

npx serve .   # then open index.html
```

Web platform notes:

- Page-based (PDF) output is not supported; `WebCanvasRenderer` is a bitmap destination.
- Glyph indices are Unicode scalar values (the Canvas API exposes no font tables), rendered with `fillText`; metrics come from `measureText`. Scalars outside the Basic Multilingual Plane map to glyph 0.
- `decodePNG` is unavailable (the web only decodes images asynchronously); create an `Image` from an `ImageData` object instead, or draw `HTMLImageElement`/`ImageBitmap` directly onto the canvas. `encodePNG` requires a DOM document (`canvas.toDataURL`).
- Shape antialiasing cannot be disabled; `shouldAntialias` only controls image smoothing.
- Font names resolve as CSS font families (with camel-case expansion, e.g. `"TimesNewRoman-Bold"` → `"Times New Roman"`, bold), falling back to `sans-serif`.
- Executables built with the Embedded Swift SDK must link the Unicode data tables: `.linkedLibrary("swiftUnicodeDataTables", .when(platforms: [.wasi]))`.

### Rendering Differences

- **Shadows**: Quartz and the Web Canvas render blurred shadows; the Cairo, Android and 3DS backends draw shadows without blur (a silhouette at the offset).
- **Fonts**: font resolution is fuzzy on Linux (FontConfig) and Android (Typeface), but strict on Apple platforms (Core Text descriptor matching by PostScript name or family name, with camel-case expansion, e.g. `"TimesNewRoman-Bold"` → family *Times New Roman*, bold).
- **Text** maps characters to glyphs one by one, with fallback fonts for characters the font lacks: scripts that shape aren't laid out.
- **Gradients**: Cairo extends both ends of a gradient or neither, so `GradientOptions` with one end draws both.
- **Blend modes** a backend can't do draw as `normal`: plus darker on Cairo, everything but normal on the 3DS.

## CoreGraphics C API (Linux)

`libCoreGraphics` is Darwin's CoreGraphics C API (`CGContextRef`, `CGPathRef`, `CGRectGetMinX`, …) drawn by Silica, for programs written against Apple's CoreGraphics on platforms that don't have it: C and C++ code on Linux, and [Perry](https://github.com/PureSwift/Perry)'s Darwin apps. CMake builds it on platforms other than Darwin (`SILICA_BUILD_COREGRAPHICS`), and installs `include/CoreGraphics/CoreGraphics.h`, a `CoreGraphics` module map for Swift, and `lib/libCoreGraphics.so`:

```c
#include <CoreGraphics/CoreGraphics.h>

CGMutablePathRef path = CGPathCreateMutable();
CGPathAddEllipseInRect(path, NULL, CGRectMake(0, 0, 40, 20));
CGRect bounds = CGPathGetPathBoundingBox(path);
CGPathRelease(path);
```

- **What it exports** is listed in [`Scripts/CoreGraphics/symbols.txt`](Scripts/CoreGraphics/symbols.txt): the public drawing API (contexts, bitmap contexts, paths, geometry, colors and color spaces, images, data providers, gradients, patterns, functions, shadings, fonts, layers). Displays, events, windows, PDF documents and ImageIO aren't part of it.
- **Implemented so far:** geometry, affine transforms, paths, bitmap contexts and drawing in them, colors and device color spaces, gradients, images (from bitmap contexts and from data providers), data providers, fonts (FreeType's, through Cairo), glyphs drawn in contexts, layers (`CGLayer` and transparency layers), patterns (colored and stencils), tiled images, shadings of functions, image masks, masked images and clips to masks, images masked by colors and read from PNGs (by Cairo), calibrated, ICC and indexed color spaces, transforms from their components, and paths made from paths: flattened, dashed, stroked, and the areas they fill combined. Named color spaces (`CGColorSpaceCreateWithName`, `GetName`, property lists, linearized and extended forms) and the constant colors work by their names' strings, through the Core Foundation bridge. One function is left: `CGImageCreateWithJPEGDataProvider`, which needs a JPEG decoder. Everything else listed is a stub that prints `CoreGraphics: <function> is not implemented by Silica yet` once and returns zero (or aborts, with `SILICA_CG_ABORT_ON_UNIMPLEMENTED` set), so programs link and load against the whole API.
- **Bitmap contexts** draw with SilicaCairo. Memory in Cairo's layout (premultiplied ARGB in 32-bit words of the host's byte order: `kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host`) is drawn into directly; other formats (RGBA, ARGB and skipped alpha in either byte order, gray, alpha only) are kept in step with a surface of Cairo's own around each drawing. Colors are sRGB: there's no color management.
- **Paths from paths** (`CGPathCreateCopyByStrokingPath`, `…ByUnioningPath`, …) are made of lines: curves become lines no farther than 0.05 from them. The same operations are on Silica's `Path`: `strokedPath(_:)`, `dashed(phase:lengths:)`, `flattened(threshold:)`, `union(_:using:)`, `intersection`, `subtracting`, `symmetricDifference`, `lineIntersection`, `lineSubtraction`, `normalized(using:)`, `componentsSeparated(using:)` and `intersects(_:using:)`.
- **Patterns** draw their cell once, at the device's resolution, and repeat it: every tiling is drawn as `kCGPatternTilingConstantSpacing`. **Shadings** sample their function 256 times and draw the gradient between the samples.
- **Core Foundation:** Silica has none, so a function that takes or returns a `CFStringRef`, `CFDataRef` or `CFURLRef` (`CGFontCreateWithFontName`, `CGFontCopyFullName`, `CGDataProviderCopyData`, …) returns NULL or zero unless a runtime that has Core Foundation sets `CoreGraphicsObjects.coreFoundation` to bridge them. Silica exports none of Core Foundation's constants (`kCGColorSpaceSRGB`, `kCGColorWhite`): the runtime has its own, and names are compared by their strings. Its bridge's `constant` hands back the runtime's constant for a name, so `CGColorSpaceGetName` returns that very pointer.
- **Each symbol is also exported under its Mach-O name** (`_CGPathCreateMutable`), as Darwin code links it.
- **References** (`CGPathRef`, …) are retained Swift objects behind an opaque pointer, following Core Foundation's create, copy and release rules. A runtime that needs its own objects behind them (Perry, for Core Foundation and Objective-C) supplies them through `CoreGraphicsObjects` in the `SilicaCoreGraphicsABI` module.
- **Conformance:** the programs in [`Conformance/CoreGraphics`](Conformance/CoreGraphics) print what CoreGraphics returns. The text program loads the same font file on both (`fonts/DejaVuSansMono.ttf`, under the license beside it). Their output from Apple's framework is recorded on macOS (`Scripts/CoreGraphics/conformance.sh record`), and CI compares libCoreGraphics' output with it (`conformance.sh check`).
- After implementing a function in `Sources/SilicaCoreGraphicsABI` (with `@c @implementation`), run `Scripts/CoreGraphics/gen_stubs.py` to retire its stub and regenerate the export lists.

## Building with CMake

For a system image (Buildroot and the like), CMake builds `Silica` and a
backend (`SilicaCairo` on Linux, `SilicaQuartz` on macOS) as shared
libraries with library evolution, and installs them and their modules into
the Swift resource directory (`lib/swift/<system>`), where apps find them
like the OS's own frameworks:

```bash
cmake -B build -G Ninja -DCMAKE_INSTALL_PREFIX=/usr
```

```bash
cmake --build build
```

```bash
cmake --install build
```

`SilicaCairo` needs the `Cairo` and `FontConfig` Swift modules in the
resource directory, or on search paths in `CMAKE_Swift_FLAGS`. SwiftPM stays
the way to develop and test, and to build the other backends.

- Linux/macOS (Cairo backend): `cairo`, `fontconfig`, `freetype` system libraries.
- macOS (Quartz backend): system frameworks only.
- WebAssembly: [JavaScriptKit](https://github.com/swiftwasm/JavaScriptKit) (pulled automatically; only built when compiling for WebAssembly).
