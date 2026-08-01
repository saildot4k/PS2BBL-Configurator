--[[
  Main flow: main, choose_mc, select_config, initHdd, open, choose_load.
  run*(s, pad) where s has .common, .font, .drawMode, .drawListRow and state vars.
  Strings: try strings.lua (cwd override) then scripts/lang/strings_XX.lua. If CWD override, L1/R1 lang cycle is disabled.
  (Use loadfile for the optional CWD file: with VFS, pcall(dofile, path) can fail for paths not in VFS; loadfile returns nil if missing.)
]]

local startupPathCommon = (_G.CONFIG_UI and _G.CONFIG_UI.common) or nil

local function tryLoadStrings(path)
  local chunk = loadfile(path)
  if not chunk and startupPathCommon and startupPathCommon.beginPathAccess then
    local mounted, accessPath = startupPathCommon.beginPathAccess(path, {
      loadModule = true,
      mountPartition = true,
    })
    local probePath = accessPath or path
    chunk = loadfile(probePath)
    if startupPathCommon.endPathAccess then
      startupPathCommon.endPathAccess(mounted)
    end
  end
  if not chunk then return nil end
  local ok, t = pcall(chunk)
  return (ok and type(t) == "table") and t or nil
end

local startupDefaultLanguage = (_G.CONFIG_UI and _G.CONFIG_UI.startupDefaultLanguage) or nil

local strings = tryLoadStrings("strings.lua")
local cwdOverride = (strings ~= nil)
if not cwdOverride then
  if type(startupDefaultLanguage) == "string" and startupDefaultLanguage ~= "" then
    strings = tryLoadStrings("scripts/lang/strings_" .. startupDefaultLanguage .. ".lua")
  end
  if not strings then
    strings = dofile("scripts/lang/strings_en.lua")
  end
end
strings = strings or {}
_G.CONFIG_UI.strings = strings
_G.CONFIG_UI.langCycleDisabled = cwdOverride

local function defaultLanguageDisplayName(code)
  local names = {
    de = "Deutsch",
    en = "English",
    es = "Espanol",
    fr = "Francais",
  }
  return names[code] or ((type(code) == "string" and code ~= "") and code:upper() or "Language")
end

local function getLanguageCodeFromFile(file)
  return type(file) == "string" and file:match("^strings_(%w+)%.lua$") or nil
end

local function buildLanguageDisplayNames(files)
  local names = {}
  for i, file in ipairs(files or {}) do
    local code = getLanguageCodeFromFile(file)
    local displayName = defaultLanguageDisplayName(code)
    local langStrings = tryLoadStrings("scripts/lang/" .. file)
    if langStrings and type(langStrings.language_name) == "string" and langStrings.language_name ~= "" then
      displayName = langStrings.language_name
    elseif langStrings and type(langStrings.main) == "table" and type(langStrings.main.language_name) == "string" and
        langStrings.main.language_name ~= "" then
      displayName = langStrings.main.language_name
    end
    names[i] = displayName
  end
  return names
end

