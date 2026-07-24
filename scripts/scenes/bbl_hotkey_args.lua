--[[ Argument editor for one BBL hotkey slot (ARG_<HOTKEY>_E#). ]]

local arg_presets = dofile("scripts/scenes/arg_presets.lua")
local arg_profiles = dofile("scripts/scenes/arg_profiles.lua")
local arg_gsm_picker = dofile("scripts/scenes/arg_gsm_picker.lua")
local arg_add_menu = dofile("scripts/scenes/arg_add_menu.lua")
local actions_menu = dofile("scripts/scenes/actions_menu.lua")

local function run(ctx)
  local _ = ctx._
  if not ctx.lines then
    ctx.state = "editor"
    return
  end
  local keyId = ctx.bblHotkeyKey
  local slot = tonumber(ctx.bblEntrySlot)
  if not keyId or not slot then
    ctx.state = "bbl_hotkey_entry"
    return
  end
  if ctx.fileType == "freemcboot_cnf" or ctx.context == "freehddboot" then
    ctx.state = "bbl_hotkey_entry"
    return
  end
  local keyDisabled = (_.config_parse.isBblHotkeyDisabled and _.config_parse.isBblHotkeyDisabled(ctx.lines, keyId)) and true or false

  local maxArgs = _.config_parse.getBblMaxArgsPerEntry and _.config_parse.getBblMaxArgsPerEntry() or nil
  local hasArgCap = (type(maxArgs) == "number" and maxArgs > 0)

  local function getArgs()
    return _.config_parse.getBblHotkeyArgs(ctx.lines, keyId, slot) or {}
  end

  local function markConfigMutated()
    ctx._configModifiedCache = nil
    ctx.configModified = true
  end

  local function setArgs(args)
    _.config_parse.setBblHotkeyArgs(ctx.lines, keyId, slot, args)
    markConfigMutated()
  end

  local function findArgIndexByValue(argList, value, fallback)
    local target = tostring(value or "")
    for i = #argList, 1, -1 do
      local item = argList[i]
      local v = (type(item) == "table") and item.value or item
      if tostring(v or "") == target then
        return i
      end
    end
    return _.common.clampListSelection(fallback or 1, #argList)
  end

  local function addArgValue(v)
    local value = tostring(v or "")
    if value == "" then return end
    local args2 = getArgs()
    if hasArgCap and #args2 >= maxArgs then return end
    table.insert(args2, { value = value, disabled = false })
    setArgs(args2)
    local refreshed = getArgs()
    ctx.bblArgSel = findArgIndexByValue(refreshed, value, #refreshed)
  end

  local function openNewArgumentInput(prompt, maxLen, callback)
    _.common.beginTextInput(ctx, {
      titleIdMode = nil,
      prompt = prompt,
      value = "",
      maxLen = maxLen,
      callback = callback,
      returnState = "bbl_hotkey_args",
      gridSel = 1,
      cursor = 1,
      scroll = 1,
      state = "text_input",
    })
  end

  local function addUdpbdPair(ipValue)
    local args2, ok = arg_presets.addUdpbdPair(getArgs(), ipValue, maxArgs)
    if not ok then return false end
    setArgs(args2)
    local refreshed = getArgs()
    local udpValue = "-udpbd_ip=" .. tostring(ipValue or ""):gsub("^%s+", ""):gsub("%s+$", "")
    ctx.bblArgSel = findArgIndexByValue(refreshed, udpValue, #refreshed)
    return true
  end

  local function addUdpfsPair(ipValue)
    local args2, ok = arg_presets.addUdpfsPair(getArgs(), ipValue, maxArgs)
    if not ok then return false end
    setArgs(args2)
    local refreshed = getArgs()
    local udpValue = "-udpfs_ip=" .. tostring(ipValue or ""):gsub("^%s+", ""):gsub("%s+$", "")
    ctx.bblArgSel = findArgIndexByValue(refreshed, udpValue, #refreshed)
    return true
  end

  local args = getArgs()
  local total = #args
  local canMoveArgs = total > 1
  local function clearMoveState()
    ctx.bblArgGrab = nil
    ctx.bblArgMoveSnapshot = nil
    ctx.bblArgMoveSel = nil
  end
  local function beginMoveState()
    if ctx.bblArgGrab then return end
    if _.common and _.common.cloneConfigLines then
      ctx.bblArgMoveSnapshot = _.common.cloneConfigLines(ctx.lines)
    else
      ctx.bblArgMoveSnapshot = nil
    end
    ctx.bblArgMoveSel = ctx.bblArgSel
    ctx.bblArgGrab = true
  end
  local function confirmMoveState()
    clearMoveState()
  end
  local function cancelMoveState()
    if ctx.bblArgMoveSnapshot then
      if _.common and _.common.cloneConfigLines then
        ctx.lines = _.common.cloneConfigLines(ctx.bblArgMoveSnapshot)
      else
        ctx.lines = ctx.bblArgMoveSnapshot
      end
      local restoredArgs = getArgs()
      ctx.bblArgSel = _.common.clampListSelection(ctx.bblArgMoveSel or ctx.bblArgSel, #restoredArgs)
      _.common.refreshConfigModified(ctx)
    end
    clearMoveState()
  end
  if not canMoveArgs then
    confirmMoveState()
  end
  local slotData = _.config_parse.getBblHotkeySlot and _.config_parse.getBblHotkeySlot(ctx.lines, keyId, slot) or nil
  local entryPath = (slotData and slotData.path) or ""
  local hasCdrom = arg_presets.hasCdromPath(entryPath)
  local isNhddlElfPath = arg_presets.isNhddlElfPath(entryPath)
  local isDkwdrvElfPath = arg_presets.isDkwdrvElfPath(entryPath)
  local usedKnown, usedModes = arg_presets.collectUsedArgs(args)
  local profileState = arg_profiles.resolve({
    surface = "bbl_hotkey",
    context = ctx.context,
    fileType = ctx.fileType,
    hasNhddlPath = isNhddlElfPath,
    hasDkwdrvPath = isDkwdrvElfPath,
  })
  local presetRows = arg_profiles.buildAddRows(profileState)
  if not arg_presets.pathsSupportPatinfo(entryPath) then
    local filteredRows = {}
    for i = 1, #presetRows do
      if presetRows[i].uniqueKey ~= "patinfo" then
        filteredRows[#filteredRows + 1] = presetRows[i]
      end
    end
    presetRows = filteredRows
  end
  if not hasCdrom then
    local filteredRows = {}
    for i = 1, #presetRows do
      if not presetRows[i].cdromOnly then
        filteredRows[#filteredRows + 1] = presetRows[i]
      end
    end
    presetRows = filteredRows
  end
  local removeNhddlPair = true
  local gsmKeys = {
    openKey = "bblArgGsmPickerMenu",
    selKey = "bblArgGsmPickerSel",
    videoKey = "bblArgGsmVideoIdx",
    compatKey = "bblArgGsmCompatIdx",
    compatSelectedKey = "bblArgGsmCompatSelected",
    argKeyKey = "bblArgGsmArgKey",
    lastVideoKey = "bblArgGsmLastVideoIdx",
    editIdxKey = "bblArgGsmEditIdx",
    rowStateKeyPrefix = "bbl_hotkey_args_gsm_picker_row_",
  }

  local function reopenAddMenu()
    if hasArgCap and total >= maxArgs then return end
    ctx.bblArgAddMenu = true
    ctx.bblArgAddSel = 1
    ctx.bblArgAddScroll = 0
  end

  local function openGsmPicker(row)
    arg_gsm_picker.open(ctx, gsmKeys, (row and row.egsmArgKey) or "-gsm")
  end

  if ctx.bblArgAddMenu and hasArgCap and total >= maxArgs then
    ctx.bblArgAddMenu = nil
    ctx.bblArgAddSel = nil
    ctx.bblArgAddScroll = nil
  end

  if arg_gsm_picker.run(ctx, {
        keys = gsmKeys,
        onSubmit = function(arg, editIdx)
          local idx = math.floor(tonumber(editIdx) or 0)
          if idx >= 1 then
            local args2 = getArgs()
            if args2[idx] then
              args2[idx].value = arg
              setArgs(args2)
              local refreshed = getArgs()
              ctx.bblArgSel = findArgIndexByValue(refreshed, arg, idx)
            end
          else
            addArgValue(arg)
          end
        end,
        onCancel = function(editIdx)
          local idx = math.floor(tonumber(editIdx) or 0)
          if idx < 1 then
            reopenAddMenu()
          end
        end,
      }) then
    return
  end

  if ctx.bblArgAddMenu then
    local function openUdpbdIpInput()
      openNewArgumentInput("UDPBD IP (x.x.x.x)", 15, function(val)
        local ip = tostring(val or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if ip ~= "" then
          addUdpbdPair(ip)
        end
        ctx.state = "bbl_hotkey_args"
      end)
    end
    local function openUdpfsIpInput()
      openNewArgumentInput("UDPFS IP (x.x.x.x)", 15, function(val)
        local ip = tostring(val or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if ip ~= "" then
          addUdpfsPair(ip)
        end
        ctx.state = "bbl_hotkey_args"
      end)
    end
    local function openTitleIdInput()
      openNewArgumentInput("TITLEID (up to 11 chars)", 11, function(val)
        local titleId = tostring(val or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if titleId ~= "" then
          addArgValue("-titleid=" .. titleId)
        end
        ctx.state = "bbl_hotkey_args"
      end)
    end
    local function openDkwdrvPathInput()
      openNewArgumentInput("DKWDRV path", 255, function(val)
        local p = tostring(val or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if p ~= "" then
          addArgValue("-dkwdrv=" .. p)
        end
        ctx.state = "bbl_hotkey_args"
      end)
    end
    local titleAdd = hasArgCap
      and ("Add argument (" .. tostring(total) .. "/" .. tostring(maxArgs) .. ") [" .. arg_profiles.getMenuTag(profileState) .. "]")
      or ("Add argument (" .. tostring(total) .. ") [" .. arg_profiles.getMenuTag(profileState) .. "]")
    if arg_add_menu.run(ctx, {
          menuOpenKey = "bblArgAddMenu",
          selKey = "bblArgAddSel",
          scrollKey = "bblArgAddScroll",
          rows = presetRows,
          title = titleAdd,
          descDefault = "Enter any custom argument manually.",
          rowStateKeyPrefix = "bbl_hotkey_args_add_row_",
          rowDisabledReason = function(row)
            return arg_presets.rowDisabled(row, usedKnown, usedModes, total, maxArgs)
          end,
          onSelect = function(row)
            if row.kind == "manual" then
              openNewArgumentInput(_.menu_str.new_argument_prompt or "New argument", 255, function(val)
                local v = val or ""
                if v ~= "" then addArgValue(v) end
                ctx.state = "bbl_hotkey_args"
              end)
            elseif row.kind == "titleid" then
              openTitleIdInput()
            elseif row.kind == "egsm" or row.kind == "gsm" then
              openGsmPicker(row)
            elseif row.kind == "dkwdrv_path" then
              openDkwdrvPathInput()
            elseif row.kind == "udpbd_ip" then
              openUdpbdIpInput()
            elseif row.modeValue == "udpbd" and usedKnown.udpbd_ip ~= true then
              openUdpbdIpInput()
            elseif row.kind == "udpfs_ip" then
              openUdpfsIpInput()
            elseif row.modeValue == "udpfs" and usedKnown.udpfs_ip ~= true then
              openUdpfsIpInput()
            else
              addArgValue(row.value or "")
            end
          end,
        }) then
      return
    end
  end

  ctx.bblArgSel = _.common.clampListSelection(ctx.bblArgSel or 1, total)
  ctx.bblArgScroll = _.common.centeredListScroll(ctx.bblArgSel, total, _.MAX_VISIBLE_LIST)

  local titleSuffix = hasArgCap
      and (" - E" .. tostring(slot) .. " args (" .. tostring(total) .. "/" .. tostring(maxArgs) .. ")")
      or (" - E" .. tostring(slot) .. " args (" .. tostring(total) .. ")")
  _.common.drawHotkeyTitle(_, keyId, titleSuffix)

  local startY = _.MARGIN_Y + _.scaleY(50)
  if _.common and _.common.drawListScrollbar then
    _.common.drawListScrollbar(_, {
      totalRows = total,
      visibleRows = _.MAX_VISIBLE_LIST,
      scrollRows = ctx.bblArgScroll,
      rowTopY = startY,
      rowHeight = _.LINE_H,
      color = _.DIM_COLOR,
    })
  end
  local maxLabelW = (_.w or 640) - (_.MARGIN_X + 24) - _.MARGIN_X
  if total == 0 then
    _.drawText(_.font, _.drawMode, _.MARGIN_X + 20, startY, _.FONT_SCALE,
      _.common_str.none or _.common_str.empty, _.DIM_COLOR)
  else
    for i = ctx.bblArgScroll + 1, math.min(ctx.bblArgScroll + _.MAX_VISIBLE_LIST, total) do
      local y = startY + (i - ctx.bblArgScroll - 1) * _.LINE_H
      local a = args[i]
      local text = (a and a.value) or ""
      if text == "" then text = _.common_str.empty end
      if canMoveArgs and ctx.bblArgGrab and i == ctx.bblArgSel then
        text = "[" .. (_.menu_str.grabbed_tag or "Move") .. "] " .. text
      end
      if _.common.fitListRowText then
        text = _.common.fitListRowText(ctx, "bbl_hotkey_args_row_" .. tostring(i), _.font, text, maxLabelW,
          _.FONT_SCALE, i == ctx.bblArgSel)
      elseif _.common.truncateTextToWidth then
        text = _.common.truncateTextToWidth(_.font, text, maxLabelW, _.FONT_SCALE)
      end
      local col = (i == ctx.bblArgSel) and _.SELECTED_COLOR or _.UNSELECTED_COLOR
      if keyDisabled or (a and a.disabled) then
        col = (i == ctx.bblArgSel) and (_.SELECTED_DIM_COLOR or _.SELECTED_COLOR) or (_.DISABLED_DIM_COLOR or _.DIM_COLOR)
      end
      _.drawListRow(_.MARGIN_X + 20, y, i == ctx.bblArgSel, text, col)
    end
  end

  local hasSelection = (total > 0 and ctx.bblArgSel >= 1 and ctx.bblArgSel <= total and args[ctx.bblArgSel])
  local canAddArg = ((not hasArgCap) or total < maxArgs)
  local canToggleSelectedArg = hasSelection and (not keyDisabled)
  local selectedDisabled = hasSelection and args[ctx.bblArgSel].disabled
  local crossPad = (hasSelection or canAddArg) and "cross" or ""
  local crossLabel = ""
  if hasSelection then
    crossLabel = ctx.bblArgGrab and (_.menu_str.confirm_label or "Confirm") or (_.menu_str.edit_label or "Edit")
  elseif canAddArg then
    crossLabel = (_.menu_str.insert_label or "Insert")
  end
  local hint = {
    {
      pad = crossPad,
      label = crossLabel,
      row = 1
    },
    { pad = "square", label = (_.menu_str.actions_label or "Actions"), row = 1 },
    {
      pad = ctx.configModified and "start" or "",
      label = ctx.configModified and (_.menu_str.save_config_label or "Save") or "",
      row = 1
    },
    {
      pad = canToggleSelectedArg and "triangle" or "",
      label = canToggleSelectedArg and
          (selectedDisabled and (_.menu_str.enable_label or "Enable") or (_.menu_str.disable_label or "Disable")) or "",
      row = 1
    },
    {
      pad = "circle",
      label = ctx.bblArgGrab and (_.menu_str.cancel_label or "Cancel") or (_.menu_str.back_label or "Back"),
      row = 1
    },
  }
  _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, hint, nil, _.DIM_COLOR, _.w - 2 * _.MARGIN_X)

  local function moveSelectedArg(step)
    if not hasSelection or total <= 1 then return end
    local dst = ctx.bblArgSel + step
    if dst < 1 or dst > total then return end
    local args2 = getArgs()
    local movedItem = args2[ctx.bblArgSel]
    local movedValue = movedItem and movedItem.value or ""
    args2[ctx.bblArgSel], args2[dst] = args2[dst], args2[ctx.bblArgSel]
    setArgs(args2)
    local refreshed = getArgs()
    ctx.bblArgSel = findArgIndexByValue(refreshed, movedValue, dst)
  end

  local function removeSelectedArg()
    if not hasSelection then return end
    local args2 = arg_presets.removeArgAndPairedUdpbd(getArgs(), ctx.bblArgSel, removeNhddlPair)
    setArgs(args2)
    ctx.bblArgSel = _.common.clampListSelection(ctx.bblArgSel, #args2)
    if #args2 == 0 then
      confirmMoveState()
    end
  end

  local function beginAddArg()
    if not canAddArg then return end
    confirmMoveState()
    ctx.bblArgAddMenu = true
    ctx.bblArgAddSel = 1
    ctx.bblArgAddScroll = 0
  end

  if ctx.bblArgActionsOpen then
    local actionRows = {}
    if hasSelection and canMoveArgs then
      actionRows[#actionRows + 1] = {
        id = "grab",
        label = ctx.bblArgGrab and (_.menu_str.cancel_move_label or "Cancel move") or
            (_.menu_str.grab_label or "Move"),
      }
    end
    if hasSelection then
      actionRows[#actionRows + 1] = { id = "remove", label = (_.menu_str.remove_label or "Remove") }
    end
    if canAddArg then
      actionRows[#actionRows + 1] = { id = "insert", label = (_.menu_str.insert_label or "Insert") }
    end
    if actions_menu.run(ctx, {
          openKey = "bblArgActionsOpen",
          selKey = "bblArgActionsSel",
          scrollKey = "bblArgActionsScroll",
          title = (_.menu_str.actions_title or "Actions"),
          rows = actionRows,
          rowStateKeyPrefix = "bbl_hotkey_args_actions_row_",
          onSelect = function(row)
            if row.id == "grab" then
              if ctx.bblArgGrab then
                cancelMoveState()
              else
                beginMoveState()
              end
            elseif row.id == "remove" then
              removeSelectedArg()
            elseif row.id == "insert" then
              beginAddArg()
            end
          end,
        }) then
      return
    end
  end

  if total > 0 and (_.padEffective & _.PAD_UP) ~= 0 then
    if ctx.bblArgGrab then
      moveSelectedArg(-1)
    else
      ctx.bblArgSel = _.common.wrapListSelection(ctx.bblArgSel, total, -1)
    end
  end
  if total > 0 and (_.padEffective & _.PAD_DOWN) ~= 0 then
    if ctx.bblArgGrab then
      moveSelectedArg(1)
    else
      ctx.bblArgSel = _.common.wrapListSelection(ctx.bblArgSel, total, 1)
    end
  end

  if (_.padEffective & _.PAD_CROSS) ~= 0 then
    if ctx.bblArgGrab then
      confirmMoveState()
      return
    end
    if hasSelection then
      local editIdx = ctx.bblArgSel
      local editItem = args[editIdx]
      local editVal = type(editItem) == "table" and editItem.value or editItem or ""
      local gsmArgKey, gsmVideoIdx, gsmCompatIdx = arg_gsm_picker.parseExistingGsmArg(_, editVal)
      if gsmArgKey then
        arg_gsm_picker.open(ctx, gsmKeys, gsmArgKey, gsmVideoIdx, gsmCompatIdx)
        ctx[gsmKeys.editIdxKey] = editIdx
      else
        _.common.beginTextInput(ctx, {
          titleIdMode = nil,
          prompt = _.menu_str.edit_argument_prompt or "Edit argument",
          value = editVal,
          maxLen = 255,
          callback = function(val)
            local args2 = getArgs()
            if type(args2[editIdx]) == "table" then
              args2[editIdx].value = val or ""
            elseif args2[editIdx] ~= nil then
              args2[editIdx] = { value = val or "", disabled = false }
            end
            setArgs(args2)
            local refreshed = getArgs()
            ctx.bblArgSel = findArgIndexByValue(refreshed, val or "", editIdx)
            ctx.state = "bbl_hotkey_args"
          end,
          returnState = "bbl_hotkey_args",
          gridSel = 1,
          scroll = 1,
          state = "text_input",
        })
      end
    elseif canAddArg then
      beginAddArg()
      return
    end
  end

  local function toggleSelectedArgDisabled()
    if total > 0 and not keyDisabled then
      _.config_parse.setBblHotkeyArgDisabled(ctx.lines, keyId, slot, ctx.bblArgSel, not args[ctx.bblArgSel].disabled)
      markConfigMutated()
    end
  end

  if (_.padEffective & _.PAD_TRIANGLE) ~= 0 then
    toggleSelectedArgDisabled()
  end

  if (_.padEffective & _.PAD_SQUARE) ~= 0 then
    _.common.openActionsMenu(ctx, "bblArgActionsOpen", "bblArgActionsSel", "bblArgActionsScroll")
  end
  if ctx.configModified and (_.padEffective & _.PAD_START) ~= 0 then
    _.common.saveCurrentConfig(ctx)
  end

  if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
    if ctx.bblArgGrab then
      cancelMoveState()
      return
    end
    ctx.state = "bbl_hotkey_entry"
  end
end

return { run = run }
