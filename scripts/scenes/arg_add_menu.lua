--[[ Shared add-argument preset menu renderer/input handler. ]]

local arg_add_menu = {}

local function closeMenu(ctx, opts)
  ctx[opts.menuOpenKey] = nil
  ctx[opts.selKey] = nil
  ctx[opts.scrollKey] = nil
end

local function buildDefaultHints()
  return {
    { pad = "cross", label = "Select", row = 1 },
    { pad = "circle", label = "Back", row = 1 },
  }
end

function arg_add_menu.run(ctx, opts)
  if not ctx or not opts then return false end
  local _ = ctx._
  if not _ then return false end

  local menuOpenKey = opts.menuOpenKey
  if not menuOpenKey or not ctx[menuOpenKey] then return false end

  local selKey = opts.selKey or "argAddSel"
  local scrollKey = opts.scrollKey or "argAddScroll"
  local rows = opts.rows or {}
  local maxVisible = math.max(1, math.floor(tonumber(opts.maxVisible) or (_.MAX_VISIBLE_LIST or 12)))
  local rowStateKeyPrefix = opts.rowStateKeyPrefix or "arg_add_row_"
  local rowDisabledReason = opts.rowDisabledReason or function()
    return false, nil
  end

  if #rows == 0 then
    closeMenu(ctx, opts)
    return true
  end

  local function rowDisabled(row)
    local disabled = rowDisabledReason(row)
    return disabled
  end

  local function isSelectable(index)
    local row = rows[index]
    return row ~= nil and (not rowDisabled(row))
  end

  local function moveSelection(step)
    local idx = ctx[selKey] or 1
    for attempt = 1, #rows do
      idx = _.common.wrapListSelection(idx, #rows, step)
      if isSelectable(idx) then
        ctx[selKey] = idx
        return
      end
    end
  end

  ctx[selKey] = _.common.clampListSelection(ctx[selKey] or 1, #rows)
  if not isSelectable(ctx[selKey]) then
    moveSelection(1)
  end
  ctx[scrollKey] = _.common.centeredListScroll(ctx[selKey], #rows, maxVisible)

  local title = opts.title or "Add argument"
  local selectedRow = rows[ctx[selKey]]
  local desc = (selectedRow and selectedRow.desc) or (opts.descDefault or "")

  _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1, title, _.WHITE)
  if desc ~= "" then
    if _.common.truncateTextToWidth then
      desc = _.common.truncateTextToWidth(_.font, desc, (_.w or 640) - (_.MARGIN_X * 2), 0.6)
    end
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y + _.scaleY(22), 0.6, desc, _.DIM)
  end

  local maxLabelW = (_.w or 640) - (_.MARGIN_X + 24) - _.MARGIN_X
  local inUseSuffix = opts.inUseSuffix or " (in use)"
  local needsTwoSuffix = opts.needsTwoSlotsSuffix or " (needs 2 slots)"
  for i = ctx[scrollKey] + 1, math.min(ctx[scrollKey] + maxVisible, #rows) do
    local row = rows[i]
    local label = row.label or ""
    local disabled, reason = rowDisabledReason(row)
    if disabled then
      label = label .. ((reason == "needs_two_slots") and needsTwoSuffix or inUseSuffix)
    end
    if _.common.fitListRowText then
      label = _.common.fitListRowText(ctx, rowStateKeyPrefix .. tostring(i), _.font, label, maxLabelW,
        _.FONT_SCALE, i == ctx[selKey])
    elseif _.common.truncateTextToWidth then
      label = _.common.truncateTextToWidth(_.font, label, maxLabelW, _.FONT_SCALE)
    end
    local y = _.MARGIN_Y + _.scaleY(50) + (i - ctx[scrollKey] - 1) * _.LINE_H
    local col = disabled and (_.DIM_ENTRY or _.DIM) or ((i == ctx[selKey]) and _.SELECTED_ENTRY or _.WHITE)
    _.drawListRow(_.MARGIN_X + 20, y, i == ctx[selKey], label, col)
  end

  _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, opts.hints or buildDefaultHints(), nil, _.DIM,
    _.w - 2 * _.MARGIN_X)

  if (_.padEffective & _.PAD_UP) ~= 0 then
    moveSelection(-1)
  end
  if (_.padEffective & _.PAD_DOWN) ~= 0 then
    moveSelection(1)
  end
  if (_.padEffective & _.PAD_CROSS) ~= 0 then
    local row = rows[ctx[selKey]]
    if row and not rowDisabled(row) then
      local selectedIndex = ctx[selKey]
      closeMenu(ctx, opts)
      if type(opts.onSelect) == "function" then
        opts.onSelect(row, selectedIndex)
      end
    end
  end
  if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
    closeMenu(ctx, opts)
    if type(opts.onCancel) == "function" then
      opts.onCancel()
    end
  end

  return true
end

return arg_add_menu
