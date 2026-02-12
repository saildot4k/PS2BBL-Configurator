---@meta
---@file intellisense metadata corresponding to the `System` and `IOP` library in `src/lua/system.cpp`
---@diagnostic disable


---@class System
System = {}
---@class IOP
IOP = {}

--#region System

---@return boolean
---@param F string
--- Checks for file existence
function doesFileExist(F) end

--- Opens file for further operations
---@param path string path to file
---@param openmode integer can be a combination of the following: `O_RDONLY`, `O_WRONLY`, `O_CREAT`, `O_TRUNC`, `O_RDWR`
---@return integer fd file descriptor number or negative number on error
function System.openFile(path, openmode) end

--- reads data from an already opened file
---@param fd integer the file descriptor
---@param lenght integer size in bytes to be read from the file
---@return string buf a string containing the readed data
---@return integer lenght ammount of bytes read from the file
---
---@see System.openFile
function System.readFile(fd, lenght) end


--- reads data from an already opened file
---@param fd integer the file descriptor
---@param buf string buffer of data to be written
---@param lenght integer the ammount of bytes to be written (should always be smaller or equal to the lenght of the buf)
---@return integer lenght ammount of bytes written the file
---
---@see System.openFile
function System.writeFile(fd, buf, lenght) end

--- reads data from an already opened file
---@param fd integer the file descriptor to be closed
---@return integer r 0 on success
---
---@see System.openFile
function System.closeFile(fd) end

---@enum seektypes
---@field SET integer the pos parameter acts as an absolute offset (counting from the begining of file)
---@field CUR integer the pos parameter acts as a relative offset (counting from the current file position)
---@field END integer counts from the end of the file
seektypes = {
  SET = 0,
  CUR = 1,
  END = 2,
};

--- reads data from an already opened file
---@param fd integer the file descriptor
---@param pos seektypes the position to be used
---@return integer newpos the new position on the file, counting in bytes from file begining
---
---@see System.openFile
---@see seektypes
function System.seekFile(fd, pos, type) end

--- simple wrapper to quickly obtain size of file in bytes
---@param fd integer the file descriptor
---@return integer size size of file in bytes, or negative number on error
function System.sizeFile(fd) end


--- returns or sets the current directory depending on the parameter passed
---@param path string when passed a string, that string is used as the new **C**urrent **W**orking **D**irectory of the program, pass no parameters or `nil` to make the function return the current working directory
---@overload fun() -> string
function System.currentDirectory(path) end

---@class luadirent
---@field name string name of the entry
---@field size integer size of the file **WARNING** this field may not be available in some devices, if so, the field will be `nil`
---@field directory boolean indicates if this entry is a directory or a file
luadirent = {}

--- iterates over the contents of a directory and returns a table listing it's contents
---@param path string the path that the function must scan, if no path passed, then the CWD is used instead
---@return luadirent dirent an array of tables with the directory contents
---
---@see luadirent: the array of tables returned structure
function System.listDirectory(path) end


--- attempts to create a directory at the specified path
---@param path string the path to the directory to be created
---@return integer ret operation result. 0 for success
function System.createDirectory(path) end

--- attempts to remove a directory at the specified path
---@param path string the path to the directory to be removed
---@return integer ret operation result. 0 for success
function System.removeDirectory(path) end

--- simplified wrapper for copying of one file into another location
---@param file string the path to the original file
---@param newfile string the path to the new file
--- **WARNING**: this function does not perform any kind of error handling nor error return
function System.copyFile(file, newfile) end


--- simplified wrapper for moving one file into another location
---@param file string the path to the original file
---@param newfile string the path to the new file
--- **WARNING**: this function does not perform any kind of error handling nor error return
function System.moveFile(file, newfile) end


--- threaded version of `System.copyFile`
---@param file string the path to the original file
---@param newfile string the path to the new file
--- **WARNING**: this function does not perform any kind of error handling nor error return
function System.threadCopyFile(file, newfile) end

--- this is the table structure returned by `System.getFileProgress`
---@class cpprog
---@field current integer ammount of bytes **already** copied
---@field final integer size of the file being copied
cpprog = {}

--- threaded version of `System.copyFile`
---@return cpprog progress
---
--- **WARNING**: this function does not perform any kind of error handling nor error return
---
---@see cpprog
function System.getFileProgress() end

