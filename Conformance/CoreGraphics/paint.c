/*
 * paint.c
 * Conformance of CGLayer.h, CGPattern.h, CGFunction.h, CGShading.h and the
 * masks of CGImage.h and CGContext.h: what layers, patterns, tiled images,
 * shadings and masks paint. Opaque pixels print exactly; blended ones,
 * rounded to steps of 16, past the implementations' differences in rounding.
 */

#include "conformance.h"
#include <stdlib.h>
#include <string.h>

static CGColorSpaceRef rgb;
static CGColorSpaceRef gray;

/* A context of RGBA bytes, premultiplied, transparent to start. */
static CGContextRef makeContext(size_t width, size_t height) {
    return CGBitmapContextCreate(NULL, width, height, 8, 0, rgb, kCGImageAlphaPremultipliedLast);
}

static void printPixel(const char *label, CGContextRef c, int x, int y, int quantum) {
    unsigned char *data = CGBitmapContextGetData(c);
    size_t bytesPerRow = CGBitmapContextGetBytesPerRow(c);
    size_t bytesPerPixel = CGBitmapContextGetBitsPerPixel(c) / 8;
    /* memory rows are from the top: y up from the bottom is row height - 1 - y */
    size_t row = CGBitmapContextGetHeight(c) - 1 - (size_t)y;
    unsigned char *pixel = data + row * bytesPerRow + (size_t)x * bytesPerPixel;
    printf("%s:", label);
    for (size_t i = 0; i < bytesPerPixel; i++) {
        int value = pixel[i];
        if (quantum > 1) value = (value + quantum / 2) / quantum * quantum;
        printf(" %d", value);
    }
    printf("\n");
}

static void releaseBytes(void *info, const void *data, size_t size) {
    (void)info; (void)size;
    free((void *)data);
}

/* A provider of a copy of the bytes. */
static CGDataProviderRef makeProvider(const unsigned char *bytes, size_t count) {
    unsigned char *copy = malloc(count);
    memcpy(copy, bytes, count);
    return CGDataProviderCreateWithData(NULL, copy, count, releaseBytes);
}

/* An RGBA image, premultiplied, rows from the top. */
static CGImageRef makeImage(const unsigned char *pixels, size_t width, size_t height) {
    CGDataProviderRef provider = makeProvider(pixels, width * height * 4);
    CGImageRef image = CGImageCreate(width, height, 8, 32, width * 4, rgb, kCGImageAlphaPremultipliedLast, provider, NULL,
                                     false, kCGRenderingIntentDefault);
    CGDataProviderRelease(provider);
    return image;
}

/* A gray image of a byte a pixel, rows from the top. */
static CGImageRef makeGrayImage(const unsigned char *pixels, size_t width, size_t height) {
    CGDataProviderRef provider = makeProvider(pixels, width * height);
    CGImageRef image = CGImageCreate(width, height, 8, 8, width, gray, kCGImageAlphaNone, provider, NULL,
                                     false, kCGRenderingIntentDefault);
    CGDataProviderRelease(provider);
    return image;
}

static CGImageRef makeMask(const unsigned char *samples, size_t width, size_t height, size_t bits, size_t bytesPerRow,
                           const CGFloat *decode) {
    CGDataProviderRef provider = makeProvider(samples, bytesPerRow * height);
    CGImageRef mask = CGImageMaskCreate(width, height, bits, bits, bytesPerRow, provider, decode, false);
    CGDataProviderRelease(provider);
    return mask;
}

static void printImage(const char *label, CGImageRef image) {
    if (image == NULL) { printf("%s: NULL\n", label); return; }
    const CGFloat *decode = CGImageGetDecode(image);
    printf("%s: %zux%zu bpc %zu bpp %zu bytesPerRow %zu mask %s space %s decode", label,
           CGImageGetWidth(image), CGImageGetHeight(image), CGImageGetBitsPerComponent(image),
           CGImageGetBitsPerPixel(image), CGImageGetBytesPerRow(image), CGImageIsMask(image) ? "yes" : "no",
           CGImageGetColorSpace(image) ? "yes" : "NULL");
    if (decode) { printf(" "); printNumber(decode[0]); printf(" "); printNumber(decode[1]); }
    else printf(" NULL");
    printf("\n");
}

