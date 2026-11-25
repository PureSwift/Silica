/*
 * operations.c
 * Conformance of what's made from other things: transforms from their
 * components, paths from paths (flattened, dashed, stroked, and their areas
 * combined), calibrated, ICC and indexed color spaces, colors matched to
 * spaces, and images copied, masked by colors and read from PNGs. Paths are
 * compared by the area they fill, since their elements may differ: their
 * boxes, to two decimals, and which points they contain.
 */

#include "conformance.h"
#include <stdlib.h>
#include <string.h>

static CGColorSpaceRef rgb;
static CGColorSpaceRef gray;

/* Two decimals, past differences in how curves become lines. */
static void printRounded(double value) {
    double rounded = round(value * 100) / 100;
    if (fabs(rounded) < 0.005) rounded = 0;
    printf("%.2f", rounded);
}

static void printBox(const char *label, CGPathRef path) {
    if (path == NULL) { printf("%s: NULL\n", label); return; }
    if (CGPathIsEmpty(path)) { printf("%s: empty\n", label); return; }
    CGRect box = CGPathGetPathBoundingBox(path);
    printf("%s: ", label);
    printRounded(box.origin.x); printf(" ");
    printRounded(box.origin.y); printf(" ");
    printRounded(box.size.width); printf(" ");
    printRounded(box.size.height); printf("\n");
}

static void printContains(const char *label, CGPathRef path, CGFloat x, CGFloat y) {
    printf("%s (", label);
    printNumber(x); printf(", "); printNumber(y);
    printf("): %s\n", path != NULL && CGPathContainsPoint(path, NULL, CGPointMake(x, y), false) ? "inside" : "outside");
}

struct Counts { int moves, lines, curves, closes; };

static void count(void *info, const CGPathElement *element) {
    struct Counts *counts = info;
    switch (element->type) {
    case kCGPathElementMoveToPoint: counts->moves++; break;
    case kCGPathElementAddLineToPoint: counts->lines++; break;
    case kCGPathElementAddQuadCurveToPoint:
    case kCGPathElementAddCurveToPoint: counts->curves++; break;
    case kCGPathElementCloseSubpath: counts->closes++; break;
    }
}

static struct Counts counts(CGPathRef path) {
    struct Counts counts = { 0, 0, 0, 0 };
    CGPathApply(path, &counts, count);
    return counts;
}

static CGPathRef rect(CGFloat x, CGFloat y, CGFloat width, CGFloat height) {
    return CGPathCreateWithRect(CGRectMake(x, y, width, height), NULL);
}

static CGPathRef line(CGFloat x1, CGFloat y1, CGFloat x2, CGFloat y2) {
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathMoveToPoint(path, NULL, x1, y1);
    CGPathAddLineToPoint(path, NULL, x2, y2);
    return path;
}

static void printPixel(const char *label, CGContextRef c, int x, int y) {
    unsigned char *data = CGBitmapContextGetData(c);
    size_t bytesPerRow = CGBitmapContextGetBytesPerRow(c);
    size_t row = CGBitmapContextGetHeight(c) - 1 - (size_t)y;
    unsigned char *pixel = data + row * bytesPerRow + (size_t)x * 4;
    printf("%s: %d %d %d %d\n", label, pixel[0], pixel[1], pixel[2], pixel[3]);
}

static CGContextRef makeContext(size_t width, size_t height) {
    return CGBitmapContextCreate(NULL, width, height, 8, 0, rgb, kCGImageAlphaPremultipliedLast);
}

/* MARK: Transforms */

static void printComponents(const char *label, CGAffineTransformComponents components) {
    printf("%s: scale ", label);
    printNumber(components.scale.width); printf(" "); printNumber(components.scale.height);
    printf(" shear "); printNumber(components.horizontalShear);
    printf(" rotation "); printNumber(components.rotation);
    printf(" translation "); printNumber(components.translation.dx); printf(" "); printNumber(components.translation.dy);
    printf("\n");
}

