#import <GameController/GameController.h>
#import <CoreHaptics/CoreHaptics.h>
#import <AppKit/AppKit.h>

extern "C" {
    #define __QBOOLEAN_DEFINED__
    typedef int qboolean;
    #define true 1
    #define false 0
    #include "quakedef.h"
    #include "input.h"
    #undef true
    #undef false
}

// ---------------------------------------------------------------------------
// Game Controller State
// ---------------------------------------------------------------------------
static GCController *currentController = nil;
static CHHapticEngine *hapticEngine = nil;
static cvar_t joy_sensitivity = {(char*)"joy_sensitivity", (char*)"1.0", 1}; 

// ---------------------------------------------------------------------------
// Haptics Setup
// ---------------------------------------------------------------------------
static void InitHaptics(GCController *controller) {
    if (@available(macOS 11.0, *)) {
        if (!controller.haptics) return;

        NSError *error = nil;
        // The correct method is createEngineWithLocality:
        hapticEngine = [controller.haptics createEngineWithLocality:GCHapticsLocalityDefault];
        if (!hapticEngine) {
            Con_Printf("Haptics Error: Failed to create engine\n");
            return;
        }

        [hapticEngine startAndReturnError:&error];
        if (error) {
            Con_Printf("Haptics Error: %s\n", [[error localizedDescription] UTF8String]);
        }
    }
}

// ---------------------------------------------------------------------------
// Input Driver Methods
// ---------------------------------------------------------------------------
extern "C" void IN_Init(void) {
    Con_Printf("IN_Init: Initializing GameController...\n");
    Cvar_RegisterVariable(&joy_sensitivity);

    [[NSNotificationCenter defaultCenter] addObserverForName:GCControllerDidConnectNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        GCController *controller = note.object;
        if (!currentController && controller.extendedGamepad) {
            currentController = controller;
            InitHaptics(controller);
            Con_Printf("GameController Connected: %s\n", [controller.vendorName UTF8String]);

            // Set up Adaptive Triggers for DualSense (Right Trigger: Weapon Fire)
            if (@available(macOS 11.3, *)) {
                GCDualSenseGamepad *ds = (GCDualSenseGamepad *)controller.extendedGamepad;
                if ([ds isKindOfClass:[GCDualSenseGamepad class]]) {
                    GCDualSenseAdaptiveTrigger *rt = ds.rightTrigger;
                    // Correct method: setModeFeedbackWithStartPosition:resistiveStrength:
                    [rt setModeFeedbackWithStartPosition:0.2f
                                     resistiveStrength:0.8f];
                }
            }
        }
    }];

    [[NSNotificationCenter defaultCenter] addObserverForName:GCControllerDidDisconnectNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        GCController *controller = note.object;
        if (currentController == controller) {
            currentController = nil;
            if (hapticEngine) {
                [hapticEngine stopWithCompletionHandler:nil];
                hapticEngine = nil;
            }
            Con_Printf("GameController Disconnected.\n");
        }
    }];
}

extern "C" void IN_Shutdown(void) {
    if (hapticEngine) {
        [hapticEngine stopWithCompletionHandler:nil];
        hapticEngine = nil;
    }
}

