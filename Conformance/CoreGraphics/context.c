/*
 * context.c
 * Conformance of CGContext.h, CGBitmapContext.h, CGColor.h, CGColorSpace.h,
 * CGGradient.h and CGImage.h: bitmap formats, the graphics state, and
 * pixels drawn. Opaque pixels print exactly; blended ones, rounded to steps
 * of 16, past the implementations' differences in rounding.
 */

#include "conformance.h"
#include <stdlib.h>
#include <string.h>

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

static void printFormat(const char *label, CGContextRef c) {
    if (c == NULL) { printf("%s: NULL\n", label); return; }
    printf("%s: bpc %zu bpp %zu bytesPerRow %zu alphaInfo %u bitmapInfo 0x%x\n", label,
           CGBitmapContextGetBitsPerComponent(c), CGBitmapContextGetBitsPerPixel(c), CGBitmapContextGetBytesPerRow(c),
           (unsigned)CGBitmapContextGetAlphaInfo(c), (unsigned)CGBitmapContextGetBitmapInfo(c));
}

static void drawScene(const char *name, CGContextRef c) {
    char label[128];
    /* background: an opaque fill */
    CGContextSetRGBFillColor(c, 0.2, 0.4, 0.6, 1);
    CGContextFillRect(c, CGRectMake(0, 0, 40, 40));
    snprintf(label, sizeof(label), "%s background", name); printPixel(label, c, 20, 20, 1);

    /* half-transparent red over it, in the lower left quarter */
    CGContextSetRGBFillColor(c, 1, 0, 0, 0.5);
    CGContextFillRect(c, CGRectMake(0, 0, 20, 20));
    snprintf(label, sizeof(label), "%s blended", name); printPixel(label, c, 5, 5, 16);
    snprintf(label, sizeof(label), "%s outside blend", name); printPixel(label, c, 30, 30, 1);

    /* a transformed, clipped green square */
    CGContextSaveGState(c);
    CGContextTranslateCTM(c, 20, 20);
    CGContextClipToRect(c, CGRectMake(0, 0, 10, 20));
    CGContextSetRGBFillColor(c, 0, 1, 0, 1);
    CGContextFillRect(c, CGRectMake(0, 0, 20, 10));
    CGContextRestoreGState(c);
    snprintf(label, sizeof(label), "%s clipped inside", name); printPixel(label, c, 25, 25, 1);
    snprintf(label, sizeof(label), "%s clipped outside", name); printPixel(label, c, 35, 25, 1);

    /* a thick white stroke along y = 36 */
    CGContextSetGrayStrokeColor(c, 1, 1);
    CGContextSetLineWidth(c, 4);
    CGContextMoveToPoint(c, 0, 36);
    CGContextAddLineToPoint(c, 40, 36);
    CGContextStrokePath(c);
    snprintf(label, sizeof(label), "%s stroke", name); printPixel(label, c, 10, 36, 1);

    /* cleared corner */
    CGContextClearRect(c, CGRectMake(36, 0, 4, 4));
    snprintf(label, sizeof(label), "%s cleared", name); printPixel(label, c, 38, 2, 1);
}

