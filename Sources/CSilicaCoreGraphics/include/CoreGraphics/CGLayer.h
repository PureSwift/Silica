/*
 * CGLayer.h
 * Silica's CoreGraphics: layers, drawn once and composited often.
 *
 * Copyright © 2026 PureSwift. All rights reserved.
 */

#ifndef SILICA_CGLAYER_H
#define SILICA_CGLAYER_H

#include "CGBase.h"
#include "CGGeometry.h"
#include "CGContext.h"

CG_EXTERN_C_BEGIN
CG_ASSUME_NONNULL_BEGIN

#if defined(__swift__)
#define CGLayerRef SilicaCGLayerRef
#endif

typedef struct CGLayer *CGLayerRef;

CG_EXTERN CFTypeID CGLayerGetTypeID(void);

/* A layer `size` across, a pixel a unit, in RGB with alpha; transparent to
 * start. `auxiliaryInfo` is a CFDictionaryRef, unused. */
CG_EXTERN CGLayerRef CG_NULLABLE CGLayerCreateWithContext(CGContextRef CG_NULLABLE context, CGSize size,
                                                          const void * CG_NULLABLE auxiliaryInfo);

CG_EXTERN CGLayerRef CG_NULLABLE CGLayerRetain(CGLayerRef CG_NULLABLE layer);
CG_EXTERN void CGLayerRelease(CGLayerRef CG_NULLABLE layer);

CG_EXTERN CGSize CGLayerGetSize(CGLayerRef CG_NULLABLE layer);
/* The context drawing into the layer, y up from its bottom left; the layer
 * keeps it. */
CG_EXTERN CGContextRef CG_NULLABLE CGLayerGetContext(CGLayerRef CG_NULLABLE layer);

/* The layer drawn scaled to fill a rectangle, or its own size from a point. */
CG_EXTERN void CGContextDrawLayerInRect(CGContextRef CG_NULLABLE context, CGRect rect, CGLayerRef CG_NULLABLE layer);
CG_EXTERN void CGContextDrawLayerAtPoint(CGContextRef CG_NULLABLE context, CGPoint point, CGLayerRef CG_NULLABLE layer);

CG_ASSUME_NONNULL_END
CG_EXTERN_C_END

#endif /* SILICA_CGLAYER_H */
