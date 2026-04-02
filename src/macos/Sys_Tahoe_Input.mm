/**
 * @file Sys_Tahoe_Input.mm
 * @brief Metal Quake — Unified Input Handler for macOS 17 Tahoe
 *
 * Consolidates all input handling into a single, state-aware module:
 * - Raw mouse input via CGEvent deltas (8kHz capable on M3+ MBP)
 * - Keyboard via Carbon key events (NSEvent dispatch)
 * - Game Controller via GameController.framework
 * - Core Haptics feedback integration
 * - Menu/game state-aware cursor management
 *
 * This module is designed to eventually replace the scattered input logic
 * across sys_macos.m, in_null.c, and in_gamecontroller.mm.
 *
 * @note Phase 1: Architecture + bridge definitions. The actual input
 *       processing currently lives in sys_macos.m and in_null.c.
 *       Phase 2 will migrate all input here.
 *
 * @author Metal Quake Team
 * @date 2026
 */

#import <Cocoa/Cocoa.h>
#import <GameController/GameController.h>
#import <CoreHaptics/CoreHaptics.h>
#import <Carbon/Carbon.h>

#include "Metal_Settings.h"

extern "C" {
    #define __QBOOLEAN_DEFINED__
    typedef int qboolean;
    #define true 1
    #define false 0
    #include "quakedef.h"
    #undef true
    #undef false
}


// ===========================================================================
// Input State
// ===========================================================================

/**
 * @brief Unified input state for the frame.
 *
 * Accumulated between frames, consumed by IN_Move().
 * Mouse deltas are accumulated from CGEvent callbacks.
 * Controller state is polled from GCController.
 */
typedef struct {
    /* Mouse */
    double          mouse_dx;           /**< Accumulated X delta this frame */
    double          mouse_dy;           /**< Accumulated Y delta this frame */
    BOOL            mouse_captured;     /**< Is mouse captured for gameplay? */

    /* Controller */
    float           left_stick_x;       /**< Left stick X (-1.0 to 1.0) */
    float           left_stick_y;       /**< Left stick Y (-1.0 to 1.0) */
    float           right_stick_x;      /**< Right stick X (-1.0 to 1.0) */
    float           right_stick_y;      /**< Right stick Y (-1.0 to 1.0) */
    float           left_trigger;       /**< Left trigger (0.0 to 1.0) */
    float           right_trigger;      /**< Right trigger (0.0 to 1.0) */

    /* State */
    int             key_dest;           /**< Current key destination (game/menu/console) */
    BOOL            window_focused;     /**< Is the game window focused? */
} MQInputState;

/** @brief Global input state singleton. */
static MQInputState g_inputState = {};


// ===========================================================================
// Mouse Input — CGEvent Raw Deltas
// ===========================================================================

/**
 * @brief Process a mouse movement event using CGEvent raw deltas.
 *
 * CGEvent deltas provide unaccelerated, raw hardware movement data.
 * This is critical for FPS mouse look — macOS mouse acceleration
 * creates non-linear response that makes aiming inconsistent.
 *
 * @param event NSEvent containing the mouse movement
 *
 * @note On M3+ MacBook Pro, the trackpad supports 8kHz polling.
 *       CGEvent deltas automatically benefit from higher polling rates.
 */
void MQ_ProcessMouseEvent(NSEvent* event) {
    if (!g_inputState.window_focused) return;
    if (g_inputState.key_dest != 0) return; /* key_game = 0 */

    CGEventRef cgEvent = [event CGEvent];
    if (!cgEvent) return;

    double dx = CGEventGetDoubleValueField(cgEvent, kCGMouseEventDeltaX);
    double dy = CGEventGetDoubleValueField(cgEvent, kCGMouseEventDeltaY);

    g_inputState.mouse_dx += dx;
    g_inputState.mouse_dy += dy;
}

/**
 * @brief Consume accumulated mouse deltas and apply to view angles.
 *
 * Called once per frame from IN_Move(). Applies sensitivity scaling,
 * Y-axis inversion, and pitch clamping.
 *
 * @param cmd The current movement command (for strafe support)
 */
void MQ_ApplyMouseToView(usercmd_t* cmd) {
    MetalQuakeSettings* s = MQ_GetSettings();
    (void)cmd; /* Reserved for strafe mode in Phase 2 */

    float dx = (float)g_inputState.mouse_dx * s->mouse_sensitivity;
    float dy = (float)g_inputState.mouse_dy * s->mouse_sensitivity;

    extern cvar_t m_yaw, m_pitch;

    /* Yaw (horizontal look) */
    cl.viewangles[YAW] -= m_yaw.value * dx;

    /* Pitch (vertical look) with optional inversion */
    float pitchSign = s->invert_y ? -1.0f : 1.0f;
    cl.viewangles[PITCH] += m_pitch.value * dy * pitchSign;

    /* Clamp pitch to prevent gimbal flip */
    if (cl.viewangles[PITCH] > 80.0f)  cl.viewangles[PITCH] = 80.0f;
    if (cl.viewangles[PITCH] < -70.0f) cl.viewangles[PITCH] = -70.0f;

    /* Consume deltas */
    g_inputState.mouse_dx = 0.0;
    g_inputState.mouse_dy = 0.0;
}


// ===========================================================================
// Cursor Management
// ===========================================================================