local function buildLanguageFileList()
  local list = {}
  local seen = {}

  local function addFileName(fileName)
    if type(fileName) ~= "string" then return end
    if not fileName:match("^strings_(%w+)%.lua$") then return end
    if seen[fileName] then return end
    seen[fileName] = true
    list[#list + 1] = fileName
  end

  local function scanDirectory(dirPath)
    if not (System and System.listDirectory) then return end
    local okList, listRaw = pcall(System.listDirectory, dirPath)
    if not okList or type(listRaw) ~= "table" then return end
    for i = 1, #listRaw do
      local e = listRaw[i]
      local name = nil
      local isDir = false
      if type(e) == "table" then
        name = e.name
        isDir = (e.directory == true)
      elseif type(e) == "string" then
        name = e
      end
      if (not isDir) and type(name) == "string" then
        addFileName(name)
      end
    end
  end

  -- Try both relative and absolute paths to support VFS and direct FS launches.
  scanDirectory("scripts/lang")
  scanDirectory("/scripts/lang")

  if #list == 0 then
    -- Fallback: probe known language files through VFS-aware loadfile path.
    local known = {
      "strings_en.lua",
      "strings_de.lua",
      "strings_es.lua",
      "strings_fr.lua",
      "strings_pl.lua",
      "strings_pt.lua",
    }
    for i = 1, #known do
      local file = known[i]
      if tryLoadStrings("scripts/lang/" .. file) then
        addFileName(file)
      end
    end
  end

  table.sort(list)
  return list
end

-- Build list of lang files (scripts/lang/strings_*.lua) for language cycle; only when not CWD override.
if not cwdOverride then
  local list = buildLanguageFileList()
  _G.CONFIG_UI.langFiles = list
  _G.CONFIG_UI.langDisplayNames = buildLanguageDisplayNames(list)
  local idx = 1
  local foundTarget = false
  local targetFile = nil
  if type(startupDefaultLanguage) == "string" and startupDefaultLanguage ~= "" then
    targetFile = "strings_" .. startupDefaultLanguage .. ".lua"
  end
  if targetFile then
    for i, f in ipairs(list) do
      if f == targetFile then
        idx = i
        foundTarget = true
        break
      end
    end
  end
  if not foundTarget then
    for i, f in ipairs(list) do
      if f == "strings_en.lua" then
        idx = i; break
      end
    end
  end
  _G.CONFIG_UI.langIndex = idx
else
  _G.CONFIG_UI.langFiles = nil
  _G.CONFIG_UI.langIndex = nil
  _G.CONFIG_UI.langDisplayNames = nil
end

local C = _G.CONFIG_UI
local common = C.common
local config_parse = C.config_parse
if common and common.onLanguageChanged then
  pcall(common.onLanguageChanged, nil, strings)
end

local PAD_UP, PAD_DOWN, PAD_CROSS, PAD_CIRCLE, PAD_SQUARE, PAD_TRIANGLE = common.PAD_UP, common.PAD_DOWN,
    common.PAD_CROSS, common.PAD_CIRCLE, common.PAD_SQUARE, common.PAD_TRIANGLE

local openDbg = common.makeDebugLogger("CONFIG_UI_OPEN_DEBUG", "[open] ")

local function countTrue(list)
  local n = 0
  for i = 1, #(list or {}) do
    if list[i] then n = n + 1 end
  end
  return n
end

local function getLanguageDisplayName(idx)
  local names = C.langDisplayNames
  if names and names[idx] and names[idx] ~= "" then
    return names[idx]
  end
  local code = getLanguageCodeFromFile(C.langFiles and C.langFiles[idx] or nil)
  return defaultLanguageDisplayName(code)
end

local function hasLanguageChoices()
  return not C.langCycleDisabled and C.langFiles and #C.langFiles > 1
end

local function getLanguageHintLabel(main_str)
  local baseHint = main_str.main_hint_items_with_lang or main_str.main_hint_items or {}
  local raw = common.findHintLabel(baseHint, "L1", common.findHintLabel(baseHint, "R1", "Language"))
  local cleaned = tostring(raw or ""):gsub("^%s+", ""):gsub("%s+$", "")
  cleaned = cleaned:gsub("%s*[%+%-]$", "")
  if cleaned == "" then cleaned = "Language" end
  return cleaned
end

local function getSettingsHintLabel(main_str)
  local raw = main_str.main_settings or "Settings"
  local cleaned = tostring(raw or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if cleaned == "" then cleaned = "Settings" end
  return cleaned
end

local function getCreditsHintLabel(main_str)
  local baseHint = main_str.main_hint_items or {}
  local raw = main_str.main_credits or common.findHintLabel(baseHint, "triangle", "Credits")
  local cleaned = tostring(raw or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if cleaned == "" then cleaned = "Credits" end
  return cleaned
end

local function buildMainCreditsLines(main_str)
  local spanishLabel = main_str.main_credits_language_spanish or "Spanish"
  local portugueseLabel = main_str.main_credits_language_portuguese or "Portuguese"
  return {
    main_str.main_credits_built_using or "Built Using:",
    "-Enceladus",
    main_str.main_credits_thanks_to or "Thanks to:",
    "-pcm720",
    "-R3Z3N",
    "-Berion",
    "-GhostTownUS",
    main_str.main_credits_translators or "Translators:",
    "-ViZoR: " .. tostring(spanishLabel),
    "-nuno: " .. tostring(portugueseLabel),
  }
end

local CREDITS_HEADING_BLUE = Color.new(0x36, 0x51, 0x72, 0x80)

local function buildMainBaseHintItems(main_str)
  local baseHint = main_str.main_hint_items or {}
  local enterLabel = common.findHintLabel(baseHint, "cross", "Enter")
  local exitLabel = common.findHintLabel(baseHint, "circle", common.findHintLabel(baseHint, "start", "Exit"))
  local settingsLabel = getSettingsHintLabel(main_str)
  local creditsLabel = getCreditsHintLabel(main_str)
  local out = {
    { pad = "cross", label = enterLabel, row = 1 },
    { pad = "square", label = settingsLabel, row = 1 },
    { pad = "circle", label = exitLabel, row = 1 },
  }
  table.insert(out, #out, { pad = "triangle", label = creditsLabel, row = 1 })
  return out
end

local function buildMainLanguageOverlayHintItems(main_str)
  local base = main_str.cross_select_circle_back_items or {}
  local selectLabel = common.findHintLabel(base, "cross", "Enter")
  local cancelLabel = (strings and strings.menu_entries and strings.menu_entries.cancel_label) or
      common.findHintLabel(base, "circle", "Cancel")
  local languageLabel = getLanguageHintLabel(main_str)
  return {
    { pad = "cross", label = selectLabel, row = 1 },
    { pad = "square", label = languageLabel, row = 1 },
    { pad = "circle", label = cancelLabel, row = 1 },
  }
end

local function buildMainCreditsOverlayHintItems(main_str)
  local base = main_str.cross_select_circle_back_items or {}
  local cancelLabel = (strings and strings.menu_entries and strings.menu_entries.cancel_label) or
      common.findHintLabel(base, "circle", "Back")
  local creditsLabel = getCreditsHintLabel(main_str)
  return {
    { pad = "triangle", label = creditsLabel, row = 1 },
    { pad = "circle", label = cancelLabel, row = 1 },
  }
end

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

local function clearSelectConfigAutoBackState(s)
  if not s then return end
  s.chosenMcSlotAuto = nil
  s.osdmenuConfigDeviceAuto = nil
  s.mbrConfigDeviceAuto = nil
  s.selectConfigSourceAuto = nil
  s.pendingKnownPathAuto = nil
  s.editorBackStateOverride = nil
end

local function clearAutoSourceBackState(s)
  if not s then return end
  s.selectConfigSourceAuto = nil
  s.pendingKnownPathAuto = nil
  s.editorBackStateOverride = nil
end

local function detectMainCnfFilter()
  local configured = (_G.CONFIG_UI and _G.CONFIG_UI.startupMainFilter) or nil
  if type(configured) == "table" then
    local out = {}
    local hasAny = false
    for id, enabled in pairs(configured) do
      if enabled == true or enabled == false then
        out[id] = enabled
        hasAny = true
      end
    end
    if hasAny then
      return out
    end
    return nil
  end
  return nil
end

local MAIN_CNF_FILTER = detectMainCnfFilter()

local MAIN_SHOW_KEY_TO_ID = {
  show_freemcboot = "freemcboot",
  show_freehddboot = "freehddboot",
  show_osdmenu = "osdmenu",
  show_osdmenu_mbr = "mbr",
  show_hosdmenu = "hosdmenu",
  show_ps2bbl = "ps2bbl",
  show_psxbbl = "psxbbl",
}

local MAIN_FILTER_KEY_ORDER = {
  "freemcboot",
  "freehddboot",
  "osdmenu",
  "mbr",
  "hosdmenu",
  "ps2bbl",
  "psxbbl",
}

local function parseMainFilterEnabled(value)
  if value == true then return true end
  if value == false then return false end
  local s = tostring(value or ""):lower()
  if s == "1" or s == "true" or s == "yes" or s == "on" then return true end
  if s == "0" or s == "false" or s == "no" or s == "off" then return false end
  return nil
end

local function getMainFilterBuildKey()
  if type(MAIN_CNF_FILTER) ~= "table" then
    return "all"
  end
  local parts = {}
  for i = 1, #MAIN_FILTER_KEY_ORDER do
    local id = MAIN_FILTER_KEY_ORDER[i]
    local enabled = MAIN_CNF_FILTER[id]
    if enabled == true then
      parts[#parts + 1] = id .. "=1"
    elseif enabled == false then
      parts[#parts + 1] = id .. "=0"
    end
  end
  if #parts == 0 then
    return "all"
  end
  return table.concat(parts, ";")
end

local function getRuntimePlatform()
  if common and common.getRuntimePlatform then
    return common.getRuntimePlatform()
  end
  local runtime = _G and _G.CONFIG_UI
  local platform = runtime and runtime.runtimePlatform
  if type(platform) == "table" then return platform end
  return {}
end

local function isRuntimePsx()
  if common and common.isRuntimePsx then
    return common.isRuntimePsx()
  end
  return getRuntimePlatform().isPsx == true
end

local function hideRuntimeHddDevices()
  if common and common.hideRuntimeHddDevices then
    return common.hideRuntimeHddDevices()
  end
  return getRuntimePlatform().hideHddDevices == true
end

local function getRuntimeFilterBuildKey()
  local platform = getRuntimePlatform()
  return "psx=" .. tostring(platform.isPsx == true) ..
      ";hdd=" .. tostring(platform.hideHddDevices == true) ..
      ";rom=" .. tostring(platform.romverPrefix or "")
end

local function setMainFilterFromShowKey(rawKey, value)
  local showKey = tostring(rawKey or ""):lower()
  local id = MAIN_SHOW_KEY_TO_ID[showKey]
  if not id then return false end
  local enabled = parseMainFilterEnabled(value)
  if enabled == nil then return false end
  if type(MAIN_CNF_FILTER) ~= "table" then
    MAIN_CNF_FILTER = {}
  end
  MAIN_CNF_FILTER[id] = enabled
  return true
end

C.setMainFilterFromShowKey = setMainFilterFromShowKey

local function includeMainEntry(id)
  if (id == "freehddboot" or id == "mbr" or id == "hosdmenu") and hideRuntimeHddDevices() then return false end
  if id == "psxbbl" and not isRuntimePsx() then return false end
  if MAIN_CNF_FILTER == nil then return true end
  local enabled = MAIN_CNF_FILTER[id]
  if enabled == nil then
    return true
  end
  return enabled == true
end

local MAIN_ENTRY_DEFAULT_DESCRIPTIONS = {
  freemcboot = "v1.966",
  freehddboot = "v1.966",
  osdmenu = "v1.3.0",
  mbr = "v1.3.0",
  hosdmenu = "v1.3.0",
  ps2bbl = "v2.0.0",
  psxbbl = "v2.0.0",
}

local function getMainEntryDescription(main_str, id)
  local key = tostring(id or "")
  if key == "" then return "" end
  local descs = main_str and main_str.main_entry_descriptions
  if type(descs) == "table" and type(descs[key]) == "string" then
    return descs[key]
  end
  local directKey = "main_" .. key .. "_desc"
  if type(main_str and main_str[directKey]) == "string" then
    return main_str[directKey]
  end
  return MAIN_ENTRY_DEFAULT_DESCRIPTIONS[key] or ""
end

local function buildMainEntries(main_str)
  local out = {}
  local function addEntry(entry)
    if includeMainEntry(entry.id) then
      entry.desc = entry.desc or getMainEntryDescription(main_str, entry.id)
      out[#out + 1] = entry
    end
  end

  addEntry({
    id = "freemcboot",
    label = main_str.main_freemcboot or "FreeMCBoot",
    logoKey = "freemcboot",
    context = "freemcboot",
    fileType = "freemcboot_cnf",
    state = "select_config",
  })
  addEntry({
    id = "freehddboot",
    label = main_str.main_freehddboot or "FreeHDBoot",
    logoKey = "freehdboot",
    context = "freehddboot",
    fileType = "freemcboot_cnf",
    state = "select_config",
  })
  addEntry({
    id = "osdmenu",
    label = main_str.main_osdmenu or "OSDMenu",
    logoKey = "osdmenu",
    context = "osdmenu",
    fileType = "osdmenu_cnf",
    state = "select_config",
  })
  addEntry({
    id = "mbr",
    label = main_str.main_osdmenu_mbr or "OSDMenu MBR",
    logoKey = "osdmenu_mbr",
    context = "mbr",
    fileType = "osdmbr_cnf",
    state = "select_config",
  })
  addEntry({
    id = "hosdmenu",
    label = main_str.main_hosdmenu or "HOSDMenu",
    logoKey = "hosdmenu",
    context = "hosdmenu",
    fileType = "osdmenu_cnf",
    state = "select_config",
  })
  if C.config_options and C.config_options.isEgsmUiEnabled and C.config_options.isEgsmUiEnabled() then
    addEntry({
      id = "egsm",
      label = main_str.main_egsm or "eGSM",
      logoKey = "osdmenu",
      context = "osdmenu",
      fileType = "osdgsm_cnf",
      state = "choose_mc",
    })
  end
  addEntry({
    id = "ps2bbl",
    label = main_str.main_ps2bbl_mc or "PS2BBL",
    logoKey = "ps2bbl",
    context = "ps2bbl",
    fileType = "ps2bbl_ini",
    state = "select_config",
  })
  addEntry({
    id = "psxbbl",
    label = main_str.main_psxbbl_mc or "PSXBBL",
    logoKey = "psxbbl",
    context = "psxbbl",
    fileType = "psxbbl_ini",
    state = "select_config",
  })

  return out
end

local function buildMainChoices(main_str)
  local entries = buildMainEntries(main_str)
  local out = {}
  for i = 1, #entries do
    out[i] = entries[i].label
  end
  return out, entries
end

local function applyLanguageFileIndex(s, idx)
  local files = C.langFiles
  if not files or #files < 1 then return false end
  local target = common.clampListSelection(idx or (C.langIndex or 1), #files)
  local newStrings = tryLoadStrings("scripts/lang/" .. files[target])
  if newStrings and type(newStrings) == "table" then
    strings = newStrings
    C.strings = newStrings
    C.langIndex = target
    if _G.CONFIG_UI then
      _G.CONFIG_UI.strings = newStrings
      local code = getLanguageCodeFromFile(files[target])
      if type(code) == "string" and code ~= "" then
        _G.CONFIG_UI.startupDefaultLanguage = code
      end
    end
    if s then
      local labels, entries = buildMainChoices(newStrings.main or {})
      s.main = labels
      s.mainEntries = entries
      s.mainBuildKey = nil
    end
    if common and common.onLanguageChanged then
      pcall(common.onLanguageChanged, s, newStrings)
    end
    return true
  end
  return false
end

local function applyLanguageIndex(s, idx)
  if not hasLanguageChoices() then return false end
  return applyLanguageFileIndex(s, idx)
end

local function applyLanguageCode(s, code)
  local targetCode = tostring(code or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if targetCode == "" then return false end
  local files = C.langFiles
  if not files or #files < 1 then return false end
  for i = 1, #files do
    local fileCode = getLanguageCodeFromFile(files[i])
    if type(fileCode) == "string" and fileCode:lower() == targetCode then
      return applyLanguageFileIndex(s, i)
    end
  end
  return false
end

C.applyLanguageCode = applyLanguageCode

local function isBblContext(context)
  if common and common.isBblContext then
    return common.isBblContext(context)
  end
  return context == "ps2bbl" or context == "psxbbl"
end

local function nextStateAfterMcSelection(s)
  if common and common.getNextStateAfterMcSelection then
    return common.getNextStateAfterMcSelection(s and s.context or nil)
  end
  if isBblContext(s.context) then return "select_config" end
  if s.context == "osdmenu" then return "select_config" end
  if s.context == "hosdmenu" then return "select_config" end
  return "open"
end

local function getOpenParentState(s)
  if common and common.getOpenParentState then
    return common.getOpenParentState(s and s.context or nil, s and s.fileType or nil)
  end
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
  if s.context == "hosdmenu" then
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

local function getMbrConfigDeviceSel(s)
  local sel = s and s.mbrConfigDeviceSel
  if type(sel) ~= "number" then return 1 end
  return math.floor(sel)
end

local function setMbrConfigDeviceSel(s, sel)
  if s then s.mbrConfigDeviceSel = sel end
end

local function getOsdmenuConfigDeviceSel(s)
  local sel = s and s.osdmenuConfigDeviceSel
  if type(sel) ~= "number" then return 1 end
  return math.floor(sel)
end

local function setOsdmenuConfigDeviceSel(s, sel)
  if s then s.osdmenuConfigDeviceSel = sel end
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

local function initEmptyLinesForFileType(s, reason)
  s.lines = config_parse.parse("")
  if s.fileType == "freemcboot_cnf" and C.config_options.getFreemcbootDefaults then
    for k, v in pairs(C.config_options.getFreemcbootDefaults()) do config_parse.set(s.lines, k, v) end
  elseif s.fileType == "osdmenu_cnf" and C.config_options.getOsdmenuDefaults then
    for k, v in pairs(C.config_options.getOsdmenuDefaults()) do config_parse.set(s.lines, k, v) end
  elseif s.fileType == "r3configurator_cnf" and C.config_options.r3configurator_cnf then
    for i = 1, #C.config_options.r3configurator_cnf do
      local o = C.config_options.r3configurator_cnf[i]
      if o and o.key and o.key:sub(1, 1) ~= "_" and o.default ~= nil then
        config_parse.set(s.lines, o.key, tostring(o.default))
      end
    end
  end
  openDbg("init empty lines", "fileType=" .. tostring(s.fileType), "reason=" .. tostring(reason),
    "lineCount=" .. tostring(#(s.lines or {})))
end

local function normalizeLoadedLinesForFileType(s)
  if s and s.fileType == "osdmenu_cnf" and config_parse.migrateOsdmenuBootOption then
    config_parse.migrateOsdmenuBootOption(s.lines)
  end
end

local function pathExists(path)
  local mounted, accessPath = common.beginPathAccess(path)
  local ok = common.tryOpen(accessPath or path)
  common.endPathAccess(mounted)
  openDbg("exists", "path=" .. tostring(path), "accessPath=" .. tostring(accessPath or path), "result=" .. tostring(ok))
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
  local mounted, accessPath = common.beginPathAccess(path)
  openDbg("load begin", "path=" .. tostring(path), "accessPath=" .. tostring(accessPath or path),
    "mounted=" .. tostring(mounted))
  local ok, lines, err = pcall(config_parse.load, accessPath or path)
  common.endPathAccess(mounted)
  if ok and lines then
    openDbg("load success", "path=" .. tostring(path), "entries=" .. tostring(#(lines or {})))
    return lines
  end
  if ok then
    openDbg("load failed", "path=" .. tostring(path), "error=" .. tostring(err))
    return nil, err
  end
  openDbg("load exception", "path=" .. tostring(path), "error=" .. tostring(lines))
  return nil, lines
end

local function setStateAfterLoad(s)
  if common.setCleanConfigSnapshot then
    common.setCleanConfigSnapshot(s, { needsInitialSave = false })
  else
    s.configModified = false
    s.configNeedsInitialSave = false
  end
  local isCategorized = (s.fileType == "osdmenu_cnf" or s.fileType == "freemcboot_cnf" or s.fileType == "osdmbr_cnf" or
      s.fileType == "ps2bbl_ini" or s.fileType == "psxbbl_ini")
  if s.fileType == "osdgsm_cnf" then
    s.state = "egsm_editor"
    s.egsmSel, s.egsmScroll = 1, 0
  else
    s.state = isCategorized and "editor_categories" or "editor"
    s.editorCategoryIdx = isCategorized and 0 or nil
    s.editorPendingEnterCategoryIdx = nil
    s.editorPendingReturnCategorySel = nil
    s.optList = isCategorized and nil or C.config_options[s.fileType]
    s.optSel, s.optScroll = 1, 0
    if not s.optList then s.optList = {} end
  end
  if s.fileType ~= "osdmbr_cnf" then clearPathPickerState(s) end
end

local function markNewInMemoryConfigState(s)
  if s and s.fileType == "r3configurator_cnf" then
    if common.setCleanConfigSnapshot then
      common.setCleanConfigSnapshot(s, { needsInitialSave = false })
    else
      s.configModified = false
      s.configNeedsInitialSave = false
    end
  else
    if common.markNewUnsavedConfig then
      common.markNewUnsavedConfig(s)
    else
      s.configModified = true
    end
  end
end

local function runMain(s, pad)
  local MAIN_LOGO_FLIP_FRAMES = 8
  local main_str = (C.strings and C.strings.main) or {}
  local dt, dlr = common.drawText, s.drawListRow
  local M = s.MARGIN_X or common.MARGIN_X
  local H = s.HINT_Y or common.HINT_Y
  local L = s.LINE_H or common.LINE_H
  local MY = s.MARGIN_Y or common.MARGIN_Y
  local sc = s.scaleY or function(y) return y end
  local SE = common.SELECTED_COLOR

  local egsmEnabled = (C.config_options and C.config_options.isEgsmUiEnabled and C.config_options.isEgsmUiEnabled()) or
      false
  local filterKey = getMainFilterBuildKey()
  local expectedBuildKey = tostring(egsmEnabled) .. "|" .. filterKey .. "|" .. getRuntimeFilterBuildKey()
  if type(s.main) ~= "table" or type(s.mainEntries) ~= "table" or s.mainBuildKey ~= expectedBuildKey then
    local labels, entries = buildMainChoices(main_str)
    s.main = labels
    s.mainEntries = entries
    s.mainBuildKey = expectedBuildKey
  end

  if #s.main < 1 then
    s.main = { main_str.main_freemcboot or "FreeMCBoot" }
    s.mainEntries = {
      {
        id = "freemcboot",
        label = main_str.main_freemcboot or "FreeMCBoot",
        logoKey = "freemcboot",
        context = "freemcboot",
        fileType = "freemcboot_cnf",
        state = "select_config",
      }
    }
  end

  local function getMainOverlayLogoKey(sel)
    local entry = s.mainEntries and s.mainEntries[sel]
    return entry and entry.logoKey or nil
  end

  local function getMainEntryById(id)
    local entryId = tostring(id or "")
    if entryId == "" then return nil end
    for i = 1, #(s.mainEntries or {}) do
      local entry = s.mainEntries[i]
      if entry and entry.id == entryId then
        return entry
      end
    end
    return nil
  end

  local function openMainEntry(entry)
    if not entry then return false end
    s.mainLogoFlip = nil
    s.mainOverlayLogoKey = entry.logoKey
    s.context = entry.context
    s.fileType = entry.fileType
    s.selectedKnownPath = nil
    s.openExplicitPath = nil
    s.chosenMcSlot = nil
    s.mbrConfigDevice = nil
    s.mbrConfigDeviceSel = nil
    s.osdmenuConfigDevice = nil
    s.osdmenuConfigDeviceSel = nil
    clearSelectConfigAutoBackState(s)
    clearLoadChoiceState(s)
    clearPathPickerState(s)
    s.state = entry.state
    return true
  end

  if s.mainSel < 1 then s.mainSel = 1 end
  if s.mainSel > #s.main then s.mainSel = #s.main end

  local function drawMainBaseUi()
    dt(s.font, s.drawMode, M, MY, 1.1, main_str.main_title or "", common.WHITE)
    local versionStr = (type(APP_VERSION) == "string" and APP_VERSION ~= "") and APP_VERSION or
        (main_str.version_unknown or "unknown")
    local vw = common.calcTextWidth(s.font, versionStr, 0.75) or (#versionStr * 9)
    local viewW = s.w or 640
    dt(s.font, s.drawMode, viewW - M - vw, MY, 0.75, versionStr, common.DIM_COLOR)
    dt(s.font, s.drawMode, M, MY + sc(22), 0.75, main_str.main_sub or "", common.DIM_COLOR)
    local hintItems = buildMainBaseHintItems(main_str)
    common.drawHintLine(s.font, s.drawMode, M, H, 0.7, hintItems or {}, nil, common.DIM_COLOR)
    local selectedEntry = s.mainEntries and s.mainEntries[s.mainSel]
    local descText = tostring((selectedEntry and selectedEntry.desc) or "")
    if descText ~= "" then
      local hintTypography = common.getHintTypography(s.font, s.drawMode)
      local hintDrawScale = hintTypography.drawScale
      local hintFont = hintTypography.font
      local hintTextH = hintTypography.textHeight
      local hintColor = common.UNSELECTED_COLOR or common.DIM_COLOR or common.WHITE
      local descMaxW = (s.w or 640) - (M * 2)
      local descRawW = (common.calcTextWidth and common.calcTextWidth(hintFont, descText, hintDrawScale)) or
          (#descText * 8)
      local useTicker = descRawW > descMaxW
      if useTicker then
        if common.fitListRowText then
          descText = common.fitListRowText(s, "main_desc_" .. tostring(selectedEntry.id or ""), hintFont, descText,
            descMaxW, hintDrawScale, true, { holdStart = 55, stepFrames = 16, holdEnd = 85 })
        elseif common.truncateTextToWidth then
          descText = common.truncateTextToWidth(hintFont, descText, descMaxW, hintDrawScale)
        end
      end
      local tw = (common.calcTextWidth and common.calcTextWidth(hintFont, descText, hintDrawScale)) or
          (#descText * 8)
      local x
      if useTicker then
        x = M
      else
        local startCenterX = common.getHintStartCenterX and common.getHintStartCenterX(s, (s.w or 640) - (2 * M))
        x = startCenterX and math.floor(startCenterX - (tw / 2) + 0.5) or common.centerX(s, tw)
      end
      dt(hintFont, s.drawMode, x, s.DESC_Y_BOTTOM or (H - common.PAD_HINT_TOTAL_H), hintDrawScale, descText,
        hintColor, hintTextH)
    end
    for i, label in ipairs(s.main) do
      local y = MY + sc(50) + (i - 1) * L
      local col = (i == s.mainSel) and SE or common.UNSELECTED_COLOR
      dlr(M + 20, y, i == s.mainSel, label, col)
    end
  end

  if s.mainLangPrompt and not hasLanguageChoices() then
    s.mainLangPrompt = nil
    s.mainLangSel = nil
    s.mainLangPromptAnim = nil
    s.mainLangPromptClosing = nil
  end
  if s.mainLangPrompt then
    local total = #C.langFiles
    s.mainLangSel = common.clampListSelection(s.mainLangSel or (C.langIndex or 1), total)
    local closing = s.mainLangPromptClosing == true
    local anim = tonumber(s.mainLangPromptAnim)
    if type(anim) ~= "number" then
      anim = closing and 1 or 0
    end
    if closing then
      anim = math.max(0, anim - (1 / 6))
    else
      anim = math.min(1, anim + (1 / 6))
    end
    s.mainLangPromptAnim = anim
    drawMainBaseUi()
    local maxVis = math.max(1, math.min(8, total))
    local scroll = common.centeredListScroll(s.mainLangSel, total, maxVis)
    local hintTypography = common.getHintTypography(s.font, s.drawMode)
    local textScale = hintTypography.textScale
    local rowScale = hintTypography.drawScale
    local hintFont = hintTypography.font
    local textH = hintTypography.textHeight
    local function textWidth(text, scale)
      local useScale = scale or rowScale
      if common.calcTextWidth then
        return common.calcTextWidth(hintFont, tostring(text or ""), useScale)
      end
      local str = tostring(text or "")
      return math.floor((8 * useScale) * #str)
    end

    local spaceW = textWidth(" ", rowScale)
    if spaceW < 1 then
      local probeW = textWidth("M", rowScale)
      if probeW < 1 then probeW = math.floor((8 * rowScale) + 0.5) end
      spaceW = math.max(2, math.floor((probeW * 0.32) + 0.5))
    end
    local markerW = textWidth(">", rowScale)
    if markerW < 1 then markerW = math.max(2, math.floor((spaceW * 1.2) + 0.5)) end
    local maxLabelWIntrinsic = 0
    for i = 1, total do
      local lw = textWidth(getLanguageDisplayName(i), rowScale)
      if lw > maxLabelWIntrinsic then maxLabelWIntrinsic = lw end
    end

    local padX = math.floor((sc(8) or 8) + 0.5)
    local padTop = math.floor((sc(6) or 6) + 0.5)
    local titleH = 0
    local titleGap = 0
    local padBottom = math.floor((sc(6) or 6) + 0.5)
    local rowStep = textH + math.max(2, math.floor((sc(3) or 3) + 0.5))

    local sideMargin = common.PAD_HINT_SIDE_MARGIN or 0
    local hintGridXShift = common.PAD_HINT_GRID_X_SHIFT or 0
    local hintGridExtraW = common.PAD_HINT_GRID_EXTRA_W or 0
    local hintTotalW = ((s.w or 640) - (2 * M)) + hintGridExtraW
    local hintXEff = M + sideMargin + hintGridXShift
    local hintWidthEff = hintTotalW - (2 * sideMargin)
    local slotW = hintWidthEff / 5
    local squareSlotLeft = hintXEff + slotW
    local squareSlotCenter = squareSlotLeft + (slotW / 2)
    local startSlotLeft = hintXEff + (2 * slotW)
    local startSlotCenter = startSlotLeft + (slotW / 2)
    local hintIconScale = tonumber(common.PAD_HINT_ICON_SCALE) or 0.54
    local hintIconW = math.max(10, math.floor(((common.PAD_ICON_W or 26) * hintIconScale) + 0.5))
    local hintGap = math.max(2, math.floor(((common.PAD_HINT_GAP or 5) * textScale) + 0.5))
    local squareButtonLeft = math.floor(squareSlotCenter - (hintIconW / 2))
    local startButtonLeft = math.floor(startSlotCenter - (hintIconW / 2))
    local desiredBoxX = squareButtonLeft
    local desiredRowLabelX = squareButtonLeft + hintIconW + hintGap
    local rowLabelOffset = desiredRowLabelX - desiredBoxX
    if rowLabelOffset < (padX + markerW + spaceW) then
      rowLabelOffset = padX + markerW + spaceW
    end
    local rightGap = math.max(3, math.floor((sc(4) or 4) + 0.5))
    local targetRightX = startButtonLeft - rightGap
    local desiredToStartW = math.floor(targetRightX - desiredBoxX + 0.5)
    if desiredToStartW < 90 then desiredToStartW = 90 end
    local contentW = math.max(90, math.floor((rowLabelOffset + maxLabelWIntrinsic + padX) + 0.5))
    local boxW = math.max(desiredToStartW, contentW)
    local maxBoxW = (s.w or 640) - (2 * M)
    if boxW > maxBoxW then boxW = maxBoxW end
    local boxH = padTop + titleH + titleGap + (maxVis * rowStep) + padBottom

    local hintRowH = math.max(14, math.floor(((common.PAD_HINT_ROW_H or 28) * textScale) + 0.5))
    local hintRowTop = math.floor(H) - hintRowH
    local finalBoxY = hintRowTop - boxH - math.max(2, math.floor((sc(2) or 2) + 0.5))
    local slideDist = math.max(10, math.floor((sc(14) or 14) + 0.5))
    local boxY = finalBoxY + math.floor((1 - anim) * slideDist)
    local boxX = desiredBoxX
    local minX = M
    local maxX = (s.w or 640) - boxW - M
    if boxX < minX then boxX = minX end
    if boxX > maxX then boxX = maxX end

    if Graphics and Graphics.drawRect then
      local alpha = math.floor(120 * anim + 0.5)
      if alpha < 0 then alpha = 0 end
      if alpha > 120 then alpha = 120 end
      Graphics.drawRect(boxX, boxY, boxW, boxH, Color.new(40, 40, 48, alpha))
    end

    local rowStartY = boxY + padTop + titleH + titleGap
    local rowLabelX = desiredRowLabelX
    local rowMarkerX = rowLabelX - markerW - spaceW
    local maxLabelW = (boxX + boxW) - padX - rowLabelX
    if maxLabelW < 1 then maxLabelW = 1 end

    for i = scroll + 1, math.min(scroll + maxVis, total) do
      local y = rowStartY + (i - scroll - 1) * rowStep
      local label = getLanguageDisplayName(i)
      if common.fitListRowText then
        label = common.fitListRowText(s, "main_lang_row_" .. tostring(i), hintFont, label, maxLabelW, rowScale,
          i == s.mainLangSel)
      elseif common.truncateTextToWidth then
        label = common.truncateTextToWidth(hintFont, label, maxLabelW, rowScale)
      end
      local col = (i == s.mainLangSel) and SE or common.UNSELECTED_COLOR
      if i == s.mainLangSel then
        dt(hintFont, s.drawMode, rowMarkerX, y, rowScale, ">", col)
      end
      dt(hintFont, s.drawMode, rowLabelX, y, rowScale, label, col)
    end
    local hintItems = buildMainLanguageOverlayHintItems(main_str)
    if Graphics and Graphics.drawRect then
      local hintBg = (common and common.BACKGROUND_COLOR) or Color.new(0, 0, 0, 0x80)
      local hintRowH = math.max(14, math.floor(((common.PAD_HINT_ROW_H or 28) * textScale) + 0.5))
      local hintRowTop = math.floor(H) - hintRowH
      local hintW = (s.w or 640) - (2 * M)
      Graphics.drawRect(M, hintRowTop, hintW, hintRowH, hintBg)
    end
    common.drawHintLine(s.font, s.drawMode, M, H, 0.7, hintItems, nil, common.DIM_COLOR)
    if not closing then
      if (pad & PAD_UP) ~= 0 then
        s.mainLangSel = common.wrapListSelection(s.mainLangSel, total, -1)
      end
      if (pad & PAD_DOWN) ~= 0 then
        s.mainLangSel = common.wrapListSelection(s.mainLangSel, total, 1)
      end
      if (pad & PAD_CROSS) ~= 0 then
        applyLanguageIndex(s, s.mainLangSel)
        s.mainLangPrompt = nil
        s.mainLangSel = nil
        s.mainLangPromptAnim = nil
        s.mainLangPromptClosing = nil
      elseif (pad & PAD_CIRCLE) ~= 0 or (pad & PAD_SQUARE) ~= 0 then
        s.mainLangPromptClosing = true
        if s.mainLangPromptAnim < 0.001 then
          s.mainLangPromptAnim = 1
        end
      end
    elseif anim <= 0.001 then
      s.mainLangPrompt = nil
      s.mainLangSel = nil
      s.mainLangPromptAnim = nil
      s.mainLangPromptClosing = nil
    end
    return
  end

  if s.mainCreditsPrompt then
    local closing = s.mainCreditsPromptClosing == true
    local anim = tonumber(s.mainCreditsPromptAnim)
    if type(anim) ~= "number" then
      anim = closing and 1 or 0
    end
    if closing then
      anim = math.max(0, anim - (1 / 6))
    else
      anim = math.min(1, anim + (1 / 6))
    end
    s.mainCreditsPromptAnim = anim
    drawMainBaseUi()

    local lines = buildMainCreditsLines(main_str)
    local total = #lines
    local hintTypography = common.getHintTypography(s.font, s.drawMode)
    local textScale = hintTypography.textScale
    local rowScale = hintTypography.drawScale
    local hintFont = hintTypography.font
    local textH = hintTypography.textHeight
    local function textWidth(text, scale)
      local useScale = scale or rowScale
      if common.calcTextWidth then
        return common.calcTextWidth(hintFont, tostring(text or ""), useScale)
      end
      local str = tostring(text or "")
      return math.floor((8 * useScale) * #str)
    end

    local maxLabelWIntrinsic = 0
    for i = 1, total do
      local lw = textWidth(lines[i], rowScale)
      if lw > maxLabelWIntrinsic then maxLabelWIntrinsic = lw end
    end

    local padX = math.floor((sc(8) or 8) + 0.5)
    local padTop = math.floor((sc(6) or 6) + 0.5)
    local padBottom = math.floor((sc(6) or 6) + 0.5)
    local rowStep = textH + math.max(2, math.floor((sc(3) or 3) + 0.5))

    local sideMargin = common.PAD_HINT_SIDE_MARGIN or 0
    local hintGridXShift = common.PAD_HINT_GRID_X_SHIFT or 0
    local hintGridExtraW = common.PAD_HINT_GRID_EXTRA_W or 0
    local hintTotalW = ((s.w or 640) - (2 * M)) + hintGridExtraW
    local hintXEff = M + sideMargin + hintGridXShift
    local hintWidthEff = hintTotalW - (2 * sideMargin)
    local slotW = hintWidthEff / 5
    local triangleSlotLeft = hintXEff + (3 * slotW)
    local triangleSlotCenter = triangleSlotLeft + (slotW / 2)
    local circleSlotLeft = hintXEff + (4 * slotW)
    local circleSlotCenter = circleSlotLeft + (slotW / 2)
    local hintIconScale = tonumber(common.PAD_HINT_ICON_SCALE) or 0.54
    local hintIconW = math.max(10, math.floor(((common.PAD_ICON_W or 26) * hintIconScale) + 0.5))
    local hintGap = math.max(2, math.floor(((common.PAD_HINT_GAP or 5) * textScale) + 0.5))
    local triangleButtonLeft = math.floor(triangleSlotCenter - (hintIconW / 2))
    local circleButtonLeft = math.floor(circleSlotCenter - (hintIconW / 2))
    local desiredBoxX = triangleButtonLeft
    local desiredRowLabelX = triangleButtonLeft + hintIconW + hintGap
    local rowLabelOffset = desiredRowLabelX - desiredBoxX
    if rowLabelOffset < padX then rowLabelOffset = padX end
    local rightGap = math.max(3, math.floor((sc(4) or 4) + 0.5))
    local targetRightX = circleButtonLeft - rightGap
    local desiredToCircleW = math.floor(targetRightX - desiredBoxX + 0.5)
    if desiredToCircleW < 90 then desiredToCircleW = 90 end
    local contentW = math.max(90, math.floor((rowLabelOffset + maxLabelWIntrinsic + padX) + 0.5))
    local boxW = math.max(desiredToCircleW, contentW)
    local maxBoxW = (s.w or 640) - (2 * M)
    if boxW > maxBoxW then boxW = maxBoxW end
    local boxH = padTop + (total * rowStep) + padBottom

    local hintRowH = math.max(14, math.floor(((common.PAD_HINT_ROW_H or 28) * textScale) + 0.5))
    local hintRowTop = math.floor(H) - hintRowH
    local finalBoxY = hintRowTop - boxH - math.max(2, math.floor((sc(2) or 2) + 0.5))
    local slideDist = math.max(10, math.floor((sc(14) or 14) + 0.5))
    local boxY = finalBoxY + math.floor((1 - anim) * slideDist)
    local boxX = desiredBoxX
    local minX = M
    local maxX = (s.w or 640) - boxW - M
    if boxX < minX then boxX = minX end
    if boxX > maxX then boxX = maxX end

    if Graphics and Graphics.drawRect then
      local alpha = math.floor(120 * anim + 0.5)
      if alpha < 0 then alpha = 0 end
      if alpha > 120 then alpha = 120 end
      Graphics.drawRect(boxX, boxY, boxW, boxH, Color.new(40, 40, 48, alpha))
    end

    local rowStartY = boxY + padTop
    local rowLabelX = boxX + rowLabelOffset
    local maxLabelW = (boxX + boxW) - padX - rowLabelX
    if maxLabelW < 1 then maxLabelW = 1 end
    local creditsHeadingColor = CREDITS_HEADING_BLUE
    for i = 1, total do
      local y = rowStartY + (i - 1) * rowStep
      local rawLabel = lines[i]
      local isHeading = type(rawLabel) == "string" and rawLabel:sub(1, 1) ~= "-"
      local label = rawLabel
      if common.fitListRowText then
        label = common.fitListRowText(s, "main_credits_row_" .. tostring(i), hintFont, label, maxLabelW, rowScale, false)
      elseif common.truncateTextToWidth then
        label = common.truncateTextToWidth(hintFont, label, maxLabelW, rowScale)
      end
      local rowColor = isHeading and creditsHeadingColor or common.WHITE
      dt(hintFont, s.drawMode, rowLabelX, y, rowScale, label, rowColor)
    end

    local hintItems = buildMainCreditsOverlayHintItems(main_str)
    if Graphics and Graphics.drawRect then
      local hintBg = (common and common.BACKGROUND_COLOR) or Color.new(0, 0, 0, 0x80)
      local hintRowH = math.max(14, math.floor(((common.PAD_HINT_ROW_H or 28) * textScale) + 0.5))
      local hintRowTop = math.floor(H) - hintRowH
      local hintW = (s.w or 640) - (2 * M)
      Graphics.drawRect(M, hintRowTop, hintW, hintRowH, hintBg)
    end
    common.drawHintLine(s.font, s.drawMode, M, H, 0.7, hintItems, nil, common.DIM_COLOR)

    if not closing then
      if (pad & PAD_TRIANGLE) ~= 0 or (pad & PAD_CIRCLE) ~= 0 then
        s.mainCreditsPromptClosing = true
        if s.mainCreditsPromptAnim < 0.001 then
          s.mainCreditsPromptAnim = 1
        end
      end
    elseif anim <= 0.001 then
      s.mainCreditsPrompt = nil
      s.mainCreditsPromptAnim = nil
      s.mainCreditsPromptClosing = nil
    end
    return
  end

  if (pad & PAD_TRIANGLE) ~= 0 then
    s.mainCreditsPrompt = true
    s.mainCreditsPromptAnim = 0
    s.mainCreditsPromptClosing = nil
    drawMainBaseUi()
    return
  end

  if (pad & PAD_SQUARE) ~= 0 then
    local settingsEntry = getMainEntryById("r3configurator") or {
      id = "r3configurator",
      logoKey = nil,
      context = "r3configurator",
      fileType = "r3configurator_cnf",
      state = "open",
    }
    if openMainEntry(settingsEntry) then
      return
    end
  end

  local prevSel = s.mainSel
  local navDir = nil
  if (pad & PAD_UP) ~= 0 then
    s.mainSel = common.wrapListSelection(s.mainSel, #s.main, -1)
    navDir = "up"
  elseif (pad & PAD_DOWN) ~= 0 then
    s.mainSel = common.wrapListSelection(s.mainSel, #s.main, 1)
    navDir = "down"
  end
  local newKey = getMainOverlayLogoKey(s.mainSel)
  if navDir and s.mainSel ~= prevSel then
    local oldKey = getMainOverlayLogoKey(prevSel)
    if oldKey and newKey and oldKey ~= newKey then
      s.mainLogoFlip = {
        active = true,
        direction = navDir,
        frame = 1,
        frames = MAIN_LOGO_FLIP_FRAMES,
        fromKey = oldKey,
        toKey = newKey,
      }
    end
  end
  s.mainOverlayLogoKey = newKey
  local openedExitPrompt = false
  if (pad & PAD_CIRCLE) ~= 0 and not s.mainExitPrompt then
    s.mainExitPrompt = true
    openedExitPrompt = true
  end
  if s.mainExitPrompt then
    local msg = main_str.main_exit_prompt or main_str.main_exit
    local tw = common.calcTextWidth(s.font, msg, 1.1)
    local w = s.w or 640
    local h = s.h or 448
    local lineH = s.LINE_H or common.LINE_H
    local boxW = tw + 48
    local boxH = lineH + 24
    local boxX = math.floor((w - boxW) / 2)
    local boxY = math.floor((h - boxH) / 2)
    if Graphics and Graphics.drawRect then
      Graphics.drawRect(boxX, boxY, boxW, boxH, Color.new(40, 40, 48, 110))
    end
    local cx = common.centerX and common.centerX(s, tw) or math.floor((w - tw) / 2)
    local cy = boxY + math.floor((boxH - lineH) / 2)
    dt(s.font, s.drawMode, math.max(M, cx), cy, 1.1, msg, common.WHITE)
    common.drawHintLine(s.font, s.drawMode, M, H, 0.7, main_str.main_exit_hint_items or main_str.circle_back_items, nil,
      common.DIM_COLOR)
    if (pad & PAD_CROSS) ~= 0 then System.exitToBrowser() end
    if (pad & PAD_CIRCLE) ~= 0 and not openedExitPrompt then s.mainExitPrompt = nil end
    return
  end
  drawMainBaseUi()
  if (pad & PAD_CROSS) ~= 0 then
    local entry = s.mainEntries and s.mainEntries[s.mainSel]
    openMainEntry(entry)
  end
end

local getPresentMcSlotsCached

local function runChooseMc(s, pad)
  local main_str = (C.strings and C.strings.main) or {}
  local dt, dlr = common.drawText, s.drawListRow
  local M = s.MARGIN_X or common.MARGIN_X
  local H = s.HINT_Y or common.HINT_Y
  local L = s.LINE_H or common.LINE_H
  local MY = s.MARGIN_Y or common.MARGIN_Y
  local sc = s.scaleY or function(y) return y end
  local SE = common.SELECTED_COLOR
  local slots = getPresentMcSlotsCached(s)
  if #slots == 0 then
    if s.context == "freemcboot" and s.fileType == "freemcboot_cnf" then
      -- FreeMCBoot can still be loaded/created on mass:/ even when no MC is inserted.
      s.chosenMcSlot = nil
      s.state = "open"
      return
    end
    dt(s.font, s.drawMode, M, MY, 1.1, main_str.no_memory_card, common.WHITE)
    dt(s.font, s.drawMode, M, MY + sc(30), 0.8, main_str.insert_mc, common.UNSELECTED_COLOR)
    common.drawHintLine(s.font, s.drawMode, M, H, 0.7, main_str.circle_back_items, nil, common.DIM_COLOR)
    if (pad & PAD_CIRCLE) ~= 0 then s.state = "main" end
  elseif #slots == 1 then
    s.chosenMcSlot = slots[1]
    s.chosenMcSlotAuto = true
    if s.context == "osdmenu" then
      s.osdmenuConfigDevice = "mc"
      s.osdmenuConfigDeviceAuto = true
    end
    s.state = nextStateAfterMcSelection(s)
  else
    dt(s.font, s.drawMode, M, MY, 1.1, main_str.select_memory_card, common.WHITE)
    dt(s.font, s.drawMode, M, MY + sc(24), 0.8, main_str.config_card_hint, common.DIM_COLOR)
    common.drawHintLine(s.font, s.drawMode, M, H, 0.7, main_str.cross_select_circle_back_items, nil, common.DIM_COLOR)
    if s.mcSel < 1 then s.mcSel = 1 end
    if s.mcSel > #slots then s.mcSel = #slots end
    for i = 1, #slots do
      local y = MY + sc(50) + (i - 1) * L
      local label = (slots[i] == 0 and main_str.memory_card_1_slot) or main_str.memory_card_2_slot
      local col = (i == s.mcSel) and SE or common.UNSELECTED_COLOR
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
      s.chosenMcSlotAuto = nil
      if s.context == "osdmenu" then
        s.osdmenuConfigDevice = "mc"
        s.osdmenuConfigDeviceAuto = nil
      end
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

getPresentMcSlotsCached = function(s)
  local slots = (common.getPresentMcSlots and common.getPresentMcSlots()) or {}
  if s then
    s.presentMcSlotsCache = nil
  end
  return slots
end

local function getLaunchSlotInfo(s)
  if s and s.launchSlotInfo and s.launchSlotInfo.sceneEpoch == (s._sceneEpoch or 0) then
    return s.launchSlotInfo
  end

  local info = {
    sceneEpoch = (s and s._sceneEpoch) or 0,
    family = "unknown",
    slot = nil,
  }

  if System and System.currentDirectory then
    local ok, cwd = pcall(System.currentDirectory)
    local p = ok and tostring(cwd or ""):gsub("\\", "/"):lower() or ""
    if p:match("^mc0:") then
      info.family, info.slot = "mc", 0
    elseif p:match("^mc1:") then
      info.family, info.slot = "mc", 1
    elseif p:match("^mmce0:") then
      info.family, info.slot = "mmce", 0
    elseif p:match("^mmce1:") then
      info.family, info.slot = "mmce", 1
    elseif p:match("^xfrom:") then
      info.family = "xfrom"
    elseif p:match("^mass1:") or p:match("^usb1:") then
      info.family, info.slot = "usb", 1
    elseif p:match("^mass0:") or p:match("^mass:") or p:match("^usb0:") or p:match("^usb:") then
      info.family, info.slot = "usb", 0
    elseif p:match("^massx:") or p:match("^mx4sio:") then
      info.family = "mx4sio"
    elseif p:match("^ata1:") then
      info.family, info.slot = "ata", 1
    elseif p:match("^ata0:") or p:match("^ata:") then
      info.family, info.slot = "ata", 0
    elseif p:match("^hdd%d:") or p:match("^pfs%d:") then
      info.family = "hdd"
    end
  end

  if info.family == "unknown" and System and System.getLaunchDeviceFamily then
    local okFam, fam = pcall(System.getLaunchDeviceFamily)
    local f = okFam and tostring(fam or ""):lower() or ""
    if f == "mass" then f = "usb" end
    if f == "usb" or f == "mmce" or f == "mx4sio" or f == "hdd" or f == "mc" or f == "ata" or f == "xfrom" then
      info.family = f
    end
  end

  if s then
    s.launchSlotInfo = info
  end
  return info
end

local function getSelectConfigDevicePresence(s)
  local sceneEpoch = (s and s._sceneEpoch) or 0

  local launch = getLaunchSlotInfo(s)
  local mc0, mc1 = false, false
  local usb0, usb1 = true, true
  local slots = getPresentMcSlotsCached(s)
  for i = 1, #slots do
    if slots[i] == 0 then
      mc0 = true
    elseif slots[i] == 1 then
      mc1 = true
    end
  end
  local mmce0, mmce1 = mc0, mc1

  -- MC drivers are already loaded, so MC/MMCE slot visibility can be decided up front.
  -- Other removable families stay visible and are lazy-loaded only after user confirms.
  if launch.family == "usb" and (launch.slot == 0 or launch.slot == 1) then
    usb0 = (launch.slot == 0)
    usb1 = (launch.slot == 1)
  end

  local out = {
    sceneEpoch = sceneEpoch,
    mc0 = mc0,
    mc1 = mc1,
    mmce0 = mmce0,
    mmce1 = mmce1,
    usb0 = usb0,
    usb1 = usb1,
  }
  if s then
    s.selectConfigDevicePresenceCache = nil
  end
  return out
end

local function buildBblSourceOptions(s, iniFileType)
  local dev_str = (C.strings and C.strings.devices) or {}
  local visibility = (C.config_options and C.config_options.getBblPathDeviceVisibility and
      C.config_options.getBblPathDeviceVisibility()) or nil
  local iniName = (iniFileType == "psxbbl_ini") and "PSXBBL.INI" or "PS2BBL.INI"
  local presence = getSelectConfigDevicePresence(s)
  local presentMc = {}
  local slots = getPresentMcSlotsCached(s)
  for i = 1, #slots do
    if slots[i] == 0 or slots[i] == 1 then
      presentMc[slots[i]] = true
    end
  end
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

  if presentMc[0] then
    addDevice("mc", dev_str.memory_card_1 or "Memory Card 1", { "mc0:/SYS-CONF/" .. iniName }, "mc0:")
  end
  if presentMc[1] then
    addDevice("mc", dev_str.memory_card_2 or "Memory Card 2", { "mc1:/SYS-CONF/" .. iniName }, "mc1:")
  end
  if presence.mmce0 then
    addDevice("mmce", dev_str.mmce_0 or "MMCE in slot 1", { "mmce0:/PS2BBL/CONFIG.INI" }, "mmce0:", nil, "mmce")
  end
  if presence.mmce1 then
    addDevice("mmce", dev_str.mmce_1 or "MMCE in slot 2", { "mmce1:/PS2BBL/CONFIG.INI" }, "mmce1:", nil, "mmce")
  end
  if presence.usb0 then
    addDevice("usb", dev_str.usb_storage_0 or "USB Mass Storage 1", { "usb0:/PS2BBL/CONFIG.INI" }, nil, "usb0", "usb")
  end
  if presence.usb1 then
    addDevice("usb", dev_str.usb_storage_1 or "USB Mass Storage 2", { "usb1:/PS2BBL/CONFIG.INI" }, nil, "usb1", "usb")
  end
  addDevice("mx4sio", dev_str.mx4sio_sd or "MX4SIO", { "mx4sio:/PS2BBL/CONFIG.INI" }, nil, "mx4sio", "mx4sio")
  if not hideRuntimeHddDevices() then
    addDevice("hdd", dev_str.hdd_mbr_0 or "APA-formatted HDD 1",
      { "hdd0:__sysconf:pfs:/PS2BBL/CONFIG.INI" }, "hdd0:", nil, "hdd")
    addDevice("hdd", dev_str.hdd_mbr_1 or "APA-formatted HDD 2",
      { "hdd1:__sysconf:pfs:/PS2BBL/CONFIG.INI" }, "hdd1:", nil, "hdd")
    addDevice("ata", dev_str.exfat_hdd_mbr_0 or "exFAT-formatted HDD 1", { "ata0:/PS2BBL/CONFIG.INI" }, nil,
      "ata0", "hdd")
    addDevice("ata", dev_str.exfat_hdd_mbr_1 or "exFAT-formatted HDD 2", { "ata1:/PS2BBL/CONFIG.INI" }, nil,
      "ata1", "hdd")
  end
  if iniFileType == "psxbbl_ini" and isRuntimePsx() then
    addDevice("xfrom", dev_str.xfrom or "XFROM (PSX ONLY!)", { "xfrom:/PS2BBL/CONFIG.INI" }, "xfrom:", nil, "xfrom")
  end
  return out
end

local function buildFreemcbootSourceOptions(s, context)
  local dev_str = (C.strings and C.strings.devices) or {}
  local presence = getSelectConfigDevicePresence(s)
  local presentMc = {}
  local slots = getPresentMcSlotsCached(s)
  for i = 1, #slots do
    if slots[i] == 0 or slots[i] == 1 then
      presentMc[slots[i]] = true
    end
  end
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
  if presentMc[0] then
    add(dev_str.memory_card_1 or "Memory Card 1", "mc0:/SYS-CONF/" .. fileName, "mc")
  end
  if presentMc[1] then
    add(dev_str.memory_card_2 or "Memory Card 2", "mc1:/SYS-CONF/" .. fileName, "mc")
  end
  if presence.usb0 then
    add(dev_str.usb_storage_0 or "USB Mass Storage 1", "mass:/" .. fileName, "usb")
  end
  if presence.usb1 then
    add(dev_str.usb_storage_1 or "USB Mass Storage 2", "mass1:/" .. fileName, "usb")
  end
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
  local directOpenSingle = (opts.directOpenSingle == true)
  local paths = pick.paths or {}
  if directOpenSingle and (not includeBrowseIni) and #paths == 1 then
    local directPath = paths[1]
    if type(directPath) == "string" and directPath ~= "" then
      clearLoadChoiceState(s)
      clearPathPickerState(s)
      -- Keep the exact single-source device path selected in Free*Boot flows.
      s.selectedKnownPath = directPath
      s.currentPath = directPath
      s.openExplicitPath = true
      s.state = "open"
      return true
    end
  end
  s.loadChoices = {}
  s.loadPathExists = {}
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
  local dev_str = (C.strings and C.strings.devices) or {}
  local dt, dlr = common.drawText, s.drawListRow
  local M = s.MARGIN_X or common.MARGIN_X
  local H = s.HINT_Y or common.HINT_Y
  local L = s.LINE_H or common.LINE_H
  local MY = s.MARGIN_Y or common.MARGIN_Y
  local sc = s.scaleY or function(y) return y end
  local SE = common.SELECTED_COLOR

  local function drawNoCompatibleDevices()
    dt(s.font, s.drawMode, M, MY, 1.1, main_str.which_device or "Which device?", common.WHITE)
    dt(s.font, s.drawMode, M + 20, MY + sc(50), common.FONT_SCALE,
      main_str.no_compatible_devices or "No compatible devices", common.DIM_COLOR)
    common.drawHintLine(s.font, s.drawMode, M, H, 0.7, main_str.circle_back_items, nil, common.DIM_COLOR)
    if (pad & PAD_CIRCLE) ~= 0 then
      s.state = "main"
    end
  end

  if s.context == "osdmenu" or s.context == "hosdmenu" or s.context == "mbr" then
    if s.context == "osdmenu" and not s.osdmenuConfigDevice then
      local options = {}
      local slots = getPresentMcSlotsCached(s)
      for i = 1, #slots do
        if slots[i] == 0 then
          options[#options + 1] = { label = main_str.memory_card_1_slot or "Memory Card 1", device = "mc", slot = 0 }
        elseif slots[i] == 1 then
          options[#options + 1] = { label = main_str.memory_card_2_slot or "Memory Card 2", device = "mc", slot = 1 }
        end
      end
      if isRuntimePsx() then
        options[#options + 1] = { label = dev_str.xfrom or "XFROM (PSX ONLY!)", device = "xfrom" }
      end
      if #options == 0 then
        drawNoCompatibleDevices()
        return
      end
      if #options == 1 then
        local pick = options[1]
        s.osdmenuConfigDevice = pick.device
        s.chosenMcSlot = pick.slot
        s.osdmenuConfigDeviceAuto = true
        s.chosenMcSlotAuto = (pick.slot ~= nil) and true or nil
        clearLoadChoiceState(s)
        clearPathPickerState(s)
        return
      end

      local sel = getOsdmenuConfigDeviceSel(s)
      if sel < 1 then sel = 1 end
      if sel > #options then sel = #options end
      setOsdmenuConfigDeviceSel(s, sel)

      dt(s.font, s.drawMode, M, MY, 1.1, main_str.which_device or "Which device?", common.WHITE)
      common.drawHintLine(s.font, s.drawMode, M, H, 0.7, main_str.cross_select_circle_back_items, nil,
        common.DIM_COLOR)
      for i, opt in ipairs(options) do
        local y = MY + sc(50) + (i - 1) * L
        local col = (i == sel) and SE or common.UNSELECTED_COLOR
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
      setOsdmenuConfigDeviceSel(s, sel)

      if (pad & PAD_CROSS) ~= 0 then
        local pick = options[sel]
        if pick and pick.device then
          s.osdmenuConfigDevice = pick.device
          s.chosenMcSlot = pick.slot
          s.osdmenuConfigDeviceAuto = nil
          s.chosenMcSlotAuto = nil
          clearLoadChoiceState(s)
          clearPathPickerState(s)
          return
        end
      end
      if (pad & PAD_CIRCLE) ~= 0 then
        s.state = "main"
      end
      return
    end

    if s.context == "mbr" and not s.mbrConfigDevice then
      local options = {}
      if not hideRuntimeHddDevices() then
        options[#options + 1] = { label = dev_str.hdd or "APA-formatted HDD", device = "hdd" }
      end
      if isRuntimePsx() then
        options[#options + 1] = { label = dev_str.xfrom or "XFROM (PSX ONLY!)", device = "xfrom" }
      end
      if #options == 0 then
        drawNoCompatibleDevices()
        return
      end
      local function chooseMbrDevice(pick)
        if not (pick and pick.device) then return false end
        s.mbrConfigDevice = pick.device
        clearLoadChoiceState(s)
        clearPathPickerState(s)
        if pick.device == "hdd" and not s.hddReady then
          s.initHddSuccessState = "select_config"
          s.initHddCancelState = "select_config"
          s.state = "initHdd"
          s.initHddPhase = "load"
        end
        return true
      end
      if #options == 1 then
        s.mbrConfigDeviceAuto = true
        chooseMbrDevice(options[1])
        return
      end
      local sel = getMbrConfigDeviceSel(s)
      if sel < 1 then sel = 1 end
      if sel > #options then sel = #options end
      setMbrConfigDeviceSel(s, sel)

      dt(s.font, s.drawMode, M, MY, 1.1, main_str.which_device or "Which device?", common.WHITE)
      common.drawHintLine(s.font, s.drawMode, M, H, 0.7, main_str.cross_select_circle_back_items, nil,
        common.DIM_COLOR)
      for i, opt in ipairs(options) do
        local y = MY + sc(50) + (i - 1) * L
        local col = (i == sel) and SE or common.UNSELECTED_COLOR
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
      setMbrConfigDeviceSel(s, sel)

      if (pad & PAD_CROSS) ~= 0 then
        s.mbrConfigDeviceAuto = nil
        if chooseMbrDevice(options[sel]) then
          return
        end
      end
      if (pad & PAD_CIRCLE) ~= 0 then
        s.state = "main"
      end
      return
    end

    local options
    if s.context == "mbr" then
      options = {
        { label = main_str.select_config_osdmbr_cnf or "OSDMBR.CNF", fileType = "osdmbr_cnf" },
        { label = main_str.select_config_osdgsm_cnf or "OSDGSM.CNF", fileType = "osdgsm_cnf" },
      }
    else
      options = {
        { label = main_str.select_config_osdmenu_cnf or "OSDMENU.CNF", fileType = "osdmenu_cnf" },
        { label = main_str.select_config_osdgsm_cnf or "OSDGSM.CNF", fileType = "osdgsm_cnf" },
      }
    end
    local sel = getSelectConfigSel(s)
    if sel < 1 then sel = 1 end
    if sel > #options then sel = #options end
    setSelectConfigSel(s, sel)

    if #options == 1 then
      local pick = options[1]
      if pick and pick.fileType then
        s.fileType = pick.fileType
        clearLoadChoiceState(s)
        clearPathPickerState(s)
        s.state = "open"
        return
      end
    end

    dt(s.font, s.drawMode, M, MY, 1.1, main_str.which_file, common.WHITE)
    common.drawHintLine(s.font, s.drawMode, M, H, 0.7, main_str.cross_select_circle_back_items, nil, common.DIM_COLOR)
    for i, opt in ipairs(options) do
      local y = MY + sc(50) + (i - 1) * L
      local col = (i == sel) and SE or common.UNSELECTED_COLOR
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
      if s.context == "mbr" then
        if s.mbrConfigDeviceAuto then
          s.mbrConfigDevice = nil
          s.mbrConfigDeviceAuto = nil
          s.state = "main"
          return
        end
        s.mbrConfigDevice = nil
      elseif s.context == "osdmenu" then
        if s.osdmenuConfigDeviceAuto then
          s.osdmenuConfigDevice = nil
          s.osdmenuConfigDeviceAuto = nil
          s.chosenMcSlot = nil
          s.chosenMcSlotAuto = nil
          s.state = "main"
          return
        end
        s.osdmenuConfigDevice = nil
        s.chosenMcSlot = nil
        s.chosenMcSlotAuto = nil
      else
        s.state = "main"
      end
    end
    return
  end

  if s.context == "freemcboot" or s.context == "freehddboot" then
    local options = buildFreemcbootSourceOptions(s, s.context)
    if s.pendingKnownPathPick then
      local pendingPick = s.pendingKnownPathPick
      local pendingAuto = s.pendingKnownPathAuto
      s.pendingKnownPathPick = nil
      s.pendingKnownPathAuto = nil
      if pendingAuto then
        s.selectConfigSourceAuto = true
        s.editorBackStateOverride = "main"
      end
      if applyKnownPathPick(s, pendingPick, main_str, { directOpenSingle = true }) then
        return
      end
    end
    local function chooseFreemcbootSource(pick, autoSelected)
      s.fileType = "freemcboot_cnf"
      clearPathPickerState(s)
      if pick and pick.action == "known_paths" then
        if autoSelected then
          s.selectConfigSourceAuto = true
          s.editorBackStateOverride = "main"
        else
          clearAutoSourceBackState(s)
        end
        if pickUsesHdd(pick) and not s.hddReady then
          s.pendingKnownPathPick = pick
          s.pendingKnownPathAuto = autoSelected and true or nil
          s.initHddSuccessState = "select_config"
          s.initHddCancelState = "select_config"
          s.state = "initHdd"
          s.initHddPhase = "load"
          return true
        end
        applyKnownPathPick(s, pick, main_str, { directOpenSingle = true })
        return true
      end
      return false
    end
    if #options == 0 then
      drawNoCompatibleDevices()
      return
    end
    if #options == 1 then
      chooseFreemcbootSource(options[1], true)
      return
    end

    local sel = getSelectConfigSel(s)
    if sel < 1 then sel = 1 end
    if sel > #options then sel = #options end
    setSelectConfigSel(s, sel)

    dt(s.font, s.drawMode, M, MY, 1.1, main_str.which_device or "Which device?", common.WHITE)
    common.drawHintLine(s.font, s.drawMode, M, H, 0.7, main_str.cross_select_circle_back_items, nil, common.DIM_COLOR)
    for i, opt in ipairs(options) do
      local y = MY + sc(50) + (i - 1) * L
      local col = (i == sel) and SE or common.UNSELECTED_COLOR
      dlr(M + 20, y, i == sel, opt.label or "", col)
    end
    if (pad & PAD_UP) ~= 0 then
      sel = common.wrapListSelection(sel, #options, -1)
    end
    if (pad & PAD_DOWN) ~= 0 then
      sel = common.wrapListSelection(sel, #options, 1)
    end
    setSelectConfigSel(s, sel)

    if (pad & PAD_CROSS) ~= 0 then
      chooseFreemcbootSource(options[sel], false)
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

  local options = buildBblSourceOptions(s, iniFileType)
  if s.pendingKnownPathPick then
    local pendingPick = s.pendingKnownPathPick
    local pendingAuto = s.pendingKnownPathAuto
    s.pendingKnownPathPick = nil
    s.pendingKnownPathAuto = nil
    if pendingAuto then
      s.selectConfigSourceAuto = true
    end
    if applyKnownPathPick(s, pendingPick, main_str, { includeBrowseIni = true }) then
      return
    end
  end
  local function chooseBblSource(pick, autoSelected)
    s.fileType = iniFileType
    clearPathPickerState(s)
    if pick and pick.action == "known_paths" then
      if autoSelected then
        s.selectConfigSourceAuto = true
      else
        clearAutoSourceBackState(s)
      end
      if pickUsesHdd(pick) and not s.hddReady then
        s.pendingKnownPathPick = pick
        s.pendingKnownPathAuto = autoSelected and true or nil
        s.initHddSuccessState = "select_config"
        s.initHddCancelState = "select_config"
        s.state = "initHdd"
        s.initHddPhase = "load"
        return true
      end
      applyKnownPathPick(s, pick, main_str, { includeBrowseIni = true })
      return true
    end
    return false
  end
  if #options == 0 then
    drawNoCompatibleDevices()
    return
  end
  if #options == 1 then
    chooseBblSource(options[1], true)
    return
  end

  local sel = getSelectConfigSel(s)
  if sel < 1 then sel = 1 end
  if sel > #options then sel = #options end
  setSelectConfigSel(s, sel)

  dt(s.font, s.drawMode, M, MY, 1.1, main_str.which_device or "Which device?", common.WHITE)
  if path_str.bbl_build_device_hint then
    local bblName = (iniFileType == "psxbbl_ini") and "PSXBBL" or "PS2BBL"
    local hint = tostring(path_str.bbl_build_device_hint):gsub("PS%?BBL", bblName)
    if common.truncateTextToWidth then
      hint = common.truncateTextToWidth(s.font, hint, (s.w or 640) - (M * 2), 0.55)
    end
    dt(s.font, s.drawMode, M, MY + sc(20), 0.55, hint, common.DIM_COLOR)
  end
  common.drawHintLine(s.font, s.drawMode, M, H, 0.7, main_str.cross_select_circle_back_items, nil, common.DIM_COLOR)
  for i, opt in ipairs(options) do
    local y = MY + sc(50) + (i - 1) * L
    local col = (i == sel) and SE or common.UNSELECTED_COLOR
    dlr(M + 20, y, i == sel, opt.label or "", col)
  end
  if (pad & PAD_UP) ~= 0 then
    sel = common.wrapListSelection(sel, #options, -1)
  end
  if (pad & PAD_DOWN) ~= 0 then
    sel = common.wrapListSelection(sel, #options, 1)
  end
  setSelectConfigSel(s, sel)

  if (pad & PAD_CROSS) ~= 0 then
    chooseBblSource(options[sel], false)
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
  local M = s.MARGIN_X or common.MARGIN_X
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
    dt(s.font, s.drawMode, math.max(M, cx2), descY, 0.85, main_str.init_hdd_sub, common.DIM_COLOR)
    -- Show this frame on vblank before module load to avoid a visible full-screen flash.
    Screen.waitVblankStart()
    Screen.flip()
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
      dt(s.font, s.drawMode, math.max(M, cx2), descY, 0.85, main_str.init_hdd_sub, common.DIM_COLOR)
      common.drawHintLine(s.font, s.drawMode, M, H, 0.7, main_str.circle_back_items, nil, common.DIM_COLOR)
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
    common.drawHintLine(s.font, s.drawMode, M, H, 0.7, main_str.circle_back_items, nil, common.DIM_COLOR)
    if (pad & PAD_CIRCLE) ~= 0 then
      if s.selectConfigSourceAuto or s.pendingKnownPathAuto or s.mbrConfigDeviceAuto then
        s.mbrConfigDevice = nil
        s.mbrConfigDeviceAuto = nil
        clearAutoSourceBackState(s)
        s.state = "main"
        s.initHddPhase = nil
        s.initHddSuccessState = nil
        s.initHddCancelState = nil
        s.pendingKnownPathPick = nil
        return
      end
      if s.context == "mbr" and s.initHddCancelState == "select_config" then
        s.mbrConfigDevice = nil
      end
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
  if s.context == "mbr" and (s.fileType == "osdmbr_cnf" or s.fileType == "osdgsm_cnf") and
      not s.mbrConfigDevice and not s.openExplicitPath then
    s.state = "select_config"
    return
  end
  if s.context == "osdmenu" and (s.fileType == "osdmenu_cnf" or s.fileType == "osdgsm_cnf") and
      not s.osdmenuConfigDevice and not s.openExplicitPath then
    s.state = "select_config"
    return
  end
  local mbrNeedsHdd = (s.context == "mbr" and s.mbrConfigDevice == "hdd")
  if (s.context == "hosdmenu" or mbrNeedsHdd) and not s.hddReady then
    s.state = "initHdd"
    s.initHddPhase = "load"
    s.initHddSuccessState = "open"
    s.initHddCancelState = "main"
    s.pendingKnownPathPick = nil
    return
  end
  local dt = common.drawText
  local M = s.MARGIN_X or common.MARGIN_X
  local H = s.HINT_Y or common.HINT_Y
  local MY = s.MARGIN_Y or common.MARGIN_Y
  local sc = s.scaleY or function(y) return y end
  if s.fileType == "freemcboot_cnf" and (s.context == "freemcboot" or s.context == "freehddboot") and
      not s.openExplicitPath then
    local pinnedPath = s.selectedKnownPath
    if type(pinnedPath) == "string" and pinnedPath ~= "" then
      -- Scene transitions should not alter Free*Boot navigation flow:
      -- device pick always maps to one explicit path.
      s.currentPath = pinnedPath
      s.openExplicitPath = true
    end
  end
  if s.openExplicitPath and s.currentPath and s.currentPath ~= "" then
    if not pathExists(s.currentPath) then
      openDbg("explicit path missing; creating new in memory", "path=" .. tostring(s.currentPath))
      initEmptyLinesForFileType(s, "explicit path missing")
      s.openExplicitPath = nil
      clearLoadChoiceState(s)
      setStateAfterLoad(s)
      markNewInMemoryConfigState(s)
      openDbg("mark modified", "reason=new file in memory (explicit path missing)")
      return
    end
    local loaded, loadErr = loadLinesWithDeviceAccess(s.currentPath)
    if loaded then
      s.lines = loaded
      normalizeLoadedLinesForFileType(s)
      s.openExplicitPath = nil
      clearLoadChoiceState(s)
      setStateAfterLoad(s)
      return
    end
    openDbg("explicit path load failed", "path=" .. tostring(s.currentPath), "error=" .. tostring(loadErr))
    dt(s.font, s.drawMode, M, MY + sc(60), common.FONT_SCALE, main_str.failed_to_load .. tostring(s.currentPath),
      common.UNSELECTED_COLOR)
    common.drawHintLine(s.font, s.drawMode, M, H, 0.7, main_str.cross_back_items, nil, common.DIM_COLOR)
    if (pad & PAD_CROSS) ~= 0 then
      s.openExplicitPath = nil
      clearLoadChoiceState(s)
      s.state = getOpenParentState(s)
    end
    return
  end
  local configDevice = s.mbrConfigDevice or s.osdmenuConfigDevice
  local locations = C.config_options.getLocations(s.context, s.fileType, s.chosenMcSlot, configDevice)
  openDbg("resolve locations", "context=" .. tostring(s.context), "fileType=" .. tostring(s.fileType),
    "count=" .. tostring(#(locations or {})))
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
    openDbg("choose load", "mode=allow_create", "choices=" .. tostring(#s.loadChoices),
      "existingChoices=" .. tostring(countTrue(s.loadPathExists)))
    s.state = "choose_load"
    return
  end
  local existing = findExistingPathsWithDeviceAccess(locations)
  if #existing == 0 then
    if C.config_options and C.config_options.getDefaultLocation then
      s.currentPath = C.config_options.getDefaultLocation(s.context, s.fileType, s.chosenMcSlot, configDevice)
    else
      s.currentPath = locations[1]
    end
    if not s.currentPath then
      openDbg("open failed", "reason=no location found")
      dt(s.font, s.drawMode, M, MY + sc(60), common.FONT_SCALE, main_str.no_location, common.UNSELECTED_COLOR)
      common.drawHintLine(s.font, s.drawMode, M, H, 0.7, main_str.cross_back_items, nil, common.DIM_COLOR)
      if (pad & PAD_CROSS) ~= 0 then s.state = getOpenParentState(s) end
    else
      openDbg("no existing file; creating new in memory", "path=" .. tostring(s.currentPath))
      initEmptyLinesForFileType(s, "no existing path")
      setStateAfterLoad(s)
      markNewInMemoryConfigState(s)
      openDbg("mark modified", "reason=new file in memory (no existing path)")
    end
  elseif #existing == 1 then
    s.currentPath = existing[1]
    openDbg("single existing path", "path=" .. tostring(s.currentPath))
    local loaded, loadErr = loadLinesWithDeviceAccess(s.currentPath)
    if not loaded then
      openDbg("single path load failed", "path=" .. tostring(s.currentPath), "error=" .. tostring(loadErr))
      dt(s.font, s.drawMode, M, MY + sc(60), common.FONT_SCALE, main_str.failed_to_load .. tostring(s.currentPath),
        common.UNSELECTED_COLOR)
      common.drawHintLine(s.font, s.drawMode, M, H, 0.7, main_str.cross_back_items, nil, common.DIM_COLOR)
      if (pad & PAD_CROSS) ~= 0 then s.state = getOpenParentState(s) end
    else
      s.lines = loaded
      normalizeLoadedLinesForFileType(s)
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
    openDbg("choose load", "mode=existing_only", "choices=" .. tostring(#existing))
    s.state = "choose_load"
  end
end

local function runChooseLoad(s, pad)
  local main_str = (C.strings and C.strings.main) or {}
  local dev_str = (C.strings and C.strings.devices) or {}
  local dt, dlr = common.drawText, s.drawListRow
  local M = s.MARGIN_X or common.MARGIN_X
  local H = s.HINT_Y or common.HINT_Y
  local L = s.LINE_H or common.LINE_H
  local MY = s.MARGIN_Y or common.MARGIN_Y
  local sc = s.scaleY or function(y) return y end
  local SE = common.SELECTED_COLOR
  local choices = s.loadChoices or {}
  local allowCreate = (s.loadAllowCreate == true)
  local useNumberedHddChoiceLabels = (s.fileType == "ps2bbl_ini" or s.fileType == "psxbbl_ini" or s.context == "mbr")
  if s.loadSel < 1 then s.loadSel = 1 end
  if s.loadSel > #choices then s.loadSel = #choices end
  local maxVis = s.MAX_VISIBLE_LIST or s.MAX_VISIBLE or common.MAX_VISIBLE
  local total = #choices
  local maxLabelW = (s.w or 640) - (M + 24) - M
  local scroll = 0
  if total > maxVis then
    scroll = s.loadSel - math.floor(maxVis / 2)
    scroll = math.max(0, math.min(scroll, total - maxVis))
  end
  dt(s.font, s.drawMode, M, MY, 1.1, main_str.which_file or "Which file?", common.WHITE)
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
          (p:match("^xfrom:") and (dev_str.xfrom or "XFROM (PSX ONLY!)")) or
          (p:match("^ata1:") and
            ((useNumberedHddChoiceLabels and dev_str.exfat_hdd_mbr_1) or dev_str.exfat_hdd_mass0)) or
          ((p:match("^ata0:") or p:match("^ata:")) and
            ((useNumberedHddChoiceLabels and dev_str.exfat_hdd_mbr_0) or dev_str.exfat_hdd_mass0)) or
          (p:match("^mx4sio:") and dev_str.mx4sio_sd) or
          (p:match("^usb1:") and (dev_str.usb_storage_1 or dev_str.usb_storage_0)) or
          ((p:match("^usb:") or p:match("^usb0:")) and dev_str.usb_storage_0) or
          (p:match("^massX:") and dev_str.mx4sio_sd) or
          (p:match("^mass1:") and (dev_str.usb_storage_1 or dev_str.usb_storage_0)) or
          ((p:match("^mass:") or p:match("^mass0:")) and dev_str.usb_storage_0) or
          (p:match("^mmce0:") and dev_str.mmce_0) or
          (p:match("^mmce1:") and dev_str.mmce_1) or
          (p:match("^hdd1:") and ((useNumberedHddChoiceLabels and dev_str.hdd_mbr_1) or dev_str.hdd_1 or dev_str.hdd)) or
          (p:match("^hdd0:") and ((useNumberedHddChoiceLabels and dev_str.hdd_mbr_0) or dev_str.hdd)) or
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
    local col = (idx == s.loadSel) and SE or common.UNSELECTED_COLOR
    dlr(M + 20, y, idx == s.loadSel, label, col)
  end
  common.drawHintLine(s.font, s.drawMode, M, H, 0.7, main_str.cross_load_circle_back_items, nil, common.DIM_COLOR)
  if (pad & PAD_UP) ~= 0 then
    s.loadSel = s.loadSel - 1; if s.loadSel < 1 then s.loadSel = #choices end
  end
  if (pad & PAD_DOWN) ~= 0 then
    s.loadSel = s.loadSel + 1; if s.loadSel > #choices then s.loadSel = 1 end
  end
  if (pad & PAD_CROSS) ~= 0 and #choices > 0 then
    local chosen = choices[s.loadSel]
    if type(chosen) == "table" and chosen.kind == "browse_ini" then
      openDbg("choose load selection", "kind=browse_ini", "deviceId=" .. tostring(chosen.browseDeviceId),
        "deviceType=" .. tostring(chosen.browseDeviceType))
      local allDevices = (C.file_selector and C.file_selector.getDevices and
          C.file_selector.getDevices("config_ini", { fileType = s.fileType })) or {}
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
    openDbg("choose load selection", "path=" .. tostring(s.currentPath), "allowCreate=" .. tostring(allowCreate),
      "exists=" .. tostring(exists))
    if allowCreate and not exists then
      openDbg("selected missing path; creating new in memory", "path=" .. tostring(s.currentPath))
      initEmptyLinesForFileType(s, "choose_load create missing")
      setStateAfterLoad(s)
      markNewInMemoryConfigState(s)
      openDbg("mark modified", "reason=new file in memory (choose_load missing path)")
      clearLoadChoiceState(s)
    else
      local loaded, loadErr = loadLinesWithDeviceAccess(s.currentPath)
      if loaded then
        s.lines = loaded
        normalizeLoadedLinesForFileType(s)
        setStateAfterLoad(s)
        clearLoadChoiceState(s)
      else
        openDbg("choose load failed", "path=" .. tostring(s.currentPath), "error=" .. tostring(loadErr))
      end
    end
  end
  if (pad & PAD_CIRCLE) ~= 0 then
    if s.selectConfigSourceAuto then
      s.state = "main"
      clearAutoSourceBackState(s)
    else
      s.state = s.loadReturnState or "select_config"
    end
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