static void transforms(void) {
    printf("-- transforms\n");
    printComponents("identity", CGAffineTransformDecompose(CGAffineTransformIdentity));
    printComponents("scale", CGAffineTransformDecompose(CGAffineTransformMakeScale(2, 3)));
    printComponents("rotation", CGAffineTransformDecompose(CGAffineTransformMakeRotation(M_PI / 6)));
    printComponents("translation", CGAffineTransformDecompose(CGAffineTransformMakeTranslation(5, 7)));
    printComponents("shear", CGAffineTransformDecompose(CGAffineTransformMake(1, 0, 0.5, 1, 0, 0)));
    printComponents("flip x", CGAffineTransformDecompose(CGAffineTransformMake(-1, 0, 0, 1, 0, 0)));
    printComponents("flip y", CGAffineTransformDecompose(CGAffineTransformMake(1, 0, 0, -1, 0, 0)));

    CGAffineTransformComponents components = { { 2, 3 }, 0.5, 0.3, { 4, 5 } };
    CGAffineTransform made = CGAffineTransformMakeWithComponents(components);
    printTransform("made", made);
    printComponents("made, decomposed", CGAffineTransformDecompose(made));
    CGAffineTransformComponents rotated = { { 1, 1 }, 0, M_PI / 2, { 0, 0 } };
    printTransform("rotated", CGAffineTransformMakeWithComponents(rotated));
}

/* MARK: Paths of Paths */

static void apply(void) {
    printf("-- applying\n");
    CGPathRef path = rect(0, 0, 10, 10);
#if defined(__BLOCKS__)
    __block int elements = 0;
    __block CGFloat sum = 0;
    CGPathApplyWithBlock(path, ^(const CGPathElement *element) {
        elements++;
        if (element->type != kCGPathElementCloseSubpath) sum += element->points[0].x + element->points[0].y;
    });
    printf("block elements: %d sum ", elements);
    printNumber(sum);
    printf("\n");
#else
    printf("blocks unavailable\n");
#endif
    CGPathRelease(path);
}

static void copies(void) {
    printf("-- flattening\n");
    CGPathRef ellipse = CGPathCreateWithEllipseInRect(CGRectMake(0, 0, 10, 10), NULL);
    CGPathRef flat = CGPathCreateCopyByFlattening(ellipse, 0.5);
    struct Counts flatCounts = counts(flat);
    printf("flattened: curves %d closes %d lines %s\n", flatCounts.curves, flatCounts.closes, flatCounts.lines > 4 ? "some" : "few");
    printBox("flattened box", flat);
    printContains("flattened", flat, 5, 5);
    CGPathRelease(flat);
    CGPathRelease(ellipse);

    printf("-- dashing\n");
    CGPathRef segment = line(0, 0, 10, 0);
    CGFloat dashes[] = { 2, 2 };
    CGPathRef dashed = CGPathCreateCopyByDashingPath(segment, NULL, 0, dashes, 2);
    printf("dashes: %d\n", counts(dashed).moves);
    printBox("dashed box", dashed);
    CGPathRelease(dashed);
    dashed = CGPathCreateCopyByDashingPath(segment, NULL, 1, dashes, 2);
    printf("dashes from 1: %d\n", counts(dashed).moves);
    printBox("dashed from 1 box", dashed);
    CGPathRelease(dashed);
    CGAffineTransform moved = CGAffineTransformMakeTranslation(0, 5);
    dashed = CGPathCreateCopyByDashingPath(segment, &moved, 0, dashes, 2);
    printBox("dashed and moved box", dashed);
    CGPathRelease(dashed);
    CGPathRef square = rect(0, 0, 10, 10);
    CGFloat long_dashes[] = { 15, 5 };
    dashed = CGPathCreateCopyByDashingPath(square, NULL, 0, long_dashes, 2);
    printf("square dashes: %d\n", counts(dashed).moves);
    printBox("square dashed box", dashed);
    CGPathRelease(dashed);

    printf("-- stroking\n");
    CGPathRef stroked = CGPathCreateCopyByStrokingPath(segment, NULL, 4, kCGLineCapButt, kCGLineJoinMiter, 10);
    printBox("butt", stroked);
    printContains("butt", stroked, 5, 1.5);
    printContains("butt", stroked, 5, 2.5);
    printContains("butt", stroked, -1, 0);
    CGPathRelease(stroked);
    stroked = CGPathCreateCopyByStrokingPath(segment, NULL, 4, kCGLineCapSquare, kCGLineJoinMiter, 10);
    printBox("square", stroked);
    printContains("square", stroked, -1.5, 1.5);
    CGPathRelease(stroked);
    stroked = CGPathCreateCopyByStrokingPath(segment, NULL, 4, kCGLineCapRound, kCGLineJoinMiter, 10);
    printContains("round", stroked, 11.5, 0);
    printContains("round", stroked, 11.8, 1.8);
    printContains("round", stroked, -1.5, 0);
    CGPathRelease(stroked);
    stroked = CGPathCreateCopyByStrokingPath(segment, &moved, 4, kCGLineCapButt, kCGLineJoinMiter, 10);
    printBox("moved", stroked);
    CGPathRelease(stroked);

    CGMutablePathRef corner = CGPathCreateMutable();
    CGPathMoveToPoint(corner, NULL, 0, 0);
    CGPathAddLineToPoint(corner, NULL, 10, 0);
    CGPathAddLineToPoint(corner, NULL, 10, 10);
    stroked = CGPathCreateCopyByStrokingPath(corner, NULL, 2, kCGLineCapButt, kCGLineJoinMiter, 10);
    printBox("miter", stroked);
    printContains("miter", stroked, 10.9, -0.9);
    CGPathRelease(stroked);
    stroked = CGPathCreateCopyByStrokingPath(corner, NULL, 2, kCGLineCapButt, kCGLineJoinBevel, 10);
    printContains("bevel", stroked, 10.9, -0.9);
    printContains("bevel", stroked, 10.4, -0.4);
    CGPathRelease(stroked);
    stroked = CGPathCreateCopyByStrokingPath(corner, NULL, 2, kCGLineCapButt, kCGLineJoinRound, 10);
    printContains("round join", stroked, 10.9, -0.9);
    printContains("round join", stroked, 10.6, -0.6);
    CGPathRelease(stroked);
    stroked = CGPathCreateCopyByStrokingPath(corner, NULL, 2, kCGLineCapButt, kCGLineJoinMiter, 1);
    printContains("miter over its limit", stroked, 10.9, -0.9);
    CGPathRelease(stroked);
    CGPathRelease(corner);

    stroked = CGPathCreateCopyByStrokingPath(square, NULL, 2, kCGLineCapButt, kCGLineJoinMiter, 10);
    printBox("closed", stroked);
    printContains("closed", stroked, 0, 5);
    printContains("closed", stroked, 5, 5);
    printContains("closed corner", stroked, -0.9, -0.9);
    CGPathRelease(stroked);
    printBox("no width", CGPathCreateCopyByStrokingPath(segment, NULL, 0, kCGLineCapButt, kCGLineJoinMiter, 10));
    CGPathRelease(square);
    CGPathRelease(segment);
}

