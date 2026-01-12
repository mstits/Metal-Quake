#include "quakedef.h"
#import <Carbon/Carbon.h> // For key codes
#import <Cocoa/Cocoa.h>
#include <sys/stat.h>

qboolean isDedicated = false;

// Forward declarations
void Key_Event(int key, qboolean down);

// Key mappings (from in_macos.m)
static int keymap[256];

static void InitKeymap(void) {
  memset(keymap, 0, sizeof(keymap));

  // Letters
  keymap[kVK_ANSI_A] = 'a';
  keymap[kVK_ANSI_B] = 'b';
  keymap[kVK_ANSI_C] = 'c';
  keymap[kVK_ANSI_D] = 'd';
  keymap[kVK_ANSI_E] = 'e';
  keymap[kVK_ANSI_F] = 'f';
  keymap[kVK_ANSI_G] = 'g';
  keymap[kVK_ANSI_H] = 'h';
  keymap[kVK_ANSI_I] = 'i';
  keymap[kVK_ANSI_J] = 'j';
  keymap[kVK_ANSI_K] = 'k';
  keymap[kVK_ANSI_L] = 'l';
  keymap[kVK_ANSI_M] = 'm';
  keymap[kVK_ANSI_N] = 'n';
  keymap[kVK_ANSI_O] = 'o';
  keymap[kVK_ANSI_P] = 'p';
  keymap[kVK_ANSI_Q] = 'q';
  keymap[kVK_ANSI_R] = 'r';
  keymap[kVK_ANSI_S] = 's';
  keymap[kVK_ANSI_T] = 't';
  keymap[kVK_ANSI_U] = 'u';
  keymap[kVK_ANSI_V] = 'v';
  keymap[kVK_ANSI_W] = 'w';
  keymap[kVK_ANSI_X] = 'x';
  keymap[kVK_ANSI_Y] = 'y';
  keymap[kVK_ANSI_Z] = 'z';

  // Numbers
  keymap[kVK_ANSI_1] = '1';
  keymap[kVK_ANSI_2] = '2';
  keymap[kVK_ANSI_3] = '3';
  keymap[kVK_ANSI_4] = '4';
  keymap[kVK_ANSI_5] = '5';
  keymap[kVK_ANSI_6] = '6';
  keymap[kVK_ANSI_7] = '7';
  keymap[kVK_ANSI_8] = '8';
  keymap[kVK_ANSI_9] = '9';
  keymap[kVK_ANSI_0] = '0';

  // Special keys
  keymap[kVK_Return] = K_ENTER;
  keymap[kVK_Escape] = K_ESCAPE;
  keymap[kVK_Delete] = K_BACKSPACE;
  keymap[kVK_Tab] = K_TAB;
  keymap[kVK_Space] = K_SPACE;
  keymap[kVK_UpArrow] = K_UPARROW;
  keymap[kVK_DownArrow] = K_DOWNARROW;
  keymap[kVK_LeftArrow] = K_LEFTARROW;
  keymap[kVK_RightArrow] = K_RIGHTARROW;
  keymap[kVK_Control] = K_CTRL;
  keymap[kVK_Shift] = K_SHIFT;
  keymap[kVK_Option] = K_ALT;
  keymap[kVK_Command] = K_ALT;
  keymap[kVK_ANSI_Grave] = '`'; // Console toggle
  keymap[kVK_F1] = K_F1;
  keymap[kVK_F2] = K_F2;
  keymap[kVK_F3] = K_F3;
  keymap[kVK_F4] = K_F4;
  keymap[kVK_F5] = K_F5;
  keymap[kVK_F6] = K_F6;
  keymap[kVK_F7] = K_F7;
  keymap[kVK_F8] = K_F8;
  keymap[kVK_F9] = K_F9;
  keymap[kVK_F10] = K_F10;
  keymap[kVK_F11] = K_F11;
  keymap[kVK_F12] = K_F12;

  // Punctuation
  keymap[kVK_ANSI_Minus] = '-';
  keymap[kVK_ANSI_Equal] = '=';
  keymap[kVK_ANSI_LeftBracket] = '[';
  keymap[kVK_ANSI_RightBracket] = ']';
  keymap[kVK_ANSI_Semicolon] = ';';
  keymap[kVK_ANSI_Quote] = '\'';
  keymap[kVK_ANSI_Comma] = ',';
  keymap[kVK_ANSI_Period] = '.';
  keymap[kVK_ANSI_Slash] = '/';
  keymap[kVK_ANSI_Backslash] = '\\';
}

@interface QuakeAppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>
@property(nonatomic, assign) BOOL shouldKeepRunning;
@end

static QuakeAppDelegate *appDelegate;
static NSWindow *gameWindow = nil;

