--[[ Path picker: device list, partitions, or directory browse. ]]

local actions_menu = dofile("scripts/scenes/actions_menu.lua")

local function hideRuntimeHddDevices(ctx)
  local _ = ctx and ctx._
  if _ and _.common and _.common.hideRuntimeHddDevices then
    return _.common.hideRuntimeHddDevices()
  end
  local runtime = _G and _G.CONFIG_UI
  local platform = runtime and runtime.runtimePlatform
  return type(platform) == "table" and platform.hideHddDevices == true
end

local function bootKeyPickerOpts(ctx)
  if not ctx then return nil end
  if ctx.pathPickerBootKeyDisabled == nil then return nil end
  return { keyDisabledOverride = ctx.pathPickerBootKeyDisabled and true or false }
end

-- Apply chosen path for MBR boot key and return next state. Returns nil if not a boot-key pick.
local function applyBootPathAndReturn(ctx, val)
  if not ctx.pathPickerBootKey or not ctx.lines then return nil end
  local _ = ctx._
  local bootOpts = bootKeyPickerOpts(ctx)
  local bootKey = ctx.pathPickerBootKey
  local parentWasDisabled = (ctx.pathPickerBootKeyDisabled == true) or
      ((_.config_parse.isBootKeyDisabled and _.config_parse.isBootKeyDisabled(ctx.lines, bootKey)) and true or false)
  local selectedPathIdx = nil
  if ctx.pathPickerEditIdx then
    local paths = _.config_parse.getBootPathEntries(ctx.lines, bootKey, bootOpts) or {}
    local item = paths[ctx.pathPickerEditIdx]
    if type(item) == "table" then
      item.value = val
      item.disabled = false
      item.comment = nil
    else
      paths[ctx.pathPickerEditIdx] = { value = val, disabled = false }
    end
    selectedPathIdx = ctx.pathPickerEditIdx
    _.config_parse.setBootPathEntries(ctx.lines, bootKey, paths, bootOpts)
  elseif ctx.pathPickerInsertBelow then
    selectedPathIdx = _.config_parse.insertBootPathBelow(ctx.lines, bootKey, ctx.pathPickerInsertBelow, val, bootOpts)
  else
    selectedPathIdx = _.config_parse.insertBootPathBelow(ctx.lines, bootKey, 0x7fffffff, val, bootOpts)
  end
  if parentWasDisabled and selectedPathIdx and _.config_parse.enableBootPathFromDisabledParent then
    _.config_parse.enableBootPathFromDisabledParent(ctx.lines, bootKey, selectedPathIdx)
    ctx.entryPathsBootKeyDisabledTag = tostring(bootKey or "")
    ctx.entryPathsBootKeyDisabledOverride = false
    ctx.entryArgsBootKeyDisabledTag = tostring(bootKey or "")
    ctx.entryArgsBootKeyDisabledOverride = false
  end
  if _.config_parse.applyOsdmbrBootAutoArgs then
    _.config_parse.applyOsdmbrBootAutoArgs(ctx.lines, bootKey)
    ctx.entryArgsPathsCache = nil
    ctx.entryArgsModelCache = nil
  end
  ctx.state = ctx.pathPickerReturnState or "editor"
  ctx.pathPickerBootKey = nil
  ctx.pathPickerBootKeyDisabled = nil
  ctx.pathPickerReturnState = nil
  ctx.pathPickerForEntryIdx = nil
  ctx.pathPickerEditIdx = nil
  ctx.pathPickerInsertBelow = nil
  return true
end

-- Apply chosen path for a BBL hotkey slot and return next state. Returns nil if not a BBL slot pick.
local function applyBblHotkeyPathAndReturn(ctx, val)
  if not ctx.pathPickerBblHotkeyKey or not ctx.pathPickerBblHotkeySlot or not ctx.lines then return nil end
  local _ = ctx._
  local slot = tonumber(ctx.pathPickerBblHotkeySlot)
  if not slot then return nil end
  local key = ctx.pathPickerBblHotkeyKey
  local parentWasDisabled = (_.config_parse.isBblHotkeyDisabled and _.config_parse.isBblHotkeyDisabled(ctx.lines, key)) and
      true or false
  _.config_parse.setBblHotkeyPath(ctx.lines, key, slot, val, false)
  if parentWasDisabled and _.config_parse.enableBblHotkeySlotFromDisabledParent then
    _.config_parse.enableBblHotkeySlotFromDisabledParent(ctx.lines, key, slot)
  end
  ctx.state = ctx.pathPickerReturnState or "bbl_hotkey_entry"
  ctx.pathPickerBblHotkeyKey = nil
  ctx.pathPickerBblHotkeySlot = nil
  ctx.pathPickerBblHotkeyDisabled = nil
  ctx.pathPickerReturnState = nil
  ctx.pathPickerEditIdx = nil
  return true
end

local function applyBblIrxPathAndReturn(ctx, val)
  if not ctx.pathPickerBblIrxIdx or not ctx.lines then return nil end
  local _ = ctx._
  local entryIdx = tonumber(ctx.pathPickerBblIrxIdx)
  if not entryIdx then return nil end
  _.config_parse.setBblIrxEntry(ctx.lines, entryIdx, val, false)
  ctx.state = ctx.pathPickerReturnState or "bbl_irx_entries"
  ctx.pathPickerBblIrxIdx = nil
  ctx.pathPickerBblIrxDisabled = nil
  ctx.pathPickerReturnState = nil
  ctx.pathPickerEditIdx = nil
  ctx.pathPickerFileExts = nil
  return true
end

-- Convert pfs path (pfs0:/ or pfs1:/...) to full partition path (hdd0:PART:pfs:/...).
-- Returns nil if not a pfs path.
local function pfsToPartitionPath(pfsPath, partitionPath)
  if not pfsPath or not partitionPath then return nil end
  local part = tostring(partitionPath or "")
  part = part:gsub("^%s+", ""):gsub("%s+$", "")
  part = part:gsub("^(hdd%d):/+", "%1:")
  local partFromPfs = part:match("^(hdd%d:[^:]+):pfs:.*$")
  if partFromPfs then
    part = partFromPfs
  end
  part = part:gsub("/+$", "")
  local rest = tostring(pfsPath):match("^pfs[01]:(.*)$")
  if not rest then return nil end
  if rest == "" then
    rest = "/"
  else
    rest = "/" .. rest:gsub("^/+", "")
  end
  return part .. ":pfs:" .. rest
end

-- IOP reset unloads all device drivers; clear all loaded flags.
local function clearLoadedIfIopReset(ctx)
  ctx.pathPickerLoadedDeviceTypes = {}
end

local function resetIopForMc1AfterSlotDriver(ctx, e)
  if not (ctx and e and e.name == "mc1:") then return end
  local loaded = ctx.pathPickerLoadedDeviceTypes
  if not (loaded and (loaded["mx4sio"] or loaded["mmce"])) then return end
  if not (System and System.resetIOP) then return end
  System.resetIOP()
  clearLoadedIfIopReset(ctx)
end

local function isConfigOpenTarget(ctx)
  return ctx and ctx.pathPickerTarget == "config_open"
end

local function getPickerDevices(ctx, _)
  if not (_ and _.file_selector and _.file_selector.getDevices) then return {} end
  return _.file_selector.getDevices(ctx and ctx.pathPickerContext, {
    fileType = ctx and ctx.fileType
  }) or {}
end

local function hasIniFilter(ctx)
  if not ctx or type(ctx.pathPickerFileExts) ~= "table" then return false end
  for i = 1, #ctx.pathPickerFileExts do
    local ext = tostring(ctx.pathPickerFileExts[i] or ""):lower()
    if ext ~= "" and ext:sub(1, 1) ~= "." then ext = "." .. ext end
    if ext == ".ini" then return true end
  end
  return false
end

local function hasIrxFilter(ctx)
  if not ctx or type(ctx.pathPickerFileExts) ~= "table" then return false end
  for i = 1, #ctx.pathPickerFileExts do
    local ext = tostring(ctx.pathPickerFileExts[i] or ""):lower()
    if ext ~= "" and ext:sub(1, 1) ~= "." then ext = "." .. ext end
    if ext == ".irx" then return true end
  end
  return false
end

local function isBblIrxPath(path)
  local s = tostring(path or ""):gsub("^%s+", ""):gsub("%s+$", "")
  return s ~= "" and s:lower():match("%.irx$") ~= nil, s
end

local function normalizeBdmRoot(prefix)
  if type(prefix) ~= "string" or prefix == "" then return nil end
  return (prefix:sub(-1) == ":") and prefix or (prefix .. ":")
end

local function bdmPathFromRoot(root, rest)
  root = normalizeBdmRoot(root)
  if not root then return nil end
  rest = tostring(rest or ""):gsub("^/+", "")
  if rest == "" then return root .. "/" end
  return root .. "/" .. rest
end

