/*
 * CGGradient.h
 * Silica's CoreGraphics: gradients.
 *
 * Copyright © 2026 PureSwift. All rights reserved.
 */

#ifndef SILICA_CGGRADIENT_H
#define SILICA_CGGRADIENT_H

#include "CGBase.h"
#include "CGColorSpace.h"

CG_EXTERN_C_BEGIN
CG_ASSUME_NONNULL_BEGIN

#if defined(__swift__)
#define CGGradientRef SilicaCGGradientRef
#endif

typedef struct CGGradient *CGGradientRef;

typedef uint32_t CGGradientDrawingOptions;
enum {
    kCGGradientDrawsBeforeStartLocation = (1 << 0),
    kCGGradientDrawsAfterEndLocation = (1 << 1)
};

CG_EXTERN CFTypeID CGGradientGetTypeID(void);

/* `components` holds `count` colors of the space's components and alpha;
 * `locations`, from 0 to 1, or NULL to spread them evenly. */
CG_EXTERN CGGradientRef CG_NULLABLE CGGradientCreateWithColorComponents(CGColorSpaceRef CG_NULLABLE space,
                                                                        const CGFloat * CG_NULLABLE components,
                                                                        const CGFloat * CG_NULLABLE locations, size_t count);

CG_EXTERN CGGradientRef CG_NULLABLE CGGradientRetain(CGGradientRef CG_NULLABLE gradient);
CG_EXTERN void CGGradientRelease(CGGradientRef CG_NULLABLE gradient);

CG_ASSUME_NONNULL_END
CG_EXTERN_C_END

#endif /* SILICA_CGGRADIENT_H */
