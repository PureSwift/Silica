//
//  DemoSlides.swift
//  Silica3DS
//
//  Created by Alsey Coleman Miller on 7/13/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//
//  Shared slide content for the ports/3DS homebrew demo (Embedded Swift) and
//  for host-side render-dump tooling that exercises the exact same drawing
//  code without needing a 3DS or emulator -- useful for isolating a rendering
//  bug to one slide instead of a single busy composite.
//

#if canImport(Foundation)
import Foundation
#endif
#if canImport(Silica)
import Silica
#endif

/// A slideshow exercising the Nintendo 3DS software renderer: fills, strokes,
/// dashes, arcs/clipping, transparency layers, shadows, images, transforms,
/// and a Swift-logo-style badge -- the same drawing surface the desktop
/// backends render through Cairo / CoreGraphics / Android Canvas.
public enum Silica3DSDemo {

    public struct Slide {
        public let name: String
        public let draw: (Nintendo3DSContext) -> ()
    }

    /// The 3DS top screen's logical size (400x240 points).
    public static let screenSize = CGSize(width: 400, height: 240)

    public nonisolated(unsafe) static let slides: [Slide] = [

        Slide(name: "Fills (winding vs even-odd)") { context in
            background(context)

            // solid rect
            context.setFillColor(red: 0.90, green: 0.24, blue: 0.20)
            context.addRect(CGRect(x: 16, y: 16, width: 60, height: 60))
            context.fillPath()

            // circle
            context.setFillColor(red: 0.36, green: 0.78, blue: 0.36)
            context.addArc(center: CGPoint(x: 130, y: 46), radius: 30, startAngle: 0, endAngle: 2 * .pi, clockwise: false)
            context.fillPath()

            // nested squares, nonzero winding (same direction): filled solid
            context.setFillColor(red: 0.25, green: 0.45, blue: 0.95)
            context.beginPath()
            context.addRect(CGRect(x: 200, y: 16, width: 60, height: 60))
            context.addRect(CGRect(x: 215, y: 31, width: 30, height: 30))
            context.fillPath(using: .winding)

            // nested squares, even-odd: hole in the middle
            context.setFillColor(red: 0.95, green: 0.75, blue: 0.20)
            context.beginPath()
            context.addRect(CGRect(x: 290, y: 16, width: 60, height: 60))
            context.addRect(CGRect(x: 305, y: 31, width: 30, height: 30))
            context.fillPath(using: .evenOdd)

            // 5-pointed star (winding)
            context.setFillColor(red: 0.75, green: 0.35, blue: 0.85)
            context.beginPath()
            var first = true
            for index in 0 ..< 10 {
                let angle = CGFloat(index) * .pi / 5 - .pi / 2
                let radius: CGFloat = index % 2 == 0 ? 34 : 14
                let point = CGPoint(x: 80 + radius * CGFloat(cos(Double(angle))),
                                    y: 150 + radius * CGFloat(sin(Double(angle))))
                if first { context.move(to: point); first = false }
                else { context.addLine(to: point) }
            }
            context.closePath()
            context.fillPath()

            // ring (even-odd)
            context.setFillColor(red: 0.36, green: 0.78, blue: 0.78)
            context.beginPath()
            context.addArc(center: CGPoint(x: 200, y: 150), radius: 34, startAngle: 0, endAngle: 2 * .pi, clockwise: false)
            context.addArc(center: CGPoint(x: 200, y: 150), radius: 16, startAngle: 0, endAngle: 2 * .pi, clockwise: false)
            context.fillPath(using: .evenOdd)

            // pentagon (winding)
            context.setFillColor(red: 0.95, green: 0.55, blue: 0.20)
            context.beginPath()
            first = true
            for index in 0 ..< 5 {
                let angle = CGFloat(index) * 2 * .pi / 5 - .pi / 2
                let point = CGPoint(x: 320 + 34 * CGFloat(cos(Double(angle))),
                                    y: 150 + 34 * CGFloat(sin(Double(angle))))
                if first { context.move(to: point); first = false }
                else { context.addLine(to: point) }
            }
            context.closePath()
            context.fillPath()
        },

        Slide(name: "Stroke caps & joins") { context in
            background(context)

            let caps: [CGLineCap] = [.butt, .round, .square]
            context.setStrokeColor(red: 0.98, green: 0.55, blue: 0.20)
            context.setLineWidth(14)
            for (index, cap) in caps.enumerated() {
                let y = CGFloat(40 + index * 40)
                context.lineCap = cap
                context.beginPath()
                context.move(to: CGPoint(x: 40, y: y))
                context.addLine(to: CGPoint(x: 160, y: y))
                context.strokePath()
            }

            // Each V below is its OWN subpath, so leave a visible gap between
            // them: unconnected subpaths that merely touch at a point have no
            // join between them (in any vector renderer, not just this one)
            // and would show a misleading notch where their differently
            // angled cut ends meet.
            let joins: [CGLineJoin] = [.miter, .round, .bevel]
            context.setStrokeColor(red: 0.30, green: 0.65, blue: 0.95)
            context.setLineWidth(14)
            context.lineCap = .butt
            for (index, join) in joins.enumerated() {
                let x = CGFloat(200 + index * 70)
                context.lineJoin = join
                context.beginPath()
                context.move(to: CGPoint(x: x, y: 30))
                context.addLine(to: CGPoint(x: x + 25, y: 90))
                context.addLine(to: CGPoint(x: x + 50, y: 30))
                context.strokePath()
            }

            // closed rect showing all-corner joins
            context.setStrokeColor(red: 0.85, green: 0.35, blue: 0.85)
            context.setLineWidth(8)
            context.lineJoin = .miter
            context.addRect(CGRect(x: 40, y: 160, width: 100, height: 60))
            context.strokePath()
        },

        Slide(name: "Dashed strokes") { context in
            background(context)

            let dashes: [[CGFloat]] = [[8, 8], [2, 6], [16, 4, 4, 4], []]
            context.setStrokeColor(red: 0.95, green: 0.75, blue: 0.20)
            context.setLineWidth(5)
            for (index, pattern) in dashes.enumerated() {
                let y = CGFloat(40 + index * 40)
                context.setLineDash(phase: 0, lengths: pattern)
                context.beginPath()
                context.move(to: CGPoint(x: 20, y: y))
                context.addLine(to: CGPoint(x: 380, y: y))
                context.strokePath()
            }
            context.setLineDash(phase: 0, lengths: [])

            // dashed rounded capsule
            context.setStrokeColor(red: 0.36, green: 0.78, blue: 0.78)
            context.setLineWidth(4)
            context.setLineDash(phase: 0, lengths: [10, 6])
            addRoundedRect(context, CGRect(x: 60, y: 190, width: 280, height: 40), radius: 20)
            context.strokePath()
            context.setLineDash(phase: 0, lengths: [])
        },

        Slide(name: "Arcs & clipping") { context in
            background(context)

            // pie slices (counterclockwise sweep from 0)
            let colors: [(CGFloat, CGFloat, CGFloat)] = [
                (0.90, 0.24, 0.20), (0.95, 0.75, 0.20), (0.36, 0.78, 0.36), (0.30, 0.55, 0.95)
            ]
            let center = CGPoint(x: 90, y: 90)
            var angle: CGFloat = 0
            for color in colors {
                let sweep = CGFloat.pi / 2
                context.setFillColor(red: color.0, green: color.1, blue: color.2)
                context.beginPath()
                context.move(to: center)
                context.addArc(center: center, radius: 60, startAngle: angle, endAngle: angle + sweep, clockwise: false)
                context.closePath()
                context.fillPath()
                angle += sweep
            }

            // clip a checkerboard to a circle
            context.saveGState()
            context.beginPath()
            context.addArc(center: CGPoint(x: 260, y: 90), radius: 60, startAngle: 0, endAngle: 2 * .pi, clockwise: false)
            context.clip()
            let squareSize: CGFloat = 15
            for row in 0 ..< 9 {
                for column in 0 ..< 9 {
                    if (row + column) % 2 == 0 {
                        context.setFillColor(red: 0.85, green: 0.35, blue: 0.85)
                    } else {
                        context.setFillColor(red: 0.15, green: 0.15, blue: 0.20)
                    }
                    context.addRect(CGRect(x: 200 + CGFloat(column) * squareSize,
                                           y: 30 + CGFloat(row) * squareSize,
                                           width: squareSize, height: squareSize))
                    context.fillPath()
                }
            }
            context.restoreGState()

            // arc from tangent lines (rounded-rect corner primitive)
            context.setStrokeColor(red: 0.98, green: 0.55, blue: 0.20)
            context.setLineWidth(6)
            addRoundedRect(context, CGRect(x: 30, y: 170, width: 340, height: 55), radius: 24)
            context.strokePath()
        },

        Slide(name: "Transparency layers & shadows") { context in
            background(context)

            // three overlapping translucent circles via a transparency layer
            context.setAlpha(0.6)
            context.beginTransparencyLayer(auxiliaryInfo: nil)
            let circleColors: [(CGFloat, CGFloat, CGFloat)] = [
                (0.90, 0.24, 0.20), (0.36, 0.78, 0.36), (0.30, 0.55, 0.95)
            ]
            for (index, color) in circleColors.enumerated() {
                context.setFillColor(red: color.0, green: color.1, blue: color.2)
                context.beginPath()
                let x = 90 + CGFloat(index) * 40
                context.addArc(center: CGPoint(x: x, y: 90), radius: 55, startAngle: 0, endAngle: 2 * .pi, clockwise: false)
                context.fillPath()
            }
            context.endTransparencyLayer()
            context.setAlpha(1.0)

            // shadowed shapes
            context.setShadow(offset: CGSize(width: 8, height: 8), radius: 0,
                              color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.65))
            context.setFillColor(red: 0.95, green: 0.75, blue: 0.20)
            context.addRect(CGRect(x: 250, y: 40, width: 70, height: 70))
            context.fillPath()

            context.setFillColor(red: 0.85, green: 0.35, blue: 0.85)
            context.beginPath()
            context.addArc(center: CGPoint(x: 340, y: 75), radius: 32, startAngle: 0, endAngle: 2 * .pi, clockwise: false)
            context.fillPath()
            context.setShadow(offset: .zero, radius: 0, color: .clear)

            // rotated translucent squares
            context.setFillColor(red: 0.30, green: 0.65, blue: 0.95, alpha: 0.7)
            for index in 0 ..< 4 {
                context.saveGState()
                context.translateBy(x: 60 + CGFloat(index) * 60, y: 175)
                context.rotate(by: CGFloat(index) * .pi / 8 + .pi / 8)
                context.addRect(CGRect(x: -22, y: -22, width: 44, height: 44))
                context.fillPath()
                context.restoreGState()
            }
        },

