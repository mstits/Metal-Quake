#include "quakedef.h"
#import <Carbon/Carbon.h> // For keycodes
#import <Cocoa/Cocoa.h>
#import <GameController/GameController.h>

// Quake Key Mappings
static int keymap[256];

// Gamepad — we keep a weak reference to the most-recently-connected controller.
// All access happens on the main thread (IN_Init / IN_Move are main-thread only).
static GCController *activeController = nil;

cvar_t mouse_sensitivity = {"sensitivity", "3"};
qboolean mouseactive;
int mouse_x, mouse_y;
int old_mouse_x, old_mouse_y;

// Track mouse delta for look
static float accum_mouse_x = 0;
static float accum_mouse_y = 0;

void MapKey(int key, int qkey) {
  if (key >= 0 && key < 256)
    keymap[key] = qkey;
}

void IN_Init(void) {
  int i;
  for (i = 0; i < 256; i++)
    keymap[i] = 0;

  // Standard WASD
  MapKey(kVK_ANSI_W, 'w');
  MapKey(kVK_ANSI_A, 'a');
  MapKey(kVK_ANSI_S, 's');
  MapKey(kVK_ANSI_D, 'd');
  MapKey(kVK_ANSI_Q, 'q');
  MapKey(kVK_ANSI_E, 'e');
  MapKey(kVK_ANSI_R, 'r');
  MapKey(kVK_ANSI_F, 'f');
  MapKey(kVK_ANSI_Z, 'z');
  MapKey(kVK_ANSI_X, 'x');
  MapKey(kVK_ANSI_C, 'c');
  MapKey(kVK_ANSI_V, 'v');

  // All letters for console
  MapKey(kVK_ANSI_B, 'b');
  MapKey(kVK_ANSI_G, 'g');
  MapKey(kVK_ANSI_H, 'h');
  MapKey(kVK_ANSI_I, 'i');
  MapKey(kVK_ANSI_J, 'j');
  MapKey(kVK_ANSI_K, 'k');
  MapKey(kVK_ANSI_L, 'l');
  MapKey(kVK_ANSI_M, 'm');
  MapKey(kVK_ANSI_N, 'n');
  MapKey(kVK_ANSI_O, 'o');
  MapKey(kVK_ANSI_P, 'p');
  MapKey(kVK_ANSI_T, 't');
  MapKey(kVK_ANSI_U, 'u');
  MapKey(kVK_ANSI_Y, 'y');

  // Arrows
  MapKey(kVK_UpArrow, K_UPARROW);
  MapKey(kVK_DownArrow, K_DOWNARROW);
  MapKey(kVK_LeftArrow, K_LEFTARROW);
  MapKey(kVK_RightArrow, K_RIGHTARROW);

  // Modifiers
  MapKey(kVK_Space, K_SPACE);
  MapKey(kVK_Return, K_ENTER);
  MapKey(kVK_Escape, K_ESCAPE);
  MapKey(kVK_Control, K_CTRL);
  MapKey(kVK_Shift, K_SHIFT);
  MapKey(kVK_Option, K_ALT);
  MapKey(kVK_Command, K_ALT);

  // Numbers
  MapKey(kVK_ANSI_1, '1');
  MapKey(kVK_ANSI_2, '2');
  MapKey(kVK_ANSI_3, '3');
  MapKey(kVK_ANSI_4, '4');
  MapKey(kVK_ANSI_5, '5');
  MapKey(kVK_ANSI_6, '6');
  MapKey(kVK_ANSI_7, '7');
  MapKey(kVK_ANSI_8, '8');
  MapKey(kVK_ANSI_9, '9');
  MapKey(kVK_ANSI_0, '0');

  // Punctuation for console
  MapKey(kVK_ANSI_Minus, '-');
  MapKey(kVK_ANSI_Equal, '=');
  MapKey(kVK_ANSI_LeftBracket, '[');
  MapKey(kVK_ANSI_RightBracket, ']');
  MapKey(kVK_ANSI_Semicolon, ';');
  MapKey(kVK_ANSI_Quote, '\'');
  MapKey(kVK_ANSI_Comma, ',');
  MapKey(kVK_ANSI_Period, '.');
  MapKey(kVK_ANSI_Slash, '/');
  MapKey(kVK_ANSI_Backslash, '\\');
  MapKey(kVK_ANSI_Grave, '`'); // Console toggle

  // Misc
  MapKey(kVK_Tab, K_TAB);
  MapKey(kVK_F1, K_F1);
  MapKey(kVK_F2, K_F2);
  MapKey(kVK_F3, K_F3);
  MapKey(kVK_F4, K_F4);
  MapKey(kVK_F5, K_F5);
  MapKey(kVK_F6, K_F6);
  MapKey(kVK_F7, K_F7);
  MapKey(kVK_F8, K_F8);
  MapKey(kVK_F9, K_F9);
  MapKey(kVK_F10, K_F10);
  MapKey(kVK_F11, K_F11);
  MapKey(kVK_F12, K_F12);
  MapKey(kVK_Delete, K_BACKSPACE);
  MapKey(kVK_ForwardDelete, K_DEL);
  MapKey(kVK_Home, K_HOME);
  MapKey(kVK_End, K_END);
  MapKey(kVK_PageUp, K_PGUP);
  MapKey(kVK_PageDown, K_PGDN);
  MapKey(kVK_Help, K_INS);

  // Numpad — mapped to the equivalent navigation keys so default Quake
  // bindings (which expect numpad arrows for movement) work out of the box.
  MapKey(kVK_ANSI_Keypad8, K_UPARROW);
  MapKey(kVK_ANSI_Keypad2, K_DOWNARROW);
  MapKey(kVK_ANSI_Keypad4, K_LEFTARROW);
  MapKey(kVK_ANSI_Keypad6, K_RIGHTARROW);
  MapKey(kVK_ANSI_Keypad7, K_HOME);
  MapKey(kVK_ANSI_Keypad1, K_END);
  MapKey(kVK_ANSI_Keypad9, K_PGUP);
  MapKey(kVK_ANSI_Keypad3, K_PGDN);
  MapKey(kVK_ANSI_Keypad0, K_INS);
  MapKey(kVK_ANSI_KeypadDecimal, K_DEL);
  MapKey(kVK_ANSI_KeypadEnter, K_ENTER);

  Cvar_RegisterVariable(&mouse_sensitivity);

  // ---- Gamepad / controller support ----
  // Pick up any already-connected controller.
  for (GCController *ctrl in [GCController controllers]) {
    if (ctrl.extendedGamepad) {
      activeController = ctrl;
      break;
    }
  }

  // Watch for future connect / disconnect.
  [[NSNotificationCenter defaultCenter]
      addObserverForName:GCControllerDidConnectNotification
                  object:nil
                   queue:[NSOperationQueue mainQueue]
              usingBlock:^(NSNotification *note) {
                GCController *ctrl = note.object;
                if (!activeController && ctrl.extendedGamepad)
                  activeController = ctrl;
              }];

  [[NSNotificationCenter defaultCenter]
      addObserverForName:GCControllerDidDisconnectNotification
                  object:nil
                   queue:[NSOperationQueue mainQueue]
              usingBlock:^(NSNotification *note) {
                if (activeController == note.object) {
                  activeController = nil;
                  // Try to fall back to another connected controller.
                  for (GCController *ctrl in [GCController controllers]) {
                    if (ctrl.extendedGamepad) {
                      activeController = ctrl;
                      break;
                    }
                  }
                }
              }];

  printf("IN_Init: Input Initialized\n");
}

