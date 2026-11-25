/*
 * text.c
 * Conformance of CGFont.h, CGDataProvider.h, CGImageCreate and the text
 * functions of CGContext.h, with a font file both implementations load:
 * fonts/DejaVuSansMono.ttf. Glyphs are rasterized differently by each, so
 * the pixels checked are whether there's ink in generous regions.
 */

#include "conformance.h"
#include <stdlib.h>
#include <string.h>

#ifndef CONFORMANCE_FONTS
#error "conformance.sh defines CONFORMANCE_FONTS, the fonts directory"
#endif

static const char *fontPath = CONFORMANCE_FONTS "/DejaVuSansMono.ttf";

/* Whether any pixel in the rectangle (y up from the bottom, inclusive) has ink. */
static bool hasInk(CGContextRef c, int minX, int minY, int maxX, int maxY) {
    unsigned char *data = CGBitmapContextGetData(c);
    size_t bytesPerRow = CGBitmapContextGetBytesPerRow(c);
    size_t height = CGBitmapContextGetHeight(c);
    for (int y = minY; y <= maxY; y++) {
        for (int x = minX; x <= maxX; x++) {
            unsigned char *pixel = data + (height - 1 - (size_t)y) * bytesPerRow + (size_t)x * 4;
            if (pixel[3] > 64) return true;
        }
    }
    return false;
}

static int released = 0;
static void releaseData(void *info, const void *data, size_t size) { (void)info; (void)data; (void)size; released++; }

typedef struct { const unsigned char *bytes; size_t size; size_t offset; } Reader;
static size_t getBytes(void *info, void *buffer, size_t count) {
    Reader *reader = info;
    size_t left = reader->size - reader->offset;
    size_t n = count < left ? count : left;
    memcpy(buffer, reader->bytes + reader->offset, n);
    reader->offset += n;
    return n;
}
static size_t getBytesAtPosition(void *info, void *buffer, off_t position, size_t count) {
    Reader *reader = info;
    if ((size_t)position >= reader->size) return 0;
    size_t left = reader->size - (size_t)position;
    size_t n = count < left ? count : left;
    memcpy(buffer, reader->bytes + position, n);
    return n;
}

static unsigned char *readFile(const char *path, size_t *size) {
    FILE *file = fopen(path, "rb");
    if (!file) return NULL;
    fseek(file, 0, SEEK_END);
    *size = (size_t)ftell(file);
    fseek(file, 0, SEEK_SET);
    unsigned char *bytes = malloc(*size);
    *size = fread(bytes, 1, *size, file);
    fclose(file);
    return bytes;
}

