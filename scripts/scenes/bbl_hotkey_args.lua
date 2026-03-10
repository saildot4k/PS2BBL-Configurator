--[[ Argument editor for one BBL hotkey slot (ARG_<HOTKEY>_E#). ]]

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

  local maxArgs = (_.config_parse.getBblMaxArgsPerEntry and _.config_parse.getBblMaxArgsPerEntry()) or 8
  local function getArgs()
    return _.config_parse.getBblHotkeyArgs(ctx.lines, keyId, slot) or {}
  end
  local function setArgs(args)
    _.config_parse.setBblHotkeyArgs(ctx.lines, keyId, slot, args)
    ctx.configModified = true
  end
  local function addArgValue(v)
    local value = tostring(v or "")
    if value == "" then return end
    local args2 = getArgs()
    if #args2 >= maxArgs then return end
    table.insert(args2, { value = value, disabled = false })
    setArgs(args2)
    ctx.bblArgSel = #args2
  end
  local function openNewArgumentInput(prompt, maxLen, callback)
    ctx.textInputTitleIdMode = nil
    ctx.textInputPrompt = prompt
    ctx.textInputValue = ""
    ctx.textInputMaxLen = maxLen
    ctx.textInputCallback = callback
    ctx.textInputReturnState = "bbl_hotkey_args"
    ctx.textInputGridSel = 1
    ctx.textInputCursor = 1
    ctx.textInputScroll = 1
    ctx.state = "text_input"
  end
  local function normalizeArg(v)
    return tostring(v or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
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
    local needMode = not hasModeUdpbd
    local needIp = not hasUdpbdIp
    local needCount = (needMode and 1 or 0) + (needIp and 1 or 0)
    if (#args2 + needCount) > maxArgs then return false end
    if needMode then table.insert(args2, { value = "-mode=udpbd", disabled = false }) end
    if needIp then table.insert(args2, { value = "-udpbd_ip=" .. ip, disabled = false }) end
    setArgs(args2)
    ctx.bblArgSel = #args2
    return true
  end

  local args = getArgs()
  local total = #args
  local entryPath = _.config_parse.getBblHotkeyPath(ctx.lines, keyId, slot)
  local entryPathLower = (type(entryPath) == "string") and entryPath:lower():gsub("^%s+", ""):gsub("%s+$", "") or ""
  local isNhddlElfPath = (entryPathLower:match("nhddl%.elf$") ~= nil)
  local usedKnown = {
    appid = false,
    titleid = false,
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
    if a == "-appid" then
      usedKnown.appid = true
    elseif a:match("^%-titleid=") then
      usedKnown.titleid = true
    elseif a:match("^%-dev9=") then
      usedKnown.dev9 = true
    elseif a == "-patinfo" then
      usedKnown.patinfo = true
    elseif a:match("^%-video=") then
      usedKnown.video = true
    elseif a:match("^%-udpbd_ip=") then
      usedKnown.udpbd_ip = true
    elseif a == "-noinit" then
      usedKnown.noinit = true
    else
      local mv = a:match("^%-mode=%s*(.+)$")
      if mv and mv ~= "" then
        mv = mv:gsub("^%s+", ""):gsub("%s+$", "")
        if mv ~= "" then usedModes[mv] = true end
      end
    end
  end

  local presetRows = {
    {
      label = "Enter manually",
      kind = "manual",
      desc = "Enter any custom argument manually.",
    },
  }

  if not isNhddlElfPath then
    table.insert(presetRows, {
      label = "-appid",
      value = "-appid",
      desc = "Forces app visual game ID even if APP_GAMEID = 0.",
      uniqueKey = "appid",
    })
    table.insert(presetRows, {
      label = "-titleid=<11 chars>",
      kind = "titleid",
      desc = "Overrides app title ID (up to 11 characters).",
      uniqueKey = "titleid",
    })
  end

  if isNhddlElfPath then
    table.insert(presetRows, {
      label = "-video=ntsc",
      value = "-video=ntsc",
      desc = "NHDDL: force NTSC video mode.",
      uniqueKey = "video",
    })
    table.insert(presetRows, {
      label = "-video=pal",
      value = "-video=pal",
      desc = "NHDDL: force PAL video mode.",
      uniqueKey = "video",
    })
    table.insert(presetRows, {
      label = "-video=480p",
      value = "-video=480p",
      desc = "NHDDL/Neutrino: request 480p (build-dependent).",
      uniqueKey = "video",
    })
    table.insert(presetRows, {
      label = "-mode=usb",
      value = "-mode=usb",
      desc = "NHDDL: initialize USB mode only.",
      modeValue = "usb",
    })
    table.insert(presetRows, {
      label = "-mode=mx4sio",
      value = "-mode=mx4sio",
      desc = "NHDDL: initialize MX4SIO mode only.",
      modeValue = "mx4sio",
    })
    table.insert(presetRows, {
      label = "-mode=mmce",
      value = "-mode=mmce",
      desc = "NHDDL: initialize MMCE mode only.",
      modeValue = "mmce",
    })
    table.insert(presetRows, {
      label = "-mode=ilink",
      value = "-mode=ilink",
      desc = "NHDDL: initialize iLink mode only.",
      modeValue = "ilink",
    })
    table.insert(presetRows, {
      label = "-mode=ata",
      value = "-mode=ata",
      desc = "NHDDL: initialize ATA mode only.",
      modeValue = "ata",
    })
    table.insert(presetRows, {
      label = "-mode=hdl",
      value = "-mode=hdl",
      desc = "NHDDL: initialize HDL mode only.",
      modeValue = "hdl",
    })
    table.insert(presetRows, {
      label = "-mode=udpbd",
      value = "-mode=udpbd",
      desc = "NHDDL UDPBD mode; requires -udpbd_ip=<IP> (paired automatically).",
      modeValue = "udpbd",
    })
    table.insert(presetRows, {
      label = "-udpbd_ip=<ip>",
      kind = "udpbd_ip",
      desc = "NHDDL UDPBD IP; requires -mode=udpbd (paired automatically).",
      uniqueKey = "udpbd_ip",
    })
    table.insert(presetRows, {
      label = "-noinit",
      value = "-noinit",
      desc = "NHDDL: skip IOP initialization (advanced).",
      uniqueKey = "noinit",
    })
  end

  table.insert(presetRows, {
    label = "-dev9=NICHDD",
    value = "-dev9=NICHDD",
    desc = "Keep both DEV9 (network) and HDD powered/on.",
    uniqueKey = "dev9",
  })
  table.insert(presetRows, {
    label = "-dev9=NIC",
    value = "-dev9=NIC",
    desc = "Keep DEV9 on; unmount pfs0: and idle hdd0:/hdd1:.",
    uniqueKey = "dev9",
  })
  table.insert(presetRows, {
    label = "-patinfo",
    value = "-patinfo",
    desc = "Enable PATINFO launch handling for :PATINFO paths.",
    uniqueKey = "patinfo",
  })

  if ctx.bblArgAddMenu and total >= maxArgs then
    ctx.bblArgAddMenu = nil
    ctx.bblArgAddSel = nil
    ctx.bblArgAddScroll = nil
  end
  if ctx.bblArgAddMenu then
    local rows = presetRows
    local function rowDisabled(row)
      if not row then return true end
      if row.modeValue and row.modeValue ~= "" then
        if row.modeValue == "udpbd" and usedModes["udpbd"] ~= true and usedKnown.udpbd_ip ~= true and total > (maxArgs - 2) then
          -- Need 2 slots to add missing pair (-mode=udpbd + -udpbd_ip=...).
          return true
        end
        return usedModes[row.modeValue] == true
      end
      if row.kind == "udpbd_ip" and usedKnown.udpbd_ip ~= true and usedModes["udpbd"] ~= true and total > (maxArgs - 2) then
        -- Need 2 slots to add missing pair (-mode=udpbd + -udpbd_ip=...).
        return true
      end
      if not row.uniqueKey or row.uniqueKey == "" then return false end
      return usedKnown[row.uniqueKey] == true
    end
    local function isSelectable(idx)
      local row = rows[idx]
      return row ~= nil and (not rowDisabled(row))
    end
    local function moveSelection(step)
      local idx = ctx.bblArgAddSel or 1
      for _ = 1, #rows do
        idx = idx + step
        if idx < 1 then idx = #rows end
        if idx > #rows then idx = 1 end
        if isSelectable(idx) then
          ctx.bblArgAddSel = idx
          return
        end
      end
    end
    ctx.bblArgAddSel = ctx.bblArgAddSel or 1
    if ctx.bblArgAddSel < 1 then ctx.bblArgAddSel = 1 end
    if ctx.bblArgAddSel > #rows then ctx.bblArgAddSel = #rows end
    if not isSelectable(ctx.bblArgAddSel) then
      moveSelection(1)
    end
    ctx.bblArgAddScroll = ctx.bblArgAddScroll or 0
    if #rows > _.MAX_VISIBLE_LIST then
      ctx.bblArgAddScroll = ctx.bblArgAddSel - math.floor(_.MAX_VISIBLE_LIST / 2)
      ctx.bblArgAddScroll = math.max(0, math.min(ctx.bblArgAddScroll, #rows - _.MAX_VISIBLE_LIST))
    else
      ctx.bblArgAddScroll = 0
    end

    local titleAdd = "Add argument (" .. tostring(total) .. "/" .. tostring(maxArgs) .. ")"
    if isNhddlElfPath then titleAdd = titleAdd .. " [NHDDL]" end
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1, titleAdd, _.WHITE)
    local selected = rows[ctx.bblArgAddSel]
    local desc = selected and selected.desc or "Enter any custom argument manually."
    if _.common.truncateTextToWidth then
      desc = _.common.truncateTextToWidth(_.font, desc, (_.w or 640) - (_.MARGIN_X * 2), 0.6)
    end
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y + _.scaleY(22), 0.6, desc, _.DIM)
    local maxLabelW = (_.w or 640) - (_.MARGIN_X + 24) - _.MARGIN_X
    for i = ctx.bblArgAddScroll + 1, math.min(ctx.bblArgAddScroll + _.MAX_VISIBLE_LIST, #rows) do
      local row = rows[i]
      local text = row.label or ""
      local disabledRow = rowDisabled(row)
      if disabledRow then
        if ((row.modeValue == "udpbd" and usedModes["udpbd"] ~= true and usedKnown.udpbd_ip ~= true) or
            (row.kind == "udpbd_ip" and usedKnown.udpbd_ip ~= true and usedModes["udpbd"] ~= true)) and
            total > (maxArgs - 2) then
          text = text .. " (needs 2 slots)"
        else
          text = text .. " (in use)"
        end
      end
      if _.common.truncateTextToWidth then
        text = _.common.truncateTextToWidth(_.font, text, maxLabelW, _.FONT_SCALE)
      end
      local y = _.MARGIN_Y + _.scaleY(50) + (i - ctx.bblArgAddScroll - 1) * _.LINE_H
      local col = disabledRow and (_.DIM_ENTRY or _.DIM) or ((i == ctx.bblArgAddSel) and _.SELECTED_ENTRY or _.WHITE)
      _.drawListRow(_.MARGIN_X + 20, y, i == ctx.bblArgAddSel, text, col)
    end
    _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, {
      { pad = "cross", label = "Select", row = 1 },
      { pad = "circle", label = "Back", row = 1 },
    }, nil, _.DIM, _.w - 2 * _.MARGIN_X)

    if (_.padEffective & _.PAD_UP) ~= 0 then
      moveSelection(-1)
    end
    if (_.padEffective & _.PAD_DOWN) ~= 0 then
      moveSelection(1)
    end
    if (_.padEffective & _.PAD_CROSS) ~= 0 then
      local row = rows[ctx.bblArgAddSel]
      if row and not rowDisabled(row) then
        ctx.bblArgAddMenu = nil
        ctx.bblArgAddSel = nil
        ctx.bblArgAddScroll = nil
        if row.kind == "manual" then
          openNewArgumentInput(_.menu_str.new_argument_prompt or "New argument", 255, function(val)
            local v = val or ""
            if v ~= "" then addArgValue(v) end
            ctx.state = "bbl_hotkey_args"
          end)
        elseif row.kind == "titleid" then
          openNewArgumentInput("TITLEID (up to 11 chars)", 11, function(val)
            local titleId = tostring(val or ""):gsub("^%s+", ""):gsub("%s+$", "")
            if titleId ~= "" then
              addArgValue("-titleid=" .. titleId)
            end
            ctx.state = "bbl_hotkey_args"
          end)
        elseif row.kind == "udpbd_ip" then
          openNewArgumentInput("UDPBD IP (x.x.x.x)", 15, function(val)
            local ip = tostring(val or ""):gsub("^%s+", ""):gsub("%s+$", "")
            if ip ~= "" then
              addUdpbdPair(ip)
            end
            ctx.state = "bbl_hotkey_args"
          end)
        elseif row.modeValue == "udpbd" and usedKnown.udpbd_ip ~= true then
          openNewArgumentInput("UDPBD IP (x.x.x.x)", 15, function(val)
            local ip = tostring(val or ""):gsub("^%s+", ""):gsub("%s+$", "")
            if ip ~= "" then
              addUdpbdPair(ip)
            end
            ctx.state = "bbl_hotkey_args"
          end)
        else
          addArgValue(row.value or "")
        end
      end
    end
    if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
      ctx.bblArgAddMenu = nil
      ctx.bblArgAddSel = nil
      ctx.bblArgAddScroll = nil
    end
    return
  end

  ctx.bblArgSel = ctx.bblArgSel or 1
  if total <= 0 then
    ctx.bblArgSel = 1
  else
    if ctx.bblArgSel < 1 then ctx.bblArgSel = 1 end
    if ctx.bblArgSel > total then ctx.bblArgSel = total end
  end
  ctx.bblArgScroll = ctx.bblArgScroll or 0
  if total > _.MAX_VISIBLE_LIST then
    ctx.bblArgScroll = ctx.bblArgSel - math.floor(_.MAX_VISIBLE_LIST / 2)
    ctx.bblArgScroll = math.max(0, math.min(ctx.bblArgScroll, total - _.MAX_VISIBLE_LIST))
  else
    ctx.bblArgScroll = 0
  end

  local displayKey = (keyId == "AUTO") and "AUTOBOOT" or keyId
  local title = displayKey .. " - E" .. tostring(slot) .. " args (" .. tostring(total) .. "/" .. tostring(maxArgs) .. ")"
  _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1, title, _.WHITE)

  local maxLabelW = (_.w or 640) - (_.MARGIN_X + 24) - _.MARGIN_X
  if total == 0 then
    _.drawText(_.font, _.drawMode, _.MARGIN_X + 20, _.MARGIN_Y + _.scaleY(50), _.FONT_SCALE, _.common_str.none or _.common_str.empty, _.DIM)
  else
    for i = ctx.bblArgScroll + 1, math.min(ctx.bblArgScroll + _.MAX_VISIBLE_LIST, total) do
      local y = _.MARGIN_Y + _.scaleY(50) + (i - ctx.bblArgScroll - 1) * _.LINE_H
      local a = args[i]
      local text = (a and a.value) or ""
      if text == "" then text = _.common_str.empty end
      if _.common.truncateTextToWidth then
        text = _.common.truncateTextToWidth(_.font, text, maxLabelW, _.FONT_SCALE)
      end
      local col = (i == ctx.bblArgSel) and _.SELECTED_ENTRY or _.WHITE
      if a and a.disabled then
        col = (i == ctx.bblArgSel) and (_.SELECTED_ENTRY_DIM or _.SELECTED_ENTRY) or (_.DIM_ENTRY or _.DIM)
      end
      _.drawListRow(_.MARGIN_X + 20, y, i == ctx.bblArgSel, text, col)
    end
  end

  local hint
  if total > 0 and args[ctx.bblArgSel] then
    hint = args[ctx.bblArgSel].disabled and (_.menu_str.args_hint_items_with_enable or _.menu_str.args_hint_items) or
        (_.menu_str.args_hint_items_with_disable or _.menu_str.args_hint_items)
  else
    hint = {
      { pad = "select", label = "Add", row = 1 },
      { pad = "circle", label = "Back", row = 1 },
    }
  end
  _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, hint, nil, _.DIM, _.w - 2 * _.MARGIN_X)

  if total > 0 and (_.padEffective & _.PAD_UP) ~= 0 then
    ctx.bblArgSel = ctx.bblArgSel - 1
    if ctx.bblArgSel < 1 then ctx.bblArgSel = total end
  end
  if total > 0 and (_.padEffective & _.PAD_DOWN) ~= 0 then
    ctx.bblArgSel = ctx.bblArgSel + 1
    if ctx.bblArgSel > total then ctx.bblArgSel = 1 end
  end

  if total > 0 and (_.padEffective & _.PAD_CROSS) ~= 0 then
    local editIdx = ctx.bblArgSel
    local editVal = (args[editIdx] and args[editIdx].value) or ""
    ctx.textInputTitleIdMode = nil
    ctx.textInputPrompt = _.menu_str.edit_argument_prompt or "Edit argument"
    ctx.textInputValue = editVal
    ctx.textInputMaxLen = 255
    ctx.textInputCallback = function(val)
      local args2 = getArgs()
      if args2[editIdx] then
        args2[editIdx].value = val or ""
      end
      setArgs(args2)
      ctx.state = "bbl_hotkey_args"
    end
    ctx.textInputReturnState = "bbl_hotkey_args"
    ctx.textInputGridSel = 1
    ctx.textInputCursor = #ctx.textInputValue + 1
    ctx.textInputScroll = 1
    ctx.state = "text_input"
  end

  if (_.padEffective & _.PAD_SELECT) ~= 0 and total < maxArgs then
    ctx.bblArgAddMenu = true
    ctx.bblArgAddSel = ctx.bblArgAddSel or 1
    ctx.bblArgAddScroll = ctx.bblArgAddScroll or 0
  end

  if total > 0 and (_.padEffective & _.PAD_TRIANGLE) ~= 0 then
    _.config_parse.setBblHotkeyArgDisabled(ctx.lines, keyId, slot, ctx.bblArgSel, not args[ctx.bblArgSel].disabled)
    ctx.configModified = true
  end
  if total > 0 and (_.padEffective & _.PAD_SQUARE) ~= 0 then
    local args2 = getArgs()
    local removed = args2[ctx.bblArgSel]
    local removedVal = normalizeArg(type(removed) == "table" and removed.value or removed)
    local removedModeUdpbd = removedVal:match("^%-mode=%s*udpbd%s*$") ~= nil
    local removedUdpbdIp = removedVal:match("^%-udpbd_ip=") ~= nil
    table.remove(args2, ctx.bblArgSel)
    if removedModeUdpbd then
      for i = #args2, 1, -1 do
        local av = normalizeArg(type(args2[i]) == "table" and args2[i].value or args2[i])
        if av:match("^%-udpbd_ip=") then
          table.remove(args2, i)
          break
        end
      end
    elseif removedUdpbdIp then
      for i = #args2, 1, -1 do
        local av = normalizeArg(type(args2[i]) == "table" and args2[i].value or args2[i])
        if av:match("^%-mode=%s*udpbd%s*$") then
          table.remove(args2, i)
          break
        end
      end
    end
    setArgs(args2)
    if ctx.bblArgSel > #args2 then ctx.bblArgSel = math.max(1, #args2) end
  end
  if total > 1 and (_.padEffective & _.PAD_L1) ~= 0 then
    if ctx.bblArgSel > 1 then
      local args2 = getArgs()
      args2[ctx.bblArgSel], args2[ctx.bblArgSel - 1] = args2[ctx.bblArgSel - 1], args2[ctx.bblArgSel]
      setArgs(args2)
      ctx.bblArgSel = ctx.bblArgSel - 1
    end
  end
  if total > 1 and (_.padEffective & _.PAD_R1) ~= 0 then
    if ctx.bblArgSel < total then
      local args2 = getArgs()
      args2[ctx.bblArgSel], args2[ctx.bblArgSel + 1] = args2[ctx.bblArgSel + 1], args2[ctx.bblArgSel]
      setArgs(args2)
      ctx.bblArgSel = ctx.bblArgSel + 1
    end
  end

  if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
    ctx.state = "bbl_hotkey_entry"
  end
end

return { run = run }
