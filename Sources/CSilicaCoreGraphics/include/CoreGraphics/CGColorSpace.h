/*
 * CGColorSpace.h
 * Silica's CoreGraphics: color spaces.
 *
 * Copyright © 2026 PureSwift. All rights reserved.
 */

#ifndef SILICA_CGCOLORSPACE_H
#define SILICA_CGCOLORSPACE_H

#include "CGBase.h"
#include "CGDataProvider.h"

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

/* Calibrated and ICC spaces draw as the device space of their model: Silica
 * has no color management. */
CG_EXTERN CGColorSpaceRef CG_NULLABLE CGColorSpaceCreateCalibratedGray(const CGFloat * CG_NULLABLE whitePoint,
                                                                       const CGFloat * CG_NULLABLE blackPoint, CGFloat gamma);
CG_EXTERN CGColorSpaceRef CG_NULLABLE CGColorSpaceCreateCalibratedRGB(const CGFloat * CG_NULLABLE whitePoint,
                                                                      const CGFloat * CG_NULLABLE blackPoint,
                                                                      const CGFloat * CG_NULLABLE gamma, const CGFloat * CG_NULLABLE matrix);
/* An ICC profile of 1, 3 or 4 components, or else the alternate space. */
CG_EXTERN CGColorSpaceRef CG_NULLABLE CGColorSpaceCreateICCBased(size_t nComponents, const CGFloat * CG_NULLABLE range,
                                                                 CGDataProviderRef CG_NULLABLE profile,
                                                                 CGColorSpaceRef CG_NULLABLE alternate);
/* `data` is a CFDataRef, where Core Foundation is bridged: its profile's
 * gray, RGB or CMYK space. */
CG_EXTERN CGColorSpaceRef CG_NULLABLE CGColorSpaceCreateWithICCData(const void * CG_NULLABLE data);
/* The profile an ICC space was made with, where Core Foundation is bridged. */
CG_EXTERN CFDataRef CG_NULLABLE CGColorSpaceCopyICCData(CGColorSpaceRef CG_NULLABLE space);
/* A named space's linear or extended range form (kCGColorSpaceSRGB's are
 * kCGColorSpaceLinearSRGB and kCGColorSpaceExtendedSRGB); NULL for other
 * spaces, as on Darwin. They draw as their model's device space. */
CG_EXTERN CGColorSpaceRef CG_NULLABLE CGColorSpaceCreateLinearized(CGColorSpaceRef CG_NULLABLE space);
CG_EXTERN CGColorSpaceRef CG_NULLABLE CGColorSpaceCreateExtended(CGColorSpaceRef CG_NULLABLE space);

/* A space of `lastIndex + 1` colors of the base space, a byte a component in
 * the table. */
CG_EXTERN CGColorSpaceRef CG_NULLABLE CGColorSpaceCreateIndexed(CGColorSpaceRef CG_NULLABLE baseSpace, size_t lastIndex,
                                                                const unsigned char * CG_NULLABLE colorTable);
/* Spaces by name. A name is a CFStringRef, read by its string where Core
 * Foundation is bridged: Silica knows Darwin's names (kCGColorSpaceSRGB,
 * kCGColorSpaceDisplayP3, kCGColorSpaceGenericGrayGamma2_2, …), and draws
 * each space as the device space of its model. The device spaces are named
 * too (kCGColorSpaceDeviceRGB). The name a space gets is the runtime's
 * constant, where it has one; the space keeps it. */
CG_EXTERN CGColorSpaceRef CG_NULLABLE CGColorSpaceCreateWithName(CFStringRef CG_NULLABLE name);
CG_EXTERN CFStringRef CG_NULLABLE CGColorSpaceGetName(CGColorSpaceRef CG_NULLABLE space);
CG_EXTERN CFStringRef CG_NULLABLE CGColorSpaceCopyName(CGColorSpaceRef CG_NULLABLE space);
/* A CFPropertyListRef describing a space: its ICC profile as data if it was
 * made from one, else its name, or for a device space the name of the space
 * it is (kCGColorSpaceSRGB for kCGColorSpaceDeviceRGB). NULL for others. */
CG_EXTERN const void * CG_NULLABLE CGColorSpaceCopyPropertyList(CGColorSpaceRef CG_NULLABLE space);
CG_EXTERN CGColorSpaceRef CG_NULLABLE CGColorSpaceCreateWithPropertyList(const void * CG_NULLABLE plist);

CG_EXTERN size_t CGColorSpaceGetColorTableCount(CGColorSpaceRef CG_NULLABLE space);
CG_EXTERN void CGColorSpaceGetColorTable(CGColorSpaceRef CG_NULLABLE space, uint8_t * CG_NULLABLE table);

CG_ASSUME_NONNULL_END
CG_EXTERN_C_END

#endif /* SILICA_CGCOLORSPACE_H */