int main(void) {
    printf("-- providers\n");
    size_t size = 0;
    unsigned char *fontBytes = readFile(fontPath, &size);
    printf("font file read: %s\n", fontBytes ? "true" : "false");

    CGDataProviderRef fromFile = CGDataProviderCreateWithFilename(fontPath);
    printf("from file: %s\n", fromFile ? "made" : "NULL");
    printf("missing file: %s\n", CGDataProviderCreateWithFilename("/nonexistent/font.ttf") ? "made" : "NULL");

    CGDataProviderRef withData = CGDataProviderCreateWithData((void *)0x1234, fontBytes, size, releaseData);
    printf("info: %s\n", CGDataProviderGetInfo(withData) == (void *)0x1234 ? "kept" : "lost");
    Reader sequentialReader = { fontBytes, size, 0 };
    CGDataProviderSequentialCallbacks sequential = { 0, getBytes, NULL, NULL, NULL };
    CGDataProviderRef fromSequence = CGDataProviderCreateSequential(&sequentialReader, &sequential);
    Reader directReader = { fontBytes, size, 0 };
    CGDataProviderDirectCallbacks direct = { 0, NULL, NULL, getBytesAtPosition, NULL };
    CGDataProviderRef fromDirect = CGDataProviderCreateDirect(&directReader, (off_t)size, &direct);

    printf("-- fonts\n");
    CGFontRef font = CGFontCreateWithDataProvider(fromFile);
    printf("font: %s\n", font ? "made" : "NULL");
    CGFontRef fromBytes = CGFontCreateWithDataProvider(withData);
    CGFontRef fromSequential = CGFontCreateWithDataProvider(fromSequence);
    CGFontRef fromDirectFont = CGFontCreateWithDataProvider(fromDirect);
    printf("from bytes, sequence, direct: %d %d %d\n", CGFontGetUnitsPerEm(fromBytes), CGFontGetUnitsPerEm(fromSequential),
           CGFontGetUnitsPerEm(fromDirectFont));
    CGFontRelease(fromBytes);
    CGDataProviderRelease(withData);
    printf("released data: %d\n", released);

    printf("units per em: %d\n", CGFontGetUnitsPerEm(font));
    printf("glyphs: %zu\n", CGFontGetNumberOfGlyphs(font));
    printf("ascent: %d\n", CGFontGetAscent(font));
    printf("descent: %d\n", CGFontGetDescent(font));
    printf("leading: %d\n", CGFontGetLeading(font));
    printf("cap height: %d\n", CGFontGetCapHeight(font));
    printf("x height: %d\n", CGFontGetXHeight(font));
    printRect("bbox", CGFontGetFontBBox(font));
    printf("italic angle: "); printNumber(CGFontGetItalicAngle(font)); printf("\n");
    printf("stem v: "); printNumber(CGFontGetStemV(font)); printf("\n");
    CGGlyph glyphs[] = { 3, 36, 43, 72, 88 };
    int advances[5];
    printBool("advances", CGFontGetGlyphAdvances(font, glyphs, 5, advances));
    printf("advances: %d %d %d %d %d\n", advances[0], advances[1], advances[2], advances[3], advances[4]);
    CGRect boxes[5];
    printBool("bboxes", CGFontGetGlyphBBoxes(font, glyphs, 5, boxes));
    for (int i = 0; i < 5; i++) { char label[32]; snprintf(label, sizeof(label), "bbox %d", glyphs[i]); printRect(label, boxes[i]); }

    printf("-- text\n");
    CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
    CGContextRef c = CGBitmapContextCreate(NULL, 200, 100, 8, 0, rgb, kCGImageAlphaPremultipliedLast);
    printTransform("initial text matrix", CGContextGetTextMatrix(c));
    printPoint("initial text position", CGContextGetTextPosition(c));
    CGContextSetFont(c, font);
    CGContextSetFontSize(c, 40);
    CGContextSetRGBFillColor(c, 0, 0, 0, 1);
    CGGlyph letter = 43;
    CGContextSetTextPosition(c, 10, 30);
    CGContextShowGlyphs(c, &letter, 1);
    printPoint("after one glyph", CGContextGetTextPosition(c));
    printBool("ink above baseline", hasInk(c, 10, 34, 30, 55));
    printBool("ink below baseline", hasInk(c, 0, 0, 199, 26));
    printBool("ink right of glyph", hasInk(c, 40, 0, 199, 99));

    CGGlyph pair[] = { 43, 43 };
    CGContextSetCharacterSpacing(c, 5);
    CGContextShowGlyphsAtPoint(c, 100, 60, pair, 2);
    printPoint("after two glyphs with spacing", CGContextGetTextPosition(c));
    CGContextSetCharacterSpacing(c, 0);

    CGSize stepped[] = { { 30, 0 }, { 30, 5 } };
    CGContextSetTextPosition(c, 0, 0);
    CGContextShowGlyphsWithAdvances(c, pair, stepped, 2);
    printPoint("after advances", CGContextGetTextPosition(c));

    CGPoint placed[] = { { 0, 0 }, { 50, 0 } };
    CGContextSetTextPosition(c, 5, 5);
    CGContextShowGlyphsAtPositions(c, pair, placed, 2);
    printPoint("after positions", CGContextGetTextPosition(c));

    CGContextRef invisible = CGBitmapContextCreate(NULL, 100, 100, 8, 0, rgb, kCGImageAlphaPremultipliedLast);
    CGContextSetFont(invisible, font);
    CGContextSetFontSize(invisible, 40);
    CGContextSetTextDrawingMode(invisible, kCGTextInvisible);
    CGContextSetTextPosition(invisible, 10, 30);
    CGContextShowGlyphs(invisible, &letter, 1);
    printPoint("invisible after", CGContextGetTextPosition(invisible));
    printBool("invisible ink", hasInk(invisible, 0, 0, 99, 99));

    CGContextRef scaled = CGBitmapContextCreate(NULL, 200, 200, 8, 0, rgb, kCGImageAlphaPremultipliedLast);
    CGContextSetFont(scaled, font);
    CGContextSetFontSize(scaled, 20);
    CGContextSetTextMatrix(scaled, CGAffineTransformMakeScale(2, 4));
    printTransform("text matrix", CGContextGetTextMatrix(scaled));
    CGContextSetTextPosition(scaled, 10, 10);
    CGContextShowGlyphs(scaled, &letter, 1);
    printPoint("scaled after", CGContextGetTextPosition(scaled));
    printBool("scaled ink tall", hasInk(scaled, 10, 60, 40, 70));

    CGContextRef stroked = CGBitmapContextCreate(NULL, 100, 100, 8, 0, rgb, kCGImageAlphaPremultipliedLast);
    CGContextSetFont(stroked, font);
    CGContextSetFontSize(stroked, 60);
    CGContextSetTextDrawingMode(stroked, kCGTextStroke);
    CGContextSetRGBStrokeColor(stroked, 0, 0, 0, 1);
    CGContextSetLineWidth(stroked, 2);
    CGContextSetTextPosition(stroked, 20, 20);
    CGContextShowGlyphs(stroked, &letter, 1);
    printBool("stroked ink", hasInk(stroked, 20, 20, 60, 70));

    printf("-- images from data\n");
    unsigned char rgba[] = { 255, 0, 0, 255,   0, 255, 0, 255,
                             0, 0, 255, 255,   128, 128, 128, 128 };
    CGDataProviderRef pixels = CGDataProviderCreateWithData(NULL, rgba, sizeof(rgba), NULL);
    CGImageRef image = CGImageCreate(2, 2, 8, 32, 8, rgb, kCGImageAlphaPremultipliedLast, pixels, NULL, false, kCGRenderingIntentDefault);
    printf("image: %s %zu x %zu provider %s\n", image ? "made" : "NULL", CGImageGetWidth(image), CGImageGetHeight(image),
           CGImageGetDataProvider(image) ? "kept" : "NULL");
    CGContextRef target = CGBitmapContextCreate(NULL, 2, 2, 8, 0, rgb, kCGImageAlphaPremultipliedLast);
    CGContextDrawImage(target, CGRectMake(0, 0, 2, 2), image);
    unsigned char *drawn = CGBitmapContextGetData(target);
    size_t row = CGBitmapContextGetBytesPerRow(target);
    printf("drawn: %d %d %d %d | %d %d %d %d | %d %d %d %d | %d %d %d %d\n",
           drawn[0], drawn[1], drawn[2], drawn[3], drawn[4], drawn[5], drawn[6], drawn[7],
           drawn[row], drawn[row + 1], drawn[row + 2], drawn[row + 3], drawn[row + 4], drawn[row + 5], drawn[row + 6], drawn[row + 7]);

    unsigned char straight[] = { 255, 0, 0, 128 };
    CGDataProviderRef straightPixels = CGDataProviderCreateWithData(NULL, straight, sizeof(straight), NULL);
    CGImageRef straightImage = CGImageCreate(1, 1, 8, 32, 4, rgb, kCGImageAlphaLast, straightPixels, NULL, false, kCGRenderingIntentDefault);
    CGContextRef one = CGBitmapContextCreate(NULL, 1, 1, 8, 0, rgb, kCGImageAlphaPremultipliedLast);
    CGContextDrawImage(one, CGRectMake(0, 0, 1, 1), straightImage);
    unsigned char *onePixel = CGBitmapContextGetData(one);
    printf("straight alpha drawn: %d %d %d %d\n", onePixel[0], onePixel[1], onePixel[2], onePixel[3]);

    CGColorSpaceRef gray = CGColorSpaceCreateDeviceGray();
    unsigned char grays[] = { 0, 64, 128, 255 };
    CGDataProviderRef grayPixels = CGDataProviderCreateWithData(NULL, grays, sizeof(grays), NULL);
    CGImageRef grayImage = CGImageCreate(4, 1, 8, 8, 4, gray, kCGImageAlphaNone, grayPixels, NULL, false, kCGRenderingIntentDefault);
    CGContextRef grayTarget = CGBitmapContextCreate(NULL, 4, 1, 8, 0, rgb, kCGImageAlphaPremultipliedLast);
    CGContextDrawImage(grayTarget, CGRectMake(0, 0, 4, 1), grayImage);
    unsigned char *grayDrawn = CGBitmapContextGetData(grayTarget);
    printf("gray image drawn: %d %d %d %d\n", grayDrawn[0], grayDrawn[4], grayDrawn[8], grayDrawn[12]);

    unsigned char rgb24[] = { 10, 20, 30,  40, 50, 60 };
    CGDataProviderRef rgbPixels = CGDataProviderCreateWithData(NULL, rgb24, sizeof(rgb24), NULL);
    CGImageRef rgbImage = CGImageCreate(2, 1, 8, 24, 6, rgb, kCGImageAlphaNone, rgbPixels, NULL, false, kCGRenderingIntentDefault);
    printf("rgb24 image: %s bpp %zu\n", rgbImage ? "made" : "NULL", CGImageGetBitsPerPixel(rgbImage));
    printf("short provider: %s\n", CGImageCreate(4, 4, 8, 32, 16, rgb, kCGImageAlphaPremultipliedLast, pixels, NULL, false,
                                                 kCGRenderingIntentDefault) ? "made" : "NULL");
    return 0;
}
