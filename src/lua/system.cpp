#include "devices/init.h"
#include "devices/utils.h"
#include "devices/vfs.h"
#include "graphics/graphics.h"
#include "lua/player.h"
#include "lua/utils.h"
#include <dirent.h>
#include <hdd-ioctl.h>
#include <libmc.h>
#include <malloc.h>
#include <sifrpc.h>
#include <stdio.h>
#include <string.h>
#include <sys/fcntl.h>
#include <sys/stat.h>
#include <unistd.h>

#define NEWLIB_PORT_AWARE
#include <fileXio_rpc.h>
#include <fileio.h>

#define MAX_DIR_FILES 512
char *boot_path = NULL;

// Sets root path for Lua
void lua_set_root(char *path) {
  if (!path) {
    boot_path = (char *)"";
    return;
  }
  char normalized[512];
  const char *src = ps2_normalize_path(path);
  snprintf(normalized, sizeof(normalized), "%s", src ? src : path);

  char *end = strrchr(normalized, '/');
  if (end)
    *end = '\0';

  printf("lua_system: setting Lua root path to %s\n", normalized);
  boot_path = strdup(normalized);
}

static int lua_getCurrentDirectory(lua_State *L) {
  char path[256];
  getcwd(path, 256);
  {
    const char *normalized = ps2_normalize_path(path);
    lua_pushstring(L, normalized ? normalized : path);
  }

  return 1;
}

static int lua_setCurrentDirectory(lua_State *L) {
  static char temp_path[256];
  const char *path = luaL_checkstring(L, 1);
  if (!path)
    return luaL_error(L, "Argument error: System.currentDirectory(file) takes a filename as string as argument.");

  lua_getCurrentDirectory(L);

  // let's do what the ps2sdk should do,
  // some normalization... :)
  // if absolute path (contains [drive]:path/)
  if (strchr(path, ':')) {
    snprintf(temp_path, sizeof(temp_path), "%s", path);
  } else // relative path
  {
    // remove last directory ?
    if (!strncmp(path, "..", 2)) {
      if (!getcwd(temp_path, sizeof(temp_path)))
        temp_path[0] = '\0';
      if (temp_path[0] != '\0' && (temp_path[strlen(temp_path) - 1] != ':')) {
        int idx = (int)strlen(temp_path) - 1;
        do {
          idx--;
        } while (idx > 0 && temp_path[idx] != '/');
        if (idx >= 0)
          temp_path[idx] = '\0';
      }

    }
    // add given directory to the existing path
    else {
      char cwd[256];
      if (!getcwd(cwd, sizeof(cwd)))
        cwd[0] = '\0';
      snprintf(temp_path, sizeof(temp_path), "%s/%s", cwd, path);
    }
  }

  printf("lua_system: changing directory to %s\n", ps2_normalize_path(temp_path));
  chdir(ps2_normalize_path(temp_path));

  return 1;
}

static int lua_curdir(lua_State *L) {
  int argc = lua_gettop(L);
  if (argc == 0)
    return lua_getCurrentDirectory(L);
  if (argc == 1 && lua_type(L, 1) == LUA_TSTRING)
    return lua_setCurrentDirectory(L);
  return luaL_error(L, "Argument error: System.currentDirectory([file]) takes zero or one argument.");
}

