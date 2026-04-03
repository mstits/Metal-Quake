typedef struct {
  vec3_t origin;
  vec3_t angles;
  int modelindex;
  int frame;
  int colormap;
  int skin;
  int effects;
} entity_state_t;

#include "cvar.h"
#include "render.h"

#ifdef GLQUAKE
#include "gl_model.h"
#else
#include "model.h"
#include "d_iface.h"
#endif

#include "wad.h"
#include "draw.h"
#include "progs.h"
#include "net.h"
#include "protocol.h"
#include "client.h"
#include "world.h"
#include "server.h"
#include "cmd.h"
#include "sbar.h"
#include "screen.h"
#include "sound.h"

#include "cdaudio.h"
#include "console.h"
#include "crc.h"
#include "input.h"
#include "keys.h"
#include "menu.h"
#include "view.h"

typedef struct {
  char *basedir;
  char *cachedir;
  int argc;
  char **argv;
  void *membase;
  int memsize;
} quakeparms_t;

extern qboolean noclip_anglehack;
extern quakeparms_t host_parms;
extern cvar_t sys_ticrate;
extern cvar_t sys_nostdout;
extern cvar_t developer;
extern qboolean host_initialized;
extern double host_frametime;
extern byte *host_basepal;
extern byte *host_colormap;
extern int host_framecount;
extern double realtime;

void Host_ClearMemory(void);
void Host_ServerFrame(void);
void Host_InitCommands(void);
void Host_Init(quakeparms_t *parms);
void Host_Shutdown(void);
void Host_Error(char *error, ...);
void Host_EndGame(char *message, ...);
void Host_Frame(float time);
void Host_Quit_f(void);
void Host_ClientCommands(char *fmt, ...);
void Host_ShutdownServer(qboolean crash);

extern qboolean msg_suppress_1;
extern int current_skill;
extern qboolean isDedicated;
extern int minimum_memory;
extern cvar_t chase_active;
void Chase_Init(void);
void Chase_Reset(void);
void Chase_Update(void);
