#ifndef DEVICES_VFS_H
#define DEVICES_VFS_H

#include <stdbool.h>
#include <stddef.h>

// Initialize VFS from an embedded blob (format from tools/build_vfs.py). If blob is NULL or size 0, VFS is disabled.
void vfs_init(const void *blob, size_t size);

// Return true if VFS was initialized with a valid blob and can serve files.
bool vfs_available(void);

// Get file content from VFS by path (e.g. "scripts/ui_main.lua").
// Path must match exactly (forward slashes, no leading ./).
// Returns pointer to data and writes size to *out_size, or NULL if not found.
// Pointer is valid until vfs_init is called again or process exits.
const void *vfs_get(const char *path, size_t *out_size);

#endif
