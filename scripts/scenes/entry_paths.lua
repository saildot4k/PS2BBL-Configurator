--[[ Paths list for a menu entry or MBR boot key (when ctx.bootKey is set and we're in MBR). ]]

local actions_menu = dofile("scripts/scenes/actions_menu.lua")

local function run(ctx)
  local _ = ctx._
  local function isE1LockedPath(pathVal)
    local p = tostring(pathVal or "")
    if p:lower() == "cdrom" then return true end
    local up = p:upper()
    return up == "OSDSYS" or up == "POWEROFF" or up == "FASTBOOT"
  end
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
    if ctx.entryPathsBootKeyDisabledTag ~= bootKeyTag or ctx.entryPathsBootKeyDisabledOverride == nil then
      ctx.entryPathsBootKeyDisabledTag = bootKeyTag
      ctx.entryPathsBootKeyDisabledOverride =
          (_.config_parse.isBootKeyDisabled and _.config_parse.isBootKeyDisabled(ctx.lines, ctx.bootKey)) and true or false
    end
    bootKeyDisabledOverride = ctx.entryPathsBootKeyDisabledOverride and true or false
    bootKeyOpts = { keyDisabledOverride = bootKeyDisabledOverride }
  end
  local parentPathsDisabled = false
  if isBoot then
    parentPathsDisabled = bootKeyDisabledOverride and true or false
  else
    parentPathsDisabled = (_.config_parse.isMenuEntryDisabled and _.config_parse.isMenuEntryDisabled(ctx.lines, ctx.entryIdx)) and
        true or false
  end
  local paths = {}
  local hasArgsPaths = false
  local hasSpecialArgsPath = false
  local hasFirstExclusivePath = false
  local function buildPathScan()
    local outPaths = isBoot and (_.config_parse.getBootPathEntries(ctx.lines, ctx.bootKey, bootKeyOpts) or {}) or
        _.config_parse.getMenuEntryPaths(ctx.lines, ctx.entryIdx)
    local outHasArgs = false
    local outHasSpecialArgs = false
    local outHasFirstExclusive = false
    for i, p in ipairs(outPaths) do
      local pv = type(p) == "table" and p.value or p
      local flags = _.file_selector.getPathFlags and _.file_selector.getPathFlags(pv) or {}
      if not flags.noargs then outHasArgs = true end
      if flags.specialargs then outHasSpecialArgs = true end
      if i == 1 and isE1LockedPath(pv) then outHasFirstExclusive = true end
    end
    return outPaths, outHasArgs, outHasSpecialArgs, outHasFirstExclusive
  end
  local function getPathScanCache()
    local cache = ctx.entryPathsScanCache
    if cache and cache.sceneEpoch == sceneEpoch and cache.linesRef == ctx.lines and
        cache.isBoot == isBoot and cache.entryIdx == (ctx.entryIdx or 0) and cache.bootKey == (ctx.bootKey or "") then
      return cache
    end
    local outPaths, outHasArgs, outHasSpecialArgs, outHasFirstExclusive = buildPathScan()
    cache = {
      sceneEpoch = sceneEpoch,
      linesRef = ctx.lines,
      isBoot = isBoot,
      entryIdx = ctx.entryIdx or 0,
      bootKey = ctx.bootKey or "",
      paths = outPaths,
      hasArgsPaths = outHasArgs,
      hasSpecialArgsPath = outHasSpecialArgs,
      hasFirstExclusivePath = outHasFirstExclusive,
    }
    ctx.entryPathsScanCache = cache
    return cache
  end
  local function invalidatePathScanCache()
    ctx.entryPathsScanCache = nil
  end
  local function applyPathScan(cache)
    paths = cache.paths or {}
    hasArgsPaths = cache.hasArgsPaths and true or false
    hasSpecialArgsPath = cache.hasSpecialArgsPath and true or false
    hasFirstExclusivePath = cache.hasFirstExclusivePath and true or false
  end
  applyPathScan(getPathScanCache())
  local function refreshPaths()
    invalidatePathScanCache()
    applyPathScan(getPathScanCache())
    if #paths <= 1 then
      ctx.entryPathGrab = nil
    end
  end
  local function clearMoveState()
    ctx.entryPathGrab = nil
    ctx.entryPathMoveSnapshot = nil
    ctx.entryPathMoveSel = nil
  end
  local function beginMoveState()
    if ctx.entryPathGrab then return end
    if _.common and _.common.cloneConfigLines then
      ctx.entryPathMoveSnapshot = _.common.cloneConfigLines(ctx.lines)
    else
      ctx.entryPathMoveSnapshot = nil
    end
    ctx.entryPathMoveSel = ctx.entryPathSel
    ctx.entryPathGrab = true
  end
  local function confirmMoveState()
    clearMoveState()
  end
  local function cancelMoveState()
    if ctx.entryPathMoveSnapshot then
      if _.common and _.common.cloneConfigLines then
        ctx.lines = _.common.cloneConfigLines(ctx.entryPathMoveSnapshot)
      else
        ctx.lines = ctx.entryPathMoveSnapshot
      end
      refreshPaths()
      ctx.entryPathSel = _.common.clampListSelection(ctx.entryPathMoveSel or ctx.entryPathSel, #paths)
      _.common.refreshConfigModified(ctx)
    end
    clearMoveState()
  end
  local pathRows = #paths
  local canMovePaths = pathRows > 1
  if not canMovePaths then
    confirmMoveState()
  end
  local isFmcbEntry = (not isBoot) and ((ctx.fileType == "freemcboot_cnf") or (ctx.context == "freehddboot"))
  local maxPathsPerEntry = (isFmcbEntry and ((_.config_options and _.config_options.FMCB_MAX_PATHS_PER_ENTRY) or 3)) or nil
  local canAddPathBase = (not isFmcbEntry) or (pathRows < maxPathsPerEntry)
  local canAddPath = canAddPathBase and (not hasFirstExclusivePath)
  local total = pathRows
  if isBoot and (hasArgsPaths or hasSpecialArgsPath) then total = total + 1 end -- Arguments or Launch Disc options row
  if ctx.entryPathSel < 1 then ctx.entryPathSel = 1 end
  if ctx.entryPathSel > total then ctx.entryPathSel = (total > 0) and total or 1 end
  if total > _.MAX_VISIBLE_LIST then
    ctx.entryPathScroll = ctx.entryPathSel - math.floor(_.MAX_VISIBLE_LIST / 2)
    ctx.entryPathScroll = math.max(0, math.min(ctx.entryPathScroll, total - _.MAX_VISIBLE_LIST))
  else
    ctx.entryPathScroll = 0
  end
  local titleStr
  if isBoot then
    titleStr = (_.strings.options and _.strings.options[ctx.bootKey] and _.strings.options[ctx.bootKey].label) or
        ctx.bootKey
  else
    local name = _.config_parse.getMenuEntryName(ctx.lines, ctx.entryIdx) or ""
    name = name ~= "" and name or (_.common_str.name_not_defined or _.common_str.empty)
    local prefix = "Paths for "
    local suffix = " (entry " .. tostring(ctx.entryIdx) .. ")"
    local prefixW = _.common.calcTextWidth(_.font, prefix, 1) or 0
    local suffixW = _.common.calcTextWidth(_.font, suffix, 1) or 0
    local availableW = (_.w or 640) - 2 * _.MARGIN_X - prefixW - suffixW
    if availableW > 0 then
      name = _.common.truncateTextToWidth(_.font, name, availableW, 1)
    end
    titleStr = string.format(_.menu_str.paths_for_entry_title, name, ctx.entryIdx)
  end
  if isBoot then
    _.common.drawBootTitle(_, ctx.bootKey, titleStr)
  else
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1, titleStr, _.WHITE)
  end
  local startY = _.MARGIN_Y + _.scaleY(50)
  if _.common and _.common.drawListScrollbar then
    _.common.drawListScrollbar(_, {
      totalRows = total,
      visibleRows = _.MAX_VISIBLE_LIST,
      scrollRows = ctx.entryPathScroll,
      rowTopY = startY,
      rowHeight = _.LINE_H,
      color = _.DIM_COLOR,
    })
  end
  local argsRow = pathRows + 1
  local argsRowIsSpecial = hasSpecialArgsPath and (not hasArgsPaths or #paths == 1)
  local function pathLabel(p)
    if p == "" then return _.common_str.empty end
    if p == "cdrom" then return _.dev_str.launch_disc end
    if p == "dvd" then return _.dev_str.dvd_player end
    if (p or ""):upper() == "$HOSDSYS" then return _.dev_str.hosdsys end
    if (p or ""):upper() == "$PSBBN" then return _.dev_str.psbbn end
    if p == "hdd0:__system:pfs:/p2lboot/osdboot.elf" then
      local linuxArgs = nil
      if isBoot and ctx.bootKey and _.config_parse.getBootArgEntries then
        linuxArgs = _.config_parse.getBootArgEntries(ctx.lines, ctx.bootKey, bootKeyOpts) or {}
      elseif (not isBoot) and ctx.entryIdx and _.config_parse.getMenuEntryArgs then
        linuxArgs = _.config_parse.getMenuEntryArgs(ctx.lines, ctx.entryIdx) or {}
      end
      if linuxArgs then
        for _, item in ipairs(linuxArgs) do
          local value = type(item) == "table" and item.value or item
          if value == "pfs0:/p2lboot/ps2-linux-vga" then return _.dev_str.ps2_linux_vga or "PS2 Linux VGA" end
          if value == "pfs0:/p2lboot/ps2-linux-ntsc" then return _.dev_str.ps2_linux_ntsc or "PS2 Linux NTSC" end
        end
      end
      return _.dev_str.ps2_linux_ntsc or "PS2 Linux NTSC"
    end
    if (p or ""):upper() == "$XOSD" then return _.dev_str.xosd or "XOSD (PSX ONLY!)" end
    if (p or ""):upper() == "$OSDMENU" then return _.dev_str.osdmenu_psx or "OSDMenu (PSX ONLY!)" end
    if p == "OSDSYS" or p == "osdsys" then return _.dev_str.osd end
    if p == "POWEROFF" or p == "poweroff" then return _.dev_str.shutdown end
    if _.common and _.common.normalizePathForDisplay then
      return _.common.normalizePathForDisplay(p)
    end
    return p
  end
  local maxLabelW = (_.w or 640) - (_.MARGIN_X + 24) - _.MARGIN_X
  for i = ctx.entryPathScroll + 1, math.min(ctx.entryPathScroll + _.MAX_VISIBLE_LIST, total) do
    local y = startY + (i - ctx.entryPathScroll - 1) * _.LINE_H
    local label
    if isBoot and (hasArgsPaths or hasSpecialArgsPath) and i == argsRow then
      if argsRowIsSpecial then
        local args = _.config_parse.getBootArgs(ctx.lines, ctx.bootKey, bootKeyOpts) or {}
        label = _.menu_str.launch_disc_options .. (#args == 0 and "" or (" (" .. #args .. ")"))
      else
        local args = _.config_parse.getBootArgs(ctx.lines, ctx.bootKey, bootKeyOpts) or {}
        label = _.menu_str.arguments .. (#args == 0 and "" or (" (" .. #args .. ")"))
      end
    else
      local pathStr = type(paths[i]) == "table" and paths[i].value or paths[i]
      label = pathLabel(pathStr or "")
    end
    if _.common.fitListRowText then
      label = _.common.fitListRowText(ctx, "entry_paths_row_" .. tostring(i), _.font, label, maxLabelW, _.FONT_SCALE,
        i == ctx.entryPathSel)
    elseif _.common.truncateTextToWidth then
      label = _.common.truncateTextToWidth(_.font, label, maxLabelW, _.FONT_SCALE)
    end
    local col = (i == ctx.entryPathSel) and _.SELECTED_COLOR or _.UNSELECTED_COLOR
    if i <= pathRows and type(paths[i]) == "table" and (parentPathsDisabled or paths[i].disabled) then
      col = (i == ctx.entryPathSel) and (_.SELECTED_DIM_COLOR or _.SELECTED_COLOR) or (_.DISABLED_DIM_COLOR or _.DIM_COLOR)
    end
    if canMovePaths and ctx.entryPathGrab and i == ctx.entryPathSel and i <= pathRows then
      label = "[" .. (_.menu_str.grabbed_tag or "Move") .. "] " .. label
    end
    _.drawListRow(_.MARGIN_X + 20, y, i == ctx.entryPathSel, label, col)
  end
  local hasPathSelection = (ctx.entryPathSel >= 1 and ctx.entryPathSel <= pathRows)
  local argsRowSelected = isBoot and (hasArgsPaths or hasSpecialArgsPath) and ctx.entryPathSel == argsRow
  local selectedPathDisabled = hasPathSelection and type(paths[ctx.entryPathSel]) == "table" and
      ((parentPathsDisabled or paths[ctx.entryPathSel].disabled) and true or false)
  local canTogglePathDisabled = hasPathSelection and type(paths[ctx.entryPathSel]) == "table"
  local crossLabel = ""
  if ctx.entryPathGrab then
    crossLabel = (_.menu_str.confirm_label or "Confirm")
  elseif hasPathSelection or argsRowSelected then
    crossLabel = (_.menu_str.edit_label or "Edit")
  elseif canAddPath then
    crossLabel = (_.menu_str.insert_label or "Insert")
  end
  local pathHints = {
    {
      pad = crossLabel ~= "" and "cross" or "",
      label = crossLabel,
      row = 1
    },
    { pad = "square", label = _.menu_str.actions_label or "Actions", row = 1 },
    {
      pad = ctx.configModified and "start" or "",
      label = ctx.configModified and (_.menu_str.save_config_label or "Save") or "",
      row = 1
    },
    {
      pad = canTogglePathDisabled and "triangle" or "",
      label = canTogglePathDisabled and
          (selectedPathDisabled and (_.menu_str.enable_label or "Enable") or (_.menu_str.disable_label or "Disable")) or "",
      row = 1
    },
    {
      pad = "circle",
      label = ctx.entryPathGrab and (_.menu_str.cancel_label or "Cancel") or (_.menu_str.back_label or "Back"),
      row = 1
    },
  }
  _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, pathHints, nil, _.DIM_COLOR,
    _.w - 2 * _.MARGIN_X)

  local function markConfigMutated()
    invalidatePathScanCache()
    ctx._configModifiedCache = nil
    ctx.configModified = true
  end

  local function openPathPicker(editIdx)
    local pickerContext = isBoot and "mbr" or (isFmcbEntry and "fmcb_entry" or "osdmenu")
    ctx.editKey = nil
    ctx.pathPickerForEntryIdx = isBoot and nil or ctx.entryIdx
    ctx.pathPickerBootKey = isBoot and ctx.bootKey or nil
    ctx.pathPickerBootKeyDisabled = isBoot and bootKeyDisabledOverride or nil
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
    ctx.pathPickerReturnState = "entry_paths"
    ctx.state = "path_picker"
  end
  local function toggleSelectedPathDisabled()
    if not (ctx.entryPathSel >= 1 and ctx.entryPathSel <= pathRows and type(paths[ctx.entryPathSel]) == "table") then return end
    local current = (parentPathsDisabled or (paths[ctx.entryPathSel].disabled and true or false)) and true or false
    local target = not current
    if isBoot then
      if parentPathsDisabled then
        if not target then
          local changed = _.config_parse.enableBootPathFromDisabledParent and
              _.config_parse.enableBootPathFromDisabledParent(ctx.lines, ctx.bootKey, ctx.entryPathSel)
          if changed then
            ctx.entryPathsBootKeyDisabledTag = tostring(ctx.bootKey or "")
            ctx.entryPathsBootKeyDisabledOverride = false
            ctx.entryArgsBootKeyDisabledTag = tostring(ctx.bootKey or "")
            ctx.entryArgsBootKeyDisabledOverride = false
            markConfigMutated()
          end
        end
        return
      end
      _.config_parse.setBootPathDisabled(ctx.lines, ctx.bootKey, ctx.entryPathSel, target, bootKeyOpts)
      markConfigMutated()
      return
    end
    if parentPathsDisabled then
      if not target then
        local changed = _.config_parse.enableMenuEntryPathFromDisabledParent and
            _.config_parse.enableMenuEntryPathFromDisabledParent(ctx.lines, ctx.entryIdx, ctx.entryPathSel)
        if changed then
          markConfigMutated()
        end
      end
      return
    end
    _.config_parse.setPathDisabled(ctx.lines, ctx.entryIdx, ctx.entryPathSel, target)
    markConfigMutated()
  end
  local function removeSelectedPath()
    if not hasPathSelection then return end
    refreshPaths()
    table.remove(paths, ctx.entryPathSel)
    if isBoot then
      _.config_parse.setBootPathEntries(ctx.lines, ctx.bootKey, paths, bootKeyOpts)
    else
      _.config_parse.setMenuEntryPaths(ctx.lines, ctx.entryIdx, paths)
    end
    markConfigMutated()
    refreshPaths()
    if ctx.entryPathSel > #paths then
      ctx.entryPathSel = math.max(1, #paths)
    end
  end
  local function insertPathFromActions()
    if not canAddPath then return end
    if isBoot and hasPathSelection then
      ctx.pathPickerInsertBelow = ctx.entryPathSel
    else
      ctx.pathPickerInsertBelow = nil
    end
    confirmMoveState()
    openPathPicker(nil)
  end
  local function swapSelectedPath(step)
    refreshPaths()
    if not hasPathSelection then return end
    local dst = ctx.entryPathSel + step
    if dst < 1 or dst > #paths then return end
    paths[ctx.entryPathSel], paths[dst] = paths[dst], paths[ctx.entryPathSel]
    if isBoot then
      _.config_parse.setBootPathEntries(ctx.lines, ctx.bootKey, paths, bootKeyOpts)
    else
      _.config_parse.setMenuEntryPaths(ctx.lines, ctx.entryIdx, paths)
    end
    markConfigMutated()
    ctx.entryPathSel = dst
    refreshPaths()
  end

  if ctx.entryPathsActionsOpen then
    local actionRows = {}
    if hasPathSelection and canMovePaths then
      actionRows[#actionRows + 1] = {
        id = "grab",
        label = ctx.entryPathGrab and (_.menu_str.cancel_move_label or "Cancel move") or
            (_.menu_str.grab_label or "Move"),
      }
    end
    if canAddPath then
      actionRows[#actionRows + 1] = { id = "insert", label = (_.menu_str.insert_label or "Insert") }
    end
    if hasPathSelection then
      actionRows[#actionRows + 1] = { id = "remove", label = (_.menu_str.remove_label or "Remove") }
    end
    if actions_menu.run(ctx, {
          openKey = "entryPathsActionsOpen",
          selKey = "entryPathsActionsSel",
          scrollKey = "entryPathsActionsScroll",
          title = (_.menu_str.actions_title or "Actions"),
          rows = actionRows,
          rowStateKeyPrefix = "entry_paths_actions_row_",
          onSelect = function(row)
            if row.id == "grab" then
              if ctx.entryPathGrab then
                cancelMoveState()
              else
                beginMoveState()
              end
            elseif row.id == "insert" then
              insertPathFromActions()
            elseif row.id == "remove" then
              removeSelectedPath()
            end
          end,
        }) then
      return
    end
  end

  if (_.padEffective & _.PAD_UP) ~= 0 then
    if ctx.entryPathGrab and hasPathSelection then
      swapSelectedPath(-1)
    else
      ctx.entryPathSel = ctx.entryPathSel - 1
      if ctx.entryPathSel < 1 then ctx.entryPathSel = total end
    end
  end
  if (_.padEffective & _.PAD_DOWN) ~= 0 then
    if ctx.entryPathGrab and hasPathSelection then
      swapSelectedPath(1)
    else
      ctx.entryPathSel = ctx.entryPathSel + 1
      if ctx.entryPathSel > total then ctx.entryPathSel = 1 end
    end
  end

  if (_.padEffective & _.PAD_TRIANGLE) ~= 0 then
    toggleSelectedPathDisabled()
  end
  if (_.padEffective & _.PAD_CROSS) ~= 0 then
    if ctx.entryPathGrab then
      confirmMoveState()
      return
    end
    if isBoot and (hasArgsPaths or hasSpecialArgsPath) and ctx.entryPathSel == argsRow then
      if argsRowIsSpecial then
        ctx.cdromOptSel = 1
        ctx.state = "entry_cdrom_options"
      else
        local args = _.config_parse.getBootArgs(ctx.lines, ctx.bootKey, bootKeyOpts) or {}
        if #args == 0 then
          ctx.entryArgAddMenu = true
          ctx.entryArgAddSel = 1
          ctx.entryArgAddScroll = 0
        end
        ctx.entryArgsBootKeyDisabledTag = tostring(ctx.bootKey or "")
        ctx.entryArgsBootKeyDisabledOverride = bootKeyDisabledOverride and true or false
        ctx.entryArgSel = 1
        ctx.entryArgScroll = 0
        ctx.state = "entry_args"
      end
    elseif ctx.entryPathSel >= 1 and ctx.entryPathSel <= #paths then
      openPathPicker(ctx.entryPathSel)
    elseif canAddPath and pathRows == 0 then
      -- After removing all paths, Cross should still insert by opening the device picker.
      confirmMoveState()
      openPathPicker(nil)
    end
  end
  if (_.padEffective & _.PAD_SQUARE) ~= 0 then
    _.common.openActionsMenu(ctx, "entryPathsActionsOpen", "entryPathsActionsSel", "entryPathsActionsScroll")
  end
  if ctx.configModified and (_.padEffective & _.PAD_START) ~= 0 then
    _.common.saveCurrentConfig(ctx)
  end
  if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
    if ctx.entryPathGrab then
      cancelMoveState()
      return
    end
    ctx.state = isBoot and "editor" or "menu_entry_edit"
  end
end

return { run = run }
