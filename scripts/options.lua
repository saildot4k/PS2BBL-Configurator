--[[
  Option structure per config type (keys, types, defaults). No UI text here.
  Labels, descriptions, and category names come from lang/strings_<LANG>.lua (see ui_main.lua).
]]

local config_options = {}

-- UI feature toggles. Keep eGSM code present but hidden until enabled.
config_options.FEATURES = {
  egsm_ui = true,
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
  ata = false,
  xfrom = false,
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
-- Ordered to match PS2BBL source search order (first -> last), ignoring unsupported XFROM.
local function buildPs2BblIniLocations()
  local out = {}
  appendUnique(out, "mmce1:/PS2BBL/PS2BBL.INI")
  appendUnique(out, "mmce0:/PS2BBL/PS2BBL.INI")
  appendUnique(out, "hdd0:__sysconf:pfs:/PS2BBL/CONFIG.INI")
  appendUnique(out, "massX:/PS2BBL/CONFIG.INI")
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
  appendUnique(out, "mmce1:/PS2BBL/PS2BBL.INI")
  appendUnique(out, "mmce0:/PS2BBL/PS2BBL.INI")
  appendUnique(out, "hdd0:__sysconf:pfs:/PS2BBL/CONFIG.INI")
  appendUnique(out, "massX:/PS2BBL/CONFIG.INI")
  appendUnique(out, "mass:/PS2BBL/CONFIG.INI")
  return out
end

-- Config file locations by context and file type (ps2bbl_ini, psxbbl_ini, osdmenu_cnf, osdmbr_cnf, osdgsm_cnf).
function config_options.getLocations(context, fileType, chosenMcSlot)
  if fileType == "ps2bbl_ini" then
    return buildPs2BblIniLocations()
  end
  if fileType == "psxbbl_ini" then
    return buildPsxBblIniLocations()
  end
  if fileType == "freemcboot_cnf" then
    if chosenMcSlot == 0 then
      return {
        "mc0:/SYS-CONF/FREEMCB.CNF",
        "mass:/FREEMCB.CNF",
        "hdd0:__sysconf/FMCB/FREEHDB.CNF",
      }
    end
    if chosenMcSlot == 1 then
      return {
        "mc1:/SYS-CONF/FREEMCB.CNF",
        "mass:/FREEMCB.CNF",
        "hdd0:__sysconf/FMCB/FREEHDB.CNF",
      }
    end
    return {
      "mc0:/SYS-CONF/FREEMCB.CNF",
      "mc1:/SYS-CONF/FREEMCB.CNF",
      "mass:/FREEMCB.CNF",
      "hdd0:__sysconf/FMCB/FREEHDB.CNF",
    }
  end
  if fileType == "osdmenu_cnf" then
    if context == "osdmenu" then
      if chosenMcSlot == 0 then return { "mc0:/SYS-CONF/OSDMENU.CNF" } end
      if chosenMcSlot == 1 then return { "mc1:/SYS-CONF/OSDMENU.CNF" } end
      return { "mc0:/SYS-CONF/OSDMENU.CNF", "mc1:/SYS-CONF/OSDMENU.CNF" }
    end
    if context == "hosdmenu" then return { "pfs0:/osdmenu/OSDMENU.CNF" } end
    return {}
  end
  if fileType == "osdmbr_cnf" then
    if context == "mbr" then return { "pfs0:/osdmenu/OSDMBR.CNF" } end
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
      if chosenMcSlot == 0 then return { "mc0:/SYS-CONF/OSDGSM.CNF" } end
      if chosenMcSlot == 1 then return { "mc1:/SYS-CONF/OSDGSM.CNF" } end
      return { "mc0:/SYS-CONF/OSDGSM.CNF", "mc1:/SYS-CONF/OSDGSM.CNF" }
    end
    if context == "hosdmenu" or context == "mbr" then
      return { "pfs0:/osdmenu/OSDGSM.CNF" }
    end
    return {}
  end
  return {}
end

-- Preferred create/save path when no existing file was found.
function config_options.getDefaultLocation(context, fileType, chosenMcSlot)
  if fileType == "ps2bbl_ini" then
    return buildBblDefaultMcPath("PS2BBL.INI", chosenMcSlot)
  end
  if fileType == "psxbbl_ini" then
    return buildBblDefaultMcPath("PSXBBL.INI", chosenMcSlot)
  end
  if fileType == "freemcboot_cnf" then
    return buildBblDefaultMcPath("FREEMCB.CNF", chosenMcSlot)
  end
  local loc = config_options.getLocations(context, fileType, chosenMcSlot)
  return (loc and loc[1]) or nil
end

config_options.BBL_HOTKEYS = {
  "TRIANGLE", "CIRCLE", "CROSS", "SQUARE", "UP", "DOWN", "LEFT", "RIGHT",
  "L1", "L2", "L3", "R1", "R2", "R3", "SELECT", "START"
}
config_options.BBL_MAX_ENTRIES = 10
config_options.BBL_MAX_ARGS_PER_ENTRY = 8
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
      enumVals = { "0", "1", "2", "3", "4", "5" },
      enumDisplayMap = {
        ["0"] = "OFF",
        ["1"] = "CONSOLE INFO",
        ["2"] = "LOGO+INFO",
        ["3"] = "LAUNCH KEY NAME",
        ["4"] = "LAUNCH KEY FOUND FILE",
        ["5"] = "LAUNCH KEY FOUND PATH",
      },
      label = "LOGO_DISPLAY",
      desc = "Display speed: FAST (0-3), SLOWER (4-5).",
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
      key = "PS1DRV_ENABLE_FAST",
      optType = "bool",
      default = "0",
      label = "PS1DRV_ENABLE_FAST",
      desc = "Enable PS1 fast loading.",
    },
    {
      key = "PS1DRV_ENABLE_SMOOTH",
      optType = "bool",
      default = "0",
      label = "PS1DRV_ENABLE_SMOOTH",
      desc = "Enable PS1 smoothing.",
    },
    {
      key = "PS1DRV_USE_PS1VN",
      optType = "bool",
      default = "0",
      label = "PS1DRV_USE_PS1VN",
      desc = "Enable PS1 video negator.",
    },
  }

  for i = 1, 10 do
    local k = "LOAD_IRX_E" .. tostring(i)
    table.insert(out, {
      key = k,
      optType = "path",
      default = "",
      label = k,
      desc = "IRX module path (" .. tostring(i) .. ").",
    })
  end
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
      intPadDeltas = { left = -100, L1 = -1000, L2 = -10000, R2 = 10000, R1 = 1000, right = 100 },
      intPadLabels = { left = "-0.1s", L1 = "-1s", L2 = "-10s", R2 = "+10s", R1 = "+1s", right = "+0.1s" },
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
      key = "KEY_READ_WAIT_TIME",
      optType = "int",
      default = "6000",
      min = 0,
      max = 600000,
      intPadDeltas = { left = -100, L1 = -1000, L2 = -10000, R2 = 10000, R1 = 1000, right = 100 },
      intPadLabels = { left = "-0.1s", L1 = "-1s", L2 = "-10s", R2 = "+10s", R1 = "+1s", right = "+0.1s" },
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
  local maxSlots = (type(config_options.FMCB_BBL_MAX_ENTRIES) == "number" and config_options.FMCB_BBL_MAX_ENTRIES) or 3
  for i = 1, maxSlots do
    table.insert(out, {
      key = "_auto_e" .. tostring(i),
      optType = "bbl_slot",
      bblKeyId = "AUTO",
      bblEntrySlot = i,
      label = "E" .. tostring(i),
      desc = "Edit LK_AUTO_E" .. tostring(i) .. " (no arguments).",
    })
  end
  return out
