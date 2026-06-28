--[[
  R3Configurator -  GUI Configurator for FMCB, OSDMenu, PS2BBL — main and editor UI.
  Renders every frame; pad debounced. Main flow in ui_main.lua.
]]

local common = dofile("scripts/ui_common.lua")
local config_parse = dofile("scripts/parse.lua")
local scene_module = dofile("scripts/ui_state.lua")

local function trimString(s)
  return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function getStartupCwd()
  if System and System.currentDirectory then
    local okCwd, cwdValue = pcall(System.currentDirectory)
    if okCwd and type(cwdValue) == "string" and cwdValue ~= "" then
      return cwdValue
    end
  end
  return nil
end

local function splitHddPartitionPath(path)
  local s = tostring(path or ""):gsub("\\", "/")
  local part, rest = s:match("^(hdd%d:[^:]+):pfs:(.*)$")
  if not part then
    -- Accept FMCB-style partition path (hdd0:__sysconf/dir/file) in addition to :pfs: form.
    part, rest = s:match("^(hdd%d:[^/:]+)(/.*)$")
  end
  if not part then return nil, nil end
  if not rest or rest == "" then rest = "/" end
  if rest:sub(1, 1) ~= "/" then rest = "/" .. rest end
  return part, rest
end

local function beginStartupPathAccess(path)
  local resolved = (common.resolvePathForAccess and common.resolvePathForAccess(path)) or tostring(path or "")
  local moduleType = common.getPathModuleType and common.getPathModuleType(resolved)
  if moduleType and System and System.loadModules then
    pcall(System.loadModules, moduleType)
  end

  local part, rest = splitHddPartitionPath(resolved)
  if part and rest then
    if System and System.fileXioMount then
      pcall(System.fileXioMount, "pfs0:", part)
      return "pfs0:", "pfs0:" .. rest, resolved
    end
    return nil, resolved, resolved
  end
  if resolved:match("^pfs0:/") and System and System.fileXioMount then
    pcall(System.fileXioMount, "pfs0:", "hdd0:__sysconf")
    return "pfs0:", resolved, resolved
  end
  return nil, resolved, resolved
end

local function endStartupPathAccess(mounted)
  if mounted and System and System.fileXioUmount then
    pcall(System.fileXioUmount, mounted)
  end
end

local function startupFileExists(path)
  local mounted, accessPath = beginStartupPathAccess(path)
  local ok, exists = pcall(doesFileExist, accessPath or path)
  endStartupPathAccess(mounted)
  return ok and exists == true
end

local function resolveStartupPath(path)
  if type(path) ~= "string" or path == "" then return nil end
  if startupFileExists(path) then return path end
  if startupFileExists("./" .. path) then return "./" .. path end
  local cwd = getStartupCwd()
  if cwd and cwd ~= "" then
    local base = cwd
    if base:sub(-1) ~= "/" then base = base .. "/" end
    if startupFileExists(base .. path) then
      return base .. path
    end
  end
  return nil
end

local function parseStartupBool(v)
  local s = trimString(v):lower()
  if s == "1" or s == "true" or s == "yes" or s == "on" then return true end
  if s == "0" or s == "false" or s == "no" or s == "off" then return false end
  return nil
end

local function loadStartupConfig()
  local cfg = {
    path = nil,
    video_mode = nil,
    swap_buttons = nil,
    default_language = nil,
    keyboard_layout = nil,
    scene_transition = nil,
    scene_transition_frames = nil,
    main_filter = nil,
    colors = {},
  }

  local cfgPath = resolveStartupPath("r3configurator.cnf")
  if not cfgPath then
    return cfg
  end

  local mounted, accessPath, resolvedPath = beginStartupPathAccess(cfgPath)
  local lines, err = config_parse.load(accessPath or cfgPath)
  endStartupPathAccess(mounted)
  if not lines then
    print("ui: failed loading startup config r3configurator.cnf: " .. tostring(err))
    return cfg
  end

  cfg.path = resolvedPath or cfgPath
  local kv = {}
  for i = 1, #(lines or {}) do
    local e = lines[i]
    if e and e.key and not e.comment then
      kv[trimString(e.key):lower()] = trimString(e.value or "")
    end
  end

  local vm = trimString(kv.video_mode):lower()
  if vm == "480p" or vm == "pal" or vm == "ntsc" or vm == "auto" then
    cfg.video_mode = vm
  end

  local swap = parseStartupBool(kv.swap_buttons)
  if swap ~= nil then
    cfg.swap_buttons = swap
  end

  local lang = trimString(kv.default_language):lower()
  if lang ~= "" and lang:match("^[%a][%w_]*$") then
    cfg.default_language = lang
  end

  local keyboardLayout = trimString(kv.keyboard_layout):lower()
  if keyboardLayout ~= "" and common.normalizeKeyboardLayout then
    cfg.keyboard_layout = common.normalizeKeyboardLayout(keyboardLayout)
  end

  local transitionType = trimString(kv.scene_transition)
  if transitionType ~= "" then
    if common.normalizeSceneTransitionType then
      cfg.scene_transition = common.normalizeSceneTransitionType(transitionType)
    else
      cfg.scene_transition = transitionType:lower()
    end
  end

  local transitionFrames = trimString(kv.scene_transition_frames)
  if transitionFrames ~= "" then
    if common.normalizeSceneTransitionFrames then
      cfg.scene_transition_frames = common.normalizeSceneTransitionFrames(transitionFrames)
    else
      local n = math.floor(tonumber(transitionFrames) or 10)
      if n < 1 then n = 1 end
      if n > 60 then n = 60 end
      cfg.scene_transition_frames = n
    end
  end

  local showKeyToId = {
    show_freemcboot = "freemcboot",
    show_freehddboot = "freehddboot",
    show_osdmenu = "osdmenu",
    show_osdmenu_mbr = "mbr",
    show_hosdmenu = "hosdmenu",
    show_ps2bbl = "ps2bbl",
    show_psxbbl = "psxbbl",
  }
  local filter = {}
  local hasFilter = false
  for key, id in pairs(showKeyToId) do
    local b = parseStartupBool(kv[key])
    if b ~= nil then
      hasFilter = true
      filter[id] = b
    end
  end
  if hasFilter then
    cfg.main_filter = filter
  end

  local colorKeys = {
    "cross", "square", "triangle", "circle",
    "selected", "selected_dim", "unselected", "dim", "background"
  }
  for i = 1, #colorKeys do
    local key = colorKeys[i]
    local value = trimString(kv[key])
    if value ~= "" then
      cfg.colors[key] = value
    end
  end

  return cfg
end

local function normalizeVideoModeSpec(spec)
  if type(spec) ~= "table" then return nil end

  local mode = tonumber(spec.mode or spec.vmode)
  local width = tonumber(spec.width) or 640
  local height = tonumber(spec.height) or 448
  local interlace = tonumber(spec.interlace)
  local field = tonumber(spec.field)

  if type(mode) ~= "number" then
    if interlace == NONINTERLACED and type(_480p) == "number" then
      mode = _480p
    elseif height >= 500 and type(PAL) == "number" then
      mode = PAL
    elseif type(NTSC) == "number" then
      mode = NTSC
    end
  end
  if type(mode) ~= "number" then return nil end

  if type(interlace) ~= "number" then
    if mode == _480p then
      interlace = NONINTERLACED
    else
      interlace = INTERLACED
    end
  end
  if type(field) ~= "number" then
    field = (interlace == NONINTERLACED) and FRAME or FIELD
  end

  local outW = math.max(1, math.floor(width + 0.5))
  local outH = math.max(1, math.floor(height + 0.5))
  return {
    mode = mode,
    width = outW,
    height = outH,
    interlace = interlace,
    field = field,
  }
end

local function captureCurrentVideoModeSpec()
  if not (Screen and Screen.getMode) then return nil end
  local ok, spec = pcall(Screen.getMode)
  if not ok or type(spec) ~= "table" then
    return nil
  end
  return normalizeVideoModeSpec(spec)
end

local flushOverlayLogoCache = nil

local function applyVideoModeSpec(spec)
  local normalized = normalizeVideoModeSpec(spec)
  if not normalized then
    return false, "invalid mode specification"
  end
  if not (Screen and Screen.setMode) then
    return false, "Screen.setMode unavailable"
  end
  if common.flushPadIconCache then
    pcall(common.flushPadIconCache)
  end
  if flushOverlayLogoCache then
    pcall(flushOverlayLogoCache)
  end
  local ok, err = pcall(Screen.setMode, normalized.mode, normalized.width, normalized.height, CT24, normalized.interlace,
    normalized.field)
  if not ok then
    return false, err
  end
  return true
end

local function getVideoModeSpecForKey(modeKey)
  local key = trimString(modeKey):lower()
  local specs = {
    ["480p"] = { mode = _480p, width = 640, height = 480, interlace = NONINTERLACED, field = FRAME },
    ["pal"] = { mode = PAL, width = 640, height = 512, interlace = INTERLACED, field = FIELD },
    ["ntsc"] = { mode = NTSC, width = 640, height = 448, interlace = INTERLACED, field = FIELD },
  }
  local spec = specs[key]
  if not spec then return nil end
  return {
    mode = spec.mode,
    width = spec.width,
    height = spec.height,
    interlace = spec.interlace,
    field = spec.field,
  }
end

local STARTUP_CFG = loadStartupConfig()
local NATIVE_VIDEO_MODE_SPEC = captureCurrentVideoModeSpec()
local STARTUP_CWD = getStartupCwd()

local function readRom0File(path, maxLen)
  if not (System and System.openFile and System.readFile and System.closeFile) then return nil end
  local okOpen, h = pcall(System.openFile, path, 0)
  if not okOpen or type(h) ~= "number" or h < 0 then
    return nil
  end
  local okRead, data = pcall(System.readFile, h, maxLen or 64)
  pcall(System.closeFile, h)
  if okRead and type(data) == "string" then
    return data
  end
  return nil
end

local function isStartupSelectHeld()
  if not (Pads and Pads.get) then return false end
  local selectMask = (common and common.PAD_SELECT) or 0x0001
  for sample = 1, 6 do
    for port = 0, 1 do
      local okPad, rawPad = pcall(Pads.get, port)
      if okPad and type(rawPad) == "number" and (rawPad & selectMask) ~= 0 then
        return true
      end
    end
    if sample < 6 and Screen and Screen.waitVblankStart then
      pcall(Screen.waitVblankStart)
    end
  end
  return false
end

local function probeRuntimePlatform()
  local forceShowAll = isStartupSelectHeld()
  local psxverExists = false
  if doesFileExist then
    local okExists, exists = pcall(doesFileExist, "rom0:PSXVER")
    psxverExists = okExists and exists == true
  else
    psxverExists = readRom0File("rom0:PSXVER", 1) ~= nil
  end

  local romver = readRom0File("rom0:ROMVER", 14)
  if type(romver) == "string" then
    romver = romver:gsub("%z", ""):gsub("[\r\n]+$", ""):gsub("%s+$", "")
  end
  local romverPrefix = (type(romver) == "string") and romver:sub(1, 4) or ""
  local romverModel = tonumber(romverPrefix)

  return {
    psxverExists = psxverExists,
    probedIsPsx = psxverExists,
    isPsx = forceShowAll or psxverExists,
    romver = romver,
    romverPrefix = romverPrefix,
    romverModel = romverModel,
    forceShowAll = forceShowAll,
    hideHddDevices = (not forceShowAll) and (type(romverModel) == "number" and romverModel >= 220),
  }
end

local STARTUP_PLATFORM = probeRuntimePlatform()

_G.CONFIG_UI = {
  common = common,
  config_parse = config_parse,
  startupConfig = STARTUP_CFG,
  startupCwd = STARTUP_CWD,
  runtimePlatform = STARTUP_PLATFORM,
  startupMainFilter = STARTUP_CFG.main_filter,
  startupDefaultLanguage = STARTUP_CFG.default_language,
  startupKeyboardLayout = STARTUP_CFG.keyboard_layout,
  keyboardLayout = (common.normalizeKeyboardLayout and common.normalizeKeyboardLayout(STARTUP_CFG.keyboard_layout)) or
      (STARTUP_CFG.keyboard_layout or common.KEYBOARD_LAYOUT_DEFAULT),
  startupSceneTransitionType = STARTUP_CFG.scene_transition,
  startupSceneTransitionFrames = STARTUP_CFG.scene_transition_frames,
  sceneTransitionType = (common.normalizeSceneTransitionType and common.normalizeSceneTransitionType(STARTUP_CFG.scene_transition)) or
      (STARTUP_CFG.scene_transition or common.SCENE_TRANSITION_DEFAULT_TYPE),
  sceneTransitionFrames = (common.normalizeSceneTransitionFrames and common.normalizeSceneTransitionFrames(STARTUP_CFG.scene_transition_frames)) or
      (STARTUP_CFG.scene_transition_frames or common.SCENE_TRANSITION_DEFAULT_FRAMES),
  nativeVideoMode = NATIVE_VIDEO_MODE_SPEC,
  applyVideoModeSpec = applyVideoModeSpec,
  getVideoModeSpecForKey = getVideoModeSpecForKey,
}

local function getSceneDrawOffsetX()
  local runtime = _G and _G.CONFIG_UI
  return math.floor(tonumber(runtime and runtime.sceneDrawOffsetX) or 0)
end

local function getSceneDrawAlpha()
  local runtime = _G and _G.CONFIG_UI
  local a = tonumber(runtime and runtime.sceneDrawAlpha)
  if not a then return 1 end
  if a < 0 then return 0 end
  if a > 1 then return 1 end
  return a
end

local function getSceneDrawScale()
  local runtime = _G and _G.CONFIG_UI
  local s = tonumber(runtime and runtime.sceneDrawScale)
  if not s or s <= 0 then return 1 end
  if s < 0.1 then s = 0.1 end
  if s > 4 then s = 4 end
  return s
end

local function getSceneDrawScaleX()
  local runtime = _G and _G.CONFIG_UI
  local sx = tonumber(runtime and runtime.sceneDrawScaleX)
  if sx == nil then
    return getSceneDrawScale()
  end
  if sx < -4 then sx = -4 end
  if sx > 4 then sx = 4 end
  return sx
end

local function getSceneDrawScaleY()
  local runtime = _G and _G.CONFIG_UI
  local sy = tonumber(runtime and runtime.sceneDrawScaleY)
  if sy == nil then
    return getSceneDrawScale()
  end
  if sy < -4 then sy = -4 end
  if sy > 4 then sy = 4 end
  return sy
