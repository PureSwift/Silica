/*
 * path.c
 * Conformance of CGPath.h's functions.
 */

#include "conformance.h"

static void printElement(void *info, const CGPathElement *element) {
    const char *names[] = { "move", "line", "quad", "curve", "close" };
    int points[] = { 1, 1, 2, 3, 0 };
    printf("  %s", names[element->type]);
    for (int i = 0; i < points[element->type]; i++) {
        printf(" ");
        printNumber(element->points[i].x);
        printf(",");
        printNumber(element->points[i].y);
    }
    printf("\n");
    (*(int *)info)++;
}

static void printPath(const char *label, CGPathRef path) {
    int count = 0;
    printf("%s:\n", label);
    CGPathApply(path, &count, printElement);
    printf("  elements: %d\n", count);
    printBool("  empty", CGPathIsEmpty(path));
    printPoint("  current", CGPathGetCurrentPoint(path));
    printRect("  bounds", CGPathGetBoundingBox(path));
    printRect("  path bounds", CGPathGetPathBoundingBox(path));
    CGRect rect = CGRectZero;
    bool isRect = CGPathIsRect(path, &rect);
    printBool("  isRect", isRect);
    if (isRect) printRect("  rect", rect);
}

int main(void) {
    CGAffineTransform shift = CGAffineTransformMakeTranslation(100, 50);

    CGMutablePathRef empty = CGPathCreateMutable();
    printPath("empty", empty);

    CGMutablePathRef lines = CGPathCreateMutable();
    CGPathAddLineToPoint(lines, NULL, 5, 5); /* no current point: ignored */
    CGPathMoveToPoint(lines, NULL, 0, 0);
    CGPathAddLineToPoint(lines, NULL, 10, 0);
    CGPathAddLineToPoint(lines, NULL, 10, 10);
    CGPathCloseSubpath(lines);
    CGPathAddLineToPoint(lines, NULL, 20, 20); /* after a close: from the subpath's start */
    printPath("lines", lines);

    CGMutablePathRef curves = CGPathCreateMutable();
    CGPathMoveToPoint(curves, &shift, 0, 0);
    CGPathAddQuadCurveToPoint(curves, &shift, 10, 20, 20, 0);
    CGPathAddCurveToPoint(curves, &shift, 30, -20, 40, 20, 50, 0);
    printPath("curves", curves);

    const char *rectNames[] = { "rect", "negative rect" };
    CGRect rects[] = { CGRectMake(1, 2, 30, 40), CGRectMake(31, 42, -30, -40) };
    for (int i = 0; i < 2; i++) {
        CGMutablePathRef rect = CGPathCreateMutable();
        CGPathAddRect(rect, NULL, rects[i]);
        printPath(rectNames[i], rect);
        CGPathRelease(rect);
    }
    CGPathRef created = CGPathCreateWithRect(CGRectMake(0, 0, 10, 20), &shift);
    printPath("created rect", created);

    CGPathRef ellipse = CGPathCreateWithEllipseInRect(CGRectMake(0, 0, 40, 20), NULL);
    printPath("ellipse", ellipse);
    CGPathRef rounded = CGPathCreateWithRoundedRect(CGRectMake(0, 0, 40, 20), 5, 4, NULL);
    printPath("rounded rect", rounded);

    const char *arcNames[] = { "arc ccw", "arc cw", "arc full", "arc wrap", "arc same" };
    double arcs[][3] = { { 0, M_PI / 2, 0 }, { 0, M_PI / 2, 1 }, { 0, 2 * M_PI, 0 }, { M_PI, M_PI / 4, 0 }, { 1, 1, 0 } };
    for (int i = 0; i < 5; i++) {
        CGMutablePathRef arc = CGPathCreateMutable();
        CGPathAddArc(arc, NULL, 50, 50, 10, arcs[i][0], arcs[i][1], arcs[i][2] != 0);
        printPath(arcNames[i], arc);
        CGPathRelease(arc);
    }
    CGMutablePathRef relative = CGPathCreateMutable();
    CGPathMoveToPoint(relative, NULL, 0, 0);
    CGPathAddRelativeArc(relative, NULL, 50, 50, 10, 0, -M_PI);
    printPath("relative arc", relative);

    CGMutablePathRef tangent = CGPathCreateMutable();
    CGPathMoveToPoint(tangent, NULL, 0, 0);
    CGPathAddArcToPoint(tangent, NULL, 10, 0, 10, 10, 5);
    printPath("arc to point", tangent);

    CGMutablePathRef polyline = CGPathCreateMutable();
    CGPoint points[] = { { 0, 0 }, { 5, 10 }, { 10, 0 } };
    CGPathAddLines(polyline, NULL, points, 3);
    CGRect pair[] = { CGRectMake(0, 0, 1, 1), CGRectMake(2, 2, 1, 1) };
    CGPathAddRects(polyline, NULL, pair, 2);
    CGPathAddEllipseInRect(polyline, &shift, CGRectMake(0, 0, 4, 4));
    printPath("lines, rects and ellipse", polyline);

    CGMutablePathRef combined = CGPathCreateMutableCopy(lines);
    CGPathAddPath(combined, &shift, curves);
    printPath("combined", combined);
    CGPathRef transformed = CGPathCreateCopyByTransformingPath(curves, &shift);
    printPath("transformed", transformed);

    printBool("equal copy", CGPathEqualToPath(lines, CGPathCreateCopy(lines)));
    printBool("equal other", CGPathEqualToPath(lines, curves));

    CGMutablePathRef ring = CGPathCreateMutable();
    CGPathAddRect(ring, NULL, CGRectMake(0, 0, 30, 30));
    CGPathAddRect(ring, NULL, CGRectMake(10, 10, 10, 10));
    printBool("contains hole winding", CGPathContainsPoint(ring, NULL, CGPointMake(15, 15), false));
    printBool("contains hole even-odd", CGPathContainsPoint(ring, NULL, CGPointMake(15, 15), true));
    printBool("contains outside", CGPathContainsPoint(ring, NULL, CGPointMake(40, 15), false));
    printBool("contains transformed", CGPathContainsPoint(ring, &shift, CGPointMake(-95, -45), false));
    printBool("contains ellipse center", CGPathContainsPoint(ellipse, NULL, CGPointMake(20, 10), false));
    printBool("contains ellipse corner", CGPathContainsPoint(ellipse, NULL, CGPointMake(1, 1), false));

    CGPathRelease(empty);
    CGPathRelease(lines);
    CGPathRelease(curves);
    CGPathRelease(created);
    CGPathRelease(ellipse);
    CGPathRelease(rounded);
    CGPathRelease(relative);
    CGPathRelease(tangent);
    CGPathRelease(polyline);
    CGPathRelease(combined);
    CGPathRelease(transformed);
    CGPathRelease(ring);
    return 0;
}
