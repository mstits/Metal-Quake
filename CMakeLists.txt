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

# macOS platform sources
set(MACOS_SOURCES
    Quake/sys_macos.m
    Quake/net_macos.c
    Quake/cd_null.c
    src/macos/vid_metal.cpp
    src/macos/snd_coreaudio.cpp
    src/macos/in_gamecontroller.mm
    src/macos/net_apple.cpp
)

add_executable(quake_metal ${COMMON_SOURCES} ${MACOS_SOURCES})

target_include_directories(quake_metal PRIVATE
    Quake
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