end

local function getSceneDrawCenter()
  local runtime = _G and _G.CONFIG_UI
  local w = tonumber(runtime and runtime.currentSceneWidth) or common.DEFAULT_W
  local h = tonumber(runtime and runtime.currentSceneHeight) or common.DEFAULT_H
  local cx = tonumber(runtime and runtime.sceneDrawCenterX) or (w / 2)
  local cy = tonumber(runtime and runtime.sceneDrawCenterY) or (h / 2)
  return cx, cy
end

local function isProjectiveSceneTransformActive()
  local runtime = _G and _G.CONFIG_UI
  return type(runtime) == "table" and runtime.sceneDrawProjective == true
end

local function projectScenePoint(px, py)
  if common and common.projectScenePoint then
    return common.projectScenePoint(px, py)
  end
  return nil
end

local function transformScenePoint(x, y)
  local px = tonumber(x) or 0
  local py = tonumber(y) or 0
  local projX, projY = projectScenePoint(px, py)
  if projX ~= nil and projY ~= nil then
    px, py = projX, projY
  else
    local scaleX = getSceneDrawScaleX()
    local scaleY = getSceneDrawScaleY()
    if math.abs(scaleX - 1) > 0.0001 or math.abs(scaleY - 1) > 0.0001 then
      local cx, cy = getSceneDrawCenter()
      px = cx + ((px - cx) * scaleX)
      py = cy + ((py - cy) * scaleY)
    end
  end
  px = px + getSceneDrawOffsetX()
  return px, py
end

local function scaleSceneLengthX(v)
  local n = tonumber(v) or 0
  if isProjectiveSceneTransformActive() then
    local cx, cy = getSceneDrawCenter()
    local x1, y1 = transformScenePoint(cx, cy)
    local x2, y2 = transformScenePoint(cx + n, cy)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt((dx * dx) + (dy * dy))
  end
  return n * math.abs(getSceneDrawScaleX())
end

local function scaleSceneLengthY(v)
  local n = tonumber(v) or 0
  if isProjectiveSceneTransformActive() then
    local cx, cy = getSceneDrawCenter()
    local x1, y1 = transformScenePoint(cx, cy)
    local x2, y2 = transformScenePoint(cx, cy + n)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt((dx * dx) + (dy * dy))
  end
  return n * math.abs(getSceneDrawScaleY())
end

local function scaleSceneLength(v)
  local n = tonumber(v) or 0
  local sx = math.abs(getSceneDrawScaleX())
  local sy = math.abs(getSceneDrawScaleY())
  return n * ((sx + sy) * 0.5)
end

local function isIdentitySceneTransform()
  local runtime = _G and _G.CONFIG_UI
  if type(runtime) ~= "table" then return true end
  if runtime.sceneDrawProjective == true then
    return false
  end
  local offsetX = tonumber(runtime.sceneDrawOffsetX) or 0
  local drawAlpha = tonumber(runtime.sceneDrawAlpha)
  if drawAlpha == nil then drawAlpha = 1 end
  local sx = tonumber(runtime.sceneDrawScaleX)
  if sx == nil then sx = tonumber(runtime.sceneDrawScale) or 1 end
  local sy = tonumber(runtime.sceneDrawScaleY)
  if sy == nil then sy = tonumber(runtime.sceneDrawScale) or 1 end
  local yaw = tonumber(runtime.sceneDrawYawRad) or 0
  local pitch = tonumber(runtime.sceneDrawPitchRad) or 0
  return math.abs(offsetX) < 0.0001 and drawAlpha >= 0.999 and math.abs(yaw) < 0.0001 and math.abs(pitch) < 0.0001 and
      math.abs(sx - 1) < 0.0001 and
      math.abs(sy - 1) < 0.0001
end

