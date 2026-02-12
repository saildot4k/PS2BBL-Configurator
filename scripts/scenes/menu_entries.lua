--[[ Menu entries list (OSDMENU). ]]

local function run(ctx)
  local _ = ctx._
  if not ctx.lines then
    ctx.state = "editor"; return
  end
  ctx.entryList = _.config_parse.getMenuEntryIndices(ctx.lines)
  local startY = _.MARGIN_Y + _.scaleY(50)
  local numEntries = #ctx.entryList
  local displayIdx = (ctx.entrySel >= 2 and ctx.entrySel - 1) or 0
  local counterStr = (displayIdx == 0 and _.common_str.dash or tostring(displayIdx)) .. " / " .. tostring(numEntries)
  _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1, _.menu_str.edit_menu_entries, _.WHITE)
  _.drawText(_.font, _.drawMode, 540, _.MARGIN_Y, 0.9, counterStr, _.DIM)
  if ctx.entrySel < 1 then ctx.entrySel = 1 end
  local total = 1 + #ctx.entryList
  if ctx.entrySel > total then ctx.entrySel = total end
  if ctx.entrySel > ctx.entryScroll + _.MAX_VISIBLE then ctx.entryScroll = ctx.entrySel - _.MAX_VISIBLE end
  if ctx.entrySel < ctx.entryScroll + 1 then ctx.entryScroll = ctx.entrySel - 1 end
  for i = ctx.entryScroll + 1, math.min(ctx.entryScroll + _.MAX_VISIBLE, total) do
    local y = startY + (i - ctx.entryScroll - 1) * _.LINE_H
    local label
    if i == 1 then
      label = _.menu_str.new_entry
    else
      local ent = ctx.entryList[i - 1]
      local idx = ent.idx
      label = _.config_parse.getMenuEntryName(ctx.lines, idx) or (_.menu_str.item .. idx)
    end
    local col = (i == ctx.entrySel) and _.SELECTED_ENTRY or _.WHITE
    if i >= 2 and ctx.entryList[i - 1].disabled then col = col == _.SELECTED_ENTRY and _.SELECTED_ENTRY or _.DIM end
    _.drawListRow(_.MARGIN_X + 20, y, i == ctx.entrySel, label, col)
  end
  if (_.padEffective & _.PAD_UP) ~= 0 then
    ctx.entrySel = ctx.entrySel - 1; if ctx.entrySel < 1 then ctx.entrySel = total end
  end
  if (_.padEffective & _.PAD_DOWN) ~= 0 then
    ctx.entrySel = ctx.entrySel + 1; if ctx.entrySel > total then ctx.entrySel = 1 end
  end
  if (_.padEffective & _.PAD_LEFT) ~= 0 then
    ctx.entrySel = math.max(1, ctx.entrySel - 10)
  end
  if (_.padEffective & _.PAD_RIGHT) ~= 0 then
    ctx.entrySel = math.min(total, ctx.entrySel + 10)
  end
  if (_.padEffective & _.PAD_TRIANGLE) ~= 0 then
    if ctx.entrySel >= 2 and ctx.entrySel <= #ctx.entryList + 1 then
      local ent = ctx.entryList[ctx.entrySel - 1]
      _.config_parse.setMenuEntryDisabled(ctx.lines, ent.idx, not ent.disabled)
      ctx.configModified = true
      ctx.entryList = _.config_parse.getMenuEntryIndices(ctx.lines)
    end
  end
  if (_.padEffective & _.PAD_L1) ~= 0 then
    if ctx.entrySel >= 2 and #ctx.entryList >= 2 then
      local curIdx = ctx.entryList[ctx.entrySel - 1].idx
      local prevIdx = ctx.entryList[ctx.entrySel - 2].idx
      if _.config_parse.swapMenuEntryContent(ctx.lines, curIdx, prevIdx) then
        ctx.configModified = true
        ctx.entryList = _.config_parse.getMenuEntryIndices(ctx.lines)
        ctx.entrySel = ctx.entrySel - 1
      end
    end
  end
  if (_.padEffective & _.PAD_R1) ~= 0 then
    if ctx.entrySel >= 2 and ctx.entrySel <= #ctx.entryList then
      local curIdx = ctx.entryList[ctx.entrySel - 1].idx
      local nextIdx = ctx.entryList[ctx.entrySel].idx
      if _.config_parse.swapMenuEntryContent(ctx.lines, curIdx, nextIdx) then
        ctx.configModified = true
        ctx.entryList = _.config_parse.getMenuEntryIndices(ctx.lines)
        ctx.entrySel = ctx.entrySel + 1
      end
    end
  end
  if (_.padEffective & _.PAD_CROSS) ~= 0 then
    if ctx.entrySel == 1 then
      local nextIdx = _.config_parse.getFirstUnusedMenuEntryIndex(ctx.lines)
      _.config_parse.addMenuEntry(ctx.lines, nextIdx, _.menu_str.add_entry_label)
      ctx.configModified = true
      ctx.entryList = _.config_parse.getMenuEntryIndices(ctx.lines)
      ctx.entryIdx = nextIdx
      ctx.entryEditSub = 1
      ctx.state = "menu_entry_edit"
    else
      ctx.entryIdx = ctx.entryList[ctx.entrySel - 1].idx
      ctx.entryEditSub = 1
      ctx.state = "menu_entry_edit"
    end
  end
  if (_.padEffective & _.PAD_SQUARE) ~= 0 then
    if ctx.entrySel >= 2 and ctx.entrySel <= #ctx.entryList + 1 then
      local idx = ctx.entryList[ctx.entrySel - 1].idx
      _.config_parse.removeMenuEntry(ctx.lines, idx)
      ctx.configModified = true
      ctx.entryList = _.config_parse.getMenuEntryIndices(ctx.lines)
      if ctx.entrySel > #ctx.entryList + 1 then ctx.entrySel = #ctx.entryList + 1 end
      if ctx.entrySel < 1 then ctx.entrySel = 1 end
    end
  end
  local hints = _.menu_str.hint_items
  if ctx.entrySel >= 2 and ctx.entrySel <= #ctx.entryList + 1 then
    hints = ctx.entryList[ctx.entrySel - 1].disabled and (_.menu_str.hint_items_with_enable or hints)
        or (_.menu_str.hint_items_with_disable or hints)
  end
  _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, hints, nil, _.DIM,
    _.w - 2 * _.MARGIN_X)
  if (_.padEffective & _.PAD_CIRCLE) ~= 0 then ctx.state = "editor" end
end

return { run = run }
