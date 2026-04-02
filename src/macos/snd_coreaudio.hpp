#ifndef __SND_COREAUDIO_H__
#define __SND_COREAUDIO_H__

#ifdef __cplusplus
extern "C" {
#endif

#include "quakedef.h"
#include "sound.h"

// Quake Sound Driver Interface
qboolean SNDDMA_Init(void);
int      SNDDMA_GetDMAPos(void);
void     SNDDMA_Shutdown(void);
void     SNDDMA_Submit(void);

#ifdef __cplusplus
}
#endif

#endif // __SND_COREAUDIO_H__
