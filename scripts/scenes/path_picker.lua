--[[ Path picker: device list, partitions, or directory browse. ]]

-- Apply chosen path for MBR boot key and return next state. Returns nil if not a boot-key pick.
local function applyBootPathAndReturn(ctx, val)
  if not ctx.pathPickerBootKey or not ctx.lines then return nil end
  local _ = ctx._
  if ctx.pathPickerEditIdx then
    local paths = _.config_parse.getBootPaths(ctx.lines, ctx.pathPickerBootKey) or {}
    paths[ctx.pathPickerEditIdx] = val
    _.config_parse.setBootPaths(ctx.lines, ctx.pathPickerBootKey, paths)
  else
    _.config_parse.append(ctx.lines, ctx.pathPickerBootKey, val)
  end
  ctx.state = ctx.pathPickerReturnState or "editor"
  ctx.pathPickerBootKey = nil
  ctx.pathPickerReturnState = nil
  ctx.pathPickerForEntryIdx = nil
  ctx.pathPickerEditIdx = nil
  return true
end

-- Apply chosen path for a BBL hotkey slot and return next state. Returns nil if not a BBL slot pick.
local function applyBblHotkeyPathAndReturn(ctx, val)
  if not ctx.pathPickerBblHotkeyKey or not ctx.pathPickerBblHotkeySlot or not ctx.lines then return nil end
  local _ = ctx._
  local slot = tonumber(ctx.pathPickerBblHotkeySlot)
  if not slot then return nil end
  _.config_parse.setBblHotkeyPath(ctx.lines, ctx.pathPickerBblHotkeyKey, slot, val,
    ctx.pathPickerBblHotkeyDisabled and true or false)
  ctx.state = ctx.pathPickerReturnState or "bbl_hotkey_entry"
  ctx.pathPickerBblHotkeyKey = nil
  ctx.pathPickerBblHotkeySlot = nil
  ctx.pathPickerBblHotkeyDisabled = nil
  ctx.pathPickerReturnState = nil
  ctx.pathPickerEditIdx = nil
  return true
end

-- Convert pfs path (pfs0:/ or pfs1:/...) to full partition path (hdd0:PART:pfs:...). Returns nil if not a pfs path.
local function pfsToPartitionPath(pfsPath, partitionPath)
  if not pfsPath or not partitionPath then return nil end
  local rest = pfsPath:match("^pfs[01]:/?(.*)$")
  if not rest then return nil end
  if rest == "" then return partitionPath .. ":pfs:/" end
  return partitionPath .. ":pfs:" .. rest
end

-- IOP reset (mx4sio/mmce) unloads all device drivers; clear all loaded flags.
local function clearLoadedIfIopReset(ctx)
  ctx.pathPickerLoadedDeviceTypes = {}
end

local function isConfigOpenTarget(ctx)
  return ctx and ctx.pathPickerTarget == "config_open"
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

local function listBrowseEntries(ctx, path)
  local _ = ctx._
  if isConfigOpenTarget(ctx) then
    local raw = _.file_selector.listDirectory(path) or {}
    local out = {}
    for i = 1, #raw do
      local e = raw[i]
      if e and e.directory then
        table.insert(out, e)
      elseif e and tostring(e.name or ""):lower() == "config.ini" then
        table.insert(out, e)
      end
    end
    return out
  end
  local exts = ctx.pathPickerFileExts
  if type(exts) == "table" and #exts > 0 and _.common and _.common.listDirectoryFiltered then
    return _.common.listDirectoryFiltered(path, _.file_selector, { extensions = exts })
  end
  return _.listDirectoryElfOnly(path)
end

local function clearPickerTransient(ctx)
  ctx.pathList = nil
  ctx.pathBrowsePath = nil
  ctx.pathPickerBdmPrefix = nil
  ctx.pathPickerBdmMountpoint = nil
  ctx.pathPickerBrowseSelStack = nil
end

