#!/bin/bash

# Comprehensive build script for modern Quake on Apple Silicon
set -e

# Compile options
# -Wno-everything is used here to suppress warnings from the 1996 codebase
# in a real development environment, we would fix these or use specific flags.
CXX="clang++"
CC="clang"
CFLAGS="-O3 -g -std=c11 -I. -I./Quake -I./src/macos -I./metal-cpp -Wno-everything"
CXXFLAGS="-O3 -g -std=c++17 -fobjc-arc -I. -I./Quake -I./src/macos -I./metal-cpp -Wno-everything"
LDFLAGS="-framework Foundation -framework Metal -framework QuartzCore -framework GameController -framework CoreHaptics -framework Network -framework AudioUnit -framework AudioToolbox -framework AppKit -framework MetalKit"

# Weak-link frameworks not on all macOS versions
LDFLAGS="$LDFLAGS -Wl,-weak_framework,MetalFX"
LDFLAGS="$LDFLAGS -Wl,-weak_framework,PHASE"
LDFLAGS="$LDFLAGS -framework CoreML -framework GameKit"

# Common source files
COMMON_SOURCES=(
    Quake/chase.c
    Quake/cl_demo.c
    Quake/cl_input.c
    Quake/cl_main.c
    Quake/cl_parse.c
    Quake/cl_tent.c
    Quake/cmd.c
    Quake/qcommon.c
    Quake/console.c
    Quake/crc.c
    Quake/cvar.c
    Quake/draw.c
    Quake/host.c
    Quake/host_cmd.c
    Quake/keys.c
    Quake/mathlib.c
    Quake/menu.c
    Quake/model.c
    Quake/net_dgrm.c
    Quake/net_loop.c
    Quake/net_main.c
    Quake/net_vcr.c
    Quake/nonintel.c
    Quake/pr_cmds.c
    Quake/pr_edict.c
    Quake/pr_exec.c
    Quake/r_aclip.c
    Quake/r_alias.c
    Quake/r_bsp.c
    Quake/r_draw.c
    Quake/r_edge.c
    Quake/r_efrag.c
    Quake/r_light.c
    Quake/r_main.c
    Quake/r_misc.c
    Quake/r_part.c
    Quake/r_sky.c
    Quake/r_sprite.c
    Quake/r_surf.c
    Quake/r_vars.c
    Quake/sbar.c
    Quake/screen.c
    Quake/snd_dma.c
    Quake/snd_mem.c
    Quake/snd_mix.c
    Quake/sv_main.c
    Quake/sv_move.c
    Quake/sv_phys.c
    Quake/sv_user.c
    Quake/view.c
    Quake/wad.c
    Quake/world.c
    Quake/zone.c
    Quake/d_edge.c
    Quake/d_fill.c
    Quake/d_init.c
    Quake/d_modech.c
    Quake/d_part.c
    Quake/d_polyse.c
    Quake/d_scan.c
    Quake/d_sky.c
    Quake/d_sprite.c
    Quake/d_surf.c
    Quake/d_vars.c
    Quake/d_zpoint.c
)

# Apple-native implementations
MACOS_SOURCES=(
    Quake/sys_macos.m
    Quake/net_macos.c
    Quake/cd_null.c
    src/macos/vid_metal.cpp
    src/macos/Metal_Renderer_Main.cpp
    src/macos/Sys_Tahoe_Input.mm
    src/macos/snd_coreaudio.cpp
    src/macos/in_gamecontroller.mm
    src/macos/net_apple.cpp
    src/macos/GCD_Tasks.m
    src/macos/MetalQuakeBridge.m
    src/macos/MQ_PHASE_Audio.m
    src/macos/MQ_CoreML.m
    src/macos/MQ_Ecosystem.m
)

# Metal shader sources
METAL_SOURCES=(
    src/macos/rt_shader.metal
    src/macos/MQ_MeshShaders.metal
    src/macos/MQ_LiquidGlass.metal
)
# Swift sources (compiled separately with swiftc)
SWIFT_SOURCES=(
    src/macos/MetalQuakeLauncher.swift
)

echo "Building Quake for Apple Silicon..."

# Create build directory
rm -rf build_obj
mkdir -p build_obj

# Compile Metal shaders to .metallib
echo "Compiling Metal shaders..."
METAL_AIR_FILES=()
for f in "${METAL_SOURCES[@]}"; do
    air="build_obj/$(basename ${f%.metal}.air)"
    xcrun metal -c -target air64-apple-macos26.0 "$f" -o "$air" 2>&1 || {
        echo "Warning: Metal shader $f failed to compile — skipping"
        continue
    }
    METAL_AIR_FILES+=("$air")
done

if [ ${#METAL_AIR_FILES[@]} -gt 0 ]; then
    xcrun metallib "${METAL_AIR_FILES[@]}" -o quake_rt.metallib 2>&1 || {
        echo "Warning: metallib link failed — RT/Mesh shaders unavailable"
    }
    echo "Metal shaders compiled: quake_rt.metallib"
fi

OBJ_FILES=()

# Compile C files
for f in "${COMMON_SOURCES[@]}"; do
    obj="build_obj/$(basename ${f%.c}.o)"
    echo "Compiling $f..."
    $CC $CFLAGS -c "$f" -o "$obj"
    OBJ_FILES+=("$obj")
done

# Compile macOS Specific files
for f in "${MACOS_SOURCES[@]}"; do
    ext="${f##*.}"
    obj="build_obj/$(basename ${f%.$ext}.o)"
    echo "Compiling $f..."
    if [ "$ext" == "cpp" ] || [ "$ext" == "mm" ]; then
        $CXX $CXXFLAGS -c "$f" -o "$obj"
    else
        $CC $CFLAGS -c "$f" -o "$obj"
    fi
    OBJ_FILES+=("$obj")
done

# Compile Swift sources (SwiftUI launcher)
if [ ${#SWIFT_SOURCES[@]} -gt 0 ]; then
    echo "Compiling Swift sources..."
    SWIFT_OBJ="build_obj/MetalQuakeLauncher.o"
    swiftc -parse-as-library -emit-object -O \
        -import-objc-header src/macos/MetalQuakeBridge.h \
        -target arm64-apple-macos26.0 \
        -Xcc -I -Xcc ./Quake -Xcc -I -Xcc ./src/macos \
        "${SWIFT_SOURCES[@]}" \
        -o "$SWIFT_OBJ" 2>&1 || {
        echo "Warning: Swift compilation failed — launcher will not be available"
        SWIFT_OBJ=""
    }
    if [ -n "$SWIFT_OBJ" ]; then
        OBJ_FILES+=("$SWIFT_OBJ")
    fi
fi

echo "Linking..."
$CXX "${OBJ_FILES[@]}" -o quake_metal $LDFLAGS -framework SwiftUI -L$(xcrun --toolchain default --show-sdk-platform-path)/../../lib/swift/macosx -lswiftCore 2>/dev/null || \
$CXX "${OBJ_FILES[@]}" -o quake_metal $LDFLAGS 2>&1

echo "Build complete! Binary: ./quake_metal"
echo "Note: Ensure id1/pak0.pak is available for testing."
