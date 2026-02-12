--[[ Paths list for a menu entry or MBR boot key (when ctx.bootKey is set and we're in MBR). ]]

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
  local paths = isBoot and (_.config_parse.getBootPaths(ctx.lines, ctx.bootKey) or {}) or
      _.config_parse.getMenuEntryPaths(ctx.lines, ctx.entryIdx)
  local hasExclusivePath = false
  local hasArgsPaths = false
  local hasSpecialArgsPath = false
  for i, p in ipairs(paths) do
    local flags = _.file_selector.getPathFlags and _.file_selector.getPathFlags(p) or {}
    if flags.exclusive then hasExclusivePath = true end
    if not flags.noargs then hasArgsPaths = true end
    if flags.specialargs then hasSpecialArgsPath = true end
  end
  local total = (hasExclusivePath and #paths) or (#paths + 1)
  if isBoot and (hasArgsPaths or hasSpecialArgsPath) then total = total + 1 end -- Arguments or Launch Disc options row
  if ctx.entryPathSel < 1 then ctx.entryPathSel = 1 end
  if ctx.entryPathSel > total then ctx.entryPathSel = total end
  if ctx.entryPathSel > ctx.entryPathScroll + _.MAX_VISIBLE then ctx.entryPathScroll = ctx.entryPathSel - _.MAX_VISIBLE end
  if ctx.entryPathSel < ctx.entryPathScroll + 1 then ctx.entryPathScroll = ctx.entryPathSel - 1 end
  local titleStr
  if isBoot then
    titleStr = (_.strings.options and _.strings.options[ctx.bootKey] and _.strings.options[ctx.bootKey].label) or
    ctx.bootKey
  else
    local name = _.config_parse.getMenuEntryName(ctx.lines, ctx.entryIdx) or ""
    titleStr = string.format(_.menu_str.paths_for_entry_title, name ~= "" and name or _.common_str.empty, ctx.entryIdx)
  end
  _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1, titleStr, _.WHITE)
  local pathRows = (hasExclusivePath and #paths) or (#paths + 1)
  local argsRow = pathRows + 1
  local argsRowIsSpecial = hasSpecialArgsPath and (not hasArgsPaths or #paths == 1)
  local function pathLabel(p)
    if p == "" then return _.common_str.empty end
    if p == "cdrom" then return _.dev_str.launch_disc end
    if p == "dvd" then return _.dev_str.dvd_player end
    if (p or ""):upper() == "$HOSDSYS" then return _.dev_str.hosdsys end
    if (p or ""):upper() == "$PSBBN" then return _.dev_str.psbbn end
    if p == "OSDSYS" or p == "osdsys" then return _.dev_str.osd end
    if p == "POWEROFF" or p == "poweroff" then return _.dev_str.shutdown end
    return p:sub(1, 50) .. (#p > 50 and "..." or "")
  end
  for i = ctx.entryPathScroll + 1, math.min(ctx.entryPathScroll + _.MAX_VISIBLE, total) do
    local y = _.MARGIN_Y + _.scaleY(50) + (i - ctx.entryPathScroll - 1) * _.LINE_H
    local label
    if isBoot and (hasArgsPaths or hasSpecialArgsPath) and i == argsRow then
      if argsRowIsSpecial then
        local args = _.config_parse.getBootArgs(ctx.lines, ctx.bootKey) or {}
        label = _.menu_str.launch_disc_options .. (#args == 0 and "" or (" (" .. #args .. ")"))
      else
        local args = _.config_parse.getBootArgs(ctx.lines, ctx.bootKey) or {}
        label = _.menu_str.arguments .. (#args == 0 and "" or (" (" .. #args .. ")"))
      end
    else
      local pathStr = (i <= #paths) and paths[i] or ""
      label = (i <= #paths) and pathLabel(pathStr) or _.menu_str.add_path
    end
    local col = (i == ctx.entryPathSel) and _.SELECTED_ENTRY or _.WHITE
    _.drawListRow(_.MARGIN_X + 20, y, i == ctx.entryPathSel, label, col)
  end
  _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, _.menu_str.paths_hint_items, nil, _.DIM,
    _.w - 2 * _.MARGIN_X)
  if (_.padEffective & _.PAD_UP) ~= 0 then
    ctx.entryPathSel = ctx.entryPathSel - 1; if ctx.entryPathSel < 1 then ctx.entryPathSel = total end
  end
  if (_.padEffective & _.PAD_DOWN) ~= 0 then
    ctx.entryPathSel = ctx.entryPathSel + 1; if ctx.entryPathSel > total then ctx.entryPathSel = 1 end
  end
  if (_.padEffective & _.PAD_CROSS) ~= 0 then
    if isBoot and (hasArgsPaths or hasSpecialArgsPath) and ctx.entryPathSel == argsRow then
      if argsRowIsSpecial then
        ctx.cdromOptSel = 1
        ctx.state = "entry_cdrom_options"
      else
        ctx.entryArgSel = 1
        ctx.entryArgScroll = 0
        ctx.state = "entry_args"
      end
    elseif (ctx.entryPathSel == pathRows and not hasExclusivePath) or (ctx.entryPathSel >= 1 and ctx.entryPathSel <= #paths) then
      local editIdx = (ctx.entryPathSel == pathRows and not hasExclusivePath) and nil or ctx.entryPathSel
      ctx.pathPickerForEntryIdx = isBoot and nil or ctx.entryIdx
      ctx.pathPickerBootKey = isBoot and ctx.bootKey or nil
      ctx.pathPickerEditIdx = editIdx
      ctx.pathPickerSub = "device"
      ctx.pathList = _.file_selector.getDevices(isBoot and "mbr" or "osdmenu") or {}
      ctx.pathPickerSel = 1
      ctx.pathPickerScroll = 0
      ctx.pathPickerContext = isBoot and "mbr" or "osdmenu"
      ctx.pathPickerReturnState = "entry_paths"
      ctx.state = "path_picker"
    end
  end
  if (_.padEffective & _.PAD_L1) ~= 0 then
    if ctx.entryPathSel >= 1 and ctx.entryPathSel <= #paths and ctx.entryPathSel > 1 then
      paths = isBoot and (_.config_parse.getBootPaths(ctx.lines, ctx.bootKey) or {}) or
          _.config_parse.getMenuEntryPaths(ctx.lines, ctx.entryIdx)
      paths[ctx.entryPathSel], paths[ctx.entryPathSel - 1] = paths[ctx.entryPathSel - 1], paths[ctx.entryPathSel]
      if isBoot then
        _.config_parse.setBootPaths(ctx.lines, ctx.bootKey, paths)
      else
        _.config_parse.setMenuEntryPaths(
          ctx.lines, ctx.entryIdx, paths)
      end
      ctx.configModified = true
      ctx.entryPathSel = ctx.entryPathSel - 1
    end
  end
  if (_.padEffective & _.PAD_R1) ~= 0 then
    if ctx.entryPathSel >= 1 and ctx.entryPathSel <= #paths and ctx.entryPathSel < #paths then
      paths = isBoot and (_.config_parse.getBootPaths(ctx.lines, ctx.bootKey) or {}) or
          _.config_parse.getMenuEntryPaths(ctx.lines, ctx.entryIdx)
      paths[ctx.entryPathSel], paths[ctx.entryPathSel + 1] = paths[ctx.entryPathSel + 1], paths[ctx.entryPathSel]
      if isBoot then
        _.config_parse.setBootPaths(ctx.lines, ctx.bootKey, paths)
      else
        _.config_parse.setMenuEntryPaths(
          ctx.lines, ctx.entryIdx, paths)
      end
      ctx.configModified = true
      ctx.entryPathSel = ctx.entryPathSel + 1
    end
  end
  if (_.padEffective & _.PAD_SQUARE) ~= 0 then
    if ctx.entryPathSel >= 1 and ctx.entryPathSel <= #paths then
      paths = isBoot and (_.config_parse.getBootPaths(ctx.lines, ctx.bootKey) or {}) or
          _.config_parse.getMenuEntryPaths(ctx.lines, ctx.entryIdx)
      table.remove(paths, ctx.entryPathSel)
      if isBoot then
        _.config_parse.setBootPaths(ctx.lines, ctx.bootKey, paths)
      else
        _.config_parse.setMenuEntryPaths(
          ctx.lines, ctx.entryIdx, paths)
      end
      ctx.configModified = true
      if ctx.entryPathSel > #paths then ctx.entryPathSel = math.max(1, #paths) end
    end
  end
  if (_.padEffective & _.PAD_CIRCLE) ~= 0 then ctx.state = isBoot and "editor" or "menu_entry_edit" end
end

return { run = run }
