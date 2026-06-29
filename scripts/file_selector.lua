--[[
  File selector for configurator.
  Context:
    "osdmenu"     = full device list (OSDMENU.CNF)
    "mbr"         = MBR-supported paths only (OSDMBR.CNF)
    "fmcb_entry"  = FreeMCBoot/FreeHDBoot menu entry paths
    "fmcb_launch" = FreeMCBoot/FreeHDBoot launch-key paths
  Returns selected path string (and optional cdrom args table if cdrom chosen).
  Special entries: cdrom (Launch Disc), dvd (MBR only, DVD Player).
  Option to convert mc/mmce/usbN paths to wildcard (mc?, mmce?, usb:) at selection time.
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
local pathStrings = strings.path_picker or {}

local function runtimePlatform()
  local runtime = _G and _G.CONFIG_UI
  local platform = runtime and runtime.runtimePlatform
  if type(platform) == "table" then return platform end
  return {}
end

local function isRuntimePsx()
  return runtimePlatform().isPsx == true
end

local function hideRuntimeHddDevices()
  return runtimePlatform().hideHddDevices == true
end

-- Static devices (fixed mountpoints). descKey = key in strings.devices for label (so lang cycle works).
local STATIC = {
  { name = "mc0:",   descKey = "memory_card_1", mbr = true },
  { name = "mc1:",   descKey = "memory_card_2", mbr = true },
  { name = "mmce0:", descKey = "mmce_0",        deviceType = "mmce" },
  { name = "mmce1:", descKey = "mmce_1",        deviceType = "mmce" },
  { name = "hdd0:",  descKey = "hdd",           deviceType = "hdd", mbr = true, hddNum = 0 },
  { name = "hdd1:",  descKey = "hdd_1",         deviceType = "hdd", mbr = true, mbrOnly = true, hddNum = 1 },
}
local BDM_DESC = { usb0 = "usb_storage_0", usb1 = "usb_storage_1", mx4sio = "mx4sio_sd" }
local BDM_OPTIONS = {
  { deviceId = "ata0",   bdmType = "ata",    bdmPathPrefix = "ata",   mbr = true },
  { deviceId = "ata1",   bdmType = "ata",    bdmPathPrefix = "ata1",  mbr = true, mbrOnly = true },
  { deviceId = "usb0",   bdmType = "usb",    bdmPathPrefix = "mass" },
  { deviceId = "usb1",   bdmType = "usb",    bdmPathPrefix = "mass" },
  { deviceId = "mx4sio", bdmType = "mx4sio", bdmPathPrefix = "mx4sio" },
}

local function isFreeBootContext(context, fileType)
  return context == "fmcb_entry" or context == "fmcb_launch" or
      context == "freemcboot" or context == "freehddboot" or
      context == "freedvdboot" or
      fileType == "freemcboot_cnf"
end

local function bdmPrefixForContext(opt, context, fileType)
  if not opt then return nil end
  if (context == "mbr" or context == "osdmenu" or context == "path_only" or context == "config_ini") and
      opt.bdmType == "ata" and opt.deviceId then
    return opt.deviceId
  end
  if opt.bdmType == "usb" then
    if isFreeBootContext(context, fileType) then return opt.bdmPathPrefix end
    return opt.deviceId
  end
  if opt.bdmType == "mx4sio" then
    return "mx4sio"
  end
  return opt.bdmPathPrefix
end

local function bdmBrowsePrefix(opt)
  if not opt then return nil end
  if opt.bdmType == "usb" and opt.deviceId then return opt.deviceId end
  if opt.bdmType == "ata" and opt.deviceId then return opt.deviceId end
  if opt.bdmType == "mx4sio" then return "mx4sio" end
  return opt.bdmPathPrefix
end

-- Special devices (instant-select, no browse). descKey = key in strings.devices.
-- contexts = "osdmenu" | "mbr" | "fmcb_entry" | "fmcb_launch" | { ... }.
-- Optional: noargs, exclusive, specialargs (specialargs is ignored unless exclusive is set).
local SPECIAL = {
  { name = "$HOSDSYS", descKey = "hosdsys",     special = "hosdsys",  contexts = "mbr", noargs = true },
  { name = "$PSBBN",   descKey = "psbbn",       special = "psbbn",    contexts = "mbr", noargs = true },
  { name = "$XOSD",    descKey = "xosd",        helperKey = "mbr_cmd_xosd",    special = "xosd",     contexts = "mbr", noargs = true },
  { name = "$OSDMENU", descKey = "osdmenu_psx", helperKey = "mbr_cmd_osdmenu", special = "osdmenu",  contexts = "mbr", noargs = true },
  { name = "OSDSYS",   descKey = "osd",         special = "osdsys",   contexts = { "osdmenu", "fmcb_entry", "fmcb_launch" }, noargs = true, exclusive = true },
  { name = "OSDMENU",  descKey = "osdmenu",     special = "osdmenu",  contexts = "fmcb_launch",         noargs = true },
  { name = "FASTBOOT", descKey = "fastboot",    special = "fastboot", contexts = { "fmcb_entry", "fmcb_launch" }, noargs = true, exclusive = true },
  { name = "POWEROFF", descKey = "shutdown",    special = "poweroff", contexts = { "osdmenu", "fmcb_entry", "fmcb_launch" }, noargs = true, exclusive = true },
  { name = "cdrom",    descKey = "launch_disc", special = "cdrom",    contexts = { "osdmenu", "mbr" }, noargs = true, exclusive = true, specialargs = true },
  { name = "dvd",      descKey = "dvd_player",  special = "dvd",      contexts = "mbr",                noargs = true, exclusive = true },
}

local function getFlagsByName(name)
  if not name or name == "" then return nil end
  local p = name
  if p:upper() == "OSDSYS" then p = "OSDSYS" end
  if p:upper() == "OSDMENU" then p = "OSDMENU" end
  if p:upper() == "FASTBOOT" then p = "FASTBOOT" end
  if p:upper() == "POWEROFF" then p = "POWEROFF" end
  if p:upper() == "$HOSDSYS" then p = "$HOSDSYS" end
  if p:upper() == "$PSBBN" then p = "$PSBBN" end
  if p:upper() == "$XOSD" then p = "$XOSD" end
  if p:upper() == "$OSDMENU" then p = "$OSDMENU" end
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
    if hideRuntimeHddDevices() then return false end
    return isVisible(visibility, "hdd")
  end
  if s.deviceType == "xfrom" then
    if not isRuntimePsx() then return false end
    return isVisible(visibility, "xfrom")
  end
  return true
end

local function bdmPathOnlyVisible(visibility, opt)
  if not opt or not opt.bdmType then return false end
  if opt.bdmType == "ata" then
    if hideRuntimeHddDevices() then return false end
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
function file_selector.getDevices(context, opts)
  local dev = (_G.CONFIG_UI and _G.CONFIG_UI.strings and _G.CONFIG_UI.strings.devices) or dev
  local isFmcbContext = (context == "fmcb_entry" or context == "fmcb_launch")
  local fileType = nil
  if type(opts) == "table" then
    fileType = opts.fileType
  elseif type(opts) == "string" then
    fileType = opts
  end
  if type(fileType) ~= "string" or fileType == "" then
    local runtime = _G and _G.CONFIG_UI
    if runtime and type(runtime.fileType) == "string" and runtime.fileType ~= "" then
      fileType = runtime.fileType
    end
  end
  local includePsxXfromPathOnly = (context == "path_only" and fileType == "psxbbl_ini")
  local isBblFileType = (fileType == "ps2bbl_ini" or fileType == "psxbbl_ini")
  local includeBblHddPairs = (context == "path_only" or context == "config_ini") and isBblFileType

  local function addXfromPathOnly(out, addedStatic, opts)
    if not isRuntimePsx() then return end
    opts = opts or {}
    local marker = "xfrom:"
    if addedStatic and addedStatic[marker] then return end
    local entry = { name = marker, desc = dev.xfrom or "XFROM (PSX ONLY!)", deviceType = "xfrom" }
    if opts.visibility and not staticPathOnlyVisible(opts.visibility, entry) then return end
    table.insert(out, withFlags(entry))
    if addedStatic then addedStatic[marker] = true end
  end

  local function addStatic(out, addedStatic, s, opts)
    if not s then return end
    opts = opts or {}
    if s.deviceType == "hdd" and hideRuntimeHddDevices() then return end
    if opts.isMbr and not s.mbr then return end
    if s.mbrOnly and not (opts.isMbr or opts.includeMbrOnly) then return end
    if opts.visibility and not staticPathOnlyVisible(opts.visibility, s) then return end
    if addedStatic and addedStatic[s.name] then return end
    local descKey = s.descKey
    local useNumberedHddLabels = opts.isMbr or opts.useMbrHddLabels
    if useNumberedHddLabels and s.name == "hdd0:" then
      descKey = "hdd_mbr_0"
    elseif useNumberedHddLabels and s.name == "hdd1:" then
      descKey = "hdd_mbr_1"
    end
    local desc = (descKey and dev[descKey]) or (s.descKey and dev[s.descKey]) or s.name
    table.insert(out, withFlags({ name = s.name, desc = desc, deviceType = s.deviceType, hddNum = s.hddNum }))
    if addedStatic then addedStatic[s.name] = true end
  end
  local function addBdm(out, addedBdm, opt, opts)
    if not opt then return end
    opts = opts or {}
    if opt.bdmType == "ata" and hideRuntimeHddDevices() then return end
    if opts.isMbr and not opt.mbr then return end
    if opt.mbrOnly and not (opts.isMbr or opts.includeMbrOnly) then return end
    if opts.visibility and not bdmPathOnlyVisible(opts.visibility, opt) then return end
    if addedBdm and addedBdm[opt.deviceId] then return end
    local desc
    local useNumberedHddLabels = opts.isMbr or opts.useMbrHddLabels
    if useNumberedHddLabels and opt.deviceId == "ata0" then
      desc = dev.exfat_hdd_mbr_0 or "exFAT-formatted HDD 1"
    elseif useNumberedHddLabels and opt.deviceId == "ata1" then
      desc = dev.exfat_hdd_mbr_1 or "exFAT-formatted HDD 2"
    else
      desc = (opt.deviceId and opt.deviceId:sub(1, 3) == "ata") and dev.exfat_hdd_mass0 or
          (dev[BDM_DESC[opt.deviceId]] or opt.deviceId)
    end
    local deviceType = (opt.bdmType == "ata" and "hdd") or opt.bdmType
    table.insert(out,
      withFlags({
        name = opt.deviceId,
        desc = desc,
        deviceType = deviceType,
        deviceId = opt.deviceId,
        bdmPathPrefix = bdmPrefixForContext(opt, context, fileType),
        bdmBrowsePrefix = bdmBrowsePrefix(opt)
      }))
    if addedBdm then addedBdm[opt.deviceId] = true end
  end
  local function addStaticByName(out, addedStatic, name, opts)
    for _, s in ipairs(STATIC) do
      if s.name == name then
        addStatic(out, addedStatic, s, opts)
        return
      end
    end
  end
  local function addXfromMbr(out, addedStatic)
    if not isRuntimePsx() then return end
    local marker = "xfrom:"
    if addedStatic and addedStatic[marker] then return end
    table.insert(out, withFlags({ name = marker, desc = dev.xfrom or "XFROM (PSX ONLY!)", deviceType = "xfrom" }))
    if addedStatic then addedStatic[marker] = true end
  end
  local function addBdmById(out, addedBdm, deviceId, opts)
    for _, opt in ipairs(BDM_OPTIONS) do
      if opt.deviceId == deviceId then
        addBdm(out, addedBdm, opt, opts)
        return
      end
    end
  end
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
    local addedStatic = {}
    local addedBdm = {}
    local addOpts = {
      visibility = visibility,
      includeMbrOnly = includeBblHddPairs,
      useMbrHddLabels = includeBblHddPairs,
    }

    -- Preferred choose-device order:
    -- MC1, MC2, MMCE1, MMCE2, USB1, USB2, MX4SIO, APA HDD(s), exFAT HDD(s).
    addStaticByName(out, addedStatic, "mc0:", addOpts)
    addStaticByName(out, addedStatic, "mc1:", addOpts)
    addStaticByName(out, addedStatic, "mmce0:", addOpts)
    addStaticByName(out, addedStatic, "mmce1:", addOpts)
    addBdmById(out, addedBdm, "usb0", addOpts)
    addBdmById(out, addedBdm, "usb1", addOpts)
    addBdmById(out, addedBdm, "mx4sio", addOpts)
    addStaticByName(out, addedStatic, "hdd0:", addOpts)
    if includeBblHddPairs then addStaticByName(out, addedStatic, "hdd1:", addOpts) end
    addBdmById(out, addedBdm, "ata0", addOpts)
    if includeBblHddPairs then addBdmById(out, addedBdm, "ata1", addOpts) end

    -- Keep any other supported devices after the preferred block.
    for _, s in ipairs(STATIC) do
      addStatic(out, addedStatic, s, addOpts)
    end
    for _, opt in ipairs(BDM_OPTIONS) do
      addBdm(out, addedBdm, opt, addOpts)
    end
    if includePsxXfromPathOnly then
      -- PSXBBL-only: expose XFROM ELF browsing, pinned at the bottom.
      addXfromPathOnly(out, addedStatic, addOpts)
    end
    return out
  end
  local isMbr = (context == "mbr")
  local isOsdPathPicker = (context == "osdmenu")
  local out = {}
  local addedStatic = {}
  local addedBdm = {}
  local addOpts = {
    isMbr = isMbr,
    includeMbrOnly = isOsdPathPicker,
    useMbrHddLabels = isOsdPathPicker,
  }

  -- Preferred choose-device order:
  -- MC1, MC2, MMCE1, MMCE2, USB1, USB2, MX4SIO, APA HDD, exFAT HDD.
  addStaticByName(out, addedStatic, "mc0:", addOpts)
  addStaticByName(out, addedStatic, "mc1:", addOpts)
  addStaticByName(out, addedStatic, "mmce0:", addOpts)
  addStaticByName(out, addedStatic, "mmce1:", addOpts)
  addBdmById(out, addedBdm, "usb0", addOpts)
  addBdmById(out, addedBdm, "usb1", addOpts)
  addBdmById(out, addedBdm, "mx4sio", addOpts)
  addStaticByName(out, addedStatic, "hdd0:", addOpts)
  if isMbr or isOsdPathPicker then addStaticByName(out, addedStatic, "hdd1:", addOpts) end
  addBdmById(out, addedBdm, "ata0", addOpts)
  if isMbr or isOsdPathPicker then addBdmById(out, addedBdm, "ata1", addOpts) end
  if isMbr then addXfromMbr(out, addedStatic) end

  -- Keep any other supported devices after the preferred block.
  for _, s in ipairs(STATIC) do
    addStatic(out, addedStatic, s, addOpts)
  end
  for _, opt in ipairs(BDM_OPTIONS) do
    addBdm(out, addedBdm, opt, addOpts)
  end
  local deferredMbrSpecials = {}
  local function appendSpecial(s)
    if not s then return end
    if not isRuntimePsx() and (s.name == "$XOSD" or s.name == "$OSDMENU") then return end
    local desc = (s.descKey and dev[s.descKey]) or s.name
    local helper = (s.helperKey and pathStrings[s.helperKey]) or nil
    if isFmcbContext and s.name == "POWEROFF" then
      desc = "POWEROFF"
    end
    table.insert(out, withFlags({ name = s.name, desc = desc, helper = helper, special = s.special }))
  end
  for _, s in ipairs(SPECIAL) do
    if inContext(s.contexts, context) then
      if isMbr and (s.name == "$XOSD" or s.name == "$OSDMENU") then
        deferredMbrSpecials[#deferredMbrSpecials + 1] = s
      else
        appendSpecial(s)
      end
    end
  end
  for _, s in ipairs(deferredMbrSpecials) do
    appendSpecial(s)
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
    name = tostring(name):gsub("^/+", ""):gsub("/+$", "")
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

-- BDM deviceId (ata0, usb0, usb1, mx4sio) -> path prefix for config.
-- Optional context allows scene-specific prefix mapping.
function file_selector.getBdmPathPrefix(deviceId, context, fileType)
  if not deviceId then return nil end
  for _, opt in ipairs(BDM_OPTIONS) do
    if opt.deviceId == deviceId then return bdmPrefixForContext(opt, context, fileType) end
  end
  return nil
end

function file_selector.getBdmBrowsePrefix(deviceId)
  if not deviceId then return nil end
  for _, opt in ipairs(BDM_OPTIONS) do
    if opt.deviceId == deviceId then return bdmBrowsePrefix(opt) end
  end
  return nil
end

-- Convert path to wildcard form: mc0/mc1 -> mc?, mmce0/mmce1 -> mmce?, usb0/usb1 -> usb:.
function file_selector.toWildcard(path)
  if not path then return path end
  path = path:gsub("^mc0:", "mc?:")
  path = path:gsub("^mc1:", "mc?:")
  path = path:gsub("^mmce0:", "mmce?:")
  path = path:gsub("^mmce1:", "mmce?:")
  path = path:gsub("^usb0:", "usb:")
  path = path:gsub("^usb1:", "usb:")
  return path
end

-- Check if path is mc0/mc1, mmce0/mmce1, or usb0/usb1 (can offer wildcard).
function file_selector.canWildcard(path)
  if not path then return false end
  local p = pathPrefix(path)
  return p == "mc0:" or p == "mc1:" or p == "mmce0:" or p == "mmce1:" or p == "usb0:" or p == "usb1:"
end

-- Resolve logical deviceId (ata0, usb0, usb1, mx4sio) to current mountpoint (e.g. mass0:). Returns nil if not found.
function file_selector.getDeviceMountpoint(deviceId)
  if not System or not System.getDeviceMountpoint or not deviceId then return nil end
  return System.getDeviceMountpoint(deviceId)
end

return file_selector