// listDirectory([path]): returns table of { name, directory [, size] }. MC uses libmc; all other paths use fileXio.
static int lua_dir(lua_State *L) {
  int argc = lua_gettop(L);
  if (argc != 0 && argc != 1)
    return luaL_error(L, "Argument error: System.listDirectory([path]) takes zero or one argument.");

  char path[256];
  if (!getcwd(path, sizeof(path)))
    path[0] = '\0';

  if (argc == 1) {
    const char *temp_path = luaL_checkstring(L, 1);
    if (strchr(temp_path, ':'))
      snprintf(path, sizeof(path), "%s", temp_path);
    else
      snprintf(path, sizeof(path), "%s%s", boot_path ? boot_path : "", temp_path);
  }
  {
    const char *normalized = ps2_normalize_path(path);
    snprintf(path, sizeof(path), "%s", normalized ? normalized : "");
  }

  // Memory cards: libmc
  if (strcmp(path, "mc0:") == 0 || strcmp(path, "mc1:") == 0) {
    int nPort = (path[2] == '0') ? 0 : 1;
    char mcPath[256];
    size_t plen = strlen(path);
    snprintf(mcPath, sizeof(mcPath), "%s", plen >= 4 ? path + 4 : "/");
    if (mcPath[0] == '\0')
      snprintf(mcPath, sizeof(mcPath), "%s", "/");
    size_t mlen = strlen(mcPath);
    if (mlen > 0 && mcPath[mlen - 1] != '/')
      strncat(mcPath, "/-*", sizeof(mcPath) - strlen(mcPath) - 1);
    else
      strncat(mcPath, "*", sizeof(mcPath) - strlen(mcPath) - 1);

    sceMcTblGetDir mcEntries[MAX_DIR_FILES] __attribute__((aligned(64)));
    int numRead;
    mcGetDir(nPort, 0, mcPath, 0, MAX_DIR_FILES, mcEntries);
    while (!mcSync(MC_WAIT, NULL, &numRead))
      ;

    lua_newtable(L);
    for (int i = 0; i < numRead; i++) {
      lua_pushnumber(L, i + 1);
      lua_newtable(L);
      lua_pushstring(L, "name");
      lua_pushstring(L, (const char *)mcEntries[i].EntryName);
      lua_settable(L, -3);
      lua_pushstring(L, "size");
      lua_pushnumber(L, mcEntries[i].FileSizeByte);
      lua_settable(L, -3);
      lua_pushstring(L, "directory");
      lua_pushboolean(L, (mcEntries[i].AttrFile & MC_ATTR_SUBDIR) != 0);
      lua_settable(L, -3);
      lua_settable(L, -3);
    }
    return 1;
  }

  // All other paths: fileXio. Device roots need trailing /.
  size_t plen = strlen(path);
  if (plen > 0 && path[plen - 1] != '/' && strchr(path, ':')) {
    if (plen < sizeof(path) - 1)
      strncat(path, "/", sizeof(path) - strlen(path) - 1);
  }

  int fd = fileXioDopen(path);
  if (fd < 0) {
    vfs_dirent_t vfsEntries[MAX_DIR_FILES];
    size_t numVfsEntries = 0;

    if (vfs_available()) {
      numVfsEntries = vfs_listdir(path, vfsEntries, MAX_DIR_FILES);
      if (numVfsEntries == 0 && boot_path && boot_path[0] != '\0') {
        size_t bootLen = strlen(boot_path);
        if (strncmp(path, boot_path, bootLen) == 0) {
          numVfsEntries = vfs_listdir(path + bootLen, vfsEntries, MAX_DIR_FILES);
        }
      }
    }

    if (numVfsEntries > 0) {
      lua_newtable(L);
      for (size_t i = 0; i < numVfsEntries; i++) {
        lua_pushnumber(L, (lua_Number)(i + 1));
        lua_newtable(L);
        lua_pushstring(L, "name");
        lua_pushstring(L, vfsEntries[i].name);
        lua_settable(L, -3);
        lua_pushstring(L, "directory");
        lua_pushboolean(L, vfsEntries[i].directory);
        lua_settable(L, -3);
        lua_pushstring(L, "size");
        lua_pushnumber(L, (lua_Number)vfsEntries[i].size);
        lua_settable(L, -3);
        lua_settable(L, -3);
      }
      return 1;
    }

    lua_pushnil(L);
    return 1;
  }

  lua_newtable(L);
  int cpt = 1;
  iox_dirent_t dirent;
  int r;
  while ((r = fileXioDread(fd, &dirent)) > 0) {
    dirent.name[255] = '\0';
    if (dirent.name[0] == '.' && (dirent.name[1] == '\0' || (dirent.name[1] == '.' && dirent.name[2] == '\0')))
      continue;
    if (strncmp(path, "hdd", 3) == 0 && (dirent.stat.attr & APA_FLAG_SUB))
      continue;
    lua_pushnumber(L, cpt++);
    lua_newtable(L);
    lua_pushstring(L, "name");
    lua_pushstring(L, dirent.name);
    lua_settable(L, -3);
    lua_pushstring(L, "directory");
    lua_pushboolean(L, (dirent.stat.mode & FIO_S_IFDIR) != 0);
    lua_settable(L, -3);
    lua_settable(L, -3);
  }
  fileXioDclose(fd);
  return 1;
}

