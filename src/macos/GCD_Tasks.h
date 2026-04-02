/**
 * @file GCD_Tasks.h
 * @brief Metal Quake — Grand Central Dispatch Task Infrastructure
 *
 * Provides a lightweight parallel dispatch layer over GCD for the Quake engine.
 * All parallelism is gated behind MQ_GetSettings()->gcd_enabled.
 *
 * Usage:
 *   MQ_ParallelFor(count, ^(size_t i) { process(items[i]); });
 *   MQ_DispatchGroup(group, queue, ^{ heavy_work(); });
 *
 * Thread Safety:
 *   - Read-only access to world BSP data is safe from any thread
 *   - Write access to entity state requires group barriers
 *   - pr_global_struct is NOT thread-safe — serialize QuakeC execution
 *
 * @author Metal Quake Team
 * @date 2026
 */

#ifndef GCD_TASKS_H
#define GCD_TASKS_H

#include <dispatch/dispatch.h>

#ifdef __cplusplus
extern "C" {
#endif

// ---- Queue Management ----

/**
 * @brief Initialize GCD task queues.
 * Creates concurrent queues sized to available P-core count.
 * Must be called once during engine init (after Sys_Init).
 */
void MQ_TasksInit(void);

/**
 * @brief Shutdown GCD task queues.
 * Waits for all pending work, then releases queues.
 */
void MQ_TasksShutdown(void);

/**
 * @brief Get the high-priority concurrent queue for render/BSP work.
 */
dispatch_queue_t MQ_GetRenderQueue(void);

/**
 * @brief Get the default-priority concurrent queue for physics/misc work.
 */
dispatch_queue_t MQ_GetPhysicsQueue(void);

// ---- Parallel Primitives ----

/**
 * @brief Parallel for-loop using dispatch_apply.
 *
 * Splits 'count' iterations across available cores.
 * Falls back to serial execution if GCD is disabled or count < threshold.
 *
 * @param count   Number of iterations
 * @param stride  Minimum iterations per thread (0 = auto)
 * @param queue   Dispatch queue (NULL = global concurrent)
 * @param block   Block to execute for each index
 */
void MQ_ParallelFor(size_t count, size_t stride,
                    dispatch_queue_t queue,
                    void (^block)(size_t index));

/**
 * @brief Serial fallback for MQ_ParallelFor when GCD is disabled.
 */
static inline void MQ_SerialFor(size_t count, void (^block)(size_t index)) {
    for (size_t i = 0; i < count; i++) block(i);
}

// ---- Group Synchronization ----

/**
 * @brief Create a dispatch group for frame synchronization.
 * @return New dispatch_group_t (caller must release)
 */
dispatch_group_t MQ_CreateGroup(void);

/**
 * @brief Wait for all tasks in a group to complete.
 * @param group  The dispatch group to wait on
 * @param timeout_ms  Maximum wait time in milliseconds (0 = forever)
 * @return 0 on success, non-zero on timeout
 */
long MQ_GroupWait(dispatch_group_t group, unsigned long timeout_ms);

// ---- Engine-Specific Parallel Tasks ----

/**
 * @brief Parallel R_MarkLeaves — mark BSP leaves visible from PVS.
 *
 * Splits the leaf iteration across cores using dispatch_apply.
 * Uses atomic compare-and-swap for thread-safe visframe marking.
 *
 * @param vis        PVS data from Mod_LeafPVS
 * @param numleafs   Number of leaves in worldmodel
 * @param leaves     Pointer to worldmodel->leafs array
 * @param visframecount  Current visibility frame counter
 */
void MQ_ParallelMarkLeaves(unsigned char *vis, int numleafs,
                           void *leaves, int visframecount);

/**
 * @brief Parallel texture atlas pixel copy.
 *
 * Copies texture data into atlas in parallel — each texture is independent.
 *
 * @param atlas_pixels  Destination atlas pixel buffer
 * @param atlas_width   Atlas width in pixels
 * @param entries       Array of atlas entry descriptors
 * @param count         Number of entries
 * @param palette       256-entry palette (index → RGBA)
 */
void MQ_ParallelAtlasCopy(unsigned char *atlas_pixels, int atlas_width,
                          void *entries, int count,
                          unsigned char *palette);

// ---- Runtime Configuration ----

/**
 * @brief Check if GCD parallelism is enabled.
 * Reads from MetalQuakeSettings.
 */
int MQ_IsParallelEnabled(void);

/**
 * @brief Get the number of available performance cores.
 */
int MQ_GetPCoreCount(void);

#ifdef __cplusplus
}
#endif

#endif /* GCD_TASKS_H */