int main(void) {
    CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
    CGColorSpaceRef gray = CGColorSpaceCreateDeviceGray();

    printf("-- color spaces\n");
    printf("rgb: model %d components %zu\n", (int)CGColorSpaceGetModel(rgb), CGColorSpaceGetNumberOfComponents(rgb));
    printf("gray: model %d components %zu\n", (int)CGColorSpaceGetModel(gray), CGColorSpaceGetNumberOfComponents(gray));

    printf("-- colors\n");
    CGFloat components[] = { 0.1, 0.2, 0.3, 0.4 };
    CGColorRef color = CGColorCreate(rgb, components);
    printf("color: components %zu alpha ", CGColorGetNumberOfComponents(color)); printNumber(CGColorGetAlpha(color)); printf("\n");
    const CGFloat *values = CGColorGetComponents(color);
    printf("color components:"); for (size_t i = 0; i < CGColorGetNumberOfComponents(color); i++) { printf(" "); printNumber(values[i]); } printf("\n");
    CGColorRef copy = CGColorCreateCopyWithAlpha(color, 0.9);
    printf("copy alpha: "); printNumber(CGColorGetAlpha(copy)); printf("\n");
    printBool("equal", CGColorEqualToColor(color, color));
    printBool("equal with other alpha", CGColorEqualToColor(color, copy));
    CGColorRef grayColor = CGColorCreateGenericGray(0.5, 1);
    printf("gray color components %zu model %d\n", CGColorGetNumberOfComponents(grayColor), (int)CGColorSpaceGetModel(CGColorGetColorSpace(grayColor)));

    printf("-- formats\n");
    printFormat("rgba", CGBitmapContextCreate(NULL, 10, 10, 8, 0, rgb, kCGImageAlphaPremultipliedLast));
    printFormat("rgba 13 wide", CGBitmapContextCreate(NULL, 13, 10, 8, 0, rgb, kCGImageAlphaPremultipliedLast));
    printFormat("bgra", CGBitmapContextCreate(NULL, 10, 10, 8, 0, rgb, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little));
    printFormat("argb", CGBitmapContextCreate(NULL, 10, 10, 8, 0, rgb, kCGImageAlphaPremultipliedFirst));
    printFormat("rgbx", CGBitmapContextCreate(NULL, 10, 10, 8, 0, rgb, kCGImageAlphaNoneSkipLast));
    printFormat("gray", CGBitmapContextCreate(NULL, 10, 10, 8, 0, gray, kCGImageAlphaNone));
    printFormat("gray 13 wide", CGBitmapContextCreate(NULL, 13, 10, 8, 0, gray, kCGImageAlphaNone));
    printFormat("alpha only", CGBitmapContextCreate(NULL, 10, 10, 8, 0, NULL, kCGImageAlphaOnly));
    printFormat("explicit row", CGBitmapContextCreate(NULL, 10, 10, 8, 64, rgb, kCGImageAlphaPremultipliedLast));
    printFormat("row too short", CGBitmapContextCreate(NULL, 10, 10, 8, 20, rgb, kCGImageAlphaPremultipliedLast));
    printFormat("straight alpha", CGBitmapContextCreate(NULL, 10, 10, 8, 0, rgb, kCGImageAlphaLast));
    printFormat("rgb without alpha", CGBitmapContextCreate(NULL, 10, 10, 8, 0, rgb, kCGImageAlphaNone));

    printf("-- drawing\n");
    struct { const char *name; uint32_t info; CGColorSpaceRef space; } formats[] = {
        { "rgba", kCGImageAlphaPremultipliedLast, rgb },
        { "bgra", kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little, rgb },
        { "argb", kCGImageAlphaPremultipliedFirst, rgb },
        { "rgbx", kCGImageAlphaNoneSkipLast, rgb },
        { "gray", kCGImageAlphaNone, gray },
    };
    for (size_t i = 0; i < sizeof(formats) / sizeof(formats[0]); i++) {
        size_t bytesPerPixel = formats[i].space == gray ? 1 : 4;
        size_t bytesPerRow = 40 * bytesPerPixel;
        void *memory = calloc(bytesPerRow, 40);
        CGContextRef c = CGBitmapContextCreate(memory, 40, 40, 8, bytesPerRow, formats[i].space, formats[i].info);
        drawScene(formats[i].name, c);
        CGContextRelease(c);
        free(memory);
    }

    CGContextRef alphaOnly = CGBitmapContextCreate(NULL, 40, 40, 8, 40, NULL, kCGImageAlphaOnly);
    CGContextSetRGBFillColor(alphaOnly, 1, 0, 0, 0.5);
    CGContextFillRect(alphaOnly, CGRectMake(0, 0, 20, 20));
    printPixel("alpha only blended", alphaOnly, 5, 5, 16);
    printPixel("alpha only empty", alphaOnly, 30, 30, 1);

    printf("-- memory written by the program\n");
    {
        unsigned char *memory = calloc(40 * 4, 40);
        CGContextRef c = CGBitmapContextCreate(memory, 40, 40, 8, 40 * 4, rgb, kCGImageAlphaPremultipliedLast);
        /* the program paints the whole memory opaque blue, then draws half-transparent white over it */
        for (int i = 0; i < 40 * 40; i++) { memory[i * 4 + 2] = 255; memory[i * 4 + 3] = 255; }
        CGContextSetRGBFillColor(c, 1, 1, 1, 0.5);
        CGContextFillRect(c, CGRectMake(0, 0, 10, 10));
        printPixel("over program's blue", c, 5, 5, 16);
        printPixel("program's blue", c, 30, 30, 1);
        CGContextRelease(c);
        free(memory);
    }

    printf("-- state\n");
    CGContextRef c = CGBitmapContextCreate(NULL, 100, 50, 8, 0, rgb, kCGImageAlphaPremultipliedLast);
    printTransform("initial ctm", CGContextGetCTM(c));
    printRect("initial clip", CGContextGetClipBoundingBox(c));
    printBool("initial path empty", CGContextIsPathEmpty(c));
    printPoint("initial current point", CGContextGetPathCurrentPoint(c));
    printf("initial interpolation %d\n", (int)CGContextGetInterpolationQuality(c));
    CGContextSaveGState(c);
    CGContextTranslateCTM(c, 10, 20);
    CGContextScaleCTM(c, 2, 3);
    CGContextRotateCTM(c, M_PI / 2);
    printTransform("ctm", CGContextGetCTM(c));
    printPoint("to device", CGContextConvertPointToDeviceSpace(c, CGPointMake(1, 2)));
    printPoint("to user", CGContextConvertPointToUserSpace(c, CGPointMake(30, 40)));
    printSize("size to device", CGContextConvertSizeToDeviceSpace(c, CGSizeMake(1, 2)));
    printRect("rect to device", CGContextConvertRectToDeviceSpace(c, CGRectMake(0, 0, 1, 2)));
    CGContextClipToRect(c, CGRectMake(0, 0, 5, 5));
    printRect("clip", CGContextGetClipBoundingBox(c));
    CGContextRestoreGState(c);
    printTransform("restored ctm", CGContextGetCTM(c));
    printRect("restored clip", CGContextGetClipBoundingBox(c));

    CGContextAddLineToPoint(c, 5, 5); /* no current point: ignored */
    printBool("line without point empty", CGContextIsPathEmpty(c));
    CGContextMoveToPoint(c, 10, 10);
    CGContextAddCurveToPoint(c, 20, 40, 30, -20, 40, 10);
    printPoint("current point", CGContextGetPathCurrentPoint(c));
    printRect("path bounds", CGContextGetPathBoundingBox(c));
    CGContextAddRect(c, CGRectMake(50, 10, 20, 20));
    printBool("contains in rect", CGContextPathContainsPoint(c, CGPointMake(60, 20), kCGPathFill));
    printBool("contains outside", CGContextPathContainsPoint(c, CGPointMake(90, 20), kCGPathFill));
    CGPathRef copied = CGContextCopyPath(c);
    printRect("copied path bounds", CGPathGetBoundingBox(copied));
    CGContextTranslateCTM(c, 5, 5);
    printPoint("current point after translate", CGContextGetPathCurrentPoint(c));
    CGContextFillPath(c);
    printBool("path empty after fill", CGContextIsPathEmpty(c));

    printf("-- images\n");
    CGContextRef source = CGBitmapContextCreate(NULL, 2, 2, 8, 0, rgb, kCGImageAlphaPremultipliedLast);
    /* top left red, top right green, bottom left blue, bottom right white (y up) */
    CGContextSetRGBFillColor(source, 1, 0, 0, 1); CGContextFillRect(source, CGRectMake(0, 1, 1, 1));
    CGContextSetRGBFillColor(source, 0, 1, 0, 1); CGContextFillRect(source, CGRectMake(1, 1, 1, 1));
    CGContextSetRGBFillColor(source, 0, 0, 1, 1); CGContextFillRect(source, CGRectMake(0, 0, 1, 1));
    CGContextSetRGBFillColor(source, 1, 1, 1, 1); CGContextFillRect(source, CGRectMake(1, 0, 1, 1));
    CGImageRef image = CGBitmapContextCreateImage(source);
    printf("image: %zu x %zu bpc %zu bpp %zu alphaInfo %u bitmapInfo 0x%x\n", CGImageGetWidth(image), CGImageGetHeight(image),
           CGImageGetBitsPerComponent(image), CGImageGetBitsPerPixel(image), (unsigned)CGImageGetAlphaInfo(image),
           (unsigned)CGImageGetBitmapInfo(image));
    CGImageRef cropped = CGImageCreateWithImageInRect(image, CGRectMake(1, 0, 1, 1));
    printf("cropped: %zu x %zu\n", CGImageGetWidth(cropped), CGImageGetHeight(cropped));
    CGContextRef target = CGBitmapContextCreate(NULL, 40, 40, 8, 0, rgb, kCGImageAlphaPremultipliedLast);
    CGContextDrawImage(target, CGRectMake(0, 0, 40, 40), image);
    printPixel("image top left", target, 10, 30, 1);
    printPixel("image top right", target, 30, 30, 1);
    printPixel("image bottom left", target, 10, 10, 1);
    printPixel("image bottom right", target, 30, 10, 1);
    CGContextDrawImage(target, CGRectMake(0, 0, 40, 40), cropped);
    printPixel("cropped image", target, 20, 20, 1);
    CGContextSetInterpolationQuality(target, kCGInterpolationNone);
    printf("interpolation %d\n", (int)CGContextGetInterpolationQuality(target));
    CGContextDrawImage(target, CGRectMake(0, 0, 40, 40), image);
    printPixel("nearest top left", target, 10, 30, 1);
    printPixel("nearest left of middle", target, 19, 30, 1);
    printPixel("nearest right of middle", target, 20, 30, 1);
    printPixel("nearest bottom right", target, 30, 10, 1);

    printf("-- gradients\n");
    CGFloat stops[] = { 0, 0, 0, 1, 1, 1, 1, 1 };
    CGGradientRef gradient = CGGradientCreateWithColorComponents(rgb, stops, NULL, 2);
    CGContextRef g = CGBitmapContextCreate(NULL, 100, 10, 8, 0, rgb, kCGImageAlphaPremultipliedLast);
    CGContextDrawLinearGradient(g, gradient, CGPointMake(0, 0), CGPointMake(100, 0), 0);
    printPixel("linear start", g, 1, 5, 16);
    printPixel("linear middle", g, 50, 5, 16);
    printPixel("linear end", g, 98, 5, 16);
    CGContextRef r = CGBitmapContextCreate(NULL, 100, 100, 8, 0, rgb, kCGImageAlphaPremultipliedLast);
    CGContextDrawRadialGradient(r, gradient, CGPointMake(50, 50), 0, CGPointMake(50, 50), 40, 0);
    printPixel("radial center", r, 50, 50, 16);
    printPixel("radial halfway", r, 70, 50, 16);
    printPixel("radial outside", r, 95, 95, 1);
    CGContextDrawRadialGradient(r, gradient, CGPointMake(50, 50), 0, CGPointMake(50, 50), 40, kCGGradientDrawsAfterEndLocation);
    printPixel("radial extended", r, 95, 95, 16);

    printf("-- layers and shadows\n");
    CGContextRef l = CGBitmapContextCreate(NULL, 40, 40, 8, 0, rgb, kCGImageAlphaPremultipliedLast);
    CGContextSetAlpha(l, 0.5);
    CGContextBeginTransparencyLayer(l, NULL);
    CGContextSetRGBFillColor(l, 0, 0, 0, 1);
    CGContextFillRect(l, CGRectMake(0, 0, 20, 20));
    CGContextFillRect(l, CGRectMake(10, 10, 20, 20));
    CGContextEndTransparencyLayer(l);
    printPixel("layer overlap", l, 15, 15, 16);
    printPixel("layer single", l, 5, 5, 16);
    CGContextRef s = CGBitmapContextCreate(NULL, 40, 40, 8, 0, rgb, kCGImageAlphaPremultipliedLast);
    CGColorRef blue = CGColorCreateGenericRGB(0, 0, 1, 1);
    CGContextSetShadowWithColor(s, CGSizeMake(10, -10), 0, blue);
    CGContextSetRGBFillColor(s, 1, 0, 0, 1);
    CGContextFillRect(s, CGRectMake(5, 20, 10, 10));
    printPixel("shadowed shape", s, 10, 25, 16);
    printPixel("shadow", s, 20, 15, 16);
    return 0;
}
