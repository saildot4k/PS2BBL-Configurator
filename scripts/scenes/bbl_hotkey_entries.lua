--[[ Per-hotkey slots (E1..E10): name, path slots, enable/disable, remove. ]]

local actions_menu = dofile("scripts/scenes/actions_menu.lua")

local function isE1ExclusivePath(commonRef, pathVal, isFmcb)
  local p = (commonRef and commonRef.trimPathValue and commonRef.trimPathValue(pathVal)) or
      tostring(pathVal or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if p == "" then return false end
  if p:lower() == "cdrom" then return true end
  if commonRef and commonRef.isBblSpecialExclusivePath and commonRef.isBblSpecialExclusivePath(p) then
    return true
  end
  local up = p:upper()
  if up == "$CDVD" or up == "$CDVD_NO_PS2LOGO" or up == "$CREDITS" or up == "$HDDCHECKER" then
    return true
  end
  if isFmcb and (up == "OSDSYS" or up == "POWEROFF" or up == "FASTBOOT") then
    return true
  end
  return false
end

local function buildRows(_, ctx, keyId, maxEntries, includeNameRow)
  local rows = {}
  if includeNameRow then
    local nameVal = _.config_parse.getBblHotkeyName(ctx.lines, keyId) or ""
    rows[#rows + 1] = { kind = "name", nameVal = nameVal }
  end
  for i = 1, maxEntries do
    local slot = _.config_parse.getBblHotkeySlot(ctx.lines, keyId, i)
    if slot.used then
      rows[#rows + 1] = { kind = "entry", slot = i, data = slot }
    end
  end
  return rows
end

local function formatArgCount(n)
  local count = tonumber(n) or 0
  if count == 1 then
    return "(1 arg)"
  end
  return "(" .. tostring(count) .. " args)"
end

local function run(ctx)
  local _ = ctx._
  local returnState = ctx.bblEntryListReturnState or "bbl_hotkeys"
  if not ctx.lines then
    ctx.state = "editor"
    return
  end
  local keyId = ctx.bblHotkeyKey
  if not keyId or keyId == "" then
    ctx.state = returnState
    return
  end

  local isFmcb = (ctx.fileType == "freemcboot_cnf") or (ctx.context == "freehddboot")
  local maxEntries = isFmcb and ((_.config_options and _.config_options.FMCB_BBL_MAX_ENTRIES) or 3) or
      ((_.config_parse.getBblMaxEntries and _.config_parse.getBblMaxEntries()) or 10)
  local includeNameRow = not isFmcb
  local sceneEpoch = tonumber(ctx._sceneEpoch) or 0
  local function getRowsCache()
    local cache = ctx.bblHotkeyEntriesRowsCache
    if cache and cache.sceneEpoch == sceneEpoch and cache.linesRef == ctx.lines and
        cache.keyId == keyId and cache.maxEntries == maxEntries and cache.includeNameRow == includeNameRow then
      return cache
    end
    local keyDisabled = (_.config_parse.isBblHotkeyDisabled and _.config_parse.isBblHotkeyDisabled(ctx.lines, keyId)) and true or
        false
    local rows = buildRows(_, ctx, keyId, maxEntries, includeNameRow)
    local usedCount = 0
    for i = 1, #rows do
      if rows[i].kind == "entry" then
        usedCount = usedCount + 1
      end
    end
    cache = {
      sceneEpoch = sceneEpoch,
      linesRef = ctx.lines,
      keyId = keyId,
      maxEntries = maxEntries,
      includeNameRow = includeNameRow,
      keyDisabled = keyDisabled,
      rows = rows,
      usedCount = usedCount,
    }
    ctx.bblHotkeyEntriesRowsCache = cache
    return cache
  end
  local function invalidateRowsCache()
    ctx.bblHotkeyEntriesRowsCache = nil
  end
  local function markConfigMutated()
    invalidateRowsCache()
    ctx._configModifiedCache = nil
    ctx.configModified = true
  end
  local rowsCache = getRowsCache()
  local keyDisabled = rowsCache.keyDisabled and true or false
  local rows = rowsCache.rows or {}
  local usedCount = tonumber(rowsCache.usedCount) or 0
  local e1Slot = _.config_parse.getBblHotkeySlot and _.config_parse.getBblHotkeySlot(ctx.lines, keyId, 1) or nil
  local e1LocksAdditionalPaths = (e1Slot and e1Slot.pathExists and isE1ExclusivePath(_.common, e1Slot.path, isFmcb)) and
      true or false
  local function isEntryBlockedByE1(row)
    return row and row.kind == "entry" and e1LocksAdditionalPaths and (tonumber(row.slot) or 0) > 1
  end
  local canMoveEntries = (usedCount > 1) and (not e1LocksAdditionalPaths)
  local function clearMoveState()
    ctx.bblEntryGrab = nil
    ctx.bblEntryMoveSnapshot = nil
    ctx.bblEntryMoveSel = nil
  end
  local function beginMoveState()
    if ctx.bblEntryGrab then return end
    if _.common and _.common.cloneConfigLines then
      ctx.bblEntryMoveSnapshot = _.common.cloneConfigLines(ctx.lines)
    else
      ctx.bblEntryMoveSnapshot = nil
    end
    ctx.bblEntryMoveSel = ctx.bblEntrySel
    ctx.bblEntryGrab = true
  end
  local function confirmMoveState()
    clearMoveState()
  end
  local function cancelMoveState()
    if ctx.bblEntryMoveSnapshot then
      if _.common and _.common.cloneConfigLines then
        ctx.lines = _.common.cloneConfigLines(ctx.bblEntryMoveSnapshot)
      else
        ctx.lines = ctx.bblEntryMoveSnapshot
      end
      invalidateRowsCache()
      local restoredRows = buildRows(_, ctx, keyId, maxEntries, includeNameRow)
      if #restoredRows == 0 then
        restoredRows[#restoredRows + 1] = { kind = "empty" }
      end
      ctx.bblEntrySel = _.common.clampListSelection(ctx.bblEntryMoveSel or ctx.bblEntrySel, #restoredRows)
      _.common.refreshConfigModified(ctx)
    end
    clearMoveState()
  end
  if not canMoveEntries then
    confirmMoveState()
  end
  local canInsert = (usedCount < maxEntries) and (not e1LocksAdditionalPaths)
  if #rows == 0 then
    rows[#rows + 1] = { kind = "empty" }
  end

  if ctx.bblEntryFocusSlot then
    for i, row in ipairs(rows) do
      if row.kind == "entry" and row.slot == ctx.bblEntryFocusSlot then
        ctx.bblEntrySel = i
        break
      end
    end
    ctx.bblEntryFocusSlot = nil
  end

  ctx.bblEntrySel = ctx.bblEntrySel or 1
  if ctx.bblEntrySel < 1 then ctx.bblEntrySel = 1 end
  if ctx.bblEntrySel > #rows then ctx.bblEntrySel = #rows end
  ctx.bblEntryScroll = ctx.bblEntryScroll or 0

  if #rows > _.MAX_VISIBLE_LIST then
    ctx.bblEntryScroll = ctx.bblEntrySel - math.floor(_.MAX_VISIBLE_LIST / 2)
    ctx.bblEntryScroll = math.max(0, math.min(ctx.bblEntryScroll, #rows - _.MAX_VISIBLE_LIST))
  else
    ctx.bblEntryScroll = 0
  end
  local startY = _.MARGIN_Y + _.scaleY(50)
  if _.common and _.common.drawListScrollbar then
    _.common.drawListScrollbar(_, {
      totalRows = #rows,
      visibleRows = _.MAX_VISIBLE_LIST,
      scrollRows = ctx.bblEntryScroll,
      rowTopY = startY,
      rowHeight = _.LINE_H,
      color = _.DIM_COLOR,
    })
  end

  local titleSuffix = "- Launch Key"
  if keyId == "AUTO" then
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1, "AUTOBOOT " .. titleSuffix, _.WHITE)
  else
    local icon = _.common.getPadIcon(keyId)
    local baseIconW = _.common.PAD_ICON_W or 26
    local baseIconH = _.common.PAD_ICON_H or 26
    local textH = (_.common and _.common.FT_PIXEL_H) or 18
    local iconH = math.min(baseIconH, textH)
    local iconW = math.max(1, math.floor((baseIconW * iconH) / baseIconH + 0.5))
    local iconGap = 8
    local iconY = _.MARGIN_Y + math.floor(((_.LINE_H or iconH) - iconH) / 2)
    if icon then
      if _.Graphics.drawScaleImage then
        _.Graphics.drawScaleImage(icon, _.MARGIN_X, iconY, iconW, iconH)
      else
        _.Graphics.drawImage(icon, _.MARGIN_X, iconY)
      end
    end
    _.drawText(_.font, _.drawMode, _.MARGIN_X + iconW + iconGap, _.MARGIN_Y, 1, titleSuffix, _.WHITE)
  end
  local maxLabelW = (_.w or 640) - (_.MARGIN_X + 24) - _.MARGIN_X
  local nameNotDefined = _.common_str.name_not_defined or _.common_str.empty

  for i = ctx.bblEntryScroll + 1, math.min(ctx.bblEntryScroll + _.MAX_VISIBLE_LIST, #rows) do
    local row = rows[i]
    local y = startY + (i - ctx.bblEntryScroll - 1) * _.LINE_H
    local col = (i == ctx.bblEntrySel) and _.SELECTED_COLOR or _.UNSELECTED_COLOR
    local text = ""
    if row.kind == "name" then
      local disp = (row.nameVal ~= "" and row.nameVal) or nameNotDefined
      text = (_.menu_str.name or "Name: ") .. disp
      if keyDisabled then
        col = (i == ctx.bblEntrySel) and (_.SELECTED_DIM_COLOR or _.SELECTED_COLOR) or (_.DISABLED_DIM_COLOR or _.DIM_COLOR)
      end
    elseif row.kind == "entry" then
      local slot = row.data
      local p = _.common_str.not_set
      if slot.path ~= "" then
        p = _.common.formatDisplayPathWithCommands(_, slot.path)
      elseif slot.pathExists then
        p = _.common_str.empty
      end
      if isFmcb then
        text = p
      else
        text = p .. " " .. formatArgCount(slot.argCount)
      end
      if isEntryBlockedByE1(row) then
        col = (i == ctx.bblEntrySel) and (_.SELECTED_DIM_COLOR or _.SELECTED_COLOR) or (_.DISABLED_DIM_COLOR or _.DIM_COLOR)
      elseif keyDisabled or slot.disabled then
        col = (i == ctx.bblEntrySel) and (_.SELECTED_DIM_COLOR or _.SELECTED_COLOR) or (_.DISABLED_DIM_COLOR or _.DIM_COLOR)
      end
    elseif row.kind == "empty" then
      text = _.common_str.none or _.common_str.empty
    else
      text = (_.menu_str.add_entry_label or "Add") .. " path"
    end
    if _.common.fitListRowText then
      text = _.common.fitListRowText(ctx, "bbl_hotkey_entries_row_" .. tostring(i), _.font, text, maxLabelW,
        _.FONT_SCALE, i == ctx.bblEntrySel)
    elseif _.common.truncateTextToWidth then
      text = _.common.truncateTextToWidth(_.font, text, maxLabelW, _.FONT_SCALE)
    end
    if row.kind == "entry" and canMoveEntries and ctx.bblEntryGrab and i == ctx.bblEntrySel then
      text = "[" .. (_.menu_str.grabbed_tag or "Move") .. "] " .. text
    end
    _.drawListRow(_.MARGIN_X + 20, y, i == ctx.bblEntrySel, text, col)
  end

  local sel = rows[ctx.bblEntrySel]
  local isEntrySel = sel and sel.kind == "entry"
  local selBlockedByE1 = isEntryBlockedByE1(sel)
  local selectedEntryDisabled = isEntrySel and ((keyDisabled or (sel.data and sel.data.disabled)) and true or false) or false
  local canToggleSelectedEntry = isEntrySel and (not selBlockedByE1)
  local canOpenActions = sel and sel.kind ~= "name"
  local canCrossOpen = sel and (sel.kind ~= "empty" or canInsert)
  if selBlockedByE1 then
    canCrossOpen = false
  end
  local hint = {
    {
      pad = canCrossOpen and "cross" or "",
      label = canCrossOpen and
          (ctx.bblEntryGrab and (_.menu_str.confirm_label or "Confirm") or (_.menu_str.enter_label or "Enter")) or "",
      row = 1
    },
    {
      pad = canOpenActions and "square" or "",
      label = canOpenActions and (_.menu_str.actions_label or "Actions") or "",
      row = 1
    },
    {
      pad = ctx.configModified and "start" or "",
      label = ctx.configModified and (_.menu_str.save_config_label or "Save") or "",
      row = 1
    },
    {
      pad = canToggleSelectedEntry and "triangle" or "",
      label = canToggleSelectedEntry and
          (selectedEntryDisabled and (_.menu_str.enable_label or "Enable") or (_.menu_str.disable_label or "Disable")) or "",
      row = 1
    },
    {
      pad = "circle",
      label = ctx.bblEntryGrab and (_.menu_str.cancel_label or "Cancel") or (_.menu_str.back_label or "Back"),
      row = 1
    },
  }
  _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, hint, nil, _.DIM_COLOR, _.w - 2 * _.MARGIN_X)

  local function beginPathPickerForSlot(slotNum, slotDisabled, returnStateOverride)
    local sNum = tonumber(slotNum)
    if not sNum then return end
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
    ctx.pathPickerBblHotkeySlot = sNum
    ctx.pathPickerBblHotkeyDisabled = slotDisabled and true or false
    ctx.pathPickerReturnState = returnStateOverride or "bbl_hotkey_entries"
    if ctx.pathPickerReturnState == "bbl_hotkey_entry" then
      ctx.bblEntrySlot = sNum
      ctx.bblEntryDetailSel = 1
      ctx.bblEntryDetailReturnState = "bbl_hotkey_entries"
    end
    ctx.pathPickerContext = "path_only"
    ctx.pathPickerSub = "device"
    ctx.pathList = _.file_selector.getDevices("path_only", { fileType = ctx.fileType }) or {}
    ctx.pathPickerSel = 1
    ctx.pathPickerScroll = 0
    ctx.pathBrowsePath = nil
    ctx.state = "path_picker"
  end

  local function insertEntryBelowSelected()
    if not canInsert then return end
    local belowSlot = 0
    if sel and sel.kind == "entry" then
      belowSlot = sel.slot
    end
    local newSlot = _.config_parse.insertBblHotkeySlotBelow(ctx.lines, keyId, belowSlot, maxEntries)
    if newSlot then
      markConfigMutated()
      confirmMoveState()
      if isFmcb then
        local inserted = _.config_parse.getBblHotkeySlot and _.config_parse.getBblHotkeySlot(ctx.lines, keyId, newSlot) or
            nil
        local inheritedDisabled = (inserted and inserted.disabled) or keyDisabled
        beginPathPickerForSlot(newSlot, inheritedDisabled, "bbl_hotkey_entries")
      else
        -- For BBL (non-FreeBoot), choose path first, then land on path/args detail.
        local inserted = _.config_parse.getBblHotkeySlot and _.config_parse.getBblHotkeySlot(ctx.lines, keyId, newSlot) or
            nil
        local inheritedDisabled = (inserted and inserted.disabled) or keyDisabled
        beginPathPickerForSlot(newSlot, inheritedDisabled, "bbl_hotkey_entry")
      end
    end
  end

  local function insertFirstEntryAndChoosePath()
    if not canInsert then return end
    local newSlot = _.config_parse.insertBblHotkeySlotBelow(ctx.lines, keyId, 0, maxEntries)
    if not newSlot then return end
    markConfigMutated()
    confirmMoveState()
    local inserted = _.config_parse.getBblHotkeySlot and _.config_parse.getBblHotkeySlot(ctx.lines, keyId, newSlot) or nil
    local inheritedDisabled = (inserted and inserted.disabled) or keyDisabled
    beginPathPickerForSlot(newSlot, inheritedDisabled, isFmcb and "bbl_hotkey_entries" or "bbl_hotkey_entry")
  end

  local function removeSelectedEntry()
    if not (sel and sel.kind == "entry") then return end
    local removed = _.config_parse.removeBblHotkeySlot(ctx.lines, keyId, sel.slot)
    if removed then
      markConfigMutated()
      confirmMoveState()
    end
  end

  local function moveSelectedEntry(step)
    if not (sel and sel.kind == "entry" and canMoveEntries) then return end
    local dst = sel.slot + step
    if dst < 1 or dst > maxEntries then return end
    _.config_parse.swapBblHotkeySlots(ctx.lines, keyId, sel.slot, dst)
    markConfigMutated()
    ctx.bblEntryFocusSlot = dst
  end

  if ctx.bblEntryActionsOpen then
    local actionRows = {}
    if isEntrySel and canMoveEntries then
      actionRows[#actionRows + 1] = {
        id = "grab",
        label = ctx.bblEntryGrab and (_.menu_str.cancel_move_label or "Cancel move") or
            (_.menu_str.grab_label or "Move"),
      }
    end
    if isEntrySel then
      actionRows[#actionRows + 1] = { id = "remove", label = (_.menu_str.remove_label or "Remove") }
    end
    if canInsert and sel and sel.kind ~= "name" then
      actionRows[#actionRows + 1] = { id = "insert", label = (_.menu_str.insert_label or "Insert") }
    end
    if actions_menu.run(ctx, {
          openKey = "bblEntryActionsOpen",
          selKey = "bblEntryActionsSel",
          scrollKey = "bblEntryActionsScroll",
          title = (_.menu_str.actions_title or "Actions"),
          rows = actionRows,
          rowStateKeyPrefix = "bbl_hotkey_entries_actions_row_",
          onSelect = function(row)
            if row.id == "grab" then
              if ctx.bblEntryGrab then
                cancelMoveState()
              else
                beginMoveState()
              end
            elseif row.id == "insert" then
              insertEntryBelowSelected()
            elseif row.id == "remove" then
              removeSelectedEntry()
            end
          end,
        }) then
      return
    end
  end

  if (_.padEffective & _.PAD_UP) ~= 0 then
    if ctx.bblEntryGrab and isEntrySel then
      moveSelectedEntry(-1)
    else
      ctx.bblEntrySel = _.common.moveListSelection(ctx.bblEntrySel, #rows, -1, { ctx = ctx })
    end
  end
  if (_.padEffective & _.PAD_DOWN) ~= 0 then
    if ctx.bblEntryGrab and isEntrySel then
      moveSelectedEntry(1)
    else
      ctx.bblEntrySel = _.common.moveListSelection(ctx.bblEntrySel, #rows, 1, { ctx = ctx })
    end
  end

  if (_.padEffective & _.PAD_CROSS) ~= 0 then
    if ctx.bblEntryGrab then
      confirmMoveState()
      return
    end
    if sel.kind == "name" then
      -- For empty BBL launch keys, choose ELF path first (device picker) before naming.
      if (not isFmcb) and usedCount == 0 and canInsert then
        insertFirstEntryAndChoosePath()
        return
      end
      local currentName = _.config_parse.getBblHotkeyName(ctx.lines, keyId) or ""
      local prompt = "NAME_" .. keyId
      local initialValue = currentName
      local onSubmit = function(val)
        _.config_parse.setBblHotkeyName(ctx.lines, keyId, val or "")
        markConfigMutated()
        ctx.state = "bbl_hotkey_entries"
      end
      _.common.beginTextInput(ctx, {
        titleIdMode = nil,
        prompt = prompt,
        value = initialValue,
        maxLen = 64,
        callback = onSubmit,
        returnState = "bbl_hotkey_entries",
        gridSel = 1,
        cursor = #initialValue + 1,
        scroll = 1,
        state = "text_input",
      })
    elseif sel.kind == "entry" then
      if selBlockedByE1 then
        -- E1-exclusive commands lock later slots from editing.
        return
      end
      if isFmcb then
        -- FreeMCBoot/FreeHDBoot launch-key entries are path-only, so go straight to device select.
        beginPathPickerForSlot(sel.slot, ((sel.data and sel.data.disabled) and true or false) or keyDisabled)
      else
        ctx.bblEntrySlot = sel.slot
        ctx.bblEntryDetailSel = 1
        ctx.bblEntryDetailReturnState = "bbl_hotkey_entries"
        ctx.state = "bbl_hotkey_entry"
      end
    elseif sel.kind == "empty" and canInsert then
      insertEntryBelowSelected()
    end
  end

  local function toggleSelectedEntryDisabled()
    if sel and sel.kind == "entry" and not isEntryBlockedByE1(sel) then
      local changed = false
      local effectiveDisabled = (keyDisabled or (sel.data and sel.data.disabled)) and true or false
      if keyDisabled and effectiveDisabled and _.config_parse.enableBblHotkeySlotFromDisabledParent then
        changed = _.config_parse.enableBblHotkeySlotFromDisabledParent(ctx.lines, keyId, sel.slot) and true or false
      else
        changed = _.config_parse.setBblHotkeySlotDisabled and
            _.config_parse.setBblHotkeySlotDisabled(ctx.lines, keyId, sel.slot, not sel.data.disabled) or false
      end
      if changed then
        markConfigMutated()
      end
    end
  end
  if (_.padEffective & _.PAD_TRIANGLE) ~= 0 then
    toggleSelectedEntryDisabled()
  end
  if canOpenActions and (_.padEffective & _.PAD_SQUARE) ~= 0 then
    _.common.openActionsMenu(ctx, "bblEntryActionsOpen", "bblEntryActionsSel", "bblEntryActionsScroll")
  end
  if ctx.configModified and (_.padEffective & _.PAD_START) ~= 0 then
    _.common.saveCurrentConfig(ctx)
  end
  if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
    if ctx.bblEntryGrab then
      cancelMoveState()
      return
    end
    ctx.state = returnState
    ctx.bblEntryListReturnState = nil
    ctx.bblEntryDetailReturnState = nil
  end
end

return { run = run }
