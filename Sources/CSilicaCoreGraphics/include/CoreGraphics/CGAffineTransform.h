/*
 * CGAffineTransform.h
 * Silica's CoreGraphics: affine transforms.
 *
 * Copyright © 2026 PureSwift. All rights reserved.
 */

#ifndef SILICA_CGAFFINETRANSFORM_H
#define SILICA_CGAFFINETRANSFORM_H

#include "CGBase.h"
#include "CGGeometry.h"

CG_EXTERN_C_BEGIN
CG_ASSUME_NONNULL_BEGIN

/* x' = a·x + c·y + tx, y' = b·x + d·y + ty */
struct CGAffineTransform {
    CGFloat a, b, c, d;
    CGFloat tx, ty;
};
typedef struct CGAffineTransform CGAffineTransform;

/* A transform as a scale, then a shear, a rotation and a translation. */
struct CGAffineTransformComponents {
    CGSize scale;
    CGFloat horizontalShear;
    CGFloat rotation;
    CGVector translation;
};
typedef struct CGAffineTransformComponents CGAffineTransformComponents;

CG_EXTERN const CGAffineTransform CGAffineTransformIdentity;

CG_EXTERN CGAffineTransform CGAffineTransformMake(CGFloat a, CGFloat b, CGFloat c, CGFloat d, CGFloat tx, CGFloat ty);
CG_EXTERN CGAffineTransform CGAffineTransformMakeTranslation(CGFloat tx, CGFloat ty);
CG_EXTERN CGAffineTransform CGAffineTransformMakeScale(CGFloat sx, CGFloat sy);
CG_EXTERN CGAffineTransform CGAffineTransformMakeRotation(CGFloat angle);

CG_EXTERN bool CGAffineTransformIsIdentity(CGAffineTransform t);
CG_EXTERN bool CGAffineTransformEqualToTransform(CGAffineTransform t1, CGAffineTransform t2);

/* A translation, scale or rotation applied before `t`. */
CG_EXTERN CGAffineTransform CGAffineTransformTranslate(CGAffineTransform t, CGFloat tx, CGFloat ty);
CG_EXTERN CGAffineTransform CGAffineTransformScale(CGAffineTransform t, CGFloat sx, CGFloat sy);
CG_EXTERN CGAffineTransform CGAffineTransformRotate(CGAffineTransform t, CGFloat angle);

/* The inverse, or `t` itself when it can't be inverted. */
CG_EXTERN CGAffineTransform CGAffineTransformInvert(CGAffineTransform t);
/* `t1`, then `t2`. */
CG_EXTERN CGAffineTransform CGAffineTransformConcat(CGAffineTransform t1, CGAffineTransform t2);

CG_EXTERN CGPoint CGPointApplyAffineTransform(CGPoint point, CGAffineTransform t);
CG_EXTERN CGSize CGSizeApplyAffineTransform(CGSize size, CGAffineTransform t);
/* The smallest rectangle containing the transformed corners. */
CG_EXTERN CGRect CGRectApplyAffineTransform(CGRect rect, CGAffineTransform t);

CG_ASSUME_NONNULL_END
CG_EXTERN_C_END

#endif /* SILICA_CGAFFINETRANSFORM_H */
