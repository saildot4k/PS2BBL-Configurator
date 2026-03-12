--[[
  Main flow: main, choose_mc, select_config, initHdd, open, choose_load.
  run*(s, pad) where s has .common, .font, .drawMode, .drawListRow and state vars.
  Strings: try strings.lua (cwd override) then scripts/lang/strings_XX.lua. If CWD override, L1/R1 lang cycle is disabled.
  (Use loadfile for the optional CWD file: with VFS, pcall(dofile, path) can fail for paths not in VFS; loadfile returns nil if missing.)
]]

local function tryLoadStrings(path)
  local chunk = loadfile(path)
  if not chunk then return nil end
  local ok, t = pcall(chunk)
  return (ok and type(t) == "table") and t or nil
end

local strings = tryLoadStrings("strings.lua")
local cwdOverride = (strings ~= nil)
if not cwdOverride then
  strings = dofile("scripts/lang/strings_en.lua")
end
strings = strings or {}
_G.CONFIG_UI.strings = strings
_G.CONFIG_UI.langCycleDisabled = cwdOverride

-- Build list of lang files (scripts/lang/strings_*.lua) for L1/R1 cycle; only when not CWD override.
if not cwdOverride and System and System.listDirectory then
  local list = {}
  local okList, listRaw = pcall(System.listDirectory, "/scripts/lang")
  if okList and type(listRaw) == "table" then
    for i = 1, #listRaw do
      local e = listRaw[i]
      local name = (e and e.name) or ""
      if name:match("^strings_(%w+)%.lua$") and not (e and e.directory) then
        table.insert(list, name)
      end
    end
    table.sort(list)
  end
  _G.CONFIG_UI.langFiles = list
  local idx = 1
  for i, f in ipairs(list) do
    if f == "strings_en.lua" then
      idx = i; break
    end
  end
  _G.CONFIG_UI.langIndex = idx
else
  _G.CONFIG_UI.langFiles = nil
  _G.CONFIG_UI.langIndex = nil
end

local C = _G.CONFIG_UI
local common = C.common
local config_parse = C.config_parse

local PAD_UP, PAD_DOWN, PAD_CROSS, PAD_CIRCLE, PAD_START = common.PAD_UP, common.PAD_DOWN, common.PAD_CROSS,
    common.PAD_CIRCLE, common.PAD_START
local PAD_L1, PAD_R1 = common.PAD_L1, common.PAD_R1

local function clearPathPickerState(s)
  s.bootKey = nil
  s.pathPickerBootKey = nil
  s.pathPickerReturnState = nil
  s.pathPickerTarget = nil
  s.pathPickerFileExts = nil
  s.pathPickerLockedDevice = nil
  s.pathPickerLockedDeviceStarted = nil
end

local function clearLoadChoiceState(s)
  s.loadChoices = nil
  s.loadAllowCreate = nil
  s.loadPathExists = nil
  s.loadReturnState = nil
end

local function buildMainChoices(main_str)
  local out = {
    main_str.main_freemcboot or "FreeMCBoot",
    main_str.main_freehddboot or "FreeHDBoot",
    main_str.main_osdmenu or "OSDMenu",
    main_str.main_osdmenu_mbr or "OSDMenu MBR",
    main_str.main_hosdmenu or "HOSDMenu",
    main_str.main_ps2bbl_mc or "PS2BBL",
    main_str.main_psxbbl_mc or "PSXBBL",
  }
  if C.config_options and C.config_options.isEgsmUiEnabled and C.config_options.isEgsmUiEnabled() then
    table.insert(out, 6, main_str.main_egsm or "eGSM")
  end
  return out
end

local function isBblContext(context)
  return context == "ps2bbl" or context == "psxbbl"
end

local function nextStateAfterMcSelection(s)
  if isBblContext(s.context) then return "select_config" end
  if s.context == "osdmenu" then return "select_config" end
  return "open"
end

local function getOpenParentState(s)
  if isBblContext(s.context) then
    return "select_config"
  end
  if s.context == "freemcboot" or s.context == "freehddboot" then
    if s.fileType == "freemcboot_cnf" then
      return "select_config"
    end
  end
  if s.context == "osdmenu" then
    if s.fileType == "osdmenu_cnf" or s.fileType == "osdgsm_cnf" then
      return "select_config"
    end
  end
  return "main"
end

local function getSelectConfigSelTable(s)
  if type(s.selectConfigSelByContext) ~= "table" then
    s.selectConfigSelByContext = {}
  end
  return s.selectConfigSelByContext
end

local function getSelectConfigSel(s)
  local t = getSelectConfigSelTable(s)
  local key = s.context or "__none__"
  local sel = t[key]
  if type(sel) ~= "number" then return 1 end
  return math.floor(sel)
end

local function setSelectConfigSel(s, sel)
  local t = getSelectConfigSelTable(s)
  local key = s.context or "__none__"
  t[key] = sel
end

local function resolveContextFileType(s)
  if s.context == "ps2bbl" then return "ps2bbl_ini" end
  if s.context == "psxbbl" then return "psxbbl_ini" end
  return nil
end

local function resolveIniFileType(s)
  local ft = resolveContextFileType(s)
  if ft then return ft end
  if s.fileType == "ps2bbl_ini" or s.fileType == "psxbbl_ini" then
    return s.fileType
  end
  return nil
end

local function initEmptyLinesForFileType(s)
  s.lines = config_parse.parse("")
  if s.fileType == "freemcboot_cnf" and C.config_options.getFreemcbootDefaults then
    for k, v in pairs(C.config_options.getFreemcbootDefaults()) do config_parse.set(s.lines, k, v) end
  elseif s.fileType == "osdmenu_cnf" and C.config_options.getOsdmenuDefaults then
    for k, v in pairs(C.config_options.getOsdmenuDefaults()) do config_parse.set(s.lines, k, v) end
  end
