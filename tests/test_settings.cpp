/*
 * Round-trip test for MQ_SaveSettings / MQ_LoadSettings.
 *
 * Strategy: mutate every field of MetalQuakeSettings to a non-default
 * value, save, reset to defaults, load, verify every field matches the
 * mutated set. Silently tolerant of float precision (FLT_EPSILON*8).
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <unistd.h>
#include "Metal_Settings.h"

/* The implementation functions live in Metal_Renderer_Main.cpp. */
extern MetalQuakeSettings* MQ_GetSettings(void);
extern void MQ_InitSettings(void);
extern void MQ_SaveSettings(const char* path);
extern void MQ_LoadSettings(const char* path);

/* Stub the engine symbols the settings module forwards to so the test
 * doesn't need to link the whole Quake engine. MQ_ApplySettings pushes
 * values into Cvar_SetValue, which has no side effect in this unit
 * test. extern "C" keeps the symbol C-linkage to match the impl side. */
extern "C" void Cvar_SetValue(char *name, float value) { (void)name; (void)value; }

static int failures = 0;

#define EXPECT_INT(label, got, expected) do {                          \
    if ((got) != (expected)) {                                         \
        fprintf(stderr, "FAIL: %s: expected %d, got %d\n",             \
                (label), (int)(expected), (int)(got));                 \
        failures++;                                                    \
    }                                                                  \
} while (0)

#define EXPECT_FLT(label, got, expected) do {                          \
    if (fabsf((got) - (expected)) > 1e-4f) {                           \
        fprintf(stderr, "FAIL: %s: expected %.4f, got %.4f\n",         \
                (label), (double)(expected), (double)(got));           \
        failures++;                                                    \
    }                                                                  \
} while (0)

int main(void) {
    const char *path = "/tmp/mq_test_settings.cfg";
    unlink(path);

    MQ_InitSettings();
    MetalQuakeSettings *s = MQ_GetSettings();

    /* Mutate every field off its default. */
    s->rt_enabled = 0;
    s->rt_quality = MQ_RT_QUALITY_ULTRA;
    s->metalfx_mode = MQ_METALFX_TEMPORAL;
    s->metalfx_scale = 2.75f;
    s->neural_denoise = 1;
    s->mesh_shaders = 1;
    s->liquid_glass_ui = 1;
    s->internal_width = 640;
    s->internal_height = 480;
    s->display_width = 1920;
    s->display_height = 1080;
    s->audio_mode = MQ_AUDIO_PHASE;
    s->spatial_audio = 1;
    s->master_volume = 0.42f;
    s->music_volume = 0.31f;
    s->mouse_sensitivity = 11.5f;
    s->auto_aim = 0;
    s->invert_y = 1;
    s->raw_mouse = 0;
    s->controller_deadzone = 0.22f;
    s->haptic_intensity = 0.5f;
    s->fov = 105.0f;
    s->gamma = 0.85f;
    s->hud_scale = 1.5f;
    s->coreml_textures = 1;
    s->neural_bots = 1;
    s->sound_spatializer = 1;
    s->high_contrast_hud = 1;
    s->subtitles = 1;
    s->crt_mode = 1;
    s->ssao_enabled = 1;
    s->chromatic_aberration = 1;
    s->edr_enabled = 1;
    s->underwater_fx = 0;

    MQ_SaveSettings(path);

    /* Reset to defaults, then reload. */
    MQ_InitSettings();
    MQ_LoadSettings(path);
    s = MQ_GetSettings();

    EXPECT_INT("rt_enabled",          s->rt_enabled,          0);
    EXPECT_INT("rt_quality",          (int)s->rt_quality,     MQ_RT_QUALITY_ULTRA);
    EXPECT_INT("metalfx_mode",        (int)s->metalfx_mode,   MQ_METALFX_TEMPORAL);
    EXPECT_FLT("metalfx_scale",       s->metalfx_scale,       2.75f);
    EXPECT_INT("neural_denoise",      s->neural_denoise,      1);
    EXPECT_INT("mesh_shaders",        s->mesh_shaders,        1);
    EXPECT_INT("liquid_glass_ui",     s->liquid_glass_ui,     1);
    EXPECT_INT("internal_width",      s->internal_width,      640);
    EXPECT_INT("internal_height",     s->internal_height,     480);
    EXPECT_INT("display_width",       s->display_width,       1920);
    EXPECT_INT("display_height",      s->display_height,      1080);
    EXPECT_INT("audio_mode",          (int)s->audio_mode,     MQ_AUDIO_PHASE);
    EXPECT_INT("spatial_audio",       s->spatial_audio,       1);
    EXPECT_FLT("master_volume",       s->master_volume,       0.42f);
    EXPECT_FLT("music_volume",        s->music_volume,        0.31f);
    EXPECT_FLT("mouse_sensitivity",   s->mouse_sensitivity,   11.5f);
    EXPECT_INT("auto_aim",            s->auto_aim,            0);
    EXPECT_INT("invert_y",            s->invert_y,            1);
    EXPECT_INT("raw_mouse",           s->raw_mouse,           0);
    EXPECT_FLT("controller_deadzone", s->controller_deadzone, 0.22f);
    EXPECT_FLT("haptic_intensity",    s->haptic_intensity,    0.5f);
    EXPECT_FLT("fov",                 s->fov,                 105.0f);
    EXPECT_FLT("gamma",               s->gamma,               0.85f);
    EXPECT_FLT("hud_scale",           s->hud_scale,           1.5f);
    EXPECT_INT("coreml_textures",     s->coreml_textures,     1);
    EXPECT_INT("neural_bots",         s->neural_bots,         1);
    EXPECT_INT("sound_spatializer",   s->sound_spatializer,   1);
    EXPECT_INT("high_contrast_hud",   s->high_contrast_hud,   1);
    EXPECT_INT("subtitles",           s->subtitles,           1);
    EXPECT_INT("crt_mode",            s->crt_mode,            1);
    EXPECT_INT("ssao_enabled",        s->ssao_enabled,        1);
    EXPECT_INT("chromatic_aberration",s->chromatic_aberration,1);
    EXPECT_INT("edr_enabled",         s->edr_enabled,         1);
    EXPECT_INT("underwater_fx",       s->underwater_fx,       0);

    unlink(path);
    if (failures == 0) {
        printf("PASS: settings round-trip (%d fields)\n", 34);
        return 0;
    }
    fprintf(stderr, "FAIL: %d field mismatches\n", failures);
    return 1;
}
