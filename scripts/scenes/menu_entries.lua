--[[ Menu entries list (OSDMENU). ]]

local actions_menu = dofile("scripts/scenes/actions_menu.lua")

local function buildEntryNameMap(lines)
  local out = {}
  for i = 1, #(lines or {}) do
    local entry = lines[i]
    local key = entry and entry.key
    if key then
      local idx = key:match("^name_OSDSYS_ITEM_(%d+)$")
      if idx then
        local n = tonumber(idx)
        if n and out[n] == nil then
          out[n] = entry.value or ""
        end
      end
    end
  end
  return out
end

local function buildEntryPathPresenceMap(lines)
  local out = {}
  for i = 1, #(lines or {}) do
    local entry = lines[i]
    local key = entry and entry.key
    if key then
      local idx = key:match("^path%d+_OSDSYS_ITEM_(%d+)$")
      if idx then
        local n = tonumber(idx)
        local value = tostring((entry and entry.value) or "")
        value = value:gsub("^%s+", ""):gsub("%s+$", "")
        if n and value ~= "" then
          out[n] = true
        end
      end
    end
  end
  return out
end

local function buildEntryActivePathPresenceMap(lines, entryDisabledByIdx)
  local out = {}
  for i = 1, #(lines or {}) do
    local entry = lines[i]
    local key = entry and entry.key
    if key and (not entry.comment) then
      local idx = key:match("^path%d+_OSDSYS_ITEM_(%d+)$")
      if idx then
        local n = tonumber(idx)
        local value = tostring((entry and entry.value) or "")
        value = value:gsub("^%s+", ""):gsub("%s+$", "")
        if n and value ~= "" and (not (entryDisabledByIdx and entryDisabledByIdx[n])) then
          out[n] = true
        end
      end
    end
  end
  return out
end

local function buildEntrySeparatorMap(_, nameByIdx)
  local out = {}
  for idx, name in pairs(nameByIdx or {}) do
    if _.config_parse.isMenuEntrySeparatorName and _.config_parse.isMenuEntrySeparatorName(name) then
      out[idx] = true
    end
  end
  return out
end

