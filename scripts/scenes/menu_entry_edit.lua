--[[ Single menu entry edit (name, paths, args, delete). ]]

local actions_menu = dofile("scripts/scenes/actions_menu.lua")

local function run(ctx)
  local _ = ctx._
  local formatBelForDisplay = (_.common and _.common.formatBelForDisplay) or function(text)
    return tostring(text or ""):gsub(string.char(7), "\226\150\161")
  end
  if not ctx.lines or not ctx.entryIdx then
    ctx.state = "menu_entries"; ctx.entryIdx = nil; return
  end
  local name = _.config_parse.getMenuEntryName(ctx.lines, ctx.entryIdx) or ""
  local paths = _.config_parse.getMenuEntryPaths(ctx.lines, ctx.entryIdx)
  local args = _.config_parse.getMenuEntryArgs(ctx.lines, ctx.entryIdx)
  local function hasUsablePathValue(pathVal)
    local s = tostring(pathVal or "")
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    return s ~= "", s
  end
  local function pathLabel(p)
    if p == "" then return _.common_str.empty end
    if p == "cdrom" then return _.dev_str.launch_disc end
    if p == "dvd" then return _.dev_str.dvd_player end
    if (p or ""):upper() == "$HOSDSYS" then return _.dev_str.hosdsys end
    if (p or ""):upper() == "$PSBBN" then return _.dev_str.psbbn end
    if p == "OSDSYS" or p == "osdsys" then return _.dev_str.osd end
    if p == "POWEROFF" or p == "poweroff" then return _.dev_str.shutdown end
    if _.common and _.common.normalizePathForDisplay then
      return _.common.normalizePathForDisplay(p)
    end
    return p
  end
  local isFmcbEntry = (ctx.fileType == "freemcboot_cnf") or (ctx.context == "freehddboot")
  local isSeparatorEntry = (not isFmcbEntry) and _.config_parse.isMenuEntrySeparatorName and
      _.config_parse.isMenuEntrySeparatorName(name)
  local parentEntryDisabled = isFmcbEntry and _.config_parse.isMenuEntryDisabled and
      (_.config_parse.isMenuEntryDisabled(ctx.lines, ctx.entryIdx) and true or false) or false
  local separatorText = nil
  if isSeparatorEntry and _.config_parse.getMenuEntrySeparatorText then
    separatorText = _.config_parse.getMenuEntrySeparatorText(name) or ""
  end
  local nameDisplay = (separatorText ~= nil) and separatorText or name
  local hasOsdOrShutdown = false
  local allowArgs = (not isFmcbEntry) and (not isSeparatorEntry)
  for _, p in ipairs(paths) do
    local pv = type(p) == "table" and p.value or p
    if (pv or ""):upper() == "OSDSYS" or (pv or ""):upper() == "POWEROFF" then
      hasOsdOrShutdown = true; break
    end
  end
  local fmcbMaxPaths = 0
  local fmcbPaths = {}
  if isFmcbEntry then
    fmcbMaxPaths = (_.config_options and _.config_options.FMCB_MAX_PATHS_PER_ENTRY) or 3
    if fmcbMaxPaths < 1 then fmcbMaxPaths = 3 end
    if fmcbMaxPaths > 3 then fmcbMaxPaths = 3 end
    for i = 1, #paths do
      local item = paths[i]
      local pathVal = type(item) == "table" and item.value or item
      local hasValue, normalizedVal = hasUsablePathValue(pathVal)
      if hasValue then
        local rowItem = {
          value = normalizedVal,
          disabled = type(item) == "table" and (item.disabled and true or false) or false
        }
        if type(item) == "table" and item.comment ~= nil then
          rowItem.comment = item.comment
        end
        fmcbPaths[#fmcbPaths + 1] = rowItem
      end
    end
  end
  local subRows = {}
  subRows[#subRows + 1] = { id = "edit_name", kind = "name", label = _.menu_str.edit_name }
  local function appendPathRows()
    for i = 1, fmcbMaxPaths do
      local item = fmcbPaths[i]
      local hasValue = item ~= nil
      local valueText = hasValue and pathLabel(item.value or "") or (_.common_str.not_set or _.common_str.empty)
      subRows[#subRows + 1] = {
        id = "path_" .. tostring(i),
        kind = "path",
        pathIndex = i,
        hasValue = hasValue,
        disabled = hasValue and item.disabled or false,
        label = valueText,
      }
    end
  end
  if isFmcbEntry then
    appendPathRows()
  elseif not isSeparatorEntry then
    subRows[#subRows + 1] = { id = "paths", kind = "paths", label = _.menu_str.paths_label }
  end
  local hasCdrom = false
  for _, p in ipairs(paths) do
    local pv = type(p) == "table" and p.value or p
    if pv == "cdrom" then
      hasCdrom = true; break
    end
  end
  local hasCdromPathConflict = hasCdrom and (#paths > 1)
  if allowArgs and hasCdrom then
    subRows[#subRows + 1] = { id = "launch_disc_options", kind = "launch_disc_options", label = _.menu_str.launch_disc_options }
  end
  if allowArgs and not (hasOsdOrShutdown or hasCdrom) then
    subRows[#subRows + 1] = { id = "arguments", kind = "arguments", label = _.menu_str.arguments }
  end
  local pathsStr = _.menu_str.paths .. (#paths == 0 and _.menu_str.none or #paths .. _.menu_str.path_s)
  local argsStr = _.menu_str.args ..
      ((not allowArgs or hasOsdOrShutdown) and _.menu_str.none or
      (#args == 0 and _.menu_str.none or #args .. _.menu_str.arg_s))
  local summaryStr = pathsStr
  if allowArgs then
    summaryStr = pathsStr .. ", " .. argsStr
  end
  _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1, _.menu_str.entry_index .. ctx.entryIdx, _.WHITE)
  _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y + _.scaleY(24), 0.8,
    _.menu_str.name .. (nameDisplay == "" and (_.common_str.name_not_defined or _.common_str.empty) or
      formatBelForDisplay(nameDisplay):sub(1, 40)), _.DIM_COLOR)
  if not isFmcbEntry then
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y + _.scaleY(44), 0.8, summaryStr, _.DIM_COLOR)
  end
  if allowArgs and hasCdromPathConflict then
    local warn = _.menu_str.cdrom_exclusive_warning or
        "Launch disc with override must be the only path for this entry."
    if _.common.fitListRowText then
      local warnFit = _.common.fitListRowText(ctx, "menu_entry_edit_cdrom_warning", _.font, warn,
        (_.w or 640) - 2 * _.MARGIN_X, 0.6, true)
      _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y + _.scaleY(64), 0.6, warnFit, _.KEYBOARD_SELECTED_COLOR or _.DIM_COLOR)
    elseif _.common.truncateTextToWidth then
      local warnFit = _.common.truncateTextToWidth(_.font, warn, (_.w or 640) - 2 * _.MARGIN_X, 0.6)
      _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y + _.scaleY(64), 0.6, warnFit, _.KEYBOARD_SELECTED_COLOR or _.DIM_COLOR)
    else
      _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y + _.scaleY(64), 0.6, warn, _.KEYBOARD_SELECTED_COLOR or _.DIM_COLOR)
    end
  end
  if ctx.entryEditSub < 1 then ctx.entryEditSub = 1 end
  if ctx.entryEditSub > #subRows then ctx.entryEditSub = #subRows end
  local maxLabelW = (_.w or 640) - (_.MARGIN_X + 20) - _.MARGIN_X
  local listTopY = _.MARGIN_Y + _.scaleY(isFmcbEntry and 76 or 90)
  for i = 1, #subRows do
    local row = subRows[i]
    local y = listTopY + (i - 1) * _.LINE_H
    local isSelected = (i == ctx.entryEditSub)
    local col = isSelected and _.SELECTED_COLOR or _.UNSELECTED_COLOR
    if row.kind == "path" then
      if parentEntryDisabled or row.disabled then
        col = isSelected and (_.SELECTED_DIM_COLOR or _.SELECTED_COLOR) or (_.DISABLED_DIM_COLOR or _.DIM_COLOR)
      elseif not row.hasValue then
        col = isSelected and _.SELECTED_COLOR or (_.DISABLED_DIM_COLOR or _.DIM_COLOR)
      end
    end
    local label = row.label
    if row.kind == "path" and ctx.fmcbEntryPathGrab and i == ctx.entryEditSub then
      label = "[" .. (_.menu_str.grabbed_tag or "Move") .. "] " .. label
    end
    label = formatBelForDisplay(label)
    if _.common.fitListRowText then
      label = _.common.fitListRowText(ctx, "menu_entry_edit_row_" .. tostring(row.id or i), _.font, label, maxLabelW,
        _.FONT_SCALE, isSelected)
    elseif _.common.truncateTextToWidth then
      label = _.common.truncateTextToWidth(_.font, label, maxLabelW, _.FONT_SCALE)
    end
    _.drawListRow(_.MARGIN_X + 20, y, isSelected, label, col)
  end
  local selectedRow = subRows[ctx.entryEditSub]
  local function markConfigMutated()
    ctx._configModifiedCache = nil
    ctx.configModified = true
  end
  local function selectedPathRowIndex()
    if not (isFmcbEntry and selectedRow and selectedRow.kind == "path") then return nil end
    return tonumber(selectedRow.pathIndex)
  end
  local function selectedPathValueIndex()
    local idx = selectedPathRowIndex()
    if not idx then return nil end
    if idx < 1 or idx > #fmcbPaths then return nil end
    return idx
  end
  local function clearMoveState()
    ctx.fmcbEntryPathGrab = nil
    ctx.fmcbEntryPathMoveSnapshot = nil
  end
  local function confirmMoveState()
    clearMoveState()
  end
  local function cancelMoveState()
    if ctx.fmcbEntryPathMoveSnapshot then
      if _.common and _.common.cloneConfigLines then
        ctx.lines = _.common.cloneConfigLines(ctx.fmcbEntryPathMoveSnapshot)
      else
        ctx.lines = ctx.fmcbEntryPathMoveSnapshot
      end
      _.common.refreshConfigModified(ctx)
    end
    clearMoveState()
  end
  local function beginMoveState()
    local idx = selectedPathValueIndex()
    if not idx or #fmcbPaths <= 1 then return end
    if _.common and _.common.cloneConfigLines then
      ctx.fmcbEntryPathMoveSnapshot = _.common.cloneConfigLines(ctx.lines)
    else
      ctx.fmcbEntryPathMoveSnapshot = nil
    end
    ctx.fmcbEntryPathGrab = true
  end
  local function swapSelectedPath(step)
    local idx = selectedPathValueIndex()
    if not idx then return end
    local dst = idx + step
    if dst < 1 or dst > #fmcbPaths then return end
    fmcbPaths[idx], fmcbPaths[dst] = fmcbPaths[dst], fmcbPaths[idx]
    _.config_parse.setMenuEntryPaths(ctx.lines, ctx.entryIdx, fmcbPaths)
    markConfigMutated()
    ctx.entryEditSub = 1 + dst
  end
  local function canOperateFmcbPathRow(row)
    if not (isFmcbEntry and row and row.kind == "path") then return false end
    local nextInsertIdx = math.min(fmcbMaxPaths, #fmcbPaths + 1)
    return row.pathIndex and row.pathIndex <= nextInsertIdx
  end
  local function canOpenFmcbPathActions(row)
    if ctx.fmcbEntryPathGrab then return false end
    if not canOperateFmcbPathRow(row) then return false end
    return row.hasValue or (not row.hasValue)
  end
  local baseHints = _.menu_str.cross_select_circle_back_items or {}
  local crossLabel = (baseHints[1] and baseHints[1].label) or (_.menu_str.enter_label or _.menu_str.edit_label or "Enter")
  local backLabel = (baseHints[2] and baseHints[2].label) or (_.menu_str.back_label or "Back")
  local crossPad = "cross"
  local selectedFmcbPathDisabled = isFmcbEntry and selectedRow and selectedRow.kind == "path" and selectedRow.hasValue and
      ((parentEntryDisabled or selectedRow.disabled) and true or false) or false
  local canToggleFmcbPathDisabled = isFmcbEntry and (not ctx.fmcbEntryPathGrab) and selectedRow and
      selectedRow.kind == "path" and selectedRow.hasValue
  local fmcbPathToggleLabel = canToggleFmcbPathDisabled and
      (selectedFmcbPathDisabled and (_.menu_str.enable_label or "Enable") or (_.menu_str.disable_label or "Disable")) or ""
  if isFmcbEntry then
    if ctx.fmcbEntryPathGrab then
      crossLabel = _.menu_str.confirm_label or "Confirm"
      backLabel = _.menu_str.cancel_label or "Cancel"
    elseif selectedRow and selectedRow.kind == "path" then
      if not canOperateFmcbPathRow(selectedRow) then
        crossPad = ""
        crossLabel = ""
      elseif selectedRow.hasValue then
        crossLabel = _.menu_str.edit_label or "Edit"
      else
        crossLabel = _.menu_str.insert_label or "Insert"
      end
    end
  end
  local entryEditHints = {
    { pad = crossPad, label = crossLabel, row = 1 },
    {
      pad = (isFmcbEntry and canOpenFmcbPathActions(selectedRow)) and "square" or "",
      label = (isFmcbEntry and canOpenFmcbPathActions(selectedRow)) and (_.menu_str.actions_label or "Actions") or "",
      row = 1
    },
    {
      pad = ctx.configModified and "start" or "",
      label = ctx.configModified and (_.menu_str.save_config_label or "Save") or "",
      row = 1
    },
    {
      pad = canToggleFmcbPathDisabled and "triangle" or "",
      label = canToggleFmcbPathDisabled and fmcbPathToggleLabel or "",
      row = 1
    },
    { pad = "circle", label = backLabel, row = 1 },
  }
  _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, entryEditHints, nil, _.DIM_COLOR, _.w - 2 * _.MARGIN_X)
  local function openPathPicker(editIdx)
    local pickerContext = isFmcbEntry and "fmcb_entry" or "osdmenu"
    ctx.editKey = nil
    ctx.pathPickerForEntryIdx = ctx.entryIdx
    ctx.pathPickerBootKey = nil
    ctx.pathPickerBootKeyDisabled = nil
    ctx.pathPickerBblHotkeyKey = nil
    ctx.pathPickerBblHotkeySlot = nil
    ctx.pathPickerBblHotkeyDisabled = nil
    ctx.pathPickerBblIrxIdx = nil
    ctx.pathPickerBblIrxDisabled = nil
    ctx.pathPickerTarget = nil
    ctx.pathPickerFileExts = nil
    ctx.pathPickerEditIdx = editIdx
    ctx.pathPickerInsertBelow = nil
    ctx.pathPickerSub = "device"
    ctx.pathList = _.file_selector.getDevices(pickerContext) or {}
    ctx.pathPickerSel = 1
    ctx.pathPickerScroll = 0
    ctx.pathPickerContext = pickerContext
    ctx.pathPickerReturnState = "menu_entry_edit"
    ctx.state = "path_picker"
  end
  local function removeFmcbPath(pathIndex)
    if not isFmcbEntry then return end
    if pathIndex < 1 or pathIndex > #fmcbPaths then return end
    table.remove(fmcbPaths, pathIndex)
    _.config_parse.setMenuEntryPaths(ctx.lines, ctx.entryIdx, fmcbPaths)
    markConfigMutated()
  end
  local function setFmcbPathDisabled(pathIndex, disabled)
    if not isFmcbEntry then return end
    if pathIndex < 1 or pathIndex > #fmcbPaths then return end
    local rawCurrent = fmcbPaths[pathIndex].disabled and true or false
    local current = (parentEntryDisabled or rawCurrent) and true or false
    local target = disabled
    if target == nil then
      target = not current
    else
      target = target and true or false
    end
    if parentEntryDisabled and (not target) then
      local changed = _.config_parse.enableMenuEntryPathFromDisabledParent and
          _.config_parse.enableMenuEntryPathFromDisabledParent(ctx.lines, ctx.entryIdx, pathIndex)
      if changed then
        markConfigMutated()
      end
      return
    end
    if parentEntryDisabled then return end
    local desiredComment = target and true or nil
    local currentComment = fmcbPaths[pathIndex].comment
    local normalizedCurrentComment = (currentComment == 2) and 2 or (currentComment and true or nil)
    if current == target and normalizedCurrentComment == desiredComment then return end
    fmcbPaths[pathIndex].disabled = target
    fmcbPaths[pathIndex].comment = desiredComment
    _.config_parse.setMenuEntryPaths(ctx.lines, ctx.entryIdx, fmcbPaths)
    markConfigMutated()
  end
  if isFmcbEntry and ctx.fmcbEntryPathActionsOpen then
    local actionRows = {}
    if selectedRow and selectedRow.kind == "path" and canOperateFmcbPathRow(selectedRow) then
      actionRows[#actionRows + 1] = {
        id = "edit",
        label = selectedRow.hasValue and (_.menu_str.edit_label or "Edit") or (_.menu_str.insert_label or "Insert"),
      }
      if selectedRow.hasValue and #fmcbPaths > 1 then
        actionRows[#actionRows + 1] = {
          id = "move",
          label = _.menu_str.grab_label or "Move",
        }
      end
      if selectedRow.hasValue then
        actionRows[#actionRows + 1] = {
          id = "toggle_disabled",
          label = ((parentEntryDisabled or selectedRow.disabled) and true or false) and
              (_.menu_str.enable_label or "Enable") or
              (_.menu_str.disable_label or "Disable")
        }
      end
      if selectedRow.hasValue then
        actionRows[#actionRows + 1] = { id = "remove", label = (_.menu_str.remove_label or "Remove") }
      end
    end
    if actions_menu.run(ctx, {
          openKey = "fmcbEntryPathActionsOpen",
          selKey = "fmcbEntryPathActionsSel",
          scrollKey = "fmcbEntryPathActionsScroll",
          title = (_.menu_str.actions_title or "Actions"),
          rows = actionRows,
          rowStateKeyPrefix = "fmcb_entry_path_actions_row_",
          onSelect = function(row)
            if row.id == "edit" then
              if selectedRow and selectedRow.kind == "path" and selectedRow.hasValue then
                openPathPicker(selectedRow.pathIndex)
              else
                openPathPicker(nil)
              end
            elseif row.id == "move" then
              beginMoveState()
            elseif row.id == "toggle_disabled" and selectedRow and selectedRow.kind == "path" then
              setFmcbPathDisabled(selectedRow.pathIndex, nil)
            elseif row.id == "remove" and selectedRow and selectedRow.kind == "path" then
              removeFmcbPath(selectedRow.pathIndex)
            end
          end,
        }) then
      return
    end
  end

  if (_.padEffective & _.PAD_UP) ~= 0 then
    if isFmcbEntry and ctx.fmcbEntryPathGrab then
      swapSelectedPath(-1)
    else
      ctx.entryEditSub = _.common.moveListSelection(ctx.entryEditSub, #subRows, -1, { ctx = ctx })
    end
  end
  if (_.padEffective & _.PAD_DOWN) ~= 0 then
    if isFmcbEntry and ctx.fmcbEntryPathGrab then
      swapSelectedPath(1)
    else
      ctx.entryEditSub = _.common.moveListSelection(ctx.entryEditSub, #subRows, 1, { ctx = ctx })
    end
  end
  if (_.padEffective & _.PAD_CROSS) ~= 0 then
    if isFmcbEntry and ctx.fmcbEntryPathGrab then
      confirmMoveState()
      return
    end
    local row = subRows[ctx.entryEditSub]
    if row.kind == "name" then
      local allowBelKey = (ctx.fileType == "freemcboot_cnf" or ctx.fileType == "osdmenu_cnf")
      local prompt = _.menu_str.entry_name_prompt
      local currentNameRaw = _.config_parse.getMenuEntryName(ctx.lines, ctx.entryIdx) or ""
      local editingSeparator = (not isFmcbEntry) and _.config_parse.isMenuEntrySeparatorName and
          _.config_parse.isMenuEntrySeparatorName(currentNameRaw)
      local currentNameDisplay = currentNameRaw
      if editingSeparator and _.config_parse.getMenuEntrySeparatorText then
        currentNameDisplay = _.config_parse.getMenuEntrySeparatorText(currentNameRaw) or ""
      end
      if currentNameDisplay == _.menu_str.add_entry_label then currentNameDisplay = "" end
      local initialValue = currentNameDisplay
      local maxLen = _.config_parse.LIMIT_NAME
      _.common.configureBelTextInput(ctx, {
        allow = allowBelKey,
        context = ctx.context,
      })
      local onSubmit = function(val)
        local saveVal = val or ""
        if editingSeparator and saveVal:sub(1, 2) ~= "$!" then
          saveVal = "$!" .. saveVal
        end
        local newIsSeparator = (not isFmcbEntry) and _.config_parse.isMenuEntrySeparatorName and
            _.config_parse.isMenuEntrySeparatorName(saveVal)
        _.config_parse.setMenuEntryName(ctx.lines, ctx.entryIdx, saveVal)
        if newIsSeparator then
          _.config_parse.setMenuEntryPaths(ctx.lines, ctx.entryIdx, {})
          _.config_parse.setMenuEntryArgs(ctx.lines, ctx.entryIdx, {})
        end
        ctx._configModifiedCache = nil
        ctx.configModified = true
        ctx.state = "menu_entry_edit"
      end
      _.common.beginTextInput(ctx, {
        titleIdMode = nil,
        prompt = prompt,
        value = initialValue,
        maxLen = maxLen,
        callback = onSubmit,
        returnState = "menu_entry_edit",
        gridSel = 1,
        cursor = #initialValue + 1,
        scroll = 1,
        state = "text_input",
      })
    elseif row.kind == "path" and isFmcbEntry then
      if canOperateFmcbPathRow(row) then
        if row.hasValue then
          openPathPicker(row.pathIndex)
        else
          openPathPicker(nil)
        end
      end
    elseif row.kind == "paths" then
      ctx.state = "entry_paths"
      ctx.entryPathSel = 1
      ctx.entryPathScroll = 0
    elseif row.kind == "launch_disc_options" then
      if hasCdromPathConflict then
        ctx.saveSplash = {
          kind = "failed",
          title = _.menu_str.invalid_selection_title or "Invalid selection",
          detail = _.menu_str.cdrom_exclusive_warning or
              "Launch disc with override must be the only path for this entry.",
          framesLeft = 120
        }
      else
        ctx.cdromOptSel = 1
        ctx.state = "entry_cdrom_options"
      end
    elseif row.kind == "arguments" then
      if #args == 0 then
        ctx.entryArgAddMenu = true
        ctx.entryArgAddSel = 1
        ctx.entryArgAddScroll = 0
      end
      ctx.state = "entry_args"
      ctx.entryArgSel = 1
      ctx.entryArgScroll = 0
    end
  end
  if isFmcbEntry and (_.padEffective & _.PAD_SQUARE) ~= 0 then
    local row = subRows[ctx.entryEditSub]
    if row and row.kind == "path" and canOpenFmcbPathActions(row) then
      _.common.openActionsMenu(ctx, "fmcbEntryPathActionsOpen", "fmcbEntryPathActionsSel", "fmcbEntryPathActionsScroll")
    end
  end
  if isFmcbEntry and (not ctx.fmcbEntryPathGrab) and (_.padEffective & _.PAD_TRIANGLE) ~= 0 then
    local row = subRows[ctx.entryEditSub]
    if row and row.kind == "path" and row.hasValue then
      setFmcbPathDisabled(row.pathIndex, nil)
    end
  end
  if ctx.configModified and (_.padEffective & _.PAD_START) ~= 0 then
    _.common.saveCurrentConfig(ctx)
  end
  if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
    if isFmcbEntry and ctx.fmcbEntryPathGrab then
      cancelMoveState()
      return
    end
    ctx.state = "menu_entries"; ctx.entryIdx = nil
  end
end

return { run = run }