local function installSceneDrawOffsetGraphicsProxy()
  local runtime = _G and _G.CONFIG_UI
  if type(runtime) ~= "table" then return end
  if runtime.sceneDrawOffsetGraphicsProxyInstalled then return end
  local rawGraphics = Graphics
  if type(rawGraphics) ~= "table" then return end
  runtime.rawGraphics = runtime.rawGraphics or rawGraphics
  rawGraphics = runtime.rawGraphics
  local wrappedCache = {}
  local unpackFn = table.unpack or unpack

  local function applySceneAlphaToColor(color)
    if type(color) ~= "number" then return color end
    local drawAlpha = getSceneDrawAlpha()
    if drawAlpha >= 0.999 then return color end
    local base = math.floor(color)
    local a = (base >> 24) & 0xFF
    local scaledA = math.floor(a * drawAlpha + 0.5)
    if scaledA < 0 then scaledA = 0 end
    if scaledA > 0x80 then scaledA = 0x80 end
    return (base & 0x00FFFFFF) | ((scaledA & 0xFF) << 24)
  end

  local function wrapDrawFn(name, fn)
    if name == "drawRect" then
      return function(x, y, width, height, color)
        if isIdentitySceneTransform() then
          return fn(x, y, width, height, color)
        end
        local c = (type(color) == "number") and applySceneAlphaToColor(color) or color
        if isProjectiveSceneTransformActive() and rawGraphics.drawQuad then
          local px = tonumber(x) or 0
          local py = tonumber(y) or 0
          local pw = tonumber(width) or 0
          local ph = tonumber(height) or 0
          local x1, y1 = transformScenePoint(px, py)
          local x2, y2 = transformScenePoint(px, py + ph)
          local x3, y3 = transformScenePoint(px + pw, py)
          local x4, y4 = transformScenePoint(px + pw, py + ph)
          return rawGraphics.drawQuad(x1, y1, x2, y2, x3, y3, x4, y4, c)
        end
        local tx, ty = transformScenePoint(x, y)
        local tw = math.max(0, scaleSceneLengthX(width))
        local th = math.max(0, scaleSceneLengthY(height))
        return fn(tx, ty, tw, th, c)
      end
    elseif name == "drawPixel" then
      return function(x, y, color)
        if isIdentitySceneTransform() then
          return fn(x, y, color)
        end
        local c = (type(color) == "number") and applySceneAlphaToColor(color) or color
        local tx, ty = transformScenePoint(x, y)
        return fn(tx, ty, c)
      end
    elseif name == "drawCircle" then
      return function(x, y, radius, color, fill)
        if isIdentitySceneTransform() then
          return fn(x, y, radius, color, fill)
        end
        local c = (type(color) == "number") and applySceneAlphaToColor(color) or color
        local tx, ty = transformScenePoint(x, y)
        local tr = math.max(0, scaleSceneLength(radius))
        return fn(tx, ty, tr, c, fill)
      end
    elseif name == "drawLine" then
      return function(x1, y1, x2, y2, color)
        if isIdentitySceneTransform() then
          return fn(x1, y1, x2, y2, color)
        end
        local c = (type(color) == "number") and applySceneAlphaToColor(color) or color
        local tx1, ty1 = transformScenePoint(x1, y1)
        local tx2, ty2 = transformScenePoint(x2, y2)
        return fn(tx1, ty1, tx2, ty2, c)
      end
    elseif name == "drawTriangle" then
      return function(x1, y1, x2, y2, x3, y3, ...)
        if isIdentitySceneTransform() then
          return fn(x1, y1, x2, y2, x3, y3, ...)
        end
        local args = { ... }
        for i = 1, math.min(3, #args) do
          if type(args[i]) == "number" then
            args[i] = applySceneAlphaToColor(args[i])
          end
        end
        local tx1, ty1 = transformScenePoint(x1, y1)
        local tx2, ty2 = transformScenePoint(x2, y2)
        local tx3, ty3 = transformScenePoint(x3, y3)
        return fn(tx1, ty1, tx2, ty2, tx3, ty3, unpackFn(args))
      end
    elseif name == "drawQuad" then
      return function(x1, y1, x2, y2, x3, y3, x4, y4, ...)
        if isIdentitySceneTransform() then
          return fn(x1, y1, x2, y2, x3, y3, x4, y4, ...)
        end
        local args = { ... }
        for i = 1, math.min(4, #args) do
          if type(args[i]) == "number" then
            args[i] = applySceneAlphaToColor(args[i])
          end
        end
        local tx1, ty1 = transformScenePoint(x1, y1)
        local tx2, ty2 = transformScenePoint(x2, y2)
        local tx3, ty3 = transformScenePoint(x3, y3)
        local tx4, ty4 = transformScenePoint(x4, y4)
        return fn(tx1, ty1, tx2, ty2, tx3, ty3, tx4, ty4, unpackFn(args))
      end
    elseif name == "drawImage" then
      return function(image, x, y, color)
        if isIdentitySceneTransform() then
          if color ~= nil then
            return fn(image, x, y, color)
          end
          return fn(image, x, y)
        end
        local c = color
        if type(c) == "number" then
          c = applySceneAlphaToColor(c)
        elseif getSceneDrawAlpha() < 0.999 then
          c = applySceneAlphaToColor(0x80808080)
        end
        local iw = (rawGraphics.getImageWidth and tonumber(rawGraphics.getImageWidth(image))) or 0
        local ih = (rawGraphics.getImageHeight and tonumber(rawGraphics.getImageHeight(image))) or 0
        if iw > 0 and ih > 0 and rawGraphics.drawImageQuad then
          local tx1, ty1 = transformScenePoint(x, y)
          local tx2, ty2 = transformScenePoint((tonumber(x) or 0), (tonumber(y) or 0) + ih)
          local tx3, ty3 = transformScenePoint((tonumber(x) or 0) + iw, (tonumber(y) or 0))
          local tx4, ty4 = transformScenePoint((tonumber(x) or 0) + iw, (tonumber(y) or 0) + ih)
          if c ~= nil then
            return rawGraphics.drawImageQuad(image, tx1, ty1, tx2, ty2, tx3, ty3, tx4, ty4, c)
          end
          return rawGraphics.drawImageQuad(image, tx1, ty1, tx2, ty2, tx3, ty3, tx4, ty4)
        end
        local tx, ty = transformScenePoint(x, y)
        if c ~= nil then
          return fn(image, tx, ty, c)
        end
        return fn(image, tx, ty)
      end
    elseif name == "drawScaleImage" then
      return function(image, x, y, width, height, color)
        if isIdentitySceneTransform() then
          if color ~= nil then
            return fn(image, x, y, width, height, color)
          end
          return fn(image, x, y, width, height)
        end
        local c = color
        if type(c) == "number" then
          c = applySceneAlphaToColor(c)
        elseif getSceneDrawAlpha() < 0.999 then
          c = applySceneAlphaToColor(0x80808080)
        end
        local px = tonumber(x) or 0
        local py = tonumber(y) or 0
        local pw = tonumber(width) or 0
        local ph = tonumber(height) or 0
        if rawGraphics.drawImageQuad then
          local tx1, ty1 = transformScenePoint(px, py)
          local tx2, ty2 = transformScenePoint(px, py + ph)
          local tx3, ty3 = transformScenePoint(px + pw, py)
          local tx4, ty4 = transformScenePoint(px + pw, py + ph)
          if c ~= nil then
            return rawGraphics.drawImageQuad(image, tx1, ty1, tx2, ty2, tx3, ty3, tx4, ty4, c)
          end
          return rawGraphics.drawImageQuad(image, tx1, ty1, tx2, ty2, tx3, ty3, tx4, ty4)
        end
        local tx, ty = transformScenePoint(px, py)
        local tw = scaleSceneLengthX(pw)
        local th = scaleSceneLengthY(ph)
        if c ~= nil then
          return fn(image, tx, ty, tw, th, c)
        end
        return fn(image, tx, ty, tw, th)
      end
    elseif name == "drawRotateImage" then
      return function(image, x, y, angle, color)
        if isIdentitySceneTransform() then
          if color ~= nil then
            return fn(image, x, y, angle, color)
          end
          return fn(image, x, y, angle)
        end
        local c = color
        if type(c) == "number" then
          c = applySceneAlphaToColor(c)
        elseif getSceneDrawAlpha() < 0.999 then
          c = applySceneAlphaToColor(0x80808080)
        end
        local tx, ty = transformScenePoint(x, y)
        local sceneScaleX = math.abs(getSceneDrawScaleX())
        local sceneScaleY = math.abs(getSceneDrawScaleY())
        if (math.abs(sceneScaleX - 1) > 0.0001 or math.abs(sceneScaleY - 1) > 0.0001) and rawGraphics.drawImageExtended and
            rawGraphics.getImageWidth and
            rawGraphics.getImageHeight then
          local iw = tonumber(rawGraphics.getImageWidth(image)) or 0
          local ih = tonumber(rawGraphics.getImageHeight(image)) or 0
          if iw > 0 and ih > 0 then
            if c ~= nil then
              return rawGraphics.drawImageExtended(image, tx, ty, 0, 0, iw, ih, iw * sceneScaleX, ih * sceneScaleY,
                tonumber(angle) or 0, c)
            end
            return rawGraphics.drawImageExtended(image, tx, ty, 0, 0, iw, ih, iw * sceneScaleX, ih * sceneScaleY,
              tonumber(angle) or 0)
          end
        end
        if c ~= nil then
          return fn(image, tx, ty, angle, c)
        end
        return fn(image, tx, ty, angle)
      end
    elseif name == "drawImageExtended" then
      return function(image, x, y, startx, starty, width, height, scale_x, scale_y, angle, color)
        if isIdentitySceneTransform() then
          if color ~= nil then
            return fn(image, x, y, startx, starty, width, height, scale_x, scale_y, angle, color)
          end
          return fn(image, x, y, startx, starty, width, height, scale_x, scale_y, angle)
        end
        local c = color
        if type(c) == "number" then
          c = applySceneAlphaToColor(c)
        elseif getSceneDrawAlpha() < 0.999 then
          c = applySceneAlphaToColor(0x80808080)
        end
        local tx, ty = transformScenePoint(x, y)
        local sx = (tonumber(scale_x) or tonumber(width) or 0) * math.abs(getSceneDrawScaleX())
        local sy = (tonumber(scale_y) or tonumber(height) or 0) * math.abs(getSceneDrawScaleY())
        if c ~= nil then
          return fn(image, tx, ty, startx, starty, width, height, sx, sy, angle, c)
        end
        return fn(image, tx, ty, startx, starty, width, height, sx, sy, angle)
      end
    elseif name == "drawPartialImage" then
      return function(image, x, y, startx, starty, endx, endy, color)
        if isIdentitySceneTransform() then
          if color ~= nil then
            return fn(image, x, y, startx, starty, endx, endy, color)
          end
          return fn(image, x, y, startx, starty, endx, endy)
        end
        local c = color
        if type(c) == "number" then
          c = applySceneAlphaToColor(c)
        elseif getSceneDrawAlpha() < 0.999 then
          c = applySceneAlphaToColor(0x80808080)
        end
        local px = tonumber(x) or 0
        local py = tonumber(y) or 0
        local pw = (tonumber(endx) or 0) - (tonumber(startx) or 0)
        local ph = (tonumber(endy) or 0) - (tonumber(starty) or 0)
        if rawGraphics.drawImageQuadPartial then
          local tx1, ty1 = transformScenePoint(px, py)
          local tx2, ty2 = transformScenePoint(px, py + ph)
          local tx3, ty3 = transformScenePoint(px + pw, py)
          local tx4, ty4 = transformScenePoint(px + pw, py + ph)
          if c ~= nil then
            return rawGraphics.drawImageQuadPartial(image, tx1, ty1, tx2, ty2, tx3, ty3, tx4, ty4, startx, starty, endx,
              endy, c)
          end
          return rawGraphics.drawImageQuadPartial(image, tx1, ty1, tx2, ty2, tx3, ty3, tx4, ty4, startx, starty, endx,
            endy)
        end
        local tx, ty = transformScenePoint(px, py)
        if c ~= nil then
          return fn(image, tx, ty, startx, starty, endx, endy, c)
        end
        return fn(image, tx, ty, startx, starty, endx, endy)
      end
    elseif name == "drawImageQuad" then
      return function(image, x1, y1, x2, y2, x3, y3, x4, y4, color)
        if isIdentitySceneTransform() then
          if color ~= nil then
            return fn(image, x1, y1, x2, y2, x3, y3, x4, y4, color)
          end
          return fn(image, x1, y1, x2, y2, x3, y3, x4, y4)
        end
        local c = color
        if type(c) == "number" then
          c = applySceneAlphaToColor(c)
        elseif getSceneDrawAlpha() < 0.999 then
          c = applySceneAlphaToColor(0x80808080)
        end
        local tx1, ty1 = transformScenePoint(x1, y1)
        local tx2, ty2 = transformScenePoint(x2, y2)
        local tx3, ty3 = transformScenePoint(x3, y3)
        local tx4, ty4 = transformScenePoint(x4, y4)
        if c ~= nil then
          return fn(image, tx1, ty1, tx2, ty2, tx3, ty3, tx4, ty4, c)
        end
        return fn(image, tx1, ty1, tx2, ty2, tx3, ty3, tx4, ty4)
      end
    elseif name == "drawImageQuadPartial" then
      return function(image, x1, y1, x2, y2, x3, y3, x4, y4, startx, starty, endx, endy, color)
        if isIdentitySceneTransform() then
          if color ~= nil then
            return fn(image, x1, y1, x2, y2, x3, y3, x4, y4, startx, starty, endx, endy, color)
          end
          return fn(image, x1, y1, x2, y2, x3, y3, x4, y4, startx, starty, endx, endy)
        end
        local c = color
        if type(c) == "number" then
          c = applySceneAlphaToColor(c)
        elseif getSceneDrawAlpha() < 0.999 then
          c = applySceneAlphaToColor(0x80808080)
        end
        local tx1, ty1 = transformScenePoint(x1, y1)
        local tx2, ty2 = transformScenePoint(x2, y2)
        local tx3, ty3 = transformScenePoint(x3, y3)
        local tx4, ty4 = transformScenePoint(x4, y4)
        if c ~= nil then
          return fn(image, tx1, ty1, tx2, ty2, tx3, ty3, tx4, ty4, startx, starty, endx, endy, c)
        end
        return fn(image, tx1, ty1, tx2, ty2, tx3, ty3, tx4, ty4, startx, starty, endx, endy)
      end
    end
    return fn
  end

  local proxy = {}
  setmetatable(proxy, {
    __index = function(_, key)
      local cached = wrappedCache[key]
      if cached ~= nil then return cached end
      local value = rawGraphics[key]
      if type(value) ~= "function" then
        wrappedCache[key] = value
        return value
      end
      local wrapped = wrapDrawFn(key, value)
      wrappedCache[key] = wrapped
      return wrapped
    end,
    __newindex = function(_, key, value)
      rawGraphics[key] = value
      wrappedCache[key] = nil
    end,
    __pairs = function()
      return pairs(rawGraphics)
    end,
  })
  Graphics = proxy
  runtime.sceneDrawOffsetGraphicsProxyInstalled = true
  runtime.sceneDrawOffsetGraphicsProxy = proxy
end

installSceneDrawOffsetGraphicsProxy()
local main = dofile("scripts/ui_main.lua")
local file_selector = dofile("scripts/file_selector.lua")
local config_options = dofile("scripts/options.lua")
_G.CONFIG_UI.file_selector = file_selector
_G.CONFIG_UI.config_options = config_options
_G.CONFIG_UI.main = main
-- State modules (editor, choose_save, etc.): each has .run(ctx) and reads/writes ctx.
local scene_editor = dofile("scripts/scenes/editor.lua")
local scene_choose_save = dofile("scripts/scenes/choose_save.lua")
local scene_menu_entries = dofile("scripts/scenes/menu_entries.lua")
local scene_menu_entry_edit = dofile("scripts/scenes/menu_entry_edit.lua")
local scene_entry_cdrom_options = dofile("scripts/scenes/entry_cdrom_options.lua")
local scene_entry_paths = dofile("scripts/scenes/entry_paths.lua")
local scene_entry_args = dofile("scripts/scenes/entry_args.lua")
local scene_bbl_hotkeys = dofile("scripts/scenes/bbl_hotkeys.lua")
local scene_bbl_irx_entries = dofile("scripts/scenes/bbl_irx_entries.lua")
local scene_bbl_hotkey_entries = dofile("scripts/scenes/bbl_hotkey_entries.lua")
local scene_bbl_hotkey_entry = dofile("scripts/scenes/bbl_hotkey_entry.lua")
local scene_bbl_hotkey_args = dofile("scripts/scenes/bbl_hotkey_args.lua")
local scene_text_input = dofile("scripts/scenes/text_input.lua")
local scene_path_picker = dofile("scripts/scenes/path_picker.lua")
local scene_egsm_editor = dofile("scripts/scenes/egsm_editor.lua")
local scene_egsm_value_edit = dofile("scripts/scenes/egsm_value_edit.lua")
local scene_katamari_easter_egg = dofile("scripts/scenes/katamari_easter_egg.lua")

local strings = _G.CONFIG_UI.strings
local editor_str = strings.editor
local menu_str = strings.menu_entries
local path_str = strings.path_picker
local common_str = strings.common
local text_str = strings.text_input
local dev_str = strings.devices

-- Local aliases so the rest of the file can stay unchanged
local PAD_UP, PAD_DOWN, PAD_LEFT, PAD_RIGHT = common.PAD_UP, common.PAD_DOWN, common.PAD_LEFT, common.PAD_RIGHT
local PAD_CROSS, PAD_CIRCLE, PAD_SELECT, PAD_START, PAD_TRIANGLE, PAD_SQUARE = common.PAD_CROSS, common.PAD_CIRCLE,
    common.PAD_SELECT, common.PAD_START, common.PAD_TRIANGLE, common.PAD_SQUARE
local PAD_L1, PAD_R1, PAD_L2, PAD_R2 = common.PAD_L1, common.PAD_R1, common.PAD_L2, common.PAD_R2
local WHITE, UNSELECTED_COLOR, DIM_COLOR, DISABLED_DIM_COLOR, BLACK = common.WHITE, common.UNSELECTED_COLOR, common.DIM_COLOR, common.DISABLED_DIM_COLOR, common.BACKGROUND_COLOR
local KEYBOARD_SELECTED_COLOR, SELECTED_COLOR, PREFIX_W = common.KEYBOARD_SELECTED_COLOR, common.SELECTED_COLOR, common.PREFIX_W
local SELECTED_DIM_COLOR = common.SELECTED_DIM_COLOR
local TEXT_CURSOR_COLOR = common.TEXT_CURSOR_COLOR
local FONT_SCALE = common.FONT_SCALE
local VALUE_MAX_LEN, VALUE_MAX_LEN_LONG = common.VALUE_MAX_LEN, common.VALUE_MAX_LEN_LONG
local KEYBOARD_ROWS, KEYBOARD_ROWS_SHIFTED, KEYBOARD_ROWS_TITLE_ID = common.KEYBOARD_ROWS, common.KEYBOARD_ROWS_SHIFTED,
    common.KEYBOARD_ROWS_TITLE_ID
local KEYBOARD_ROW_OFFSETS, KEYBOARD_ROW_OFFSETS_TITLE_ID = common.KEYBOARD_ROW_OFFSETS,
    common.KEYBOARD_ROW_OFFSETS_TITLE_ID
local KEY_BG, KEY_BG_SEL, KEY_BORDER, KEY_BORDER_SEL = common.KEY_BG, common.KEY_BG_SEL, common.KEY_BORDER,
    common.KEY_BORDER_SEL

local function refreshRuntimeColorAliases()
  WHITE, UNSELECTED_COLOR, DIM_COLOR, DISABLED_DIM_COLOR, BLACK = common.WHITE, common.UNSELECTED_COLOR, common.DIM_COLOR, common.DISABLED_DIM_COLOR, common.BACKGROUND_COLOR
  KEYBOARD_SELECTED_COLOR, SELECTED_COLOR, PREFIX_W = common.KEYBOARD_SELECTED_COLOR, common.SELECTED_COLOR, common.PREFIX_W
  SELECTED_DIM_COLOR = common.SELECTED_DIM_COLOR
  TEXT_CURSOR_COLOR = common.TEXT_CURSOR_COLOR
end

local function applyStartupVideoModeCnf()
  local modeKey = STARTUP_CFG and STARTUP_CFG.video_mode or nil
  if not modeKey or modeKey == "" or modeKey == "auto" then return end

  local selected = getVideoModeSpecForKey(modeKey)
  if not selected or type(selected.mode) ~= "number" then return end

  local ok, err = applyVideoModeSpec(selected)
  if ok then
    print("ui: startup video mode override from r3configurator.cnf (video_mode=" .. tostring(modeKey) .. ")")
  else
    print("ui: failed startup video mode override from r3configurator.cnf: " .. tostring(err))
  end
end

local function applyStartupSwapButtonsCnf()
  local enabled = (STARTUP_CFG and STARTUP_CFG.swap_buttons == true) and true or false
  if common.setSwapCrossCircle then
    common.setSwapCrossCircle(enabled)
  else
    common.SWAP_CROSS_CIRCLE = (enabled == true)
  end
  _G.CONFIG_UI.swapCrossCircle = enabled == true
  if enabled then
    print("ui: startup button swap override from r3configurator.cnf (swap_buttons=1)")
  end
end

local function parseStartupColorValue(raw)
  local value = tostring(raw or "")
  local trimmed = value:gsub("^%s+", ""):gsub("%s+$", "")
  if trimmed == "" then return nil end

  if trimmed:match("^[%x][%x][%x][%x][%x][%x]$") then
    return tonumber(trimmed:sub(1, 2), 16), tonumber(trimmed:sub(3, 4), 16), tonumber(trimmed:sub(5, 6), 16), 0x80
  end

  return nil
end

local STARTUP_COLOR_KEYS = {
  "cross", "square", "triangle", "circle",
  "selected", "selected_dim", "unselected", "dim", "background",
}

local STARTUP_COLOR_FIELDS = {
  cross = { "PAD_LABEL_CROSS" },
  square = { "PAD_LABEL_SQUARE" },
  triangle = { "PAD_LABEL_TRIANGLE" },
  circle = { "PAD_LABEL_CIRCLE" },
  selected = { "SELECTED_COLOR" },
  selected_dim = { "SELECTED_DIM_COLOR" },
  unselected = { "UNSELECTED_COLOR" },
  dim = { "DIM_COLOR", "DISABLED_DIM_COLOR" },
  background = { "BACKGROUND_COLOR" },
}

local STARTUP_DEFAULT_COLOR_FIELDS = {
  PAD_LABEL_CROSS = common.PAD_LABEL_CROSS,
  PAD_LABEL_SQUARE = common.PAD_LABEL_SQUARE,
  PAD_LABEL_TRIANGLE = common.PAD_LABEL_TRIANGLE,
  PAD_LABEL_CIRCLE = common.PAD_LABEL_CIRCLE,
  SELECTED_COLOR = common.SELECTED_COLOR,
  SELECTED_DIM_COLOR = common.SELECTED_DIM_COLOR,
  UNSELECTED_COLOR = common.UNSELECTED_COLOR,
  DIM_COLOR = common.DIM_COLOR,
  DISABLED_DIM_COLOR = common.DISABLED_DIM_COLOR,
  BACKGROUND_COLOR = common.BACKGROUND_COLOR,
}

local function applyStartupColorByKey(colorKey, raw)
  local r, g, b, a = parseStartupColorValue(raw)
  if not r then return false end
  local fields = STARTUP_COLOR_FIELDS[colorKey] or {}
  for i = 1, #fields do
    common[fields[i]] = Color.new(r, g, b, a)
  end
  return true
end

local function applyStartupDefaultColors()
  for field, color in pairs(STARTUP_DEFAULT_COLOR_FIELDS) do
    common[field] = color
  end
end

local function applyStartupColorsCnf()
  -- Always seed from built-in defaults first, then override from cnf keys (if present/valid).
  applyStartupDefaultColors()

  local hasStartupCnf = (STARTUP_CFG and STARTUP_CFG.path) and true or false
  local kv = hasStartupCnf and (STARTUP_CFG.colors or {}) or {}
  local applied = 0
  local seen = 0
  for i = 1, #STARTUP_COLOR_KEYS do
    local key = STARTUP_COLOR_KEYS[i]
    local raw = kv[key]
    if raw and raw ~= "" then
      seen = seen + 1
      if applyStartupColorByKey(key, raw) then
        applied = applied + 1
      else
        print("ui: r3configurator.cnf invalid value for " .. tostring(key) .. ": " .. tostring(raw))
      end
    end
  end

  refreshRuntimeColorAliases()
  _G.CONFIG_UI.colorsCnfActive = hasStartupCnf and (applied > 0) or false
  if not hasStartupCnf then
    print("ui: startup colors using built-in defaults (r3configurator.cnf missing or unreadable)")
  elseif applied > 0 then
    print("ui: startup colors override from r3configurator.cnf (" .. tostring(applied) .. " key(s) applied)")
  elseif seen > 0 then
    print("ui: startup colors override from r3configurator.cnf (all provided color values invalid; using defaults)")
  else
    print("ui: startup colors override from r3configurator.cnf (no color keys found; using defaults)")
  end
end

local function setSceneTransitionRuntime(transitionType, transitionFrames)
  local runtime = _G.CONFIG_UI or {}
  local normalizedType = (common.normalizeSceneTransitionType and common.normalizeSceneTransitionType(transitionType)) or
      tostring(transitionType or common.SCENE_TRANSITION_DEFAULT_TYPE)
  local normalizedFrames = (common.normalizeSceneTransitionFrames and common.normalizeSceneTransitionFrames(transitionFrames)) or
      math.floor(tonumber(transitionFrames) or common.SCENE_TRANSITION_DEFAULT_FRAMES)
  if not (common.normalizeSceneTransitionFrames) then
    if normalizedFrames < 1 then normalizedFrames = 1 end
    if normalizedFrames > 60 then normalizedFrames = 60 end
  end
  runtime.sceneTransitionType = normalizedType
  runtime.sceneTransitionFrames = normalizedFrames
  _G.CONFIG_UI = runtime
  return normalizedType, normalizedFrames
end

local function getSceneTransitionRuntime()
  local runtime = _G.CONFIG_UI or {}
  local transitionType = runtime.sceneTransitionType
  local transitionFrames = runtime.sceneTransitionFrames
  transitionType, transitionFrames = setSceneTransitionRuntime(transitionType, transitionFrames)
  return transitionType, transitionFrames
end

local function getPageTransitionDirectionFromPad(padMask)
  local mask = tonumber(padMask) or 0
  if (mask & PAD_CIRCLE) ~= 0 then
    return "out"
  end
  if (mask & PAD_CROSS) ~= 0 then
    return "in"
  end
  return "in"
end

local function scenePagePart(value)
  if value == nil then return "" end
  return tostring(value)
end

local function getVisibleScenePageKey(ctx, sceneName)
  if type(ctx) ~= "table" then return nil end
  local scene = tostring(sceneName or ctx.state or "")
  if scene == "" then return nil end

  if scene == "select_config" then
    local context = tostring(ctx.context or "")
    if context == "osdmenu" then
      if not ctx.osdmenuConfigDevice then
        return "select_config:osdmenu:device"
      end
      return "select_config:osdmenu:file:" .. scenePagePart(ctx.osdmenuConfigDevice) .. ":" ..
          scenePagePart(ctx.chosenMcSlot)
    elseif context == "mbr" then
      if not ctx.mbrConfigDevice then
        return "select_config:mbr:device"
      end
      return "select_config:mbr:file:" .. scenePagePart(ctx.mbrConfigDevice)
    elseif context == "hosdmenu" then
      return "select_config:hosdmenu:file"
    elseif context == "freemcboot" or context == "freehddboot" then
      return "select_config:" .. context .. ":file"
    elseif context == "ps2bbl" or context == "psxbbl" then
      return "select_config:" .. context .. ":device"
    end
    return "select_config:" .. context .. ":" .. scenePagePart(ctx.fileType)
  end

  if scene == "choose_load" then
    local count = (type(ctx.loadChoices) == "table") and #ctx.loadChoices or 0
    return "choose_load:" .. scenePagePart(ctx.context) .. ":" .. scenePagePart(ctx.fileType) .. ":" ..
        tostring(count)
  end

  if scene == "path_picker" then
    local sub = tostring(ctx.pathPickerSub or "")
    if sub == "browse" then
      return "path_picker:browse:" .. scenePagePart(ctx.pathBrowsePath)
    elseif sub == "partitions" then
      return "path_picker:partitions:" .. scenePagePart(ctx.pathBrowsePath)
    elseif sub == "device" then
      return "path_picker:device:" .. scenePagePart(ctx.pathPickerContext) .. ":" ..
          scenePagePart(ctx.pathPickerTarget)
    end
    return "path_picker:" .. sub
  end

  return scene
end

local function updateVisibleScenePageTransition(ctx, sceneName)
  if type(ctx) ~= "table" then return end
  local key = getVisibleScenePageKey(ctx, sceneName)
  if not key then return end
  local scene = tostring(sceneName or ctx.state or "")
  if scene == "path_picker" and (ctx.pathPickerLoading or ctx.pathPickerLoadingTimeoutMsg) then
    ctx._lastVisibleScenePageWasTransient = true
    return
  end
  if ctx._lastVisibleScenePageScene ~= scene then
    ctx._lastVisibleScenePageScene = scene
    ctx._lastVisibleScenePageKey = key
    return
  end
  if ctx._lastVisibleScenePageWasTransient then
    ctx._lastVisibleScenePageWasTransient = nil
    ctx._lastVisibleScenePageKey = key
    return
  end
  if ctx._lastVisibleScenePageKey == key then return end
  ctx._lastVisibleScenePageKey = key
  ctx._sceneEpoch = (tonumber(ctx._sceneEpoch) or 0) + 1
  if common.isSceneTransitionInActive and common.isSceneTransitionInActive(ctx) then
    return
  end
  local transitionType, transitionFrames = getSceneTransitionRuntime()
  if common.shouldRunSceneTransition and not common.shouldRunSceneTransition(transitionType, transitionFrames) then
    return
  end
  if common.beginSceneTransitionIn then
    common.beginSceneTransitionIn(ctx, transitionType, transitionFrames, {
      direction = getPageTransitionDirectionFromPad(ctx._lastPadEffective),
    })
  end
end

local function applyStartupSceneTransitionCnf()
  local transitionType = STARTUP_CFG and STARTUP_CFG.scene_transition or nil
  local transitionFrames = STARTUP_CFG and STARTUP_CFG.scene_transition_frames or nil
  local normalizedType, normalizedFrames = setSceneTransitionRuntime(transitionType, transitionFrames)
  _G.CONFIG_UI.setSceneTransitionConfig = setSceneTransitionRuntime
  _G.CONFIG_UI.getSceneTransitionConfig = getSceneTransitionRuntime
  if STARTUP_CFG and STARTUP_CFG.path then
    print("ui: scene transitions from r3configurator.cnf (type=" .. tostring(normalizedType) .. ", frames=" ..
      tostring(normalizedFrames) .. ")")
  end
end

local function getLocations(ctx, ft, slot, device) return config_options.getLocations(ctx, ft, slot, device) end
local function loadCustomFont() return common.loadCustomFont() end
local function drawText(font, mode, x, y, scale, text, color) return common.drawText(font, mode, x, y, scale, text, color) end
local function parseColor(v) return common.parseColor(v) end
local function formatColor(r, g, b, a) return common.formatColor(r, g, b, a) end

local function listDirectoryElfOnly(path)
  return common.listDirectoryElfOnly(path, file_selector)
end

local function resolveNextOsdItemKey(lines)
  local prefix = "path1_OSDSYS_ITEM_"
  local entries = config_parse.getByPrefix(lines, prefix)
  local maxN = 0
  for _, entry in ipairs(entries) do
    local num = entry.key and tonumber(entry.key:sub(#prefix + 1))
    if num and num > maxN then maxN = num end
  end
  return prefix .. tostring(maxN + 1)
end

local overlayLogoCache = {}
local overlayLogoKeepDigest = nil
local OVERLAY_LOGO_OPACITY = 0.25 -- 75% transparent
local OVERLAY_LOGO_OPACITY_R3 = 1.0 -- keep splash/title logo fully visible if selected
local OVERLAY_LOGO_R3_TITLE_KEY = "__r3_title__"
local OVERLAY_LOGO_R3_TITLE_SCALE = 0.50
local OVERLAY_LOGO_STICK_DEADZONE_PERCENT = 0.13
local OVERLAY_LOGO_STICK_DEADZONE = math.floor((127 * OVERLAY_LOGO_STICK_DEADZONE_PERCENT) + 0.5)
local OVERLAY_LOGO_STICK_SMOOTH = 0.22
local OVERLAY_LOGO_ROTATION_MAX_DEG = 180.0
local OVERLAY_LOGO_RADIUS_BASE = 3.00
local OVERLAY_LOGO_DEPTH_RADIUS_FRACTION = 0.40
local OVERLAY_LOGO_WARP_COLS = 8
local OVERLAY_LOGO_WARP_ROWS = 4
local OVERLAY_LOGO_EFFECTIVE_MIN = 0.60
local OVERLAY_LOGO_EFFECTIVE_MAX = 9.00
local OVERLAY_LOGO_CAMERA_MIN_DENOM = 0.20
local OVERLAY_LOGO_PERSPECTIVE_MIN_ABS = 0.04
local OVERLAY_LOGO_SCALE_MIN_ABS = 0.04
local OVERLAY_LOGO_SCALE_MAX_ABS = 2.40
local KATAMARI_EASTER_EGG_STATE = "katamari_easter_egg"
local KATAMARI_EASTER_EGG_TRIGGER_SECONDS = 10
local KATAMARI_EASTER_EGG_TRIGGER_FRAMES = math.max(1,
  math.floor((KATAMARI_EASTER_EGG_TRIGGER_SECONDS * 60) + 0.5))
local KATAMARI_EASTER_EGG_NEUTRAL_ALLOW_SECONDS = 0.5
local KATAMARI_EASTER_EGG_NEUTRAL_ALLOW_FRAMES = math.max(0,
  math.floor((KATAMARI_EASTER_EGG_NEUTRAL_ALLOW_SECONDS * 60) + 0.5))
local KATAMARI_EASTER_EGG_MOVE_THRESHOLD_NORMALIZED = 0.05

local function isValidImageHandle(img)
  return type(img) == "number" and img ~= 0
end

local function clampSignedAbs(v, minAbs, maxAbs)
  local n = tonumber(v) or 0
  local sign = (n < 0) and -1 or 1
  local a = math.abs(n)
  if a < minAbs then a = minAbs end
  if a > maxAbs then a = maxAbs end
  return sign * a
end

local function normalizeStickAxis(raw)
  local v = tonumber(raw) or 0
  local a = math.abs(v)
  if a <= OVERLAY_LOGO_STICK_DEADZONE then return 0 end
  local denom = 127 - OVERLAY_LOGO_STICK_DEADZONE
  if denom <= 0 then return 0 end
  local n = (a - OVERLAY_LOGO_STICK_DEADZONE) / denom
  if n > 1 then n = 1 end
  return (v < 0) and (-n) or n
end

local function readStickNormalized(getFn)
  if not getFn then return 0, 0, false, 0, 0 end
  local ok, x, y = pcall(getFn, 0)
  if not ok then
    ok, x, y = pcall(getFn)
  end
  if not ok then return 0, 0, false, 0, 0 end
  local rawX = tonumber(x) or 0
  local rawY = tonumber(y) or 0
  return normalizeStickAxis(rawX), normalizeStickAxis(rawY), true, rawX, rawY
end

local function readAnyStickState()
  local lx, ly, leftOk, lRawX, lRawY = readStickNormalized(Pads and Pads.getLeftStick)
  local rx, ry, rightOk, rRawX, rRawY = readStickNormalized(Pads and Pads.getRightStick)
  if not leftOk and not rightOk then
    return 0, 0, 0, 0, false
  end
  local invalidSignature = (math.abs(lRawX) >= 126 and math.abs(lRawY) >= 126 and
      math.abs(rRawX) >= 126 and math.abs(rRawY) >= 126)
  if invalidSignature then
    return 0, 0, 0, 0, false
  end
  local stickActive = not (lx == 0 and ly == 0 and rx == 0 and ry == 0)
  return lx, ly, rx, ry, stickActive
end

local function resetKatamariEasterEggCounters(ctx)
  ctx._katamariStickActiveFrames = 0
  ctx._katamariStickCountdownFrames = 0
  ctx._katamariStickNeutralFrames = 0
  ctx._katamariPrevLx = 0
  ctx._katamariPrevLy = 0
  ctx._katamariPrevRx = 0
  ctx._katamariPrevRy = 0
end

local function updateKatamariEasterEggTrigger(ctx, sceneName)
  if type(ctx) ~= "table" then return false end
  if ctx._katamariEasterEggTriggered == true then
    resetKatamariEasterEggCounters(ctx)
    return false
  end
  if sceneName == KATAMARI_EASTER_EGG_STATE or ctx.state == KATAMARI_EASTER_EGG_STATE then
    resetKatamariEasterEggCounters(ctx)
    return false
  end

  local lx, ly, rx, ry, stickActive = readAnyStickState()
  local requireRelease = (ctx._katamariStickRequireRelease == true)

  if requireRelease then
    resetKatamariEasterEggCounters(ctx)
    if not stickActive then
      ctx._katamariStickRequireRelease = nil
    end
    return false
  end

  local countdownFrames = math.max(0, math.floor(tonumber(ctx._katamariStickCountdownFrames) or 0))
  local activeFrames = math.max(0, math.floor(tonumber(ctx._katamariStickActiveFrames) or 0))
  local neutralFrames = math.max(0, math.floor(tonumber(ctx._katamariStickNeutralFrames) or 0))
  local prevLx = tonumber(ctx._katamariPrevLx) or 0
  local prevLy = tonumber(ctx._katamariPrevLy) or 0
  local prevRx = tonumber(ctx._katamariPrevRx) or 0
  local prevRy = tonumber(ctx._katamariPrevRy) or 0
  local moveThreshold = tonumber(KATAMARI_EASTER_EGG_MOVE_THRESHOLD_NORMALIZED) or 0.05
  if moveThreshold < 0 then moveThreshold = 0 end

  local movementDelta = math.abs(lx - prevLx) + math.abs(ly - prevLy) + math.abs(rx - prevRx) + math.abs(ry - prevRy)
  local stickMoving = (stickActive and movementDelta >= moveThreshold)

  ctx._katamariPrevLx = lx
  ctx._katamariPrevLy = ly
  ctx._katamariPrevRx = rx
  ctx._katamariPrevRy = ry

  if stickMoving then
    countdownFrames = countdownFrames + 1
    activeFrames = activeFrames + 1
  elseif countdownFrames > 0 then
    countdownFrames = countdownFrames + 1
    neutralFrames = neutralFrames + 1
  else
    resetKatamariEasterEggCounters(ctx)
    return false
  end

  ctx._katamariStickCountdownFrames = countdownFrames
  ctx._katamariStickActiveFrames = activeFrames
  ctx._katamariStickNeutralFrames = neutralFrames

  if neutralFrames > KATAMARI_EASTER_EGG_NEUTRAL_ALLOW_FRAMES then
    resetKatamariEasterEggCounters(ctx)
    return false
  end

  if countdownFrames >= KATAMARI_EASTER_EGG_TRIGGER_FRAMES then
    resetKatamariEasterEggCounters(ctx)
    ctx._katamariStickRequireRelease = true
    ctx._katamariEasterEggTriggered = true
    ctx.katamariEasterEggReturnState = sceneName
    ctx.state = KATAMARI_EASTER_EGG_STATE
    return true
  end

  return false
end

local function getOverlayLogoAnalogTransform(ctx)
  local state = ctx._overlayLogoAnalogState
  if type(state) ~= "table" then
    state = { lx = 0, ly = 0, rx = 0, ry = 0 }
    ctx._overlayLogoAnalogState = state
  end

  local lx, ly, leftOk, lRawX, lRawY = readStickNormalized(Pads and Pads.getLeftStick)
  local rx, ry, rightOk, rRawX, rRawY = readStickNormalized(Pads and Pads.getRightStick)
  if not leftOk and not rightOk then
    state.lx, state.ly, state.rx, state.ry = 0, 0, 0, 0
    return 1, 1, 0, 0, 0, 0
  end

  local invalidSignature = (math.abs(lRawX) >= 126 and math.abs(lRawY) >= 126 and
      math.abs(rRawX) >= 126 and math.abs(rRawY) >= 126)
  if invalidSignature then
    state.lx, state.ly, state.rx, state.ry = 0, 0, 0, 0
    return 1, 1, 0, 0, 0, 0
  end

  -- Centered sticks should produce exact identity (no residual drift/tilt/roll).
  if lx == 0 and ly == 0 and rx == 0 and ry == 0 then
    state.lx, state.ly, state.rx, state.ry = 0, 0, 0, 0
    return 1, 1, 0, 0, 0, 0
  end

  local smooth = OVERLAY_LOGO_STICK_SMOOTH
  state.lx = (tonumber(state.lx) or 0) + (lx - (tonumber(state.lx) or 0)) * smooth
  state.ly = (tonumber(state.ly) or 0) + (ly - (tonumber(state.ly) or 0)) * smooth
  state.rx = (tonumber(state.rx) or 0) + (rx - (tonumber(state.rx) or 0)) * smooth
  state.ry = (tonumber(state.ry) or 0) + (ry - (tonumber(state.ry) or 0)) * smooth

  -- Camera-orbit model (left stick):
  -- Yaw (left/right) and pitch (up/down) move the viewpoint along the sphere.
  -- This keeps horizontal and vertical perspective independent:
  -- left/right does not invert vertically, up/down does not invert horizontally.
  local yawRad = math.rad((state.lx or 0) * OVERLAY_LOGO_ROTATION_MAX_DEG)
  local pitchRad = math.rad((-(state.ly or 0)) * OVERLAY_LOGO_ROTATION_MAX_DEG)
  -- Camera position on sphere is conceptual here:
  -- x = R*sin(yaw)*cos(pitch), y = R*sin(pitch), z = R*cos(yaw)*cos(pitch)
  -- We intentionally keep axis-decoupled visual mapping below for predictable UX.

  -- Right stick up/down defines logo depth offset in world Z:
  -- up => farther (logo appears farther), down => closer.
  -- Right stick left/right is currently reserved (no-op).
  local baseRadius = tonumber(OVERLAY_LOGO_RADIUS_BASE) or 3.00
  if baseRadius < 0.10 then baseRadius = 0.10 end
  local depthFraction = tonumber(OVERLAY_LOGO_DEPTH_RADIUS_FRACTION) or 0.40
  if depthFraction < 0 then depthFraction = 0 end
  local depthLimit = baseRadius * depthFraction
  local depthOffset = (-(state.ry or 0)) * depthLimit
  if depthOffset > depthLimit then depthOffset = depthLimit end
  if depthOffset < -depthLimit then depthOffset = -depthLimit end

  local effectiveDistance = baseRadius + depthOffset
  local effMin = tonumber(OVERLAY_LOGO_EFFECTIVE_MIN) or 0.60
  local effMax = tonumber(OVERLAY_LOGO_EFFECTIVE_MAX) or 9.00
  if effMin < 0.10 then effMin = 0.10 end
  if effMax < effMin then effMax = effMin end
  if effectiveDistance < effMin then effectiveDistance = effMin end
  if effectiveDistance > effMax then effectiveDistance = effMax end
  local radiusScale = baseRadius / effectiveDistance

  -- Fallback scales for engines without quad warping.
  local yawCos = math.cos(yawRad)
  local pitchCos = math.cos(pitchRad)
  if math.abs(yawCos) < OVERLAY_LOGO_PERSPECTIVE_MIN_ABS then
    yawCos = (yawCos < 0) and (-OVERLAY_LOGO_PERSPECTIVE_MIN_ABS) or OVERLAY_LOGO_PERSPECTIVE_MIN_ABS
  end
  if math.abs(pitchCos) < OVERLAY_LOGO_PERSPECTIVE_MIN_ABS then
    pitchCos = (pitchCos < 0) and (-OVERLAY_LOGO_PERSPECTIVE_MIN_ABS) or OVERLAY_LOGO_PERSPECTIVE_MIN_ABS
  end
  local sx = clampSignedAbs(yawCos * radiusScale, OVERLAY_LOGO_SCALE_MIN_ABS, OVERLAY_LOGO_SCALE_MAX_ABS)
  local sy = clampSignedAbs(pitchCos * radiusScale, OVERLAY_LOGO_SCALE_MIN_ABS, OVERLAY_LOGO_SCALE_MAX_ABS)

  -- Camera orbit does not roll around view axis by default.
  return sx, sy, 0, yawRad, pitchRad, depthOffset
end

local function projectOverlayLogoQuadCorners(cx, cy, halfW, halfH, yawRad, pitchRad, depthOffset)
  local hw = tonumber(halfW) or 0
  local hh = tonumber(halfH) or 0
  if hw <= 0 or hh <= 0 then return nil end

  local radius = tonumber(OVERLAY_LOGO_RADIUS_BASE) or 3.00
  local focal = tonumber(OVERLAY_LOGO_RADIUS_BASE) or 3.00
  local minDen = tonumber(OVERLAY_LOGO_CAMERA_MIN_DENOM) or 0.20
  if radius < 0.10 then radius = 0.10 end
  if focal < 0.10 then focal = 0.10 end
  if minDen < 0.05 then minDen = 0.05 end

  local cyaw, syaw = math.cos(yawRad or 0), math.sin(yawRad or 0)
  local cpitch, spitch = math.cos(pitchRad or 0), math.sin(pitchRad or 0)

  -- Camera position on a sphere around world origin (logo center at origin).
  local camX = radius * syaw * cpitch
  local camY = radius * spitch
  local camZ = radius * cyaw * cpitch

  local function normalize3(x, y, z)
    local l = math.sqrt((x * x) + (y * y) + (z * z))
    if l <= 0.000001 then return 0, 0, 1 end
    return x / l, y / l, z / l
  end

  local function cross3(ax, ay, az, bx, by, bz)
    return (ay * bz) - (az * by), (az * bx) - (ax * bz), (ax * by) - (ay * bx)
  end

  local function dot3(ax, ay, az, bx, by, bz)
    return (ax * bx) + (ay * by) + (az * bz)
  end

  -- Camera basis built analytically from yaw/pitch to avoid pole flips/jumps.
  -- This stays continuous when pitch crosses +/-90 degrees.
  local fwdX, fwdY, fwdZ = normalize3(-syaw * cpitch, -spitch, -cyaw * cpitch)
  local rightX, rightY, rightZ = normalize3(cyaw, 0, -syaw)
  local upX, upY, upZ = cross3(rightX, rightY, rightZ, fwdX, fwdY, fwdZ)
  upX, upY, upZ = normalize3(upX, upY, upZ)

  local aspectY = hh / math.max(hw, 0.0001)
  local unit = hw
  local centerOffset = tonumber(depthOffset) or 0
  -- Keep right-stick depth in world space (default view axis), not camera-forward.
  -- This way left-stick orbit reveals a different camera path/radius feel instead
  -- of the logo following the camera and appearing to only rotate around itself.
  local centerX = 0
  local centerY = 0
  local centerZ = -centerOffset

  local function project(px, py)
    -- Logo plane in world-space, centered at (0, 0, -depthOffset).
    local pX = centerX + px
    local pY = centerY + py
    local pZ = centerZ

    -- Point in camera-space.
    local vX = pX - camX
    local vY = pY - camY
    local vZ = pZ - camZ
    local xCam = dot3(vX, vY, vZ, rightX, rightY, rightZ)
    local yCam = dot3(vX, vY, vZ, upX, upY, upZ)
    local zCam = dot3(vX, vY, vZ, fwdX, fwdY, fwdZ)
    if zCam < minDen then zCam = minDen end

    local p = focal / zCam
    return cx + (xCam * unit * p), cy + (yCam * unit * p)
  end

  -- True geometry path: fixed plane extents.
  local ux = 1
  local uy = aspectY

  local ulx, uly = project(-ux, -uy)
  local blx, bly = project(-ux, uy)
  local urx, ury = project(ux, -uy)
  local brx, bry = project(ux, uy)

  return ulx, uly, blx, bly, urx, ury, brx, bry, project, aspectY
end

flushOverlayLogoCache = function()
  if Graphics and Graphics.freeImage then
    for key, tex in pairs(overlayLogoCache) do
      if isValidImageHandle(tex) then
        pcall(Graphics.freeImage, tex)
      end
      overlayLogoCache[key] = nil
    end
  else
    for key in pairs(overlayLogoCache) do
      overlayLogoCache[key] = nil
    end
  end
  overlayLogoKeepDigest = nil
end

local function digestOverlayLogoKeepSet(keepSet)
  local keys = {}
  for key, keep in pairs(keepSet or {}) do
    if keep == true then
      keys[#keys + 1] = tostring(key)
    end
  end
  table.sort(keys)
  return table.concat(keys, "|")
end

local function pruneOverlayLogoCache(keepSet)
  if Graphics and Graphics.freeImage then
    for key, tex in pairs(overlayLogoCache) do
      if not keepSet[key] then
        if isValidImageHandle(tex) then
          pcall(Graphics.freeImage, tex)
        end
        overlayLogoCache[key] = nil
      end
    end
  else
    for key in pairs(overlayLogoCache) do
      if not keepSet[key] then
        overlayLogoCache[key] = nil
      end
    end
  end
end

local function buildOverlayLogoKeepSet(ctx, isR3SettingsScene)
  local keep = {}
  if type(ctx) ~= "table" then return keep end

  if isR3SettingsScene then
    keep[OVERLAY_LOGO_R3_TITLE_KEY] = true
    return keep
  end

  if ctx.state == "main" and type(ctx.mainEntries) == "table" and #ctx.mainEntries > 0 then
    local count = #ctx.mainEntries
    local sel = math.floor(tonumber(ctx.mainSel) or 1)
    if sel < 1 then sel = 1 end
    if sel > count then sel = count end
    local function addByIndex(i)
      local idx = i
      if idx < 1 then idx = count end
      if idx > count then idx = 1 end
      local entry = ctx.mainEntries[idx]
      local key = tostring(entry and entry.logoKey or "")
      if key ~= "" then
        keep[key] = true
      end
    end
    -- Keep only current + one above + one below (with wraparound).
    addByIndex(sel)
    addByIndex(sel - 1)
    addByIndex(sel + 1)
    return keep
  end

  -- Once a main entry is selected and we leave main, keep only the in-use logo.
  local key = tostring(ctx.mainOverlayLogoKey or "")
  if key ~= "" then
    keep[key] = true
  end
  return keep
end

local function getOverlayLogoColor(key)
  local opacity = (key == "r3configurat3r") and OVERLAY_LOGO_OPACITY_R3 or OVERLAY_LOGO_OPACITY
  return Color.new(0x80, 0x80, 0x80, math.floor(0x80 * opacity + 0.5))
end

local function getSelectionOverlayLogoTexture(key)
  if not key or key == "" then return nil end
  local cached = overlayLogoCache[key]
  if cached ~= nil then
    return (cached ~= false) and cached or nil
  end

  local candidatePaths
  if key == OVERLAY_LOGO_R3_TITLE_KEY then
    candidatePaths = { "res/title.png", "res/logo_r3configurat3r.png" }
  else
    candidatePaths = { "res/logo_" .. tostring(key) .. ".png" }
  end

  for i = 1, #candidatePaths do
    local rawPath = candidatePaths[i]
    local resolvedPath = resolveStartupPath(rawPath)
    local tried = {}
    local loadPaths = {}
    if resolvedPath and resolvedPath ~= "" then
      loadPaths[#loadPaths + 1] = resolvedPath
      tried[resolvedPath] = true
    end
    if rawPath and rawPath ~= "" and not tried[rawPath] then
      loadPaths[#loadPaths + 1] = rawPath
    end
    for j = 1, #loadPaths do
      local ok, img = pcall(Graphics.loadImage, loadPaths[j])
      if ok and isValidImageHandle(img) then
        if Graphics.setImageFilters and LINEAR then
          pcall(Graphics.setImageFilters, img, LINEAR)
        end
        overlayLogoCache[key] = img
        return img
      end
    end
  end

  overlayLogoCache[key] = false
  return nil
end

local function drawSelectionOverlayLogoKey(ctx, key, isR3SettingsScene, transform)
  if not ctx then return false end
  if not key or key == "" then return false end
  local tex = getSelectionOverlayLogoTexture(key)
  if not tex then return false end

  local sw = ctx.w or common.DEFAULT_W
  local sh = ctx.h or common.DEFAULT_H
  local iw = (Graphics.getImageWidth and Graphics.getImageWidth(tex)) or 0
  local ih = (Graphics.getImageHeight and Graphics.getImageHeight(tex)) or 0
  if iw <= 0 or ih <= 0 then return false end

  local maxW = math.floor(sw * 0.90)
  local maxH = math.floor(sh * 0.72)
  local scale = math.min(1.0, maxW / iw, maxH / ih)
  if isR3SettingsScene then
    scale = math.min(scale, OVERLAY_LOGO_R3_TITLE_SCALE)
  end
  local analogScaleX, analogScaleY, analogRoll, yawRad, pitchRad, depthOffset =
      getOverlayLogoAnalogTransform(ctx)
  if type(transform) == "table" then
    if transform.ignoreAnalog then
      analogScaleX, analogScaleY, analogRoll = 1, 1, 0
      yawRad, pitchRad, depthOffset = 0, 0, 0
    end
    if transform.scaleX ~= nil then analogScaleX = tonumber(transform.scaleX) or analogScaleX end
    if transform.scaleY ~= nil then analogScaleY = tonumber(transform.scaleY) or analogScaleY end
    if transform.roll ~= nil then analogRoll = tonumber(transform.roll) or analogRoll end
    if transform.yawRad ~= nil then yawRad = tonumber(transform.yawRad) or yawRad end
    if transform.pitchRad ~= nil then pitchRad = tonumber(transform.pitchRad) or pitchRad end
    if transform.depthOffset ~= nil then depthOffset = tonumber(transform.depthOffset) or depthOffset end
  end
  local baseW = math.max(1, math.floor(iw * scale + 0.5))
  local baseH = math.max(1, math.floor(ih * scale + 0.5))
  local halfW = baseW * 0.5
  local halfH = baseH * 0.5
  local drawW = baseW * analogScaleX
  local drawH = baseH * analogScaleY
  local cx = math.floor((sw / 2) + 0.5)
  local cy = math.floor((sh / 2) + 0.5)
  local color = getOverlayLogoColor(key)

  if Graphics.drawImageQuad then
    local ulx, uly, blx, bly, urx, ury, brx, bry, projectFn, aspectY =
        projectOverlayLogoQuadCorners(cx, cy, halfW, halfH, yawRad, pitchRad, depthOffset)
    if ulx and uly and blx and bly and urx and ury and brx and bry then
      if Graphics.drawImageQuadPartial and projectFn and aspectY then
        local cols = math.max(1, math.floor(tonumber(OVERLAY_LOGO_WARP_COLS) or 1))
        local rows = math.max(1, math.floor(tonumber(OVERLAY_LOGO_WARP_ROWS) or 1))
        if cols > 1 or rows > 1 then
          local spanY = 2 * aspectY
          for row = 0, rows - 1 do
            local v0 = row / rows
            local v1 = (row + 1) / rows
            local py0 = (-aspectY) + (spanY * v0)
            local py1 = (-aspectY) + (spanY * v1)
            for col = 0, cols - 1 do
              local u0 = col / cols
              local u1 = (col + 1) / cols
              local px0 = -1 + (2 * u0)
              local px1 = -1 + (2 * u1)
              local qx1, qy1 = projectFn(px0, py0)
              local qx2, qy2 = projectFn(px0, py1)
              local qx3, qy3 = projectFn(px1, py0)
              local qx4, qy4 = projectFn(px1, py1)
              Graphics.drawImageQuadPartial(tex, qx1, qy1, qx2, qy2, qx3, qy3, qx4, qy4, iw * u0, ih * v0, iw * u1,
                ih * v1, color)
            end
          end
          return true
        end
      end
      Graphics.drawImageQuad(tex, ulx, uly, blx, bly, urx, ury, brx, bry, color)
      return true
    end
  end

  if Graphics.drawImageExtended then
    Graphics.drawImageExtended(tex, cx, cy, 0, 0, iw, ih, drawW, drawH, analogRoll or 0, color)
  elseif Graphics.drawScaleImage then
    local dw = math.max(1, math.floor(math.abs(drawW) + 0.5))
    local dh = math.max(1, math.floor(math.abs(drawH) + 0.5))
    local x = math.floor((sw - dw) / 2)
    local y = math.floor((sh - dh) / 2)
    Graphics.drawScaleImage(tex, x, y, dw, dh, color)
  else
    local x = math.floor((sw - iw) / 2)
    local y = math.floor((sh - ih) / 2)
    Graphics.drawImage(tex, x, y, color)
  end
  return true
end

local function drawSelectionOverlayLogo(ctx)
  if not ctx then return end
  local isR3SettingsScene = (ctx.state ~= "main") and (ctx.context == "r3configurator")
  local keepSet = buildOverlayLogoKeepSet(ctx, isR3SettingsScene)
  local keepDigest = digestOverlayLogoKeepSet(keepSet)
  if keepDigest ~= overlayLogoKeepDigest then
    pruneOverlayLogoCache(keepSet)
    overlayLogoKeepDigest = keepDigest
  end
  if not isR3SettingsScene and ctx.state == "main" then
    local flip = ctx.mainLogoFlip
    if type(flip) == "table" and flip.active and flip.fromKey and flip.toKey then
      local frames = math.max(2, math.floor(tonumber(flip.frames) or 8))
      local frame = math.floor(tonumber(flip.frame) or 1)
      if frame < 1 then frame = 1 end
      if frame > frames then frame = frames end
      local phase1 = math.max(1, math.floor(frames / 2))
      local phase2Start = phase1 + 1
      local phase2Count = math.max(1, frames - phase1)
      local sign = (flip.direction == "down") and -1 or 1
      local key = nil
      local pitchRad = 0

      if frame <= phase1 then
        local t = frame / phase1
        pitchRad = sign * t * (math.pi * 0.5)
        key = flip.fromKey
      else
        local t = 0
        if phase2Count > 1 then
          t = (frame - phase2Start) / (phase2Count - 1)
        end
        if t < 0 then t = 0 end
        if t > 1 then t = 1 end
        pitchRad = (-sign) * (1 - t) * (math.pi * 0.5)
        key = flip.toKey
      end

      local drawn = drawSelectionOverlayLogoKey(ctx, key, false, {
        ignoreAnalog = true,
        yawRad = 0,
        pitchRad = pitchRad,
        depthOffset = 0,
      })
      if not drawn then
        drawSelectionOverlayLogoKey(ctx, flip.toKey, false, nil)
      end

      if frame >= frames then
        flip.active = false
        flip.frame = frames
        ctx.mainOverlayLogoKey = flip.toKey
      else
        flip.frame = frame + 1
      end
      return
    end
  end

  local key = isR3SettingsScene and OVERLAY_LOGO_R3_TITLE_KEY or ctx.mainOverlayLogoKey
  drawSelectionOverlayLogoKey(ctx, key, isR3SettingsScene, nil)
end

local function mainLoop()
  local font, drawMode = loadCustomFont()
  local function drawListRow(x, y, selected, label, col)
    drawText(font, drawMode, x, y, FONT_SCALE, label, col)
  end

  local ctx = scene_module.initContext()
  ctx.font, ctx.drawMode, ctx.drawListRow = font, drawMode, drawListRow
  ctx.drawBackgroundLayer = drawSelectionOverlayLogo
  ctx._preSceneFrameHook = function(c, sceneName)
    if updateKatamariEasterEggTrigger(c, sceneName) then
      return true
    end
    updateVisibleScenePageTransition(c, sceneName)
    return false
  end
  ctx.main = {
    (strings.main.main_freemcboot or "FreeMCBoot"),
    (strings.main.main_freehddboot or "FreeHDBoot"),
    (strings.main.main_osdmenu or "OSDMenu"),
    (strings.main.main_osdmenu_mbr or "OSDMenu MBR"),
    (strings.main.main_hosdmenu or "HOSDMenu"),
    (strings.main.main_ps2bbl_mc or "PS2BBL"),
    (strings.main.main_psxbbl_mc or "PSXBBL"),
  }
  if config_options.isEgsmUiEnabled and config_options.isEgsmUiEnabled() then
    table.insert(ctx.main, 6, (strings.main.main_egsm or "eGSM"))
  end

  local mainSel = 1
  local context, fileType, currentPath, lines = "ps2bbl", nil, nil, nil
  local chosenMcSlot = nil
  local state = "main"
  local mcSel = 1
  local hddReady = false
  local prevPad = 0
  local optList, optSel, optScroll, saveSplash = nil, 1, 0, nil
  local editKey = nil
  local pathPickerSub = nil
  local pathPickerSel, pathPickerScroll = 1, 0
  local pathBrowsePath, pathList = nil, nil
  local pathPickerTarget, pathPickerFileExts = nil, nil
  local isAddPath, addPathKey = false, nil
  local pathPickerContext = "osdmenu"
  local pfs1Mounted = nil
  local entryList, entrySel, entryScroll = {}, 1, 0
  local entryIdx, entryEditSub = nil, 1
  local pathPickerForEntryIdx = nil
  local pathPickerBblHotkeyKey, pathPickerBblHotkeySlot, pathPickerBblHotkeyDisabled = nil, nil, nil
  local pathPickerBblIrxIdx, pathPickerBblIrxDisabled = nil, nil
  local textInputPrompt, textInputValue, textInputMaxLen, textInputCallback = nil, "", 79, nil
  local textInputGridSel, textInputShift = 1, false
  local editorCategoryIdx = 0
  local loadChoices, loadSel = nil, 1
  local saveChoices, saveSel = nil, 1
  local entryPathSel, entryPathScroll = 1, 0
  local entryArgSel, entryArgScroll = 1, 0
  local bblIrxSel, bblIrxScroll = 1, 0
  local cdromOptSel = 1
  local pathPickerEditIdx, argEditIdx = nil, nil
  local textInputReturnState, textInputCursor, textInputScroll = "menu_entry_edit", 1, 1
  local holdFrameCount = 0
  local holdRepeatCountdown = 0
  local holdRepeatFps = 0
  local bootKey, pathPickerBootKey, pathPickerReturnState = nil, nil, nil
  local configModified, editorLeavePrompt, returnToSelectConfigAfterSave, returnToSelectConfigAfterSaveFlash = false, nil,
      nil, nil
  local openExplicitPath = nil

  local function syncToS(c)
    c.state, c.lines, c.currentPath, c.fileType, c.context = state, lines, currentPath, fileType, context
    c.chosenMcSlot, c.mainSel, c.mcSel, c.hddReady = chosenMcSlot, mainSel, mcSel, hddReady
    c.optList, c.optSel, c.optScroll, c.saveSplash = optList, optSel, optScroll, saveSplash
    c.editKey, c.pathPickerSub, c.pathPickerSel, c.pathPickerScroll = editKey, pathPickerSub, pathPickerSel,
        pathPickerScroll
    c.pathBrowsePath, c.pathList, c.pathPickerTarget, c.pathPickerFileExts = pathBrowsePath, pathList, pathPickerTarget,
        pathPickerFileExts
    c.isAddPath, c.addPathKey = isAddPath, addPathKey
    c.pathPickerContext, c.pfs1Mounted = pathPickerContext, pfs1Mounted
    c.entryList, c.entrySel, c.entryScroll = entryList, entrySel, entryScroll
    c.entryIdx, c.entryEditSub = entryIdx, entryEditSub
    c.pathPickerForEntryIdx = pathPickerForEntryIdx
    c.pathPickerBblHotkeyKey, c.pathPickerBblHotkeySlot, c.pathPickerBblHotkeyDisabled = pathPickerBblHotkeyKey,
        pathPickerBblHotkeySlot, pathPickerBblHotkeyDisabled
    c.pathPickerBblIrxIdx, c.pathPickerBblIrxDisabled = pathPickerBblIrxIdx, pathPickerBblIrxDisabled
    c.textInputPrompt, c.textInputValue, c.textInputMaxLen = textInputPrompt, textInputValue, textInputMaxLen
    c.textInputGridSel, c.textInputShift = textInputGridSel, textInputShift
    c.editorCategoryIdx = editorCategoryIdx
    c.loadChoices, c.loadSel = loadChoices, loadSel
    c.saveChoices, c.saveSel = saveChoices, saveSel
    c.entryPathSel, c.entryPathScroll = entryPathSel, entryPathScroll
    c.entryArgSel, c.entryArgScroll = entryArgSel, entryArgScroll
    c.bblIrxSel, c.bblIrxScroll = bblIrxSel, bblIrxScroll
    c.cdromOptSel = cdromOptSel
    c.pathPickerEditIdx, c.argEditIdx = pathPickerEditIdx, argEditIdx
    c.textInputReturnState, c.textInputCursor, c.textInputScroll = textInputReturnState, textInputCursor, textInputScroll
    c.bootKey, c.pathPickerBootKey, c.pathPickerReturnState = bootKey, pathPickerBootKey, pathPickerReturnState
    c.prevPad, c.holdFrameCount, c.holdRepeatCountdown, c.holdRepeatFps = prevPad, holdFrameCount,
        holdRepeatCountdown, holdRepeatFps
    c.configModified, c.editorLeavePrompt, c.returnToSelectConfigAfterSave, c.returnToSelectConfigAfterSaveFlash =
        configModified, editorLeavePrompt, returnToSelectConfigAfterSave, returnToSelectConfigAfterSaveFlash
    c.openExplicitPath = openExplicitPath
  end
  local function syncFromS(c)
    state, lines, currentPath, fileType, context = c.state, c.lines, c.currentPath, c.fileType, c.context
    chosenMcSlot, mainSel, mcSel, hddReady = c.chosenMcSlot, c.mainSel, c.mcSel, c.hddReady
    optList, optSel, optScroll, saveSplash = c.optList, c.optSel, c.optScroll, c.saveSplash
    editKey, pathPickerSub, pathPickerSel, pathPickerScroll = c.editKey, c.pathPickerSub, c.pathPickerSel,
        c.pathPickerScroll
    pathBrowsePath, pathList = c.pathBrowsePath, c.pathList
    pathPickerTarget, pathPickerFileExts = c.pathPickerTarget, c.pathPickerFileExts
    isAddPath, addPathKey = c.isAddPath, c.addPathKey
    pathPickerContext, pfs1Mounted = c.pathPickerContext, c.pfs1Mounted
    entryList, entrySel, entryScroll = c.entryList, c.entrySel, c.entryScroll
    entryIdx, entryEditSub = c.entryIdx, c.entryEditSub
    pathPickerForEntryIdx = c.pathPickerForEntryIdx
    pathPickerBblHotkeyKey, pathPickerBblHotkeySlot, pathPickerBblHotkeyDisabled = c.pathPickerBblHotkeyKey,
        c.pathPickerBblHotkeySlot, c.pathPickerBblHotkeyDisabled
    pathPickerBblIrxIdx, pathPickerBblIrxDisabled = c.pathPickerBblIrxIdx, c.pathPickerBblIrxDisabled
    textInputPrompt, textInputValue, textInputMaxLen = c.textInputPrompt, c.textInputValue, c.textInputMaxLen
    textInputGridSel, textInputShift = c.textInputGridSel, c.textInputShift
    editorCategoryIdx = c.editorCategoryIdx
    loadChoices, loadSel = c.loadChoices, c.loadSel
    saveChoices, saveSel = c.saveChoices, c.saveSel
    entryPathSel, entryPathScroll = c.entryPathSel, c.entryPathScroll
    entryArgSel, entryArgScroll = c.entryArgSel, c.entryArgScroll
    bblIrxSel, bblIrxScroll = c.bblIrxSel, c.bblIrxScroll
    cdromOptSel = c.cdromOptSel
    pathPickerEditIdx, argEditIdx = c.pathPickerEditIdx, c.argEditIdx
    textInputReturnState, textInputCursor, textInputScroll = c.textInputReturnState, c.textInputCursor, c
        .textInputScroll
    bootKey, pathPickerBootKey, pathPickerReturnState = c.bootKey, c.pathPickerBootKey, c.pathPickerReturnState
    prevPad, holdFrameCount, holdRepeatCountdown, holdRepeatFps = c.prevPad or prevPad, c.holdFrameCount or 0,
        c.holdRepeatCountdown or 0, c.holdRepeatFps or 0
    configModified, editorLeavePrompt, returnToSelectConfigAfterSave, returnToSelectConfigAfterSaveFlash =
        c.configModified, c.editorLeavePrompt, c.returnToSelectConfigAfterSave, c.returnToSelectConfigAfterSaveFlash
    openExplicitPath = c.openExplicitPath
  end

  -- One-frame dispatch for all states. Main-flow states use runSceneLoop; others use this.
  local function runOneFrame(c)
    syncFromS(c)
    if type(c._preSceneFrameHook) == "function" then
      c._preSceneFrameHook(c, state, 0)
      if type(c.state) == "string" and c.state ~= "" then
        state = c.state
      end
    end
    refreshRuntimeColorAliases()
    if _G and _G.CONFIG_UI then
      _G.CONFIG_UI.uiFrameCounter = (tonumber(_G.CONFIG_UI.uiFrameCounter) or 0) + 1
    end
    if not common.shouldSkipSceneClearForTransition(c) then
      Screen.clear(BLACK)
    end
    common.runLayout(c)
    common.applySceneDrawOffsetForCurrentFrame(c)
    local w = c.w or common.DEFAULT_W
    local h = c.h or common.DEFAULT_H
    local uiScale = c.uiScale or 1
    local scaleX = c.scaleX or function(x) return math.floor(((x or 0) * uiScale) + 0.5) end
    local scaleY = c.scaleY or function(y) return math.floor(((y or 0) * uiScale) + 0.5) end
    if _G.CONFIG_UI then
      _G.CONFIG_UI.currentUiScale = uiScale
      _G.CONFIG_UI.currentDrawWidth = math.max(1, scaleX(common.FT_DRAW_W))
      _G.CONFIG_UI.currentDrawHeight = math.max(1, scaleY(common.FT_DRAW_H))
    end
    local drawSceneBackgroundLayer = (state ~= "text_input" and state ~= KATAMARI_EASTER_EGG_STATE)
    if drawSceneBackgroundLayer and c.drawBackgroundLayer and
        (not common.shouldDrawBackgroundLayerForTransition or common.shouldDrawBackgroundLayerForTransition(c) ~= false) then
      if common.drawWithoutSceneTransform then
        common.drawWithoutSceneTransform(function()
          c.drawBackgroundLayer(c)
        end)
      else
        c.drawBackgroundLayer(c)
      end
    end
    local HINT_Y = c.HINT_Y
    local DESC_Y_BOTTOM = c.DESC_Y_BOTTOM
    local MARGIN_X = c.MARGIN_X or common.MARGIN_X
    local MARGIN_Y, LINE_H, ROW_H = c.MARGIN_Y, c.LINE_H, c.ROW_H
    local VALUE_X = c.VALUE_X or common.VALUE_X
    local KEYBOARD_CENTER_X = c.KEYBOARD_CENTER_X or ((c.uiOriginX or 0) + scaleX(common.KEYBOARD_CENTER_X))
    local KEYBOARD_CENTER_Y = c.KEYBOARD_CENTER_Y or ((c.uiOriginY or 0) + scaleY(common.KEYBOARD_CENTER_Y))
    local maxVisible = c.MAX_VISIBLE or common.MAX_VISIBLE
    local maxVisibleList = c.MAX_VISIBLE_LIST or common.MAX_VISIBLE_LIST
    local KEY_W = c.KEY_WIDTH or math.max(1, scaleX(common.KEY_WIDTH))
    local KEY_H = c.KEY_HEIGHT or math.max(1, scaleY(common.KEY_HEIGHT))
    local KEY_G = c.KEY_GAP or math.max(1, scaleX(common.KEY_GAP))
    local KEY_CW = c.KEY_CHAR_W or math.max(1, scaleX(common.KEY_CHAR_W))
    local KEY_LH = c.KEY_LINE_H or math.max(1, scaleY(common.KEY_LINE_H))
    common.applyFtPixelSize(c, font, drawMode, uiScale, false)
    c.prevPad = prevPad
    c.holdFrameCount = holdFrameCount
    c.holdRepeatCountdown = holdRepeatCountdown
    c.holdRepeatFps = holdRepeatFps
    local rawPadEffective = common.getPadEffective(c)
    local padEffective = common.shouldBlockInputForSceneTransition(c) and 0 or rawPadEffective
    c._lastPadEffective = padEffective
    prevPad = c.prevPad or prevPad
    holdFrameCount = c.holdFrameCount or 0
    holdRepeatCountdown = c.holdRepeatCountdown or 0
    holdRepeatFps = c.holdRepeatFps or holdRepeatFps
    -- Epochs are used by scene-level caches:
    -- scene epoch bumps on state transitions; input epoch bumps after button activity.
    c._sceneEpoch = c._sceneEpoch or 0
    c._inputEpoch = c._inputEpoch or 0
    if c._lastSceneForEpoch ~= state then
      c._sceneEpoch = c._sceneEpoch + 1
      c._lastSceneForEpoch = state
    end
    -- Refresh strings from CONFIG_UI so L1/R1 lang cycle in main menu takes effect in all states.
    local strings = (_G.CONFIG_UI and _G.CONFIG_UI.strings) or strings
    local editor_str = (strings and strings.editor) or editor_str
    local menu_str = (strings and strings.menu_entries) or menu_str
    local path_str = (strings and strings.path_picker) or path_str
    local common_str = (strings and strings.common) or common_str
    local text_str = (strings and strings.text_input) or text_str
    local dev_str = (strings and strings.devices) or dev_str
    -- Frame context for state modules: read/write c.*, use c._ for helpers and constants.
    c._ = {
      font = font,
      drawMode = drawMode,
      w = w,
      h = h,
      padEffective = padEffective,
      drawListRow = drawListRow,
      scaleX = scaleX,
      scaleY = scaleY,
      MARGIN_X = MARGIN_X,
      MARGIN_Y = MARGIN_Y,
      LINE_H = LINE_H,
      ROW_H = ROW_H,
      MAX_VISIBLE = maxVisible,
      MAX_VISIBLE_LIST = maxVisibleList,
      VALUE_X = VALUE_X,
      FONT_SCALE = FONT_SCALE,
      VALUE_MAX_LEN = VALUE_MAX_LEN,
      VALUE_MAX_LEN_LONG = VALUE_MAX_LEN_LONG,
      DESC_Y_BOTTOM = DESC_Y_BOTTOM,
      HINT_Y = HINT_Y,
      SELECTED_COLOR = SELECTED_COLOR,
      SELECTED_DIM_COLOR = SELECTED_DIM_COLOR,
      WHITE = WHITE,
      UNSELECTED_COLOR = UNSELECTED_COLOR,
      DIM_COLOR = DIM_COLOR,
      DISABLED_DIM_COLOR = DISABLED_DIM_COLOR,
      KEYBOARD_SELECTED_COLOR = KEYBOARD_SELECTED_COLOR,
      TEXT_CURSOR_COLOR = TEXT_CURSOR_COLOR,
      drawText = drawText,
      common = common,
      config_parse = config_parse,
      config_options = config_options,
      strings = strings,
      editor_str = editor_str,
      menu_str = menu_str,
      path_str = path_str,
      common_str = common_str,
      text_str = text_str,
      dev_str = dev_str,
      getLocations = getLocations,
      parseColor = parseColor,
      formatColor = formatColor,
      listDirectoryElfOnly = listDirectoryElfOnly,
      resolveNextOsdItemKey = resolveNextOsdItemKey,
      file_selector = file_selector,
      Graphics = Graphics,
      Color = Color,
      KEYBOARD_CENTER_X = KEYBOARD_CENTER_X,
      KEYBOARD_CENTER_Y = KEYBOARD_CENTER_Y,
      KEY_WIDTH = KEY_W,
      KEY_HEIGHT = KEY_H,
      KEY_GAP = KEY_G,
      KEY_H = KEY_H,
      KEY_LH = KEY_LH,
      KEY_CHAR_W = KEY_CW,
      KEY_BG = KEY_BG,
      KEY_BG_SEL = KEY_BG_SEL,
      KEY_BORDER = KEY_BORDER,
      KEY_BORDER_SEL = KEY_BORDER_SEL,
      KEYBOARD_ROWS = KEYBOARD_ROWS,
      KEYBOARD_ROWS_SHIFTED = KEYBOARD_ROWS_SHIFTED,
      KEYBOARD_ROWS_TITLE_ID = KEYBOARD_ROWS_TITLE_ID,
      normalizeKeyboardLayout = common.normalizeKeyboardLayout,
      getKeyboardLayoutSpec = common.getKeyboardLayoutSpec,
      KEYBOARD_ROW_OFFSETS = KEYBOARD_ROW_OFFSETS,
      KEYBOARD_ROW_OFFSETS_TITLE_ID = KEYBOARD_ROW_OFFSETS_TITLE_ID,
      PAD_UP = PAD_UP,
      PAD_DOWN = PAD_DOWN,
      PAD_LEFT = PAD_LEFT,
      PAD_RIGHT = PAD_RIGHT,
      PAD_CROSS = PAD_CROSS,
      PAD_CIRCLE = PAD_CIRCLE,
      PAD_SELECT = PAD_SELECT,
      PAD_START = PAD_START,
      PAD_TRIANGLE = PAD_TRIANGLE,
      PAD_SQUARE = PAD_SQUARE,
      PAD_L1 = PAD_L1,
      PAD_R1 = PAD_R1,
      PAD_L2 = PAD_L2,
      PAD_R2 = PAD_R2,
    }

    local renderedState = state
    if state == "main" then
      main.runMain(ctx, padEffective)
      syncFromS(ctx)
    elseif state == "choose_mc" then
      main.runChooseMc(ctx, padEffective)
      syncFromS(ctx)
    elseif state == "select_config" then
      main.runSelectConfig(ctx, padEffective)
      syncFromS(ctx)
    elseif state == "initHdd" then
      main.runInitHdd(ctx, padEffective)
      syncFromS(ctx)
    elseif state == "open" then
      main.runOpen(ctx, padEffective)
      syncFromS(ctx)
    elseif state == "choose_load" then
      main.runChooseLoad(ctx, padEffective)
      syncFromS(ctx)
    elseif state == "editor" or state == "editor_categories" then
      syncToS(c)
      scene_editor.run(c)
      syncFromS(c)
    elseif state == "choose_save" then
      syncToS(c)
      scene_choose_save.run(c)
      syncFromS(c)
    elseif state == "menu_entries" then
      syncToS(c)
      scene_menu_entries.run(c)
      syncFromS(c)
    elseif state == "menu_entry_edit" then
      syncToS(c)
      scene_menu_entry_edit.run(c)
      syncFromS(c)
    elseif state == "entry_cdrom_options" then
      syncToS(c)
      scene_entry_cdrom_options.run(c)
      syncFromS(c)
    elseif state == "entry_paths" then
      syncToS(c)
      scene_entry_paths.run(c)
      syncFromS(c)
    elseif state == "entry_args" then
      syncToS(c)
      scene_entry_args.run(c)
      syncFromS(c)
    elseif state == "bbl_hotkeys" then
      syncToS(c)
      scene_bbl_hotkeys.run(c)
      syncFromS(c)
    elseif state == "bbl_irx_entries" then
      syncToS(c)
      scene_bbl_irx_entries.run(c)
      syncFromS(c)
    elseif state == "bbl_hotkey_entries" then
      syncToS(c)
      scene_bbl_hotkey_entries.run(c)
      syncFromS(c)
    elseif state == "bbl_hotkey_entry" then
      syncToS(c)
      scene_bbl_hotkey_entry.run(c)
      syncFromS(c)
    elseif state == "bbl_hotkey_args" then
      syncToS(c)
      scene_bbl_hotkey_args.run(c)
      syncFromS(c)
    elseif state == "egsm_editor" then
      syncToS(c)
      scene_egsm_editor.run(c)
      syncFromS(c)
    elseif state == "egsm_value_edit" then
      syncToS(c)
      scene_egsm_value_edit.run(c)
      syncFromS(c)
    elseif state == KATAMARI_EASTER_EGG_STATE then
      syncToS(c)
      scene_katamari_easter_egg.run(c)
      syncFromS(c)
    elseif state == "text_input" then
      syncToS(c)
      scene_text_input.run(c)
      syncFromS(c)
    elseif state == "path_picker" then
      syncToS(c)
      scene_path_picker.run(c)
      syncFromS(c)
    end

    -- Keep keyboard shoulder hints transition-consistent across scene changes.
    -- Non-keyboard scenes drive this row toward empty so it fades out instead of cutting.
    local runtime = _G and _G.CONFIG_UI
    local pendingShoulderFade = type(runtime) == "table" and type(runtime.keyboardShoulderFadeStates) == "table" and
        runtime.keyboardShoulderFadeStates["__keyboard_shoulder_hint_row__"] ~= nil
    local driveKeyboardShoulderRow = (type(runtime) == "table" and runtime.sceneTransitionAnimActive == true) or
        pendingShoulderFade
    if driveKeyboardShoulderRow and renderedState ~= "text_input" and renderedState ~= KATAMARI_EASTER_EGG_STATE and
        scene_text_input and type(scene_text_input.drawShoulderHints) == "function" then
      local shoulderTotalWidth = (c.w or common.DEFAULT_W) - (2 * (c.MARGIN_X or common.MARGIN_X))
      local ok, err = pcall(scene_text_input.drawShoulderHints, c, c._, {}, 0.7, shoulderTotalWidth,
        c.DIM_COLOR or DIM_COLOR or c.UNSELECTED_COLOR or UNSELECTED_COLOR)
      if not ok and c then
        if c._keyboardShoulderHintDrawErrorReported ~= true then
          c._keyboardShoulderHintDrawErrorReported = true
          print("ui: warning: drawShoulderHints failed (" .. tostring(err) .. ")")
        end
      end
    end

    common.refreshConfigModified(c)
    if renderedState ~= KATAMARI_EASTER_EGG_STATE then
      common.drawSaveSplash(c)
    end
    common.drawAndAdvanceSceneTransitionIn(c)
    syncFromS(c)
    if padEffective ~= 0 then
      c._inputEpoch = (c._inputEpoch or 0) + 1
    end

    prevPad = c.prevPad or prevPad
    syncToS(c)
    -- Present on vblank to reduce full-screen shimmer/tearing.
    Screen.waitVblankStart()
    Screen.flip()
    return c.state, c
  end

  local function getSceneTransitionDirectionFromPad(padMask)
    local mask = tonumber(padMask) or 0
    if (mask & PAD_CIRCLE) ~= 0 then
      return "out"
    end
    if (mask & PAD_CROSS) ~= 0 then
      return "in"
    end
    return nil
  end

  local function isSlideLikeSceneTransition(transitionType)
    local t = transitionType
    if common.normalizeSceneTransitionType then
      t = common.normalizeSceneTransitionType(t)
    end
    return t == "slide" or t == "whip_pan" or t == "zoom" or t == "flip_horizontal" or t == "flip_vertical"
  end

  local sceneSelectionSpecs = {
    main = {
      { field = "mainSel", top = 1 },
    },
    choose_mc = {
      { field = "mcSel", top = 1 },
    },
    select_config = {
      { kind = "select_config", top = 1 },
    },
    choose_load = {
      { field = "loadSel", top = 1 },
    },
    editor = {
      { field = "optSel", top = 1 },
      { field = "optScroll", top = 0 },
    },
    editor_categories = {
      { field = "optSel", top = 1 },
      { field = "optScroll", top = 0 },
    },
    choose_save = {
      { field = "saveSel", top = 1 },
    },
    menu_entries = {
      { field = "entrySel", top = 1 },
      { field = "entryScroll", top = 0 },
    },
    menu_entry_edit = {
      { field = "entryEditSub", top = 1 },
    },
    entry_cdrom_options = {
      { field = "cdromOptSel", top = 1 },
    },
    entry_paths = {
      { field = "entryPathSel", top = 1 },
      { field = "entryPathScroll", top = 0 },
    },
    entry_args = {
      { field = "entryArgSel", top = 1 },
      { field = "entryArgScroll", top = 0 },
    },
    bbl_hotkeys = {
      { field = "bblHotkeySel", top = 1 },
      { field = "bblHotkeyScroll", top = 0 },
    },
    bbl_irx_entries = {
      { field = "bblIrxSel", top = 1 },
      { field = "bblIrxScroll", top = 0 },
    },
    bbl_hotkey_entries = {
      { field = "bblEntrySel", top = 1 },
      { field = "bblEntryScroll", top = 0 },
    },
    bbl_hotkey_entry = {
      { field = "bblEntryDetailSel", top = 1 },
    },
    bbl_hotkey_args = {
      { field = "bblArgSel", top = 1 },
      { field = "bblArgScroll", top = 0 },
    },
    egsm_editor = {
      { field = "egsmSel", top = 1 },
    },
    egsm_value_edit = {
      { field = "egsmValueSel", top = 1 },
    },
    text_input = {
      { field = "textInputGridSel", top = 1 },
    },
    path_picker = {
      { field = "pathPickerSel", top = 1 },
      { field = "pathPickerScroll", top = 0 },
    },
  }

  local function getSelectConfigContextKey(c)
    return c.context or "__none__"
  end

  local function getSceneSelectionStack(c)
    if type(c._sceneSelectionStack) ~= "table" then
      c._sceneSelectionStack = {}
    end
    return c._sceneSelectionStack
  end

  local function captureSceneSelectionSnapshot(c, sceneName)
    local specs = sceneSelectionSpecs[sceneName]
    if type(specs) ~= "table" then
      return nil
    end
    local snap = { scene = sceneName, fields = {} }
    local hasData = false
    for i = 1, #specs do
      local spec = specs[i]
      if spec and spec.kind == "select_config" then
        local byContext = c.selectConfigSelByContext
        local ctxKey = getSelectConfigContextKey(c)
        local sel = type(byContext) == "table" and byContext[ctxKey] or nil
        if type(sel) == "number" then
          snap.selectConfig = {
            context = ctxKey,
            sel = math.floor(sel),
          }
          hasData = true
        end
      elseif spec and spec.field then
        local value = c[spec.field]
        if type(value) == "number" then
          snap.fields[spec.field] = value
          hasData = true
        end
      end
    end
    if not hasData then
      return nil
    end
    return snap
  end

  local function restoreSceneSelectionSnapshot(c, snap)
    if type(snap) ~= "table" then
      return
    end
    local fields = snap.fields
    if type(fields) == "table" then
      for field, value in pairs(fields) do
        c[field] = value
      end
    end
    local selectConfig = snap.selectConfig
    if type(selectConfig) == "table" then
      if type(c.selectConfigSelByContext) ~= "table" then
        c.selectConfigSelByContext = {}
      end
      local ctxKey = selectConfig.context or getSelectConfigContextKey(c)
      local sel = tonumber(selectConfig.sel) or 1
      c.selectConfigSelByContext[ctxKey] = math.floor(sel)
    end
  end

  local function resetSceneSelectionToTop(c, sceneName)
    local specs = sceneSelectionSpecs[sceneName]
    if type(specs) ~= "table" then
      return
    end
    for i = 1, #specs do
      local spec = specs[i]
      if spec and spec.kind == "select_config" then
        if type(c.selectConfigSelByContext) ~= "table" then
          c.selectConfigSelByContext = {}
        end
        c.selectConfigSelByContext[getSelectConfigContextKey(c)] = tonumber(spec.top) or 1
      elseif spec and spec.field then
        c[spec.field] = tonumber(spec.top) or 1
      end
    end
  end

  local function rememberSceneSelectionBeforeForward(c, sceneName)
    local snap = captureSceneSelectionSnapshot(c, sceneName)
    if not snap then
      return
    end
    local stack = getSceneSelectionStack(c)
    stack[#stack + 1] = snap
  end

  local function restoreSceneSelectionOnBack(c, sceneName)
    local stack = getSceneSelectionStack(c)
    for i = #stack, 1, -1 do
      local snap = stack[i]
      if snap and snap.scene == sceneName then
        restoreSceneSelectionSnapshot(c, snap)
        for j = #stack, i, -1 do
          stack[j] = nil
        end
        return
      end
    end
  end

  local function getSceneNavigationDirection(c, nextScene)
    local direction = getSceneTransitionDirectionFromPad(c and c._lastPadEffective)
    if direction == "in" or direction == "out" then
      return direction
    end
    -- Fallback for scene/page changes not driven by a direct pad edge this frame:
    -- if destination matches stack top, treat as back; otherwise treat as forward.
    local stack = getSceneSelectionStack(c)
    local top = stack[#stack]
    if top and top.scene == nextScene then
      return "out"
    end
    return "in"
  end

  local function applySceneSelectionNavigationPolicy(c, prevScene, nextScene)
    if not c then return end
    if type(prevScene) ~= "string" or type(nextScene) ~= "string" or prevScene == nextScene then return end
    if prevScene == KATAMARI_EASTER_EGG_STATE or nextScene == KATAMARI_EASTER_EGG_STATE then return end
    local direction = getSceneNavigationDirection(c, nextScene)
    if direction == "out" then
      restoreSceneSelectionOnBack(c, nextScene)
    else
      rememberSceneSelectionBeforeForward(c, prevScene)
      resetSceneSelectionToTop(c, nextScene)
    end
  end

  local function runSceneTransitionOnStateChange(c, prevScene, nextScene)
    if not c then return end
    if type(prevScene) ~= "string" or type(nextScene) ~= "string" or prevScene == nextScene then return end
    if prevScene == KATAMARI_EASTER_EGG_STATE or nextScene == KATAMARI_EASTER_EGG_STATE then
      c.sceneTransitionIn = nil
      return c
    end
    local direction = getSceneNavigationDirection(c, nextScene)
    -- Some scene changes (notably * -> open) are one-shot loaders that can
    -- immediately resolve to editor/choose_load. Resolve once up-front so
    -- transitions run against a stable destination scene.
    if nextScene == "open" and type(main) == "table" and type(main.runOpen) == "function" then
      c.state = "open"
      state = "open"
      main.runOpen(c, 0)
      if type(c.state) == "string" and c.state ~= "" then
        nextScene = c.state
      else
        nextScene = "open"
      end
      state = c.state
    end
    local transitionType, transitionFrames = getSceneTransitionRuntime()
    local normalizedType = transitionType
    if common.normalizeSceneTransitionType then
      normalizedType = common.normalizeSceneTransitionType(transitionType)
    end
    if normalizedType == "slide" then
      local totalFrames = common.normalizeSceneTransitionFrames and common.normalizeSceneTransitionFrames(transitionFrames) or
          transitionFrames
      totalFrames = math.max(2, math.floor(tonumber(totalFrames) or 2))
      local outFrames = math.max(1, math.floor(totalFrames / 2))
      local inFrames = math.max(1, totalFrames - outFrames)
      local incomingDirection = direction
      local outgoingDirection = (incomingDirection == "out" or incomingDirection == "back") and "in" or "out"
      local function runSlidePhase(sceneName, phase, frames, phaseDirection, lockState)
        c.state = sceneName
        state = sceneName
        c.sceneTransitionIn = nil
        common.beginSceneTransitionIn(c, normalizedType, frames, {
          direction = phaseDirection,
          phase = phase,
          -- Keep slide handoff bounded to a two-scene span.
          -- Outgoing moves 0 -> 0.5W, incoming moves 0.5W -> 0.
          distanceScale = 0.5,
        })
        while common.isSceneTransitionInActive(c) do
          local _next, newCtx = runOneFrame(c)
          c = newCtx or c
          if lockState then
            c.state = sceneName
            state = sceneName
          end
        end
      end
      runSlidePhase(prevScene, "out", outFrames, outgoingDirection, true)
      runSlidePhase(nextScene, "in", inFrames, incomingDirection, false)
      state = c.state
      return c
    end
    if normalizedType == "flip_horizontal" or normalizedType == "flip_vertical" then
      local totalFrames = common.normalizeSceneTransitionFrames and common.normalizeSceneTransitionFrames(transitionFrames) or
          transitionFrames
      totalFrames = math.max(2, math.floor(tonumber(totalFrames) or 2))
      local outFrames = math.max(1, math.floor(totalFrames / 2))
      local inFrames = math.max(1, totalFrames - outFrames)
      local flipBaseSign = ((direction == "out" or direction == "back") and 1) or -1
      local function runFlipPhase(sceneName, phase, frames, lockState)
        c.state = sceneName
        state = sceneName
        c.sceneTransitionIn = nil
        common.beginSceneTransitionIn(c, normalizedType, frames, {
          direction = direction,
          phase = phase,
          flipBaseSign = flipBaseSign,
        })
        while common.isSceneTransitionInActive(c) do
          local _next, newCtx = runOneFrame(c)
          c = newCtx or c
          -- Outgoing phase should stay on the source scene plane.
          -- Incoming phase must be allowed to progress naturally (e.g. open -> editor)
          -- so one-shot scene actions are not replayed.
          if lockState then
            c.state = sceneName
            state = sceneName
          end
        end
      end
      runFlipPhase(prevScene, "out", outFrames, true)
      runFlipPhase(nextScene, "in", inFrames, false)
      state = c.state
      return c
    end
    if common.normalizeSceneTransitionType and common.normalizeSceneTransitionType(transitionType) == "cross_dissolve" then
      c.sceneTransitionIn = nil
      common.beginSceneTransitionIn(c, transitionType, transitionFrames, { direction = direction })
      return c
    end
    if direction == "out" then
      c.sceneTransitionIn = nil
      if isSlideLikeSceneTransition(transitionType) then
        common.beginSceneTransitionIn(c, transitionType, transitionFrames, { direction = "out" })
      else
        common.playSceneTransitionOnCurrentFrame(c, "out", transitionType, transitionFrames)
      end
    else
      common.beginSceneTransitionIn(c, transitionType, transitionFrames, { direction = "in" })
    end
    return c
  end

  local sceneNames = { "main", "choose_mc", "select_config", "initHdd", "open", "choose_load", "editor",
    "editor_categories", "choose_save",
    "menu_entries", "menu_entry_edit", "entry_cdrom_options", "entry_paths", "entry_args", "bbl_hotkeys",
    "bbl_irx_entries",
    "bbl_hotkey_entries", "bbl_hotkey_entry", "bbl_hotkey_args", "egsm_editor", "egsm_value_edit", "text_input",
    "path_picker", KATAMARI_EASTER_EGG_STATE }
  local scenes = {}
  for _, name in ipairs(sceneNames) do scenes[name] = { run = runOneFrame } end
  -- Main-flow scenes use runSceneLoop (clear, layout, handler, flip until state change).
  local mainFlowHandlers = {
    main = main.runMain,
    choose_mc = main.runChooseMc,
    select_config = main.runSelectConfig,
    initHdd = main.runInitHdd,
    open = main.runOpen,
    choose_load = main.runChooseLoad,
  }
  for name, handler in pairs(mainFlowHandlers) do
    scenes[name] = {
      run = function(ctx)
        return common.runSceneLoop(ctx, name, handler)
      end,
    }
  end
  local currentScene = ctx.state
  while currentScene do
    local scene = scenes[currentScene]
    if not scene or not scene.run then break end
    local prevScene = currentScene
    local nextScene, newCtx = scene.run(ctx)
    ctx = newCtx
    applySceneSelectionNavigationPolicy(ctx, prevScene, nextScene)
    ctx = runSceneTransitionOnStateChange(ctx, prevScene, nextScene) or ctx
    -- Transition playback can legitimately advance state beyond nextScene
    -- (e.g. select_config -> open -> editor in one pass).
    -- Honor the effective state to avoid replaying one-shot scene handlers.
    currentScene = (ctx and ctx.state) or nextScene
  end
end

applyStartupVideoModeCnf()
applyStartupSwapButtonsCnf()
applyStartupSceneTransitionCnf()
applyStartupColorsCnf()
return mainLoop()
