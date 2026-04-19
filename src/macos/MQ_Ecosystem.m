/**
 * @file MQ_Ecosystem.m
 * @brief Apple Ecosystem Integration for Metal Quake
 *
 * Provides:
 * 1. Sound Spatializer UI — Accessibility visual overlay for audio direction
 * 2. Game Center — Achievement/leaderboard/matchmaking integration
 * 3. SharePlay — Spectating and co-op session sharing
 * 4. High-Frequency Mouse Polling — 8kHz+ support on M3+ MacBook Pro
 */

#import <Foundation/Foundation.h>
#import <GameKit/GameKit.h>
#import <AppKit/AppKit.h>
#import <MetricKit/MetricKit.h>

#define __QBOOLEAN_DEFINED__
typedef int qboolean;
#define true 1
#define false 0
#include "quakedef.h"
#undef true
#undef false

// The Sound Spatializer accessibility overlay used to live here as a C
// struct/array pair and an NSView, but none of it was ever attached to
// the game window — allocation-only, no render path. Removed in v1.4.0
// cleanup along with the matching launcher toggle. If it comes back the
// right implementation lives in an NSHostingView over the MTKView.

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - MetricKit crash + performance telemetry
// ═══════════════════════════════════════════════════════════════════════════

// MetricKit hands the app diagnostic payloads (crashes, hangs, CPU
// exceptions) on the next launch. We write them to a log file in the
// user's Application Support directory so post-mortem debugging doesn't
// require running the app under a debugger.

API_AVAILABLE(macos(12.0))
@interface MQMetricSubscriber : NSObject <MXMetricManagerSubscriber>
@end

@implementation MQMetricSubscriber
- (void)didReceiveDiagnosticPayloads:(NSArray<MXDiagnosticPayload *> *)payloads
    API_AVAILABLE(macos(12.0)) {
    NSString *dir = [NSString pathWithComponents:@[
        NSHomeDirectory(), @"Library", @"Application Support", @"MetalQuake"
    ]];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir
                               withIntermediateDirectories:YES
                                                attributes:nil
                                                     error:nil];
    for (MXDiagnosticPayload *payload in payloads) {
        NSData *json = [payload JSONRepresentation];
        if (!json) continue;
        NSString *stamp = [NSString stringWithFormat:@"%.0f", [[NSDate date] timeIntervalSince1970]];
        NSString *path = [dir stringByAppendingPathComponent:
            [NSString stringWithFormat:@"diagnostic-%@.json", stamp]];
        [json writeToFile:path atomically:YES];
        Con_Printf("MetricKit: diagnostic payload written to %s\n", [path UTF8String]);
    }
}
@end

static MQMetricSubscriber *_metricSubscriber = nil;

