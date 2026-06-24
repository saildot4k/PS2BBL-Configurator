--[[
  Option structure per config type (keys, types, defaults). No UI text here.
  Labels, descriptions, and category names come from lang/strings_<LANG>.lua (see ui_main.lua).
]]

local config_options = {}

-- UI feature toggles. Keep eGSM code present but hidden until enabled.
config_options.FEATURES = {
  egsm_ui = false,
}

-- Device visibility for PS2BBL/PSXBBL path picker (path_only context).
-- Set any key to false to hide it from device selection:
-- mc, usb, hdd (APA/PFS), mmce, mx4sio, ata (exFAT via BDM ata0), xfrom
config_options.BBL_PATH_DEVICE_VISIBILITY = {
  mc = true,
  usb = true,
  hdd = true,
  mmce = true,
  mx4sio = true,
  ata = true,
  xfrom = true,
}

function config_options.isEgsmUiEnabled()
  return config_options.FEATURES.egsm_ui == true
end

function config_options.getBblPathDeviceVisibility()
  return config_options.BBL_PATH_DEVICE_VISIBILITY
end

local function appendUnique(out, path)
  if not path or path == "" then return end
  for i = 1, #out do
    if out[i] == path then return end
  end
  out[#out + 1] = path
end

local function buildBblDefaultMcPath(mcFile, chosenMcSlot)
  if chosenMcSlot == 1 then
    return "mc1:/SYS-CONF/" .. mcFile
  end
  return "mc0:/SYS-CONF/" .. mcFile
end

-- Known PS2BBL/PSXBBL lookup locations, excluding CWD (CONFIG.INI) because CWD is launch-dependent.
-- Ordered to match PS2BBL source search order (first -> last).
local function buildPs2BblIniLocations()
  local out = {}
  appendUnique(out, "mmce1:/PS2BBL/CONFIG.INI")
  appendUnique(out, "mmce0:/PS2BBL/CONFIG.INI")
  appendUnique(out, "ata0:/PS2BBL/CONFIG.INI")
  appendUnique(out, "ata1:/PS2BBL/CONFIG.INI")
  appendUnique(out, "hdd0:__sysconf:pfs:/PS2BBL/CONFIG.INI")
  appendUnique(out, "hdd1:__sysconf:pfs:/PS2BBL/CONFIG.INI")
  appendUnique(out, "mx4sio:/PS2BBL/CONFIG.INI")
  appendUnique(out, "mass:/PS2BBL/CONFIG.INI")
  appendUnique(out, "mc1:/SYS-CONF/PS2BBL.INI")
  appendUnique(out, "mc0:/SYS-CONF/PS2BBL.INI")
  return out
end

-- PSXBBL checks PSXBBL.INI on memory cards before the shared PS2BBL paths.
local function buildPsxBblIniLocations()
  local out = {}
  appendUnique(out, "mc1:/SYS-CONF/PSXBBL.INI")
  appendUnique(out, "mc0:/SYS-CONF/PSXBBL.INI")
  appendUnique(out, "mmce1:/PS2BBL/CONFIG.INI")
  appendUnique(out, "mmce0:/PS2BBL/CONFIG.INI")
  appendUnique(out, "xfrom:/PS2BBL/CONFIG.INI")
  appendUnique(out, "ata0:/PS2BBL/CONFIG.INI")
  appendUnique(out, "ata1:/PS2BBL/CONFIG.INI")
  appendUnique(out, "hdd0:__sysconf:pfs:/PS2BBL/CONFIG.INI")
  appendUnique(out, "hdd1:__sysconf:pfs:/PS2BBL/CONFIG.INI")
  appendUnique(out, "mx4sio:/PS2BBL/CONFIG.INI")
  appendUnique(out, "mass:/PS2BBL/CONFIG.INI")
  return out
end

local function appendOsdMcPaths(out, slot, fileName)
  appendUnique(out, "mc" .. tostring(slot) .. ":/SYS-CONF/" .. fileName)
end

local function buildOsdMcLocations(chosenMcSlot, fileName)
  local out = {}
  if chosenMcSlot == 0 or chosenMcSlot == 1 then
    appendOsdMcPaths(out, chosenMcSlot, fileName)
    return out
  end
  appendOsdMcPaths(out, 0, fileName)
  appendOsdMcPaths(out, 1, fileName)
  return out
end

local function buildOsdmenuLocations(fileName, chosenMcSlot, selectedDevice, includeXfrom)
  local out = {}
  if selectedDevice == "mc" or selectedDevice == nil or selectedDevice == "" then
    local mc = buildOsdMcLocations(chosenMcSlot, fileName)
    for i = 1, #mc do
      appendUnique(out, mc[i])
    end
  end
  if includeXfrom and (selectedDevice == "xfrom" or selectedDevice == nil or selectedDevice == "") then
    appendUnique(out, "xfrom:/osdmenu/" .. fileName)
  end
  return out
end

local function buildMbrLocations(fileName, selectedDevice)
  local out = {}
  if selectedDevice == "hdd" or selectedDevice == nil or selectedDevice == "" then
    appendUnique(out, "hdd0:__sysconf:pfs:osdmenu/" .. fileName)
  end
  if selectedDevice == "xfrom" or selectedDevice == nil or selectedDevice == "" then
    appendUnique(out, "xfrom:/osdmenu/" .. fileName)
  end
  return out
end

-- Config file locations by context and file type
-- (ps2bbl_ini, psxbbl_ini, osdmenu_cnf, osdmbr_cnf, osdgsm_cnf, r3configurator_cnf).
function config_options.getLocations(context, fileType, chosenMcSlot, selectedDevice)
  if fileType == "r3configurator_cnf" then
    return { "r3configurator.cnf" }
  end
  if fileType == "ps2bbl_ini" then
    return buildPs2BblIniLocations()
  end
  if fileType == "psxbbl_ini" then
    return buildPsxBblIniLocations()
  end
  if fileType == "freemcboot_cnf" then
    if context == "freehddboot" then
      if chosenMcSlot == 0 then
        return {
          "hdd0:__sysconf/FMCB/FREEHDB.CNF",
          "mc0:/SYS-CONF/FREEHDB.CNF",
          "mass:/FREEHDB.CNF",
          "mass1:/FREEHDB.CNF",
        }
      end
      if chosenMcSlot == 1 then
        return {
          "hdd0:__sysconf/FMCB/FREEHDB.CNF",
          "mc1:/SYS-CONF/FREEHDB.CNF",
          "mass:/FREEHDB.CNF",
          "mass1:/FREEHDB.CNF",
        }
      end
      return {
        "hdd0:__sysconf/FMCB/FREEHDB.CNF",
        "mc0:/SYS-CONF/FREEHDB.CNF",
        "mc1:/SYS-CONF/FREEHDB.CNF",
        "mass:/FREEHDB.CNF",
        "mass1:/FREEHDB.CNF",
      }
    end
    if chosenMcSlot == 0 then
      return {
        "mc0:/SYS-CONF/FREEMCB.CNF",
        "mass:/FREEMCB.CNF",
        "mass1:/FREEMCB.CNF",
      }
    end
    if chosenMcSlot == 1 then
      return {
        "mc1:/SYS-CONF/FREEMCB.CNF",
        "mass:/FREEMCB.CNF",
        "mass1:/FREEMCB.CNF",
      }
    end
    return {
      "mc0:/SYS-CONF/FREEMCB.CNF",
      "mc1:/SYS-CONF/FREEMCB.CNF",
      "mass:/FREEMCB.CNF",
      "mass1:/FREEMCB.CNF",
    }
  end
  if fileType == "osdmenu_cnf" then
    if context == "osdmenu" then
      return buildOsdmenuLocations("OSDMENU.CNF", chosenMcSlot, selectedDevice, true)
    end
    if context == "hosdmenu" then return { "pfs0:/osdmenu/OSDMENU.CNF" } end
    return {}
  end
  if fileType == "osdmbr_cnf" then
    if context == "mbr" then return buildMbrLocations("OSDMBR.CNF", selectedDevice) end
    return {}
  end
  if fileType == "osdgsm_cnf" then
    if context == "ps2bbl" or context == "psxbbl" then
      if chosenMcSlot == 1 then
        return { "mc1:/SYS-CONF/OSDGSM.CNF", "mc0:/SYS-CONF/OSDGSM.CNF", "pfs0:/osdmenu/OSDGSM.CNF" }
      end
      return { "mc0:/SYS-CONF/OSDGSM.CNF", "mc1:/SYS-CONF/OSDGSM.CNF", "pfs0:/osdmenu/OSDGSM.CNF" }
    end
    if context == "osdmenu" then
      return buildOsdmenuLocations("OSDGSM.CNF", chosenMcSlot, selectedDevice, true)
    end
    if context == "mbr" then
      return buildMbrLocations("OSDGSM.CNF", selectedDevice)
    end
    if context == "hosdmenu" then
      return { "pfs0:/osdmenu/OSDGSM.CNF", "xfrom:/osdmenu/OSDGSM.CNF" }
    end
    return {}
  end
  return {}
end

-- Preferred create/save path when no existing file was found.
function config_options.getDefaultLocation(context, fileType, chosenMcSlot, selectedDevice)
  if fileType == "ps2bbl_ini" then
    return buildBblDefaultMcPath("PS2BBL.INI", chosenMcSlot)
  end
  if fileType == "psxbbl_ini" then
    return buildBblDefaultMcPath("PSXBBL.INI", chosenMcSlot)
  end
  if fileType == "freemcboot_cnf" then
    if context == "freehddboot" then
      return "hdd0:__sysconf/FMCB/FREEHDB.CNF"
    end
    return buildBblDefaultMcPath("FREEMCB.CNF", chosenMcSlot)
  end
  local loc = config_options.getLocations(context, fileType, chosenMcSlot, selectedDevice)
  return (loc and loc[1]) or nil
end

config_options.BBL_HOTKEYS = {
  "TRIANGLE", "CIRCLE", "CROSS", "SQUARE", "UP", "DOWN", "LEFT", "RIGHT",
  "L1", "L2", "L3", "R1", "R2", "R3", "SELECT", "START"
}
config_options.BBL_MAX_ENTRIES = 10
config_options.BBL_MAX_ARGS_PER_ENTRY = nil -- uncapped
config_options.BBL_MAX_IRX_ENTRIES = 10
config_options.FMCB_MAX_ENTRIES = 99
config_options.FMCB_MAX_PATHS_PER_ENTRY = 3
config_options.FMCB_BBL_MAX_ENTRIES = 3

function config_options.getBblHotkeys()
  return config_options.BBL_HOTKEYS
end

-- PS2BBL/PSXBBL global options and IRX load entries.
local function buildBblIniGlobalOptions()
  local out = {
    {
      key = "VIDEO_MODE",
      optType = "enum",
      default = "AUTO",
      enumVals = { "AUTO", "NTSC", "PAL", "480P" },
      label = "VIDEO_MODE",
      desc = "Loader UI mode: AUTO, NTSC, PAL, 480P.",
    },
    {
      key = "LOGO_DISPLAY",
      optType = "enum",
      default = "3",
      enumVals = { "0", "1", "2", "3" },
      enumDisplayMap = {
        ["0"] = "OFF",
        ["1"] = "CONSOLE INFO",
        ["2"] = "LOGO+INFO",
        ["3"] = "LAUNCH KEY NAME",
      },
      label = "LOGO_DISPLAY",
      desc = "Logo/info display mode.",
    },
    {
      key = "OSDHISTORY_READ",
      optType = "bool",
      default = "1",
      label = "OSDHISTORY_READ",
      desc = "Read previous OSD history state.",
    },
    {
      key = "EJECT_TRAY",
      optType = "bool",
      default = "0",
      label = "EJECT_TRAY",
      desc = "Eject tray before launch.",
    },
    {
      key = "DISC_STOP",
      optType = "bool",
      default = "1",
      label = "DISC_STOP",
      desc = "Stop disc after config is loaded",
    },
    {
      key = "APP_GAMEID",
      optType = "bool",
      default = "1",
      label = "APP_GAMEID",
      desc = "Game ID for RetroGem",
    },
    {
      key = "CDROM_DISABLE_GAMEID",
      optType = "bool",
      default = "0",
      label = "CDROM_DISABLE_GAMEID",
      desc = "Disable RetroGem Game ID for DISCS",
    },
  }

  table.insert(out, {
    key = "_bbl_irx_entries",
    optType = "action",
    label = "Edit IRX entries",
    desc = "Edit LOAD_IRX_E# module paths.",
  })
  return out
end

local function buildBblIniAutoOptions()
  local out = {
    {
      key = "KEY_READ_WAIT_TIME",
      optType = "int",
      default = "6000",
      min = 0,
      max = 600000,
      intPadDeltas = { left = -100, right = 100 },
      intPadLabels = { left = "-0.1s", right = "+0.1s" },
      label = "Timer:",
      desc = "Seconds until this list is executed.",
    },
    {
      key = "NAME_AUTO",
      optType = "text",
      default = "",
      label = "NAME",
      desc = "Display name for AUTO.",
      maxLen = 64,
    },
  }
  for i = 1, 10 do
    table.insert(out, {
      key = "_auto_e" .. tostring(i),
      optType = "bbl_slot",
      bblKeyId = "AUTO",
      bblEntrySlot = i,
      label = "E" .. tostring(i),
      desc = "Edit LK_AUTO_E" .. tostring(i) .. " and ARG_AUTO_E" .. tostring(i) .. ".",
    })
  end
  return out
end

local function buildFreemcbootAutoOptions()
  local out = {
    {
      key = "pad_delay",
      optType = "int",
      default = "0",
      min = 0,
      max = 600000,
      intPadDeltas = { left = -100, right = 100 },
      intPadLabels = { left = "-0.1s", right = "+0.1s" },
      label = "Pad Delay:",
      desc = "Delay before AUTOBOOT launch key selection is processed.",
    },
  }
  local maxSlots = (type(config_options.FMCB_BBL_MAX_ENTRIES) == "number" and config_options.FMCB_BBL_MAX_ENTRIES) or 3
  for i = 1, maxSlots do
      table.insert(out, {
      key = "_auto_e" .. tostring(i),
      optType = "bbl_slot",
      bblKeyId = "AUTO",
      bblEntrySlot = i,
      label = "E" .. tostring(i),
      desc = "Edit LK_Auto_E" .. tostring(i) .. ".",
    })
  end
  return out
end

config_options.ps2bbl_ini = buildBblIniGlobalOptions()
config_options.psxbbl_ini = buildBblIniGlobalOptions()
config_options.ps2bbl_ini_auto = buildBblIniAutoOptions()
config_options.psxbbl_ini_auto = buildBblIniAutoOptions()
config_options.ps2bbl_ini_categories = {
  { name = "Global", options = config_options.ps2bbl_ini },
  { name = "Auto boot", options = config_options.ps2bbl_ini_auto },
  { name = "Launch keys", options = { { key = "_bbl_hotkeys", optType = "action", label = "Launch keys" } } },
}
config_options.psxbbl_ini_categories = {
  { name = "Global", options = config_options.psxbbl_ini },
  { name = "Auto boot", options = config_options.psxbbl_ini_auto },
  { name = "Launch keys", options = { { key = "_bbl_hotkeys", optType = "action", label = "Launch keys" } } },
}

-- optType: "path", "bool", "enum", "string", "int", "text", "color", "action", "header"
-- int: numeric value; +/- hints and L1/R1/L2/R2 apply. bool/path/text/color do not show numeric hints.
config_options.osdmenu_cnf_categories = {
  {
    options = {
      { key = "OSDSYS_video_mode",    optType = "enum", default = "AUTO", enumVals = { "AUTO", "PAL", "NTSC", "480p", "1080i" } },
      { key = "OSDSYS_region",        optType = "enum", default = "AUTO", enumVals = { "AUTO", "jap", "usa", "eur" } },
      { key = "OSDSYS_Skip_Disc",     optType = "bool", default = "1" },
      {
        key = "OSDSYS_boot",
        optType = "enum",
        default = "clock",
        enumVals = { "clock", "browser", "opening" },
        enumDisplayMap = {
          clock = "CLOCK",
          browser = "BROWSER",
          opening = "OPENING",
        },
      },
    },
  },
  {
    options = {
      { key = "OSDSYS_custom_menu",           optType = "bool",  default = "1" },
      { key = "OSDSYS_scroll_menu",           optType = "bool",  default = "1" },
      { key = "OSDSYS_menu_x",                optType = "int",   default = "320", min = 50, max = 590 },
      { key = "OSDSYS_menu_y",                optType = "int",   default = "110", min = 0, max = 220 },
      { key = "OSDSYS_enter_x",               optType = "int",   default = "30",  min = -1, max = 520 },
      { key = "OSDSYS_enter_y",               optType = "int",   default = "-1",  min = -1, max = 242 },
      { key = "OSDSYS_version_x",             optType = "int",   default = "-1",  min = -1, max = 520 },
      { key = "OSDSYS_version_y",             optType = "int",   default = "-1",  min = -1, max = 242 },
      { key = "OSDSYS_cursor_max_velocity",   optType = "int",   default = "1500" },
      { key = "OSDSYS_cursor_acceleration",   optType = "int",   default = "150" },
      { key = "OSDSYS_left_cursor",           optType = "text",  default = "",                   maxLen = 19 },
      { key = "OSDSYS_right_cursor",          optType = "text",  default = "",                   maxLen = 19 },
      { key = "OSDSYS_menu_top_delimiter",    optType = "text",  default = "",                   maxLen = 79 },
      { key = "OSDSYS_menu_bottom_delimiter", optType = "text",  default = "",                   maxLen = 79 },
      { key = "OSDSYS_num_displayed_items",   optType = "int",   default = "7" },
      { key = "OSDSYS_selected_color",        optType = "color", default = "0x10,0x80,0xE0,0x80" },
      { key = "OSDSYS_unselected_color",      optType = "color", default = "0x33,0x33,0x33,0x80" },
    },
  },
  {
    options = {
      { key = "cdrom_skip_ps2logo",   optType = "bool", default = "1" },
      { key = "app_gameid",           optType = "bool", default = "0" },
      { key = "cdrom_disable_gameid", optType = "bool", default = "0" },
      { key = "cdrom_use_dkwdrv",     optType = "bool", default = "0" },
      { key = "ps1drv_enable_fast",   optType = "bool", default = "0" },
      { key = "ps1drv_enable_smooth", optType = "bool", default = "0" },
      { key = "ps1drv_use_ps1vn",     optType = "bool", default = "1" },
      { key = "path_DKWDRV_ELF",      optType = "path", default = "" },
    },
  },
  {
    options = {
      { key = "_menu_entries", optType = "action" },
    },
  },
}
config_options.freemcboot_cnf_auto = buildFreemcbootAutoOptions()
config_options.freemcboot_cnf_categories = {
  {
    name = "OSD behavior modifiers",
    options = {
      { key = "OSDSYS_video_mode",    optType = "enum", default = "AUTO", enumVals = { "AUTO", "PAL", "NTSC" } },
      { key = "OSDSYS_Skip_Disc",     optType = "bool", default = "0" },
      { key = "OSDSYS_Skip_Logo",     optType = "bool", default = "1" },
      { key = "OSDSYS_Inner_Browser", optType = "bool", default = "0" },
      { key = "OSDSYS_Skip_MC",       optType = "bool", default = "1" },
      { key = "OSDSYS_Skip_HDD",      optType = "bool", default = "1" },
      { key = "Debug_Screen",         optType = "bool", default = "0" },
    },
  },
  {
    name = "OSD custom menu options",
    options = {
      { key = "hacked_OSDSYS",              optType = "bool",  default = "1" },
      { key = "OSDSYS_scroll_menu",         optType = "bool",  default = "1" },
      { key = "OSDSYS_menu_x",              optType = "int",   default = "320", min = 50, max = 590 },
      { key = "OSDSYS_menu_y",              optType = "int",   default = "110", min = 0, max = 220 },
      { key = "OSDSYS_enter_x",             optType = "int",   default = "30",  min = -1, max = 520 },
      { key = "OSDSYS_enter_y",             optType = "int",   default = "-1",  min = -1, max = 242 },
      { key = "OSDSYS_version_x",           optType = "int",   default = "-1",  min = -1, max = 520 },
      { key = "OSDSYS_version_y",           optType = "int",   default = "-1",  min = -1, max = 242 },
      { key = "OSDSYS_cursor_max_velocity", optType = "int",   default = "1500" },
      { key = "OSDSYS_cursor_acceleration", optType = "int",   default = "150" },
      { key = "OSDSYS_left_cursor",         optType = "text",  default = "",                   maxLen = 19 },
      { key = "OSDSYS_right_cursor",        optType = "text",  default = "",                   maxLen = 19 },
      { key = "OSDSYS_menu_top_delimiter",  optType = "text",  default = "",                   maxLen = 79 },
      { key = "OSDSYS_menu_bottom_delimiter", optType = "text", default = "",                  maxLen = 79 },
      { key = "OSDSYS_num_displayed_items", optType = "int",   default = "7" },
      { key = "OSDSYS_selected_color",      optType = "color", default = "0x10,0x80,0xE0,0x80" },
      { key = "OSDSYS_unselected_color",    optType = "color", default = "0x33,0x33,0x33,0x80" },
    },
  },
  {
    name = "Disc Options",
    options = {
      { key = "FastBoot",   optType = "bool", default = "1" },
      { key = "_esr_paths_header", optType = "header", label = "ESR Paths:" },
      { key = "ESR_Path_E1", optType = "path", default = "mass:/BOOT/ESR.ELF" },
      { key = "ESR_Path_E2", optType = "path", default = "mc?:/BOOT/ESR.ELF" },
      { key = "ESR_Path_E3", optType = "path", default = "hdd0:__sysconf:pfs:/FMCB/ESR.ELF" },
    },
  },
  {
    name = "Auto boot",
    options = config_options.freemcboot_cnf_auto,
  },
  {
    name = "Launch keys",
    options = { { key = "_bbl_hotkeys", optType = "action", label = "Launch keys" } },
  },
  {
    name = "Edit menu entries",
    options = { { key = "_menu_entries", optType = "action" } },
  },
}

local function getLanguageCodeFromFile(file)
  return type(file) == "string" and file:match("^strings_(%w+)%.lua$") or nil
end

local function buildR3DefaultLanguageSpec()
  local enumVals = {}
  local enumDisplayMap = {}
  local seen = {}
  local files = (_G.CONFIG_UI and _G.CONFIG_UI.langFiles) or {}
  local names = (_G.CONFIG_UI and _G.CONFIG_UI.langDisplayNames) or {}

  for i, file in ipairs(files) do
    local code = tostring(getLanguageCodeFromFile(file) or ""):lower()
    if code ~= "" and not seen[code] then
      seen[code] = true
      enumVals[#enumVals + 1] = code
      local display = names[i]
      if type(display) == "string" and display ~= "" then
        enumDisplayMap[code] = display
      end
    end
  end

  if #enumVals == 0 then
    enumVals = { "en" }
    enumDisplayMap.en = "English"
  end

  local defaultCode = "en"
  local hasEnglish = false
  for i = 1, #enumVals do
    if enumVals[i] == "en" then
      hasEnglish = true
      break
    end
  end
  if not hasEnglish then
    defaultCode = enumVals[1]
  end

  return defaultCode, enumVals, enumDisplayMap
end

local R3_DEFAULT_LANGUAGE_DEFAULT, R3_DEFAULT_LANGUAGE_ENUM_VALS, R3_DEFAULT_LANGUAGE_ENUM_DISPLAY_MAP = buildR3DefaultLanguageSpec()

local R3_KEYBOARD_LAYOUT_ENUM_VALS = { "qwerty", "dvorak", "qwertz", "azerty", "abnt", "abc" }
local R3_KEYBOARD_LAYOUT_ENUM_DISPLAY_MAP = {
  qwerty = "QWERTY",
  dvorak = "DVORAK",
  qwertz = "QWERTZ",
  azerty = "AZERTY",
  abnt = "ABNT",
  abc = "ABC",
}

config_options.r3configurator_cnf = {
  {
    key = "video_mode",
    optType = "enum",
    default = "auto",
    enumVals = { "auto", "ntsc", "pal", "480p" },
    enumDisplayMap = {
      auto = "AUTO",
      ntsc = "NTSC",
      pal = "PAL",
      ["480p"] = "480p",
    },
    label = "Video mode",
    desc = "Startup video mode (auto keeps native PS2 mode).",
  },
  {
    key = "swap_buttons",
    optType = "bool",
    default = "0",
    label = "Swap buttons",
    desc = "Swap confirm/cancel (Cross <-> Circle).",
  },
  {
    key = "default_language",
    optType = "enum",
    default = R3_DEFAULT_LANGUAGE_DEFAULT,
    enumVals = R3_DEFAULT_LANGUAGE_ENUM_VALS,
    enumDisplayMap = R3_DEFAULT_LANGUAGE_ENUM_DISPLAY_MAP,
    label = "Default language",
    desc = "Default UI language.",
  },
  {
    key = "keyboard_layout",
    optType = "enum",
    default = "qwerty",
    enumVals = R3_KEYBOARD_LAYOUT_ENUM_VALS,
    enumDisplayMap = R3_KEYBOARD_LAYOUT_ENUM_DISPLAY_MAP,
    label = "Keyboard layout",
    desc = "On-screen keyboard layout.",
  },
  { key = "show_freemcboot", optType = "bool", default = "1", label = "Show FreeMCBoot" },
  { key = "show_freehddboot", optType = "bool", default = "1", label = "Show FreeHDBoot" },
  { key = "show_osdmenu", optType = "bool", default = "1", label = "Show OSDMenu" },
  { key = "show_osdmenu_mbr", optType = "bool", default = "1", label = "Show OSDMenu MBR" },
  { key = "show_hosdmenu", optType = "bool", default = "1", label = "Show HOSDMenu" },
  { key = "show_ps2bbl", optType = "bool", default = "1", label = "Show PS2BBL" },
  { key = "show_psxbbl", optType = "bool", default = "1", label = "Show PSXBBL" },
  {
    key = "scene_transition",
    optType = "enum",
    default = "cut",
    enumVals = { "cut", "slide", "cross_dissolve", "whip_pan", "zoom", "flip_horizontal", "flip_vertical" },
    enumDisplayMap = {
      cut = "Cut",
      slide = "Slide",
      cross_dissolve = "Cross dissolve",
      whip_pan = "Whip pan",
      zoom = "Zoom",
      flip_horizontal = "Flip horizontal",
      flip_vertical = "Flip vertical",
    },
    label = "Scene transition",
    desc = "Transition style for scene changes (confirm/edit = in, cancel/back = out).",
  },
  {
    key = "scene_transition_frames",
    optType = "int",
    default = "10",
    min = 1,
    max = 60,
    label = "Transition frames",
    desc = "Transition speed in frames (higher is slower).",
  },
  { key = "cross", optType = "color", default = "606060", label = "Cross color" },
  { key = "square", optType = "color", default = "606060", label = "Square color" },
  { key = "triangle", optType = "color", default = "606060", label = "Triangle color" },
  { key = "circle", optType = "color", default = "606060", label = "Circle color" },
  { key = "selected", optType = "color", default = "0072A0", label = "Selected color" },
  { key = "selected_dim", optType = "color", default = "003250", label = "Selected dim color" },
  { key = "unselected", optType = "color", default = "C8C8C8", label = "Unselected color" },
  { key = "dim", optType = "color", default = "606060", label = "Dim color" },
  { key = "background", optType = "color", default = "141414", label = "Background color" },
}

-- Get default value for a single key from osdmenu_cnf_categories (nil if no default).
function config_options.getOsdmenuDefault(key)
  for _, cat in ipairs(config_options.osdmenu_cnf_categories) do
    for _, o in ipairs(cat.options) do
      if o.key == key and o.default ~= nil then return o.default end
    end
  end
  return nil
end

-- Return key -> default map for all options that have a default (for new config and Triangle reset; excludes menu entries only).
function config_options.getOsdmenuDefaults()
  local out = {}
  for _, cat in ipairs(config_options.osdmenu_cnf_categories) do
    for _, o in ipairs(cat.options) do
      if o.key and o.default ~= nil and o.key:sub(1, 1) ~= "_" then
        out[o.key] = o.default
      end
    end
  end
  return out
end

function config_options.getFreemcbootDefault(key)
  for _, cat in ipairs(config_options.freemcboot_cnf_categories or {}) do
    for _, o in ipairs(cat.options or {}) do
      if o.key == key and o.default ~= nil then
        return o.default
      end
    end
  end
  return nil
end

function config_options.getFreemcbootDefaults()
  local out = {}
  for _, cat in ipairs(config_options.freemcboot_cnf_categories or {}) do
    for _, o in ipairs(cat.options or {}) do
      if o.key and o.default ~= nil and o.key:sub(1, 1) ~= "_" then
        out[o.key] = o.default
      end
    end
  end
  return out
end

function config_options.getR3ConfiguratorDefault(key)
  for _, o in ipairs(config_options.r3configurator_cnf or {}) do
    if o.key == key and o.default ~= nil then
      return o.default
    end
  end
  return nil
end

function config_options.getR3ConfiguratorDefaults()
  local out = {}
  for _, o in ipairs(config_options.r3configurator_cnf or {}) do
    if o.key and o.default ~= nil and o.key:sub(1, 1) ~= "_" then
      out[o.key] = o.default
    end
  end
  return out
end

-- Launch Disc (cdrom) options. key = launcher argument (-nologo etc.). Label/desc from strings.cdrom_options (by key without leading -).
config_options.cdrom_options = {
  { key = "-nologo" },
  { key = "-nogameid" },
  { key = "-dkwdrv" },
  { key = "-ps1fast" },
  { key = "-ps1smooth" },
  { key = "-ps1vneg" },
}

local OSD_LANGUAGE_DISPLAY = {
  jap = "Japanese (Nihongo)",
  eng = "English",
  fre = "French (Francais)",
  spa = "Spanish (Espanol)",
  ger = "German (Deutsch)",
  ita = "Italian (Italiano)",
  dut = "Dutch (Nederlands)",
  por = "Portuguese (Portugues)",
  rus = "Russian (Russkiy)",
  kor = "Korean (Hangugeo)",
  tch = "Traditional Chinese (Zhongwen)",
  sch = "Simplified Chinese (Zhongwen)",
}

local OSDMBR_BEHAVIOR_OPTIONS = {
  { key = "osd_screentype", optType = "enum", default = "", enumVals = { "4:3", "16:9", "full" } },
  {
    key = "osd_language",
    optType = "enum",
    default = "",
    enumVals = { "jap", "eng", "fre", "spa", "ger", "ita", "dut", "por", "rus", "kor", "tch", "sch" },
    enumDisplayMap = OSD_LANGUAGE_DISPLAY,
  },
}

local OSDMBR_LAUNCH_OPTIONS = {
  { key = "cdrom_skip_ps2logo",   optType = "bool", default = "1" },
  { key = "app_gameid",           optType = "bool", default = "0" },
  { key = "cdrom_disable_gameid", optType = "bool", default = "0" },
  { key = "cdrom_use_dkwdrv",     optType = "bool", default = "0" },
  { key = "ps1drv_enable_fast",   optType = "bool", default = "0" },
  { key = "ps1drv_enable_smooth", optType = "bool", default = "0" },
  { key = "ps1drv_use_ps1vn",     optType = "bool", default = "1" },
  { key = "prefer_bbn",           optType = "bool", default = "0" },
}

local OSDMBR_BOOT_OPTIONS = {
  { key = "boot_auto",     optType = "boot_paths" },
  { key = "boot_start",    optType = "boot_paths" },
  { key = "boot_select",   optType = "boot_paths" },
  { key = "boot_triangle", optType = "boot_paths" },
  { key = "boot_circle",   optType = "boot_paths" },
  { key = "boot_cross",    optType = "boot_paths" },
  { key = "boot_square",   optType = "boot_paths" },
  { key = "boot_up",       optType = "boot_paths" },
  { key = "boot_down",     optType = "boot_paths" },
  { key = "boot_left",     optType = "boot_paths" },
  { key = "boot_right",    optType = "boot_paths" },
  { key = "boot_l1",       optType = "boot_paths" },
  { key = "boot_l2",       optType = "boot_paths" },
  { key = "boot_r1",       optType = "boot_paths" },
  { key = "boot_r2",       optType = "boot_paths" },
}

config_options.osdmbr_cnf_categories = {
  { name = "OSD behavior modifiers", options = OSDMBR_BEHAVIOR_OPTIONS },
  { name = "Disc and application launch modifiers", options = OSDMBR_LAUNCH_OPTIONS },
  { name = "Autoboot and launch keys", options = OSDMBR_BOOT_OPTIONS },
}

-- Flat OSDMBR.CNF option order used by save/regeneration helpers.
config_options.osdmbr_cnf = {}
for _, cat in ipairs(config_options.osdmbr_cnf_categories) do
  for _, o in ipairs(cat.options or {}) do
    config_options.osdmbr_cnf[#config_options.osdmbr_cnf + 1] = o
  end
end

-- OSDGSM.CNF: edited in egsm_editor state (default + title overrides on one screen). Option list not used.
config_options.osdgsm_cnf = {}

-- eGSM value options (loader README: video empty/fp1/fp2/1080ix1..3, compat empty/1/2/3). Single source of truth for parse/UI.
config_options.EGSM_VIDEO = { "", "fp1", "fp2", "1080ix1", "1080ix2", "1080ix3" }
config_options.EGSM_COMPAT = { "", "1", "2", "3" }
function config_options.getEgsmVideoOptions()
  return config_options.EGSM_VIDEO
end

function config_options.getEgsmCompatOptions()
  return config_options.EGSM_COMPAT
end

return config_options
