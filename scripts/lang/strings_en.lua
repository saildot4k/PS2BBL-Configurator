--[[
  English UI strings for the configurator.
  Copy to strings_XX.lua (e.g. strings_fr.lua) and translate values; keep keys unchanged.
  Hint _items: each entry is { pad = "cross", label = "Enter" }. Optional row = 1 (bottom) or 2 (top); if any item has row=2, row assignment is from lang, else first 4 go bottom, rest top.
]]

local strings = {}

-- Main flow (main, choose_mc, select_config, initHdd, open, choose_load)
strings.main = {
  main_title = "OSDMenu Configurator",
  main_sub = "Pick one of the options below",
  version_unknown = "unknown",
  main_hint_items = { { pad = "up", label = "Up" }, { pad = "cross", label = "Enter" }, { pad = "down", label = "Down" }, { pad = "start", label = "Exit", row = 2 } },
  main_hint_items_with_lang = { { pad = "up", label = "Up" }, { pad = "cross", label = "Enter" }, { pad = "down", label = "Down" }, { pad = "L1", label = "Language", row = 2 }, { pad = "start", label = "Save", row = 2 }, { pad = "R1", label = "Language", row = 2 } },
  main_ps2bbl_mc = "PS2BBL",
  main_psxbbl_mc = "PSXBBL",
  main_exit = "Exit to browser",
  main_exit_prompt = "Exit to browser?",
  main_exit_hint_items = { { pad = "cross", label = "Yes" }, { pad = "circle", label = "No" } },
  no_memory_card = "No memory card found",
  insert_mc = "Insert a memory card and try again",
  circle_back_items = { { pad = "circle", label = "Back" } },
  select_memory_card = "Select memory card to load config from",
  config_card_hint = "Config file will be created if it doesn't exist",
  cross_select_circle_back_items = { { pad = "cross", label = "Enter" }, { pad = "circle", label = "Back" } },
  memory_card_1_slot = "Memory Card 1",
  memory_card_2_slot = "Memory Card 2",
  which_file = "Which file?",
  init_hdd_title = "Initializing HDD modules...",
  init_hdd_sub = "Loading HDD drivers and mounting __sysconf",
  no_location = "No location for this file type",
  hdd_not_found = "Make sure HDD is connected and formatted",
  cross_back_items = { { pad = "cross", label = "Back" } },
  failed_to_load = "Failed to load: ",
  cross_load_circle_back_items = { { pad = "cross", label = "Load" }, { pad = "circle", label = "Back" } },
  select_config_ps2bbl_ini = "PS2BBL.INI",
  select_config_psxbbl_ini = "PSXBBL.INI",
  select_config_osdmenu_cnf = "OSDMENU.CNF",
  select_config_osdmbr_cnf = "OSDMBR.CNF",
  select_config_osdgsm_cnf = "OSDGSM.CNF",
}

-- Editor
strings.editor = {
  saved = "Saved",
  cross_open_circle_back_items = { { pad = "cross", label = "Enter" }, { pad = "start", label = "Save" }, { pad = "circle", label = "Back" } },
  start_save_circle_back_items = { { pad = "start", label = "Save" }, { pad = "circle", label = "Back" } },
  hint_edit_items = { { pad = "cross", label = "Edit", row = 1 }, { pad = "triangle", label = "Reset", row = 1 }, { pad = "start", label = "Save", row = 1 }, { pad = "circle", label = "Back", row = 1 }, { pad = "left", label = "-1", row = 2 }, { pad = "L1", label = "-10", row = 2 }, { pad = "L2", label = "-50", row = 2 }, { pad = "R2", label = "+50", row = 2 }, { pad = "R1", label = "+10", row = 2 }, { pad = "right", label = "+1", row = 2 } },
  no_option_list = "No option list for this file type",
  save_config_to = "Save config to",
  save_failed = "Save failed",
  no_save_location = "No save location",
  error_write_failed = "Write failed",
  error_read_failed = "Read failed",
  error_cannot_get_size = "Cannot get file size",
  error_cannot_open = "Cannot open ",
  error_cannot_open_for_write = "Cannot open for write ",
  cross_save_circle_cancel_items = { { pad = "cross", label = "Save" }, { pad = "circle", label = "Cancel" } },
  leave_save_prompt = "Save changes before leaving?",
  leave_save_hint_items = { { pad = "cross", label = "Save" }, { pad = "triangle", label = "Discard" }, { pad = "circle", label = "Cancel" } },
  edit_color_suffix = " — Edit color",
  red = "Red",
  green = "Green",
  blue = "Blue",
  alpha = "Alpha",
  color_edit_hint_items = { { pad = "cross", label = "Apply", row = 1 }, { pad = "up", label = "Up", row = 1 }, { pad = "down", label = "Down", row = 1 }, { pad = "circle", label = "Back", row = 1 }, { pad = "left", label = "-1", row = 2 }, { pad = "L1", label = "-10", row = 2 }, { pad = "L2", label = "-50", row = 2 }, { pad = "R2", label = "+50", row = 2 }, { pad = "R1", label = "+10", row = 2 }, { pad = "right", label = "+1", row = 2 } },
}

