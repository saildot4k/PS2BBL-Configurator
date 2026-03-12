--[[ Arguments list for a menu entry or MBR boot key (when ctx.bootKey is set and we're in MBR). ]]

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
  local hasNhddlElfPath = false
  for _, p in ipairs(paths or {}) do
    local pv = type(p) == "table" and p.value or p
    local pathLower = tostring(pv or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if pv == "cdrom" then hasCdrom = true end
    if pathLower:match("nhddl%.elf$") then hasNhddlElfPath = true end
    if hasCdrom and hasNhddlElfPath then break end
  end

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
  local function normalizeArg(v)
    return tostring(v or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
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
    ctx.argEditIdx = nil
    ctx.textInputTitleIdMode = nil
    ctx.textInputPrompt = prompt
    ctx.textInputValue = ""
    ctx.textInputMaxLen = maxLen
    ctx.textInputCallback = callback
    ctx.textInputReturnState = "entry_args"
    ctx.textInputGridSel = 1
    ctx.textInputCursor = 1
    ctx.textInputScroll = 1
    ctx.state = "text_input"
  end
  local function getUdpbdPairState(list)
    local hasModeUdpbd = false
    local hasUdpbdIp = false
    for _, item in ipairs(list or {}) do
      local av = type(item) == "table" and item.value or item
      local a = normalizeArg(av)
      if a:match("^%-mode=%s*udpbd%s*$") then
        hasModeUdpbd = true
      elseif a:match("^%-udpbd_ip=") then
        hasUdpbdIp = true
      end
    end
    return hasModeUdpbd, hasUdpbdIp
  end
  local function addUdpbdPair(ipValue)
    local ip = tostring(ipValue or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if ip == "" then return false end
    local args2 = getArgs()
    local hasModeUdpbd, hasUdpbdIp = getUdpbdPairState(args2)
    if not hasModeUdpbd then table.insert(args2, { value = "-mode=udpbd", disabled = false }) end
    if not hasUdpbdIp then table.insert(args2, { value = "-udpbd_ip=" .. ip, disabled = false }) end
    setArgs(args2)
    ctx.entryArgSel = #args2
    return true
  end

  local args = getArgs()
  local total = #args

  local usedKnown = {
    dev9 = false,
    patinfo = false,
    video = false,
    udpbd_ip = false,
    noinit = false,
  }
  local usedModes = {}
  for _, item in ipairs(args) do
    local av = type(item) == "table" and item.value or item
    local a = normalizeArg(av)
    if a:match("^%-video=") then
      usedKnown.video = true
    elseif a:match("^%-udpbd_ip=") then
      usedKnown.udpbd_ip = true
    elseif a == "-noinit" then
      usedKnown.noinit = true
    elseif a == "-patinfo" then
      usedKnown.patinfo = true
    elseif a:match("^%-dev9=") then
      usedKnown.dev9 = true
    else
      local mv = a:match("^%-mode=%s*(.+)$")
      if mv and mv ~= "" then
        mv = mv:gsub("^%s+", ""):gsub("%s+$", "")
        if mv ~= "" then usedModes[mv] = true end
      end
    end
  end

  local nhddlPresetRows = nil
  if hasNhddlElfPath then
    nhddlPresetRows = {
      {
        label = "Enter manually",
        kind = "manual",
        desc = "Enter any custom argument manually.",
      },
      {
        label = "-video=ntsc",
        value = "-video=ntsc",
        desc = "NHDDL: force NTSC video mode.",
        uniqueKey = "video",
      },
      {
        label = "-video=pal",
        value = "-video=pal",
        desc = "NHDDL: force PAL video mode.",
        uniqueKey = "video",
      },
      {
        label = "-video=480p",
        value = "-video=480p",
        desc = "NHDDL/Neutrino: request 480p (build-dependent).",
        uniqueKey = "video",
      },
      {
        label = "-mode=usb",
        value = "-mode=usb",
        desc = "NHDDL: initialize USB mode only.",
        modeValue = "usb",
      },
      {
        label = "-mode=mx4sio",
        value = "-mode=mx4sio",
        desc = "NHDDL: initialize MX4SIO mode only.",
        modeValue = "mx4sio",
      },
      {
        label = "-mode=mmce",
        value = "-mode=mmce",
        desc = "NHDDL: initialize MMCE mode only.",
        modeValue = "mmce",
      },
      {
        label = "-mode=ilink",
        value = "-mode=ilink",
        desc = "NHDDL: initialize iLink mode only.",
        modeValue = "ilink",
      },
      {
        label = "-mode=ata",
        value = "-mode=ata",
        desc = "NHDDL: initialize ATA mode only.",
        modeValue = "ata",
      },
      {
        label = "-mode=hdl",
        value = "-mode=hdl",
        desc = "NHDDL: initialize HDL mode only.",
        modeValue = "hdl",
      },
      {
        label = "-mode=udpbd",
        value = "-mode=udpbd",
        desc = "NHDDL UDPBD mode; requires -udpbd_ip=<IP> (paired automatically).",
        modeValue = "udpbd",
      },
      {
        label = "-udpbd_ip=<ip>",
        kind = "udpbd_ip",
        desc = "NHDDL UDPBD IP; requires -mode=udpbd (paired automatically).",
        uniqueKey = "udpbd_ip",
      },
      {
        label = "-noinit",
        value = "-noinit",
        desc = "NHDDL: skip IOP initialization (advanced).",
        uniqueKey = "noinit",
      },
      {
        label = "-dev9=NICHDD",
        value = "-dev9=NICHDD",
        desc = "Keep both DEV9 (network) and HDD powered/on.",
        uniqueKey = "dev9",
      },
      {
        label = "-dev9=NIC",
        value = "-dev9=NIC",
        desc = "Keep DEV9 on; unmount pfs0: and idle hdd0:/hdd1:.",
        uniqueKey = "dev9",
      },
      {
        label = "-patinfo",
        value = "-patinfo",
        desc = "Enable PATINFO launch handling for :PATINFO paths.",
        uniqueKey = "patinfo",
      },
    }
  else
    ctx.entryArgAddMenu = nil
    ctx.entryArgAddSel = nil
    ctx.entryArgAddScroll = nil
  end

  if ctx.entryArgAddMenu and nhddlPresetRows then
    local rows = nhddlPresetRows
    local function rowDisabled(row)
      if not row then return true end
      if row.modeValue and row.modeValue ~= "" then
        return usedModes[row.modeValue] == true
      end
      if row.kind == "udpbd_ip" then
        return usedKnown.udpbd_ip == true
      end
      if not row.uniqueKey or row.uniqueKey == "" then return false end
      return usedKnown[row.uniqueKey] == true
    end
    local function isSelectable(idx)
      local row = rows[idx]
      return row ~= nil and (not rowDisabled(row))
    end
    local function moveSelection(step)
      local idx = ctx.entryArgAddSel or 1
      for _ = 1, #rows do
        idx = idx + step
        if idx < 1 then idx = #rows end
        if idx > #rows then idx = 1 end
        if isSelectable(idx) then
          ctx.entryArgAddSel = idx
          return
        end
      end
    end

    ctx.entryArgAddSel = ctx.entryArgAddSel or 1
    if ctx.entryArgAddSel < 1 then ctx.entryArgAddSel = 1 end
    if ctx.entryArgAddSel > #rows then ctx.entryArgAddSel = #rows end
    if not isSelectable(ctx.entryArgAddSel) then moveSelection(1) end
    ctx.entryArgAddScroll = ctx.entryArgAddScroll or 0
    if #rows > _.MAX_VISIBLE_LIST then
      ctx.entryArgAddScroll = ctx.entryArgAddSel - math.floor(_.MAX_VISIBLE_LIST / 2)
      ctx.entryArgAddScroll = math.max(0, math.min(ctx.entryArgAddScroll, #rows - _.MAX_VISIBLE_LIST))
    else
      ctx.entryArgAddScroll = 0
    end

    local titleAdd = "Add argument [NHDDL]"
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1, titleAdd, _.WHITE)
    local selected = rows[ctx.entryArgAddSel]
    local desc = selected and selected.desc or "Enter any custom argument manually."
    if _.common.truncateTextToWidth then
      desc = _.common.truncateTextToWidth(_.font, desc, (_.w or 640) - (_.MARGIN_X * 2), 0.6)
    end
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y + _.scaleY(22), 0.6, desc, _.DIM)

    local maxLabelW = (_.w or 640) - (_.MARGIN_X + 24) - _.MARGIN_X
    for i = ctx.entryArgAddScroll + 1, math.min(ctx.entryArgAddScroll + _.MAX_VISIBLE_LIST, #rows) do
      local row = rows[i]
      local text = row.label or ""
      local disabledRow = rowDisabled(row)
      if disabledRow then text = text .. " (in use)" end
      if _.common.fitListRowText then
        text = _.common.fitListRowText(ctx, "entry_args_add_row_" .. tostring(i), _.font, text, maxLabelW,
          _.FONT_SCALE, i == ctx.entryArgAddSel)
      elseif _.common.truncateTextToWidth then
        text = _.common.truncateTextToWidth(_.font, text, maxLabelW, _.FONT_SCALE)
      end
      local y = _.MARGIN_Y + _.scaleY(50) + (i - ctx.entryArgAddScroll - 1) * _.LINE_H
      local col = disabledRow and (_.DIM_ENTRY or _.DIM) or ((i == ctx.entryArgAddSel) and _.SELECTED_ENTRY or _.WHITE)
      _.drawListRow(_.MARGIN_X + 20, y, i == ctx.entryArgAddSel, text, col)
    end
    _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, {
      { pad = "cross", label = "Select", row = 1 },
      { pad = "circle", label = "Back", row = 1 },
    }, nil, _.DIM, _.w - 2 * _.MARGIN_X)

    if (_.padEffective & _.PAD_UP) ~= 0 then moveSelection(-1) end
    if (_.padEffective & _.PAD_DOWN) ~= 0 then moveSelection(1) end
    if (_.padEffective & _.PAD_CROSS) ~= 0 then
      local row = rows[ctx.entryArgAddSel]
      if row and not rowDisabled(row) then
        ctx.entryArgAddMenu = nil
        ctx.entryArgAddSel = nil
        ctx.entryArgAddScroll = nil
        if row.kind == "manual" then
          openNewArgumentInput(_.menu_str.new_argument_prompt, 79, function(val)
            local v = val or ""
            if v ~= "" then addArgValue(v) end
            ctx.state = "entry_args"
          end)
        elseif row.kind == "udpbd_ip" then
          openNewArgumentInput("UDPBD IP (x.x.x.x)", 15, function(val)
            local ip = tostring(val or ""):gsub("^%s+", ""):gsub("%s+$", "")
            if ip ~= "" then addUdpbdPair(ip) end
            ctx.state = "entry_args"
          end)
        elseif row.modeValue == "udpbd" and usedKnown.udpbd_ip ~= true then
          openNewArgumentInput("UDPBD IP (x.x.x.x)", 15, function(val)
            local ip = tostring(val or ""):gsub("^%s+", ""):gsub("%s+$", "")
            if ip ~= "" then addUdpbdPair(ip) end
            ctx.state = "entry_args"
          end)
        else
          addArgValue(row.value or "")
        end
      end
    end
    if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
      ctx.entryArgAddMenu = nil
      ctx.entryArgAddSel = nil
      ctx.entryArgAddScroll = nil
    end
    return
  end

  if ctx.entryArgSel < 1 then ctx.entryArgSel = 1 end
  if ctx.entryArgSel > total then ctx.entryArgSel = (total > 0) and total or 1 end
  if total > _.MAX_VISIBLE_LIST then
    ctx.entryArgScroll = ctx.entryArgSel - math.floor(_.MAX_VISIBLE_LIST / 2)
    ctx.entryArgScroll = math.max(0, math.min(ctx.entryArgScroll, total - _.MAX_VISIBLE_LIST))
  else
    ctx.entryArgScroll = 0
  end

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
    ctx.entryArgSel = ctx.entryArgSel - 1; if ctx.entryArgSel < 1 then ctx.entryArgSel = total end
  end
  if (_.padEffective & _.PAD_DOWN) ~= 0 then
    ctx.entryArgSel = ctx.entryArgSel + 1; if ctx.entryArgSel > total then ctx.entryArgSel = 1 end
  end

  if (_.padEffective & _.PAD_TRIANGLE) ~= 0 and not isBoot and ctx.entryArgSel >= 1 and ctx.entryArgSel <= total and
      type(args[ctx.entryArgSel]) == "table" then
    _.config_parse.setArgDisabled(ctx.lines, ctx.entryIdx, ctx.entryArgSel, not args[ctx.entryArgSel].disabled)
    ctx.configModified = true
  end

  if (_.padEffective & _.PAD_CROSS) ~= 0 then
    if ctx.entryArgSel >= 1 and ctx.entryArgSel <= #args then
      ctx.argEditIdx = ctx.entryArgSel
      ctx.textInputTitleIdMode = nil
      ctx.textInputPrompt = _.menu_str.edit_argument_prompt
      ctx.textInputValue = type(args[ctx.entryArgSel]) == "table" and args[ctx.entryArgSel].value or args[ctx.entryArgSel]
      ctx.textInputMaxLen = 79
      ctx.textInputCallback = function(val)
        local args2 = getArgs()
        if type(args2[ctx.argEditIdx]) == "table" then
          args2[ctx.argEditIdx].value = val or ""
        else
          args2[ctx.argEditIdx] = { value = val or "", disabled = false }
        end
        setArgs(args2)
        ctx.state = "entry_args"
      end
      ctx.textInputReturnState = "entry_args"
      ctx.textInputGridSel = 1
      ctx.textInputCursor = #ctx.textInputValue + 1
      ctx.textInputScroll = 1
      ctx.state = "text_input"
    end
  end

  if (_.padEffective & _.PAD_SELECT) ~= 0 and not hasCdrom then
    if hasNhddlElfPath and nhddlPresetRows then
      ctx.entryArgAddMenu = true
      ctx.entryArgAddSel = ctx.entryArgAddSel or 1
      ctx.entryArgAddScroll = ctx.entryArgAddScroll or 0
    else
      openNewArgumentInput(_.menu_str.new_argument_prompt, 79, function(val)
        if (val or "") ~= "" then
          local args2 = getArgs(); table.insert(args2, { value = val, disabled = false }); setArgs(args2)
        end
        ctx.state = "entry_args"
      end)
    end
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
      local args2 = getArgs()
      local removed = args2[ctx.entryArgSel]
      local removedVal = normalizeArg(type(removed) == "table" and removed.value or removed)
      local removedModeUdpbd = removedVal:match("^%-mode=%s*udpbd%s*$") ~= nil
      local removedUdpbdIp = removedVal:match("^%-udpbd_ip=") ~= nil
      table.remove(args2, ctx.entryArgSel)
      if hasNhddlElfPath and removedModeUdpbd then
        for i = #args2, 1, -1 do
          local av = normalizeArg(type(args2[i]) == "table" and args2[i].value or args2[i])
          if av:match("^%-udpbd_ip=") then
            table.remove(args2, i)
            break
          end
        end
      elseif hasNhddlElfPath and removedUdpbdIp then
        for i = #args2, 1, -1 do
          local av = normalizeArg(type(args2[i]) == "table" and args2[i].value or args2[i])
          if av:match("^%-mode=%s*udpbd%s*$") then
            table.remove(args2, i)
            break
          end
        end
      end
      setArgs(args2)
      if ctx.entryArgSel > #args2 then ctx.entryArgSel = math.max(1, #args2) end
    end
  end

  if (_.padEffective & _.PAD_CIRCLE) ~= 0 then ctx.state = isBoot and "entry_paths" or "menu_entry_edit" end
end

return { run = run }
