--[[ eGSM single-screen editor: default + title overrides + Add. Title ID = 4 letters + 5 digits. ]]

local function run(ctx)
  local _ = ctx._
  if not ctx.lines then
    ctx.state = "select_config"; ctx.currentPath = nil; return
  end

  -- Leave-save prompt when going back to config select with unsaved changes
  if ctx.editorLeavePrompt then
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1, _.editor_str.leave_save_prompt, _.WHITE)
    _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, _.editor_str.leave_save_hint_items, nil, _.DIM,
      _.w - 2 * _.MARGIN_X)
    if (_.padEffective & _.PAD_CROSS) ~= 0 then
      ctx.editorLeavePrompt = nil
      ctx.saveSplash = nil
      local locations = _.getLocations(ctx.context, "osdgsm_cnf", ctx.chosenMcSlot)
      if #locations >= 2 then
        ctx.returnToSelectConfigAfterSave = true
        ctx.saveChoices = locations
        ctx.saveSel = 1
        ctx.state = "choose_save"
      else
        local path = ctx.currentPath or (locations and locations[1])
        if path and path ~= "" then
          ctx.lines = _.config_parse.regenerateForSave(ctx.lines, ctx.fileType, _.config_options)
          local parentDir = path:match("^(.+)/[^/]+$")
          local ok, err = _.common.saveConfig(ctx, path, ctx.lines, parentDir)
          if ok then
            ctx.currentPath = path
            ctx.saveSplash = { kind = "saved", detail = path or "", framesLeft = 60 }
            ctx.configModified = false
            ctx.returnToSelectConfigAfterSaveFlash = true
          else
            ctx.saveSplash = { kind = "failed", detail = _.common.localizeParseError(err, _.editor_str) or
            _.editor_str.save_failed, framesLeft = 60 }
          end
        else
          ctx.saveSplash = { kind = "failed", detail = _.editor_str.no_save_location, framesLeft = 60 }
        end
      end
    elseif (_.padEffective & _.PAD_TRIANGLE) ~= 0 then
      ctx.editorLeavePrompt = nil
      ctx.state = "select_config"
      ctx.currentPath = nil
      ctx.lines = nil
      ctx.egsmSel = 1
      ctx.egsmScroll = 0
      ctx.saveSplash = nil
    elseif (_.padEffective & _.PAD_CIRCLE) ~= 0 then
      ctx.editorLeavePrompt = nil
    end
    return
  end

  local pathStr = ctx.currentPath or ""
  if #pathStr > 56 then
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 0.8, pathStr:sub(1, 56), _.DIM)
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y + _.scaleY(18), 0.8, pathStr:sub(57), _.DIM)
  else
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 0.8, pathStr, _.DIM)
  end

  if ctx.saveSplash and ctx.saveSplash.framesLeft > 0 and ctx.saveSplash.kind == "saved" and ctx.returnToSelectConfigAfterSaveFlash then
    return
  end

  local entries = _.config_parse.getEgsmEntries(ctx.lines)
  local total = 1 + #entries
  if ctx.egsmSel < 1 then ctx.egsmSel = 1 end
  if ctx.egsmSel > total then ctx.egsmSel = total end
  local maxVis = _.MAX_VISIBLE_LIST
  if total > maxVis then
    ctx.egsmScroll = ctx.egsmSel - math.floor(maxVis / 2)
    ctx.egsmScroll = math.max(0, math.min(ctx.egsmScroll, total - maxVis))
  else
    ctx.egsmScroll = 0
  end

  local defValue, defCommented = _.config_parse.getEgsmDefault(ctx.lines)
  local startY = _.MARGIN_Y + _.scaleY(50)
  local counterStr = ctx.egsmSel .. "/" .. total
  local counterW = (_.common.calcTextWidth and _.common.calcTextWidth(_.font, counterStr, 0.7)) or (#counterStr * 8)
  _.drawText(_.font, _.drawMode, math.max(_.MARGIN_X, (_.w or 640) - _.MARGIN_X - counterW), _.MARGIN_Y, 0.7, counterStr,
    _.DIM)
  for i = ctx.egsmScroll + 1, math.min(ctx.egsmScroll + maxVis, total) do
    local y = startY + (i - ctx.egsmScroll - 1) * _.LINE_H
    local col = (i == ctx.egsmSel) and _.SELECTED_ENTRY or _.WHITE
    if i == 1 then
      if defCommented then
        col = (i == ctx.egsmSel) and (_.SELECTED_ENTRY_DIM or _.SELECTED_ENTRY) or
            (_.DIM_ENTRY or _.DIM)
      end
      _.drawListRow(_.MARGIN_X + 20, y, i == ctx.egsmSel, _.strings.egsm.default_label, col)
      _.drawText(_.font, _.drawMode, _.VALUE_X, y, _.FONT_SCALE, (defValue == "" and "—") or defValue, col)
    else
      local ent = entries[i - 1]
      if ent.commented then
        col = (i == ctx.egsmSel) and (_.SELECTED_ENTRY_DIM or _.SELECTED_ENTRY) or
            (_.DIM_ENTRY or _.DIM)
      end
      _.drawListRow(_.MARGIN_X + 20, y, i == ctx.egsmSel, ent.titleId, col)
      _.drawText(_.font, _.drawMode, _.VALUE_X, y, _.FONT_SCALE, (ent.value == "" and "—") or ent.value, col)
    end
  end

  local hintItems = _.strings.egsm.hint_items
  if ctx.egsmSel == 1 then
    hintItems = defCommented and (_.strings.egsm.hint_items_with_enable or hintItems) or
        (_.strings.egsm.hint_items_with_disable or hintItems)
  elseif ctx.egsmSel >= 2 and ctx.egsmSel <= 1 + #entries then
    local ent = entries[ctx.egsmSel - 1]
    hintItems = ent.commented and (_.strings.egsm.hint_items_with_enable or hintItems) or
        (_.strings.egsm.hint_items_with_disable or hintItems)
  end
  _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, hintItems, nil, _.DIM, _.w - 2 * _.MARGIN_X)

  if (_.padEffective & _.PAD_UP) ~= 0 then
    ctx.egsmSel = ctx.egsmSel - 1; if ctx.egsmSel < 1 then ctx.egsmSel = total end
  end
  if (_.padEffective & _.PAD_DOWN) ~= 0 then
    ctx.egsmSel = ctx.egsmSel + 1; if ctx.egsmSel > total then ctx.egsmSel = 1 end
  end

  if (_.padEffective & _.PAD_TRIANGLE) ~= 0 and (ctx.egsmSel == 1 or (ctx.egsmSel >= 2 and ctx.egsmSel <= 1 + #entries)) then
    if ctx.egsmSel == 1 then
      _.config_parse.setEgsmDefault(ctx.lines, defValue, not defCommented)
    else
      local ent = entries[ctx.egsmSel - 1]
      _.config_parse.setEgsmEntry(ctx.lines, ent.titleId, ent.value, not ent.commented)
    end
    ctx.configModified = true
  end

  if (_.padEffective & _.PAD_CROSS) ~= 0 and (ctx.egsmSel == 1 or (ctx.egsmSel >= 2 and ctx.egsmSel <= 1 + #entries)) then
    ctx.egsmEditDefault = (ctx.egsmSel == 1)
    if not ctx.egsmEditDefault then
      local ent = entries[ctx.egsmSel - 1]
      ctx.egsmEditTitleId = ent.titleId
      ctx.egsmEditCommented = ent.commented
    else
      ctx.egsmEditTitleId = nil
      ctx.egsmEditCommented = defCommented
    end
    ctx.egsmVideoIdx = nil
    ctx.egsmCompatIdx = nil
    ctx.state = "egsm_value_edit"
  end

  if (_.padEffective & _.PAD_SELECT) ~= 0 then
    ctx.textInputPrompt = _.strings.egsm.title_id_prompt
    ctx.textInputValue = ""
    ctx.textInputMaxLen = 15
    ctx.textInputTitleIdMode = true
    ctx.textInputCallback = function(val)
      local id = _.config_parse.parseTitleIdInput and _.config_parse.parseTitleIdInput(val or "")
      if id and _.config_parse.isValidTitleId(id) then
        _.config_parse.setEgsmEntry(ctx.lines, id, "", true)
        local entriesAfter = _.config_parse.getEgsmEntries(ctx.lines)
        for i, ent in ipairs(entriesAfter) do
          if ent.titleId == id then
            ctx.egsmSel = 1 + i
            break
          end
        end
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
    ctx.egsmSel = math.min(ctx.egsmSel, 1 + #entries - 1)
    if ctx.egsmSel < 1 then ctx.egsmSel = 1 end
  end

  if (_.padEffective & _.PAD_START) ~= 0 then
    ctx.saveSplash = nil
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
        local ok, err = _.common.saveConfig(ctx, path, ctx.lines, parentDir)
        if ok then
          ctx.currentPath = path
          ctx.saveSplash = { kind = "saved", detail = path or "", framesLeft = 60 }
          ctx.configModified = false
        else
          ctx.saveSplash = { kind = "failed", detail = _.common.localizeParseError(err, _.editor_str) or
          _.editor_str.save_failed, framesLeft = 60 }
        end
      else
        ctx.saveSplash = { kind = "failed", detail = _.editor_str.no_save_location, framesLeft = 60 }
      end
    end
  end

  if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
    if ctx.configModified then
      ctx.editorLeavePrompt = true
    else
      ctx.state = "select_config"; ctx.currentPath = nil; ctx.lines = nil; ctx.egsmSel = 1; ctx.egsmScroll = 0; ctx.saveSplash = nil
    end
  end
end

return { run = run }