/* MARK: Layers */

static void layers(void) {
    printf("-- layers\n");
    CGContextRef c = makeContext(40, 40);
    CGLayerRef layer = CGLayerCreateWithContext(c, CGSizeMake(10, 10), NULL);
    printSize("layer size", CGLayerGetSize(layer));
    CGContextRef inside = CGLayerGetContext(layer);
    printBool("layer has a context", inside != NULL);
    printTransform("layer ctm", CGContextGetCTM(inside));
    printRect("layer clip", CGContextGetClipBoundingBox(inside));
    printBool("layer context is the same", CGLayerGetContext(layer) == inside);

    /* red on the left, blue on the right, a green band along the bottom */
    CGContextSetRGBFillColor(inside, 1, 0, 0, 1);
    CGContextFillRect(inside, CGRectMake(0, 0, 5, 10));
    CGContextSetRGBFillColor(inside, 0, 0, 1, 1);
    CGContextFillRect(inside, CGRectMake(5, 0, 5, 10));
    CGContextSetRGBFillColor(inside, 0, 1, 0, 1);
    CGContextFillRect(inside, CGRectMake(0, 0, 10, 2));

    CGContextDrawLayerAtPoint(c, CGPointMake(10, 10), layer);
    printPixel("at point left", c, 12, 15, 1);
    printPixel("at point right", c, 17, 15, 1);
    printPixel("at point bottom", c, 15, 10, 1);
    printPixel("at point outside", c, 25, 25, 1);

    CGContextDrawLayerInRect(c, CGRectMake(20, 20, 20, 20), layer);
    printPixel("in rect left", c, 25, 30, 1);
    printPixel("in rect right", c, 35, 30, 1);
    printPixel("in rect bottom", c, 30, 21, 1);

    /* with the context's alpha */
    CGContextRef faded = makeContext(10, 10);
    CGContextSetAlpha(faded, 0.5);
    CGContextDrawLayerAtPoint(faded, CGPointZero, layer);
    printPixel("with alpha", faded, 2, 5, 16);
    CGContextRelease(faded);

    printBool("empty layer", CGLayerCreateWithContext(c, CGSizeMake(0, 10), NULL) == NULL);
    CGLayerRelease(layer);
    CGContextRelease(c);
}

/* MARK: Shadings */

/* red to blue across the input, opaque */
static void redToBlue(void *info, const CGFloat *in, CGFloat *out) {
    (void)info;
    out[0] = in[0];
    out[1] = 0;
    out[2] = 1 - in[0];
    out[3] = 1;
}

/* gray from black to white, without alpha */
static void blackToWhite(void *info, const CGFloat *in, CGFloat *out) {
    (void)info;
    out[0] = in[0];
}

static int released;

static void releaseInfo(void *info) {
    (void)info;
    released++;
}

