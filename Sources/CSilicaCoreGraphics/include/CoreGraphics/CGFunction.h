/*
 * CGFunction.h
 * Silica's CoreGraphics: functions, which shadings sample.
 *
 * Copyright © 2026 PureSwift. All rights reserved.
 */

#ifndef SILICA_CGFUNCTION_H
#define SILICA_CGFUNCTION_H

#include "CGBase.h"

CG_EXTERN_C_BEGIN
CG_ASSUME_NONNULL_BEGIN

#if defined(__swift__)
#define CGFunctionRef SilicaCGFunctionRef
#endif

typedef struct CGFunction *CGFunctionRef;

typedef void (*CGFunctionEvaluateCallback)(void * CG_NULLABLE info, const CGFloat *in, CGFloat *out);
typedef void (*CGFunctionReleaseInfoCallback)(void * CG_NULLABLE info);

struct CGFunctionCallbacks {
    unsigned int version;
    CGFunctionEvaluateCallback CG_NULLABLE evaluate;
    CGFunctionReleaseInfoCallback CG_NULLABLE releaseInfo;
};
typedef struct CGFunctionCallbacks CGFunctionCallbacks;

CG_EXTERN CFTypeID CGFunctionGetTypeID(void);

/* A function of `domainDimension` inputs, each within its pair of `domain`,
 * to `rangeDimension` outputs, each clipped to its pair of `range` (or not
 * at all for NULL). */
CG_EXTERN CGFunctionRef CG_NULLABLE CGFunctionCreate(void * CG_NULLABLE info, size_t domainDimension,
                                                     const CGFloat * CG_NULLABLE domain, size_t rangeDimension,
                                                     const CGFloat * CG_NULLABLE range,
                                                     const CGFunctionCallbacks * CG_NULLABLE callbacks);

CG_EXTERN CGFunctionRef CG_NULLABLE CGFunctionRetain(CGFunctionRef CG_NULLABLE function);
CG_EXTERN void CGFunctionRelease(CGFunctionRef CG_NULLABLE function);

CG_ASSUME_NONNULL_END
CG_EXTERN_C_END

#endif /* SILICA_CGFUNCTION_H */
