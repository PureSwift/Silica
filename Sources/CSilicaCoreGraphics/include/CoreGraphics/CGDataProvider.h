/*
 * CGDataProvider.h
 * Silica's CoreGraphics: data providers.
 *
 * Copyright © 2026 PureSwift. All rights reserved.
 */

#ifndef SILICA_CGDATAPROVIDER_H
#define SILICA_CGDATAPROVIDER_H

#include <sys/types.h>
#include "CGBase.h"

CG_EXTERN_C_BEGIN
CG_ASSUME_NONNULL_BEGIN

#if defined(__swift__)
#define CGDataProviderRef SilicaCGDataProviderRef
#endif

typedef struct CGDataProvider *CGDataProviderRef;

typedef size_t (*CGDataProviderGetBytesCallback)(void * CG_NULLABLE info, void *buffer, size_t count);
typedef off_t (*CGDataProviderSkipForwardCallback)(void * CG_NULLABLE info, off_t count);
typedef void (*CGDataProviderRewindCallback)(void * CG_NULLABLE info);
typedef void (*CGDataProviderReleaseInfoCallback)(void * CG_NULLABLE info);

struct CGDataProviderSequentialCallbacks {
    unsigned int version;
    CGDataProviderGetBytesCallback CG_NULLABLE getBytes;
    CGDataProviderSkipForwardCallback CG_NULLABLE skipForward;
    CGDataProviderRewindCallback CG_NULLABLE rewind;
    CGDataProviderReleaseInfoCallback CG_NULLABLE releaseInfo;
};
typedef struct CGDataProviderSequentialCallbacks CGDataProviderSequentialCallbacks;

typedef const void * CG_NULLABLE (*CGDataProviderGetBytePointerCallback)(void * CG_NULLABLE info);
typedef void (*CGDataProviderReleaseBytePointerCallback)(void * CG_NULLABLE info, const void *pointer);
typedef size_t (*CGDataProviderGetBytesAtPositionCallback)(void * CG_NULLABLE info, void *buffer, off_t pos, size_t cnt);

struct CGDataProviderDirectCallbacks {
    unsigned int version;
    CGDataProviderGetBytePointerCallback CG_NULLABLE getBytePointer;
    CGDataProviderReleaseBytePointerCallback CG_NULLABLE releaseBytePointer;
    CGDataProviderGetBytesAtPositionCallback CG_NULLABLE getBytesAtPosition;
    CGDataProviderReleaseInfoCallback CG_NULLABLE releaseInfo;
};
typedef struct CGDataProviderDirectCallbacks CGDataProviderDirectCallbacks;

typedef void (*CGDataProviderReleaseDataCallback)(void * CG_NULLABLE info, const void *data, size_t size);

CG_EXTERN CFTypeID CGDataProviderGetTypeID(void);

/* The bytes are read from the callbacks when the provider is made. */
CG_EXTERN CGDataProviderRef CG_NULLABLE CGDataProviderCreateSequential(void * CG_NULLABLE info,
                                                                       const CGDataProviderSequentialCallbacks * CG_NULLABLE callbacks);
CG_EXTERN CGDataProviderRef CG_NULLABLE CGDataProviderCreateDirect(void * CG_NULLABLE info, off_t size,
                                                                   const CGDataProviderDirectCallbacks * CG_NULLABLE callbacks);
/* The data is used where it is, until `releaseData` is called with it when
 * the provider goes. */
CG_EXTERN CGDataProviderRef CG_NULLABLE CGDataProviderCreateWithData(void * CG_NULLABLE info, const void * CG_NULLABLE data, size_t size,
                                                                     CGDataProviderReleaseDataCallback CG_NULLABLE releaseData);
/* The file is read when the provider is made. */
CG_EXTERN CGDataProviderRef CG_NULLABLE CGDataProviderCreateWithFilename(const char * CG_NULLABLE filename);
CG_EXTERN CGDataProviderRef CG_NULLABLE CGDataProviderCreateWithCFData(CFDataRef CG_NULLABLE data);
CG_EXTERN CGDataProviderRef CG_NULLABLE CGDataProviderCreateWithURL(CFURLRef CG_NULLABLE url);

CG_EXTERN CGDataProviderRef CG_NULLABLE CGDataProviderRetain(CGDataProviderRef CG_NULLABLE provider);
CG_EXTERN void CGDataProviderRelease(CGDataProviderRef CG_NULLABLE provider);

CG_EXTERN CFDataRef CG_NULLABLE CGDataProviderCopyData(CGDataProviderRef CG_NULLABLE provider);
CG_EXTERN void * CG_NULLABLE CGDataProviderGetInfo(CGDataProviderRef CG_NULLABLE provider);

CG_ASSUME_NONNULL_END
CG_EXTERN_C_END

#endif /* SILICA_CGDATAPROVIDER_H */
