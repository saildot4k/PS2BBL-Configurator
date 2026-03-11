--[[
  OSDMenu GUI Configurator — main and editor UI.
  Renders every frame; pad debounced. Main flow in ui_main.lua.
]]

local common = dofile("scripts/ui_common.lua")
local config_parse = dofile("scripts/parse.lua")
local scene_module = dofile("scripts/ui_state.lua")

_G.CONFIG_UI = { common = common, config_parse = config_parse }
local main = dofile("scripts/ui_main.lua")
local file_selector = dofile("scripts/file_selector.lua")
local config_options = dofile("scripts/options.lua")
_G.CONFIG_UI.file_selector = file_selector
_G.CONFIG_UI.config_options = config_options
_G.CONFIG_UI.main = main
-- State modules (editor, choose_save, etc.): each has .run(ctx) and reads/writes ctx.
local scene_editor = dofile("scripts/scenes/editor.lua")
local scene_choose_save = dofile("scripts/scenes/choose_save.lua")
local scene_color_edit = dofile("scripts/scenes/color_edit.lua")
local scene_menu_entries = dofile("scripts/scenes/menu_entries.lua")
local scene_menu_entry_edit = dofile("scripts/scenes/menu_entry_edit.lua")
local scene_entry_cdrom_options = dofile("scripts/scenes/entry_cdrom_options.lua")
local scene_entry_paths = dofile("scripts/scenes/entry_paths.lua")
local scene_entry_args = dofile("scripts/scenes/entry_args.lua")
local scene_bbl_hotkeys = dofile("scripts/scenes/bbl_hotkeys.lua")
local scene_bbl_hotkey_entries = dofile("scripts/scenes/bbl_hotkey_entries.lua")
local scene_bbl_hotkey_entry = dofile("scripts/scenes/bbl_hotkey_entry.lua")
local scene_bbl_hotkey_args = dofile("scripts/scenes/bbl_hotkey_args.lua")
local scene_text_input = dofile("scripts/scenes/text_input.lua")
local scene_path_picker = dofile("scripts/scenes/path_picker.lua")
local scene_egsm_editor = dofile("scripts/scenes/egsm_editor.lua")
local scene_egsm_value_edit = dofile("scripts/scenes/egsm_value_edit.lua")

local strings = _G.CONFIG_UI.strings
local editor_str = strings.editor
local menu_str = strings.menu_entries
local path_str = strings.path_picker
local common_str = strings.common
local text_str = strings.text_input
local dev_str = strings.devices

-- Local aliases so the rest of the file can stay unchanged
local PAD_UP, PAD_DOWN, PAD_LEFT, PAD_RIGHT = common.PAD_UP, common.PAD_DOWN, common.PAD_LEFT, common.PAD_RIGHT
local PAD_CROSS, PAD_CIRCLE, PAD_START, PAD_TRIANGLE, PAD_SQUARE = common.PAD_CROSS, common.PAD_CIRCLE, common.PAD_START,
    common.PAD_TRIANGLE, common.PAD_SQUARE
local PAD_SELECT = common.PAD_SELECT
local PAD_L1, PAD_R1, PAD_L2, PAD_R2 = common.PAD_L1, common.PAD_R1, common.PAD_L2, common.PAD_R2
local WHITE, GRAY, DIM, DIM_ENTRY, BLACK = common.WHITE, common.GRAY, common.DIM, common.DIM_ENTRY, common.BGCOLOR
local HIGHLIGHT, SELECTED_ENTRY, PREFIX_W = common.HIGHLIGHT, common.SELECTED_ENTRY, common.PREFIX_W
local SELECTED_ENTRY_DIM = common.SELECTED_ENTRY_DIM
local TEXT_CURSOR_COLOR = common.TEXT_CURSOR_COLOR
local FONT_SCALE, LINE_H, ROW_H = common.FONT_SCALE, common.LINE_H, common.ROW_H
local MARGIN_X, MARGIN_Y = common.MARGIN_X, common.MARGIN_Y
local MAX_VISIBLE = common.MAX_VISIBLE
local MAX_VISIBLE_LIST = common.MAX_VISIBLE_LIST
local VALUE_X, VALUE_MAX_LEN, VALUE_MAX_LEN_LONG = common.VALUE_X, common.VALUE_MAX_LEN, common.VALUE_MAX_LEN_LONG
local DESC_Y_BOTTOM, HINT_Y = common.DESC_Y_BOTTOM, common.HINT_Y
local KEYBOARD_ROWS, KEYBOARD_ROWS_SHIFTED, KEYBOARD_ROWS_TITLE_ID = common.KEYBOARD_ROWS, common.KEYBOARD_ROWS_SHIFTED,
    common.KEYBOARD_ROWS_TITLE_ID
