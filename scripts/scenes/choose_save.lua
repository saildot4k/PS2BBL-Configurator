--[[ Choose save location (multi-slot OSDMENU). ]]

local function run(ctx)
  local _ = ctx._
  _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1, _.editor_str.save_config_to, _.WHITE)
  local choices = ctx.saveChoices or {}
  if ctx.saveSel < 1 then ctx.saveSel = 1 end
  if ctx.saveSel > #choices then ctx.saveSel = #choices end
  local maxVis = _.MAX_VISIBLE
  local total = #choices
  local startY = _.MARGIN_Y + _.scaleY(50)
  local maxLabelW = (_.w or 640) - (_.MARGIN_X + 20) - _.MARGIN_X
  local scroll = 0
  if total > maxVis then
    scroll = ctx.saveSel - math.floor(maxVis / 2)
    scroll = math.max(0, math.min(scroll, total - maxVis))
  end
  if _.common and _.common.drawListScrollbar then
    _.common.drawListScrollbar(_, {
      totalRows = total,
      visibleRows = maxVis,
      scrollRows = scroll,
      rowTopY = startY,
      rowHeight = _.LINE_H,
      color = _.DIM_COLOR,
    })
  end
  for i = scroll + 1, math.min(scroll + maxVis, total) do
    local p = choices[i] or ""
    local label = (p:match("^mc0:") and _.dev_str.memory_card_1) or (p:match("^mc1:") and _.dev_str.memory_card_2) or
        (p:match("^pfs0:") and _.dev_str.hdd) or
        p:sub(1, 40)
    if _.common.fitListRowText then
      label = _.common.fitListRowText(ctx, "choose_save_row_" .. tostring(i), _.font, label, maxLabelW, _.FONT_SCALE,
        i == ctx.saveSel)
    elseif _.common.truncateTextToWidth then
      label = _.common.truncateTextToWidth(_.font, label, maxLabelW, _.FONT_SCALE)
    end
    local y = startY + (i - scroll - 1) * _.LINE_H
    local col = (i == ctx.saveSel) and _.SELECTED_COLOR or _.UNSELECTED_COLOR
    _.drawListRow(_.MARGIN_X + 20, y, i == ctx.saveSel, label, col)
  end
  _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, _.editor_str.cross_save_circle_cancel_items, nil,
    _.DIM_COLOR, _.w - 2 * _.MARGIN_X)
  if (_.padEffective & _.PAD_UP) ~= 0 then
    ctx.saveSel = _.common.moveListSelection(ctx.saveSel, #choices, -1, { ctx = ctx })
  end
  if (_.padEffective & _.PAD_DOWN) ~= 0 then
    ctx.saveSel = _.common.moveListSelection(ctx.saveSel, #choices, 1, { ctx = ctx })
  end
  if (_.padEffective & _.PAD_CROSS) ~= 0 and #choices > 0 then
    local path = choices[ctx.saveSel]
    local ok = _.common.saveCurrentConfig(ctx, {
      path = path,
      allowChoose = false,
      locations = { path },
    })
    if ok then
      if ctx.returnToSelectConfigAfterSave then
        if type(ctx.returnToSelectConfigAfterSave) == "string" then
          ctx.returnStateAfterSaveFlash = ctx.returnToSelectConfigAfterSave
        end
        ctx.returnToSelectConfigAfterSave = nil
        ctx.returnToSelectConfigAfterSaveFlash = true
      end
      if ctx.returnToMenuEntriesAfterSave then
        ctx.returnToMenuEntriesAfterSave = nil
        ctx.state = "menu_entries"
      else
        ctx.state = (ctx.fileType == "osdgsm_cnf") and "egsm_editor" or "editor"
      end
    else
      if ctx.returnToMenuEntriesAfterSave then
        ctx.returnToMenuEntriesAfterSave = nil
        ctx.state = "menu_entries"
      else
        ctx.state = (ctx.fileType == "osdgsm_cnf") and "egsm_editor" or "editor"
      end
    end
    ctx.saveChoices = nil
  end
  if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
    ctx.returnToSelectConfigAfterSave = nil
    ctx.returnStateAfterSaveFlash = nil
    if ctx.returnToMenuEntriesAfterSave then
      ctx.returnToMenuEntriesAfterSave = nil
      ctx.state = "menu_entries"
    else
      ctx.state = (ctx.fileType == "osdgsm_cnf") and "egsm_editor" or "editor"
    end
    ctx.saveChoices = nil
  end
end

return { run = run }