local function bdmRestFromPath(path, root)
  root = normalizeBdmRoot(root)
  if not root then return nil end
  local p = tostring(path or "")
  if p == root or p == root .. "/" then return "" end
  if p:sub(1, #root) ~= root then return nil end
  return p:sub(#root + 1):gsub("^/+", "")
end

local function isIndexedUsbPath(path)
  return tostring(path or ""):match("^usb%d:") ~= nil
end

local function bdmAccessPathForBrowse(ctx, path)
  if not (ctx and ctx.pathPickerBdmBrowseRoot and ctx.pathPickerBdmMountpoint) then return path end
  local rest = bdmRestFromPath(path, ctx.pathPickerBdmBrowseRoot)
  if rest == nil then return path end
  return bdmPathFromRoot(ctx.pathPickerBdmMountpoint, rest) or path
end

local function mapBdmEntriesToBrowse(ctx, entries)
  if not (ctx and ctx.pathPickerBdmBrowseRoot and ctx.pathPickerBdmMountpoint) then return entries end
  if type(entries) ~= "table" then return entries end
  for i = 1, #entries do
    local e = entries[i]
    if e and e.full then
      local rest = bdmRestFromPath(e.full, ctx.pathPickerBdmMountpoint)
      if rest ~= nil then
        e.full = bdmPathFromRoot(ctx.pathPickerBdmBrowseRoot, rest) or e.full
      end
    end
  end
  return entries
end

local function listBrowseEntries(ctx, path)
  local _ = ctx._
  local accessPath = bdmAccessPathForBrowse(ctx, path)
  if isConfigOpenTarget(ctx) then
    local fileType = tostring(ctx and ctx.fileType or "")
    local browsePathLower = tostring(path or ""):lower()
    local allowPsxBblIni = (fileType == "psxbbl_ini") and
        (browsePathLower:match("^mc0:/") or browsePathLower:match("^mc1:/"))
    local raw = _.file_selector.listDirectory(accessPath) or {}
    local out = {}
    for i = 1, #raw do
      local e = raw[i]
      if e and e.directory then
        table.insert(out, e)
      elseif e then
        local nameLower = tostring(e.name or ""):lower()
        if nameLower == "config.ini" or (allowPsxBblIni and nameLower == "psxbbl.ini") then
          table.insert(out, e)
        end
      end
    end
    return mapBdmEntriesToBrowse(ctx, out)
  end
  local exts = ctx.pathPickerFileExts
  if type(exts) == "table" and #exts > 0 and _.common and _.common.listDirectoryFiltered then
    return mapBdmEntriesToBrowse(ctx, _.common.listDirectoryFiltered(accessPath, _.file_selector, { extensions = exts }))
  end
  return mapBdmEntriesToBrowse(ctx, _.listDirectoryElfOnly(accessPath))
end

local function clearPickerTransient(ctx)
  ctx.pathList = nil
  ctx.pathBrowsePath = nil
  ctx.pathPickerBdmPrefix = nil
  ctx.pathPickerBdmBrowseRoot = nil
  ctx.pathPickerBdmMountpoint = nil
  ctx.pathPickerBrowseSelStack = nil
end

local function clearConfigOpenPickerState(ctx)
  ctx.pathPickerTarget = nil
  ctx.pathPickerFileExts = nil
  ctx.pathPickerLockedDevice = nil
  ctx.pathPickerLockedDeviceStarted = nil
end

local function getPathFlagsCaseAware(fileSelector, pathVal)
  local getPathFlags = fileSelector and fileSelector.getPathFlags
  if not getPathFlags then return {} end
  local flags = getPathFlags(pathVal) or {}
  if (not flags.exclusive) and type(pathVal) == "string" then
    local lower = pathVal:lower()
    if lower ~= pathVal then
      local lowerFlags = getPathFlags(lower) or {}
      if lowerFlags.exclusive then
        flags = lowerFlags
      end
    end
  end
  return flags
end

local function isFmcbAutoBootPickerContext(ctx)
  if not ctx or not ctx.pathPickerBblHotkeyKey then return false end
  local isFmcb = (ctx.fileType == "freemcboot_cnf") or (ctx.context == "freehddboot")
  if not isFmcb then return false end
  return tostring(ctx.pathPickerBblHotkeyKey or ""):upper() == "AUTO"
end

local function isE1LockedPath(ctx, pathVal)
  local up = tostring(pathVal or ""):gsub("^%s+", ""):gsub("%s+$", ""):upper()
  if up == "CDROM" then return true end
  if up == "POWEROFF" then return true end
  if up == "FASTBOOT" then
    -- Free*BOOT AUTO special-case: FASTBOOT can coexist with other paths.
    return not isFmcbAutoBootPickerContext(ctx)
  end
  if up == "OSDSYS" then
    -- Free*BOOT Auto boot is special: OSDSYS may coexist with regular device paths.
    return not isFmcbAutoBootPickerContext(ctx)
  end
  return false
end

local function isBblE1ExclusivePath(ctx, pathVal)
  local common = ctx and ctx._ and ctx._.common
  if common and common.isBblSpecialExclusivePath then
    return common.isBblSpecialExclusivePath(pathVal)
  end
  local up = tostring(pathVal or ""):gsub("^%s+", ""):gsub("%s+$", ""):upper()
  return up == "CDROM" or up == "$CDVD" or up == "$CDVD_NO_PS2LOGO" or up == "$CREDITS" or up == "$HDDCHECKER"
end

local function isPathExclusiveInContext(ctx, pathVal, flags)
  if not (flags and flags.exclusive) then return false end
  local up = tostring(pathVal or ""):gsub("^%s+", ""):gsub("%s+$", ""):upper()
  if isFmcbAutoBootPickerContext(ctx) then
    -- Free*BOOT AUTO special-case: OSDSYS and FASTBOOT are not exclusive
    -- against normal device paths (single-use rules are enforced separately).
    if up == "OSDSYS" or up == "FASTBOOT" then
      return false
    end
  end
  return true
end

local function getFmcbSingleUseCommand(ctx, pathVal)
  local up = tostring(pathVal or ""):gsub("^%s+", ""):gsub("%s+$", ""):upper()
  if up == "POWEROFF" then
    return up
  end
  if isFmcbAutoBootPickerContext(ctx) then
    -- Free*BOOT Auto boot special-case:
    -- allow OSDSYS/OSDMENU alongside regular device paths,
    -- but keep OSDSYS and OSDMENU mutually exclusive with each other.
    if up == "OSDSYS" or up == "OSDMENU" then
      return "__FMCB_AUTO_OSD_GROUP__"
    end
    if up == "FASTBOOT" then
      return up
    end
    return nil
  end
  -- Free*BOOT conflict set:
  -- OSDMENU, OSDSYS, and FASTBOOT are mutually exclusive in menu entries / launch keys.
  if up == "OSDSYS" or up == "OSDMENU" or up == "FASTBOOT" then
    return "__FMCB_OSD_FASTBOOT_GROUP__"
  end
  return nil
end

local function isFmcbSingleUseContext(ctx)
  if not ctx then return false end
  if ctx.pathPickerContext == "fmcb_entry" or ctx.pathPickerContext == "fmcb_launch" then
    return true
  end
  if ctx.pathPickerBblHotkeyKey then
    return (ctx.fileType == "freemcboot_cnf") or (ctx.context == "freehddboot")
  end
  return false
end

local function getBblMaxEntriesForContext(ctx)
  local _ = ctx._
  local maxEntries = (_.config_parse.getBblMaxEntries and _.config_parse.getBblMaxEntries()) or 10
  local isFmcb = (ctx.fileType == "freemcboot_cnf") or (ctx.context == "freehddboot")
  if isFmcb then
    local fmcbCap = (_.config_options and _.config_options.FMCB_BBL_MAX_ENTRIES) or 3
    maxEntries = math.max(1, math.min(maxEntries, fmcbCap))
  end
  return maxEntries
end

-- Performance note:
-- Free*BOOT Auto boot / Launch Keys choose-device can drop to ~30 FPS if we
-- repeatedly call getBblHotkeySlot() per frame. Keep these per-slot stats
-- cached and shared by both getOtherTargetPathStats() and
-- buildFmcbSingleUseTakenMap() so we only scan slots once per frame context.
local function getCachedBblPickerSelectionStats(ctx, keyId, slot, maxEntries)
  if not (ctx and ctx.lines and keyId and slot and maxEntries) then return nil end
  local cache = ctx.pathPickerBblSelectionCache
  if cache and cache.linesRef == ctx.lines and cache.pathListRef == ctx.pathList and cache.keyId == keyId and
      cache.slot == slot and cache.maxEntries == maxEntries then
    return cache.stats, cache.taken
  end

  local _ = ctx._
  local stats = { count = 0, firstExclusive = false, firstCdrom = false, targetIndex = slot }
  local taken = {}
  local slots = {}
  for i = 1, maxEntries do
    local s = _.config_parse.getBblHotkeySlot(ctx.lines, keyId, i)
    local pv = s and s.path or nil
    local hasValue = false
    if s and s.pathExists then
      local sv = tostring(pv or ""):gsub("^%s+", ""):gsub("%s+$", "")
      hasValue = (sv ~= "")
    end
    slots[i] = { path = pv, hasValue = hasValue }
  end

  if slot ~= 1 then
    local first = slots[1]
    local firstPv = first and first.path or nil
    if first and first.hasValue then
      stats.firstExclusive = (isE1LockedPath(ctx, firstPv) or isBblE1ExclusivePath(ctx, firstPv)) and true or false
      stats.firstCdrom = (type(firstPv) == "string" and firstPv:lower() == "cdrom") and true or false
    end
  end

  for i = 1, maxEntries do
    if i ~= slot then
      local s = slots[i]
      if s and s.hasValue then
        stats.count = stats.count + 1
        local cmd = getFmcbSingleUseCommand(ctx, s.path)
        if cmd then taken[cmd] = true end
      end
    end
  end

  ctx.pathPickerBblSelectionCache = {
    linesRef = ctx.lines,
    pathListRef = ctx.pathList,
    keyId = keyId,
    slot = slot,
    maxEntries = maxEntries,
    stats = stats,
    taken = taken,
  }
  return stats, taken
end

local function buildFmcbSingleUseTakenMap(ctx, targetIndex)
  local taken = {}
  if not isFmcbSingleUseContext(ctx) then return taken end
  local _ = ctx._
  if ctx.pathPickerBblHotkeyKey and ctx.lines and _.config_parse.getBblHotkeySlot then
    local keyId = ctx.pathPickerBblHotkeyKey
    local slot = tonumber(targetIndex) or tonumber(ctx.pathPickerBblHotkeySlot) or 1
    local maxEntries = getBblMaxEntriesForContext(ctx)
    local _, cachedTaken = getCachedBblPickerSelectionStats(ctx, keyId, slot, maxEntries)
    if cachedTaken then return cachedTaken end
    return taken
  end

  local paths = nil
  if ctx.pathPickerForEntryIdx and ctx.lines then
    paths = _.config_parse.getMenuEntryPaths(ctx.lines, ctx.pathPickerForEntryIdx) or {}
  elseif ctx.pathPickerBootKey and ctx.lines then
    paths = _.config_parse.getBootPathEntries(ctx.lines, ctx.pathPickerBootKey, bootKeyPickerOpts(ctx)) or {}
  end
  if not paths then return taken end
  for i = 1, #paths do
    if not targetIndex or i ~= targetIndex then
      local item = paths[i]
      local pv = type(item) == "table" and item.value or item
      local cmd = getFmcbSingleUseCommand(ctx, pv)
      if cmd then taken[cmd] = true end
    end
  end
  return taken
end

local function isFmcbEntryE1LockedPath(ctx, pathVal)
  if not ctx or ctx.pathPickerContext ~= "fmcb_entry" then return false end
  local up = tostring(pathVal or ""):gsub("^%s+", ""):gsub("%s+$", ""):upper()
  return up == "OSDSYS" or up == "POWEROFF" or up == "FASTBOOT"
end

local function isFmcbLaunchE1LockedPath(ctx, pathVal)
  if not ctx or not ctx.pathPickerBblHotkeyKey then return false end
  local isFmcb = (ctx.fileType == "freemcboot_cnf") or (ctx.context == "freehddboot")
  if not isFmcb then return false end
  local up = tostring(pathVal or ""):gsub("^%s+", ""):gsub("%s+$", ""):upper()
  if isFmcbAutoBootPickerContext(ctx) then
    return up == "POWEROFF"
  end
  return up == "FASTBOOT" or up == "POWEROFF"
end

local function isE1RestrictedPathForContext(ctx, pathVal)
  if isBblE1ExclusivePath(ctx, pathVal) then return true end
  if isFmcbEntryE1LockedPath(ctx, pathVal) then return true end
  if isFmcbLaunchE1LockedPath(ctx, pathVal) then return true end
  return false
end

local function hasUsablePathValue(pathVal)
  local s = tostring(pathVal or "")
  s = s:gsub("^%s+", ""):gsub("%s+$", "")
  return s ~= ""
end

local function getFirstEmptyPathIndex(paths)
  for i = 1, #(paths or {}) do
    local item = paths[i]
    local pv = type(item) == "table" and item.value or item
    if not hasUsablePathValue(pv) then
      return i
    end
  end
  return nil
end

local function trimmedText(value)
  return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function defaultNameFromPickerEntry(entry)
  if not (entry and entry.defaultName) then return nil end
  local name = trimmedText(entry.presetName or entry.desc or "")
  return (name ~= "") and name or nil
end

local function getManualPathPrefillValue(ctx)
  if not ctx then return "" end
  local _ = ctx._
  local function asText(v)
    if v == nil then return "" end
    return tostring(v)
  end
  local editIdx = tonumber(ctx.pathPickerEditIdx)

  -- Single-value path option edit (editor optType="path").
  if ctx.editKey and ctx.lines and _.config_parse and _.config_parse.get then
    local v = _.config_parse.get(ctx.lines, ctx.editKey)
    if v ~= nil then
      return asText(v)
    end
  end

  -- Menu entry path edit.
  if ctx.pathPickerForEntryIdx and ctx.lines and editIdx and editIdx >= 1 and _.config_parse and _.config_parse.getMenuEntryPaths then
    local paths = _.config_parse.getMenuEntryPaths(ctx.lines, ctx.pathPickerForEntryIdx) or {}
    local item = paths[editIdx]
    local pv = type(item) == "table" and item.value or item
    return asText(pv)
  end

  -- Boot key path edit.
  if ctx.pathPickerBootKey and ctx.lines and editIdx and editIdx >= 1 and _.config_parse and _.config_parse.getBootPathEntries then
    local paths = _.config_parse.getBootPathEntries(ctx.lines, ctx.pathPickerBootKey, bootKeyPickerOpts(ctx)) or {}
    local item = paths[editIdx]
    local pv = type(item) == "table" and item.value or item
    return asText(pv)
  end

  -- BBL hotkey slot path edit.
  if ctx.pathPickerBblHotkeyKey and ctx.pathPickerBblHotkeySlot and ctx.lines and _.config_parse and _.config_parse.getBblHotkeySlot then
    local slotNum = tonumber(ctx.pathPickerBblHotkeySlot)
    local slot = slotNum and _.config_parse.getBblHotkeySlot(ctx.lines, ctx.pathPickerBblHotkeyKey, slotNum) or nil
    if slot and slot.pathExists then
      return asText(slot.path)
    end
  end

  -- BBL IRX path edit.
  if ctx.pathPickerBblIrxIdx and ctx.lines and _.config_parse and _.config_parse.getBblIrxEntry then
    local entryIdx = tonumber(ctx.pathPickerBblIrxIdx)
    local v = entryIdx and _.config_parse.getBblIrxEntry(ctx.lines, entryIdx) or nil
    if v ~= nil then
      return asText(v)
    end
  end

  return ""
end

local function setMenuEntryPathValue(paths, editIdx, val)
  if editIdx and editIdx >= 1 then
    local item = paths[editIdx]
    if type(item) == "table" then
      item.value = val
      item.disabled = false
      item.comment = nil
    else
      paths[editIdx] = { value = val, disabled = false }
    end
    return editIdx
  end
  local firstEmptyIdx = getFirstEmptyPathIndex(paths)
  if firstEmptyIdx then
    local item = paths[firstEmptyIdx]
    if type(item) == "table" then
      item.value = val
      item.disabled = false
      item.comment = nil
    else
      paths[firstEmptyIdx] = { value = val, disabled = false }
    end
    return firstEmptyIdx
  end
  table.insert(paths, { value = val, disabled = false })
  return #paths
end

local function applyMenuEntryPathAndReturn(ctx, val, opts)
  if not ctx.pathPickerForEntryIdx or not ctx.lines then return nil end
  local _ = ctx._
  local entryIdx = ctx.pathPickerForEntryIdx
  local paths = _.config_parse.getMenuEntryPaths(ctx.lines, entryIdx)
  local pathIdx = setMenuEntryPathValue(paths, ctx.pathPickerEditIdx, val)
  _.config_parse.setMenuEntryPaths(ctx.lines, entryIdx, paths)
  if pathIdx and _.config_parse.isMenuEntryDisabled and _.config_parse.isMenuEntryDisabled(ctx.lines, entryIdx) and
      _.config_parse.enableMenuEntryPathFromDisabledParent then
    _.config_parse.enableMenuEntryPathFromDisabledParent(ctx.lines, entryIdx, pathIdx)
  end
  if opts and opts.noargs then
    _.config_parse.setMenuEntryArgs(ctx.lines, entryIdx, {})
  elseif opts and type(opts.args) == "table" then
    _.config_parse.setMenuEntryArgs(ctx.lines, entryIdx, opts.args)
  end
  local defaultName = type(opts) == "table" and opts.defaultName or nil
  if defaultName and _.config_parse.getMenuEntryName and _.config_parse.setMenuEntryName then
    local currentName = _.config_parse.getMenuEntryName(ctx.lines, entryIdx) or ""
    if trimmedText(currentName) == "" then
      _.config_parse.setMenuEntryName(ctx.lines, entryIdx, defaultName)
    end
  end
  ctx.entryIdx = entryIdx
  ctx.state = ctx.pathPickerReturnState or (ctx.pathPickerEditIdx and "entry_paths") or "menu_entry_edit"
  ctx.pathPickerForEntryIdx = nil
  ctx.pathPickerEditIdx = nil
  ctx.pathPickerReturnState = nil
  return true
end

local function hasFmcbSingleUseDuplicateInTarget(ctx, pathVal, targetIndex, takenMap)
  if not isFmcbSingleUseContext(ctx) then return false end
  local cmd = getFmcbSingleUseCommand(ctx, pathVal)
  if not cmd then return false end
  local map = takenMap or buildFmcbSingleUseTakenMap(ctx, targetIndex)
  return map[cmd] and true or false
end

local function getOtherTargetPathStats(ctx)
  local _ = ctx._
  local editIdx = tonumber(ctx.pathPickerEditIdx)
  local out = { count = 0, firstExclusive = false, firstCdrom = false, targetIndex = nil }
  local paths = nil
  if ctx.pathPickerBblHotkeyKey and ctx.pathPickerBblHotkeySlot and ctx.lines and _.config_parse.getBblHotkeySlot then
    local keyId = ctx.pathPickerBblHotkeyKey
    local slot = tonumber(ctx.pathPickerBblHotkeySlot) or 1
    local maxEntries = getBblMaxEntriesForContext(ctx)
    local cachedStats = getCachedBblPickerSelectionStats(ctx, keyId, slot, maxEntries)
    if cachedStats then return cachedStats end
    return out
  end

  if ctx.pathPickerForEntryIdx and ctx.lines then
    paths = _.config_parse.getMenuEntryPaths(ctx.lines, ctx.pathPickerForEntryIdx) or {}
  elseif ctx.pathPickerBootKey and ctx.lines then
    paths = _.config_parse.getBootPathEntries(ctx.lines, ctx.pathPickerBootKey, bootKeyPickerOpts(ctx)) or {}
  end
  if not paths then return out end

  if editIdx and editIdx >= 1 then
    out.targetIndex = editIdx
  else
    local insertBelow = tonumber(ctx.pathPickerInsertBelow)
    if insertBelow and insertBelow >= 1 then
      out.targetIndex = math.max(1, math.min(#paths + 1, insertBelow + 1))
    else
      out.targetIndex = getFirstEmptyPathIndex(paths) or (#paths + 1)
    end
  end

  -- E1-only rule: only the first path controls whether additional paths are blocked.
  if (not editIdx or editIdx ~= 1) and paths[1] then
    local firstPv = type(paths[1]) == "table" and paths[1].value or paths[1]
    if hasUsablePathValue(firstPv) then
      out.firstExclusive = isE1LockedPath(ctx, firstPv) and true or false
      out.firstCdrom = (type(firstPv) == "string" and firstPv:lower() == "cdrom") and true or false
    end
  end

  for i = 1, #paths do
    if not editIdx or i ~= editIdx then
      local item = paths[i]
      local pv = type(item) == "table" and item.value or item
      if hasUsablePathValue(pv) then
        out.count = out.count + 1
      end
    end
  end
  return out
end

local function showExclusivePathWarning(ctx, pathVal)
  local _ = ctx._
  local p = tostring(pathVal or "")
  local pLower = p:lower()
  local detail
  if pLower == "cdrom" then
    detail = _.menu_str and _.menu_str.cdrom_exclusive_warning
  end
  if not detail or detail == "" then
    detail = (_.path_str and _.path_str.exclusive_path_warning) or
        "This path must be the first and only path for this entry."
  end
  ctx.saveSplash = {
    kind = "failed",
    title = (_.menu_str and _.menu_str.invalid_selection_title) or
        (_.path_str and _.path_str.invalid_selection_title) or "Invalid selection",
    detail = detail,
    framesLeft = 120
  }
end

local function showPathNotSupportedWarning(ctx, detail)
  local _ = ctx._
  local fallback = "This path is not supported in this context."
  ctx.saveSplash = {
    kind = "failed",
    title = (_.menu_str and _.menu_str.invalid_selection_title) or
        (_.path_str and _.path_str.invalid_selection_title) or "Invalid selection",
    detail = (type(detail) == "string" and detail ~= "") and detail or fallback,
    framesLeft = 120
  }
end

local function isBblPathOnlyXfromDisallowed(ctx, pathVal)
  if not ctx or ctx.pathPickerContext ~= "path_only" then return false end
  local ft = tostring(ctx.fileType or "")
  if ft ~= "ps2bbl_ini" and ft ~= "psxbbl_ini" then return false end
  local p = tostring(pathVal or ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()
  if p:match("^xfrom:") == nil then return false end
  -- PSXBBL allows xfrom: entry paths; PS2BBL does not.
  return ft ~= "psxbbl_ini"
end

local function isPsxBblXfromPathWithoutElf(ctx, pathVal)
  if not ctx or ctx.pathPickerContext ~= "path_only" then return false end
  if tostring(ctx.fileType or "") ~= "psxbbl_ini" then return false end
  local p = tostring(pathVal or ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()
  if p:match("^xfrom:") == nil then return false end
  return p:match("%.elf$") == nil
end

local function canUsePathSelection(ctx, pathVal, singleUseTakenMap)
  local _ = ctx._
  if isBblPathOnlyXfromDisallowed(ctx, pathVal) then
    showPathNotSupportedWarning(ctx,
      "xfrom: entry paths are supported only for PSXBBL.")
    return false
  end
  if isPsxBblXfromPathWithoutElf(ctx, pathVal) then
    showPathNotSupportedWarning(ctx,
      "xfrom: paths for PSXBBL must point to an .elf file.")
    return false
  end
  local flags = getPathFlagsCaseAware(_.file_selector, pathVal)
  local pathIsExclusive = isPathExclusiveInContext(ctx, pathVal, flags)
  local stats = getOtherTargetPathStats(ctx)
  local targetIndex = tonumber(stats.targetIndex)
  if hasFmcbSingleUseDuplicateInTarget(ctx, pathVal, targetIndex, singleUseTakenMap) then
    showExclusivePathWarning(ctx, pathVal)
    return false
  end
  if targetIndex and targetIndex ~= 1 and isE1RestrictedPathForContext(ctx, pathVal) then
    showExclusivePathWarning(ctx, pathVal)
    return false
  end
  if targetIndex and isBblE1ExclusivePath(ctx, pathVal) then
    if stats.count == 0 then return true end
    showExclusivePathWarning(ctx, pathVal)
    return false
  end
  if pathIsExclusive then
    if stats.count == 0 then return true end
    showExclusivePathWarning(ctx, pathVal)
    return false
  end
  if stats.firstExclusive then
    showExclusivePathWarning(ctx, stats.firstCdrom and "cdrom" or pathVal)
    return false
  end
  return true
end

local function leaveLockedConfigBrowse(ctx)
  if ctx.pfs0Mounted and System.fileXioUmount then System.fileXioUmount("pfs0:") end
  if ctx.pfs1Mounted and System.fileXioUmount then System.fileXioUmount("pfs1:") end
  ctx.pfs0Mounted = nil
  ctx.pfs1Mounted = nil
  clearPickerTransient(ctx)
  ctx.pathPickerLoading = nil
  ctx.pathPickerLoadingFrames = nil
  ctx.pathPickerModulesLoaded = nil
  ctx.pathPickerLoadingTimeoutMsg = nil
  ctx.state = ctx.pathPickerReturnState or "select_config"
  ctx.pathPickerReturnState = nil
  clearConfigOpenPickerState(ctx)
end

local function applyConfigOpenPathAndReturn(ctx, val)
  if not isConfigOpenTarget(ctx) then return nil end
  if ctx.pfs0Mounted and System.fileXioUmount then System.fileXioUmount("pfs0:") end
  if ctx.pfs1Mounted and System.fileXioUmount then System.fileXioUmount("pfs1:") end
  ctx.pfs0Mounted = nil
  ctx.pfs1Mounted = nil
  clearPickerTransient(ctx)
  ctx.currentPath = tostring(val or ""):gsub("/$", "")
  ctx.openExplicitPath = true
  ctx.state = "open"
  ctx.pathPickerReturnState = nil
  clearConfigOpenPickerState(ctx)
  return true
end

-- Apply a manually entered path and leave path picker (used by "Enter path manually" text input callback).
local function applyManualPath(ctx, val)
  if not val or val == "" then
    if isConfigOpenTarget(ctx) then
      if ctx.pfs0Mounted and System.fileXioUmount then System.fileXioUmount("pfs0:") end
      if ctx.pfs1Mounted and System.fileXioUmount then System.fileXioUmount("pfs1:") end
      ctx.pfs0Mounted = nil
      ctx.pfs1Mounted = nil
      ctx.state = ctx.pathPickerReturnState or "select_config"
      clearPickerTransient(ctx)
      ctx.pathPickerReturnState = nil
      clearConfigOpenPickerState(ctx)
      return
    end
    -- Done with empty path: return to entry paths or path_picker so we don't show "Choose device" / "No devices"
    if ctx.pathPickerForEntryIdx then
      ctx.entryIdx = ctx.pathPickerForEntryIdx
      ctx.state = ctx.pathPickerReturnState or (ctx.pathPickerEditIdx and "entry_paths") or "menu_entry_edit"
      ctx.pathPickerForEntryIdx = nil
      ctx.pathPickerEditIdx = nil
      ctx.pathPickerInsertBelow = nil
    elseif ctx.pathPickerBblHotkeyKey then
      ctx.state = ctx.pathPickerReturnState or "bbl_hotkey_entry"
      ctx.pathPickerBblHotkeyKey = nil
      ctx.pathPickerBblHotkeySlot = nil
      ctx.pathPickerBblHotkeyDisabled = nil
    elseif ctx.pathPickerBblIrxIdx then
      ctx.state = ctx.pathPickerReturnState or "bbl_irx_entries"
      ctx.pathPickerBblIrxIdx = nil
      ctx.pathPickerBblIrxDisabled = nil
      ctx.pathPickerFileExts = nil
    else
      ctx.state = ctx.pathPickerReturnState or "editor"
    end
    ctx.pathList = nil
    ctx.pathPickerReturnState = nil
    return
  end
  local _ = ctx._
  if ctx.pathPickerBblIrxIdx then
    local okIrx, normalizedVal = isBblIrxPath(val)
    if not okIrx then
      ctx.saveSplash = {
        kind = "failed",
        title = (_.editor_str and _.editor_str.save_failed) or "Save failed",
        textColor = _.KEYBOARD_SELECTED_COLOR,
        detail = (_.path_str and _.path_str.irx_extension_required) or "Path must end in .irx",
        framesLeft = 60
      }
      ctx.state = "path_picker"
      ctx.pathPickerSub = "device"
      ctx.pathList = getPickerDevices(ctx, _)
      ctx.pathPickerScroll = 0
      return
    end
    val = normalizedVal
  end
  if not canUsePathSelection(ctx, val) then
    ctx.state = "path_picker"
    ctx.pathPickerSub = "device"
    ctx.pathList = getPickerDevices(ctx, _)
    ctx.pathPickerScroll = 0
    return
  end
  if ctx.pfs0Mounted and System.fileXioUmount then System.fileXioUmount("pfs0:") end
  if ctx.pfs1Mounted and System.fileXioUmount then System.fileXioUmount("pfs1:") end
  ctx.pathList = nil
  ctx.pathBrowsePath = nil
  ctx.pfs0Mounted = nil
  ctx.pfs1Mounted = nil
  if applyConfigOpenPathAndReturn(ctx, val) then
    return
  end
  ctx._configModifiedCache = nil
  ctx.configModified = true
  if applyBootPathAndReturn(ctx, val) then
  elseif applyBblHotkeyPathAndReturn(ctx, val) then
  elseif applyBblIrxPathAndReturn(ctx, val) then
  elseif applyMenuEntryPathAndReturn(ctx, val) then
  elseif ctx.isAddPath then
    local key = (ctx.addPathKey == "path1_OSDSYS_ITEM_1") and _.resolveNextOsdItemKey(ctx.lines) or ctx.addPathKey
    _.config_parse.append(ctx.lines, key, val)
    ctx.state = "editor"
  else
    _.config_parse.set(ctx.lines, ctx.editKey or "", val)
    ctx.state = "editor"
  end
  ctx.pathPickerBootKey = nil
  ctx.pathPickerBootKeyDisabled = nil
  ctx.pathPickerReturnState = nil
  ctx.pathPickerInsertBelow = nil
  ctx.pathPickerBdmPrefix = nil
  ctx.pathPickerBdmBrowseRoot = nil
  ctx.pathPickerBdmMountpoint = nil
  clearConfigOpenPickerState(ctx)
end

local function ensureBblCommandRows(ctx)
  if not ctx or ctx.pathPickerContext ~= "path_only" or not ctx.pathPickerBblHotkeyKey then return end
  if not ctx.pathList then return end
  for _, row in ipairs(ctx.pathList) do
    if row and row.special == "bbl_cmd" then
      return
    end
  end
  local _ = ctx._
  local p = _.path_str or {}
  local cmdRows
  if ctx.fileType == "freemcboot_cnf" then
    cmdRows = {
      { name = "OSDSYS", desc = p.fmcb_cmd_osdsys or "Boot hacked OSDSYS", special = "bbl_cmd" },
      { name = "OSDMENU", desc = p.fmcb_cmd_osdmenu or "Boot hacked OSDSYS, enforce skip disc boot", special = "bbl_cmd" },
      { name = "FASTBOOT", desc = p.fmcb_cmd_fastboot or "Boot PS2 Disc without logo", special = "bbl_cmd" },
      {
        name = "POWEROFF",
        desc = p.fmcb_cmd_poweroff or "Shutdown the console: FMCB 1.966 only, else use POWEROFF.ELF",
        special = "bbl_cmd"
      },
    }
  else
    local launchDiscLabel = (_.dev_str and _.dev_str.launch_disc) or
        p.bbl_cmd_cdvd_label or "Launch disc with override"
    cmdRows = {
      { name = "cdrom", desc = launchDiscLabel, special = "bbl_cmd", exclusive = true, noargs = true, specialargs = true },
      { name = "$OSDSYS", desc = p.bbl_cmd_osdsys_label or "OSDSYS", special = "bbl_cmd" },
      { name = "$CREDITS", desc = p.bbl_cmd_credits_label or "Credits", special = "bbl_cmd", exclusive = true },
      { name = "$HDDCHECKER", desc = p.bbl_cmd_hddchecker_label or "Check HDD", special = "bbl_cmd", exclusive = true },
    }
    if not hideRuntimeHddDevices(ctx) then
      cmdRows[#cmdRows + 1] = {
        name = "hdd0:__system:pfs:/p2lboot/osdboot.elf",
        desc = (_.dev_str and _.dev_str.ps2_linux_ntsc) or "PS2 Linux NTSC",
        special = "bbl_cmd",
        args = { "--kernel", "pfs0:/p2lboot/ps2-linux-ntsc" },
        defaultName = true,
      }
      cmdRows[#cmdRows + 1] = {
        name = "hdd0:__system:pfs:/p2lboot/osdboot.elf",
        desc = (_.dev_str and _.dev_str.ps2_linux_vga) or "PS2 Linux VGA",
        special = "bbl_cmd",
        args = { "--kernel", "pfs0:/p2lboot/ps2-linux-vga" },
        defaultName = true,
      }
    end
  end
  for i = 1, #cmdRows do
    table.insert(ctx.pathList, cmdRows[i])
  end
end

local function isFreeBootFileContext(ctx)
  if not ctx then return false end
  return (ctx.fileType == "freemcboot_cnf") or (ctx.context == "freehddboot")
end

local function filterFreeBootChooseDeviceList(ctx)
  if not ctx or ctx.pathPickerSub ~= "device" or not ctx.pathList then return end
  if ctx.pathPickerFreeBootFilterAppliedTo == ctx.pathList then return end
  local isFreeBootChoose = isFreeBootFileContext(ctx) or
      (ctx.pathPickerContext == "fmcb_entry") or
      (ctx.pathPickerContext == "fmcb_launch")
  if not isFreeBootChoose then return end
  local out = {}
  for i = 1, #ctx.pathList do
    local e = ctx.pathList[i]
    local keep = false
    if e and e.special then
      -- Keep command rows (OSDSYS/OSDMENU/FASTBOOT/POWEROFF and other special entries).
      keep = true
    else
      local name = tostring(e and e.name or ""):lower()
      local deviceId = tostring(e and e.deviceId or ""):lower()
      -- Free*BOOT choose-device supports MC, USB, and APA HDD.
      if name == "mc0:" or name == "mc1:" or name == "hdd0:" then
        keep = true
      elseif deviceId == "usb0" or deviceId == "usb1" then
        keep = true
      end
    end
    if keep then out[#out + 1] = e end
  end
  ctx.pathList = out
  ctx.pathPickerFreeBootFilterAppliedTo = ctx.pathList
  local count = #out
  if count <= 0 then
    ctx.pathPickerSel = 1
    ctx.pathPickerScroll = 0
  else
    if (ctx.pathPickerSel or 1) > count then ctx.pathPickerSel = count end
    if (ctx.pathPickerSel or 1) < 1 then ctx.pathPickerSel = 1 end
  end
end

local function centeredScroll(sel, total, maxVis)
  if total <= maxVis then return 0 end
  local s = sel - math.floor(maxVis / 2)
  return math.max(0, math.min(s, total - maxVis))
end

local function getSelectedBblName(ctx)
  local ft = ctx and ctx.fileType or nil
  if ft == "freemcboot_cnf" then return "FreeMCBoot" end
  if ft == "psxbbl_ini" then return "PSXBBL" end
  if ft == "ps2bbl_ini" then return "PS2BBL" end
  local c = ctx and ctx.context or nil
  if c == "freemcboot" then return "FreeMCBoot" end
  if c == "psxbbl" then return "PSXBBL" end
  return "PS2BBL"
end

local function normalizeBdmPrefixForPathPickerContext(ctx, prefix)
  if type(prefix) ~= "string" or prefix == "" then return prefix end
  if not ctx then return prefix end
  local pickerContext = ctx.pathPickerContext
  if pickerContext ~= "path_only" and pickerContext ~= "config_ini" then return prefix end
  local ft = tostring(ctx.fileType or "")
  if ft ~= "ps2bbl_ini" and ft ~= "psxbbl_ini" then return prefix end
  if prefix == "mass" or prefix:match("^mass%d+$") then return "usb" end
  if prefix == "massX" then return "mx4sio" end
  return prefix
end

local function setBdmBrowseState(ctx, e, mp)
  local _ = ctx._
  local mpNorm = (mp:sub(-1) == ":") and mp or (mp .. ":")
  local savePrefix = normalizeBdmPrefixForPathPickerContext(ctx,
    _.file_selector.getBdmPathPrefix(e.deviceId, ctx.pathPickerContext, ctx.fileType))
  local browsePrefix = e.bdmBrowsePrefix
  if (not browsePrefix or browsePrefix == "") and _.file_selector.getBdmBrowsePrefix then
    browsePrefix = _.file_selector.getBdmBrowsePrefix(e.deviceId)
  end
  browsePrefix = browsePrefix or savePrefix or e.deviceId
  ctx.pathPickerBdmMountpoint = mpNorm
  ctx.pathPickerBdmBrowseRoot = normalizeBdmRoot(browsePrefix)
  ctx.pathPickerBdmPrefix = savePrefix or browsePrefix
  ctx.pathBrowsePath = bdmPathFromRoot(ctx.pathPickerBdmBrowseRoot, "")
  return ctx.pathBrowsePath
end

local function beginBrowseForDevice(ctx, e)
  if not e then return end
  local _ = ctx._
  ctx.pathPickerFreeBootFilterAppliedTo = nil
  if e.deviceType == "hdd" and not e.deviceId then
    local hddNum = tonumber(e.hddNum)
    if hddNum == nil then
      hddNum = tonumber(tostring(e.name or ""):match("^hdd(%d):")) or 0
    end
    local hddRoot = "hdd" .. tostring(hddNum) .. ":"
    ctx.pathPickerDeviceSel = ctx.pathPickerSel
    ctx.pathPickerLoadedDeviceTypes = ctx.pathPickerLoadedDeviceTypes or {}
    if ctx.pathPickerLoadedDeviceTypes["hdd"] then
      if System and System.loadModules then System.loadModules("hdd") end
      local hddOk = false
      if System and System.listDirectory then
        local ok, list = pcall(function() return System.listDirectory(hddRoot) end)
        hddOk = ok and type(list) == "table"
      end
      if hddOk then
        ctx.pathPickerSub = "partitions"
        ctx.pathList = _.file_selector.getHddPartitions(hddNum) or {}
        ctx.pathBrowsePath = hddRoot
        ctx.pathPickerSel = 1
        ctx.pathPickerScroll = 0
      else
        ctx.pathPickerLoading = { deviceType = "hdd", staticHdd = true, hddNum = hddNum, hddRoot = hddRoot }
        ctx.pathPickerLoadingFrames = 0
      end
    else
      ctx.pathPickerLoading = { deviceType = "hdd", staticHdd = true, hddNum = hddNum, hddRoot = hddRoot }
      ctx.pathPickerLoadingFrames = 0
    end
  elseif e.deviceId and e.deviceType then
    ctx.pathPickerDeviceSel = ctx.pathPickerSel
    ctx.pathPickerLoadedDeviceTypes = ctx.pathPickerLoadedDeviceTypes or {}
    if e.deviceType == "mx4sio" and ctx.pathPickerLoadedDeviceTypes["mmce"] then clearLoadedIfIopReset(ctx) end
    if ctx.pathPickerLoadedDeviceTypes[e.deviceType] then
      if System and System.loadModules then System.loadModules(e.deviceType) end
      local mp = (System and System.getDeviceMountpoint) and System.getDeviceMountpoint(e.deviceId) or nil
      if mp and mp ~= "" then
        setBdmBrowseState(ctx, e, mp)
        ctx.pathList = listBrowseEntries(ctx, ctx.pathBrowsePath)
        ctx.pathPickerSub = "browse"
        ctx.pathPickerSel = 1
        ctx.pathPickerScroll = 0
      else
        ctx.pathPickerLoading = { deviceId = e.deviceId, deviceType = e.deviceType }
        ctx.pathPickerLoadingFrames = 0
      end
    else
      ctx.pathPickerLoading = { deviceId = e.deviceId, deviceType = e.deviceType }
      ctx.pathPickerLoadingFrames = 0
    end
  else
    ctx.pathPickerDeviceSel = ctx.pathPickerSel
    -- Static device (mc, mmce) without deviceId: use name as path. Load MMCE module when selecting mmce.
    ctx.pathPickerLoadedDeviceTypes = ctx.pathPickerLoadedDeviceTypes or {}
    if e.deviceType == "mmce" and ctx.pathPickerLoadedDeviceTypes["mx4sio"] then clearLoadedIfIopReset(ctx) end
    resetIopForMc1AfterSlotDriver(ctx, e)
    if e.deviceType and System and System.loadModules then System.loadModules(e.deviceType) end
    local browsePath = e.name or ""
    if browsePath and browsePath ~= "" and browsePath:find(":") then
      ctx.pathBrowsePath = (browsePath:sub(-1) == ":") and (browsePath .. "/") or browsePath
      ctx.pathList = listBrowseEntries(ctx, ctx.pathBrowsePath)
    else
      ctx.pathBrowsePath = nil
      ctx.pathList = {}
    end
    ctx.pathPickerSub = "browse"
    ctx.pathPickerSel = 1
    if e.deviceType then ctx.pathPickerLoadedDeviceTypes[e.deviceType] = true end
  end
end

local function run(ctx)
  local _ = ctx._
  -- Wildcard confirm: path is mc0/mc1/mmce0/mmce1; Cross = Yes (use wildcard), Circle = No (use as-is)
  if ctx.pathPickerWildcardConfirm and ctx.pathPickerPendingPath then
    local val = ctx.pathPickerPendingPath
    local mode = ctx.pathPickerWildcardMode or "single"
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1, _.path_str.wildcard_confirm_title, _.WHITE)
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y + _.scaleY(28), _.FONT_SCALE, val, _.UNSELECTED_COLOR)
    _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, _.path_str.wildcard_confirm_hint, nil, _.DIM_COLOR,
      _.w - 2 * _.MARGIN_X)
    local function applyAndExit(chosenVal)
      if mode ~= "config_open" then
        ctx._configModifiedCache = nil
        ctx.configModified = true
      end
      if mode == "config_open" then
        applyConfigOpenPathAndReturn(ctx, chosenVal)
      elseif mode == "single" then
        _.config_parse.set(ctx.lines, ctx.editKey, chosenVal)
        ctx.state = "editor"
      elseif mode == "bbl_hotkey" then
        applyBblHotkeyPathAndReturn(ctx, chosenVal)
      elseif mode == "bbl_irx" then
        applyBblIrxPathAndReturn(ctx, chosenVal)
      elseif mode == "entry" then
        applyMenuEntryPathAndReturn(ctx, chosenVal)
      elseif mode == "add" then
        local key = (ctx.addPathKey == "path1_OSDSYS_ITEM_1") and _.resolveNextOsdItemKey(ctx.lines) or ctx.addPathKey
        _.config_parse.append(ctx.lines, key, chosenVal)
        ctx.state = "editor"
      elseif mode == "boot" then
        applyBootPathAndReturn(ctx, chosenVal)
      end
      ctx.pathPickerWildcardConfirm = nil
      ctx.pathPickerPendingPath = nil
      ctx.pathPickerWildcardMode = nil
      ctx.pathPickerBdmPrefix = nil
      ctx.pathPickerBdmBrowseRoot = nil
      ctx.pathPickerBdmMountpoint = nil
      if ctx.pfs0Mounted and System.fileXioUmount then System.fileXioUmount("pfs0:") end
      if ctx.pfs1Mounted and System.fileXioUmount then System.fileXioUmount("pfs1:") end
      ctx.pathList = nil
      ctx.pathBrowsePath = nil
      ctx.pfs0Mounted = nil
      ctx.pfs1Mounted = nil
    end
    if (_.padEffective & _.PAD_CROSS) ~= 0 then
      applyAndExit(_.file_selector.toWildcard(val))
    elseif (_.padEffective & _.PAD_CIRCLE) ~= 0 then
      applyAndExit(val)
    end
    return
  end
  if ctx.pathPickerSub == "device" then
    ensureBblCommandRows(ctx)
    filterFreeBootChooseDeviceList(ctx)
    if isConfigOpenTarget(ctx) and ctx.pathPickerLockedDevice and not ctx.pathPickerLockedDeviceStarted then
      ctx.pathPickerLockedDeviceStarted = true
      beginBrowseForDevice(ctx, ctx.pathPickerLockedDevice)
      if ctx.pathPickerSub ~= "device" then
        return
      end
    end
    -- Loading state: probe every ~200ms, 3s timeout; show splash only when waiting
    if ctx.pathPickerLoading then
      local load = ctx.pathPickerLoading
      local PROBE_INTERVAL_FRAMES = 12 -- ~200ms at 60fps
      local LOAD_TIMEOUT_FRAMES = 180  -- 3s at 60fps
      -- Draw splash first so it shows before any blocking loadModules()
      if not (ctx.pathPickerLoadingFrames and ctx.pathPickerLoadingFrames >= LOAD_TIMEOUT_FRAMES) then
        local msg = _.path_str.waiting_for_device_drivers
        local tw = _.common.calcTextWidth(_.font, msg, 1)
        local cx = _.common.centerX(_, tw)
        local cy = math.floor((_.MARGIN_Y + _.HINT_Y) / 2) - math.floor(_.LINE_H / 2)
        _.drawText(_.font, _.drawMode, cx, cy, 1, msg, _.WHITE)
      end
      _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7,
        _.path_str.circle_back_items, nil, _.DIM_COLOR, _.w - 2 * _.MARGIN_X)
      ctx.pathPickerLoadingFrames = (ctx.pathPickerLoadingFrames or 0) + 1
      -- Load drivers on frame 2 so the first splash frame is presented before blocking (same for all HDD/BDM)
      if ctx.pathPickerLoadingFrames == 2 and not ctx.pathPickerModulesLoaded and load.deviceType and System and System.loadModules then
        System.loadModules(load.deviceType)
        ctx.pathPickerModulesLoaded = true
      end
      local mp = nil
      if load.staticHdd then
        if ctx.pathPickerLoadingFrames > 0 and ctx.pathPickerLoadingFrames % PROBE_INTERVAL_FRAMES == 0 then
          local hddNum = tonumber(load.hddNum) or 0
          local hddRoot = tostring(load.hddRoot or ("hdd" .. tostring(hddNum) .. ":"))
          local ok = false
          if System and System.listDirectory then
            local listed, list = pcall(function() return System.listDirectory(hddRoot) end)
            ok = listed and type(list) == "table"
          end
          if ok then
            ctx.pathPickerLoading = nil
            ctx.pathPickerLoadingFrames = nil
            ctx.pathPickerModulesLoaded = nil
            ctx.pathPickerLoadedDeviceTypes = ctx.pathPickerLoadedDeviceTypes or {}
            ctx.pathPickerLoadedDeviceTypes["hdd"] = true
            ctx.pathPickerSub = "partitions"
            ctx.pathList = _.file_selector.getHddPartitions(hddNum) or {}
            ctx.pathBrowsePath = hddRoot
            ctx.pathPickerSel = 1
            ctx.pathPickerScroll = 0
          end
        end
      else
        if ctx.pathPickerLoadingFrames > 0 and ctx.pathPickerLoadingFrames % PROBE_INTERVAL_FRAMES == 0 then
          mp = (System and System.getDeviceMountpoint) and System.getDeviceMountpoint(load.deviceId) or nil
        end
        if mp and mp ~= "" then
          ctx.pathPickerLoading = nil
          ctx.pathPickerLoadingFrames = nil
          ctx.pathPickerModulesLoaded = nil
          ctx.pathPickerLoadedDeviceTypes = ctx.pathPickerLoadedDeviceTypes or {}
          ctx.pathPickerLoadedDeviceTypes[load.deviceType] = true
          local bdmEntry = {
            deviceId = load.deviceId,
            bdmBrowsePrefix = (_.file_selector.getBdmBrowsePrefix and _.file_selector.getBdmBrowsePrefix(load.deviceId)) or nil,
          }
          setBdmBrowseState(ctx, bdmEntry, mp)
          ctx.pathList = listBrowseEntries(ctx, ctx.pathBrowsePath)
          ctx.pathPickerSub = "browse"
          ctx.pathPickerSel = 1
          ctx.pathPickerScroll = 0
        end
      end
      if ctx.pathPickerLoading and ctx.pathPickerLoadingFrames >= LOAD_TIMEOUT_FRAMES then
        local timeoutDevice = load.deviceId or (load.staticHdd and (load.hddRoot or "hdd0:")) or load.deviceType or "device"
        ctx.pathPickerLoading = nil
        ctx.pathPickerLoadingFrames = nil
        ctx.pathPickerModulesLoaded = nil
        ctx.pathPickerLoadingTimeoutMsg = tostring(timeoutDevice)
      end
    else
      if ctx.pathPickerLoadingTimeoutMsg then
        local timeoutDevice = tostring(ctx.pathPickerLoadingTimeoutMsg)
        local msg = _.path_str.device_timeout
        if type(msg) == "string" and msg:find("%%DEVICE%%") then
          msg = msg:gsub("%%DEVICE%%", function() return timeoutDevice end)
        else
          msg = timeoutDevice .. " not found"
        end
        local tw = _.common.calcTextWidth(_.font, msg, _.FONT_SCALE)
        local cx = _.common.centerX(_, tw)
        local cy = math.floor((_.MARGIN_Y + _.HINT_Y) / 2) - math.floor(_.LINE_H / 2)
        _.drawText(_.font, _.drawMode, cx, cy, _.FONT_SCALE, msg, _.DIM_COLOR)
      end
    end
    if not ctx.pathPickerLoadingTimeoutMsg and not ctx.pathPickerLoading then
      _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1,
        ctx.isAddPath and _.path_str.add_path_choose_device or _.path_str.choose_device, _.WHITE)
      if (ctx.pathPickerContext == "path_only" or ctx.pathPickerContext == "config_ini") and
          (not isFreeBootFileContext(ctx)) and _.path_str.bbl_build_device_hint then
        local hint = _.path_str.bbl_build_device_hint
        hint = hint:gsub("PS%?BBL", getSelectedBblName(ctx))
        if _.common.truncateTextToWidth then
          hint = _.common.truncateTextToWidth(_.font, hint, _.w - (_.MARGIN_X * 2), 0.55)
        end
        _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y + _.scaleY(20), 0.55, hint, _.DIM_COLOR)
      end
      if ctx.pathList and #ctx.pathList > 0 and not ctx.pathPickerLoading then
        local lockedConfigBrowse = isConfigOpenTarget(ctx) and ctx.pathPickerLockedDevice
        local includeManualEntry = not lockedConfigBrowse
        local manualOffset = includeManualEntry and 1 or 0
        local rawCount = #ctx.pathList + manualOffset
        local function deviceFromRawIndex(rawIdx)
          local devIdx = rawIdx - manualOffset
          if devIdx < 1 or devIdx > #ctx.pathList then return nil end
          return ctx.pathList[devIdx]
        end
        local otherStats = getOtherTargetPathStats(ctx)
        local targetIndex = tonumber(otherStats.targetIndex)
        local fmcbSingleUseTaken = buildFmcbSingleUseTakenMap(ctx, targetIndex)
        local function isGreyed(e)
          if not e then return true end
          if hasFmcbSingleUseDuplicateInTarget(ctx, e.name, targetIndex, fmcbSingleUseTaken) then
            return true
          end
          if targetIndex and targetIndex ~= 1 and isE1RestrictedPathForContext(ctx, e.name) then
            return true
          end
          if isPathExclusiveInContext(ctx, e.name, { exclusive = e.exclusive }) then return otherStats.count > 0 end
          if otherStats.firstExclusive then return true end
          return false
        end
        local rawGreyed = {}
        local function isSelectableRaw(rawIdx)
          if includeManualEntry and rawIdx == 1 then return true end
          local e = deviceFromRawIndex(rawIdx)
          local grey = (e == nil) or isGreyed(e)
          rawGreyed[rawIdx] = grey
          return (e ~= nil) and not grey
        end
        local selectableRaw = {}
        local inactiveRaw = {}
        for rawIdx = 1, rawCount do
          if isSelectableRaw(rawIdx) then
            selectableRaw[#selectableRaw + 1] = rawIdx
          else
            inactiveRaw[#inactiveRaw + 1] = rawIdx
          end
        end
        local displayRows = {}
        for i = 1, #selectableRaw do
          displayRows[#displayRows + 1] = { kind = "entry", rawIdx = selectableRaw[i], selectable = true }
        end
        local showInactiveDivider = (#inactiveRaw > 0)
        if showInactiveDivider then
          local dividerText = (_.path_str and _.path_str.inactive_items_separator) or
              "-- Items below are already used or must be E1 --"
          displayRows[#displayRows + 1] = { kind = "separator", selectable = false, text = dividerText }
        end
        for i = 1, #inactiveRaw do
          displayRows[#displayRows + 1] = { kind = "entry", rawIdx = inactiveRaw[i], selectable = false }
        end
        local totalCount = #displayRows
        if ctx.pathPickerSel < 1 then ctx.pathPickerSel = 1 end
        if ctx.pathPickerSel > totalCount then ctx.pathPickerSel = totalCount end
        local function rawIndexFromDisplay(displayIdx)
          local row = displayRows[displayIdx]
          if not row or row.kind ~= "entry" then return nil end
          return row.rawIdx
        end
        local function isSelectableDisplay(displayIdx)
          local row = displayRows[displayIdx]
          return row and row.selectable == true
        end
        if not isSelectableDisplay(ctx.pathPickerSel) then
          local found = nil
          for idx = 1, totalCount do
            if isSelectableDisplay(idx) then
              found = idx
              break
            end
          end
          if not found then
            for idx = 1, totalCount do
              if rawIndexFromDisplay(idx) then
                found = idx
                break
              end
            end
          end
          ctx.pathPickerSel = found or 1
        end
        local maxVis = _.MAX_VISIBLE_LIST
        if totalCount > maxVis then
          ctx.pathPickerScroll = ctx.pathPickerSel - math.floor(maxVis / 2)
          ctx.pathPickerScroll = math.max(0, math.min(ctx.pathPickerScroll, totalCount - maxVis))
        else
          ctx.pathPickerScroll = 0
        end
        local startY = _.MARGIN_Y + _.scaleY(50)
        if _.common and _.common.drawListScrollbar then
          _.common.drawListScrollbar(_, {
            totalRows = totalCount,
            visibleRows = maxVis,
            scrollRows = ctx.pathPickerScroll,
            rowTopY = startY,
            rowHeight = _.LINE_H,
            color = _.DIM_COLOR,
          })
        end
        local maxLabelW = (_.w or 640) - (_.MARGIN_X + 20) - _.MARGIN_X
        for i = 1, math.min(maxVis, totalCount - ctx.pathPickerScroll) do
          local displayIdx = ctx.pathPickerScroll + i
          local row = displayRows[displayIdx] or {}
          local listIdx = rawIndexFromDisplay(displayIdx)
          local displayName
          local greyed = false
          local e = nil
          if row.kind == "separator" then
            displayName = row.text or "-- Items below are already used or must be E1 --"
          else
            if includeManualEntry and listIdx == 1 then
              displayName = _.path_str.enter_path_manually
            else
              e = deviceFromRawIndex(listIdx)
              if e and e.special == "bbl_cmd" and ctx.fileType == "freemcboot_cnf" then
                displayName = e.name or e.desc or _.common_str.empty
              else
                displayName = e and (e.desc or e.name or _.common_str.empty) or _.common_str.empty
              end
              greyed = (rawGreyed[listIdx] == true)
            end
          end
          local y = startY + (i - 1) * _.LINE_H
          local isSelectedEntryRow = (row.kind == "entry") and isSelectableDisplay(displayIdx) and
              (displayIdx == ctx.pathPickerSel)
          local col = _.DIM_COLOR
          if row.kind ~= "separator" then
            col = greyed and _.DIM_COLOR or (isSelectedEntryRow and _.SELECTED_COLOR or _.UNSELECTED_COLOR)
          end
          if _.common.fitListRowText then
            local rowStateKey = (row.kind == "separator") and "path_picker_device_sep" or
                ("path_picker_device_row_" .. tostring(listIdx))
            displayName = _.common.fitListRowText(ctx, rowStateKey, _.font, displayName,
              maxLabelW, _.FONT_SCALE, isSelectedEntryRow)
          elseif _.common.truncateTextToWidth then
            displayName = _.common.truncateTextToWidth(_.font, displayName or "", maxLabelW, _.FONT_SCALE)
          end
          _.drawListRow(_.MARGIN_X + 20, y, isSelectedEntryRow, displayName, col)
        end
        do
          local function getFmcbCommandHelper(entry)
            if not entry then return nil end
            local isFmcbPicker = (ctx.pathPickerContext == "fmcb_entry" or ctx.pathPickerContext == "fmcb_launch")
            local isFmcbPathOnly = (ctx.pathPickerContext == "path_only") and
                ((ctx.fileType == "freemcboot_cnf") or (ctx.context == "freehddboot"))
            if not (isFmcbPicker or isFmcbPathOnly) then return nil end
            local key = tostring(entry.name or ""):upper()
            local p = _.path_str or {}
            if key == "OSDSYS" then
              return p.fmcb_cmd_osdsys or "Boot hacked OSDSYS"
            elseif key == "OSDMENU" then
              return p.fmcb_cmd_osdmenu or "Boot hacked OSDSYS, enforce skip disc boot"
            elseif key == "FASTBOOT" then
              return p.fmcb_cmd_fastboot or "Boot PS2 Disc without logo"
            elseif key == "POWEROFF" then
              return p.fmcb_cmd_poweroff or "Shutdown the console: FMCB 1.966 only, else use POWEROFF.ELF"
            end
            return nil
          end

          local selectedHelper = nil
          local selectedRawIdx = rawIndexFromDisplay(ctx.pathPickerSel)
          if not (includeManualEntry and selectedRawIdx == 1) then
            local selectedEntry = selectedRawIdx and deviceFromRawIndex(selectedRawIdx) or nil
            selectedHelper = (selectedEntry and selectedEntry.helper) or getFmcbCommandHelper(selectedEntry)
          end
          if selectedHelper and selectedHelper ~= "" then
            local hintTypography = _.common.getHintTypography(_.font, _.drawMode)
            local hintDrawScale = hintTypography.drawScale
            local hintFont = hintTypography.font
            local hintTextH = hintTypography.textHeight
            local descMaxW = (_.w or 640) - (_.MARGIN_X * 2)
            local helperRawW = (_.common.calcTextWidth and _.common.calcTextWidth(hintFont, selectedHelper, hintDrawScale)) or
                (#tostring(selectedHelper or "") * 8)
            local useTicker = helperRawW > descMaxW
            if useTicker then
              if _.common.fitListRowText then
                selectedHelper = _.common.fitListRowText(ctx, "path_picker_device_helper", hintFont, selectedHelper,
                  descMaxW, hintDrawScale, true, { holdStart = 55, stepFrames = 16, holdEnd = 85 })
              elseif _.common.truncateTextToWidth then
                selectedHelper = _.common.truncateTextToWidth(hintFont, selectedHelper, descMaxW, hintDrawScale)
              end
            end
            local tw = (_.common.calcTextWidth and _.common.calcTextWidth(hintFont, selectedHelper, hintDrawScale)) or
                (#tostring(selectedHelper or "") * 8)
            local x
            if useTicker then
              x = _.MARGIN_X
            else
              local startCenterX = _.common.getHintStartCenterX and
                  _.common.getHintStartCenterX(_, (_.w or 640) - (2 * _.MARGIN_X))
              x = startCenterX and math.floor(startCenterX - (tw / 2) + 0.5) or _.common.centerX(_, tw)
            end
            local hintColor = (_.UNSELECTED_COLOR or _.DIM_COLOR)
            _.drawText(hintFont, _.drawMode, x, _.DESC_Y_BOTTOM, hintDrawScale, selectedHelper, hintColor, hintTextH)
          end
        end
        if (_.padEffective & _.PAD_UP) ~= 0 then
          local idx = ctx.pathPickerSel
          for _i = 1, totalCount do
            idx = _.common.moveListSelection(idx, totalCount, -1, { ctx = ctx })
            if isSelectableDisplay(idx) then
              ctx.pathPickerSel = idx; break
            end
          end
        end
        if (_.padEffective & _.PAD_DOWN) ~= 0 then
          local idx = ctx.pathPickerSel
          for _i = 1, totalCount do
            idx = _.common.moveListSelection(idx, totalCount, 1, { ctx = ctx })
            if isSelectableDisplay(idx) then
              ctx.pathPickerSel = idx; break
            end
          end
        end
        if (_.padEffective & _.PAD_CROSS) ~= 0 then
          local selectedRawIdx = rawIndexFromDisplay(ctx.pathPickerSel)
          if includeManualEntry and selectedRawIdx == 1 then
            local prefill = getManualPathPrefillValue(ctx)
            local prompt = _.path_str.enter_path_prompt
            local initialValue = prefill
            _.common.configureBelTextInput(ctx, {
              allow = false,
              hidePipeBackslash = true,
            })
            local onSubmit = function(val)
              applyManualPath(ctx, val)
            end
            _.common.beginTextInput(ctx, {
              titleIdMode = nil,
              prompt = prompt,
              value = initialValue,
              maxLen = 79,
              callback = onSubmit,
              returnState = "path_picker",
              gridSel = 1,
              cursor = #initialValue + 1,
              scroll = 1,
              state = "text_input",
            })
          else
            if not isSelectableDisplay(ctx.pathPickerSel) then
              -- Unselectable helper/inactive rows ignore Cross.
            else
              local e = selectedRawIdx and deviceFromRawIndex(selectedRawIdx) or nil
              if isGreyed(e) then
              showExclusivePathWarning(ctx, e and e.name)
              elseif e.special then
                local pathVal = e.name or ""
                if canUsePathSelection(ctx, pathVal, fmcbSingleUseTaken) then
                  if ctx.pfs0Mounted and System.fileXioUmount then System.fileXioUmount("pfs0:") end
                  if ctx.pfs1Mounted and System.fileXioUmount then System.fileXioUmount("pfs1:") end
                  ctx.pathList = nil
                  ctx.pfs0Mounted = nil
                  ctx.pfs1Mounted = nil
                  if ctx.pathPickerBootKey and ctx.lines then
                    local bootKey = ctx.pathPickerBootKey
                    if applyBootPathAndReturn(ctx, pathVal) then
                      if e.noargs then
                        _.config_parse.setBootArgs(ctx.lines, bootKey, {})
                      elseif type(e.args) == "table" then
                        _.config_parse.setBootArgs(ctx.lines, bootKey, e.args)
                      end
                      if _.config_parse.applyOsdmbrBootAutoArgs then
                        _.config_parse.applyOsdmbrBootAutoArgs(ctx.lines, bootKey)
                      end
                    end
                  else
                    local defaultName = defaultNameFromPickerEntry(e)
                    local bblKey = ctx.pathPickerBblHotkeyKey
                    local bblSlot = tonumber(ctx.pathPickerBblHotkeySlot)
                    if applyBblHotkeyPathAndReturn(ctx, pathVal) then
                      if e.noargs and _.config_parse.setBblHotkeyArgs and bblKey and bblSlot then
                        _.config_parse.setBblHotkeyArgs(ctx.lines, bblKey, bblSlot, {})
                      elseif type(e.args) == "table" and _.config_parse.setBblHotkeyArgs and bblKey and bblSlot then
                        _.config_parse.setBblHotkeyArgs(ctx.lines, bblKey, bblSlot, e.args)
                      end
                      if defaultName and _.config_parse.getBblHotkeyName and _.config_parse.setBblHotkeyName and bblKey then
                        local currentName = _.config_parse.getBblHotkeyName(ctx.lines, bblKey) or ""
                        if trimmedText(currentName) == "" then
                          _.config_parse.setBblHotkeyName(ctx.lines, bblKey, defaultName)
                        end
                      end
                    elseif applyBblIrxPathAndReturn(ctx, pathVal) then
                    elseif applyMenuEntryPathAndReturn(ctx, pathVal, { noargs = e.noargs, args = e.args, defaultName = defaultName }) then
                    elseif ctx.isAddPath then
                      local key = (ctx.addPathKey == "path1_OSDSYS_ITEM_1") and _.resolveNextOsdItemKey(ctx.lines) or
                          ctx.addPathKey
                      _.config_parse.append(ctx.lines, key, pathVal)
                      ctx.state = "editor"
                    else
                      _.config_parse.set(ctx.lines, ctx.editKey or "", pathVal)
                      ctx.state = "editor"
                    end
                  end
                  ctx._configModifiedCache = nil
                  ctx.configModified = true
                end
              else
                beginBrowseForDevice(ctx, e)
              end
            end
          end
        end
      else
        _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y + _.scaleY(60), _.FONT_SCALE, _.path_str.no_devices, _
          .UNSELECTED_COLOR)
      end
    end
    if ctx.pathPickerLoading then
    elseif ctx.pathPickerLoadingTimeoutMsg then
      _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, _.path_str.circle_back_items, nil, _.DIM_COLOR,
        _.w - 2 * _.MARGIN_X)
    else
      _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, _.path_str.cross_select_circle_back_items, nil,
        _.DIM_COLOR, _.w - 2 * _.MARGIN_X)
    end
    if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
      if isConfigOpenTarget(ctx) and ctx.pathPickerLockedDevice then
        leaveLockedConfigBrowse(ctx)
        return
      end
      if ctx.pathPickerLoading or ctx.pathPickerLoadingTimeoutMsg then
        ctx.pathPickerLoading = nil
        ctx.pathPickerLoadingFrames = nil
        ctx.pathPickerModulesLoaded = nil
        ctx.pathPickerLoadingTimeoutMsg = nil
        ctx.pathList = getPickerDevices(ctx, _)
      else
        if ctx.pfs0Mounted and System.fileXioUmount then System.fileXioUmount("pfs0:") end
        if ctx.pfs1Mounted and System.fileXioUmount then System.fileXioUmount("pfs1:") end
        if ctx.pathPickerBootKey then
          ctx.state = ctx.pathPickerReturnState or "editor"
          ctx.pathPickerBootKey = nil; ctx.pathPickerBootKeyDisabled = nil; ctx.pathPickerReturnState = nil
        elseif ctx.pathPickerBblHotkeyKey then
          ctx.state = ctx.pathPickerReturnState or "bbl_hotkey_entry"
          ctx.pathPickerBblHotkeyKey = nil
          ctx.pathPickerBblHotkeySlot = nil
          ctx.pathPickerBblHotkeyDisabled = nil
          ctx.pathPickerReturnState = nil
        elseif ctx.pathPickerBblIrxIdx then
          ctx.state = ctx.pathPickerReturnState or "bbl_irx_entries"
          ctx.pathPickerBblIrxIdx = nil
          ctx.pathPickerBblIrxDisabled = nil
          ctx.pathPickerReturnState = nil
          ctx.pathPickerFileExts = nil
        elseif ctx.pathPickerForEntryIdx then
          ctx.entryIdx = ctx.pathPickerForEntryIdx
          ctx.state = ctx.pathPickerReturnState or (ctx.pathPickerEditIdx and "entry_paths") or "menu_entry_edit"
          ctx.pathPickerForEntryIdx = nil; ctx.pathPickerEditIdx = nil
          ctx.pathPickerReturnState = nil
        elseif isConfigOpenTarget(ctx) then
          ctx.state = ctx.pathPickerReturnState or "select_config"
          ctx.pathPickerReturnState = nil
          clearConfigOpenPickerState(ctx)
        else
          ctx.state = "editor"
        end
        ctx.pathList = nil; ctx.pathBrowsePath = nil; ctx.pathPickerBdmPrefix = nil; ctx.pathPickerBdmBrowseRoot = nil; ctx.pathPickerBdmMountpoint = nil
        ctx.pfs0Mounted = nil; ctx.pfs1Mounted = nil
      end
    end
  elseif ctx.pathPickerSub == "partitions" then
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1, _.path_str.select_hdd_partition, _.WHITE)
    local parts = ctx.pathList or {}
    if ctx.pathPickerSel < 1 then ctx.pathPickerSel = 1 end
    if ctx.pathPickerSel > #parts then ctx.pathPickerSel = #parts end
    local maxVis = _.MAX_VISIBLE_LIST
    local startY = _.MARGIN_Y + _.scaleY(50)
    if #parts > maxVis then
      ctx.pathPickerScroll = ctx.pathPickerSel - math.floor(maxVis / 2)
      ctx.pathPickerScroll = math.max(0, math.min(ctx.pathPickerScroll, #parts - maxVis))
    else
      ctx.pathPickerScroll = 0
    end
    if _.common and _.common.drawListScrollbar then
      _.common.drawListScrollbar(_, {
        totalRows = #parts,
        visibleRows = maxVis,
        scrollRows = ctx.pathPickerScroll,
        rowTopY = startY,
        rowHeight = _.LINE_H,
        color = _.DIM_COLOR,
      })
    end
    local maxLabelW = (_.w or 640) - (_.MARGIN_X + 20) - _.MARGIN_X
    for i = ctx.pathPickerScroll + 1, math.min(ctx.pathPickerScroll + maxVis, #parts) do
      local p = parts[i]
      if not p then break end
      local y = startY + (i - ctx.pathPickerScroll - 1) * _.LINE_H
      local col = (i == ctx.pathPickerSel) and _.SELECTED_COLOR or _.UNSELECTED_COLOR
      local label = p.name or _.common_str.empty
      if _.common.fitListRowText then
        label = _.common.fitListRowText(ctx, "path_picker_part_row_" .. tostring(i), _.font, label, maxLabelW,
          _.FONT_SCALE, i == ctx.pathPickerSel)
      elseif _.common.truncateTextToWidth then
        label = _.common.truncateTextToWidth(_.font, label, maxLabelW, _.FONT_SCALE)
      end
      _.drawListRow(_.MARGIN_X + 20, y, i == ctx.pathPickerSel, label, col)
    end
    if #parts == 0 then
      _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y + _.scaleY(60), _.FONT_SCALE, _.path_str.no_partitions, _
        .DIM_COLOR)
    end
    local hasFileFilter = type(ctx.pathPickerFileExts) == "table" and #ctx.pathPickerFileExts > 0
    local allowPatinfo = (not isConfigOpenTarget(ctx)) and (not hasFileFilter)
    local partHint = isConfigOpenTarget(ctx) and _.path_str.cross_open_circle_back_items or
        (allowPatinfo and (_.path_str.cross_open_square_patinfo_circle_back_items or _.path_str.cross_open_circle_back_items) or
          _.path_str.cross_open_circle_back_items)
    _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, partHint, nil, _.DIM_COLOR, _.w - 2 * _.MARGIN_X)
    if (_.padEffective & _.PAD_UP) ~= 0 then
      ctx.pathPickerSel = _.common.moveListSelection(ctx.pathPickerSel, #parts, -1, { ctx = ctx })
    end
    if (_.padEffective & _.PAD_DOWN) ~= 0 then
      ctx.pathPickerSel = _.common.moveListSelection(ctx.pathPickerSel, #parts, 1, { ctx = ctx })
    end
    if (_.padEffective & _.PAD_LEFT) ~= 0 then
      ctx.pathPickerSel = math.max(1, ctx.pathPickerSel - maxVis)
    end
    if (_.padEffective & _.PAD_RIGHT) ~= 0 then
      ctx.pathPickerSel = math.min(#parts, ctx.pathPickerSel + maxVis)
    end
    if allowPatinfo and (_.padEffective & _.PAD_SQUARE) ~= 0 and #parts > 0 then
      local p = parts[ctx.pathPickerSel]
      if not p then p = {} end
      local hddRoot = tostring(ctx.pathBrowsePath or "hdd0:")
      if not hddRoot:match("^hdd%d:") then hddRoot = "hdd0:" end
      local partFull = p.full or (hddRoot .. (p.name or ""))
      local val = partFull .. ":PATINFO"
      if not canUsePathSelection(ctx, val) then
        return
      end
      if applyBootPathAndReturn(ctx, val) then
      elseif applyBblHotkeyPathAndReturn(ctx, val) then
      elseif applyBblIrxPathAndReturn(ctx, val) then
      elseif applyMenuEntryPathAndReturn(ctx, val) then
      elseif ctx.isAddPath then
        local key = (ctx.addPathKey == "path1_OSDSYS_ITEM_1") and _.resolveNextOsdItemKey(ctx.lines) or ctx.addPathKey
        _.config_parse.append(ctx.lines, key, val)
        ctx.state = "editor"
      else
        _.config_parse.set(ctx.lines, ctx.editKey, val); ctx.state = "editor"
      end
      ctx._configModifiedCache = nil
      ctx.configModified = true
      ctx.pathList = nil; ctx.pathBrowsePath = nil; ctx.pathPickerBdmPrefix = nil; ctx.pathPickerBdmBrowseRoot = nil; ctx.pathPickerBdmMountpoint = nil
      ctx.pathPickerSub = "device"
    end
    if (_.padEffective & _.PAD_CROSS) ~= 0 and #parts > 0 then
      local p = parts[ctx.pathPickerSel]
      if not p then p = {} end
      ctx.pathPickerPartitionSel = ctx.pathPickerSel
      local partName = p.name or ""
      local hddRoot = tostring(ctx.pathBrowsePath or "hdd0:")
      if not hddRoot:match("^hdd%d:") then hddRoot = "hdd0:" end
      local partFull = p.full or (hddRoot .. partName)
      if partName == "__sysconf" then
        if System.fileXioMount then System.fileXioMount("pfs0:", partFull) end
        ctx.pfs0Mounted = partFull
        ctx.pathBrowsePath = "pfs0:/"
        ctx.pathList = listBrowseEntries(ctx, "pfs0:/")
        ctx.pathPickerSub = "browse"
        ctx.pathPickerSel = 1; ctx.pathPickerScroll = 0
      else
        if System.fileXioMount then System.fileXioMount("pfs1:", partFull) end
        ctx.pfs1Mounted = partFull
        ctx.pathBrowsePath = "pfs1:/"
        local ok, list = pcall(listBrowseEntries, ctx, "pfs1:/")
        ctx.pathList = (ok and list) and list or {}
        ctx.pathPickerSub = "browse"
        ctx.pathPickerSel = 1; ctx.pathPickerScroll = 0
      end
    end
    if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
      if isConfigOpenTarget(ctx) and ctx.pathPickerLockedDevice then
        leaveLockedConfigBrowse(ctx)
        return
      end
      ctx.pathPickerSub = "device"
      ctx.pathList = getPickerDevices(ctx, _)
      ctx.pathBrowsePath = nil
      local n = #(ctx.pathList or {})
      ctx.pathPickerSel = math.max(1, math.min(ctx.pathPickerDeviceSel or 1, n))
      ctx.pathPickerScroll = centeredScroll(ctx.pathPickerSel, n, _.MAX_VISIBLE_LIST)
    end
  else
    local headerPath = ctx.pathBrowsePath or ""
    local partPath = ctx.pfs1Mounted or ctx.pfs0Mounted
    if partPath then
      local display = pfsToPartitionPath(headerPath, partPath)
      if display then headerPath = display end
    end
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 0.9, headerPath, _.DIM_COLOR)
    local show = ctx.pathList or {}
    if #show == 0 then
      ctx.pathPickerSel = 0
    else
      ctx.pathPickerSel = math.max(1, math.min(ctx.pathPickerSel, #show))
    end
    local maxVis = _.MAX_VISIBLE_LIST
    local startY = _.MARGIN_Y + _.scaleY(50)
    if #show > maxVis and ctx.pathPickerSel > 0 then
      ctx.pathPickerScroll = ctx.pathPickerSel - math.floor(maxVis / 2)
      ctx.pathPickerScroll = math.max(0, math.min(ctx.pathPickerScroll, #show - maxVis))
    elseif #show <= maxVis then
      ctx.pathPickerScroll = 0
    end
    if _.common and _.common.drawListScrollbar then
      _.common.drawListScrollbar(_, {
        totalRows = #show,
        visibleRows = maxVis,
        scrollRows = ctx.pathPickerScroll,
        rowTopY = startY,
        rowHeight = _.LINE_H,
        color = _.DIM_COLOR,
      })
    end
    local maxLabelW = (_.w or 640) - (_.MARGIN_X + 20) - _.MARGIN_X
    for i = ctx.pathPickerScroll + 1, math.min(ctx.pathPickerScroll + maxVis, #show) do
      local e = show[i]
      if not e then break end
      local y = startY + (i - ctx.pathPickerScroll - 1) * _.LINE_H
      local label = e.name or _.common_str.empty
      if e.directory and label ~= "" then label = label .. "/" end
      local col = (i == ctx.pathPickerSel) and _.SELECTED_COLOR or _.UNSELECTED_COLOR
      if _.common.fitListRowText then
        label = _.common.fitListRowText(ctx, "path_picker_browse_row_" .. tostring(i), _.font, label, maxLabelW,
          _.FONT_SCALE, i == ctx.pathPickerSel)
      elseif _.common.truncateTextToWidth then
        label = _.common.truncateTextToWidth(_.font, label, maxLabelW, _.FONT_SCALE)
      end
      _.drawListRow(_.MARGIN_X + 20, y, i == ctx.pathPickerSel, label, col)
    end
    if #show == 0 then
      local noFilesLabel
      if hasIniFilter(ctx) then
        noFilesLabel = _.path_str.no_ini_files or "No INI files or folders"
      elseif hasIrxFilter(ctx) then
        noFilesLabel = _.path_str.no_irx_files or "No IRX files or folders"
      else
        noFilesLabel = _.path_str.no_elf_files
      end
      _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y + _.scaleY(55), _.FONT_SCALE, noFilesLabel, _.DIM_COLOR)
    end
    local canCreateConfigIni = isConfigOpenTarget(ctx) and ctx.pathBrowsePath
    if not canCreateConfigIni then
      ctx.pathBrowseActionsOpen = nil
      ctx.pathBrowseActionsSel = nil
      ctx.pathBrowseActionsScroll = nil
    end
    local createIniLabel = "Create CONFIG.INI"
    if canCreateConfigIni and type(_.path_str.cross_select_create_circle_back_items) == "table" then
      for i = 1, #_.path_str.cross_select_create_circle_back_items do
        local item = _.path_str.cross_select_create_circle_back_items[i]
        local pad = tostring(item and item.pad or ""):lower()
        if item and (pad == "square" or pad == "select") and item.label and item.label ~= "" then
          createIniLabel = tostring(item.label)
          break
        end
      end
    end
    local browseHint = {
      { pad = "cross", label = (_.path_str.cross_select_file_items and _.path_str.cross_select_file_items[1] and _.path_str.cross_select_file_items[1].label) or "Select", row = 1 },
      { pad = canCreateConfigIni and "square" or "", label = canCreateConfigIni and (_.menu_str.actions_label or "Actions") or "", row = 1 },
      { pad = "circle", label = (_.path_str.cross_select_file_items and _.path_str.cross_select_file_items[2] and _.path_str.cross_select_file_items[2].label) or "Back", row = 1 },
    }
    _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, browseHint, nil, _.DIM_COLOR, _.w - 2 * _.MARGIN_X)

    local function createConfigIniInBrowseDir()
      local dir = tostring(ctx.pathBrowsePath):gsub("/$", "")
      local val = dir .. "/CONFIG.INI"
      local partPath = ctx.pfs1Mounted or ctx.pfs0Mounted
      if partPath then
        val = pfsToPartitionPath(val, partPath) or val
      end
      if _.file_selector.canWildcard and _.file_selector.canWildcard(val) and isIndexedUsbPath(val) then
        ctx.pathPickerPendingPath = val
        ctx.pathPickerWildcardConfirm = true
        ctx.pathPickerWildcardMode = "config_open"
        return true
      end
      return applyConfigOpenPathAndReturn(ctx, val) == true
    end

    if ctx.pathBrowseActionsOpen and canCreateConfigIni then
      if actions_menu.run(ctx, {
            openKey = "pathBrowseActionsOpen",
            selKey = "pathBrowseActionsSel",
            scrollKey = "pathBrowseActionsScroll",
            title = (_.menu_str.actions_title or "Actions"),
            rows = {
              { id = "create_ini", label = createIniLabel },
            },
            rowStateKeyPrefix = "path_browse_actions_row_",
            onSelect = function(row)
              if row.id == "create_ini" then
                createConfigIniInBrowseDir()
              end
            end,
          }) then
        return
      end
    end

    if canCreateConfigIni and (_.padEffective & _.PAD_SQUARE) ~= 0 then
      _.common.openActionsMenu(ctx, "pathBrowseActionsOpen", "pathBrowseActionsSel", "pathBrowseActionsScroll")
      return
    end
    if #show > 0 then
      if (_.padEffective & _.PAD_UP) ~= 0 then
        ctx.pathPickerSel = _.common.moveListSelection(ctx.pathPickerSel, #show, -1, { ctx = ctx })
      end
      if (_.padEffective & _.PAD_DOWN) ~= 0 then
        ctx.pathPickerSel = _.common.moveListSelection(ctx.pathPickerSel, #show, 1, { ctx = ctx })
      end
      if (_.padEffective & _.PAD_LEFT) ~= 0 then
        ctx.pathPickerSel = math.max(1, ctx.pathPickerSel - maxVis)
      end
      if (_.padEffective & _.PAD_RIGHT) ~= 0 then
        ctx.pathPickerSel = math.min(#show, ctx.pathPickerSel + maxVis)
      end
    end
    if (_.padEffective & _.PAD_CROSS) ~= 0 then
      local e = (ctx.pathPickerSel > 0 and ctx.pathPickerSel <= #show) and show[ctx.pathPickerSel] or nil
      if e then
        if e.directory then
          ctx.pathPickerBrowseSelStack = ctx.pathPickerBrowseSelStack or {}
          table.insert(ctx.pathPickerBrowseSelStack, ctx.pathPickerSel)
          ctx.pathBrowsePath = e.full
          ctx.pathList = listBrowseEntries(ctx, ctx.pathBrowsePath)
          ctx.pathPickerSel = 1
          ctx.pathPickerScroll = 0
        else
          local rawPath = e.full and e.full:gsub("/$", "") or e.full
          local partPath = ctx.pfs1Mounted or ctx.pfs0Mounted
          local val = (partPath and pfsToPartitionPath(rawPath, partPath)) or rawPath
          if ctx.pathPickerBdmPrefix and ctx.pathPickerBdmBrowseRoot and rawPath then
            local rest = bdmRestFromPath(rawPath, ctx.pathPickerBdmBrowseRoot)
            if rest ~= nil then
              val = ctx.pathPickerBdmPrefix .. ":" .. (rest ~= "" and "/" .. rest or "")
            end
          end
          if not canUsePathSelection(ctx, val) then
            return
          end
          local openedConfig = false
          if isConfigOpenTarget(ctx) and _.file_selector.canWildcard and _.file_selector.canWildcard(val) and
              isIndexedUsbPath(val) then
            ctx.pathPickerPendingPath = val
            ctx.pathPickerWildcardConfirm = true
            ctx.pathPickerWildcardMode = "config_open"
          elseif applyConfigOpenPathAndReturn(ctx, val) then
            openedConfig = true
          elseif _.file_selector.canWildcard and _.file_selector.canWildcard(val) then
            ctx.pathPickerPendingPath = val
            ctx.pathPickerWildcardConfirm = true
            if ctx.pathPickerBootKey then
              ctx.pathPickerWildcardMode = "boot"
            elseif ctx.pathPickerBblHotkeyKey then
              ctx.pathPickerWildcardMode = "bbl_hotkey"
            elseif ctx.pathPickerBblIrxIdx then
              ctx.pathPickerWildcardMode = "bbl_irx"
            elseif ctx.pathPickerForEntryIdx then
              ctx.pathPickerWildcardMode = "entry"
            elseif ctx.isAddPath then
              ctx.pathPickerWildcardMode = "add"
            else
              ctx.pathPickerWildcardMode = "single"
            end
          elseif applyBootPathAndReturn(ctx, val) then
          elseif applyBblHotkeyPathAndReturn(ctx, val) then
          elseif applyBblIrxPathAndReturn(ctx, val) then
          elseif applyMenuEntryPathAndReturn(ctx, val) then
          elseif ctx.isAddPath then
            local key = (ctx.addPathKey == "path1_OSDSYS_ITEM_1") and _.resolveNextOsdItemKey(ctx.lines) or
                ctx.addPathKey
            _.config_parse.append(ctx.lines, key, val)
            ctx.state = "editor"
          else
            _.config_parse.set(ctx.lines, ctx.editKey, val)
            ctx.state = "editor"
          end
          if not openedConfig and not (ctx.pathPickerWildcardConfirm and ctx.pathPickerWildcardMode == "config_open") then
            ctx._configModifiedCache = nil
            ctx.configModified = true
            if not ctx.pathPickerWildcardConfirm then
              if ctx.pfs0Mounted and System.fileXioUmount then System.fileXioUmount("pfs0:") end
              if ctx.pfs1Mounted and System.fileXioUmount then System.fileXioUmount("pfs1:") end
              clearPickerTransient(ctx)
              ctx.pfs0Mounted = nil
              ctx.pfs1Mounted = nil
              clearConfigOpenPickerState(ctx)
            end
          end
        end
      end
    end
    if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
      if ctx.pathBrowsePath then
        local norm = ctx.pathBrowsePath:gsub("/$", "")
        -- At partition root (pfs0 = __sysconf, pfs1 = other HDD partition): go back to partition list, not device
        if norm == "pfs1:" or norm == "pfs1" or norm == "pfs0:" or norm == "pfs0" then
          local mountedPart = (norm == "pfs0:" or norm == "pfs0") and ctx.pfs0Mounted or ctx.pfs1Mounted
          local hddNum = tonumber(tostring(mountedPart or ""):match("^hdd(%d):")) or 0
          local hddRoot = "hdd" .. tostring(hddNum) .. ":"
          if ctx.pfs0Mounted and System.fileXioUmount then System.fileXioUmount("pfs0:") end
          if ctx.pfs1Mounted and System.fileXioUmount then System.fileXioUmount("pfs1:") end
          ctx.pfs0Mounted = nil; ctx.pfs1Mounted = nil
          ctx.pathPickerSub = "partitions"
          ctx.pathList = _.file_selector.getHddPartitions(hddNum) or {}
          ctx.pathBrowsePath = hddRoot
          local n = #(ctx.pathList or {})
          ctx.pathPickerSel = math.max(1, math.min(ctx.pathPickerPartitionSel or 1, n))
          ctx.pathPickerScroll = centeredScroll(ctx.pathPickerSel, n, _.MAX_VISIBLE_LIST)
        else
          local up = ctx.pathBrowsePath:gsub("/$", ""):gsub("/[^/]+$", "")
          if up == ctx.pathBrowsePath:gsub("/$", "") then
            if isConfigOpenTarget(ctx) and ctx.pathPickerLockedDevice then
              leaveLockedConfigBrowse(ctx)
              return
            end
            ctx.pathPickerSub = "device"
            ctx.pathPickerBrowseSelStack = nil
            ctx.pathPickerBdmPrefix = nil
            ctx.pathPickerBdmBrowseRoot = nil
            ctx.pathPickerBdmMountpoint = nil
            ctx.pathList = getPickerDevices(ctx, _)
            ctx.pathBrowsePath = nil
            local n = #(ctx.pathList or {})
            ctx.pathPickerSel = math.max(1, math.min(ctx.pathPickerDeviceSel or 1, n))
            ctx.pathPickerScroll = centeredScroll(ctx.pathPickerSel, n, _.MAX_VISIBLE_LIST)
          else
            ctx.pathBrowsePath = (up:sub(-1) == ":") and (up .. "/") or up
            ctx.pathList = listBrowseEntries(ctx, ctx.pathBrowsePath)
            local stack = ctx.pathPickerBrowseSelStack or {}
            ctx.pathPickerSel = math.max(1, math.min(table.remove(stack) or 1, #(ctx.pathList or {})))
            ctx.pathPickerBrowseSelStack = #stack > 0 and stack or nil
            ctx.pathPickerScroll = centeredScroll(ctx.pathPickerSel, #(ctx.pathList or {}), _.MAX_VISIBLE_LIST)
          end
        end
      else
        -- No path (e.g. unresolved device or empty): go back to device list, not editor
        if isConfigOpenTarget(ctx) and ctx.pathPickerLockedDevice then
          leaveLockedConfigBrowse(ctx)
          return
        end
        ctx.pathPickerSub = "device"
        ctx.pathPickerBrowseSelStack = nil
        ctx.pathPickerBdmPrefix = nil
        ctx.pathPickerBdmBrowseRoot = nil
        ctx.pathPickerBdmMountpoint = nil
        ctx.pathList = getPickerDevices(ctx, _)
        ctx.pathBrowsePath = nil
        local n = #(ctx.pathList or {})
        ctx.pathPickerSel = math.max(1, math.min(ctx.pathPickerDeviceSel or 1, n))
        ctx.pathPickerScroll = centeredScroll(ctx.pathPickerSel, n, _.MAX_VISIBLE_LIST)
      end
    end
  end
end

return { run = run }
