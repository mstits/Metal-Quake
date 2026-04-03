cmake_minimum_required(VERSION 3.15)
project(Quake VERSION 1.09 LANGUAGES C CXX OBJC OBJCXX)

set(CMAKE_C_STANDARD 99)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_OBJC_STANDARD 99)

# Suppress warnings from the 1996 codebase.
# In a real development environment, fix these or use specific flags.
add_compile_options(-Wno-everything)

# Enable ARC for Objective-C/C++ files
set(CMAKE_OBJC_FLAGS "${CMAKE_OBJC_FLAGS} -fobjc-arc")
set(CMAKE_OBJCXX_FLAGS "${CMAKE_OBJCXX_FLAGS} -fobjc-arc")

# Common Quake engine sources (C)
set(COMMON_SOURCES
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

# macOS platform sources
set(MACOS_SOURCES
    src/macos/sys_macos.m
    src/core/net_macos.c
    src/core/cd_null.c
    src/macos/vid_metal.cpp
    src/macos/snd_coreaudio.cpp
    src/macos/in_gamecontroller.mm
    src/macos/net_apple.cpp
)

add_executable(quake_metal ${COMMON_SOURCES} ${MACOS_SOURCES})

target_include_directories(quake_metal PRIVATE
    src/core
    src/macos
    metal-cpp
)

# Required Apple frameworks
target_link_libraries(quake_metal PRIVATE
    "-framework Foundation"
    "-framework Metal"
    "-framework QuartzCore"
    "-framework AppKit"
    "-framework MetalKit"
    "-framework AudioUnit"
    "-framework AudioToolbox"
    "-framework GameController"
    "-framework CoreHaptics"
    "-framework Network"
)

# MetalFX is only available on macOS 13.0+
target_link_options(quake_metal PRIVATE "-Wl,-weak_framework,MetalFX")

# Build settings
set_target_properties(quake_metal PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}"
)
