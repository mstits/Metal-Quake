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
    extern double host_frametime;
    return (host_frametime > 0.0) ? (float)(1.0 / host_frametime) : 0.0f;
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
    
    // Input
    if ([d objectForKey:@"mq_mouseSensitivity"]) s->mouse_sensitivity = (float)[d doubleForKey:@"mq_mouseSensitivity"];
    if ([d objectForKey:@"mq_autoAim"])          s->auto_aim         = [d boolForKey:@"mq_autoAim"] ? 1 : 0;
    if ([d objectForKey:@"mq_invertY"])           s->invert_y         = [d boolForKey:@"mq_invertY"] ? 1 : 0;
    if ([d objectForKey:@"mq_rawMouse"])          s->raw_mouse        = [d boolForKey:@"mq_rawMouse"] ? 1 : 0;
    if ([d objectForKey:@"mq_controllerDeadzone"]) s->controller_deadzone = (float)[d doubleForKey:@"mq_controllerDeadzone"];
    
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
