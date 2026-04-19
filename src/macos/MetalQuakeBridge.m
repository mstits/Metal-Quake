/**
 * @file MetalQuakeBridge.m
 * @brief C ↔ Swift bridge implementation for Metal Quake.
 */

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

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
    // Cache the last valid FPS reading so the launcher doesn't flash 0
    // between frames (host_frametime is zero on the first frame and for
    // any tick where Host_Frame early-exited).
    extern double host_frametime;
    static float lastFPS = 60.0f;
    if (host_frametime > 0.0) {
        lastFPS = (float)(1.0 / host_frametime);
    }
    return lastFPS;
}

void MQBridge_SaveSettingsToDisk(void) {
    extern void MQ_SaveSettings(const char* path);
    MQ_SaveSettings("id1/metal_quake.cfg");
}

// Simple accessibility getters exposed as plain C so legacy engine files
// like snd_dma.c can query them without pulling in Metal_Settings.h and
// the whole Objective-C/C++ header chain.
int MQ_Subtitles_Enabled(void) {
    MetalQuakeSettings *s = MQ_GetSettings();
    return (s && s->subtitles) ? 1 : 0;
}

void MQBridge_SetLauncherVisible(int visible) {
    _launcherVisible = visible;
    extern keydest_t key_dest;
    
    if (visible) {
        // Showing launcher
        key_dest = key_menu;
        CGDisplayShowCursor(kCGDirectMainDisplay);
        CGAssociateMouseAndMouseCursorPosition(YES); // free mouse
        
        // Show SwiftUI overlay
        if (@available(macOS 26.0, *)) {
            extern NSWindow *gameWindow;
            Class launcherClass = NSClassFromString(@"_TtC18MetalQuakeLauncher28MetalQuakeLauncherController");
            if (launcherClass && gameWindow) {
                id shared = [launcherClass valueForKey:@"shared"];
                [shared performSelector:@selector(showIn:) withObject:gameWindow];
            }
        }
    } else {
        // Hiding launcher
        
        // Remove SwiftUI overlay first
        if (@available(macOS 26.0, *)) {
            Class launcherClass = NSClassFromString(@"_TtC18MetalQuakeLauncher28MetalQuakeLauncherController");
            if (launcherClass) {
                id shared = [launcherClass valueForKey:@"shared"];
                [shared performSelector:@selector(hide)];
            }
        }
        
        // Restore game window as key
        extern NSWindow *gameWindow;
        if (gameWindow) {
            [gameWindow makeKeyAndOrderFront:nil];
            
            // Warp cursor to window center to prevent edge-drift on resume
            NSRect frame = [gameWindow frame];
            CGFloat cx = NSMidX(frame);
            CGFloat cy = NSMidY(frame);
            CGFloat screenHeight = [[NSScreen mainScreen] frame].size.height;
            CGWarpMouseCursorPosition(CGPointMake(cx, screenHeight - cy));
        }
        
        // Recapture mouse for FPS
        key_dest = key_game;
        CGDisplayHideCursor(kCGDirectMainDisplay);
        CGAssociateMouseAndMouseCursorPosition(NO);
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

// Best-effort map discovery. We scan id1/maps (plus -game override dirs
// if present) for .bsp files on the filesystem. Quake's PAK files can
// also carry maps, but the pak loader is C-level and exposing its
// directory requires poking at pak_t internals — filesystem maps cover
// the mod case, which is why this used to be hardcoded.
static void _discoverMaps(void) {
    if (_cachedMaps) return;

    NSMutableSet<NSString*> *found = [NSMutableSet set];
    NSFileManager *fm = [NSFileManager defaultManager];

    NSArray<NSString*> *searchDirs = @[ @"id1/maps" ];
    for (NSString *dir in searchDirs) {
        NSArray<NSString*> *entries = [fm contentsOfDirectoryAtPath:dir error:nil];
        for (NSString *e in entries) {
            if ([[e pathExtension] caseInsensitiveCompare:@"bsp"] == NSOrderedSame) {
                [found addObject:[e stringByDeletingPathExtension]];
            }
        }
    }

    // Always include the standard episode maps — if the user runs with
    // just pak0.pak and no extracted maps on disk, the filesystem scan
    // returns nothing and the launcher would look empty.
    NSArray<NSString*> *pakMaps = @[
        @"start",
        @"e1m1", @"e1m2", @"e1m3", @"e1m4", @"e1m5", @"e1m6", @"e1m7", @"e1m8",
        @"e2m1", @"e2m2", @"e2m3", @"e2m4", @"e2m5", @"e2m6", @"e2m7",
        @"e3m1", @"e3m2", @"e3m3", @"e3m4", @"e3m5", @"e3m6", @"e3m7",
        @"e4m1", @"e4m2", @"e4m3", @"e4m4", @"e4m5", @"e4m6", @"e4m7", @"e4m8",
        @"dm1", @"dm2", @"dm3", @"dm4", @"dm5", @"dm6",
        @"end"
    ];
    for (NSString *m in pakMaps) [found addObject:m];

    NSArray *sorted = [[found allObjects] sortedArrayUsingSelector:@selector(compare:)];
    _cachedMaps = sorted;
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

// ---- Settings Sync: UserDefaults → MetalQuakeSettings → Engine ----

void MQBridge_SyncSettings(void) {
    MetalQuakeSettings *s = MQ_GetSettings();
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    
    // Rendering
    if ([d objectForKey:@"mq_rtEnabled"])      s->rt_enabled       = [d boolForKey:@"mq_rtEnabled"] ? 1 : 0;
    if ([d objectForKey:@"mq_rtQuality"])       s->rt_quality       = (MQRTQuality)[d integerForKey:@"mq_rtQuality"];
    if ([d objectForKey:@"mq_metalfxMode"])     s->metalfx_mode     = (MQMetalFXMode)[d integerForKey:@"mq_metalfxMode"];
    if ([d objectForKey:@"mq_metalfxScale"])    s->metalfx_scale    = (float)[d doubleForKey:@"mq_metalfxScale"];
    if ([d objectForKey:@"mq_neuralDenoise"])   s->neural_denoise   = [d boolForKey:@"mq_neuralDenoise"] ? 1 : 0;
    if ([d objectForKey:@"mq_meshShaders"])     s->mesh_shaders     = [d boolForKey:@"mq_meshShaders"] ? 1 : 0;
    if ([d objectForKey:@"mq_liquidGlassUI"])   s->liquid_glass_ui  = [d boolForKey:@"mq_liquidGlassUI"] ? 1 : 0;
    
    // Audio
    if ([d objectForKey:@"mq_audioMode"])       s->audio_mode       = (MQAudioMode)[d integerForKey:@"mq_audioMode"];
    if ([d objectForKey:@"mq_spatialAudio"])    s->spatial_audio    = [d boolForKey:@"mq_spatialAudio"] ? 1 : 0;
    if ([d objectForKey:@"mq_masterVolume"])    s->master_volume    = (float)[d doubleForKey:@"mq_masterVolume"];
    if ([d objectForKey:@"mq_volumeMusic"])     s->music_volume     = (float)[d doubleForKey:@"mq_volumeMusic"];

    // Input
    if ([d objectForKey:@"mq_mouseSensitivity"]) s->mouse_sensitivity = (float)[d doubleForKey:@"mq_mouseSensitivity"];
    if ([d objectForKey:@"mq_autoAim"])          s->auto_aim         = [d boolForKey:@"mq_autoAim"] ? 1 : 0;
    if ([d objectForKey:@"mq_invertY"])           s->invert_y         = [d boolForKey:@"mq_invertY"] ? 1 : 0;
    if ([d objectForKey:@"mq_rawMouse"])          s->raw_mouse        = [d boolForKey:@"mq_rawMouse"] ? 1 : 0;
    if ([d objectForKey:@"mq_controllerDeadzone"]) s->controller_deadzone = (float)[d doubleForKey:@"mq_controllerDeadzone"];
    if ([d objectForKey:@"mq_hapticIntensity"]) s->haptic_intensity = (float)[d doubleForKey:@"mq_hapticIntensity"];

    // View
    if ([d objectForKey:@"mq_fov"])             s->fov              = (float)[d doubleForKey:@"mq_fov"];
    if ([d objectForKey:@"mq_gamma"])           s->gamma            = (float)[d doubleForKey:@"mq_gamma"];
    if ([d objectForKey:@"mq_hudScale"])        s->hud_scale        = (float)[d doubleForKey:@"mq_hudScale"];
    
    // Intelligence
    if ([d objectForKey:@"mq_coremlTextures"])  s->coreml_textures  = [d boolForKey:@"mq_coremlTextures"] ? 1 : 0;
    if ([d objectForKey:@"mq_neuralBots"])      s->neural_bots      = [d boolForKey:@"mq_neuralBots"] ? 1 : 0;
    
    // Accessibility
    if ([d objectForKey:@"mq_soundSpatializer"]) s->sound_spatializer = [d boolForKey:@"mq_soundSpatializer"] ? 1 : 0;
    if ([d objectForKey:@"mq_highContrastHUD"])  s->high_contrast_hud = [d boolForKey:@"mq_highContrastHUD"] ? 1 : 0;
    if ([d objectForKey:@"mq_subtitles"])        s->subtitles        = [d boolForKey:@"mq_subtitles"] ? 1 : 0;
    
    s->_dirty = 1;
    
    // Apply to engine (syncs cvars like sensitivity, vid_rtx)
    MQ_ApplySettings();
    
    // Sync additional cvars directly
    extern void Cvar_SetValue(char *var_name, float value);
    Cvar_SetValue((char*)"vid_rtx", s->rt_enabled ? 1.0f : 0.0f);
    Cvar_SetValue((char*)"sensitivity", s->mouse_sensitivity);
    // Only set volume if user explicitly configured it (don't zero out audio from unset defaults)
    if ([d objectForKey:@"mq_masterVolume"] && s->master_volume > 0.001f) {
        Cvar_SetValue((char*)"volume", s->master_volume);
    }
    if (s->invert_y) Cvar_SetValue((char*)"m_pitch", -0.022f);
    else Cvar_SetValue((char*)"m_pitch", 0.022f);
}

// ---- Save Slots ----

// Quake's save files live in the gamedir (id1/ or a mod dir). The engine
// uses `save <name>` and `load <name>` where <name> is the filename
// stem; `save quick` writes `id1/quick.sav`. We enumerate those on demand
// so newly-saved games appear without a launcher restart.
static NSMutableArray<NSString*>* _saveSlots = nil;
static NSMutableArray<NSNumber*>* _saveTimestamps = nil;

static void _refreshSaveSlots(void) {
    _saveSlots = [NSMutableArray array];
    _saveTimestamps = [NSMutableArray array];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSString*> *entries = [fm contentsOfDirectoryAtPath:@"id1" error:nil];
    for (NSString *e in entries) {
        if ([[e pathExtension] caseInsensitiveCompare:@"sav"] != NSOrderedSame) continue;
        NSString *stem = [e stringByDeletingPathExtension];
        [_saveSlots addObject:stem];
        NSDictionary *attrs = [fm attributesOfItemAtPath:[@"id1" stringByAppendingPathComponent:e] error:nil];
        NSDate *mod = attrs[NSFileModificationDate];
        [_saveTimestamps addObject:@(mod ? [mod timeIntervalSince1970] : 0.0)];
    }
}

int MQBridge_GetSaveSlotCount(void) {
    _refreshSaveSlots();
    return (int)_saveSlots.count;
}

const char* MQBridge_GetSaveSlotName(int index) {
    if (!_saveSlots || index < 0 || index >= (int)_saveSlots.count) return "";
    return [_saveSlots[index] UTF8String];
}

double MQBridge_GetSaveSlotTimestamp(int index) {
    if (!_saveTimestamps || index < 0 || index >= (int)_saveTimestamps.count) return 0.0;
    return [_saveTimestamps[index] doubleValue];
}

void MQBridge_LoadSaveSlot(int index) {
    if (!_saveSlots || index < 0 || index >= (int)_saveSlots.count) return;
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "load %s\n", [_saveSlots[index] UTF8String]);
    extern void Cbuf_AddText(char *text);
    Cbuf_AddText(cmd);
    _launcherVisible = 0;
}

void MQBridge_SaveCurrentGame(const char* slotName) {
    if (!slotName || !slotName[0]) return;
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "save %s\n", slotName);
    extern void Cbuf_AddText(char *text);
    Cbuf_AddText(cmd);
}

// ---- Demos ----

// Scan id1/ and id1/demos/ for .dem files and return the stem. Keep the
// list across calls but refresh on each GetDemoCount call so recording a
// new demo becomes visible on the next launcher tick.
static NSMutableArray<NSString*>* _demoList = nil;

static void _refreshDemos(void) {
    _demoList = [NSMutableArray array];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSString*> *roots = @[ @"id1", @"id1/demos" ];
    for (NSString *dir in roots) {
        NSArray<NSString*> *entries = [fm contentsOfDirectoryAtPath:dir error:nil];
        for (NSString *e in entries) {
            if ([[e pathExtension] caseInsensitiveCompare:@"dem"] == NSOrderedSame) {
                [_demoList addObject:[e stringByDeletingPathExtension]];
            }
        }
    }
    [_demoList sortUsingSelector:@selector(compare:)];
}

int MQBridge_GetDemoCount(void) {
    _refreshDemos();
    return (int)_demoList.count;
}

const char* MQBridge_GetDemoName(int index) {
    if (!_demoList || index < 0 || index >= (int)_demoList.count) return "";
    return [_demoList[index] UTF8String];
}

void MQBridge_PlayDemo(const char* name) {
    if (!name || !name[0]) return;
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "playdemo %s\n", name);
    extern void Cbuf_AddText(char *text);
    Cbuf_AddText(cmd);
    _launcherVisible = 0;
}