// Build logical deviceId for BDM mass device: ata0, ata1, usb0, usb1, mx4sio. Caller provides type and per-type index.
static void bdm_device_id(char *buf, size_t buf_size, const char *bdm_type, int index) {
  if (strcmp(bdm_type, "mx4sio") == 0)
    snprintf(buf, buf_size, "mx4sio");
  else
    snprintf(buf, buf_size, "%s%d", bdm_type, index);
}

#define MASS_PROBE_MAX 8

// Resolve logical deviceId (ata0, usb0, usb1, mx4sio) to current mountpoint (e.g. mass0:).
static int lua_getDeviceMountpoint(lua_State *L) {
  const char *device_id = luaL_checkstring(L, 1);
  int i;
  int ata_idx = 0, usb_idx = 0, mx4sio_idx = 0;
  char candidate[16];

  for (i = 0; i < MASS_PROBE_MAX; i++) {
    char path[16];
    char path_for_open[16];
    int fd;
    const char *bdm_type;
    snprintf(path, sizeof(path), "mass%d:", i);
    snprintf(path_for_open, sizeof(path_for_open), "mass%d:/", i);
    fd = fileXioDopen(path_for_open);
    if (fd < 0)
      continue;
    bdm_type = devices_get_bdm_driver(path_for_open);
    fileXioDclose(fd);
    // If driver doesn't support GET_DRIVERNAME ioctl, treat as usb so first mass matches usb0
    if (!bdm_type || strcmp(bdm_type, "mass") == 0)
      bdm_type = "usb";
    candidate[0] = '\0';
    if (strcmp(bdm_type, "ata") == 0)
      bdm_device_id(candidate, sizeof(candidate), "ata", ata_idx++);
    else if (strcmp(bdm_type, "usb") == 0)
      bdm_device_id(candidate, sizeof(candidate), "usb", usb_idx++);
    else if (strcmp(bdm_type, "mx4sio") == 0)
      bdm_device_id(candidate, sizeof(candidate), "mx4sio", mx4sio_idx++);
    if (candidate[0] && strcmp(candidate, device_id) == 0) {
      lua_pushstring(L, path);
      return 1;
    }
  }
  lua_pushnil(L);
  return 1;
}

// Returns launch device family inferred from boot_path:
// "mc", "xfrom", "mmce", "hdd", "usb", "mx4sio", "ata", "bdm", or "unknown".
static int lua_getLaunchDeviceFamily(lua_State *L) {
  if (!boot_path || boot_path[0] == '\0') {
    lua_pushstring(L, "unknown");
    return 1;
  }

  uint32_t device = devices_guess_device_type(boot_path);
  if (device & Device_MMCE) {
    lua_pushstring(L, "mmce");
    return 1;
  }
  if (device & Device_HDD) {
    lua_pushstring(L, "hdd");
    return 1;
  }
  if (device & Device_XFROM) {
    lua_pushstring(L, "xfrom");
    return 1;
  }
  if (device & Device_Basic) {
    if (!strncmp(boot_path, "mc", 2))
      lua_pushstring(L, "mc");
    else
      lua_pushstring(L, "basic");
    return 1;
  }

  if (device & Device_BDM) {
    const char *colon = strchr(boot_path, ':');
    if (colon) {
      char mountpoint[16] = {0};
      size_t len = (size_t)(colon - boot_path + 1);
      if (len > sizeof(mountpoint) - 2)
        len = sizeof(mountpoint) - 2;
      memcpy(mountpoint, boot_path, len);
      mountpoint[len] = '/';
      mountpoint[len + 1] = '\0';
      const char *driver = devices_get_bdm_driver(mountpoint);
      if (driver) {
        lua_pushstring(L, driver);
        return 1;
      }
    }
    lua_pushstring(L, "bdm");
    return 1;
  }

  lua_pushstring(L, "unknown");
  return 1;
}

static int lua_createDir(lua_State *L) {
  const char *path = luaL_checkstring(L, 1);
  if (!path)
    return luaL_error(L, "Argument error: System.createDirectory(directory) takes a directory name as string as argument.");
  int r = mkdir(path, 0777);

  lua_pushinteger(L, r);
  return 1;
}

