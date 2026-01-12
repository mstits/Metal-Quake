/* header */
#define QUAKE_GAME
#define VERSION 1.09
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "common.h"
#include "mathlib.h"
#include "bspfile.h"
#include "sys.h"
#include "vid.h"
#include "zone.h"

typedef struct {
  vec3_t origin;
  vec3_t angles;
  int modelindex;
  int frame;
  int colormap;
  int skin;
  int effects;
} entity_state_t;

#include "client.h"
#include "cmd.h"
#include "cvar.h"
#include "draw.h"
#include "net.h"
#include "progs.h"
#include "protocol.h"
#include "render.h"
#include "sbar.h"
#include "screen.h"
#include "server.h"
#include "sound.h"
#include "wad.h"

#ifdef GLQUAKE
#include "gl_model.h"
#else
#include "d_iface.h"
#include "model.h"
#endif

#include "cdaudio.h"
#include "console.h"
#include "crc.h"
#include "input.h"
#include "keys.h"
#include "menu.h"
#include "view.h"
#include "world.h"

//=============================================================================

// the host system specifies the base of the directory tree, the
// command line parms passed to the program, and the amount of memory
// available for the program to use

typedef struct {
  char *basedir;
  char *cachedir; // for development over ISDN lines
  int argc;
  char **argv;
  void *membase;
  int memsize;
} quakeparms_t;

//=============================================================================

extern qboolean noclip_anglehack;

//
// host
//
extern quakeparms_t host_parms;

extern cvar_t sys_ticrate;
extern cvar_t sys_nostdout;
extern cvar_t developer;

extern qboolean host_initialized; // true if into command execution
extern double host_frametime;
extern byte *host_basepal;
extern byte *host_colormap;
extern int host_framecount; // incremented every frame, never reset
extern double realtime;     // not bounded in any way, changed at
                            // start of every frame, never reset

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

extern qboolean
    msg_suppress_1;       // suppresses resolution and cache size console output
                          //  an fullscreen DIB focus gain/loss
extern int current_skill; // skill level for currently loaded level (in case
                          //  the user changes the cvar while the level is
                          //  running, this reflects the level actually in use)

extern qboolean isDedicated;

extern int minimum_memory;

//
// chase
//
extern cvar_t chase_active;

void Chase_Init(void);
void Chase_Reset(void);
void Chase_Update(void);
