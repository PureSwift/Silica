/*
 * CGContext.h
 * Silica's CoreGraphics: drawing contexts.
 *
 * Copyright © 2026 PureSwift. All rights reserved.
 */

#ifndef SILICA_CGCONTEXT_H
#define SILICA_CGCONTEXT_H

#include "CGBase.h"
#include "CGGeometry.h"
#include "CGAffineTransform.h"
#include "CGPath.h"
#include "CGColorSpace.h"
#include "CGColor.h"
#include "CGGradient.h"
#include "CGPattern.h"
#include "CGShading.h"
#include "CGImage.h"
#include "CGFont.h"

CG_EXTERN_C_BEGIN
CG_ASSUME_NONNULL_BEGIN

#if defined(__swift__)
#define CGContextRef SilicaCGContextRef
#endif

typedef struct CGContext *CGContextRef;

typedef int32_t CGPathDrawingMode;
enum {
    kCGPathFill = 0,
    kCGPathEOFill = 1,
    kCGPathStroke = 2,
    kCGPathFillStroke = 3,
    kCGPathEOFillStroke = 4
};

typedef int32_t CGInterpolationQuality;
enum {
    kCGInterpolationDefault = 0,
    kCGInterpolationNone = 1,
    kCGInterpolationLow = 2,
    kCGInterpolationMedium = 4,
    kCGInterpolationHigh = 3
};

typedef int32_t CGBlendMode;
enum {
    kCGBlendModeNormal = 0,
    kCGBlendModeMultiply,
    kCGBlendModeScreen,
    kCGBlendModeOverlay,
    kCGBlendModeDarken,
    kCGBlendModeLighten,
    kCGBlendModeColorDodge,
    kCGBlendModeColorBurn,
    kCGBlendModeSoftLight,
    kCGBlendModeHardLight,
    kCGBlendModeDifference,
    kCGBlendModeExclusion,
    kCGBlendModeHue,
    kCGBlendModeSaturation,
    kCGBlendModeColor,
    kCGBlendModeLuminosity,
    kCGBlendModeClear,
    kCGBlendModeCopy,
    kCGBlendModeSourceIn,
    kCGBlendModeSourceOut,
    kCGBlendModeSourceAtop,
    kCGBlendModeDestinationOver,
    kCGBlendModeDestinationIn,
    kCGBlendModeDestinationOut,
    kCGBlendModeDestinationAtop,
    kCGBlendModeXOR,
    kCGBlendModePlusDarker,
    kCGBlendModePlusLighter
};

CG_EXTERN CFTypeID CGContextGetTypeID(void);

CG_EXTERN CGContextRef CG_NULLABLE CGContextRetain(CGContextRef CG_NULLABLE c);
CG_EXTERN void CGContextRelease(CGContextRef CG_NULLABLE c);

/* A bitmap context has one page; these do nothing to it. */
CG_EXTERN void CGContextBeginPage(CGContextRef CG_NULLABLE c, const CGRect * CG_NULLABLE mediaBox);
CG_EXTERN void CGContextEndPage(CGContextRef CG_NULLABLE c);
/* Drawing reaches a bitmap context's memory as it's done: these do nothing. */
CG_EXTERN void CGContextFlush(CGContextRef CG_NULLABLE c);
CG_EXTERN void CGContextSynchronize(CGContextRef CG_NULLABLE c);
CG_EXTERN void CGContextSynchronizeAttributes(CGContextRef CG_NULLABLE c);

/* Graphics state */
CG_EXTERN void CGContextSaveGState(CGContextRef CG_NULLABLE c);
CG_EXTERN void CGContextRestoreGState(CGContextRef CG_NULLABLE c);

/* The current transformation matrix */
CG_EXTERN void CGContextScaleCTM(CGContextRef CG_NULLABLE c, CGFloat sx, CGFloat sy);
CG_EXTERN void CGContextTranslateCTM(CGContextRef CG_NULLABLE c, CGFloat tx, CGFloat ty);
CG_EXTERN void CGContextRotateCTM(CGContextRef CG_NULLABLE c, CGFloat angle);
CG_EXTERN void CGContextConcatCTM(CGContextRef CG_NULLABLE c, CGAffineTransform transform);
CG_EXTERN CGAffineTransform CGContextGetCTM(CGContextRef CG_NULLABLE c);