-- Menu entries
strings.menu_entries = {
  edit_menu_entries = "Edit menu entries",
  item = "Item ",
  hint_items = { { pad = "cross", label = "Enter", row = 1 }, { pad = "select", label = "Insert", row = 1 }, { pad = "square", label = "Delete", row = 1 }, { pad = "circle", label = "Back", row = 1 }, { pad = "left", label = "-12", row = 2 }, { pad = "L1", label = "Up", row = 2 }, { pad = "start", label = "Save", row = 2 }, { pad = "R1", label = "Down", row = 2 }, { pad = "right", label = "+12", row = 2 } },
  hint_items_with_enable = { { pad = "cross", label = "Enter", row = 1 }, { pad = "triangle", label = "Enable", row = 1 }, { pad = "select", label = "Insert", row = 1 }, { pad = "square", label = "Delete", row = 1 }, { pad = "circle", label = "Back", row = 1 }, { pad = "left", label = "-12", row = 2 }, { pad = "L1", label = "Up", row = 2 }, { pad = "start", label = "Save", row = 2 }, { pad = "R1", label = "Down", row = 2 }, { pad = "right", label = "+12", row = 2 } },
  hint_items_with_disable = { { pad = "cross", label = "Enter", row = 1 }, { pad = "triangle", label = "Disable", row = 1 }, { pad = "select", label = "Insert", row = 1 }, { pad = "square", label = "Delete", row = 1 }, { pad = "circle", label = "Back", row = 1 }, { pad = "left", label = "-12", row = 2 }, { pad = "L1", label = "Up", row = 2 }, { pad = "start", label = "Save", row = 2 }, { pad = "R1", label = "Down", row = 2 }, { pad = "right", label = "+12", row = 2 } },
  entry_index = "Entry ",
  name = "Name: ",
  paths = "Paths: ",
  args = "args: ",
  none = "none",
  path_s = " path(s)",
  arg_s = " arg(s)",
  cross_select_circle_back_items = { { pad = "cross", label = "Enter" }, { pad = "circle", label = "Back" } },
  edit_name = "Edit name",
  paths_label = "Paths",
  launch_disc_options = "Launch disc options",
  arguments = "Arguments",
  entry_name_prompt = "Entry name",
  add_entry_label = "New entry",
  launch_disc_options_title = "Launch disc options",
  launch_disc_options_sub = "These options override the default disc launch behavior",
  paths_for_entry_title = "Paths for %s (entry %s)",
  paths_hint_items = { { pad = "cross", label = "Edit", row = 1 }, { pad = "square", label = "Remove", row = 1 }, { pad = "circle", label = "Back", row = 1 }, { pad = "L1", label = "Up", row = 2 }, { pad = "select", label = "Add", row = 2 }, { pad = "R1", label = "Down", row = 2 } },
  paths_hint_items_with_enable = { { pad = "cross", label = "Edit", row = 1 }, { pad = "triangle", label = "Enable", row = 1 }, { pad = "square", label = "Remove", row = 1 }, { pad = "circle", label = "Back", row = 1 }, { pad = "L1", label = "Up", row = 2 }, { pad = "select", label = "Add", row = 2 }, { pad = "R1", label = "Down", row = 2 } },
  paths_hint_items_with_disable = { { pad = "cross", label = "Edit", row = 1 }, { pad = "triangle", label = "Disable", row = 1 }, { pad = "square", label = "Remove", row = 1 }, { pad = "circle", label = "Back", row = 1 }, { pad = "L1", label = "Up", row = 2 }, { pad = "select", label = "Add", row = 2 }, { pad = "R1", label = "Down", row = 2 } },
  args_for_entry_title = "Arguments for %s (entry %s)",
  args_hint_items = { { pad = "cross", label = "Edit", row = 1 }, { pad = "square", label = "Remove", row = 1 }, { pad = "circle", label = "Back", row = 1 }, { pad = "L1", label = "Up", row = 2 }, { pad = "select", label = "Add", row = 2 }, { pad = "R1", label = "Down", row = 2 } },
  args_hint_items_with_enable = { { pad = "cross", label = "Edit", row = 1 }, { pad = "triangle", label = "Enable", row = 1 }, { pad = "square", label = "Remove", row = 1 }, { pad = "circle", label = "Back", row = 1 }, { pad = "L1", label = "Up", row = 2 }, { pad = "select", label = "Add", row = 2 }, { pad = "R1", label = "Down", row = 2 } },
  args_hint_items_with_disable = { { pad = "cross", label = "Edit", row = 1 }, { pad = "triangle", label = "Disable", row = 1 }, { pad = "square", label = "Remove", row = 1 }, { pad = "circle", label = "Back", row = 1 }, { pad = "L1", label = "Up", row = 2 }, { pad = "select", label = "Add", row = 2 }, { pad = "R1", label = "Down", row = 2 } },
  cdrom_hint = "Launch disc entry: use Launch disc options for flags",
  cdrom_toggle_hint_items = { { pad = "cross", label = "Toggle" }, { pad = "circle", label = "Back" } },
  new_argument_prompt = "New argument",
  edit_argument_prompt = "Edit argument",
}

