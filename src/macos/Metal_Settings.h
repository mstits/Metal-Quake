/**
 * @file Metal_Settings.h
 * @brief Metal Quake — Toggleable Feature Configuration
 *
 * Central configuration struct for all modern engine features.
 * Every high-end feature is toggleable from the Modern Settings menu.
 * This header is included by both C++ renderer code and the SwiftUI bridge.
 *
 * @note All settings are hot-reloadable at runtime via the settings menu.
 * @author Metal Quake Team
 * @date 2026
 */

#ifndef METAL_SETTINGS_H
#define METAL_SETTINGS_H

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief RT quality presets controlling ray count, bounce depth, and resolution.
 */
typedef enum {
    MQ_RT_QUALITY_OFF    = 0, /**< RT disabled, software renderer only */
    MQ_RT_QUALITY_LOW    = 1, /**< 1 shadow ray, no GI bounce, half-res */
    MQ_RT_QUALITY_MEDIUM = 2, /**< 1 shadow ray, 1 GI bounce, full internal res */
    MQ_RT_QUALITY_HIGH   = 3, /**< 2 shadow rays, 1 GI bounce, full res + denoise */
    MQ_RT_QUALITY_ULTRA  = 4  /**< 4 shadow rays, 2 GI bounces, full res + denoise */
} MQRTQuality;

/**
 * @brief MetalFX upscaling modes.
 */
typedef enum {
    MQ_METALFX_OFF      = 0, /**< No upscaling, native resolution */
    MQ_METALFX_SPATIAL  = 1, /**< Spatial upscaling (single frame) */
    MQ_METALFX_TEMPORAL = 2  /**< Temporal upscaling (motion vectors required) */
} MQMetalFXMode;

/**
 * @brief PHASE audio modes.
 */
typedef enum {
    MQ_AUDIO_COREAUDIO = 0, /**< Legacy Core Audio direct output */
    MQ_AUDIO_PHASE     = 1  /**< PHASE spatial engine with BSP occlusion */
} MQAudioMode;

/**
 * @brief Central settings struct for all Metal Quake features.
 *
 * Every field is runtime-modifiable. The renderer reads this struct
 * each frame to determine pipeline configuration.
 *
 * @note Thread-safe reads are guaranteed via atomic flag on dirty bit.
 */
typedef struct {
    /* ---- Rendering ---- */
    int             rt_enabled;         /**< Master RT toggle (0=off, 1=on) */
    MQRTQuality     rt_quality;         /**< RT quality preset */
    MQMetalFXMode   metalfx_mode;       /**< MetalFX upscaling mode */
    float           metalfx_scale;      /**< MetalFX scale factor (1.0–4.0) */
    int             neural_denoise;     /**< Neural denoiser toggle (0/1) */
    int             mesh_shaders;       /**< Mesh shader toggle (0/1, M3+ only) */
    int             liquid_glass_ui;    /**< Liquid Glass HUD/menus (0/1) */

    /* ---- Resolution ---- */
    int             internal_width;     /**< RT internal render width */
    int             internal_height;    /**< RT internal render height */
    int             display_width;      /**< Final display width */
    int             display_height;     /**< Final display height */

    /* ---- Audio ---- */
    MQAudioMode     audio_mode;         /**< Core Audio vs PHASE */
    int             spatial_audio;      /**< Personalized spatial audio (0/1) */
    float           master_volume;      /**< Master volume (0.0–1.0) */

    /* ---- Input ---- */
    float           mouse_sensitivity;  /**< Mouse sensitivity (1.0–20.0) */
    int             auto_aim;           /**< Auto-aim toggle (0/1) */
    int             invert_y;           /**< Invert Y axis (0/1) */
    int             raw_mouse;          /**< Raw mouse input (0/1) */
    float           controller_deadzone;/**< Controller stick deadzone (0.0–0.5) */

    /* ---- Intelligence ---- */
    int             coreml_textures;    /**< CoreML texture upscaling (0/1) */
    int             neural_bots;        /**< Neural bot AI (0/1) */

    /* ---- Accessibility ---- */
    int             sound_spatializer;  /**< Visual sound spatializer (0/1) */
    int             high_contrast_hud;  /**< High-contrast HUD mode (0/1) */
    int             subtitles;          /**< Event subtitles (0/1) */

    /* ---- Post-Processing ---- */
    int             crt_mode;           /**< CRT scanline filter (0/1) */
    int             ssao_enabled;       /**< Screen-Space Ambient Occlusion (0/1) */
    int             chromatic_aberration; /**< Chromatic aberration (0/1) */
    int             edr_enabled;        /**< Extended Dynamic Range on XDR displays (0/1) */
    int             underwater_fx;      /**< Enhanced underwater distortion (0/1) */

    /* ---- Internal ---- */
    int             _dirty;             /**< Settings changed flag (atomic) */
} MetalQuakeSettings;

/**
 * @brief Get the global settings singleton.
 * @return Pointer to the mutable settings struct.
 */
MetalQuakeSettings* MQ_GetSettings(void);

/**
 * @brief Initialize settings with defaults appropriate for detected hardware.
 *
 * Detects GPU family, ANE availability, and sets appropriate defaults:
 * - M1/M2: RT off, MetalFX spatial, no denoise
 * - M3+: RT medium, MetalFX spatial, denoise available
 * - M3+ Ultra: RT high, MetalFX temporal, denoise on
 */
void MQ_InitSettings(void);

/**
 * @brief Apply current settings to the active renderer.
 *
 * Called after any settings change. Reconfigures:
 * - RT pipeline state
 * - MetalFX scaler creation/mode
 * - Audio engine switch (Core Audio ↔ PHASE)
 * - Input sensitivity
 */
void MQ_ApplySettings(void);

/**
 * @brief Serialize settings to disk.
 * @param path File path to write (typically "id1/metal_quake.cfg")
 */
void MQ_SaveSettings(const char* path);

/**
 * @brief Load settings from disk.
 * @param path File path to read (typically "id1/metal_quake.cfg")
 */
void MQ_LoadSettings(const char* path);

#ifdef __cplusplus
}
#endif

#endif /* METAL_SETTINGS_H */
