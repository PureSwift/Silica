//
//  main.swift
//  WebCanvasDemo
//
//  Draws with Silica's `GraphicsContext` onto HTML canvases through the
//  SilicaWeb backend — the same `TestStyleKit` (PaintCode-generated) content
//  that SilicaCairoTests' StyleKitTests renders with the Cairo backend, plus a
//  showcase panel exercising primitives Silica supports (paths, arcs,
//  transforms, transparency layers, clipping, gradients, and bitmap
//  round-tripping).
//

#if canImport(Foundation)
import Foundation
#endif
import JavaScriptKit
import SilicaWeb

WebBackend.register()

let document = JSObject.global.document

/// Canvas pixels per CSS pixel, so drawing is sharp on high-density displays.
let scale = max(JSObject.global.devicePixelRatio.number ?? 1, 1)

var title = document.createElement("h1")
title.innerText = "Silica on the Web Canvas API"
_ = document.body.appendChild(title)

var intro = document.createElement("p")
intro.innerText = "Each canvas below is drawn by SilicaWeb's WebCanvasRenderer through Silica's GraphicsContext."
_ = document.body.appendChild(intro)

var grid = document.createElement("div")
grid.style = .string("display: flex; flex-wrap: wrap; gap: 16px; align-items: flex-start;")
_ = document.body.appendChild(grid)

/// Creates a labeled canvas `width` by `height` points, draws into it, and appends it to the grid.
@discardableResult
func panel(_ label: String, width: Int, height: Int, draw: (GraphicsContext) -> Void) -> GraphicsContext {

    let figure = document.createElement("figure")
    figure.style = .string("margin: 0; padding: 8px; background: #fff; border-radius: 8px; box-shadow: 0 1px 4px rgba(0,0,0,0.15);")

    // the canvas has `scale` pixels per point, shown `width` by `height` CSS pixels
    let canvas = document.createElement("canvas")
    canvas.width = .number((Double(width) * scale).rounded(.up))
    canvas.height = .number((Double(height) * scale).rounded(.up))
    canvas.style = .string("display: block; background: #fff; width: \(width)px; height: \(height)px;")
    _ = figure.appendChild(canvas)

    let caption = document.createElement("figcaption")
    caption.innerText = .string(label)
    caption.style = .string("font: 12px sans-serif; color: #333; margin-top: 4px;")
    _ = figure.appendChild(caption)

    _ = grid.appendChild(figure)

    let renderer = try! WebCanvasRenderer(canvas: canvas.object!, size: Size(width: Double(width), height: Double(height)), scale: scale)
    let context = GraphicsContext(renderer)
    draw(context)
    return context
}

// MARK: - TestStyleKit (same content SilicaCairoTests renders with the Cairo backend)

panel("drawSimpleShapes", width: 240, height: 120) { context in
    TestStyleKit.drawSimpleShapes(in: context)
}

panel("drawAdvancedShapes", width: 240, height: 120) { context in
    TestStyleKit.drawAdvancedShapes(in: context)
}

panel("drawSwiftLogo", width: 200, height: 200) { context in
    TestStyleKit.drawSwiftLogo(in: context, frame: Rect(x: 0, y: 0, width: 200, height: 200))
}

panel("drawSwiftLogoWithText", width: 164 * 2, height: 48 * 2) { context in
    TestStyleKit.drawSwiftLogoWithText(in: context, frame: Rect(x: 0, y: 0, width: 164 * 2, height: 48 * 2))
}

panel("drawSingleLineText", width: 240, height: 120) { context in
    TestStyleKit.drawSingleLineText(in: context)
}

panel("drawMultiLineText", width: 240, height: 180) { context in
    TestStyleKit.drawMultiLineText(in: context)
}

// MARK: - Showcase: primitives beyond TestStyleKit's PaintCode output

