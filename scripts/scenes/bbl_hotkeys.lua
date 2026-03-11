--[[ PS2BBL/PSXBBL hotkey list (16 buttons, AUTO handled separately). ]]

local function run(ctx)
  local _ = ctx._
  if not ctx.lines then
    ctx.state = "editor"
    return
  end

  local hotkeys = (_.config_options.getBblHotkeys and _.config_options.getBblHotkeys()) or
      (_.config_parse.getBblHotkeys and _.config_parse.getBblHotkeys()) or {}
  if #hotkeys == 0 then
    ctx.state = "editor"
    return
  end

  local title = "Launch Keys"
  local isFmcb = (ctx.fileType == "freemcboot_cnf")
  _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1, title, _.WHITE)

  ctx.bblHotkeySel = ctx.bblHotkeySel or 1
  if ctx.bblHotkeySel < 1 then ctx.bblHotkeySel = 1 end
  if ctx.bblHotkeySel > #hotkeys then ctx.bblHotkeySel = #hotkeys end
  ctx.bblHotkeyScroll = ctx.bblHotkeyScroll or 0

  if #hotkeys > _.MAX_VISIBLE_LIST then
    ctx.bblHotkeyScroll = ctx.bblHotkeySel - math.floor(_.MAX_VISIBLE_LIST / 2)
    ctx.bblHotkeyScroll = math.max(0, math.min(ctx.bblHotkeyScroll, #hotkeys - _.MAX_VISIBLE_LIST))
  else
    ctx.bblHotkeyScroll = 0
  end

  local rowX = _.MARGIN_X + 20
  local maxLabelW = (_.w or 640) - (rowX + 4) - _.MARGIN_X
  local baseIconW = _.common.PAD_ICON_W or 26
  local baseIconH = _.common.PAD_ICON_H or 26
  local textH = (_.common and _.common.FT_PIXEL_H) or 18
  local iconH = math.min(baseIconH, textH)
  local iconW = math.max(1, math.floor((baseIconW * iconH) / baseIconH + 0.5))
  local iconGap = 8
  for i = ctx.bblHotkeyScroll + 1, math.min(ctx.bblHotkeyScroll + _.MAX_VISIBLE_LIST, #hotkeys) do
    local keyId = hotkeys[i]
    local keyIcon = _.common.getPadIcon(keyId)
    local nameVal = _.config_parse.getBblHotkeyName(ctx.lines, keyId) or ""
    local disp = isFmcb and tostring(keyId or "") or ((nameVal ~= "" and nameVal) or _.common_str.empty)
    local line = disp
    local lineMaxW = maxLabelW - iconW - iconGap
    if _.common.truncateTextToWidth then
      line = _.common.truncateTextToWidth(_.font, line, lineMaxW, _.FONT_SCALE)
    end
    local y = _.MARGIN_Y + _.scaleY(50) + (i - ctx.bblHotkeyScroll - 1) * _.LINE_H
    local col = (i == ctx.bblHotkeySel) and _.SELECTED_ENTRY or _.WHITE
    local iconY = y + math.floor(((_.LINE_H or iconH) - iconH) / 2)
    if _.Graphics.drawScaleImage then
      _.Graphics.drawScaleImage(keyIcon, rowX, iconY, iconW, iconH)
    else
      _.Graphics.drawImage(keyIcon, rowX, iconY)
    end
    _.drawText(_.font, _.drawMode, rowX + iconW + iconGap, y, _.FONT_SCALE, line, col)
  end

  _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7,
    _.menu_str.cross_select_circle_back_items or { { pad = "cross", label = "Enter" }, { pad = "circle", label = "Back" } },
    nil, _.DIM, _.w - 2 * _.MARGIN_X)

  if (_.padEffective & _.PAD_UP) ~= 0 then
    ctx.bblHotkeySel = ctx.bblHotkeySel - 1
    if ctx.bblHotkeySel < 1 then ctx.bblHotkeySel = #hotkeys end
  end
  if (_.padEffective & _.PAD_DOWN) ~= 0 then
    ctx.bblHotkeySel = ctx.bblHotkeySel + 1
    if ctx.bblHotkeySel > #hotkeys then ctx.bblHotkeySel = 1 end
  end
  if (_.padEffective & _.PAD_CROSS) ~= 0 then
    ctx.bblHotkeyKey = hotkeys[ctx.bblHotkeySel]
    ctx.bblEntrySel = ctx.bblEntrySel or 1
    ctx.bblEntryScroll = ctx.bblEntryScroll or 0
    ctx.bblEntryFocusSlot = nil
    ctx.state = "bbl_hotkey_entries"
  end
  if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
    ctx.state = "editor"
  end
end

return { run = run }
