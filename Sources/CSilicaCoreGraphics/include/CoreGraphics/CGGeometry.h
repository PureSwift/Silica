/*
 * CGGeometry.h
 * Silica's CoreGraphics: points, sizes, vectors and rectangles.
 *
 * Copyright © 2026 PureSwift. All rights reserved.
 */

#ifndef SILICA_CGGEOMETRY_H
#define SILICA_CGGEOMETRY_H

#include "CGBase.h"

CG_EXTERN_C_BEGIN
CG_ASSUME_NONNULL_BEGIN

struct CGPoint {
    CGFloat x;
    CGFloat y;
};
typedef struct CGPoint CGPoint;

struct CGSize {
    CGFloat width;
    CGFloat height;
};
typedef struct CGSize CGSize;

struct CGVector {
    CGFloat dx;
    CGFloat dy;
};
typedef struct CGVector CGVector;

struct CGRect {
    CGPoint origin;
    CGSize size;
};
typedef struct CGRect CGRect;

/* An edge of a rectangle, for CGRectDivide. */
typedef uint32_t CGRectEdge;
enum {
    CGRectMinXEdge = 0,
    CGRectMinYEdge = 1,
    CGRectMaxXEdge = 2,
    CGRectMaxYEdge = 3
};

CG_EXTERN const CGPoint CGPointZero;
CG_EXTERN const CGSize CGSizeZero;
CG_EXTERN const CGRect CGRectZero;
/* The rectangle with no position: what intersecting rectangles that don't
 * overlap gives. */
CG_EXTERN const CGRect CGRectNull;
/* The rectangle with no bounds. */
CG_EXTERN const CGRect CGRectInfinite;

CG_INLINE CGPoint CGPointMake(CGFloat x, CGFloat y) {
    CGPoint point; point.x = x; point.y = y; return point;
}

CG_INLINE CGSize CGSizeMake(CGFloat width, CGFloat height) {
    CGSize size; size.width = width; size.height = height; return size;
}

CG_INLINE CGVector CGVectorMake(CGFloat dx, CGFloat dy) {
    CGVector vector; vector.dx = dx; vector.dy = dy; return vector;
}

CG_INLINE CGRect CGRectMake(CGFloat x, CGFloat y, CGFloat width, CGFloat height) {
    CGRect rect;
    rect.origin.x = x; rect.origin.y = y;
    rect.size.width = width; rect.size.height = height;
    return rect;
}

CG_EXTERN CGFloat CGRectGetMinX(CGRect rect);
CG_EXTERN CGFloat CGRectGetMidX(CGRect rect);
CG_EXTERN CGFloat CGRectGetMaxX(CGRect rect);
CG_EXTERN CGFloat CGRectGetMinY(CGRect rect);
CG_EXTERN CGFloat CGRectGetMidY(CGRect rect);
CG_EXTERN CGFloat CGRectGetMaxY(CGRect rect);
CG_EXTERN CGFloat CGRectGetWidth(CGRect rect);
CG_EXTERN CGFloat CGRectGetHeight(CGRect rect);

CG_EXTERN bool CGPointEqualToPoint(CGPoint point1, CGPoint point2);
CG_EXTERN bool CGSizeEqualToSize(CGSize size1, CGSize size2);
CG_EXTERN bool CGRectEqualToRect(CGRect rect1, CGRect rect2);

/* The rectangle with a positive width and height. */
CG_EXTERN CGRect CGRectStandardize(CGRect rect);
CG_EXTERN bool CGRectIsEmpty(CGRect rect);
CG_EXTERN bool CGRectIsNull(CGRect rect);
CG_EXTERN bool CGRectIsInfinite(CGRect rect);

CG_EXTERN CGRect CGRectInset(CGRect rect, CGFloat dx, CGFloat dy);
CG_EXTERN CGRect CGRectIntegral(CGRect rect);
CG_EXTERN CGRect CGRectUnion(CGRect r1, CGRect r2);
CG_EXTERN CGRect CGRectIntersection(CGRect r1, CGRect r2);
CG_EXTERN CGRect CGRectOffset(CGRect rect, CGFloat dx, CGFloat dy);
CG_EXTERN void CGRectDivide(CGRect rect, CGRect *slice, CGRect *remainder, CGFloat amount, CGRectEdge edge);

CG_EXTERN bool CGRectContainsPoint(CGRect rect, CGPoint point);
CG_EXTERN bool CGRectContainsRect(CGRect rect1, CGRect rect2);
CG_EXTERN bool CGRectIntersectsRect(CGRect rect1, CGRect rect2);

CG_ASSUME_NONNULL_END
CG_EXTERN_C_END

#endif /* SILICA_CGGEOMETRY_H */
