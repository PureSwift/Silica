/*
 * CGBitmapContext.h
 * Silica's CoreGraphics: bitmap contexts.
 *
 * Copyright © 2026 PureSwift. All rights reserved.
 */

#ifndef SILICA_CGBITMAPCONTEXT_H
#define SILICA_CGBITMAPCONTEXT_H

#include "CGBase.h"
#include "CGContext.h"

CG_EXTERN_C_BEGIN
CG_ASSUME_NONNULL_BEGIN

typedef void (*CGBitmapContextReleaseDataCallback)(void * CG_NULLABLE releaseInfo, void * CG_NULLABLE data);

/* A context drawing into `data`, or into memory of its own when it's NULL.
 * The formats: 8 bits a component; RGB with premultiplied or skipped alpha,
 * first or last, in either byte order; gray without alpha; and alpha alone.
 * With `bytesPerRow` 0, rows are as long as the width needs. */
CG_EXTERN CGContextRef CG_NULLABLE CGBitmapContextCreate(void * CG_NULLABLE data, size_t width, size_t height,
                                                         size_t bitsPerComponent, size_t bytesPerRow,
                                                         CGColorSpaceRef CG_NULLABLE space, uint32_t bitmapInfo);
/* The same, calling `releaseCallback` with `data` when the context goes. */
CG_EXTERN CGContextRef CG_NULLABLE CGBitmapContextCreateWithData(void * CG_NULLABLE data, size_t width, size_t height,
                                                                 size_t bitsPerComponent, size_t bytesPerRow,
                                                                 CGColorSpaceRef CG_NULLABLE space, uint32_t bitmapInfo,
                                                                 CGBitmapContextReleaseDataCallback CG_NULLABLE releaseCallback,
                                                                 void * CG_NULLABLE releaseInfo);

CG_EXTERN void * CG_NULLABLE CGBitmapContextGetData(CGContextRef CG_NULLABLE context);
CG_EXTERN size_t CGBitmapContextGetWidth(CGContextRef CG_NULLABLE context);
CG_EXTERN size_t CGBitmapContextGetHeight(CGContextRef CG_NULLABLE context);
CG_EXTERN size_t CGBitmapContextGetBitsPerComponent(CGContextRef CG_NULLABLE context);
CG_EXTERN size_t CGBitmapContextGetBitsPerPixel(CGContextRef CG_NULLABLE context);
CG_EXTERN size_t CGBitmapContextGetBytesPerRow(CGContextRef CG_NULLABLE context);
CG_EXTERN CGColorSpaceRef CG_NULLABLE CGBitmapContextGetColorSpace(CGContextRef CG_NULLABLE context);
CG_EXTERN CGImageAlphaInfo CGBitmapContextGetAlphaInfo(CGContextRef CG_NULLABLE context);
CG_EXTERN CGBitmapInfo CGBitmapContextGetBitmapInfo(CGContextRef CG_NULLABLE context);
/* A copy of what's drawn, as an image of the context's format. */
CG_EXTERN CGImageRef CG_NULLABLE CGBitmapContextCreateImage(CGContextRef CG_NULLABLE context);

CG_ASSUME_NONNULL_END
CG_EXTERN_C_END

#endif /* SILICA_CGBITMAPCONTEXT_H */
