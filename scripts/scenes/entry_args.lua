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
  local args = isBoot and (function()
    local a = _.config_parse.getBootArgs(ctx.lines, ctx.bootKey) or {}
    local t = {} for _, v in ipairs(a) do table.insert(t, { value = v, disabled = false }) end return t
  end)() or (_.config_parse.getMenuEntryArgs(ctx.lines, ctx.entryIdx) or {})
  local hasCdrom = false
  for _, p in ipairs(paths or {}) do
    local pv = type(p) == "table" and p.value or p
    if pv == "cdrom" then
      hasCdrom = true; break
    end
  end
  local total = #args
  if ctx.entryArgSel < 1 then ctx.entryArgSel = 1 end
  if ctx.entryArgSel > total then ctx.entryArgSel = (total > 0) and total or 1 end
  if ctx.entryArgSel > ctx.entryArgScroll + _.MAX_VISIBLE_LIST then ctx.entryArgScroll = ctx.entryArgSel - _.MAX_VISIBLE_LIST end
  if ctx.entryArgSel < ctx.entryArgScroll + 1 then ctx.entryArgScroll = ctx.entryArgSel - 1 end
  local titleStr = isBoot and
      ((_.strings.options and _.strings.options[ctx.bootKey] and _.strings.options[ctx.bootKey].label) or ctx.bootKey) ..
      " - " .. _.menu_str.arguments or (_.menu_str.args_for_entry .. ctx.entryIdx)
  _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1, titleStr, _.WHITE)
  if not isBoot and hasCdrom then
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y + _.scaleY(24), 0.75,
      _.menu_str.cdrom_hint, _.DIM)
  end
  for i = ctx.entryArgScroll + 1, math.min(ctx.entryArgScroll + _.MAX_VISIBLE_LIST, total) do
    local y = _.MARGIN_Y + _.scaleY(50) + (i - ctx.entryArgScroll - 1) * _.LINE_H
    local a = args[i]
    local av = type(a) == "table" and a.value or a
    local label = (av and (av:sub(1, 52) .. (#av > 52 and "..." or ""))) or ""
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
  _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, argHints, nil, _.DIM,
    _.w - 2 * _.MARGIN_X)
  if (_.padEffective & _.PAD_UP) ~= 0 then
    ctx.entryArgSel = ctx.entryArgSel - 1; if ctx.entryArgSel < 1 then ctx.entryArgSel = total end
  end
  if (_.padEffective & _.PAD_DOWN) ~= 0 then
    ctx.entryArgSel = ctx.entryArgSel + 1; if ctx.entryArgSel > total then ctx.entryArgSel = 1 end
  end
  local function getArgs()
    if isBoot then
      local a = _.config_parse.getBootArgs(ctx.lines, ctx.bootKey) or {}
      local t = {} for _, v in ipairs(a) do table.insert(t, { value = v, disabled = false }) end return t
    end
    return _.config_parse.getMenuEntryArgs(ctx.lines, ctx.entryIdx) or {}
  end
  local function setArgs(a)
    if isBoot then
      local v = {} for _, item in ipairs(a or {}) do table.insert(v, type(item) == "table" and item.value or item) end
      _.config_parse.setBootArgs(ctx.lines, ctx.bootKey, v)
      ctx.configModified = true
    else
      _.config_parse.setMenuEntryArgs(ctx.lines, ctx.entryIdx, a)
      ctx.configModified = true
    end
  end
  if (_.padEffective & _.PAD_TRIANGLE) ~= 0 and not isBoot and ctx.entryArgSel >= 1 and ctx.entryArgSel <= total and type(args[ctx.entryArgSel]) == "table" then
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
    ctx.argEditIdx = nil
    ctx.textInputTitleIdMode = nil
    ctx.textInputPrompt = _.menu_str.new_argument_prompt
    ctx.textInputValue = ""
    ctx.textInputMaxLen = 79
    ctx.textInputCallback = function(val)
      if (val or "") ~= "" then
        local args2 = getArgs(); table.insert(args2, { value = val, disabled = false }); setArgs(args2)
      end
      ctx.state = "entry_args"
    end
    ctx.textInputReturnState = "entry_args"
    ctx.textInputGridSel = 1
    ctx.textInputCursor = 1
    ctx.textInputScroll = 1
    ctx.state = "text_input"
  end
  if (_.padEffective & _.PAD_L1) ~= 0 then
    if ctx.entryArgSel >= 1 and ctx.entryArgSel <= total and ctx.entryArgSel > 1 then
      local args2 = getArgs(); args2[ctx.entryArgSel], args2[ctx.entryArgSel - 1] = args2[ctx.entryArgSel - 1], args2[ctx.entryArgSel]; setArgs(args2)
      ctx.entryArgSel = ctx.entryArgSel - 1
    end
  end
  if (_.padEffective & _.PAD_R1) ~= 0 then
    if ctx.entryArgSel >= 1 and ctx.entryArgSel <= total and ctx.entryArgSel < total then
      local args2 = getArgs(); args2[ctx.entryArgSel], args2[ctx.entryArgSel + 1] = args2[ctx.entryArgSel + 1], args2[ctx.entryArgSel]; setArgs(args2)
      ctx.entryArgSel = ctx.entryArgSel + 1
    end
  end
  if (_.padEffective & _.PAD_SQUARE) ~= 0 then
    if ctx.entryArgSel >= 1 and ctx.entryArgSel <= total then
      local args2 = getArgs(); table.remove(args2, ctx.entryArgSel); setArgs(args2)
      if ctx.entryArgSel > #args2 then ctx.entryArgSel = math.max(1, #args2) end
    end
  end
  if (_.padEffective & _.PAD_CIRCLE) ~= 0 then ctx.state = isBoot and "entry_paths" or "menu_entry_edit" end
end

return { run = run }
