--[[ Menu entries list (OSDMENU). ]]

local function run(ctx)
  local _ = ctx._
  if not ctx.lines then
    ctx.state = "editor"; return
  end
  ctx.entryList = _.config_parse.getMenuEntryIndices(ctx.lines)
  local startY = _.MARGIN_Y + _.scaleY(50)
  local numEntries = #ctx.entryList
  local total = numEntries
  local isFmcb = (ctx.fileType == "freemcboot_cnf")
  local maxEntries = (isFmcb and ((_.config_options and _.config_options.FMCB_MAX_ENTRIES) or 99)) or nil
  local canAddEntry = (not isFmcb) or (numEntries < maxEntries)
  local counterStr = (numEntries == 0 and "0 / 0") or (tostring(ctx.entrySel) .. " / " .. tostring(numEntries))
  _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1, _.menu_str.edit_menu_entries, _.WHITE)
  _.drawText(_.font, _.drawMode, 540, _.MARGIN_Y, 0.9, counterStr, _.DIM)
  if ctx.entrySel < 1 then ctx.entrySel = 1 end
  if total > 0 and ctx.entrySel > total then ctx.entrySel = total end
  local maxVis = _.MAX_VISIBLE_LIST
  if total > maxVis then
    ctx.entryScroll = ctx.entrySel - math.floor(maxVis / 2)
    ctx.entryScroll = math.max(0, math.min(ctx.entryScroll, total - maxVis))
  else
    ctx.entryScroll = 0
  end
  local maxLabelW = (_.w or 640) - (_.MARGIN_X + 20) - _.MARGIN_X
  for i = ctx.entryScroll + 1, math.min(ctx.entryScroll + maxVis, total) do
    local ent = ctx.entryList[i]
    local idx = ent.idx
    local name = _.config_parse.getMenuEntryName(ctx.lines, idx)
    local label = (name == "" or not name) and _.common_str.empty or (name or (_.menu_str.item .. idx))
    local y = startY + (i - ctx.entryScroll - 1) * _.LINE_H
    local col = (i == ctx.entrySel) and _.SELECTED_ENTRY or _.WHITE
    if label == _.common_str.empty then col = (i == ctx.entrySel) and _.SELECTED_ENTRY or _.DIM end
    if ent.disabled then
      col = (i == ctx.entrySel) and (_.SELECTED_ENTRY_DIM or _.SELECTED_ENTRY) or
          (_.DIM_ENTRY or _.DIM)
    end
    if _.common.fitListRowText then
      label = _.common.fitListRowText(ctx, "menu_entries_row_" .. tostring(i), _.font, label, maxLabelW, _.FONT_SCALE,
        i == ctx.entrySel)
    elseif _.common.truncateTextToWidth then
      label = _.common.truncateTextToWidth(_.font, label, maxLabelW, _.FONT_SCALE)
    end
    _.drawListRow(_.MARGIN_X + 20, y, i == ctx.entrySel, label, col)
  end
  if (_.padEffective & _.PAD_UP) ~= 0 then
    ctx.entrySel = ctx.entrySel - 1; if ctx.entrySel < 1 then ctx.entrySel = total end
  end
  if (_.padEffective & _.PAD_DOWN) ~= 0 then
    ctx.entrySel = ctx.entrySel + 1; if ctx.entrySel > total then ctx.entrySel = 1 end
  end
  if (_.padEffective & _.PAD_LEFT) ~= 0 then
    ctx.entrySel = math.max(1, ctx.entrySel - maxVis)
  end
  if (_.padEffective & _.PAD_RIGHT) ~= 0 then
    ctx.entrySel = math.min(total, ctx.entrySel + maxVis)
  end
  if (_.padEffective & _.PAD_SELECT) ~= 0 and canAddEntry then
    local belowIdx = (total == 0) and 0 or ctx.entryList[ctx.entrySel].idx
    local newIdx = _.config_parse.insertMenuEntryBelow(ctx.lines, belowIdx, "")
    ctx.configModified = true
    ctx.entryList = _.config_parse.getMenuEntryIndices(ctx.lines)
    ctx.entrySel = (total == 0) and 1 or (ctx.entrySel + 1)
    ctx.entryIdx = newIdx
    ctx.entryEditSub = ctx.entryEditSub or 1
    ctx.state = "menu_entry_edit"
  end
  if (_.padEffective & _.PAD_TRIANGLE) ~= 0 then
    if ctx.entrySel >= 1 and ctx.entrySel <= #ctx.entryList then
      local ent = ctx.entryList[ctx.entrySel]
      _.config_parse.setMenuEntryDisabled(ctx.lines, ent.idx, not ent.disabled)
      ctx.configModified = true
      ctx.entryList = _.config_parse.getMenuEntryIndices(ctx.lines)
    end
  end
  if (_.padEffective & _.PAD_L1) ~= 0 then
    if ctx.entrySel >= 1 and #ctx.entryList >= 2 and ctx.entrySel >= 2 then
      local curIdx = ctx.entryList[ctx.entrySel].idx
      local prevIdx = ctx.entryList[ctx.entrySel - 1].idx
      if _.config_parse.swapMenuEntryContent(ctx.lines, curIdx, prevIdx) then
        ctx.configModified = true
        ctx.entryList = _.config_parse.getMenuEntryIndices(ctx.lines)
        ctx.entrySel = ctx.entrySel - 1
      end
    end
  end
  if (_.padEffective & _.PAD_R1) ~= 0 then
    if ctx.entrySel >= 1 and ctx.entrySel <= #ctx.entryList - 1 then
      local curIdx = ctx.entryList[ctx.entrySel].idx
      local nextIdx = ctx.entryList[ctx.entrySel + 1].idx
      if _.config_parse.swapMenuEntryContent(ctx.lines, curIdx, nextIdx) then
        ctx.configModified = true
        ctx.entryList = _.config_parse.getMenuEntryIndices(ctx.lines)
        ctx.entrySel = ctx.entrySel + 1
      end
    end
  end
  if (_.padEffective & _.PAD_CROSS) ~= 0 then
    if total > 0 and ctx.entrySel >= 1 and ctx.entrySel <= #ctx.entryList then
      ctx.entryIdx = ctx.entryList[ctx.entrySel].idx
      ctx.entryEditSub = ctx.entryEditSub or 1
      ctx.state = "menu_entry_edit"
    end
  end
  if (_.padEffective & _.PAD_SQUARE) ~= 0 then
    if ctx.entrySel >= 1 and ctx.entrySel <= #ctx.entryList then
      local idx = ctx.entryList[ctx.entrySel].idx
      _.config_parse.removeMenuEntry(ctx.lines, idx)
      ctx.configModified = true
      ctx.entryList = _.config_parse.getMenuEntryIndices(ctx.lines)
      if ctx.entrySel > #ctx.entryList then ctx.entrySel = #ctx.entryList end
      if ctx.entrySel < 1 then ctx.entrySel = 1 end
    end
  end
  local hints = _.menu_str.hint_items
  if ctx.entrySel >= 1 and ctx.entrySel <= #ctx.entryList then
    hints = ctx.entryList[ctx.entrySel].disabled and (_.menu_str.hint_items_with_enable or hints)
        or (_.menu_str.hint_items_with_disable or hints)
  end
  if not canAddEntry then
    local filtered = {}
    for _, item in ipairs(hints or {}) do
      if item.pad ~= "select" then
        filtered[#filtered + 1] = item
      end
    end
    hints = filtered
  end
  local pageStr = tostring(maxVis)
  local hintsAdjusted = {}
  for _, item in ipairs(hints) do
    local label = item.label
    if item.pad == "left" then
      label = "-" .. pageStr
    elseif item.pad == "right" then
      label = "+" .. pageStr
    end
    hintsAdjusted[#hintsAdjusted + 1] = { pad = item.pad, label = label, row = item.row }
  end
  _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, hintsAdjusted, nil, _.DIM,
    _.w - 2 * _.MARGIN_X)
  if (_.padEffective & _.PAD_START) ~= 0 then
    ctx.saveSplash = nil
    local locations = _.getLocations(ctx.context, ctx.fileType, ctx.chosenMcSlot)
    if ctx.fileType == "osdmenu_cnf" and #locations >= 2 then
      ctx.saveChoices = locations
      ctx.saveSel = ctx.saveSel or 1
      ctx.returnToMenuEntriesAfterSave = true
      ctx.state = "choose_save"
    else
      local path = ctx.currentPath or (locations and locations[1])
      if path and path ~= "" then
        ctx.lines = _.config_parse.regenerateForSave(ctx.lines, ctx.fileType, _.config_options)
        local parentDir = path:match("^(.+)/[^/]+$")
        local ok, err = _.common.saveConfig(ctx, path, ctx.lines, parentDir)
        if ok then
          ctx.currentPath = path
          ctx.saveSplash = { kind = "saved", detail = path or "", framesLeft = 60 }
          ctx.configModified = false
        else
          ctx.saveSplash = {
            kind = "failed",
            detail = _.common.localizeParseError(err, _.editor_str) or
                _.editor_str.save_failed,
            framesLeft = 60
          }
        end
      else
        ctx.saveSplash = { kind = "failed", detail = _.editor_str.no_save_location, framesLeft = 60 }
      end
    end
  end
  if (_.padEffective & _.PAD_CIRCLE) ~= 0 then ctx.state = "editor" end
end

return { run = run }
