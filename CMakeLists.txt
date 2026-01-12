cmake_minimum_required(VERSION 3.15)
project(Quake VERSION 1.09 LANGUAGES C OBJC)

set(CMAKE_C_STANDARD 99)
set(CMAKE_OBJC_STANDARD 99)

# Define source files
set(SOURCES
    WinQuake/cl_demo.c
    WinQuake/cl_input.c
    WinQuake/cl_main.c
    WinQuake/cl_parse.c
    WinQuake/cl_tent.c
    WinQuake/chase.c
    WinQuake/cmd.c
    WinQuake/common.c
    WinQuake/console.c
    WinQuake/crc.c
    WinQuake/cvar.c
    WinQuake/draw.c
    WinQuake/d_edge.c
    WinQuake/d_fill.c
    WinQuake/d_init.c
    WinQuake/d_modech.c
    WinQuake/d_part.c
    WinQuake/d_polyse.c
    WinQuake/d_scan.c
    WinQuake/d_sky.c
    WinQuake/d_sprite.c
    WinQuake/d_surf.c
    WinQuake/d_vars.c
    WinQuake/d_zpoint.c
    WinQuake/host.c
    WinQuake/host_cmd.c
    WinQuake/keys.c
    WinQuake/menu.c
    WinQuake/mathlib.c
    WinQuake/model.c
    WinQuake/net_dgrm.c
    WinQuake/net_loop.c
    WinQuake/net_main.c
    WinQuake/net_vcr.c
    WinQuake/net_udp.c
    WinQuake/net_bsd.c
    WinQuake/nonintel.c
    WinQuake/pr_cmds.c
    WinQuake/pr_edict.c
    WinQuake/pr_exec.c
    WinQuake/r_aclip.c
    WinQuake/r_alias.c
    WinQuake/r_bsp.c
    WinQuake/r_light.c
    WinQuake/r_draw.c
    WinQuake/r_efrag.c
    WinQuake/r_edge.c
    WinQuake/r_misc.c
    WinQuake/r_main.c
    WinQuake/r_sky.c
    WinQuake/r_sprite.c
    WinQuake/r_surf.c
    WinQuake/r_part.c
    WinQuake/r_vars.c
    WinQuake/screen.c
    WinQuake/sbar.c
    WinQuake/sv_main.c
    WinQuake/sv_phys.c
    WinQuake/sv_move.c
    WinQuake/sv_user.c
    WinQuake/zone.c
    WinQuake/view.c
    WinQuake/wad.c
    WinQuake/world.c
    WinQuake/cd_null.c
    # Platform specific
    WinQuake/sys_macos.m
    WinQuake/vid_metal.m
    WinQuake/snd_macos.m
    WinQuake/in_macos.m
)

# Add macOS frameworks
find_library(COCOA_FRAMEWORK Cocoa)
find_library(METAL_FRAMEWORK Metal)
find_library(METALKIT_FRAMEWORK MetalKit)
find_library(IOKIT_FRAMEWORK IOKit)
find_library(AUDIO_TOOLBOX_FRAMEWORK AudioToolbox)
find_library(AVFOUNDATION_FRAMEWORK AVFoundation)

add_executable(Quake MACOSX_BUNDLE ${SOURCES})

target_link_libraries(Quake
    PRIVATE
    ${COCOA_FRAMEWORK}
    ${METAL_FRAMEWORK}
    ${METALKIT_FRAMEWORK}
    ${IOKIT_FRAMEWORK}
    ${AUDIO_TOOLBOX_FRAMEWORK}
    ${AVFOUNDATION_FRAMEWORK}
)

target_include_directories(Quake PRIVATE WinQuake)

set_target_properties(Quake PROPERTIES
    MACOSX_BUNDLE_BUNDLE_NAME "Quake"
    MACOSX_BUNDLE_GUI_IDENTIFIER "com.idsoftware.quake"
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/Info.plist.in"
)

# Placeholder Info.plist
file(WRITE ${CMAKE_CURRENT_SOURCE_DIR}/Info.plist.in
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
    <!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
    <plist version=\"1.0\">
    <dict>
        <key>CFBundleExecutable</key>
        <string>\$(EXECUTABLE_NAME)</string>
        <key>CFBundleIdentifier</key>
        <string>com.idsoftware.quake</string>
        <key>CFBundleName</key>
        <string>Quake</string>
        <key>CFBundlePackageType</key>
        <string>APPL</string>
        <key>CFBundleShortVersionString</key>
        <string>1.0</string>
        <key>LSMinimumSystemVersion</key>
        <string>10.15</string>
    </dict>
    </plist>"
)
