--[[ Choose save location (multi-slot OSDMENU). ]]

local function run(ctx)
  local _ = ctx._
  _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1, _.editor_str.save_config_to, _.WHITE)
  local choices = ctx.saveChoices or {}
  if ctx.saveSel < 1 then ctx.saveSel = 1 end
  if ctx.saveSel > #choices then ctx.saveSel = #choices end
  local maxVis = _.MAX_VISIBLE
  local total = #choices
  local scroll = 0
  if total > maxVis then
    scroll = ctx.saveSel - math.floor(maxVis / 2)
    scroll = math.max(0, math.min(scroll, total - maxVis))
  end
  for i = scroll + 1, math.min(scroll + maxVis, total) do
    local p = choices[i] or ""
    local label = (p:match("^mc0:") and _.dev_str.memory_card_1) or (p:match("^mc1:") and _.dev_str.memory_card_2) or
        (p:match("^pfs0:") and _.dev_str.hdd) or
        p:sub(1, 40)
    local y = _.MARGIN_Y + _.scaleY(50) + (i - scroll - 1) * _.LINE_H
    local col = (i == ctx.saveSel) and _.SELECTED_ENTRY or _.WHITE
    _.drawListRow(_.MARGIN_X + 20, y, i == ctx.saveSel, label, col)
  end
  _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, _.editor_str.cross_save_circle_cancel_items, nil,
    _.DIM, _.w - 2 * _.MARGIN_X)
  if (_.padEffective & _.PAD_UP) ~= 0 then
    ctx.saveSel = ctx.saveSel - 1; if ctx.saveSel < 1 then ctx.saveSel = #choices end
  end
  if (_.padEffective & _.PAD_DOWN) ~= 0 then
    ctx.saveSel = ctx.saveSel + 1; if ctx.saveSel > #choices then ctx.saveSel = 1 end
  end
  if (_.padEffective & _.PAD_CROSS) ~= 0 and #choices > 0 then
    local path = choices[ctx.saveSel]
    local parentDir = path and path:match("^(.+)/[^/]+$")
    ctx.lines = _.config_parse.regenerateForSave(ctx.lines, ctx.fileType, _.config_options)
    ctx.saveSplash = nil
    local ok, err = _.common.saveConfig(ctx, path, ctx.lines, parentDir)
    if ok then
      ctx.currentPath = path
      ctx.saveSplash = { kind = "saved", detail = path or "", framesLeft = 60 }
      ctx.configModified = false
      if ctx.returnToSelectConfigAfterSave then
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
      ctx.saveSplash = {
        kind = "failed",
        detail = _.common.localizeParseError(err, _.editor_str) or
            _.editor_str.save_failed,
        framesLeft = 60
      }
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