static void areas(void) {
    printf("-- areas\n");
    CGPathRef a = rect(0, 0, 10, 10);
    CGPathRef b = rect(5, 5, 10, 10);
    CGPathRef far = rect(50, 50, 5, 5);
    CGPathRef beside = rect(10, 0, 10, 10);

    CGPathRef result = CGPathCreateCopyByUnioningPath(a, b, false);
    printBox("union", result);
    printContains("union", result, 2, 2);
    printContains("union", result, 12, 12);
    printContains("union", result, 12, 2);
    printContains("union", result, 7, 7);
    CGPathRelease(result);

    result = CGPathCreateCopyByIntersectingPath(a, b, false);
    printBox("intersection", result);
    printContains("intersection", result, 7, 7);
    printContains("intersection", result, 2, 2);
    CGPathRelease(result);

    result = CGPathCreateCopyBySubtractingPath(a, b, false);
    printBox("subtraction", result);
    printContains("subtraction", result, 7, 7);
    printContains("subtraction", result, 2, 2);
    printContains("subtraction", result, 8, 2);
    CGPathRelease(result);

    result = CGPathCreateCopyBySymmetricDifferenceOfPath(a, b, false);
    printBox("symmetric difference", result);
    printContains("symmetric difference", result, 7, 7);
    printContains("symmetric difference", result, 2, 2);
    printContains("symmetric difference", result, 12, 12);
    CGPathRelease(result);

    result = CGPathCreateCopyByIntersectingPath(a, far, false);
    printBox("disjoint intersection", result);
    if (result) CGPathRelease(result);
    result = CGPathCreateCopyByUnioningPath(a, beside, false);
    printBox("union beside", result);
    printContains("union beside", result, 10, 5);
    CGPathRelease(result);

    /* a hole, by its winding */
    CGMutablePathRef holed = CGPathCreateMutable();
    CGPathAddRect(holed, NULL, CGRectMake(0, 0, 10, 10));
    CGPathAddRect(holed, NULL, CGRectMake(3, 3, 4, 4));
    result = CGPathCreateCopyByNormalizing(holed, true);
    printBox("normalized even-odd", result);
    printContains("normalized even-odd", result, 5, 5);
    printContains("normalized even-odd", result, 1, 1);
    CGPathRelease(result);
    result = CGPathCreateCopyByNormalizing(holed, false);
    printContains("normalized winding", result, 5, 5);
    CGPathRelease(result);
    result = CGPathCreateCopyByUnioningPath(holed, far, true);
    printContains("even-odd union", result, 5, 5);
    printContains("even-odd union", result, 52, 52);
    CGPathRelease(result);

    /* curves */
    CGPathRef circle = CGPathCreateWithEllipseInRect(CGRectMake(0, 0, 10, 10), NULL);
    result = CGPathCreateCopyBySubtractingPath(a, circle, false);
    printContains("square less circle", result, 5, 5);
    printContains("square less circle", result, 0.5, 0.5);
    printContains("square less circle", result, 9.5, 9.5);
    CGPathRelease(result);
    CGPathRelease(circle);

    printf("-- intersecting\n");
    printBool("overlapping", CGPathIntersectsPath(a, b, false));
    printBool("disjoint", CGPathIntersectsPath(a, far, false));
    printBool("inside", CGPathIntersectsPath(a, rect(2, 2, 2, 2), false));

    printf("-- lines\n");
    CGPathRef across = line(-5, 5, 15, 5);
    result = CGPathCreateCopyOfLineByIntersectingPath(across, a, false);
    printBox("line inside", result);
    printf("line inside pieces: %d\n", counts(result).moves);
    CGPathRelease(result);
    result = CGPathCreateCopyOfLineBySubtractingPath(across, a, false);
    printBox("line outside", result);
    printf("line outside pieces: %d\n", counts(result).moves);
    CGPathRelease(result);
    result = CGPathCreateCopyOfLineByIntersectingPath(across, far, false);
    printBox("line missing", result);
    if (result) CGPathRelease(result);
    CGPathRelease(across);

    CGPathRelease(holed);
    CGPathRelease(beside);
    CGPathRelease(far);
    CGPathRelease(b);
    CGPathRelease(a);
}

