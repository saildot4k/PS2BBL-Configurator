--[[ Editor state: config option list and category list (OSDMENU). ]]

local function formatTimerSeconds(msText, unitSingular, unitPlural)
  local ms = tonumber(msText or "")
  if not ms then return msText end
  local singular = unitSingular or "second"
  local plural = unitPlural or "seconds"
  if ms <= 0 then return "0 " .. plural end
  local sec10 = math.floor((ms + 50) / 100)
  local secText
  if sec10 % 10 == 0 then
    secText = tostring(math.floor(sec10 / 10))
  else
    secText = string.format("%.1f", sec10 / 10)
  end
  local unit = (secText == "1") and singular or plural
  return secText .. " " .. unit
end

local function formatArgCount(n)
  local count = tonumber(n) or 0
  if count == 1 then return "(1 arg)" end
  return "(" .. tostring(count) .. " args)"
end

local function getOsdmbrHotkeyPadName(key)
  if key == "boot_start" then return "start" end
  if key == "boot_triangle" then return "triangle" end
  if key == "boot_circle" then return "circle" end
  if key == "boot_cross" then return "cross" end
  if key == "boot_square" then return "square" end
  return nil
end

local function getCategoryOptSel(ctx, categoryIdx)
  if not categoryIdx or categoryIdx < 1 then return 1 end
  local byFile = ctx.editorCategoryOptSelByFile
  if type(byFile) ~= "table" then return 1 end
  local fileKey = ctx.fileType or "__none__"
  local byCategory = byFile[fileKey]
  if type(byCategory) ~= "table" then return 1 end
  local sel = byCategory[categoryIdx]
  if type(sel) ~= "number" then return 1 end
  return math.max(1, math.floor(sel))
end

local function setCategoryOptSel(ctx, categoryIdx, sel)
  if not categoryIdx or categoryIdx < 1 then return end
  if type(ctx.editorCategoryOptSelByFile) ~= "table" then
    ctx.editorCategoryOptSelByFile = {}
  end
  local fileKey = ctx.fileType or "__none__"
  if type(ctx.editorCategoryOptSelByFile[fileKey]) ~= "table" then
    ctx.editorCategoryOptSelByFile[fileKey] = {}
  end
  ctx.editorCategoryOptSelByFile[fileKey][categoryIdx] = math.max(1, math.floor(tonumber(sel) or 1))
end

local function getEditorBackState(ctx)
  local context = ctx and ctx.context or nil
  local fileType = ctx and ctx.fileType or nil
  if context == "ps2bbl" or context == "psxbbl" then
    return "select_config"
  end
  if context == "osdmenu" or context == "freemcboot" then
    if fileType == "osdmenu_cnf" or fileType == "osdgsm_cnf" or fileType == "freemcboot_cnf" then
      local common = ctx and ctx._ and ctx._.common or nil
      local slots = (common and common.getPresentMcSlots and common.getPresentMcSlots()) or {}
      if type(slots) == "table" and #slots > 1 then
        return "choose_mc"
      end
      return "main"
    end
  end
  return "main"
end

