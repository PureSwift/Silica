//
//  main.swift
//  WebCanvasDemo
//
//  Draws with Silica's CoreGraphics-style API onto HTML canvases through the
//  SilicaWeb backend — the same `TestStyleKit` (PaintCode-generated) content
//  that SilicaCairoTests' StyleKitTests renders to PDF with the Cairo backend,
//  plus a showcase panel exercising primitives Silica supports (paths, arcs,
//  transforms, transparency layers, clipping, and bitmap round-tripping).
//

#if canImport(Foundation)
import Foundation
#endif
import JavaScriptKit
import SilicaWeb

let document = JSObject.global.document

var title = document.createElement("h1")
title.innerText = "Silica on the Web Canvas API"
_ = document.body.appendChild(title)

var intro = document.createElement("p")
intro.innerText = "Each canvas below is drawn by SilicaWeb's WebCanvasContext using Silica's CoreGraphics-style API."
_ = document.body.appendChild(intro)

var grid = document.createElement("div")
grid.style = .string("display: flex; flex-wrap: wrap; gap: 16px; align-items: flex-start;")
_ = document.body.appendChild(grid)

/// Creates a labeled canvas of the specified size, draws into it, and appends it to the grid.
@discardableResult
func panel(_ label: String, width: Int, height: Int, draw: (WebCanvasContext) -> Void) -> WebCanvasContext {

    var figure = document.createElement("figure")
    figure.style = .string("margin: 0; padding: 8px; background: #fff; border-radius: 8px; box-shadow: 0 1px 4px rgba(0,0,0,0.15);")

    var canvas = document.createElement("canvas")
    canvas.width = .number(Double(width))
    canvas.height = .number(Double(height))
    canvas.style = .string("display: block; background: #fff;")
    _ = figure.appendChild(canvas)

    var caption = document.createElement("figcaption")
    caption.innerText = .string(label)
    caption.style = .string("font: 12px sans-serif; color: #333; margin-top: 4px;")
    _ = figure.appendChild(caption)

    _ = grid.appendChild(figure)

    let context = try! WebCanvasContext(canvas: canvas.object!, size: CGSize(width: CGFloat(width), height: CGFloat(height)))

    UIGraphicsPushContext(context)
    draw(context)
    UIGraphicsPopContext()

    return context
}

// MARK: - TestStyleKit (same content SilicaCairoTests renders with the Cairo backend)

panel("drawSimpleShapes", width: 240, height: 120) { _ in
    TestStyleKit.drawSimpleShapes()
}

panel("drawAdvancedShapes", width: 240, height: 120) { _ in
    TestStyleKit.drawAdvancedShapes()
}

