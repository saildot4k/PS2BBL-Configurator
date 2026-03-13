--[[ PS2BBL/PSXBBL LOAD_IRX_E# editor. ]]

local function beginIrxPathEdit(_, ctx, entryIdx, disabled)
  ctx.editKey = nil
  ctx.isAddPath = false
  ctx.addPathKey = nil
  ctx.pathPickerBootKey = nil
  ctx.pathPickerForEntryIdx = nil
  ctx.pathPickerEditIdx = nil
  ctx.pathPickerBblHotkeyKey = nil
  ctx.pathPickerBblHotkeySlot = nil
  ctx.pathPickerBblHotkeyDisabled = nil
  ctx.pathPickerBblIrxIdx = entryIdx
  ctx.pathPickerBblIrxDisabled = disabled and true or false
  ctx.pathPickerContext = "path_only"
  ctx.pathPickerSub = "device"
  ctx.pathList = _.file_selector.getDevices("path_only") or {}
  ctx.pathPickerSel = 1
  ctx.pathPickerScroll = 0
  ctx.pathBrowsePath = nil
  ctx.pathPickerTarget = nil
  ctx.pathPickerFileExts = { ".irx" }
  ctx.pathPickerReturnState = "bbl_irx_entries"
  ctx.state = "path_picker"
end

local function saveAndStay(ctx, _)
  ctx.saveSplash = nil
  local locations = _.getLocations(ctx.context, ctx.fileType, ctx.chosenMcSlot)
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
        detail = _.common.localizeParseError(err, _.editor_str) or _.editor_str.save_failed,
        framesLeft = 60
      }
    end
  else
    ctx.saveSplash = { kind = "failed", detail = _.editor_str.no_save_location, framesLeft = 60 }
  end
end

local function run(ctx)
  local _ = ctx._
  if not ctx.lines then
    ctx.state = "editor"
    return
  end

  local maxEntries = (_.config_options and _.config_options.BBL_MAX_IRX_ENTRIES) or
      ((_.config_parse.getBblMaxIrxEntries and _.config_parse.getBblMaxIrxEntries()) or 10)
  local entries = _.config_parse.getBblIrxEntryIndices(ctx.lines)
  local total = #entries
  local canAddEntry = total < maxEntries

  ctx.bblIrxSel = ctx.bblIrxSel or 1
  if ctx.bblIrxSel < 1 then ctx.bblIrxSel = 1 end
  if total == 0 then ctx.bblIrxSel = 1 end
  if total > 0 and ctx.bblIrxSel > total then ctx.bblIrxSel = total end

  local counterStr = (total == 0 and "0 / 0") or (tostring(ctx.bblIrxSel) .. " / " .. tostring(total))
  _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1, _.menu_str.edit_irx_entries or "Edit IRX entries", _.WHITE)
  _.drawText(_.font, _.drawMode, 540, _.MARGIN_Y, 0.9, counterStr, _.DIM)

  local startY = _.MARGIN_Y + _.scaleY(50)
  local maxVis = _.MAX_VISIBLE_LIST
  if total > maxVis then
    ctx.bblIrxScroll = ctx.bblIrxSel - math.floor(maxVis / 2)
    ctx.bblIrxScroll = math.max(0, math.min(ctx.bblIrxScroll, total - maxVis))
  else
    ctx.bblIrxScroll = 0
  end

  local maxLabelW = (_.w or 640) - (_.MARGIN_X + 20) - _.MARGIN_X
  for i = ctx.bblIrxScroll + 1, math.min(ctx.bblIrxScroll + maxVis, total) do
    local ent = entries[i]
    local idx = ent.idx
    local value = _.config_parse.getBblIrxEntry(ctx.lines, idx) or ""
    local label = "E" .. tostring(idx) .. ": " .. ((value ~= "" and value) or _.common_str.empty)
    local y = startY + (i - ctx.bblIrxScroll - 1) * _.LINE_H
    local col = (i == ctx.bblIrxSel) and _.SELECTED_ENTRY or _.WHITE
    if value == "" then
      col = (i == ctx.bblIrxSel) and _.SELECTED_ENTRY or _.DIM
    end
    if ent.disabled then
      col = (i == ctx.bblIrxSel) and (_.SELECTED_ENTRY_DIM or _.SELECTED_ENTRY) or (_.DIM_ENTRY or _.DIM)
    end
    if _.common.fitListRowText then
      label = _.common.fitListRowText(ctx, "bbl_irx_row_" .. tostring(i), _.font, label, maxLabelW, _.FONT_SCALE,
        i == ctx.bblIrxSel)
    elseif _.common.truncateTextToWidth then
      label = _.common.truncateTextToWidth(_.font, label, maxLabelW, _.FONT_SCALE)
    end
    _.drawListRow(_.MARGIN_X + 20, y, i == ctx.bblIrxSel, label, col)
  end

  if (_.padEffective & _.PAD_UP) ~= 0 and total > 0 then
    ctx.bblIrxSel = ctx.bblIrxSel - 1
    if ctx.bblIrxSel < 1 then ctx.bblIrxSel = total end
  end
  if (_.padEffective & _.PAD_DOWN) ~= 0 and total > 0 then
    ctx.bblIrxSel = ctx.bblIrxSel + 1
    if ctx.bblIrxSel > total then ctx.bblIrxSel = 1 end
  end

  if (_.padEffective & _.PAD_SELECT) ~= 0 and canAddEntry then
    local belowIdx = (total == 0) and 0 or entries[ctx.bblIrxSel].idx
    local newIdx = _.config_parse.insertBblIrxEntryBelow(ctx.lines, belowIdx, "")
    if newIdx then
      ctx.configModified = true
      ctx.bblIrxSel = (total == 0) and 1 or (ctx.bblIrxSel + 1)
      beginIrxPathEdit(_, ctx, newIdx, false)
      return
    end
  end

  if total > 0 and (_.padEffective & _.PAD_TRIANGLE) ~= 0 then
    local ent = entries[ctx.bblIrxSel]
    _.config_parse.setBblIrxEntryDisabled(ctx.lines, ent.idx, not ent.disabled)
    ctx.configModified = true
  end

  if total > 0 and (_.padEffective & _.PAD_L1) ~= 0 and ctx.bblIrxSel >= 2 then
    local curIdx = entries[ctx.bblIrxSel].idx
    local prevIdx = entries[ctx.bblIrxSel - 1].idx
    if _.config_parse.swapBblIrxEntryContent(ctx.lines, curIdx, prevIdx) then
      ctx.configModified = true
      ctx.bblIrxSel = ctx.bblIrxSel - 1
    end
  end

  if total > 0 and (_.padEffective & _.PAD_R1) ~= 0 and ctx.bblIrxSel <= total - 1 then
    local curIdx = entries[ctx.bblIrxSel].idx
    local nextIdx = entries[ctx.bblIrxSel + 1].idx
    if _.config_parse.swapBblIrxEntryContent(ctx.lines, curIdx, nextIdx) then
      ctx.configModified = true
      ctx.bblIrxSel = ctx.bblIrxSel + 1
    end
  end

  if (_.padEffective & _.PAD_CROSS) ~= 0 and total > 0 then
    local ent = entries[ctx.bblIrxSel]
    beginIrxPathEdit(_, ctx, ent.idx, ent.disabled)
    return
  end

  if (_.padEffective & _.PAD_SQUARE) ~= 0 and total > 0 then
    local idx = entries[ctx.bblIrxSel].idx
    _.config_parse.removeBblIrxEntry(ctx.lines, idx)
    ctx.configModified = true
    if ctx.bblIrxSel > total - 1 then ctx.bblIrxSel = math.max(1, total - 1) end
  end

  local hints = _.menu_str.irx_hint_items_with_disable or _.menu_str.irx_hint_items or {}
  if total > 0 then
    local selected = entries[ctx.bblIrxSel]
    if selected.disabled then
      hints = _.menu_str.irx_hint_items_with_enable or hints
    end
  end
  _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, hints, nil, _.DIM, _.w - 2 * _.MARGIN_X)

  if (_.padEffective & _.PAD_START) ~= 0 then
    saveAndStay(ctx, _)
  end

  if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
    ctx.state = "editor"
  end
end

return { run = run }