static int lua_removeDir(lua_State *L) {
  const char *path = luaL_checkstring(L, 1);
  if (!path)
    return luaL_error(L, "Argument error: System.removeDirectory(directory) takes a directory name as string as argument.");
  int r = rmdir(path);

  lua_pushinteger(L, r);
  return 1;
}

static int copy_file_contents(const char *sourcePath, const char *destPath, int removeSource) {
  char buf[BUFSIZ];
  ssize_t bytesRead = 0;
  int source = -1;
  int dest = -1;
  int ok = 1;

  source = open(sourcePath, O_RDONLY, 0);
  if (source < 0)
    return 0;

  dest = open(destPath, O_WRONLY | O_CREAT | O_TRUNC, 0644);
  if (dest < 0) {
    close(source);
    return 0;
  }

  while ((bytesRead = read(source, buf, sizeof(buf))) > 0) {
    ssize_t totalWritten = 0;
    while (totalWritten < bytesRead) {
      ssize_t bytesWritten = write(dest, buf + totalWritten, bytesRead - totalWritten);
      if (bytesWritten <= 0) {
        ok = 0;
        goto done;
      }
      totalWritten += bytesWritten;
    }
  }
  if (bytesRead < 0)
    ok = 0;

done:
  if (close(source) < 0)
    ok = 0;
  if (close(dest) < 0)
    ok = 0;
  if (ok && removeSource && remove(sourcePath) < 0)
    ok = 0;
  return ok;
}

static int lua_movefile(lua_State *L) {
  int argc = lua_gettop(L);
  if (argc != 2)
    return luaL_error(L, "Argument error: System.moveFile(source, destination) takes two filenames as strings as arguments.");
  const char *oldName = luaL_checkstring(L, 1);
  const char *newName = luaL_checkstring(L, 2);
  if (!oldName || !newName)
    return luaL_error(L, "Argument error: System.moveFile(source, destination) takes two filenames as strings as arguments.");

  if (!copy_file_contents(oldName, newName, 1))
    return luaL_error(L, "System.moveFile failed.");

  return 0;
}

static int lua_removeFile(lua_State *L) {
  const char *path = luaL_checkstring(L, 1);
  if (!path)
    return luaL_error(L, "Argument error: System.removeFile(filename) takes a filename as string as argument.");
  int r = remove(path);

  lua_pushinteger(L, r);
  return 1;
}

static int lua_copyfile(lua_State *L) {
  int argc = lua_gettop(L);
  if (argc != 2)
    return luaL_error(L, "Argument error: System.copyFile(source, destination) takes two filenames as strings as arguments.");
  const char *ogfile = luaL_checkstring(L, 1);
  const char *newfile = luaL_checkstring(L, 2);
  if (!ogfile || !newfile)
    return luaL_error(L, "Argument error: System.copyFile(source, destination) takes two filenames as strings as arguments.");

  if (!copy_file_contents(ogfile, newfile, 0))
    return luaL_error(L, "System.copyFile failed.");

  return 0;
}

static char modulePath[256];

static void setModulePath() { getcwd(modulePath, 256); }

static int lua_sleep(lua_State *L) {
  if (lua_gettop(L) != 1)
    return luaL_error(L, "seconds expected.");
  int sec = luaL_checkinteger(L, 1);
  sleep(sec);
  return 0;
}

static int lua_getFreeMemory(lua_State *L) {
  if (lua_gettop(L) != 0)
    return luaL_error(L, "no arguments expected.");

  size_t result = get_free_mem();

  lua_pushinteger(L, (uint32_t)(result));
  return 1;
}

static int lua_exit(lua_State *L) {
  int argc = lua_gettop(L);
  if (argc != 0)
    return luaL_error(L, "System.exitToBrowser");
  asm volatile("li $3, 0x04;"
               "syscall;"
               "nop;");
  return 0;
}

static int lua_getmcinfo(lua_State *L) {
  int argc = lua_gettop(L);
  int type, freespace, format, result;

  int mcslot = 0;
  if (argc == 1)
    mcslot = luaL_checkinteger(L, 1);

  mcGetInfo(mcslot, 0, &type, &freespace, &format);
  mcSync(0, NULL, &result);

  lua_newtable(L);

  lua_pushstring(L, "type");
  lua_pushinteger(L, type);
  lua_settable(L, -3);

  lua_pushstring(L, "freemem");
  lua_pushinteger(L, freespace);
  lua_settable(L, -3);

  lua_pushstring(L, "format");
  lua_pushinteger(L, format);
  lua_settable(L, -3);

  lua_pushstring(L, "result");
  lua_pushinteger(L, result);
  lua_settable(L, -3);

  return 1;
}

