#include "devices/init.h"
#include "devices/mc.h"
#include "devices/pad.h"
#include <iopcontrol.h>
#include <loadfile.h>
#include <sbv_patches.h>
#include <sifrpc.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#define NEWLIB_PORT_AWARE
#include <fileXio_rpc.h>

// Macros for loading embedded IOP modules
#define IRX_DEFINE(mod)                                                                                                                              \
  extern uint32_t mod##_irx[];                                                                                                                       \
  extern uint32_t size_##mod##_irx
#define INT_MODULE(mod, argFunc, deviceType) {#mod, mod##_irx, &size_##mod##_irx, argFunc, deviceType}

// Function used to initialize module arguments. Returned pointer must point to static or const data.
typedef const char *(*moduleArgFunc)(uint32_t *argLength);

typedef struct ModuleListEntry {
  const char *name;
  uint32_t *irx;
  uint32_t *size;
  moduleArgFunc argumentFunction;
  uint32_t type;
} ModuleListEntry;

#ifdef POWERPC_UART
IRX_DEFINE(ppctty);
#endif
IRX_DEFINE(iomanX);
IRX_DEFINE(fileXio);
IRX_DEFINE(sio2man);
IRX_DEFINE(mcman);
IRX_DEFINE(mcserv);
IRX_DEFINE(padman);
IRX_DEFINE(usbd_mini);
IRX_DEFINE(bdm);
IRX_DEFINE(bdmfs_fatfs);
IRX_DEFINE(usbmass_bd_mini);
IRX_DEFINE(mx4sio_bd_mini);
IRX_DEFINE(mmceman);
IRX_DEFINE(ps2dev9);
IRX_DEFINE(ata_bd);
IRX_DEFINE(ps2hdd);
IRX_DEFINE(ps2fs);

// Used to keep track of loaded device modules and devices
static uint32_t loadedModules = 0;
static uint32_t loadedDevices = 0;

// ps2hdd and ps2fs init args
static const char *get_ps2hdd_args(uint32_t *len);
static const char *get_ps2fs_args(uint32_t *len);

// List of modules to load, in order
static ModuleListEntry moduleList[] = {
// Basic modules
#ifdef POWERPC_UART
    INT_MODULE(ppctty, NULL, Device_Basic),
#endif
    INT_MODULE(iomanX, NULL, Device_Basic),
    INT_MODULE(fileXio, NULL, Device_Basic),
    INT_MODULE(sio2man, NULL, Device_Basic),
    INT_MODULE(mcman, NULL, Device_Basic),
    INT_MODULE(mcserv, NULL, Device_Basic),
    INT_MODULE(padman, NULL, Device_Basic),
    // MMCE
    INT_MODULE(mmceman, NULL, Device_MMCE),
    // BDM
    INT_MODULE(bdm, NULL, Device_USB | Device_HDD | Device_MX4SIO),
    INT_MODULE(bdmfs_fatfs, NULL, Device_USB | Device_HDD | Device_MX4SIO),
    // HDD
    INT_MODULE(ps2dev9, NULL, Device_HDD),
    INT_MODULE(ata_bd, NULL, Device_HDD),
    INT_MODULE(ps2hdd, get_ps2hdd_args, Device_HDD),
    INT_MODULE(ps2fs, get_ps2fs_args, Device_HDD),
    // USB
    INT_MODULE(usbd_mini, NULL, Device_USB),
    INT_MODULE(usbmass_bd_mini, NULL, Device_USB),
    // MX4SIO
    INT_MODULE(mx4sio_bd_mini, NULL, Device_MX4SIO),
};
#define MODULE_COUNT (sizeof(moduleList) / sizeof(moduleList[0]))

static void iop_reboot(void) {
  printf("devices_init: rebooting IOP\n");
  SifInitRpc(0);
  while (!SifIopReset("", 0)) {
  };
  while (!SifIopSync()) {
  };
  SifInitRpc(0);

  // Apply SBV patches on every IOP reboot (required to load modules from EE RAM)
  sbv_patch_enable_lmb();
  sbv_patch_disable_prefix_check();
  sbv_patch_fileio();
}

