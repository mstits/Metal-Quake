#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#import <MetalKit/MetalKit.h>
#import <Carbon/Carbon.h>
#include <sys/stat.h>
#include <mach/mach_time.h>
#include "quakedef.h"

@interface QuakeAppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>
@property(nonatomic, assign) BOOL shouldKeepRunning;
@end

static QuakeAppDelegate *appDelegate;
NSWindow *gameWindow = nil;
static MTKView *g_mtkView = nil;
qboolean isDedicated = false;
float mouse_x, mouse_y;

// ---------------------------------------------------------------------------
// Quake Key Mapping (Carbon Scan Codes to Quake K_ constants)
// ---------------------------------------------------------------------------
static int MapKey(uint16_t keyCode) {
    switch (keyCode) {
        case kVK_ANSI_A: return 'a';
        case kVK_ANSI_B: return 'b';
        case kVK_ANSI_C: return 'c';
        case kVK_ANSI_D: return 'd';
        case kVK_ANSI_E: return 'e';
        case kVK_ANSI_F: return 'f';
        case kVK_ANSI_G: return 'g';
        case kVK_ANSI_H: return 'h';
        case kVK_ANSI_I: return 'i';
        case kVK_ANSI_J: return 'j';
        case kVK_ANSI_K: return 'k';
        case kVK_ANSI_L: return 'l';
        case kVK_ANSI_M: return 'm';
        case kVK_ANSI_N: return 'n';
        case kVK_ANSI_O: return 'o';
        case kVK_ANSI_P: return 'p';
        case kVK_ANSI_Q: return 'q';
        case kVK_ANSI_R: return 'r';
        case kVK_ANSI_S: return 's';
        case kVK_ANSI_T: return 't';
        case kVK_ANSI_U: return 'u';
        case kVK_ANSI_V: return 'v';
        case kVK_ANSI_W: return 'w';
        case kVK_ANSI_X: return 'x';
        case kVK_ANSI_Y: return 'y';
        case kVK_ANSI_Z: return 'z';
        case kVK_ANSI_1: return '1';
        case kVK_ANSI_2: return '2';
        case kVK_ANSI_3: return '3';
        case kVK_ANSI_4: return '4';
        case kVK_ANSI_5: return '5';
        case kVK_ANSI_6: return '6';
        case kVK_ANSI_7: return '7';
        case kVK_ANSI_8: return '8';
        case kVK_ANSI_9: return '9';
        case kVK_ANSI_0: return '0';
        case kVK_ANSI_Minus: return '-';
        case kVK_ANSI_Equal: return '=';
        case kVK_ANSI_LeftBracket: return '[';
        case kVK_ANSI_RightBracket: return ']';
        case kVK_ANSI_Backslash: return '\\';
        case kVK_ANSI_Semicolon: return ';';
        case kVK_ANSI_Quote: return '\'';
        case kVK_ANSI_Grave: return '`';
        case kVK_ANSI_Comma: return ',';
        case kVK_ANSI_Period: return '.';
        case kVK_ANSI_Slash: return '/';
        case kVK_Space: return K_SPACE;
        case kVK_Escape: return K_ESCAPE;
        case kVK_Return: return K_ENTER;
        case kVK_Tab: return K_TAB;
        case kVK_Delete: return K_BACKSPACE;
        case kVK_ForwardDelete: return K_DEL;
        case kVK_Control: return K_CTRL;
        case kVK_Shift: return K_SHIFT;
        case kVK_Option: return K_ALT;
        case kVK_UpArrow: return K_UPARROW;
        case kVK_DownArrow: return K_DOWNARROW;
        case kVK_LeftArrow: return K_LEFTARROW;
        case kVK_RightArrow: return K_RIGHTARROW;
        case kVK_F1: return K_F1;
        case kVK_F2: return K_F2;
        case kVK_F3: return K_F3;
        case kVK_F4: return K_F4;
        case kVK_F5: return K_F5;
        case kVK_F6: return K_F6;
        case kVK_F7: return K_F7;
        case kVK_F8: return K_F8;
        case kVK_F9: return K_F9;
        case kVK_F10: return K_F10;
        case kVK_F11: return K_F11;
        case kVK_F12: return K_F12;
        default: return 0;
    }
}

void Sys_RegisterWindow(NSWindow *window) {
  gameWindow = window;
  [window setDelegate:appDelegate];
}

