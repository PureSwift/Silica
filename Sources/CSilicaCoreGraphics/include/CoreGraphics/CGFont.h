/*
 * CGFont.h
 * Silica's CoreGraphics: fonts.
 *
 * Copyright © 2026 PureSwift. All rights reserved.
 */

#ifndef SILICA_CGFONT_H
#define SILICA_CGFONT_H

#include "CGBase.h"
#include "CGGeometry.h"
#include "CGDataProvider.h"

CG_EXTERN_C_BEGIN
CG_ASSUME_NONNULL_BEGIN

#if defined(__swift__)
#define CGFontRef SilicaCGFontRef
#endif

typedef struct CGFont *CGFontRef;
typedef unsigned short CGFontIndex;
typedef CGFontIndex CGGlyph;

enum {
    kCGFontIndexMax = ((1 << 16) - 2),
    kCGFontIndexInvalid = ((1 << 16) - 1),
    kCGGlyphMax = kCGFontIndexMax
};

CG_EXTERN CFTypeID CGFontGetTypeID(void);

/* A font from a font file's bytes (TrueType, OpenType). */
CG_EXTERN CGFontRef CG_NULLABLE CGFontCreateWithDataProvider(CGDataProviderRef CG_NULLABLE provider);
/* A font of the system's by PostScript or family name. */
CG_EXTERN CGFontRef CG_NULLABLE CGFontCreateWithFontName(CFStringRef CG_NULLABLE name);

CG_EXTERN CGFontRef CG_NULLABLE CGFontRetain(CGFontRef CG_NULLABLE font);
CG_EXTERN void CGFontRelease(CGFontRef CG_NULLABLE font);

CG_EXTERN CFStringRef CG_NULLABLE CGFontCopyPostScriptName(CGFontRef CG_NULLABLE font);
CG_EXTERN CFStringRef CG_NULLABLE CGFontCopyFullName(CGFontRef CG_NULLABLE font);

/* Metrics in font units. */
CG_EXTERN int CGFontGetUnitsPerEm(CGFontRef CG_NULLABLE font);
CG_EXTERN size_t CGFontGetNumberOfGlyphs(CGFontRef CG_NULLABLE font);
CG_EXTERN int CGFontGetAscent(CGFontRef CG_NULLABLE font);
CG_EXTERN int CGFontGetDescent(CGFontRef CG_NULLABLE font);
CG_EXTERN int CGFontGetLeading(CGFontRef CG_NULLABLE font);
CG_EXTERN int CGFontGetCapHeight(CGFontRef CG_NULLABLE font);
CG_EXTERN int CGFontGetXHeight(CGFontRef CG_NULLABLE font);
CG_EXTERN CGRect CGFontGetFontBBox(CGFontRef CG_NULLABLE font);
CG_EXTERN CGFloat CGFontGetItalicAngle(CGFontRef CG_NULLABLE font);
CG_EXTERN CGFloat CGFontGetStemV(CGFontRef CG_NULLABLE font);
CG_EXTERN bool CGFontGetGlyphBBoxes(CGFontRef CG_NULLABLE font, const CGGlyph * CG_NULLABLE glyphs, size_t count, CGRect * CG_NULLABLE bboxes);
CG_EXTERN bool CGFontGetGlyphAdvances(CGFontRef CG_NULLABLE font, const CGGlyph * CG_NULLABLE glyphs, size_t count, int * CG_NULLABLE advances);

CG_EXTERN CGGlyph CGFontGetGlyphWithGlyphName(CGFontRef CG_NULLABLE font, CFStringRef CG_NULLABLE name);
CG_EXTERN CFStringRef CG_NULLABLE CGFontCopyGlyphNameForGlyph(CGFontRef CG_NULLABLE font, CGGlyph glyph);
CG_EXTERN CFDataRef CG_NULLABLE CGFontCopyTableForTag(CGFontRef CG_NULLABLE font, uint32_t tag);

CG_ASSUME_NONNULL_END
CG_EXTERN_C_END

#endif /* SILICA_CGFONT_H */