// ---- Server Browser ----

// Quake's netcode maintains `hostcache[]` — an array of servers seen via
// slist/broadcast response. The `slist` console command triggers a LAN
// broadcast; responses arrive async and repopulate the cache. We don't
// re-implement the protocol here; we just poke `slist` and inspect the
// resulting cache.

// hostcache_t + hostcache[] + hostCacheCount are declared by net.h,
// already included transitively via quakedef.h at the top of this file.

void MQBridge_ScanLAN(void) {
    extern void Cbuf_AddText(char *text);
    // `slist` triggers the driver broadcast. Results populate over ~1s.
    Cbuf_AddText("slist\n");
    Con_Printf("LAN scan sent; responses populating…\n");
}

int MQBridge_GetServerCount(void) {
    return hostCacheCount;
}

const char* MQBridge_GetServerAddress(int index) {
    if (index < 0 || index >= hostCacheCount) return "";
    return hostcache[index].cname;
}

const char* MQBridge_GetServerName(int index) {
    if (index < 0 || index >= hostCacheCount) return "";
    return hostcache[index].name;
}

// Toggle a boolean cvar (any non-zero value flips to 0; zero flips to 1).
// Goes through Cvar_SetValue so the cvar subsystem's change hooks fire.
void MQBridge_ToggleCvar(const char *name) {
    if (!name || !name[0]) return;
    cvar_t *v = Cvar_FindVar((char *)name);
    if (!v) return;
    extern void Cvar_SetValue(char *var_name, float value);
    Cvar_SetValue((char *)name, v->value != 0.0f ? 0.0f : 1.0f);
}