        Slide(name: "Images") { context in
            background(context)

            // a small procedurally generated checkerboard image, drawn scaled
            // and upright via the UIKit-style pre-flip (as PaintCode/UIKit code does)
            let tiles = 8
            var pixels = [UInt8](repeating: 0, count: tiles * tiles * 4)
            for row in 0 ..< tiles {
                for column in 0 ..< tiles {
                    let offset = (row * tiles + column) * 4
                    let isLight = (row + column) % 2 == 0
                    pixels[offset]     = isLight ? 235 : 40   // R
                    pixels[offset + 1] = isLight ? 200 : 60   // G
                    pixels[offset + 2] = isLight ? 90  : 160  // B
                    pixels[offset + 3] = 255                  // A
                }
            }
            let image = CGImage(width: tiles, height: tiles, bytesPerRow: tiles * 4, data: Data(pixels))

            for index in 0 ..< 3 {
                let rect = CGRect(x: 30 + CGFloat(index) * 130, y: 40, width: 96, height: 96)
                drawUpright(image, in: rect, on: context)
            }

            // same image drawn scaled up + rotated, to exercise the image sampler under a transform
            context.saveGState()
            context.translateBy(x: 260, y: 170)
            context.rotate(by: .pi / 10)
            drawUpright(image, in: CGRect(x: -50, y: -50, width: 100, height: 100), on: context)
            context.restoreGState()
        },

