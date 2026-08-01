--[[ Editor state: config option list and category list (OSDMENU). ]]

local actions_menu = dofile("scripts/scenes/actions_menu.lua")

local function formatTimerSeconds(msText, unitSingular, unitPlural)
  local ms = tonumber(msText or "")
  if not ms then return msText end
  local singular = unitSingular or "second"
  local plural = unitPlural or "seconds"
  local sec = math.max(0, math.floor((ms + 500) / 1000))
  local unit = (sec == 1) and singular or plural
  local secText = string.format("%3d", sec)
  return secText .. " " .. unit
end

local function formatArgCount(n)
  local count = tonumber(n) or 0
  if count == 1 then return "(1 arg)" end
  return "(" .. tostring(count) .. " args)"
end

local function trimPathValue(pathVal)
  return tostring(pathVal or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function formatLaunchPathSummary(_, paths)
  local activePaths = {}
  for i = 1, #(paths or {}) do
    local item = paths[i]
    local value = type(item) == "table" and item.value or item
    local disabled = type(item) == "table" and item.disabled == true
    if not disabled and trimPathValue(value) ~= "" then
      activePaths[#activePaths + 1] = value
    end
  end

  if #activePaths <= 0 then
    return (_.common_str and _.common_str.empty) or "(empty)"
  end
  if #activePaths == 1 then
    if _.common and _.common.formatDisplayPathWithCommands then
      return _.common.formatDisplayPathWithCommands(_, activePaths[1])
    end
    return tostring(activePaths[1] or "")
  end
  return tostring(#activePaths) .. " paths"
end

local function getOsdmbrHotkeyPadName(key)
  local commonRef = _G and _G.CONFIG_UI and _G.CONFIG_UI.common
  if commonRef and commonRef.bootKeyToPadName then
    return commonRef.bootKeyToPadName(key)
  end
  if key == "boot_start" then return "start" end
  if key == "boot_select" then return "select" end
  if key == "boot_triangle" then return "triangle" end
  if key == "boot_circle" then return "circle" end
  if key == "boot_cross" then return "cross" end
  if key == "boot_square" then return "square" end
  if key == "boot_up" then return "up" end
  if key == "boot_down" then return "down" end
  if key == "boot_left" then return "left" end
  if key == "boot_right" then return "right" end
  if key == "boot_l1" then return "l1" end
  if key == "boot_l2" then return "l2" end
  if key == "boot_r1" then return "r1" end
  if key == "boot_r2" then return "r2" end
  return nil
end

local function isOsdmbrToggleableBootKey(key)
  return type(key) == "string" and key:match("^boot_") ~= nil and key ~= "boot_auto"
end

local function osdmbrBootKeyHasEntries(ctx, _, key)
  if not (ctx and _ and key) then return false end
  local getBootPathEntries = _.config_parse and _.config_parse.getBootPathEntries
  if getBootPathEntries then
    local paths = getBootPathEntries(ctx.lines, key) or {}
    if #paths > 0 then return true end
  end
  local getBootArgEntries = _.config_parse and _.config_parse.getBootArgEntries
  if getBootArgEntries then
    local args = getBootArgEntries(ctx.lines, key) or {}
    if #args > 0 then return true end
  end
  return false
end

local function getEditorBackState(ctx)
  if ctx and type(ctx.editorBackStateOverride) == "string" and ctx.editorBackStateOverride ~= "" then
    return ctx.editorBackStateOverride
  end
  local context = ctx and ctx.context or nil
  local fileType = ctx and ctx.fileType or nil
  local commonRef = ctx and ctx._ and ctx._.common or nil
  if commonRef and commonRef.getEditorBackState then
    return commonRef.getEditorBackState(context, fileType, commonRef.getPresentMcSlots)
  end
  return "main"
end

local R3_COLOR_KEY_TO_FIELD = {
  cross = "PAD_LABEL_CROSS",
  square = "PAD_LABEL_SQUARE",
  triangle = "PAD_LABEL_TRIANGLE",
  circle = "PAD_LABEL_CIRCLE",
  selected = "SELECTED_COLOR",
  selected_dim = "SELECTED_DIM_COLOR",
  unselected = "UNSELECTED_COLOR",
  dim = "DIM_COLOR",
  background = "BACKGROUND_COLOR",
}

local R3_BUTTON_COLOR_PRESET = {
  cross = "365172",
  square = "AF4B6D",
  triangle = "358D4E",
  circle = "933624",
  selected = "365172",
  selected_dim = "003250",
  unselected = "C8C8C8",
  dim = "606060",
  background = "000000",
}

local R3_DEFAULT_COLOR_PRESET = {
  cross = "606060",
  square = "606060",
  triangle = "606060",
  circle = "606060",
  selected = "0072A0",
  selected_dim = "003250",
  unselected = "C8C8C8",
  dim = "606060",
  background = "000000",
}

local function parseR3HexColor(raw)
  local value = tostring(raw or "")
  local trimmed = value:gsub("^%s+", ""):gsub("%s+$", "")
  if not trimmed:match("^[%x][%x][%x][%x][%x][%x]$") then
    return nil
  end
  local r = tonumber(trimmed:sub(1, 2), 16) or 0
  local g = tonumber(trimmed:sub(3, 4), 16) or 0
  local b = tonumber(trimmed:sub(5, 6), 16) or 0
  return r, g, b, 0x80
end

local function formatR3HexColor(r, g, b)
  local function toByte(v)
    local n = tonumber(v) or 0
    if n < 0 then n = 0 end
    if n > 255 then n = 255 end
    return math.floor(n + 0.5)
  end
  return string.format("%02X%02X%02X", toByte(r), toByte(g), toByte(b))
end

local function isR3ConfiguratorFile(ctx)
  return ctx and ctx.fileType == "r3configurator_cnf"
end

local function isBlockedSceneTransitionEnumValue(ctx, opt, value)
  return false
end

local function getCurrentSceneTransitionType(ctx, _)
  if not (ctx and _) then return "cut" end
  local t = (_.config_parse and _.config_parse.get and _.config_parse.get(ctx.lines, "scene_transition")) or "cut"
  if tostring(t or "") == "" then
    t = "cut"
  end
  if _.common and _.common.normalizeSceneTransitionType then
    return _.common.normalizeSceneTransitionType(t)
  end
  return tostring(t or "cut"):lower():gsub("^%s+", ""):gsub("%s+$", "")
end

local function isTemporarilyDisabledEditorOption(ctx, _, opt)
  if not isR3ConfiguratorFile(ctx) then return false end
  local key = tostring(opt and opt.key or "")
  if key == "scene_transition_frames" then
    return getCurrentSceneTransitionType(ctx, _) == "cut"
  end
  return false
end

local function findEnumIndex(enumVals, value)
  local list = enumVals or {}
  for i, v in ipairs(list) do
    if v == value then return i end
  end
  return 0
end

local function cycleEnumIndex(ctx, opt, currentIndex, step, allowUnset)
  local values = opt and opt.enumVals or nil
  local count = values and #values or 0
  if count <= 0 then return currentIndex end
  local minIdx = allowUnset and 0 or 1
  local idx = tonumber(currentIndex) or minIdx
  local dir = (tonumber(step) or 0) < 0 and -1 or 1
  local span = count + (allowUnset and 1 or 0)
  for _scan = 1, span do
    idx = idx + dir
    if idx < minIdx then idx = count end
    if idx > count then idx = minIdx end
    if idx == 0 then
      return idx
    end
    if not isBlockedSceneTransitionEnumValue(ctx, opt, values[idx]) then
      return idx
    end
  end
  return currentIndex
end

local function resolveOptionDescription(ctx, _, opt)
  if not opt then return "" end
  local key = opt.key
  local textDef = (_.strings and _.strings.options and key and _.strings.options[key]) or nil
  if opt.optType == "enum" and key then
    local raw = (_.config_parse and _.config_parse.get and _.config_parse.get(ctx.lines, key)) or opt.default or ""
    local enumDescMap = (textDef and textDef.enumDescMap) or opt.enumDescMap
    if type(enumDescMap) == "table" then
      local rawKey = tostring(raw or "")
      local desc = enumDescMap[rawKey] or enumDescMap[rawKey:lower()] or enumDescMap[rawKey:upper()]
      if desc ~= nil then return desc end
    end
  end
  return (textDef and textDef.desc) or opt.desc or ""
end

local function resolveOptionEnumDisplay(_, opt, raw)
  local rawText = tostring(raw or "")
  if rawText == "" then return rawText end
  local key = opt and opt.key or nil
  local textDef = (_.strings and _.strings.options and key and _.strings.options[key]) or nil
  local enumDisplayMap = (textDef and textDef.enumDisplayMap) or (opt and opt.enumDisplayMap)
  if type(enumDisplayMap) == "table" then
    return enumDisplayMap[rawText] or enumDisplayMap[rawText:lower()] or enumDisplayMap[rawText:upper()] or rawText
  end
  return rawText
end

local function isDeviceAbsolutePath(path)
  local p = tostring(path or "")
  if p == "" then return false end
  if p:match("^[%w_]+:") then return true end
  if p:sub(1, 1) == "/" then return true end
  return false
end

local function getEditorDisplayPath(ctx, rawPath)
  local path = tostring(rawPath or "")
  local cache = ctx and ctx.editorDisplayPathCache or nil
  if cache and cache.rawPath == path then
    return cache.value or path
  end

  local out = path
  if path ~= "" and not isDeviceAbsolutePath(path) then
    local rel = path
    if rel:sub(1, 2) == "./" then
      rel = rel:sub(3)
    end
    if System and System.currentDirectory then
      local ok, cwd = pcall(System.currentDirectory)
      local base = ok and tostring(cwd or "") or ""
      if base ~= "" then
        if base:sub(-1) ~= "/" then
          base = base .. "/"
        end
        out = base .. rel
      end
    end
  end
  if ctx and ctx._ and ctx._.common and ctx._.common.normalizePathForDisplay then
    out = ctx._.common.normalizePathForDisplay(out)
  end

  if ctx then
    ctx.editorDisplayPathCache = {
      rawPath = path,
      value = out,
    }
  end
  return out
end

local function isR3ConfiguratorColorKey(ctx, key)
  if not isR3ConfiguratorFile(ctx) then return false end
  return R3_COLOR_KEY_TO_FIELD[tostring(key or "")] ~= nil
end

local function parseOptionColorValue(ctx, _, key, raw, defaultValue)
  if isR3ConfiguratorColorKey(ctx, key) then
    local r, g, b, a = parseR3HexColor(raw)
    if r then return r, g, b, a end
    local dr, dg, db, da = parseR3HexColor(defaultValue)
    if dr then return dr, dg, db, da end
    return 0, 0, 0, 0x80
  end
  return _.parseColor(raw or defaultValue)
end

local function formatOptionColorValue(ctx, _, key, r, g, b, a)
  if isR3ConfiguratorColorKey(ctx, key) then
    return formatR3HexColor(r, g, b)
  end
  return _.formatColor(r, g, b, a)
end

local function applyR3ConfiguratorVideoModeLive(value)
  local modeKey = tostring(value or ""):lower()
  if modeKey == "" or modeKey == "auto" then
    local runtime = _G.CONFIG_UI
    if runtime and runtime.nativeVideoMode and runtime.applyVideoModeSpec then
      pcall(runtime.applyVideoModeSpec, runtime.nativeVideoMode)
    end
    return
  end

  local runtime = _G.CONFIG_UI
  local selected = nil
  if runtime and runtime.getVideoModeSpecForKey then
    selected = runtime.getVideoModeSpecForKey(modeKey)
  end
  if not selected or type(selected.mode) ~= "number" then
    local modeMap = {
      ["480p"] = { mode = _480p, width = 640, height = 480, interlace = NONINTERLACED, field = FRAME },
      ["pal"] = { mode = PAL, width = 640, height = 512, interlace = INTERLACED, field = FIELD },
      ["ntsc"] = { mode = NTSC, width = 640, height = 448, interlace = INTERLACED, field = FIELD },
    }
    selected = modeMap[modeKey]
  end
  if not selected or type(selected.mode) ~= "number" then
    return
  end
  if runtime and runtime.applyVideoModeSpec then
    pcall(runtime.applyVideoModeSpec, selected)
  elseif Screen and Screen.setMode then
    pcall(Screen.setMode, selected.mode, selected.width or 640, selected.height or 448, CT24, selected.interlace,
      selected.field)
  end
end

local function applyR3ConfiguratorRuntimeOverride(ctx, _, key, value)
  if not isR3ConfiguratorFile(ctx) then return end
  local rawKey = tostring(key or "")
  if rawKey == "swap_buttons" then
    local enabled = (tostring(value or "") == "1")
    if _.common.setSwapCrossCircle then
      _.common.setSwapCrossCircle(enabled)
    else
      _.common.SWAP_CROSS_CIRCLE = enabled
    end
    return
  end
  if rawKey == "video_mode" then
    applyR3ConfiguratorVideoModeLive(value)
    return
  end
  if rawKey == "scene_transition" or rawKey == "scene_transition_frames" then
    local runtime = _G.CONFIG_UI
    if runtime and runtime.setSceneTransitionConfig then
      local transitionType = _.config_parse.get(ctx.lines, "scene_transition") or runtime.sceneTransitionType
      local transitionFrames = _.config_parse.get(ctx.lines, "scene_transition_frames") or runtime.sceneTransitionFrames
      pcall(runtime.setSceneTransitionConfig, transitionType, transitionFrames)
    end
    return
  end
  if rawKey == "default_language" then
    local runtime = _G.CONFIG_UI
    if runtime and runtime.applyLanguageCode then
      pcall(runtime.applyLanguageCode, ctx, tostring(value or ""))
    end
    return
  end
  if rawKey == "keyboard_layout" then
    local runtime = _G.CONFIG_UI
    if runtime then
      local layout = (_.common.normalizeKeyboardLayout and _.common.normalizeKeyboardLayout(value)) or tostring(value or "")
      runtime.keyboardLayout = layout
    end
    return
  end
  if _G.CONFIG_UI and _G.CONFIG_UI.setMainFilterFromShowKey then
    if _G.CONFIG_UI.setMainFilterFromShowKey(rawKey, value) then
      return
    end
  end

  local field = R3_COLOR_KEY_TO_FIELD[rawKey]
  if not field then return end
  local r, g, b = parseR3HexColor(value)
  if not r then return end
  local color = _.Color.new(r, g, b, 0x80)
  _.common[field] = color
  if field == "SELECTED_COLOR" then
    _.SELECTED_COLOR = color
    _.common.TEXT_CURSOR_COLOR = color
    _.TEXT_CURSOR_COLOR = color
  elseif field == "SELECTED_DIM_COLOR" then
    _.SELECTED_DIM_COLOR = color
  elseif field == "UNSELECTED_COLOR" then
    _.UNSELECTED_COLOR = color
  elseif field == "DIM_COLOR" then
    _.DIM_COLOR = color
    -- Keep disabled-row dim tone in sync with configured dim color.
    _.common.DISABLED_DIM_COLOR = color
    _.DISABLED_DIM_COLOR = color
  end
end

local function setConfigValue(ctx, _, key, value)
  local outValue = value
  local rawKey = tostring(key or "")
  if isR3ConfiguratorFile(ctx) and rawKey == "scene_transition_frames" then
    if _.common and _.common.normalizeSceneTransitionFrames then
      outValue = _.common.normalizeSceneTransitionFrames(value)
    else
      local n = math.floor(tonumber(value) or 10)
      if n < 1 then n = 1 end
      if n > 60 then n = 60 end
      outValue = n
    end
  end
  _.config_parse.set(ctx.lines, key, tostring(outValue or ""))
  applyR3ConfiguratorRuntimeOverride(ctx, _, key, outValue)
end

local function markConfigMutated(ctx, recomputeDirty)
  if not ctx then return end
  ctx.editorFrameParseCache = nil
  ctx._configModifiedCache = nil
  if recomputeDirty and ctx._ and ctx._.common and ctx._.common.refreshConfigModified then
    ctx._.common.refreshConfigModified(ctx)
  else
    ctx.configModified = true
  end
end

local OSD_VISUAL_PRESET_KEYS = {
  OSDSYS_menu_x = true,
  OSDSYS_menu_y = true,
  OSDSYS_enter_x = true,
  OSDSYS_enter_y = true,
  OSDSYS_version_x = true,
  OSDSYS_version_y = true,
  OSDSYS_cursor_max_velocity = true,
  OSDSYS_cursor_acceleration = true,
}

-- Patched menu defaults used by this configurator.
local OSD_VISUAL_PATCHED_DEFAULTS = {
  OSDSYS_menu_x = "320",
  OSDSYS_menu_y = "110",
  OSDSYS_enter_x = "30",
  OSDSYS_enter_y = "-1",
  OSDSYS_version_x = "-1",
  OSDSYS_version_y = "-1",
  OSDSYS_cursor_max_velocity = "1500",
  OSDSYS_cursor_acceleration = "150",
}

-- Original PS2 OSDSYS coordinate look with app cursor defaults.
local OSD_VISUAL_PS2_DEFAULTS = {
  OSDSYS_menu_x = "430",
  OSDSYS_menu_y = "110",
  OSDSYS_enter_x = "-1",
  OSDSYS_enter_y = "-1",
  OSDSYS_version_x = "-1",
  OSDSYS_version_y = "-1",
  OSDSYS_cursor_max_velocity = "1500",
  OSDSYS_cursor_acceleration = "150",
}

local function isOsdVisualPresetKey(key)
  local k = tostring(key or "")
  return OSD_VISUAL_PRESET_KEYS[k] == true
end

local function applyOsdVisualPreset(ctx, _, preset)
  if not (ctx and _ and ctx.lines and preset) then return end
  for key, value in pairs(preset) do
    setConfigValue(ctx, _, key, tostring(value or ""))
  end
  -- Preset apply mutates many keys at once and may resolve back to clean.
  markConfigMutated(ctx, true)
end

local R3_PRESET_COLOR_KEYS = {
  "cross", "square", "triangle", "circle",
  "selected", "selected_dim", "unselected", "dim", "background"
}

local function applyR3ColorPreset(ctx, _, preset)
  if not (ctx and _ and ctx.lines and preset) then return end
  for i = 1, #R3_PRESET_COLOR_KEYS do
    local key = R3_PRESET_COLOR_KEYS[i]
    local value = preset[key]
    if value ~= nil then
      setConfigValue(ctx, _, key, tostring(value))
    end
  end
  -- Preset apply mutates many keys at once and may resolve back to clean.
  markConfigMutated(ctx, true)
end

local function valuesEquivalent(a, b)
  local sa = tostring(a or "")
  local sb = tostring(b or "")
  if sa == sb then return true end
  local na = tonumber(sa)
  local nb = tonumber(sb)
  if na ~= nil and nb ~= nil then
    return na == nb
  end
  return false
end

local function optionMatchesDefault(ctx, _, key, def, getValue)
  if not (ctx and _ and key) then return false end
  if def == nil then return false end
  local getter = getValue or _.config_parse.get
  local cur = getter(ctx.lines, key)
  local effective = (cur ~= nil) and cur or def
  return valuesEquivalent(effective, def)
end

local function makeFrameParseCache(_, lines)
  local getCache = {}
  local getWithCommentCache = {}
  local getMultiCache = {}
  local getBootPathsCache = {}
  local getBootPathEntriesCache = {}
  local getBblSlotCache = {}
  local isBootKeyDisabledCache = {}

  local function cacheKeyForSlot(keyId, slot)
    return tostring(keyId or "") .. ":" .. tostring(slot or "")
  end

  return {
    get = function(_ignored, key)
      if key == nil then return nil end
      if getCache[key] == nil then
        getCache[key] = { _.config_parse.get(lines, key) }
      end
      return getCache[key][1]
    end,
    getWithComment = function(_ignored, key)
      if key == nil then return nil, nil end
      if getWithCommentCache[key] == nil then
        getWithCommentCache[key] = { _.config_parse.getWithComment(lines, key) }
      end
      return getWithCommentCache[key][1], getWithCommentCache[key][2]
    end,
    getMulti = function(_ignored, key)
      if key == nil then return {} end
      if getMultiCache[key] == nil then
        getMultiCache[key] = _.config_parse.getMulti(lines, key)
      end
      return getMultiCache[key]
    end,
    getBootPaths = function(_ignored, key)
      if key == nil then return {} end
      if getBootPathsCache[key] == nil then
        getBootPathsCache[key] = _.config_parse.getBootPaths(lines, key)
      end
      return getBootPathsCache[key]
    end,
    getBootPathEntries = function(_ignored, key)
      if key == nil then return {} end
      if getBootPathEntriesCache[key] == nil then
        getBootPathEntriesCache[key] = _.config_parse.getBootPathEntries(lines, key)
      end
      return getBootPathEntriesCache[key]
    end,
    getBblHotkeySlot = function(_ignored, keyId, slot)
      if keyId == nil or slot == nil then return nil end
      local ck = cacheKeyForSlot(keyId, slot)
      if getBblSlotCache[ck] == nil then
        getBblSlotCache[ck] = _.config_parse.getBblHotkeySlot(lines, keyId, slot)
      end
      return getBblSlotCache[ck]
    end,
    isBootKeyDisabled = function(_ignored, key)
      if key == nil then return false end
      if isBootKeyDisabledCache[key] == nil then
        isBootKeyDisabledCache[key] = (_.config_parse.isBootKeyDisabled and _.config_parse.isBootKeyDisabled(lines, key)) and
            true or false
      end
      return isBootKeyDisabledCache[key]
    end,
  }
end

local function getEditorParseCache(ctx, _)
  local sceneEpoch = ctx._sceneEpoch or 0
  local inputEpoch = ctx._inputEpoch or 0
  local isDirty = ctx.configModified == true
  local cache = ctx.editorFrameParseCache
  local cacheHit = cache and
      cache.linesRef == ctx.lines and
      cache.sceneEpoch == sceneEpoch and
      cache.isDirty == isDirty
  -- While dirty, retain inputEpoch as conservative invalidation so in-place edits
  -- are reflected immediately without requiring state transitions.
  if cacheHit and ((not isDirty) or cache.inputEpoch == inputEpoch) then
    return cache
  end
  cache = makeFrameParseCache(_, ctx.lines or {})
  cache.linesRef = ctx.lines
  cache.sceneEpoch = sceneEpoch
  cache.inputEpoch = inputEpoch
  cache.isDirty = isDirty
  ctx.editorFrameParseCache = cache
  return cache
end

local function removeHintPad(items, padName)
  local out = {}
  local target = tostring(padName or ""):lower()
  for i = 1, #(items or {}) do
    local item = items[i]
    if tostring(item and item.pad or ""):lower() ~= target then
      out[#out + 1] = item
    end
  end
  return out
end

local function isSceneTransitionTestOption(opt)
  local key = tostring(opt and opt.key or "")
  return key == "scene_transition" or key == "scene_transition_frames"
end

local function beginSceneTransitionSelfTest(ctx, _)
  if not (ctx and _ and _.common and _.common.beginSceneTransitionIn and _.common.shouldRunSceneTransition) then
    return
  end
  local runtime = _G.CONFIG_UI or {}
  local transitionType = (_.config_parse and _.config_parse.get and _.config_parse.get(ctx.lines, "scene_transition")) or
      runtime.sceneTransitionType
  local transitionFrames = (_.config_parse and _.config_parse.get and _.config_parse.get(ctx.lines, "scene_transition_frames")) or
      runtime.sceneTransitionFrames
  if _.common.normalizeSceneTransitionType then
    transitionType = _.common.normalizeSceneTransitionType(transitionType)
  end
  if _.common.normalizeSceneTransitionFrames then
    transitionFrames = _.common.normalizeSceneTransitionFrames(transitionFrames)
  else
    local n = math.floor(tonumber(transitionFrames) or 10)
    if n < 1 then n = 1 end
    if n > 60 then n = 60 end
    transitionFrames = n
  end
  if not _.common.shouldRunSceneTransition(transitionType, transitionFrames) then
    return
  end
  ctx.sceneTransitionIn = nil
  _.common.beginSceneTransitionIn(ctx, transitionType, transitionFrames, { direction = "in" })
end

local function prettifyBblGlobalLabel(ctx, o, label)
  if not (ctx and o and label) then return label end
  if (ctx.fileType ~= "ps2bbl_ini" and ctx.fileType ~= "psxbbl_ini") then
    return label
  end
  if ctx.editorCategoryIdx ~= 1 then
    return label
  end
  return tostring(label):gsub("_", " ")
end

local function drawColorSwatch(_, x, y, w, h, fillColor)
  if not (_ and _.Graphics and _.Graphics.drawRect and fillColor) then return end
  -- 1px white perimeter around the swatch.
  _.Graphics.drawRect(x - 1, y - 1, w + 2, h + 2, _.WHITE)
  _.Graphics.drawRect(x, y, w, h, fillColor)
end

local function isTimerDigitEditKey(key)
  return key == "KEY_READ_WAIT_TIME" or key == "pad_delay"
end

local function clampNumber(n, minV, maxV)
  if n < minV then return minV end
  if n > maxV then return maxV end
  return n
end

local function formatTimerDigitValue(ms)
  local seconds = math.max(0, math.floor(((tonumber(ms) or 0) + 500) / 1000))
  return string.format("%03d", seconds)
end

local function startTimerDigitEdit(ctx, _, opt)
  if not (ctx and _ and opt and opt.key) then return end
  local raw = _.config_parse.get(ctx.lines, opt.key) or opt.default or "0"
  local num = tonumber(raw)
  if not num then num = tonumber(opt.default or "0") end
  if not num then num = 0 end
  local minV = tonumber(opt.min) or 0
  local maxV = tonumber(opt.max) or 999900
  num = clampNumber(math.floor((num + 500) / 1000) * 1000, minV, maxV)
  local label = (_.strings.options and _.strings.options[opt.key] and _.strings.options[opt.key].label) or opt.label or opt.key
  ctx.timerDigitEdit = {
    key = opt.key,
    label = label,
    value = num,
    min = minV,
    max = maxV,
    digit = 1, -- 1=hundreds sec, 2=tens, 3=ones
  }
end

local function drawTimerDigitInlineValue(_, edit, x, y, scale)
  local valueText = formatTimerDigitValue(edit.value)
  local selectedCharIndex = edit.digit
  local cursorX = x
  for i = 1, #valueText do
    local ch = valueText:sub(i, i)
    local col = (i == selectedCharIndex) and (_.SELECTED_COLOR or _.WHITE) or _.UNSELECTED_COLOR
    _.drawText(_.font, _.drawMode, cursorX, y, scale, ch, col)
    local cw = (_.common.calcTextWidth and _.common.calcTextWidth(_.font, ch, scale)) or 10
    cursorX = cursorX + cw
  end
  local secondsLabel = (_.common_str and _.common_str.seconds) or "seconds"
  if secondsLabel ~= "" then
    _.drawText(_.font, _.drawMode, cursorX, y, scale, " " .. tostring(secondsLabel), _.UNSELECTED_COLOR)
  end
end

local function runTimerDigitInlineInput(ctx, _)
  local edit = ctx.timerDigitEdit
  if not edit then return false end

  if (_.padEffective & _.PAD_LEFT) ~= 0 then
    edit.digit = edit.digit - 1
    if edit.digit < 1 then edit.digit = 3 end
  end
  if (_.padEffective & _.PAD_RIGHT) ~= 0 then
    edit.digit = edit.digit + 1
    if edit.digit > 3 then edit.digit = 1 end
  end

  local weightByDigit = { 100000, 10000, 1000 }
  local weight = weightByDigit[edit.digit] or 1000
  if (_.padEffective & _.PAD_UP) ~= 0 then
    edit.value = clampNumber(edit.value + weight, edit.min, edit.max)
  end
  if (_.padEffective & _.PAD_DOWN) ~= 0 then
    edit.value = clampNumber(edit.value - weight, edit.min, edit.max)
  end

  if (_.padEffective & _.PAD_CROSS) ~= 0 then
    setConfigValue(ctx, _, edit.key, tostring(edit.value))
    markConfigMutated(ctx)
    ctx.timerDigitEdit = nil
  elseif (_.padEffective & _.PAD_CIRCLE) ~= 0 then
    ctx.timerDigitEdit = nil
  end

  return true
end

local function resolveIntBounds(opt, currentNum)
  local minV = tonumber(opt and opt.min)
  local maxV = tonumber(opt and opt.max)
  local hasExplicitMin = (opt and opt.min ~= nil)
  local hasExplicitMax = (opt and opt.max ~= nil)
  if minV == nil then minV = 0 end
  if maxV == nil then maxV = 9999 end

  if opt and opt.min == nil and opt.max == nil then
    local key = tostring(opt.key or "")
    if key == "OSDSYS_enter_x" or key == "OSDSYS_enter_y" or key == "OSDSYS_version_x" or key == "OSDSYS_version_y" then
      minV, maxV = -999, 999
    elseif key:match("^OSDSYS_.*_x$") then
      maxV = 639
    elseif key:match("^OSDSYS_.*_y$") then
      maxV = 447
    elseif key:match("num_displayed") then
      minV, maxV = 1, 30
    end
  end

  local defNum = tonumber(opt and opt.default or nil)
  if (not hasExplicitMin) then
    if defNum and defNum < minV then minV = defNum end
    if currentNum and currentNum < minV then minV = currentNum end
  end
  if (not hasExplicitMax) then
    if defNum and defNum > maxV then maxV = defNum end
    if currentNum and currentNum > maxV then maxV = currentNum end
  end
  if maxV < minV then maxV = minV end
  return minV, maxV
end

local function intDigitCountForRange(minV, maxV)
  local maxAbs = math.max(math.abs(math.floor(minV or 0)), math.abs(math.floor(maxV or 0)), 0)
  local digits = #tostring(maxAbs)
  if digits < 1 then digits = 1 end
  return digits
end

local function formatIntDigitValue(edit)
  local n = tonumber(edit.value) or 0
  n = math.floor(n)
  local digits = math.max(1, tonumber(edit.digits) or 1)
  local absText = string.format("%0" .. tostring(digits) .. "d", math.abs(n))
  if edit.showSign then
    return ((n < 0) and "-" or " ") .. absText
  end
  return absText
end

local function startIntDigitEdit(ctx, _, opt)
  if not (ctx and _ and opt and opt.key) then return end
  local raw = _.config_parse.get(ctx.lines, opt.key) or opt.default or "0"
  local num = tonumber(raw)
  if not num then num = tonumber(opt.default or "0") end
  if not num then num = 0 end
  if num >= 0 then
    num = math.floor(num + 0.5)
  else
    num = math.ceil(num - 0.5)
  end
  local minV, maxV = resolveIntBounds(opt, num)
  num = clampNumber(num, minV, maxV)
  local digits = intDigitCountForRange(minV, maxV)
  ctx.intDigitEdit = {
    key = opt.key,
    value = num,
    min = minV,
    max = maxV,
    digit = 1, -- 1=highest place, N=ones
    digits = digits,
    showSign = (minV < 0),
  }
end

local function drawIntDigitInlineValue(_, edit, x, y, scale)
  local valueText = formatIntDigitValue(edit)
  local selectedCharIndex = edit.digit
  if edit.showSign then selectedCharIndex = selectedCharIndex + 1 end
  local cursorX = x
  for i = 1, #valueText do
    local ch = valueText:sub(i, i)
    local isSign = edit.showSign and (i == 1)
    local col = isSign and _.DIM_COLOR or _.UNSELECTED_COLOR
    if i == selectedCharIndex then
      col = _.SELECTED_COLOR or _.WHITE
    end
    _.drawText(_.font, _.drawMode, cursorX, y, scale, ch, col)
    local cw = (_.common.calcTextWidth and _.common.calcTextWidth(_.font, ch, scale)) or 10
    cursorX = cursorX + cw
  end
end

local function runIntDigitInlineInput(ctx, _)
  local edit = ctx.intDigitEdit
  if not edit then return false end

  if (_.padEffective & _.PAD_LEFT) ~= 0 then
    edit.digit = edit.digit - 1
    if edit.digit < 1 then edit.digit = edit.digits end
  end
  if (_.padEffective & _.PAD_RIGHT) ~= 0 then
    edit.digit = edit.digit + 1
    if edit.digit > edit.digits then edit.digit = 1 end
  end

  local place = edit.digits - edit.digit
  local weight = 10 ^ place
  if (_.padEffective & _.PAD_UP) ~= 0 then
    edit.value = clampNumber((tonumber(edit.value) or 0) + weight, edit.min, edit.max)
  end
  if (_.padEffective & _.PAD_DOWN) ~= 0 then
    edit.value = clampNumber((tonumber(edit.value) or 0) - weight, edit.min, edit.max)
  end

  if (_.padEffective & _.PAD_CROSS) ~= 0 then
    setConfigValue(ctx, _, edit.key, tostring(math.floor(tonumber(edit.value) or 0)))
    markConfigMutated(ctx)
    ctx.intDigitEdit = nil
  elseif (_.padEffective & _.PAD_CIRCLE) ~= 0 then
    ctx.intDigitEdit = nil
  end

  return true
end

local function startInlineColorEdit(ctx, _, opt)
  if not (ctx and _ and opt and opt.key) then return end
  local isR3 = isR3ConfiguratorColorKey(ctx, opt.key)
  local r, g, b, a = parseOptionColorValue(ctx, _, opt.key, _.config_parse.get(ctx.lines, opt.key) or opt.default, opt.default)
  if isR3 then a = 0x80 end
  ctx.colorInlineEdit = {
    key = opt.key,
    values = { r, g, b, a },
    orig = { r, g, b, a },
    channelCount = isR3 and 3 or 4,
    channel = 1,
    digit = 1, -- 1=hundreds, 2=tens, 3=ones
    highlightX = nil,
    highlightW = nil,
  }
end

local function drawInlineColorEditValue(_, edit, x, y, scale)
  if not edit then return end
  local labels = { "R", "G", "B", "A" }
  local channelCount = tonumber(edit.channelCount) or 4
  local calcTextWidth = _.common and _.common.calcTextWidth
  local function textWidth(s)
    if calcTextWidth then
      return calcTextWidth(_.font, s, scale)
    end
    return #tostring(s or "") * 8
  end

  local blockGap = textWidth(" ")
  local channelBlocks = {}
  local cursorX = x

  for ch = 1, channelCount do
    local val = clampNumber(tonumber(edit.values[ch]) or 0, 0, 255)
    local valStr = string.format("%03d", val)
    local blockText = labels[ch] .. valStr
    local blockW = textWidth(blockText)
    channelBlocks[ch] = { x = cursorX, w = blockW, valStr = valStr }
    cursorX = cursorX + blockW
    if ch < channelCount then
      cursorX = cursorX + blockGap
    end
  end

  local activeBlock = channelBlocks[edit.channel]
  if activeBlock then
    local padX = math.max(1, math.floor((_.scaleX and _.scaleX(2)) or 2))
    local padY = math.max(1, math.floor((_.scaleY and _.scaleY(2)) or 2))
    local fontPixelH = (_.common and _.common.FT_PIXEL_H) or 18
    local blockH = math.max(8, math.floor(fontPixelH * (scale or 1) + 0.5))
    local targetX = activeBlock.x - padX
    local targetW = activeBlock.w + padX * 2

    -- Slide highlight to the currently selected channel for smoother channel changes.
    if type(edit.highlightX) ~= "number" then edit.highlightX = targetX end
    if type(edit.highlightW) ~= "number" then edit.highlightW = targetW end
    local function smoothStep(cur, target, factor)
      local delta = target - cur
      if math.abs(delta) < 0.6 then return target end
      return cur + (delta * factor)
    end
    edit.highlightX = smoothStep(edit.highlightX, targetX, 0.45)
    edit.highlightW = smoothStep(edit.highlightW, targetW, 0.45)

    local underlay = _.Color.new(96, 96, 96, 110)
    _.Graphics.drawRect(math.floor(edit.highlightX + 0.5), y - padY, math.floor(edit.highlightW + 0.5), blockH + padY * 2,
      underlay)
  end

  cursorX = x
  for ch = 1, channelCount do
    local prefix = labels[ch]
    local prefixCol = _.WHITE
    if ch == 1 then
      prefixCol = _.Color.new(230, 70, 70, 128)
    elseif ch == 2 then
      prefixCol = _.Color.new(80, 200, 80, 128)
    elseif ch == 3 then
      prefixCol = _.Color.new(60, 80, 170, 128)
    elseif ch == 4 then
      prefixCol = _.Color.new(210, 210, 210, 0x80)
    end
    _.drawText(_.font, _.drawMode, cursorX, y, scale, prefix, prefixCol)
    cursorX = cursorX + textWidth(prefix)

    local valStr = channelBlocks[ch] and channelBlocks[ch].valStr or "000"
    for i = 1, #valStr do
      local digit = valStr:sub(i, i)
      local col = (ch == edit.channel and i == edit.digit) and (_.SELECTED_COLOR or _.WHITE) or _.UNSELECTED_COLOR
      _.drawText(_.font, _.drawMode, cursorX, y, scale, digit, col)
      cursorX = cursorX + textWidth(digit)
    end
    if ch < channelCount then
      _.drawText(_.font, _.drawMode, cursorX, y, scale, " ", _.UNSELECTED_COLOR)
      cursorX = cursorX + blockGap
    end
  end
end

local function runInlineColorEditInput(ctx, _)
  local edit = ctx.colorInlineEdit
  if not edit then return false end
  local channelCount = tonumber(edit.channelCount) or 4
  local maxLinear = channelCount * 3
  local isR3 = isR3ConfiguratorColorKey(ctx, edit.key)

  local function toLinear(ch, digit)
    return ((ch - 1) * 3) + digit
  end

  local function fromLinear(idx)
    local safe = idx
    if safe < 1 then safe = 1 end
    if safe > maxLinear then safe = maxLinear end
    local ch = math.floor((safe - 1) / 3) + 1
    local digit = ((safe - 1) % 3) + 1
    return ch, digit
  end

  if (_.padEffective & _.PAD_LEFT) ~= 0 then
    local idx = toLinear(edit.channel, edit.digit) - 1
    if idx < 1 then idx = maxLinear end
    edit.channel, edit.digit = fromLinear(idx)
  end
  if (_.padEffective & _.PAD_RIGHT) ~= 0 then
    local idx = toLinear(edit.channel, edit.digit) + 1
    if idx > maxLinear then idx = 1 end
    edit.channel, edit.digit = fromLinear(idx)
  end
  if (_.padEffective & _.PAD_SQUARE) ~= 0 then
    edit.channel = edit.channel + 1
    if edit.channel > channelCount then edit.channel = 1 end
  end

  local weightByDigit = { 100, 10, 1 }
  local weight = weightByDigit[edit.digit] or 1
  local changed = false
  if (_.padEffective & _.PAD_UP) ~= 0 then
    edit.values[edit.channel] = clampNumber((tonumber(edit.values[edit.channel]) or 0) + weight, 0, 255)
    changed = true
  end
  if (_.padEffective & _.PAD_DOWN) ~= 0 then
    edit.values[edit.channel] = clampNumber((tonumber(edit.values[edit.channel]) or 0) - weight, 0, 255)
    changed = true
  end
  if changed and isR3 then
    setConfigValue(ctx, _, edit.key, formatR3HexColor(edit.values[1], edit.values[2], edit.values[3]))
    markConfigMutated(ctx)
  end

  if (_.padEffective & _.PAD_CROSS) ~= 0 then
    setConfigValue(ctx, _, edit.key,
      formatOptionColorValue(ctx, _, edit.key, edit.values[1], edit.values[2], edit.values[3], edit.values[4]))
    markConfigMutated(ctx)
    ctx.colorInlineEdit = nil
  elseif (_.padEffective & _.PAD_CIRCLE) ~= 0 then
    if isR3 and edit.orig then
      setConfigValue(ctx, _, edit.key, formatR3HexColor(edit.orig[1], edit.orig[2], edit.orig[3]))
    end
    ctx.colorInlineEdit = nil
  end

  return true
end

local function run(ctx)
  local _ = ctx._
  local formatBelForDisplay = (_.common and _.common.formatBelForDisplay) or function(text)
    return tostring(text or ""):gsub(string.char(7), "\226\150\161")
  end
  local frameParse = getEditorParseCache(ctx, _)
  local cachedGet = frameParse.get
  local cachedGetWithComment = frameParse.getWithComment
  local cachedGetMulti = frameParse.getMulti
  local cachedGetBootPaths = frameParse.getBootPaths
  local cachedGetBootPathEntries = frameParse.getBootPathEntries
  local cachedGetBblHotkeySlot = frameParse.getBblHotkeySlot
  local cachedIsBootKeyDisabled = frameParse.isBootKeyDisabled
  if _.common.handleLeaveSavePrompt(ctx, {
        onSave = function()
          _.common.saveCurrentConfig(ctx, {
            allowChoose = (ctx.fileType == "osdmenu_cnf"),
            beforeChooseSave = function()
              ctx.returnToSelectConfigAfterSave = getEditorBackState(ctx)
            end,
            afterSave = function()
              ctx.returnStateAfterSaveFlash = getEditorBackState(ctx)
              ctx.returnToSelectConfigAfterSaveFlash = true
            end,
          })
        end,
        onDiscard = function()
          ctx.state = getEditorBackState(ctx)
          ctx.currentPath = nil
          ctx.lines = nil
          ctx.optList = nil
          ctx.editorCategoryIdx = 0
          ctx.editorPendingEnterCategoryIdx = nil
          ctx.editorPendingReturnCategorySel = nil
          ctx.saveSplash = nil
        end,
      }) then
    return
  end

  local pathStr = getEditorDisplayPath(ctx, ctx.currentPath or "")
  if isR3ConfiguratorFile(ctx) then
    local pathScale = 0.8
    local maxPathW = (_.w or 640) - (_.MARGIN_X * 2)
    local drawPath = pathStr
    if _.common and _.common.fitListRowText then
      drawPath = _.common.fitListRowText(ctx, "editor_header_path", _.font, pathStr, maxPathW, pathScale, true,
        { holdStart = 55, stepFrames = 14, holdEnd = 85 })
    elseif _.common and _.common.truncateTextToWidth then
      drawPath = _.common.truncateTextToWidth(_.font, pathStr, maxPathW, pathScale)
    end
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, pathScale, drawPath, _.DIM_COLOR)
  elseif #pathStr > 56 then
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 0.8, pathStr:sub(1, 56), _.DIM_COLOR)
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y + _.scaleY(18), 0.8, pathStr:sub(57), _.DIM_COLOR)
  else
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 0.8, pathStr, _.DIM_COLOR)
  end

  if ctx.saveSplash and ctx.saveSplash.framesLeft > 0 and ctx.saveSplash.kind == "saved" and ctx.returnToSelectConfigAfterSaveFlash then
    return
  end

  local isCategorizedFile = (ctx.fileType == "osdmenu_cnf" or ctx.fileType == "freemcboot_cnf" or
      ctx.fileType == "osdmbr_cnf" or ctx.fileType == "ps2bbl_ini" or ctx.fileType == "psxbbl_ini")
  local categories = {}
  if ctx.fileType == "osdmenu_cnf" then
    categories = _.config_options.osdmenu_cnf_categories or {}
  elseif ctx.fileType == "freemcboot_cnf" then
    categories = _.config_options.freemcboot_cnf_categories or _.config_options.osdmenu_cnf_categories or {}
  elseif ctx.fileType == "osdmbr_cnf" then
    categories = _.config_options.osdmbr_cnf_categories or {}
  elseif ctx.fileType == "ps2bbl_ini" then
    categories = _.config_options.ps2bbl_ini_categories or {}
  elseif ctx.fileType == "psxbbl_ini" then
    categories = _.config_options.psxbbl_ini_categories or {}
  end

  local function resolveCategoryOptList(cat)
    local rawOpts = (cat and cat.options) or {}
    -- DKWDRV custom path not applicable for HOSDMenu (no MC path)
    if ctx.context == "hosdmenu" and ctx.fileType == "osdmenu_cnf" then
      local filtered = {}
      for _, o in ipairs(rawOpts) do
        if o.key ~= "path_DKWDRV_ELF" then filtered[#filtered + 1] = o end
      end
      return filtered
    end
    return rawOpts
  end

  local function applyEnterCategory(categoryIdx)
    local selectedCategoryIdx = math.max(1, math.floor(tonumber(categoryIdx) or 1))
    if #categories > 0 and selectedCategoryIdx > #categories then
      selectedCategoryIdx = #categories
    end
    local cat = categories[selectedCategoryIdx]
    ctx.editorCategoryIdx = selectedCategoryIdx
    ctx.optList = resolveCategoryOptList(cat)
    if #ctx.optList > 0 then
      -- Forward enter should always land on the first interactive row.
      ctx.optSel = 1
    else
      ctx.optSel = 1
    end
    ctx.optScroll = ctx.optScroll or 0
  end

  if isCategorizedFile and ctx.state == "editor" and ctx.editorPendingEnterCategoryIdx then
    applyEnterCategory(ctx.editorPendingEnterCategoryIdx)
    ctx.editorPendingEnterCategoryIdx = nil
  elseif isCategorizedFile and ctx.state == "editor_categories" and ctx.editorPendingReturnCategorySel then
    local prevCategoryIdx = math.max(1, math.floor(tonumber(ctx.editorPendingReturnCategorySel) or 1))
    if #categories > 0 and prevCategoryIdx > #categories then
      prevCategoryIdx = #categories
    end
    ctx.editorCategoryIdx = 0
    ctx.optList = nil
    ctx.optSel = prevCategoryIdx
    ctx.optScroll = _.common.centeredListScroll(ctx.optSel, #categories, _.MAX_VISIBLE)
    ctx.editorPendingReturnCategorySel = nil
  end

  -- Keep interactive rows anchored to the same Y slots between category and child option pages.
  local editorListStartY = _.MARGIN_Y + _.scaleY(50)

  if isCategorizedFile and ctx.editorCategoryIdx == 0 then
    local cats = categories
    local maxVis = _.MAX_VISIBLE
    ctx.optSel = _.common.clampListSelection(ctx.optSel or 1, #cats)
    ctx.optScroll = _.common.centeredListScroll(ctx.optSel, #cats, maxVis)
    local startY = editorListStartY
    if _.common and _.common.drawListScrollbar then
      _.common.drawListScrollbar(_, {
        totalRows = #cats,
        visibleRows = maxVis,
        scrollRows = ctx.optScroll,
        rowTopY = startY,
        rowHeight = _.ROW_H,
        color = _.DIM_COLOR,
      })
    end
    local maxCatLabelW = (_.w or 640) - (_.MARGIN_X + 16) - (_.MARGIN_X + 8)
    for i = ctx.optScroll + 1, math.min(ctx.optScroll + maxVis, #cats) do
      local cat = cats[i]
      local y = startY + (i - ctx.optScroll - 1) * _.ROW_H
      local col = (i == ctx.optSel) and _.SELECTED_COLOR or _.UNSELECTED_COLOR
      local catLabel = cat.name or _.common_str.empty
      if ctx.fileType == "osdmenu_cnf" then
        catLabel = (_.strings.categories and _.strings.categories[i]) or catLabel
      elseif ctx.fileType == "freemcboot_cnf" then
        catLabel = (_.strings.categories_freemcboot and _.strings.categories_freemcboot[i]) or catLabel
      elseif ctx.fileType == "osdmbr_cnf" then
        catLabel = (_.strings.categories_osdmbr and _.strings.categories_osdmbr[i]) or catLabel
      elseif ctx.fileType == "ps2bbl_ini" or ctx.fileType == "psxbbl_ini" then
        catLabel = (_.strings.categories_bbl and _.strings.categories_bbl[i]) or catLabel
      end
      if _.common.fitListRowText then
        catLabel = _.common.fitListRowText(ctx, "editor_cat_row_" .. tostring(i), _.font, catLabel, maxCatLabelW,
          _.FONT_SCALE, i == ctx.optSel)
      elseif _.common.truncateTextToWidth then
        catLabel = _.common.truncateTextToWidth(_.font, catLabel, maxCatLabelW, _.FONT_SCALE)
      end
      _.drawListRow(_.MARGIN_X + 16, y, i == ctx.optSel,
        catLabel, col)
    end
    local categoryHints = _.common.withStartHintVisibility(_.editor_str.cross_open_circle_back_items, ctx.configModified == true)
    _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, categoryHints, nil,
      _.DIM_COLOR, _.w - 2 * _.MARGIN_X)
    if (_.padEffective & _.PAD_UP) ~= 0 then
      ctx.optSel = _.common.wrapListSelection(ctx.optSel, #cats, -1)
    end
    if (_.padEffective & _.PAD_DOWN) ~= 0 then
      ctx.optSel = _.common.wrapListSelection(ctx.optSel, #cats, 1)
    end
    if (_.padEffective & _.PAD_CROSS) ~= 0 and #cats > 0 then
      local cat = cats[ctx.optSel]
      local actionKey = cat and #(cat.options or {}) == 1 and cat.options[1].key or nil
      if actionKey == "_menu_entries" then
        ctx.state = "menu_entries"
        ctx.entryList = _.config_parse.getMenuEntryIndices(ctx.lines)
        ctx.entrySel = 1
        ctx.entryScroll = 0
      elseif actionKey == "_bbl_irx_entries" then
        ctx.bblIrxSel = 1
        ctx.bblIrxScroll = 0
        ctx.state = "bbl_irx_entries"
      elseif actionKey == "_bbl_hotkeys" then
        ctx.bblHotkeySel = 1
        ctx.state = "bbl_hotkeys"
      else
        if isCategorizedFile then
          local selectedCategoryIdx = ctx.optSel
          ctx.editorPendingEnterCategoryIdx = selectedCategoryIdx
          ctx.state = "editor"
        else
          local selectedCategoryIdx = ctx.optSel
          applyEnterCategory(selectedCategoryIdx)
        end
      end
    end
    if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
      if ctx.configModified then
        ctx.editorLeavePrompt = true
      else
        ctx.state = getEditorBackState(ctx); ctx.currentPath = nil; ctx.lines = nil; ctx.optList = nil; ctx.editorCategoryIdx = 0; ctx.editorPendingEnterCategoryIdx = nil; ctx.editorPendingReturnCategorySel = nil
      end
    end
  elseif ctx.optList and #ctx.optList > 0 then
    local startY = editorListStartY
    local maxVisFallback = isR3ConfiguratorFile(ctx) and math.max(_.MAX_VISIBLE or 0, 12) or _.MAX_VISIBLE
    local maxVis = maxVisFallback
    if _.common and _.common.computeVisibleRows then
      maxVis = _.common.computeVisibleRows(_, startY, _.ROW_H, maxVisFallback, {
        reserveRows = 1,
        reserveDescription = true,
      })
    end
    ctx.optSel = _.common.clampListSelection(ctx.optSel or 1, #ctx.optList)
    if #ctx.optList > 0 then
      local currentOpt = ctx.optList[ctx.optSel]
      if currentOpt and (currentOpt.optType == "header" or isTemporarilyDisabledEditorOption(ctx, _, currentOpt)) then
        local idx = ctx.optSel
        for _scan = 1, #ctx.optList do
          idx = _.common.wrapListSelection(idx, #ctx.optList, 1)
          local candidate = ctx.optList[idx]
          if candidate and candidate.optType ~= "header" and not isTemporarilyDisabledEditorOption(ctx, _, candidate) then
            ctx.optSel = idx
            break
          end
        end
      end
    end
    ctx.optScroll = _.common.centeredListScroll(ctx.optSel, #ctx.optList, maxVis)
    if _.common and _.common.drawListScrollbar then
      _.common.drawListScrollbar(_, {
        totalRows = #ctx.optList,
        visibleRows = maxVis,
        scrollRows = ctx.optScroll,
        rowTopY = startY,
        rowHeight = _.ROW_H,
        color = _.DIM_COLOR,
      })
    end
    for i = ctx.optScroll + 1, math.min(ctx.optScroll + maxVis, #ctx.optList) do
      local o = ctx.optList[i]
      local y = startY + (i - ctx.optScroll - 1) * _.ROW_H
      local col = (i == ctx.optSel) and _.SELECTED_COLOR or _.UNSELECTED_COLOR
      local bootKeyDisabled = false
      local lab = (_.strings.options and _.strings.options[o.key] and _.strings.options[o.key].label) or o.label
      lab = prettifyBblGlobalLabel(ctx, o, lab)
      local valDisplay
      local bootPathSummary
      local optionDisabled = isTemporarilyDisabledEditorOption(ctx, _, o)
      if o.optType == "header" or o.optType == "action" then
        valDisplay = ""
      elseif o.optType == "color" then
        valDisplay = nil
      elseif o.optType == "bool" then
        local v = cachedGet(ctx.lines, o.key) or o.default or "0"
        valDisplay = (v == "1") and _.common_str.on or _.common_str.off
      elseif o.optType == "boot_paths" then
        bootKeyDisabled = cachedIsBootKeyDisabled(ctx.lines, o.key)
        if ctx.fileType == "osdmbr_cnf" then
          local paths = cachedGetBootPathEntries(ctx.lines, o.key)
          bootPathSummary = formatLaunchPathSummary(_, paths)
          valDisplay = nil
        else
          local paths = cachedGetBootPaths(ctx.lines, o.key)
          local count = paths and #paths or 0
          if count <= 0 then
            valDisplay = ""
          else
            valDisplay = count .. _.menu_str.path_s
          end
        end
      elseif o.optType == "bbl_slot" then
        local keyId = o.bblKeyId or "AUTO"
        local slotIdx = tonumber(o.bblEntrySlot)
        local slot = (slotIdx and _.config_parse.getBblHotkeySlot) and cachedGetBblHotkeySlot(ctx.lines, keyId, slotIdx) or
            nil
        if slot and (slot.used or slot.pathExists) then
          local p = _.common_str.not_set
          if slot.path ~= "" then
            p = _.common.formatDisplayPathWithCommands(_, slot.path)
          elseif slot.pathExists then
            p = _.common_str.empty
          end
          if ctx.fileType == "freemcboot_cnf" then
            valDisplay = p
          else
            valDisplay = p .. " " .. formatArgCount(slot.argCount)
          end
        else
          valDisplay = _.common_str.not_set
        end
      elseif o.optType == "enum" then
        local raw = cachedGet(ctx.lines, o.key) or o.default or ""
        valDisplay = resolveOptionEnumDisplay(_, o, raw)
      elseif o.optType == "path" then
        local raw = cachedGet(ctx.lines, o.key) or o.default or ""
        valDisplay = _.common.formatDisplayPathWithCommands(_, raw)
      else
        local multi = cachedGetMulti(ctx.lines, o.key)
        if multi and #multi > 1 then
          valDisplay = #multi .. " paths"
        else
          valDisplay = cachedGet(ctx.lines, o.key) or o.default or ""
        end
      end
      if (o.key == "KEY_READ_WAIT_TIME" or o.key == "pad_delay") and valDisplay and valDisplay ~= "" then
        local commonStrings = _.common_str or {}
        local unitSingular = commonStrings.second or "second"
        local unitPlural = commonStrings.seconds or "seconds"
        valDisplay = formatTimerSeconds(valDisplay, unitSingular, unitPlural)
      end
      local inlineAutoRow = false
      local bootHotkeyPad = nil
      local bootHotkeyIcon = nil
      local bootHotkeyIconW, bootHotkeyIconH, bootHotkeyIconGap = 0, 0, 0
      if ctx.fileType == "osdmbr_cnf" and o.optType == "boot_paths" then
        bootHotkeyPad = getOsdmbrHotkeyPadName(o.key)
        if bootHotkeyPad then
          bootHotkeyIcon = _.common.getPadIcon and _.common.getPadIcon(bootHotkeyPad) or nil
          if bootHotkeyIcon then
            local baseIconW = _.common.PAD_ICON_W or 26
            local baseIconH = _.common.PAD_ICON_H or 26
            local textH = (_.common and _.common.FT_PIXEL_H) or 18
            bootHotkeyIconH = math.min(baseIconH, textH)
            bootHotkeyIconW = math.max(1, math.floor((baseIconW * bootHotkeyIconH) / baseIconH + 0.5))
            bootHotkeyIconGap = 8
          end
        end
      end
      if bootHotkeyIcon then
        lab = bootPathSummary or (_.common_str.empty or "(empty)")
      end
      if ctx.fileType == "osdmbr_cnf" and o.optType == "boot_paths" and o.key == "boot_auto" then
        inlineAutoRow = true
        lab = ((_.menu_str and _.menu_str.auto_label) or "Auto") .. ": " ..
            (bootPathSummary or (_.common_str.empty or "(empty)"))
        valDisplay = ""
      elseif o.key == "NAME_AUTO" then
        inlineAutoRow = true
        local nameVal = cachedGet(ctx.lines, o.key) or o.default or ""
        local nameDisp = (nameVal ~= "" and nameVal) or (_.common_str.name_not_defined or _.common_str.empty)
        lab = (_.menu_str.name or "Name: ") .. nameDisp
        valDisplay = ""
      elseif ctx.fileType == "freemcboot_cnf" and o.key and o.key:match("^ESR_Path_E%d+$") then
        inlineAutoRow = true
        local pathVal, pathCommented = nil, nil
        if _.config_parse.getWithComment then
          pathVal, pathCommented = cachedGetWithComment(ctx.lines, o.key)
        end
        if pathVal == nil then
          pathVal = ""
        end
        local pathDisp = (pathVal ~= "" and _.common.formatDisplayPathWithCommands(_, pathVal)) or _.common_str.not_set
        lab = "  " .. pathDisp
        if ctx.editorEsrPathGrab and i == ctx.optSel then
          lab = "[" .. (_.menu_str.grabbed_tag or "Move") .. "] " .. lab
        end
        if pathCommented then
          col = (i == ctx.optSel) and (_.SELECTED_DIM_COLOR or _.SELECTED_COLOR) or (_.DISABLED_DIM_COLOR or _.DIM_COLOR)
        end
        valDisplay = ""
      elseif o.optType == "bbl_slot" and (o.bblKeyId == "AUTO" or (o.key and o.key:match("^_auto_e%d+$"))) then
        inlineAutoRow = true
        local slotIdx = tonumber(o.bblEntrySlot) or 0
        local slot = _.config_parse.getBblHotkeySlot and cachedGetBblHotkeySlot(ctx.lines, "AUTO", slotIdx) or nil
        local pathDisp = _.common_str.not_set
        if slot and slot.path and slot.path ~= "" then
          pathDisp = _.common.formatDisplayPathWithCommands(_, slot.path)
        elseif slot and slot.pathExists then
          pathDisp = _.common_str.empty
        end
        if ctx.fileType == "freemcboot_cnf" then
          lab = pathDisp
        else
          local argCount = (slot and slot.argCount) or 0
          lab = pathDisp .. " " .. formatArgCount(argCount)
        end
        if ctx.editorAutoSlotGrab and i == ctx.optSel then
          lab = "[" .. (_.menu_str.grabbed_tag or "Move") .. "] " .. lab
        end
        if slot and (slot.used or slot.pathExists) and slot.disabled then
          col = (i == ctx.optSel) and (_.SELECTED_DIM_COLOR or _.SELECTED_COLOR) or (_.DISABLED_DIM_COLOR or _.DIM_COLOR)
        end
        valDisplay = ""
      end
      if o.optType == "boot_paths" and bootKeyDisabled then
        col = (i == ctx.optSel) and (_.SELECTED_DIM_COLOR or _.SELECTED_COLOR) or (_.DISABLED_DIM_COLOR or _.DIM_COLOR)
      end
      if optionDisabled then
        col = (i == ctx.optSel) and (_.SELECTED_DIM_COLOR or _.SELECTED_COLOR) or (_.DISABLED_DIM_COLOR or _.DIM_COLOR)
      end
      if inlineAutoRow then
        local maxInlineW = (_.w or 640) - (_.MARGIN_X + 16) - (_.MARGIN_X + 8)
        if _.common.fitListRowText then
          lab = _.common.fitListRowText(ctx, "editor_autoboot_row_" .. tostring(i), _.font, lab, maxInlineW, _.FONT_SCALE,
            i == ctx.optSel)
        elseif _.common.truncateTextToWidth then
          lab = _.common.truncateTextToWidth(_.font, lab, maxInlineW, _.FONT_SCALE)
        end
      elseif bootHotkeyIcon then
        local rowTextX = (_.MARGIN_X + 16) + bootHotkeyIconW + bootHotkeyIconGap
        local maxInlineW = (_.w or 640) - rowTextX - (_.MARGIN_X + 8)
        if _.common.fitListRowText then
          lab = _.common.fitListRowText(ctx, "editor_boot_hotkey_row_" .. tostring(i), _.font, lab, maxInlineW, _.FONT_SCALE,
            i == ctx.optSel)
        elseif _.common.truncateTextToWidth then
          lab = _.common.truncateTextToWidth(_.font, lab, maxInlineW, _.FONT_SCALE)
        end
      else
        local valueColX = _.VALUE_X or 360
        local maxInlineW = valueColX - (_.MARGIN_X + 16) - 14
        if valDisplay == nil then
          maxInlineW = (_.w or 640) - (_.MARGIN_X + 16) - (_.MARGIN_X + 8)
        end
        if _.common.fitListRowText then
          lab = _.common.fitListRowText(ctx, "editor_opt_row_" .. tostring(i), _.font, lab, maxInlineW, _.FONT_SCALE,
            i == ctx.optSel)
        elseif _.common.truncateTextToWidth then
          lab = _.common.truncateTextToWidth(_.font, lab, maxInlineW, _.FONT_SCALE)
        end
      end
      if bootHotkeyIcon then
        local rowX = _.MARGIN_X + 16
        local iconY = y + math.floor(((_.LINE_H or bootHotkeyIconH) - bootHotkeyIconH) / 2)
        if _.Graphics.drawScaleImage then
          _.Graphics.drawScaleImage(bootHotkeyIcon, rowX, iconY, bootHotkeyIconW, bootHotkeyIconH)
        else
          _.Graphics.drawImage(bootHotkeyIcon, rowX, iconY)
        end
        _.drawText(_.font, _.drawMode, rowX + bootHotkeyIconW + bootHotkeyIconGap, y, _.FONT_SCALE,
          formatBelForDisplay(lab), col)
      else
        lab = formatBelForDisplay(lab)
        _.drawListRow(_.MARGIN_X + 16, y, i == ctx.optSel, lab, col)
      end
      local timerInlineEdit = (i == ctx.optSel) and ctx.timerDigitEdit and ctx.timerDigitEdit.key == o.key
      local intInlineEdit = (i == ctx.optSel) and ctx.intDigitEdit and ctx.intDigitEdit.key == o.key
      local colorInlineEdit = (i == ctx.optSel) and ctx.colorInlineEdit and ctx.colorInlineEdit.key == o.key

      if (not inlineAutoRow) and valDisplay == "" and (o.optType == "path" or o.optType == "boot_paths" or o.optType == "text" or o.optType == "enum") then
        valDisplay = _.common_str.not_set
      end
      if timerInlineEdit then
        drawTimerDigitInlineValue(_, ctx.timerDigitEdit, _.VALUE_X, y, _.FONT_SCALE)
      elseif intInlineEdit then
        drawIntDigitInlineValue(_, ctx.intDigitEdit, _.VALUE_X, y, _.FONT_SCALE)
      elseif colorInlineEdit then
        local edit = ctx.colorInlineEdit
        local swatchColor = _.Color.new(edit.values[1], edit.values[2], edit.values[3], edit.values[4])
        drawColorSwatch(_, _.VALUE_X, y, 28, _.scaleY(18), swatchColor)
        drawInlineColorEditValue(_, edit, _.VALUE_X + 34, y, _.FONT_SCALE)
      elseif valDisplay then
        if valDisplay ~= "" then
          local valCol
          if valDisplay == _.common_str.off or valDisplay == _.common_str.not_set or optionDisabled then
            valCol = _.DIM_COLOR
          elseif o.optType == "bool" and valDisplay == _.common_str.on then
            valCol = _.UNSELECTED_COLOR
          else
            -- Keep value-column text tied to configured unselected/dim palette,
            -- even when the row itself is selected.
            valCol = _.UNSELECTED_COLOR
          end
          local valDisplayDraw = formatBelForDisplay(valDisplay)
          local valueAreaWidth = (_.w or 640) - 72 - _.VALUE_X
          local drawVal
          if _.common.fitValueText then
            drawVal = _.common.fitValueText(ctx, "editor_value_row_" .. tostring(i), _.font, valDisplayDraw, valueAreaWidth,
              _.FONT_SCALE, i == ctx.optSel, { holdStart = 50, stepFrames = 18, holdEnd = 70 })
          elseif _.common.fitListRowText then
            drawVal = _.common.fitListRowText(ctx, "editor_value_row_" .. tostring(i), _.font, valDisplayDraw, valueAreaWidth,
              _.FONT_SCALE, i == ctx.optSel, { holdStart = 50, stepFrames = 18, holdEnd = 70 })
          elseif _.common.truncateTextToWidth then
            drawVal = (i == ctx.optSel) and valDisplayDraw or
                _.common.truncateTextToWidth(_.font, valDisplayDraw, valueAreaWidth, _.FONT_SCALE)
          else
            drawVal = valDisplayDraw
          end
          _.drawText(_.font, _.drawMode, _.VALUE_X, y, _.FONT_SCALE, drawVal, valCol)
        end
      elseif o.optType == "color" then
        local raw = cachedGet(ctx.lines, o.key) or o.default
        local r, g, b, a = parseOptionColorValue(ctx, _, o.key, raw, o.default)
        local swatchColor = _.Color.new(r, g, b, a)
        drawColorSwatch(_, _.VALUE_X, y, 28, _.scaleY(18), swatchColor)
      end
    end
    local selOpt = ctx.optList[ctx.optSel]
    if selOpt then
      local descStr = resolveOptionDescription(ctx, _, selOpt)
      if ctx.colorInlineEdit and ctx.colorInlineEdit.key == selOpt.key then
        descStr = (_.editor_str.inline_color_edit_hint or "D-pad: Left/Right digit or channel, Up/Down change, Square channel")
      end
      if descStr ~= "" then
        local hintTypography = _.common.getHintTypography(_.font, _.drawMode)
        local hintDrawScale = hintTypography.drawScale
        local hintFont = hintTypography.font
        local hintTextH = hintTypography.textHeight
        local hintColor = (_.UNSELECTED_COLOR or _.DIM_COLOR or _.WHITE)
        local descMaxW = (_.w or 640) - (_.MARGIN_X * 2)
        local descRaw = descStr
        local descRawW = (_.common.calcTextWidth and _.common.calcTextWidth(hintFont, descRaw, hintDrawScale)) or
            (#tostring(descRaw or "") * 8)
        local useTicker = descRawW > descMaxW
        if useTicker then
          if _.common.fitListRowText then
            descStr = _.common.fitListRowText(ctx,
              "editor_desc_" .. tostring(selOpt.key or ""),
              hintFont,
              descStr,
              descMaxW,
              hintDrawScale,
              true,
              { holdStart = 55, stepFrames = 16, holdEnd = 85 })
          elseif _.common.truncateTextToWidth then
            descStr = _.common.truncateTextToWidth(hintFont, descStr, descMaxW, hintDrawScale)
          end
        end
        local tw = (_.common.calcTextWidth and _.common.calcTextWidth(hintFont, descStr, hintDrawScale)) or
            (#tostring(descStr or "") * 8)
        local x
        if useTicker then
          x = _.MARGIN_X
        else
          local startCenterX = _.common.getHintStartCenterX and _.common.getHintStartCenterX(_, (_.w or 640) - (2 * _.MARGIN_X))
          x = startCenterX and math.floor(startCenterX - (tw / 2) + 0.5) or _.common.centerX(_, tw)
        end
        _.drawText(hintFont, _.drawMode, x, _.DESC_Y_BOTTOM, hintDrawScale, descStr, hintColor, hintTextH)
      end
    end
    local isAutoSlotRow = selOpt and selOpt.optType == "bbl_slot" and selOpt.bblKeyId == "AUTO" and selOpt.bblEntrySlot
    local autoSlotNum = isAutoSlotRow and tonumber(selOpt.bblEntrySlot) or nil
    local isEsrPathRow = selOpt and ctx.fileType == "freemcboot_cnf" and selOpt.key and selOpt.key:match("^ESR_Path_E%d+$")
    local esrSlotNum = isEsrPathRow and tonumber(selOpt.key:match("^ESR_Path_E(%d+)$")) or nil
    local isOsdVisualPresetRow = selOpt and
        (ctx.fileType == "osdmenu_cnf" or ctx.fileType == "freemcboot_cnf") and
        selOpt.optType == "int" and isOsdVisualPresetKey(selOpt.key)
    local function resetDefaultFn(key)
      local keyStr = tostring(key or "")
      if ctx.fileType == "freemcboot_cnf" then
        if _.config_options and _.config_options.getFreemcbootDefault then
          local v = _.config_options.getFreemcbootDefault(keyStr)
          if v ~= nil then return v end
        end
      elseif ctx.fileType == "osdmenu_cnf" then
        if _.config_options and _.config_options.getOsdmenuDefault then
          local v = _.config_options.getOsdmenuDefault(keyStr)
          if v ~= nil then return v end
        end
      elseif ctx.fileType == "r3configurator_cnf" then
        if _.config_options and _.config_options.getR3ConfiguratorDefault then
          local v = _.config_options.getR3ConfiguratorDefault(keyStr)
          if v ~= nil then return v end
        end
      end
      if selOpt and selOpt.key == keyStr and selOpt.default ~= nil then
        return selOpt.default
      end
      return nil
    end
    local hintItems = _.common.buildEditorHintItems(selOpt, _.editor_str.hint_edit_items,
      resetDefaultFn,
      { left = _.common_str.hint_prev, right = _.common_str.hint_next })
    local canResetFromTriangle = false
    local isR3ColorPresetRow = selOpt and selOpt.optType == "color" and isR3ConfiguratorColorKey(ctx, selOpt.key)
    if selOpt and selOpt.key and selOpt.key:sub(1, 1) ~= "_" and selOpt.optType ~= "header" then
      if isOsdVisualPresetRow then
        canResetFromTriangle = true
      else
        local def = resetDefaultFn and resetDefaultFn(selOpt.key)
        if def ~= nil then
          canResetFromTriangle = not optionMatchesDefault(ctx, _, selOpt.key, def, cachedGet)
        end
      end
    end
    if isR3ColorPresetRow then
      canResetFromTriangle = true
    end
    if not canResetFromTriangle then
      hintItems = removeHintPad(hintItems, "triangle")
    end
    if isR3ColorPresetRow then
      local triangleLabel = (_.menu_str and _.menu_str.reset_label) or "Reset"
      for i = 1, #hintItems do
        local item = hintItems[i]
        if tostring(item and item.pad or ""):lower() == "triangle" then
          item.label = triangleLabel
        end
      end
    end
    local canRunSceneTransitionTest = selOpt and
        not isTemporarilyDisabledEditorOption(ctx, _, selOpt) and
        isSceneTransitionTestOption(selOpt)
    if canRunSceneTransitionTest then
      local testLabel = (_.editor_str and _.editor_str.test_label) or "Test"
      local squareHint = nil
      for i = 1, #hintItems do
        local item = hintItems[i]
        if tostring(item and item.pad or ""):lower() == "square" then
          squareHint = item
          break
        end
      end
      if squareHint then
        squareHint.label = testLabel
      else
        hintItems[#hintItems + 1] = { pad = "square", label = testLabel, row = 1 }
      end
    end
    if selOpt and selOpt.optType == "header" then
      hintItems = removeHintPad(hintItems, "cross")
    end
    if selOpt and selOpt.optType == "boot_paths" and ctx.fileType == "osdmbr_cnf" then
      local canToggle = selOpt.key and isOsdmbrToggleableBootKey(selOpt.key) and osdmbrBootKeyHasEntries(ctx, _, selOpt.key)
      local keyDisabled = canToggle and cachedIsBootKeyDisabled(ctx.lines, selOpt.key) or false
      hintItems = {
        { pad = "cross", label = (_.menu_str.edit_label or "Edit"), row = 1 },
        {
          pad = canToggle and "triangle" or "",
          label = canToggle and
              ((keyDisabled and (_.menu_str.enable_label or "Enable")) or (_.menu_str.disable_label or "Disable")) or "",
          row = 1
        },
        {
          pad = ctx.configModified and "start" or "",
          label = ctx.configModified and (_.menu_str.save_config_label or "Save") or "",
          row = 1
        },
        { pad = "circle", label = (_.menu_str.back_label or "Back"), row = 1 },
      }
    end
    local isFmcbAuto = (ctx.fileType == "freemcboot_cnf") or (ctx.context == "freehddboot")
    local maxAutoSlots = isFmcbAuto and ((_.config_options and _.config_options.FMCB_BBL_MAX_ENTRIES) or 3) or
        ((_.config_parse.getBblMaxEntries and _.config_parse.getBblMaxEntries()) or 10)
    local autoSlotData = (isAutoSlotRow and autoSlotNum and _.config_parse.getBblHotkeySlot) and
        cachedGetBblHotkeySlot(ctx.lines, "AUTO", autoSlotNum) or nil
    local autoSlotParentDisabled = (isAutoSlotRow and _.config_parse.isBblHotkeyDisabled and
        _.config_parse.isBblHotkeyDisabled(ctx.lines, "AUTO")) and true or false
    local autoSlotEffectiveDisabled = (autoSlotParentDisabled or (autoSlotData and autoSlotData.disabled)) and true or false

    local function esrKey(slot)
      return "ESR_Path_E" .. tostring(slot or "")
    end

    local function getEsrSlot(slot)
      local key = esrKey(slot)
      local value, commented = nil, nil
      if _.config_parse.getWithComment then
        value, commented = _.config_parse.getWithComment(ctx.lines, key)
      end
      return {
        key = key,
        value = value or "",
        present = (value ~= nil),
        disabled = commented and true or false
      }
    end

    local function setEsrSlot(slot, value, disabled)
      local key = esrKey(slot)
      _.config_parse.set(ctx.lines, key, value or "")
      for _, entry in ipairs(ctx.lines or {}) do
        if entry.key and entry.key == key then
          entry.comment = disabled and true or nil
          break
        end
      end
    end

    local function getEsrSlots()
      local out = {}
      for s = 1, 3 do
        out[s] = getEsrSlot(s)
      end
      return out
    end

    local function applyEsrSlots(slots)
      for s = 1, 3 do
        local row = slots[s] or {}
        setEsrSlot(s, row.value or "", row.disabled and true or false)
      end
    end

    local function countFilledEsrSlots()
      local count = 0
      for s = 1, 3 do
        local slot = getEsrSlot(s)
        if slot.value ~= "" then count = count + 1 end
      end
      return count
    end

    local function focusEsrSlot(slot)
      local key = esrKey(slot)
      for idx, opt in ipairs(ctx.optList or {}) do
        if opt and opt.key == key then
          ctx.optSel = idx
          return
        end
      end
    end
    local function clearAutoMoveState()
      ctx.editorAutoSlotGrab = nil
      ctx.editorAutoSlotMoveSnapshot = nil
      ctx.editorAutoSlotMoveSel = nil
    end
    local function beginAutoMoveState()
      if ctx.editorAutoSlotGrab then return end
      if _.common and _.common.cloneConfigLines then
        ctx.editorAutoSlotMoveSnapshot = _.common.cloneConfigLines(ctx.lines)
      else
        ctx.editorAutoSlotMoveSnapshot = nil
      end
      ctx.editorAutoSlotMoveSel = ctx.optSel
      ctx.editorAutoSlotGrab = true
    end
    local function confirmAutoMoveState()
      clearAutoMoveState()
    end
    local function cancelAutoMoveState()
      if ctx.editorAutoSlotMoveSnapshot then
        if _.common and _.common.cloneConfigLines then
          ctx.lines = _.common.cloneConfigLines(ctx.editorAutoSlotMoveSnapshot)
        else
          ctx.lines = ctx.editorAutoSlotMoveSnapshot
        end
        ctx.optSel = _.common.clampListSelection(ctx.editorAutoSlotMoveSel or ctx.optSel, #ctx.optList)
        _.common.refreshConfigModified(ctx)
      end
      clearAutoMoveState()
    end
    if not isAutoSlotRow then
      confirmAutoMoveState()
      ctx.editorAutoSlotActionsOpen = nil
    end

    local function countUsedAutoSlots()
      local usedCount = 0
      for i = 1, maxAutoSlots do
        local s = _.config_parse.getBblHotkeySlot and cachedGetBblHotkeySlot(ctx.lines, "AUTO", i) or nil
        if s and s.used then usedCount = usedCount + 1 end
      end
      return usedCount
    end

    local function cloneBblArgs(args)
      local out = {}
      for i = 1, #(args or {}) do
        local a = args[i]
        if type(a) == "table" then
          out[#out + 1] = {
            value = a.value or "",
            disabled = a.disabled and true or false
          }
        else
          out[#out + 1] = {
            value = tostring(a or ""),
            disabled = false
          }
        end
      end
      return out
    end

    local function autoSlotHasPresence(slotData)
      if not slotData then return false end
      if slotData.pathExists then return true end
      if slotData.used then return true end
      local argCount = tonumber(slotData.argCount) or 0
      return argCount > 0
    end

    local function canRemoveAutoSlot(slotNum)
      if not slotNum then return false end
      local getSlot = _.config_parse.getBblHotkeySlot
      if not getSlot then return false end
      local current = getSlot(ctx.lines, "AUTO", slotNum)
      if autoSlotHasPresence(current) then return true end
      for i = slotNum + 1, maxAutoSlots do
        local s = getSlot(ctx.lines, "AUTO", i)
        if autoSlotHasPresence(s) then
          return true
        end
      end
      return false
    end

    local function moveAutoSlot(step)
      if not (isAutoSlotRow and autoSlotNum) then return end
      local dst = autoSlotNum + step
      if dst < 1 or dst > maxAutoSlots then return end
      _.config_parse.swapBblHotkeySlots(ctx.lines, "AUTO", autoSlotNum, dst)
      markConfigMutated(ctx)
      if ctx.optSel > 1 then
        ctx.optSel = _.common.clampListSelection(ctx.optSel + step, #ctx.optList)
      end
    end

    local function insertAutoSlotBelow()
      if not (isAutoSlotRow and autoSlotNum) then return end
      local usedCount = countUsedAutoSlots()
      if usedCount >= maxAutoSlots then return end
      local newSlot = _.config_parse.insertBblHotkeySlotBelow(ctx.lines, "AUTO", autoSlotNum, maxAutoSlots)
      if newSlot then
        markConfigMutated(ctx)
        confirmAutoMoveState()
        if newSlot < autoSlotNum and ctx.optSel > 1 then
          ctx.optSel = ctx.optSel + (newSlot - autoSlotNum)
        elseif newSlot > autoSlotNum and ctx.optSel < #ctx.optList then
          ctx.optSel = ctx.optSel + 1
        end
      end
    end

    local function removeAutoSlot()
      if not (isAutoSlotRow and autoSlotNum and canRemoveAutoSlot(autoSlotNum)) then return end
      local getSlot = _.config_parse.getBblHotkeySlot
      local packed = {}
      for i = 1, maxAutoSlots do
        if i ~= autoSlotNum then
          local s = getSlot and getSlot(ctx.lines, "AUTO", i) or nil
          if s and s.used then
            packed[#packed + 1] = {
              pathExists = s.pathExists and true or false,
              path = s.path or "",
              disabled = s.disabled and true or false,
              args = cloneBblArgs(s.args),
            }
          end
        end
      end
      for i = 1, maxAutoSlots do
        local row = packed[i]
        if row then
          _.config_parse.setBblHotkeyPath(ctx.lines, "AUTO", i, row.pathExists and row.path or nil, row.disabled)
          _.config_parse.setBblHotkeyArgs(ctx.lines, "AUTO", i, row.args)
        else
          _.config_parse.setBblHotkeyPath(ctx.lines, "AUTO", i, nil, false)
          _.config_parse.setBblHotkeyArgs(ctx.lines, "AUTO", i, {})
        end
      end
      markConfigMutated(ctx)
      confirmAutoMoveState()
    end

    local function clearEsrMoveState()
      ctx.editorEsrPathGrab = nil
      ctx.editorEsrPathMoveSnapshot = nil
      ctx.editorEsrPathMoveSel = nil
    end

    local function beginEsrMoveState()
      if ctx.editorEsrPathGrab then return end
      if _.common and _.common.cloneConfigLines then
        ctx.editorEsrPathMoveSnapshot = _.common.cloneConfigLines(ctx.lines)
      else
        ctx.editorEsrPathMoveSnapshot = nil
      end
      ctx.editorEsrPathMoveSel = ctx.optSel
      ctx.editorEsrPathGrab = true
    end

    local function confirmEsrMoveState()
      clearEsrMoveState()
    end

    local function cancelEsrMoveState()
      if ctx.editorEsrPathMoveSnapshot then
        if _.common and _.common.cloneConfigLines then
          ctx.lines = _.common.cloneConfigLines(ctx.editorEsrPathMoveSnapshot)
        else
          ctx.lines = ctx.editorEsrPathMoveSnapshot
        end
        ctx.optSel = _.common.clampListSelection(ctx.editorEsrPathMoveSel or ctx.optSel, #ctx.optList)
        _.common.refreshConfigModified(ctx)
      end
      clearEsrMoveState()
    end

    if not isEsrPathRow then
      confirmEsrMoveState()
      ctx.editorEsrPathActionsOpen = nil
    end

    local function moveEsrSlot(step)
      if not (isEsrPathRow and esrSlotNum) then return end
      local dst = esrSlotNum + step
      if dst < 1 or dst > 3 then return end
      local slots = getEsrSlots()
      slots[esrSlotNum], slots[dst] = slots[dst], slots[esrSlotNum]
      applyEsrSlots(slots)
      markConfigMutated(ctx)
      focusEsrSlot(dst)
    end

    local function insertEsrSlotBelow()
      if not (isEsrPathRow and esrSlotNum and esrSlotNum < 3) then return end
      if countFilledEsrSlots() >= 3 then return end
      local slots = getEsrSlots()
      for s = 3, esrSlotNum + 2, -1 do
        slots[s] = {
          value = slots[s - 1].value or "",
          disabled = slots[s - 1].disabled and true or false
        }
      end
      slots[esrSlotNum + 1] = { value = "", disabled = false }
      applyEsrSlots(slots)
      markConfigMutated(ctx)
      confirmEsrMoveState()
      focusEsrSlot(esrSlotNum + 1)
    end

    local function removeEsrSlot()
      if not (isEsrPathRow and esrSlotNum) then return end
      if countFilledEsrSlots() <= 0 then return end
      local slots = getEsrSlots()
      for s = esrSlotNum, 2 do
        slots[s] = {
          value = slots[s + 1].value or "",
          disabled = slots[s + 1].disabled and true or false
        }
      end
      slots[3] = { value = "", disabled = false }
      applyEsrSlots(slots)
      markConfigMutated(ctx)
      confirmEsrMoveState()
      focusEsrSlot(math.min(esrSlotNum, 3))
    end

    local function toggleEsrSlotDisabled()
      if not (isEsrPathRow and esrSlotNum) then return end
      local slot = getEsrSlot(esrSlotNum)
      setEsrSlot(esrSlotNum, slot.value or "", not slot.disabled)
      markConfigMutated(ctx)
    end

    if isAutoSlotRow then
      hintItems = {
        {
          pad = "cross",
          label = ctx.editorAutoSlotGrab and (_.menu_str.confirm_label or "Confirm") or (_.menu_str.edit_label or "Edit"),
          row = 1
        },
        { pad = "square", label = (_.menu_str.actions_label or "Actions"), row = 1 },
        {
          pad = ctx.configModified and "start" or "",
          label = ctx.configModified and (_.menu_str.save_config_label or "Save") or "",
          row = 1
        },
        {
          pad = autoSlotHasPresence(autoSlotData) and "triangle" or "",
          label = autoSlotHasPresence(autoSlotData) and
              ((autoSlotEffectiveDisabled and (_.menu_str.enable_label or "Enable")) or
                (_.menu_str.disable_label or "Disable")) or "",
          row = 1
        },
        {
          pad = "circle",
          label = ctx.editorAutoSlotGrab and (_.menu_str.cancel_label or "Cancel") or (_.menu_str.back_label or "Back"),
          row = 1
        },
      }
    end

    if isEsrPathRow then
      local esrSel = getEsrSlot(esrSlotNum or 1)
      hintItems = {
        {
          pad = "cross",
          label = ctx.editorEsrPathGrab and (_.menu_str.confirm_label or "Confirm") or (_.menu_str.edit_label or "Edit"),
          row = 1
        },
        { pad = "square", label = (_.menu_str.actions_label or "Actions"), row = 1 },
        {
          pad = ctx.configModified and "start" or "",
          label = ctx.configModified and (_.menu_str.save_config_label or "Save") or "",
          row = 1
        },
        {
          pad = "triangle",
          label = esrSel.disabled and (_.menu_str.enable_label or "Enable") or (_.menu_str.disable_label or "Disable"),
          row = 1
        },
        {
          pad = "circle",
          label = ctx.editorEsrPathGrab and (_.menu_str.cancel_label or "Cancel") or (_.menu_str.back_label or "Back"),
          row = 1
        },
      }
    end

    if selOpt and ctx.timerDigitEdit and ctx.timerDigitEdit.key == selOpt.key then
      hintItems = {
        { pad = "cross", label = (_.menu_str.confirm_label or "Confirm"), row = 1 },
        { pad = "circle", label = (_.menu_str.cancel_label or "Cancel"), row = 1 },
      }
    elseif selOpt and ctx.intDigitEdit and ctx.intDigitEdit.key == selOpt.key then
      hintItems = {
        { pad = "cross", label = (_.menu_str.confirm_label or "Confirm"), row = 1 },
        { pad = "circle", label = (_.menu_str.cancel_label or "Cancel"), row = 1 },
      }
    elseif selOpt and ctx.colorInlineEdit and ctx.colorInlineEdit.key == selOpt.key then
      hintItems = {
        { pad = "cross", label = (_.menu_str.confirm_label or "Confirm"), row = 1 },
        { pad = "square", label = (_.menu_str.channel_label or "Channel"), row = 1 },
        { pad = "circle", label = (_.menu_str.cancel_label or "Cancel"), row = 1 },
      }
    end

    hintItems = _.common.withStartHintVisibility(hintItems, ctx.configModified == true)
    _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, hintItems, nil, _.DIM_COLOR, _.w - 2 * _.MARGIN_X)

    if runTimerDigitInlineInput(ctx, _) then
      return
    end
    if runIntDigitInlineInput(ctx, _) then
      return
    end
    if runInlineColorEditInput(ctx, _) then
      return
    end

    if ctx.editorOsdVisualRestoreOpen then
      if actions_menu.run(ctx, {
            openKey = "editorOsdVisualRestoreOpen",
            selKey = "editorOsdVisualRestoreSel",
            scrollKey = "editorOsdVisualRestoreScroll",
            anchorPad = "triangle",
            anchorLabel = (_.menu_str.reset_label or "Reset"),
            rows = {
              { id = "patched", label = (_.menu_str and _.menu_str.patched_defaults_label) or "Patched defaults" },
              { id = "ps2", label = (_.menu_str and _.menu_str.ps2_defaults_label) or "PS2 defaults" },
            },
            rowStateKeyPrefix = "editor_osd_visual_restore_row_",
            onSelect = function(row)
              if row.id == "patched" then
                applyOsdVisualPreset(ctx, _, OSD_VISUAL_PATCHED_DEFAULTS)
              elseif row.id == "ps2" then
                applyOsdVisualPreset(ctx, _, OSD_VISUAL_PS2_DEFAULTS)
              end
            end,
          }) then
        return
      end
    end

    if ctx.editorR3ColorPresetOpen and selOpt and selOpt.optType == "color" and isR3ConfiguratorColorKey(ctx, selOpt.key) then
      if actions_menu.run(ctx, {
            openKey = "editorR3ColorPresetOpen",
            selKey = "editorR3ColorPresetSel",
            scrollKey = "editorR3ColorPresetScroll",
            anchorPad = "triangle",
            anchorLabel = (_.menu_str and _.menu_str.reset_label) or "Reset",
            rows = {
              { id = "default", label = (_.menu_str and _.menu_str.default_label) or "Default" },
              { id = "button_colors", label = (_.menu_str and _.menu_str.button_colors_label) or "Button colors" },
            },
            rowStateKeyPrefix = "editor_r3_color_preset_row_",
            onSelect = function(row)
              if not row then return end
              if row.id == "default" then
                applyR3ColorPreset(ctx, _, R3_DEFAULT_COLOR_PRESET)
              elseif row.id == "button_colors" then
                applyR3ColorPreset(ctx, _, R3_BUTTON_COLOR_PRESET)
              end
            end,
          }) then
        return
      end
    end

    if ctx.editorAutoSlotActionsOpen and isAutoSlotRow then
      local actionRows = {}
      local usedAutoSlots = countUsedAutoSlots()
      local canMoveAutoSlots = usedAutoSlots > 1
      if not canMoveAutoSlots then
        confirmAutoMoveState()
      end
      if autoSlotData and autoSlotData.used and canMoveAutoSlots then
        actionRows[#actionRows + 1] = {
          id = "grab",
          label = ctx.editorAutoSlotGrab and (_.menu_str.cancel_move_label or "Cancel move") or
              (_.menu_str.grab_label or "Move")
        }
      end
      if canRemoveAutoSlot(autoSlotNum) then
        actionRows[#actionRows + 1] = { id = "remove", label = (_.menu_str.remove_label or "Remove") }
      end
      if usedAutoSlots < maxAutoSlots then
        actionRows[#actionRows + 1] = { id = "insert", label = (_.menu_str.insert_label or "Insert") }
      end
      if actions_menu.run(ctx, {
            openKey = "editorAutoSlotActionsOpen",
            selKey = "editorAutoSlotActionsSel",
            scrollKey = "editorAutoSlotActionsScroll",
            title = (_.menu_str.actions_title or "Actions"),
            rows = actionRows,
            rowStateKeyPrefix = "editor_auto_slot_actions_row_",
            onSelect = function(row)
              if row.id == "grab" then
                if ctx.editorAutoSlotGrab then
                  cancelAutoMoveState()
                else
                  beginAutoMoveState()
                end
              elseif row.id == "insert" then
                insertAutoSlotBelow()
              elseif row.id == "remove" then
                removeAutoSlot()
              end
            end,
          }) then
        return
      end
    end

    if ctx.editorEsrPathActionsOpen and isEsrPathRow then
      local actionRows = {}
      local filledEsrSlots = countFilledEsrSlots()
      local canMoveEsrSlots = filledEsrSlots > 1
      local canInsertEsrSlot = (esrSlotNum or 0) < 3 and filledEsrSlots < 3
      local canRemoveEsrSlot = filledEsrSlots > 0
      if not canMoveEsrSlots then
        confirmEsrMoveState()
      end
      if canMoveEsrSlots then
        actionRows[#actionRows + 1] = {
          id = "grab",
          label = ctx.editorEsrPathGrab and (_.menu_str.cancel_move_label or "Cancel move") or
              (_.menu_str.grab_label or "Move")
        }
      end
      if canInsertEsrSlot then
        actionRows[#actionRows + 1] = { id = "insert", label = (_.menu_str.insert_label or "Insert") }
      end
      if canRemoveEsrSlot then
        actionRows[#actionRows + 1] = { id = "remove", label = (_.menu_str.remove_label or "Remove") }
      end
      if actions_menu.run(ctx, {
            openKey = "editorEsrPathActionsOpen",
            selKey = "editorEsrPathActionsSel",
            scrollKey = "editorEsrPathActionsScroll",
            title = (_.menu_str.actions_title or "Actions"),
            rows = actionRows,
            rowStateKeyPrefix = "editor_esr_path_actions_row_",
            onSelect = function(row)
              if row.id == "grab" then
                if ctx.editorEsrPathGrab then
                  cancelEsrMoveState()
                else
                  beginEsrMoveState()
                end
              elseif row.id == "insert" then
                insertEsrSlotBelow()
              elseif row.id == "remove" then
                removeEsrSlot()
              end
            end,
          }) then
        return
      end
    end

    local function moveOptionSelection(step)
      local count = #(ctx.optList or {})
      if count <= 0 then return end
      local idx = _.common.clampListSelection(ctx.optSel or 1, count)
      for _scan = 1, count do
        idx = _.common.wrapListSelection(idx, count, step)
        local candidate = ctx.optList[idx]
        if candidate and candidate.optType ~= "header" and not isTemporarilyDisabledEditorOption(ctx, _, candidate) then
          ctx.optSel = idx
          return
        end
      end
    end

    if (_.padEffective & _.PAD_UP) ~= 0 then
      if isAutoSlotRow and ctx.editorAutoSlotGrab then
        moveAutoSlot(-1)
      elseif isEsrPathRow and ctx.editorEsrPathGrab then
        moveEsrSlot(-1)
      else
        moveOptionSelection(-1)
      end
    end
    if (_.padEffective & _.PAD_DOWN) ~= 0 then
      if isAutoSlotRow and ctx.editorAutoSlotGrab then
        moveAutoSlot(1)
      elseif isEsrPathRow and ctx.editorEsrPathGrab then
        moveEsrSlot(1)
      else
        moveOptionSelection(1)
      end
    end
    if (_.padEffective & (_.PAD_LEFT | _.PAD_RIGHT)) ~= 0 then
      local o = ctx.optList[ctx.optSel]
      if o and not isTemporarilyDisabledEditorOption(ctx, _, o) and o.optType == "enum" and o.enumVals and #o.enumVals > 0 then
        local cur = _.config_parse.get(ctx.lines, o.key) or o.default or ""
        local allowUnset = (o.default == "")
        local idx
        if cur == "" then
          idx = allowUnset and 0 or 1
        else
          idx = findEnumIndex(o.enumVals, cur)
          if idx == 0 then idx = 1 end
        end
        if (_.padEffective & _.PAD_LEFT) ~= 0 then
          idx = cycleEnumIndex(ctx, o, idx, -1, allowUnset)
        end
        if (_.padEffective & _.PAD_RIGHT) ~= 0 then
          idx = cycleEnumIndex(ctx, o, idx, 1, allowUnset)
        end
        setConfigValue(ctx, _, o.key, (idx == 0) and "" or o.enumVals[idx])
        markConfigMutated(ctx)
      elseif o and not isTemporarilyDisabledEditorOption(ctx, _, o) and o.optType == "bool" then
        local cur = _.config_parse.get(ctx.lines, o.key) or o.default or "0"
        setConfigValue(ctx, _, o.key, (cur == "1") and "0" or "1")
        markConfigMutated(ctx)
      elseif o and not isTemporarilyDisabledEditorOption(ctx, _, o) and o.optType == "int" then
        local cur = _.config_parse.get(ctx.lines, o.key) or o.default or "0"
        local num = tonumber(cur)
        if not num then num = tonumber(o.default or "0") end
        if not num then num = 0 end
        if num >= 0 then
          num = math.floor(num + 0.5)
        else
          num = math.ceil(num - 0.5)
        end
        local minV, maxV = resolveIntBounds(o, num)
        num = clampNumber(num, minV, maxV)
        local delta = 0
        if isTimerDigitEditKey(o.key) then
          if (_.padEffective & _.PAD_RIGHT) ~= 0 then delta = 1000 end
          if (_.padEffective & _.PAD_LEFT) ~= 0 then delta = -1000 end
        elseif o.intPadDeltas then
          local d = o.intPadDeltas
          if (_.padEffective & _.PAD_RIGHT) ~= 0 then delta = tonumber(d.right) or delta end
          if (_.padEffective & _.PAD_LEFT) ~= 0 then delta = tonumber(d.left) or delta end
        else
          if (_.padEffective & _.PAD_RIGHT) ~= 0 then delta = 1 end
          if (_.padEffective & _.PAD_LEFT) ~= 0 then delta = -1 end
        end
        if delta ~= 0 then
          num = clampNumber(num + delta, minV, maxV)
          setConfigValue(ctx, _, o.key, tostring(math.floor(num)))
          markConfigMutated(ctx)
        end
      elseif o and not isTemporarilyDisabledEditorOption(ctx, _, o) and o.optType == "string" then
        local cur = _.config_parse.get(ctx.lines, o.key) or o.default or "0"
        local num = tonumber(cur)
        if num then
          local minV = tonumber(o.min)
          local maxV = tonumber(o.max)
          if minV == nil then minV = 0 end
          if maxV == nil then maxV = 9999 end
          if o.min == nil and o.max == nil then
            if o.key and o.key:match("menu_x") then
              maxV = 639
            elseif o.key and o.key:match("menu_y") then
              maxV = 447
            elseif o.key and o.key:match("num_displayed") then
              minV, maxV = 1, 30
            end
          end
          local delta = 0
          if o.intPadDeltas then
            local d = o.intPadDeltas
            if (_.padEffective & _.PAD_RIGHT) ~= 0 then delta = tonumber(d.right) or delta end
            if (_.padEffective & _.PAD_LEFT) ~= 0 then delta = tonumber(d.left) or delta end
          else
            if (_.padEffective & _.PAD_RIGHT) ~= 0 then delta = 1 end
            if (_.padEffective & _.PAD_LEFT) ~= 0 then delta = -1 end
          end
          if delta ~= 0 then
            num = num + delta
            if num < minV then num = minV end
            if num > maxV then num = maxV end
            setConfigValue(ctx, _, o.key, tostring(num))
            markConfigMutated(ctx)
          end
        end
      end
    end
    if (_.padEffective & _.PAD_CROSS) ~= 0 then
      if isAutoSlotRow and ctx.editorAutoSlotGrab then
        confirmAutoMoveState()
        return
      end
      if isEsrPathRow and ctx.editorEsrPathGrab then
        confirmEsrMoveState()
        return
      end
      local o = ctx.optList[ctx.optSel]
      if o and not isTemporarilyDisabledEditorOption(ctx, _, o) and o.optType == "enum" and o.enumVals and #o.enumVals > 0 and
          (((ctx.fileType == "ps2bbl_ini" or ctx.fileType == "psxbbl_ini") and
            (o.key == "VIDEO_MODE" or o.key == "LOGO_DISPLAY")) or
            (ctx.fileType == "osdmenu_cnf" and (o.key == "OSDSYS_video_mode" or o.key == "OSDSYS_region")) or
            (ctx.fileType == "osdmbr_cnf" and (o.key == "osd_screentype" or o.key == "osd_language")) or
            (ctx.fileType == "r3configurator_cnf")) then
        local cur = _.config_parse.get(ctx.lines, o.key) or o.default or ""
        local allowUnset = (o.default == "")
        local idx
        if cur == "" then
          idx = allowUnset and 0 or 1
        else
          idx = findEnumIndex(o.enumVals, cur)
          if idx == 0 then idx = 1 end
        end
        idx = cycleEnumIndex(ctx, o, idx, 1, allowUnset)
        setConfigValue(ctx, _, o.key, (idx == 0) and "" or o.enumVals[idx])
        markConfigMutated(ctx)
      elseif o and not isTemporarilyDisabledEditorOption(ctx, _, o) and o.optType == "bool" then
        local cur = _.config_parse.get(ctx.lines, o.key) or o.default or "0"
        setConfigValue(ctx, _, o.key, (cur == "1") and "0" or "1")
        markConfigMutated(ctx)
      elseif o and not isTemporarilyDisabledEditorOption(ctx, _, o) and o.optType == "int" then
        if isTimerDigitEditKey(o.key) then
          startTimerDigitEdit(ctx, _, o)
        else
          startIntDigitEdit(ctx, _, o)
        end
      elseif o and not isTemporarilyDisabledEditorOption(ctx, _, o) and o.optType == "color" then
        startInlineColorEdit(ctx, _, o)
      elseif o and not isTemporarilyDisabledEditorOption(ctx, _, o) and (o.optType == "text" or o.optType == "string") then
        local allowBelKey = (o.key == "OSDSYS_left_cursor" or o.key == "OSDSYS_right_cursor" or
          o.key == "OSDSYS_menu_top_delimiter" or o.key == "OSDSYS_menu_bottom_delimiter")
        local prompt = (_.strings.options and _.strings.options[o.key] and _.strings.options[o.key].label) or
            o.label or _.common_str.enter_text
        local initialValue = _.config_parse.get(ctx.lines, o.key) or o.default or ""
        local maxLen = (o.maxLen and o.maxLen > 0) and o.maxLen or 79
        _.common.configureBelTextInput(ctx, {
          allow = allowBelKey,
          context = ctx.context,
        })
        local onSubmit = function(val)
          setConfigValue(ctx, _, o.key, val or "")
          markConfigMutated(ctx)
          ctx.state = "editor"
        end
        _.common.beginTextInput(ctx, {
          titleIdMode = nil,
          prompt = prompt,
          value = initialValue,
          maxLen = maxLen,
          callback = onSubmit,
          returnState = "editor",
          gridSel = 1,
          cursor = #initialValue + 1,
          scroll = 1,
          state = "text_input",
        })
      elseif o and not isTemporarilyDisabledEditorOption(ctx, _, o) and o.key == "_menu_entries" then
        ctx.state = "menu_entries"
        ctx.entryList = _.config_parse.getMenuEntryIndices(ctx.lines)
        ctx.entrySel = 1
        ctx.entryScroll = 0
      elseif o and not isTemporarilyDisabledEditorOption(ctx, _, o) and o.key == "_bbl_irx_entries" then
        local irxEntries = (_.config_parse.getBblIrxEntryIndices and _.config_parse.getBblIrxEntryIndices(ctx.lines)) or {}
        local targetIrxIdx, targetIrxDisabled = nil, false
        local hasUsableIrx = false
        for ii = 1, #irxEntries do
          local idx = irxEntries[ii] and tonumber(irxEntries[ii].idx) or nil
          if idx and not targetIrxIdx then
            targetIrxIdx = idx
            targetIrxDisabled = irxEntries[ii].disabled and true or false
          end
          if idx and _.config_parse.getBblIrxEntry then
            local v = _.config_parse.getBblIrxEntry(ctx.lines, idx)
            if tostring(v or "") ~= "" then
              hasUsableIrx = true
              break
            end
          end
        end
        if not hasUsableIrx then
          if not targetIrxIdx and _.config_parse.insertBblIrxEntryBelow then
            targetIrxIdx = _.config_parse.insertBblIrxEntryBelow(ctx.lines, 0, "")
            if targetIrxIdx then
              markConfigMutated(ctx)
            end
          end
          if targetIrxIdx then
            ctx.bblIrxSel = 1
            ctx.bblIrxScroll = 0
            ctx.editKey = nil
            ctx.isAddPath = false
            ctx.addPathKey = nil
            ctx.pathPickerBootKey = nil
            ctx.pathPickerBootKeyDisabled = nil
            ctx.pathPickerForEntryIdx = nil
            ctx.pathPickerEditIdx = nil
            ctx.pathPickerBblHotkeyKey = nil
            ctx.pathPickerBblHotkeySlot = nil
            ctx.pathPickerBblHotkeyDisabled = nil
            ctx.pathPickerBblIrxIdx = targetIrxIdx
            ctx.pathPickerBblIrxDisabled = targetIrxDisabled and true or false
            ctx.pathPickerContext = "path_only"
            ctx.pathPickerSub = "device"
            ctx.pathList = _.file_selector.getDevices("path_only", { fileType = ctx.fileType }) or {}
            ctx.pathPickerSel = 1
            ctx.pathPickerScroll = 0
            ctx.pathBrowsePath = nil
            ctx.pathPickerTarget = nil
            ctx.pathPickerFileExts = { ".irx" }
            ctx.pathPickerReturnState = "bbl_irx_entries"
            ctx.state = "path_picker"
          else
            ctx.bblIrxSel = 1
            ctx.bblIrxScroll = 0
            ctx.state = "bbl_irx_entries"
          end
        else
          ctx.bblIrxSel = 1
          ctx.bblIrxScroll = 0
          ctx.state = "bbl_irx_entries"
        end
      elseif o and not isTemporarilyDisabledEditorOption(ctx, _, o) and o.key == "_bbl_hotkeys" then
        ctx.bblHotkeySel = 1
        ctx.state = "bbl_hotkeys"
      elseif o and not isTemporarilyDisabledEditorOption(ctx, _, o) and o.optType == "bbl_slot" and o.bblEntrySlot then
        ctx.bblHotkeyKey = o.bblKeyId or "AUTO"
        local isAutoKey = tostring(ctx.bblHotkeyKey or ""):upper() == "AUTO"
        local slotNum = tonumber(o.bblEntrySlot)
        local slotData = (slotNum and _.config_parse.getBblHotkeySlot and
          _.config_parse.getBblHotkeySlot(ctx.lines, ctx.bblHotkeyKey, slotNum)) or nil
        local isFmcbAuto = isAutoKey and ((ctx.fileType == "freemcboot_cnf") or (ctx.context == "freehddboot"))
        local isBblAutoEmptyOrNotSet = isAutoKey and (not isFmcbAuto) and slotData and
            ((not slotData.pathExists or tostring(slotData.path or "") == "") and ((tonumber(slotData.argCount) or 0) == 0))
        if isFmcbAuto or isBblAutoEmptyOrNotSet then
          if slotNum then
            ctx.editKey = nil
            ctx.isAddPath = false
            ctx.addPathKey = nil
            ctx.pathPickerTarget = nil
            ctx.pathPickerFileExts = nil
            ctx.pathPickerBootKey = nil
            ctx.pathPickerBootKeyDisabled = nil
            ctx.pathPickerForEntryIdx = nil
            ctx.pathPickerEditIdx = nil
            ctx.pathPickerBblIrxIdx = nil
            ctx.pathPickerBblIrxDisabled = nil
            ctx.pathPickerBblHotkeyKey = ctx.bblHotkeyKey
            ctx.pathPickerBblHotkeySlot = slotNum
            ctx.pathPickerBblHotkeyDisabled = (slotData and slotData.disabled) and true or false
            if isFmcbAuto then
              ctx.pathPickerReturnState = "editor"
            else
              ctx.pathPickerReturnState = "bbl_hotkey_entry"
              ctx.bblEntrySlot = slotNum
              ctx.bblEntryDetailSel = 1
              ctx.bblEntryDetailReturnState = "editor"
            end
            ctx.pathPickerContext = "path_only"
            ctx.pathPickerSub = "device"
            ctx.pathList = _.file_selector.getDevices("path_only", { fileType = ctx.fileType }) or {}
            ctx.pathPickerSel = 1
            ctx.pathPickerScroll = 0
            ctx.pathBrowsePath = nil
            ctx.state = "path_picker"
          else
            ctx.bblEntrySlot = tonumber(o.bblEntrySlot)
            ctx.bblEntryDetailSel = 1
            ctx.bblEntryDetailReturnState = "editor"
            ctx.state = "bbl_hotkey_entry"
          end
        else
          ctx.bblEntrySlot = tonumber(o.bblEntrySlot)
          ctx.bblEntryDetailSel = 1
          ctx.bblEntryDetailReturnState = "editor"
          ctx.state = "bbl_hotkey_entry"
        end
      elseif o and not isTemporarilyDisabledEditorOption(ctx, _, o) and o.optType == "boot_paths" then
        local bootEntries = (_.config_parse.getBootPathEntries and _.config_parse.getBootPathEntries(ctx.lines, o.key)) or {}
        local hasUsableBootPath = false
        for bi = 1, #bootEntries do
          local item = bootEntries[bi]
          local value = type(item) == "table" and item.value or item
          if tostring(value or "") ~= "" then
            hasUsableBootPath = true
            break
          end
        end
        if ctx.fileType == "osdmbr_cnf" and not hasUsableBootPath then
          -- OSDMenu MBR empty/not-set launch keys: go directly to device picker and create first path slot.
          local firstEntry = bootEntries[1]
          local firstEntryValue = type(firstEntry) == "table" and firstEntry.value or firstEntry
          ctx.editKey = nil
          ctx.isAddPath = false
          ctx.addPathKey = nil
          ctx.bootKey = o.key
          ctx.pathPickerTarget = nil
          ctx.pathPickerFileExts = nil
          ctx.pathPickerForEntryIdx = nil
          ctx.pathPickerBblHotkeyKey = nil
          ctx.pathPickerBblHotkeySlot = nil
          ctx.pathPickerBblHotkeyDisabled = nil
          ctx.pathPickerBblIrxIdx = nil
          ctx.pathPickerBblIrxDisabled = nil
          ctx.pathPickerBootKey = o.key
          ctx.pathPickerBootKeyDisabled = (cachedIsBootKeyDisabled and cachedIsBootKeyDisabled(ctx.lines, o.key)) and true or
              false
          if firstEntry ~= nil and tostring(firstEntryValue or "") == "" then
            ctx.pathPickerEditIdx = 1
            ctx.pathPickerInsertBelow = nil
          else
            ctx.pathPickerEditIdx = nil
            ctx.pathPickerInsertBelow = 0
          end
          ctx.pathPickerReturnState = "entry_paths"
          ctx.pathPickerContext = "mbr"
          ctx.pathPickerSub = "device"
          ctx.pathList = _.file_selector.getDevices("mbr") or {}
          ctx.pathPickerSel = 1
          ctx.pathPickerScroll = 0
          ctx.pathBrowsePath = nil
          ctx.state = "path_picker"
        else
          ctx.bootKey = o.key
          ctx.entryIdx = nil
          ctx.entryPathSel = 1
          ctx.entryPathScroll = 0
          ctx.state = "entry_paths"
        end
      elseif o and not isTemporarilyDisabledEditorOption(ctx, _, o) and o.optType == "path" then
        ctx.editKey = o.key
        ctx.isAddPath = false
        ctx.addPathKey = nil
        local isBblLoadIrx = (ctx.fileType == "ps2bbl_ini" or ctx.fileType == "psxbbl_ini") and o.key and
            o.key:match("^LOAD_IRX_E%d+$")
        local isEsrPathPicker = ((ctx.fileType == "freemcboot_cnf") or (ctx.context == "freehddboot")) and o.key and
            o.key:match("^ESR_Path_E%d+$")
        ctx.pathPickerTarget = nil
        ctx.pathPickerFileExts = isBblLoadIrx and { ".irx" } or nil
        ctx.pathPickerBootKey = nil
        ctx.pathPickerBootKeyDisabled = nil
        ctx.pathPickerForEntryIdx = nil
        ctx.pathPickerBblHotkeyKey = nil
        ctx.pathPickerBblHotkeySlot = nil
        ctx.pathPickerBblHotkeyDisabled = nil
        ctx.pathPickerBblIrxIdx = nil
        ctx.pathPickerBblIrxDisabled = nil
        ctx.pathPickerReturnState = nil
        ctx.pathPickerContext = isBblLoadIrx and "path_only" or
            (isEsrPathPicker and "path_only" or
              ((o.key == "path_DKWDRV_ELF") and "mc_only" or ((ctx.context == "mbr") and "mbr" or "osdmenu")))
        ctx.pathPickerSub = "device"
        ctx.pathList = _.file_selector.getDevices(ctx.pathPickerContext, { fileType = ctx.fileType }) or {}
        ctx.pathPickerSel = 1
        ctx.pathPickerScroll = 0
        ctx.state = "path_picker"
      end
    end
    if (_.padEffective & _.PAD_SQUARE) ~= 0 then
      local o = ctx.optList and ctx.optList[ctx.optSel] or nil
      if o and not isTemporarilyDisabledEditorOption(ctx, _, o) and isSceneTransitionTestOption(o) then
        beginSceneTransitionSelfTest(ctx, _)
      elseif isAutoSlotRow then
        _.common.openActionsMenu(ctx, "editorAutoSlotActionsOpen", "editorAutoSlotActionsSel",
          "editorAutoSlotActionsScroll")
      elseif isEsrPathRow then
        _.common.openActionsMenu(ctx, "editorEsrPathActionsOpen", "editorEsrPathActionsSel",
          "editorEsrPathActionsScroll")
      end
    end
    if (_.padEffective & _.PAD_TRIANGLE) ~= 0 and ctx.optList and #ctx.optList > 0 then
      local o = ctx.optList[ctx.optSel]
      if o and o.optType == "boot_paths" and ctx.fileType == "osdmbr_cnf" and o.key and
          isOsdmbrToggleableBootKey(o.key) and osdmbrBootKeyHasEntries(ctx, _, o.key) then
        local disabled = _.config_parse.isBootKeyDisabled and _.config_parse.isBootKeyDisabled(ctx.lines, o.key)
        _.config_parse.setBootKeyDisabled(ctx.lines, o.key, not disabled)
        ctx.entryPathsBootKeyDisabledTag = tostring(o.key or "")
        ctx.entryPathsBootKeyDisabledOverride = (not disabled) and true or false
        ctx.entryArgsBootKeyDisabledTag = tostring(o.key or "")
        ctx.entryArgsBootKeyDisabledOverride = (not disabled) and true or false
        -- Key-level disable/enable is a common quick toggle; recompute dirty now
        -- so Start reflects true semantic state immediately on the next frame.
        markConfigMutated(ctx, true)
      elseif isOsdVisualPresetRow then
        ctx.editorOsdVisualRestoreOpen = true
        ctx.editorOsdVisualRestoreSel = ctx.editorOsdVisualRestoreSel or 1
        ctx.editorOsdVisualRestoreScroll = ctx.editorOsdVisualRestoreScroll or 0
      elseif o and o.key and o.key:match("^ESR_Path_E%d+$") and ctx.fileType == "freemcboot_cnf" then
        toggleEsrSlotDisabled()
      elseif o and o.optType == "bbl_slot" and o.bblKeyId == "AUTO" and o.bblEntrySlot then
        local slotNum = tonumber(o.bblEntrySlot)
        local slot = _.config_parse.getBblHotkeySlot and _.config_parse.getBblHotkeySlot(ctx.lines, "AUTO", slotNum) or nil
        if autoSlotHasPresence(slot) then
          local slotDisabled = (slot and slot.disabled) and true or false
          local effectiveDisabled = (autoSlotParentDisabled or slotDisabled) and true or false
          local changed = false
          if autoSlotParentDisabled and effectiveDisabled and _.config_parse.enableBblHotkeySlotFromDisabledParent then
            changed = _.config_parse.enableBblHotkeySlotFromDisabledParent(ctx.lines, "AUTO", slotNum) and true or false
          else
            changed = _.config_parse.setBblHotkeySlotDisabled and
                _.config_parse.setBblHotkeySlotDisabled(ctx.lines, "AUTO", slotNum, not slotDisabled) or false
          end
          if changed then
            markConfigMutated(ctx)
          end
        end
      elseif o and o.optType == "color" and o.key and isR3ConfiguratorColorKey(ctx, o.key) then
        ctx.editorR3ColorPresetOpen = true
        ctx.editorR3ColorPresetSel = ctx.editorR3ColorPresetSel or 1
        ctx.editorR3ColorPresetScroll = ctx.editorR3ColorPresetScroll or 0
        ctx.editorR3ColorPresetKey = o.key
      elseif o and not isTemporarilyDisabledEditorOption(ctx, _, o) and o.key and o.key:sub(1, 1) ~= "_" and o.optType ~= "header" then
        local def = resetDefaultFn and resetDefaultFn(o.key)
        if def ~= nil and not optionMatchesDefault(ctx, _, o.key, def, cachedGet) then
          setConfigValue(ctx, _, o.key, def)
          markConfigMutated(ctx, true)
        end
      end
    end
  else
    -- Avoid transient "no option list" flash while transitioning out of editor.
    -- During outgoing transition we may still render the editor scene for a few
    -- frames after ctx.lines/currentPath have been cleared for the destination scene.
    local shouldShowNoOptionList = (ctx.lines ~= nil) or (ctx.currentPath ~= nil)
    if shouldShowNoOptionList then
      _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y + _.scaleY(60), _.FONT_SCALE, _.editor_str.no_option_list,
        _.UNSELECTED_COLOR)
      local emptyHints = _.common.withStartHintVisibility(_.editor_str.start_save_circle_back_items, ctx.configModified == true)
      _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, emptyHints, nil,
        _.DIM_COLOR, _.w - 2 * _.MARGIN_X)
    end
  end

  if ctx.configModified and ((_.padEffective & _.PAD_START) ~= 0) then
    _.common.saveCurrentConfig(ctx, {
      allowChoose = (ctx.fileType == "osdmenu_cnf"),
    })
  end
  if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
    ctx.timerDigitEdit = nil
    ctx.intDigitEdit = nil
    ctx.colorInlineEdit = nil
    if ctx.editorAutoSlotGrab then
      if _.common and _.common.cloneConfigLines then
        if ctx.editorAutoSlotMoveSnapshot then
          ctx.lines = _.common.cloneConfigLines(ctx.editorAutoSlotMoveSnapshot)
          ctx.optSel = _.common.clampListSelection(ctx.editorAutoSlotMoveSel or ctx.optSel, #(ctx.optList or {}))
          _.common.refreshConfigModified(ctx)
        end
      elseif ctx.editorAutoSlotMoveSnapshot then
        ctx.lines = ctx.editorAutoSlotMoveSnapshot
        ctx.optSel = _.common.clampListSelection(ctx.editorAutoSlotMoveSel or ctx.optSel, #(ctx.optList or {}))
        _.common.refreshConfigModified(ctx)
      end
      ctx.editorAutoSlotGrab = nil
      ctx.editorAutoSlotMoveSnapshot = nil
      ctx.editorAutoSlotMoveSel = nil
      return
    end
    if ctx.editorEsrPathGrab then
      if _.common and _.common.cloneConfigLines then
        if ctx.editorEsrPathMoveSnapshot then
          ctx.lines = _.common.cloneConfigLines(ctx.editorEsrPathMoveSnapshot)
          ctx.optSel = _.common.clampListSelection(ctx.editorEsrPathMoveSel or ctx.optSel, #(ctx.optList or {}))
          _.common.refreshConfigModified(ctx)
        end
      elseif ctx.editorEsrPathMoveSnapshot then
        ctx.lines = ctx.editorEsrPathMoveSnapshot
        ctx.optSel = _.common.clampListSelection(ctx.editorEsrPathMoveSel or ctx.optSel, #(ctx.optList or {}))
        _.common.refreshConfigModified(ctx)
      end
      ctx.editorEsrPathGrab = nil
      ctx.editorEsrPathMoveSnapshot = nil
      ctx.editorEsrPathMoveSel = nil
      return
    end
    ctx.editorR3ColorPresetOpen = nil
    ctx.editorR3ColorPresetSel = nil
    ctx.editorR3ColorPresetScroll = nil
    ctx.editorR3ColorPresetKey = nil
    if isCategorizedFile and ctx.editorCategoryIdx and ctx.editorCategoryIdx > 0 then
      local prevCategoryIdx = ctx.editorCategoryIdx
      ctx.editorPendingReturnCategorySel = prevCategoryIdx
      ctx.state = "editor_categories"
      ctx.saveSplash = nil
    else
      if ctx.configModified then
        ctx.editorLeavePrompt = true
      else
        ctx.state = getEditorBackState(ctx); ctx.currentPath = nil; ctx.lines = nil; ctx.optList = nil; ctx.editorCategoryIdx = 0; ctx.editorPendingEnterCategoryIdx = nil; ctx.editorPendingReturnCategorySel = nil; ctx.saveSplash = nil
      end
    end
  end
end

return { run = run }
