/*
Copyright (C) 1996-1997 Id Software, Inc.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

*/
// cd_macos.m -- AVFoundation-based music player for Quake CD audio interface

#include "quakedef.h"
#import <AVFoundation/AVFoundation.h>

extern char com_gamedir[MAX_OSPATH];

// ---------------------------------------------------------------------------
// Module state
// ---------------------------------------------------------------------------

static AVAudioPlayer   *musicPlayer  = nil;
static cvar_t           cd_volume    = {"cd_volume", "1", true};
static float            lastVolume   = -1.0f;

static qboolean         initialized  = false;
static qboolean         enabled      = true;
static qboolean         playing      = false;
static qboolean         paused       = false;
static qboolean         playLooping  = false;
static byte             playTrack    = 0;

// Track map: index is track number (2-11), value is the path found on disk,
// or nil if the track is not present.
#define MAX_TRACKS 100
static NSString        *trackPaths[MAX_TRACKS];

// Extensions to try, in priority order.
static const char      *trackExts[] = { "ogg", "mp3", "m4a", "flac", "wav", "caf", NULL };

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

// Return a retained NSString path for the first matching file, or nil.
static NSString *FindTrackFile(int trackNum)
{
    for (int i = 0; trackExts[i] != NULL; i++)
    {
        char path[MAX_OSPATH * 2];
        snprintf(path, sizeof(path), "%s/music/track%02d.%s",
                 com_gamedir, trackNum, trackExts[i]);

        NSString *nspath = [NSString stringWithUTF8String:path];
        if ([[NSFileManager defaultManager] fileExistsAtPath:nspath])
            return nspath;
    }
    return nil;
}

// Clamp a float to [0, 1].
static inline float ClampVolume(float v)
{
    if (v < 0.0f) return 0.0f;
    if (v > 1.0f) return 1.0f;
    return v;
}

// Apply the current cd_volume cvar to the active player.
static void ApplyVolume(void)
{
    if (!musicPlayer)
        return;
    float vol = ClampVolume(cd_volume.value);
    musicPlayer.volume = vol;
    lastVolume = vol;
}

// ---------------------------------------------------------------------------
// Public CD audio interface
// ---------------------------------------------------------------------------

int CDAudio_Init(void)
{
    int n;
    int found = 0;

    if (cls.state == ca_dedicated)
        return -1;

    if (COM_CheckParm("-nocdaudio"))
        return -1;

    @autoreleasepool
    {
        // Scan for track files track02 through track99 (track 1 is data).
        for (n = 2; n < MAX_TRACKS; n++)
            trackPaths[n] = nil;

        for (n = 2; n < MAX_TRACKS; n++)
        {
            NSString *path = FindTrackFile(n);
            if (path)
            {
                trackPaths[n] = [path retain];
                Con_Printf("CDAudio: found track %02d: %s\n", n,
                           [path fileSystemRepresentation]);
                found++;
            }
        }
    }

    Cvar_RegisterVariable(&cd_volume);

    initialized = true;
    enabled     = true;

    if (found == 0)
        Con_Printf("CDAudio_Init: no music tracks found in %s/music/\n", com_gamedir);
    else
        Con_Printf("CDAudio_Init: %d music track(s) available.\n", found);

    return 0;
}


void CDAudio_Play(byte track, qboolean looping)
{
    if (!initialized || !enabled)
        return;

    if (track < 2 || track >= MAX_TRACKS)
    {
        Con_DPrintf("CDAudio_Play: bad track number %u\n", track);
        return;
    }

    // If the same track is already playing, do nothing.
    if (playing && !paused && playTrack == track)
        return;

    // Stop whatever is currently playing.
    CDAudio_Stop();

    @autoreleasepool
    {
        NSString *path = trackPaths[track];
        if (!path)
        {
            // No file for this track — silent, not an error.
            Con_DPrintf("CDAudio_Play: no file for track %u\n", track);
            return;
        }

        NSURL *url = [NSURL fileURLWithPath:path];
        NSError *error = nil;
        AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL:url
                                                                       error:&error];

        if (!player)
        {
            // OGG may fail on systems without a suitable codec — warn and bail.
            Con_Printf("CDAudio_Play: could not open track %u (%s): %s\n",
                       track,
                       [path fileSystemRepresentation],
                       [[error localizedDescription] UTF8String]);
            return;
        }

        player.numberOfLoops = looping ? -1 : 0;  // -1 = loop forever
        player.volume        = ClampVolume(cd_volume.value);
        lastVolume           = player.volume;

        if (![player prepareToPlay])
        {
            Con_DPrintf("CDAudio_Play: prepareToPlay failed for track %u\n", track);
            [player release];
            return;
        }

        if (![player play])
        {
            Con_DPrintf("CDAudio_Play: play failed for track %u\n", track);
            [player release];
            return;
        }

        musicPlayer  = [player retain];
        [player release];
    }

    playTrack   = track;
    playLooping = looping;
    playing     = true;
    paused      = false;
}


void CDAudio_Stop(void)
{
    if (!initialized)
        return;

    if (musicPlayer)
    {
        [musicPlayer stop];
        [musicPlayer release];
        musicPlayer = nil;
    }

    playing = false;
    paused  = false;
}


void CDAudio_Pause(void)
{
    if (!initialized || !playing || paused)
        return;

    if (musicPlayer)
        [musicPlayer pause];

    paused = true;
}


void CDAudio_Resume(void)
{
    if (!initialized || !playing || !paused)
        return;

    if (musicPlayer)
    {
        musicPlayer.volume = ClampVolume(cd_volume.value);
        lastVolume = musicPlayer.volume;
        [musicPlayer play];
    }

    paused = false;
}


void CDAudio_Update(void)
{
    if (!initialized || !enabled)
        return;

    // Keep volume in sync with the cvar.
    float vol = ClampVolume(cd_volume.value);
    if (vol != lastVolume && musicPlayer)
    {
        musicPlayer.volume = vol;
        lastVolume = vol;
    }

    // If not looping, detect natural end-of-track and restart if needed.
    // (AVAudioPlayer with numberOfLoops == 0 stops on its own; we just clear
    // the playing flag so the next CDAudio_Play call works cleanly.)
    if (playing && !paused && musicPlayer)
    {
        if (!musicPlayer.isPlaying)
        {
            // Track finished naturally.
            [musicPlayer release];
            musicPlayer = nil;
            playing     = false;

            if (playLooping)
            {
                // Shouldn't happen (numberOfLoops == -1 when looping), but be safe.
                CDAudio_Play(playTrack, true);
            }
        }
    }
}


void CDAudio_Shutdown(void)
{
    if (!initialized)
        return;

    CDAudio_Stop();

    // Release cached path strings.
    for (int n = 0; n < MAX_TRACKS; n++)
    {
        if (trackPaths[n])
        {
            [trackPaths[n] release];
            trackPaths[n] = nil;
        }
    }

    initialized = false;
}