static int lua_openfile(lua_State *L) {
  int argc = lua_gettop(L);
  if (argc != 2)
    return luaL_error(L, "wrong number of arguments");
  const char *file_tbo = luaL_checkstring(L, 1);
  int type = luaL_checkinteger(L, 2);
  int fileHandle = open(file_tbo, type, 0777);
#ifdef OPENFILE_FAIL_RAISE_LUAERR
  if (fileHandle < 0)
    return luaL_error(L, "cannot open requested file.");
#endif
  lua_pushinteger(L, fileHandle);
  return 1;
}

static int lua_readfile(lua_State *L) {
  int argc = lua_gettop(L);
  if (argc != 2)
    return luaL_error(L, "wrong number of arguments");
  int file = luaL_checkinteger(L, 1);
  uint32_t size = luaL_checkinteger(L, 2);
  uint8_t *buffer = (uint8_t *)malloc((size_t)size + 1);
  if (buffer == NULL) {
    lua_pushnil(L);
    lua_pushinteger(L, -1);
    return 2;
  }
  ssize_t len = read(file, buffer, size);
  if (len < 0) {
    free(buffer);
    lua_pushnil(L);
    lua_pushinteger(L, (lua_Integer)len);
    return 2;
  }
  buffer[len] = 0;
  lua_pushlstring(L, (const char *)buffer, (size_t)len);
  lua_pushinteger(L, (lua_Integer)len);
  free(buffer);
  return 2;
}

static int lua_writefile(lua_State *L) {
  int argc = lua_gettop(L);
  if (argc != 3)
    return luaL_error(L, "wrong number of arguments");
  int fileHandle = luaL_checkinteger(L, 1);
  const char *text = luaL_checkstring(L, 2);
  int size = luaL_checknumber(L, 3);
  int len = write(fileHandle, text, size);
  lua_pushinteger(L, len);
  return 1;
}

static int lua_closefile(lua_State *L) {
  int argc = lua_gettop(L);
  if (argc != 1)
    return luaL_error(L, "wrong number of arguments");
  int fileHandle = luaL_checkinteger(L, 1);
  int r = close(fileHandle);
  lua_pushinteger(L, r);
  return 1;
}

static int lua_seekfile(lua_State *L) {
  int argc = lua_gettop(L);
  if (argc != 3)
    return luaL_error(L, "wrong number of arguments");
  int fileHandle = luaL_checkinteger(L, 1);
  int pos = luaL_checkinteger(L, 2);
  uint32_t type = luaL_checkinteger(L, 3);
  off_t newpos = lseek(fileHandle, pos, type);
  lua_pushinteger(L, newpos);
  return 1;
}

static int lua_sizefile(lua_State *L) {
  int argc = lua_gettop(L);
  if (argc != 1)
    return luaL_error(L, "wrong number of arguments");
  int fileHandle = luaL_checkinteger(L, 1);
  uint32_t cur_off = lseek(fileHandle, 0, SEEK_CUR);
  uint32_t size = lseek(fileHandle, 0, SEEK_END);
  lseek(fileHandle, cur_off, SEEK_SET);
  lua_pushinteger(L, size);
  return 1;
}

static int lua_checkexist(lua_State *L) {
  int argc = lua_gettop(L);
  if (argc != 1)
    return luaL_error(L, "wrong number of arguments");
  const char *file_tbo = luaL_checkstring(L, 1);
  int fileHandle = open(file_tbo, O_RDONLY, 0777);
  if (fileHandle >= 0) {
    close(fileHandle);
    lua_pushboolean(L, true);
    return 1;
  }
  if (vfs_available()) {
    size_t dummy = 0;
    if (vfs_get(file_tbo, &dummy) != NULL) {
      lua_pushboolean(L, true);
      return 1;
    }
  }
  lua_pushboolean(L, false);
  return 1;
}

extern void *_gp;

#define BUFSIZE (64 * 1024)

static volatile off_t progress, max_progress;

struct pathMap {
  char *in;
  char *out;
};