extern "C" void IN_Commands(void) {
    if (!currentController) return;

    GCExtendedGamepad *pad = currentController.extendedGamepad;
    
    // Right Trigger → Fire
    if (pad.rightTrigger.value > 0.3f) {
        Key_Event(K_CTRL, 1);
    } else {
        Key_Event(K_CTRL, 0);
    }
    
    // Left Trigger → Jump
    if (pad.leftTrigger.value > 0.3f) {
        Key_Event(K_SPACE, 1);
    } else {
        Key_Event(K_SPACE, 0);
    }
    
    // A → Jump (alternate)
    Key_Event(K_SPACE, pad.buttonA.isPressed ? 1 : 0);
    
    // Y → Next weapon (impulse 10)
    {
        static BOOL lastY = NO;
        if (pad.buttonY.isPressed && !lastY) {
            Key_Event('/', 1); Key_Event('/', 0);  // bound to impulse 10
        }
        lastY = pad.buttonY.isPressed;
    }
    
    // B → Swim down / crouch
    Key_Event('c', pad.buttonB.isPressed ? 1 : 0);
    
    // X → Use / open doors (impulse)
    {
        static BOOL lastX = NO;
        if (pad.buttonX.isPressed && !lastX) {
            Key_Event(K_ENTER, 1); Key_Event(K_ENTER, 0);
        }
        lastX = pad.buttonX.isPressed;
    }
    
    // Right Shoulder → Next weapon
    {
        static BOOL lastRB = NO;
        if (pad.rightShoulder.isPressed && !lastRB) {
            Key_Event('/', 1); Key_Event('/', 0);
        }
        lastRB = pad.rightShoulder.isPressed;
    }
    
    // Left Shoulder → Previous weapon
    {
        static BOOL lastLB = NO;
        if (pad.leftShoulder.isPressed && !lastLB) {
            // Quake uses impulse 12 for prev weapon
            Key_Event('.', 1); Key_Event('.', 0);
        }
        lastLB = pad.leftShoulder.isPressed;
    }
    
    // Menu button → Escape (opens/closes menu)
    if (pad.buttonMenu.isPressed) {
        Key_Event(K_ESCAPE, 1);
    } else {
        Key_Event(K_ESCAPE, 0);
    }
    
    // D-pad for movement
    if (pad.dpad.up.isPressed)    Key_Event(K_UPARROW, 1); else Key_Event(K_UPARROW, 0);
    if (pad.dpad.down.isPressed)  Key_Event(K_DOWNARROW, 1); else Key_Event(K_DOWNARROW, 0);
    if (pad.dpad.left.isPressed)  Key_Event(K_LEFTARROW, 1); else Key_Event(K_LEFTARROW, 0);
    if (pad.dpad.right.isPressed) Key_Event(K_RIGHTARROW, 1); else Key_Event(K_RIGHTARROW, 0);
}

extern "C" void IN_Move(usercmd_t *cmd) {
    // --- Mouse freelook (always active) ---
    {
        extern float mouse_x, mouse_y;
        extern cvar_t sensitivity, m_yaw, m_pitch;
        
        mouse_x *= sensitivity.value;
        mouse_y *= sensitivity.value;
        
        // Yaw (horizontal)
        cl.viewangles[YAW] -= m_yaw.value * mouse_x;
        
        // Pitch (vertical) — always freelook, modern FPS standard
        V_StopPitchDrift();
        cl.viewangles[PITCH] += m_pitch.value * mouse_y;
        
        // Clamp pitch
        if (cl.viewangles[PITCH] > 80.0f)  cl.viewangles[PITCH] = 80.0f;
        if (cl.viewangles[PITCH] < -70.0f) cl.viewangles[PITCH] = -70.0f;
        
        mouse_x = mouse_y = 0.0f;
    }
    
    // --- Controller input (additive, if connected) ---
    if (currentController) {
        GCExtendedGamepad *pad = currentController.extendedGamepad;
        
        float lx = pad.leftThumbstick.xAxis.value;
        float ly = pad.leftThumbstick.yAxis.value;
        float rx = pad.rightThumbstick.xAxis.value;
        float ry = pad.rightThumbstick.yAxis.value;
        
        // Left stick for movement
        if (fabs(ly) > 0.1f) cmd->forwardmove += ly * 400.0f * joy_sensitivity.value;
        if (fabs(lx) > 0.1f) cmd->sidemove    += lx * 400.0f * joy_sensitivity.value;
        
        // Right stick for looking
        if (fabs(rx) > 0.1f) cl.viewangles[YAW]   -= rx * 4.0f * joy_sensitivity.value;
        if (fabs(ry) > 0.1f) cl.viewangles[PITCH]  -= ry * 4.0f * joy_sensitivity.value;
    }
}

extern "C" void IN_ClearStates(void) {
    // Clear any virtual buttons if necessary
}

// ---------------------------------------------------------------------------
// Haptic Feedback — Per-weapon fire + damage patterns
// ---------------------------------------------------------------------------

/**
 * Play a haptic transient with given parameters.
 * intensity: 0.0–1.0 (force strength)
 * sharpness: 0.0–1.0 (0=rumble, 1=click)
 * duration:  seconds
 */
