/*
 * CGShading.h
 * Silica's CoreGraphics: shadings.
 *
 * Copyright © 2026 PureSwift. All rights reserved.
 */

#ifndef SILICA_CGSHADING_H
#define SILICA_CGSHADING_H

#include "CGBase.h"
#include "CGGeometry.h"
#include "CGColorSpace.h"
#include "CGFunction.h"

CG_EXTERN_C_BEGIN
CG_ASSUME_NONNULL_BEGIN

#if defined(__swift__)
#define CGShadingRef SilicaCGShadingRef
#endif

typedef struct CGShading *CGShadingRef;

CG_EXTERN CFTypeID CGShadingGetTypeID(void);

/* Shadings color with a function of one input, from its domain's start to
 * its end, to the space's components and then alpha (1 if the function has
 * no more outputs than the space has components). Silica samples the
 * function 256 times and draws the gradient between the samples. */
CG_EXTERN CGShadingRef CG_NULLABLE CGShadingCreateAxial(CGColorSpaceRef CG_NULLABLE space, CGPoint start, CGPoint end,
                                                        CGFunctionRef CG_NULLABLE function, bool extendStart, bool extendEnd);
CG_EXTERN CGShadingRef CG_NULLABLE CGShadingCreateRadial(CGColorSpaceRef CG_NULLABLE space, CGPoint start, CGFloat startRadius,
                                                         CGPoint end, CGFloat endRadius, CGFunctionRef CG_NULLABLE function,
                                                         bool extendStart, bool extendEnd);

CG_EXTERN CGShadingRef CG_NULLABLE CGShadingRetain(CGShadingRef CG_NULLABLE shading);
CG_EXTERN void CGShadingRelease(CGShadingRef CG_NULLABLE shading);

CG_ASSUME_NONNULL_END
CG_EXTERN_C_END

#endif /* SILICA_CGSHADING_H */
