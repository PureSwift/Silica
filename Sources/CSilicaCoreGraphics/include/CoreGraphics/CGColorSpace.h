/*
 * CGColorSpace.h
 * Silica's CoreGraphics: color spaces.
 *
 * Copyright © 2026 PureSwift. All rights reserved.
 */

#ifndef SILICA_CGCOLORSPACE_H
#define SILICA_CGCOLORSPACE_H

#include "CGBase.h"

CG_EXTERN_C_BEGIN
CG_ASSUME_NONNULL_BEGIN

#if defined(__swift__)
#define CGColorSpaceRef SilicaCGColorSpaceRef
#endif

typedef struct CGColorSpace *CGColorSpaceRef;

typedef int32_t CGColorSpaceModel;
enum {
    kCGColorSpaceModelUnknown = -1,
    kCGColorSpaceModelMonochrome = 0,
    kCGColorSpaceModelRGB = 1,
    kCGColorSpaceModelCMYK = 2,
    kCGColorSpaceModelLab = 3,
    kCGColorSpaceModelDeviceN = 4,
    kCGColorSpaceModelIndexed = 5,
    kCGColorSpaceModelPattern = 6,
    kCGColorSpaceModelXYZ = 7
};

typedef int32_t CGColorRenderingIntent;
enum {
    kCGRenderingIntentDefault = 0,
    kCGRenderingIntentAbsoluteColorimetric = 1,
    kCGRenderingIntentRelativeColorimetric = 2,
    kCGRenderingIntentPerceptual = 3,
    kCGRenderingIntentSaturation = 4
};

CG_EXTERN CFTypeID CGColorSpaceGetTypeID(void);

/* Silica draws in sRGB: the device spaces are sRGB and its gray, and CMYK
 * converts to sRGB naively. */
CG_EXTERN CGColorSpaceRef CGColorSpaceCreateDeviceRGB(void);
CG_EXTERN CGColorSpaceRef CGColorSpaceCreateDeviceGray(void);
CG_EXTERN CGColorSpaceRef CGColorSpaceCreateDeviceCMYK(void);

CG_EXTERN CGColorSpaceRef CG_NULLABLE CGColorSpaceRetain(CGColorSpaceRef CG_NULLABLE space);
CG_EXTERN void CGColorSpaceRelease(CGColorSpaceRef CG_NULLABLE space);

CG_EXTERN CGColorSpaceModel CGColorSpaceGetModel(CGColorSpaceRef CG_NULLABLE space);
CG_EXTERN size_t CGColorSpaceGetNumberOfComponents(CGColorSpaceRef CG_NULLABLE space);

/* A space of patterns: colored with no base space, or uncolored, a stencil
 * painted in a color of the base space. */
CG_EXTERN CGColorSpaceRef CG_NULLABLE CGColorSpaceCreatePattern(CGColorSpaceRef CG_NULLABLE baseSpace);
/* A pattern space's base space, or NULL. */
CG_EXTERN CGColorSpaceRef CG_NULLABLE CGColorSpaceGetBaseColorSpace(CGColorSpaceRef CG_NULLABLE space);
CG_EXTERN CGColorSpaceRef CG_NULLABLE CGColorSpaceCopyBaseColorSpace(CGColorSpaceRef CG_NULLABLE space);

CG_ASSUME_NONNULL_END
CG_EXTERN_C_END

#endif /* SILICA_CGCOLORSPACE_H */