/* MARK: Contexts */

static void contexts(void) {
    printf("-- contexts\n");
    CGContextRef c = makeContext(20, 20);
    CGContextSetLineWidth(c, 4);
    CGContextMoveToPoint(c, 2, 10);
    CGContextAddLineToPoint(c, 18, 10);
    CGContextReplacePathWithStrokedPath(c);
    CGRect box = CGContextGetPathBoundingBox(c);
    printf("stroked path: "); printRounded(box.origin.x); printf(" "); printRounded(box.origin.y); printf(" ");
    printRounded(box.size.width); printf(" "); printRounded(box.size.height); printf("\n");
    CGContextSetRGBFillColor(c, 1, 0, 0, 1);
    CGContextFillPath(c);
    printPixel("stroked inside", c, 10, 11);
    printPixel("stroked outside", c, 10, 14);

    CGContextSaveGState(c);
    CGContextClipToRect(c, CGRectMake(0, 0, 5, 5));
    CGContextResetClip(c);
    printRect("reset clip", CGContextGetClipBoundingBox(c));
    CGContextSetRGBFillColor(c, 0, 0, 1, 1);
    CGContextFillRect(c, CGRectMake(10, 0, 5, 5));
    printPixel("after reset", c, 12, 2);
    CGContextRestoreGState(c);
    CGContextRelease(c);
}

/* MARK: Color Spaces */

