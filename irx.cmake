# IRX from PS2SDK (match Makefile IOP_MODULES order)
set(IRX_FILES
    iomanX
    fileXio
    sio2man
    mcman
    extflash
    xfromman
    mcserv
    padman
    usbd_mini
    bdm
    bdmfs_fatfs
    usbmass_bd_mini
    mx4sio_bd_mini
    ps2dev9
    ata_bd
    ps2hdd
    ps2fs
)

# Local precompiled IRX under modules/
set(LOCAL_IRX_FILES mmceman)

# Optional IRX
if(POWERPC_UART)
  list(APPEND IRX_FILES ppctty)
endif()

# PS2SDK IRX -> bin2c -> _irx.c
foreach(IRX_FILE ${IRX_FILES})
  string(REPLACE "-" "_" irx_name_clean ${IRX_FILE})
  add_custom_command(
        OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/${irx_name_clean}_irx.c"
        COMMAND $ENV{PS2SDK}/bin/bin2c
                $ENV{PS2SDK}/iop/irx/${IRX_FILE}.irx
                "${CMAKE_CURRENT_BINARY_DIR}/${irx_name_clean}_irx.c"
                "${irx_name_clean}_irx"
        DEPENDS $ENV{PS2SDK}/iop/irx/${IRX_FILE}.irx
        COMMENT "Converting ${IRX_FILE}.irx with bin2c"
    )
  list(APPEND SOURCES "${CMAKE_CURRENT_BINARY_DIR}/${irx_name_clean}_irx.c")
endforeach()

# Local IRX -> bin2c -> _irx.c
foreach(IRX_FILE ${LOCAL_IRX_FILES})
  set(local_irx_path "${CMAKE_CURRENT_SOURCE_DIR}/modules/${IRX_FILE}.irx")
  add_custom_command(
        OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/${IRX_FILE}_irx.c"
        COMMAND $ENV{PS2SDK}/bin/bin2c
                "${local_irx_path}"
                "${CMAKE_CURRENT_BINARY_DIR}/${IRX_FILE}_irx.c"
                "${IRX_FILE}_irx"
        DEPENDS "${local_irx_path}"
        COMMENT "Converting local ${IRX_FILE}.irx with bin2c"
    )
  list(APPEND SOURCES "${CMAKE_CURRENT_BINARY_DIR}/${IRX_FILE}_irx.c")
endforeach()