local function run(ctx)
  local _ = ctx._
  local formatBelForDisplay = (_.common and _.common.formatBelForDisplay) or function(text)
    return tostring(text or ""):gsub(string.char(7), "\226\150\161")
  end
  if not ctx.lines then
    ctx.state = "editor"
    return
  end
  local supportsSeparators = (ctx.fileType == "osdmenu_cnf")

  local sceneEpoch = ctx._sceneEpoch or 0
  local function getMenuEntriesCache()
    local cache = ctx.menuEntriesCache
    if not cache or cache.linesRef ~= ctx.lines or cache.sceneEpoch ~= sceneEpoch then
      local entryList = _.config_parse.getMenuEntryIndices(ctx.lines)
      local entryDisabledByIdx = {}
      for i = 1, #entryList do
        local ent = entryList[i]
        if ent and ent.idx then
          entryDisabledByIdx[ent.idx] = ent.disabled and true or false
        end
      end
      local entryNameByIdx = buildEntryNameMap(ctx.lines)
      cache = {
        linesRef = ctx.lines,
        sceneEpoch = sceneEpoch,
        entryList = entryList,
        entryNameByIdx = entryNameByIdx,
        entryHasPathByIdx = buildEntryPathPresenceMap(ctx.lines),
        entryHasActivePathByIdx = buildEntryActivePathPresenceMap(ctx.lines, entryDisabledByIdx),
        entryIsSeparatorByIdx = supportsSeparators and buildEntrySeparatorMap(_, entryNameByIdx) or {},
      }
      ctx.menuEntriesCache = cache
    end
    return cache
  end
  local function invalidateMenuEntriesCache()
    ctx.menuEntriesCache = nil
  end
  local function markConfigMutated()
    invalidateMenuEntriesCache()
    ctx._configModifiedCache = nil
    ctx.configModified = true
  end

  local function refreshEntries()
    local cache = getMenuEntriesCache()
    ctx.entryList = cache.entryList or {}
    if #ctx.entryList == 0 then
      ctx.entrySel = 1
      ctx.menuEntryGrab = nil
    elseif ctx.entrySel < 1 then
      ctx.entrySel = 1
    elseif ctx.entrySel > #ctx.entryList then
      ctx.entrySel = #ctx.entryList
    end
    if #ctx.entryList <= 1 then
      ctx.menuEntryGrab = nil
    end
  end

  local function clearMoveState()
    ctx.menuEntryGrab = nil
    ctx.menuEntryMoveSnapshot = nil
    ctx.menuEntryMoveSel = nil
  end

  local function beginMoveState()
    if ctx.menuEntryGrab then return end
    if _.common and _.common.cloneConfigLines then
      ctx.menuEntryMoveSnapshot = _.common.cloneConfigLines(ctx.lines)
    else
      ctx.menuEntryMoveSnapshot = nil
    end
    ctx.menuEntryMoveSel = ctx.entrySel
    ctx.menuEntryGrab = true
  end

  local function confirmMoveState()
    clearMoveState()
  end

  local function cancelMoveState()
    if ctx.menuEntryMoveSnapshot then
      if _.common and _.common.cloneConfigLines then
        ctx.lines = _.common.cloneConfigLines(ctx.menuEntryMoveSnapshot)
      else
        ctx.lines = ctx.menuEntryMoveSnapshot
      end
      invalidateMenuEntriesCache()
      refreshEntries()
      ctx.entrySel = _.common.clampListSelection(ctx.menuEntryMoveSel or ctx.entrySel, #ctx.entryList)
      _.common.refreshConfigModified(ctx)
    end
    clearMoveState()
  end

  local function saveFromMenuEntries()
    _.common.saveCurrentConfig(ctx, {
      allowChoose = (ctx.fileType == "osdmenu_cnf"),
      beforeChooseSave = function()
        ctx.returnToMenuEntriesAfterSave = true
      end,
      beforeSave = function()
        invalidateMenuEntriesCache()
      end,
    })
  end

  local function openPathPickerForEntry(entryIdx)
    local idx = tonumber(entryIdx)
    if not idx then return end
    local pickerContext = ((ctx.fileType == "freemcboot_cnf") or (ctx.context == "freehddboot")) and "fmcb_entry" or
        "osdmenu"
    ctx.editKey = nil
    ctx.pathPickerForEntryIdx = idx
    ctx.pathPickerBootKey = nil
    ctx.pathPickerBootKeyDisabled = nil
    ctx.pathPickerBblHotkeyKey = nil
    ctx.pathPickerBblHotkeySlot = nil
    ctx.pathPickerBblHotkeyDisabled = nil
    ctx.pathPickerBblIrxIdx = nil
    ctx.pathPickerBblIrxDisabled = nil
    ctx.pathPickerTarget = nil
    ctx.pathPickerFileExts = nil
    ctx.pathPickerEditIdx = nil
    ctx.pathPickerInsertBelow = nil
    ctx.pathPickerSub = "device"
    ctx.pathList = _.file_selector.getDevices(pickerContext) or {}
    ctx.pathPickerSel = 1
    ctx.pathPickerScroll = 0
    ctx.pathPickerContext = pickerContext
    ctx.pathPickerReturnState = "menu_entry_edit"
    ctx.state = "path_picker"
  end

  local function focusEntryByIdx(entryIdx)
    local idx = tonumber(entryIdx)
    if not idx then return end
    for pos, ent in ipairs(ctx.entryList or {}) do
      if ent and ent.idx == idx then
        ctx.entrySel = pos
        return
      end
    end
  end

  local function openSeparatorNameInput(entryIdx)
    if not supportsSeparators then return false end
    local idx = tonumber(entryIdx)
    if not idx then return false end
    local currentNameRaw = _.config_parse.getMenuEntryName(ctx.lines, idx) or ""
    local currentNameDisplay = currentNameRaw
    if _.config_parse.getMenuEntrySeparatorText and _.config_parse.isMenuEntrySeparatorName and
        _.config_parse.isMenuEntrySeparatorName(currentNameRaw) then
      currentNameDisplay = _.config_parse.getMenuEntrySeparatorText(currentNameRaw) or ""
    end
    if currentNameDisplay == _.menu_str.add_entry_label then currentNameDisplay = "" end
    local allowBelKey = (ctx.fileType == "freemcboot_cnf" or ctx.fileType == "osdmenu_cnf")
    local prompt = _.menu_str.entry_name_prompt
    local initialValue = currentNameDisplay
    local maxLen = _.config_parse.LIMIT_NAME
    _.common.configureBelTextInput(ctx, {
      allow = allowBelKey,
      context = ctx.context,
    })
    local onSubmit = function(val)
      local nameText = tostring(val or "")
      if nameText:sub(1, 2) == "$!" then
        nameText = nameText:sub(3)
      end
      _.config_parse.setMenuEntryName(ctx.lines, idx, "$!" .. nameText)
      _.config_parse.setMenuEntryPaths(ctx.lines, idx, {})
      _.config_parse.setMenuEntryArgs(ctx.lines, idx, {})
      markConfigMutated()
      refreshEntries()
      focusEntryByIdx(idx)
      ctx.state = "menu_entries"
    end
    _.common.beginTextInput(ctx, {
      titleIdMode = nil,
      prompt = prompt,
      value = initialValue,
      maxLen = maxLen,
      callback = onSubmit,
      returnState = "menu_entries",
      gridSel = 1,
      cursor = #initialValue + 1,
      scroll = 1,
      state = "text_input",
    })
    return true
  end

  local function insertBelowSelection(canAddEntry, total, directPicker, insertName)
    if not canAddEntry then return end
    local belowIdx = (total == 0) and 0 or ctx.entryList[ctx.entrySel].idx
    local newIdx = _.config_parse.insertMenuEntryBelow(ctx.lines, belowIdx, insertName or "")
    if not newIdx then return end
    local insertedIsSeparator = supportsSeparators and _.config_parse.isMenuEntrySeparatorName and
        _.config_parse.isMenuEntrySeparatorName(insertName or "")
    if insertedIsSeparator then
      _.config_parse.setMenuEntryPaths(ctx.lines, newIdx, {})
      _.config_parse.setMenuEntryArgs(ctx.lines, newIdx, {})
    end
    markConfigMutated()
    refreshEntries()
    ctx.entrySel = (total == 0) and 1 or math.min(ctx.entrySel + 1, #ctx.entryList)
    ctx.entryIdx = newIdx
    ctx.entryEditSub = 1
    confirmMoveState()
    if insertedIsSeparator then
      openSeparatorNameInput(newIdx)
      return
    end
    if directPicker then
      openPathPickerForEntry(newIdx)
    else
      ctx.state = "menu_entry_edit"
    end
  end

  local function insertSeparatorBelowSelection(canAddEntry, total)
    if not supportsSeparators or not canAddEntry then return end
    local belowIdx = (total == 0) and 0 or ctx.entryList[ctx.entrySel].idx
    local newIdx = _.config_parse.insertMenuEntryBelow(ctx.lines, belowIdx, "$!")
    if not newIdx then return end
    _.config_parse.setMenuEntryPaths(ctx.lines, newIdx, {})
    _.config_parse.setMenuEntryArgs(ctx.lines, newIdx, {})
    markConfigMutated()
    refreshEntries()
    ctx.entrySel = (total == 0) and 1 or math.min(ctx.entrySel + 1, #ctx.entryList)
    ctx.entryIdx = newIdx
    ctx.entryEditSub = 1
    confirmMoveState()
    if not openSeparatorNameInput(newIdx) then
      ctx.state = "menu_entry_edit"
    end
  end

  refreshEntries()
  local cache = getMenuEntriesCache()
  local entryNameByIdx = cache.entryNameByIdx or {}
  local entryHasPathByIdx = cache.entryHasPathByIdx or {}
  local entryHasActivePathByIdx = cache.entryHasActivePathByIdx or {}
  local entryIsSeparatorByIdx = cache.entryIsSeparatorByIdx or {}
  local startY = _.MARGIN_Y + _.scaleY(50)
  local total = #ctx.entryList
  local canMoveEntries = total > 1
  if not canMoveEntries then
    confirmMoveState()
  end
  local isFmcb = (ctx.fileType == "freemcboot_cnf")
  local maxEntries = (isFmcb and ((_.config_options and _.config_options.FMCB_MAX_ENTRIES) or 99)) or nil
  local canAddEntry = (not isFmcb) or (total < maxEntries)

  _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1, _.menu_str.edit_menu_entries, _.WHITE)

  local maxVis = _.MAX_VISIBLE_LIST
  if total > maxVis then
    ctx.entryScroll = ctx.entrySel - math.floor(maxVis / 2)
    ctx.entryScroll = math.max(0, math.min(ctx.entryScroll, total - maxVis))
  else
    ctx.entryScroll = 0
  end
  if _.common and _.common.drawListScrollbar then
    _.common.drawListScrollbar(_, {
      totalRows = total,
      visibleRows = maxVis,
      scrollRows = ctx.entryScroll,
      rowTopY = startY,
      rowHeight = _.LINE_H,
      color = _.DIM_COLOR,
    })
  end

  local maxLabelW = (_.w or 640) - (_.MARGIN_X + 20) - _.MARGIN_X
  local missingNameLabel = _.common_str.name_not_defined or _.common_str.empty
  local missingPathLabel = _.common_str.path_not_defined or _.common_str.empty
  local separatorSuffix = _.menu_str.separator_suffix or "(separator)"
  for i = ctx.entryScroll + 1, math.min(ctx.entryScroll + maxVis, total) do
    local ent = ctx.entryList[i]
    local idx = ent.idx
    local name = entryNameByIdx[idx]
    local isSeparator = entryIsSeparatorByIdx[idx] == true
    local hasName = (name ~= nil and name ~= "")
    local hasPath = (entryHasPathByIdx[idx] == true)
    local hasActivePath = (entryHasActivePathByIdx[idx] == true)
    local usesPlaceholder = false
    local label
    if isSeparator then
      local sepText = (_.config_parse.getMenuEntrySeparatorText and _.config_parse.getMenuEntrySeparatorText(name)) or ""
      if sepText ~= "" then
        label = sepText .. " " .. separatorSuffix
      else
        label = separatorSuffix
      end
    elseif not hasName and not hasPath then
      label = _.common_str.empty
      usesPlaceholder = true
    elseif not hasName then
      label = missingNameLabel
      usesPlaceholder = true
    elseif not hasPath then
      label = missingPathLabel
      usesPlaceholder = true
    else
      label = name or (_.menu_str.item .. idx)
    end
    if canMoveEntries and ctx.menuEntryGrab and i == ctx.entrySel then
      label = "[" .. (_.menu_str.grabbed_tag or "Move") .. "] " .. label
    end
    label = formatBelForDisplay(label)
    local y = startY + (i - ctx.entryScroll - 1) * _.LINE_H
    local col = (i == ctx.entrySel) and _.SELECTED_COLOR or _.UNSELECTED_COLOR
    local effectiveDisabled = ent.disabled or ((not isSeparator) and (not hasActivePath))
    if usesPlaceholder then
      col = (i == ctx.entrySel) and _.SELECTED_COLOR or _.DIM_COLOR
    end
    if effectiveDisabled then
      col = (i == ctx.entrySel) and (_.SELECTED_DIM_COLOR or _.SELECTED_COLOR) or (_.DISABLED_DIM_COLOR or _.DIM_COLOR)
    end
    if _.common.fitListRowText then
      label = _.common.fitListRowText(ctx, "menu_entries_row_" .. tostring(i), _.font, label, maxLabelW, _.FONT_SCALE,
        i == ctx.entrySel)
    elseif _.common.truncateTextToWidth then
      label = _.common.truncateTextToWidth(_.font, label, maxLabelW, _.FONT_SCALE)
    end
    _.drawListRow(_.MARGIN_X + 20, y, i == ctx.entrySel, label, col)
  end

  local hasSelection = (ctx.entrySel >= 1 and ctx.entrySel <= total)
  local canCrossOpen = hasSelection or canAddEntry
  local selectedIdx = hasSelection and ctx.entryList[ctx.entrySel].idx or nil
  local selectedIsSeparator = selectedIdx and (entryIsSeparatorByIdx[selectedIdx] == true) or false
  local selectedHasActivePath = selectedIdx and (entryHasActivePathByIdx[selectedIdx] == true) or false
  local selectedDisabled = hasSelection and
      (ctx.entryList[ctx.entrySel].disabled or ((not selectedIsSeparator) and (not selectedHasActivePath))) or false
  local hintItems = {
    {
      pad = canCrossOpen and "cross" or "",
      label = canCrossOpen and
          (hasSelection and (ctx.menuEntryGrab and (_.menu_str.confirm_label or "Confirm") or (_.menu_str.enter_label or "Enter")) or
            (_.menu_str.edit_label or "Edit")) or "",
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
      label = hasSelection and (selectedDisabled and (_.menu_str.enable_label or "Enable") or (_.menu_str.disable_label or "Disable")) or "",
      row = 1
    },
    {
      pad = "circle",
      label = ctx.menuEntryGrab and (_.menu_str.cancel_label or "Cancel") or (_.menu_str.back_label or "Back"),
      row = 1
    },
  }
  _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, hintItems, nil, _.DIM_COLOR, _.w - 2 * _.MARGIN_X)

  if ctx.menuEntriesActionsOpen then
    local actionRows = {}
    if hasSelection and canMoveEntries then
      actionRows[#actionRows + 1] = {
        id = "grab",
        label = ctx.menuEntryGrab and (_.menu_str.cancel_move_label or "Cancel move") or (_.menu_str.grab_label or "Move"),
      }
    end
    if canAddEntry then
      actionRows[#actionRows + 1] = { id = "insert", label = (_.menu_str.insert_label or "Insert") }
      if supportsSeparators then
        actionRows[#actionRows + 1] = {
          id = "insert_separator",
          label = (_.menu_str.insert_separator_label or "Insert separator")
        }
      end
    end
    if hasSelection then
      actionRows[#actionRows + 1] = { id = "remove", label = (_.menu_str.remove_label or "Remove") }
    end
    if actions_menu.run(ctx, {
          openKey = "menuEntriesActionsOpen",
          selKey = "menuEntriesActionsSel",
          scrollKey = "menuEntriesActionsScroll",
          title = (_.menu_str.actions_title or "Actions"),
          rows = actionRows,
          rowStateKeyPrefix = "menu_entries_actions_row_",
          onSelect = function(row)
            if row.id == "grab" then
              if ctx.menuEntryGrab then
                cancelMoveState()
              else
                beginMoveState()
              end
            elseif row.id == "insert" then
              insertBelowSelection(canAddEntry, total)
            elseif row.id == "insert_separator" then
              insertSeparatorBelowSelection(canAddEntry, total)
            elseif row.id == "remove" and hasSelection then
              local idx = ctx.entryList[ctx.entrySel].idx
              _.config_parse.removeMenuEntry(ctx.lines, idx)
              markConfigMutated()
              refreshEntries()
            end
          end,
        }) then
      return
    end
  end

  if (_.padEffective & _.PAD_UP) ~= 0 then
    if ctx.menuEntryGrab and hasSelection and ctx.entrySel > 1 then
      local curIdx = ctx.entryList[ctx.entrySel].idx
      local prevIdx = ctx.entryList[ctx.entrySel - 1].idx
      if _.config_parse.swapMenuEntryContent(ctx.lines, curIdx, prevIdx) then
        markConfigMutated()
        refreshEntries()
        ctx.entrySel = ctx.entrySel - 1
      end
    else
      ctx.entrySel = _.common.moveListSelection(ctx.entrySel, total, -1, { ctx = ctx })
    end
  end
  if (_.padEffective & _.PAD_DOWN) ~= 0 then
    if ctx.menuEntryGrab and hasSelection and ctx.entrySel < total then
      local curIdx = ctx.entryList[ctx.entrySel].idx
      local nextIdx = ctx.entryList[ctx.entrySel + 1].idx
      if _.config_parse.swapMenuEntryContent(ctx.lines, curIdx, nextIdx) then
        markConfigMutated()
        refreshEntries()
        ctx.entrySel = ctx.entrySel + 1
      end
    else
      ctx.entrySel = _.common.moveListSelection(ctx.entrySel, total, 1, { ctx = ctx })
    end
  end

  if (_.padEffective & _.PAD_TRIANGLE) ~= 0 and hasSelection then
    local ent = ctx.entryList[ctx.entrySel]
    local idx = ent.idx
    local currentDisabled = _.config_parse.isMenuEntryDisabled(ctx.lines, idx) and true or false
    local targetDisabled = not (selectedDisabled and true or false)
    -- If entry is effectively disabled only because all child paths are disabled,
    -- a single triangle press should still enable parent + children.
    local shouldApply = (currentDisabled ~= targetDisabled) or
        (selectedDisabled and (not currentDisabled) and (not targetDisabled))
    if shouldApply then
      _.config_parse.setMenuEntryDisabled(ctx.lines, idx, targetDisabled)
      markConfigMutated()
      refreshEntries()
    end
  end

  if (_.padEffective & _.PAD_CROSS) ~= 0 then
    if hasSelection then
      if ctx.menuEntryGrab then
        confirmMoveState()
        return
      end
      local selectedIdx = ctx.entryList[ctx.entrySel].idx
      if supportsSeparators and entryIsSeparatorByIdx[selectedIdx] == true then
        if openSeparatorNameInput(selectedIdx) then
          return
        end
      end
      ctx.entryIdx = selectedIdx
      ctx.entryEditSub = 1
      ctx.state = "menu_entry_edit"
    elseif canAddEntry then
      insertBelowSelection(canAddEntry, total, true)
    end
  end

  if (_.padEffective & _.PAD_SQUARE) ~= 0 then
    _.common.openActionsMenu(ctx, "menuEntriesActionsOpen", "menuEntriesActionsSel", "menuEntriesActionsScroll")
  end

  if ctx.configModified and (_.padEffective & _.PAD_START) ~= 0 then
    saveFromMenuEntries()
  end

  if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
    if ctx.menuEntryGrab then
      cancelMoveState()
      return
    end
    ctx.state = "editor"
  end
end

return { run = run }
