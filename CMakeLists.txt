cmake_minimum_required(VERSION 3.13)

include($ENV{PS2SDK}/ps2dev.cmake)

project(osdmenu-configurator)

# Executable names
set(EE_BIN "r3configurator_unc.elf")
set(EE_BIN_PKD "r3configurator.elf")

# Output directory
set(OUTDIR "release" CACHE STRING "Release directory")

# Options
option(ENABLE_DEBUG "Enable debugging mode" OFF)
option(EMBED_VFS "Embed bin/System/ as virtual filesystem" OFF)
option(POWERPC_UART "Enable PowerPC UART" OFF)

# Core + app sources
set(SOURCES
    src/main.cpp
    # Device support
    src/devices/init.cpp
    src/devices/pad.cpp
    src/devices/vfs.cpp
    src/devices/mc.cpp
    src/devices/utils.cpp
    # Graphics
    src/graphics/graphics.cpp
    src/graphics/render.cpp
    src/graphics/calc_3d.cpp
    src/graphics/gsKit3d_sup.cpp
    src/graphics/atlas.cpp
    src/graphics/fntsys.cpp
    src/graphics/splash.cpp
    # Lua bindings
    src/lua/player.cpp
    src/lua/controls.cpp
    src/lua/timer.cpp
    src/lua/screen.cpp
    src/lua/graphics.cpp
    src/lua/system.cpp
    src/lua/render.cpp
    src/lua/utils.cpp
)

# Embedded resources and IRX (append generated sources to SOURCES)
include(${CMAKE_CURRENT_SOURCE_DIR}/irx.cmake)
include(${CMAKE_CURRENT_SOURCE_DIR}/embed.cmake)

# Git version for splash (git describe --always --dirty --tags --exclude nightly)
find_package(Git QUIET)
if(GIT_FOUND)
  execute_process(
        COMMAND ${GIT_EXECUTABLE} describe --always --dirty --tags --exclude nightly
        OUTPUT_VARIABLE GIT_VERSION
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    )
  execute_process(
        COMMAND ${GIT_EXECUTABLE} rev-parse --short=12 HEAD
        OUTPUT_VARIABLE GIT_COMMIT
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    )
else()
  set(GIT_VERSION "unknown")
  set(GIT_COMMIT "unknown")
endif()

if(NOT GIT_VERSION)
  set(GIT_VERSION "unknown")
endif()

if(NOT GIT_COMMIT)
  set(GIT_COMMIT "unknown")
endif()

# App version shown in UI/splash:
# - defaults to git describe
# - can be overridden by CI/release jobs (e.g. 1.2.0)
set(APP_VERSION_OVERRIDE "" CACHE STRING "Optional override for displayed app version (e.g. 1.2.0)")
if(APP_VERSION_OVERRIDE STREQUAL "")
  set(APP_VERSION_VALUE "${GIT_VERSION}")
else()
  set(APP_VERSION_VALUE "${APP_VERSION_OVERRIDE}")
endif()
if(APP_VERSION_VALUE STREQUAL "")
  set(APP_VERSION_VALUE "unknown")
endif()

