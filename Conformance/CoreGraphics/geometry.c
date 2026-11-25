/*
 * geometry.c
 * Conformance of CGGeometry.h's functions.
 */

#include "conformance.h"

int main(void) {
    const char *names[] = { "plain", "negative", "zero", "thin", "null", "infinite", "fractional" };
    CGRect rects[] = {
        CGRectMake(10, 20, 30, 40),
        CGRectMake(10, 20, -30, -40),
        CGRectZero,
        CGRectMake(5, 5, 0, 10),
        CGRectNull,
        CGRectInfinite,
        CGRectMake(0.5, 1.25, 10.3, 2.6),
    };
    int count = sizeof(rects) / sizeof(rects[0]);
    char label[128];

    for (int i = 0; i < count; i++) {
        CGRect r = rects[i];
        printf("-- %s\n", names[i]);
        printf("min/mid/max x: "); printNumber(CGRectGetMinX(r)); printf(" "); printNumber(CGRectGetMidX(r)); printf(" "); printNumber(CGRectGetMaxX(r)); printf("\n");
        printf("min/mid/max y: "); printNumber(CGRectGetMinY(r)); printf(" "); printNumber(CGRectGetMidY(r)); printf(" "); printNumber(CGRectGetMaxY(r)); printf("\n");
        printf("width/height: "); printNumber(CGRectGetWidth(r)); printf(" "); printNumber(CGRectGetHeight(r)); printf("\n");
        printRect("standardize", CGRectStandardize(r));
        printBool("isEmpty", CGRectIsEmpty(r));
        printBool("isNull", CGRectIsNull(r));
        printBool("isInfinite", CGRectIsInfinite(r));
        printRect("inset 2 3", CGRectInset(r, 2, 3));
        printRect("inset -2 -3", CGRectInset(r, -2, -3));
        printRect("inset 100 1", CGRectInset(r, 100, 1));
        printRect("integral", CGRectIntegral(r));
        printRect("offset 1 2", CGRectOffset(r, 1, 2));
        printBool("contains 15 25", CGRectContainsPoint(r, CGPointMake(15, 25)));
        printBool("contains -15 -15", CGRectContainsPoint(r, CGPointMake(-15, -15)));
        printBool("contains min corner", CGRectContainsPoint(r, CGPointMake(CGRectGetMinX(r), CGRectGetMinY(r))));
        printBool("contains max corner", CGRectContainsPoint(r, CGPointMake(CGRectGetMaxX(r), CGRectGetMaxY(r))));
        for (int edge = 0; edge < 4; edge++) {
            CGRect slice, remainder;
            CGRectDivide(r, &slice, &remainder, 7, (CGRectEdge)edge);
            snprintf(label, sizeof(label), "divide edge %d slice", edge); printRect(label, slice);
            snprintf(label, sizeof(label), "divide edge %d remainder", edge); printRect(label, remainder);
        }
        CGRect slice, remainder;
        CGRectDivide(r, &slice, &remainder, 1000, CGRectMinXEdge);
        printRect("divide past slice", slice);
        printRect("divide past remainder", remainder);
        CGRectDivide(r, &slice, &remainder, -5, CGRectMinXEdge);
        printRect("divide negative slice", slice);
        printRect("divide negative remainder", remainder);
        for (int j = 0; j < count; j++) {
            CGRect s = rects[j];
            snprintf(label, sizeof(label), "union %s", names[j]); printRect(label, CGRectUnion(r, s));
            snprintf(label, sizeof(label), "intersection %s", names[j]); printRect(label, CGRectIntersection(r, s));
            snprintf(label, sizeof(label), "intersects %s", names[j]); printBool(label, CGRectIntersectsRect(r, s));
            snprintf(label, sizeof(label), "containsRect %s", names[j]); printBool(label, CGRectContainsRect(r, s));
            snprintf(label, sizeof(label), "equal %s", names[j]); printBool(label, CGRectEqualToRect(r, s));
        }
    }

    printf("-- touching\n");
    CGRect a = CGRectMake(0, 0, 10, 10), b = CGRectMake(10, 0, 10, 10);
    printRect("intersection", CGRectIntersection(a, b));
    printBool("intersects", CGRectIntersectsRect(a, b));
    printBool("equal standardized", CGRectEqualToRect(CGRectMake(0, 0, 10, 10), CGRectMake(10, 10, -10, -10)));
    printBool("point equal", CGPointEqualToPoint(CGPointMake(1, 2), CGPointMake(1, 2)));
    printBool("size equal", CGSizeEqualToSize(CGSizeMake(1, 2), CGSizeMake(2, 1)));
    printRect("zero", CGRectZero);
    printPoint("point zero", CGPointZero);
    printSize("size zero", CGSizeZero);
    return 0;
}
