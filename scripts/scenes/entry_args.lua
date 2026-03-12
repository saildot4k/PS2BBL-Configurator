--[[ Arguments list for a menu entry or MBR boot key (when ctx.bootKey is set and we're in MBR). ]]

local arg_presets = dofile("scripts/scenes/arg_presets.lua")
local arg_profiles = dofile("scripts/scenes/arg_profiles.lua")
local arg_gsm_picker = dofile("scripts/scenes/arg_gsm_picker.lua")
local arg_add_menu = dofile("scripts/scenes/arg_add_menu.lua")

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
  local hasOsdOrShutdown = false
  for _, p in ipairs(paths or {}) do
    local pv = type(p) == "table" and p.value or p
    if (pv or ""):upper() == "OSDSYS" or (pv or ""):upper() == "POWEROFF" then
      hasOsdOrShutdown = true; break
    end
  end
  if not isBoot and hasOsdOrShutdown then
    ctx.state = "menu_entry_edit"; return
  end

  local hasCdrom = false
  for _, p in ipairs(paths or {}) do
    if arg_presets.pathValue(p):lower() == "cdrom" then
      hasCdrom = true
      break
    end
  end
  local hasNhddlElfPath = arg_presets.hasNhddlElfPath(paths)

  local function getArgs()
    if isBoot then
      local a = _.config_parse.getBootArgs(ctx.lines, ctx.bootKey) or {}
      local t = {}
      for _, v in ipairs(a) do table.insert(t, { value = v, disabled = false }) end
      return t
    end
    return _.config_parse.getMenuEntryArgs(ctx.lines, ctx.entryIdx) or {}
  end

  local function setArgs(a)
    if isBoot then
      local v = {}
      for _, item in ipairs(a or {}) do table.insert(v, type(item) == "table" and item.value or item) end
      _.config_parse.setBootArgs(ctx.lines, ctx.bootKey, v)
      ctx.configModified = true
    else
      _.config_parse.setMenuEntryArgs(ctx.lines, ctx.entryIdx, a)
      ctx.configModified = true
    end
  end

  local function addArgValue(v)
    local value = tostring(v or "")
    if value == "" then return end
    local args2 = getArgs()
    table.insert(args2, { value = value, disabled = false })
    setArgs(args2)
    ctx.entryArgSel = #args2
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
    ctx.entryArgSel = #args2
    return true
  end

  local args = getArgs()
  local total = #args
  local usedKnown, usedModes = arg_presets.collectUsedArgs(args)
  local profileState = arg_profiles.resolve({
    surface = "entry_args",
    context = ctx.context,
    fileType = ctx.fileType,
    isBoot = isBoot,
    hasNhddlPath = hasNhddlElfPath,
  })
  local addRows = arg_profiles.buildAddRows(profileState)
  local removeNhddlPair = arg_profiles.profileUsesNhddl(profileState.activeProfileId)

  local function clearGsmMenus()
    ctx.entryArgGsmVideoMenu = nil
    ctx.entryArgGsmVideoSel = nil
    ctx.entryArgGsmVideoScroll = nil
    ctx.entryArgGsmCompatMenu = nil
    ctx.entryArgGsmCompatSel = nil
    ctx.entryArgGsmCompatScroll = nil
    ctx.entryArgGsmVideoIdx = nil
    ctx.entryArgGsmArgKey = nil
  end

  local function reopenAddMenu()
    ctx.entryArgAddMenu = true
    ctx.entryArgAddSel = ctx.entryArgAddSel or 1
    ctx.entryArgAddScroll = ctx.entryArgAddScroll or 0
  end

  local function openGsmPicker(row)
    clearGsmMenus()
    ctx.entryArgGsmArgKey = (row and row.egsmArgKey) or "-gsm"
    ctx.entryArgGsmVideoMenu = true
    ctx.entryArgGsmVideoSel = ctx.entryArgGsmVideoSel or 1
    ctx.entryArgGsmVideoScroll = ctx.entryArgGsmVideoScroll or 0
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

  local function openTitleIdInput()
    openNewArgumentInput("TITLEID (up to 11 chars)", 11, function(val)
      local titleId = tostring(val or ""):gsub("^%s+", ""):gsub("%s+$", "")
      if titleId ~= "" then
        addArgValue("-titleid=" .. titleId)
      end
      ctx.state = "entry_args"
    end)
  end

  if ctx.entryArgGsmCompatMenu then
    local compatRows = arg_gsm_picker.buildCompatRows(_)
    if #compatRows == 0 then
      clearGsmMenus()
      reopenAddMenu()
    elseif arg_add_menu.run(ctx, {
          menuOpenKey = "entryArgGsmCompatMenu",
          selKey = "entryArgGsmCompatSel",
          scrollKey = "entryArgGsmCompatScroll",
          rows = compatRows,
          title = arg_gsm_picker.compatTitle(_, ctx.entryArgGsmVideoIdx),
          descDefault = "Select compatibility mode.",
          rowStateKeyPrefix = "entry_args_gsm_compat_row_",
          onSelect = function(row)
            local arg = arg_gsm_picker.buildArg(_, ctx.entryArgGsmArgKey, ctx.entryArgGsmVideoIdx, row.compatIdx)
            clearGsmMenus()
            if arg and arg ~= "" then
              addArgValue(arg)
            end
          end,
          onCancel = function()
            ctx.entryArgGsmCompatMenu = nil
            ctx.entryArgGsmCompatSel = nil
            ctx.entryArgGsmCompatScroll = nil
            ctx.entryArgGsmVideoMenu = true
            ctx.entryArgGsmVideoSel = ctx.entryArgGsmVideoSel or 1
            ctx.entryArgGsmVideoScroll = ctx.entryArgGsmVideoScroll or 0
          end,
        }) then
      return
    end
  end

  if ctx.entryArgGsmVideoMenu then
    local videoRows = arg_gsm_picker.buildVideoRows(_)
    if #videoRows == 0 then
      clearGsmMenus()
      reopenAddMenu()
    elseif arg_add_menu.run(ctx, {
          menuOpenKey = "entryArgGsmVideoMenu",
          selKey = "entryArgGsmVideoSel",
          scrollKey = "entryArgGsmVideoScroll",
          rows = videoRows,
          title = arg_gsm_picker.videoTitle(_),
          descDefault = "Select eGSM video mode.",
          rowStateKeyPrefix = "entry_args_gsm_video_row_",
          onSelect = function(row)
            ctx.entryArgGsmVideoIdx = row.videoIdx
            ctx.entryArgGsmCompatMenu = true
            ctx.entryArgGsmCompatSel = ctx.entryArgGsmCompatSel or 1
            ctx.entryArgGsmCompatScroll = ctx.entryArgGsmCompatScroll or 0
          end,
          onCancel = function()
            clearGsmMenus()
            reopenAddMenu()
          end,
        }) then
      return
    end
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
            elseif row.kind == "udpbd_ip" then
              openUdpbdIpInput()
            elseif row.modeValue == "udpbd" and usedKnown.udpbd_ip ~= true then
              openUdpbdIpInput()
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
    name = name ~= "" and name or _.common_str.empty
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
  _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1, titleStr, _.WHITE)
  if not isBoot and hasCdrom then
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y + _.scaleY(24), 0.75, _.menu_str.cdrom_hint, _.DIM)
  end

  local maxLabelW = (_.w or 640) - (_.MARGIN_X + 24) - _.MARGIN_X
  for i = ctx.entryArgScroll + 1, math.min(ctx.entryArgScroll + _.MAX_VISIBLE_LIST, total) do
    local y = _.MARGIN_Y + _.scaleY(50) + (i - ctx.entryArgScroll - 1) * _.LINE_H
    local a = args[i]
    local av = type(a) == "table" and a.value or a
    local label = (av and av ~= "" and av) or _.common_str.empty
    if _.common.fitListRowText then
      label = _.common.fitListRowText(ctx, "entry_args_row_" .. tostring(i), _.font, label, maxLabelW, _.FONT_SCALE,
        i == ctx.entryArgSel)
    elseif _.common.truncateTextToWidth then
      label = _.common.truncateTextToWidth(_.font, label, maxLabelW, _.FONT_SCALE)
    end
    local col = (i == ctx.entryArgSel) and _.SELECTED_ENTRY or _.WHITE
    if not isBoot and type(a) == "table" and a.disabled then
      col = (i == ctx.entryArgSel) and (_.SELECTED_ENTRY_DIM or _.SELECTED_ENTRY) or (_.DIM_ENTRY or _.DIM)
    end
    _.drawListRow(_.MARGIN_X + 20, y, i == ctx.entryArgSel, label, col)
  end

  local argHints = _.menu_str.args_hint_items
  if not isBoot and ctx.entryArgSel >= 1 and ctx.entryArgSel <= total and type(args[ctx.entryArgSel]) == "table" then
    argHints = args[ctx.entryArgSel].disabled and (_.menu_str.args_hint_items_with_enable or argHints)
        or (_.menu_str.args_hint_items_with_disable or argHints)
  end
  _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, argHints, nil, _.DIM, _.w - 2 * _.MARGIN_X)

  if (_.padEffective & _.PAD_UP) ~= 0 then
    ctx.entryArgSel = _.common.wrapListSelection(ctx.entryArgSel, total, -1)
  end
  if (_.padEffective & _.PAD_DOWN) ~= 0 then
    ctx.entryArgSel = _.common.wrapListSelection(ctx.entryArgSel, total, 1)
  end

  if (_.padEffective & _.PAD_TRIANGLE) ~= 0 and not isBoot and ctx.entryArgSel >= 1 and ctx.entryArgSel <= total and
      type(args[ctx.entryArgSel]) == "table" then
    _.config_parse.setArgDisabled(ctx.lines, ctx.entryIdx, ctx.entryArgSel, not args[ctx.entryArgSel].disabled)
    ctx.configModified = true
  end

  if (_.padEffective & _.PAD_CROSS) ~= 0 then
    if ctx.entryArgSel >= 1 and ctx.entryArgSel <= #args then
      local editIdx = ctx.entryArgSel
      local editValue = type(args[editIdx]) == "table" and args[editIdx].value or args[editIdx]
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
          ctx.state = "entry_args"
        end,
        returnState = "entry_args",
        gridSel = 1,
        scroll = 1,
        state = "text_input",
      })
    end
  end

  if (_.padEffective & _.PAD_SELECT) ~= 0 and (isBoot or not hasCdrom) then
    ctx.entryArgAddMenu = true
    ctx.entryArgAddSel = ctx.entryArgAddSel or 1
    ctx.entryArgAddScroll = ctx.entryArgAddScroll or 0
  end

  if (_.padEffective & _.PAD_L1) ~= 0 then
    if ctx.entryArgSel >= 1 and ctx.entryArgSel <= total and ctx.entryArgSel > 1 then
      local args2 = getArgs(); args2[ctx.entryArgSel], args2[ctx.entryArgSel - 1] = args2[ctx.entryArgSel - 1],
          args2[ctx.entryArgSel]; setArgs(args2)
      ctx.entryArgSel = ctx.entryArgSel - 1
    end
  end
  if (_.padEffective & _.PAD_R1) ~= 0 then
    if ctx.entryArgSel >= 1 and ctx.entryArgSel <= total and ctx.entryArgSel < total then
      local args2 = getArgs(); args2[ctx.entryArgSel], args2[ctx.entryArgSel + 1] = args2[ctx.entryArgSel + 1],
          args2[ctx.entryArgSel]; setArgs(args2)
      ctx.entryArgSel = ctx.entryArgSel + 1
    end
  end

  if (_.padEffective & _.PAD_SQUARE) ~= 0 then
    if ctx.entryArgSel >= 1 and ctx.entryArgSel <= total then
      local args2 = arg_presets.removeArgAndPairedUdpbd(getArgs(), ctx.entryArgSel, removeNhddlPair)
      setArgs(args2)
      ctx.entryArgSel = _.common.clampListSelection(ctx.entryArgSel, #args2)
    end
  end

  if (_.padEffective & _.PAD_CIRCLE) ~= 0 then ctx.state = isBoot and "entry_paths" or "menu_entry_edit" end
end

return { run = run }