static void spaces(void) {
    printf("-- color spaces\n");
    CGFloat white[] = { 0.9505, 1, 1.089 };
    CGFloat black[] = { 0, 0, 0 };
    CGFloat gammas[] = { 1.8, 1.8, 1.8 };
    CGFloat matrix[] = { 0.4497, 0.2446, 0.0252, 0.3163, 0.6720, 0.1412, 0.1845, 0.0833, 0.9227 };
    CGColorSpaceRef calibratedGray = CGColorSpaceCreateCalibratedGray(white, black, 1.8);
    printf("calibrated gray: model %d components %zu\n", (int)CGColorSpaceGetModel(calibratedGray),
           CGColorSpaceGetNumberOfComponents(calibratedGray));
    CGColorSpaceRef calibratedRGB = CGColorSpaceCreateCalibratedRGB(white, black, gammas, matrix);
    printf("calibrated rgb: model %d components %zu\n", (int)CGColorSpaceGetModel(calibratedRGB),
           CGColorSpaceGetNumberOfComponents(calibratedRGB));

    const unsigned char table[] = { 255, 0, 0, 0, 0, 255 };
    CGColorSpaceRef indexed = CGColorSpaceCreateIndexed(rgb, 1, table);
    printf("indexed: model %d components %zu colors %zu base model %d\n", (int)CGColorSpaceGetModel(indexed),
           CGColorSpaceGetNumberOfComponents(indexed), CGColorSpaceGetColorTableCount(indexed),
           (int)CGColorSpaceGetModel(CGColorSpaceGetBaseColorSpace(indexed)));
    unsigned char copied[6] = { 0 };
    CGColorSpaceGetColorTable(indexed, copied);
    printf("indexed table: %d %d %d %d %d %d\n", copied[0], copied[1], copied[2], copied[3], copied[4], copied[5]);
    printBool("indexed too many", CGColorSpaceCreateIndexed(rgb, 256, table) == NULL);
    printBool("indexed of indexed", CGColorSpaceCreateIndexed(indexed, 0, table) == NULL);
    printf("rgb colors: %zu\n", CGColorSpaceGetColorTableCount(rgb));

    CGContextRef c = makeContext(4, 4);
    CGFloat second[] = { 1, 1 };
    CGColorRef blue = CGColorCreate(indexed, second);
    CGContextSetFillColorWithColor(c, blue);
    CGContextFillRect(c, CGRectMake(0, 0, 4, 4));
    printPixel("indexed color", c, 1, 1);
    CGContextSetFillColorSpace(c, indexed);
    CGFloat first[] = { 0, 1 };
    CGContextSetFillColor(c, first);
    CGContextFillRect(c, CGRectMake(0, 0, 4, 4));
    printPixel("indexed fill", c, 1, 1);
    CGColorRelease(blue);
    CGContextRelease(c);

    printBool("linearized rgb", CGColorSpaceCreateLinearized(rgb) != NULL);
    printBool("extended rgb", CGColorSpaceCreateExtended(rgb) != NULL);
    printBool("linearized indexed", CGColorSpaceCreateLinearized(indexed) != NULL);

    printf("-- matching colors\n");
    CGColorRef red = CGColorCreateGenericRGB(1, 0, 0, 0.5);
    CGColorRef matched = CGColorCreateCopyByMatchingToColorSpace(gray, kCGRenderingIntentDefault, red, NULL);
    printf("red in gray: components %zu alpha ", CGColorGetNumberOfComponents(matched));
    printRounded(CGColorGetAlpha(matched));
    printf(" model %d\n", (int)CGColorSpaceGetModel(CGColorGetColorSpace(matched)));
    CGFloat half[] = { 0.5, 1 };
    CGColorRef middle = CGColorCreate(gray, half);
    CGColorRef inRGB = CGColorCreateCopyByMatchingToColorSpace(rgb, kCGRenderingIntentDefault, middle, NULL);
    const CGFloat *components = CGColorGetComponents(inRGB);
    printf("gray in rgb: ");
    printRounded(components[0]); printf(" "); printRounded(components[1]); printf(" "); printRounded(components[2]);
    printf("\n");
    printBool("matched to indexed", CGColorCreateCopyByMatchingToColorSpace(indexed, kCGRenderingIntentDefault, red, NULL) == NULL);
    CGColorRelease(inRGB);
    CGColorRelease(middle);
    CGColorRelease(matched);
    CGColorRelease(red);

    CGColorSpaceRelease(indexed);
    CGColorSpaceRelease(calibratedRGB);
    CGColorSpaceRelease(calibratedGray);
}

/* MARK: Images */

static void releaseBytes(void *info, const void *data, size_t size) {
    (void)info; (void)size;
    free((void *)data);
}

