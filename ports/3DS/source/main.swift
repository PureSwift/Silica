//---------------------------------------------------------------------------------
//
//  Silica demo for Nintendo 3DS -- Embedded Swift ARM11 binary.
//
//  Draws vector graphics (Silica's CGContext API, rasterized by the Silica3DS
//  software renderer) on the top screen: a Swift-logo-style rounded rectangle
//  with a stylized bird, plus fills, strokes, dashes, arcs, transforms, and a
//  shadowed shape -- exercising the same drawing surface the desktop backends
//  render through Cairo / CoreGraphics / Android Canvas.
//
//    START    exit
//
//---------------------------------------------------------------------------------

import CTRU
#if canImport(Silica3DS)
import Silica3DS
#endif

gfxInitDefault()
gfxSetDoubleBuffering(GFX_TOP, false)

// text console on the bottom screen
consoleInit(GFX_BOTTOM, nil)
ctru_puts("\n  Silica on Nintendo 3DS\n")
ctru_puts("  Software-rendered CGContext\n\n")
ctru_puts("  Press START to exit\n")

// MARK: - Drawing

let screen = Nintendo3DSContext.Screen.top
let context = try! Nintendo3DSContext(screen: screen, scale: 2)

let width = screen.size.width
let height = screen.size.height

// background
context.setFillColor(red: 0.12, green: 0.12, blue: 0.18)
context.addRect(CGRect(x: 0, y: 0, width: width, height: height))
context.fillPath()

// Swift-logo-style rounded badge
func addRoundedRect(_ rect: CGRect, radius: CGFloat) {
    context.beginPath()
    context.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
    context.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
    context.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY),
                   tangent2End: CGPoint(x: rect.maxX, y: rect.minY + radius), radius: radius)
    context.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
    context.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY),
                   tangent2End: CGPoint(x: rect.maxX - radius, y: rect.maxY), radius: radius)
    context.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
    context.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY),
                   tangent2End: CGPoint(x: rect.minX, y: rect.maxY - radius), radius: radius)
    context.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
    context.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY),
                   tangent2End: CGPoint(x: rect.minX + radius, y: rect.minY), radius: radius)
    context.closePath()
}

let badge = CGRect(x: 24, y: 40, width: 160, height: 160)

context.setShadow(offset: CGSize(width: 5, height: 5), radius: 0,
                  color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.6))
context.setFillColor(red: 0.94, green: 0.32, blue: 0.21)  // Swift orange
addRoundedRect(badge, radius: 36)
context.fillPath()
context.setShadow(offset: .zero, radius: 0, color: .clear)

// stylized bird: two swooping quad-curve wings
context.setFillColor(red: 1, green: 1, blue: 1)
context.beginPath()
context.move(to: CGPoint(x: 52, y: 150))
context.addQuadCurve(to: CGPoint(x: 160, y: 78), control: CGPoint(x: 120, y: 150))
context.addQuadCurve(to: CGPoint(x: 118, y: 128), control: CGPoint(x: 150, y: 118))
context.addQuadCurve(to: CGPoint(x: 60, y: 88), control: CGPoint(x: 84, y: 120))
context.addQuadCurve(to: CGPoint(x: 100, y: 138), control: CGPoint(x: 82, y: 122))
context.addQuadCurve(to: CGPoint(x: 52, y: 150), control: CGPoint(x: 72, y: 148))
context.closePath()
context.fillPath()

// right-hand column: shape samples matching the desktop test content
context.saveGState()
context.translateBy(x: 216, y: 32)

// star (winding fill)
context.setFillColor(red: 0.25, green: 0.35, blue: 0.9)
context.beginPath()
var first = true
for index in 0 ..< 10 {
    let angle = CGFloat(index) * .pi / 5 - .pi / 2
    let radius: CGFloat = index % 2 == 0 ? 28 : 12
    let point = CGPoint(x: 40 + radius * CGFloat(cos(Double(angle))),
                        y: 30 + radius * CGFloat(sin(Double(angle))))
    if first { context.move(to: point); first = false }
    else { context.addLine(to: point) }
}
context.closePath()
context.fillPath()

// ring (even-odd fill)
context.setFillColor(red: 0.36, green: 0.78, blue: 0.36)
context.beginPath()
context.addArc(center: CGPoint(x: 130, y: 30), radius: 28, startAngle: 0, endAngle: 2 * .pi, clockwise: false)
context.addArc(center: CGPoint(x: 130, y: 30), radius: 14, startAngle: 0, endAngle: 2 * .pi, clockwise: false)
context.fillPath(using: .evenOdd)

// dashed stroked capsule
context.setStrokeColor(red: 0.98, green: 0.8, blue: 0.25)
context.setLineWidth(4)
context.setLineDash(phase: 0, lengths: [10, 6])
addRoundedRect(CGRect(x: 8, y: 76, width: 152, height: 40), radius: 20)
context.strokePath()
context.setLineDash(phase: 0, lengths: [])

// rotated translucent squares
context.setFillColor(red: 0.85, green: 0.4, blue: 0.85, alpha: 0.75)
for index in 0 ..< 3 {
    context.saveGState()
    context.translateBy(x: 30 + CGFloat(index) * 52, y: 156)
    context.rotate(by: CGFloat(index) * .pi / 8 + .pi / 8)
    context.addRect(CGRect(x: -16, y: -16, width: 32, height: 32))
    context.fillPath()
    context.restoreGState()
}

context.restoreGState()

// present once (double buffering is off, so the frame sticks)
context.present()

ctru_puts("  Frame rendered.\n")

// MARK: - Main loop

while aptMainLoop() {

    // gspWaitForVBlank() is a macro; call its expansion directly
    gspWaitForEvent(GSPGPU_EVENT_VBlank0, true)
    hidScanInput()

    if hidKeysDown() & KEY_START != 0 {
        break
    }
}

gfxExit()
