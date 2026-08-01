--[[ Launch Disc (cdrom) options for a menu entry or MBR boot key. ]]

local function run(ctx)
  local _ = ctx._
  local isBoot = not not (ctx.bootKey and (ctx.context == "mbr" or ctx.fileType == "osdmbr_cnf"))
  local bblKeyId = ctx.bblHotkeyKey
  local bblSlot = tonumber(ctx.bblEntrySlot)
  local isBblHotkey = (not isBoot) and bblKeyId and bblSlot and
      (ctx.fileType == "ps2bbl_ini" or ctx.fileType == "psxbbl_ini")
  if not ctx.lines then
    ctx.state = isBoot and "editor" or (isBblHotkey and "bbl_hotkey_entry" or "menu_entry_edit")
    if isBoot then ctx.bootKey = nil end
    return
  end
  if not isBoot and not isBblHotkey and not ctx.entryIdx then
    ctx.state = "menu_entry_edit"; return
  end
  local args = isBoot and (function()
    local a = _.config_parse.getBootArgs(ctx.lines, ctx.bootKey) or {}
    local t = {}
    for _, v in ipairs(a) do table.insert(t, { value = v, disabled = false }) end
    return t
  end)() or
      (isBblHotkey and (_.config_parse.getBblHotkeyArgs(ctx.lines, bblKeyId, bblSlot) or {}) or
        (_.config_parse.getMenuEntryArgs(ctx.lines, ctx.entryIdx) or {}))
  local opts = _.config_options.cdrom_options or {}
  local optionOrderByKey = {}
  for i = 1, #opts do
    local o = opts[i]
    local key = o and o.key or nil
    if key and key ~= "" then
      optionOrderByKey[key] = i
    end
  end
  local targetOrderKey = isBoot and ("boot:" .. tostring(ctx.bootKey or "")) or
      (isBblHotkey and ("bbl:" .. tostring(bblKeyId or "") .. ":" .. tostring(bblSlot or 0)) or
        ("entry:" .. tostring(ctx.entryIdx or 0)))
  -- Keep launch-disc option args in stable per-target order so off/on reverts
  -- return to the same semantic line order and don't leave a false dirty state.
  if ctx.cdromOptionOrderKey ~= targetOrderKey or type(ctx.cdromOptionOrder) ~= "table" then
    local rankByValue = {}
    local nextRank = 1
    for i = 1, #args do
      local av = type(args[i]) == "table" and args[i].value or args[i]
      if av ~= nil and rankByValue[av] == nil then
        rankByValue[av] = nextRank
        nextRank = nextRank + 1
      end
    end
    local fallbackBase = nextRank
    for i = 1, #opts do
      local key = opts[i] and opts[i].key or nil
      if key and key ~= "" and rankByValue[key] == nil then
        rankByValue[key] = fallbackBase + i
      end
    end
    ctx.cdromOptionOrder = rankByValue
    ctx.cdromOptionOrderKey = targetOrderKey
  end
  if ctx.cdromOptSel < 1 then ctx.cdromOptSel = 1 end
  if ctx.cdromOptSel > #opts then ctx.cdromOptSel = #opts end
  local function hasArg(key)
    for _, a in ipairs(args) do if (type(a) == "table" and a.value or a) == key then return true end end
    return false
  end
  local function markConfigMutated()
    -- Force frame-end dirty recomputation after an edit so immediate revert
    -- can clear Save without waiting for stale cache invalidation.
    ctx._configModifiedCache = nil
    ctx.configModified = true
  end
  local function insertOptionArgWithStableOrder(argList, key)
    local rankByValue = ctx.cdromOptionOrder or {}
    local newRank = rankByValue[key] or (1000 + (optionOrderByKey[key] or 0))
    local insertAt = #argList + 1
    for i = 1, #argList do
      local av = type(argList[i]) == "table" and argList[i].value or argList[i]
      local r = rankByValue[av]
      if r and r > newRank then
        insertAt = i
        break
      end
    end
    table.insert(argList, insertAt, { value = key, disabled = false })
  end
  _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1, _.menu_str.launch_disc_options_title, _.WHITE)
  _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y + _.scaleY(24), 0.8, _.menu_str.launch_disc_options_sub, _.DIM_COLOR)
  local startY = _.MARGIN_Y + _.scaleY(50)
  local maxLabelW = (_.VALUE_X or 360) - (_.MARGIN_X + 20) - 14
  local cdromStrings = _.strings.cdrom_options or {}
  local function cdromStringKey(argKey) return (argKey and argKey:gsub("^-", "")) or argKey end
  for i = 1, #opts do
    local o = opts[i]
    local y = startY + (i - 1) * _.LINE_H
    local on = hasArg(o.key)
    local col = (i == ctx.cdromOptSel) and _.SELECTED_COLOR or _.UNSELECTED_COLOR
    local coSt = cdromStrings[cdromStringKey(o.key)]
    local rowLabel = (coSt and coSt.label) or o.key
    if _.common.fitListRowText then
      rowLabel = _.common.fitListRowText(ctx, "entry_cdrom_row_" .. tostring(i), _.font, rowLabel, maxLabelW, _.FONT_SCALE,
        i == ctx.cdromOptSel)
    elseif _.common.truncateTextToWidth then
      rowLabel = _.common.truncateTextToWidth(_.font, rowLabel, maxLabelW, _.FONT_SCALE)
    end
    _.drawListRow(_.MARGIN_X + 20, y, i == ctx.cdromOptSel, rowLabel, col)
    _.drawText(_.font, _.drawMode, _.VALUE_X, y, _.FONT_SCALE, on and _.common_str.on or _.common_str.off,
      on and _.UNSELECTED_COLOR or _.DIM_COLOR)
  end
  local selOpt = opts[ctx.cdromOptSel]
  local selCoSt = selOpt and cdromStrings[cdromStringKey(selOpt.key)]
  if selCoSt and selCoSt.desc then
    local descText = tostring(selCoSt.desc or "")
    local hintTypography = _.common.getHintTypography(_.font, _.drawMode)
    local hintDrawScale = hintTypography.drawScale
    local hintFont = hintTypography.font
    local hintTextH = hintTypography.textHeight
    local hintColor = (_.UNSELECTED_COLOR or _.DIM_COLOR or _.WHITE)
    local descMaxW = (_.w or 640) - (_.MARGIN_X * 2)
    local descRawW = (_.common.calcTextWidth and _.common.calcTextWidth(hintFont, descText, hintDrawScale)) or (#descText * 8)
    local useTicker = descRawW > descMaxW
    if useTicker then
      if _.common.fitListRowText then
        descText = _.common.fitListRowText(ctx, "entry_cdrom_desc_" .. tostring(selOpt and selOpt.key or ""), hintFont,
          descText, descMaxW, hintDrawScale, true, { holdStart = 55, stepFrames = 16, holdEnd = 85 })
      elseif _.common.truncateTextToWidth then
        descText = _.common.truncateTextToWidth(hintFont, descText, descMaxW, hintDrawScale)
      end
    end
    local tw = (_.common.calcTextWidth and _.common.calcTextWidth(hintFont, descText, hintDrawScale)) or (#descText * 8)
    local x
    if useTicker then
      x = _.MARGIN_X
    else
      local startCenterX = _.common.getHintStartCenterX and _.common.getHintStartCenterX(_, (_.w or 640) - (2 * _.MARGIN_X))
      x = startCenterX and math.floor(startCenterX - (tw / 2) + 0.5) or _.common.centerX(_, tw)
    end
    _.drawText(hintFont, _.drawMode, x, _.DESC_Y_BOTTOM, hintDrawScale, descText, hintColor, hintTextH)
  end
  local baseHints = _.menu_str.cdrom_toggle_hint_items or {}
  local crossLabel = (baseHints[1] and baseHints[1].label) or "Toggle"
  local backLabel = (baseHints[2] and baseHints[2].label) or (_.menu_str.back_label or "Back")
  local cdromHints = {
    { pad = "cross", label = crossLabel, row = 1 },
    {
      pad = ctx.configModified and "start" or "",
      label = ctx.configModified and (_.menu_str.save_config_label or "Save") or "",
      row = 1
    },
    { pad = "circle", label = backLabel, row = 1 },
  }
  for i = 3, #baseHints do
    cdromHints[#cdromHints + 1] = baseHints[i]
  end
  _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, cdromHints, nil, _.DIM_COLOR, _.w - 2 * _.MARGIN_X)
  if (_.padEffective & _.PAD_UP) ~= 0 then
    ctx.cdromOptSel = _.common.moveListSelection(ctx.cdromOptSel, #opts, -1, { ctx = ctx })
  end
  if (_.padEffective & _.PAD_DOWN) ~= 0 then
    ctx.cdromOptSel = _.common.moveListSelection(ctx.cdromOptSel, #opts, 1, { ctx = ctx })
  end
  local function toggleSelectedOption()
    if #opts == 0 then return end
    local key = opts[ctx.cdromOptSel].key
    args = isBoot and (function()
      local a = _.config_parse.getBootArgs(ctx.lines, ctx.bootKey) or {}
      local t = {}
      for _, v in ipairs(a) do table.insert(t, { value = v, disabled = false }) end
      return t
    end)() or
        (isBblHotkey and (_.config_parse.getBblHotkeyArgs(ctx.lines, bblKeyId, bblSlot) or {}) or
          (_.config_parse.getMenuEntryArgs(ctx.lines, ctx.entryIdx) or {}))
    if hasArg(key) then
      local newArgs = {}
      for _, a in ipairs(args) do
        local av = type(a) == "table" and a.value or a
        if av ~= key then table.insert(newArgs, type(a) == "table" and a or { value = a, disabled = false }) end
      end
      if isBoot then
        local v = {}
        for _, item in ipairs(newArgs) do table.insert(v, type(item) == "table" and item.value or item) end
        _.config_parse.setBootArgs(ctx.lines, ctx.bootKey, v, { preserveOrder = true })
      elseif isBblHotkey then
        _.config_parse.setBblHotkeyArgs(ctx.lines, bblKeyId, bblSlot, newArgs, { preserveOrder = true })
      else
        _.config_parse.setMenuEntryArgs(ctx.lines, ctx.entryIdx, newArgs, { preserveOrder = true })
      end
      markConfigMutated()
    else
      insertOptionArgWithStableOrder(args, key)
      if isBoot then
        local v = {}
        for _, item in ipairs(args) do table.insert(v, type(item) == "table" and item.value or item) end
        _.config_parse.setBootArgs(ctx.lines, ctx.bootKey, v, { preserveOrder = true })
      elseif isBblHotkey then
        _.config_parse.setBblHotkeyArgs(ctx.lines, bblKeyId, bblSlot, args, { preserveOrder = true })
      else
        _.config_parse.setMenuEntryArgs(ctx.lines, ctx.entryIdx, args, { preserveOrder = true })
      end
      markConfigMutated()
    end
  end
  if (_.padEffective & (_.PAD_LEFT | _.PAD_RIGHT | _.PAD_CROSS)) ~= 0 then
    toggleSelectedOption()
  end
  if ctx.configModified and (_.padEffective & _.PAD_START) ~= 0 then
    _.common.saveCurrentConfig(ctx)
  end
  if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
    ctx.cdromOptionOrder = nil
    ctx.cdromOptionOrderKey = nil
    if isBoot then
      ctx.state = "editor"; ctx.bootKey = nil
    elseif isBblHotkey then
      ctx.state = "bbl_hotkey_entry"
    else
      ctx.state = "menu_entry_edit"
    end
  end
end

return { run = run }
