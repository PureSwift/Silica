/*
 * unimplemented.c
 * What a stub calls: libCoreGraphics' report of a function it lacks.
 *
 * Copyright © 2026 PureSwift. All rights reserved.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "silica_cg_internal.h"

/* Each function is reported once; a short list of names is enough. */
#define SILICA_CG_REPORTED_MAX 64
static const char *reported[SILICA_CG_REPORTED_MAX];
static int reportedCount = 0;

void silica_cg_unimplemented(const char *function) {
    for (int index = 0; index < reportedCount; index++) {
        if (reported[index] == function) {
            return;
        }
    }
    if (reportedCount < SILICA_CG_REPORTED_MAX) {
        reported[reportedCount++] = function;
    }
    fprintf(stderr, "CoreGraphics: %s is not implemented by Silica yet\n", function);
    if (getenv("SILICA_CG_ABORT_ON_UNIMPLEMENTED") != NULL) {
        abort();
    }
}
