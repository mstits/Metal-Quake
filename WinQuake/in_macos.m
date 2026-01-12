#include "quakedef.h"
#import <Carbon/Carbon.h> // For keycodes
#import <Cocoa/Cocoa.h>

// Quake Key Mappings
static int keymap[256];

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

  Cvar_RegisterVariable(&mouse_sensitivity);

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
          type == NSEventTypeRightMouseDragged) {
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
}

void IN_Mode(void) {}