/* Drawing attributes */
CG_EXTERN void CGContextSetLineWidth(CGContextRef CG_NULLABLE c, CGFloat width);
CG_EXTERN void CGContextSetLineCap(CGContextRef CG_NULLABLE c, CGLineCap cap);
CG_EXTERN void CGContextSetLineJoin(CGContextRef CG_NULLABLE c, CGLineJoin join);
CG_EXTERN void CGContextSetMiterLimit(CGContextRef CG_NULLABLE c, CGFloat limit);
CG_EXTERN void CGContextSetLineDash(CGContextRef CG_NULLABLE c, CGFloat phase, const CGFloat * CG_NULLABLE lengths, size_t count);
CG_EXTERN void CGContextSetFlatness(CGContextRef CG_NULLABLE c, CGFloat flatness);
CG_EXTERN void CGContextSetAlpha(CGContextRef CG_NULLABLE c, CGFloat alpha);
CG_EXTERN void CGContextSetBlendMode(CGContextRef CG_NULLABLE c, CGBlendMode mode);
CG_EXTERN void CGContextSetShouldAntialias(CGContextRef CG_NULLABLE c, bool shouldAntialias);
CG_EXTERN void CGContextSetAllowsAntialiasing(CGContextRef CG_NULLABLE c, bool allowsAntialiasing);
CG_EXTERN void CGContextSetInterpolationQuality(CGContextRef CG_NULLABLE c, CGInterpolationQuality quality);
CG_EXTERN CGInterpolationQuality CGContextGetInterpolationQuality(CGContextRef CG_NULLABLE c);
CG_EXTERN void CGContextSetRenderingIntent(CGContextRef CG_NULLABLE c, CGColorRenderingIntent intent);

/* Paths */
CG_EXTERN void CGContextBeginPath(CGContextRef CG_NULLABLE c);
CG_EXTERN void CGContextMoveToPoint(CGContextRef CG_NULLABLE c, CGFloat x, CGFloat y);
CG_EXTERN void CGContextAddLineToPoint(CGContextRef CG_NULLABLE c, CGFloat x, CGFloat y);
CG_EXTERN void CGContextAddCurveToPoint(CGContextRef CG_NULLABLE c, CGFloat cp1x, CGFloat cp1y, CGFloat cp2x, CGFloat cp2y, CGFloat x, CGFloat y);
CG_EXTERN void CGContextAddQuadCurveToPoint(CGContextRef CG_NULLABLE c, CGFloat cpx, CGFloat cpy, CGFloat x, CGFloat y);
CG_EXTERN void CGContextClosePath(CGContextRef CG_NULLABLE c);
CG_EXTERN void CGContextAddRect(CGContextRef CG_NULLABLE c, CGRect rect);
CG_EXTERN void CGContextAddRects(CGContextRef CG_NULLABLE c, const CGRect * CG_NULLABLE rects, size_t count);
CG_EXTERN void CGContextAddLines(CGContextRef CG_NULLABLE c, const CGPoint * CG_NULLABLE points, size_t count);
CG_EXTERN void CGContextAddEllipseInRect(CGContextRef CG_NULLABLE c, CGRect rect);
CG_EXTERN void CGContextAddArc(CGContextRef CG_NULLABLE c, CGFloat x, CGFloat y, CGFloat radius, CGFloat startAngle, CGFloat endAngle, int clockwise);
CG_EXTERN void CGContextAddArcToPoint(CGContextRef CG_NULLABLE c, CGFloat x1, CGFloat y1, CGFloat x2, CGFloat y2, CGFloat radius);
CG_EXTERN void CGContextAddPath(CGContextRef CG_NULLABLE c, CGPathRef CG_NULLABLE path);
/* The current path, in user space. */
CG_EXTERN CGPathRef CG_NULLABLE CGContextCopyPath(CGContextRef CG_NULLABLE c);
CG_EXTERN bool CGContextIsPathEmpty(CGContextRef CG_NULLABLE c);
CG_EXTERN CGPoint CGContextGetPathCurrentPoint(CGContextRef CG_NULLABLE c);
CG_EXTERN CGRect CGContextGetPathBoundingBox(CGContextRef CG_NULLABLE c);
/* The current path, replaced by the outline of its stroke in the context's
 * line width, caps, joins, miter limit and dashes. */