static char *dup_cstr(const char *src) {
  size_t len;
  char *dst;
  if (!src)
    return NULL;
  len = strlen(src) + 1;
  dst = (char *)malloc(len);
  if (!dst)
    return NULL;
  memcpy(dst, src, len);
  return dst;
}

static int copyThread(void *data) {
  pathMap *paths = (pathMap *)data;
  int in = -1;
  int out = -1;
  char buffer[BUFSIZE];
  progress = 0;
  max_progress = 0;

  if (paths == NULL || paths->in == NULL || paths->out == NULL)
    goto done;
  in = open(paths->in, O_RDONLY, 0);
  if (in < 0)
    goto done;
  out = open(paths->out, O_WRONLY | O_CREAT | O_TRUNC, 0644);
  if (out < 0)
    goto done;
  // Get the input file size.
  {
    off_t size = lseek(in, 0, SEEK_END);
    if (size >= 0) {
      max_progress = size;
      lseek(in, 0, SEEK_SET);
    }
  }

  ssize_t bytes_read;
  while ((bytes_read = read(in, buffer, BUFSIZE)) > 0) {
    ssize_t totalWritten = 0;
    while (totalWritten < bytes_read) {
      ssize_t bytesWritten = write(out, buffer + totalWritten, bytes_read - totalWritten);
      if (bytesWritten <= 0)
        goto done;
      totalWritten += bytesWritten;
    }
    progress += totalWritten;
  }

  // copy is done, or an error occurred
done:
  if (in >= 0)
    close(in);
  if (out >= 0)
    close(out);
  if (paths != NULL) {
    free(paths->in);
    free(paths->out);
    free(paths);
  }
  ExitDeleteThread();
  return 0;
}

static int lua_copyasync(lua_State *L) {
  int argc = lua_gettop(L);
  if (argc != 2)
    return luaL_error(L, "wrong number of arguments");
  const char *inPath = luaL_checkstring(L, 1);
  const char *outPath = luaL_checkstring(L, 2);

  pathMap *copypaths = (pathMap *)malloc(sizeof(pathMap));
  if (!copypaths)
    return luaL_error(L, "System.threadCopyFile: out of memory.");
  copypaths->in = NULL;
  copypaths->out = NULL;

  copypaths->in = dup_cstr(inPath);
  copypaths->out = dup_cstr(outPath);
  if (!copypaths->in || !copypaths->out) {
    free(copypaths->in);
    free(copypaths->out);
    free(copypaths);
    return luaL_error(L, "System.threadCopyFile: out of memory.");
  }

  static uint8_t copyThreadStack[65 * 1024] __attribute__((aligned(16)));

  ee_thread_t thread_param;

  thread_param.gp_reg = &_gp;
  thread_param.func = (void *)copyThread;
  thread_param.stack = (void *)copyThreadStack;
  thread_param.stack_size = sizeof(copyThreadStack);
  thread_param.initial_priority = 0x12;
  int thread = CreateThread(&thread_param);
  if (thread < 0) {
    free(copypaths->in);
    free(copypaths->out);
    free(copypaths);
    return luaL_error(L, "System.threadCopyFile: failed to create thread.");
  }

  StartThread(thread, (void *)copypaths);
  return 0;
}

static int lua_getfileprogress(lua_State *L) {
  lua_newtable(L);

  lua_pushstring(L, "current");
  lua_pushinteger(L, (int)progress);
  lua_settable(L, -3);

  lua_pushstring(L, "final");
  lua_pushinteger(L, (int)max_progress);
  lua_settable(L, -3);

  return 1;
}
static int lua_fileXioMount(lua_State *L) {
  int argc = lua_gettop(L);
  int flag = FIO_MT_RDWR;
  if (argc < 2)
    return luaL_error(L, "wrong number of arguments");
  const char *mountpoint = luaL_checkstring(L, 1);
  const char *blockdev = luaL_checkstring(L, 2);
  if (argc > 2)
    flag = luaL_checkinteger(L, 3);
  int r = fileXioMount(mountpoint, blockdev, flag);

  lua_pushinteger(L, r);
  return 1;
}

static int lua_fileXioUmount(lua_State *L) {
  int argc = lua_gettop(L);
  if (argc != 1)
    return luaL_error(L, "wrong number of arguments");
  const char *mountpoint = luaL_checkstring(L, 1);
  int r = fileXioUmount(mountpoint);

  lua_pushinteger(L, r);
  return 1;
}

