/**
 * @file Metal_Renderer_Main.cpp
 * @brief MetalQuakeSettings lifecycle — init, apply, save, load.
 *
 * The parallel-command-encoding and multicore BSP work this file once
 * scaffolded has been implemented directly in vid_metal.cpp (see the
 * dispatch_apply blocks in VID_Update). What remains here is the
 * settings singleton and its disk serialization.
 */

#include "Metal_Settings.h"

/* Forward declarations — these come from vid_metal.cpp and will be
 * refactored into this module during Phase 2 integration. */
extern "C" {
    #define __QBOOLEAN_DEFINED__
    typedef int qboolean;
    #define true 1
    #define false 0
    #include "quakedef.h"
    #undef true
    #undef false
}

#include <Foundation/Foundation.hpp>
#include <Metal/Metal.hpp>
#include <QuartzCore/QuartzCore.hpp>
#include <dispatch/dispatch.h>
#include <vector>

// ---------------------------------------------------------------------------
// Settings Implementation
// ---------------------------------------------------------------------------

/** @brief Global settings singleton. */
static MetalQuakeSettings g_settings = {};

MetalQuakeSettings* MQ_GetSettings(void) {
    return &g_settings;
}

/**
 * @brief Initialize settings with hardware-appropriate defaults.
 *
 * Queries the Metal device for GPU family support and configures
 * RT quality, MetalFX mode, and denoise availability accordingly.
 */
void MQ_InitSettings(void) {
    MetalQuakeSettings* s = &g_settings;

    /* Rendering defaults */
    s->rt_enabled       = 1;
    s->rt_quality       = MQ_RT_QUALITY_MEDIUM;
    s->metalfx_mode     = MQ_METALFX_SPATIAL;
    s->metalfx_scale    = 2.0f;
    s->neural_denoise   = 0;
    s->mesh_shaders     = 0;
    s->liquid_glass_ui  = 0;

    /* Resolution defaults */
    s->internal_width   = 320;
    s->internal_height  = 240;
    s->display_width    = 1280;
    s->display_height   = 720;

    /* Audio defaults */
    s->audio_mode       = MQ_AUDIO_COREAUDIO;
    s->spatial_audio    = 0;
    s->master_volume    = 0.7f;
    s->music_volume     = 0.5f;

    /* Input defaults */
    s->mouse_sensitivity = 3.0f;
    s->auto_aim          = 1;
    s->invert_y          = 0;
    s->raw_mouse         = 1;
    s->controller_deadzone = 0.15f;
    s->haptic_intensity  = 1.0f;

    /* View defaults */
    s->fov               = 90.0f;
    s->gamma             = 1.0f;
    s->hud_scale         = 1.0f;

    /* Intelligence defaults.
       `neural_bots` is retained in the struct for config-file forward-
       compatibility but no longer surfaces in the launcher — implementing
       neural monster AI would be a full engine rewrite. coreml_textures
       gates the MPSGraph atlas upscaler. */
    s->coreml_textures  = 0;
    s->neural_bots      = 0;

    /* Accessibility defaults.
       `sound_spatializer` is retained for compat; the visual direction
       overlay it gated was removed when the ecosystem module lost its
       never-attached NSView. high_contrast_hud and subtitles are live. */
    s->sound_spatializer   = 0;
    s->high_contrast_hud   = 0;
    s->subtitles           = 0;

    /* Post-Processing defaults */
    s->crt_mode            = 0;
    s->ssao_enabled        = 0;
    s->chromatic_aberration = 0;
    s->edr_enabled         = 0;
    s->underwater_fx       = 1;  // ON by default — replaces legacy D_WarpScreen

    s->_dirty = 0;
}

/**
 * @brief Apply settings to the live engine.
 *
 * Called after any setting changes. Propagates values to the
 * appropriate Quake cvars and Metal pipeline configuration.
 */
extern "C" void Cvar_SetValue(char* var_name, float value);