local function run(ctx)
  local _ = ctx._
  -- Leave-save prompt when going back to file select with unsaved changes
  if ctx.editorLeavePrompt then
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1, _.editor_str.leave_save_prompt, _.WHITE)
    _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, _.editor_str.leave_save_hint_items, nil, _.DIM,
      _.w - 2 * _.MARGIN_X)
    if (_.padEffective & _.PAD_CROSS) ~= 0 then
      ctx.editorLeavePrompt = nil
      ctx.saveSplash = nil
      local locations = _.getLocations(ctx.context, ctx.fileType, ctx.chosenMcSlot)
      if ctx.fileType == "osdmenu_cnf" and #locations >= 2 then
        ctx.returnToSelectConfigAfterSave = getEditorBackState(ctx)
        ctx.saveChoices = locations
        ctx.saveSel = ctx.saveSel or 1
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
                ctx.returnStateAfterSaveFlash = getEditorBackState(ctx)
                ctx.returnToSelectConfigAfterSaveFlash = true
              else
            ctx.saveSplash = {
              kind = "failed",
              detail = _.common.localizeParseError(err, _.editor_str) or
                  _.editor_str.save_failed,
              framesLeft = 60
            }
          end
        else
          ctx.saveSplash = { kind = "failed", detail = _.editor_str.no_save_location, framesLeft = 60 }
        end
      end
    elseif (_.padEffective & _.PAD_TRIANGLE) ~= 0 then
      ctx.editorLeavePrompt = nil
      ctx.state = getEditorBackState(ctx)
      ctx.currentPath = nil
      ctx.lines = nil
      ctx.optList = nil
      ctx.editorCategoryIdx = 0
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

  local isCategorizedFile = (ctx.fileType == "osdmenu_cnf" or ctx.fileType == "freemcboot_cnf" or
      ctx.fileType == "ps2bbl_ini" or ctx.fileType == "psxbbl_ini")
  local categories = {}
  if ctx.fileType == "osdmenu_cnf" then
    categories = _.config_options.osdmenu_cnf_categories or {}
  elseif ctx.fileType == "freemcboot_cnf" then
    categories = _.config_options.freemcboot_cnf_categories or _.config_options.osdmenu_cnf_categories or {}
  elseif ctx.fileType == "ps2bbl_ini" then
    categories = _.config_options.ps2bbl_ini_categories or {}
  elseif ctx.fileType == "psxbbl_ini" then
    categories = _.config_options.psxbbl_ini_categories or {}
  end

  if isCategorizedFile and ctx.editorCategoryIdx == 0 then
    local cats = categories
    if ctx.optSel < 1 then ctx.optSel = 1 end
    if ctx.optSel > #cats then ctx.optSel = #cats end
    local maxVis = _.MAX_VISIBLE
    if #cats > maxVis then
      ctx.optScroll = ctx.optSel - math.floor(maxVis / 2)
      ctx.optScroll = math.max(0, math.min(ctx.optScroll, #cats - maxVis))
    else
      ctx.optScroll = 0
    end
    local maxCatLabelW = (_.w or 640) - (_.MARGIN_X + 16) - (_.MARGIN_X + 8)
    for i = ctx.optScroll + 1, math.min(ctx.optScroll + maxVis, #cats) do
      local cat = cats[i]
      local y = _.MARGIN_Y + _.scaleY(50) + (i - ctx.optScroll - 1) * _.ROW_H
      local col = (i == ctx.optSel) and _.SELECTED_ENTRY or _.WHITE
      local catLabel = cat.name or _.common_str.empty
      if ctx.fileType == "osdmenu_cnf" then
        catLabel = (_.strings.categories and _.strings.categories[i]) or catLabel
      elseif ctx.fileType == "freemcboot_cnf" then
        catLabel = (_.strings.categories_freemcboot and _.strings.categories_freemcboot[i]) or catLabel
      end
      if _.common.fitListRowText then
        catLabel = _.common.fitListRowText(ctx, "editor_cat_row_" .. tostring(i), _.font, catLabel, maxCatLabelW,
          _.FONT_SCALE, i == ctx.optSel)
      elseif _.common.truncateTextToWidth then
        catLabel = _.common.truncateTextToWidth(_.font, catLabel, maxCatLabelW, _.FONT_SCALE)
      end
      _.drawListRow(_.MARGIN_X + 16, y, i == ctx.optSel,
        catLabel, col)
    end
    _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, _.editor_str.cross_open_circle_back_items, nil,
      _.DIM, _.w - 2 * _.MARGIN_X)
    if (_.padEffective & _.PAD_UP) ~= 0 then
      ctx.optSel = ctx.optSel - 1; if ctx.optSel < 1 then ctx.optSel = #cats end
    end
    if (_.padEffective & _.PAD_DOWN) ~= 0 then
      ctx.optSel = ctx.optSel + 1; if ctx.optSel > #cats then ctx.optSel = 1 end
    end
    if (_.padEffective & _.PAD_CROSS) ~= 0 and #cats > 0 then
      local cat = cats[ctx.optSel]
      local actionKey = cat and #(cat.options or {}) == 1 and cat.options[1].key or nil
      if actionKey == "_menu_entries" then
        ctx.state = "menu_entries"
        ctx.entryList = _.config_parse.getMenuEntryIndices(ctx.lines)
        ctx.entrySel = ctx.entrySel or 1
        ctx.entryScroll = ctx.entryScroll or 0
      elseif actionKey == "_bbl_hotkeys" then
        ctx.bblHotkeySel = ctx.bblHotkeySel or 1
        ctx.state = "bbl_hotkeys"
      else
        local selectedCategoryIdx = ctx.optSel
        ctx.editorCategoryIdx = selectedCategoryIdx
        local rawOpts = cat.options or {}
        -- DKWDRV custom path not applicable for HOSDMenu (no MC path)
        if ctx.context == "hosdmenu" and ctx.fileType == "osdmenu_cnf" then
          ctx.optList = {}
          for _, o in ipairs(rawOpts) do
            if o.key ~= "path_DKWDRV_ELF" then ctx.optList[#ctx.optList + 1] = o end
          end
        else
          ctx.optList = rawOpts
        end
        local rememberedSel = getCategoryOptSel(ctx, selectedCategoryIdx)
        if #ctx.optList > 0 then
          ctx.optSel = math.max(1, math.min(rememberedSel, #ctx.optList))
        else
          ctx.optSel = 1
        end
        ctx.optScroll = ctx.optScroll or 0
      end
    end
    if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
      if ctx.configModified then
        ctx.editorLeavePrompt = true
      else
        ctx.state = getEditorBackState(ctx); ctx.currentPath = nil; ctx.lines = nil; ctx.optList = nil; ctx.editorCategoryIdx = 0
      end
    end
  elseif ctx.optList and #ctx.optList > 0 then
    local startY = _.MARGIN_Y + _.scaleY(58)
    local maxVis = _.MAX_VISIBLE
    if #ctx.optList > maxVis then
      ctx.optScroll = ctx.optSel - math.floor(maxVis / 2)
      ctx.optScroll = math.max(0, math.min(ctx.optScroll, #ctx.optList - maxVis))
    else
      ctx.optScroll = 0
    end
    for i = ctx.optScroll + 1, math.min(ctx.optScroll + maxVis, #ctx.optList) do
      local o = ctx.optList[i]
      local y = startY + (i - ctx.optScroll - 1) * _.ROW_H
      local col = (i == ctx.optSel) and _.SELECTED_ENTRY or _.WHITE
      local lab = (_.strings.options and _.strings.options[o.key] and _.strings.options[o.key].label) or o.label
      local valDisplay
      if o.optType == "header" or o.optType == "action" then
        valDisplay = ""
      elseif o.optType == "color" then
        valDisplay = nil
      elseif o.optType == "bool" then
        local v = _.config_parse.get(ctx.lines, o.key) or o.default or "0"
        valDisplay = (v == "1") and _.common_str.on or _.common_str.off
      elseif o.optType == "boot_paths" then
        local paths = _.config_parse.getBootPaths(ctx.lines, o.key)
        if not paths or #paths == 0 then
          valDisplay = ""
        else
          valDisplay = #paths .. _.menu_str.path_s
        end
      elseif o.optType == "bbl_slot" then
        local keyId = o.bblKeyId or "AUTO"
        local slotIdx = tonumber(o.bblEntrySlot)
        local slot = (slotIdx and _.config_parse.getBblHotkeySlot) and _.config_parse.getBblHotkeySlot(ctx.lines, keyId, slotIdx) or
            nil
        if slot and slot.used then
          local p = (slot.path ~= "" and slot.path) or _.common_str.not_set
          if ctx.fileType == "freemcboot_cnf" then
            valDisplay = p
          else
            valDisplay = p .. " " .. formatArgCount(slot.argCount)
          end
        else
          valDisplay = _.common_str.not_set
        end
      elseif o.optType == "enum" then
        local raw = _.config_parse.get(ctx.lines, o.key) or o.default or ""
        if raw ~= "" and o.enumDisplayMap and o.enumDisplayMap[raw] then
          valDisplay = o.enumDisplayMap[raw]
        else
          valDisplay = raw
        end
      else
        local multi = _.config_parse.getMulti(ctx.lines, o.key)
        if multi and #multi > 1 then
          valDisplay = #multi .. " paths"
        else
          valDisplay = _.config_parse.get(ctx.lines, o.key) or o.default or ""
        end
      end
      if o.key == "KEY_READ_WAIT_TIME" and valDisplay and valDisplay ~= "" then
        local commonStrings = _.common_str or {}
        local unitSingular = commonStrings.second or "second"
        local unitPlural = commonStrings.seconds or "seconds"
        valDisplay = formatTimerSeconds(valDisplay, unitSingular, unitPlural)
      end
      local inlineAutoRow = false
      local bootHotkeyPad = nil
      local bootHotkeyIcon = nil
      local bootHotkeyIconW, bootHotkeyIconH, bootHotkeyIconGap = 0, 0, 0
      if ctx.fileType == "osdmbr_cnf" and o.optType == "boot_paths" then
        bootHotkeyPad = getOsdmbrHotkeyPadName(o.key)
        if bootHotkeyPad then
          bootHotkeyIcon = _.common.getPadIcon and _.common.getPadIcon(bootHotkeyPad) or nil
          if bootHotkeyIcon then
            local baseIconW = _.common.PAD_ICON_W or 26
            local baseIconH = _.common.PAD_ICON_H or 26
            local textH = (_.common and _.common.FT_PIXEL_H) or 18
            bootHotkeyIconH = math.min(baseIconH, textH)
            bootHotkeyIconW = math.max(1, math.floor((baseIconW * bootHotkeyIconH) / baseIconH + 0.5))
            bootHotkeyIconGap = 8
          end
        end
      end
      if o.key == "NAME_AUTO" then
        inlineAutoRow = true
        local nameVal = _.config_parse.get(ctx.lines, o.key) or o.default or ""
        local nameDisp = (nameVal ~= "" and nameVal) or _.common_str.empty
        lab = (_.menu_str.name or "Name: ") .. nameDisp
        valDisplay = ""
      elseif ctx.fileType == "freemcboot_cnf" and o.key and o.key:match("^ESR_Path_E%d+$") then
        inlineAutoRow = true
        local slotIdx = o.key:match("^ESR_Path_E(%d+)$") or "?"
        local pathVal = _.config_parse.get(ctx.lines, o.key) or o.default or ""
        local pathDisp = (pathVal ~= "" and pathVal) or _.common_str.not_set
        lab = "ESR path E" .. tostring(slotIdx) .. ": " .. pathDisp
        valDisplay = ""
      elseif o.optType == "bbl_slot" and (o.bblKeyId == "AUTO" or (o.key and o.key:match("^_auto_e%d+$"))) then
        inlineAutoRow = true
        local slotIdx = tonumber(o.bblEntrySlot) or 0
        local slot = _.config_parse.getBblHotkeySlot and _.config_parse.getBblHotkeySlot(ctx.lines, "AUTO", slotIdx) or nil
        local pathDisp = (slot and slot.path and slot.path ~= "") and slot.path or _.common_str.not_set
        if ctx.fileType == "freemcboot_cnf" then
          lab = "E" .. tostring(slotIdx) .. ": " .. pathDisp
        else
          local argCount = (slot and slot.argCount) or 0
          lab = "E" .. tostring(slotIdx) .. ": " .. pathDisp .. " " .. formatArgCount(argCount)
        end
        valDisplay = ""
      end
      if inlineAutoRow then
        local maxInlineW = (_.w or 640) - (_.MARGIN_X + 16) - (_.MARGIN_X + 8)
        if _.common.fitListRowText then
          lab = _.common.fitListRowText(ctx, "editor_autoboot_row_" .. tostring(i), _.font, lab, maxInlineW, _.FONT_SCALE,
            i == ctx.optSel)
        elseif _.common.truncateTextToWidth then
          lab = _.common.truncateTextToWidth(_.font, lab, maxInlineW, _.FONT_SCALE)
        end
      elseif bootHotkeyIcon then
        local rowTextX = (_.MARGIN_X + 16) + bootHotkeyIconW + bootHotkeyIconGap
        local maxInlineW = (_.w or 640) - rowTextX - (_.MARGIN_X + 8)
        if _.common.fitListRowText then
          lab = _.common.fitListRowText(ctx, "editor_boot_hotkey_row_" .. tostring(i), _.font, lab, maxInlineW, _.FONT_SCALE,
            i == ctx.optSel)
        elseif _.common.truncateTextToWidth then
          lab = _.common.truncateTextToWidth(_.font, lab, maxInlineW, _.FONT_SCALE)
        end
      else
        local valueColX = _.VALUE_X or 360
        local maxInlineW = valueColX - (_.MARGIN_X + 16) - 14
        if valDisplay == nil then
          maxInlineW = (_.w or 640) - (_.MARGIN_X + 16) - (_.MARGIN_X + 8)
        end
        if _.common.fitListRowText then
          lab = _.common.fitListRowText(ctx, "editor_opt_row_" .. tostring(i), _.font, lab, maxInlineW, _.FONT_SCALE,
            i == ctx.optSel)
        elseif _.common.truncateTextToWidth then
          lab = _.common.truncateTextToWidth(_.font, lab, maxInlineW, _.FONT_SCALE)
        end
      end
      if bootHotkeyIcon then
        local rowX = _.MARGIN_X + 16
        local iconY = y + math.floor(((_.LINE_H or bootHotkeyIconH) - bootHotkeyIconH) / 2)
        if _.Graphics.drawScaleImage then
          _.Graphics.drawScaleImage(bootHotkeyIcon, rowX, iconY, bootHotkeyIconW, bootHotkeyIconH)
        else
          _.Graphics.drawImage(bootHotkeyIcon, rowX, iconY)
        end
        _.drawText(_.font, _.drawMode, rowX + bootHotkeyIconW + bootHotkeyIconGap, y, _.FONT_SCALE, lab, col)
      else
        _.drawListRow(_.MARGIN_X + 16, y, i == ctx.optSel, lab, col)
      end
      if (not inlineAutoRow) and valDisplay == "" and (o.optType == "path" or o.optType == "boot_paths" or o.optType == "text" or o.optType == "enum") then
        valDisplay = _.common_str.not_set
      end
      if valDisplay then
        if valDisplay ~= "" then
          local valCol = (valDisplay == _.common_str.off or valDisplay == _.common_str.not_set) and _.DIM or
              ((i == ctx.optSel) and _.WHITE or _.GRAY)
          local valueAreaWidth = (_.w or 640) - 72 - _.VALUE_X
          local textW = (_.common.calcTextWidth and _.common.calcTextWidth(_.font, valDisplay, _.FONT_SCALE)) or
              (#valDisplay * 10)
          local drawVal = valDisplay
          if i == ctx.optSel and textW > valueAreaWidth then
            -- Autoscroll long value (e.g. DKWDRV path): hold at start, scroll slowly, hold at end then repeat
            ctx.editorValueScrollTicks = (ctx.editorValueScrollTicks or 0) + 1
            local ticks = ctx.editorValueScrollTicks
            local visibleChars = 1
            if _.common.calcTextWidth then
              for n = 1, #valDisplay do
                if _.common.calcTextWidth(_.font, valDisplay:sub(1, n), _.FONT_SCALE) > valueAreaWidth then
                  visibleChars = n - 1
                  break
                end
                visibleChars = n
              end
            else
              visibleChars = math.max(1, math.floor(valueAreaWidth / 10))
            end
            visibleChars = math.min(visibleChars, #valDisplay)
            local totalSteps = math.max(0, #valDisplay - visibleChars)
            local HOLD_START, FRAMES_PER_STEP, HOLD_END = 50, 18, 70
            local cycleLen = HOLD_START + totalSteps * FRAMES_PER_STEP + HOLD_END
            if ticks >= cycleLen then
              ctx.editorValueScrollTicks = 0
              ticks = 0
            end
            local scrollStart
            if ticks < HOLD_START then
              scrollStart = 1
            elseif ticks < HOLD_START + totalSteps * FRAMES_PER_STEP then
              scrollStart = 1 + math.floor((ticks - HOLD_START) / FRAMES_PER_STEP)
            else
              scrollStart = totalSteps + 1
            end
            drawVal = valDisplay:sub(scrollStart, scrollStart + visibleChars - 1)
          elseif i ~= ctx.optSel then
            -- Truncate to fit within value area (screen margin)
            if textW > valueAreaWidth and _.common.calcTextWidth then
              for n = 1, #valDisplay do
                if _.common.calcTextWidth(_.font, valDisplay:sub(1, n) .. "...", _.FONT_SCALE) > valueAreaWidth then
                  drawVal = (n > 1 and (valDisplay:sub(1, n - 1) .. "...") or "...")
                  break
                end
                drawVal = valDisplay
              end
            elseif textW > valueAreaWidth then
              local maxLen = math.max(1, math.floor(valueAreaWidth / 10) - 3)
              drawVal = valDisplay:sub(1, maxLen) .. "..."
            end
          end
          _.drawText(_.font, _.drawMode, _.VALUE_X, y, _.FONT_SCALE, drawVal, valCol)
        end
      elseif o.optType == "color" then
        local r, g, b, a = _.parseColor(_.config_parse.get(ctx.lines, o.key) or o.default)
        local swatchColor = _.Color.new(r, g, b, a)
        _.Graphics.drawRect(_.VALUE_X, y, 28, _.scaleY(18), swatchColor)
      end
    end
    local selOpt = ctx.optList[ctx.optSel]
    if selOpt then
      local descStr = (_.strings.options and _.strings.options[selOpt.key] and _.strings.options[selOpt.key].desc) or
          selOpt.desc or ""
      if selOpt.key == "LOGO_DISPLAY" then
        local cur = _.config_parse.get(ctx.lines, selOpt.key) or selOpt.default or ""
        local n = tonumber(cur) or 0
        descStr = (n >= 4) and "Display speed: SLOWER (4-5)" or "Display speed: FAST (0-3)"
      end
      if descStr ~= "" then
        local tw = _.common.calcTextWidth(_.font, descStr, 0.72)
        local x = _.common.centerX(_, tw)
        _.drawText(_.font, _.drawMode, x, _.DESC_Y_BOTTOM, 0.72, descStr, _.DIM)
      end
    end
    if #ctx.optList > maxVis then
      _.drawText(_.font, _.drawMode, _.w - 72, startY - _.scaleY(4), 0.7, ctx.optSel .. "/" .. #ctx.optList, _.DIM)
    end
    local hintItems = _.common.buildEditorHintItems(selOpt, _.editor_str.hint_edit_items,
      _.config_options.getOsdmenuDefault,
      { left = _.common_str.hint_prev, right = _.common_str.hint_next })
    _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, hintItems, nil, _.DIM, _.w - 2 * _.MARGIN_X)
    if (_.padEffective & _.PAD_UP) ~= 0 then
      if ctx.optSel > 1 then ctx.optSel = ctx.optSel - 1 else ctx.optSel = #ctx.optList end
      ctx.editorValueScrollTicks = nil
    end
    if (_.padEffective & _.PAD_DOWN) ~= 0 then
      if ctx.optSel < #ctx.optList then ctx.optSel = ctx.optSel + 1 else ctx.optSel = 1 end
      ctx.editorValueScrollTicks = nil
    end
    if (_.padEffective & (_.PAD_LEFT | _.PAD_RIGHT | _.PAD_L1 | _.PAD_R1 | _.PAD_L2 | _.PAD_R2)) ~= 0 then
      local o = ctx.optList[ctx.optSel]
      if o.optType == "enum" and o.enumVals and #o.enumVals > 0 then
        local cur = _.config_parse.get(ctx.lines, o.key) or o.default or ""
        local allowUnset = (o.default == "")
        local idx = 0
        if cur == "" then
          idx = allowUnset and 0 or 1
        else
          for ei, v in ipairs(o.enumVals) do
            if v == cur then
              idx = ei; break
            end
          end
          if idx == 0 then idx = 1 end
        end
        if (_.padEffective & _.PAD_LEFT) ~= 0 then
          idx = idx - 1
          if idx < 0 then idx = #o.enumVals end
          if idx == 0 and not allowUnset then idx = #o.enumVals end
        end
        if (_.padEffective & _.PAD_RIGHT) ~= 0 then
          idx = idx + 1
          if idx > #o.enumVals then idx = (allowUnset and 0 or 1) end
        end
        _.config_parse.set(ctx.lines, o.key, (idx == 0) and "" or o.enumVals[idx])
        ctx.configModified = true
      elseif (o.optType == "int" or o.optType == "string") then
        local cur = _.config_parse.get(ctx.lines, o.key) or o.default or "0"
        local num = tonumber(cur)
        if num then
          local minV = tonumber(o.min)
          local maxV = tonumber(o.max)
          if minV == nil then minV = 0 end
          if maxV == nil then maxV = 9999 end
          if o.min == nil and o.max == nil then
            if o.key and o.key:match("menu_x") then
              maxV = 639
            elseif o.key and o.key:match("menu_y") then
              maxV = 447
            elseif o.key and o.key:match("num_displayed") then
              minV, maxV = 1, 30
            end
          end
          local delta = 0
          if o.intPadDeltas then
            local d = o.intPadDeltas
            if (_.padEffective & _.PAD_RIGHT) ~= 0 then delta = tonumber(d.right) or delta end
            if (_.padEffective & _.PAD_LEFT) ~= 0 then delta = tonumber(d.left) or delta end
            if (_.padEffective & _.PAD_R1) ~= 0 then delta = tonumber(d.R1) or delta end
            if (_.padEffective & _.PAD_L1) ~= 0 then delta = tonumber(d.L1) or delta end
            if (_.padEffective & _.PAD_R2) ~= 0 then delta = tonumber(d.R2) or delta end
            if (_.padEffective & _.PAD_L2) ~= 0 then delta = tonumber(d.L2) or delta end
          else
            if (_.padEffective & _.PAD_RIGHT) ~= 0 then delta = 1 end
            if (_.padEffective & _.PAD_LEFT) ~= 0 then delta = -1 end
            if (_.padEffective & _.PAD_R1) ~= 0 then delta = 10 end
            if (_.padEffective & _.PAD_L1) ~= 0 then delta = -10 end
            if (_.padEffective & _.PAD_R2) ~= 0 then delta = 50 end
            if (_.padEffective & _.PAD_L2) ~= 0 then delta = -50 end
          end
          if delta ~= 0 then
            num = num + delta
            if num < minV then num = minV end
            if num > maxV then num = maxV end
            _.config_parse.set(ctx.lines, o.key, tostring(num))
            ctx.configModified = true
          end
        end
      end
    end
    if (_.padEffective & _.PAD_CROSS) ~= 0 then
      local o = ctx.optList[ctx.optSel]
      if o.optType == "bool" then
        local cur = _.config_parse.get(ctx.lines, o.key) or o.default or "0"
        _.config_parse.set(ctx.lines, o.key, (cur == "1") and "0" or "1")
        ctx.configModified = true
      elseif o.optType == "color" then
        ctx.colorOpt = o
        local r, g, b, a = _.parseColor(_.config_parse.get(ctx.lines, o.key) or o.default)
        ctx.colorVals = { r, g, b, a }
        ctx.colorCh = 1
        ctx.state = "color_edit"
      elseif o.optType == "text" or o.optType == "string" then
        ctx.textInputTitleIdMode = nil
        ctx.textInputPrompt = (_.strings.options and _.strings.options[o.key] and _.strings.options[o.key].label) or
            o.label or _.common_str.enter_text
        ctx.textInputValue = _.config_parse.get(ctx.lines, o.key) or o.default or ""
        ctx.textInputMaxLen = (o.maxLen and o.maxLen > 0) and o.maxLen or 79
        ctx.textInputCallback = function(val)
          _.config_parse.set(ctx.lines, o.key, val or "")
          ctx.configModified = true
          ctx.state = "editor"
        end
        ctx.textInputReturnState = "editor"
        ctx.textInputGridSel = 1
        ctx.textInputCursor = #ctx.textInputValue + 1
        ctx.textInputScroll = 1
        ctx.state = "text_input"
      elseif o.key == "_menu_entries" then
        ctx.state = "menu_entries"
        ctx.entryList = _.config_parse.getMenuEntryIndices(ctx.lines)
        ctx.entrySel = ctx.entrySel or 1
        ctx.entryScroll = ctx.entryScroll or 0
      elseif o.key == "_bbl_hotkeys" then
        ctx.bblHotkeySel = ctx.bblHotkeySel or 1
        ctx.state = "bbl_hotkeys"
      elseif o.optType == "bbl_slot" and o.bblEntrySlot then
        ctx.bblHotkeyKey = o.bblKeyId or "AUTO"
        ctx.bblEntrySlot = tonumber(o.bblEntrySlot)
        ctx.bblEntryDetailSel = ctx.bblEntryDetailSel or 1
        ctx.bblEntryDetailReturnState = "editor"
        ctx.state = "bbl_hotkey_entry"
      elseif o.optType == "boot_paths" then
        ctx.bootKey = o.key
        ctx.entryIdx = nil
        ctx.entryPathSel = ctx.entryPathSel or 1
        ctx.entryPathScroll = ctx.entryPathScroll or 0
        ctx.state = "entry_paths"
      elseif o.optType == "path" then
        ctx.editKey = o.key
        ctx.isAddPath = false
        ctx.addPathKey = nil
        local isBblLoadIrx = (ctx.fileType == "ps2bbl_ini" or ctx.fileType == "psxbbl_ini") and o.key and
            o.key:match("^LOAD_IRX_E%d+$")
        ctx.pathPickerContext = isBblLoadIrx and "path_only" or
            ((o.key == "path_DKWDRV_ELF") and "mc_only" or ((ctx.context == "mbr") and "mbr" or "osdmenu"))
        ctx.pathPickerSub = "device"
        ctx.pathList = _.file_selector.getDevices(ctx.pathPickerContext) or {}
        ctx.pathPickerSel = ctx.pathPickerSel or 1
        ctx.pathPickerScroll = ctx.pathPickerScroll or 0
        ctx.state = "path_picker"
      end
    end
    if (_.padEffective & _.PAD_TRIANGLE) ~= 0 and ctx.optList and #ctx.optList > 0 and
        (ctx.fileType == "osdmenu_cnf" or ctx.fileType == "freemcboot_cnf") then
      local o = ctx.optList[ctx.optSel]
      if o and o.key and o.key:sub(1, 1) ~= "_" and o.optType ~= "header" then
        local def = nil
        if ctx.fileType == "freemcboot_cnf" then
          def = _.config_options.getFreemcbootDefault and _.config_options.getFreemcbootDefault(o.key)
        else
          def = _.config_options.getOsdmenuDefault and _.config_options.getOsdmenuDefault(o.key)
        end
        if def ~= nil then
          _.config_parse.set(ctx.lines, o.key, def); ctx.configModified = true
        end
      end
    end
  else
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y + _.scaleY(60), _.FONT_SCALE, _.editor_str.no_option_list,
      _.GRAY)
    _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, _.editor_str.start_save_circle_back_items, nil,
      _.DIM, _.w - 2 * _.MARGIN_X)
  end

  if (_.padEffective & _.PAD_START) ~= 0 then
    ctx.saveSplash = nil
    local locations = _.getLocations(ctx.context, ctx.fileType, ctx.chosenMcSlot)
    if ctx.fileType == "osdmenu_cnf" and #locations >= 2 then
      ctx.saveChoices = locations
      ctx.saveSel = ctx.saveSel or 1
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
          ctx.saveSplash = {
            kind = "failed",
            detail = _.common.localizeParseError(err, _.editor_str) or
                _.editor_str.save_failed,
            framesLeft = 60
          }
        end
      else
        ctx.saveSplash = { kind = "failed", detail = _.editor_str.no_save_location, framesLeft = 60 }
      end
    end
  end
  if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
    if isCategorizedFile and ctx.editorCategoryIdx and ctx.editorCategoryIdx > 0 then
      setCategoryOptSel(ctx, ctx.editorCategoryIdx, ctx.optSel)
      local prevCategoryIdx = ctx.editorCategoryIdx
      ctx.editorCategoryIdx = 0
      ctx.optList = nil
      ctx.optSel = prevCategoryIdx
      ctx.saveSplash = nil
    else
      if ctx.configModified then
        ctx.editorLeavePrompt = true
      else
        ctx.state = getEditorBackState(ctx); ctx.currentPath = nil; ctx.lines = nil; ctx.optList = nil; ctx.editorCategoryIdx = 0; ctx.saveSplash = nil
      end
    end
  end
end

return { run = run }
