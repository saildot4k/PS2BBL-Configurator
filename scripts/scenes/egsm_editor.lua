--[[ eGSM single-screen editor: default + title overrides + Add. Title ID = 4 letters + 5 digits. ]]

local function run(ctx)
  local _ = ctx._
  if not ctx.lines then
    ctx.state = "select_config"; ctx.currentPath = nil; return
  end

  local pathStr = ctx.currentPath or ""
  if #pathStr > 56 then
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 0.8, pathStr:sub(1, 56), _.DIM)
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y + _.scaleY(18), 0.8, pathStr:sub(57), _.DIM)
  else
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 0.8, pathStr, _.DIM)
  end

  if ctx.saveFlash and ctx.saveFlash > 0 then
    if _.common.drawSavedSplash(ctx) then
      ctx.returnToSelectConfigAfterSaveFlash = nil
      ctx.state = "select_config"
      ctx.currentPath = nil
      ctx.lines = nil
      ctx.egsmSel = 1
      ctx.egsmScroll = 0
      ctx.saveError = nil
      return
    end
  end
  if ctx.returnToSelectConfigAfterSaveFlash then
    return
  end
  _.common.drawSaveError(ctx)

  local entries = _.config_parse.getEgsmEntries(ctx.lines)
  local total = 2 + #entries
  if ctx.egsmSel < 1 then ctx.egsmSel = 1 end
  if ctx.egsmSel > total then ctx.egsmSel = total end
  ctx.egsmScroll = ctx.egsmScroll or 0
  if ctx.egsmSel > ctx.egsmScroll + _.MAX_VISIBLE_LIST then ctx.egsmScroll = ctx.egsmSel - _.MAX_VISIBLE_LIST end
  if ctx.egsmSel < ctx.egsmScroll + 1 then ctx.egsmScroll = ctx.egsmSel - 1 end
  ctx.egsmScroll = math.max(0, math.min(ctx.egsmScroll, total - _.MAX_VISIBLE_LIST))

  local function valueDisplay(val, commented)
    if commented or val == "disabled" or val == "" then
      return _.strings.egsm.disabled
    end
    return val
  end

  local startY = _.MARGIN_Y + _.scaleY(50)
  for i = (ctx.egsmScroll or 0) + 1, math.min((ctx.egsmScroll or 0) + _.MAX_VISIBLE_LIST, total) do
    local y = startY + (i - (ctx.egsmScroll or 0) - 1) * _.LINE_H
    local col = (i == ctx.egsmSel) and _.SELECTED_ENTRY or _.WHITE
    if i == 1 then
      local def = _.config_parse.getEgsmDefault(ctx.lines)
      _.drawListRow(_.MARGIN_X + 20, y, i == ctx.egsmSel,
        _.strings.egsm.default_label, col)
      _.drawText(_.font, _.drawMode, _.VALUE_X, y, _.FONT_SCALE, valueDisplay(def, (def == "disabled")),
        (def == "" or def == "disabled") and _.DIM or col)
    elseif i <= 1 + #entries then
      local ent = entries[i - 1]
      _.drawListRow(_.MARGIN_X + 20, y, i == ctx.egsmSel, ent.titleId, col)
      _.drawText(_.font, _.drawMode, _.VALUE_X, y, _.FONT_SCALE, valueDisplay(ent.value, ent.commented),
        (ent.commented or ent.value == "" or ent.value == "disabled") and _.DIM or col)
    else
      _.drawListRow(_.MARGIN_X + 20, y, i == ctx.egsmSel,
        _.strings.egsm.add_title_id, col)
    end
  end

  _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7,
    _.strings.egsm.hint_items, nil, _.DIM, _.w - 2 * _.MARGIN_X)

  if (_.padEffective & _.PAD_UP) ~= 0 then
    ctx.egsmSel = ctx.egsmSel - 1; if ctx.egsmSel < 1 then ctx.egsmSel = total end
  end
  if (_.padEffective & _.PAD_DOWN) ~= 0 then
    ctx.egsmSel = ctx.egsmSel + 1; if ctx.egsmSel > total then ctx.egsmSel = 1 end
  end

  if (_.padEffective & _.PAD_CROSS) ~= 0 and (ctx.egsmSel == 1 or (ctx.egsmSel >= 2 and ctx.egsmSel <= 1 + #entries)) then
    ctx.egsmEditDefault = (ctx.egsmSel == 1)
    if not ctx.egsmEditDefault then
      ctx.egsmEditTitleId = entries[ctx.egsmSel - 1].titleId
    else
      ctx.egsmEditTitleId = nil
    end
    ctx.egsmVideoIdx = nil
    ctx.egsmCompatIdx = nil
    ctx.state = "egsm_value_edit"
  elseif (_.padEffective & _.PAD_CROSS) ~= 0 and ctx.egsmSel == total then
    ctx.textInputPrompt = _.strings.egsm.title_id_prompt
    ctx.textInputValue = ""
    ctx.textInputMaxLen = 15
    ctx.textInputTitleIdMode = true
    ctx.textInputCallback = function(val)
      local id = _.config_parse.parseTitleIdInput and _.config_parse.parseTitleIdInput(val or "")
      if id and _.config_parse.isValidTitleId(id) then
        _.config_parse.setEgsmEntry(ctx.lines, id, "disabled", true)
      end
      ctx.state = "egsm_editor"
    end
    ctx.textInputReturnState = "egsm_editor"
    ctx.textInputGridSel = 1
    ctx.textInputCursor = 1
    ctx.textInputScroll = 1
    ctx.state = "text_input"
  end

  if (_.padEffective & _.PAD_SQUARE) ~= 0 and ctx.egsmSel >= 2 and ctx.egsmSel <= 1 + #entries then
    local ent = entries[ctx.egsmSel - 1]
    _.config_parse.removeEgsmEntry(ctx.lines, ent.titleId)
    if ctx.egsmSel > #entries then ctx.egsmSel = math.max(1, #entries + 1) end
  end

  if (_.padEffective & _.PAD_START) ~= 0 then
    ctx.saveError = nil
    local locations = _.getLocations(ctx.context, "osdgsm_cnf", ctx.chosenMcSlot)
    if #locations >= 2 then
      ctx.saveChoices = locations
      ctx.saveSel = 1
      ctx.state = "choose_save"
    else
      local path = ctx.currentPath or (locations and locations[1])
      if path and path ~= "" then
        ctx.lines = _.config_parse.regenerateForSave(ctx.lines, ctx.fileType, _.config_options)
        local parentDir = path:match("^(.+)/[^/]+$")
        local ok, err = _.config_parse.save(path, ctx.lines, parentDir)
        if ok then
          ctx.currentPath = path
          ctx.saveFlash = 60
        else
          ctx.saveError = _.common.localizeParseError(err, _.editor_str) or _.editor_str.save_failed
        end
      else
        ctx.saveError = _.editor_str.no_save_location
      end
    end
  end

  if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
    ctx.state = "select_config"; ctx.currentPath = nil; ctx.lines = nil; ctx.egsmSel = 1; ctx.egsmScroll = 0; ctx.saveError = nil
  end
end

return { run = run }