--- attempts to remove a file
---@return integer ret 0 on success
---@param file string the path for the file to be deleted
function System.removeFile(file) end

---internally it is the same than `System.moveFile`. use that instead
---@see System.moveFile
---
---@deprecated
---@see System.moveFile
function System.rename(source, dest) end

---@return integer freebytes ammount of of free RAM on the Emotion Engine. expressed as bytes
---Total RAM:
--- - **Retail PS2**: `32`mb
--- - **System246/Konami Python1**: `32`mb
--- - **PSX DESR and System256**: `64`mb
--- - **PS2 DTL-T TOOL units**: `128`mb
function System.getFreeMemory() end

--- Executes the system OSDSYS abruptly
function System.exitToBrowser() end

---@type mctypes
--- No memory card or unknown device
sceMcTypeNoCard=0;

---@type mctypes
--- PS1 memory card
sceMcTypePS1=1;

---@type mctypes
--- PS2 memorycard
sceMcTypePS2=2;

---@type mctypes
--- PocketStation
sceMcTypePDA=3;

---@type mcformat
MC_UNFORMATTED=0;
---@type mcformat
MC_FORMATTED=1;


---@type mcinfores
--- the memory card on this port has not been changed since the last call to `System.getMCInfo`
SAME_CARD = 0;

---@type mcinfores
--- a new formatted card has been plugged to the port since the last call to `System.getMCInfo`
NEW_FORMATTED_CARD = -1;

---@type mcinfores
--- a new **un**formatted card has been plugged to the port since the last call to `System.getMCInfo`
NEW_UNFORMATTED_CARD = -2;

---@class mcinfo
---@field type mctypes what kind of memory card is plugged into that port
---@field freemem integer ammount of free memory on card, not always available
---@field format mcformat if the memory card is formatted
---@field result integer the result of the C mcSync() function. for more information read here
mcinfo = {}


--- Obtains information about a memory card connected
--- @param port integer The memory card port to obtain information. defaults to 0 if no param passed
--- @return mcinfo mcinfo
--- @see mcinfo
--- @overload fun()
function System.getMCInfo(port) end

---@enum mountmode
---@type mountmode
FIO_MT_RDWR = 0x00;

---@type mountmode
--- Read ONLY mount mode
FIO_MT_RDONLY = 0x01;

--- Returns list of partition names for hdd0 or hdd1 (e.g. __common, __sysconf). Empty until APA/ps2hdd modules are loaded.
--- @param hddNum integer 0 = hdd0:, 1 = hdd1:. Optional, defaults to 0.
--- @return table array of partition name strings
--- @overload fun():table
function System.listHddPartitions(hddNum) end

--- Loads an embedded IOP module by name. Dependencies (bitmask in irx_requires) are loaded automatically. Names: "usbd_mini", "bdm", "bdmfs_fatfs", "usbmass_bd_mini", "mx4sio_bd_mini", "mmceman", "ps2dev9", "ata_bd", "ps2hdd", "ps2fs". For HDD (hdd0: partitions) load "ata_bd" then "ps2hdd" and "ps2fs".
--- @param name string module name
--- @return integer 0 success, -1 unknown name, -2 load failed
function System.loadModules(name) end

--- Resolves logical deviceId (ata0, ata1, usb0, usb1, mx4sio) to current mountpoint (e.g. mass0:). Returns nil if not found.
--- @param deviceId string e.g. "ata0", "usb0"
--- @return string|nil mountpoint (e.g. "mass0:") or nil
function System.getDeviceMountpoint(deviceId) end

--- Mounts a filesystem via the fileXio driver
--- @see mountmode
--- @param mountpoint string path to the mountpoint that will be exposed
--- @param path string path to the block to mount
--- @param openmode mountmode [mountmode token](lua://mountmode). **[Optional param: deault `FIO_MT_RDWR`]**
--- @return integer result
--- **EXAMPLE:** To mount an HDD PFS partition you would need to load the required IRX drivers, then do
--- `System.fileXioMount("pfs:", "hdd0:PARTITION")`
--- @overload fun(mountpoint:string, path:string): integer:result
--- @nodiscard
function System.fileXioMount(mountpoint, path, FIO_MT_RDWR) end

--- Unmounts a filesystem
--- @return integer result
--- @param mountpoint string path to the mountpoint that will be unmounted
function System.fileXioUmount(mountpoint) end

--#endregion System

