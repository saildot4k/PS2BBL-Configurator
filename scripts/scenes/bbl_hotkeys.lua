--[[ PS2BBL/PSXBBL hotkey list (16 buttons, AUTO handled separately). ]]

local function formatPathCount(count)
  if count == 1 then
    return "1 path"
  end
  return tostring(count) .. " paths"
end

local function formatSinglePath(_, pathVal)
  if _.common and _.common.formatDisplayPathWithCommands then
    return _.common.formatDisplayPathWithCommands(_, pathVal)
  end
  return tostring(pathVal or "")
end

local function canonicalHotkeyId(raw, hotkeySet)
  if type(raw) ~= "string" then return nil end
  local upper = raw:upper()
  if hotkeySet[upper] then return upper end
  return nil
end

local function hasUsablePathValue(value)
  local s = tostring(value or "")
  s = s:gsub("^%s+", ""):gsub("%s+$", "")
  return s ~= ""
end

-- Build per-hotkey summary in one pass to avoid repeated O(lines) lookups per row/slot.
local function buildHotkeySummary(lines, hotkeys, maxEntries)
  local cap = math.max(0, math.floor(tonumber(maxEntries) or 0))
  local hotkeySet = {}
  local summary = {}
  for i = 1, #hotkeys do
    local keyId = hotkeys[i]
    hotkeySet[keyId] = true
    summary[keyId] = {
      disabled = false,
      disabledSeen = false,
      name = "",
      pathCount = 0,
      activePathCount = 0,
      singlePath = "",
      slotState = {},
    }
  end

  for _, entry in ipairs(lines or {}) do
    local key = entry and entry.key
    if type(key) == "string" then
      local nameId = key:match("^NAME_(.+)$")
      if nameId then
        local canon = canonicalHotkeyId(nameId, hotkeySet)
        local s = canon and summary[canon] or nil
        if s then
          s.disabledSeen = true
          if entry.comment then
            s.disabled = true
          end
          if s.name == "" then
            s.name = entry.value or ""
          end
        end
      else
        local pathId, slotStr = key:match("^LK_(.+)_E(%d+)$")
        if pathId then
          local canon = canonicalHotkeyId(pathId, hotkeySet)
          local s = canon and summary[canon] or nil
          if s then
            s.disabledSeen = true
            if entry.comment == 2 then
              s.disabled = true
            end
            local slot = tonumber(slotStr)
            if slot and slot >= 1 and slot <= cap then
              local slotState = s.slotState[slot]
              if not slotState then
                slotState = { defined = false, active = false, path = "" }
                s.slotState[slot] = slotState
              end
              if hasUsablePathValue(entry.value) then
                slotState.defined = true
                slotState.path = entry.value or ""
                if not entry.comment then
                  slotState.active = true
                end
              end
            end
          end
        else
          local argId = key:match("^ARG_(.+)_E%d+$")
          if argId then
            local canon = canonicalHotkeyId(argId, hotkeySet)
            local s = canon and summary[canon] or nil
            if s then
              s.disabledSeen = true
              if entry.comment == 2 then
                s.disabled = true
              end
            end
          end
        end
      end
    end
  end
  for i = 1, #hotkeys do
    local keyId = hotkeys[i]
    local s = summary[keyId]
    if s and s.slotState then
      local pathCount = 0
      local activePathCount = 0
      local singlePath = ""
      for slot = 1, cap do
        local slotState = s.slotState[slot]
        if slotState then
          if slotState.defined then
            pathCount = pathCount + 1
            if pathCount == 1 then
              singlePath = slotState.path or ""
            end
          end
          if slotState.active then
            activePathCount = activePathCount + 1
          end
        end
      end
      s.pathCount = pathCount
      s.activePathCount = activePathCount
      s.singlePath = (pathCount == 1) and singlePath or ""
      if activePathCount > 0 then
        s.disabled = false
      elseif pathCount > 0 then
        s.disabled = true
      end
      s.slotState = nil
    end
  end

  return summary