void IN_Shutdown(void) {}

void IN_Commands(void) {
  // Poll for all pending events from the NSApp
  @autoreleasepool {
    NSEvent *event;
    while ((event = [NSApp nextEventMatchingMask:NSEventMaskAny
                                       untilDate:nil // Don't wait
                                          inMode:NSDefaultRunLoopMode
                                         dequeue:YES])) {

      NSEventType type = [event type];

      // Handle keyboard events
      if (type == NSEventTypeKeyDown) {
        unsigned short code = [event keyCode];
        if (code < 256 && keymap[code]) {
          Key_Event(keymap[code], true);
        }
        // Don't forward to app (prevents beep)
        continue;
      }

      if (type == NSEventTypeKeyUp) {
        unsigned short code = [event keyCode];
        if (code < 256 && keymap[code]) {
          Key_Event(keymap[code], false);
        }
        continue;
      }

      // Track mouse delta for mouse look
      if (type == NSEventTypeMouseMoved ||
          type == NSEventTypeLeftMouseDragged ||
          type == NSEventTypeRightMouseDragged ||
          type == NSEventTypeOtherMouseDragged) {
        accum_mouse_x += [event deltaX];
        accum_mouse_y += [event deltaY];
      }

      // Mouse Buttons
      if (type == NSEventTypeLeftMouseDown)
        Key_Event(K_MOUSE1, true);
      if (type == NSEventTypeLeftMouseUp)
        Key_Event(K_MOUSE1, false);
      if (type == NSEventTypeRightMouseDown)
        Key_Event(K_MOUSE2, true);
      if (type == NSEventTypeRightMouseUp)
        Key_Event(K_MOUSE2, false);
      if (type == NSEventTypeOtherMouseDown)
        Key_Event(K_MOUSE3, true);
      if (type == NSEventTypeOtherMouseUp)
        Key_Event(K_MOUSE3, false);

      // Scroll wheel
      if (type == NSEventTypeScrollWheel) {
        float dy = [event scrollingDeltaY];
        if (dy > 0) {
          Key_Event(K_MWHEELUP, true);
          Key_Event(K_MWHEELUP, false);
        } else if (dy < 0) {
          Key_Event(K_MWHEELDOWN, true);
          Key_Event(K_MWHEELDOWN, false);
        }
      }

      // Forward other events to the application
      [NSApp sendEvent:event];
    }
  }
}

