#ifndef DEVICES_INIT_H
#define DEVICES_INIT_H

// Supported devices
#define Device_Basic (1 << 0)  // Memory cards
#define Device_HDD (1 << 1)    // exFAT and APA HDD
#define Device_USB (1 << 2)    // USB
#define Device_MX4SIO (1 << 3) // MX4SIO
#define Device_MMCE (1 << 4)   // MMCE
#define Device_BDM (1 << 5)    // Catch-all for BDM, only used by devices_guess_device_type

// Load basic IOP modules (iomanX, fileXio, sio2man, mcman, mcserv, padman) and init device services.
// Will reboot IOP and reinitialize device services on every call.
// Returns 0 on success.
int device_init(void);

// Load IOP modules by device type or by IRX name.
// Supported device types:
// - "mmce"
// - "hdd" (both exFAT and APA)
// - "usb"
// - "mx4sio"
// MX4SIO and MMCE are incompatible, so loading MMCE after MX4SIO will reinitialize IOP and vice versa
// Returns 0 on success, negative number if failed
int device_init_load_modules(const char *name);

#endif