        Slide(name: "Transforms") { context in
            background(context)

            let width = screenSize.width
            let height = screenSize.height

            // a grid of rotated + scaled squares fanning out from the center,
            // exercising concatenated scale/rotate/translate
            let colors: [(CGFloat, CGFloat, CGFloat)] = [
                (0.90, 0.24, 0.20), (0.95, 0.75, 0.20), (0.36, 0.78, 0.36),
                (0.30, 0.55, 0.95), (0.85, 0.35, 0.85), (0.98, 0.55, 0.20)
            ]
            for index in 0 ..< 12 {
                context.saveGState()
                context.translateBy(x: width / 2, y: height / 2)
                context.rotate(by: CGFloat(index) * .pi / 6)
                context.translateBy(x: 70, y: 0)
                let scale = 0.5 + CGFloat(index) * 0.04
                context.scaleBy(x: scale, y: scale)
                let color = colors[index % colors.count]
                context.setFillColor(red: color.0, green: color.1, blue: color.2)
                context.addRect(CGRect(x: -18, y: -18, width: 36, height: 36))
                context.fillPath()
                context.restoreGState()
            }

            // a stroked square under a nonuniform scale, to confirm the pen
            // transforms with the CTM (not just the geometry)
            context.saveGState()
            context.translateBy(x: 60, y: 190)
            context.scaleBy(x: 3, y: 1)
            context.setStrokeColor(red: 0.30, green: 0.65, blue: 0.95)
            context.setLineWidth(4)
            context.addRect(CGRect(x: 0, y: -15, width: 30, height: 30))
            context.strokePath()
            context.restoreGState()
        },