void MQ_ApplySettings(void) {
    MetalQuakeSettings* s = &g_settings;

    /* Sync to Quake cvars */
    Cvar_SetValue((char*)"sensitivity", s->mouse_sensitivity);
    Cvar_SetValue((char*)"sv_aim", s->auto_aim ? 0.93f : 1.0f);
    Cvar_SetValue((char*)"vid_rtx", s->rt_enabled ? 1.0f : 0.0f);

    /* View cvars — these all exist in legacy Quake and are hot-reloadable. */
    if (s->fov >= 10.0f && s->fov <= 170.0f)
        Cvar_SetValue((char*)"fov", s->fov);
    if (s->gamma >= 0.3f && s->gamma <= 2.0f)
        Cvar_SetValue((char*)"gamma", s->gamma);

    /* Audio split — `volume` is SFX master in Quake, `bgmvolume` is CD/music. */
    if (s->master_volume >= 0.0f && s->master_volume <= 1.0f)
        Cvar_SetValue((char*)"volume", s->master_volume);
    if (s->music_volume >= 0.0f && s->music_volume <= 1.0f)
        Cvar_SetValue((char*)"bgmvolume", s->music_volume);

    /* HUD scale maps onto Quake's existing scr_viewsize cvar: the 3D
       viewport shrinks as the HUD effectively grows. scr_viewsize is
       [30..120] (clamped internally), so we interpolate such that
       hud_scale 1.0 gives 120 (full viewport, minimal HUD chrome) and
       hud_scale 3.0 gives 80 (generous HUD strip). */
    if (s->hud_scale >= 1.0f && s->hud_scale <= 3.0f) {
        float viewsize = 120.0f - (s->hud_scale - 1.0f) * 20.0f;
        Cvar_SetValue((char*)"viewsize", viewsize);
    }

    /* Audio mode: PHASE reads audio_mode from settings implicitly via
       MQ_PHASE_IsEnabled(), which is checked in S_Update/S_StartSound.
       No explicit enable/disable call needed — changing the setting is enough.

       Previously this function silently toggled neural_denoise on when
       rt_quality was HIGH+, which surprised users who'd explicitly turned
       denoise off — they'd see the setting snap back on after Apply.
       The choice is now under the user's control exclusively. */

    s->_dirty = 0;
}

/**
 * @brief Save settings to a config file.
 * @param path File path (e.g., "id1/metal_quake.cfg")
 *
 * Serializes all 28 public fields of MetalQuakeSettings. Format is
 * line-oriented "key value" pairs readable by a human and round-trippable
 * through MQ_LoadSettings. Unknown keys are ignored on load, so the file
 * is forward-compatible with additions.
 */
void MQ_SaveSettings(const char* path) {
    MetalQuakeSettings* s = &g_settings;
    FILE* f = fopen(path, "w");
    if (!f) return;

    fprintf(f, "// Metal Quake Settings — Auto-generated (do not edit by hand)\n");

    /* Rendering */
    fprintf(f, "rt_enabled %d\n", s->rt_enabled);
    fprintf(f, "rt_quality %d\n", (int)s->rt_quality);
    fprintf(f, "metalfx_mode %d\n", (int)s->metalfx_mode);
    fprintf(f, "metalfx_scale %.3f\n", s->metalfx_scale);
    fprintf(f, "neural_denoise %d\n", s->neural_denoise);
    fprintf(f, "mesh_shaders %d\n", s->mesh_shaders);
    fprintf(f, "liquid_glass_ui %d\n", s->liquid_glass_ui);

    /* Resolution */
    fprintf(f, "internal_width %d\n", s->internal_width);
    fprintf(f, "internal_height %d\n", s->internal_height);
    fprintf(f, "display_width %d\n", s->display_width);
    fprintf(f, "display_height %d\n", s->display_height);

    /* Audio */
    fprintf(f, "audio_mode %d\n", (int)s->audio_mode);
    fprintf(f, "spatial_audio %d\n", s->spatial_audio);
    fprintf(f, "master_volume %.3f\n", s->master_volume);
    fprintf(f, "music_volume %.3f\n", s->music_volume);

    /* Input */
    fprintf(f, "mouse_sensitivity %.3f\n", s->mouse_sensitivity);
    fprintf(f, "auto_aim %d\n", s->auto_aim);
    fprintf(f, "invert_y %d\n", s->invert_y);
    fprintf(f, "raw_mouse %d\n", s->raw_mouse);
    fprintf(f, "controller_deadzone %.3f\n", s->controller_deadzone);
    fprintf(f, "haptic_intensity %.3f\n", s->haptic_intensity);

    /* View */
    fprintf(f, "fov %.2f\n", s->fov);
    fprintf(f, "gamma %.3f\n", s->gamma);
    fprintf(f, "hud_scale %.3f\n", s->hud_scale);

    /* Intelligence */
    fprintf(f, "coreml_textures %d\n", s->coreml_textures);
    fprintf(f, "neural_bots %d\n", s->neural_bots);

    /* Accessibility */
    fprintf(f, "sound_spatializer %d\n", s->sound_spatializer);
    fprintf(f, "high_contrast_hud %d\n", s->high_contrast_hud);
    fprintf(f, "subtitles %d\n", s->subtitles);

    /* Post-Processing */
    fprintf(f, "crt_mode %d\n", s->crt_mode);
    fprintf(f, "ssao_enabled %d\n", s->ssao_enabled);
    fprintf(f, "chromatic_aberration %d\n", s->chromatic_aberration);
    fprintf(f, "edr_enabled %d\n", s->edr_enabled);
    fprintf(f, "underwater_fx %d\n", s->underwater_fx);

    fclose(f);
}