-- Path picker
strings.path_picker = {
  choose_device = "Choose device",
  add_path_choose_device = "Add path: choose device",
  enter_path_manually = "Enter path manually",
  enter_path_prompt = "Enter path",
  cross_select_circle_back_items = { { pad = "cross", label = "Enter" }, { pad = "circle", label = "Back" } },
  select_hdd_partition = "Select HDD partition",
  no_partitions = "No partitions (is HDD connected?)",
  cross_open_circle_back_items = { { pad = "cross", label = "Enter" }, { pad = "circle", label = "Back" } },
  cross_open_square_patinfo_circle_back_items = { { pad = "cross", label = "Enter" }, { pad = "square", label = "PATINFO" }, { pad = "circle", label = "Back" } },
  no_elf_files = "No ELF files or folders",
  cross_select_file_items = { { pad = "cross", label = "Select" }, { pad = "circle", label = "Back" } },
  no_devices = "No devices",
  waiting_for_device_drivers = "Waiting for device...",
  circle_back_items = { { pad = "circle", label = "Back" } },
  device_timeout = "Device timeout",
  wildcard_confirm_title = "Use path as wildcard?",
  wildcard_confirm_hint = { { pad = "cross", label = "Yes" }, { pad = "circle", label = "No" } },
}

-- Device and special-entry names. Used by both OSDMenu and MBR file selector / path picker (common strings).
strings.devices = {
  memory_card_1 = "Memory Card 1",
  memory_card_2 = "Memory Card 2",
  launch_disc = "Launch disc with override",
  dvd_player = "DVD Player",
  osd = "OSDSYS",
  shutdown = "Shutdown",
  hosdsys = "Browser 2.0 / HOSDMenu",
  psbbn = "PlayStation Broadband Navigator",
  usb_storage_0 = "USB Mass Storage 1",
  usb_storage_1 = "USB Mass Storage 2",
  mmce_0 = "MMCE in slot 1",
  mmce_1 = "MMCE in slot 2",
  mx4sio_sd = "MX4SIO",
  exfat_hdd_mass0 = "exFAT-formatted HDD",
  hdd = "APA-formatted HDD",
}

-- Common tokens
strings.common = {
  on = "On",
  off = "Off",
  not_set = "(not set)",
  empty = "(empty)",
  enter_text = "Enter text",
  hint_prev = "Previous",
  hint_next = "Next",
}

-- Category names (for OSDMENU editor, by 1-based index)
strings.categories = {
  [1] = "OSD behavior modifiers",
  [2] = "OSD custom menu options",
  [3] = "Disc and application launch modifiers",
  [4] = "Edit menu entries",
}

