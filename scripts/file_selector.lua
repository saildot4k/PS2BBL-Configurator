--[[
  File selector for configurator.
  Context: "osdmenu" = full device list (OSDMENU.CNF); "mbr" = MBR-supported paths only (OSDMBR.CNF).
  Returns selected path string (and optional cdrom args table if cdrom chosen).
  Special entries: cdrom (Launch Disc), dvd (MBR only, DVD Player).
  Option to convert mc/mmce path to wildcard (mc?, mmce?) at selection time.
  OSDMenu and MBR use the same lang strings (strings.devices) for device and special-entry labels.

  Path/device flags (noargs, exclusive, specialargs) unify handling across path_picker and entry_paths:
  - noargs: clear all arguments when this path is selected.
  - exclusive: grey out when any other path exists (must be the only path).
  - specialargs: show special argument screen (e.g. Launch Disc options); ignored unless exclusive is set.
]]

local file_selector = {}
local System = System
local strings = _G.CONFIG_UI and _G.CONFIG_UI.strings or {}
local dev = strings.devices or {}

-- Static devices (fixed mountpoints). descKey = key in strings.devices for label (so lang cycle works).
local STATIC = {
  { name = "mc0:",   descKey = "memory_card_1", mbr = true },
  { name = "mc1:",   descKey = "memory_card_2", mbr = true },
  { name = "mmce0:", descKey = "mmce_0",        deviceType = "mmce" },
  { name = "mmce1:", descKey = "mmce_1",        deviceType = "mmce" },
  { name = "hdd0:",  descKey = "hdd",           deviceType = "hdd", mbr = true },
}
local BDM_DESC = { usb0 = "usb_storage_0", usb1 = "usb_storage_1", mx4sio = "mx4sio_sd" }
local BDM_OPTIONS = {
  { deviceId = "ata0",   bdmType = "ata",    bdmPathPrefix = "ata",   mbr = true },
  { deviceId = "usb0",   bdmType = "usb",    bdmPathPrefix = "mass" },
  { deviceId = "usb1",   bdmType = "usb",    bdmPathPrefix = "mass" },
  { deviceId = "mx4sio", bdmType = "mx4sio", bdmPathPrefix = "massX" },
}

-- Special devices (instant-select, no browse). descKey = key in strings.devices. contexts = "osdmenu" | "mbr" | {"osdmenu","mbr"}.
-- Optional: noargs, exclusive, specialargs (specialargs is ignored unless exclusive is set).
local SPECIAL = {
  { name = "$HOSDSYS", descKey = "hosdsys",     special = "hosdsys",  contexts = "mbr" },
  { name = "$PSBBN",   descKey = "psbbn",       special = "psbbn",    contexts = "mbr" },
  { name = "OSDSYS",   descKey = "osd",         special = "osdsys",   contexts = "osdmenu",            noargs = true, exclusive = true },
  { name = "POWEROFF", descKey = "shutdown",    special = "poweroff", contexts = "osdmenu",            noargs = true, exclusive = true },
  { name = "cdrom",    descKey = "launch_disc", special = "cdrom",    contexts = { "osdmenu", "mbr" }, noargs = true, exclusive = true, specialargs = true },
  { name = "dvd",      descKey = "dvd_player",  special = "dvd",      contexts = "mbr",                noargs = true, exclusive = true },
}

local function getFlagsByName(name)
  if not name or name == "" then return nil end
  local p = name
  if p:upper() == "OSDSYS" then p = "OSDSYS" end
  if p:upper() == "POWEROFF" then p = "POWEROFF" end
  for _, s in ipairs(SPECIAL) do
    if s.name == p then return s end
  end
  return nil
end

-- Return flags for a path string (as stored in config). specialargs is only returned when exclusive is set.
function file_selector.getPathFlags(path)
  local s = getFlagsByName(path)
  if not s then return {} end
  local f = { noargs = s.noargs, exclusive = s.exclusive, specialargs = s.specialargs and s.exclusive }
  return f
end

local function withFlags(entry)
  local s = getFlagsByName(entry.name)
  if s then
    entry.noargs = s.noargs
    entry.exclusive = s.exclusive
    entry.specialargs = s.specialargs and s.exclusive
  end
  return entry
end

local function pathPrefix(path)
  if not path or path == "" then return path end
  local colon = path:find(":")
  if colon then return path:sub(1, colon) end
  return path
end

local function inContext(contexts, context)
  if contexts == context then return true end
  if type(contexts) == "table" then
    for _, c in ipairs(contexts) do if c == context then return true end end
  end
  return false