local function clearConfigOpenPickerState(ctx)
  ctx.pathPickerTarget = nil
  ctx.pathPickerFileExts = nil
  ctx.pathPickerLockedDevice = nil
  ctx.pathPickerLockedDeviceStarted = nil
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
      ctx.state = (ctx.pathPickerEditIdx and "entry_paths") or "menu_entry_edit"
      ctx.pathPickerForEntryIdx = nil
      ctx.pathPickerEditIdx = nil
    elseif ctx.pathPickerBblHotkeyKey then
      ctx.state = ctx.pathPickerReturnState or "bbl_hotkey_entry"
      ctx.pathPickerBblHotkeyKey = nil
      ctx.pathPickerBblHotkeySlot = nil
      ctx.pathPickerBblHotkeyDisabled = nil
    else
      ctx.state = ctx.pathPickerReturnState or "editor"
    end
    ctx.pathList = nil
    ctx.pathPickerReturnState = nil
    return
  end
  local _ = ctx._
  if ctx.pfs0Mounted and System.fileXioUmount then System.fileXioUmount("pfs0:") end
  if ctx.pfs1Mounted and System.fileXioUmount then System.fileXioUmount("pfs1:") end
  ctx.pathList = nil
  ctx.pathBrowsePath = nil
  ctx.pfs0Mounted = nil
  ctx.pfs1Mounted = nil
  if applyConfigOpenPathAndReturn(ctx, val) then
    return
  end
  ctx.configModified = true
  if applyBootPathAndReturn(ctx, val) then
  elseif applyBblHotkeyPathAndReturn(ctx, val) then
  elseif ctx.pathPickerForEntryIdx then
    local paths = _.config_parse.getMenuEntryPaths(ctx.lines, ctx.pathPickerForEntryIdx)
    if ctx.pathPickerEditIdx then
      local item = paths[ctx.pathPickerEditIdx]
      if type(item) == "table" then item.value = val else paths[ctx.pathPickerEditIdx] = { value = val, disabled = false } end
    else
      table.insert(paths, { value = val, disabled = false })
    end
    _.config_parse.setMenuEntryPaths(ctx.lines, ctx.pathPickerForEntryIdx, paths)
    ctx.entryIdx = ctx.pathPickerForEntryIdx
    ctx.state = (ctx.pathPickerEditIdx and "entry_paths") or "menu_entry_edit"
    ctx.pathPickerForEntryIdx = nil
    ctx.pathPickerEditIdx = nil
  elseif ctx.isAddPath then
    local key = (ctx.addPathKey == "path1_OSDSYS_ITEM_1") and _.resolveNextOsdItemKey(ctx.lines) or ctx.addPathKey
    _.config_parse.append(ctx.lines, key, val)
    ctx.state = "editor"
  else
    _.config_parse.set(ctx.lines, ctx.editKey or "", val)
    ctx.state = "editor"
  end
  ctx.pathPickerBootKey = nil
  ctx.pathPickerReturnState = nil
  ctx.pathPickerBdmPrefix = nil
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
      { name = "OSDSYS", desc = p.fmcb_cmd_osdsys or "OSDSYS", special = "bbl_cmd" },
    }
  else
    cmdRows = {
      { name = "$CDVD", desc = p.bbl_cmd_cdvd or "$CDVD", special = "bbl_cmd" },
      { name = "$CDVD_NO_PS2LOGO", desc = p.bbl_cmd_cdvd_no_logo or "$CDVD_NO_PS2LOGO", special = "bbl_cmd" },
      { name = "$OSDSYS", desc = p.bbl_cmd_osdsys or "$OSDSYS", special = "bbl_cmd" },
      { name = "$CREDITS", desc = p.bbl_cmd_credits or "$CREDITS", special = "bbl_cmd" },
      { name = "$HDDCHECKER", desc = p.bbl_cmd_hddchecker or "$HDDCHECKER (HDD build)", special = "bbl_cmd" },
      { name = "$RUNKELF:", desc = p.bbl_cmd_runkelf or "$RUNKELF:<path>", special = "bbl_cmd", bblTokenPrompt = true },
    }
  end
  for i = 1, #cmdRows do
    table.insert(ctx.pathList, cmdRows[i])
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