end

config_options.ps2bbl_ini = buildBblIniGlobalOptions()
config_options.psxbbl_ini = buildBblIniGlobalOptions()
config_options.ps2bbl_ini_auto = buildBblIniAutoOptions()
config_options.psxbbl_ini_auto = buildBblIniAutoOptions()
config_options.ps2bbl_ini_categories = {
  { name = "GLOBAL", options = config_options.ps2bbl_ini },
  { name = "AUTOBOOT", options = config_options.ps2bbl_ini_auto },
  { name = "LAUNCH KEYS", options = { { key = "_bbl_hotkeys", optType = "action", label = "LAUNCH KEYS" } } },
}
config_options.psxbbl_ini_categories = {
  { name = "GLOBAL", options = config_options.psxbbl_ini },
  { name = "AUTOBOOT", options = config_options.psxbbl_ini_auto },
  { name = "LAUNCH KEYS", options = { { key = "_bbl_hotkeys", optType = "action", label = "LAUNCH KEYS" } } },
}

-- optType: "path", "bool", "enum", "string", "int", "text", "color", "action", "header"
-- int: numeric value; +/- hints and L1/R1/L2/R2 apply. bool/path/text/color do not show numeric hints.
config_options.osdmenu_cnf_categories = {
  {
    options = {
      { key = "OSDSYS_video_mode",    optType = "enum", default = "AUTO", enumVals = { "AUTO", "PAL", "NTSC", "480p", "1080i" } },
      { key = "OSDSYS_region",        optType = "enum", default = "AUTO", enumVals = { "AUTO", "jap", "usa", "eur" } },
      { key = "OSDSYS_Skip_Disc",     optType = "bool", default = "1" },
      { key = "OSDSYS_Skip_Logo",     optType = "bool", default = "1" },
      { key = "OSDSYS_Inner_Browser", optType = "bool", default = "0" },
    },
  },
  {
    options = {
      { key = "OSDSYS_custom_menu",           optType = "bool",  default = "1" },
      { key = "OSDSYS_scroll_menu",           optType = "bool",  default = "1" },
      { key = "OSDSYS_menu_x",                optType = "int",   default = "320" },
      { key = "OSDSYS_menu_y",                optType = "int",   default = "110" },
      { key = "OSDSYS_enter_x",               optType = "int",   default = "30" },
      { key = "OSDSYS_enter_y",               optType = "int",   default = "-1" },
      { key = "OSDSYS_version_x",             optType = "int",   default = "-1" },
      { key = "OSDSYS_version_y",             optType = "int",   default = "-1" },
      { key = "OSDSYS_cursor_max_velocity",   optType = "int",   default = "1500" },
      { key = "OSDSYS_cursor_acceleration",   optType = "int",   default = "150" },
      { key = "OSDSYS_left_cursor",           optType = "text",  default = "",                   maxLen = 19 },
      { key = "OSDSYS_right_cursor",          optType = "text",  default = "",                   maxLen = 19 },
      { key = "OSDSYS_menu_top_delimiter",    optType = "text",  default = "",                   maxLen = 79 },
      { key = "OSDSYS_menu_bottom_delimiter", optType = "text",  default = "",                   maxLen = 79 },
      { key = "OSDSYS_num_displayed_items",   optType = "int",   default = "5" },
      { key = "OSDSYS_selected_color",        optType = "color", default = "0x10,0x80,0xE0,0x80" },
      { key = "OSDSYS_unselected_color",      optType = "color", default = "0x33,0x33,0x33,0x80" },
    },
  },
  {
    options = {
      { key = "cdrom_skip_ps2logo",   optType = "bool", default = "1" },
      { key = "cdrom_disable_gameid", optType = "bool", default = "0" },
      { key = "cdrom_use_dkwdrv",     optType = "bool", default = "0" },
      { key = "ps1drv_enable_fast",   optType = "bool", default = "0" },
      { key = "ps1drv_enable_smooth", optType = "bool", default = "0" },
      { key = "ps1drv_use_ps1vn",     optType = "bool", default = "1" },
      { key = "app_gameid",           optType = "bool", default = "0" },
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
config_options.freemcboot_cnf_categories = {}
for i = 1, #config_options.osdmenu_cnf_categories do
  config_options.freemcboot_cnf_categories[#config_options.freemcboot_cnf_categories + 1] =
      config_options.osdmenu_cnf_categories[i]
end
config_options.freemcboot_cnf_categories[#config_options.freemcboot_cnf_categories + 1] = {
  name = "AUTOBOOT",
  options = config_options.freemcboot_cnf_auto,
}
config_options.freemcboot_cnf_categories[#config_options.freemcboot_cnf_categories + 1] = {
  name = "LAUNCH KEYS",
  options = { { key = "_bbl_hotkeys", optType = "action", label = "LAUNCH KEYS" } },
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
  local def = config_options.getOsdmenuDefault(key)
  if def ~= nil then return def end
  for _, o in ipairs(config_options.freemcboot_cnf_auto or {}) do
    if o.key == key and o.default ~= nil then
      return o.default
    end
  end
  return nil
end

function config_options.getFreemcbootDefaults()
  local out = config_options.getOsdmenuDefaults()
  for _, o in ipairs(config_options.freemcboot_cnf_auto or {}) do
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

-- OSDMBR.CNF: boot button paths (multi) + args; then other options. Label/desc from strings.options[key].
config_options.osdmbr_cnf = {
  { key = "boot_auto",            optType = "boot_paths" },
  { key = "boot_start",           optType = "boot_paths" },
  { key = "boot_triangle",        optType = "boot_paths" },
  { key = "boot_circle",          optType = "boot_paths" },
  { key = "boot_cross",           optType = "boot_paths" },
  { key = "boot_square",          optType = "boot_paths" },
  { key = "cdrom_skip_ps2logo",   optType = "bool",      default = "1" },
  { key = "cdrom_disable_gameid", optType = "bool",      default = "0" },
  { key = "cdrom_use_dkwdrv",     optType = "bool",      default = "0" },
  { key = "ps1drv_enable_fast",   optType = "bool",      default = "0" },
  { key = "ps1drv_enable_smooth", optType = "bool",      default = "0" },
  { key = "ps1drv_use_ps1vn",     optType = "bool",      default = "1" },
  { key = "prefer_bbn",           optType = "bool",      default = "0" },
  { key = "app_gameid",           optType = "bool",      default = "0" },
  { key = "osd_screentype",       optType = "enum",      default = "", enumVals = { "4:3", "16:9", "full" } },
  { key = "osd_language",         optType = "enum",      default = "", enumVals = { "jap", "eng", "fre", "spa", "ger", "ita", "dut", "por", "rus", "kor", "tch", "sch" } },
}

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