panel("drawSwiftLogo", width: 200, height: 200) { _ in
    TestStyleKit.drawSwiftLogo(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
}

panel("drawSwiftLogoWithText", width: 164 * 2, height: 48 * 2) { _ in
    TestStyleKit.drawSwiftLogoWithText(frame: CGRect(x: 0, y: 0, width: 164 * 2, height: 48 * 2))
}

// `String.draw(in:withAttributes:)` takes `[String: Any]`, unavailable in Embedded Swift.
#if canImport(Foundation)

panel("drawSingleLineText", width: 240, height: 120) { _ in
    TestStyleKit.drawSingleLineText()
}

panel("drawMultiLineText", width: 240, height: 180) { _ in
    TestStyleKit.drawMultiLineText()
}

#endif

// MARK: - Showcase: primitives beyond TestStyleKit's PaintCode output

panel("Showcase: shapes, transforms, transparency, clipping, bitmaps", width: 480, height: 360) { context in

    // background
    context.setFillColor(red: 0.97, green: 0.97, blue: 1.0)
    context.beginPath()
    context.addRect(CGRect(x: 0, y: 0, width: 480, height: 360))
    context.fillPath()

    // shadowed rounded rectangle (UIKit shim)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 4, height: 4), radius: 0, color: CGColor(grey: 0, alpha: 0.25))
    let card = UIBezierPath(roundedRect: CGRect(x: 24, y: 24, width: 200, height: 120), cornerRadius: 16)
    context.setFillColor(CGColor.white)
    context.beginPath()
    context.addPath(card.cgPath)
    context.fillPath()
    context.restoreGState()

    // dashed stroke around the card
    context.setStrokeColor(red: 0.28, green: 0.51, blue: 0.98)
    context.setLineWidth(3)
    context.setLineDash(phase: 0, lengths: [8, 4])
    context.beginPath()
    context.addPath(UIBezierPath(roundedRect: CGRect(x: 24, y: 24, width: 200, height: 120), cornerRadius: 16).cgPath)
    context.strokePath()
    context.setLineDash(phase: 0, lengths: [])

    // circle + arc wedge
    context.setFillColor(red: 0.32, green: 0.8, blue: 0.35)
    context.beginPath()
    context.addEllipse(in: CGRect(x: 260, y: 32, width: 104, height: 104))
    context.fillPath()

    context.setFillColor(red: 1.0, green: 0.62, blue: 0.11)
    context.beginPath()
    context.move(to: CGPoint(x: 312, y: 84))
    context.addArc(center: CGPoint(x: 312, y: 84), radius: 52, startAngle: 0, endAngle: .pi / 1.5, clockwise: false)
    context.closePath()
    context.fillPath()

    // bezier heart, rotated, in a half-transparent layer
    context.saveGState()
    context.translateBy(x: 404, y: 48)
    context.rotate(by: .pi / 8)
    context.setAlpha(0.5)
    context.beginTransparencyLayer()

    let heart = CGMutablePath()
    heart.move(to: CGPoint(x: 24, y: 46))
    heart.addCurve(to: CGPoint(x: 0, y: 12), control1: CGPoint(x: 2, y: 30), control2: CGPoint(x: 0, y: 22))
    heart.addCurve(to: CGPoint(x: 12, y: 0), control1: CGPoint(x: 0, y: 4), control2: CGPoint(x: 5, y: 0))
    heart.addCurve(to: CGPoint(x: 24, y: 8), control1: CGPoint(x: 19, y: 0), control2: CGPoint(x: 24, y: 8))
    heart.addCurve(to: CGPoint(x: 36, y: 0), control1: CGPoint(x: 24, y: 8), control2: CGPoint(x: 29, y: 0))
    heart.addCurve(to: CGPoint(x: 48, y: 12), control1: CGPoint(x: 43, y: 0), control2: CGPoint(x: 48, y: 4))
    heart.addCurve(to: CGPoint(x: 24, y: 46), control1: CGPoint(x: 48, y: 22), control2: CGPoint(x: 46, y: 30))
    heart.closeSubpath()

    context.setFillColor(red: 0.9, green: 0.1, blue: 0.25)
    context.beginPath()
    context.addPath(heart)
    context.fillPath()

    context.endTransparencyLayer()
    context.restoreGState()

    // clipped stripes
    context.saveGState()
    context.beginPath()
    context.addEllipse(in: CGRect(x: 32, y: 180, width: 120, height: 120))
    context.clip()

    for index in 0 ..< 8 {
        let even = index % 2 == 0
        context.setFillColor(red: even ? 0.15 : 0.98, green: even ? 0.28 : 0.79, blue: even ? 0.80 : 0.16)
        context.beginPath()
        context.addRect(CGRect(x: 32 + CGFloat(index) * 15, y: 180, width: 15, height: 120))
        context.fillPath()
    }
    context.restoreGState()

    // stroked star under a scaled transform
    context.saveGState()
    context.translateBy(x: 200, y: 200)
    context.scaleBy(x: 1.4, y: 1.0)
    context.setStrokeColor(red: 0.55, green: 0.2, blue: 0.85)
    context.setLineWidth(4)
    context.lineJoin = .round
    context.beginPath()
    context.move(to: CGPoint(x: 40, y: 0))
    context.addLine(to: CGPoint(x: 52, y: 28))
    context.addLine(to: CGPoint(x: 80, y: 30))
    context.addLine(to: CGPoint(x: 58, y: 50))
    context.addLine(to: CGPoint(x: 66, y: 80))
    context.addLine(to: CGPoint(x: 40, y: 62))
    context.addLine(to: CGPoint(x: 14, y: 80))
    context.addLine(to: CGPoint(x: 22, y: 50))
    context.addLine(to: CGPoint(x: 0, y: 30))
    context.addLine(to: CGPoint(x: 28, y: 28))
    context.closePath()
    context.strokePath()
    context.restoreGState()

    // bitmap round-trip: render a checkerboard offscreen and composite it
    if let offscreen = try? WebCanvasContext(size: CGSize(width: 40, height: 40)) {

        for row in 0 ..< 4 {
            for column in 0 ..< 4 {
                let even = (row + column) % 2 == 0
                offscreen.setFillColor(red: even ? 0.1 : 0.9, green: even ? 0.1 : 0.9, blue: even ? 0.1 : 0.2)
                offscreen.beginPath()
                offscreen.addRect(CGRect(x: CGFloat(column) * 10, y: CGFloat(row) * 10, width: 10, height: 10))
                offscreen.fillPath()
            }
        }

        if let image = offscreen.makeImage() {
            context.draw(image, in: CGRect(x: 380, y: 200, width: 64, height: 64))
        }
    }

    // text
    if let font = CGFont(name: "Helvetica-Bold") {
        context.setFont(font)
        context.fontSize = 22
        context.setFillColor(red: 0.1, green: 0.1, blue: 0.25)
        context.textPosition = CGPoint(x: 32, y: 320)
        context.show(text: "Hello from Silica + JavaScriptKit!")
    }
}

// signal readiness for automated checks
var status = document.createElement("p")
status.id = "status"
status.innerText = "rendered"
_ = document.body.appendChild(status)