/**
 * @brief Update cursor visibility based on game state.
 *
 * - In-game (key_game): cursor hidden, captured
 * - Console/menu: cursor visible, released
 * - Window unfocused: cursor visible
 *
 * Called once per frame from the main loop.
 */
void MQ_UpdateCursorState(void) {
    extern keydest_t key_dest;
    static int lastKeyDest = -1;

    int currentDest = (int)key_dest;
    if (currentDest == lastKeyDest) return;
    lastKeyDest = currentDest;

    g_inputState.key_dest = currentDest;

    if (currentDest == 0 /* key_game */ && g_inputState.window_focused) {
        CGDisplayHideCursor(kCGDirectMainDisplay);
        g_inputState.mouse_captured = YES;
    } else {
        CGDisplayShowCursor(kCGDirectMainDisplay);
        g_inputState.mouse_captured = NO;
    }
}


// ===========================================================================
// Controller Input
// ===========================================================================

/**
 * @brief Poll the connected game controller and apply input.
 *
 * Reads stick, trigger, and button state from the first connected
 * GCExtendedGamepad-compatible controller.
 *
 * Stick values within the deadzone are zeroed to prevent drift.
 *
 * @note Controller input is additive with mouse — both can be active
 *       simultaneously for hybrid mouse+controller setups.
 */
void MQ_PollController(void) {
    MetalQuakeSettings* s = MQ_GetSettings();
    GCController* controller = [GCController current];
    if (!controller || !controller.extendedGamepad) return;

    GCExtendedGamepad* gp = controller.extendedGamepad;
    float dz = s->controller_deadzone;

    /* Left stick → movement */
    float lx = gp.leftThumbstick.xAxis.value;
    float ly = gp.leftThumbstick.yAxis.value;
    if (fabsf(lx) < dz) lx = 0.0f;
    if (fabsf(ly) < dz) ly = 0.0f;
    g_inputState.left_stick_x = lx;
    g_inputState.left_stick_y = ly;

    /* Right stick → look */
    float rx = gp.rightThumbstick.xAxis.value;
    float ry = gp.rightThumbstick.yAxis.value;
    if (fabsf(rx) < dz) rx = 0.0f;
    if (fabsf(ry) < dz) ry = 0.0f;
    g_inputState.right_stick_x = rx;
    g_inputState.right_stick_y = ry;

    /* Triggers */
    g_inputState.left_trigger = gp.leftTrigger.value;
    g_inputState.right_trigger = gp.rightTrigger.value;

    /**
     * @todo Phase 2: Apply controller look to viewangles.
     * @todo Phase 2: Map buttons to Quake key events.
     * @todo Phase 2: Set adaptive trigger resistance per-weapon.
     */
}


// ===========================================================================
// Haptic Feedback
// ===========================================================================

/**
 * @brief Fire a haptic feedback pattern.
 *
 * Creates and plays a CHHapticEvent for damage, explosions, or
 * weapon feedback. Uses Core Haptics for DualSense and Mac haptic
 * trackpad support.
 *
 * @param intensity Effect intensity (0.0–1.0)
 * @param sharpness Effect sharpness (0.0=rumble, 1.0=click)
 * @param duration Effect duration in seconds
 *
 * @note Requires CHHapticEngine to be initialized (done in Phase 2).
 */
void MQ_PlayHaptic(float intensity, float sharpness, float duration) {
    (void)intensity; (void)sharpness; (void)duration;

    /**
     * @todo Phase 2: Create CHHapticEngine on first call.
     * @code
     * NSError* error = nil;
     * CHHapticEngine* engine = [[CHHapticEngine alloc] initAndReturnError:&error];
     * [engine startAndReturnError:&error];
     *
     * CHHapticEventParameter* intensityParam =
     *     [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticIntensity
     *                                                  value:intensity];
     * CHHapticEventParameter* sharpnessParam =
     *     [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticSharpness
     *                                                  value:sharpness];
     * CHHapticEvent* event =
     *     [[CHHapticEvent alloc] initWithEventType:CHHapticEventTypeHapticTransient
     *                                  parameters:@[intensityParam, sharpnessParam]
     *                                relativeTime:0
     *                                    duration:duration];
     *
     * CHHapticPattern* pattern = [[CHHapticPattern alloc] initWithEvents:@[event] parameters:@[] error:&error];
     * id<CHHapticPatternPlayer> player = [engine createPlayerWithPattern:pattern error:&error];
     * [player startAtTime:CHHapticTimeImmediate error:&error];
     * @endcode
     */
}


// ===========================================================================
// Frame Integration
// ===========================================================================

/**
 * @brief Per-frame input processing entry point.
 *
 * Called from Host_Frame. Updates:
 * 1. Cursor state (show/hide)
 * 2. Controller polling
 * 3. Mouse deltas → view angles (via IN_Move path)
 *
 * @note Currently, the actual IN_Move call path goes through in_null.c.
 *       Phase 2 will route through MQ_ApplyMouseToView instead.
 */
void MQ_InputFrame(void) {
    MQ_UpdateCursorState();
    MQ_PollController();

    /**
     * @todo Phase 2: Replace in_null.c IN_Move with MQ_ApplyMouseToView.
     * @todo Phase 2: Apply controller right stick to viewangles.
     * @todo Phase 2: Map controller buttons to key events.
     */
}
