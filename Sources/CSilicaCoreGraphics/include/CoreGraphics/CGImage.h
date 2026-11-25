/*
 * CGImage.h
 * Silica's CoreGraphics: images.
 *
 * Copyright © 2026 PureSwift. All rights reserved.
 */

#ifndef SILICA_CGIMAGE_H
#define SILICA_CGIMAGE_H

#include "CGBase.h"
#include "CGColorSpace.h"
#include "CGGeometry.h"

CG_EXTERN_C_BEGIN
CG_ASSUME_NONNULL_BEGIN

#if defined(__swift__)
#define CGImageRef SilicaCGImageRef
#endif

typedef struct CGImage *CGImageRef;

typedef uint32_t CGImageAlphaInfo;
enum {
    kCGImageAlphaNone = 0,
    kCGImageAlphaPremultipliedLast = 1,
    kCGImageAlphaPremultipliedFirst = 2,
    kCGImageAlphaLast = 3,
    kCGImageAlphaFirst = 4,
    kCGImageAlphaNoneSkipLast = 5,
    kCGImageAlphaNoneSkipFirst = 6,
    kCGImageAlphaOnly = 7
};

typedef uint32_t CGImageByteOrderInfo;
enum {
    kCGImageByteOrderMask = 0x7000,
    kCGImageByteOrderDefault = (0 << 12),
    kCGImageByteOrder16Little = (1 << 12),
    kCGImageByteOrder32Little = (2 << 12),
    kCGImageByteOrder16Big = (3 << 12),
    kCGImageByteOrder32Big = (4 << 12)
};

typedef uint32_t CGBitmapInfo;
enum {
    kCGBitmapAlphaInfoMask = 0x1F,
    kCGBitmapFloatInfoMask = 0xF00,
    kCGBitmapFloatComponents = (1 << 8),
    kCGBitmapByteOrderMask = kCGImageByteOrderMask,
    kCGBitmapByteOrderDefault = kCGImageByteOrderDefault,
    kCGBitmapByteOrder16Little = kCGImageByteOrder16Little,
    kCGBitmapByteOrder32Little = kCGImageByteOrder32Little,
    kCGBitmapByteOrder16Big = kCGImageByteOrder16Big,
    kCGBitmapByteOrder32Big = kCGImageByteOrder32Big
};

#if defined(__BIG_ENDIAN__) || (defined(__BYTE_ORDER__) && __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__)
#define kCGBitmapByteOrder16Host kCGBitmapByteOrder16Big
#define kCGBitmapByteOrder32Host kCGBitmapByteOrder32Big
#else
#define kCGBitmapByteOrder16Host kCGBitmapByteOrder16Little
#define kCGBitmapByteOrder32Host kCGBitmapByteOrder32Little
#endif

CG_EXTERN CFTypeID CGImageGetTypeID(void);

CG_EXTERN CGImageRef CG_NULLABLE CGImageRetain(CGImageRef CG_NULLABLE image);
CG_EXTERN void CGImageRelease(CGImageRef CG_NULLABLE image);

CG_EXTERN CGImageRef CG_NULLABLE CGImageCreateCopy(CGImageRef CG_NULLABLE image);
/* The part of the image in `rect`, in pixels from its top left, rounded out
 * to whole pixels; NULL when it's outside the image. */
CG_EXTERN CGImageRef CG_NULLABLE CGImageCreateWithImageInRect(CGImageRef CG_NULLABLE image, CGRect rect);

CG_EXTERN size_t CGImageGetWidth(CGImageRef CG_NULLABLE image);
CG_EXTERN size_t CGImageGetHeight(CGImageRef CG_NULLABLE image);
CG_EXTERN size_t CGImageGetBitsPerComponent(CGImageRef CG_NULLABLE image);
CG_EXTERN size_t CGImageGetBitsPerPixel(CGImageRef CG_NULLABLE image);
CG_EXTERN size_t CGImageGetBytesPerRow(CGImageRef CG_NULLABLE image);
CG_EXTERN CGColorSpaceRef CG_NULLABLE CGImageGetColorSpace(CGImageRef CG_NULLABLE image);
CG_EXTERN CGImageAlphaInfo CGImageGetAlphaInfo(CGImageRef CG_NULLABLE image);
CG_EXTERN CGBitmapInfo CGImageGetBitmapInfo(CGImageRef CG_NULLABLE image);
CG_EXTERN CGImageByteOrderInfo CGImageGetByteOrderInfo(CGImageRef CG_NULLABLE image);
CG_EXTERN bool CGImageGetShouldInterpolate(CGImageRef CG_NULLABLE image);
CG_EXTERN CGColorRenderingIntent CGImageGetRenderingIntent(CGImageRef CG_NULLABLE image);
CG_EXTERN bool CGImageIsMask(CGImageRef CG_NULLABLE image);

CG_ASSUME_NONNULL_END
CG_EXTERN_C_END

#endif /* SILICA_CGIMAGE_H */
