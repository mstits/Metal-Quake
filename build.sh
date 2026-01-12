#!/bin/bash
set -e

mkdir -p build/Quake.app/Contents/MacOS
mkdir -p build/Quake.app/Contents/Resources

# Create PkgInfo
echo "APPL????" > build/Quake.app/Contents/PkgInfo

# Compile
echo "Compiling..."
clang -o build/Quake.app/Contents/MacOS/Quake \
    -O2 -g \
    -D__APPLE__ -DQuake \
    -IWinQuake \
    -framework Cocoa -framework Metal -framework MetalKit -framework IOKit -framework AudioToolbox -framework AVFoundation \
    WinQuake/cl_demo.c \
    WinQuake/cl_input.c \
    WinQuake/cl_main.c \
    WinQuake/cl_parse.c \
    WinQuake/cl_tent.c \
    WinQuake/chase.c \
    WinQuake/cmd.c \
    WinQuake/qcommon.c \
    WinQuake/console.c \
    WinQuake/crc.c \
    WinQuake/cvar.c \
    WinQuake/draw.c \
    WinQuake/d_edge.c \
    WinQuake/d_fill.c \
    WinQuake/d_init.c \
    WinQuake/d_modech.c \
    WinQuake/d_part.c \
    WinQuake/d_polyse.c \
    WinQuake/d_scan.c \
    WinQuake/d_sky.c \
    WinQuake/d_sprite.c \
    WinQuake/d_surf.c \
    WinQuake/d_vars.c \
    WinQuake/d_zpoint.c \
    WinQuake/host.c \
    WinQuake/host_cmd.c \
    WinQuake/keys.c \
    WinQuake/menu.c \
    WinQuake/mathlib.c \
    WinQuake/model.c \
    WinQuake/net_dgrm.c \
    WinQuake/net_loop.c \
    WinQuake/net_main.c \
    WinQuake/net_vcr.c \
    WinQuake/net_udp.c \
    WinQuake/net_bsd.c \
    WinQuake/nonintel.c \
    WinQuake/pr_cmds.c \
    WinQuake/pr_edict.c \
    WinQuake/pr_exec.c \
    WinQuake/r_aclip.c \
    WinQuake/r_alias.c \
    WinQuake/r_bsp.c \
    WinQuake/r_light.c \
    WinQuake/r_draw.c \
    WinQuake/r_efrag.c \
    WinQuake/r_edge.c \
    WinQuake/r_misc.c \
    WinQuake/r_main.c \
    WinQuake/r_sky.c \
    WinQuake/r_sprite.c \
    WinQuake/r_surf.c \
    WinQuake/r_part.c \
    WinQuake/r_vars.c \
    WinQuake/screen.c \
    WinQuake/sbar.c \
    WinQuake/sv_main.c \
    WinQuake/sv_phys.c \
    WinQuake/sv_move.c \
    WinQuake/sv_user.c \
    WinQuake/zone.c \
    WinQuake/view.c \
    WinQuake/wad.c \
    WinQuake/world.c \
    WinQuake/snd_dma.c \
    WinQuake/snd_mix.c \
    WinQuake/snd_mem.c \
    WinQuake/cd_null.c \
    WinQuake/sys_macos.m \
    WinQuake/vid_metal.m \
    WinQuake/snd_macos.m \
    WinQuake/in_macos.m

# Copy Info.plist
cp Info.plist.in build/Quake.app/Contents/Info.plist

# Ad-hoc code signing (Required for Apple Silicon/arm64)
echo "Signing application..."
codesign --force --deep --sign - build/Quake.app

echo "Build complete: build/Quake.app"
