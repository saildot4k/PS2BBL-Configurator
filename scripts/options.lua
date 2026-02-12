--[[
  Option structure per config type (keys, types, defaults). No UI text here.
  Labels, descriptions, and category names come from lang/strings_<LANG>.lua (see ui_main.lua).
]]

local config_options = {}

-- Config file locations by context and file type (osdmenu_cnf, osdmbr_cnf, osdgsm_cnf).
function config_options.getLocations(context, fileType, chosenMcSlot)
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

-- optType: "path", "bool", "enum", "string", "int", "text", "color", "action", "header", "add_path"
-- int: numeric value; +/- hints and L1/R1/L2/R2 apply. bool/path/text/color do not show numeric hints.
config_options.osdmenu_cnf_categories = {
  {
    options = {
      { key = "OSDSYS_video_mode",    optType = "enum", default = "AUTO", enumVals = { "AUTO", "PAL", "NTSC", "480p", "1080i" } },
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

return config_options