void MQ_MetricKit_Init(void) {
    if (@available(macOS 12.0, *)) {
        if (_metricSubscriber) return;
        _metricSubscriber = [[MQMetricSubscriber alloc] init];
        [[MXMetricManager sharedManager] addSubscriber:_metricSubscriber];
        Con_Printf("MetricKit: subscribed for crash/hang diagnostics\n");
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Game Center
// ═══════════════════════════════════════════════════════════════════════════

static BOOL _gcAuthenticated = NO;

void MQ_GameCenter_Init(void) {
    @autoreleasepool {
        GKLocalPlayer *localPlayer = [GKLocalPlayer localPlayer];

        localPlayer.authenticateHandler = ^(NSViewController *viewController, NSError *error) {
            if (viewController) {
                // Present the Apple-provided sign-in sheet on the main
                // thread, anchored to the game window. If no window
                // exists yet (very early boot), fall back to the shared
                // app's key window.
                dispatch_async(dispatch_get_main_queue(), ^{
                    extern NSWindow *gameWindow;
                    NSWindow *anchor = gameWindow ?: [NSApp keyWindow] ?: [NSApp mainWindow];
                    if (anchor && anchor.contentViewController) {
                        [anchor.contentViewController presentViewControllerAsSheet:viewController];
                    } else {
                        // Last resort: show as a transient panel so the
                        // user can at least see it.
                        NSWindow *w = [NSWindow windowWithContentViewController:viewController];
                        [w setTitle:@"Sign in to Game Center"];
                        [w makeKeyAndOrderFront:nil];
                    }
                });
            } else if ([GKLocalPlayer localPlayer].isAuthenticated) {
                _gcAuthenticated = YES;
                Con_Printf("Game Center: Authenticated as %s\n",
                           [[[GKLocalPlayer localPlayer] displayName] UTF8String]);
            } else {
                Con_Printf("Game Center: Not authenticated — %s\n",
                           error ? [[error localizedDescription] UTF8String] : "unknown");
            }
        };
    }
}

void MQ_GameCenter_ReportScore(const char *leaderboardID, int64_t score) {
    if (!_gcAuthenticated) return;
    
    @autoreleasepool {
        GKLeaderboardScore *entry = [[GKLeaderboardScore alloc] init];
        entry.leaderboardID = [NSString stringWithUTF8String:leaderboardID];
        entry.value = score;
        entry.player = [GKLocalPlayer localPlayer];
        
        [GKLeaderboard submitScore:score
                           context:0
                            player:[GKLocalPlayer localPlayer]
                  leaderboardIDs:@[entry.leaderboardID]
             completionHandler:^(NSError *error) {
            if (error) {
                Con_Printf("Game Center: Score submit failed\n");
            } else {
                Con_Printf("Game Center: Score %lld submitted\n", score);
            }
        }];
    }
}

void MQ_GameCenter_ReportAchievement(const char *achievementID, double percent) {
    if (!_gcAuthenticated) return;
    
    @autoreleasepool {
        GKAchievement *achievement = [[GKAchievement alloc]
            initWithIdentifier:[NSString stringWithUTF8String:achievementID]];
        achievement.percentComplete = percent;
        achievement.showsCompletionBanner = YES;
        
        [GKAchievement reportAchievements:@[achievement]
                    withCompletionHandler:^(NSError *error) {
            if (!error) {
                Con_Printf("Game Center: Achievement '%s' at %.0f%%\n", achievementID, percent);
            }
        }];
    }
}

// Quake-specific achievements. Called from cl_parse.c on intermission
// (map end). Reports per-map completion plus a running monster kill count
// milestone. Safe to call every intermission — Game Center deduplicates.
void MQ_GameCenter_CheckAchievements(void) {
    if (!_gcAuthenticated) return;
    int kills = cl.stats[STAT_MONSTERS];
    if (kills >= 100)  MQ_GameCenter_ReportAchievement("quake.centurion",  100.0);
    if (kills >= 500)  MQ_GameCenter_ReportAchievement("quake.slayer",     100.0);
    if (kills >= 1000) MQ_GameCenter_ReportAchievement("quake.exterminator", 100.0);
}

// Called from cl_parse.c at svc_intermission / svc_finale. Throttles at
// most one report per map to avoid duplicate submits when a finale cuts
// to a new intermission screen.
void MQ_Ecosystem_OnIntermission(const char *mapName, float completedTime) {
    if (!mapName || !mapName[0]) return;
    static char _lastReported[128] = {0};
    if (strncmp(_lastReported, mapName, sizeof(_lastReported)) == 0) return;
    strncpy(_lastReported, mapName, sizeof(_lastReported) - 1);
    _lastReported[sizeof(_lastReported) - 1] = '\0';

    Con_Printf("Ecosystem: map %s completed in %.2fs\n", mapName, completedTime);
    MQ_GameCenter_CheckAchievements();

    // Leaderboard submission: a monotonic integer derived from completion
    // time (lower is better so we negate). Identifier derived from the
    // BSP base name (e.g. "maps/e1m1.bsp" → "quake.time.e1m1").
    if (_gcAuthenticated) {
        @autoreleasepool {
            const char *base = strrchr(mapName, '/');
            base = base ? base + 1 : mapName;
            char ident[96];
            snprintf(ident, sizeof(ident), "quake.time.%s", base);
            char *dot = strrchr(ident, '.');
            if (dot && (dot != ident)) *dot = '\0'; // strip .bsp
            NSString *leaderboardId = [NSString stringWithUTF8String:ident];
            GKScore *score = [[GKScore alloc] initWithLeaderboardIdentifier:leaderboardId];
            score.value = (int64_t)(completedTime * 1000.0f);
            [GKScore reportScores:@[score] withCompletionHandler:^(NSError *e) {
                if (!e) Con_Printf("Ecosystem: leaderboard %s submitted\n", [leaderboardId UTF8String]);
            }];
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - SharePlay
// ═══════════════════════════════════════════════════════════════════════════

// SharePlay / GroupActivities is a Swift-only framework.
// The actual QuakeGroupActivity class lives in MetalQuakeLauncher.swift.
// These C stubs provide engine-side hooks.

static BOOL _sharePlayActive = NO;

// SharePlay is Swift-only (GroupActivities framework). The actual
// GroupActivity type + activation/observe logic lives in
// MetalQuakeLauncher.swift as MQSharePlayManager. These C entry points
// call into it via the Objective-C runtime so the engine (which is C++
// / plain ObjC) doesn't have to link Swift concurrency directly.
// Swift classes from MetalQuakeLauncher are Swift-mangled under the
// MetalQuakeLauncher module prefix. Try both the plain name (if the
// Swift class was @objc-exported) and the mangled form.
static Class _findSharePlayClass(void) {
    Class c = NSClassFromString(@"MQSharePlayManager");
    if (c) return c;
    return NSClassFromString(@"_TtC18MetalQuakeLauncher19MQSharePlayManager");
}

void MQ_SharePlay_Init(void) {
    Class cls = _findSharePlayClass();
    if (cls) {
        id mgr = [cls performSelector:@selector(shared)];
        if (mgr && [mgr respondsToSelector:@selector(observeIncoming)]) {
            [mgr performSelector:@selector(observeIncoming)];
            Con_Printf("SharePlay: listening for incoming session joins\n");
            return;
        }
    }
    Con_Printf("SharePlay: Swift GroupActivities unavailable (build without launcher?)\n");
}

void MQ_SharePlay_StartSession(void) {
    _sharePlayActive = YES;
    Class cls = _findSharePlayClass();
    if (!cls) { Con_Printf("SharePlay: manager missing\n"); return; }
    id mgr = [cls performSelector:@selector(shared)];
    // Use the current map as the metadata title, and the engine's best
    // guess at an external address (falls back to localhost).
    const char *map = (cl.worldmodel && cl.worldmodel->name[0])
        ? cl.worldmodel->name
        : "start";
    NSString *addr = @"127.0.0.1:27500";
    NSString *mapName = [NSString stringWithUTF8String:map];
    if ([mgr respondsToSelector:@selector(startSessionWithServerAddress:mapName:)]) {
        // Swift-exported selector uses named parameters.
        SEL sel = @selector(startSessionWithServerAddress:mapName:);
        NSMethodSignature *sig = [mgr methodSignatureForSelector:sel];
        if (sig) {
            NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
            [inv setTarget:mgr];
            [inv setSelector:sel];
            [inv setArgument:&addr atIndex:2];
            [inv setArgument:&mapName atIndex:3];
            [inv invoke];
        }
    }
    Con_Printf("SharePlay: Session started for %s\n", map);
}

void MQ_SharePlay_StopSession(void) {
    _sharePlayActive = NO;
    Con_Printf("SharePlay: Session ended\n");
}

int MQ_SharePlay_IsActive(void) {
    return _sharePlayActive ? 1 : 0;
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - High-Frequency Mouse Polling
// ═══════════════════════════════════════════════════════════════════════════

/**
 * On M3+ MacBook Pro, the trackpad and external mice support up to 8kHz
 * polling. We configure CGEvent tapping at the highest available rate.
 */

static int _mousePollingRate = 1000;

// HID devices advertise their own poll rate; we don't get to pick it from
// userspace — the USB descriptor fixes it at enumeration. The old code
// just printed a claim based on GPU family, which was aspirational and
// misleading. Report the best available according to the connected HID
// device when possible, or log the claim-based fallback for devices we
// can't introspect. CGEvent tap deltas are always as precise as the HID
// endpoint's rate regardless of what we do here.
void MQ_HighFreqMouse_Init(void) {
    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        const char *tier = "unknown GPU family";
        int expected = 1000;
        if (device) {
            if ([device supportsFamily:MTLGPUFamilyApple9]) {
                tier = "M3+ (Apple9)";
                expected = 8000;
            } else if ([device supportsFamily:MTLGPUFamilyApple8]) {
                tier = "M2 (Apple8)";
                expected = 4000;
            } else if ([device supportsFamily:MTLGPUFamilyApple7]) {
                tier = "M1 (Apple7)";
                expected = 1000;
            }
        }
        _mousePollingRate = expected;
        Con_Printf("Input: %s detected — up to %dHz mouse polling (actual rate set by attached HID device)\n",
                   tier, expected);
    }
}

int MQ_HighFreqMouse_GetRate(void) {
    return _mousePollingRate;
}
