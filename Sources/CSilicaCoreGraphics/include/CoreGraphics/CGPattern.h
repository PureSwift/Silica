/*
 * CGPattern.h
 * Silica's CoreGraphics: patterns.
 *
 * Copyright © 2026 PureSwift. All rights reserved.
 */

#ifndef SILICA_CGPATTERN_H
#define SILICA_CGPATTERN_H

#include "CGBase.h"
#include "CGGeometry.h"
#include "CGAffineTransform.h"

CG_EXTERN_C_BEGIN
CG_ASSUME_NONNULL_BEGIN

#if defined(__swift__)
#define CGPatternRef SilicaCGPatternRef
#define CGContextRef SilicaCGContextRef
#endif

typedef struct CGPattern *CGPatternRef;

/* A pattern draws its cell into a context: declared here as CGContext.h does. */
typedef struct CGContext *CGContextRef;

typedef int32_t CGPatternTiling;
enum {
    kCGPatternTilingNoDistortion = 0,
    kCGPatternTilingConstantSpacingMinimalDistortion = 1,
    kCGPatternTilingConstantSpacing = 2
};

typedef void (*CGPatternDrawPatternCallback)(void * CG_NULLABLE info, CGContextRef CG_NULLABLE context);
typedef void (*CGPatternReleaseInfoCallback)(void * CG_NULLABLE info);

struct CGPatternCallbacks {
    unsigned int version;
    CGPatternDrawPatternCallback CG_NULLABLE drawPattern;
    CGPatternReleaseInfoCallback CG_NULLABLE releaseInfo;
};
typedef struct CGPatternCallbacks CGPatternCallbacks;

CG_EXTERN CFTypeID CGPatternGetTypeID(void);

/* A pattern of a cell `bounds` in pattern space, drawn by `drawPattern` and
 * repeated every `xStep` and `yStep`. `matrix` maps pattern space into the
 * default user space of the context it paints. Silica draws the cell once,
 * at the device's resolution, and repeats it: every tiling is drawn as
 * kCGPatternTilingConstantSpacing. An uncolored pattern is a stencil: its
 * cell draws in the color it's set with, unless it sets its own, as Apple's
 * do. */
CG_EXTERN CGPatternRef CG_NULLABLE CGPatternCreate(void * CG_NULLABLE info, CGRect bounds, CGAffineTransform matrix,
                                                   CGFloat xStep, CGFloat yStep, CGPatternTiling tiling, bool isColored,
                                                   const CGPatternCallbacks * CG_NULLABLE callbacks);

CG_EXTERN CGPatternRef CG_NULLABLE CGPatternRetain(CGPatternRef CG_NULLABLE pattern);
CG_EXTERN void CGPatternRelease(CGPatternRef CG_NULLABLE pattern);

CG_ASSUME_NONNULL_END
CG_EXTERN_C_END

#endif /* SILICA_CGPATTERN_H */