/**
 * @brief Load settings from a config file.
 * @param path File path (e.g., "id1/metal_quake.cfg")
 *
 * Tolerates missing keys (keeps defaults from MQ_InitSettings) and unknown
 * keys (silently skipped, for forward-compat with newer config files).
 */
void MQ_LoadSettings(const char* path) {
    MetalQuakeSettings* s = &g_settings;
    FILE* f = fopen(path, "r");
    if (!f) return;

    // Read line-by-line so we can skip blank lines and `//` comments
    // without fscanf getting stuck when the `//` token fails to parse
    // as a float (which happened previously and made the loader abort
    // before any field was restored).
    char line[256];
    char key[64];
    float val;
    while (fgets(line, sizeof(line), f)) {
        if (line[0] == '/' || line[0] == '#' || line[0] == '\n' || line[0] == '\0') continue;
        if (sscanf(line, "%63s %f", key, &val) != 2) continue;
        do { /* single-iteration block so the "if/else if" chain below
                can stay written as-is. */
        /* Rendering */
        if      (strcmp(key, "rt_enabled") == 0)           s->rt_enabled = (int)val;
        else if (strcmp(key, "rt_quality") == 0)           s->rt_quality = (MQRTQuality)(int)val;
        else if (strcmp(key, "metalfx_mode") == 0)         s->metalfx_mode = (MQMetalFXMode)(int)val;
        else if (strcmp(key, "metalfx_scale") == 0)        s->metalfx_scale = val;
        else if (strcmp(key, "neural_denoise") == 0)       s->neural_denoise = (int)val;
        else if (strcmp(key, "mesh_shaders") == 0)         s->mesh_shaders = (int)val;
        else if (strcmp(key, "liquid_glass_ui") == 0)      s->liquid_glass_ui = (int)val;

        /* Resolution */
        else if (strcmp(key, "internal_width") == 0)       s->internal_width = (int)val;
        else if (strcmp(key, "internal_height") == 0)      s->internal_height = (int)val;
        else if (strcmp(key, "display_width") == 0)        s->display_width = (int)val;
        else if (strcmp(key, "display_height") == 0)       s->display_height = (int)val;

        /* Audio */
        else if (strcmp(key, "audio_mode") == 0)           s->audio_mode = (MQAudioMode)(int)val;
        else if (strcmp(key, "spatial_audio") == 0)        s->spatial_audio = (int)val;
        else if (strcmp(key, "master_volume") == 0)        s->master_volume = val;
        else if (strcmp(key, "music_volume") == 0)         s->music_volume = val;

        /* Input */
        else if (strcmp(key, "mouse_sensitivity") == 0)    s->mouse_sensitivity = val;
        else if (strcmp(key, "auto_aim") == 0)             s->auto_aim = (int)val;
        else if (strcmp(key, "invert_y") == 0)             s->invert_y = (int)val;
        else if (strcmp(key, "raw_mouse") == 0)            s->raw_mouse = (int)val;
        else if (strcmp(key, "controller_deadzone") == 0)  s->controller_deadzone = val;
        else if (strcmp(key, "haptic_intensity") == 0)     s->haptic_intensity = val;

        /* View */
        else if (strcmp(key, "fov") == 0)                  s->fov = val;
        else if (strcmp(key, "gamma") == 0)                s->gamma = val;
        else if (strcmp(key, "hud_scale") == 0)            s->hud_scale = val;

        /* Intelligence */
        else if (strcmp(key, "coreml_textures") == 0)      s->coreml_textures = (int)val;
        else if (strcmp(key, "neural_bots") == 0)          s->neural_bots = (int)val;

        /* Accessibility */
        else if (strcmp(key, "sound_spatializer") == 0)    s->sound_spatializer = (int)val;
        else if (strcmp(key, "high_contrast_hud") == 0)    s->high_contrast_hud = (int)val;
        else if (strcmp(key, "subtitles") == 0)            s->subtitles = (int)val;

        /* Post-Processing */
        else if (strcmp(key, "crt_mode") == 0)             s->crt_mode = (int)val;
        else if (strcmp(key, "ssao_enabled") == 0)         s->ssao_enabled = (int)val;
        else if (strcmp(key, "chromatic_aberration") == 0) s->chromatic_aberration = (int)val;
        else if (strcmp(key, "edr_enabled") == 0)          s->edr_enabled = (int)val;
        else if (strcmp(key, "underwater_fx") == 0)        s->underwater_fx = (int)val;
        /* unknown key: silently ignored for forward-compat */
        } while (0);
    }

    fclose(f);
    s->_dirty = 1;
}
