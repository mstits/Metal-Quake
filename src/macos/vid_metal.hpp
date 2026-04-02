#ifndef __VID_METAL_HPP__
#define __VID_METAL_HPP__

#ifdef __cplusplus
extern "C" {
#endif

// Forward declare vrect_t to avoid including vid.h here
struct vrect_s;
typedef struct vrect_s vrect_t;

void VID_Init(unsigned char *palette);
void VID_Shutdown(void);
void VID_Update(vrect_t *rects);
int  VID_SetMode(int modenum, unsigned char *palette);

#ifdef __cplusplus
}
#endif

#endif // __VID_METAL_HPP__