void* Sys_CreateWindow(int width, int height, void* pDevice) {
  id<MTLDevice> device = (__bridge id<MTLDevice>)pDevice;
  NSRect frame = NSMakeRect(0, 0, width, height);
  NSWindow* window = [[NSWindow alloc] initWithContentRect:frame
                                                 styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable
                                                   backing:NSBackingStoreBuffered
                                                     defer:NO];
  [window setTitle:@"Quake Modern (Metal)"];
  
  g_mtkView = [[MTKView alloc] initWithFrame:frame device:device];
  g_mtkView.colorPixelFormat = MTLPixelFormatBGRA8Unorm; // Must match MetalFX scaler output format
  g_mtkView.drawableSize = CGSizeMake(width, height);
  g_mtkView.paused = YES;
  g_mtkView.enableSetNeedsDisplay = NO;
  
  if ([g_mtkView.layer isKindOfClass:[CAMetalLayer class]]) {
      ((CAMetalLayer*)g_mtkView.layer).displaySyncEnabled = NO;
  }
  
  // Use a container view so SwiftUI overlays can layer on top of Metal
  NSView *container = [[NSView alloc] initWithFrame:frame];
  container.wantsLayer = YES;
  g_mtkView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  [container addSubview:g_mtkView];
  [window setContentView:container];
  [window setAcceptsMouseMovedEvents:YES];
  [window makeKeyAndOrderFront:nil];
  [window center];
  
  Sys_RegisterWindow(window);
  
  return (__bridge void*)g_mtkView.layer;
}

void* Sys_GetNextDrawable(void* layer) {
  CAMetalLayer* metalLayer = (__bridge CAMetalLayer*)layer;
  return (__bridge void*)[metalLayer nextDrawable];
}

void Sys_SetWindowSize(int width, int height) {
    if (!gameWindow || !g_mtkView) return;
    
    // Make sure we run this on the main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        NSRect frame = [gameWindow frame];
        NSRect contentRect = [NSWindow contentRectForFrameRect:frame styleMask:[gameWindow styleMask]];
        
        // Calculate new frame based on requested content size
        NSRect newContentRect = NSMakeRect(contentRect.origin.x, contentRect.origin.y, width, height);
        NSRect newFrame = [NSWindow frameRectForContentRect:newContentRect styleMask:[gameWindow styleMask]];
        
        // Keep the top-left corner anchored when resizing if possible, or just center it.
        [gameWindow setFrame:newFrame display:YES animate:NO];
        [gameWindow center];
        
        g_mtkView.drawableSize = CGSizeMake(width, height);
    });
}

@implementation QuakeAppDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {}
- (void)windowWillClose:(NSNotification *)notification {
  self.shouldKeepRunning = NO;
}
@end

void Sys_Error(char *error, ...) {
  va_list argptr;
  char text[4096];

  va_start(argptr, error);
  vsnprintf(text, sizeof(text), error, argptr);
  va_end(argptr);

  printf("Sys_Error: %s\n", text);
  fflush(stdout);
  appDelegate.shouldKeepRunning = NO;
  exit(1);
}

void Sys_Printf(char *fmt, ...) {
  va_list argptr;
  char text[4096];

  va_start(argptr, fmt);
  vsnprintf(text, sizeof(text), fmt, argptr);
  va_end(argptr);
  printf("%s", text);
  fflush(stdout);
}

void Sys_Quit(void) {
  appDelegate.shouldKeepRunning = NO;
  exit(0);
}

double Sys_FloatTime(void) {
  static mach_timebase_info_data_t info = {0, 0};
  static uint64_t start = 0;
  if (info.denom == 0) {
    mach_timebase_info(&info);
    start = mach_continuous_time();
  }
  uint64_t now = mach_continuous_time();
  return (double)(now - start) * (double)info.numer / (double)info.denom / 1e9;
}

char *Sys_ConsoleInput(void) { return NULL; }
void Sys_Sleep(void) {}
void Sys_SendKeyEvents(void) {}
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
  if (i == -1) return -1;
  FILE *f = fopen(path, "rb");
  if (!f) return -1;
  file_handles[i] = f;
  *hndl = i;
  fseek(f, 0, SEEK_END);
  int len = ftell(f);
  fseek(f, 0, SEEK_SET);
  return len;
}

