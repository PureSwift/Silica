/*
 * conformance.h
 * Printing for the conformance programs: each prints what CoreGraphics
 * returns, so the output from Apple's framework and from libCoreGraphics
 * can be compared line by line.
 */

#ifndef SILICA_CONFORMANCE_H
#define SILICA_CONFORMANCE_H

#include <CoreGraphics/CoreGraphics.h>
#include <math.h>
#include <stdio.h>

/* Six significant digits: what the implementations agree to, past
 * differences in rounding. Values within rounding of zero print as 0. */
static inline void printNumber(double value) {
    if (fabs(value) < 1e-9) { printf("0"); return; }
    if (isinf(value)) { printf(value > 0 ? "inf" : "-inf"); return; }
    if (fabs(value) > 1e300) { printf(value > 0 ? "huge" : "-huge"); return; }
    printf("%.6g", value);
}

static inline void printRect(const char *label, CGRect rect) {
    printf("%s: ", label);
    printNumber(rect.origin.x); printf(" ");
    printNumber(rect.origin.y); printf(" ");
    printNumber(rect.size.width); printf(" ");
    printNumber(rect.size.height); printf("\n");
}

static inline void printPoint(const char *label, CGPoint point) {
    printf("%s: ", label);
    printNumber(point.x); printf(" ");
    printNumber(point.y); printf("\n");
}

static inline void printSize(const char *label, CGSize size) {
    printf("%s: ", label);
    printNumber(size.width); printf(" ");
    printNumber(size.height); printf("\n");
}

static inline void printTransform(const char *label, CGAffineTransform t) {
    printf("%s: ", label);
    printNumber(t.a); printf(" "); printNumber(t.b); printf(" ");
    printNumber(t.c); printf(" "); printNumber(t.d); printf(" ");
    printNumber(t.tx); printf(" "); printNumber(t.ty); printf("\n");
}

static inline void printBool(const char *label, bool value) {
    printf("%s: %s\n", label, value ? "true" : "false");
}

#endif