static void shadings(void) {
    printf("-- shadings\n");
    CGFloat domain[] = { 0, 1 };
    CGFloat range[] = { 0, 1, 0, 1, 0, 1, 0, 1 };
    CGFunctionCallbacks callbacks = { 0, redToBlue, releaseInfo };
    CGFunctionRef function = CGFunctionCreate(NULL, 1, domain, 4, range, &callbacks);
    printBool("function", function != NULL);
    printBool("function type", CGFunctionGetTypeID() != CGShadingGetTypeID());

    CGShadingRef axial = CGShadingCreateAxial(rgb, CGPointMake(16, 0), CGPointMake(48, 0), function, false, false);
    CGContextRef c = makeContext(64, 8);
    CGContextDrawShading(c, axial);
    printPixel("axial before start", c, 4, 4, 1);
    printPixel("axial start", c, 17, 4, 16);
    printPixel("axial middle", c, 32, 4, 16);
    printPixel("axial end", c, 46, 4, 16);
    printPixel("axial after end", c, 60, 4, 1);
    CGContextRelease(c);
    CGShadingRelease(axial);

    axial = CGShadingCreateAxial(rgb, CGPointMake(16, 0), CGPointMake(48, 0), function, true, true);
    c = makeContext(64, 8);
    CGContextDrawShading(c, axial);
    printPixel("extended before start", c, 4, 4, 1);
    printPixel("extended after end", c, 60, 4, 1);
    CGContextRelease(c);
    CGShadingRelease(axial);

    CGShadingRef radial = CGShadingCreateRadial(rgb, CGPointMake(32, 32), 0, CGPointMake(32, 32), 16, function, false, false);
    c = makeContext(64, 64);
    CGContextDrawShading(c, radial);
    printPixel("radial center", c, 32, 32, 16);
    printPixel("radial inside", c, 35, 35, 16);
    printPixel("radial outside", c, 60, 60, 1);
    CGContextRelease(c);
    CGShadingRelease(radial);

    /* within the clip and the transform */
    axial = CGShadingCreateAxial(rgb, CGPointMake(0, 0), CGPointMake(32, 0), function, true, true);
    c = makeContext(64, 8);
    CGContextClipToRect(c, CGRectMake(0, 0, 32, 8));
    CGContextScaleCTM(c, 0.5, 1);
    CGContextDrawShading(c, axial);
    printPixel("scaled middle", c, 8, 4, 16);
    printPixel("clipped", c, 40, 4, 1);
    CGContextRelease(c);
    CGShadingRelease(axial);

    /* a gray function without alpha is opaque */
    CGFunctionCallbacks grayCallbacks = { 0, blackToWhite, NULL };
    CGFunctionRef grayFunction = CGFunctionCreate(NULL, 1, domain, 1, NULL, &grayCallbacks);
    CGShadingRef grayShading = CGShadingCreateAxial(gray, CGPointMake(0, 0), CGPointMake(64, 0), grayFunction, false, false);
    c = makeContext(64, 8);
    CGContextDrawShading(c, grayShading);
    printPixel("gray middle", c, 32, 4, 16);
    CGContextRelease(c);
    CGShadingRelease(grayShading);
    CGFunctionRelease(grayFunction);

    CGFunctionRelease(function);
    printf("function info released: %d\n", released);
}

/* MARK: Patterns */

static int drawn;

/* red in the cell's lower left quarter */
static void drawCell(void *info, CGContextRef c) {
    (void)info;
    drawn++;
    CGContextSetRGBFillColor(c, 1, 0, 0, 1);
    CGContextFillRect(c, CGRectMake(0, 0, 4, 4));
}

/* a stencil, in the color it's set with */
static void drawStencil(void *info, CGContextRef c) {
    (void)info;
    CGContextFillRect(c, CGRectMake(0, 0, 4, 4));
}

/* a stencil that sets a color of its own */
static void drawRedStencil(void *info, CGContextRef c) {
    (void)info;
    CGContextSetRGBFillColor(c, 1, 0, 0, 1);
    CGContextFillRect(c, CGRectMake(0, 0, 4, 4));
}

/* a cell twice the step across: it spills into the next */
static void drawWide(void *info, CGContextRef c) {
    (void)info;
    CGContextSetRGBFillColor(c, 0, 0, 1, 1);
    CGContextFillRect(c, CGRectMake(6, 0, 4, 2));
}

