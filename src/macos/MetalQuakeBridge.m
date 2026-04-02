/**
 * @file MetalQuakeBridge.m
 * @brief C ↔ Swift bridge implementation for Metal Quake.
 */

#import <Foundation/Foundation.h>

// Quake includes
#define __QBOOLEAN_DEFINED__
typedef int qboolean;
#define true 1
#define false 0
#include "quakedef.h"
#undef true
#undef false

#include "MetalQuakeBridge.h"
#include "Metal_Settings.h"

// Settings functions are implemented in Metal_Renderer_Main.cpp
// Bridge just forward-declares and uses them via Metal_Settings.h

static int _launcherVisible = 0;


// ---- Engine Control ----

void MQBridge_StartMap(const char* mapName) {
    if (!mapName || !mapName[0]) return;
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "map %s\n", mapName);
    extern void Cbuf_AddText(char *text);
    Cbuf_AddText(cmd);
    _launcherVisible = 0;
}

void MQBridge_ConsoleCommand(const char* command) {
    if (!command || !command[0]) return;
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "%s\n", command);
    extern void Cbuf_AddText(char *text);
    Cbuf_AddText(cmd);
}

void MQBridge_Disconnect(void) {
    extern void Cbuf_AddText(char *text);
    Cbuf_AddText("disconnect\n");
}

int MQBridge_IsInGame(void) {
    return (cls.state == ca_connected && cls.signon == SIGNONS) ? 1 : 0;
}

const char* MQBridge_GetCurrentMap(void) {
    if (cl.worldmodel && cl.worldmodel->name[0])
        return cl.worldmodel->name;
    return "";
}

float MQBridge_GetFPS(void) {
    extern double host_frametime;
    return (host_frametime > 0.0) ? (float)(1.0 / host_frametime) : 0.0f;
}

void MQBridge_SetLauncherVisible(int visible) {
    _launcherVisible = visible;
    // When showing launcher, show cursor; when hiding, hide it
    if (visible) {
        extern keydest_t key_dest;
        key_dest = key_menu;
    }
}

int MQBridge_IsLauncherVisible(void) {
    return _launcherVisible;
}

MetalQuakeSettings MQBridge_GetSettingsCopy(void) {
    MetalQuakeSettings *s = MQ_GetSettings();
    return *s;
}

void MQBridge_ApplySettings(MetalQuakeSettings settings) {
    MetalQuakeSettings *s = MQ_GetSettings();
    *s = settings;
    s->_dirty = 1;
    MQ_ApplySettings();
}

// ---- Map Discovery ----

static NSArray<NSString*>* _cachedMaps = nil;

static void _discoverMaps(void) {
    if (_cachedMaps) return;
    
    // Known Quake episode maps
    NSMutableArray* maps = [NSMutableArray array];
    const char* knownMaps[] = {
        "start", "e1m1", "e1m2", "e1m3", "e1m4", "e1m5", "e1m6", "e1m7", "e1m8",
        "e2m1", "e2m2", "e2m3", "e2m4", "e2m5", "e2m6", "e2m7",
        "e3m1", "e3m2", "e3m3", "e3m4", "e3m5", "e3m6", "e3m7",
        "e4m1", "e4m2", "e4m3", "e4m4", "e4m5", "e4m6", "e4m7", "e4m8",
        "dm1", "dm2", "dm3", "dm4", "dm5", "dm6",
        "end",
        NULL
    };
    
    for (int i = 0; knownMaps[i]; i++) {
        [maps addObject:[NSString stringWithUTF8String:knownMaps[i]]];
    }
    
    _cachedMaps = [maps copy];
}

int MQBridge_GetMapCount(void) {
    _discoverMaps();
    return (int)[_cachedMaps count];
}

const char* MQBridge_GetMapName(int index) {
    _discoverMaps();
    if (index < 0 || index >= (int)[_cachedMaps count]) return "";
    return [_cachedMaps[index] UTF8String];
}
