//---------------------------------------------------------------------------------
// shim.c -- runtime support the Embedded Swift object needs but devkitARM's
// newlib does not provide for this target (the same gaps the junkbot-swift
// 3DS port works around).
//---------------------------------------------------------------------------------
#include <3ds.h>
#include <errno.h>
#include <malloc.h>
#include <stdio.h>
#include <stdlib.h>

#include "shim.h"

// Swift's allocator calls posix_memalign; newlib's armv6k/fpu libc only ships
// memalign (declared, but never defined).
int posix_memalign(void **memptr, size_t alignment, size_t size) {
	void *p = memalign(alignment, size);
	if (!p) return ENOMEM;
	*memptr = p;
	return 0;
}

// Embedded Swift's runtime can reference arc4random_buf (e.g. for hashing
// seeds); newlib's arc4random_buf falls through to getentropy, which libctru
// doesn't implement. Supply a small xorshift PRNG as the missing entropy
// source. NOT cryptographically secure -- nothing in this demo relies on
// randomness for anything security-sensitive.
static uint32_t s_entropyState = 0x2545F491u;

int getentropy(void *buf, size_t buflen) {
	uint8_t *p = (uint8_t *)buf;
	for (size_t i = 0; i < buflen; i++) {
		s_entropyState ^= s_entropyState << 13;
		s_entropyState ^= s_entropyState >> 17;
		s_entropyState ^= s_entropyState << 5;
		p[i] = (uint8_t)s_entropyState;
	}
	return 0;
}

int _getentropy_r(void *reent, void *buf, size_t buflen) {
	(void)reent;
	return getentropy(buf, buflen);
}

void ctru_puts(const char *s) {
	printf("%s", s);
}

//---------------------------------------------------------------------------------
// Embedded Swift's String support references the Unicode normalization tables
// (libswiftUnicodeDataTables.a) for non-ASCII comparison and hashing. The
// prebuilt armv6 library is soft-float and cannot link against the 3DS's
// hard-float ABI, so trap instead: ASCII-only string operations (all this
// port performs) never reach these entry points.
//---------------------------------------------------------------------------------
#define SILICA_UNICODE_STUB(name) \
	void name(void) { \
		ctru_puts("fatal: Unicode normalization unavailable (" #name ")\n"); \
		abort(); \
	}

SILICA_UNICODE_STUB(_swift_stdlib_getNormData)
SILICA_UNICODE_STUB(_swift_stdlib_getComposition)
SILICA_UNICODE_STUB(_swift_stdlib_getDecompositionEntry)
SILICA_UNICODE_STUB(_swift_stdlib_nfd_decompositions)