// Load a single module entry
static int load_module(ModuleListEntry *mod) {
  uint32_t arglen = 0;
  const char *argStr = NULL;

  if (mod->argumentFunction != NULL) {
    argStr = mod->argumentFunction(&arglen);
    if (argStr == NULL)
      return -1;
  }

  printf("devices_init: loading %s\n", mod->name);
  int iopret = 0;
  int ret = SifExecModuleBuffer(mod->irx, *mod->size, arglen, (char *)argStr, &iopret);
  printf("devices_init: loaded %s with id: %d, ret:%d\n", mod->name, ret, iopret);
  if (ret < 0)
    return ret;
  if (iopret == 1)
    ret = -2;

  // Delay to prevent ps2hdd module from hanging
  if ((mod->type & Device_HDD) && !strcmp(mod->name, "ata_bd"))
    sleep(1);
  return ret;
}

// Initializes IOP modules for given device type. Does not reboot IOP.
static int init_modules(uint32_t device) {
  int res = 0;
  for (int i = 0; i < (int)MODULE_COUNT; i++) {
    // Ignore unneeded and already loaded modules
    if (!(device & moduleList[i].type) || (loadedModules & (1u << i)))
      continue;

    if ((res = load_module(&moduleList[i]) != 0) < 0)
      return res;

    // Mark module as loaded
    loadedModules |= (1u << i);
  }
  // Mark device as initialized
  loadedDevices |= device;
  return 0;
}

// Load basic IOP modules (iomanX, fileXio, sio2man, mcman, mcserv, padman) and init device services.
// Will reboot IOP and reinitialize device services on every call.
// Returns 0 on success.
int device_init(void) {
  if (loadedDevices) {
    // Deinit device services
    mc_deinit();
    pad_deinit();
    fileXioExit();
  }

  // Reboot IOP
  iop_reboot();
  loadedDevices = 0;
  loadedModules = 0;

  // Initialize basic modules
  int r = init_modules(Device_Basic);

  // Initialize device services
  fileXioInit();
  mc_init();
  pad_init();

  return r;
}

// Supported device type names for loadModules (not arbitrary IRX names).
// "hdd" = full HDD stack (ATA + APA: ata_bd, ps2hdd, ps2fs). "usb", "mx4sio", "mmce".
static uint32_t device_string_to_type(const char *name) {
  if (strcmp(name, "hdd") == 0)
    return Device_HDD;
  if (strcmp(name, "usb") == 0)
    return Device_USB;
  if (strcmp(name, "mx4sio") == 0)
    return Device_MX4SIO;
  if (strcmp(name, "mmce") == 0)
    return Device_MMCE;
  return 0;
}

// Load IOP modules by device type or by IRX name.
// Supported device types:
// - "mmce"
// - "hdd" (both exFAT and APA)
// - "usb"
// - "mx4sio"
// MX4SIO and MMCE are incompatible, so loading MMCE after MX4SIO will reinitialize IOP and vice versa
// Returns 0 on success, negative number if failed
int device_init_load_modules(const char *name) {
  uint32_t type = device_string_to_type(name);
  if (type == 0)
    return -1;

  if (loadedDevices & type)
    return 0;

  int res = 0;
  if (((type & Device_MX4SIO) && (loadedDevices & Device_MMCE)) || ((type & Device_MMCE) && (loadedDevices & Device_MX4SIO))) {
    // MX4SIO and MMCE modules are incompatible. Reinitialize IOP first.
    if ((res = device_init()))
      return res;
  }

  return init_modules(type);
}

// ps2hdd/ps2fs init args (null-separated)
static const char ps2hdd_args[] = "-o\0"
                                  "4\0"
                                  "-n\0"
                                  "20\0";
static const char ps2fs_args[] = "-m\0"
                                 "2\0"
                                 "-o\0"
                                 "10\0"
                                 "-n\0"
                                 "40\0";
static const char *get_ps2hdd_args(uint32_t *len) {
  *len = sizeof(ps2hdd_args);
  return ps2hdd_args;
}
static const char *get_ps2fs_args(uint32_t *len) {
  *len = sizeof(ps2fs_args);
  return ps2fs_args;
}