end

local function getBblPathDeviceVisibility()
  local cfg = _G.CONFIG_UI and _G.CONFIG_UI.config_options
  if cfg and cfg.getBblPathDeviceVisibility then
    return cfg.getBblPathDeviceVisibility()
  end
  return nil
end

local function nextNaturalChunk(s, idx)
  local first = s:sub(idx, idx)
  if first == "" then return "", idx, false end
  local isDigit = (first:match("%d") ~= nil)
  local j = idx
  while j <= #s do
    local d = (s:sub(j, j):match("%d") ~= nil)
    if d ~= isDigit then break end
    j = j + 1
  end
  return s:sub(idx, j - 1), j, isDigit
end

local function naturalLessText(a, b)
  local sa = tostring(a or "")
  local sb = tostring(b or "")
  local la = sa:lower()
  local lb = sb:lower()
  local ia, ib = 1, 1

  while ia <= #la and ib <= #lb do
    local ca, na, da = nextNaturalChunk(la, ia)
    local cb, nb, db = nextNaturalChunk(lb, ib)
    if da and db then
      local ta = ca:gsub("^0+", "")
      local tb = cb:gsub("^0+", "")
      if ta == "" then ta = "0" end
      if tb == "" then tb = "0" end
      if #ta ~= #tb then return #ta < #tb end
      if ta ~= tb then return ta < tb end
      if #ca ~= #cb then return #ca < #cb end
    else
      if ca ~= cb then return ca < cb end
    end
    ia, ib = na, nb
  end

  if #la ~= #lb then return #la < #lb end
  return sa < sb
end

local function sortEntriesByName(entries, directoriesFirst)
  if type(entries) ~= "table" or #entries < 2 then return entries end
  table.sort(entries, function(a, b)
    local ad = not not (a and a.directory)
    local bd = not not (b and b.directory)
    if directoriesFirst and ad ~= bd then
      return ad and not bd
    end
    return naturalLessText(a and a.name, b and b.name)
  end)
  return entries
end

local function isVisible(visibility, key)
  if not visibility or not key then return true end
  local v = visibility[key]
  if v == nil then return true end
  return v == true
end

local function staticPathOnlyVisible(visibility, s)
  if not s then return false end
  if s.name == "mc0:" or s.name == "mc1:" then
    return isVisible(visibility, "mc")
  end
  if s.deviceType == "mmce" then
    return isVisible(visibility, "mmce")
  end
  if s.deviceType == "hdd" then
    return isVisible(visibility, "hdd")
  end
  return true
end

local function bdmPathOnlyVisible(visibility, opt)
  if not opt or not opt.bdmType then return false end
  if opt.bdmType == "ata" then
    return isVisible(visibility, "ata")
  end
  return isVisible(visibility, opt.bdmType)
end

-- Build device list for UI.
-- context:
--   "osdmenu"  = full device list + osdmenu special entries
--   "mbr"      = MBR-compatible devices + mbr specials
--   "mc_only"  = memory cards only
--   "path_only"= filesystem devices only (no special command entries)
-- Every device gets withFlags(entry).
function file_selector.getDevices(context)
  local dev = (_G.CONFIG_UI and _G.CONFIG_UI.strings and _G.CONFIG_UI.strings.devices) or dev
  if context == "mc_only" then
    local out = {}
    for i = 1, 2 do
      local s = STATIC[i]
      local desc = (s.descKey and dev[s.descKey]) or s.name
      table.insert(out, withFlags({ name = s.name, desc = desc, deviceType = s.deviceType }))
    end
    return out
  end
  if context == "path_only" or context == "config_ini" then
    local visibility = getBblPathDeviceVisibility()
    local out = {}
    for _, s in ipairs(STATIC) do
      if staticPathOnlyVisible(visibility, s) then
        local desc = (s.descKey and dev[s.descKey]) or s.name
        table.insert(out, withFlags({ name = s.name, desc = desc, deviceType = s.deviceType }))
      end
    end
    for _, opt in ipairs(BDM_OPTIONS) do
      if bdmPathOnlyVisible(visibility, opt) then
        local desc = (opt.deviceId and opt.deviceId:sub(1, 3) == "ata") and dev.exfat_hdd_mass0 or
            (dev[BDM_DESC[opt.deviceId]] or opt.deviceId)
        local deviceType = (opt.bdmType == "ata" and "hdd") or opt.bdmType
        table.insert(out,
          withFlags({
            name = opt.deviceId,
            desc = desc,
            deviceType = deviceType,
            deviceId = opt.deviceId,
            bdmPathPrefix = opt.bdmPathPrefix
          }))
      end
    end
    return out
  end
  local isMbr = (context == "mbr")
  local out = {}
  for _, s in ipairs(STATIC) do
    if not isMbr or s.mbr then
      local desc = (s.descKey and dev[s.descKey]) or s.name
      table.insert(out, withFlags({ name = s.name, desc = desc, deviceType = s.deviceType }))
    end
  end
  for _, opt in ipairs(BDM_OPTIONS) do
    if not isMbr or opt.mbr then
      local desc = (opt.deviceId and opt.deviceId:sub(1, 3) == "ata") and dev.exfat_hdd_mass0 or
          (dev[BDM_DESC[opt.deviceId]] or opt.deviceId)
      local deviceType = (opt.bdmType == "ata" and "hdd") or opt.bdmType
      table.insert(out,
        withFlags({
          name = opt.deviceId,
          desc = desc,
          deviceType = deviceType,
          deviceId = opt.deviceId,
          bdmPathPrefix =
              opt.bdmPathPrefix
        }))
    end
  end
  for _, s in ipairs(SPECIAL) do
    if inContext(s.contexts, context) then
      local desc = (s.descKey and dev[s.descKey]) or s.name
      table.insert(out, withFlags({ name = s.name, desc = desc, special = s.special }))
    end
  end
  return out
