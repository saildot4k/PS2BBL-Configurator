--[[ Arguments list for a menu entry or MBR boot key (when ctx.bootKey is set and we're in MBR). ]]

local arg_presets = dofile("scripts/scenes/arg_presets.lua")
local arg_profiles = dofile("scripts/scenes/arg_profiles.lua")
local arg_gsm_picker = dofile("scripts/scenes/arg_gsm_picker.lua")
local arg_add_menu = dofile("scripts/scenes/arg_add_menu.lua")
local actions_menu = dofile("scripts/scenes/actions_menu.lua")

local function run(ctx)
  local _ = ctx._
  local isBoot = not not (ctx.bootKey and (ctx.context == "mbr" or ctx.fileType == "osdmbr_cnf"))
  if not ctx.lines then
    ctx.state = isBoot and "editor" or "menu_entry_edit"; return
  end
  if not isBoot and not ctx.entryIdx then
    ctx.state = "menu_entry_edit"; return
  end
  if isBoot and not ctx.bootKey then
    ctx.state = "editor"; return
  end

  local sceneEpoch = tonumber(ctx._sceneEpoch) or 0
  local bootKeyDisabledOverride = nil
  local bootKeyOpts = nil
  if isBoot then
    local bootKeyTag = tostring(ctx.bootKey or "")
    if ctx.entryArgsBootKeyDisabledTag ~= bootKeyTag or ctx.entryArgsBootKeyDisabledOverride == nil then
      ctx.entryArgsBootKeyDisabledTag = bootKeyTag
      ctx.entryArgsBootKeyDisabledOverride =
          (_.config_parse.isBootKeyDisabled and _.config_parse.isBootKeyDisabled(ctx.lines, ctx.bootKey)) and true or false
    end
    bootKeyDisabledOverride = ctx.entryArgsBootKeyDisabledOverride and true or false
    bootKeyOpts = { keyDisabledOverride = bootKeyDisabledOverride }
  end
  local parentArgsDisabled = false
  if isBoot then
    parentArgsDisabled = bootKeyDisabledOverride and true or false
  else
    parentArgsDisabled = (_.config_parse.isMenuEntryDisabled and _.config_parse.isMenuEntryDisabled(ctx.lines, ctx.entryIdx)) and
        true or false
  end
  local function buildPathsModel()
    local outPaths = isBoot and (_.config_parse.getBootPaths(ctx.lines, ctx.bootKey, bootKeyOpts) or {}) or
        _.config_parse.getMenuEntryPaths(ctx.lines, ctx.entryIdx)
    local outHasOsdOrShutdown = false
    for _, p in ipairs(outPaths or {}) do
      local pv = type(p) == "table" and p.value or p
      if (pv or ""):upper() == "OSDSYS" or (pv or ""):upper() == "POWEROFF" then
        outHasOsdOrShutdown = true
        break
      end
    end
    return {
      sceneEpoch = sceneEpoch,
      linesRef = ctx.lines,
      isBoot = isBoot,
      entryIdx = ctx.entryIdx or 0,
      bootKey = ctx.bootKey or "",
      paths = outPaths,
      hasOsdOrShutdown = outHasOsdOrShutdown
    }
  end
  local function getPathsModel()
    local cache = ctx.entryArgsPathsCache
    if cache and cache.sceneEpoch == sceneEpoch and cache.linesRef == ctx.lines and
        cache.isBoot == isBoot and cache.entryIdx == (ctx.entryIdx or 0) and cache.bootKey == (ctx.bootKey or "") then
      return cache
    end
    cache = buildPathsModel()
    ctx.entryArgsPathsCache = cache
    return cache
  end
  local pathsModel = getPathsModel()
  local paths = pathsModel.paths or {}
  local hasOsdOrShutdown = pathsModel.hasOsdOrShutdown and true or false
  if not isBoot and hasOsdOrShutdown then
    ctx.state = "menu_entry_edit"; return
  end

  local hasCdrom = arg_presets.hasCdromPath(paths)
  local hasNhddlElfPath = arg_presets.hasNhddlElfPath(paths)
  local hasDkwdrvElfPath = arg_presets.hasDkwdrvElfPath(paths)

  local function getArgs()
    if isBoot then
      return _.config_parse.getBootArgEntries(ctx.lines, ctx.bootKey, bootKeyOpts) or {}
    end
    return _.config_parse.getMenuEntryArgs(ctx.lines, ctx.entryIdx) or {}
  end

  local function markConfigMutated()
    ctx._configModifiedCache = nil
    ctx.configModified = true
  end

  local function setArgs(a)
    if isBoot then
      _.config_parse.setBootArgEntries(ctx.lines, ctx.bootKey, a or {}, bootKeyOpts)
    else
      _.config_parse.setMenuEntryArgs(ctx.lines, ctx.entryIdx, a)
    end
    markConfigMutated()
    ctx.entryArgsModelCache = nil
  end

  local function findArgIndexByValue(argList, value, fallback)
    local target = tostring(value or "")
    for i = #argList, 1, -1 do
      local item = argList[i]
      local v = type(item) == "table" and item.value or item
      if tostring(v or "") == target then
        return i
      end
    end
    return _.common.clampListSelection(fallback or 1, #argList)
  end

  local invalidateArgsModel

  local function addArgValue(v)
    local value = tostring(v or "")
    if value == "" then return end
    if isBoot and ctx.entryArgInsertBelow and ctx.entryArgInsertBelow >= 0 then
      _.config_parse.insertBootArgBelow(ctx.lines, ctx.bootKey, ctx.entryArgInsertBelow, value, bootKeyOpts)
      markConfigMutated()
      invalidateArgsModel()
      local refreshed = getArgs()
      ctx.entryArgSel = findArgIndexByValue(refreshed, value, #refreshed)
    else
      local args2 = getArgs()
      table.insert(args2, { value = value, disabled = false })
      setArgs(args2)
      local refreshed = getArgs()
      ctx.entryArgSel = findArgIndexByValue(refreshed, value, #refreshed)
    end
    ctx.entryArgInsertBelow = nil
  end

  local function openNewArgumentInput(prompt, maxLen, callback)
    _.common.beginTextInput(ctx, {
      clearArgEditIdx = true,
      titleIdMode = nil,
      prompt = prompt,
      value = "",
      maxLen = maxLen,
      callback = callback,
      returnState = "entry_args",
      gridSel = 1,
      cursor = 1,
      scroll = 1,
      state = "text_input",
    })
  end

  local function addUdpbdPair(ipValue)
    local args2, ok = arg_presets.addUdpbdPair(getArgs(), ipValue)
    if not ok then return false end
    setArgs(args2)
    local refreshed = getArgs()
    local udpValue = "-udpbd_ip=" .. tostring(ipValue or ""):gsub("^%s+", ""):gsub("%s+$", "")
    ctx.entryArgSel = findArgIndexByValue(refreshed, udpValue, #refreshed)
    return true
  end

  local function addUdpfsPair(ipValue)
    local args2, ok = arg_presets.addUdpfsPair(getArgs(), ipValue)
    if not ok then return false end
    setArgs(args2)
    local refreshed = getArgs()
    local udpValue = "-udpfs_ip=" .. tostring(ipValue or ""):gsub("^%s+", ""):gsub("%s+$", "")
    ctx.entryArgSel = findArgIndexByValue(refreshed, udpValue, #refreshed)
    return true
  end

  local function buildArgsModel()
    local outArgs = getArgs()
    local outTotal = #outArgs
    local outUsedKnown, outUsedModes = arg_presets.collectUsedArgs(outArgs)
    local outProfileState = arg_profiles.resolve({
      surface = "entry_args",
      context = ctx.context,
      fileType = ctx.fileType,
      isBoot = isBoot,
      hasNhddlPath = hasNhddlElfPath,
      hasDkwdrvPath = hasDkwdrvElfPath,
    })
    local outAddRows = arg_profiles.buildAddRows(outProfileState)
    if not arg_presets.pathsSupportPatinfo(paths) then
      local filteredRows = {}
      for i = 1, #outAddRows do
        if outAddRows[i].uniqueKey ~= "patinfo" then
          filteredRows[#filteredRows + 1] = outAddRows[i]
        end
      end
      outAddRows = filteredRows
    end
    if not hasCdrom then
      local filteredRows = {}
      for i = 1, #outAddRows do
        if not outAddRows[i].cdromOnly then
          filteredRows[#filteredRows + 1] = outAddRows[i]
        end
      end
      outAddRows = filteredRows
    end
    return {
      sceneEpoch = sceneEpoch,
      linesRef = ctx.lines,
      isBoot = isBoot,
      entryIdx = ctx.entryIdx or 0,
      bootKey = ctx.bootKey or "",
      context = ctx.context or "",
      fileType = ctx.fileType or "",
      hasCdrom = hasCdrom and true or false,
      hasNhddlElfPath = hasNhddlElfPath and true or false,
      hasDkwdrvElfPath = hasDkwdrvElfPath and true or false,
      args = outArgs,
      total = outTotal,
      usedKnown = outUsedKnown,
      usedModes = outUsedModes,
      profileState = outProfileState,
      addRows = outAddRows,
      removeNhddlPair = arg_profiles.profileUsesNhddl(outProfileState.activeProfileId),
    }
  end
  local function getArgsModel()
    local cache = ctx.entryArgsModelCache
    if cache and cache.sceneEpoch == sceneEpoch and cache.linesRef == ctx.lines and
        cache.isBoot == isBoot and cache.entryIdx == (ctx.entryIdx or 0) and cache.bootKey == (ctx.bootKey or "") and
        cache.context == (ctx.context or "") and cache.fileType == (ctx.fileType or "") and
        cache.hasCdrom == (hasCdrom and true or false) and
        cache.hasNhddlElfPath == (hasNhddlElfPath and true or false) and
        cache.hasDkwdrvElfPath == (hasDkwdrvElfPath and true or false) then
      return cache
    end
    cache = buildArgsModel()
    ctx.entryArgsModelCache = cache
    return cache
  end
  invalidateArgsModel = function()
    ctx.entryArgsModelCache = nil
  end
  local argsModel = getArgsModel()
  local args = argsModel.args or {}
  local total = tonumber(argsModel.total) or #args
  local canMoveArgs = total > 1
  local function clearMoveState()
    ctx.entryArgGrab = nil
    ctx.entryArgMoveSnapshot = nil
    ctx.entryArgMoveSel = nil
  end
  local function beginMoveState()
    if ctx.entryArgGrab then return end
    if _.common and _.common.cloneConfigLines then
      ctx.entryArgMoveSnapshot = _.common.cloneConfigLines(ctx.lines)
    else
      ctx.entryArgMoveSnapshot = nil
    end
    ctx.entryArgMoveSel = ctx.entryArgSel
    ctx.entryArgGrab = true
  end
  local function confirmMoveState()
    clearMoveState()
  end
  local function cancelMoveState()
    if ctx.entryArgMoveSnapshot then
      if _.common and _.common.cloneConfigLines then
        ctx.lines = _.common.cloneConfigLines(ctx.entryArgMoveSnapshot)
      else
        ctx.lines = ctx.entryArgMoveSnapshot
      end
      local restoredArgs = getArgs()
      ctx.entryArgSel = _.common.clampListSelection(ctx.entryArgMoveSel or ctx.entryArgSel, #restoredArgs)
      _.common.refreshConfigModified(ctx)
    end
    clearMoveState()
  end
  if not canMoveArgs then
    confirmMoveState()
  end
  local usedKnown = argsModel.usedKnown or {}
  local usedModes = argsModel.usedModes or {}
  local profileState = argsModel.profileState or {}
  local addRows = argsModel.addRows or {}
  local removeNhddlPair = argsModel.removeNhddlPair and true or false
  local gsmKeys = {
    openKey = "entryArgGsmPickerMenu",
    selKey = "entryArgGsmPickerSel",
    videoKey = "entryArgGsmVideoIdx",
    compatKey = "entryArgGsmCompatIdx",
    compatSelectedKey = "entryArgGsmCompatSelected",
    argKeyKey = "entryArgGsmArgKey",
    lastVideoKey = "entryArgGsmLastVideoIdx",
    editIdxKey = "entryArgGsmEditIdx",
    rowStateKeyPrefix = "entry_args_gsm_picker_row_",
  }

  local function clearGsmMenus()
    arg_gsm_picker.clearState(ctx, gsmKeys)
  end

  local function reopenAddMenu()
    ctx.entryArgAddMenu = true
    ctx.entryArgAddSel = 1
    ctx.entryArgAddScroll = 0
  end

  local function openGsmPicker(row)
    arg_gsm_picker.open(ctx, gsmKeys, (row and row.egsmArgKey) or "-gsm")
  end

  if hasCdrom and not isBoot then
    ctx.entryArgAddMenu = nil
    ctx.entryArgAddSel = nil
    ctx.entryArgAddScroll = nil
    clearGsmMenus()
  end

  local function openUdpbdIpInput()
    openNewArgumentInput("UDPBD IP (x.x.x.x)", 15, function(val)
      local ip = tostring(val or ""):gsub("^%s+", ""):gsub("%s+$", "")
      if ip ~= "" then addUdpbdPair(ip) end
      ctx.state = "entry_args"
    end)
  end

  local function openUdpfsIpInput()
    openNewArgumentInput("UDPFS IP (x.x.x.x)", 15, function(val)
      local ip = tostring(val or ""):gsub("^%s+", ""):gsub("%s+$", "")
      if ip ~= "" then addUdpfsPair(ip) end
      ctx.state = "entry_args"
    end)
  end

  local function openTitleIdInput()
    openNewArgumentInput("TITLEID (up to 11 chars)", 11, function(val)
      local titleId = tostring(val or ""):gsub("^%s+", ""):gsub("%s+$", "")
      if titleId ~= "" then
        addArgValue("-titleid=" .. titleId)
      end
      ctx.state = "entry_args"
    end)
  end

  local function openDkwdrvPathInput()
    openNewArgumentInput("DKWDRV path", 79, function(val)
      local p = tostring(val or ""):gsub("^%s+", ""):gsub("%s+$", "")
      if p ~= "" then
        addArgValue("-dkwdrv=" .. p)
      end
      ctx.state = "entry_args"
    end)
  end

  if arg_gsm_picker.run(ctx, {
        keys = gsmKeys,
        onSubmit = function(arg, editIdx)
          local idx = math.floor(tonumber(editIdx) or 0)
          if idx >= 1 then
            local args2 = getArgs()
            if type(args2[idx]) == "table" then
              args2[idx].value = arg
            else
              args2[idx] = { value = arg, disabled = false }
            end
            setArgs(args2)
            local refreshed = getArgs()
            ctx.entryArgSel = findArgIndexByValue(refreshed, arg, idx)
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

  if ctx.entryArgAddMenu and #addRows > 0 then
    if arg_add_menu.run(ctx, {
          menuOpenKey = "entryArgAddMenu",
          selKey = "entryArgAddSel",
          scrollKey = "entryArgAddScroll",
          rows = addRows,
          title = "Add argument [" .. arg_profiles.getMenuTag(profileState) .. "]",
          descDefault = "Enter any custom argument manually.",
          rowStateKeyPrefix = "entry_args_add_row_",
          rowDisabledReason = function(row)
            return arg_presets.rowDisabled(row, usedKnown, usedModes, total)
          end,
          onSelect = function(row)
            if row.kind == "manual" then
              openNewArgumentInput(_.menu_str.new_argument_prompt, 79, function(val)
                local v = val or ""
                if v ~= "" then addArgValue(v) end
                ctx.state = "entry_args"
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

  ctx.entryArgSel = _.common.clampListSelection(ctx.entryArgSel or 1, total)
  ctx.entryArgScroll = _.common.centeredListScroll(ctx.entryArgSel, total, _.MAX_VISIBLE_LIST)

  local titleStr
  if isBoot then
    titleStr = ((_.strings.options and _.strings.options[ctx.bootKey] and _.strings.options[ctx.bootKey].label) or ctx.bootKey) ..
        " - " .. _.menu_str.arguments
  else
    local name = _.config_parse.getMenuEntryName(ctx.lines, ctx.entryIdx) or ""
    name = name ~= "" and name or (_.common_str.name_not_defined or _.common_str.empty)
    local prefix = "Arguments for "
    local suffix = " (entry " .. tostring(ctx.entryIdx) .. ")"
    local prefixW = _.common.calcTextWidth(_.font, prefix, 1) or 0
    local suffixW = _.common.calcTextWidth(_.font, suffix, 1) or 0
    local availableW = (_.w or 640) - 2 * _.MARGIN_X - prefixW - suffixW
    if availableW > 0 then
      name = _.common.truncateTextToWidth(_.font, name, availableW, 1)
    end
    titleStr = string.format(_.menu_str.args_for_entry_title, name, ctx.entryIdx)
  end
  if isBoot then
    _.common.drawBootTitle(_, ctx.bootKey, titleStr)
  else
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1, titleStr, _.WHITE)
  end
  if not isBoot and hasCdrom then
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y + _.scaleY(24), 0.75, _.menu_str.cdrom_hint, _.DIM_COLOR)
  end

  local startY = _.MARGIN_Y + _.scaleY(50)
  if _.common and _.common.drawListScrollbar then
    _.common.drawListScrollbar(_, {
      totalRows = total,
      visibleRows = _.MAX_VISIBLE_LIST,
      scrollRows = ctx.entryArgScroll,
      rowTopY = startY,
      rowHeight = _.LINE_H,
      color = _.DIM_COLOR,
    })
  end
  local maxLabelW = (_.w or 640) - (_.MARGIN_X + 24) - _.MARGIN_X
  for i = ctx.entryArgScroll + 1, math.min(ctx.entryArgScroll + _.MAX_VISIBLE_LIST, total) do
    local y = startY + (i - ctx.entryArgScroll - 1) * _.LINE_H
    local a = args[i]
    local av = type(a) == "table" and a.value or a
    local label = (av and av ~= "" and av) or _.common_str.empty
    if canMoveArgs and ctx.entryArgGrab and i == ctx.entryArgSel then
      label = "[" .. (_.menu_str.grabbed_tag or "Move") .. "] " .. label
    end
    if _.common.fitListRowText then
      label = _.common.fitListRowText(ctx, "entry_args_row_" .. tostring(i), _.font, label, maxLabelW, _.FONT_SCALE,
        i == ctx.entryArgSel)
    elseif _.common.truncateTextToWidth then
      label = _.common.truncateTextToWidth(_.font, label, maxLabelW, _.FONT_SCALE)
    end
    local col = (i == ctx.entryArgSel) and _.SELECTED_COLOR or _.UNSELECTED_COLOR
    if type(a) == "table" and (parentArgsDisabled or a.disabled) then
      col = (i == ctx.entryArgSel) and (_.SELECTED_DIM_COLOR or _.SELECTED_COLOR) or (_.DISABLED_DIM_COLOR or _.DIM_COLOR)
    end
    _.drawListRow(_.MARGIN_X + 20, y, i == ctx.entryArgSel, label, col)
  end

  local hasSelection = (ctx.entryArgSel >= 1 and ctx.entryArgSel <= total)
  local canAddArg = (isBoot or not hasCdrom)
  local selectedDisabled = hasSelection and type(args[ctx.entryArgSel]) == "table" and
      (parentArgsDisabled or args[ctx.entryArgSel].disabled)
  local crossPad = (hasSelection or canAddArg) and "cross" or ""
  local crossLabel = ""
  if hasSelection then
    crossLabel = ctx.entryArgGrab and (_.menu_str.confirm_label or "Confirm") or (_.menu_str.edit_label or "Edit")
  elseif canAddArg then
    crossLabel = (_.menu_str.insert_label or "Insert")
  end
  local argHints = {
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
      pad = (hasSelection and (not parentArgsDisabled)) and "triangle" or "",
      label = hasSelection and
          (selectedDisabled and (_.menu_str.enable_label or "Enable") or (_.menu_str.disable_label or "Disable")) or "",
      row = 1
    },
    {
      pad = "circle",
      label = ctx.entryArgGrab and (_.menu_str.cancel_label or "Cancel") or (_.menu_str.back_label or "Back"),
      row = 1
    },
  }
  _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, argHints, nil, _.DIM_COLOR, _.w - 2 * _.MARGIN_X)

  local function toggleSelectedArgDisabled()
    if parentArgsDisabled then return end
    if ctx.entryArgSel >= 1 and ctx.entryArgSel <= total and type(args[ctx.entryArgSel]) == "table" then
      if isBoot then
        _.config_parse.setBootArgDisabled(ctx.lines, ctx.bootKey, ctx.entryArgSel, not args[ctx.entryArgSel].disabled,
          bootKeyOpts)
      else
        _.config_parse.setArgDisabled(ctx.lines, ctx.entryIdx, ctx.entryArgSel, not args[ctx.entryArgSel].disabled)
      end
      markConfigMutated()
      invalidateArgsModel()
    end
  end

  local function moveSelectedArg(step)
    if not hasSelection or total <= 1 then return end
    local dst = ctx.entryArgSel + step
    if dst < 1 or dst > total then return end
    local args2 = getArgs()
    local movedItem = args2[ctx.entryArgSel]
    local movedValue = type(movedItem) == "table" and movedItem.value or movedItem
    args2[ctx.entryArgSel], args2[dst] = args2[dst], args2[ctx.entryArgSel]
    setArgs(args2)
    local refreshed = getArgs()
    ctx.entryArgSel = findArgIndexByValue(refreshed, movedValue, dst)
  end

  local function removeSelectedArg()
    if not hasSelection then return end
    local args2 = arg_presets.removeArgAndPairedUdpbd(getArgs(), ctx.entryArgSel, removeNhddlPair)
    setArgs(args2)
    ctx.entryArgSel = _.common.clampListSelection(ctx.entryArgSel, #args2)
    if #args2 == 0 then
      confirmMoveState()
    end
  end

  local function beginAddArg()
    if not canAddArg then return end
    if isBoot and total > 0 and hasSelection then
      ctx.entryArgInsertBelow = ctx.entryArgSel
    else
      ctx.entryArgInsertBelow = nil
    end
    confirmMoveState()
    ctx.entryArgAddMenu = true
    ctx.entryArgAddSel = 1
    ctx.entryArgAddScroll = 0
  end

  if ctx.entryArgsActionsOpen then
    local actionRows = {}
    if hasSelection and canMoveArgs then
      actionRows[#actionRows + 1] = {
        id = "grab",
        label = ctx.entryArgGrab and (_.menu_str.cancel_move_label or "Cancel move") or
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
          openKey = "entryArgsActionsOpen",
          selKey = "entryArgsActionsSel",
          scrollKey = "entryArgsActionsScroll",
          title = (_.menu_str.actions_title or "Actions"),
          rows = actionRows,
          rowStateKeyPrefix = "entry_args_actions_row_",
          onSelect = function(row)
            if row.id == "grab" then
              if ctx.entryArgGrab then
                cancelMoveState()
              else
                beginMoveState()
              end
            elseif row.id == "insert" then
              beginAddArg()
            elseif row.id == "remove" then
              removeSelectedArg()
            end
          end,
        }) then
      return
    end
  end

  if (_.padEffective & _.PAD_UP) ~= 0 then
    if ctx.entryArgGrab then
      moveSelectedArg(-1)
    else
      ctx.entryArgSel = _.common.moveListSelection(ctx.entryArgSel, total, -1, { ctx = ctx })
    end
  end
  if (_.padEffective & _.PAD_DOWN) ~= 0 then
    if ctx.entryArgGrab then
      moveSelectedArg(1)
    else
      ctx.entryArgSel = _.common.moveListSelection(ctx.entryArgSel, total, 1, { ctx = ctx })
    end
  end

  if (_.padEffective & _.PAD_TRIANGLE) ~= 0 then
    toggleSelectedArgDisabled()
  end

  if (_.padEffective & _.PAD_CROSS) ~= 0 then
    if ctx.entryArgGrab then
      confirmMoveState()
      return
    end
    if hasSelection then
      local editIdx = ctx.entryArgSel
      local editValue = type(args[editIdx]) == "table" and args[editIdx].value or args[editIdx]
      local gsmArgKey, gsmVideoIdx, gsmCompatIdx = arg_gsm_picker.parseExistingGsmArg(_, editValue)
      if gsmArgKey then
        arg_gsm_picker.open(ctx, gsmKeys, gsmArgKey, gsmVideoIdx, gsmCompatIdx)
        ctx[gsmKeys.editIdxKey] = editIdx
      else
        _.common.beginTextInput(ctx, {
          argEditIdx = editIdx,
          titleIdMode = nil,
          prompt = _.menu_str.edit_argument_prompt,
          value = editValue,
          maxLen = 79,
          callback = function(val)
            local args2 = getArgs()
            if type(args2[ctx.argEditIdx]) == "table" then
              args2[ctx.argEditIdx].value = val or ""
            else
              args2[ctx.argEditIdx] = { value = val or "", disabled = false }
            end
            setArgs(args2)
            local refreshed = getArgs()
            ctx.entryArgSel = findArgIndexByValue(refreshed, val or "", ctx.argEditIdx)
            ctx.state = "entry_args"
          end,
          returnState = "entry_args",
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

  if (_.padEffective & _.PAD_SQUARE) ~= 0 then
    _.common.openActionsMenu(ctx, "entryArgsActionsOpen", "entryArgsActionsSel", "entryArgsActionsScroll")
  end
  if ctx.configModified and (_.padEffective & _.PAD_START) ~= 0 then
    _.common.saveCurrentConfig(ctx)
  end

  if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
    if ctx.entryArgGrab then
      cancelMoveState()
      return
    end
    ctx.state = isBoot and "entry_paths" or "menu_entry_edit"
  end
end

return { run = run }