static void patterns(void) {
    printf("-- patterns\n");
    CGPatternCallbacks callbacks = { 0, drawCell, releaseInfo };
    released = 0;
    CGPatternRef pattern = CGPatternCreate(NULL, CGRectMake(0, 0, 8, 8), CGAffineTransformIdentity, 8, 8,
                                           kCGPatternTilingConstantSpacing, true, &callbacks);
    printBool("pattern", pattern != NULL);

    CGColorSpaceRef colored = CGColorSpaceCreatePattern(NULL);
    printf("colored space: model %d components %zu base %s\n", (int)CGColorSpaceGetModel(colored),
           CGColorSpaceGetNumberOfComponents(colored), CGColorSpaceGetBaseColorSpace(colored) ? "yes" : "NULL");
    CGColorSpaceRef uncolored = CGColorSpaceCreatePattern(rgb);
    printf("uncolored space: model %d components %zu base model %d\n", (int)CGColorSpaceGetModel(uncolored),
           CGColorSpaceGetNumberOfComponents(uncolored), (int)CGColorSpaceGetModel(CGColorSpaceGetBaseColorSpace(uncolored)));

    CGContextRef c = makeContext(32, 32);
    CGFloat opaque[] = { 1 };
    CGContextSetFillColorSpace(c, colored);
    CGContextSetFillPattern(c, pattern, opaque);
    CGContextFillRect(c, CGRectMake(0, 0, 32, 32));
    printPixel("colored cell", c, 1, 1, 1);
    printPixel("colored outside cell", c, 5, 5, 1);
    printPixel("colored next across", c, 9, 1, 1);
    printPixel("colored next up", c, 1, 9, 1);
    printBool("cell drawn", drawn > 0);

    /* a stroke with a pattern */
    CGContextClearRect(c, CGRectMake(0, 0, 32, 32));
    CGContextSetStrokeColorSpace(c, colored);
    CGContextSetStrokePattern(c, pattern, opaque);
    CGContextSetLineWidth(c, 4);
    CGContextMoveToPoint(c, 0, 18);
    CGContextAddLineToPoint(c, 32, 18);
    CGContextStrokePath(c);
    printPixel("stroke in cell", c, 1, 18, 1);
    printPixel("stroke outside cell", c, 5, 18, 1);
    printPixel("outside stroke", c, 1, 25, 1);
    CGContextRelease(c);

    /* the pattern's matrix moves it in base space, whatever the transform */
    CGPatternRef moved = CGPatternCreate(NULL, CGRectMake(0, 0, 8, 8), CGAffineTransformMakeTranslation(2, 0), 8, 8,
                                         kCGPatternTilingConstantSpacing, true, &callbacks);
    c = makeContext(32, 32);
    CGContextTranslateCTM(c, 1, 0);
    CGContextSetFillColorSpace(c, colored);
    CGContextSetFillPattern(c, moved, opaque);
    CGContextFillRect(c, CGRectMake(-1, 0, 32, 32));
    printPixel("moved before", c, 1, 1, 1);
    printPixel("moved cell", c, 3, 1, 1);
    CGContextRelease(c);
    CGPatternRelease(moved);

    /* scaled patterns draw their cell larger */
    CGPatternRef scaled = CGPatternCreate(NULL, CGRectMake(0, 0, 8, 8), CGAffineTransformMakeScale(2, 2), 8, 8,
                                          kCGPatternTilingConstantSpacing, true, &callbacks);
    c = makeContext(32, 32);
    CGContextSetFillColorSpace(c, colored);
    CGContextSetFillPattern(c, scaled, opaque);
    CGContextFillRect(c, CGRectMake(0, 0, 32, 32));
    printPixel("scaled cell", c, 6, 6, 1);
    printPixel("scaled outside cell", c, 10, 6, 1);
    printPixel("scaled next", c, 17, 1, 1);
    CGContextRelease(c);
    CGPatternRelease(scaled);

    /* the phase moves patterns set after it */
    c = makeContext(32, 32);
    CGContextSetPatternPhase(c, CGSizeMake(0, 2));
    CGContextSetFillColorSpace(c, colored);
    CGContextSetFillPattern(c, pattern, opaque);
    CGContextFillRect(c, CGRectMake(0, 0, 32, 32));
    printPixel("phase below", c, 1, 1, 1);
    printPixel("phase cell", c, 1, 3, 1);
    CGContextRelease(c);

    /* a cell that spills past its step */
    CGPatternCallbacks wideCallbacks = { 0, drawWide, NULL };
    CGPatternRef wide = CGPatternCreate(NULL, CGRectMake(0, 0, 16, 8), CGAffineTransformIdentity, 8, 8,
                                        kCGPatternTilingConstantSpacing, true, &wideCallbacks);
    c = makeContext(32, 32);
    CGContextSetFillColorSpace(c, colored);
    CGContextSetFillPattern(c, wide, opaque);
    CGContextFillRect(c, CGRectMake(0, 0, 32, 32));
    printPixel("wide in cell", c, 7, 1, 1);
    printPixel("wide spilled", c, 9, 1, 1);
    printPixel("wide outside", c, 4, 1, 1);
    CGContextRelease(c);
    CGPatternRelease(wide);

    /* a stencil, painted in the color it's set with */
    CGPatternCallbacks stencilCallbacks = { 0, drawStencil, NULL };
    CGPatternRef stencil = CGPatternCreate(NULL, CGRectMake(0, 0, 8, 8), CGAffineTransformIdentity, 8, 8,
                                           kCGPatternTilingConstantSpacing, false, &stencilCallbacks);
    c = makeContext(32, 32);
    CGFloat green[] = { 0, 1, 0, 1 };
    CGContextSetFillColorSpace(c, uncolored);
    CGContextSetFillPattern(c, stencil, green);
    CGContextFillRect(c, CGRectMake(0, 0, 32, 32));
    printPixel("stencil cell", c, 1, 1, 1);
    printPixel("stencil outside cell", c, 5, 5, 1);
    CGContextRelease(c);

    /* a stencil that sets its own color */
    CGPatternCallbacks redCallbacks = { 0, drawRedStencil, NULL };
    CGPatternRef redStencil = CGPatternCreate(NULL, CGRectMake(0, 0, 8, 8), CGAffineTransformIdentity, 8, 8,
                                              kCGPatternTilingConstantSpacing, false, &redCallbacks);
    c = makeContext(32, 32);
    CGContextSetFillColorSpace(c, uncolored);
    CGContextSetFillPattern(c, redStencil, green);
    CGContextFillRect(c, CGRectMake(0, 0, 32, 32));
    printPixel("red stencil cell", c, 1, 1, 1);
    CGContextRelease(c);
    CGPatternRelease(redStencil);

    /* a pattern as a color, half transparent */
    CGFloat half[] = { 0, 0, 1, 0.5 };
    CGColorRef color = CGColorCreateWithPattern(uncolored, stencil, half);
    printf("pattern color: components %zu alpha ", CGColorGetNumberOfComponents(color));
    printNumber(CGColorGetAlpha(color));
    printf(" pattern %s\n", CGColorGetPattern(color) == stencil ? "same" : "other");
    c = makeContext(32, 32);
    CGContextSetFillColorWithColor(c, color);
    CGContextFillRect(c, CGRectMake(0, 0, 32, 32));
    printPixel("pattern color cell", c, 1, 1, 16);
    printPixel("pattern color outside cell", c, 5, 5, 1);
    /* a color set after it paints in its place */
    CGContextSetRGBFillColor(c, 1, 1, 1, 1);
    CGContextFillRect(c, CGRectMake(0, 0, 32, 32));
    printPixel("color after pattern", c, 5, 5, 1);
    CGContextRelease(c);
    CGColorRelease(color);

    /* the context's alpha applies to a pattern */
    c = makeContext(32, 32);
    CGContextSetAlpha(c, 0.5);
    CGContextSetFillColorSpace(c, colored);
    CGContextSetFillPattern(c, pattern, opaque);
    CGContextFillRect(c, CGRectMake(0, 0, 32, 32));
    printPixel("pattern with alpha", c, 1, 1, 16);
    CGContextRelease(c);

    /* restoring the state restores the color the pattern replaced */
    c = makeContext(32, 32);
    CGContextSetRGBFillColor(c, 0, 0, 1, 1);
    CGContextSaveGState(c);
    CGContextSetFillColorSpace(c, colored);
    CGContextSetFillPattern(c, pattern, opaque);
    CGContextRestoreGState(c);
    CGContextFillRect(c, CGRectMake(0, 0, 32, 32));
    printPixel("restored color", c, 5, 5, 1);
    CGContextRelease(c);

    CGPatternRelease(stencil);
    CGPatternRelease(pattern);
    CGColorSpaceRelease(colored);
    CGColorSpaceRelease(uncolored);
    printf("pattern info released: %d\n", released);
}