end

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
  local isFmcb = (ctx.fileType == "freemcboot_cnf") or (ctx.context == "freehddboot")
  local maxEntries = isFmcb and ((_.config_options and _.config_options.FMCB_BBL_MAX_ENTRIES) or 3) or
      ((_.config_parse.getBblMaxEntries and _.config_parse.getBblMaxEntries()) or 10)
  local sceneEpoch = ctx._sceneEpoch or 0
  local hotkeySummaryCache = ctx.bblHotkeySummaryCache
  if not hotkeySummaryCache or hotkeySummaryCache.linesRef ~= ctx.lines or hotkeySummaryCache.maxEntries ~= maxEntries or
      hotkeySummaryCache.sceneEpoch ~= sceneEpoch then
    hotkeySummaryCache = {
      linesRef = ctx.lines,
      maxEntries = maxEntries,
      sceneEpoch = sceneEpoch,
      summary = buildHotkeySummary(ctx.lines, hotkeys, maxEntries),
    }
    ctx.bblHotkeySummaryCache = hotkeySummaryCache
  end
  local hotkeySummary = hotkeySummaryCache.summary or {}
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
  local startY = _.MARGIN_Y + _.scaleY(50)
  if _.common and _.common.drawListScrollbar then
    _.common.drawListScrollbar(_, {
      totalRows = #hotkeys,
      visibleRows = _.MAX_VISIBLE_LIST,
      scrollRows = ctx.bblHotkeyScroll,
      rowTopY = startY,
      rowHeight = _.LINE_H,
      color = _.DIM_COLOR,
    })
  end

  local rowX = _.MARGIN_X + 20
  local maxLabelW = (_.w or 640) - (rowX + 4) - _.MARGIN_X
  local baseIconW = _.common.PAD_ICON_W or 26
  local baseIconH = _.common.PAD_ICON_H or 26
  local textH = (_.common and _.common.FT_PIXEL_H) or 18
  local iconH = math.min(baseIconH, textH)
  local iconW = math.max(1, math.floor((baseIconW * iconH) / baseIconH + 0.5))
  local iconGap = 8
  local nameNotDefined = _.common_str.name_not_defined or _.common_str.empty
  local pathNotDefined = _.common_str.path_not_defined or _.common_str.empty
  for i = ctx.bblHotkeyScroll + 1, math.min(ctx.bblHotkeyScroll + _.MAX_VISIBLE_LIST, #hotkeys) do
    local keyId = hotkeys[i]
    local info = hotkeySummary[keyId] or { disabled = false, name = "", pathCount = 0 }
    local keyIcon = _.common.getPadIcon(keyId)
    local keyDisabled = info.disabled and true or false
    local nameVal = info.name or ""
    local pathCount = tonumber(info.pathCount) or 0
    local activePathCount = tonumber(info.activePathCount) or 0
    local hasName = (nameVal ~= "")
    local hasPath = (pathCount > 0)
    local hasActivePath = (activePathCount > 0)
    local effectiveDisabled = keyDisabled or (not hasActivePath)
    local disp
    if isFmcb then
      if pathCount <= 0 then
        disp = _.common_str.empty
      elseif pathCount == 1 then
        disp = formatSinglePath(_, info.singlePath)
      else
        disp = formatPathCount(pathCount)
      end
    elseif not hasName and not hasPath then
      disp = _.common_str.empty
    elseif not hasName then
      disp = nameNotDefined .. " (" .. formatPathCount(pathCount) .. ")"
    elseif not hasPath then
      disp = pathNotDefined
    else
      disp = nameVal .. " (" .. formatPathCount(pathCount) .. ")"
    end
    local line = disp
    if _.common and _.common.formatBelForDisplay then
      line = _.common.formatBelForDisplay(line)
    end
    local lineMaxW = maxLabelW - iconW - iconGap
    if _.common.fitListRowText then
      line = _.common.fitListRowText(ctx, "bbl_hotkeys_row_" .. tostring(i), _.font, line, lineMaxW, _.FONT_SCALE,
        i == ctx.bblHotkeySel)
    elseif _.common.truncateTextToWidth then
      line = _.common.truncateTextToWidth(_.font, line, lineMaxW, _.FONT_SCALE)
    end
    local y = startY + (i - ctx.bblHotkeyScroll - 1) * _.LINE_H
    local col = (i == ctx.bblHotkeySel) and _.SELECTED_COLOR or _.UNSELECTED_COLOR
    if effectiveDisabled then
      col = (i == ctx.bblHotkeySel) and (_.SELECTED_DIM_COLOR or _.SELECTED_COLOR) or (_.DISABLED_DIM_COLOR or _.DIM_COLOR)
    end
    if keyIcon then
      local iconY = y + math.floor(((_.LINE_H or iconH) - iconH) / 2)
      if _.Graphics.drawScaleImage then
        _.Graphics.drawScaleImage(keyIcon, rowX, iconY, iconW, iconH)
      else
        _.Graphics.drawImage(keyIcon, rowX, iconY)
      end
    end
    _.drawText(_.font, _.drawMode, rowX + iconW + iconGap, y, _.FONT_SCALE, line, col)
  end

  local selKey = hotkeys[ctx.bblHotkeySel]
  local selInfo = selKey and hotkeySummary[selKey] or nil
  local selDisabledRaw = selInfo and selInfo.disabled and true or false
  local selHasActivePath = (tonumber(selInfo and selInfo.activePathCount) or 0) > 0
  local selDisabled = selDisabledRaw or (not selHasActivePath)
  local selCanToggleDisabled = selInfo and selInfo.disabledSeen and true or false
  local hint = {
    { pad = "cross", label = (_.menu_str.enter_label or "Enter"), row = 1 },
    {
      pad = ctx.configModified and "start" or "",
      label = ctx.configModified and (_.menu_str.save_config_label or "Save") or "",
      row = 1
    },
    {
      pad = selCanToggleDisabled and "triangle" or "",
      label = selCanToggleDisabled and
          (selDisabled and (_.menu_str.enable_label or "Enable") or (_.menu_str.disable_label or "Disable")) or "",
      layoutLabel = (_.menu_str.disable_label or "Disable"),
      row = 1
    },
    { pad = "circle", label = (_.menu_str.back_label or "Back"), row = 1 },
  }
  _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, hint, nil, _.DIM_COLOR, _.w - 2 * _.MARGIN_X)

  if (_.padEffective & _.PAD_UP) ~= 0 then
    ctx.bblHotkeySel = ctx.bblHotkeySel - 1
    if ctx.bblHotkeySel < 1 then ctx.bblHotkeySel = #hotkeys end
  end
  if (_.padEffective & _.PAD_DOWN) ~= 0 then
    ctx.bblHotkeySel = ctx.bblHotkeySel + 1
    if ctx.bblHotkeySel > #hotkeys then ctx.bblHotkeySel = 1 end
  end
  local function beginFirstPathPickerForHotkey(keyId, slotDisabled)
    if not keyId or not _.config_parse.insertBblHotkeySlotBelow then return false end
    local firstSlot = _.config_parse.insertBblHotkeySlotBelow(ctx.lines, keyId, 0, maxEntries)
    if not firstSlot then return false end
    ctx.configModified = true
    ctx.bblHotkeySummaryCache = nil
    ctx.bblHotkeyKey = keyId
    ctx.bblEntryListReturnState = "bbl_hotkeys"
    ctx.bblEntryFocusSlot = firstSlot
    ctx.editKey = nil
    ctx.isAddPath = false
    ctx.addPathKey = nil
    ctx.pathPickerTarget = nil
    ctx.pathPickerFileExts = nil
    ctx.pathPickerBootKey = nil
    ctx.pathPickerBootKeyDisabled = nil
    ctx.pathPickerForEntryIdx = nil
    ctx.pathPickerEditIdx = nil
    ctx.pathPickerInsertBelow = nil
    ctx.pathPickerBblIrxIdx = nil
    ctx.pathPickerBblIrxDisabled = nil
    ctx.pathPickerBblHotkeyKey = keyId
    ctx.pathPickerBblHotkeySlot = firstSlot
    ctx.pathPickerBblHotkeyDisabled = slotDisabled and true or false
    ctx.pathPickerReturnState = "bbl_hotkey_entries"
    ctx.pathPickerContext = "path_only"
    ctx.pathPickerSub = "device"
    ctx.pathList = _.file_selector.getDevices("path_only", { fileType = ctx.fileType }) or {}
    ctx.pathPickerSel = 1
    ctx.pathPickerScroll = 0
    ctx.pathBrowsePath = nil
    ctx.state = "path_picker"
    return true
  end
  if (_.padEffective & _.PAD_CROSS) ~= 0 then
    local keyId = hotkeys[ctx.bblHotkeySel]
    local info = keyId and hotkeySummary[keyId] or nil
    local isEmptyBblHotkey = (not isFmcb) and info and ((tonumber(info.pathCount) or 0) <= 0)
    if isEmptyBblHotkey then
      local disabled = info and info.disabled and true or false
      if beginFirstPathPickerForHotkey(keyId, disabled) then
        return
      end
    end
    ctx.bblHotkeyKey = keyId
    ctx.bblEntrySel = 1
    ctx.bblEntryScroll = 0
    ctx.bblEntryFocusSlot = nil
    ctx.bblEntryListReturnState = "bbl_hotkeys"
    ctx.state = "bbl_hotkey_entries"
  end
  if (_.padEffective & _.PAD_TRIANGLE) ~= 0 then
    local keyId = hotkeys[ctx.bblHotkeySel]
    local info = keyId and hotkeySummary[keyId] or nil
    local canToggle = info and info.disabledSeen and true or false
    if keyId and canToggle and _.config_parse.setBblHotkeyDisabled then
      local rawDisabled = _.config_parse.isBblHotkeyDisabled(ctx.lines, keyId) and true or false
      local hasActivePath = (tonumber(info and info.activePathCount) or 0) > 0
      local effectiveDisabled = rawDisabled or (not hasActivePath)
      local targetDisabled = not effectiveDisabled
      local changed = _.config_parse.setBblHotkeyDisabled(ctx.lines, keyId, targetDisabled)
      if changed then
        ctx.configModified = true
        ctx.bblHotkeySummaryCache = nil
      end
    end
  end
  if ctx.configModified and (_.padEffective & _.PAD_START) ~= 0 then
    _.common.saveCurrentConfig(ctx)
  end
  if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
    ctx.state = "editor"
  end
end

return { run = run }