// Returns list of partition names for hdd0 or hdd1. Load device type "apa" via System.loadModules for HDD access. Lua may use
// System.listDirectory("hdd0:") when APA is loaded to get partition names.
static int lua_listHddPartitions(lua_State *L) {
  int hddNum = 0;
  if (lua_gettop(L) >= 1) {
    hddNum = (int)luaL_checkinteger(L, 1);
    if (hddNum != 0 && hddNum != 1)
      return luaL_error(L, "System.listHddPartitions: hddNum must be 0 (hdd0) or 1 (hdd1)");
  }
  (void)hddNum;
  lua_newtable(L);
  return 1;
}

static int lua_loadModules(lua_State *L) {
  const char *name = luaL_checkstring(L, 1);
  int r = device_init_load_modules(name);
  lua_pushinteger(L, r);
  return 1;
}

static int lua_resetIOP(lua_State *L) {
  if (lua_gettop(L) != 0)
    return luaL_error(L, "System.resetIOP takes no arguments.");
  int r = device_init();
  lua_pushinteger(L, r);
  return 1;
}

static const luaL_Reg System_functions[] = {
    {"openFile", lua_openfile},
    {"readFile", lua_readfile},
    {"writeFile", lua_writefile},
    {"closeFile", lua_closefile},
    {"seekFile", lua_seekfile},
    {"sizeFile", lua_sizefile},
    //{"doesFileExist",            lua_checkexist}, BREAKS ERROR HANDLING IF DECLARED INSIDE TABLE. DONT ASK ME WHY
    {"currentDirectory", lua_curdir},
    {"listDirectory", lua_dir},
    {"createDirectory", lua_createDir},
    {"removeDirectory", lua_removeDir},
    {"moveFile", lua_movefile},
    {"copyFile", lua_copyfile},
    {"threadCopyFile", lua_copyasync},
    {"getFileProgress", lua_getfileprogress},
    {"removeFile", lua_removeFile},
    {"sleep", lua_sleep},
    {"getFreeMemory", lua_getFreeMemory},
    {"exitToBrowser", lua_exit},
    {"getMCInfo", lua_getmcinfo},
    {"getDeviceMountpoint", lua_getDeviceMountpoint},
    {"getLaunchDeviceFamily", lua_getLaunchDeviceFamily},
    {"listHddPartitions", lua_listHddPartitions},
    {"loadModules", lua_loadModules},
    {"resetIOP", lua_resetIOP},
    {"fileXioMount", lua_fileXioMount},
    {"fileXioUmount", lua_fileXioUmount},
    {0, 0}};

void luaSystem_init(lua_State *L) {

  lua_register(L, "doesFileExist", lua_checkexist);

  setModulePath();
  lua_newtable(L);
  luaL_setfuncs(L, System_functions, 0);
  lua_setglobal(L, "System");

  lua_newtable(L);

  lua_pushinteger(L, O_RDONLY);
  lua_setglobal(L, "O_RDONLY");

  lua_pushinteger(L, O_WRONLY);
  lua_setglobal(L, "O_WRONLY");

  lua_pushinteger(L, O_CREAT);
  lua_setglobal(L, "O_CREAT");

  lua_pushinteger(L, O_TRUNC);
  lua_setglobal(L, "O_TRUNC");

  lua_pushinteger(L, O_RDWR);
  lua_setglobal(L, "O_RDWR");

  lua_pushinteger(L, SEEK_SET);
  lua_setglobal(L, "SET");

  lua_pushinteger(L, SEEK_END);
  lua_setglobal(L, "END");

  lua_pushinteger(L, SEEK_CUR);
  lua_setglobal(L, "CUR");

  lua_pushinteger(L, 1);
  lua_setglobal(L, "READ_ONLY");

  lua_pushinteger(L, 2);
  lua_setglobal(L, "READ_WRITE");

  lua_pushinteger(L, FIO_MT_RDWR);
  lua_setglobal(L, "FIO_MT_RDWR");

  lua_pushinteger(L, FIO_MT_RDONLY);
  lua_setglobal(L, "FIO_MT_RDONLY");

#ifdef APP_VERSION
  lua_pushstring(L, APP_VERSION);
#else
  lua_pushstring(L, "unknown");
#endif
  lua_setglobal(L, "APP_VERSION");
}
