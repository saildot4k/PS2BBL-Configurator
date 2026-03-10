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

  local title = "HOTKEYS"
  _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1, title, _.WHITE)

  ctx.bblHotkeySel = ctx.bblHotkeySel or 1
  if ctx.bblHotkeySel < 1 then ctx.bblHotkeySel = 1 end
  if ctx.bblHotkeySel > #hotkeys then ctx.bblHotkeySel = #hotkeys end
  ctx.bblHotkeyScroll = ctx.bblHotkeyScroll or 0

  if #hotkeys > _.MAX_VISIBLE_LIST then
    if ctx.bblHotkeySel > ctx.bblHotkeyScroll + _.MAX_VISIBLE_LIST then
      ctx.bblHotkeyScroll = ctx.bblHotkeySel - _.MAX_VISIBLE_LIST
    end
    if ctx.bblHotkeySel < ctx.bblHotkeyScroll + 1 then
      ctx.bblHotkeyScroll = ctx.bblHotkeySel - 1
    end
  else
    ctx.bblHotkeyScroll = 0
  end

  local maxLabelW = (_.w or 640) - (_.MARGIN_X + 24) - _.MARGIN_X
  for i = ctx.bblHotkeyScroll + 1, math.min(ctx.bblHotkeyScroll + _.MAX_VISIBLE_LIST, #hotkeys) do
    local keyId = hotkeys[i]
    local nameVal = _.config_parse.getBblHotkeyName(ctx.lines, keyId) or ""
    local disp = (nameVal ~= "" and nameVal) or _.common_str.empty
    local line = keyId .. ": " .. disp
    if _.common.truncateTextToWidth then
      line = _.common.truncateTextToWidth(_.font, line, maxLabelW, _.FONT_SCALE)
    end
    local y = _.MARGIN_Y + _.scaleY(50) + (i - ctx.bblHotkeyScroll - 1) * _.LINE_H
    local col = (i == ctx.bblHotkeySel) and _.SELECTED_ENTRY or _.WHITE
    _.drawListRow(_.MARGIN_X + 20, y, i == ctx.bblHotkeySel, line, col)
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
    ctx.bblEntryReturnState = nil
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