local KEYBOARD_CENTER_X, KEYBOARD_CENTER_Y = common.KEYBOARD_CENTER_X, common.KEYBOARD_CENTER_Y
local KEY_WIDTH, KEY_HEIGHT, KEY_GAP = common.KEY_WIDTH, common.KEY_HEIGHT, common.KEY_GAP
local KEY_BG, KEY_BG_SEL, KEY_BORDER, KEY_BORDER_SEL = common.KEY_BG, common.KEY_BG_SEL, common.KEY_BORDER,
    common.KEY_BORDER_SEL
local KEY_CHAR_W, KEY_LINE_H = common.KEY_CHAR_W, common.KEY_LINE_H

local function getLocations(ctx, ft, slot) return config_options.getLocations(ctx, ft, slot) end
local function getPresentMcSlots() return common.getPresentMcSlots() end
local function findExistingPaths(loc) return common.findExistingPaths(loc) end
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

local function mainLoop()
  local font, drawMode = loadCustomFont()
  local function drawListRow(x, y, selected, label, col)
    drawText(font, drawMode, x, y, FONT_SCALE, label, col)
  end

  local ctx = scene_module.initContext()
  ctx.font, ctx.drawMode, ctx.drawListRow = font, drawMode, drawListRow
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
  local colorOpt, colorCh, colorVals = nil, 1, nil
  local entryList, entrySel, entryScroll = {}, 1, 0
  local entryIdx, entryEditSub = nil, 1
  local pathPickerForEntryIdx = nil
  local pathPickerBblHotkeyKey, pathPickerBblHotkeySlot, pathPickerBblHotkeyDisabled = nil, nil, nil
  local textInputPrompt, textInputValue, textInputMaxLen, textInputCallback = nil, "", 79, nil
  local textInputGridSel, textInputShift = 1, false
  local editorCategoryIdx = 0
  local loadChoices, loadSel = nil, 1
  local saveChoices, saveSel = nil, 1
  local entryPathSel, entryPathScroll = 1, 0
  local entryArgSel, entryArgScroll = 1, 0
  local cdromOptSel = 1
  local pathPickerEditIdx, argEditIdx = nil, nil
  local textInputReturnState, textInputCursor, textInputScroll = "menu_entry_edit", 1, 1
  local holdFrameCount = 0
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
    c.colorOpt, c.colorCh, c.colorVals = colorOpt, colorCh, colorVals
    c.entryList, c.entrySel, c.entryScroll = entryList, entrySel, entryScroll
    c.entryIdx, c.entryEditSub = entryIdx, entryEditSub
    c.pathPickerForEntryIdx = pathPickerForEntryIdx
    c.pathPickerBblHotkeyKey, c.pathPickerBblHotkeySlot, c.pathPickerBblHotkeyDisabled = pathPickerBblHotkeyKey,
        pathPickerBblHotkeySlot, pathPickerBblHotkeyDisabled
    c.textInputPrompt, c.textInputValue, c.textInputMaxLen = textInputPrompt, textInputValue, textInputMaxLen
    c.textInputGridSel, c.textInputShift = textInputGridSel, textInputShift
    c.editorCategoryIdx = editorCategoryIdx
    c.loadChoices, c.loadSel = loadChoices, loadSel
    c.saveChoices, c.saveSel = saveChoices, saveSel
    c.entryPathSel, c.entryPathScroll = entryPathSel, entryPathScroll
    c.entryArgSel, c.entryArgScroll = entryArgSel, entryArgScroll
    c.cdromOptSel = cdromOptSel
    c.pathPickerEditIdx, c.argEditIdx = pathPickerEditIdx, argEditIdx
    c.textInputReturnState, c.textInputCursor, c.textInputScroll = textInputReturnState, textInputCursor, textInputScroll
    c.bootKey, c.pathPickerBootKey, c.pathPickerReturnState = bootKey, pathPickerBootKey, pathPickerReturnState
    c.prevPad, c.holdFrameCount = prevPad, holdFrameCount
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
    colorOpt, colorCh, colorVals = c.colorOpt, c.colorCh, c.colorVals
    entryList, entrySel, entryScroll = c.entryList, c.entrySel, c.entryScroll
    entryIdx, entryEditSub = c.entryIdx, c.entryEditSub
    pathPickerForEntryIdx = c.pathPickerForEntryIdx
    pathPickerBblHotkeyKey, pathPickerBblHotkeySlot, pathPickerBblHotkeyDisabled = c.pathPickerBblHotkeyKey,
        c.pathPickerBblHotkeySlot, c.pathPickerBblHotkeyDisabled
    textInputPrompt, textInputValue, textInputMaxLen = c.textInputPrompt, c.textInputValue, c.textInputMaxLen
    textInputGridSel, textInputShift = c.textInputGridSel, c.textInputShift
    editorCategoryIdx = c.editorCategoryIdx
    loadChoices, loadSel = c.loadChoices, c.loadSel
    saveChoices, saveSel = c.saveChoices, c.saveSel
    entryPathSel, entryPathScroll = c.entryPathSel, c.entryPathScroll
    entryArgSel, entryArgScroll = c.entryArgSel, c.entryArgScroll
    cdromOptSel = c.cdromOptSel
    pathPickerEditIdx, argEditIdx = c.pathPickerEditIdx, c.argEditIdx
    textInputReturnState, textInputCursor, textInputScroll = c.textInputReturnState, c.textInputCursor, c
        .textInputScroll
    bootKey, pathPickerBootKey, pathPickerReturnState = c.bootKey, c.pathPickerBootKey, c.pathPickerReturnState
    prevPad, holdFrameCount = c.prevPad or prevPad, c.holdFrameCount or 0
    configModified, editorLeavePrompt, returnToSelectConfigAfterSave, returnToSelectConfigAfterSaveFlash =
        c.configModified, c.editorLeavePrompt, c.returnToSelectConfigAfterSave, c.returnToSelectConfigAfterSaveFlash
    openExplicitPath = c.openExplicitPath
  end

  local REPEATABLE_MASK = PAD_UP | PAD_DOWN | PAD_LEFT | PAD_RIGHT | PAD_L1 | PAD_R1 | PAD_L2 | PAD_R2

  -- One-frame dispatch for all states. Main-flow states use runSceneLoop; others use this.
  local function runOneFrame(c)
    syncFromS(c)
    Screen.clear(BLACK)
    local vmode = Screen.getMode()
    local w = (vmode and vmode.width) or common.DEFAULT_W
    local h = (vmode and vmode.height) or common.DEFAULT_H
    local sy = h / common.DEFAULT_H -- vertical scale for PAL (512) vs NTSC (448); keeps proportions
    c.sy = sy
    -- Keep font at NTSC size on both modes so text fits; only layout (positions, row heights) scales on PAL
    if _G.CONFIG_UI then
      _G.CONFIG_UI.currentDrawHeight = nil
      _G.CONFIG_UI.currentDrawWidth = nil
    end
    c.MARGIN_Y = math.floor(common.MARGIN_Y * sy)
    -- Keep line/row height at NTSC size so spacing matches unscaled text
    c.LINE_H = common.LINE_H
    c.ROW_H = common.ROW_H
    c.HINT_Y = h - math.floor(24 * sy)
    c.DESC_Y_BOTTOM = c.HINT_Y - common.PAD_HINT_TOTAL_H - common.DESC_TO_HINT_MARGIN
    c.scaleY = function(y) return math.floor((y or 0) * sy) end
    local fps = (h == 512) and 50 or 60            -- PAL 50Hz, NTSC 60Hz
    local REPEAT_DELAY_FRAMES = math.ceil(fps / 3) -- repeat every 1/3 s
    local HINT_Y = c.HINT_Y
    local DESC_Y_BOTTOM = c.DESC_Y_BOTTOM
    local KEYBOARD_CENTER_Y = math.floor(h * 220 / 448)
    local MARGIN_Y, LINE_H, ROW_H = c.MARGIN_Y, c.LINE_H, c.ROW_H
    local scaleY = c.scaleY
    local KEY_H = scaleY(common.KEY_HEIGHT)
    local KEY_LH = scaleY(common.KEY_LINE_H)
    if drawMode == "ftPrint" and font then Font.ftSetPixelSize(font, 0, common.FT_PIXEL_H) end
    local pad = Pads.get(0)
    local padJust = pad & ~prevPad
    -- Held inputs: repeat every 1/3 s
    local padRepeat = 0
    if (pad & REPEATABLE_MASK) ~= 0 then
      holdFrameCount = holdFrameCount + 1
      if holdFrameCount >= REPEAT_DELAY_FRAMES then
        padRepeat = pad & REPEATABLE_MASK
        holdFrameCount = 0
      end
    else
      holdFrameCount = 0
    end
    local padEffective = padJust | padRepeat
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
      scaleY = scaleY,
      MARGIN_X = MARGIN_X,
      MARGIN_Y = MARGIN_Y,
      LINE_H = LINE_H,
      ROW_H = ROW_H,
      MAX_VISIBLE = MAX_VISIBLE,
      MAX_VISIBLE_LIST = MAX_VISIBLE_LIST,
      VALUE_X = VALUE_X,
      FONT_SCALE = FONT_SCALE,
      VALUE_MAX_LEN = VALUE_MAX_LEN,
      VALUE_MAX_LEN_LONG = VALUE_MAX_LEN_LONG,
      DESC_Y_BOTTOM = DESC_Y_BOTTOM,
      HINT_Y = HINT_Y,
      SELECTED_ENTRY = SELECTED_ENTRY,
      SELECTED_ENTRY_DIM = SELECTED_ENTRY_DIM,
      WHITE = WHITE,
      GRAY = GRAY,
      DIM = DIM,
      DIM_ENTRY = DIM_ENTRY,
      HIGHLIGHT = HIGHLIGHT,
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
      KEY_WIDTH = KEY_WIDTH,
      KEY_HEIGHT = KEY_HEIGHT,
      KEY_GAP = KEY_GAP,
      KEY_H = KEY_H,
      KEY_LH = KEY_LH,
      KEY_BG = KEY_BG,
      KEY_BG_SEL = KEY_BG_SEL,
      KEY_BORDER = KEY_BORDER,
      KEY_BORDER_SEL = KEY_BORDER_SEL,
      KEY_CHAR_W = KEY_CHAR_W,
      KEYBOARD_ROWS = KEYBOARD_ROWS,
      KEYBOARD_ROWS_SHIFTED = KEYBOARD_ROWS_SHIFTED,
      KEYBOARD_ROWS_TITLE_ID = KEYBOARD_ROWS_TITLE_ID,
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
    elseif state == "editor" then
      syncToS(c)
      scene_editor.run(c)
      syncFromS(c)
    elseif state == "choose_save" then
      syncToS(c)
      scene_choose_save.run(c)
      syncFromS(c)
    elseif state == "color_edit" then
      syncToS(c)
      scene_color_edit.run(c)
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
    elseif state == "text_input" then
      syncToS(c)
      scene_text_input.run(c)
      syncFromS(c)
    elseif state == "path_picker" then
      syncToS(c)
      scene_path_picker.run(c)
      syncFromS(c)
    end

    common.drawSaveSplash(c)
    syncFromS(c)

    prevPad = pad
    syncToS(c)
    Screen.flip()
    Screen.waitVblankStart()
    return c.state, c
  end
  local sceneNames = { "main", "choose_mc", "select_config", "initHdd", "open", "choose_load", "editor", "choose_save",
    "color_edit", "menu_entries", "menu_entry_edit", "entry_cdrom_options", "entry_paths", "entry_args", "bbl_hotkeys",
    "bbl_hotkey_entries", "bbl_hotkey_entry", "bbl_hotkey_args", "egsm_editor", "egsm_value_edit", "text_input",
    "path_picker" }
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
    local nextScene, newCtx = scene.run(ctx)
    ctx = newCtx
    currentScene = nextScene
  end
end

return mainLoop()