CG_EXTERN void CGContextReplacePathWithStrokedPath(CGContextRef CG_NULLABLE c);
CG_EXTERN bool CGContextPathContainsPoint(CGContextRef CG_NULLABLE c, CGPoint point, CGPathDrawingMode mode);

/* Painting; each clears the current path */
CG_EXTERN void CGContextDrawPath(CGContextRef CG_NULLABLE c, CGPathDrawingMode mode);
CG_EXTERN void CGContextFillPath(CGContextRef CG_NULLABLE c);
CG_EXTERN void CGContextEOFillPath(CGContextRef CG_NULLABLE c);
CG_EXTERN void CGContextStrokePath(CGContextRef CG_NULLABLE c);
CG_EXTERN void CGContextFillRect(CGContextRef CG_NULLABLE c, CGRect rect);
CG_EXTERN void CGContextFillRects(CGContextRef CG_NULLABLE c, const CGRect * CG_NULLABLE rects, size_t count);
CG_EXTERN void CGContextStrokeRect(CGContextRef CG_NULLABLE c, CGRect rect);
CG_EXTERN void CGContextStrokeRectWithWidth(CGContextRef CG_NULLABLE c, CGRect rect, CGFloat width);
CG_EXTERN void CGContextClearRect(CGContextRef CG_NULLABLE c, CGRect rect);
CG_EXTERN void CGContextFillEllipseInRect(CGContextRef CG_NULLABLE c, CGRect rect);
CG_EXTERN void CGContextStrokeEllipseInRect(CGContextRef CG_NULLABLE c, CGRect rect);
CG_EXTERN void CGContextStrokeLineSegments(CGContextRef CG_NULLABLE c, const CGPoint * CG_NULLABLE points, size_t count);

/* Clipping */
CG_EXTERN void CGContextClip(CGContextRef CG_NULLABLE c);
CG_EXTERN void CGContextEOClip(CGContextRef CG_NULLABLE c);
CG_EXTERN void CGContextClipToRect(CGContextRef CG_NULLABLE c, CGRect rect);
CG_EXTERN void CGContextClipToRects(CGContextRef CG_NULLABLE c, const CGRect * CG_NULLABLE rects, size_t count);
/* Clips to a mask in a rectangle, upright: an image mask, or a gray image
 * whose samples are the alpha. Nothing is drawn outside the rectangle. */
CG_EXTERN void CGContextClipToMask(CGContextRef CG_NULLABLE c, CGRect rect, CGImageRef CG_NULLABLE mask);
/* The clip back to the whole context, until the state is restored. */
CG_EXTERN void CGContextResetClip(CGContextRef CG_NULLABLE c);
CG_EXTERN CGRect CGContextGetClipBoundingBox(CGContextRef CG_NULLABLE c);

/* Colors */
CG_EXTERN void CGContextSetFillColorWithColor(CGContextRef CG_NULLABLE c, CGColorRef CG_NULLABLE color);
CG_EXTERN void CGContextSetStrokeColorWithColor(CGContextRef CG_NULLABLE c, CGColorRef CG_NULLABLE color);
CG_EXTERN void CGContextSetFillColorSpace(CGContextRef CG_NULLABLE c, CGColorSpaceRef CG_NULLABLE space);
CG_EXTERN void CGContextSetStrokeColorSpace(CGContextRef CG_NULLABLE c, CGColorSpaceRef CG_NULLABLE space);
/* `components` are in the fill (or stroke) color space, then alpha. */
CG_EXTERN void CGContextSetFillColor(CGContextRef CG_NULLABLE c, const CGFloat * CG_NULLABLE components);
CG_EXTERN void CGContextSetStrokeColor(CGContextRef CG_NULLABLE c, const CGFloat * CG_NULLABLE components);
CG_EXTERN void CGContextSetGrayFillColor(CGContextRef CG_NULLABLE c, CGFloat gray, CGFloat alpha);
CG_EXTERN void CGContextSetGrayStrokeColor(CGContextRef CG_NULLABLE c, CGFloat gray, CGFloat alpha);
CG_EXTERN void CGContextSetRGBFillColor(CGContextRef CG_NULLABLE c, CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha);
CG_EXTERN void CGContextSetRGBStrokeColor(CGContextRef CG_NULLABLE c, CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha);

