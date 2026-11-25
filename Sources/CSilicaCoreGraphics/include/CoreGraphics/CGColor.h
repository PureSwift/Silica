/*
 * CGColor.h
 * Silica's CoreGraphics: colors.
 *
 * Copyright © 2026 PureSwift. All rights reserved.
 */

#ifndef SILICA_CGCOLOR_H
#define SILICA_CGCOLOR_H

#include "CGBase.h"
#include "CGColorSpace.h"
#include "CGPattern.h"

CG_EXTERN_C_BEGIN
CG_ASSUME_NONNULL_BEGIN

#if defined(__swift__)
#define CGColorRef SilicaCGColorRef
#endif

typedef struct CGColor *CGColorRef;

CG_EXTERN CFTypeID CGColorGetTypeID(void);

/* `components` holds the space's components, then alpha. */
CG_EXTERN CGColorRef CG_NULLABLE CGColorCreate(CGColorSpaceRef CG_NULLABLE space, const CGFloat * CG_NULLABLE components);
CG_EXTERN CGColorRef CGColorCreateGenericGray(CGFloat gray, CGFloat alpha);
CG_EXTERN CGColorRef CGColorCreateGenericRGB(CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha);
CG_EXTERN CGColorRef CGColorCreateSRGB(CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha);
CG_EXTERN CGColorRef CG_NULLABLE CGColorCreateCopy(CGColorRef CG_NULLABLE color);
CG_EXTERN CGColorRef CG_NULLABLE CGColorCreateCopyWithAlpha(CGColorRef CG_NULLABLE color, CGFloat alpha);

CG_EXTERN CGColorRef CG_NULLABLE CGColorRetain(CGColorRef CG_NULLABLE color);
CG_EXTERN void CGColorRelease(CGColorRef CG_NULLABLE color);

CG_EXTERN bool CGColorEqualToColor(CGColorRef CG_NULLABLE color1, CGColorRef CG_NULLABLE color2);
CG_EXTERN size_t CGColorGetNumberOfComponents(CGColorRef CG_NULLABLE color);
/* The color's components, then alpha; valid while the color is. */
CG_EXTERN const CGFloat * CG_NULLABLE CGColorGetComponents(CGColorRef CG_NULLABLE color);
CG_EXTERN CGFloat CGColorGetAlpha(CGColorRef CG_NULLABLE color);
CG_EXTERN CGColorSpaceRef CG_NULLABLE CGColorGetColorSpace(CGColorRef CG_NULLABLE color);

/* A pattern as a color, in a pattern space: `components` are the base
 * space's components and alpha for an uncolored pattern, or alpha alone. */
CG_EXTERN CGColorRef CG_NULLABLE CGColorCreateWithPattern(CGColorSpaceRef CG_NULLABLE space, CGPatternRef CG_NULLABLE pattern,
                                                          const CGFloat * CG_NULLABLE components);
CG_EXTERN CGPatternRef CG_NULLABLE CGColorGetPattern(CGColorRef CG_NULLABLE color);

CG_ASSUME_NONNULL_END
CG_EXTERN_C_END

#endif /* SILICA_CGCOLOR_H */