end

-- HDD partition list (APA). Requires APA loaded. Uses listDirectory("hdd0:") to get partition names.
function file_selector.getHddPartitions(hddNum)
  hddNum = hddNum or 0
  local prefix = (hddNum == 0) and "hdd0:" or "hdd1:"
  local list = System.listDirectory(prefix)
  if not list then return {} end
  local out = {}
  for i = 1, #list do
    local e = list[i]
    local name = (e and (e.name or e.fileName)) or ""
    if name ~= "" and name ~= "." and name ~= ".." then
      local full = prefix .. name
      table.insert(out, { name = name, full = full })
    end
  end
  sortEntriesByName(out, false)
  return out
end

-- Return path and optional args. path = chosen path; args = list of strings for cdrom (or nil).
-- selectCallback(devices, currentPath, context) -> should call back with (path, args, useWildcard).
-- This module only provides data; the actual UI (navigation, list, confirm) is in config_ui.
function file_selector.listDirectory(path)
  local list = System.listDirectory(path)
  if not list then return nil end
  local out = {}
  for i = 1, #list do
    local e = list[i]
    local name = e.name or ""
    if name == "." or name == ".." then goto continue end
    local isDir = e.directory
    local full = path
    if full:sub(-1) ~= ":" and full:sub(-1) ~= "/" then full = full .. "/" end
    full = full .. name
    if isDir then full = full .. "/" end
    table.insert(out, { name = name, full = full, directory = isDir })
    ::continue::
  end
  sortEntriesByName(out, true)
  return out
end

-- BDM deviceId (ata0, usb0, usb1, mx4sio) -> path prefix for config (ata, usb, mx4sio). Returns nil if not BDM.
function file_selector.getBdmPathPrefix(deviceId)
  if not deviceId then return nil end
  for _, opt in ipairs(BDM_OPTIONS) do
    if opt.deviceId == deviceId then return opt.bdmPathPrefix end
  end
  return nil
end

-- Convert path to wildcard form: mc0/ mc1 -> mc?, mmce0/ mmce1 -> mmce?.
function file_selector.toWildcard(path)
  if not path then return path end
  path = path:gsub("^mc0:", "mc?:")
  path = path:gsub("^mc1:", "mc?:")
  path = path:gsub("^mmce0:", "mmce?:")
  path = path:gsub("^mmce1:", "mmce?:")
  return path
end

-- Check if path is mc0/mc1 or mmce0/mmce1 (can offer wildcard).
function file_selector.canWildcard(path)
  if not path then return false end
  local p = pathPrefix(path)
  return p == "mc0:" or p == "mc1:" or p == "mmce0:" or p == "mmce1:"
end

-- Resolve logical deviceId (ata0, usb0, usb1, mx4sio) to current mountpoint (e.g. mass0:). Returns nil if not found.
function file_selector.getDeviceMountpoint(deviceId)
  if not System or not System.getDeviceMountpoint or not deviceId then return nil end
  return System.getDeviceMountpoint(deviceId)
end

return file_selector
