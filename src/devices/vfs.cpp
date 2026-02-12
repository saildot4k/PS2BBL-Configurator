#include "devices/vfs.h"
#include <debug.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

static const uint8_t *vfs_blob = NULL;
static size_t vfs_size = 0;
static size_t vfs_data_start = 0;

static const uint8_t MAGIC[4] = {'E', 'V', 'F', 'S'};

void vfs_init(const void *blob, size_t size) {
  printf("vfs: initializing VFS @ %p\n", blob);
  vfs_blob = (const uint8_t *)blob;
  vfs_size = size;
  vfs_data_start = 0;

  if (!blob || size < 8) {
    printf("vfs: invalid size\n");
    return;
  }
  if (memcmp(blob, MAGIC, 4) != 0) {
    printf("vfs: invalid magic\n");
    return;
  }

  uint32_t num = _lw((u32)blob + 4);
  const uint8_t *ptr = (const uint8_t *)blob + 8;
  for (uint32_t i = 0; i < num; i++) {
    uint32_t path_len = _lw((u32)ptr);
    ptr += 4 + path_len + 4 + 4;
  }
  size_t header_len = (size_t)(ptr - vfs_blob);
  // File data starts after header padded to 16 bytes (see build_vfs.py)
  vfs_data_start = (header_len + 15) & ~(size_t)15;
  printf("vfs: initialized VFS @ %p, size %d\n", blob, size);
}

bool vfs_available(void) { return (vfs_blob != NULL && vfs_size >= 8 && vfs_data_start > 0); }

// Normalize path for lookup: skip leading '/' and "./" to match VFS entries (e.g. "scripts/...").
static const char *vfs_normalize_path(const char *path, size_t *out_len) {
  while (*path == '/')
    path++;
  if (path[0] == '.' && path[1] == '/')
    path += 2;
  *out_len = strlen(path);
  return path;
}

const void *vfs_get(const char *path, size_t *out_size) {
  if (!out_size)
    return NULL;
  *out_size = 0;
  if (!path)
    return NULL;
  if (!vfs_available())
    return NULL;

  size_t path_len;
  path = vfs_normalize_path(path, &path_len);
  if (path_len > 0x7FFFFFFF)
    return NULL;

  uint32_t num = _lw((u32)vfs_blob + 4);
  const uint8_t *ptr = vfs_blob + 8;

  for (uint32_t i = 0; i < num; i++) {
    uint32_t len = _lw((u32)ptr);
    if (strcmp((const char *)(ptr + 4), path) == 0) {
      uint32_t offset = _lw((u32)(ptr + 4 + len));
      uint32_t size = _lw((u32)(ptr + 4 + len + 4));
      if (vfs_data_start + offset + size <= vfs_size) {
        *out_size = size;
        printf("vfs: opened \"%s\" (%u bytes)\n", path, (uint32_t)size);
        return vfs_blob + vfs_data_start + offset;
      }
      return NULL;
    }
    ptr += 4 + len + 4 + 4;
  }
  return NULL;
}