/* MARK: Tiled Images */

static void tiledImages(void) {
    printf("-- tiled images\n");
    /* red, green over blue, white */
    const unsigned char pixels[] = {
        255, 0, 0, 255,   0, 255, 0, 255,
        0, 0, 255, 255,   255, 255, 255, 255,
    };
    CGImageRef image = makeImage(pixels, 2, 2);
    CGContextRef c = makeContext(16, 16);
    CGContextDrawTiledImage(c, CGRectMake(0, 0, 2, 2), image);
    printPixel("tile top left", c, 0, 1, 1);
    printPixel("tile top right", c, 1, 1, 1);
    printPixel("tile bottom left", c, 0, 0, 1);
    printPixel("tile bottom right", c, 1, 0, 1);
    printPixel("next tile across", c, 2, 1, 1);
    printPixel("next tile up", c, 0, 3, 1);
    printPixel("far tile", c, 14, 15, 1);
    CGContextRelease(c);

    /* from the rectangle's origin, within the clip */
    c = makeContext(16, 16);
    CGContextClipToRect(c, CGRectMake(0, 0, 8, 16));
    CGContextDrawTiledImage(c, CGRectMake(1, 0, 2, 2), image);
    printPixel("offset tile", c, 1, 1, 1);
    printPixel("offset before", c, 0, 1, 1);
    printPixel("tile clipped", c, 12, 1, 1);
    CGContextRelease(c);
    CGImageRelease(image);
}