add_definitions(-DAPP_VERSION=\"${APP_VERSION_VALUE}\")
add_definitions(-DLUA_USE_PS2)

if(ENABLE_DEBUG)
  add_definitions(-DDEBUG)
endif()

if(EMBED_VFS)
  add_definitions(-DEMBED_VFS)
endif()

if(POWERPC_UART)
  add_definitions(-DPOWERPC_UART)
endif()

# Compiler flags (match Makefile)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wno-sign-compare -fno-strict-aliasing -fno-exceptions")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wno-sign-compare -fno-strict-aliasing -fno-exceptions")

# Main executable
add_executable(${EE_BIN} ${SOURCES})

target_include_directories(${EE_BIN}
    PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src/include
    $ENV{PS2DEV}/gsKit/include
    $ENV{PS2SDK}/ports/include
    $ENV{PS2SDK}/ports/include/freetype2
    $ENV{PS2SDK}/ports/include/zlib
)

# Link directories (match Makefile -L flags so libs are found)
target_link_directories(${EE_BIN}
    PRIVATE
    $ENV{PS2SDK}/ports/lib
    $ENV{PS2DEV}/gsKit/lib
)

target_link_libraries(${EE_BIN}
    patches
    fileXio
    pad
    libdebug.a
    lua
    math3d
    freetype
    gskit_toolkit
    gskit
    dmakit
    png
    z
    mc
)

# SAS/title.cfg metadata configuration:
# - Version defaults to the app version shown in UI
# - Release date is generated at build time (ordinal format)
set(SAS_TITLE_VERSION "" CACHE STRING "Optional override for SAS/title.cfg Version field; defaults to app display version")
if(SAS_TITLE_VERSION STREQUAL "")
  set(SAS_TITLE_VERSION_VALUE "${APP_VERSION_VALUE}")
else()
  set(SAS_TITLE_VERSION_VALUE "${SAS_TITLE_VERSION}")
endif()

if(SAS_TITLE_VERSION_VALUE STREQUAL "")
  set(SAS_TITLE_VERSION_VALUE "unknown")
endif()

set(SAS_TITLE_SOURCE "${CMAKE_SOURCE_DIR}/SAS/title.cfg")
set(SAS_TITLE_GENERATED "${CMAKE_CURRENT_BINARY_DIR}/generated/SAS/title.cfg")
set(SAS_TITLE_GEN_SCRIPT "${CMAKE_SOURCE_DIR}/cmake/generate_title_cfg.cmake")
set(SAS_ICON_SYS_SOURCE "${CMAKE_SOURCE_DIR}/SAS/icon.sys")
set(SAS_COPY_ICN_SOURCE "${CMAKE_SOURCE_DIR}/SAS/copy.icn")
set(SAS_DEL_ICN_SOURCE "${CMAKE_SOURCE_DIR}/SAS/del.icn")
set(SAS_LIST_ICN_SOURCE "${CMAKE_SOURCE_DIR}/SAS/list.icn")

# Strip ELF from debug symbols
# set_target_properties(${EE_BIN} PROPERTIES LINK_FLAGS "-s")

add_custom_command(
    TARGET ${EE_BIN}
    POST_BUILD
    COMMAND ${PS2DEV}/bin/ps2-packer
            $<TARGET_FILE:${EE_BIN}>
            ${CMAKE_CURRENT_BINARY_DIR}/${EE_BIN_PKD}
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    COMMENT "Packing ${EE_BIN} as ${EE_BIN_PKD}"
)

if(EMBED_VFS)
  add_custom_command(
        TARGET ${EE_BIN}
        POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E make_directory ${OUTDIR}/
        COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_SOURCE_DIR}/README.md ${OUTDIR}/
        COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_SOURCE_DIR}/r3configurator.cnf ${OUTDIR}/r3configurator.cnf
        COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_CURRENT_BINARY_DIR}/${EE_BIN_PKD} ${OUTDIR}/${EE_BIN_PKD}
        COMMAND ${CMAKE_COMMAND} -DINPUT=${SAS_TITLE_SOURCE}
                                 -DOUTPUT=${SAS_TITLE_GENERATED}
                                 -DTITLE_VERSION=${SAS_TITLE_VERSION_VALUE}
                                 -P ${SAS_TITLE_GEN_SCRIPT}
        COMMAND ${CMAKE_COMMAND} -E copy ${SAS_TITLE_GENERATED} ${OUTDIR}/title.cfg
        COMMAND ${CMAKE_COMMAND} -E copy ${SAS_ICON_SYS_SOURCE} ${OUTDIR}/icon.sys
        COMMAND ${CMAKE_COMMAND} -E copy ${SAS_COPY_ICN_SOURCE} ${OUTDIR}/copy.icn
        COMMAND ${CMAKE_COMMAND} -E copy ${SAS_DEL_ICN_SOURCE} ${OUTDIR}/del.icn
        COMMAND ${CMAKE_COMMAND} -E copy ${SAS_LIST_ICN_SOURCE} ${OUTDIR}/list.icn
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        COMMENT "Copying ELF and SAS assets to release directory root"
    )
else()
  add_custom_command(
        TARGET ${EE_BIN}
        POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E make_directory ${OUTDIR}/
        COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_SOURCE_DIR}/README.md ${OUTDIR}/
        COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_SOURCE_DIR}/r3configurator.cnf ${OUTDIR}/r3configurator.cnf
        COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_CURRENT_BINARY_DIR}/${EE_BIN_PKD} ${OUTDIR}/${EE_BIN_PKD}
        COMMAND ${CMAKE_COMMAND} -E copy_directory ${CMAKE_SOURCE_DIR}/scripts ${OUTDIR}/scripts
        COMMAND ${CMAKE_COMMAND} -DINPUT=${SAS_TITLE_SOURCE}
                                 -DOUTPUT=${SAS_TITLE_GENERATED}
                                 -DTITLE_VERSION=${SAS_TITLE_VERSION_VALUE}
                                 -P ${SAS_TITLE_GEN_SCRIPT}
        COMMAND ${CMAKE_COMMAND} -E copy ${SAS_TITLE_GENERATED} ${OUTDIR}/title.cfg
        COMMAND ${CMAKE_COMMAND} -E copy ${SAS_ICON_SYS_SOURCE} ${OUTDIR}/icon.sys
        COMMAND ${CMAKE_COMMAND} -E copy ${SAS_COPY_ICN_SOURCE} ${OUTDIR}/copy.icn
        COMMAND ${CMAKE_COMMAND} -E copy ${SAS_DEL_ICN_SOURCE} ${OUTDIR}/del.icn
        COMMAND ${CMAKE_COMMAND} -E copy ${SAS_LIST_ICN_SOURCE} ${OUTDIR}/list.icn
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        COMMENT "Copying ELF, scripts, and SAS assets to release directory root"
    )
endif()