int Sys_FileOpenWrite(char *path) {
  int i = FindFreeHandle();
  if (i == -1) return -1;
  FILE *f = fopen(path, "wb");
  if (!f) return -1;
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
  if (!f) return -1;
  fclose(f);
  return 1;
}

void InitKeymap(void) {}

int main(int argc, char **argv) {
  @autoreleasepool {
    InitKeymap();

    NSApplication *app = [NSApplication sharedApplication];
    appDelegate = [[QuakeAppDelegate alloc] init];
    [app setDelegate:appDelegate];
    [app setActivationPolicy:NSApplicationActivationPolicyRegular];
    [app finishLaunching];

    quakeparms_t parms;
    memset(&parms, 0, sizeof(parms));
    parms.argc = argc;
    parms.argv = argv;
    parms.basedir = ".";
    
    for (int i = 1; i < argc - 1; i++) {
      if (strcmp(argv[i], "-basedir") == 0) {
        parms.basedir = argv[i + 1];
        break;
      }
    }

    parms.memsize = 256 * 1024 * 1024;  // 256MB — Apple Silicon unified memory
    parms.membase = malloc(parms.memsize);

    Host_Init(&parms);
    
    // Initialize GCD multicore task system
    extern void MQ_TasksInit(void);
    MQ_TasksInit();
    
    // Initialize PHASE spatial audio engine (dual-engine alongside Core Audio)
    extern void MQ_PHASE_Init(void);
    MQ_PHASE_Init();
    
    // Initialize CoreML neural pipeline (graceful skip if no models)
    extern void MQ_CoreML_Init(id device);
    MQ_CoreML_Init(MTLCreateSystemDefaultDevice());
    
    // Sync settings from UserDefaults (launcher persistence) on startup
    extern void MQBridge_SyncSettings(void);
    MQBridge_SyncSettings();
    
    // Enable mouse look by default and hide cursor
    extern void Cbuf_AddText(char *text);
    Cbuf_AddText("+mlook\n");
    CGDisplayHideCursor(kCGDirectMainDisplay);
    CGAssociateMouseAndMouseCursorPosition(true);

    double oldtime = Sys_FloatTime();
    appDelegate.shouldKeepRunning = YES;

    while (appDelegate.shouldKeepRunning) {
      @autoreleasepool {
        if (gameWindow && ![gameWindow isVisible]) {
          appDelegate.shouldKeepRunning = NO;
          break;
        }

        double newtime = Sys_FloatTime();
        double time = newtime - oldtime;
        oldtime = newtime;
        if (time > 0.2) time = 0.2;

        NSEvent *event;
        while ((event = [app nextEventMatchingMask:NSEventMaskAny
                                         untilDate:[NSDate distantPast]
                                            inMode:NSDefaultRunLoopMode
                                           dequeue:YES])) {
          switch ([event type]) {
            case NSEventTypeKeyDown: {
              int k = MapKey([event keyCode]);
              
              // Tab toggles SwiftUI launcher overlay
              if (k == K_TAB) {
                extern int MQBridge_IsLauncherVisible(void);
                extern void MQBridge_SetLauncherVisible(int visible);
                int newState = !MQBridge_IsLauncherVisible();
                MQBridge_SetLauncherVisible(newState);
                break;
              }
              
              // Escape hides launcher if open
              if (k == K_ESCAPE) {
                extern int MQBridge_IsLauncherVisible(void);
                extern void MQBridge_SetLauncherVisible(int visible);
                if (MQBridge_IsLauncherVisible()) {
                  MQBridge_SetLauncherVisible(0);
                  break;
                }
              }
              
              // When launcher is visible, forward everything to AppKit
              {
                extern int MQBridge_IsLauncherVisible(void);
                if (MQBridge_IsLauncherVisible()) {
                  [app sendEvent:event];
                  break;
                }
              }
              
              if (k) Key_Event(k, true);
              break;
            }
            case NSEventTypeKeyUp: {
              extern int MQBridge_IsLauncherVisible(void);
              if (MQBridge_IsLauncherVisible()) { [app sendEvent:event]; break; }
              int k = MapKey([event keyCode]);
              if (k) Key_Event(k, false);
              break;
            }
            case NSEventTypeLeftMouseDown:
            case NSEventTypeLeftMouseUp:
            case NSEventTypeRightMouseDown:
            case NSEventTypeRightMouseUp:
            case NSEventTypeOtherMouseDown:
            case NSEventTypeOtherMouseUp:
            case NSEventTypeScrollWheel: {
              extern int MQBridge_IsLauncherVisible(void);
              if (MQBridge_IsLauncherVisible()) {
                [app sendEvent:event];
                break;
              }
              if ([event type] == NSEventTypeScrollWheel) break; // no game scroll
              int k;
              switch ([event type]) {
                case NSEventTypeLeftMouseDown: 
                  if (![gameWindow isKeyWindow]) {
                    [NSApp activateIgnoringOtherApps:YES];
                    [gameWindow makeKeyAndOrderFront:nil];
                  }
                  k = K_MOUSE1; Key_Event(k, true); 
                  break;
                case NSEventTypeLeftMouseUp: k = K_MOUSE1; Key_Event(k, false); break;
                case NSEventTypeRightMouseDown: 
                  if (![gameWindow isKeyWindow]) {
                    [NSApp activateIgnoringOtherApps:YES];
                    [gameWindow makeKeyAndOrderFront:nil];
                  }
                  k = K_MOUSE2; Key_Event(k, true); 
                  break;
                case NSEventTypeRightMouseUp: k = K_MOUSE2; Key_Event(k, false); break;
                case NSEventTypeOtherMouseDown: 
                  if (![gameWindow isKeyWindow]) {
                    [NSApp activateIgnoringOtherApps:YES];
                    [gameWindow makeKeyAndOrderFront:nil];
                  }
                  k = K_MOUSE3; Key_Event(k, true); 
                  break;
                case NSEventTypeOtherMouseUp: k = K_MOUSE3; Key_Event(k, false); break;
                default: break;
              }
              break;
            }
            case NSEventTypeMouseMoved:
            case NSEventTypeLeftMouseDragged:
            case NSEventTypeRightMouseDragged:
            case NSEventTypeOtherMouseDragged: {
              extern int MQBridge_IsLauncherVisible(void);
              if (MQBridge_IsLauncherVisible()) {
                [app sendEvent:event];
                break;
              }
              // Use CGEvent deltas for smooth, raw mouse input
              extern keydest_t key_dest;
              if (gameWindow && [gameWindow isKeyWindow] && key_dest == key_game) {
                CGEventRef cgEvent = [event CGEvent];
                double dx = CGEventGetDoubleValueField(cgEvent, kCGMouseEventDeltaX);
                double dy = CGEventGetDoubleValueField(cgEvent, kCGMouseEventDeltaY);
                mouse_x += dx;
                mouse_y += dy;
              }
              break;
            }
            default:
              [app sendEvent:event];
              break;
          }
        }

        // Mouse capture + cursor management
        {
          extern keydest_t key_dest;
          static keydest_t _lastKeyDest = (keydest_t)-1;
          static BOOL _mouseGrabbed = NO;
          
          BOOL shouldGrab = (key_dest == key_game)
                         && gameWindow
                         && [gameWindow isKeyWindow]
                         && [NSApp isActive];
          
          if (key_dest != _lastKeyDest || shouldGrab != _mouseGrabbed) {
            if (shouldGrab && !_mouseGrabbed) {
              // Capture mouse: hide cursor, do NOT disassociate (avoids Cmd+Shift+4 bug)
              CGDisplayHideCursor(kCGDirectMainDisplay);
              _mouseGrabbed = YES;
            } else if (!shouldGrab && _mouseGrabbed) {
              // Release mouse: show cursor
              CGDisplayShowCursor(kCGDirectMainDisplay);
              _mouseGrabbed = NO;
            }
            _lastKeyDest = key_dest;
          }
          
          if (_mouseGrabbed && gameWindow) {
              // Continuously warp cursor to window center to prevent edge drift
              // This acts as a robust substitute for CGAssociateMouse(false)
              NSRect frame = [gameWindow frame];
              CGFloat cx = NSMidX(frame);
              CGFloat cy = NSMidY(frame);
              CGFloat screenHeight = [[NSScreen mainScreen] frame].size.height;
              CGWarpMouseCursorPosition(CGPointMake(cx, screenHeight - cy));
          }
        }

        Host_Frame(time);
      }
    }

    CGDisplayShowCursor(kCGDirectMainDisplay);
    Host_Shutdown();
  }
  return 0;
}
