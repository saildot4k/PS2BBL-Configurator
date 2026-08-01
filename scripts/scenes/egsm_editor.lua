--[[ eGSM single-screen editor: default + title overrides + Add. Title ID = 4 letters + 5 digits. ]]

local actions_menu = dofile("scripts/scenes/actions_menu.lua")

local function getEgsmBackState(ctx)
  local context = ctx and ctx.context or nil
  local commonRef = ctx and ctx._ and ctx._.common or nil
  if commonRef and commonRef.getEditorBackState then
    return commonRef.getEditorBackState(context, "osdgsm_cnf", commonRef.getPresentMcSlots)
  end
  return "main"
end

local function run(ctx)
  local _ = ctx._
  if not ctx.lines then
    ctx.state = getEgsmBackState(ctx); ctx.currentPath = nil; return
  end

  if _.common.handleLeaveSavePrompt(ctx, {
        onSave = function()
          _.common.saveCurrentConfig(ctx, {
            allowChoose = true,
            locationFileType = "osdgsm_cnf",
            beforeChooseSave = function()
              ctx.returnToSelectConfigAfterSave = getEgsmBackState(ctx)
            end,
            afterSave = function()
              ctx.returnStateAfterSaveFlash = getEgsmBackState(ctx)
              ctx.returnToSelectConfigAfterSaveFlash = true
            end,
          })
        end,
        onDiscard = function()
          ctx.state = getEgsmBackState(ctx)
          ctx.currentPath = nil
          ctx.lines = nil
          ctx.saveSplash = nil
        end,
      }) then
    return
  end

  local pathStr = ctx.currentPath or ""
  if #pathStr > 56 then
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 0.8, pathStr:sub(1, 56), _.DIM_COLOR)
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y + _.scaleY(18), 0.8, pathStr:sub(57), _.DIM_COLOR)
  else
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 0.8, pathStr, _.DIM_COLOR)
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
  if _.common and _.common.drawListScrollbar then
    _.common.drawListScrollbar(_, {
      totalRows = total,
      visibleRows = maxVis,
      scrollRows = ctx.egsmScroll,
      rowTopY = startY,
      rowHeight = _.LINE_H,
      color = _.DIM_COLOR,
    })
  end
  for i = ctx.egsmScroll + 1, math.min(ctx.egsmScroll + maxVis, total) do
    local y = startY + (i - ctx.egsmScroll - 1) * _.LINE_H
    local col = (i == ctx.egsmSel) and _.SELECTED_COLOR or _.UNSELECTED_COLOR
    if i == 1 then
      if defCommented then
        col = (i == ctx.egsmSel) and (_.SELECTED_DIM_COLOR or _.SELECTED_COLOR) or
            (_.DISABLED_DIM_COLOR or _.DIM_COLOR)
      end
      _.drawListRow(_.MARGIN_X + 20, y, i == ctx.egsmSel, _.strings.egsm.default_label, col)
      _.drawText(_.font, _.drawMode, _.VALUE_X, y, _.FONT_SCALE, (defValue == "" and "—") or defValue, col)
    else
      local ent = entries[i - 1]
      if ent.commented then
        col = (i == ctx.egsmSel) and (_.SELECTED_DIM_COLOR or _.SELECTED_COLOR) or
            (_.DISABLED_DIM_COLOR or _.DIM_COLOR)
      end
      _.drawListRow(_.MARGIN_X + 20, y, i == ctx.egsmSel, ent.titleId, col)
      _.drawText(_.font, _.drawMode, _.VALUE_X, y, _.FONT_SCALE, (ent.value == "" and "—") or ent.value, col)
    end
  end

  local hasEntrySelection = (ctx.egsmSel >= 2 and ctx.egsmSel <= 1 + #entries)
  local selectedCommented = defCommented
  if hasEntrySelection then
    selectedCommented = entries[ctx.egsmSel - 1].commented
  end
  local hintItems = {
    { pad = "cross", label = (_.menu_str.edit_label or "Edit"), row = 1 },
    { pad = "square", label = (_.menu_str.actions_label or "Actions"), row = 1 },
    { pad = ctx.configModified and "start" or "", label = ctx.configModified and (_.menu_str.save_config_label or "Save") or "", row = 1 },
    { pad = "triangle", label = selectedCommented and (_.menu_str.enable_label or "Enable") or (_.menu_str.disable_label or "Disable"), row = 1 },
    { pad = "circle", label = (_.menu_str.back_label or "Back"), row = 1 },
  }
  hintItems = _.common.withStartHintVisibility(hintItems, ctx.configModified == true)
  _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, hintItems, nil, _.DIM_COLOR, _.w - 2 * _.MARGIN_X)

  if not ctx.egsmActionsOpen then
    if (_.padEffective & _.PAD_UP) ~= 0 then
      ctx.egsmSel = _.common.moveListSelection(ctx.egsmSel, total, -1, { ctx = ctx })
    end
    if (_.padEffective & _.PAD_DOWN) ~= 0 then
      ctx.egsmSel = _.common.moveListSelection(ctx.egsmSel, total, 1, { ctx = ctx })
    end
  end

  local function toggleSelectedEgsmDisabled()
    if ctx.egsmSel == 1 then
      _.config_parse.setEgsmDefault(ctx.lines, defValue, not defCommented)
      ctx.configModified = true
    elseif ctx.egsmSel >= 2 and ctx.egsmSel <= 1 + #entries then
      local ent = entries[ctx.egsmSel - 1]
      _.config_parse.setEgsmEntry(ctx.lines, ent.titleId, ent.value, not ent.commented)
      ctx.configModified = true
    end
  end

  if (not ctx.egsmActionsOpen) and ((_.padEffective & _.PAD_TRIANGLE) ~= 0) then
    toggleSelectedEgsmDisabled()
  end

  local function beginInsertEgsmEntry()
    local prompt = _.strings.egsm.title_id_prompt
    local initialValue = ""
    local onSubmit = function(val)
      local id = _.config_parse.parseTitleIdInput and _.config_parse.parseTitleIdInput(val or "")
      if id and _.config_parse.isValidTitleId(id) then
        _.config_parse.setEgsmEntry(ctx.lines, id, "", true)
        ctx.configModified = true
        local entriesAfter = _.config_parse.getEgsmEntries(ctx.lines)
        for i, ent in ipairs(entriesAfter) do
          if ent.titleId == id then
            ctx.egsmSel = 1 + i
            break
          end
        end
        ctx.egsmEditDefault = false
        ctx.egsmEditTitleId = id
        ctx.egsmEditCommented = true
        ctx.egsmVideoIdx = nil
        ctx.egsmCompatIdx = nil
        ctx.egsmCompatSelected = nil
        ctx.state = "egsm_value_edit"
        return
      end
      ctx.state = "egsm_editor"
    end
    _.common.beginTextInput(ctx, {
      titleIdMode = true,
      prompt = prompt,
      value = initialValue,
      maxLen = 15,
      callback = onSubmit,
      returnState = "egsm_editor",
      gridSel = 1,
      cursor = 1,
      scroll = 1,
      state = "text_input",
    })
  end

  local function removeSelectedEgsmEntry()
    if not hasEntrySelection then return end
    local ent = entries[ctx.egsmSel - 1]
    _.config_parse.removeEgsmEntry(ctx.lines, ent.titleId)
    ctx.configModified = true
    ctx.egsmSel = math.min(ctx.egsmSel, 1 + #entries - 1)
    if ctx.egsmSel < 1 then ctx.egsmSel = 1 end
  end

  if ctx.egsmActionsOpen then
    local actionRows = {
      { id = "insert", label = (_.menu_str.insert_label or "Insert") },
    }
    if hasEntrySelection then
      actionRows[#actionRows + 1] = { id = "remove", label = (_.menu_str.remove_label or "Remove") }
    end
    if actions_menu.run(ctx, {
          openKey = "egsmActionsOpen",
          selKey = "egsmActionsSel",
          scrollKey = "egsmActionsScroll",
          title = (_.menu_str.actions_title or "Actions"),
          rows = actionRows,
          rowStateKeyPrefix = "egsm_actions_row_",
          onSelect = function(row)
            if row.id == "insert" then
              beginInsertEgsmEntry()
            elseif row.id == "remove" then
              removeSelectedEgsmEntry()
            end
          end,
        }) then
      return
    end
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

  if (_.padEffective & _.PAD_SQUARE) ~= 0 then
    _.common.openActionsMenu(ctx, "egsmActionsOpen", "egsmActionsSel", "egsmActionsScroll")
  end

  if ctx.configModified and (_.padEffective & _.PAD_START) ~= 0 then
    _.common.saveCurrentConfig(ctx, {
      allowChoose = true,
      locationFileType = "osdgsm_cnf",
    })
  end

  if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
    if ctx.configModified then
      ctx.editorLeavePrompt = true
    else
      ctx.state = getEgsmBackState(ctx); ctx.currentPath = nil; ctx.lines = nil; ctx.saveSplash = nil
    end
  end
end

return { run = run }
