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
  if s.fileType == "osdmenu_cnf" and C.config_options.getOsdmenuDefaults then
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
  local part, rest = tostring(path):match("^(hdd%d:[^:]+):pfs:(.*)$")
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
  local isCategorized = (s.fileType == "osdmenu_cnf" or s.fileType == "ps2bbl_ini" or s.fileType == "psxbbl_ini")
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
        s.main = {
          (newStrings.main and newStrings.main.main_ps2bbl_mc) or "PS2BBL",
          (newStrings.main and newStrings.main.main_psxbbl_mc) or "PSXBBL",
        }
      end
    elseif (pad & PAD_R1) ~= 0 then
      idx = idx % #C.langFiles + 1
      local okLoad, newStrings = pcall(dofile, "scripts/lang/" .. C.langFiles[idx])
      if okLoad and newStrings and type(newStrings) == "table" then
        C.strings = newStrings
        C.langIndex = idx
        s.main = {
          (newStrings.main and newStrings.main.main_ps2bbl_mc) or "PS2BBL",
          (newStrings.main and newStrings.main.main_psxbbl_mc) or "PSXBBL",
        }
      end
    end
  end

  if (pad & PAD_UP) ~= 0 and s.mainSel > 1 then
    s.mainSel = s.mainSel - 1
  end
  if (pad & PAD_DOWN) ~= 0 and s.mainSel < #s.main then
    s.mainSel = s.mainSel + 1
  end
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
      s.context = "ps2bbl"
      s.fileType = "ps2bbl_ini"
      s.chosenMcSlot = nil
      clearPathPickerState(s)
      s.state = "choose_mc"
    elseif s.mainSel == 2 then
      s.context = "psxbbl"
      s.fileType = "psxbbl_ini"
      s.chosenMcSlot = nil
      clearPathPickerState(s)
      s.state = "choose_mc"
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
    dt(s.font, s.drawMode, M, MY, 1.1, main_str.no_memory_card, common.WHITE)
    dt(s.font, s.drawMode, M, MY + sc(30), 0.8, main_str.insert_mc, common.GRAY)
    common.drawHintLine(s.font, s.drawMode, M, H, 0.7, main_str.circle_back_items, nil, common.DIM)
    if (pad & PAD_CIRCLE) ~= 0 then s.state = "main" end
  elseif #slots == 1 then
    s.chosenMcSlot = slots[1]
    s.state = "select_config"
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
      s.state = "select_config"
    end
    if (pad & PAD_CIRCLE) ~= 0 then s.state = "main" end
  end
end