panel("Showcase: shapes, transforms, transparency, clipping, gradients, bitmaps", width: 480, height: 360) { context in

    // background
    context.fill(Path(Rect(x: 0, y: 0, width: 480, height: 360)), with: Color(red: 0.97, green: 0.97, blue: 1.0))

    // shadowed rounded rectangle
    let card = Path(roundedRect: Rect(x: 24, y: 24, width: 200, height: 120), cornerRadius: 16)
    context.saveGState()
    context.setShadow(offset: Size(width: 4, height: 4), blur: 0, color: Color(white: 0, alpha: 0.25))
    context.fill(card, with: .white)
    context.restoreGState()

    // dashed stroke around the card
    context.stroke(card, with: Color(red: 0.28, green: 0.51, blue: 0.98), style: StrokeStyle(lineWidth: 3, dash: [8, 4]))

    // circle + arc wedge
    context.fill(Path(ellipseIn: Rect(x: 260, y: 32, width: 104, height: 104)), with: Color(red: 0.32, green: 0.8, blue: 0.35))

    var wedge = Path()
    wedge.move(to: Point(x: 312, y: 84))
    wedge.addArc(center: Point(x: 312, y: 84), radius: 52, startAngle: 0, endAngle: .pi / 1.5, clockwise: false)
    wedge.closeSubpath()
    context.fill(wedge, with: Color(red: 1.0, green: 0.62, blue: 0.11))

    // bezier heart, rotated, in a half-transparent layer
    context.saveGState()
    context.translateBy(x: 404, y: 48)
    context.rotate(by: .pi / 8)
    context.setAlpha(0.5)
    context.beginTransparencyLayer()

    var heart = Path()
    heart.move(to: Point(x: 24, y: 46))
    heart.addCurve(to: Point(x: 0, y: 12), control1: Point(x: 2, y: 30), control2: Point(x: 0, y: 22))
    heart.addCurve(to: Point(x: 12, y: 0), control1: Point(x: 0, y: 4), control2: Point(x: 5, y: 0))
    heart.addCurve(to: Point(x: 24, y: 8), control1: Point(x: 19, y: 0), control2: Point(x: 24, y: 8))
    heart.addCurve(to: Point(x: 36, y: 0), control1: Point(x: 24, y: 8), control2: Point(x: 29, y: 0))
    heart.addCurve(to: Point(x: 48, y: 12), control1: Point(x: 43, y: 0), control2: Point(x: 48, y: 4))
    heart.addCurve(to: Point(x: 24, y: 46), control1: Point(x: 48, y: 22), control2: Point(x: 46, y: 30))
    heart.closeSubpath()
    context.fill(heart, with: Color(red: 0.9, green: 0.1, blue: 0.25))

    context.endTransparencyLayer()
    context.restoreGState()

    // linear gradient, clipped to a capsule
    context.saveGState()
    context.clip(to: Path(roundedRect: Rect(x: 24, y: 154, width: 432, height: 16), cornerRadius: 8))
    context.drawLinearGradient(
        Gradient(colors: [Color(red: 0.28, green: 0.51, blue: 0.98), Color(red: 0.55, green: 0.2, blue: 0.85), Color(red: 0.9, green: 0.1, blue: 0.25)]),
        start: Point(x: 24, y: 0),
        end: Point(x: 456, y: 0)
    )
    context.restoreGState()

    // clipped stripes
    context.saveGState()
    context.clip(to: Path(ellipseIn: Rect(x: 32, y: 180, width: 120, height: 120)))

    for index in 0 ..< 8 {
        let even = index % 2 == 0
        let color = Color(red: even ? 0.15 : 0.98, green: even ? 0.28 : 0.79, blue: even ? 0.80 : 0.16)
        context.fill(Path(Rect(x: 32 + Double(index) * 15, y: 180, width: 15, height: 120)), with: color)
    }
    context.restoreGState()

    // stroked star under a scaled transform, with CoreGraphics' path methods
    context.saveGState()
    context.translateBy(x: 200, y: 200)
    context.scaleBy(x: 1.4, y: 1.0)
    context.setStrokeColor(Color(red: 0.55, green: 0.2, blue: 0.85))
    context.setLineWidth(4)
    context.lineJoin = .round
    context.beginPath()
    context.addLines(between: [
        Point(x: 40, y: 0), Point(x: 52, y: 28), Point(x: 80, y: 30), Point(x: 58, y: 50), Point(x: 66, y: 80),
        Point(x: 40, y: 62), Point(x: 14, y: 80), Point(x: 22, y: 50), Point(x: 0, y: 30), Point(x: 28, y: 28)
    ])
    context.closePath()
    context.strokePath()
    context.restoreGState()

    // bitmap round-trip: render a checkerboard offscreen and composite it,
    // upright, with a blue top row
    if let offscreen = BitmapContext(width: 40, height: 40, scale: scale) {

        for row in 0 ..< 4 {
            for column in 0 ..< 4 {
                let even = (row + column) % 2 == 0
                let color = row == 0 && even
                    ? Color(red: 0.15, green: 0.28, blue: 0.80)
                    : Color(red: even ? 0.1 : 0.9, green: even ? 0.1 : 0.9, blue: even ? 0.1 : 0.2)
                offscreen.fill(Path(Rect(x: Double(column) * 10, y: Double(row) * 10, width: 10, height: 10)), with: color)
            }
        }

        if let image = offscreen.makeImage() {
            context.draw(image, in: Rect(x: 380, y: 200, width: 64, height: 64))
        }
    }

    // text, its baseline at y = 320
    if let font = Font(name: "Helvetica-Bold", size: 22) {
        context.font = font
        context.fillColor = Color(red: 0.1, green: 0.1, blue: 0.25)
        context.draw("Hello from Silica + JavaScriptKit!", at: Point(x: 32, y: 320 - font.ascent))
    }
}

// signal readiness for automated checks
var status = document.createElement("p")
status.id = "status"
status.innerText = "rendered"
_ = document.body.appendChild(status)
