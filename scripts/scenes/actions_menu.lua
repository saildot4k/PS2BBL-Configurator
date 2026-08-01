--[[ Shared anchored actions menu (Square by default; configurable anchor). ]]

local actions_menu = {}

local function copyHintItem(src)
  if type(src) ~= "table" then return nil end
  local out = {}
  for k, v in pairs(src) do
    out[k] = v
  end
  return out
end

local function normalizePadName(pad)
  local p = tostring(pad or ""):lower()
  if p == "l1" or p == "l2" or p == "l3" or p == "r1" or p == "r2" or p == "r3" then
    return p:upper()
  end
  return p
end

local function padMaskForName(_, pad)
  local p = normalizePadName(pad)
  if p == "cross" then return _.PAD_CROSS end
  if p == "circle" then return _.PAD_CIRCLE end
  if p == "triangle" then return _.PAD_TRIANGLE end
  if p == "square" then return _.PAD_SQUARE end
  if p == "start" then return _.PAD_START end
  if p == "select" then return _.PAD_SELECT end
  if p == "up" then return _.PAD_UP end
  if p == "down" then return _.PAD_DOWN end
  if p == "left" then return _.PAD_LEFT end
  if p == "right" then return _.PAD_RIGHT end
  if p == "L1" then return _.PAD_L1 end
  if p == "L2" then return _.PAD_L2 end
  if p == "L3" then return _.PAD_L3 end
  if p == "R1" then return _.PAD_R1 end
  if p == "R2" then return _.PAD_R2 end
  if p == "R3" then return _.PAD_R3 end
  return nil
end

