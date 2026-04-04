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
static CFMachPortRef g_mouseEventTap = NULL;

static CGEventRef MQ_MouseCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    if (type == kCGEventMouseMoved) {
        if (!g_inputState.window_focused || g_inputState.key_dest != 0) return event;
        
        double dx = CGEventGetDoubleValueField(event, kCGMouseEventDeltaX);
        double dy = CGEventGetDoubleValueField(event, kCGMouseEventDeltaY);
        
        g_inputState.mouse_dx += dx;
        g_inputState.mouse_dy += dy;
    }
    return event;
}

void MQ_ProcessMouseEvent(NSEvent* event) {
    if (!g_mouseEventTap) {
        CGEventMask mask = CGEventMaskBit(kCGEventMouseMoved);
        g_mouseEventTap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap, kCGEventTapOptionListenOnly, mask, MQ_MouseCallback, NULL);
        if (g_mouseEventTap) {
            CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, g_mouseEventTap, 0);
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, kCFRunLoopCommonModes);
            CGEventTapEnable(g_mouseEventTap, true);
            CFRelease(runLoopSource);
        }
    } else {
        return; // Handled by CGEventTap zero-latency callback
    }

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

static struct {
    bool a, b, x, y;
    bool up, down, left, right;
    bool l1, l2, l3;
    bool r1, r2, r3;
    bool menu, options;
} prevControllerState = {0};

extern "C" void Key_Event(int key, qboolean down);

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

    /* Button Mapping */
    auto checkBtn = [](bool& prev, bool curr, int key) {
        if (curr != prev) {
            Key_Event(key, curr);
            prev = curr;
        }
    };

    checkBtn(prevControllerState.a, gp.buttonA.isPressed, K_JOY1);
    checkBtn(prevControllerState.b, gp.buttonB.isPressed, K_JOY2);
    checkBtn(prevControllerState.x, gp.buttonX.isPressed, K_JOY3);
    checkBtn(prevControllerState.y, gp.buttonY.isPressed, K_JOY4);
    
    checkBtn(prevControllerState.l1, gp.leftShoulder.isPressed, K_AUX1);
    checkBtn(prevControllerState.r1, gp.rightShoulder.isPressed, K_AUX2);
    checkBtn(prevControllerState.l2, gp.leftTrigger.isPressed, K_AUX3);
    checkBtn(prevControllerState.r2, gp.rightTrigger.isPressed, K_AUX4);
    
    checkBtn(prevControllerState.up, gp.dpad.up.isPressed, K_UPARROW);
    checkBtn(prevControllerState.down, gp.dpad.down.isPressed, K_DOWNARROW);
    checkBtn(prevControllerState.left, gp.dpad.left.isPressed, K_LEFTARROW);
    checkBtn(prevControllerState.right, gp.dpad.right.isPressed, K_RIGHTARROW);

    if (@available(macOS 11.0, *)) {
        if (gp.buttonOptions) checkBtn(prevControllerState.options, gp.buttonOptions.isPressed, K_ESCAPE);
        if (gp.buttonMenu) checkBtn(prevControllerState.menu, gp.buttonMenu.isPressed, K_ESCAPE);
        if (gp.leftThumbstickButton) checkBtn(prevControllerState.l3, gp.leftThumbstickButton.isPressed, K_AUX5);
        if (gp.rightThumbstickButton) checkBtn(prevControllerState.r3, gp.rightThumbstickButton.isPressed, K_AUX6);
    }
    
    // Adaptive Triggers for DualSense (macOS 11.3+)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability-new"
    if ([controller.physicalInputProfile isKindOfClass:NSClassFromString(@"GCDualSenseGamepad")]) {
        id dualSense = controller.physicalInputProfile;
        id rightTrigger = [dualSense valueForKey:@"rightTrigger"];
        
        // IT_SHOTGUN = 1, IT_SUPER_SHOTGUN = 2, IT_NAILGUN = 3, IT_SUPER_NAILGUN = 4, IT_GRENADE_LAUNCHER = 5, IT_ROCKET_LAUNCHER = 6, IT_LIGHTNING = 7
        // Hardcoding rough resistance based on active weapon: cl.stats[STAT_ACTIVEWEAPON]
        int weapon = cl.stats[STAT_ACTIVEWEAPON];
        
        // Map Quake weapon bitflags to numbers for easier logic
        int wId = 0;
        if (weapon == (1<<0)) wId = 0; // Axe
        else if (weapon == (1<<1)) wId = 1; // Shotgun
        else if (weapon == (1<<2)) wId = 2; // Super Shotgun
        else if (weapon == (1<<3)) wId = 3; // Nailgun
        else if (weapon == (1<<4)) wId = 4; // Super Nailgun
        else if (weapon == (1<<5)) wId = 5; // Grenade Launcher
        else if (weapon == (1<<6)) wId = 6; // Rocket Launcher
        else if (weapon == (1<<7)) wId = 7; // Thunderbolt
        
        if (wId == 1 || wId == 2) {
            // Shotgun / Super Shotgun: heavy pull, sudden break
            [rightTrigger setModeWeaponWithStartPosition:0.2 endPosition:0.8 resistiveStrength:0.8];
        } else if (wId == 3 || wId == 4) {
            // Nailgun / Super Nailgun: continuous machine gun rattle
            [rightTrigger setModeVibrationWithStartPosition:0.1 amplitude:0.5 frequency:10.0];
        } else if (wId == 5 || wId == 6) {
            // Grenade / Rocket Launcher: very heavy pull
            [rightTrigger setModeFeedbackWithStartPosition:0.1 resistiveStrength:1.0];
        } else if (wId == 7) {
            // Lightning Gun: smooth resistance
            [rightTrigger setModeFeedbackWithStartPosition:0.0 resistiveStrength:0.3];
        } else {
            // Axe / Default
            [rightTrigger setModeFeedbackWithStartPosition:0.0 resistiveStrength:0.0];
        }
    }
#pragma clang diagnostic pop
}


// ===========================================================================
// Haptic Feedback
// ===========================================================================

#import <CoreHaptics/CoreHaptics.h>

static CHHapticEngine* g_hapticEngine = nil;
static bool g_hapticEngineStarted = false;

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
 */
void MQ_PlayHaptic(float intensity, float sharpness, float duration) {
    if (@available(macOS 10.15, *)) {
        if (!g_hapticEngine) {
            NSError* error = nil;
            g_hapticEngine = [[CHHapticEngine alloc] initAndReturnError:&error];
            if (!error && g_hapticEngine) {
                [g_hapticEngine startAndReturnError:&error];
                if (!error) g_hapticEngineStarted = true;
            }
        }
        
        if (g_hapticEngineStarted) {
            NSError* error = nil;
            CHHapticEventParameter* intensityParam =
                [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticIntensity
                                                             value:intensity];
            CHHapticEventParameter* sharpnessParam =
                [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticSharpness
                                                             value:sharpness];
            CHHapticEvent* event =
                [[CHHapticEvent alloc] initWithEventType:CHHapticEventTypeHapticTransient
                                             parameters:@[intensityParam, sharpnessParam]
                                           relativeTime:0
                                               duration:duration];
            
            CHHapticPattern* pattern = [[CHHapticPattern alloc] initWithEvents:@[event] parameters:@[] error:&error];
            id<CHHapticPatternPlayer> player = [g_hapticEngine createPlayerWithPattern:pattern error:&error];
            [player startAtTime:CHHapticTimeImmediate error:&error];
        }
    }
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
 */
void MQ_InputFrame(void) {
    MQ_UpdateCursorState();
    MQ_PollController();
}