void MQBridge_ConnectServer(int index) {
    if (index < 0 || index >= hostCacheCount) return;
    char cmd[128];
    snprintf(cmd, sizeof(cmd), "connect %s\n", hostcache[index].cname);
    extern void Cbuf_AddText(char *text);
    Cbuf_AddText(cmd);
    _launcherVisible = 0;
}

// ---- MetalFX Spatial Upscaler ----

#if __has_include(<MetalFX/MetalFX.h>)
#import <MetalFX/MetalFX.h>
static id<MTLFXSpatialScaler> _mfxSpatialScaler = nil;

void* MQBridge_CreateSpatialUpscaler(void* device, int srcW, int srcH, int dstW, int dstH, unsigned long pixelFormat) {
    if (@available(macOS 13.0, *)) {
        id<MTLDevice> mtlDevice = (__bridge id<MTLDevice>)device;
        MTLFXSpatialScalerDescriptor *desc = [[MTLFXSpatialScalerDescriptor alloc] init];
        desc.inputWidth = srcW;
        desc.inputHeight = srcH;
        desc.outputWidth = dstW;
        desc.outputHeight = dstH;
        desc.colorTextureFormat = (MTLPixelFormat)pixelFormat;
        desc.outputTextureFormat = (MTLPixelFormat)pixelFormat;
        desc.colorProcessingMode = MTLFXSpatialScalerColorProcessingModeLinear;
        
        _mfxSpatialScaler = [desc newSpatialScalerWithDevice:mtlDevice];
        if (_mfxSpatialScaler) {
            Con_Printf("MetalFX: Spatial upscaler %dx%d -> %dx%d\n", srcW, srcH, dstW, dstH);
            return (__bridge_retained void*)_mfxSpatialScaler;
        }
        Con_Printf("MetalFX: Spatial upscaler creation failed\n");
    }
    return NULL;
}

int MQBridge_SpatialUpscale(void* scaler, void* cmdBuf, void* srcTex, void* dstTex) {
    if (@available(macOS 13.0, *)) {
        id<MTLFXSpatialScaler> s = (__bridge id<MTLFXSpatialScaler>)scaler;
        if (!s) return 0;
        s.colorTexture = (__bridge id<MTLTexture>)srcTex;
        s.outputTexture = (__bridge id<MTLTexture>)dstTex;
        [s encodeToCommandBuffer:(__bridge id<MTLCommandBuffer>)cmdBuf];
        return 1;
    }
    return 0;
}
#else
void* MQBridge_CreateSpatialUpscaler(void* d, int sw, int sh, int dw, int dh, unsigned long pf) { return NULL; }
int MQBridge_SpatialUpscale(void* s, void* c, void* src, void* dst) { return 0; }
#endif