static CGDataProviderRef makeProvider(const unsigned char *bytes, size_t count) {
    unsigned char *copy = malloc(count);
    memcpy(copy, bytes, count);
    return CGDataProviderCreateWithData(NULL, copy, count, releaseBytes);
}

/* a 2 by 2 RGBA PNG: red, half transparent green, then blue, white */
static const unsigned char png[] = {
    0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x02, 0x08, 0x06, 0x00, 0x00, 0x00, 0x72, 0xb6, 0x0d,
    0x24, 0x00, 0x00, 0x00, 0x14, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9c, 0x63, 0xf8, 0xcf, 0xc0, 0xf0,
    0x1f, 0x08, 0x1b, 0x18, 0x80, 0x34, 0x18, 0x00, 0x00, 0x44, 0xd2, 0x09, 0x78, 0xb6, 0x87, 0x23,
    0x4b, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82,
};

static void images(void) {
    printf("-- images\n");
    /* red, blue, in RGB of 3 bytes */
    const unsigned char pixels[] = { 255, 0, 0, 0, 0, 255 };
    CGDataProviderRef provider = makeProvider(pixels, sizeof(pixels));
    CGImageRef image = CGImageCreate(2, 1, 8, 24, 6, rgb, kCGImageAlphaNone, provider, NULL, false, kCGRenderingIntentDefault);
    CGDataProviderRelease(provider);
    printf("pixel format: %u\n", (unsigned)CGImageGetPixelFormatInfo(image));
    printBool("type", CGImageGetUTType(image) == NULL);

    printBool("copy in gray", CGImageCreateCopyWithColorSpace(image, gray) == NULL);
    CGColorSpaceRef other = CGColorSpaceCreateDeviceRGB();
    CGImageRef copy = CGImageCreateCopyWithColorSpace(image, other);
    printf("copy in rgb: %s model %d\n", copy ? "yes" : "NULL", copy ? (int)CGColorSpaceGetModel(CGImageGetColorSpace(copy)) : -1);
    if (copy) CGImageRelease(copy);
    CGColorSpaceRelease(other);

    CGFloat redRange[] = { 250, 255, 0, 5, 0, 5 };
    CGImageRef masked = CGImageCreateWithMaskingColors(image, redRange);
    printf("masked by color: %s bpp %zu alpha info %u\n", masked ? "yes" : "NULL", CGImageGetBitsPerPixel(masked),
           (unsigned)CGImageGetAlphaInfo(masked));
    CGContextRef c = makeContext(2, 1);
    CGContextDrawImage(c, CGRectMake(0, 0, 2, 1), masked);
    printPixel("masked red", c, 0, 0);
    printPixel("kept blue", c, 1, 0);
    CGContextRelease(c);
    CGImageRelease(masked);
    CGImageRelease(image);

    provider = makeProvider(png, sizeof(png));
    CGImageRef decoded = CGImageCreateWithPNGDataProvider(provider, NULL, false, kCGRenderingIntentDefault);
    CGDataProviderRelease(provider);
    printf("png: %zux%zu bpc %zu bpp %zu\n", CGImageGetWidth(decoded), CGImageGetHeight(decoded),
           CGImageGetBitsPerComponent(decoded), CGImageGetBitsPerPixel(decoded));
    c = makeContext(2, 2);
    CGContextDrawImage(c, CGRectMake(0, 0, 2, 2), decoded);
    printPixel("png top left", c, 0, 1);
    printPixel("png top right", c, 1, 1);
    printPixel("png bottom left", c, 0, 0);
    printPixel("png bottom right", c, 1, 0);
    CGContextRelease(c);
    CGImageRelease(decoded);
    const unsigned char notPNG[] = { 1, 2, 3, 4 };
    provider = makeProvider(notPNG, sizeof(notPNG));
    printBool("not a png", CGImageCreateWithPNGDataProvider(provider, NULL, false, kCGRenderingIntentDefault) == NULL);
    CGDataProviderRelease(provider);
}

int main(void) {
    rgb = CGColorSpaceCreateDeviceRGB();
    gray = CGColorSpaceCreateDeviceGray();
    transforms();
    apply();
    copies();
    areas();
    contexts();
    spaces();
    images();
    CGColorSpaceRelease(gray);
    CGColorSpaceRelease(rgb);
    return 0;
}
