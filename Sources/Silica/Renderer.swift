//
//  Renderer.swift
//  Silica
//
//  Created by Alsey Coleman Miller on 11/25/26.
//  Copyright © 2026 PureSwift. All rights reserved.
//

/// A drawing destination: what each rendering backend implements, and what a
/// `GraphicsContext` draws through.
///
/// Each method is one drawing command, so a recorded drawing replays into a
/// renderer one command at a time. A renderer keeps a graphics state that
/// `saveState()` pushes and `restoreState()` pops: the transform, the colors,
/// the stroke style, the clip, the alpha, the blend mode, the shadow and
/// antialiasing. Everything else arrives with the command that uses it.
///
/// User space has its origin at the top left with y pointing down, in points.
/// A renderer applies its own scale, and flips the y axis if its platform
/// draws the other way up.
public protocol Renderer: AnyObject {

    /// The size of the drawing destination, in points.
    var size: Size { get }

    // MARK: Graphics State

    /// Pushes a copy of the graphics state.
    func saveState()

    /// Pops the graphics state pushed last. Without one, does nothing.
    func restoreState()

    /// Applies a transform before the current one.
    func concatenate(_ transform: AffineTransform)

    /// The opacity everything is drawn with, from 0 to 1.
    func setAlpha(_ alpha: Double)

    func setBlendMode(_ mode: BlendMode)

    func setShouldAntialias(_ shouldAntialias: Bool)

    func setFillColor(_ color: Color)

    func setStrokeColor(_ color: Color)

    func setStrokeStyle(_ style: StrokeStyle)

    /// The shadow what's drawn casts, or nil for none.
    func setShadow(_ shadow: Shadow?)

    /// How images are sampled when they're scaled. A renderer that can't
    /// choose ignores it.
    func setInterpolationQuality(_ quality: InterpolationQuality)

    // MARK: Painting

    /// Fills a path with the fill color.
    func fill(_ path: Path, rule: FillRule)

    /// Strokes a path with the stroke color and style.
    func stroke(_ path: Path)

    /// Intersects the clip with a path.
    func clip(to path: Path, rule: FillRule)

    /// Clears a rectangle to transparent, within the clip.
    func clear(_ rect: Rect)

    /// Draws an image scaled to fill a rectangle, upright: its first row at
    /// the rectangle's top.
    func draw(_ image: Image, in rect: Rect)

    /// Paints a gradient along a line, within the clip.
    func drawLinearGradient(_ gradient: Gradient, start: Point, end: Point, options: GradientOptions)

    /// Paints a gradient between two circles, within the clip.
    func drawRadialGradient(_ gradient: Gradient, startCenter: Point, startRadius: Double,
                            endCenter: Point, endRadius: Double, options: GradientOptions)

    /// Draws what follows into a layer composited when it ends, with the alpha,
    /// shadow and blend mode at its start. Inside the layer they start reset.
    /// With a rectangle, the layer is clipped to it.
    func beginTransparencyLayer(in rect: Rect?)

    func endTransparencyLayer()

    /// Draws glyphs of a font at baseline origins in user space, filled with
    /// the fill color, stroked with the stroke color and style, or both.
    ///
    /// The glyphs are upright when y points down: `textMatrix`'s linear part
    /// is applied to their outlines, scaled to the font's size, so a matrix
    /// with a negative `d` draws them upright when y points up.
    func draw(_ glyphs: [Glyph], at positions: [Point], font: Font, textMatrix: AffineTransform, mode: TextDrawingMode)

    // MARK: Document

    /// Starts a page in a page-based (PDF) destination.
    func beginPage()

    /// Ends a page in a page-based (PDF) destination.
    func endPage()

    /// Finishes the destination (e.g. writes the PDF trailer). Nothing may be
    /// drawn after.
    func finish() throws(SilicaError)

    /// What's drawn so far as an image, or nil for a destination that isn't a bitmap.
    func makeImage() -> Image?
}

public extension Renderer {

    func setInterpolationQuality(_ quality: InterpolationQuality) { }
}