-- OSDMENU.CNF option labels and descriptions (by option key)
strings.options_osdmenu = {
  OSDSYS_video_mode = { label = "Force video mode", desc = "Force OSD video mode" },
  OSDSYS_region = { label = "Force region", desc = "Force OSD region" },
  OSDSYS_Skip_Disc = { label = "Skip disc", desc = "Skip automatic disc launch" },
  OSDSYS_Skip_Logo = { label = "Skip intro", desc = "Skip SCE intro animation" },
  OSDSYS_Inner_Browser = { label = "Inner browser", desc = "Boot into memory card browser" },
  OSDSYS_custom_menu = { label = "Custom menu", desc = "Enable custom menu" },
  OSDSYS_scroll_menu = { label = "Infinite scrolling", desc = "Enable infinite scrolling" },
  OSDSYS_menu_x = { label = "Menu X", desc = "Custom menu X position" },
  OSDSYS_menu_y = { label = "Menu Y", desc = "Custom menu Y position" },
  OSDSYS_enter_x = { label = "Enter X", desc = "Enter button X position" },
  OSDSYS_enter_y = { label = "Enter Y", desc = "Enter button Y position" },
  OSDSYS_version_x = { label = "Version X", desc = "Version button X position" },
  OSDSYS_version_y = { label = "Version Y", desc = "Version button Y position" },
  OSDSYS_cursor_max_velocity = { label = "Cursor speed", desc = "Cursor maximum speed" },
  OSDSYS_cursor_acceleration = { label = "Cursor acceleration", desc = "Cursor acceleration" },
  OSDSYS_left_cursor = { label = "Left cursor text", desc = "Max 19 chars" },
  OSDSYS_right_cursor = { label = "Right cursor text", desc = "Max 19 chars" },
  OSDSYS_menu_top_delimiter = { label = "Menu top delimiter", desc = "Max 79 chars" },
  OSDSYS_menu_bottom_delimiter = { label = "Menu bottom delimiter", desc = "Max 79 chars" },
  OSDSYS_num_displayed_items = { label = "Items shown", desc = "Number of menu items visible" },
  OSDSYS_selected_color = { label = "Selected color", desc = "Menu entry highlight color" },
  OSDSYS_unselected_color = { label = "Unselected color", desc = "Menu entry color" },
  cdrom_skip_ps2logo = { label = "Skip PS2LOGO", desc = "Skip PlayStation 2 logo at disc boot" },
  cdrom_disable_gameid = { label = "Disable visual game ID", desc = "Disable visual game ID" },
  cdrom_use_dkwdrv = { label = "Use DKWDRV", desc = "Use DKWDRV for PS1 discs" },
  ps1drv_enable_fast = { label = "PS1 fast loading", desc = "Force PS1 fast disc speed" },
  ps1drv_enable_smooth = { label = "PS1 texture smoothing", desc = "Force PS1 texture smoothing" },
  ps1drv_use_ps1vn = { label = "Use PS1VN", desc = "Use PS1 Video Mode Negator" },
  app_gameid = { label = "Application Game ID", desc = "Enable visual game ID for ELF files" },
  path_DKWDRV_ELF = { label = "DKWDRV path", desc = "Custom path to DKWDRV.ELF" },
  _menu_entries = { label = "Edit menu entries", desc = "Edit custom menu entries: name, paths, arguments" },
}

-- OSDMBR.CNF option labels and descriptions (by option key)
strings.options_osdmbr = {
  boot_auto = { label = "Boot auto", desc = "Default paths and arguments" },
  boot_start = { label = "Boot START", desc = "Paths and arguments for start button" },
  boot_triangle = { label = "Boot TRIANGLE", desc = "Paths and arguments for triangle button" },
  boot_circle = { label = "Boot CIRCLE", desc = "Paths and arguments for circle button" },
  boot_cross = { label = "Boot CROSS", desc = "Paths and arguments for cross button" },
  boot_square = { label = "Boot SQUARE", desc = "Paths and arguments for square button" },
  cdrom_skip_ps2logo = { label = "Skip PS2LOGO", desc = "Skip PlayStation 2 logo at disc boot" },
  cdrom_disable_gameid = { label = "Disable visual game ID", desc = "Disable visual game ID" },
  cdrom_use_dkwdrv = { label = "Use DKWDRV", desc = "Use DKWDRV for PS1 discs" },
  ps1drv_enable_fast = { label = "PS1 fast loading", desc = "Force PS1 fast disc speed" },
  ps1drv_enable_smooth = { label = "PS1 texture smoothing", desc = "Force PS1 texture smoothing" },
  ps1drv_use_ps1vn = { label = "Use PS1VN", desc = "Use PS1 Video Mode Negator" },
  prefer_bbn = { label = "Prefer BBN", desc = "Load PSBBN when rebooting" },
  app_gameid = { label = "Application Game ID", desc = "Display visual Game ID for ELF files" },
  osd_screentype = { label = "OSD screen type", desc = "Force OSD screen type (4:3, 16:9, full)" },
  osd_language = { label = "OSD language", desc = "Force OSD language (depends on console model)" },
}

