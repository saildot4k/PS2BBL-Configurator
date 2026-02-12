#ifndef DEVICES_UTILS_H
#define DEVICES_UTILS_H

#include <unistd.h>

// Maps BDM driver type to driver name for given mountpoint
const char *devices_get_bdm_driver(const char *mountpoint);

// Attempts to detect device type from the path and returns number corresponding to device defined in devices/init.h
uint32_t devices_guess_device_type(const char *path);

// Tries to open the device
// Returns 0 if device is available
int devices_probe(char *path, int attempts);

#endif
