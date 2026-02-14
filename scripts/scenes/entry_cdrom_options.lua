--[[ Launch Disc (cdrom) options for a menu entry or MBR boot key. ]]

local function run(ctx)
  local _ = ctx._
  local isBoot = not not (ctx.bootKey and (ctx.context == "mbr" or ctx.fileType == "osdmbr_cnf"))
  if not ctx.lines then
    ctx.state = isBoot and "editor" or "menu_entry_edit"
    if isBoot then ctx.bootKey = nil end
    return
  end
  if not isBoot and not ctx.entryIdx then
    ctx.state = "menu_entry_edit"; return
  end
  local args = isBoot and (function()
    local a = _.config_parse.getBootArgs(ctx.lines, ctx.bootKey) or {}
    local t = {}
    for _, v in ipairs(a) do table.insert(t, { value = v, disabled = false }) end
    return t
  end)() or (_.config_parse.getMenuEntryArgs(ctx.lines, ctx.entryIdx) or {})
  local opts = _.config_options.cdrom_options or {}
  if ctx.cdromOptSel < 1 then ctx.cdromOptSel = 1 end
  if ctx.cdromOptSel > #opts then ctx.cdromOptSel = #opts end
  local function hasArg(key)
    for _, a in ipairs(args) do if (type(a) == "table" and a.value or a) == key then return true end end
    return false
  end
  _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1, _.menu_str.launch_disc_options_title, _.WHITE)
  _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y + _.scaleY(24), 0.8, _.menu_str.launch_disc_options_sub, _.DIM)
  local startY = _.MARGIN_Y + _.scaleY(50)
  local cdromStrings = _.strings.cdrom_options or {}
  local function cdromStringKey(argKey) return (argKey and argKey:gsub("^-", "")) or argKey end
  for i = 1, #opts do
    local o = opts[i]
    local y = startY + (i - 1) * _.LINE_H
    local on = hasArg(o.key)
    local col = (i == ctx.cdromOptSel) and _.SELECTED_ENTRY or _.WHITE
    local coSt = cdromStrings[cdromStringKey(o.key)]
    local rowLabel = (coSt and coSt.label) or o.key
    _.drawListRow(_.MARGIN_X + 20, y, i == ctx.cdromOptSel, rowLabel, col)
    _.drawText(_.font, _.drawMode, _.VALUE_X, y, _.FONT_SCALE, on and _.common_str.on or _.common_str.off,
      on and _.WHITE or _.DIM)
  end
  local selOpt = opts[ctx.cdromOptSel]
  local selCoSt = selOpt and cdromStrings[cdromStringKey(selOpt.key)]
  if selCoSt and selCoSt.desc then
    local tw = _.common.calcTextWidth(_.font, selCoSt.desc, 0.72)
    local x = _.common.centerX(_, tw)
    _.drawText(_.font, _.drawMode, x, _.DESC_Y_BOTTOM, 0.72, selCoSt.desc, _.DIM)
  end
  _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, _.menu_str.cdrom_toggle_hint_items, nil, _.DIM,
    _.w - 2 * _.MARGIN_X)
  if (_.padEffective & _.PAD_UP) ~= 0 then
    ctx.cdromOptSel = ctx.cdromOptSel - 1; if ctx.cdromOptSel < 1 then ctx.cdromOptSel = #opts end
  end
  if (_.padEffective & _.PAD_DOWN) ~= 0 then
    ctx.cdromOptSel = ctx.cdromOptSel + 1; if ctx.cdromOptSel > #opts then ctx.cdromOptSel = 1 end
  end
  if (_.padEffective & _.PAD_CROSS) ~= 0 and #opts > 0 then
    local key = opts[ctx.cdromOptSel].key
    args = isBoot and (function()
      local a = _.config_parse.getBootArgs(ctx.lines, ctx.bootKey) or {}
      local t = {}
      for _, v in ipairs(a) do table.insert(t, { value = v, disabled = false }) end
      return t
    end)() or (_.config_parse.getMenuEntryArgs(ctx.lines, ctx.entryIdx) or {})
    if hasArg(key) then
      local newArgs = {}
      for _, a in ipairs(args) do
        local av = type(a) == "table" and a.value or a
        if av ~= key then table.insert(newArgs, type(a) == "table" and a or { value = a, disabled = false }) end
      end
      if isBoot then
        local v = {}
        for _, item in ipairs(newArgs) do table.insert(v, type(item) == "table" and item.value or item) end
        _.config_parse.setBootArgs(ctx.lines, ctx.bootKey, v)
      else
        _.config_parse.setMenuEntryArgs(ctx.lines, ctx.entryIdx, newArgs)
      end
      ctx.configModified = true
    else
      table.insert(args, { value = key, disabled = false })
      if isBoot then
        local v = {}
        for _, item in ipairs(args) do table.insert(v, type(item) == "table" and item.value or item) end
        _.config_parse.setBootArgs(ctx.lines, ctx.bootKey, v)
      else
        _.config_parse.setMenuEntryArgs(ctx.lines, ctx.entryIdx, args)
      end
      ctx.configModified = true
    end
  end
  if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
    if isBoot then
      ctx.state = "editor"; ctx.bootKey = nil
    else
      ctx.state = "menu_entry_edit"
    end
  end
end

return { run = run }
