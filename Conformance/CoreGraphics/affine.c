/*
 * affine.c
 * Conformance of CGAffineTransform.h's functions.
 */

#include "conformance.h"

int main(void) {
    CGAffineTransform transforms[] = {
        CGAffineTransformIdentity,
        CGAffineTransformMake(1, 2, 3, 4, 5, 6),
        CGAffineTransformMakeTranslation(10, -20),
        CGAffineTransformMakeScale(2, -3),
        CGAffineTransformMakeRotation(M_PI / 6),
        CGAffineTransformMakeRotation(M_PI / 2),
        CGAffineTransformMake(0, 0, 0, 0, 5, 5),
    };
    int count = sizeof(transforms) / sizeof(transforms[0]);
    char label[128];
    CGRect rect = CGRectMake(1, 2, 3, 4);
    for (int i = 0; i < count; i++) {
        CGAffineTransform t = transforms[i];
        printf("-- transform %d\n", i);
        printTransform("t", t);
        printBool("isIdentity", CGAffineTransformIsIdentity(t));
        printTransform("translate", CGAffineTransformTranslate(t, 3, 4));
        printTransform("scale", CGAffineTransformScale(t, 2, 0.5));
        printTransform("rotate", CGAffineTransformRotate(t, M_PI / 3));
        printTransform("invert", CGAffineTransformInvert(t));
        printPoint("point", CGPointApplyAffineTransform(CGPointMake(7, -2), t));
        printSize("size", CGSizeApplyAffineTransform(CGSizeMake(7, -2), t));
        printRect("rect", CGRectApplyAffineTransform(rect, t));
        printRect("null rect", CGRectApplyAffineTransform(CGRectNull, t));
        for (int j = 0; j < count; j++) {
            snprintf(label, sizeof(label), "concat %d", j); printTransform(label, CGAffineTransformConcat(t, transforms[j]));
            snprintf(label, sizeof(label), "equal %d", j); printBool(label, CGAffineTransformEqualToTransform(t, transforms[j]));
        }
    }
    printTransform("identity", CGAffineTransformIdentity);
    return 0;
}
