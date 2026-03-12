--[[ Argument editor for one BBL hotkey slot (ARG_<HOTKEY>_E#). ]]

local arg_presets = dofile("scripts/scenes/arg_presets.lua")
local arg_profiles = dofile("scripts/scenes/arg_profiles.lua")
local arg_gsm_picker = dofile("scripts/scenes/arg_gsm_picker.lua")
local arg_add_menu = dofile("scripts/scenes/arg_add_menu.lua")

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
    ctx.bblArgSel = #args2
    return true
  end

  local args = getArgs()
  local total = #args
  local entryPath = _.config_parse.getBblHotkeyPath(ctx.lines, keyId, slot)
  local isNhddlElfPath = arg_presets.isNhddlElfPath(entryPath)
  local usedKnown, usedModes = arg_presets.collectUsedArgs(args)
  local profileState = arg_profiles.resolve({
    surface = "bbl_hotkey",
    context = ctx.context,
    fileType = ctx.fileType,
    hasNhddlPath = isNhddlElfPath,
  })
  local presetRows = arg_profiles.buildAddRows(profileState)
  local removeNhddlPair = true

  local function clearGsmMenus()
    ctx.bblArgGsmVideoMenu = nil
    ctx.bblArgGsmVideoSel = nil
    ctx.bblArgGsmVideoScroll = nil
    ctx.bblArgGsmCompatMenu = nil
    ctx.bblArgGsmCompatSel = nil
    ctx.bblArgGsmCompatScroll = nil
    ctx.bblArgGsmVideoIdx = nil
    ctx.bblArgGsmArgKey = nil
  end

  local function reopenAddMenu()
    if total >= maxArgs then return end
    ctx.bblArgAddMenu = true
    ctx.bblArgAddSel = ctx.bblArgAddSel or 1
    ctx.bblArgAddScroll = ctx.bblArgAddScroll or 0
  end

  local function openGsmPicker(row)
    clearGsmMenus()
    ctx.bblArgGsmArgKey = (row and row.egsmArgKey) or "-gsm"
    ctx.bblArgGsmVideoMenu = true
    ctx.bblArgGsmVideoSel = ctx.bblArgGsmVideoSel or 1
    ctx.bblArgGsmVideoScroll = ctx.bblArgGsmVideoScroll or 0
  end

  if ctx.bblArgAddMenu and total >= maxArgs then
    ctx.bblArgAddMenu = nil
    ctx.bblArgAddSel = nil
    ctx.bblArgAddScroll = nil
  end

  if ctx.bblArgGsmCompatMenu then
    local compatRows = arg_gsm_picker.buildCompatRows(_)
    if #compatRows == 0 then
      clearGsmMenus()
      reopenAddMenu()
    elseif arg_add_menu.run(ctx, {
          menuOpenKey = "bblArgGsmCompatMenu",
          selKey = "bblArgGsmCompatSel",
          scrollKey = "bblArgGsmCompatScroll",
          rows = compatRows,
          title = arg_gsm_picker.compatTitle(_, ctx.bblArgGsmVideoIdx),
          descDefault = "Select compatibility mode.",
          rowStateKeyPrefix = "bbl_hotkey_args_gsm_compat_row_",
          onSelect = function(row)
            local arg = arg_gsm_picker.buildArg(_, ctx.bblArgGsmArgKey, ctx.bblArgGsmVideoIdx, row.compatIdx)
            clearGsmMenus()
            if arg and arg ~= "" then
              addArgValue(arg)
            end
          end,
          onCancel = function()
            ctx.bblArgGsmCompatMenu = nil
            ctx.bblArgGsmCompatSel = nil
            ctx.bblArgGsmCompatScroll = nil
            ctx.bblArgGsmVideoMenu = true
            ctx.bblArgGsmVideoSel = ctx.bblArgGsmVideoSel or 1
            ctx.bblArgGsmVideoScroll = ctx.bblArgGsmVideoScroll or 0
          end,
        }) then
      return
    end
  end

  if ctx.bblArgGsmVideoMenu then
    local videoRows = arg_gsm_picker.buildVideoRows(_)
    if #videoRows == 0 then
      clearGsmMenus()
      reopenAddMenu()
    elseif arg_add_menu.run(ctx, {
          menuOpenKey = "bblArgGsmVideoMenu",
          selKey = "bblArgGsmVideoSel",
          scrollKey = "bblArgGsmVideoScroll",
          rows = videoRows,
          title = arg_gsm_picker.videoTitle(_),
          descDefault = "Select eGSM video mode.",
          rowStateKeyPrefix = "bbl_hotkey_args_gsm_video_row_",
          onSelect = function(row)
            ctx.bblArgGsmVideoIdx = row.videoIdx
            ctx.bblArgGsmCompatMenu = true
            ctx.bblArgGsmCompatSel = ctx.bblArgGsmCompatSel or 1
            ctx.bblArgGsmCompatScroll = ctx.bblArgGsmCompatScroll or 0
          end,
          onCancel = function()
            clearGsmMenus()
            reopenAddMenu()
          end,
        }) then
      return
    end
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
    local function openTitleIdInput()
      openNewArgumentInput("TITLEID (up to 11 chars)", 11, function(val)
        local titleId = tostring(val or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if titleId ~= "" then
          addArgValue("-titleid=" .. titleId)
        end
        ctx.state = "bbl_hotkey_args"
      end)
    end
    local titleAdd = "Add argument (" .. tostring(total) .. "/" .. tostring(maxArgs) .. ") [" ..
        arg_profiles.getMenuTag(profileState) .. "]"
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

  ctx.bblArgSel = _.common.clampListSelection(ctx.bblArgSel or 1, total)
  ctx.bblArgScroll = _.common.centeredListScroll(ctx.bblArgSel, total, _.MAX_VISIBLE_LIST)

  local displayKey = (keyId == "AUTO") and "AUTOBOOT" or keyId
  local title = displayKey .. " - E" .. tostring(slot) .. " args (" .. tostring(total) .. "/" .. tostring(maxArgs) .. ")"
  _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1, title, _.WHITE)

  local maxLabelW = (_.w or 640) - (_.MARGIN_X + 24) - _.MARGIN_X
  if total == 0 then
    _.drawText(_.font, _.drawMode, _.MARGIN_X + 20, _.MARGIN_Y + _.scaleY(50), _.FONT_SCALE,
      _.common_str.none or _.common_str.empty, _.DIM)
  else
    for i = ctx.bblArgScroll + 1, math.min(ctx.bblArgScroll + _.MAX_VISIBLE_LIST, total) do
      local y = _.MARGIN_Y + _.scaleY(50) + (i - ctx.bblArgScroll - 1) * _.LINE_H
      local a = args[i]
      local text = (a and a.value) or ""
      if text == "" then text = _.common_str.empty end
      if _.common.fitListRowText then
        text = _.common.fitListRowText(ctx, "bbl_hotkey_args_row_" .. tostring(i), _.font, text, maxLabelW,
          _.FONT_SCALE, i == ctx.bblArgSel)
      elseif _.common.truncateTextToWidth then
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
    ctx.bblArgSel = _.common.wrapListSelection(ctx.bblArgSel, total, -1)
  end
  if total > 0 and (_.padEffective & _.PAD_DOWN) ~= 0 then
    ctx.bblArgSel = _.common.wrapListSelection(ctx.bblArgSel, total, 1)
  end

  if total > 0 and (_.padEffective & _.PAD_CROSS) ~= 0 then
    local editIdx = ctx.bblArgSel
    local editVal = (args[editIdx] and args[editIdx].value) or ""
    _.common.beginTextInput(ctx, {
      titleIdMode = nil,
      prompt = _.menu_str.edit_argument_prompt or "Edit argument",
      value = editVal,
      maxLen = 255,
      callback = function(val)
        local args2 = getArgs()
        if args2[editIdx] then
          args2[editIdx].value = val or ""
        end
        setArgs(args2)
        ctx.state = "bbl_hotkey_args"
      end,
      returnState = "bbl_hotkey_args",
      gridSel = 1,
      scroll = 1,
      state = "text_input",
    })
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
    local args2 = arg_presets.removeArgAndPairedUdpbd(getArgs(), ctx.bblArgSel, removeNhddlPair)
    setArgs(args2)
    ctx.bblArgSel = _.common.clampListSelection(ctx.bblArgSel, #args2)
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