/* MARK: Masks */

static void masks(void) {
    printf("-- masks\n");
    /* 0 on the left, 255 on the right */
    const unsigned char halves[] = {
        0, 0, 255, 255,
        0, 0, 255, 255,
        0, 0, 255, 255,
        0, 0, 255, 255,
    };
    CGImageRef mask = makeMask(halves, 4, 4, 8, 4, NULL);
    printImage("image mask", mask);
    /* 1 for the first four samples of each row, 0 for the last */
    const unsigned char bits[] = { 0xF0, 0xF0 };
    CGImageRef bitMask = makeMask(bits, 8, 2, 1, 1, NULL);
    printImage("bit mask", bitMask);
    CGFloat inverted[] = { 1, 0 };
    CGImageRef invertedMask = makeMask(bits, 8, 2, 1, 1, inverted);
    printImage("inverted mask", invertedMask);
    printImage("bad mask", makeMask(halves, 4, 4, 3, 3, NULL));

    /* an image mask paints the fill color where it's 0 */
    CGContextRef c = makeContext(16, 16);
    CGContextSetRGBFillColor(c, 0, 0, 1, 1);
    CGContextDrawImage(c, CGRectMake(0, 0, 4, 4), mask);
    printPixel("mask paints", c, 1, 1, 1);
    printPixel("mask doesn't", c, 3, 1, 1);
    CGContextDrawImage(c, CGRectMake(0, 8, 8, 2), bitMask);
    printPixel("bit mask doesn't", c, 1, 8, 1);
    printPixel("bit mask paints", c, 6, 8, 1);
    CGContextDrawImage(c, CGRectMake(8, 8, 8, 2), invertedMask);
    printPixel("inverted paints", c, 9, 8, 1);
    printPixel("inverted doesn't", c, 14, 8, 1);
    CGContextRelease(c);

    /* clipping to a gray image */
    const unsigned char grayHalves[] = {
        255, 255, 0, 0,
        255, 255, 0, 0,
        128, 128, 0, 0,
        128, 128, 0, 0,
    };
    CGImageRef grayMask = makeGrayImage(grayHalves, 4, 4);
    c = makeContext(16, 16);
    CGContextSaveGState(c);
    CGContextClipToMask(c, CGRectMake(0, 0, 4, 4), grayMask);
    printRect("mask clip", CGContextGetClipBoundingBox(c));
    CGContextSetRGBFillColor(c, 1, 0, 0, 1);
    CGContextFillRect(c, CGRectMake(0, 0, 16, 16));
    printPixel("gray white", c, 1, 3, 1);
    printPixel("gray half", c, 1, 1, 16);
    printPixel("gray black", c, 3, 3, 1);
    printPixel("outside the mask", c, 8, 8, 1);
    CGContextRestoreGState(c);
    CGContextSetRGBFillColor(c, 0, 1, 0, 1);
    CGContextFillRect(c, CGRectMake(8, 8, 8, 8));
    printPixel("after restoring", c, 10, 10, 1);
    CGContextRelease(c);

    /* clipping to an image mask, scaled, under a transform */
    c = makeContext(16, 16);
    CGContextSaveGState(c);
    CGContextTranslateCTM(c, 8, 0);
    CGContextClipToMask(c, CGRectMake(0, 0, 8, 8), mask);
    CGContextSetRGBFillColor(c, 0, 0, 1, 1);
    CGContextFillRect(c, CGRectMake(-8, 0, 16, 16));
    CGContextRestoreGState(c);
    printPixel("image mask clip left", c, 9, 4, 1);
    printPixel("image mask clip right", c, 14, 4, 1);
    printPixel("image mask clip before", c, 4, 4, 1);
    CGContextRelease(c);

    /* two masks clip to both */
    c = makeContext(16, 16);
    CGContextClipToMask(c, CGRectMake(0, 0, 4, 4), grayMask);
    CGContextClipToMask(c, CGRectMake(0, 0, 4, 4), mask);
    CGContextSetRGBFillColor(c, 1, 0, 0, 1);
    CGContextFillRect(c, CGRectMake(0, 0, 16, 16));
    printPixel("both masks", c, 1, 3, 1);
    printPixel("one mask", c, 3, 3, 1);
    CGContextRelease(c);

    /* an image masked */
    const unsigned char greenPixels[] = {
        0, 255, 0, 255,  0, 255, 0, 255,  0, 255, 0, 255,  0, 255, 0, 255,
        0, 255, 0, 255,  0, 255, 0, 255,  0, 255, 0, 255,  0, 255, 0, 255,
        0, 255, 0, 255,  0, 255, 0, 255,  0, 255, 0, 255,  0, 255, 0, 255,
        0, 255, 0, 255,  0, 255, 0, 255,  0, 255, 0, 255,  0, 255, 0, 255,
    };
    CGImageRef greenImage = makeImage(greenPixels, 4, 4);
    CGImageRef byMask = CGImageCreateWithMask(greenImage, mask);
    printImage("masked by an image mask", byMask);
    CGImageRef byGray = CGImageCreateWithMask(greenImage, grayMask);
    printImage("masked by a gray image", byGray);
    printImage("masked by a color image", CGImageCreateWithMask(greenImage, greenImage));
    c = makeContext(16, 16);
    CGContextDrawImage(c, CGRectMake(0, 0, 4, 4), byMask);
    printPixel("image mask shows", c, 1, 1, 1);
    printPixel("image mask hides", c, 3, 1, 1);
    CGContextDrawImage(c, CGRectMake(8, 8, 8, 8), byGray);
    printPixel("gray white shows", c, 9, 15, 1);
    printPixel("gray half shows", c, 9, 9, 16);
    printPixel("gray black hides", c, 14, 15, 1);
    CGContextRelease(c);

    CGImageRelease(byMask);
    CGImageRelease(byGray);
    CGImageRelease(greenImage);
    CGImageRelease(grayMask);
    CGImageRelease(invertedMask);
    CGImageRelease(bitMask);
    CGImageRelease(mask);
}

int main(void) {
    rgb = CGColorSpaceCreateDeviceRGB();
    gray = CGColorSpaceCreateDeviceGray();
    layers();
    shadings();
    patterns();
    tiledImages();
    masks();
    CGColorSpaceRelease(gray);
    CGColorSpaceRelease(rgb);
    return 0;
}
