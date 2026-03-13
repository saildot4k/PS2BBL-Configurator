--[[ Per-slot editor for one BBL hotkey entry (path + args). ]]

local function findHintLabel(items, pad, fallback)
  for _, item in ipairs(items or {}) do
    if item.pad == pad and item.label and item.label ~= "" then
      return item.label
    end
  end
  return fallback
end

local function getTextWidth(font, label)
  if not label or label == "" then return 0 end
  if font and Font and Font.ftCalcDimensions then
    local w = Font.ftCalcDimensions(font, label)
    if type(w) == "number" and w > 0 then
      return w
    end
  end
  return #label
end

local function findWidestHintLabel(_, itemsA, itemsB, pad, fallback)
  local labelA = findHintLabel(itemsA, pad, fallback)
  local labelB = findHintLabel(itemsB, pad, fallback)
  if getTextWidth(_.font, labelA) >= getTextWidth(_.font, labelB) then
    return labelA
  end
  return labelB
end

local function run(ctx)
  local _ = ctx._
  if not ctx.lines then
    ctx.state = "editor"
    return
  end
  local keyId = ctx.bblHotkeyKey
  local slot = tonumber(ctx.bblEntrySlot)
  local returnState = ctx.bblEntryDetailReturnState or "bbl_hotkey_entries"
  if not keyId or not slot then
    ctx.bblEntryDetailReturnState = nil
    ctx.state = returnState
    return
  end

  local maxArgs = (_.config_parse.getBblMaxArgsPerEntry and _.config_parse.getBblMaxArgsPerEntry()) or 8
  local data = _.config_parse.getBblHotkeySlot(ctx.lines, keyId, slot)
  local allowArgs = (ctx.fileType ~= "freemcboot_cnf")
  local rows = allowArgs and { "path", "args" } or { "path" }
  ctx.bblEntryDetailSel = ctx.bblEntryDetailSel or 1
  if ctx.bblEntryDetailSel < 1 then ctx.bblEntryDetailSel = 1 end
  if ctx.bblEntryDetailSel > #rows then ctx.bblEntryDetailSel = #rows end

  local displayKey = (keyId == "AUTO") and "AUTOBOOT" or keyId
  local title = displayKey .. " - E" .. tostring(slot)
  _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1, title, _.WHITE)

  local pathDisp = (data.path ~= "" and data.path) or _.common_str.not_set
  local pathLine = "Path: " .. pathDisp
  local argsLine = "Arguments: " .. tostring(data.argCount) .. "/" .. tostring(maxArgs)
  local maxLabelW = (_.w or 640) - (_.MARGIN_X + 24) - _.MARGIN_X

  for i = 1, #rows do
    local y = _.MARGIN_Y + _.scaleY(50) + (i - 1) * _.LINE_H
    local col = (i == ctx.bblEntryDetailSel) and _.SELECTED_ENTRY or _.WHITE
    local line = (rows[i] == "path") and pathLine or argsLine
    if _.common.fitListRowText then
      local key = (rows[i] == "path") and "bbl_hotkey_entry_path" or "bbl_hotkey_entry_args"
      line = _.common.fitListRowText(ctx, key, _.font, line, maxLabelW, _.FONT_SCALE, i == ctx.bblEntryDetailSel)
    elseif _.common.truncateTextToWidth then
      line = _.common.truncateTextToWidth(_.font, line, maxLabelW, _.FONT_SCALE)
    end
    if rows[i] == "path" and data.disabled then
      col = (i == ctx.bblEntryDetailSel) and (_.SELECTED_ENTRY_DIM or _.SELECTED_ENTRY) or (_.DIM_ENTRY or _.DIM)
    end
    _.drawListRow(_.MARGIN_X + 20, y, i == ctx.bblEntryDetailSel, line, col)
  end

  local hint
  if rows[ctx.bblEntryDetailSel] == "path" then
    local enableHint = _.menu_str.paths_hint_items_with_enable or _.menu_str.paths_hint_items
    local disableHint = _.menu_str.paths_hint_items_with_disable or _.menu_str.paths_hint_items
    local baseHint = data.disabled and enableHint or disableHint
    local toggleLayoutLabel = findWidestHintLabel(_, enableHint, disableHint, "triangle",
      data.disabled and "Enable" or "Disable")
    hint = {
      { pad = "cross", label = findHintLabel(baseHint, "cross", "Edit"), row = 1 },
      { pad = "triangle", label = findHintLabel(baseHint, "triangle", data.disabled and "Enable" or "Disable"), layoutLabel = toggleLayoutLabel, row = 1 },
      { pad = "square", label = findHintLabel(baseHint, "square", "Remove"), row = 1 },
      { pad = "circle", label = findHintLabel(baseHint, "circle", "Back"), row = 1 },
    }
  else
    hint = {
      { pad = "cross", label = "Enter", row = 1 },
      { pad = "circle", label = "Back", row = 1 },
    }
  end
  _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, hint, nil, _.DIM, _.w - 2 * _.MARGIN_X)

  if (_.padEffective & _.PAD_UP) ~= 0 then
    ctx.bblEntryDetailSel = ctx.bblEntryDetailSel - 1
    if ctx.bblEntryDetailSel < 1 then ctx.bblEntryDetailSel = #rows end
  end
  if (_.padEffective & _.PAD_DOWN) ~= 0 then
    ctx.bblEntryDetailSel = ctx.bblEntryDetailSel + 1
    if ctx.bblEntryDetailSel > #rows then ctx.bblEntryDetailSel = 1 end
  end

  if (_.padEffective & _.PAD_CROSS) ~= 0 then
    if rows[ctx.bblEntryDetailSel] == "path" then
      -- Reuse path picker so BBL slot paths support both manual input and device browse.
      ctx.editKey = nil
      ctx.pathPickerTarget = nil
      ctx.pathPickerFileExts = nil
      ctx.pathPickerContext = "path_only"
      ctx.pathPickerSub = "device"
      ctx.pathList = _.file_selector.getDevices("path_only") or {}
      ctx.pathPickerSel = ctx.pathPickerSel or 1
      ctx.pathPickerScroll = ctx.pathPickerScroll or 0
      ctx.pathBrowsePath = nil
      ctx.pathPickerBootKey = nil
      ctx.pathPickerForEntryIdx = nil
      ctx.pathPickerEditIdx = nil
      ctx.pathPickerBblIrxIdx = nil
      ctx.pathPickerBblIrxDisabled = nil
      ctx.isAddPath = false
      ctx.addPathKey = nil
      ctx.pathPickerReturnState = "bbl_hotkey_entry"
      ctx.pathPickerBblHotkeyKey = keyId
      ctx.pathPickerBblHotkeySlot = slot
      ctx.pathPickerBblHotkeyDisabled = data.disabled and true or false
      ctx.state = "path_picker"
    elseif allowArgs then
      ctx.bblArgSel = ctx.bblArgSel or 1
      ctx.bblArgScroll = ctx.bblArgScroll or 0
      ctx.state = "bbl_hotkey_args"
    end
  end

  local function toggleSelectedPathDisabled()
    if rows[ctx.bblEntryDetailSel] == "path" and data.pathExists then
      _.config_parse.setBblHotkeyPathDisabled(ctx.lines, keyId, slot, not data.disabled)
      ctx.configModified = true
    end
  end

  if (_.padEffective & _.PAD_TRIANGLE) ~= 0 then
    toggleSelectedPathDisabled()
  end
  if rows[ctx.bblEntryDetailSel] == "path" and (_.padEffective & _.PAD_SQUARE) ~= 0 then
    _.config_parse.removeBblHotkeySlot(ctx.lines, keyId, slot)
    ctx.configModified = true
    ctx.bblEntryDetailReturnState = nil
    ctx.state = returnState
  end

  if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
    ctx.bblEntryDetailReturnState = nil
    ctx.state = returnState
  end
end

return { run = run }