int main(int argc, char **argv) {
  @autoreleasepool {
    InitKeymap();

    NSApplication *app = [NSApplication sharedApplication];
    appDelegate = [[QuakeAppDelegate alloc] init];
    [app setDelegate:appDelegate];
    [app setActivationPolicy:NSApplicationActivationPolicyRegular];

    // Don't use [app run] - we need to control the run loop ourselves
    [app finishLaunching];

    // Initialize Quake
    quakeparms_t parms;
    memset(&parms, 0, sizeof(parms));

    // Pass command line arguments properly
    parms.argc = argc;
    parms.argv = argv;

    // Find basedir from args or default to current directory
    parms.basedir = ".";
    for (int i = 1; i < argc - 1; i++) {
      if (strcmp(argv[i], "-basedir") == 0) {
        parms.basedir = argv[i + 1];
        break;
      }
    }

    parms.memsize = 16 * 1024 * 1024;
    parms.membase = malloc(parms.memsize);

    Host_Init(&parms);

    // Main game loop - we control it directly
    double oldtime = Sys_FloatTime();
    appDelegate.shouldKeepRunning = YES;

    while (appDelegate.shouldKeepRunning) {
      @autoreleasepool {
        // Process pending events - intercept keyboard before forwarding
        NSEvent *event;
        while ((event = [app nextEventMatchingMask:NSEventMaskAny
                                         untilDate:nil
                                            inMode:NSDefaultRunLoopMode
                                           dequeue:YES])) {

          NSEventType type = [event type];

          // Handle keyboard events BEFORE sendEvent to prevent macOS from
          // consuming them
          if (type == NSEventTypeKeyDown) {
            unsigned short code = [event keyCode];
            if (code < 256 && keymap[code]) {
              Key_Event(keymap[code], true);
            }
            // Don't forward key events to NSApp (prevents macOS handling)
            continue;
          }

          if (type == NSEventTypeKeyUp) {
            unsigned short code = [event keyCode];
            if (code < 256 && keymap[code]) {
              Key_Event(keymap[code], false);
            }
            continue;
          }

          // Handle mouse buttons
          if (type == NSEventTypeLeftMouseDown) {
            Key_Event(K_MOUSE1, true);
          } else if (type == NSEventTypeLeftMouseUp) {
            Key_Event(K_MOUSE1, false);
          } else if (type == NSEventTypeRightMouseDown) {
            Key_Event(K_MOUSE2, true);
          } else if (type == NSEventTypeRightMouseUp) {
            Key_Event(K_MOUSE2, false);
          }

          // Forward other events normally
          [app sendEvent:event];
        }

        // Check if window was closed
        if (gameWindow && ![gameWindow isVisible]) {
          appDelegate.shouldKeepRunning = NO;
          break;
        }

        // Find time passed
        double newtime = Sys_FloatTime();
        double time = newtime - oldtime;
        oldtime = newtime;

        // Run a frame
        Host_Frame(time);
      }
    }

    Host_Shutdown();
  }
  return 0;
}

// Called from vid_metal.m to register the game window
void Sys_RegisterWindow(NSWindow *window) {
  gameWindow = window;
  [window setDelegate:appDelegate];
}

@implementation QuakeAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
  // Quake is already initialized in main()
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:
    (NSApplication *)sender {
  return YES;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:
    (NSApplication *)sender {
  self.shouldKeepRunning = NO;
  return NSTerminateCancel;
}

- (void)windowWillClose:(NSNotification *)notification {
  self.shouldKeepRunning = NO;
}

@end

// Sys Stubs
void Sys_Error(char *error, ...) {
  va_list argptr;
  char text[1024];

  va_start(argptr, error);
  vsprintf(text, error, argptr);
  va_end(argptr);

  printf("Sys_Error: %s\n", text);
  appDelegate.shouldKeepRunning = NO;
  exit(1);
}

void Sys_Printf(char *fmt, ...) {
  va_list argptr;
  char text[1024];

  va_start(argptr, fmt);
  vsprintf(text, fmt, argptr);
  va_end(argptr);

  printf("%s", text);
}

void Sys_Quit(void) { appDelegate.shouldKeepRunning = NO; }

double Sys_FloatTime(void) {
  static double start_time = 0;
  if (start_time == 0) {
    start_time = [NSDate timeIntervalSinceReferenceDate];
  }
  return [NSDate timeIntervalSinceReferenceDate] - start_time;
}

char *Sys_ConsoleInput(void) { return NULL; }
void Sys_Sleep(void) {}

void Sys_SendKeyEvents(void) {
  // Events are already processed in main loop
}

void Sys_LowFPPrecision(void) {}
void Sys_HighFPPrecision(void) {}
void Sys_SetFPCW(void) {}
void Sys_mkdir(char *path) { mkdir(path, 0777); }

#define MAX_HANDLES 64
static FILE *file_handles[MAX_HANDLES];

static int FindFreeHandle(void) {
  for (int i = 1; i < MAX_HANDLES; i++) {
    if (file_handles[i] == NULL)
      return i;
  }
  return -1;
}

int Sys_FileOpenRead(char *path, int *hndl) {
  int i = FindFreeHandle();
  if (i == -1)
    return -1;

  FILE *f = fopen(path, "rb");
  if (!f)
    return -1;

  file_handles[i] = f;
  *hndl = i;
  fseek(f, 0, SEEK_END);
  int len = ftell(f);
  fseek(f, 0, SEEK_SET);
  return len;
}

int Sys_FileOpenWrite(char *path) {
  int i = FindFreeHandle();
  if (i == -1)
    return -1;

  FILE *f = fopen(path, "wb");
  if (!f)
    return -1;

  file_handles[i] = f;
  return i;
}

void Sys_FileClose(int handle) {
  if (handle > 0 && handle < MAX_HANDLES && file_handles[handle]) {
    fclose(file_handles[handle]);
    file_handles[handle] = NULL;
  }
}

void Sys_FileSeek(int handle, int position) {
  if (handle > 0 && handle < MAX_HANDLES && file_handles[handle]) {
    fseek(file_handles[handle], position, SEEK_SET);
  }
}

int Sys_FileRead(int handle, void *dest, int count) {
  if (handle > 0 && handle < MAX_HANDLES && file_handles[handle]) {
    return fread(dest, 1, count, file_handles[handle]);
  }
  return 0;
}

int Sys_FileWrite(int handle, void *data, int count) {
  if (handle > 0 && handle < MAX_HANDLES && file_handles[handle]) {
    return fwrite(data, 1, count, file_handles[handle]);
  }
  return 0;
}

int Sys_FileTime(char *path) {
  FILE *f = fopen(path, "rb");
  if (!f)
    return -1;
  fclose(f);
  return 1;
}
