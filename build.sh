#!/bin/bash

# Comprehensive build script for modern Quake on Apple Silicon
# Fail fast on any command error including inside pipelines so a silent
# compile failure in one stage can't propagate a stale binary forward.
set -eo pipefail

# Compile options
# -Wno-everything is used here to suppress warnings from the 1996 codebase
# in a real development environment, we would fix these or use specific flags.
CXX="clang++"
CC="clang"
CFLAGS="-O3 -g -std=c11 -I. -I./src/core -I./src/macos -I./metal-cpp -Wno-everything"
CXXFLAGS="-O3 -g -std=c++17 -fobjc-arc -I. -I./src/core -I./src/macos -I./metal-cpp -Wno-everything"
OBJCFLAGS="-O3 -g -std=c11 -fobjc-arc -I. -I./src/core -I./src/macos -I./metal-cpp -Wno-everything"
LDFLAGS="-framework Foundation -framework Metal -framework QuartzCore -framework GameController -framework CoreHaptics -framework Network -framework CoreAudio -framework AudioUnit -framework AudioToolbox -framework AppKit -framework MetalKit"

# Weak-link frameworks not on all macOS versions
LDFLAGS="$LDFLAGS -Wl,-weak_framework,MetalFX"
LDFLAGS="$LDFLAGS -Wl,-weak_framework,PHASE"
LDFLAGS="$LDFLAGS -framework CoreML -framework GameKit -framework MetricKit"
# Apple-native frameworks for improvements
LDFLAGS="$LDFLAGS -framework Accelerate -framework MetalPerformanceShaders -framework MetalPerformanceShadersGraph -framework AVFoundation -framework CoreMedia -framework CoreVideo -framework NaturalLanguage"

# Common source files
COMMON_SOURCES=(
    src/core/chase.c
    src/core/cl_demo.c
    src/core/cl_input.c
    src/core/cl_main.c
    src/core/cl_parse.c
    src/core/cl_tent.c
    src/core/cmd.c
    src/core/qcommon.c
    src/core/console.c
    src/core/crc.c
    src/core/cvar.c
    src/core/draw.c
    src/core/host.c
    src/core/host_cmd.c
    src/core/keys.c
    src/core/mathlib.c
    src/core/menu.c
    src/core/model.c
    src/core/net_dgrm.c
    src/core/net_loop.c
    src/core/net_main.c
    src/core/net_vcr.c
    src/core/nonintel.c
    src/core/pr_cmds.c
    src/core/pr_edict.c
    src/core/pr_exec.c
    src/core/r_aclip.c
    src/core/r_alias.c
    src/core/r_bsp.c
    src/core/r_draw.c
    src/core/r_edge.c
    src/core/r_efrag.c
    src/core/r_light.c
    src/core/r_main.c
    src/core/r_misc.c
    src/core/r_part.c
    src/core/r_sky.c
    src/core/r_sprite.c
    src/core/r_surf.c
    src/core/r_vars.c
    src/core/sbar.c
    src/core/screen.c
    src/core/snd_dma.c
    src/core/snd_mem.c
    src/core/snd_mix.c
    src/core/sv_main.c
    src/core/sv_move.c
    src/core/sv_phys.c
    src/core/sv_user.c
    src/core/view.c
    src/core/wad.c
    src/core/world.c
    src/core/zone.c
    src/core/d_edge.c
    src/core/d_fill.c
    src/core/d_init.c
    src/core/d_modech.c
    src/core/d_part.c
    src/core/d_polyse.c
    src/core/d_scan.c
    src/core/d_sky.c
    src/core/d_sprite.c
    src/core/d_surf.c
    src/core/d_vars.c
    src/core/d_zpoint.c
)