end

local function getPathModuleType(path)
  if not path or path == "" then return nil end
  local p = tostring(path)
  if p:match("^massX:") then return "mx4sio" end
  if p:match("^mass%d*:") then return "usb" end
  if p:match("^mmce%d:") then return "mmce" end
  if p:match("^hdd%d:") or p:match("^pfs%d:/") then return "hdd" end
  return nil
end

local function mapPartitionPathToMountedPfs(path)
  if not path then return nil, nil end
  local raw = tostring(path)
  local part, rest = raw:match("^(hdd%d:[^:]+):pfs:(.*)$")
  if not part then
    -- Accept FMCB-style partition path (hdd0:__sysconf/dir/file) in addition to :pfs: form.
    part, rest = raw:match("^(hdd%d:[^/:]+)(/.*)$")
  end
  if not part then return nil, nil end
  if not rest or rest == "" then rest = "/" end
  if rest:sub(1, 1) ~= "/" then rest = "/" .. rest end
  return part, "pfs0:" .. rest
end

local function beginPathAccess(path)
  local moduleType = getPathModuleType(path)
  if moduleType and System and System.loadModules then
    pcall(System.loadModules, moduleType)
  end
  local part, mapped = mapPartitionPathToMountedPfs(path)
  if part and mapped then
    local mounted = nil
    if System and System.fileXioMount then
      pcall(System.fileXioMount, "pfs0:", part)
      mounted = "pfs0:"
    end
    return mounted, mapped
  end
  local mounted = nil
  if path and path:match("^pfs0:/") and System and System.fileXioMount then
    pcall(System.fileXioMount, "pfs0:", "hdd0:__sysconf")
    mounted = "pfs0:"
  end
  return mounted, path
end

local function endPathAccess(mounted)
  if mounted and System and System.fileXioUmount then
    pcall(System.fileXioUmount, mounted)
  end
end

local function pathExists(path)
  local mounted, accessPath = beginPathAccess(path)
  local ok = common.tryOpen(accessPath or path)
  endPathAccess(mounted)
  return ok
end

