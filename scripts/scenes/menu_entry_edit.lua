--[[ Single menu entry edit (name, paths, args, delete). ]]

local function run(ctx)
  local _ = ctx._
  if not ctx.lines or not ctx.entryIdx then
    ctx.state = "menu_entries"; ctx.entryIdx = nil; return
  end
  local name = _.config_parse.getMenuEntryName(ctx.lines, ctx.entryIdx) or ""
  local paths = _.config_parse.getMenuEntryPaths(ctx.lines, ctx.entryIdx)
  local args = _.config_parse.getMenuEntryArgs(ctx.lines, ctx.entryIdx)
  local hasOsdOrShutdown = false
  for _, p in ipairs(paths) do
    local pv = type(p) == "table" and p.value or p
    if (pv or ""):upper() == "OSDSYS" or (pv or ""):upper() == "POWEROFF" then
      hasOsdOrShutdown = true; break
    end
  end
  local subOpts = { _.menu_str.edit_name, _.menu_str.paths_label }
  local hasCdrom = false
  for _, p in ipairs(paths) do
    local pv = type(p) == "table" and p.value or p
    if pv == "cdrom" then
      hasCdrom = true; break
    end
  end
  if hasCdrom then table.insert(subOpts, _.menu_str.launch_disc_options) end
  if not (hasOsdOrShutdown or hasCdrom) then table.insert(subOpts, _.menu_str.arguments) end
  table.insert(subOpts, _.menu_str.back)
  local pathsStr = _.menu_str.paths .. (#paths == 0 and _.menu_str.none or #paths .. _.menu_str.path_s)
  local argsStr = _.menu_str.args ..
      ((hasOsdOrShutdown or hasCdrom) and _.menu_str.none or (#args == 0 and _.menu_str.none or #args .. _.menu_str.arg_s))
  _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1, _.menu_str.entry_index .. ctx.entryIdx, _.WHITE)
  _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y + _.scaleY(24), 0.8,
    _.menu_str.name .. (name == "" and _.common_str.empty or name:sub(1, 40)), _.DIM)
  _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y + _.scaleY(44), 0.8, pathsStr .. ", " .. argsStr, _.DIM)
  if ctx.entryEditSub < 1 then ctx.entryEditSub = 1 end
  if ctx.entryEditSub > #subOpts then ctx.entryEditSub = #subOpts end
  for i = 1, #subOpts do
    local y = _.MARGIN_Y + _.scaleY(90) + (i - 1) * _.LINE_H
    local col = (i == ctx.entryEditSub) and _.SELECTED_ENTRY or _.WHITE
    _.drawListRow(_.MARGIN_X + 20, y, i == ctx.entryEditSub, subOpts[i], col)
  end
  _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, _.menu_str.cross_select_circle_back_items, nil,
    _.DIM, _.w - 2 * _.MARGIN_X)
  if (_.padEffective & _.PAD_UP) ~= 0 then
    ctx.entryEditSub = ctx.entryEditSub - 1; if ctx.entryEditSub < 1 then ctx.entryEditSub = #subOpts end
  end
  if (_.padEffective & _.PAD_DOWN) ~= 0 then
    ctx.entryEditSub = ctx.entryEditSub + 1; if ctx.entryEditSub > #subOpts then ctx.entryEditSub = 1 end
  end
  if (_.padEffective & _.PAD_CROSS) ~= 0 then
    local opt = subOpts[ctx.entryEditSub]
    if opt == _.menu_str.edit_name then
      ctx.textInputTitleIdMode = nil
      ctx.textInputPrompt = _.menu_str.entry_name_prompt
      local name = _.config_parse.getMenuEntryName(ctx.lines, ctx.entryIdx) or ""
      if name == _.menu_str.add_entry_label then name = "" end
      ctx.textInputValue = name
      ctx.textInputMaxLen = _.config_parse.LIMIT_NAME
      ctx.textInputCallback = function(val)
        _.config_parse.setMenuEntryName(ctx.lines, ctx.entryIdx, val)
        ctx.configModified = true
        ctx.state = "menu_entry_edit"
      end
      ctx.textInputReturnState = "menu_entry_edit"
      ctx.textInputGridSel = 1
      ctx.textInputCursor = #ctx.textInputValue + 1
      ctx.textInputScroll = 1
      ctx.state = "text_input"
    elseif opt == _.menu_str.paths_label then
      ctx.state = "entry_paths"
      ctx.entryPathSel = 1
      ctx.entryPathScroll = 0
    elseif opt == _.menu_str.launch_disc_options then
      ctx.cdromOptSel = 1
      ctx.state = "entry_cdrom_options"
    elseif opt == _.menu_str.arguments then
      ctx.state = "entry_args"
      ctx.entryArgSel = 1
      ctx.entryArgScroll = 0
    else
      ctx.state = "menu_entries"
      ctx.entryIdx = nil
    end
  end
  if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
    ctx.state = "menu_entries"; ctx.entryIdx = nil
  end
end

return { run = run }
