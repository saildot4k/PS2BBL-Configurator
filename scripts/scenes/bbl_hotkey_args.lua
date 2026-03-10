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

  local args = getArgs()
  local total = #args
  local presetRows = {
    { label = "Enter manually", kind = "manual" },
    { label = "-appid", value = "-appid" },
    { label = "-patinfo", value = "-patinfo" },
    { label = "-dev9=NICHDD", value = "-dev9=NICHDD" },
    { label = "-dev9=NIC", value = "-dev9=NIC" },
    { label = "-titleid=<11 chars>", kind = "titleid" },
  }

  if ctx.bblArgAddMenu and total >= maxArgs then
    ctx.bblArgAddMenu = nil
    ctx.bblArgAddSel = nil
    ctx.bblArgAddScroll = nil
  end
  if ctx.bblArgAddMenu then
    local rows = presetRows
    ctx.bblArgAddSel = ctx.bblArgAddSel or 1
    if ctx.bblArgAddSel < 1 then ctx.bblArgAddSel = 1 end
    if ctx.bblArgAddSel > #rows then ctx.bblArgAddSel = #rows end
    ctx.bblArgAddScroll = ctx.bblArgAddScroll or 0
    if #rows > _.MAX_VISIBLE_LIST then
      if ctx.bblArgAddSel > ctx.bblArgAddScroll + _.MAX_VISIBLE_LIST then
        ctx.bblArgAddScroll = ctx.bblArgAddSel - _.MAX_VISIBLE_LIST
      end
      if ctx.bblArgAddSel < ctx.bblArgAddScroll + 1 then
        ctx.bblArgAddScroll = ctx.bblArgAddSel - 1
      end
    else
      ctx.bblArgAddScroll = 0
    end

    local titleAdd = "Add argument (" .. tostring(total) .. "/" .. tostring(maxArgs) .. ")"
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1, titleAdd, _.WHITE)
    local maxLabelW = (_.w or 640) - (_.MARGIN_X + 24) - _.MARGIN_X
    for i = ctx.bblArgAddScroll + 1, math.min(ctx.bblArgAddScroll + _.MAX_VISIBLE_LIST, #rows) do
      local row = rows[i]
      local text = row.label or ""
      if _.common.truncateTextToWidth then
        text = _.common.truncateTextToWidth(_.font, text, maxLabelW, _.FONT_SCALE)
      end
      local y = _.MARGIN_Y + _.scaleY(50) + (i - ctx.bblArgAddScroll - 1) * _.LINE_H
      local col = (i == ctx.bblArgAddSel) and _.SELECTED_ENTRY or _.WHITE
      _.drawListRow(_.MARGIN_X + 20, y, i == ctx.bblArgAddSel, text, col)
    end
    _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, {
      { pad = "cross", label = "Select", row = 1 },
      { pad = "circle", label = "Back", row = 1 },
    }, nil, _.DIM, _.w - 2 * _.MARGIN_X)

    if (_.padEffective & _.PAD_UP) ~= 0 then
      ctx.bblArgAddSel = ctx.bblArgAddSel - 1
      if ctx.bblArgAddSel < 1 then ctx.bblArgAddSel = #rows end
    end
    if (_.padEffective & _.PAD_DOWN) ~= 0 then
      ctx.bblArgAddSel = ctx.bblArgAddSel + 1
      if ctx.bblArgAddSel > #rows then ctx.bblArgAddSel = 1 end
    end
    if (_.padEffective & _.PAD_CROSS) ~= 0 then
      local row = rows[ctx.bblArgAddSel]
      if row then
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
    if ctx.bblArgSel > ctx.bblArgScroll + _.MAX_VISIBLE_LIST then
      ctx.bblArgScroll = ctx.bblArgSel - _.MAX_VISIBLE_LIST
    end
    if ctx.bblArgSel < ctx.bblArgScroll + 1 then
      ctx.bblArgScroll = ctx.bblArgSel - 1
    end
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
    table.remove(args2, ctx.bblArgSel)
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