/* Patterns: `components` are the base space's components and alpha for an
 * uncolored pattern, or alpha alone. The phase moves the patterns set after
 * it, in base space. */
CG_EXTERN void CGContextSetFillPattern(CGContextRef CG_NULLABLE c, CGPatternRef CG_NULLABLE pattern, const CGFloat * CG_NULLABLE components);
CG_EXTERN void CGContextSetStrokePattern(CGContextRef CG_NULLABLE c, CGPatternRef CG_NULLABLE pattern, const CGFloat * CG_NULLABLE components);
CG_EXTERN void CGContextSetPatternPhase(CGContextRef CG_NULLABLE c, CGSize phase);

/* Shadows: the offset is in base space, y up */
CG_EXTERN void CGContextSetShadow(CGContextRef CG_NULLABLE c, CGSize offset, CGFloat blur);
CG_EXTERN void CGContextSetShadowWithColor(CGContextRef CG_NULLABLE c, CGSize offset, CGFloat blur, CGColorRef CG_NULLABLE color);

/* Gradients */
CG_EXTERN void CGContextDrawLinearGradient(CGContextRef CG_NULLABLE c, CGGradientRef CG_NULLABLE gradient,
                                           CGPoint startPoint, CGPoint endPoint, CGGradientDrawingOptions options);
CG_EXTERN void CGContextDrawRadialGradient(CGContextRef CG_NULLABLE c, CGGradientRef CG_NULLABLE gradient,
                                           CGPoint startCenter, CGFloat startRadius, CGPoint endCenter, CGFloat endRadius,
                                           CGGradientDrawingOptions options);

/* Shadings, within the clip */
CG_EXTERN void CGContextDrawShading(CGContextRef CG_NULLABLE c, CGShadingRef CG_NULLABLE shading);

/* Transparency layers; `auxiliaryInfo` is a CFDictionaryRef, unused */
CG_EXTERN void CGContextBeginTransparencyLayer(CGContextRef CG_NULLABLE c, const void * CG_NULLABLE auxiliaryInfo);
CG_EXTERN void CGContextBeginTransparencyLayerWithRect(CGContextRef CG_NULLABLE c, CGRect rect, const void * CG_NULLABLE auxInfo);
CG_EXTERN void CGContextEndTransparencyLayer(CGContextRef CG_NULLABLE c);

/* Images */
/* An image mask paints the fill color where it lets through. */
CG_EXTERN void CGContextDrawImage(CGContextRef CG_NULLABLE c, CGRect rect, CGImageRef CG_NULLABLE image);
/* The image repeated across the clip, each copy the rectangle's size, one at
 * the rectangle. */
CG_EXTERN void CGContextDrawTiledImage(CGContextRef CG_NULLABLE c, CGRect rect, CGImageRef CG_NULLABLE image);

/* Text: glyphs of a font at a size, placed by the text matrix. The clipping
 * modes draw as their fill and stroke parts, and don't clip. */
typedef int32_t CGTextDrawingMode;
enum {
    kCGTextFill = 0,
    kCGTextStroke = 1,
    kCGTextFillStroke = 2,
    kCGTextInvisible = 3,
    kCGTextFillClip = 4,
    kCGTextStrokeClip = 5,
    kCGTextFillStrokeClip = 6,
    kCGTextClip = 7
};

typedef int32_t CGTextEncoding;
enum {
    kCGEncodingFontSpecific = 0,
    kCGEncodingMacRoman = 1
};