local function buildOverlayHints(_, incoming, anchorPad, anchorLabel)
  anchorPad = normalizePadName(anchorPad ~= nil and anchorPad or "square")
  anchorLabel = tostring(anchorLabel or "")
  local list = {}
  if type(incoming) == "table" then
    for i = 1, #incoming do
      local it = copyHintItem(incoming[i])
      if it then list[#list + 1] = it end
    end
  end

  if #list == 0 then
    local selectLabel = (_ and _.menu_str and (_.menu_str.enter_label or _.menu_str.confirm_label)) or "Select"
    local cancelLabel = (_ and _.menu_str and _.menu_str.cancel_label) or "Cancel"
    list = {
      { pad = "cross", label = selectLabel, row = 1 },
      { pad = anchorPad, label = anchorLabel, row = 1 },
      { pad = "circle", label = cancelLabel, row = 1 },
    }
  end

  local hasAnchor = false
  for i = 1, #list do
    local it = list[i]
    local pad = normalizePadName(it.pad)
    if pad == anchorPad then
      it.pad = anchorPad
      it.label = anchorLabel
      it.row = it.row or 1
      hasAnchor = true
    end
  end
  if not hasAnchor then
    local insertAt = math.min(2, #list + 1)
    table.insert(list, insertAt, { pad = anchorPad, label = anchorLabel, row = 1 })
  end

  return list
end

local function closeMenu(ctx, opts)
  ctx[opts.openKey] = nil
  ctx[opts.selKey] = nil
  ctx[opts.scrollKey] = nil
  local openKeyName = tostring(opts.openKey or "actionsMenuOpen")
  ctx[openKeyName .. "_anim"] = nil
  ctx[openKeyName .. "_closing"] = nil
  ctx[openKeyName .. "_rowsCache"] = nil
  ctx[openKeyName .. "_hintsCache"] = nil
end

local function normalizeRows(rows)
  local out = {}
  local removeOut = {}
  for i = 1, #(rows or {}) do
    local row = rows[i]
    if row and row.hidden ~= true then
      local id = tostring(row.id or tostring(i))
      local normalized = {
        id = id,
        label = tostring(row.label or ""),
        enabled = (row.enabled ~= false),
        raw = row,
      }
      if id:lower() == "remove" then
        removeOut[#removeOut + 1] = normalized
      else
        out[#out + 1] = normalized
      end
    end
  end
  for i = 1, #removeOut do
    out[#out + 1] = removeOut[i]
  end
  return out
end

function actions_menu.run(ctx, opts)
  if not ctx or type(opts) ~= "table" then return false end
  local _ = ctx._
  if not _ then return false end

  local openKey = opts.openKey or "actionsMenuOpen"
  if not ctx[openKey] then return false end
  local animKey = tostring(openKey) .. "_anim"
  local closingKey = tostring(openKey) .. "_closing"
  local anchorPad = normalizePadName(opts.anchorPad ~= nil and opts.anchorPad or "square")
  local anchorLabel = tostring(opts.anchorLabel or ((_.menu_str and _.menu_str.actions_label) or "Actions"))
  local anchorPadMask = padMaskForName(_, anchorPad)

  local selKey = opts.selKey or "actionsMenuSel"
  local scrollKey = opts.scrollKey or "actionsMenuScroll"
  local sourceRows = opts.rows or {}
  local rows = nil
  if opts.cacheRows == true then
    -- Same strategy as cached repeat FPS: build once for this open session,
    -- then reuse to avoid per-frame allocations and GC jitter.
    local rowsCacheKey = tostring(openKey) .. "_rowsCache"
    local cache = ctx[rowsCacheKey]
    local sourceLen = #sourceRows
    if type(cache) == "table" and cache.source == sourceRows and cache.sourceLen == sourceLen and type(cache.rows) == "table" then
      rows = cache.rows
    else
      rows = normalizeRows(sourceRows)
      ctx[rowsCacheKey] = {
        source = sourceRows,
        sourceLen = sourceLen,
        rows = rows,
      }
    end
  else
    rows = normalizeRows(sourceRows)
  end

  if #rows == 0 then
    closeMenu(ctx, { openKey = openKey, selKey = selKey, scrollKey = scrollKey })
    return true
  end

  local function isSelectable(idx)
    local row = rows[idx]
    return row and row.enabled
  end

  local function moveSelection(step)
    local idx = ctx[selKey] or 1
    for _attempt = 1, #rows do
      idx = _.common.wrapListSelection(idx, #rows, step)
      if isSelectable(idx) then
        ctx[selKey] = idx
        return
      end
    end
  end

  ctx[selKey] = _.common.clampListSelection(ctx[selKey] or 1, #rows)
  if not isSelectable(ctx[selKey]) then
    moveSelection(1)
  end

  local maxVisibleCap = math.max(1, math.floor(tonumber(opts.maxVisible) or 8))
  local minVisible = math.max(1, math.floor(tonumber(opts.minVisible) or 1))
  if minVisible > maxVisibleCap then minVisible = maxVisibleCap end
  local visibleRows = math.max(1, math.min(#rows, maxVisibleCap))
  if visibleRows < minVisible then visibleRows = minVisible end
  ctx[scrollKey] = _.common.centeredListScroll(ctx[selKey], #rows, visibleRows)
  local closing = ctx[closingKey] == true
  local anim = tonumber(ctx[animKey])
  if type(anim) ~= "number" then
    anim = closing and 1 or 0
  end
  if closing then
    anim = math.max(0, anim - (1 / 6))
  else
    anim = math.min(1, anim + (1 / 6))
  end
  ctx[animKey] = anim

  -- Standard Square Actions overlays intentionally render without a title.
  -- Keep heading support for explicit override-style dialogs (e.g. restore defaults).
  local title = ""
  if opts.titleOverride ~= nil and tostring(opts.titleOverride) ~= "" then
    title = tostring(opts.titleOverride)
  end
  local hasTitle = (title ~= "")
  local hintTypography = _.common.getHintTypography(_.font, _.drawMode)
  local textScale = hintTypography.textScale
  local rowScale = hintTypography.drawScale
  local titleScale = rowScale
  local rowStateKeyPrefix = opts.rowStateKeyPrefix or "actions_menu_row_"

  local hintFont = hintTypography.font
  local textH = hintTypography.textHeight

  local function textWidth(text)
    if _.common and _.common.calcTextWidth then
      return _.common.calcTextWidth(hintFont, tostring(text or ""), rowScale)
    end
    local s = tostring(text or "")
    return math.floor((8 * rowScale) * #s)
  end

  local titleW = hasTitle and textWidth(title) or 0
  local spaceW = textWidth(" ")
  if spaceW < 1 then
    local probeW = textWidth("M")
    if probeW < 1 then probeW = math.floor((8 * rowScale) + 0.5) end
    spaceW = math.max(2, math.floor((probeW * 0.32) + 0.5))
  end
  local markerW = textWidth(">")
  if markerW < 1 then
    markerW = math.max(2, math.floor((spaceW * 1.2) + 0.5))
  end
  local columnLayout = (opts.columnLayout == true)
  local columnMinWidths = {}
  if type(opts.columnMinWidths) == "table" then
    for i = 1, #opts.columnMinWidths do
      local w = tonumber(opts.columnMinWidths[i])
      if w and w > 0 then
        columnMinWidths[i] = math.floor(w + 0.5)
      end
    end
  end
  local columnGap = math.max(4, math.floor((spaceW * 2) + 0.5))
  local function rowColumnCount(columns)
    if type(columns) ~= "table" then return 0 end
    local n = #columns
    while n > 0 and tostring(columns[n] or "") == "" do
      n = n - 1
    end
    return n
  end
  local function rowIntrinsicWidth(row)
    if columnLayout and row and row.raw and type(row.raw.columns) == "table" then
      local cols = row.raw.columns
      local count = rowColumnCount(cols)
      if count > 0 then
        local total = 0
        for c = 1, count do
          local colText = tostring(cols[c] or "")
          local colW = tonumber(columnMinWidths[c]) or textWidth(colText)
          total = total + colW
          if c < count then total = total + columnGap end
        end
        return total
      end
    end
    return textWidth(row and row.label or "")
  end
  local maxLabelWIntrinsic = tonumber(opts.minLabelIntrinsicW) or 0
  local skipMeasure = (opts.skipIntrinsicMeasure == true) and maxLabelWIntrinsic > 0
  if not skipMeasure then
    local measuredMax = 0
    for i = 1, #rows do
      local lw = rowIntrinsicWidth(rows[i])
      if lw > measuredMax then measuredMax = lw end
    end
    if measuredMax > maxLabelWIntrinsic then
      maxLabelWIntrinsic = measuredMax
    end
  end
  local hintGap = math.max(2, math.floor((((_.common and _.common.PAD_HINT_GAP) or 5) * textScale) + 0.5))
  local padX = math.floor((_.scaleY and _.scaleY(8) or 8) + 0.5)
  local padTop = math.floor((_.scaleY and _.scaleY(6) or 6) + 0.5)
  local titleH = hasTitle and (textH + 2) or 0
  local titleGap = hasTitle and 0 or 0
  local padBottom = math.floor((_.scaleY and _.scaleY(6) or 6) + 0.5)
  local rowStep = textH + math.max(2, math.floor((_.scaleY and _.scaleY(3) or 3) + 0.5))

  -- Match hint-grid geometry so this feels like a popup anchored to the active helper button.
  local runtime = _G and _G.CONFIG_UI
  local sideMargin = (_.common and _.common.PAD_HINT_SIDE_MARGIN) or 0
  local hintGridXShift = (_.common and _.common.PAD_HINT_GRID_X_SHIFT) or 0
  local hintGridExtraW = (_.common and _.common.PAD_HINT_GRID_EXTRA_W) or 0
  local baseHintTotalW = ((_.w or 640) - (2 * (_.MARGIN_X or 0))) + hintGridExtraW
  -- Keep overlay anchoring math in lock-step with overlay hint drawing,
  -- which now always uses static grid width.
  local autoHintExtraW = 0
  local hintXEff = (_.MARGIN_X or 0) + sideMargin + hintGridXShift
  local rightOverscan = (_.common and tonumber(_.common.PAD_HINT_GRID_RIGHT_OVERSCAN)) or 8
  if rightOverscan < 0 then rightOverscan = 0 end
  local sceneW = (type(runtime) == "table" and tonumber(runtime.currentSceneWidth)) or (_.w or 640)
  local maxHintWidthEff = math.max(1, math.floor((sceneW - rightOverscan) - hintXEff))
  local baseHintWidthEff = math.max(1, baseHintTotalW - (2 * sideMargin))
  local maxAutoExtraByScreen = math.max(0, maxHintWidthEff - baseHintWidthEff)
  if autoHintExtraW > maxAutoExtraByScreen then
    autoHintExtraW = maxAutoExtraByScreen
  end
  local hintTotalW = baseHintTotalW + autoHintExtraW
  local hintWidthEff = hintTotalW - (2 * sideMargin)
  local slotW = hintWidthEff / 5
  local function slotIndexForPad(pad)
    if pad == "cross" then return 1 end
    if pad == "square" then return 2 end
    if pad == "start" then return 3 end
    if pad == "triangle" then return 4 end
    if pad == "circle" then return 5 end
    return 2
  end
  local anchorSlotIndex = slotIndexForPad(anchorPad)
  local anchorSpanSlots = math.max(1, math.floor(tonumber(opts.anchorSpanSlots) or 1))
  local targetSlotIndex = math.min(5, anchorSlotIndex + anchorSpanSlots)
  local anchorSlotLeft = hintXEff + ((anchorSlotIndex - 1) * slotW)
  local anchorSlotCenter = anchorSlotLeft + (slotW / 2)
  local targetSlotLeft = hintXEff + ((targetSlotIndex - 1) * slotW)
  local targetSlotCenter = targetSlotLeft + (slotW / 2)
  local hintIconScale = tonumber((_.common and _.common.PAD_HINT_ICON_SCALE) or 0.54) or 0.54
  local hintIconW = math.max(10, math.floor((((_.common and _.common.PAD_ICON_W) or 26) * hintIconScale) + 0.5))
  if _.common and _.common.PAD_HINT_ALIGN_CROSS_TO_X ~= false then
    local desiredXEff = (_.MARGIN_X or 0) + (hintIconW * 0.5) - (slotW * 0.5)
    local maxXEff = (sceneW - rightOverscan) - hintWidthEff
    if desiredXEff > maxXEff then desiredXEff = maxXEff end
    hintXEff = desiredXEff
    anchorSlotLeft = hintXEff + ((anchorSlotIndex - 1) * slotW)
    anchorSlotCenter = anchorSlotLeft + (slotW / 2)
    targetSlotLeft = hintXEff + ((targetSlotIndex - 1) * slotW)
    targetSlotCenter = targetSlotLeft + (slotW / 2)
  end
  local anchorButtonLeft = math.floor(anchorSlotCenter - (hintIconW / 2))
  local targetButtonLeft = math.floor(targetSlotCenter - (hintIconW / 2))
  local anchorActionLabelX = anchorButtonLeft + hintIconW + hintGap

  -- Right edge snaps to the target button left edge (e.g. square->start span).
  local boxX = anchorButtonLeft
  local targetRightX = targetButtonLeft
  local desiredToStartW = math.floor(targetRightX - boxX + 0.5)
  if desiredToStartW < 90 then desiredToStartW = 90 end
  local contentW = math.max(90, math.floor(((anchorActionLabelX - boxX) + maxLabelWIntrinsic + padX) + 0.5))
  local forceAnchorSpanWidth = (opts.forceAnchorSpanWidth == true)
  local boxW
  if forceAnchorSpanWidth then
    boxW = desiredToStartW
  else
    boxW = math.max(desiredToStartW, contentW)
  end
  local maxBoxWAtX = (_.w or 640) - (_.MARGIN_X or 0) - boxX
  if boxW > maxBoxWAtX then boxW = maxBoxWAtX end

  -- Fit content within fixed width; choices align with anchor helper label text.
  local maxVisByHeight = visibleRows
  local boxH = padTop + titleH + titleGap + (maxVisByHeight * rowStep) + padBottom
  local hintRowH = math.max(14, math.floor((((_.common and _.common.PAD_HINT_ROW_H) or 28) * textScale) + 0.5))
  local hintRowTop = math.floor(_.HINT_Y) - hintRowH
  local finalBoxY = hintRowTop - boxH - math.max(2, math.floor((_.scaleY and _.scaleY(2) or 2) + 0.5))
  local slideDist = math.max(10, math.floor((_.scaleY and _.scaleY(14) or 14) + 0.5))
  local boxY = finalBoxY + math.floor((1 - anim) * slideDist)

  local minX = _.MARGIN_X or 0
  local maxX = (_.w or 640) - boxW - (_.MARGIN_X or 0)
  if boxX < minX then boxX = minX end
  if boxX > maxX then boxX = maxX end

  local bgAlpha = math.floor(120 * anim + 0.5)
  if bgAlpha < 0 then bgAlpha = 0 end
  if bgAlpha > 120 then bgAlpha = 120 end
  if _.Graphics and _.Graphics.drawRect then
    _.Graphics.drawRect(boxX, boxY, boxW, boxH, Color.new(40, 40, 48, bgAlpha))
  end

  local rowStartY = boxY + padTop + titleH + titleGap
  if hasTitle then
    local titleX = boxX + math.floor((boxW - titleW) / 2)
    local titleY = boxY + padTop
    _.drawText(hintFont, _.drawMode, titleX, titleY, titleScale, title, _.WHITE, textH)
  end

  local rowLabelX = anchorActionLabelX
  local rowMarkerX = rowLabelX - markerW - spaceW
  local maxLabelW = (boxX + boxW) - padX - rowLabelX
  if maxLabelW < 1 then maxLabelW = 1 end
  if _.common and _.common.drawListScrollbar then
    local barWidth = (_.scaleX and _.scaleX(8)) or 8
    _.common.drawListScrollbar(_, {
      totalRows = #rows,
      visibleRows = visibleRows,
      scrollRows = ctx[scrollKey],
      rowTopY = rowStartY,
      rowHeight = rowStep,
      color = _.DIM_COLOR,
      barWidth = barWidth,
      x = (boxX + boxW - padX - barWidth),
      minBarHeight = (_.scaleY and _.scaleY(4)) or 4,
    })
  end
  for i = ctx[scrollKey] + 1, math.min(ctx[scrollKey] + visibleRows, #rows) do
    local row = rows[i]
    local y = rowStartY + (i - ctx[scrollKey] - 1) * rowStep
    local shouldTicker = (i == ctx[selKey]) or (row.raw and row.raw.forceTicker == true)
    local col = row.enabled and ((i == ctx[selKey]) and _.SELECTED_COLOR or _.UNSELECTED_COLOR) or (_.DISABLED_DIM_COLOR or _.DIM_COLOR)
    if i == ctx[selKey] then
      _.drawText(hintFont, _.drawMode, rowMarkerX, y, rowScale, ">", col, textH)
    end
    local colCount = rowColumnCount(row.raw and row.raw.columns)
    if columnLayout and row.raw and type(row.raw.columns) == "table" and colCount > 0 then
      local cols = row.raw.columns
      local colX = rowLabelX
      for c = 1, colCount do
        local colText = tostring(cols[c] or "")
        if c < colCount then
          local colW = tonumber(columnMinWidths[c]) or textWidth(colText)
          if _.common.truncateTextToWidth then
            colText = _.common.truncateTextToWidth(hintFont, colText, math.max(1, colW), rowScale)
          end
          _.drawText(hintFont, _.drawMode, colX, y, rowScale, colText, col, textH)
          colX = colX + colW + columnGap
        else
          local avail = (boxX + boxW) - padX - colX
          if avail < 1 then avail = 1 end
          if _.common.fitListRowText then
            colText = _.common.fitListRowText(ctx, rowStateKeyPrefix .. tostring(i) .. "_c" .. tostring(c), hintFont,
              colText, avail, rowScale, shouldTicker)
          elseif _.common.truncateTextToWidth then
            colText = _.common.truncateTextToWidth(hintFont, colText, avail, rowScale)
          end
          _.drawText(hintFont, _.drawMode, colX, y, rowScale, colText, col, textH)
        end
      end
    else
      local label = row.label
      if _.common.fitListRowText then
        label = _.common.fitListRowText(ctx, rowStateKeyPrefix .. tostring(i), hintFont, label, maxLabelW, rowScale,
          shouldTicker)
      elseif _.common.truncateTextToWidth then
        label = _.common.truncateTextToWidth(hintFont, label, maxLabelW, rowScale)
      end
      _.drawText(hintFont, _.drawMode, rowLabelX, y, rowScale, label, col, textH)
    end
  end

  local hintItems = nil
  if opts.cacheHints == true then
    local hintsCacheKey = tostring(openKey) .. "_hintsCache"
    local cache = ctx[hintsCacheKey]
    local incomingHints = opts.hints
    if type(cache) == "table" and cache.incoming == incomingHints and cache.anchorPad == anchorPad and
        cache.anchorLabel == anchorLabel and type(cache.items) == "table" then
      hintItems = cache.items
    else
      hintItems = buildOverlayHints(_, incomingHints, anchorPad, anchorLabel)
      ctx[hintsCacheKey] = {
        incoming = incomingHints,
        anchorPad = anchorPad,
        anchorLabel = anchorLabel,
        items = hintItems,
      }
    end
  else
    hintItems = buildOverlayHints(_, opts.hints, anchorPad, anchorLabel)
  end
  if _.Graphics and _.Graphics.drawRect then
    local hintBg = (_.common and _.common.BACKGROUND_COLOR) or Color.new(0, 0, 0, 0x80)
    local hintRowH = math.max(14, math.floor(((_.common and _.common.PAD_HINT_ROW_H) or 28) * textScale + 0.5))
    local hintRowTop = math.floor(_.HINT_Y) - hintRowH
    local hintW = (_.w or 640) - (2 * (_.MARGIN_X or 0))
    _.Graphics.drawRect(_.MARGIN_X or 0, hintRowTop, hintW, hintRowH, hintBg)
  end
  _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, hintItems, nil, _.DIM_COLOR, _.w - 2 * _.MARGIN_X)

  if not closing then
    if (_.padEffective & _.PAD_UP) ~= 0 then
      moveSelection(-1)
    end
    if (_.padEffective & _.PAD_DOWN) ~= 0 then
      moveSelection(1)
    end

    if (_.padEffective & _.PAD_CROSS) ~= 0 then
      local row = rows[ctx[selKey]]
      if row and row.enabled then
        if opts.closeOnSelect ~= false then
          closeMenu(ctx, { openKey = openKey, selKey = selKey, scrollKey = scrollKey })
        end
        if type(opts.onSelect) == "function" then
          opts.onSelect(row.raw, row.id, ctx[selKey])
        end
      end
    end

    local anchorPressed = anchorPadMask and ((_.padEffective & anchorPadMask) ~= 0)
    local anchorHandled = false
    if anchorPressed and type(opts.onAnchorPress) == "function" then
      anchorHandled = (opts.onAnchorPress(rows[ctx[selKey]] and rows[ctx[selKey]].raw, ctx[selKey], ctx) == true)
    end
    if (_.padEffective & _.PAD_CIRCLE) ~= 0 or (anchorPressed and not anchorHandled) then
      ctx[closingKey] = true
      if ctx[animKey] < 0.001 then
        ctx[animKey] = 1
      end
    end
  end

  if closing and anim <= 0.001 then
    closeMenu(ctx, { openKey = openKey, selKey = selKey, scrollKey = scrollKey })
    if type(opts.onCancel) == "function" then
      opts.onCancel()
    end
  end

  return true
end

return actions_menu
