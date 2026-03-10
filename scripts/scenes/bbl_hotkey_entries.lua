--[[ Per-hotkey slots (E1..E10): name, path slots, reorder, enable/disable, remove. ]]

local function findFirstFreeSlot(_, ctx, keyId, maxEntries)
  for i = 1, maxEntries do
    local slot = _.config_parse.getBblHotkeySlot(ctx.lines, keyId, i)
    if not slot.used then return i end
  end
  return nil
end

local function buildRows(_, ctx, keyId, maxEntries)
  local rows = {}
  local usedCount = 0
  local nameVal = _.config_parse.getBblHotkeyName(ctx.lines, keyId) or ""
  rows[#rows + 1] = { kind = "name", nameVal = nameVal }
  for i = 1, maxEntries do
    local slot = _.config_parse.getBblHotkeySlot(ctx.lines, keyId, i)
    if slot.used then
      rows[#rows + 1] = { kind = "entry", slot = i, data = slot }
      usedCount = usedCount + 1
    end
  end
  if usedCount < maxEntries then
    rows[#rows + 1] = { kind = "add" }
  end
  return rows
end

local function formatArgCount(n)
  local count = tonumber(n) or 0
  if count == 1 then
    return "(1 arg)"
  end
  return "(" .. tostring(count) .. " args)"
end

local function run(ctx)
  local _ = ctx._
  if not ctx.lines then
    ctx.state = "editor"
    return
  end
  local keyId = ctx.bblHotkeyKey
  if not keyId or keyId == "" then
    ctx.state = "bbl_hotkeys"
    return
  end

  local maxEntries = (_.config_parse.getBblMaxEntries and _.config_parse.getBblMaxEntries()) or 10
  local rows = buildRows(_, ctx, keyId, maxEntries)
  if #rows == 0 then
    ctx.state = "bbl_hotkeys"
    return
  end

  if ctx.bblEntryFocusSlot then
    for i, row in ipairs(rows) do
      if row.kind == "entry" and row.slot == ctx.bblEntryFocusSlot then
        ctx.bblEntrySel = i
        break
      end
    end
    ctx.bblEntryFocusSlot = nil
  end

  ctx.bblEntrySel = ctx.bblEntrySel or 1
  if ctx.bblEntrySel < 1 then ctx.bblEntrySel = 1 end
  if ctx.bblEntrySel > #rows then ctx.bblEntrySel = #rows end
  ctx.bblEntryScroll = ctx.bblEntryScroll or 0

  if #rows > _.MAX_VISIBLE_LIST then
    ctx.bblEntryScroll = ctx.bblEntrySel - math.floor(_.MAX_VISIBLE_LIST / 2)
    ctx.bblEntryScroll = math.max(0, math.min(ctx.bblEntryScroll, #rows - _.MAX_VISIBLE_LIST))
  else
    ctx.bblEntryScroll = 0
  end

  local titleSuffix = "- Launch Key"
  if keyId == "AUTO" then
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1, "AUTOBOOT " .. titleSuffix, _.WHITE)
  else
    local icon = _.common.getPadIcon(keyId)
    local baseIconW = _.common.PAD_ICON_W or 26
    local baseIconH = _.common.PAD_ICON_H or 26
    local textH = (_.common and _.common.FT_PIXEL_H) or 18
    local iconH = math.min(baseIconH, textH)
    local iconW = math.max(1, math.floor((baseIconW * iconH) / baseIconH + 0.5))
    local iconGap = 8
    local iconY = _.MARGIN_Y + math.floor(((_.LINE_H or iconH) - iconH) / 2)
    if _.Graphics.drawScaleImage then
      _.Graphics.drawScaleImage(icon, _.MARGIN_X, iconY, iconW, iconH)
    else
      _.Graphics.drawImage(icon, _.MARGIN_X, iconY)
    end
    _.drawText(_.font, _.drawMode, _.MARGIN_X + iconW + iconGap, _.MARGIN_Y, 1, titleSuffix, _.WHITE)
  end
  local maxLabelW = (_.w or 640) - (_.MARGIN_X + 24) - _.MARGIN_X

  for i = ctx.bblEntryScroll + 1, math.min(ctx.bblEntryScroll + _.MAX_VISIBLE_LIST, #rows) do
    local row = rows[i]
    local y = _.MARGIN_Y + _.scaleY(50) + (i - ctx.bblEntryScroll - 1) * _.LINE_H
    local col = (i == ctx.bblEntrySel) and _.SELECTED_ENTRY or _.WHITE
    local text = ""
    if row.kind == "name" then
      local disp = (row.nameVal ~= "" and row.nameVal) or _.common_str.empty
      text = (_.menu_str.name or "Name: ") .. disp
    elseif row.kind == "entry" then
      local slot = row.data
      local p = (slot.path ~= "" and slot.path) or _.common_str.not_set
      text = "E" .. tostring(row.slot) .. ": " .. p .. " " .. formatArgCount(slot.argCount)
      if slot.disabled then
        col = (i == ctx.bblEntrySel) and (_.SELECTED_ENTRY_DIM or _.SELECTED_ENTRY) or (_.DIM_ENTRY or _.DIM)
      end
    else
      text = (_.menu_str.add_entry_label or "Add") .. " path"
    end
    if _.common.fitListRowText then
      text = _.common.fitListRowText(ctx, "bbl_hotkey_entries_row_" .. tostring(i), _.font, text, maxLabelW,
        _.FONT_SCALE, i == ctx.bblEntrySel)
    elseif _.common.truncateTextToWidth then
      text = _.common.truncateTextToWidth(_.font, text, maxLabelW, _.FONT_SCALE)
    end
    _.drawListRow(_.MARGIN_X + 20, y, i == ctx.bblEntrySel, text, col)
  end

  local sel = rows[ctx.bblEntrySel]
  local hint = _.menu_str.cross_select_circle_back_items or
      { { pad = "cross", label = "Enter" }, { pad = "circle", label = "Back" } }
  if sel and sel.kind == "entry" then
    hint = sel.data.disabled and (_.menu_str.paths_hint_items_with_enable or _.menu_str.paths_hint_items) or
        (_.menu_str.paths_hint_items_with_disable or _.menu_str.paths_hint_items)
  end
  _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, hint, nil, _.DIM, _.w - 2 * _.MARGIN_X)

  if (_.padEffective & _.PAD_UP) ~= 0 then
    ctx.bblEntrySel = ctx.bblEntrySel - 1
    if ctx.bblEntrySel < 1 then ctx.bblEntrySel = #rows end
  end
  if (_.padEffective & _.PAD_DOWN) ~= 0 then
    ctx.bblEntrySel = ctx.bblEntrySel + 1
    if ctx.bblEntrySel > #rows then ctx.bblEntrySel = 1 end
  end

  if (_.padEffective & _.PAD_CROSS) ~= 0 then
    if sel.kind == "name" then
      local currentName = _.config_parse.getBblHotkeyName(ctx.lines, keyId) or ""
      ctx.textInputTitleIdMode = nil
      ctx.textInputPrompt = "NAME_" .. keyId
      ctx.textInputValue = currentName
      ctx.textInputMaxLen = 64
      ctx.textInputCallback = function(val)
        _.config_parse.setBblHotkeyName(ctx.lines, keyId, val or "")
        ctx.configModified = true
        ctx.state = "bbl_hotkey_entries"
      end
      ctx.textInputReturnState = "bbl_hotkey_entries"
      ctx.textInputGridSel = 1
      ctx.textInputCursor = #ctx.textInputValue + 1
      ctx.textInputScroll = 1
      ctx.state = "text_input"
    elseif sel.kind == "entry" then
      ctx.bblEntrySlot = sel.slot
      ctx.bblEntryDetailSel = ctx.bblEntryDetailSel or 1
      ctx.bblEntryDetailReturnState = "bbl_hotkey_entries"
      ctx.state = "bbl_hotkey_entry"
    elseif sel.kind == "add" then
      local freeSlot = findFirstFreeSlot(_, ctx, keyId, maxEntries)
      if freeSlot then
        ctx.bblEntrySlot = freeSlot
        ctx.bblEntryDetailSel = ctx.bblEntryDetailSel or 1
        ctx.bblEntryDetailReturnState = "bbl_hotkey_entries"
        ctx.state = "bbl_hotkey_entry"
      end
    end
  end

  if sel and sel.kind == "entry" and (_.padEffective & _.PAD_TRIANGLE) ~= 0 then
    if sel.data.pathExists then
      _.config_parse.setBblHotkeyPathDisabled(ctx.lines, keyId, sel.slot, not sel.data.disabled)
      ctx.configModified = true
    end
  end
  if sel and sel.kind == "entry" and (_.padEffective & _.PAD_SQUARE) ~= 0 then
    _.config_parse.removeBblHotkeySlot(ctx.lines, keyId, sel.slot)
    ctx.configModified = true
  end
  if sel and sel.kind == "entry" and (_.padEffective & _.PAD_L1) ~= 0 then
    if sel.slot > 1 then
      _.config_parse.swapBblHotkeySlots(ctx.lines, keyId, sel.slot, sel.slot - 1)
      ctx.configModified = true
      ctx.bblEntryFocusSlot = sel.slot - 1
    end
  end
  if sel and sel.kind == "entry" and (_.padEffective & _.PAD_R1) ~= 0 then
    if sel.slot < maxEntries then
      _.config_parse.swapBblHotkeySlots(ctx.lines, keyId, sel.slot, sel.slot + 1)
      ctx.configModified = true
      ctx.bblEntryFocusSlot = sel.slot + 1
    end
  end

  if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
    ctx.state = "bbl_hotkeys"
    ctx.bblEntryDetailReturnState = nil
  end
end

return { run = run }