# Apple-native implementations
MACOS_SOURCES=(
    src/macos/sys_macos.m
    src/core/net_macos.c
    src/core/cd_null.c
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
    src/macos/MQ_FrameInterp.m
    src/macos/MQ_Residency.m
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

# Create build directory (INCREMENTAL — do NOT rm -rf)
mkdir -p build_obj

# Compile Metal shaders to .metallib
echo "Compiling Metal shaders..."
METAL_AIR_FILES=()
for f in "${METAL_SOURCES[@]}"; do
    air="build_obj/$(basename ${f%.metal}.air)"
    xcrun metal -c -target air64-apple-macos14.0 "$f" -o "$air" 2>&1 || {
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
COMPILED=0
SKIPPED=0

# Compile C files (INCREMENTAL: only if source is newer than object)
for f in "${COMMON_SOURCES[@]}"; do
    obj="build_obj/$(basename ${f%.c}.o)"
    if [ "$f" -nt "$obj" ] || [ ! -f "$obj" ]; then
        echo "Compiling $f..."
        $CC $CFLAGS -c "$f" -o "$obj"
        COMPILED=$((COMPILED + 1))
    else
        SKIPPED=$((SKIPPED + 1))
    fi
    OBJ_FILES+=("$obj")
done

# Compile macOS Specific files (INCREMENTAL)
for f in "${MACOS_SOURCES[@]}"; do
    ext="${f##*.}"
    obj="build_obj/$(basename ${f%.$ext}.o)"
    if [ "$f" -nt "$obj" ] || [ ! -f "$obj" ]; then
        echo "Compiling $f..."
        if [ "$ext" == "cpp" ] || [ "$ext" == "mm" ]; then
            $CXX $CXXFLAGS -c "$f" -o "$obj"
        elif [ "$ext" == "m" ]; then
            $CC $OBJCFLAGS -c "$f" -o "$obj"
        else
            $CC $CFLAGS -c "$f" -o "$obj"
        fi
        COMPILED=$((COMPILED + 1))
    else
        SKIPPED=$((SKIPPED + 1))
    fi
    OBJ_FILES+=("$obj")
done

# Compile Swift sources (SwiftUI launcher)
if [ ${#SWIFT_SOURCES[@]} -gt 0 ]; then
    SWIFT_OBJ="build_obj/MetalQuakeLauncher.o"
    SWIFT_NEEDS_REBUILD=0
    for sf in "${SWIFT_SOURCES[@]}"; do
        if [ "$sf" -nt "$SWIFT_OBJ" ] || [ ! -f "$SWIFT_OBJ" ]; then
            SWIFT_NEEDS_REBUILD=1
            break
        fi
    done
    if [ $SWIFT_NEEDS_REBUILD -eq 1 ]; then
        echo "Compiling Swift sources..."
        swiftc -parse-as-library -emit-object -O \
            -import-objc-header src/macos/MetalQuakeBridge.h \
            -target arm64-apple-macos14.0 \
            -Xcc -I -Xcc ./src/core -Xcc -I -Xcc ./src/macos \
            "${SWIFT_SOURCES[@]}" \
            -o "$SWIFT_OBJ" 2>&1 || {
            echo "Warning: Swift compilation failed — launcher will not be available"
            SWIFT_OBJ=""
        }
        COMPILED=$((COMPILED + 1))
    else
        SKIPPED=$((SKIPPED + 1))
    fi
    if [ -n "$SWIFT_OBJ" ]; then
        OBJ_FILES+=("$SWIFT_OBJ")
    fi
fi

echo "Compiled: $COMPILED files, Skipped: $SKIPPED (up to date)"
echo "Linking..."
$CXX "${OBJ_FILES[@]}" -o quake_metal $LDFLAGS -framework SwiftUI -L$(xcrun --toolchain default --show-sdk-platform-path)/../../lib/swift/macosx -lswiftCore 2>/dev/null || \
$CXX "${OBJ_FILES[@]}" -o quake_metal $LDFLAGS 2>&1

echo "Creating App Bundle for Game Mode..."
rm -rf build/Quake.app
mkdir -p build/Quake.app/Contents/MacOS
mkdir -p build/Quake.app/Contents/Resources
cp quake_metal build/Quake.app/Contents/MacOS/Quake
if [ -f "quake_rt.metallib" ]; then
    cp quake_rt.metallib build/Quake.app/Contents/Resources/
fi

cat << 'EOF' > build/Quake.app/Contents/Info.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>Quake</string>
    <key>CFBundleIdentifier</key>
    <string>com.metalquake.engine</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Metal Quake</string>
    <key>CFBundleDisplayName</key>
    <string>Metal Quake</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.2.0</string>
    <key>CFBundleVersion</key>
    <string>1200</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.action-games</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Quake engine © 1996 id Software. Distributed under GPLv2.</string>
    <key>MetalCaptureEnabled</key>
    <true/>
    <key>GCSupportsControllerUserInteraction</key>
    <true/>
    <key>GCSupportsGameControllerFramework</key>
    <true/>
    <key>NSGameControllers</key>
    <array>
        <string>Extended</string>
        <string>DualSense</string>
        <string>Xbox</string>
    </array>
    <key>NSGameMode</key>
    <dict>
        <key>OnLaunch</key>
        <string>Active</string>
    </dict>
</dict>
</plist>
EOF

# Codesign the bundle.
#
# Local development: MQ_SIGN_IDENTITY unset → ad-hoc signing ("-"), which
#                    Gatekeeper accepts on the same machine.
# Distribution:      export MQ_SIGN_IDENTITY="Developer ID Application: You (TEAMID)"
#                    before running this script. The output bundle is then
#                    ready for notarization:
#
#   ditto -c -k --keepParent build/Quake.app build/Quake.zip
#   xcrun notarytool submit build/Quake.zip \
#         --apple-id you@example.com --team-id TEAMID \
#         --password @keychain:AC_PASSWORD --wait
#   xcrun stapler staple build/Quake.app
#
# --options runtime is required by the notary service.
SIGN_IDENTITY="${MQ_SIGN_IDENTITY:--}"
if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --sign "$SIGN_IDENTITY" \
             --options runtime \
             build/Quake.app 2>/dev/null || \
        echo "Warning: codesign with identity '$SIGN_IDENTITY' failed (continuing anyway)"
fi

echo "Build complete! Binary: build/Quake.app"
echo "Note: Ensure id1/pak0.pak is available for testing. Run with: open build/Quake.app"
