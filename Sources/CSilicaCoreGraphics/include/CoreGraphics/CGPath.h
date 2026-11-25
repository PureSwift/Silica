/*
 * CGPath.h
 * Silica's CoreGraphics: paths.
 *
 * Copyright © 2026 PureSwift. All rights reserved.
 */

#ifndef SILICA_CGPATH_H
#define SILICA_CGPATH_H

#include "CGBase.h"
#include "CGGeometry.h"
#include "CGAffineTransform.h"

CG_EXTERN_C_BEGIN
CG_ASSUME_NONNULL_BEGIN

#if defined(__swift__)
/* Swift's importer makes CoreGraphics' reference types Core Foundation
 * classes by their names; under these names they import as opaque pointers,
 * which libCoreGraphics' Swift implementation takes. */
#define CGMutablePathRef SilicaCGMutablePathRef
#define CGPathRef SilicaCGPathRef
#endif

typedef struct CGPath *CGMutablePathRef;
typedef const struct CGPath *CGPathRef;

typedef int32_t CGLineJoin;
enum {
    kCGLineJoinMiter = 0,
    kCGLineJoinRound = 1,
    kCGLineJoinBevel = 2
};

typedef int32_t CGLineCap;
enum {
    kCGLineCapButt = 0,
    kCGLineCapRound = 1,
    kCGLineCapSquare = 2
};

typedef CFIndex CGPathFillRule;
enum {
    kCGPathFillRuleWinding = 0,
    kCGPathFillRuleEvenOdd = 1
};

typedef int32_t CGPathElementType;
enum {
    kCGPathElementMoveToPoint = 0,
    kCGPathElementAddLineToPoint = 1,
    kCGPathElementAddQuadCurveToPoint = 2,
    kCGPathElementAddCurveToPoint = 3,
    kCGPathElementCloseSubpath = 4
};

/* An element and its points: one for a move or a line, a control point and
 * an end point for a quadratic curve, two control points and an end point
 * for a cubic curve, none for a close. */
struct CGPathElement {
    CGPathElementType type;
    CGPoint *points;
};
typedef struct CGPathElement CGPathElement;

typedef void (*CGPathApplierFunction)(void * CG_NULLABLE info, const CGPathElement *element);

CG_EXTERN CFTypeID CGPathGetTypeID(void);

/* Paths follow Core Foundation's ownership rule: a function with Create or
 * Copy in its name returns a path the caller releases. */
CG_EXTERN CGMutablePathRef CGPathCreateMutable(void);
CG_EXTERN CGPathRef CG_NULLABLE CGPathCreateCopy(CGPathRef CG_NULLABLE path);
CG_EXTERN CGPathRef CG_NULLABLE CGPathCreateCopyByTransformingPath(CGPathRef CG_NULLABLE path, const CGAffineTransform * CG_NULLABLE transform);
CG_EXTERN CGMutablePathRef CG_NULLABLE CGPathCreateMutableCopy(CGPathRef CG_NULLABLE path);
CG_EXTERN CGMutablePathRef CG_NULLABLE CGPathCreateMutableCopyByTransformingPath(CGPathRef CG_NULLABLE path, const CGAffineTransform * CG_NULLABLE transform);
CG_EXTERN CGPathRef CGPathCreateWithRect(CGRect rect, const CGAffineTransform * CG_NULLABLE transform);
CG_EXTERN CGPathRef CGPathCreateWithEllipseInRect(CGRect rect, const CGAffineTransform * CG_NULLABLE transform);
CG_EXTERN CGPathRef CGPathCreateWithRoundedRect(CGRect rect, CGFloat cornerWidth, CGFloat cornerHeight, const CGAffineTransform * CG_NULLABLE transform);

CG_EXTERN CGPathRef CG_NULLABLE CGPathRetain(CGPathRef CG_NULLABLE path);
CG_EXTERN void CGPathRelease(CGPathRef CG_NULLABLE path);

CG_EXTERN bool CGPathEqualToPath(CGPathRef CG_NULLABLE path1, CGPathRef CG_NULLABLE path2);

