# Embedded resources: paths relative to source dir
set(EMBED_FILES
    res/boot.lua
    res/title.png
    res/loading.png
)

set(EMBED_BINDIR ${CMAKE_CURRENT_BINARY_DIR})

foreach(INPUT_PATH ${EMBED_FILES})
    get_filename_component(NAME "${INPUT_PATH}" NAME)
    string(REPLACE "." "_" SYMBOL "${NAME}")
    set(INPUT_ABS ${CMAKE_CURRENT_SOURCE_DIR}/${INPUT_PATH})
    set(OUTPUT_C ${EMBED_BINDIR}/${SYMBOL}.c)
    add_custom_command(
        OUTPUT ${OUTPUT_C}
        COMMAND $ENV{PS2SDK}/bin/bin2c ${INPUT_ABS} ${OUTPUT_C} ${SYMBOL}
        DEPENDS ${INPUT_ABS}
        COMMENT "Converting ${INPUT_PATH} with bin2c"
    )
    list(APPEND SOURCES ${OUTPUT_C})
endforeach()

# Optional: virtual filesystem from scripts/
if(EMBED_VFS)
    set(BUILD_VFS ${CMAKE_CURRENT_SOURCE_DIR}/tools/build_vfs.py)
    set(SCRIPT_DIR ${CMAKE_CURRENT_SOURCE_DIR}/scripts)
    file(GLOB_RECURSE VFS_FILES "${SCRIPT_DIR}/*")
    add_custom_command(
        OUTPUT ${EMBED_BINDIR}/vfs.bin
        COMMAND ${CMAKE_COMMAND} -E env PYTHONIOENCODING=utf-8
                python3 ${BUILD_VFS}
                ${CMAKE_CURRENT_SOURCE_DIR}
                ${EMBED_BINDIR}/vfs.bin
        DEPENDS ${BUILD_VFS} ${VFS_FILES}
        COMMENT "Building VFS from scripts/"
    )
    add_custom_command(
        OUTPUT ${EMBED_BINDIR}/vfs.c
        COMMAND $ENV{PS2SDK}/bin/bin2c ${EMBED_BINDIR}/vfs.bin ${EMBED_BINDIR}/vfs.c vfs
        DEPENDS ${EMBED_BINDIR}/vfs.bin
        COMMENT "Converting vfs.bin with bin2c"
    )
    list(APPEND SOURCES ${EMBED_BINDIR}/vfs.c)
endif()