-- eGSM editor (single screen: default + title overrides)
strings.egsm = {
  default_label = "Default",
  title_id_prompt = "Title ID (e.g. SCES12345)",
  hint_items = { { pad = "cross", label = "Edit", row = 1 }, { pad = "select", label = "Insert", row = 1 }, { pad = "square", label = "Delete", row = 1 }, { pad = "circle", label = "Back", row = 1 }, { pad = "start", label = "Save", row = 2 } },
  hint_items_with_enable = { { pad = "cross", label = "Edit", row = 1 }, { pad = "triangle", label = "Enable", row = 1 }, { pad = "select", label = "Insert", row = 1 }, { pad = "square", label = "Delete", row = 1 }, { pad = "circle", label = "Back", row = 1 }, { pad = "start", label = "Save", row = 2 } },
  hint_items_with_disable = { { pad = "cross", label = "Edit", row = 1 }, { pad = "triangle", label = "Disable", row = 1 }, { pad = "select", label = "Insert", row = 1 }, { pad = "square", label = "Delete", row = 1 }, { pad = "circle", label = "Back", row = 1 }, { pad = "start", label = "Save", row = 2 } },
  -- Value edit screen (per loader README: fp1/fp2/1080ix1..3, compat 1/2/3)
  value_edit_title = "eGSM value",
  result_prefix = "Value: ",
  video_header = "Video mode",
  video_240p = "Force 240/288p",
  video_480p = "Force 480/576p",
  video_1080i_1x = "Force 1080i (1x scale)",
  video_1080i_2x = "Force 1080i (2x scale)",
  video_1080i_3x = "Force 1080i (3x scale)",
  compat_header = "Compatibility",
  compat_none = "None",
  compat_1 = "Field flipping type 1 (OPL-like)",
  compat_2 = "Field flipping type 2",
  compat_3 = "Field flipping type 3",
  value_edit_hint = { { pad = "cross", label = "Select", row = 1 }, { pad = "circle", label = "Back", row = 1 } },
}

-- Single lookup table for all config types (built from the three above)
strings.options = {}
for k, v in pairs(strings.options_osdmenu or {}) do strings.options[k] = v end
for k, v in pairs(strings.options_osdmbr or {}) do strings.options[k] = v end
for k, v in pairs(strings.options_osdgsm or {}) do strings.options[k] = v end

-- CDROM option labels/descs (Launch disc options sub-screen). Keys are symbolic (no raw args).
strings.cdrom_options = {
  nologo = { label = "Skip PS2LOGO", desc = "Skip PlayStation 2 logo at disc boot" },
  nogameid = { label = "Disable visual game ID", desc = "Disable visual game ID" },
  dkwdrv = { label = "Use DKWDRV", desc = "Use DKWDRV for PS1 discs" },
  ps1fast = { label = "PS1 fast loading", desc = "Force PS1 fast disc speed" },
  ps1smooth = { label = "PS1 texture smoothing", desc = "Force PS1 texture smoothing" },
  ps1vneg = { label = "Use PS1VN", desc = "Use PS1 Video Mode Negator" },
}

-- Text input (keyboard) hint. hint_items_title_id = same but no Caps (used for GSM title ID).
strings.text_input = {
  hint_items = { { pad = "cross", label = "Enter", row = 1 }, { pad = "triangle", label = "Caps", row = 1 }, { pad = "square", label = "Backspace", row = 1 }, { pad = "circle", label = "Cancel", row = 1 }, { pad = "L1", label = "Left", row = 2 }, { pad = "start", label = "Done", row = 2 }, { pad = "R1", label = "Right", row = 2 } },
  hint_items_title_id = { { pad = "cross", label = "Enter", row = 1 }, { pad = "square", label = "Backspace", row = 1 }, { pad = "circle", label = "Cancel", row = 1 }, { pad = "L1", label = "Left", row = 2 }, { pad = "start", label = "Done", row = 2 }, { pad = "R1", label = "Right", row = 2 } },
}

return strings