CG_EXTERN void CGContextSetFont(CGContextRef CG_NULLABLE c, CGFontRef CG_NULLABLE font);
CG_EXTERN void CGContextSetFontSize(CGContextRef CG_NULLABLE c, CGFloat size);
CG_EXTERN void CGContextSetCharacterSpacing(CGContextRef CG_NULLABLE c, CGFloat spacing);
CG_EXTERN void CGContextSetTextDrawingMode(CGContextRef CG_NULLABLE c, CGTextDrawingMode mode);
CG_EXTERN void CGContextSetTextMatrix(CGContextRef CG_NULLABLE c, CGAffineTransform t);
CG_EXTERN CGAffineTransform CGContextGetTextMatrix(CGContextRef CG_NULLABLE c);
CG_EXTERN void CGContextSetTextPosition(CGContextRef CG_NULLABLE c, CGFloat x, CGFloat y);
CG_EXTERN CGPoint CGContextGetTextPosition(CGContextRef CG_NULLABLE c);
/* Glyphs from the text position, each after the last one's advance and the
 * character spacing; the text position moves past them. */
CG_EXTERN void CGContextShowGlyphs(CGContextRef CG_NULLABLE c, const CGGlyph * CG_NULLABLE g, size_t count);
CG_EXTERN void CGContextShowGlyphsAtPoint(CGContextRef CG_NULLABLE c, CGFloat x, CGFloat y, const CGGlyph * CG_NULLABLE glyphs, size_t count);
/* Glyphs at positions in text space; the text position doesn't move. */
CG_EXTERN void CGContextShowGlyphsAtPositions(CGContextRef CG_NULLABLE c, const CGGlyph * CG_NULLABLE glyphs,
                                              const CGPoint * CG_NULLABLE Lpositions, size_t count);
/* Glyphs from the text position, each after the advance before it. */
CG_EXTERN void CGContextShowGlyphsWithAdvances(CGContextRef CG_NULLABLE c, const CGGlyph * CG_NULLABLE glyphs,
                                               const CGSize * CG_NULLABLE advances, size_t count);
/* The font by name at a size, for CGContextShowText. */
CG_EXTERN void CGContextSelectFont(CGContextRef CG_NULLABLE c, const char * CG_NULLABLE name, CGFloat size, CGTextEncoding textEncoding);
/* Mac Roman text with the selected font. */
CG_EXTERN void CGContextShowText(CGContextRef CG_NULLABLE c, const char * CG_NULLABLE string, size_t length);
CG_EXTERN void CGContextShowTextAtPoint(CGContextRef CG_NULLABLE c, CGFloat x, CGFloat y, const char * CG_NULLABLE string, size_t length);
/* Silica's rasterizers smooth glyphs themselves: these do nothing. */
CG_EXTERN void CGContextSetShouldSmoothFonts(CGContextRef CG_NULLABLE c, bool shouldSmoothFonts);
CG_EXTERN void CGContextSetAllowsFontSmoothing(CGContextRef CG_NULLABLE c, bool allowsFontSmoothing);
CG_EXTERN void CGContextSetShouldSubpixelPositionFonts(CGContextRef CG_NULLABLE c, bool shouldSubpixelPositionFonts);
CG_EXTERN void CGContextSetAllowsFontSubpixelPositioning(CGContextRef CG_NULLABLE c, bool allowsFontSubpixelPositioning);
CG_EXTERN void CGContextSetShouldSubpixelQuantizeFonts(CGContextRef CG_NULLABLE c, bool shouldSubpixelQuantizeFonts);
CG_EXTERN void CGContextSetAllowsFontSubpixelQuantization(CGContextRef CG_NULLABLE c, bool allowsFontSubpixelQuantization);

/* Device space: a bitmap's pixels, from its top left */
CG_EXTERN CGPoint CGContextConvertPointToDeviceSpace(CGContextRef CG_NULLABLE c, CGPoint point);
CG_EXTERN CGPoint CGContextConvertPointToUserSpace(CGContextRef CG_NULLABLE c, CGPoint point);
CG_EXTERN CGSize CGContextConvertSizeToDeviceSpace(CGContextRef CG_NULLABLE c, CGSize size);
CG_EXTERN CGSize CGContextConvertSizeToUserSpace(CGContextRef CG_NULLABLE c, CGSize size);
CG_EXTERN CGRect CGContextConvertRectToDeviceSpace(CGContextRef CG_NULLABLE c, CGRect rect);
CG_EXTERN CGRect CGContextConvertRectToUserSpace(CGContextRef CG_NULLABLE c, CGRect rect);

CG_ASSUME_NONNULL_END
CG_EXTERN_C_END

#endif /* SILICA_CGCONTEXT_H */
