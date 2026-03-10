--[[ Per-slot editor for one BBL hotkey entry (path + args). ]]

local function run(ctx)
  local _ = ctx._
  if not ctx.lines then
    ctx.state = "editor"
    return
  end
  local keyId = ctx.bblHotkeyKey
  local slot = tonumber(ctx.bblEntrySlot)
  if not keyId or not slot then
    ctx.state = "bbl_hotkey_entries"
    return
  end

  local maxArgs = (_.config_parse.getBblMaxArgsPerEntry and _.config_parse.getBblMaxArgsPerEntry()) or 8
  local data = _.config_parse.getBblHotkeySlot(ctx.lines, keyId, slot)
  local rows = { "path", "args" }
  ctx.bblEntryDetailSel = ctx.bblEntryDetailSel or 1
  if ctx.bblEntryDetailSel < 1 then ctx.bblEntryDetailSel = 1 end
  if ctx.bblEntryDetailSel > #rows then ctx.bblEntryDetailSel = #rows end

  local title = keyId .. " - E" .. tostring(slot)
  _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1, title, _.WHITE)

  local pathDisp = (data.path ~= "" and data.path) or _.common_str.not_set
  local pathLine = "Path: " .. pathDisp
  local argsLine = "Arguments: " .. tostring(data.argCount) .. "/" .. tostring(maxArgs)
  local maxLabelW = (_.w or 640) - (_.MARGIN_X + 24) - _.MARGIN_X
  if _.common.truncateTextToWidth then
    pathLine = _.common.truncateTextToWidth(_.font, pathLine, maxLabelW, _.FONT_SCALE)
    argsLine = _.common.truncateTextToWidth(_.font, argsLine, maxLabelW, _.FONT_SCALE)
  end

  for i = 1, #rows do
    local y = _.MARGIN_Y + _.scaleY(50) + (i - 1) * _.LINE_H
    local col = (i == ctx.bblEntryDetailSel) and _.SELECTED_ENTRY or _.WHITE
    local line = (i == 1) and pathLine or argsLine
    if i == 1 and data.disabled then
      col = (i == ctx.bblEntryDetailSel) and (_.SELECTED_ENTRY_DIM or _.SELECTED_ENTRY) or (_.DIM_ENTRY or _.DIM)
    end
    _.drawListRow(_.MARGIN_X + 20, y, i == ctx.bblEntryDetailSel, line, col)
  end

  local hint
  if rows[ctx.bblEntryDetailSel] == "path" then
    hint = {
      { pad = "cross", label = "Edit", row = 1 },
      { pad = "triangle", label = data.disabled and "Enable" or "Disable", row = 1 },
      { pad = "square", label = "Remove", row = 1 },
      { pad = "circle", label = "Back", row = 1 },
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
      local currentPath, currentDisabled = _.config_parse.getBblHotkeyPath(ctx.lines, keyId, slot)
      ctx.textInputTitleIdMode = nil
      ctx.textInputPrompt = "LK_" .. keyId .. "_E" .. tostring(slot)
      ctx.textInputValue = currentPath or ""
      ctx.textInputMaxLen = 255
      ctx.textInputCallback = function(val)
        _.config_parse.setBblHotkeyPath(ctx.lines, keyId, slot, val or "", currentDisabled and true or false)
        ctx.configModified = true
        ctx.state = "bbl_hotkey_entry"
      end
      ctx.textInputReturnState = "bbl_hotkey_entry"
      ctx.textInputGridSel = 1
      ctx.textInputCursor = #ctx.textInputValue + 1
      ctx.textInputScroll = 1
      ctx.state = "text_input"
    else
      ctx.bblArgSel = 1
      ctx.bblArgScroll = 0
      ctx.state = "bbl_hotkey_args"
    end
  end

  if rows[ctx.bblEntryDetailSel] == "path" and (_.padEffective & _.PAD_TRIANGLE) ~= 0 then
    if data.pathExists then
      _.config_parse.setBblHotkeyPathDisabled(ctx.lines, keyId, slot, not data.disabled)
      ctx.configModified = true
    end
  end
  if rows[ctx.bblEntryDetailSel] == "path" and (_.padEffective & _.PAD_SQUARE) ~= 0 then
    _.config_parse.removeBblHotkeySlot(ctx.lines, keyId, slot)
    ctx.configModified = true
    ctx.state = "bbl_hotkey_entries"
  end

  if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
    ctx.state = "bbl_hotkey_entries"
  end
end

return { run = run }
