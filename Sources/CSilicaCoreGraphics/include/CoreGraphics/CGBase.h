/*
 * CGBase.h
 * Silica's CoreGraphics: the definitions every other header uses.
 *
 * Copyright © 2026 PureSwift. All rights reserved.
 */

#ifndef SILICA_CGBASE_H
#define SILICA_CGBASE_H

#include <float.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#if defined(__cplusplus)
#define CG_EXTERN extern "C"
#define CG_EXTERN_C_BEGIN extern "C" {
#define CG_EXTERN_C_END }
#else
#define CG_EXTERN extern
#define CG_EXTERN_C_BEGIN
#define CG_EXTERN_C_END
#endif

#define CG_INLINE static inline

#if defined(__has_feature) && __has_feature(nullability)
#define CG_ASSUME_NONNULL_BEGIN _Pragma("clang assume_nonnull begin")
#define CG_ASSUME_NONNULL_END _Pragma("clang assume_nonnull end")
#define CG_NULLABLE _Nullable
#define CG_NONNULL _Nonnull
#else
#define CG_ASSUME_NONNULL_BEGIN
#define CG_ASSUME_NONNULL_END
#define CG_NULLABLE
#define CG_NONNULL
#endif

/* CGFloat: `double` where pointers are 64 bits, `float` otherwise, as on
 * Darwin. It is a macro, not a typedef, because Swift's C importer treats a
 * typedef named CGFloat specially. */
#if defined(__LP64__) && __LP64__
#define CGFLOAT_TYPE double
#define CGFLOAT_IS_DOUBLE 1
#define CGFLOAT_MIN DBL_MIN
#define CGFLOAT_MAX DBL_MAX
#define CGFLOAT_EPSILON DBL_EPSILON
#else
#define CGFLOAT_TYPE float
#define CGFLOAT_IS_DOUBLE 0
#define CGFLOAT_MIN FLT_MIN
#define CGFLOAT_MAX FLT_MAX
#define CGFLOAT_EPSILON FLT_EPSILON
#endif
#define CGFloat CGFLOAT_TYPE
#define CGFLOAT_DEFINED 1

/* Core Foundation's index and type identifier, where Core Foundation itself
 * isn't included. */
#if !defined(__COREFOUNDATION_CFBASE__)
typedef unsigned long CFTypeID;
typedef long CFIndex;
#endif

#endif /* SILICA_CGBASE_H */