static void PlayHapticTransient(float intensity, float sharpness, float duration) {
    if (!hapticEngine) return;
    
    NSError *error = nil;
    CHHapticEventParameter *pIntensity = [[CHHapticEventParameter alloc]
        initWithParameterID:CHHapticEventParameterIDHapticIntensity value:intensity];
    CHHapticEventParameter *pSharpness = [[CHHapticEventParameter alloc]
        initWithParameterID:CHHapticEventParameterIDHapticSharpness value:sharpness];
    CHHapticEvent *event = [[CHHapticEvent alloc]
        initWithEventType:CHHapticEventTypeHapticTransient
               parameters:@[pIntensity, pSharpness]
             relativeTime:0
                 duration:duration];
    
    CHHapticPattern *pattern = [[CHHapticPattern alloc] initWithEvents:@[event] parameters:@[] error:&error];
    if (error) return;
    
    id<CHHapticPatternPlayer> player = [hapticEngine createPlayerWithPattern:pattern error:&error];
    if (error) return;
    
    [player startAtTime:0 error:nil];
}

/**
 * Fire haptic feedback based on current weapon.
 * Called from cl_parse.c when punchangle is received (weapon kick).
 *
 * Weapon IDs (from Quake's IT_* flags):
 *   1=Axe, 2=Shotgun, 4=SuperShotgun, 8=Nailgun,
 *   16=SuperNailgun, 32=GrenadeLauncher, 64=RocketLauncher, 128=Lightning
 */
extern "C" void IN_PlayWeaponHaptic(int weaponId) {
    if (!hapticEngine) return;
    
    float intensity, sharpness, duration;
    
    switch (weaponId) {
        case 1:   // Axe — sharp thud
            intensity = 0.6f; sharpness = 0.9f; duration = 0.05f;
            break;
        case 2:   // Shotgun — medium punch
            intensity = 0.7f; sharpness = 0.6f; duration = 0.08f;
            break;
        case 4:   // Super Shotgun — heavy double-tap
            intensity = 1.0f; sharpness = 0.5f; duration = 0.12f;
            break;
        case 8:   // Nailgun — light rapid
            intensity = 0.3f; sharpness = 0.8f; duration = 0.03f;
            break;
        case 16:  // Super Nailgun — medium rapid
            intensity = 0.4f; sharpness = 0.7f; duration = 0.04f;
            break;
        case 32:  // Grenade Launcher — deep thump
            intensity = 0.9f; sharpness = 0.2f; duration = 0.15f;
            break;
        case 64:  // Rocket Launcher — heavy kick
            intensity = 1.0f; sharpness = 0.3f; duration = 0.18f;
            break;
        case 128: // Lightning Gun — sustained buzz
            intensity = 0.5f; sharpness = 1.0f; duration = 0.02f;
            break;
        default:  // Unknown — generic
            intensity = 0.5f; sharpness = 0.5f; duration = 0.08f;
            break;
    }
    
    PlayHapticTransient(intensity, sharpness, duration);
}

/**
 * Damage haptic feedback — intensity proportional to hit severity.
 * Called from V_ParseDamage in view.c.
 * count: combined armor + blood damage (typically 10–100+)
 */
extern "C" void IN_PlayDamageHaptic(float count) {
    if (!hapticEngine) return;
    
    // Scale: 10 damage = light rumble, 100+ = full slam
    float intensity = fminf(count / 80.0f, 1.0f);
    float sharpness = fminf(count / 120.0f, 0.8f);
    float duration = 0.1f + fminf(count / 200.0f, 0.2f);
    
    PlayHapticTransient(intensity, sharpness, duration);
}

/**
 * Explosion haptic — used for nearby explosions (grenades, rockets).
 * Called from particle/explosion effects or entity events.
 */
extern "C" void IN_PlayExplosionHaptic(float distance) {
    if (!hapticEngine) return;
    
    // Closer explosions = stronger feedback. Distance in Quake units.
    float normalized = fmaxf(1.0f - (distance / 1000.0f), 0.1f);
    PlayHapticTransient(normalized, 0.15f, 0.25f);
}

// Legacy compatibility
extern "C" void IN_PlayHapticFeedback(void) {
    PlayHapticTransient(1.0f, 1.0f, 0.1f);
}

// #17 Force Touch Trackpad Haptics — works when no controller is connected
extern "C" void IN_PlayTrackpadHaptic(int pattern) {
    if (hapticEngine) return; // Controller haptics take priority
    
    // NSHapticFeedbackManager: provides haptic feedback on MacBook Force Touch trackpads
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSHapticFeedbackManager defaultPerformer]
            performFeedbackPattern:(NSHapticFeedbackPattern)pattern
            performanceTime:NSHapticFeedbackPerformanceTimeNow];
    });
}

