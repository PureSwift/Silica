//---------------------------------------------------------------------------------
// shim.h -- C support the Embedded Swift binary needs (same runtime gaps the
// junkbot-swift 3DS port fills; see shim.c).
//---------------------------------------------------------------------------------
#ifndef SILICA_3DS_SHIM_H
#define SILICA_3DS_SHIM_H

#include <stddef.h>

// Missing newlib pieces the Embedded Swift runtime references.
int posix_memalign(void **memptr, size_t alignment, size_t size);
int getentropy(void *buf, size_t buflen);

// printf is variadic (not directly callable from Swift).
void ctru_puts(const char *s);

#endif // SILICA_3DS_SHIM_H