local function beginBrowseForDevice(ctx, e)
  if not e then return end
  local _ = ctx._
  if e.deviceType == "hdd" and not e.deviceId then
    ctx.pathPickerDeviceSel = ctx.pathPickerSel
    ctx.pathPickerLoadedDeviceTypes = ctx.pathPickerLoadedDeviceTypes or {}
    if ctx.pathPickerLoadedDeviceTypes["hdd"] then
      if System and System.loadModules then System.loadModules("hdd") end
      if _.common.isHddPresent and _.common.isHddPresent() then
        ctx.pathPickerSub = "partitions"
        ctx.pathList = _.file_selector.getHddPartitions(0) or {}
        ctx.pathBrowsePath = "hdd0:"
        ctx.pathPickerSel = 1
        ctx.pathPickerScroll = 0
      else
        ctx.pathPickerLoading = { deviceType = "hdd", staticHdd = true }
        ctx.pathPickerLoadingFrames = 0
      end
    else
      ctx.pathPickerLoading = { deviceType = "hdd", staticHdd = true }
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
        local mpNorm = (mp:sub(-1) == ":") and mp or (mp .. ":")
        ctx.pathPickerBdmMountpoint = mpNorm
        ctx.pathPickerBdmPrefix = _.file_selector.getBdmPathPrefix(e.deviceId)
        ctx.pathBrowsePath = (mp:sub(-1) == ":") and (mp .. "/") or mp
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
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y + _.scaleY(28), _.FONT_SCALE, val, _.GRAY)
    _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, _.path_str.wildcard_confirm_hint, nil, _.DIM,
      _.w - 2 * _.MARGIN_X)
    local function applyAndExit(chosenVal)
      ctx.configModified = true
      if mode == "single" then
        _.config_parse.set(ctx.lines, ctx.editKey, chosenVal)
        ctx.state = "editor"
      elseif mode == "bbl_hotkey" then
        local slot = tonumber(ctx.pathPickerBblHotkeySlot)
        if slot then
          _.config_parse.setBblHotkeyPath(ctx.lines, ctx.pathPickerBblHotkeyKey, slot, chosenVal,
            ctx.pathPickerBblHotkeyDisabled and true or false)
        end
        ctx.state = ctx.pathPickerReturnState or "bbl_hotkey_entry"
        ctx.pathPickerBblHotkeyKey = nil
        ctx.pathPickerBblHotkeySlot = nil
        ctx.pathPickerBblHotkeyDisabled = nil
        ctx.pathPickerReturnState = nil
      elseif mode == "entry" then
        local paths = _.config_parse.getMenuEntryPaths(ctx.lines, ctx.pathPickerForEntryIdx)
        if ctx.pathPickerEditIdx then
          local item = paths[ctx.pathPickerEditIdx]
          if type(item) == "table" then item.value = chosenVal else paths[ctx.pathPickerEditIdx] = { value = chosenVal, disabled = false } end
        else
          table.insert(paths, { value = chosenVal, disabled = false })
        end
        _.config_parse.setMenuEntryPaths(ctx.lines, ctx.pathPickerForEntryIdx, paths)
        ctx.entryIdx = ctx.pathPickerForEntryIdx
        ctx.state = ctx.pathPickerReturnState or (ctx.pathPickerEditIdx and "entry_paths") or "menu_entry_edit"
        ctx.pathPickerForEntryIdx = nil
        ctx.pathPickerEditIdx = nil
        ctx.pathPickerReturnState = nil
      elseif mode == "add" then
        local key = (ctx.addPathKey == "path1_OSDSYS_ITEM_1") and _.resolveNextOsdItemKey(ctx.lines) or ctx.addPathKey
        _.config_parse.append(ctx.lines, key, chosenVal)
        ctx.state = "editor"
      elseif mode == "boot" then
        if ctx.pathPickerEditIdx then
          local paths = _.config_parse.getBootPaths(ctx.lines, ctx.pathPickerBootKey) or {}
          paths[ctx.pathPickerEditIdx] = chosenVal
          _.config_parse.setBootPaths(ctx.lines, ctx.pathPickerBootKey, paths)
        else
          _.config_parse.append(ctx.lines, ctx.pathPickerBootKey, chosenVal)
        end
        ctx.state = ctx.pathPickerReturnState or "editor"
        ctx.pathPickerBootKey = nil
        ctx.pathPickerReturnState = nil
        ctx.pathPickerEditIdx = nil
      end
      ctx.pathPickerWildcardConfirm = nil
      ctx.pathPickerPendingPath = nil
      ctx.pathPickerWildcardMode = nil
      ctx.pathPickerBdmPrefix = nil
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
        _.path_str.circle_back_items, nil, _.DIM, _.w - 2 * _.MARGIN_X)
      ctx.pathPickerLoadingFrames = (ctx.pathPickerLoadingFrames or 0) + 1
      -- Load drivers on frame 2 so the first splash frame is presented before blocking (same for all HDD/BDM)
      if ctx.pathPickerLoadingFrames == 2 and not ctx.pathPickerModulesLoaded and load.deviceType and System and System.loadModules then
        System.loadModules(load.deviceType)
        ctx.pathPickerModulesLoaded = true
      end
      local mp = nil
      if load.staticHdd then
        if ctx.pathPickerLoadingFrames > 0 and ctx.pathPickerLoadingFrames % PROBE_INTERVAL_FRAMES == 0 then
          if _.common.isHddPresent and _.common.isHddPresent() then
            ctx.pathPickerLoading = nil
            ctx.pathPickerLoadingFrames = nil
            ctx.pathPickerModulesLoaded = nil
            ctx.pathPickerLoadedDeviceTypes = ctx.pathPickerLoadedDeviceTypes or {}
            ctx.pathPickerLoadedDeviceTypes["hdd"] = true
            ctx.pathPickerSub = "partitions"
            ctx.pathList = _.file_selector.getHddPartitions(0) or {}
            ctx.pathBrowsePath = "hdd0:"
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
          local mpNorm = (mp:sub(-1) == ":") and mp or (mp .. ":")
          ctx.pathPickerBdmMountpoint = mpNorm
          ctx.pathPickerBdmPrefix = _.file_selector.getBdmPathPrefix(load.deviceId)
          ctx.pathBrowsePath = (mp:sub(-1) == ":") and (mp .. "/") or mp
          ctx.pathList = listBrowseEntries(ctx, ctx.pathBrowsePath)
          ctx.pathPickerSub = "browse"
          ctx.pathPickerSel = 1
          ctx.pathPickerScroll = 0
        end
      end
      if ctx.pathPickerLoading and ctx.pathPickerLoadingFrames >= LOAD_TIMEOUT_FRAMES then
        local timeoutDevice = load.deviceId or (load.staticHdd and "hdd0") or load.deviceType or "device"
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
        _.drawText(_.font, _.drawMode, cx, cy, _.FONT_SCALE, msg, _.DIM)
      end
    end
    if not ctx.pathPickerLoadingTimeoutMsg and not ctx.pathPickerLoading then
      _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1,
        ctx.isAddPath and _.path_str.add_path_choose_device or _.path_str.choose_device, _.WHITE)
      if (ctx.pathPickerContext == "path_only" or ctx.pathPickerContext == "config_ini") and _.path_str.bbl_build_device_hint then
        local hint = _.path_str.bbl_build_device_hint
        hint = hint:gsub("PS%?BBL", getSelectedBblName(ctx))
        if _.common.truncateTextToWidth then
          hint = _.common.truncateTextToWidth(_.font, hint, _.w - (_.MARGIN_X * 2), 0.55)
        end
        _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y + _.scaleY(20), 0.55, hint, _.DIM)
      end
      if ctx.pathList and #ctx.pathList > 0 and not ctx.pathPickerLoading then
        local lockedConfigBrowse = isConfigOpenTarget(ctx) and ctx.pathPickerLockedDevice
        local includeManualEntry = not lockedConfigBrowse
        local manualOffset = includeManualEntry and 1 or 0
        local totalCount = #ctx.pathList + manualOffset
        if ctx.pathPickerSel < 1 then ctx.pathPickerSel = 1 end
        if ctx.pathPickerSel > totalCount then ctx.pathPickerSel = totalCount end
        _.drawText(_.font, _.drawMode, _.w - _.MARGIN_X - 56, _.MARGIN_Y, 0.9,
          ctx.pathPickerSel .. " / " .. totalCount, _.DIM)
        local exclusiveSet = {}
        for _, dev in ipairs(ctx.pathList) do
          if dev.exclusive and dev.name then exclusiveSet[dev.name] = true end
        end
        local function deviceFromListIndex(listIdx)
          local devIdx = listIdx - manualOffset
          if devIdx < 1 or devIdx > #ctx.pathList then return nil end
          return ctx.pathList[devIdx]
        end
        local function pathIsExclusive(p)
          if not p or p == "" then return false end
          return exclusiveSet[p] or exclusiveSet[(p):upper()] == true
        end
        local entryHasOtherPaths = false
        local bootHasOtherPaths = false
        if ctx.pathPickerForEntryIdx and ctx.lines then
          local entryPaths = _.config_parse.getMenuEntryPaths(ctx.lines, ctx.pathPickerForEntryIdx)
          for _, p in ipairs(entryPaths) do
            local pv = type(p) == "table" and p.value or p
            if not pathIsExclusive(pv) then
              entryHasOtherPaths = true; break
            end
          end
        end
        if ctx.pathPickerBootKey and ctx.lines then
          local bootPaths = _.config_parse.getBootPaths(ctx.lines, ctx.pathPickerBootKey) or {}
          for _, p in ipairs(bootPaths) do
            if not pathIsExclusive(p) then
              bootHasOtherPaths = true; break
            end
          end
        end
        local hasOtherPaths = entryHasOtherPaths or bootHasOtherPaths
        local function isGreyed(e)
          if not e then return true end
          return (e.exclusive and hasOtherPaths) or false
        end
        local function isSelectable(listIdx)
          if includeManualEntry and listIdx == 1 then return true end
          local e = deviceFromListIndex(listIdx)
          return e ~= nil and not isGreyed(e)
        end
        if not isSelectable(ctx.pathPickerSel) then
          local found = nil
          for idx = 1, totalCount do
            if isSelectable(idx) then
              found = idx
              break
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
        local maxLabelW = (_.w or 640) - (_.MARGIN_X + 20) - _.MARGIN_X
        for i = 1, math.min(maxVis, totalCount - ctx.pathPickerScroll) do
          local listIdx = ctx.pathPickerScroll + i
          local displayName
          local greyed = false
          local e = nil
          if includeManualEntry and listIdx == 1 then
            displayName = _.path_str.enter_path_manually
          else
            e = deviceFromListIndex(listIdx)
            displayName = e and (e.desc or e.name or _.common_str.empty) or _.common_str.empty
            greyed = isGreyed(e)
          end
          local y = _.MARGIN_Y + _.scaleY(50) + (i - 1) * _.LINE_H
          local col = greyed and _.DIM or ((listIdx == ctx.pathPickerSel) and _.SELECTED_ENTRY or _.GRAY)
          if _.common.fitListRowText then
            displayName = _.common.fitListRowText(ctx, "path_picker_device_row_" .. tostring(listIdx), _.font,
              displayName, maxLabelW, _.FONT_SCALE, listIdx == ctx.pathPickerSel)
          elseif _.common.truncateTextToWidth then
            displayName = _.common.truncateTextToWidth(_.font, displayName or "", maxLabelW, _.FONT_SCALE)
          end
          _.drawListRow(_.MARGIN_X + 20, y, listIdx == ctx.pathPickerSel, displayName, col)
        end
        if (_.padEffective & _.PAD_UP) ~= 0 then
          local idx = ctx.pathPickerSel
          for _ = 1, totalCount do
            idx = idx - 1; if idx < 1 then idx = totalCount end
            if isSelectable(idx) then
              ctx.pathPickerSel = idx; break
            end
          end
        end
        if (_.padEffective & _.PAD_DOWN) ~= 0 then
          local idx = ctx.pathPickerSel
          for _ = 1, totalCount do
            idx = idx + 1; if idx > totalCount then idx = 1 end
            if isSelectable(idx) then
              ctx.pathPickerSel = idx; break
            end
          end
        end
        if (_.padEffective & _.PAD_CROSS) ~= 0 then
          if includeManualEntry and ctx.pathPickerSel == 1 then
            ctx.textInputTitleIdMode = nil
            ctx.textInputPrompt = _.path_str.enter_path_prompt
            ctx.textInputValue = ""
            ctx.textInputMaxLen = 79
            ctx.textInputCallback = function(val)
              applyManualPath(ctx, val)
            end
            ctx.textInputReturnState = "path_picker"
            ctx.textInputGridSel = 1
            ctx.textInputCursor = 1
            ctx.textInputScroll = 1
            ctx.state = "text_input"
          else
            local e = deviceFromListIndex(ctx.pathPickerSel)
            if isGreyed(e) then
              -- exclusive and other paths exist; ignore
            elseif e.special then
              local pathVal = e.name or ""
              if e.bblTokenPrompt then
                ctx.textInputTitleIdMode = nil
                ctx.textInputPrompt = _.path_str.bbl_cmd_runkelf_prompt or "Enter KELF path"
                ctx.textInputValue = ""
                ctx.textInputMaxLen = 79
                ctx.textInputCallback = function(val)
                  local v = tostring(val or ""):gsub("^%s+", ""):gsub("%s+$", "")
                  if v == "" then
                    ctx.state = "path_picker"
                    return
                  end
                  applyManualPath(ctx, "$RUNKELF:" .. v)
                end
                ctx.textInputReturnState = "path_picker"
                ctx.textInputGridSel = 1
                ctx.textInputCursor = 1
                ctx.textInputScroll = 1
                ctx.state = "text_input"
                return
              end
              if ctx.pfs0Mounted and System.fileXioUmount then System.fileXioUmount("pfs0:") end
              if ctx.pfs1Mounted and System.fileXioUmount then System.fileXioUmount("pfs1:") end
              ctx.pathList = nil
              ctx.pfs0Mounted = nil
              ctx.pfs1Mounted = nil
              if ctx.pathPickerBootKey and ctx.lines then
                if ctx.pathPickerEditIdx then
                  local paths = _.config_parse.getBootPaths(ctx.lines, ctx.pathPickerBootKey) or {}
                  paths[ctx.pathPickerEditIdx] = pathVal
                  _.config_parse.setBootPaths(ctx.lines, ctx.pathPickerBootKey, paths)
                else
                  _.config_parse.append(ctx.lines, ctx.pathPickerBootKey, pathVal)
                end
                if e.noargs then _.config_parse.setBootArgs(ctx.lines, ctx.pathPickerBootKey, {}) end
                ctx.state = ctx.pathPickerReturnState or "editor"
                ctx.pathPickerBootKey = nil
                ctx.pathPickerReturnState = nil
                ctx.pathPickerForEntryIdx = nil
                ctx.pathPickerEditIdx = nil
              elseif applyBblHotkeyPathAndReturn(ctx, pathVal) then
              elseif ctx.pathPickerForEntryIdx then
                local paths = _.config_parse.getMenuEntryPaths(ctx.lines, ctx.pathPickerForEntryIdx)
                if ctx.pathPickerEditIdx then
                  local item = paths[ctx.pathPickerEditIdx]
                  if type(item) == "table" then item.value = pathVal else paths[ctx.pathPickerEditIdx] = { value =
                    pathVal, disabled = false } end
                else
                  table.insert(paths, { value = pathVal, disabled = false })
                end
                _.config_parse.setMenuEntryPaths(ctx.lines, ctx.pathPickerForEntryIdx, paths)
                if e.noargs then _.config_parse.setMenuEntryArgs(ctx.lines, ctx.pathPickerForEntryIdx, {}) end
                ctx.entryIdx = ctx.pathPickerForEntryIdx
                ctx.state = (ctx.pathPickerEditIdx and "entry_paths") or "menu_entry_edit"
                ctx.pathPickerForEntryIdx = nil
                ctx.pathPickerEditIdx = nil
              elseif ctx.isAddPath then
                local key = (ctx.addPathKey == "path1_OSDSYS_ITEM_1") and _.resolveNextOsdItemKey(ctx.lines) or
                    ctx.addPathKey
                _.config_parse.append(ctx.lines, key, pathVal)
                ctx.state = "editor"
              else
                _.config_parse.set(ctx.lines, ctx.editKey or "", pathVal)
                ctx.state = "editor"
              end
              ctx.configModified = true
            else
              beginBrowseForDevice(ctx, e)
            end
          end
        end
      else
        _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y + _.scaleY(60), _.FONT_SCALE, _.path_str.no_devices, _
          .GRAY)
      end
    end
    if ctx.pathPickerLoading then
    elseif ctx.pathPickerLoadingTimeoutMsg then
      _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, _.path_str.circle_back_items, nil, _.DIM,
        _.w - 2 * _.MARGIN_X)
    else
      _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, _.path_str.cross_select_circle_back_items, nil,
        _.DIM, _.w - 2 * _.MARGIN_X)
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
        ctx.pathList = _.file_selector.getDevices(ctx.pathPickerContext) or {}
      else
        if ctx.pfs0Mounted and System.fileXioUmount then System.fileXioUmount("pfs0:") end
        if ctx.pfs1Mounted and System.fileXioUmount then System.fileXioUmount("pfs1:") end
        if ctx.pathPickerBootKey then
          ctx.state = ctx.pathPickerReturnState or "editor"
          ctx.pathPickerBootKey = nil; ctx.pathPickerReturnState = nil
        elseif ctx.pathPickerBblHotkeyKey then
          ctx.state = ctx.pathPickerReturnState or "bbl_hotkey_entry"
          ctx.pathPickerBblHotkeyKey = nil
          ctx.pathPickerBblHotkeySlot = nil
          ctx.pathPickerBblHotkeyDisabled = nil
          ctx.pathPickerReturnState = nil
        elseif ctx.pathPickerForEntryIdx then
          ctx.entryIdx = ctx.pathPickerForEntryIdx
          ctx.state = (ctx.pathPickerEditIdx and "entry_paths") or "menu_entry_edit"
          ctx.pathPickerForEntryIdx = nil; ctx.pathPickerEditIdx = nil
        elseif isConfigOpenTarget(ctx) then
          ctx.state = ctx.pathPickerReturnState or "select_config"
          ctx.pathPickerReturnState = nil
          clearConfigOpenPickerState(ctx)
        else
          ctx.state = "editor"
        end
        ctx.pathList = nil; ctx.pathBrowsePath = nil; ctx.pathPickerBdmPrefix = nil; ctx.pathPickerBdmMountpoint = nil
        ctx.pfs0Mounted = nil; ctx.pfs1Mounted = nil
      end
    end
  elseif ctx.pathPickerSub == "partitions" then
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1, _.path_str.select_hdd_partition, _.WHITE)
    local parts = ctx.pathList or {}
    if ctx.pathPickerSel < 1 then ctx.pathPickerSel = 1 end
    if ctx.pathPickerSel > #parts then ctx.pathPickerSel = #parts end
    local maxVis = _.MAX_VISIBLE_LIST
    if #parts > maxVis then
      ctx.pathPickerScroll = ctx.pathPickerSel - math.floor(maxVis / 2)
      ctx.pathPickerScroll = math.max(0, math.min(ctx.pathPickerScroll, #parts - maxVis))
    else
      ctx.pathPickerScroll = 0
    end
    if #parts > 0 then
      _.drawText(_.font, _.drawMode, _.w - _.MARGIN_X - 56, _.MARGIN_Y, 0.9, ctx.pathPickerSel .. " / " .. #parts,
        _.DIM)
    end
    local maxLabelW = (_.w or 640) - (_.MARGIN_X + 20) - _.MARGIN_X
    for i = ctx.pathPickerScroll + 1, math.min(ctx.pathPickerScroll + maxVis, #parts) do
      local p = parts[i]
      if not p then break end
      local y = _.MARGIN_Y + _.scaleY(50) + (i - ctx.pathPickerScroll - 1) * _.LINE_H
      local col = (i == ctx.pathPickerSel) and _.SELECTED_ENTRY or _.GRAY
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
        .DIM)
    end
    local partHint = isConfigOpenTarget(ctx) and _.path_str.cross_open_circle_back_items or
        (_.path_str.cross_open_square_patinfo_circle_back_items or _.path_str.cross_open_circle_back_items)
    _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, partHint, nil, _.DIM, _.w - 2 * _.MARGIN_X)
    if (_.padEffective & _.PAD_UP) ~= 0 then
      ctx.pathPickerSel = ctx.pathPickerSel - 1; if ctx.pathPickerSel < 1 then ctx.pathPickerSel = #parts end
    end
    if (_.padEffective & _.PAD_DOWN) ~= 0 then
      ctx.pathPickerSel = ctx.pathPickerSel + 1; if ctx.pathPickerSel > #parts then ctx.pathPickerSel = 1 end
    end
    if (_.padEffective & _.PAD_LEFT) ~= 0 then
      ctx.pathPickerSel = math.max(1, ctx.pathPickerSel - maxVis)
    end
    if (_.padEffective & _.PAD_RIGHT) ~= 0 then
      ctx.pathPickerSel = math.min(#parts, ctx.pathPickerSel + maxVis)
    end
    if not isConfigOpenTarget(ctx) and (_.padEffective & _.PAD_SQUARE) ~= 0 and #parts > 0 then
      local p = parts[ctx.pathPickerSel]
      if not p then p = {} end
      local partFull = p.full or ("hdd0:" .. (p.name or ""))
      local val = partFull .. ":PATINFO"
      if applyBootPathAndReturn(ctx, val) then
      elseif applyBblHotkeyPathAndReturn(ctx, val) then
      elseif ctx.pathPickerForEntryIdx then
        local paths = _.config_parse.getMenuEntryPaths(ctx.lines, ctx.pathPickerForEntryIdx)
        if ctx.pathPickerEditIdx then
          local item = paths[ctx.pathPickerEditIdx]
          if type(item) == "table" then item.value = val else paths[ctx.pathPickerEditIdx] = { value = val, disabled = false } end
        else
          table.insert(paths, { value = val, disabled = false })
        end
        _.config_parse.setMenuEntryPaths(ctx.lines, ctx.pathPickerForEntryIdx, paths)
        ctx.entryIdx = ctx.pathPickerForEntryIdx
        ctx.state = (ctx.pathPickerEditIdx and "entry_paths") or "menu_entry_edit"
        ctx.pathPickerForEntryIdx = nil; ctx.pathPickerEditIdx = nil
      elseif ctx.isAddPath then
        local key = (ctx.addPathKey == "path1_OSDSYS_ITEM_1") and _.resolveNextOsdItemKey(ctx.lines) or ctx.addPathKey
        _.config_parse.append(ctx.lines, key, val)
        ctx.state = "editor"
      else
        _.config_parse.set(ctx.lines, ctx.editKey, val); ctx.state = "editor"
      end
      ctx.configModified = true
      ctx.pathList = nil; ctx.pathBrowsePath = nil; ctx.pathPickerBdmPrefix = nil; ctx.pathPickerBdmMountpoint = nil
      ctx.pathPickerSub = "device"
    end
    if (_.padEffective & _.PAD_CROSS) ~= 0 and #parts > 0 then
      local p = parts[ctx.pathPickerSel]
      if not p then p = {} end
      ctx.pathPickerPartitionSel = ctx.pathPickerSel
      local partName = p.name or ""
      local partFull = p.full or ("hdd0:" .. partName)
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
      ctx.pathList = _.file_selector.getDevices(ctx.pathPickerContext) or {}
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
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 0.9, headerPath, _.DIM)
    local show = ctx.pathList or {}
    if #show == 0 then
      ctx.pathPickerSel = 0
    else
      ctx.pathPickerSel = math.max(1, math.min(ctx.pathPickerSel, #show))
    end
    local maxVis = _.MAX_VISIBLE_LIST
    if #show > maxVis and ctx.pathPickerSel > 0 then
      ctx.pathPickerScroll = ctx.pathPickerSel - math.floor(maxVis / 2)
      ctx.pathPickerScroll = math.max(0, math.min(ctx.pathPickerScroll, #show - maxVis))
    elseif #show <= maxVis then
      ctx.pathPickerScroll = 0
    end
    if #show > 0 then
      _.drawText(_.font, _.drawMode, _.w - _.MARGIN_X - 56, _.MARGIN_Y, 0.9, ctx.pathPickerSel .. " / " .. #show,
        _.DIM)
    end
    local maxLabelW = (_.w or 640) - (_.MARGIN_X + 20) - _.MARGIN_X
    for i = ctx.pathPickerScroll + 1, math.min(ctx.pathPickerScroll + maxVis, #show) do
      local e = show[i]
      if not e then break end
      local y = _.MARGIN_Y + _.scaleY(50) + (i - ctx.pathPickerScroll - 1) * _.LINE_H
      local label = e.name or _.common_str.empty
      if e.directory and label ~= "" then label = label .. "/" end
      local col = (i == ctx.pathPickerSel) and _.SELECTED_ENTRY or _.GRAY
      if _.common.fitListRowText then
        label = _.common.fitListRowText(ctx, "path_picker_browse_row_" .. tostring(i), _.font, label, maxLabelW,
          _.FONT_SCALE, i == ctx.pathPickerSel)
      elseif _.common.truncateTextToWidth then
        label = _.common.truncateTextToWidth(_.font, label, maxLabelW, _.FONT_SCALE)
      end
      _.drawListRow(_.MARGIN_X + 20, y, i == ctx.pathPickerSel, label, col)
    end
    if #show == 0 then
      local noFilesLabel = hasIniFilter(ctx) and (_.path_str.no_ini_files or "No INI files or folders") or _.path_str.no_elf_files
      _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y + _.scaleY(55), _.FONT_SCALE, noFilesLabel, _.DIM)
    end
    local browseHint = _.path_str.cross_select_file_items
    if isConfigOpenTarget(ctx) and ctx.pathBrowsePath then
      browseHint = _.path_str.cross_select_create_circle_back_items or browseHint
    end
    _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, browseHint, nil, _.DIM, _.w - 2 * _.MARGIN_X)
    if isConfigOpenTarget(ctx) and ctx.pathBrowsePath and (_.padEffective & _.PAD_SELECT) ~= 0 then
      local dir = tostring(ctx.pathBrowsePath):gsub("/$", "")
      local val = dir .. "/CONFIG.INI"
      local partPath = ctx.pfs1Mounted or ctx.pfs0Mounted
      if partPath then
        val = pfsToPartitionPath(val, partPath) or val
      end
      if applyConfigOpenPathAndReturn(ctx, val) then
        return
      end
    end
    if #show > 0 then
      if (_.padEffective & _.PAD_UP) ~= 0 then
        ctx.pathPickerSel = ctx.pathPickerSel - 1; if ctx.pathPickerSel < 1 then ctx.pathPickerSel = #show end
      end
      if (_.padEffective & _.PAD_DOWN) ~= 0 then
        ctx.pathPickerSel = ctx.pathPickerSel + 1; if ctx.pathPickerSel > #show then ctx.pathPickerSel = 1 end
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
          if ctx.pathPickerBdmPrefix and ctx.pathPickerBdmMountpoint and rawPath then
            local mp = ctx.pathPickerBdmMountpoint
            if rawPath == mp or rawPath:sub(1, #mp) == mp then
              local rest = rawPath:sub(#mp + 1):gsub("^/", "")
              val = ctx.pathPickerBdmPrefix .. ":" .. (rest ~= "" and "/" .. rest or "")
            end
          end
          local openedConfig = false
          if applyConfigOpenPathAndReturn(ctx, val) then
            openedConfig = true
          elseif _.file_selector.canWildcard and _.file_selector.canWildcard(val) then
            ctx.pathPickerPendingPath = val
            ctx.pathPickerWildcardConfirm = true
            if ctx.pathPickerBootKey then
              ctx.pathPickerWildcardMode = "boot"
            elseif ctx.pathPickerBblHotkeyKey then
              ctx.pathPickerWildcardMode = "bbl_hotkey"
            elseif ctx.pathPickerForEntryIdx then
              ctx.pathPickerWildcardMode = "entry"
            elseif ctx.isAddPath then
              ctx.pathPickerWildcardMode = "add"
            else
              ctx.pathPickerWildcardMode = "single"
            end
          elseif applyBootPathAndReturn(ctx, val) then
          elseif applyBblHotkeyPathAndReturn(ctx, val) then
          elseif ctx.pathPickerForEntryIdx then
            local paths = _.config_parse.getMenuEntryPaths(ctx.lines, ctx.pathPickerForEntryIdx)
            if ctx.pathPickerEditIdx then
              local item = paths[ctx.pathPickerEditIdx]
              if type(item) == "table" then item.value = val else paths[ctx.pathPickerEditIdx] = { value = val, disabled = false } end
            else
              table.insert(paths, { value = val, disabled = false })
            end
            _.config_parse.setMenuEntryPaths(ctx.lines, ctx.pathPickerForEntryIdx, paths)
            ctx.entryIdx = ctx.pathPickerForEntryIdx
            ctx.state = ctx.pathPickerReturnState or (ctx.pathPickerEditIdx and "entry_paths") or "menu_entry_edit"
            ctx.pathPickerForEntryIdx = nil
            ctx.pathPickerEditIdx = nil
            ctx.pathPickerReturnState = nil
          elseif ctx.isAddPath then
            local key = (ctx.addPathKey == "path1_OSDSYS_ITEM_1") and _.resolveNextOsdItemKey(ctx.lines) or
                ctx.addPathKey
            _.config_parse.append(ctx.lines, key, val)
            ctx.state = "editor"
          else
            _.config_parse.set(ctx.lines, ctx.editKey, val)
            ctx.state = "editor"
          end
          if not openedConfig then
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
          if ctx.pfs0Mounted and System.fileXioUmount then System.fileXioUmount("pfs0:") end
          if ctx.pfs1Mounted and System.fileXioUmount then System.fileXioUmount("pfs1:") end
          ctx.pfs0Mounted = nil; ctx.pfs1Mounted = nil
          ctx.pathPickerSub = "partitions"
          ctx.pathList = _.file_selector.getHddPartitions(0) or {}
          ctx.pathBrowsePath = "hdd0:"
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
            ctx.pathPickerBdmMountpoint = nil
            ctx.pathList = _.file_selector.getDevices(ctx.pathPickerContext) or {}
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
        ctx.pathPickerBdmMountpoint = nil
        ctx.pathList = _.file_selector.getDevices(ctx.pathPickerContext) or {}
        ctx.pathBrowsePath = nil
        local n = #(ctx.pathList or {})
        ctx.pathPickerSel = math.max(1, math.min(ctx.pathPickerDeviceSel or 1, n))
        ctx.pathPickerScroll = centeredScroll(ctx.pathPickerSel, n, _.MAX_VISIBLE_LIST)
      end
    end
  end
end

return { run = run }
