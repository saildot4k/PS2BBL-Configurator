--[[ PS2BBL/PSXBBL LOAD_IRX_E# editor. ]]

local actions_menu = dofile("scripts/scenes/actions_menu.lua")

local function buildIrxEntryValueMap(lines, maxEntries)
  local out = {}
  for i = 1, #(lines or {}) do
    local entry = lines[i]
    local key = entry and entry.key
    if key then
      local idx = key:match("^LOAD_IRX_E(%d+)$")
      if idx then
        local n = tonumber(idx)
        if n and n >= 1 and n <= maxEntries and out[n] == nil then
          out[n] = entry.value or ""
        end
      end
    end
  end
  return out
end

local function buildIrxListCache(_, lines, maxEntries)
  return {
    entries = _.config_parse.getBblIrxEntryIndices(lines),
    values = buildIrxEntryValueMap(lines, maxEntries),
  }
end

local function beginIrxPathEdit(_, ctx, entryIdx, disabled)
  ctx.editKey = nil
  ctx.isAddPath = false
  ctx.addPathKey = nil
  ctx.pathPickerBootKey = nil
  ctx.pathPickerBootKeyDisabled = nil
  ctx.pathPickerForEntryIdx = nil
  ctx.pathPickerEditIdx = nil
  ctx.pathPickerBblHotkeyKey = nil
  ctx.pathPickerBblHotkeySlot = nil
  ctx.pathPickerBblHotkeyDisabled = nil
  ctx.pathPickerBblIrxIdx = entryIdx
  ctx.pathPickerBblIrxDisabled = disabled and true or false
  ctx.pathPickerContext = "path_only"
  ctx.pathPickerSub = "device"
  ctx.pathList = _.file_selector.getDevices("path_only", { fileType = ctx.fileType }) or {}
  ctx.pathPickerSel = 1
  ctx.pathPickerScroll = 0
  ctx.pathBrowsePath = nil
  ctx.pathPickerTarget = nil
  ctx.pathPickerFileExts = { ".irx" }
  ctx.pathPickerReturnState = "bbl_irx_entries"
  ctx.state = "path_picker"
end

local function run(ctx)
  local _ = ctx._
  if not ctx.lines then
    ctx.state = "editor"
    return
  end

  local maxEntries = (_.config_options and _.config_options.BBL_MAX_IRX_ENTRIES) or
      ((_.config_parse.getBblMaxIrxEntries and _.config_parse.getBblMaxIrxEntries()) or 10)
  local sceneEpoch = ctx._sceneEpoch or 0
  local function getIrxListCache()
    local cache = ctx.bblIrxListCache
    if not cache or cache.linesRef ~= ctx.lines or cache.maxEntries ~= maxEntries or cache.sceneEpoch ~= sceneEpoch then
      cache = buildIrxListCache(_, ctx.lines, maxEntries)
      cache.linesRef = ctx.lines
      cache.maxEntries = maxEntries
      cache.sceneEpoch = sceneEpoch
      ctx.bblIrxListCache = cache
    end
    return cache
  end
  local function invalidateIrxListCache()
    ctx.bblIrxListCache = nil
  end
  local irxListCache = getIrxListCache()
  local entries = irxListCache.entries or {}
  local entryValueByIdx = irxListCache.values or {}
  local total = #entries
  local canMoveEntries = total > 1
  local function clearMoveState()
    ctx.bblIrxGrab = nil
    ctx.bblIrxMoveSnapshot = nil
    ctx.bblIrxMoveSel = nil
  end
  local function beginMoveState()
    if ctx.bblIrxGrab then return end
    if _.common and _.common.cloneConfigLines then
      ctx.bblIrxMoveSnapshot = _.common.cloneConfigLines(ctx.lines)
    else
      ctx.bblIrxMoveSnapshot = nil
    end
    ctx.bblIrxMoveSel = ctx.bblIrxSel
    ctx.bblIrxGrab = true
  end
  local function confirmMoveState()
    clearMoveState()
  end
  local function cancelMoveState()
    if ctx.bblIrxMoveSnapshot then
      if _.common and _.common.cloneConfigLines then
        ctx.lines = _.common.cloneConfigLines(ctx.bblIrxMoveSnapshot)
      else
        ctx.lines = ctx.bblIrxMoveSnapshot
      end
      invalidateIrxListCache()
      local restored = (getIrxListCache().entries) or {}
      ctx.bblIrxSel = _.common.clampListSelection(ctx.bblIrxMoveSel or ctx.bblIrxSel, #restored)
      _.common.refreshConfigModified(ctx)
    end
    clearMoveState()
  end
  if not canMoveEntries then
    confirmMoveState()
  end
  local canAddEntry = total < maxEntries

  ctx.bblIrxSel = ctx.bblIrxSel or 1
  if ctx.bblIrxSel < 1 then ctx.bblIrxSel = 1 end
  if total == 0 then ctx.bblIrxSel = 1 end
  if total > 0 and ctx.bblIrxSel > total then ctx.bblIrxSel = total end

  _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1, _.menu_str.edit_irx_entries or "Edit IRX entries", _.WHITE)
  local irxOrderHint = (_.menu_str.irx_order_hint or "IRX entry order matters!")
  local hintTypography = _.common.getHintTypography(_.font, _.drawMode)
  local hintScale = hintTypography.drawScale
  local hintFont = hintTypography.font
  local hintColor = (_.UNSELECTED_COLOR or _.DIM_COLOR or _.WHITE)
  local descMaxW = (_.w or 640) - (_.MARGIN_X * 2)
  local hintRawW = (_.common.calcTextWidth and _.common.calcTextWidth(hintFont, irxOrderHint, hintScale)) or
      (#irxOrderHint * 8)
  local useTicker = hintRawW > descMaxW
  if useTicker then
    if _.common.fitListRowText then
      irxOrderHint = _.common.fitListRowText(ctx, "bbl_irx_order_hint", hintFont, irxOrderHint, descMaxW, hintScale, true,
        { holdStart = 55, stepFrames = 16, holdEnd = 85 })
    elseif _.common.truncateTextToWidth then
      irxOrderHint = _.common.truncateTextToWidth(hintFont, irxOrderHint, descMaxW, hintScale)
    end
  end
  local hintW = (_.common.calcTextWidth and _.common.calcTextWidth(hintFont, irxOrderHint, hintScale)) or (#irxOrderHint * 8)
  local hintX
  if useTicker then
    hintX = _.MARGIN_X
  else
    local startCenterX = _.common.getHintStartCenterX and _.common.getHintStartCenterX(_, (_.w or 640) - (2 * _.MARGIN_X))
    hintX = startCenterX and math.floor(startCenterX - (hintW / 2) + 0.5) or ((_.common.centerX and _.common.centerX(_, hintW)) or _.MARGIN_X)
  end
  _.drawText(hintFont, _.drawMode, hintX, (_.DESC_Y_BOTTOM or (_.HINT_Y - _.scaleY(22))), hintScale, irxOrderHint, hintColor)

  local startY = _.MARGIN_Y + _.scaleY(50)
  local maxVis = _.MAX_VISIBLE_LIST
  if _.common and _.common.computeVisibleRows then
    maxVis = _.common.computeVisibleRows(_, startY, _.LINE_H, maxVis, {
      reserveRows = 1,
      reserveDescription = true,
    })
  end
  if total > maxVis then
    ctx.bblIrxScroll = ctx.bblIrxSel - math.floor(maxVis / 2)
    ctx.bblIrxScroll = math.max(0, math.min(ctx.bblIrxScroll, total - maxVis))
  else
    ctx.bblIrxScroll = 0
  end
  if _.common and _.common.drawListScrollbar then
    _.common.drawListScrollbar(_, {
      totalRows = total,
      visibleRows = maxVis,
      scrollRows = ctx.bblIrxScroll,
      rowTopY = startY,
      rowHeight = _.LINE_H,
      color = _.DIM_COLOR,
    })
  end

  local maxLabelW = (_.w or 640) - (_.MARGIN_X + 20) - _.MARGIN_X
  for i = ctx.bblIrxScroll + 1, math.min(ctx.bblIrxScroll + maxVis, total) do
    local ent = entries[i]
    local idx = ent.idx
    local value = entryValueByIdx[idx] or ""
    local label = "E" .. tostring(idx) .. ": " .. ((value ~= "" and value) or _.common_str.empty)
    local y = startY + (i - ctx.bblIrxScroll - 1) * _.LINE_H
    local col = (i == ctx.bblIrxSel) and _.SELECTED_COLOR or _.UNSELECTED_COLOR
    if value == "" then
      col = (i == ctx.bblIrxSel) and _.SELECTED_COLOR or _.DIM_COLOR
    end
    if ent.disabled then
      col = (i == ctx.bblIrxSel) and (_.SELECTED_DIM_COLOR or _.SELECTED_COLOR) or (_.DISABLED_DIM_COLOR or _.DIM_COLOR)
    end
    if _.common.fitListRowText then
      label = _.common.fitListRowText(ctx, "bbl_irx_row_" .. tostring(i), _.font, label, maxLabelW, _.FONT_SCALE,
        i == ctx.bblIrxSel)
    elseif _.common.truncateTextToWidth then
      label = _.common.truncateTextToWidth(_.font, label, maxLabelW, _.FONT_SCALE)
    end
    if canMoveEntries and ctx.bblIrxGrab and i == ctx.bblIrxSel then
      label = "[" .. (_.menu_str.grabbed_tag or "Move") .. "] " .. label
    end
    _.drawListRow(_.MARGIN_X + 20, y, i == ctx.bblIrxSel, label, col)
  end

  local hasSelection = (total > 0 and ctx.bblIrxSel >= 1 and ctx.bblIrxSel <= total)
  local canCrossEdit = hasSelection or canAddEntry
  local selectedDisabled = hasSelection and entries[ctx.bblIrxSel].disabled
  local hints = {
    {
      pad = canCrossEdit and "cross" or "",
      label = canCrossEdit and
          (ctx.bblIrxGrab and (_.menu_str.confirm_label or "Confirm") or (_.menu_str.edit_label or "Edit")) or "",
      row = 1
    },
    { pad = "square", label = (_.menu_str.actions_label or "Actions"), row = 1 },
    {
      pad = ctx.configModified and "start" or "",
      label = ctx.configModified and (_.menu_str.save_config_label or "Save") or "",
      row = 1
    },
    {
      pad = hasSelection and "triangle" or "",
      label = hasSelection and
          (selectedDisabled and (_.menu_str.enable_label or "Enable") or (_.menu_str.disable_label or "Disable")) or "",
      row = 1
    },
    {
      pad = "circle",
      label = ctx.bblIrxGrab and (_.menu_str.cancel_label or "Cancel") or (_.menu_str.back_label or "Back"),
      row = 1
    },
  }
  _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, hints, nil, _.DIM_COLOR, _.w - 2 * _.MARGIN_X)

  local function addIrxEntry()
    if not canAddEntry then return end
    local belowIdx = (total == 0) and 0 or entries[ctx.bblIrxSel].idx
    local newIdx = _.config_parse.insertBblIrxEntryBelow(ctx.lines, belowIdx, "")
    if newIdx then
      ctx.configModified = true
      invalidateIrxListCache()
      ctx.bblIrxSel = (total == 0) and 1 or (ctx.bblIrxSel + 1)
      confirmMoveState()
      beginIrxPathEdit(_, ctx, newIdx, false)
    end
  end

  local function removeSelectedIrx()
    if not hasSelection then return end
    local idx = entries[ctx.bblIrxSel].idx
    _.config_parse.removeBblIrxEntry(ctx.lines, idx)
    ctx.configModified = true
    invalidateIrxListCache()
    if ctx.bblIrxSel > total - 1 then ctx.bblIrxSel = math.max(1, total - 1) end
    if total - 1 <= 1 then
      confirmMoveState()
    end
  end

  local function moveSelectedIrx(step)
    if not hasSelection then return end
    local dst = ctx.bblIrxSel + step
    if dst < 1 or dst > total then return end
    local curIdx = entries[ctx.bblIrxSel].idx
    local dstIdx = entries[dst].idx
    if _.config_parse.swapBblIrxEntryContent(ctx.lines, curIdx, dstIdx) then
      ctx.configModified = true
      invalidateIrxListCache()
      ctx.bblIrxSel = dst
    end
  end

  if ctx.bblIrxActionsOpen then
    local actionRows = {}
    if hasSelection and canMoveEntries then
      actionRows[#actionRows + 1] = {
        id = "grab",
        label = ctx.bblIrxGrab and (_.menu_str.cancel_move_label or "Cancel move") or
            (_.menu_str.grab_label or "Move"),
      }
    end
    if canAddEntry then
      actionRows[#actionRows + 1] = { id = "insert", label = (_.menu_str.insert_label or "Insert") }
    end
    if hasSelection then
      actionRows[#actionRows + 1] = { id = "remove", label = (_.menu_str.remove_label or "Remove") }
    end
    if actions_menu.run(ctx, {
          openKey = "bblIrxActionsOpen",
          selKey = "bblIrxActionsSel",
          scrollKey = "bblIrxActionsScroll",
          title = (_.menu_str.actions_title or "Actions"),
          rows = actionRows,
          rowStateKeyPrefix = "bbl_irx_actions_row_",
          onSelect = function(row)
            if row.id == "grab" then
              if ctx.bblIrxGrab then
                cancelMoveState()
              else
                beginMoveState()
              end
            elseif row.id == "insert" then
              addIrxEntry()
            elseif row.id == "remove" then
              removeSelectedIrx()
            end
          end,
        }) then
      return
    end
  end

  if (_.padEffective & _.PAD_UP) ~= 0 and total > 0 then
    if ctx.bblIrxGrab then
      moveSelectedIrx(-1)
    else
      ctx.bblIrxSel = _.common.moveListSelection(ctx.bblIrxSel, total, -1, { ctx = ctx })
    end
  end
  if (_.padEffective & _.PAD_DOWN) ~= 0 and total > 0 then
    if ctx.bblIrxGrab then
      moveSelectedIrx(1)
    else
      ctx.bblIrxSel = _.common.moveListSelection(ctx.bblIrxSel, total, 1, { ctx = ctx })
    end
  end

  local function toggleSelectedIrxDisabled()
    if total > 0 then
      local ent = entries[ctx.bblIrxSel]
      _.config_parse.setBblIrxEntryDisabled(ctx.lines, ent.idx, not ent.disabled)
      ctx.configModified = true
      invalidateIrxListCache()
    end
  end

  if (_.padEffective & _.PAD_TRIANGLE) ~= 0 then
    toggleSelectedIrxDisabled()
  end

  if (_.padEffective & _.PAD_CROSS) ~= 0 and total > 0 then
    if ctx.bblIrxGrab then
      confirmMoveState()
      return
    end
    local ent = entries[ctx.bblIrxSel]
    beginIrxPathEdit(_, ctx, ent.idx, ent.disabled)
    return
  end

  if (_.padEffective & _.PAD_CROSS) ~= 0 and total == 0 and canAddEntry then
    addIrxEntry()
    return
  end

  if (_.padEffective & _.PAD_SQUARE) ~= 0 then
    _.common.openActionsMenu(ctx, "bblIrxActionsOpen", "bblIrxActionsSel", "bblIrxActionsScroll")
  end

  if ctx.configModified and (_.padEffective & _.PAD_START) ~= 0 then
    _.common.saveCurrentConfig(ctx, {
      beforeSave = function()
        ctx.bblIrxListCache = nil
      end,
    })
  end

  if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
    if ctx.bblIrxGrab then
      cancelMoveState()
      return
    end
    ctx.state = "editor"
  end
end

return { run = run }
