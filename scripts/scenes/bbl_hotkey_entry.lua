--[[ Per-slot editor for one BBL hotkey entry (path + args). ]]

local function getTextWidth(font, label)
  if not label or label == "" then return 0 end
  if font and Font and Font.ftCalcDimensions then
    local w = Font.ftCalcDimensions(font, label)
    if type(w) == "number" and w > 0 then
      return w
    end
  end
  return #label
end

local function findWidestHintLabel(_, itemsA, itemsB, pad, fallback)
  local labelA = _.common.findHintLabel(itemsA, pad, fallback)
  local labelB = _.common.findHintLabel(itemsB, pad, fallback)
  if getTextWidth(_.font, labelA) >= getTextWidth(_.font, labelB) then
    return labelA
  end
  return labelB
end

local function run(ctx)
  local _ = ctx._
  if not ctx.lines then
    ctx.state = "editor"
    return
  end
  local keyId = ctx.bblHotkeyKey
  local slot = tonumber(ctx.bblEntrySlot)
  local returnState = ctx.bblEntryDetailReturnState or "bbl_hotkey_entries"
  if not keyId or not slot then
    ctx.bblEntryDetailReturnState = nil
    ctx.state = returnState
    return
  end

  local maxArgs = _.config_parse.getBblMaxArgsPerEntry and _.config_parse.getBblMaxArgsPerEntry() or nil
  local isFmcb = (ctx.fileType == "freemcboot_cnf") or (ctx.context == "freehddboot")
  local maxEntries = isFmcb and ((_.config_options and _.config_options.FMCB_BBL_MAX_ENTRIES) or 3) or
      ((_.config_parse.getBblMaxEntries and _.config_parse.getBblMaxEntries()) or 10)
  local data = _.config_parse.getBblHotkeySlot(ctx.lines, keyId, slot)
  local keyDisabled = (_.config_parse.isBblHotkeyDisabled and _.config_parse.isBblHotkeyDisabled(ctx.lines, keyId)) and true or false
  local allowArgs = (ctx.fileType ~= "freemcboot_cnf") and (ctx.context ~= "freehddboot")
  local function isCdromLikePath(pathVal)
    local trimmed = (_.common and _.common.trimPathValue and _.common.trimPathValue(pathVal)) or
        tostring(pathVal or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local up = trimmed:upper()
    return trimmed:lower() == "cdrom" or up == "$CDVD" or up == "$CDVD_NO_PS2LOGO"
  end
  local hasCdromPath = data.pathExists and isCdromLikePath(data.path)
  local rows = allowArgs and { "path", hasCdromPath and "launch_disc_options" or "args" } or { "path" }
  ctx.bblEntryDetailSel = ctx.bblEntryDetailSel or 1
  if ctx.bblEntryDetailSel < 1 then ctx.bblEntryDetailSel = 1 end
  if ctx.bblEntryDetailSel > #rows then ctx.bblEntryDetailSel = #rows end

  _.common.drawHotkeyTitle(_, keyId, " - E" .. tostring(slot))

  local pathDisp = _.common_str.not_set
  if data.path ~= "" then
    pathDisp = _.common.formatDisplayPathWithCommands(_, data.path)
  elseif data.pathExists then
    pathDisp = _.common_str.empty
  end
  local pathLine = "Path: " .. pathDisp
  local argsLine = (type(maxArgs) == "number" and maxArgs > 0)
      and ("Arguments: " .. tostring(data.argCount) .. "/" .. tostring(maxArgs))
      or ("Arguments: " .. tostring(data.argCount))
  local launchDiscLine = (_.menu_str.launch_disc_options or "Launch disc options") ..
      ((tonumber(data.argCount) or 0) > 0 and (" (" .. tostring(data.argCount) .. ")") or "")
  local maxLabelW = (_.w or 640) - (_.MARGIN_X + 24) - _.MARGIN_X

  for i = 1, #rows do
    local y = _.MARGIN_Y + _.scaleY(50) + (i - 1) * _.LINE_H
    local col = (i == ctx.bblEntryDetailSel) and _.SELECTED_COLOR or _.UNSELECTED_COLOR
    local line = pathLine
    if rows[i] == "args" then
      line = argsLine
    elseif rows[i] == "launch_disc_options" then
      line = launchDiscLine
    end
    if _.common.fitListRowText then
      local key = (rows[i] == "path") and "bbl_hotkey_entry_path" or "bbl_hotkey_entry_args"
      line = _.common.fitListRowText(ctx, key, _.font, line, maxLabelW, _.FONT_SCALE, i == ctx.bblEntryDetailSel)
    elseif _.common.truncateTextToWidth then
      line = _.common.truncateTextToWidth(_.font, line, maxLabelW, _.FONT_SCALE)
    end
    if rows[i] == "path" and (data.disabled or keyDisabled) then
      col = (i == ctx.bblEntryDetailSel) and (_.SELECTED_DIM_COLOR or _.SELECTED_COLOR) or (_.DISABLED_DIM_COLOR or _.DIM_COLOR)
    end
    _.drawListRow(_.MARGIN_X + 20, y, i == ctx.bblEntryDetailSel, line, col)
  end

  local hint
  local function cloneBblArgs(args)
    local out = {}
    for i = 1, #(args or {}) do
      local a = args[i]
      if type(a) == "table" then
        out[#out + 1] = {
          value = a.value or "",
          disabled = a.disabled and true or false
        }
      else
        out[#out + 1] = {
          value = tostring(a or ""),
          disabled = false
        }
      end
    end
    return out
  end

  local function slotHasPresence(slotData)
    if not slotData then return false end
    if slotData.pathExists then return true end
    if slotData.used then return true end
    local argCount = tonumber(slotData.argCount) or 0
    return argCount > 0
  end

  local function canRemoveCurrentSlot()
    local getSlot = _.config_parse.getBblHotkeySlot
    if not getSlot then return false end
    local current = getSlot(ctx.lines, keyId, slot)
    if slotHasPresence(current) then return true end
    for i = slot + 1, maxEntries do
      local s = getSlot(ctx.lines, keyId, i)
      if slotHasPresence(s) then
        return true
      end
    end
    return false
  end

  local function removeCurrentSlotCompact()
    if not canRemoveCurrentSlot() then return false end
    local getSlot = _.config_parse.getBblHotkeySlot
    local packed = {}
    for i = 1, maxEntries do
      if i ~= slot then
        local s = getSlot and getSlot(ctx.lines, keyId, i) or nil
        if s and s.used then
          packed[#packed + 1] = {
            pathExists = s.pathExists and true or false,
            path = s.path or "",
            disabled = s.disabled and true or false,
            args = cloneBblArgs(s.args),
          }
        end
      end
    end
    for i = 1, maxEntries do
      local row = packed[i]
      if row then
        _.config_parse.setBblHotkeyPath(ctx.lines, keyId, i, row.pathExists and row.path or nil, row.disabled)
        _.config_parse.setBblHotkeyArgs(ctx.lines, keyId, i, row.args)
      else
        _.config_parse.setBblHotkeyPath(ctx.lines, keyId, i, nil, false)
        _.config_parse.setBblHotkeyArgs(ctx.lines, keyId, i, {})
      end
    end
    return true
  end

  local canRemoveSlot = canRemoveCurrentSlot()

  if rows[ctx.bblEntryDetailSel] == "path" then
    local enableHint = _.menu_str.paths_hint_items_with_enable or _.menu_str.paths_hint_items
    local disableHint = _.menu_str.paths_hint_items_with_disable or _.menu_str.paths_hint_items
    local effectivePathDisabled = (keyDisabled or data.disabled) and true or false
    local baseHint = effectivePathDisabled and enableHint or disableHint
    local canTogglePathDisabled = true
    local toggleLayoutLabel = findWidestHintLabel(_, enableHint, disableHint, "triangle",
      effectivePathDisabled and (_.menu_str.enable_label or "Enable") or (_.menu_str.disable_label or "Disable"))
    hint = {
      { pad = "cross", label = _.common.findHintLabel(baseHint, "cross", (_.menu_str.edit_label or "Edit")), row = 1 },
      {
        pad = canTogglePathDisabled and "triangle" or "",
        label = canTogglePathDisabled and
            _.common.findHintLabel(baseHint, "triangle",
              effectivePathDisabled and (_.menu_str.enable_label or "Enable") or (_.menu_str.disable_label or "Disable")) or "",
        layoutLabel = toggleLayoutLabel,
        row = 1
      },
      {
        pad = canRemoveSlot and "square" or "",
        label = canRemoveSlot and _.common.findHintLabel(baseHint, "square", (_.menu_str.remove_label or "Remove")) or "",
        row = 1
      },
      {
        pad = ctx.configModified and "start" or "",
        label = ctx.configModified and (_.menu_str.save_config_label or "Save") or "",
        row = 1
      },
      { pad = "circle", label = _.common.findHintLabel(baseHint, "circle", (_.menu_str.back_label or "Back")), row = 1 },
    }
  else
    hint = {
      { pad = "cross", label = (_.menu_str.enter_label or "Enter"), row = 1 },
      {
        pad = ctx.configModified and "start" or "",
        label = ctx.configModified and (_.menu_str.save_config_label or "Save") or "",
        row = 1
      },
      { pad = "circle", label = (_.menu_str.back_label or "Back"), row = 1 },
    }
  end
  _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, hint, nil, _.DIM_COLOR, _.w - 2 * _.MARGIN_X)

  if (_.padEffective & _.PAD_UP) ~= 0 then
    ctx.bblEntryDetailSel = _.common.moveListSelection(ctx.bblEntryDetailSel, #rows, -1, { ctx = ctx })
  end
  if (_.padEffective & _.PAD_DOWN) ~= 0 then
    ctx.bblEntryDetailSel = _.common.moveListSelection(ctx.bblEntryDetailSel, #rows, 1, { ctx = ctx })
  end

  if (_.padEffective & _.PAD_CROSS) ~= 0 then
    if rows[ctx.bblEntryDetailSel] == "path" then
      -- Reuse path picker so BBL slot paths support both manual input and device browse.
      ctx.editKey = nil
      ctx.pathPickerTarget = nil
      ctx.pathPickerFileExts = nil
      ctx.pathPickerContext = "path_only"
      ctx.pathPickerSub = "device"
      ctx.pathList = _.file_selector.getDevices("path_only", { fileType = ctx.fileType }) or {}
      ctx.pathPickerSel = 1
      ctx.pathPickerScroll = 0
      ctx.pathBrowsePath = nil
      ctx.pathPickerBootKey = nil
      ctx.pathPickerBootKeyDisabled = nil
      ctx.pathPickerForEntryIdx = nil
      ctx.pathPickerEditIdx = nil
      ctx.pathPickerBblIrxIdx = nil
      ctx.pathPickerBblIrxDisabled = nil
      ctx.isAddPath = false
      ctx.addPathKey = nil
      ctx.pathPickerReturnState = "bbl_hotkey_entry"
      ctx.pathPickerBblHotkeyKey = keyId
      ctx.pathPickerBblHotkeySlot = slot
      ctx.pathPickerBblHotkeyDisabled = data.disabled and true or false
      ctx.state = "path_picker"
    elseif allowArgs then
      local selectedRow = rows[ctx.bblEntryDetailSel]
      if selectedRow == "launch_disc_options" then
        ctx.cdromOptSel = 1
        ctx.state = "entry_cdrom_options"
      else
        if (tonumber(data.argCount) or 0) <= 0 then
          ctx.bblArgAddMenu = true
          ctx.bblArgAddSel = 1
          ctx.bblArgAddScroll = 0
        end
        ctx.bblArgSel = 1
        ctx.bblArgScroll = 0
        ctx.state = "bbl_hotkey_args"
      end
    end
  end

  local function toggleSelectedPathDisabled()
    if rows[ctx.bblEntryDetailSel] == "path" then
      local changed = false
      local effectivePathDisabled = (keyDisabled or data.disabled) and true or false
      if keyDisabled and effectivePathDisabled and _.config_parse.enableBblHotkeySlotFromDisabledParent then
        changed = _.config_parse.enableBblHotkeySlotFromDisabledParent(ctx.lines, keyId, slot) and true or false
      else
        changed = _.config_parse.setBblHotkeySlotDisabled and
            _.config_parse.setBblHotkeySlotDisabled(ctx.lines, keyId, slot, not data.disabled) or false
      end
      if changed then
        ctx._configModifiedCache = nil
        ctx.configModified = true
      end
    end
  end

  if (_.padEffective & _.PAD_TRIANGLE) ~= 0 then
    toggleSelectedPathDisabled()
  end
  if rows[ctx.bblEntryDetailSel] == "path" and canRemoveSlot and (_.padEffective & _.PAD_SQUARE) ~= 0 then
    local removed = removeCurrentSlotCompact()
    if removed then
      ctx._configModifiedCache = nil
      ctx.configModified = true
      ctx.bblEntryFocusSlot = math.max(1, math.min(slot, maxEntries))
    end
    ctx.bblEntryDetailReturnState = nil
    ctx.state = returnState
  end
  if ctx.configModified and (_.padEffective & _.PAD_START) ~= 0 then
    _.common.saveCurrentConfig(ctx)
  end

  if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
    ctx.bblEntryDetailReturnState = nil
    ctx.state = returnState
  end
end

return { run = run }
