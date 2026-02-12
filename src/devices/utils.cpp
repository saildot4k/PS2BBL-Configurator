#include "devices/init.h"
#include "devices/mc.h"
#include "devices/pad.h"
#include <errno.h>
#include <iopcontrol.h>
#include <loadfile.h>
#include <sbv_patches.h>
#include <sifrpc.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <usbhdfsd-common.h>

#define NEWLIB_PORT_AWARE
#include <fileXio_rpc.h>

// Maps BDM driver type to driver name for given mountpoint
const char *devices_get_bdm_driver(const char *mountpoint) {
  int fd = fileXioDopen(mountpoint);
  if (fd < 0)
    return NULL;
  char driverName[10];
  int ret = fileXioIoctl2(fd, USBMASS_IOCTL_GET_DRIVERNAME, NULL, 0, driverName, (int)sizeof(driverName) - 1);
  fileXioDclose(fd);
  if (ret < 0)
    return NULL;
  driverName[sizeof(driverName) - 1] = '\0';
  if (strncmp(driverName, "ata", 3) == 0)
    return "ata";
  if (strncmp(driverName, "sdc", 3) == 0)
    return "mx4sio";
  if (strncmp(driverName, "usb", 3) == 0)
    return "usb";
  return "mass";
}

// Attempts to detect device type from the path and returns number corresponding to one of devices defined in devices/init.h
uint32_t devices_guess_device_type(const char *path) {
  if (!strncmp(path, "mc", 2))
    return Device_Basic;
  else if (!strncmp(path, "mmce", 4))
    return Device_MMCE;
  else if (!strncmp(path, "hdd", 3))
    return Device_HDD;
  else if (!strncmp(path, "mass", 4))
    return Device_BDM; // Can be any BDM device

  return 0;
}

// Tries to open the device
// Returns 0 if device is available
int devices_probe(char *path, int attempts) {
  char mountpoint[10] = {0};
  // Get mountpoint from path
  char *m = strchr(path, ':');
  if (!m)
    return -ENODEV;
  m++;

  strncpy(mountpoint, path, m - path);

  // Wait for IOP to initialize device driver
  int fd = 0;
  for (int i = 0; i < attempts; i++) {
    fd = fileXioDopen(mountpoint);
    if (fd >= 0) {
      fileXioDclose(fd);
      return 0;
    }
    sleep(2);
  }
  return -ENODEV;
}