        Slide(name: "Swift logo badge") { context in
            background(context)

            let width = screenSize.width
            let height = screenSize.height
            let badge = CGRect(x: (width - 200) / 2, y: (height - 200) / 2, width: 200, height: 200)

            context.setShadow(offset: CGSize(width: 6, height: 6), radius: 0,
                              color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.6))
            drawSwiftLogoBadgeShape(context, in: badge)
            context.setShadow(offset: .zero, radius: 0, color: .clear)

            drawSwiftLogoBird(context, in: badge)
        },
    ]

    // MARK: - Shared Drawing Helpers

    static func addRoundedRect(_ context: Nintendo3DSContext, _ rect: CGRect, radius: CGFloat) {
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

    static func background(_ context: Nintendo3DSContext) {
        context.setFillColor(red: 0.10, green: 0.10, blue: 0.15)
        context.addRect(CGRect(x: 0, y: 0, width: screenSize.width, height: screenSize.height))
        context.fillPath()
    }

    /// Draws `image` upright in `rect`, flipping locally about the rect's own
    /// vertical center. Unlike flipping about the whole canvas height, this
    /// is correct under any active transform (translate/rotate/scale), since
    /// it never needs to know the canvas size.
    static func drawUpright(_ image: CGImage, in rect: CGRect, on context: Nintendo3DSContext) {
        context.saveGState()
        context.translateBy(x: 0, y: rect.minY + rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: rect)
        context.restoreGState()
    }

    /// The Swift logo's rounded-badge outline (the same PaintCode-generated
    /// path `TestStyleKit.drawSwiftLogo` uses, so this backend can be
    /// pixel-compared against the Cairo/CoreGraphics/Android renders of the
    /// identical geometry). Fill color is Swift's signature red-orange.
    static func drawSwiftLogoBadgeShape(_ context: Nintendo3DSContext, in rect: CGRect) {

        context.setFillColor(red: 0.915, green: 0.224, blue: 0.170)
        context.beginPath()
            context.move(to: CGPoint(x: rect.minX + 1.00000 * rect.width, y: rect.minY + 0.24841 * rect.height))
            context.addCurve(to: CGPoint(x: rect.minX + 0.99363 * rect.width, y: rect.minY + 0.18259 * rect.height), control1: CGPoint(x: rect.minX + 1.00000 * rect.width, y: rect.minY + 0.22718 * rect.height), control2: CGPoint(x: rect.minX + 0.99788 * rect.width, y: rect.minY + 0.20382 * rect.height))
            context.addCurve(to: CGPoint(x: rect.minX + 0.97240 * rect.width, y: rect.minY + 0.11890 * rect.height), control1: CGPoint(x: rect.minX + 0.98938 * rect.width, y: rect.minY + 0.16136 * rect.height), control2: CGPoint(x: rect.minX + 0.98301 * rect.width, y: rect.minY + 0.14013 * rect.height))
            context.addCurve(to: CGPoint(x: rect.minX + 0.93418 * rect.width, y: rect.minY + 0.06582 * rect.height), control1: CGPoint(x: rect.minX + 0.96178 * rect.width, y: rect.minY + 0.09979 * rect.height), control2: CGPoint(x: rect.minX + 0.94904 * rect.width, y: rect.minY + 0.08068 * rect.height))
            context.addCurve(to: CGPoint(x: rect.minX + 0.88110 * rect.width, y: rect.minY + 0.02760 * rect.height), control1: CGPoint(x: rect.minX + 0.91932 * rect.width, y: rect.minY + 0.05096 * rect.height), control2: CGPoint(x: rect.minX + 0.90021 * rect.width, y: rect.minY + 0.03609 * rect.height))
            context.addCurve(to: CGPoint(x: rect.minX + 0.81953 * rect.width, y: rect.minY + 0.00637 * rect.height), control1: CGPoint(x: rect.minX + 0.86200 * rect.width, y: rect.minY + 0.01699 * rect.height), control2: CGPoint(x: rect.minX + 0.84076 * rect.width, y: rect.minY + 0.01062 * rect.height))
            context.addCurve(to: CGPoint(x: rect.minX + 0.75372 * rect.width, y: rect.minY + 0.00000 * rect.height), control1: CGPoint(x: rect.minX + 0.79830 * rect.width, y: rect.minY + 0.00212 * rect.height), control2: CGPoint(x: rect.minX + 0.77495 * rect.width, y: rect.minY + 0.00212 * rect.height))
            context.addLine(to: CGPoint(x: rect.minX + 0.72399 * rect.width, y: rect.minY + 0.00000 * rect.height))
            context.addLine(to: CGPoint(x: rect.minX + 0.68790 * rect.width, y: rect.minY + 0.00000 * rect.height))
            context.addLine(to: CGPoint(x: rect.minX + 0.42251 * rect.width, y: rect.minY + 0.00000 * rect.height))
            context.addLine(to: CGPoint(x: rect.minX + 0.31210 * rect.width, y: rect.minY + 0.00000 * rect.height))
            context.addLine(to: CGPoint(x: rect.minX + 0.27601 * rect.width, y: rect.minY + 0.00000 * rect.height))
            context.addLine(to: CGPoint(x: rect.minX + 0.24628 * rect.width, y: rect.minY + 0.00000 * rect.height))
            context.addLine(to: CGPoint(x: rect.minX + 0.22930 * rect.width, y: rect.minY + 0.00000 * rect.height))
            context.addCurve(to: CGPoint(x: rect.minX + 0.18047 * rect.width, y: rect.minY + 0.00425 * rect.height), control1: CGPoint(x: rect.minX + 0.21231 * rect.width, y: rect.minY + 0.00000 * rect.height), control2: CGPoint(x: rect.minX + 0.19533 * rect.width, y: rect.minY + 0.00212 * rect.height))
            context.addCurve(to: CGPoint(x: rect.minX + 0.13376 * rect.width, y: rect.minY + 0.01699 * rect.height), control1: CGPoint(x: rect.minX + 0.16348 * rect.width, y: rect.minY + 0.00637 * rect.height), control2: CGPoint(x: rect.minX + 0.14862 * rect.width, y: rect.minY + 0.01062 * rect.height))
            context.addCurve(to: CGPoint(x: rect.minX + 0.11890 * rect.width, y: rect.minY + 0.02335 * rect.height), control1: CGPoint(x: rect.minX + 0.12951 * rect.width, y: rect.minY + 0.01911 * rect.height), control2: CGPoint(x: rect.minX + 0.12314 * rect.width, y: rect.minY + 0.02123 * rect.height))
            context.addCurve(to: CGPoint(x: rect.minX + 0.07856 * rect.width, y: rect.minY + 0.05096 * rect.height), control1: CGPoint(x: rect.minX + 0.10403 * rect.width, y: rect.minY + 0.03185 * rect.height), control2: CGPoint(x: rect.minX + 0.09130 * rect.width, y: rect.minY + 0.04034 * rect.height))
            context.addCurve(to: CGPoint(x: rect.minX + 0.06582 * rect.width, y: rect.minY + 0.06157 * rect.height), control1: CGPoint(x: rect.minX + 0.07431 * rect.width, y: rect.minY + 0.05520 * rect.height), control2: CGPoint(x: rect.minX + 0.07006 * rect.width, y: rect.minY + 0.05732 * rect.height))
            context.addCurve(to: CGPoint(x: rect.minX + 0.02760 * rect.width, y: rect.minY + 0.11465 * rect.height), control1: CGPoint(x: rect.minX + 0.05096 * rect.width, y: rect.minY + 0.07643 * rect.height), control2: CGPoint(x: rect.minX + 0.03609 * rect.width, y: rect.minY + 0.09554 * rect.height))
            context.addCurve(to: CGPoint(x: rect.minX + 0.00637 * rect.width, y: rect.minY + 0.17834 * rect.height), control1: CGPoint(x: rect.minX + 0.01699 * rect.width, y: rect.minY + 0.13376 * rect.height), control2: CGPoint(x: rect.minX + 0.01062 * rect.width, y: rect.minY + 0.15499 * rect.height))
            context.addCurve(to: CGPoint(x: rect.minX + 0.00000 * rect.width, y: rect.minY + 0.24416 * rect.height), control1: CGPoint(x: rect.minX + 0.00212 * rect.width, y: rect.minY + 0.19958 * rect.height), control2: CGPoint(x: rect.minX + 0.00212 * rect.width, y: rect.minY + 0.22293 * rect.height))
            context.addLine(to: CGPoint(x: rect.minX + 0.00000 * rect.width, y: rect.minY + 0.27389 * rect.height))
            context.addLine(to: CGPoint(x: rect.minX + 0.00000 * rect.width, y: rect.minY + 0.30998 * rect.height))
            context.addLine(to: CGPoint(x: rect.minX + 0.00000 * rect.width, y: rect.minY + 0.47346 * rect.height))
            context.addLine(to: CGPoint(x: rect.minX + 0.00000 * rect.width, y: rect.minY + 0.68577 * rect.height))
            context.addLine(to: CGPoint(x: rect.minX + 0.00000 * rect.width, y: rect.minY + 0.72187 * rect.height))
            context.addLine(to: CGPoint(x: rect.minX + 0.00000 * rect.width, y: rect.minY + 0.75159 * rect.height))
            context.addCurve(to: CGPoint(x: rect.minX + 0.00637 * rect.width, y: rect.minY + 0.81741 * rect.height), control1: CGPoint(x: rect.minX + 0.00000 * rect.width, y: rect.minY + 0.77282 * rect.height), control2: CGPoint(x: rect.minX + 0.00212 * rect.width, y: rect.minY + 0.79618 * rect.height))
            context.addCurve(to: CGPoint(x: rect.minX + 0.02760 * rect.width, y: rect.minY + 0.88110 * rect.height), control1: CGPoint(x: rect.minX + 0.01062 * rect.width, y: rect.minY + 0.83864 * rect.height), control2: CGPoint(x: rect.minX + 0.01699 * rect.width, y: rect.minY + 0.85987 * rect.height))
            context.addCurve(to: CGPoint(x: rect.minX + 0.06582 * rect.width, y: rect.minY + 0.93418 * rect.height), control1: CGPoint(x: rect.minX + 0.03822 * rect.width, y: rect.minY + 0.90021 * rect.height), control2: CGPoint(x: rect.minX + 0.05096 * rect.width, y: rect.minY + 0.91932 * rect.height))
            context.addCurve(to: CGPoint(x: rect.minX + 0.11890 * rect.width, y: rect.minY + 0.97240 * rect.height), control1: CGPoint(x: rect.minX + 0.08068 * rect.width, y: rect.minY + 0.94904 * rect.height), control2: CGPoint(x: rect.minX + 0.09979 * rect.width, y: rect.minY + 0.96391 * rect.height))
            context.addCurve(to: CGPoint(x: rect.minX + 0.18047 * rect.width, y: rect.minY + 0.99363 * rect.height), control1: CGPoint(x: rect.minX + 0.13800 * rect.width, y: rect.minY + 0.98301 * rect.height), control2: CGPoint(x: rect.minX + 0.15924 * rect.width, y: rect.minY + 0.98938 * rect.height))
            context.addCurve(to: CGPoint(x: rect.minX + 0.24628 * rect.width, y: rect.minY + 1.00000 * rect.height), control1: CGPoint(x: rect.minX + 0.20170 * rect.width, y: rect.minY + 0.99788 * rect.height), control2: CGPoint(x: rect.minX + 0.22505 * rect.width, y: rect.minY + 0.99788 * rect.height))
            context.addLine(to: CGPoint(x: rect.minX + 0.27601 * rect.width, y: rect.minY + 1.00000 * rect.height))
            context.addLine(to: CGPoint(x: rect.minX + 0.31210 * rect.width, y: rect.minY + 1.00000 * rect.height))
            context.addLine(to: CGPoint(x: rect.minX + 0.68790 * rect.width, y: rect.minY + 1.00000 * rect.height))
            context.addLine(to: CGPoint(x: rect.minX + 0.72399 * rect.width, y: rect.minY + 1.00000 * rect.height))
            context.addLine(to: CGPoint(x: rect.minX + 0.75372 * rect.width, y: rect.minY + 1.00000 * rect.height))
            context.addCurve(to: CGPoint(x: rect.minX + 0.81953 * rect.width, y: rect.minY + 0.99363 * rect.height), control1: CGPoint(x: rect.minX + 0.77495 * rect.width, y: rect.minY + 1.00000 * rect.height), control2: CGPoint(x: rect.minX + 0.79830 * rect.width, y: rect.minY + 0.99788 * rect.height))
            context.addCurve(to: CGPoint(x: rect.minX + 0.88110 * rect.width, y: rect.minY + 0.97240 * rect.height), control1: CGPoint(x: rect.minX + 0.84076 * rect.width, y: rect.minY + 0.98938 * rect.height), control2: CGPoint(x: rect.minX + 0.86200 * rect.width, y: rect.minY + 0.98301 * rect.height))
            context.addCurve(to: CGPoint(x: rect.minX + 0.93418 * rect.width, y: rect.minY + 0.93418 * rect.height), control1: CGPoint(x: rect.minX + 0.90021 * rect.width, y: rect.minY + 0.96178 * rect.height), control2: CGPoint(x: rect.minX + 0.91932 * rect.width, y: rect.minY + 0.94904 * rect.height))
            context.addCurve(to: CGPoint(x: rect.minX + 0.97240 * rect.width, y: rect.minY + 0.88110 * rect.height), control1: CGPoint(x: rect.minX + 0.94904 * rect.width, y: rect.minY + 0.91932 * rect.height), control2: CGPoint(x: rect.minX + 0.96391 * rect.width, y: rect.minY + 0.90021 * rect.height))
            context.addCurve(to: CGPoint(x: rect.minX + 0.99363 * rect.width, y: rect.minY + 0.81741 * rect.height), control1: CGPoint(x: rect.minX + 0.98301 * rect.width, y: rect.minY + 0.86200 * rect.height), control2: CGPoint(x: rect.minX + 0.98938 * rect.width, y: rect.minY + 0.84076 * rect.height))
            context.addCurve(to: CGPoint(x: rect.minX + 1.00000 * rect.width, y: rect.minY + 0.75159 * rect.height), control1: CGPoint(x: rect.minX + 0.99788 * rect.width, y: rect.minY + 0.79618 * rect.height), control2: CGPoint(x: rect.minX + 0.99788 * rect.width, y: rect.minY + 0.77282 * rect.height))
            context.addLine(to: CGPoint(x: rect.minX + 1.00000 * rect.width, y: rect.minY + 0.72187 * rect.height))
            context.addLine(to: CGPoint(x: rect.minX + 1.00000 * rect.width, y: rect.minY + 0.68577 * rect.height))
            context.addLine(to: CGPoint(x: rect.minX + 1.00000 * rect.width, y: rect.minY + 0.30998 * rect.height))
            context.addLine(to: CGPoint(x: rect.minX + 1.00000 * rect.width, y: rect.minY + 0.27813 * rect.height))
            context.addLine(to: CGPoint(x: rect.minX + 1.00000 * rect.width, y: rect.minY + 0.24841 * rect.height))
            context.closePath()
        context.closePath()
        context.fillPath()
    }

    /// The Swift logo's bird silhouette cutout, drawn over
    /// `drawSwiftLogoBadgeShape`'s badge in an off-white.
    static func drawSwiftLogoBird(_ context: Nintendo3DSContext, in rect: CGRect) {

        context.setFillColor(red: 0.995, green: 0.995, blue: 0.995)
        context.beginPath()
            context.move(to: CGPoint(x: rect.minX + 0.66820 * rect.width, y: rect.minY + 0.77312 * rect.height))
            context.addCurve(to: CGPoint(x: rect.minX + 0.33333 * rect.width, y: rect.minY + 0.77707 * rect.height), control1: CGPoint(x: rect.minX + 0.57909 * rect.width, y: rect.minY + 0.82461 * rect.height), control2: CGPoint(x: rect.minX + 0.45658 * rect.width, y: rect.minY + 0.82989 * rect.height))
            context.addCurve(to: CGPoint(x: rect.minX + 0.09766 * rect.width, y: rect.minY + 0.57537 * rect.height), control1: CGPoint(x: rect.minX + 0.23355 * rect.width, y: rect.minY + 0.73461 * rect.height), control2: CGPoint(x: rect.minX + 0.15074 * rect.width, y: rect.minY + 0.66030 * rect.height))
            context.addCurve(to: CGPoint(x: rect.minX + 0.18471 * rect.width, y: rect.minY + 0.62845 * rect.height), control1: CGPoint(x: rect.minX + 0.12314 * rect.width, y: rect.minY + 0.59660 * rect.height), control2: CGPoint(x: rect.minX + 0.15287 * rect.width, y: rect.minY + 0.61359 * rect.height))
            context.addCurve(to: CGPoint(x: rect.minX + 0.52879 * rect.width, y: rect.minY + 0.62860 * rect.height), control1: CGPoint(x: rect.minX + 0.31200 * rect.width, y: rect.minY + 0.68811 * rect.height), control2: CGPoint(x: rect.minX + 0.43926 * rect.width, y: rect.minY + 0.68403 * rect.height))
            context.addCurve(to: CGPoint(x: rect.minX + 0.52866 * rect.width, y: rect.minY + 0.62845 * rect.height), control1: CGPoint(x: rect.minX + 0.52875 * rect.width, y: rect.minY + 0.62856 * rect.height), control2: CGPoint(x: rect.minX + 0.52870 * rect.width, y: rect.minY + 0.62849 * rect.height))
            context.addCurve(to: CGPoint(x: rect.minX + 0.21231 * rect.width, y: rect.minY + 0.29936 * rect.height), control1: CGPoint(x: rect.minX + 0.40127 * rect.width, y: rect.minY + 0.53079 * rect.height), control2: CGPoint(x: rect.minX + 0.29299 * rect.width, y: rect.minY + 0.40340 * rect.height))
            context.addCurve(to: CGPoint(x: rect.minX + 0.16985 * rect.width, y: rect.minY + 0.24204 * rect.height), control1: CGPoint(x: rect.minX + 0.19533 * rect.width, y: rect.minY + 0.28238 * rect.height), control2: CGPoint(x: rect.minX + 0.18259 * rect.width, y: rect.minY + 0.26115 * rect.height))
            context.addCurve(to: CGPoint(x: rect.minX + 0.47771 * rect.width, y: rect.minY + 0.47558 * rect.height), control1: CGPoint(x: rect.minX + 0.26752 * rect.width, y: rect.minY + 0.33121 * rect.height), control2: CGPoint(x: rect.minX + 0.42251 * rect.width, y: rect.minY + 0.44374 * rect.height))
            context.addCurve(to: CGPoint(x: rect.minX + 0.26115 * rect.width, y: rect.minY + 0.20382 * rect.height), control1: CGPoint(x: rect.minX + 0.36093 * rect.width, y: rect.minY + 0.35244 * rect.height), control2: CGPoint(x: rect.minX + 0.25690 * rect.width, y: rect.minY + 0.19958 * rect.height))
            context.addCurve(to: CGPoint(x: rect.minX + 0.61783 * rect.width, y: rect.minY + 0.49682 * rect.height), control1: CGPoint(x: rect.minX + 0.44586 * rect.width, y: rect.minY + 0.39066 * rect.height), control2: CGPoint(x: rect.minX + 0.61783 * rect.width, y: rect.minY + 0.49682 * rect.height))
            context.addCurve(to: CGPoint(x: rect.minX + 0.63146 * rect.width, y: rect.minY + 0.50507 * rect.height), control1: CGPoint(x: rect.minX + 0.62355 * rect.width, y: rect.minY + 0.50002 * rect.height), control2: CGPoint(x: rect.minX + 0.62792 * rect.width, y: rect.minY + 0.50270 * rect.height))
            context.addCurve(to: CGPoint(x: rect.minX + 0.64119 * rect.width, y: rect.minY + 0.47558 * rect.height), control1: CGPoint(x: rect.minX + 0.63518 * rect.width, y: rect.minY + 0.49561 * rect.height), control2: CGPoint(x: rect.minX + 0.63843 * rect.width, y: rect.minY + 0.48577 * rect.height))
            context.addCurve(to: CGPoint(x: rect.minX + 0.56263 * rect.width, y: rect.minY + 0.14225 * rect.height), control1: CGPoint(x: rect.minX + 0.67091 * rect.width, y: rect.minY + 0.36730 * rect.height), control2: CGPoint(x: rect.minX + 0.63694 * rect.width, y: rect.minY + 0.24416 * rect.height))
            context.addCurve(to: CGPoint(x: rect.minX + 0.79406 * rect.width, y: rect.minY + 0.60510 * rect.height), control1: CGPoint(x: rect.minX + 0.73461 * rect.width, y: rect.minY + 0.24628 * rect.height), control2: CGPoint(x: rect.minX + 0.83652 * rect.width, y: rect.minY + 0.44161 * rect.height))
            context.addCurve(to: CGPoint(x: rect.minX + 0.79045 * rect.width, y: rect.minY + 0.61813 * rect.height), control1: CGPoint(x: rect.minX + 0.79293 * rect.width, y: rect.minY + 0.60951 * rect.height), control2: CGPoint(x: rect.minX + 0.79174 * rect.width, y: rect.minY + 0.61386 * rect.height))
            context.addCurve(to: CGPoint(x: rect.minX + 0.79193 * rect.width, y: rect.minY + 0.61996 * rect.height), control1: CGPoint(x: rect.minX + 0.79093 * rect.width, y: rect.minY + 0.61875 * rect.height), control2: CGPoint(x: rect.minX + 0.79142 * rect.width, y: rect.minY + 0.61934 * rect.height))
            context.addCurve(to: CGPoint(x: rect.minX + 0.84289 * rect.width, y: rect.minY + 0.81741 * rect.height), control1: CGPoint(x: rect.minX + 0.87686 * rect.width, y: rect.minY + 0.72611 * rect.height), control2: CGPoint(x: rect.minX + 0.85350 * rect.width, y: rect.minY + 0.83864 * rect.height))
            context.addCurve(to: CGPoint(x: rect.minX + 0.66820 * rect.width, y: rect.minY + 0.77312 * rect.height), control1: CGPoint(x: rect.minX + 0.79682 * rect.width, y: rect.minY + 0.72728 * rect.height), control2: CGPoint(x: rect.minX + 0.71153 * rect.width, y: rect.minY + 0.75484 * rect.height))
            context.closePath()
        context.closePath()
        context.fillPath()
    }
}
