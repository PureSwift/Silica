/*
 * constants.c
 * CoreGraphics' constants, exported as data under their own names.
 *
 * Copyright © 2026 PureSwift. All rights reserved.
 */

#include <math.h>
#include "CoreGraphics/CoreGraphics.h"

const CGPoint CGPointZero = { 0, 0 };
const CGSize CGSizeZero = { 0, 0 };
const CGRect CGRectZero = { { 0, 0 }, { 0, 0 } };
const CGRect CGRectNull = { { INFINITY, INFINITY }, { 0, 0 } };
/* Darwin's: half the largest CGFloat in each direction from the origin. */
const CGRect CGRectInfinite = { { -CGFLOAT_MAX / 2, -CGFLOAT_MAX / 2 }, { CGFLOAT_MAX, CGFLOAT_MAX } };
const CGAffineTransform CGAffineTransformIdentity = { 1, 0, 0, 1, 0, 0 };