local function findExistingPathsWithDeviceAccess(locations)
  local out = {}
  for _, p in ipairs(locations or {}) do
    if p and p ~= "" and pathExists(p) then
      out[#out + 1] = p
    end
  end
  return out
end

local function loadLinesWithDeviceAccess(path)
  local mounted, accessPath = beginPathAccess(path)
  local ok, lines, err = pcall(config_parse.load, accessPath or path)
  endPathAccess(mounted)
  if ok and lines then
    return lines
  end
  if ok then
    return nil, err
  end
  return nil, lines
end

local function setStateAfterLoad(s)
  s.configModified = false
  local isCategorized = (s.fileType == "osdmenu_cnf" or s.fileType == "freemcboot_cnf" or s.fileType == "ps2bbl_ini" or
      s.fileType == "psxbbl_ini")
  if s.fileType == "osdgsm_cnf" then
    s.state = "egsm_editor"
    s.egsmSel, s.egsmScroll = 1, 0
  else
    s.state = "editor"
    s.editorCategoryIdx = isCategorized and 0 or nil
    s.optList = isCategorized and nil or C.config_options[s.fileType]
    s.optSel, s.optScroll = 1, 0
    if not s.optList then s.optList = {} end
  end
  if s.fileType ~= "osdmbr_cnf" then clearPathPickerState(s) end
end

local function runMain(s, pad)
  local main_str = (C.strings and C.strings.main) or {}
  local dt, dlr = common.drawText, s.drawListRow
  local M = common.MARGIN_X
  local H = s.HINT_Y or common.HINT_Y
  local L = s.LINE_H or common.LINE_H
  local MY = s.MARGIN_Y or common.MARGIN_Y
  local sc = s.scaleY or function(y) return y end
  local SE = common.SELECTED_ENTRY

  local egsmEnabled = (C.config_options and C.config_options.isEgsmUiEnabled and C.config_options.isEgsmUiEnabled()) or
      false
  local expectedMainCount = egsmEnabled and 8 or 7
  local egsmIndex = egsmEnabled and 6 or nil
  local ps2bblIndex = egsmEnabled and 7 or 6
  local psxbblIndex = egsmEnabled and 8 or 7
  local function getMainOverlayLogoKey(sel)
    if sel == 1 then return "freemcboot" end
    if sel == 2 then return "freehdboot" end
    if sel == 3 then return "osdmenu" end
    if sel == 4 then return "osdmenu_mbr" end
    if sel == 5 then return "hosdmenu" end
    if egsmEnabled and sel == egsmIndex then return "osdmenu" end
    if sel == ps2bblIndex then return "ps2bbl" end
    if sel == psxbblIndex then return "psxbbl" end
    return nil
  end

  if type(s.main) ~= "table" or #s.main ~= expectedMainCount then
    s.main = buildMainChoices(main_str)
  end
  if s.mainSel < 1 then s.mainSel = 1 end
  if s.mainSel > #s.main then s.mainSel = #s.main end

  -- L1/R1: cycle language (only when not using CWD strings.lua override and more than one lang file)
  if not C.langCycleDisabled and C.langFiles and #C.langFiles > 1 then
    local idx = C.langIndex or 1
    if (pad & PAD_L1) ~= 0 then
      idx = idx - 1
      if idx < 1 then idx = #C.langFiles end
      local okLoad, newStrings = pcall(dofile, "scripts/lang/" .. C.langFiles[idx])
      if okLoad and newStrings and type(newStrings) == "table" then
        C.strings = newStrings
        C.langIndex = idx
        s.main = buildMainChoices(newStrings.main or {})
      end
    elseif (pad & PAD_R1) ~= 0 then
      idx = idx % #C.langFiles + 1
      local okLoad, newStrings = pcall(dofile, "scripts/lang/" .. C.langFiles[idx])
      if okLoad and newStrings and type(newStrings) == "table" then
        C.strings = newStrings
        C.langIndex = idx
        s.main = buildMainChoices(newStrings.main or {})
      end
    end
  end

  if (pad & PAD_UP) ~= 0 and s.mainSel > 1 then
    s.mainSel = s.mainSel - 1
  end
  if (pad & PAD_DOWN) ~= 0 and s.mainSel < #s.main then
    s.mainSel = s.mainSel + 1
  end
  s.mainOverlayLogoKey = getMainOverlayLogoKey(s.mainSel)
  if (pad & PAD_START) ~= 0 and not s.mainExitPrompt then s.mainExitPrompt = true end
  if s.mainExitPrompt then
    local msg = main_str.main_exit_prompt or main_str.main_exit
    local tw = common.calcTextWidth(s.font, msg, 1.1)
    local w = s.w or 640
    local cx = math.floor((w - tw) / 2)
    local cy = math.floor((MY + H) / 2) - math.floor((s.LINE_H or common.LINE_H) / 2)
    dt(s.font, s.drawMode, math.max(M, cx), cy, 1.1, msg, common.WHITE)
    common.drawHintLine(s.font, s.drawMode, M, H, 0.7, main_str.main_exit_hint_items or main_str.circle_back_items, nil,
      common.DIM)
    if (pad & PAD_CROSS) ~= 0 then System.exitToBrowser() end
    if (pad & PAD_CIRCLE) ~= 0 then s.mainExitPrompt = nil end
    return
  end
  dt(s.font, s.drawMode, M, MY, 1.1, main_str.main_title or "", common.WHITE)
  local versionStr = (type(APP_VERSION) == "string" and APP_VERSION ~= "") and APP_VERSION or
      (main_str.version_unknown or "unknown")
  local vw = common.calcTextWidth(s.font, versionStr, 0.75) or (#versionStr * 9)
  local w = s.w or 640
  dt(s.font, s.drawMode, w - M - vw, MY, 0.75, versionStr, common.DIM)
  dt(s.font, s.drawMode, M, MY + sc(22), 0.75, main_str.main_sub or "", common.DIM)
  local hintItems = (not C.langCycleDisabled and C.langFiles and #C.langFiles > 1 and main_str.main_hint_items_with_lang) or
      main_str.main_hint_items
  common.drawHintLine(s.font, s.drawMode, M, H, 0.7, hintItems or {}, nil, common.DIM)
  for i, label in ipairs(s.main) do
    local y = MY + sc(50) + (i - 1) * L
    local col = (i == s.mainSel) and SE or common.GRAY
    dlr(M + 20, y, i == s.mainSel, label, col)
  end
  if (pad & PAD_CROSS) ~= 0 then
    if s.mainSel == 1 then
      s.mainOverlayLogoKey = "freemcboot"
      s.context = "freemcboot"
      s.fileType = "freemcboot_cnf"
      s.chosenMcSlot = nil
      clearLoadChoiceState(s)
      clearPathPickerState(s)
      s.state = "select_config"
    elseif s.mainSel == 2 then
      s.mainOverlayLogoKey = "freehdboot"
      s.context = "freehddboot"
      s.fileType = "freemcboot_cnf"
      s.chosenMcSlot = nil
      clearLoadChoiceState(s)
      clearPathPickerState(s)
      s.state = "select_config"
    elseif s.mainSel == 3 then
      s.mainOverlayLogoKey = "osdmenu"
      s.context = "osdmenu"
      s.fileType = "osdmenu_cnf"
      s.chosenMcSlot = nil
      clearLoadChoiceState(s)
      clearPathPickerState(s)
      s.state = "choose_mc"
    elseif s.mainSel == 4 then
      s.mainOverlayLogoKey = "osdmenu_mbr"
      s.context = "mbr"
      s.fileType = "osdmbr_cnf"
      s.chosenMcSlot = nil
      clearLoadChoiceState(s)
      clearPathPickerState(s)
      s.state = "open"
    elseif s.mainSel == 5 then
      s.mainOverlayLogoKey = "hosdmenu"
      s.context = "hosdmenu"
      s.fileType = "osdmenu_cnf"
      s.chosenMcSlot = nil
      clearLoadChoiceState(s)
      clearPathPickerState(s)
      s.state = "open"
    elseif egsmEnabled and s.mainSel == egsmIndex then
      s.mainOverlayLogoKey = "osdmenu"
      s.context = "osdmenu"
      s.fileType = "osdgsm_cnf"
      s.chosenMcSlot = nil
      clearLoadChoiceState(s)
      clearPathPickerState(s)
      s.state = "choose_mc"
    elseif s.mainSel == ps2bblIndex then
      s.mainOverlayLogoKey = "ps2bbl"
      s.context = "ps2bbl"
      s.fileType = "ps2bbl_ini"
      s.chosenMcSlot = nil
      clearLoadChoiceState(s)
      clearPathPickerState(s)
      s.state = "select_config"
    elseif s.mainSel == psxbblIndex then
      s.mainOverlayLogoKey = "psxbbl"
      s.context = "psxbbl"
      s.fileType = "psxbbl_ini"
      s.chosenMcSlot = nil
      clearLoadChoiceState(s)
      clearPathPickerState(s)
      s.state = "select_config"
    end
  end
end

local function runChooseMc(s, pad)
  local main_str = (C.strings and C.strings.main) or {}
  local dt, dlr = common.drawText, s.drawListRow
  local M = common.MARGIN_X
  local H = s.HINT_Y or common.HINT_Y
  local L = s.LINE_H or common.LINE_H
  local MY = s.MARGIN_Y or common.MARGIN_Y
  local sc = s.scaleY or function(y) return y end
  local SE = common.SELECTED_ENTRY
  local slots = common.getPresentMcSlots()
  if #slots == 0 then
    if s.context == "freemcboot" and s.fileType == "freemcboot_cnf" then
      -- FreeMCBoot can still be loaded/created on mass:/ even when no MC is inserted.
      s.chosenMcSlot = nil
      s.state = "open"
      return
    end
    dt(s.font, s.drawMode, M, MY, 1.1, main_str.no_memory_card, common.WHITE)
    dt(s.font, s.drawMode, M, MY + sc(30), 0.8, main_str.insert_mc, common.GRAY)
    common.drawHintLine(s.font, s.drawMode, M, H, 0.7, main_str.circle_back_items, nil, common.DIM)
    if (pad & PAD_CIRCLE) ~= 0 then s.state = "main" end
  elseif #slots == 1 then
    s.chosenMcSlot = slots[1]
    s.state = nextStateAfterMcSelection(s)
  else
    dt(s.font, s.drawMode, M, MY, 1.1, main_str.select_memory_card, common.WHITE)
    dt(s.font, s.drawMode, M, MY + sc(24), 0.8, main_str.config_card_hint, common.DIM)
    common.drawHintLine(s.font, s.drawMode, M, H, 0.7, main_str.cross_select_circle_back_items, nil, common.DIM)
    if s.mcSel < 1 then s.mcSel = 1 end
    if s.mcSel > #slots then s.mcSel = #slots end
    for i = 1, #slots do
      local y = MY + sc(50) + (i - 1) * L
      local label = (slots[i] == 0 and main_str.memory_card_1_slot) or main_str.memory_card_2_slot
      local col = (i == s.mcSel) and SE or common.WHITE
      dlr(M + 20, y, i == s.mcSel, label, col)
    end
    if (pad & PAD_UP) ~= 0 then
      s.mcSel = s.mcSel - 1; if s.mcSel < 1 then s.mcSel = #slots end
    end
    if (pad & PAD_DOWN) ~= 0 then
      s.mcSel = s.mcSel + 1; if s.mcSel > #slots then s.mcSel = 1 end
    end
    if (pad & PAD_CROSS) ~= 0 then
      s.chosenMcSlot = slots[s.mcSel]
      s.state = nextStateAfterMcSelection(s)
    end
    if (pad & PAD_CIRCLE) ~= 0 then s.state = "main" end
  end
end

local function isVisible(visibility, key)
  if not visibility or not key then return true end
  local v = visibility[key]
  if v == nil then return true end
  return v == true
end

local function appendUniquePath(paths, path)
  if not path or path == "" then return end
  for i = 1, #paths do
    if paths[i] == path then return end
  end
  paths[#paths + 1] = path
end

local function buildBblSourceOptions(iniFileType)
  local dev_str = (C.strings and C.strings.devices) or {}
  local visibility = (C.config_options and C.config_options.getBblPathDeviceVisibility and
      C.config_options.getBblPathDeviceVisibility()) or nil
  local iniName = (iniFileType == "psxbbl_ini") and "PSXBBL.INI" or "PS2BBL.INI"
  local out = {}
  local function addDevice(visKey, label, paths, browseDeviceName, browseDeviceId, browseDeviceType)
    if not isVisible(visibility, visKey) then return end
    local rows = {}
    if type(paths) == "table" then
      for i = 1, #paths do
        appendUniquePath(rows, paths[i])
      end
    else
      appendUniquePath(rows, paths)
    end
    if #rows == 0 then return end
    out[#out + 1] = {
      label = label,
      action = "known_paths",
      paths = rows,
      browseDeviceName = browseDeviceName,
      browseDeviceId = browseDeviceId,
      browseDeviceType = browseDeviceType,
    }
  end
  addDevice("mc", dev_str.memory_card_1 or "Memory Card 1", { "mc0:/SYS-CONF/" .. iniName }, "mc0:")
  addDevice("mc", dev_str.memory_card_2 or "Memory Card 2", { "mc1:/SYS-CONF/" .. iniName }, "mc1:")
  addDevice("mmce", dev_str.mmce_0 or "MMCE in slot 1", { "mmce0:/PS2BBL/PS2BBL.INI" }, "mmce0:", nil, "mmce")
  addDevice("mmce", dev_str.mmce_1 or "MMCE in slot 2", { "mmce1:/PS2BBL/PS2BBL.INI" }, "mmce1:", nil, "mmce")
  addDevice("hdd", dev_str.hdd or "APA-formatted HDD", { "hdd0:__sysconf:pfs:/PS2BBL/CONFIG.INI" }, "hdd0:", nil, "hdd")
  addDevice("usb", dev_str.usb_storage_0 or "USB Mass Storage 1", { "mass:/PS2BBL/CONFIG.INI" }, nil, "usb0", "usb")
  addDevice("usb", dev_str.usb_storage_1 or "USB Mass Storage 2", { "mass1:/PS2BBL/CONFIG.INI" }, nil, "usb1", "usb")
  addDevice("mx4sio", dev_str.mx4sio_sd or "MX4SIO", { "massX:/PS2BBL/CONFIG.INI" }, nil, "mx4sio", "mx4sio")
  return out
end

local function buildFreemcbootSourceOptions(context)
  local dev_str = (C.strings and C.strings.devices) or {}
  local out = {}
  local fileName = (context == "freehddboot") and "FREEHDB.CNF" or "FREEMCB.CNF"

  local function add(label, path, deviceType)
    out[#out + 1] = {
      label = label,
      action = "known_paths",
      paths = { path },
      browseDeviceType = deviceType,
    }
  end

  if context == "freehddboot" then
    add(dev_str.hdd or "APA-formatted HDD", "hdd0:__sysconf/FMCB/FREEHDB.CNF", "hdd")
  end
  add(dev_str.memory_card_1 or "Memory Card 1", "mc0:/SYS-CONF/" .. fileName, "mc")
  add(dev_str.memory_card_2 or "Memory Card 2", "mc1:/SYS-CONF/" .. fileName, "mc")
  add(dev_str.usb_storage_0 or "USB Mass Storage 1", "mass:/" .. fileName, "usb")
  add(dev_str.usb_storage_1 or "USB Mass Storage 2", "mass1:/" .. fileName, "usb")
  return out
end

local function pickUsesHdd(pick)
  if not pick then return false end
  if pick.browseDeviceType == "hdd" then return true end
  local paths = pick.paths or {}
  for i = 1, #paths do
    local p = tostring(paths[i] or "")
    if p:match("^hdd%d:") or p:match("^pfs%d:/") then
      return true
    end
  end
  return false
end

local function applyKnownPathPick(s, pick, main_str, opts)
  if not pick or pick.action ~= "known_paths" then return false end
  opts = opts or {}
  local includeBrowseIni = (opts.includeBrowseIni == true)
  s.loadChoices = {}
  s.loadPathExists = {}
  local paths = pick.paths or {}
  for i = 1, #paths do
    local p = paths[i]
    s.loadChoices[#s.loadChoices + 1] = p
    s.loadPathExists[#s.loadPathExists + 1] = pathExists(p)
  end
  if includeBrowseIni then
    s.loadChoices[#s.loadChoices + 1] = {
      kind = "browse_ini",
      label = main_str.select_config_browse_ini or "Browse CONFIG.INI (CWD)",
      browseDeviceName = pick.browseDeviceName,
      browseDeviceId = pick.browseDeviceId,
      browseDeviceType = pick.browseDeviceType,
    }
    s.loadPathExists[#s.loadPathExists + 1] = false
  end
  s.loadAllowCreate = true
  s.loadSel = 1
  s.loadReturnState = "select_config"
  s.state = "choose_load"
  return true
end

local function runSelectConfig(s, pad)
  local main_str = (C.strings and C.strings.main) or {}
  local path_str = (C.strings and C.strings.path_picker) or {}
  local dt, dlr = common.drawText, s.drawListRow
  local M = common.MARGIN_X
  local H = s.HINT_Y or common.HINT_Y
  local L = s.LINE_H or common.LINE_H
  local MY = s.MARGIN_Y or common.MARGIN_Y
  local sc = s.scaleY or function(y) return y end
  local SE = common.SELECTED_ENTRY

  if s.context == "osdmenu" then
    local options = {
      { label = main_str.select_config_osdmenu_cnf or "OSDMENU.CNF", fileType = "osdmenu_cnf" },
      { label = main_str.select_config_osdgsm_cnf or "OSDGSM.CNF", fileType = "osdgsm_cnf" },
    }
    local sel = getSelectConfigSel(s)
    if sel < 1 then sel = 1 end
    if sel > #options then sel = #options end
    setSelectConfigSel(s, sel)

    dt(s.font, s.drawMode, M, MY, 1.1, main_str.which_file, common.WHITE)
    common.drawHintLine(s.font, s.drawMode, M, H, 0.7, main_str.cross_select_circle_back_items, nil, common.DIM)
    for i, opt in ipairs(options) do
      local y = MY + sc(50) + (i - 1) * L
      local col = (i == sel) and SE or common.GRAY
      dlr(M + 20, y, i == sel, opt.label or "", col)
    end

    if (pad & PAD_UP) ~= 0 then
      sel = sel - 1
      if sel < 1 then sel = #options end
    end
    if (pad & PAD_DOWN) ~= 0 then
      sel = sel + 1
      if sel > #options then sel = 1 end
    end
    setSelectConfigSel(s, sel)

    if (pad & PAD_CROSS) ~= 0 then
      local pick = options[sel]
      if pick and pick.fileType then
        s.fileType = pick.fileType
        clearLoadChoiceState(s)
        clearPathPickerState(s)
        s.state = "open"
        return
      end
    end
    if (pad & PAD_CIRCLE) ~= 0 then
      local slots = (common.getPresentMcSlots and common.getPresentMcSlots()) or {}
      if type(slots) == "table" and #slots > 1 then
        s.state = "choose_mc"
      else
        s.state = "main"
      end
    end
    return
  end

  if s.context == "freemcboot" or s.context == "freehddboot" then
    local options = buildFreemcbootSourceOptions(s.context)
    if s.pendingKnownPathPick then
      local pendingPick = s.pendingKnownPathPick
      s.pendingKnownPathPick = nil
      if applyKnownPathPick(s, pendingPick, main_str) then
        return
      end
    end
    local sel = getSelectConfigSel(s)
    if sel < 1 then sel = 1 end
    if sel > #options then sel = #options end
    setSelectConfigSel(s, sel)

    dt(s.font, s.drawMode, M, MY, 1.1, main_str.which_file, common.WHITE)
    common.drawHintLine(s.font, s.drawMode, M, H, 0.7, main_str.cross_select_circle_back_items, nil, common.DIM)
    for i, opt in ipairs(options) do
      local y = MY + sc(50) + (i - 1) * L
      local col = (i == sel) and SE or common.GRAY
      dlr(M + 20, y, i == sel, opt.label or "", col)
    end
    if (pad & PAD_UP) ~= 0 and sel > 1 then sel = sel - 1 end
    if (pad & PAD_DOWN) ~= 0 and sel < #options then sel = sel + 1 end
    setSelectConfigSel(s, sel)

    if (pad & PAD_CROSS) ~= 0 then
      local pick = options[sel]
      s.fileType = "freemcboot_cnf"
      clearPathPickerState(s)
      if pick and pick.action == "known_paths" then
        if pickUsesHdd(pick) and not s.hddReady then
          s.pendingKnownPathPick = pick
          s.initHddSuccessState = "select_config"
          s.initHddCancelState = "select_config"
          s.state = "initHdd"
          s.initHddPhase = "load"
          return
        end
        applyKnownPathPick(s, pick, main_str)
      end
    end

    if (pad & PAD_CIRCLE) ~= 0 then
      s.state = "main"
    end
    return
  end

  local iniFileType = resolveIniFileType(s)
  if iniFileType ~= "ps2bbl_ini" and iniFileType ~= "psxbbl_ini" then
    s.state = "open"
    return
  end

  local options = buildBblSourceOptions(iniFileType)
  if s.pendingKnownPathPick then
    local pendingPick = s.pendingKnownPathPick
    s.pendingKnownPathPick = nil
    if applyKnownPathPick(s, pendingPick, main_str, { includeBrowseIni = true }) then
      return
    end
  end
  local sel = getSelectConfigSel(s)
  if sel < 1 then sel = 1 end
  if sel > #options then sel = #options end
  setSelectConfigSel(s, sel)

  dt(s.font, s.drawMode, M, MY, 1.1, main_str.which_file, common.WHITE)
  if path_str.bbl_build_device_hint then
    local bblName = (iniFileType == "psxbbl_ini") and "PSXBBL" or "PS2BBL"
    local hint = tostring(path_str.bbl_build_device_hint):gsub("PS%?BBL", bblName)
    if common.truncateTextToWidth then
      hint = common.truncateTextToWidth(s.font, hint, (s.w or 640) - (M * 2), 0.55)
    end
    dt(s.font, s.drawMode, M, MY + sc(20), 0.55, hint, common.DIM)
  end
  common.drawHintLine(s.font, s.drawMode, M, H, 0.7, main_str.cross_select_circle_back_items, nil, common.DIM)
  for i, opt in ipairs(options) do
    local y = MY + sc(50) + (i - 1) * L
    local col = (i == sel) and SE or common.GRAY
    dlr(M + 20, y, i == sel, opt.label or "", col)
  end
  if (pad & PAD_UP) ~= 0 and sel > 1 then sel = sel - 1 end
  if (pad & PAD_DOWN) ~= 0 and sel < #options then sel = sel + 1 end
  setSelectConfigSel(s, sel)

  if (pad & PAD_CROSS) ~= 0 then
    local pick = options[sel]
    s.fileType = iniFileType
    clearPathPickerState(s)
    if pick and pick.action == "known_paths" then
      if pickUsesHdd(pick) and not s.hddReady then
        s.pendingKnownPathPick = pick
        s.initHddSuccessState = "select_config"
        s.initHddCancelState = "select_config"
        s.state = "initHdd"
        s.initHddPhase = "load"
        return
      end
      applyKnownPathPick(s, pick, main_str, { includeBrowseIni = true })
    end
  end

  if (pad & PAD_CIRCLE) ~= 0 then
    s.state = "main"
  end
end

local INIT_HDD_PROBE_FRAMES = 12    -- probe hdd0: every ~200ms at 60fps
local INIT_HDD_TIMEOUT_FRAMES = 180 -- 3s at 60fps

local function runInitHdd(s, pad)
  local main_str = (C.strings and C.strings.main) or {}
  local dt = common.drawText
  local M = common.MARGIN_X
  local MY = s.MARGIN_Y or common.MARGIN_Y
  local H = s.HINT_Y or common.HINT_Y
  local sc = s.scaleY or function(y) return y end
  local phase = s.initHddPhase or "load"

  if phase == "load" then
    local w = s.w or 640
    local h = s.h or 448
    local tw1 = common.calcTextWidth(s.font, main_str.init_hdd_title, 1.1)
    local tw2 = common.calcTextWidth(s.font, main_str.init_hdd_sub, 0.85)
    local cx1 = math.floor((w - tw1) / 2)
    local cx2 = math.floor((w - tw2) / 2)
    local lineH = sc(22)
    local gap = sc(10)
    local blockH = lineH + gap + lineH
    local titleY = math.floor((h - blockH) / 2)
    local descY = titleY + lineH + gap
    dt(s.font, s.drawMode, math.max(M, cx1), titleY, 1.1, main_str.init_hdd_title, common.WHITE)
    dt(s.font, s.drawMode, math.max(M, cx2), descY, 0.85, main_str.init_hdd_sub, common.DIM)
    Screen.flip()
    Screen.waitVblankStart()
    if System.loadModules then System.loadModules("hdd") end
    s.initHddPhase = "wait"
    s.initHddFrames = 0
    return
  end

  if phase == "wait" then
    s.initHddFrames = (s.initHddFrames or 0) + 1
    if s.initHddFrames > 0 and s.initHddFrames % INIT_HDD_PROBE_FRAMES == 0 then
      if common.isHddPresent() then
        s.hddReady = true
        s.hddNotFound = nil
        s.state = s.initHddSuccessState or "open"
        s.initHddPhase = nil
        s.initHddFrames = nil
        s.initHddSuccessState = nil
        s.initHddCancelState = nil
        return
      end
    end
    if s.initHddFrames >= INIT_HDD_TIMEOUT_FRAMES then
      s.initHddPhase = "timeout"
      s.initHddFrames = nil
      s.hddNotFound = true
    else
      -- Keep showing init message (same as load phase); "Waiting for device drivers" is only for path selectors
      local w = s.w or 640
      local h = s.h or 448
      local tw1 = common.calcTextWidth(s.font, main_str.init_hdd_title, 1.1)
      local tw2 = common.calcTextWidth(s.font, main_str.init_hdd_sub, 0.85)
      local cx1 = math.floor((w - tw1) / 2)
      local cx2 = math.floor((w - tw2) / 2)
      local lineH = sc(22)
      local gap = sc(10)
      local blockH = lineH + gap + lineH
      local titleY = math.floor((h - blockH) / 2)
      local descY = titleY + lineH + gap
      dt(s.font, s.drawMode, math.max(M, cx1), titleY, 1.1, main_str.init_hdd_title, common.WHITE)
      dt(s.font, s.drawMode, math.max(M, cx2), descY, 0.85, main_str.init_hdd_sub, common.DIM)
      common.drawHintLine(s.font, s.drawMode, M, H, 0.7, main_str.circle_back_items, nil, common.DIM)
      return
    end
  end

  if phase == "timeout" then
    local msg = main_str.hdd_not_found
    local tw = common.calcTextWidth(s.font, msg, 1.1)
    local w = s.w or 640
    local cx = math.floor((w - tw) / 2)
    local cy = math.floor((MY + H) / 2) - math.floor((s.LINE_H or common.LINE_H) / 2)
    dt(s.font, s.drawMode, math.max(M, cx), cy, 1.1, msg, common.WHITE)
    common.drawHintLine(s.font, s.drawMode, M, H, 0.7, main_str.circle_back_items, nil, common.DIM)
    if (pad & PAD_CIRCLE) ~= 0 then
      s.state = s.initHddCancelState or "main"
      s.initHddPhase = nil
      s.initHddSuccessState = nil
      s.initHddCancelState = nil
      s.pendingKnownPathPick = nil
    end
  end
end

local function runOpen(s, pad)
  local main_str = (C.strings and C.strings.main) or {}
  if (s.context == "hosdmenu" or s.context == "mbr") and not s.hddReady then
    s.state = "initHdd"
    s.initHddPhase = "load"
    s.initHddSuccessState = "open"
    s.initHddCancelState = "main"
    s.pendingKnownPathPick = nil
    return
  end
  local dt = common.drawText
  local M = common.MARGIN_X
  local H = s.HINT_Y or common.HINT_Y
  local MY = s.MARGIN_Y or common.MARGIN_Y
  local sc = s.scaleY or function(y) return y end
  if s.openExplicitPath and s.currentPath and s.currentPath ~= "" then
    if not pathExists(s.currentPath) then
      initEmptyLinesForFileType(s)
      s.openExplicitPath = nil
      clearLoadChoiceState(s)
      setStateAfterLoad(s)
      return
    end
    local loaded = loadLinesWithDeviceAccess(s.currentPath)
    if loaded then
      s.lines = loaded
      s.openExplicitPath = nil
      clearLoadChoiceState(s)
      setStateAfterLoad(s)
      return
    end
    dt(s.font, s.drawMode, M, MY + sc(60), common.FONT_SCALE, main_str.failed_to_load .. tostring(s.currentPath),
      common.GRAY)
    common.drawHintLine(s.font, s.drawMode, M, H, 0.7, main_str.cross_back_items, nil, common.DIM)
    if (pad & PAD_CROSS) ~= 0 then
      s.openExplicitPath = nil
      clearLoadChoiceState(s)
      s.state = getOpenParentState(s)
    end
    return
  end
  local locations = C.config_options.getLocations(s.context, s.fileType, s.chosenMcSlot)
  if s.fileType == "freemcboot_cnf" and (s.context == "freemcboot" or s.context == "freehddboot") and
      type(locations) == "table" and #locations > 0 then
    local prevPath = nil
    if s.loadChoices and s.loadSel and s.loadChoices[s.loadSel] then
      prevPath = s.loadChoices[s.loadSel]
    end
    s.loadChoices = {}
    s.loadPathExists = {}
    for i = 1, #locations do
      local p = locations[i]
      s.loadChoices[#s.loadChoices + 1] = p
      s.loadPathExists[#s.loadPathExists + 1] = pathExists(p)
    end
    if prevPath then
      local foundIdx = nil
      for i = 1, #s.loadChoices do
        if s.loadChoices[i] == prevPath then
          foundIdx = i
          break
        end
      end
      s.loadSel = foundIdx or s.loadSel or 1
    else
      s.loadSel = s.loadSel or 1
    end
    s.loadAllowCreate = true
    s.loadReturnState = getOpenParentState(s)
    s.state = "choose_load"
    return
  end
  local existing = findExistingPathsWithDeviceAccess(locations)
  if #existing == 0 then
    if C.config_options and C.config_options.getDefaultLocation then
      s.currentPath = C.config_options.getDefaultLocation(s.context, s.fileType, s.chosenMcSlot)
    else
      s.currentPath = locations[1]
    end
    if not s.currentPath then
      dt(s.font, s.drawMode, M, MY + sc(60), common.FONT_SCALE, main_str.no_location, common.GRAY)
      common.drawHintLine(s.font, s.drawMode, M, H, 0.7, main_str.cross_back_items, nil, common.DIM)
      if (pad & PAD_CROSS) ~= 0 then s.state = getOpenParentState(s) end
    else
      initEmptyLinesForFileType(s)
      setStateAfterLoad(s)
    end
  elseif #existing == 1 then
    s.currentPath = existing[1]
    local loaded = loadLinesWithDeviceAccess(s.currentPath)
    if not loaded then
      dt(s.font, s.drawMode, M, MY + sc(60), common.FONT_SCALE, main_str.failed_to_load .. tostring(s.currentPath),
        common.GRAY)
      common.drawHintLine(s.font, s.drawMode, M, H, 0.7, main_str.cross_back_items, nil, common.DIM)
      if (pad & PAD_CROSS) ~= 0 then s.state = getOpenParentState(s) end
    else
      s.lines = loaded
      setStateAfterLoad(s)
    end
  else
    local prevPath = nil
    if s.loadChoices and s.loadSel and s.loadChoices[s.loadSel] then
      prevPath = s.loadChoices[s.loadSel]
    end
    s.loadChoices = existing
    if prevPath then
      local foundIdx = nil
      for i, p in ipairs(existing) do
        if p == prevPath then
          foundIdx = i
          break
        end
      end
      s.loadSel = foundIdx or s.loadSel or 1
    else
      s.loadSel = s.loadSel or 1
    end
    s.loadAllowCreate = nil
    s.loadPathExists = nil
    s.loadReturnState = getOpenParentState(s)
    s.state = "choose_load"
  end
end

local function runChooseLoad(s, pad)
  local main_str = (C.strings and C.strings.main) or {}
  local dev_str = (C.strings and C.strings.devices) or {}
  local dt, dlr = common.drawText, s.drawListRow
  local M = common.MARGIN_X
  local H = s.HINT_Y or common.HINT_Y
  local L = s.LINE_H or common.LINE_H
  local MY = s.MARGIN_Y or common.MARGIN_Y
  local sc = s.scaleY or function(y) return y end
  local SE = common.SELECTED_ENTRY
  local choices = s.loadChoices or {}
  local allowCreate = (s.loadAllowCreate == true)
  if s.loadSel < 1 then s.loadSel = 1 end
  if s.loadSel > #choices then s.loadSel = #choices end
  local maxVis = common.MAX_VISIBLE
  local total = #choices
  local maxLabelW = (s.w or 640) - (M + 24) - M
  local scroll = 0
  if total > maxVis then
    scroll = s.loadSel - math.floor(maxVis / 2)
    scroll = math.max(0, math.min(scroll, total - maxVis))
  end
  for i = scroll + 1, math.min(scroll + maxVis, total) do
    local idx = i
    local choice = choices[idx]
    local isBrowseIni = (type(choice) == "table" and choice.kind == "browse_ini")
    local p = (type(choice) == "string") and choice or ""
    local label = nil
    if isBrowseIni then
      label = choice.label or (main_str.select_config_browse_ini or "Browse CONFIG.INI (CWD)")
    elseif allowCreate then
      label = p
    elseif s.fileType == "freemcboot_cnf" then
      label = p
    else
      label = (p:match("^mc0:") and dev_str.memory_card_1) or (p:match("^mc1:") and dev_str.memory_card_2) or
          (p:match("^massX:") and dev_str.mx4sio_sd) or
          ((p:match("^mass:") or p:match("^mass%d:")) and dev_str.usb_storage_0) or
          (p:match("^mmce0:") and dev_str.mmce_0) or
          (p:match("^mmce1:") and dev_str.mmce_1) or
          (p:match("^hdd0:") and dev_str.hdd) or
          (p:match("^pfs0:") and dev_str.hdd) or
          p:sub(1, 40)
    end
    if common.fitListRowText then
      label = common.fitListRowText(s, "choose_load_row_" .. tostring(i), s.font, label, maxLabelW, common.FONT_SCALE,
        idx == s.loadSel)
    elseif common.truncateTextToWidth then
      label = common.truncateTextToWidth(s.font, label or "", maxLabelW, common.FONT_SCALE)
    end
    local y = MY + sc(50) + (i - scroll - 1) * L
    local col = (idx == s.loadSel) and SE or common.WHITE
    dlr(M + 20, y, idx == s.loadSel, label, col)
  end
  common.drawHintLine(s.font, s.drawMode, M, H, 0.7, main_str.cross_load_circle_back_items, nil, common.DIM)
  if (pad & PAD_UP) ~= 0 then
    s.loadSel = s.loadSel - 1; if s.loadSel < 1 then s.loadSel = #choices end
  end
  if (pad & PAD_DOWN) ~= 0 then
    s.loadSel = s.loadSel + 1; if s.loadSel > #choices then s.loadSel = 1 end
  end
  if (pad & PAD_CROSS) ~= 0 and #choices > 0 then
    local chosen = choices[s.loadSel]
    if type(chosen) == "table" and chosen.kind == "browse_ini" then
      local allDevices = (C.file_selector and C.file_selector.getDevices and C.file_selector.getDevices("config_ini")) or {}
      local targetDevice = nil
      for i = 1, #allDevices do
        local d = allDevices[i]
        if chosen.browseDeviceId and d and d.deviceId == chosen.browseDeviceId then
          targetDevice = d
          break
        end
        if chosen.browseDeviceName and d and d.name == chosen.browseDeviceName then
          targetDevice = d
          break
        end
      end
      if not targetDevice and #allDevices == 1 then
        targetDevice = allDevices[1]
      end
      if not targetDevice and (chosen.browseDeviceName or chosen.browseDeviceId) then
        targetDevice = {
          name = chosen.browseDeviceName,
          deviceId = chosen.browseDeviceId,
          deviceType = chosen.browseDeviceType,
          desc = chosen.label,
        }
      end
      s.pathPickerContext = "config_ini"
      s.pathPickerTarget = "config_open"
      s.pathPickerFileExts = { ".ini" }
      s.pathPickerSub = "device"
      s.pathPickerLockedDevice = targetDevice
      s.pathPickerLockedDeviceStarted = nil
      s.pathList = targetDevice and { targetDevice } or {}
      s.pathPickerSel = 1
      s.pathPickerScroll = 0
      s.pathBrowsePath = nil
      s.pathPickerReturnState = "choose_load"
      s.state = "path_picker"
      return
    end

    s.currentPath = chosen
    local exists = allowCreate and ((type(s.loadPathExists) == "table" and s.loadPathExists[s.loadSel]) or pathExists(s.currentPath))
    if allowCreate and not exists then
      initEmptyLinesForFileType(s)
      setStateAfterLoad(s)
      clearLoadChoiceState(s)
    else
      local loaded = loadLinesWithDeviceAccess(s.currentPath)
      if loaded then
        s.lines = loaded
        setStateAfterLoad(s)
        clearLoadChoiceState(s)
      end
    end
  end
  if (pad & PAD_CIRCLE) ~= 0 then
    s.state = s.loadReturnState or "select_config"
    clearLoadChoiceState(s)
  end
end

return {
  runMain = runMain,
  runChooseMc = runChooseMc,
  runSelectConfig = runSelectConfig,
  runInitHdd = runInitHdd,
  runOpen = runOpen,
  runChooseLoad = runChooseLoad,
}
