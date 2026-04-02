/**
 * @file MetalQuakeBridge.h
 * @brief C ↔ Swift bridge for Metal Quake settings and engine control.
 *
 * Provides a clean C interface that Swift code can call through the bridging header.
 * This allows the SwiftUI launcher to read/write engine settings and control the game.
 */

#ifndef METALQUAKE_BRIDGE_H
#define METALQUAKE_BRIDGE_H

#include "Metal_Settings.h"

#ifdef __cplusplus
extern "C" {
#endif

// ---- Engine Control ----

/**
 * @brief Start a new game on the specified map.
 * @param mapName BSP name without extension (e.g., "e1m1")
 */
void MQBridge_StartMap(const char* mapName);

/**
 * @brief Execute a console command.
 * @param command Quake console command string
 */
void MQBridge_ConsoleCommand(const char* command);

/**
 * @brief Disconnect from the current game.
 */
void MQBridge_Disconnect(void);

/**
 * @brief Check if a game is currently active.
 * @return 1 if in-game, 0 if at menu/disconnected
 */
int MQBridge_IsInGame(void);

/**
 * @brief Get the current map name.
 * @return Static string of current map name, or "" if not in game
 */
const char* MQBridge_GetCurrentMap(void);

/**
 * @brief Get current FPS.
 * @return Frames per second as float
 */
float MQBridge_GetFPS(void);

/**
 * @brief Toggle the launcher overlay visibility.
 * @param visible 1 to show, 0 to hide
 */
void MQBridge_SetLauncherVisible(int visible);

/**
 * @brief Check if launcher is visible.
 */
int MQBridge_IsLauncherVisible(void);

// ---- Settings Access ----

/**
 * @brief Get a copy of current settings for SwiftUI binding.
 */
MetalQuakeSettings MQBridge_GetSettingsCopy(void);

/**
 * @brief Apply settings from SwiftUI back to the engine.
 */
void MQBridge_ApplySettings(MetalQuakeSettings settings);

// ---- Map Discovery ----

/**
 * @brief Get the number of available maps in the pak files.
 */
int MQBridge_GetMapCount(void);

/**
 * @brief Get map name at index.
 * @param index Map index (0 to count-1)
 * @return Static string of map filename
 */
const char* MQBridge_GetMapName(int index);

/**
 * @brief Sync settings from UserDefaults (SwiftUI @AppStorage) to engine.
 * Reads all mq_* keys, writes to MetalQuakeSettings, applies to cvars.
 */
void MQBridge_SyncSettings(void);

/** MetalFX Spatial Upscaler */
void* MQBridge_CreateSpatialUpscaler(void* device, int srcW, int srcH, int dstW, int dstH, unsigned long pixelFormat);
int MQBridge_SpatialUpscale(void* scaler, void* cmdBuf, void* srcTex, void* dstTex);

#ifdef __cplusplus
}
#endif

#endif /* METALQUAKE_BRIDGE_H */