/* `m`, where a function takes one, transforms the points added. */
CG_EXTERN void CGPathMoveToPoint(CGMutablePathRef CG_NULLABLE path, const CGAffineTransform * CG_NULLABLE m, CGFloat x, CGFloat y);
CG_EXTERN void CGPathAddLineToPoint(CGMutablePathRef CG_NULLABLE path, const CGAffineTransform * CG_NULLABLE m, CGFloat x, CGFloat y);
CG_EXTERN void CGPathAddQuadCurveToPoint(CGMutablePathRef CG_NULLABLE path, const CGAffineTransform * CG_NULLABLE m, CGFloat cpx, CGFloat cpy, CGFloat x, CGFloat y);
CG_EXTERN void CGPathAddCurveToPoint(CGMutablePathRef CG_NULLABLE path, const CGAffineTransform * CG_NULLABLE m, CGFloat cp1x, CGFloat cp1y, CGFloat cp2x, CGFloat cp2y, CGFloat x, CGFloat y);
CG_EXTERN void CGPathCloseSubpath(CGMutablePathRef CG_NULLABLE path);

CG_EXTERN void CGPathAddRect(CGMutablePathRef CG_NULLABLE path, const CGAffineTransform * CG_NULLABLE m, CGRect rect);
CG_EXTERN void CGPathAddRects(CGMutablePathRef CG_NULLABLE path, const CGAffineTransform * CG_NULLABLE m, const CGRect * CG_NULLABLE rects, size_t count);
CG_EXTERN void CGPathAddLines(CGMutablePathRef CG_NULLABLE path, const CGAffineTransform * CG_NULLABLE m, const CGPoint * CG_NULLABLE points, size_t count);
CG_EXTERN void CGPathAddEllipseInRect(CGMutablePathRef CG_NULLABLE path, const CGAffineTransform * CG_NULLABLE m, CGRect rect);
CG_EXTERN void CGPathAddRoundedRect(CGMutablePathRef CG_NULLABLE path, const CGAffineTransform * CG_NULLABLE transform, CGRect rect, CGFloat cornerWidth, CGFloat cornerHeight);
/* An arc from `startAngle` turning by `delta`: counterclockwise in y-up
 * space when `delta` is positive. */
CG_EXTERN void CGPathAddRelativeArc(CGMutablePathRef CG_NULLABLE path, const CGAffineTransform * CG_NULLABLE matrix, CGFloat x, CGFloat y, CGFloat radius, CGFloat startAngle, CGFloat delta);
CG_EXTERN void CGPathAddArc(CGMutablePathRef CG_NULLABLE path, const CGAffineTransform * CG_NULLABLE m, CGFloat x, CGFloat y, CGFloat radius, CGFloat startAngle, CGFloat endAngle, bool clockwise);
CG_EXTERN void CGPathAddArcToPoint(CGMutablePathRef CG_NULLABLE path, const CGAffineTransform * CG_NULLABLE m, CGFloat x1, CGFloat y1, CGFloat x2, CGFloat y2, CGFloat radius);
CG_EXTERN void CGPathAddPath(CGMutablePathRef CG_NULLABLE path1, const CGAffineTransform * CG_NULLABLE m, CGPathRef CG_NULLABLE path2);

CG_EXTERN bool CGPathIsEmpty(CGPathRef CG_NULLABLE path);
/* Whether the path is one rectangle; if so, `rect` is set to it. */
CG_EXTERN bool CGPathIsRect(CGPathRef CG_NULLABLE path, CGRect * CG_NULLABLE rect);
/* Where the next element starts, or CGPointZero for an empty path. */
CG_EXTERN CGPoint CGPathGetCurrentPoint(CGPathRef CG_NULLABLE path);
/* The bounds of the path's points and control points. */
CG_EXTERN CGRect CGPathGetBoundingBox(CGPathRef CG_NULLABLE path);
/* The bounds of the path's lines and curves. */
CG_EXTERN CGRect CGPathGetPathBoundingBox(CGPathRef CG_NULLABLE path);
/* Whether `point`, transformed by `m`, is inside the path filled with a rule. */
CG_EXTERN bool CGPathContainsPoint(CGPathRef CG_NULLABLE path, const CGAffineTransform * CG_NULLABLE m, CGPoint point, bool eoFill);

/* Calls `function` with each element, in order. */
CG_EXTERN void CGPathApply(CGPathRef CG_NULLABLE path, void * CG_NULLABLE info, CGPathApplierFunction CG_NULLABLE function);

CG_ASSUME_NONNULL_END
CG_EXTERN_C_END

#endif /* SILICA_CGPATH_H */