local function runSelectConfig(s, pad)
  local main_str = (C.strings and C.strings.main) or {}
  local dt, dlr = common.drawText, s.drawListRow
  local M = common.MARGIN_X
  local H = s.HINT_Y or common.HINT_Y
  local L = s.LINE_H or common.LINE_H
  local MY = s.MARGIN_Y or common.MARGIN_Y
  local sc = s.scaleY or function(y) return y end
  local SE = common.SELECTED_ENTRY
  local iniFileType = resolveIniFileType(s)
  local iniLabel = nil
  if iniFileType == "ps2bbl_ini" then
    iniLabel = main_str.select_config_ps2bbl_ini or "PS2BBL.INI"
  elseif iniFileType == "psxbbl_ini" then
    iniLabel = main_str.select_config_psxbbl_ini or "PSXBBL.INI"
  end
  if not iniFileType or not iniLabel then
    s.state = "main"
    s.chosenMcSlot = nil
    return
  end
  local showEgsm = (C.config_options.isEgsmUiEnabled and C.config_options.isEgsmUiEnabled()) or false
  local options = { { label = iniLabel, fileType = iniFileType, action = "open_known" } }
  if iniFileType == "ps2bbl_ini" or iniFileType == "psxbbl_ini" then
    options[#options + 1] = {
      label = main_str.select_config_browse_ini or "Browse config file (.INI)",
      fileType = iniFileType,
      action = "browse_ini",
    }
  end
  if showEgsm then
    options[#options + 1] = { label = main_str.select_config_osdgsm_cnf or "OSDGSM.CNF", fileType = "osdgsm_cnf" }
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
    dlr(M + 20, y, i == sel, opt.label, col)
  end
  if (pad & PAD_UP) ~= 0 and sel > 1 then sel = sel - 1 end
  if (pad & PAD_DOWN) ~= 0 and sel < #options then sel = sel + 1 end
  setSelectConfigSel(s, sel)
  if (pad & PAD_CROSS) ~= 0 then
    local pick = options[sel]
    s.fileType = pick.fileType
    clearPathPickerState(s)
    if pick.action == "browse_ini" then
      s.pathPickerContext = "config_ini"
      s.pathPickerTarget = "config_open"
      s.pathPickerFileExts = { ".ini" }
      s.pathPickerSub = "device"
      s.pathList = (C.file_selector and C.file_selector.getDevices and C.file_selector.getDevices("config_ini")) or {}
      s.pathPickerSel = 1
      s.pathPickerScroll = 0
      s.pathBrowsePath = nil
      s.pathPickerReturnState = "select_config"
      s.state = "path_picker"
    else
      s.openExplicitPath = nil
      s.state = "open"
    end
  end
  if (pad & PAD_CIRCLE) ~= 0 then
    local slots = common.getPresentMcSlots()
    if #slots <= 1 then
      s.state = "main"
      s.chosenMcSlot = nil
    else
      s.state = "choose_mc"
    end
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
        s.state = "select_config"
        s.initHddPhase = nil
        s.initHddFrames = nil
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
      s.state = "main"
      s.initHddPhase = nil
    end
  end
end

local function runOpen(s, pad)
  local main_str = (C.strings and C.strings.main) or {}
  if (s.context == "hosdmenu" or s.context == "mbr") and not s.hddReady then
    s.state = "initHdd"
    s.initHddPhase = "load"
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
      setStateAfterLoad(s)
      return
    end
    local loaded = loadLinesWithDeviceAccess(s.currentPath)
    if loaded then
      s.lines = loaded
      s.openExplicitPath = nil
      setStateAfterLoad(s)
      return
    end
    dt(s.font, s.drawMode, M, MY + sc(60), common.FONT_SCALE, main_str.failed_to_load .. tostring(s.currentPath),
      common.GRAY)
    common.drawHintLine(s.font, s.drawMode, M, H, 0.7, main_str.cross_back_items, nil, common.DIM)
    if (pad & PAD_CROSS) ~= 0 then
      s.openExplicitPath = nil
      s.state = "select_config"
    end
    return
  end
  local locations = C.config_options.getLocations(s.context, s.fileType, s.chosenMcSlot)
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
      if (pad & PAD_CROSS) ~= 0 then s.state = "select_config" end
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
      if (pad & PAD_CROSS) ~= 0 then s.state = "select_config" end
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
  if s.loadSel < 1 then s.loadSel = 1 end
  if s.loadSel > #choices then s.loadSel = #choices end
  local maxVis = common.MAX_VISIBLE
  local total = #choices
  local scroll = 0
  if total > maxVis then
    scroll = s.loadSel - math.floor(maxVis / 2)
    scroll = math.max(0, math.min(scroll, total - maxVis))
  end
  for i = scroll + 1, math.min(scroll + maxVis, total) do
    local idx = i
    local p = choices[idx] or ""
    local label = (p:match("^mc0:") and dev_str.memory_card_1) or (p:match("^mc1:") and dev_str.memory_card_2) or
        (p:match("^massX:") and dev_str.mx4sio_sd) or
        ((p:match("^mass:") or p:match("^mass%d:")) and dev_str.usb_storage_0) or
        (p:match("^mmce0:") and dev_str.mmce_0) or
        (p:match("^mmce1:") and dev_str.mmce_1) or
        (p:match("^hdd0:") and dev_str.hdd) or
        (p:match("^pfs0:") and dev_str.hdd) or
        p:sub(1, 40)
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
    s.currentPath = choices[s.loadSel]
    local loaded = loadLinesWithDeviceAccess(s.currentPath)
    if loaded then
      s.lines = loaded
      setStateAfterLoad(s)
      s.loadChoices = nil
    end
  end
  if (pad & PAD_CIRCLE) ~= 0 then
    s.state = "select_config"; s.loadChoices = nil
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
