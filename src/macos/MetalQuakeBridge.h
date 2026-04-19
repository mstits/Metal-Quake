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

/**
 * @brief Persist the current engine settings struct to
 * `id1/metal_quake.cfg` so choices survive a hard quit or crash. Called
 * from the launcher's Apply & Resume path and from the in-game Video
 * Options menu's Apply row.
 */
void MQBridge_SaveSettingsToDisk(void);

// ---- Save Slots ----

/** Number of save files currently on disk. */
int MQBridge_GetSaveSlotCount(void);

/** Save slot display name for index (e.g. "s0" → "Save 1"). */
const char* MQBridge_GetSaveSlotName(int index);

/** Save slot modification timestamp (unix epoch seconds); 0 if missing. */
double MQBridge_GetSaveSlotTimestamp(int index);

/** Load a save by slot index. */
void MQBridge_LoadSaveSlot(int index);

/** Save the current game to a new slot with the given base name. */
void MQBridge_SaveCurrentGame(const char* slotName);

// ---- Demos ----

/** Number of .dem files currently on disk (id1/demos + id1 root). */
int MQBridge_GetDemoCount(void);

/** Demo filename for index (without .dem). */
const char* MQBridge_GetDemoName(int index);

/** Start playback of the given demo. */
void MQBridge_PlayDemo(const char* name);

// ---- Server Browser ----

/**
 * @brief Send a broadcast server-query packet on the LAN. Non-blocking;
 * responses populate the internal server list which MQBridge_GetServer*
 * inspectors read. Call once when the user opens the server browser tab.
 */
void MQBridge_ScanLAN(void);

/** Number of servers discovered by the most recent scan. */
int MQBridge_GetServerCount(void);

/** Server address as a string, e.g. "192.168.1.5:27500". */
const char* MQBridge_GetServerAddress(int index);

/** Server's advertised hostname (from the hostcache), if any. */
const char* MQBridge_GetServerName(int index);

/** Connect to the server at index. */
void MQBridge_ConnectServer(int index);

/**
 * @brief Toggle a boolean cvar between 0 and 1 regardless of current value.
 * @param name console-visible cvar name, e.g. "vid_fullscreen"
 */
void MQBridge_ToggleCvar(const char *name);

/** MetalFX Spatial Upscaler */
void* MQBridge_CreateSpatialUpscaler(void* device, int srcW, int srcH, int dstW, int dstH, unsigned long pixelFormat);
int MQBridge_SpatialUpscale(void* scaler, void* cmdBuf, void* srcTex, void* dstTex);

#ifdef __cplusplus
}
#endif

#endif /* METALQUAKE_BRIDGE_H */