void IN_Move(usercmd_t *cmd) {
  // Apply accumulated mouse movement
  if (accum_mouse_x != 0 || accum_mouse_y != 0) {
    mouse_x = accum_mouse_x * mouse_sensitivity.value;
    mouse_y = accum_mouse_y * mouse_sensitivity.value;

    // Apply to view angles
    cl.viewangles[YAW] -= mouse_x * 0.022f;
    cl.viewangles[PITCH] += mouse_y * 0.022f;

    // Clamp pitch
    if (cl.viewangles[PITCH] > 80)
      cl.viewangles[PITCH] = 80;
    if (cl.viewangles[PITCH] < -70)
      cl.viewangles[PITCH] = -70;

    accum_mouse_x = 0;
    accum_mouse_y = 0;
  }

  // ---- Gamepad polling ----
  GCController *ctrl = activeController;
  if (!ctrl) return;
  GCExtendedGamepad *pad = ctrl.extendedGamepad;
  if (!pad) return;

  const float deadzone = 0.15f;

  // Right stick → look (positive Y = push up = look up = decrease pitch)
  float rx = pad.rightThumbstick.xAxis.value;
  float ry = pad.rightThumbstick.yAxis.value;
  if (fabsf(rx) < deadzone) rx = 0.0f;
  if (fabsf(ry) < deadzone) ry = 0.0f;
  if (rx != 0.0f || ry != 0.0f) {
    float sens = mouse_sensitivity.value * 3.0f;
    cl.viewangles[YAW]   -= rx * sens;
    cl.viewangles[PITCH] -= ry * sens;
    if (cl.viewangles[PITCH] >  80.0f) cl.viewangles[PITCH] =  80.0f;
    if (cl.viewangles[PITCH] < -70.0f) cl.viewangles[PITCH] = -70.0f;
  }

  // Left stick → movement (positive Y = push forward, positive X = strafe right)
  float lx = pad.leftThumbstick.xAxis.value;
  float ly = pad.leftThumbstick.yAxis.value;
  if (fabsf(lx) < deadzone) lx = 0.0f;
  if (fabsf(ly) < deadzone) ly = 0.0f;
  cmd->forwardmove += ly * 200.0f;
  cmd->sidemove    += lx * 200.0f;

  // Buttons → Key_Event on state transitions
  // Defaults mirror Quake's keyboard bindings so existing configs work.
  static BOOL prev_fire     = NO;  // right trigger  → K_CTRL  (attack)
  static BOOL prev_altfire  = NO;  // left trigger   → K_MOUSE2 (alt attack)
  static BOOL prev_jump     = NO;  // A / cross       → K_SPACE (jump)
  static BOOL prev_lshoulder = NO; // left shoulder  → '[' (prev weapon)
  static BOOL prev_rshoulder = NO; // right shoulder → ']' (next weapon)
  static BOOL prev_dpadU    = NO;
  static BOOL prev_dpadD    = NO;
  static BOOL prev_dpadL    = NO;
  static BOOL prev_dpadR    = NO;
  static BOOL prev_start    = NO;  // start/menu    → K_ESCAPE

#define SEND_IF_CHANGED(cur, prev, qkey)          \
  do {                                             \
    BOOL _cur = (cur);                             \
    if (_cur != prev) { Key_Event(qkey, _cur); prev = _cur; } \
  } while (0)

  SEND_IF_CHANGED(pad.rightTrigger.isPressed,   prev_fire,      K_CTRL);
  SEND_IF_CHANGED(pad.leftTrigger.isPressed,    prev_altfire,   K_MOUSE2);
  SEND_IF_CHANGED(pad.buttonA.isPressed,        prev_jump,      K_SPACE);
  SEND_IF_CHANGED(pad.leftShoulder.isPressed,   prev_lshoulder, '[');
  SEND_IF_CHANGED(pad.rightShoulder.isPressed,  prev_rshoulder, ']');
  SEND_IF_CHANGED(pad.dpad.up.isPressed,        prev_dpadU,     K_UPARROW);
  SEND_IF_CHANGED(pad.dpad.down.isPressed,      prev_dpadD,     K_DOWNARROW);
  SEND_IF_CHANGED(pad.dpad.left.isPressed,      prev_dpadL,     K_LEFTARROW);
  SEND_IF_CHANGED(pad.dpad.right.isPressed,     prev_dpadR,     K_RIGHTARROW);
  SEND_IF_CHANGED(pad.buttonMenu.isPressed,     prev_start,     K_ESCAPE);

#undef SEND_IF_CHANGED
}

void IN_Mode(void) {}
