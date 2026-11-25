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
#include "CGDataProvider.h"

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

/* An image of the provider's pixels, rows from the top. Silica reads 8 bits
 * a component: RGB with alpha first or last (premultiplied, straight or
 * skipped, in either byte order), RGB of 3 bytes, gray with or without
 * alpha, and alpha alone. `decode` isn't applied. */
CG_EXTERN CGImageRef CG_NULLABLE CGImageCreate(size_t width, size_t height, size_t bitsPerComponent, size_t bitsPerPixel,
                                               size_t bytesPerRow, CGColorSpaceRef CG_NULLABLE space, CGBitmapInfo bitmapInfo,
                                               CGDataProviderRef CG_NULLABLE provider, const CGFloat * CG_NULLABLE decode,
                                               bool shouldInterpolate, CGColorRenderingIntent intent);
typedef uint32_t CGImagePixelFormatInfo;
enum {
    kCGImagePixelFormatMask = 0xF0000,
    kCGImagePixelFormatPacked = (0 << 16),
    kCGImagePixelFormatRGB555 = (1 << 16),
    kCGImagePixelFormatRGB565 = (2 << 16),
    kCGImagePixelFormatRGB101010 = (3 << 16),
    kCGImagePixelFormatRGBCIF10 = (4 << 16)
};

CG_EXTERN CGImageRef CG_NULLABLE CGImageCreateCopy(CGImageRef CG_NULLABLE image);
/* The image in a space of as many components. */
CG_EXTERN CGImageRef CG_NULLABLE CGImageCreateCopyWithColorSpace(CGImageRef CG_NULLABLE image, CGColorSpaceRef CG_NULLABLE space);
/* The image, transparent where every component is within its pair of
 * `components`, in sample values: an image without alpha. */
CG_EXTERN CGImageRef CG_NULLABLE CGImageCreateWithMaskingColors(CGImageRef CG_NULLABLE image, const CGFloat * CG_NULLABLE components);
/* A PNG's image, decoded by Cairo: RGBA, or RGB with a skipped byte. */
CG_EXTERN CGImageRef CG_NULLABLE CGImageCreateWithPNGDataProvider(CGDataProviderRef CG_NULLABLE source, const CGFloat * CG_NULLABLE decode,
                                                                  bool shouldInterpolate, CGColorRenderingIntent intent);
/* A mask of 1, 2, 4 or 8 bits a sample, rows from the top: where a sample is
 * 0 (after `decode`) it paints, where it's 1 it doesn't. */
CG_EXTERN CGImageRef CG_NULLABLE CGImageMaskCreate(size_t width, size_t height, size_t bitsPerComponent, size_t bitsPerPixel,
                                                   size_t bytesPerRow, CGDataProviderRef CG_NULLABLE provider,
                                                   const CGFloat * CG_NULLABLE decode, bool shouldInterpolate);
/* The image masked: by an image mask, or by a gray image whose samples are
 * the alpha. The mask is scaled to the image. */
CG_EXTERN CGImageRef CG_NULLABLE CGImageCreateWithMask(CGImageRef CG_NULLABLE image, CGImageRef CG_NULLABLE mask);
/* The part of the image in `rect`, in pixels from its top left, rounded out
 * to whole pixels; NULL when it's outside the image. Silica doesn't crop
 * image masks or masked images: NULL. */
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
/* Silica's pixels are always packed. */
CG_EXTERN CGImagePixelFormatInfo CGImageGetPixelFormatInfo(CGImageRef CG_NULLABLE image);
/* The type of the file an image was read from, a CFStringRef: NULL, as
 * Silica reads none with ImageIO. */
CG_EXTERN CFStringRef CG_NULLABLE CGImageGetUTType(CGImageRef CG_NULLABLE image);
/* The decode array the image was made with, two values a component, or NULL. */
CG_EXTERN const CGFloat * CG_NULLABLE CGImageGetDecode(CGImageRef CG_NULLABLE image);
/* A provider of the image's pixels. */
CG_EXTERN CGDataProviderRef CG_NULLABLE CGImageGetDataProvider(CGImageRef CG_NULLABLE image);

CG_ASSUME_NONNULL_END
CG_EXTERN_C_END

#endif /* SILICA_CGIMAGE_H */
