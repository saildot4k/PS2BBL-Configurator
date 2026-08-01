--[[ On-screen keyboard text input. ]]

local actions_menu = dofile("scripts/scenes/actions_menu.lua")

local KEYBOARD_HINT_ICON_SHRINK_TOTAL = 1.0 -- total px shrink
local KEYBOARD_HINT_ICON_DARKEN_MAX = 0.24

local function buildKeyboardShoulderHints(hintItems)
  local out = {}
  for i = 1, #(hintItems or {}) do
    local item = hintItems[i]
    local pad = tostring(item and item.pad or ""):lower()
    if pad == "l1" or pad == "r1" or pad == "l2" or pad == "r2" or pad == "select" then
      out[pad] = tostring(item and item.label or "")
    end
  end
  return out
end

local function drawKeyboardShoulderHints(ctx, _, hintItems, scale, totalWidth, color)
  local labels = buildKeyboardShoulderHints(hintItems)
  local runtime = _G and _G.CONFIG_UI
  local suppressPressVisuals = math.max(0, math.floor(tonumber(ctx and ctx.textInputSuppressPressVisualFrames) or 0)) > 0

  local function clamp01(v)
    local n = tonumber(v) or 0
    if n < 0 then return 0 end
    if n > 1 then return 1 end
    return n
  end

  local function applyAlpha(colorValue, alpha)
    local c = math.floor(tonumber(colorValue) or 0)
    local a = (c >> 24) & 0xFF
    local scaled = math.floor(a * clamp01(alpha) + 0.5)
    if scaled < 0 then scaled = 0 end
    if scaled > 0x80 then scaled = 0x80 end
    return (c & 0x00FFFFFF) | ((scaled & 0xFF) << 24)
  end
  local function makeIconColor(alpha)
    local a = math.floor(0x80 * clamp01(alpha) + 0.5)
    if a < 0 then a = 0 end
    if a > 0x80 then a = 0x80 end
    -- Texture draw APIs use 0x80808080 as neutral modulation.
    return Color.new(0x80, 0x80, 0x80, a)
  end

  local function cloneSlots(src)
    local out = {}
    for i = 1, #(src or {}) do
      local s = src[i] or {}
      out[i] = {
        pad = tostring(s.pad or ""),
        col = tonumber(s.col),
        label = tostring(s.label or ""),
        used = (s.used == true),
      }
    end
    return out
  end

  local function normalizeLabelForCompare(s)
    return tostring(s or ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  end

  local function slotsEqual(a, b)
    if #(a or {}) ~= #(b or {}) then return false end
    for i = 1, #(a or {}) do
      local sa = a[i] or {}
      local sb = b[i] or {}
      if tostring(sa.pad or "") ~= tostring(sb.pad or "") then return false end
      if normalizeLabelForCompare(sa.label) ~= normalizeLabelForCompare(sb.label) then return false end
      if (sa.used == true) ~= (sb.used == true) then return false end
    end
    return true
  end

  local function drawHintsUntransformed(drawFn)
    if _.common.drawWithoutSceneTransform then
      return _.common.drawWithoutSceneTransform(drawFn)
    end
    return drawFn()
  end
  local function clearShoulderHintRowForCrossDissolve(topY, height)
    if type(runtime) ~= "table" then return end
    if runtime.sceneTransitionAnimActive ~= true then return end
    if tostring(runtime.sceneTransitionAnimType or "") ~= "cross_dissolve" then return end
    if not (_.Graphics and _.Graphics.drawRect) then return end
    local rw = math.max(1, math.floor(tonumber(runtime.currentSceneWidth) or (_.w or _.common.DEFAULT_W)))
    local ry = math.floor((tonumber(topY) or 0) - 1)
    local rh = math.max(0, math.floor((tonumber(height) or 0) + 2))
    if rh <= 0 then return end
    _.Graphics.drawRect(0, ry, rw, rh, _.common.BACKGROUND_COLOR)
  end

  local drawColor = color or _.DIM_COLOR or _.UNSELECTED_COLOR or _.WHITE
  local iconScale = tonumber((_.common and _.common.PAD_HINT_ICON_SCALE) or 0.54) or 0.54
  local baseScale = tonumber(scale) or tonumber((_.common and _.common.PAD_HINT_BASE_SCALE) or 0.7)
  local hintTypography = _.common.getHintTypography(_.font, _.drawMode, {
    baseScale = baseScale,
  })
  local textScale = hintTypography.textScale
  local drawScale = hintTypography.drawScale
  local hintFont = hintTypography.font
  local iconW = math.max(10, math.floor((_.common.PAD_ICON_W or 26) * iconScale + 0.5))
  local iconH = math.max(10, math.floor((_.common.PAD_ICON_H or 26) * iconScale + 0.5))
  local gap = math.max(2, math.floor((_.common.PAD_HINT_GAP or 5) * textScale + 0.5))
  local rowH = math.max(14, math.floor((_.common.PAD_HINT_ROW_H or 28) * textScale + 0.5))
  local textH = hintTypography.textHeight
  local baseWidth = (type(totalWidth) == "number" and totalWidth > 0) and totalWidth or _.common.PAD_HINT_DEFAULT_WIDTH
  baseWidth = baseWidth + (tonumber(_.common.PAD_HINT_GRID_EXTRA_W) or 0)
  -- Keep keyboard shoulder-row slot centers locked to the same static grid
  -- used by the bottom helper row so:
  -- L1/Select/R1 align with Square/Start/Triangle.
  local autoExtraW = 0
  local sideMargin = _.common.PAD_HINT_SIDE_MARGIN or 0
  local xEff = (_.MARGIN_X or 0) + sideMargin + (tonumber(_.common.PAD_HINT_GRID_X_SHIFT) or 0)
  local sceneW = (type(runtime) == "table" and tonumber(runtime.currentSceneWidth)) or (_.w or _.common.DEFAULT_W)
  local rightOverscan = math.max(0, math.floor(tonumber(_.common.PAD_HINT_GRID_RIGHT_OVERSCAN) or 8))
  local maxWidthEffByScreen = math.max(1, math.floor((sceneW - rightOverscan) - xEff))
  local baseWidthEff = math.max(1, baseWidth - (2 * sideMargin))
  local maxAutoExtraByScreen = math.max(0, maxWidthEffByScreen - baseWidthEff)
  if autoExtraW > maxAutoExtraByScreen then
    autoExtraW = maxAutoExtraByScreen
  end
  local width = baseWidth + autoExtraW
  local widthEff = width - (2 * sideMargin)
  local slotW = widthEff / 5
  if _.common.PAD_HINT_ALIGN_CROSS_TO_X ~= false then
    local desiredXEff = (_.MARGIN_X or 0) + (iconW * 0.5) - (slotW * 0.5)
    local maxXEff = (sceneW - rightOverscan) - widthEff
    if desiredXEff > maxXEff then desiredXEff = maxXEff end
    xEff = desiredXEff
  end
  local bottomRowTop = math.floor(_.HINT_Y) - rowH
  local topRowTop = bottomRowTop - rowH
  local hintKey = "__keyboard_shoulder_hint_row__"

  local columns = {
    { pad = "l1", col = 2 },
    { pad = "select", col = 3 },
    { pad = "r1", col = 4 },
  }
  local columnByPad = {}
  for i = 1, #columns do
    local c = columns[i]
    columnByPad[tostring(c.pad or "")] = tonumber(c.col) or i
  end

  local rowSlots = {}
  for i = 1, #columns do
    local c = columns[i]
    local label = tostring(labels[c.pad] or "")
    rowSlots[i] = {
      pad = c.pad,
      col = c.col,
      label = label,
      used = (label ~= ""),
    }
  end

  local function getTextWidth(label)
    if not label or label == "" then return 0 end
    if _.common.calcTextWidth then
      local w = _.common.calcTextWidth(hintFont, label, drawScale)
      if type(w) == "number" and w > 0 then
        return w
      end
    end
    if _.drawMode == "ftPrint" and hintFont and _.Font and _.Font.ftCalcDimensions then
      local w = _.Font.ftCalcDimensions(hintFont, label)
      if type(w) == "number" and w > 0 then
        return w
      end
    end
    return math.floor(8 * drawScale * #label)
  end

  local function drawSlot(slot, iconAlpha, labelAlpha, labelOverride)
    if not slot then return end
    local label = (labelOverride ~= nil) and tostring(labelOverride or "") or tostring(slot.label or "")
    local drawIconAlpha = clamp01(iconAlpha or 0)
    local drawLabelAlpha = clamp01(labelAlpha or 0)
    if drawIconAlpha <= 0.001 and (drawLabelAlpha <= 0.001 or label == "") then
      return
    end
    local icon = _.common.getPadIcon(slot.pad)
    local slotCol = tonumber(slot.col) or columnByPad[tostring(slot.pad or "")] or 1
    local slotCenter = xEff + (slotCol - 1) * slotW + (slotW / 2)
    local rowCenter = topRowTop + (rowH / 2)
    local textYOffset = math.floor(tonumber(_.common and _.common.PAD_HINT_TEXT_Y_OFFSET) or -5)
    local textY = math.floor(topRowTop + (rowH - textH) / 2) + textYOffset
    local basePx = math.floor(slotCenter - iconW / 2)
    local baseIconY = math.floor(rowCenter - iconH / 2)
    local pressAmount = 0
    if not suppressPressVisuals then
      pressAmount = (_.common and _.common.getHintPadPressAmount and _.common.getHintPadPressAmount(slot.pad)) or 0
    end
    local shrinkTotal = KEYBOARD_HINT_ICON_SHRINK_TOTAL * pressAmount
    local inset = math.max(0, shrinkTotal * 0.5)
    local drawIconW = math.max(1, iconW - shrinkTotal)
    local drawIconH = math.max(1, iconH - shrinkTotal)
    local px = basePx + inset
    local iconY = baseIconY + inset
    if icon and drawIconAlpha > 0.001 then
      local pressDarken = (pressAmount > 0.0001) and (KEYBOARD_HINT_ICON_DARKEN_MAX * pressAmount) or 0
      local dimmedAlpha = drawIconAlpha * (1 - clamp01(pressDarken))
      local iconColor = makeIconColor(dimmedAlpha)
      if _.Graphics.drawScaleImage then
        local ok = pcall(_.Graphics.drawScaleImage, icon, px, iconY, drawIconW, drawIconH, iconColor)
        if not ok then
          _.Graphics.drawScaleImage(icon, px, iconY, drawIconW, drawIconH)
        end
      elseif _.Graphics.drawImage then
        local ok = pcall(_.Graphics.drawImage, icon, px, iconY, iconColor)
        if not ok then
          _.Graphics.drawImage(icon, px, iconY)
        end
      end
    end
    if drawLabelAlpha > 0.001 and label ~= "" then
      local textColor = applyAlpha(drawColor, drawLabelAlpha)
      if icon then
        _.common.drawText(hintFont, _.drawMode, basePx + iconW + gap, textY, drawScale, label, textColor, textH)
      else
        local textW = getTextWidth(label)
        local textX = math.floor(slotCenter - (textW / 2))
        _.common.drawText(hintFont, _.drawMode, textX, textY, drawScale, label, textColor, textH)
      end
    end
  end

  local function drawRow(slots)
    for i = 1, #(slots or {}) do
      local slot = slots[i]
      drawSlot(slot, (slot and slot.used) and 1 or 0, (slot and slot.used) and 1 or 0)
    end
  end

  local function drawBlendedRows(fromSlots, toSlots, progress)
    local p = clamp01(progress)
    local fullOut = 1 - p
    local fullIn = p
    local function splitFadeAlpha(t)
      local q = clamp01(t)
      if q < 0.5 then
        return 1 - (q * 2), 0
      end
      return 0, (q - 0.5) * 2
    end
    local outAlpha, inAlpha = splitFadeAlpha(p)
    local count = math.max(#(fromSlots or {}), #(toSlots or {}))
    for i = 1, count do
      local fallbackCol = (columns[i] and columns[i].col) or i
      local fromSlot = (fromSlots and fromSlots[i]) or { pad = columns[i] and columns[i].pad or "", col = fallbackCol, label = "", used = false }
      local toSlot = (toSlots and toSlots[i]) or { pad = columns[i] and columns[i].pad or "", col = fallbackCol, label = "", used = false }
      local samePad = tostring(fromSlot.pad or "") == tostring(toSlot.pad or "")
      local sameUsed = (fromSlot.used == true) == (toSlot.used == true)
      local sameLabel = normalizeLabelForCompare(fromSlot.label) == normalizeLabelForCompare(toSlot.label)
      local fromIcon = (fromSlot.used == true) and 1 or 0
      local toIcon = (toSlot.used == true) and 1 or 0
      local fromLabel = tostring(fromSlot.label or "")
      local toLabel = tostring(toSlot.label or "")
      if samePad and sameUsed and sameLabel then
        drawSlot(toSlot, toIcon, (toSlot.used and toLabel ~= "") and 1 or 0)
      else
        local blendedIcon = (fromIcon * fullOut) + (toIcon * fullIn)
        if samePad and sameUsed and fromSlot.used == true and toSlot.used == true and not sameLabel then
          -- Keep one label per button during transitions.
          drawSlot(toSlot, blendedIcon, (toLabel ~= "") and 1 or 0)
        else
          drawSlot(toSlot, blendedIcon, (toSlot.used and toLabel ~= "") and fullIn or 0)
          if fromSlot.used and fromLabel ~= "" then
            drawSlot(fromSlot, 0, fullOut)
          end
        end
      end
    end
  end

  drawHintsUntransformed(function()
    clearShoulderHintRowForCrossDissolve(topRowTop, rowH)
    local transitionInfo = (_.common.getHintRowTransitionInfo and _.common.getHintRowTransitionInfo(runtime)) or nil
    local useAnimatedTransition = (type(runtime) == "table") and transitionInfo and transitionInfo.active == true and
        transitionInfo.instant ~= true
    if not useAnimatedTransition then
      if type(runtime) == "table" then
        if type(runtime.keyboardShoulderStableSlots) ~= "table" then
          runtime.keyboardShoulderStableSlots = {}
        end
        local stableSlots = runtime.keyboardShoulderStableSlots[hintKey]
        if type(stableSlots) ~= "table" or not slotsEqual(stableSlots, rowSlots) then
          runtime.keyboardShoulderStableSlots[hintKey] = cloneSlots(rowSlots)
        end
        if type(runtime.keyboardShoulderFadeStates) == "table" then
          runtime.keyboardShoulderFadeStates[hintKey] = nil
        end
      end
      drawRow(rowSlots)
    else
      local handled = _.common.drawHintSlotsWithTransition and _.common.drawHintSlotsWithTransition(runtime, {
        hintKey = hintKey,
        stableField = "keyboardShoulderStableSlots",
        fadeField = "keyboardShoulderFadeStates",
        rowSlots = rowSlots,
        cloneSlots = cloneSlots,
        slotsEqual = slotsEqual,
        drawRow = drawRow,
        drawBlendedRows = drawBlendedRows,
      })
      if not handled then
        drawRow(rowSlots)
      end
    end
  end)
end

local BEL = string.char(7)
local GLYPH_KEY_LABEL_FALLBACK = "Glyphs"
local BEL_PAGE_COUNT = 3

local BEL_COLOR_TOKENS = {
  { code = "c0", desc = "White" },
  { code = "c1", desc = "Yellow" },
  { code = "c2", desc = "Blue" },
  { code = "c3", desc = "Pink" },
  { code = "c4", desc = "Gray" },
  { code = "c5", desc = "Cyan" },
  { code = "c6", desc = "Red" },
  { code = "c7", desc = "Grey" },
  { code = "c8", desc = "Light Grey" },
  { code = "c9", desc = "Green" },
}

local BEL_SYMBOLS_PS2_ROM = {
  { code = "o000", desc = "Down Shafted Arrow", preview = "↓|" },
  { code = "o001", desc = "Right Shafted Arrow", preview = "→|" },
  { code = "o002", desc = "Left Arrow", preview = "←" },
  { code = "o003", desc = "Right Arrow", preview = "→" },
  { code = "o004", desc = "Registered Trademark", preview = "®" },
  { code = "o005", desc = "Registered Trademark (small)", preview = "®" },
  { code = "o006", desc = "Up Arrow", preview = "↑" },
  { code = "o007", desc = "Down Arrow", preview = "↓" },
  { code = "o008", desc = "Left Arrow", preview = "←" },
  { code = "o009", desc = "Right Arrow", preview = "→" },
  { code = "o010", desc = "Up Button", preview = "[↑]" },
  { code = "o011", desc = "Down Button", preview = "[↓]" },
  { code = "o012", desc = "Left Button", preview = "[←]" },
  { code = "o013", desc = "Right Button", preview = "[→]" },
  { code = "o014", desc = "Repeat", preview = "↻" },
  { code = "o015", desc = "Up/Down Arrows (small)", preview = "↕" },
  { code = "o016", desc = "PS2", preview = "PS2" },
  { code = "o017", desc = "PS2 cutoff", preview = "S2" },
  { code = "o018", desc = "Stop", preview = "■" },
  { code = "o019", desc = "Daylight Savings", preview = "☀" },
  { code = "o020", desc = "Up/Down Arrows (bigger)", preview = "↕" },
}

local BEL_SYMBOLS_HDDOSD = {
  { code = "o000", desc = "Double-chevron opening quote" },
  { code = "o001", desc = "Double-chevron closing quote" },
  { code = "o002", desc = "Bar" },
  { code = "o003", desc = "Bar" },
  { code = "o004", desc = "Right Shafted Arrow" },
  { code = "o005", desc = "Left Arrow" },
  { code = "o006", desc = "Right Arrow" },
  { code = "o007", desc = "Registered Trademark" },
  { code = "o008", desc = "Registered Trademark (small)" },
  { code = "o009", desc = "Up Arrow" },
  { code = "o010", desc = "Left Arrow" },
  { code = "o011", desc = "Down Arrow" },
  { code = "o012", desc = "Right Arrow" },
  { code = "o013", desc = "Up Button" },
  { code = "o014", desc = "Down Button" },
  { code = "o015", desc = "Left Button" },
  { code = "o016", desc = "Right Button" },
  { code = "o017", desc = "Repeat Icon" },
  { code = "o018", desc = "Up/Down Arrows" },
  { code = "o019", desc = "Stop Icon" },
  { code = "o020", desc = "Daylight Savings(?)" },
  { code = "o021", desc = "Up/Down Arrows (again?)" },
  { code = "o022", desc = "Up/Down Arrows (small)" },
  { code = "o023", desc = "Warning Icon" },
}

local BEL_TUNABLE_TOKENS = {
  { code = "r#.##", insert = "r", preview = "□r", desc = "Font scale (0.50-1.50, reset r0.00)" },
  { code = "y+##", insert = "y+", preview = "□y+", desc = "Y offset down (range unknown)" },
  { code = "y-##", insert = "y-", preview = "□y-", desc = "Y offset up (range unknown)" },
  { code = "p##", insert = "p", preview = "□p", desc = "Letter spacing (reset p00)" },
  { code = "a###", insert = "a", preview = "□a", desc = "Transparency (000-128?)" },
  { code = "w#", insert = "w", preview = "□w", desc = "Horizontal scale (0-9, reset w1)" },
}

local function countBelChars(s)
  local _, n = tostring(s or ""):gsub(BEL, "")
  return n or 0
end

local function clampBelCharsToBaseline(currentValue, baselineValue)
  local keepBel = countBelChars(baselineValue)
  local out = {}
  local kept = 0
  local s = tostring(currentValue or "")
  for i = 1, #s do
    local ch = s:sub(i, i)
    if ch == BEL then
      if kept < keepBel then
        kept = kept + 1
        out[#out + 1] = ch
      end
    else
      out[#out + 1] = ch
    end
  end
  return table.concat(out)
end

local function belProfileFromContext(ctx)
  local profile = tostring(ctx and ctx.textInputBelProfile or ""):lower()
  if profile == "hddosd" then return "hddosd" end
  if profile == "ps2rom" then return "ps2rom" end
  return "ps2rom"
end

local function clampBelPage(page)
  local p = tonumber(page) or 1
  p = math.floor(p)
  if p < 1 then p = 1 end
  if p > BEL_PAGE_COUNT then p = BEL_PAGE_COUNT end
  return p
end

local function glyphText(textInputStrings, key, fallback)
  local glyphs = (type(textInputStrings) == "table" and type(textInputStrings.glyphs) == "table") and textInputStrings.glyphs or nil
  local value = glyphs and glyphs[key]
  if type(value) == "string" and value ~= "" then
    return value
  end
  return fallback
end

local function glyphDesc(textInputStrings, tableKey, code, fallback)
  local glyphs = (type(textInputStrings) == "table" and type(textInputStrings.glyphs) == "table") and textInputStrings.glyphs or nil
  local map = glyphs and glyphs[tableKey]
  local value = (type(map) == "table") and map[code] or nil
  if type(value) == "string" and value ~= "" then
    return value
  end
  return fallback
end

local function buildBelTokenRows(profile, page, textInputStrings)
  page = clampBelPage(page)
  local out = {}
  local symHeader = (profile == "hddosd")
      and glyphText(textInputStrings, "header_symbols_hddosd", "Symbols (HDDOSD Browser 2.00)")
      or glyphText(textInputStrings, "header_symbols_ps2rom", "Symbols (PS2 ROM OSD)")
  local symRows = (profile == "hddosd") and BEL_SYMBOLS_HDDOSD or BEL_SYMBOLS_PS2_ROM
  local symDescTableKey = (profile == "hddosd") and "desc_symbols_hddosd" or "desc_symbols_ps2rom"

  if page == 1 then
    out[#out + 1] = {
      id = "header_manual",
      label = glyphText(textInputStrings, "header_manual", "Manual"),
      enabled = false
    }
    out[#out + 1] = {
      id = "token_manual_bel",
      label = "BEL  □  " .. glyphText(textInputStrings, "manual_insert_bel", "Insert BEL..."),
      columns = { "BEL", "□", glyphText(textInputStrings, "manual_insert_bel", "Insert BEL...") },
      token = BEL,
    }
    out[#out + 1] = {
      id = "header_colors",
      label = glyphText(textInputStrings, "header_colors", "Colors"),
      enabled = false
    }
    for i = 1, #BEL_COLOR_TOKENS do
      local t = BEL_COLOR_TOKENS[i]
      local token = BEL .. tostring(t.code)
      local desc = glyphDesc(textInputStrings, "desc_colors", tostring(t.code), tostring(t.desc or ""))
      out[#out + 1] = {
        id = "token_" .. tostring(t.code),
        label = tostring(t.code) .. "  " .. desc,
        columns = { tostring(t.code), "", desc },
        token = token,
      }
    end
    out[#out + 1] = {
      id = "footer_colors_sample",
      label = glyphText(textInputStrings, "footer_colors_sample", "c#/c## Many undocumented. The above is a small sample."),
      enabled = false,
      forceTicker = true,
    }
  elseif page == 2 then
    out[#out + 1] = { id = "header_symbols", label = symHeader, enabled = false }
    for i = 1, #symRows do
      local t = symRows[i]
      local token = BEL .. tostring(t.code)
      local preview = tostring(t.preview or "")
      local desc = glyphDesc(textInputStrings, symDescTableKey, tostring(t.code), tostring(t.desc or ""))
      out[#out + 1] = {
        id = "token_" .. tostring(t.code),
        label = tostring(t.code) ..
            ((preview ~= "") and ("  " .. preview) or "") ..
            "  " .. desc,
        columns = { tostring(t.code), preview, desc },
        token = token,
      }
    end
    out[#out + 1] = {
      id = "footer_symbols_sample",
      label = glyphText(textInputStrings, "footer_symbols_sample", "o000-o999 exist. The above is a small sample."),
      enabled = false,
      forceTicker = true,
    }
  else
    out[#out + 1] = {
      id = "header_tunables",
      label = glyphText(textInputStrings, "header_tunables", "Tunables"),
      enabled = false
    }
    for i = 1, #BEL_TUNABLE_TOKENS do
      local t = BEL_TUNABLE_TOKENS[i]
      local token = BEL .. tostring(t.insert or "")
      local preview = tostring(t.preview or "")
      local desc = glyphDesc(textInputStrings, "desc_tunables", tostring(t.code or ""), tostring(t.desc or ""))
      out[#out + 1] = {
        id = "token_tunable_" .. tostring(i),
        label = tostring(t.code or "") ..
            ((preview ~= "") and ("  " .. preview) or "") ..
            "  " .. desc,
        columns = { tostring(t.code or ""), preview, desc },
        token = token,
      }
    end
  end
  return out
end

local function rowColumnCount(columns)
  if type(columns) ~= "table" then return 0 end
  local n = #columns
  while n > 0 and tostring(columns[n] or "") == "" do
    n = n - 1
  end
  return n
end

local function ensureBelRowsByPage(ctx, profile, textInputStrings)
  if type(ctx.textInputBelRowsByPage) ~= "table" or ctx.textInputBelRowsProfile ~= profile or
      ctx.textInputBelRowsText ~= textInputStrings then
    local rowsByPage = {}
    for p = 1, BEL_PAGE_COUNT do
      rowsByPage[p] = buildBelTokenRows(profile, p, textInputStrings)
    end
    ctx.textInputBelRowsByPage = rowsByPage
    ctx.textInputBelRowsProfile = profile
    ctx.textInputBelRowsText = textInputStrings
  end
  return ctx.textInputBelRowsByPage
end

local function buildBelMenuLayoutMetrics(_, rowsByPage)
  local hintTypography = _.common.getHintTypography(_.font, _.drawMode)
  local rowScale = hintTypography.drawScale
  local hintFont = hintTypography.font
  local function textWidth(text)
    local s = tostring(text or "")
    if _.common and _.common.calcTextWidth then
      return _.common.calcTextWidth(hintFont, s, rowScale)
    end
    return math.floor((8 * rowScale) * #s)
  end
  local spaceW = textWidth(" ")
  if spaceW < 1 then
    local probeW = textWidth("M")
    if probeW < 1 then probeW = math.floor((8 * rowScale) + 0.5) end
    spaceW = math.max(2, math.floor((probeW * 0.32) + 0.5))
  end
  local columnGap = math.max(4, math.floor((spaceW * 2) + 0.5))
  local columnMinWidths = {}

  for p = 1, BEL_PAGE_COUNT do
    local rows = (type(rowsByPage) == "table" and rowsByPage[p]) or {}
    for i = 1, #rows do
      local cols = rows[i] and rows[i].columns
      local count = rowColumnCount(cols)
      for c = 1, count do
        local w = textWidth(tostring(cols[c] or ""))
        if w > (columnMinWidths[c] or 0) then
          columnMinWidths[c] = w
        end
      end
    end
  end

  local function rowIntrinsicWidth(row)
    local cols = row and row.columns
    local count = rowColumnCount(cols)
    if count <= 0 then
      return textWidth(row and row.label or "")
    end
    local total = 0
    for c = 1, count do
      total = total + (columnMinWidths[c] or 0)
      if c < count then total = total + columnGap end
    end
    return total
  end

  local maxIntrinsicW = 0
  for p = 1, BEL_PAGE_COUNT do
    local rows = (type(rowsByPage) == "table" and rowsByPage[p]) or {}
    for i = 1, #rows do
      local w = rowIntrinsicWidth(rows[i])
      if w > maxIntrinsicW then maxIntrinsicW = w end
    end
  end

  return columnMinWidths, maxIntrinsicW
end

local function getRawPadNow(ctx)
  local raw = tonumber(ctx and ctx._rawPadNow)
  if type(raw) == "number" then
    return raw
  end
  if Pads and Pads.get then
    local ok, v = pcall(Pads.get, 0)
    if ok and type(v) == "number" then
      return v
    end
  end
  return 0
end

local function getNominalFps(ctx, _)
  -- Use already-computed layout height instead of polling Screen.getMode()
  -- in the keyboard hot path every frame.
  local runtime = _G and _G.CONFIG_UI
  local sceneH = tonumber((ctx and ctx.h) or (_ and _.h) or (runtime and runtime.currentSceneHeight) or 0)
  if sceneH >= 500 then
    return 50
  end
  return 60
end

local function isLogicalCrossHeldNow(ctx, _)
  local crossMask = _.PAD_CROSS or 0
  if crossMask == 0 then return false end
  local rawPad = getRawPadNow(ctx)
  if _.common and _.common.remapCrossCircleMask then
    rawPad = _.common.remapCrossCircleMask(rawPad)
  end
  return (rawPad & crossMask) ~= 0
end

local function getTextInputCursorHoldRepeatMask(ctx, _, nominalFpsOverride)
  local l1r1Mask = (_.PAD_L1 or 0) | (_.PAD_R1 or 0)
  if l1r1Mask == 0 then
    return 0
  end
  local rawPad = getRawPadNow(ctx)
  local heldMask = rawPad & l1r1Mask
  local prevHeldMask = tonumber(ctx.textInputCursorPrevHeldMask) or 0
  local repeatMask = 0
  ctx.textInputCursorPrevHeldMask = heldMask
  ctx.textInputCursorHoldFrames = tonumber(ctx.textInputCursorHoldFrames) or 0
  ctx.textInputCursorHoldCountdown = tonumber(ctx.textInputCursorHoldCountdown) or 0
  ctx.textInputCursorHoldRepeatCount = tonumber(ctx.textInputCursorHoldRepeatCount) or 0

  if heldMask ~= 0 then
    local nominalFps = tonumber(nominalFpsOverride) or getNominalFps(ctx, _)
    if prevHeldMask == 0 or prevHeldMask ~= heldMask then
      local fps = (_.common.getRepeatFps and _.common.getRepeatFps(ctx, nominalFps)) or nominalFps
      -- Initial move already comes from padJust in _.padEffective.
      ctx.textInputCursorHoldFrames = 0
      ctx.textInputCursorHoldRepeatCount = 0
      ctx.textInputCursorHoldCountdown = (_.common.getRepeatIntervalFrames and
          _.common.getRepeatIntervalFrames(fps, 0, 0)) or 1
    else
      local fps = (_.common.getRepeatFps and _.common.getRepeatFps(ctx, nominalFps)) or nominalFps
      ctx.textInputCursorHoldFrames = ctx.textInputCursorHoldFrames + 1
      local targetInterval = (_.common.getRepeatIntervalFrames and
          _.common.getRepeatIntervalFrames(fps, ctx.textInputCursorHoldFrames,
            ctx.textInputCursorHoldRepeatCount)) or 1
      if ctx.textInputCursorHoldCountdown > targetInterval then
        ctx.textInputCursorHoldCountdown = targetInterval
      end
      ctx.textInputCursorHoldCountdown = ctx.textInputCursorHoldCountdown - 1
      if ctx.textInputCursorHoldCountdown <= 0 then
        repeatMask = heldMask
        ctx.textInputCursorHoldRepeatCount = ctx.textInputCursorHoldRepeatCount + 1
        ctx.textInputCursorHoldCountdown = (_.common.getRepeatIntervalFrames and
            _.common.getRepeatIntervalFrames(fps, ctx.textInputCursorHoldFrames,
              ctx.textInputCursorHoldRepeatCount)) or targetInterval
      end
    end
  else
    ctx.textInputCursorHoldFrames = 0
    ctx.textInputCursorHoldCountdown = 0
    ctx.textInputCursorHoldRepeatCount = 0
  end

  return repeatMask
end

local function getTextInputBackspaceHoldRepeatMask(ctx, _, nominalFpsOverride)
  local backspaceMask = (_.PAD_SQUARE or 0)
  if backspaceMask == 0 then
    return 0
  end
  local rawPad = getRawPadNow(ctx)
  local heldMask = rawPad & backspaceMask
  local prevHeldMask = tonumber(ctx.textInputBackspacePrevHeldMask) or 0
  local repeatMask = 0
  ctx.textInputBackspacePrevHeldMask = heldMask
  ctx.textInputBackspaceHoldFrames = tonumber(ctx.textInputBackspaceHoldFrames) or 0
  ctx.textInputBackspaceHoldCountdown = tonumber(ctx.textInputBackspaceHoldCountdown) or 0
  ctx.textInputBackspaceHoldRepeatCount = tonumber(ctx.textInputBackspaceHoldRepeatCount) or 0

  if heldMask ~= 0 then
    local nominalFps = tonumber(nominalFpsOverride) or getNominalFps(ctx, _)
    if prevHeldMask == 0 or prevHeldMask ~= heldMask then
      local fps = (_.common.getRepeatFps and _.common.getRepeatFps(ctx, nominalFps)) or nominalFps
      -- Initial delete already comes from padJust in _.padEffective.
      ctx.textInputBackspaceHoldFrames = 0
      ctx.textInputBackspaceHoldRepeatCount = 0
      ctx.textInputBackspaceHoldCountdown = (_.common.getRepeatIntervalFrames and
          _.common.getRepeatIntervalFrames(fps, 0, 0)) or 1
    else
      local fps = (_.common.getRepeatFps and _.common.getRepeatFps(ctx, nominalFps)) or nominalFps
      ctx.textInputBackspaceHoldFrames = ctx.textInputBackspaceHoldFrames + 1
      local targetInterval = (_.common.getRepeatIntervalFrames and
          _.common.getRepeatIntervalFrames(fps, ctx.textInputBackspaceHoldFrames,
            ctx.textInputBackspaceHoldRepeatCount)) or 1
      if ctx.textInputBackspaceHoldCountdown > targetInterval then
        ctx.textInputBackspaceHoldCountdown = targetInterval
      end
      ctx.textInputBackspaceHoldCountdown = ctx.textInputBackspaceHoldCountdown - 1
      if ctx.textInputBackspaceHoldCountdown <= 0 then
        repeatMask = heldMask
        ctx.textInputBackspaceHoldRepeatCount = ctx.textInputBackspaceHoldRepeatCount + 1
        ctx.textInputBackspaceHoldCountdown = (_.common.getRepeatIntervalFrames and
            _.common.getRepeatIntervalFrames(fps, ctx.textInputBackspaceHoldFrames,
              ctx.textInputBackspaceHoldRepeatCount)) or targetInterval
      end
    end
  else
    ctx.textInputBackspaceHoldFrames = 0
    ctx.textInputBackspaceHoldCountdown = 0
    ctx.textInputBackspaceHoldRepeatCount = 0
  end

  return repeatMask
end

local function getTextInputGridHorizontalHoldRepeatMask(ctx, _, nominalFpsOverride)
  local lrMask = (_.PAD_LEFT or 0) | (_.PAD_RIGHT or 0)
  if lrMask == 0 then
    return 0
  end
  local rawPad = getRawPadNow(ctx)
  local heldMask = rawPad & lrMask
  local prevHeldMask = tonumber(ctx.textInputGridHorizontalPrevHeldMask) or 0
  local repeatMask = 0
  ctx.textInputGridHorizontalPrevHeldMask = heldMask
  ctx.textInputGridHorizontalHoldFrames = tonumber(ctx.textInputGridHorizontalHoldFrames) or 0
  ctx.textInputGridHorizontalHoldCountdown = tonumber(ctx.textInputGridHorizontalHoldCountdown) or 0
  ctx.textInputGridHorizontalHoldRepeatCount = tonumber(ctx.textInputGridHorizontalHoldRepeatCount) or 0

  if heldMask ~= 0 then
    local nominalFps = tonumber(nominalFpsOverride) or getNominalFps(ctx, _)
    if prevHeldMask == 0 or prevHeldMask ~= heldMask then
      local fps = (_.common.getRepeatFps and _.common.getRepeatFps(ctx, nominalFps)) or nominalFps
      -- Initial move already comes from padJust in _.padEffective.
      ctx.textInputGridHorizontalHoldFrames = 0
      ctx.textInputGridHorizontalHoldRepeatCount = 0
      ctx.textInputGridHorizontalHoldCountdown = (_.common.getRepeatIntervalFrames and
          _.common.getRepeatIntervalFrames(fps, 0, 0)) or 1
    else
      local fps = (_.common.getRepeatFps and _.common.getRepeatFps(ctx, nominalFps)) or nominalFps
      ctx.textInputGridHorizontalHoldFrames = ctx.textInputGridHorizontalHoldFrames + 1
      local targetInterval = (_.common.getRepeatIntervalFrames and
          _.common.getRepeatIntervalFrames(fps, ctx.textInputGridHorizontalHoldFrames,
            ctx.textInputGridHorizontalHoldRepeatCount)) or 1
      if ctx.textInputGridHorizontalHoldCountdown > targetInterval then
        ctx.textInputGridHorizontalHoldCountdown = targetInterval
      end
      ctx.textInputGridHorizontalHoldCountdown = ctx.textInputGridHorizontalHoldCountdown - 1
      if ctx.textInputGridHorizontalHoldCountdown <= 0 then
        repeatMask = heldMask
        ctx.textInputGridHorizontalHoldRepeatCount = ctx.textInputGridHorizontalHoldRepeatCount + 1
        ctx.textInputGridHorizontalHoldCountdown = (_.common.getRepeatIntervalFrames and
            _.common.getRepeatIntervalFrames(fps, ctx.textInputGridHorizontalHoldFrames,
              ctx.textInputGridHorizontalHoldRepeatCount)) or targetInterval
      end
    end
  else
    ctx.textInputGridHorizontalHoldFrames = 0
    ctx.textInputGridHorizontalHoldCountdown = 0
    ctx.textInputGridHorizontalHoldRepeatCount = 0
  end

  return repeatMask
end

local function ensureKeyboardLayoutCache(ctx, _)
  local titleMode = ctx.textInputTitleIdMode == true
  local shiftMode = (not titleMode) and (ctx.textInputShift == true)
  local hidePipe = ctx.textInputHidePipeBackslash == true
  local runtime = _G and _G.CONFIG_UI
  local normalizeLayout = _.normalizeKeyboardLayout or (_.common and _.common.normalizeKeyboardLayout)
  local getLayoutSpec = _.getKeyboardLayoutSpec or (_.common and _.common.getKeyboardLayoutSpec)
  local layoutKey = (normalizeLayout and normalizeLayout(runtime and runtime.keyboardLayout)) or "qwerty"
  local layoutSpec = (getLayoutSpec and getLayoutSpec(layoutKey)) or nil
  local layoutRows = (layoutSpec and layoutSpec.rows) or _.KEYBOARD_ROWS
  local layoutShiftedRows = (layoutSpec and layoutSpec.shiftedRows) or _.KEYBOARD_ROWS_SHIFTED
  local layoutTitleRows = (layoutSpec and layoutSpec.titleRows) or _.KEYBOARD_ROWS_TITLE_ID
  local baseRows = titleMode and layoutTitleRows or (shiftMode and layoutShiftedRows or layoutRows)
  local cacheKey = layoutKey .. "|" .. (titleMode and "1" or "0") .. "|" .. (shiftMode and "1" or "0") .. "|" .. (hidePipe and "1" or "0")
  local cache = ctx.textInputKeyboardLayoutCache
  if type(cache) == "table" and cache.key == cacheKey and cache.baseRowsRef == baseRows then
    return cache
  end

  local rows = {}
  local rowCount = #(baseRows or {})
  for i = 1, rowCount do
    local row = tostring(baseRows[i] or "")
    if hidePipe then
      row = row:gsub("\\", "")
      row = row:gsub("|", "")
    end
    rows[i] = row
  end

  local keyList = {}
  local specialKeys = {}
  local rowLen = {}
  local rowStart = {}
  local running = 1
  for r = 1, rowCount do
    local row = rows[r] or ""
    rowStart[r] = running
    local len = #row
    rowLen[r] = len
    for i = 1, len do
      keyList[#keyList + 1] = row:sub(i, i)
    end
    running = running + len
  end

  local spaceIdx = nil
  if not titleMode then
    rowStart[rowCount + 1] = running
    spaceIdx = running
    keyList[#keyList + 1] = " "
    specialKeys[spaceIdx] = { kind = "space", label = "" }
    rowLen[rowCount + 1] = 1
  end

  cache = {
    key = cacheKey,
    baseRowsRef = baseRows,
    rows = rows,
    rowCount = rowCount,
    rowLen = rowLen,
    rowStart = rowStart,
    keyList = keyList,
    specialKeys = specialKeys,
    spaceIdx = spaceIdx,
    maxRow = rowCount + ((spaceIdx ~= nil) and 1 or 0),
  }
  ctx.textInputKeyboardLayoutCache = cache
  return cache
end

local function buildRowOffsetsKey(rowOffsets, rowCount)
  if type(rowOffsets) ~= "table" then
    return ""
  end
  local parts = {}
  for i = 1, rowCount do
    parts[i] = tostring(tonumber(rowOffsets[i]) or 0)
  end
  return table.concat(parts, ",")
end

local function ensureKeyboardDrawCache(ctx, _, keyboardLayout, keyboardLeft, keyY, kw, kh, rowOffsets)
  if type(ctx) ~= "table" or type(keyboardLayout) ~= "table" then
    return nil
  end
  local rows = keyboardLayout.rows or {}
  local rowStart = keyboardLayout.rowStart or {}
  local rowCount = tonumber(keyboardLayout.rowCount) or #rows
  local spaceIdx = keyboardLayout.spaceIdx
  local offsetsKey = buildRowOffsetsKey(rowOffsets, rowCount)
  local cacheSig = table.concat({
    tostring(keyboardLayout.key or ""),
    tostring(math.floor((tonumber(keyboardLeft) or 0) + 0.5)),
    tostring(math.floor((tonumber(keyY) or 0) + 0.5)),
    tostring(math.floor((tonumber(kw) or 0) + 0.5)),
    tostring(math.floor((tonumber(kh) or 0) + 0.5)),
    tostring(math.floor((tonumber(_.KEY_WIDTH) or 0) + 0.5)),
    tostring(math.floor((tonumber(_.KEY_H) or 0) + 0.5)),
    tostring(math.floor((tonumber(_.KEY_GAP) or 0) + 0.5)),
    offsetsKey,
  }, "|")

  local cache = ctx.textInputKeyboardDrawCache
  if type(cache) == "table" and cache.sig == cacheSig then
    return cache
  end

  local keys = {}
  for r = 1, rowCount do
    local row = rows[r] or ""
    local n = #row
    local startX = keyboardLeft + (tonumber(rowOffsets[r]) or 0) * _.KEY_WIDTH
    local ky = math.floor(keyY + (r - 1) * _.KEY_H + _.KEY_GAP / 2)
    for col = 1, n do
      local idx = rowStart[r] + col - 1
      local kx = math.floor(startX + (col - 1) * _.KEY_WIDTH + _.KEY_GAP / 2)
      keys[#keys + 1] = {
        idx = idx,
        kx = kx,
        ky = ky,
        label = row:sub(col, col),
      }
    end
  end

  local spaceSpec = nil
  if spaceIdx then
    local specY = keyY + rowCount * _.KEY_H
    local ky = math.floor(specY + _.KEY_GAP / 2)
    local function findAdjacentGapX(leftCh, rightCh)
      local needle = string.lower(tostring(leftCh or "") .. tostring(rightCh or ""))
      if #needle ~= 2 then return nil end
      for r = 1, rowCount do
        local row = rows[r] or ""
        local pos = string.lower(row):find(needle, 1, true)
        if pos then
          local rowStartX = keyboardLeft + (tonumber(rowOffsets[r]) or 0) * _.KEY_WIDTH
          return rowStartX + (pos * _.KEY_WIDTH)
        end
      end
      return nil
    end

    local spaceCenterX = _.KEYBOARD_CENTER_X
    local leftGapX = findAdjacentGapX("e", "r")
    local rightGapX = findAdjacentGapX("k", "l")
    local specStartX
    local spaceW

    if leftGapX and rightGapX and rightGapX > leftGapX then
      spaceCenterX = (leftGapX + rightGapX) * 0.5
      specStartX = math.floor(leftGapX + (_.KEY_GAP / 2) + 0.5)
      spaceW = math.floor((rightGapX - leftGapX) - _.KEY_GAP + 0.5)
    else
      local specSlotW = _.KEY_WIDTH * 2.2
      spaceW = math.floor(specSlotW * 2 - _.KEY_GAP)
      specStartX = math.floor(spaceCenterX - (spaceW / 2) + 0.5)
    end

    -- Make spacebar one key wider to the left (keep right edge unchanged).
    specStartX = specStartX - _.KEY_WIDTH
    spaceW = spaceW + _.KEY_WIDTH
    -- Move spacebar right by one key.
    specStartX = specStartX + _.KEY_WIDTH

    if spaceW < kw then spaceW = kw end
    spaceCenterX = specStartX + (spaceW * 0.5)
    spaceSpec = {
      idx = spaceIdx,
      kx = specStartX,
      ky = ky,
      w = spaceW,
      centerX = spaceCenterX,
    }
  end

  cache = {
    sig = cacheSig,
    keys = keys,
    space = spaceSpec,
  }
  ctx.textInputKeyboardDrawCache = cache
  return cache
end

local KEY_PRESS_IN_FRAMES = 5
local KEY_PRESS_OUT_FRAMES = 7
local KEY_PRESS_MAX_INSET = 1.0 -- px per side (2px total shrink)
local KEY_PRESS_MAX_DARKEN = 0.24
local KEY_LABEL_SCALE = 0.7
local KEY_LABEL_PRESS_SHRINK_PX = 2.0
local KEY_LABEL_Y_BIAS = -1.0

local function clamp01(v)
  local n = tonumber(v) or 0
  if n < 0 then return 0 end
  if n > 1 then return 1 end
  return n
end

local function easeOutCubic(t)
  local x = clamp01(t)
  local a = 1 - x
  return 1 - (a * a * a)
end

local function easeOutQuad(t)
  local x = clamp01(t)
  local a = 1 - x
  return 1 - (a * a)
end

local function getPressShrinkPx(pressAmount)
  local maxPx = math.max(0, math.floor((tonumber(KEY_LABEL_PRESS_SHRINK_PX) or 0) + 0.5))
  if maxPx <= 0 then return 0 end
  local pa = clamp01(pressAmount)
  return math.max(0, math.min(maxPx, math.floor((maxPx * pa) + 0.5)))
end

local function darkenColor(color, amount)
  local raw = tonumber(color)
  if raw == nil then return color end
  local base = math.floor(raw)
  local dark = clamp01(amount)
  if dark <= 0.0001 then return base end
  local a = (base >> 24) & 0xFF
  local b = (base >> 16) & 0xFF
  local g = (base >> 8) & 0xFF
  local r = base & 0xFF
  local scale = 1 - dark
  r = math.floor((r * scale) + 0.5)
  g = math.floor((g * scale) + 0.5)
  b = math.floor((b * scale) + 0.5)
  return Color.new(r, g, b, a)
end

local function getKeyPressAnimAmount(ctx, keyIdx)
  local states = ctx and ctx.textInputKeyPressAnims
  local st = type(states) == "table" and states[keyIdx] or nil
  local heldKey = math.floor(tonumber(ctx and ctx.textInputHeldPressKey) or 0)
  if heldKey == math.floor(tonumber(keyIdx) or 0) then
    if type(st) == "table" and tostring(st.phase or "") == "in_hold" then
      local frame = math.max(0, math.floor(tonumber(st.frame) or 0))
      local t = frame / math.max(1, KEY_PRESS_IN_FRAMES)
      return easeOutCubic(t)
    end
    return 1
  end
  if type(st) ~= "table" then return 0 end
  local phase = tostring(st.phase or "")
  local frame = math.max(0, math.floor(tonumber(st.frame) or 0))
  if phase == "in_hold" then
    local t = frame / math.max(1, KEY_PRESS_IN_FRAMES)
    return easeOutCubic(t)
  end
  if phase == "out" then
    local fromAmount = clamp01(tonumber(st.fromAmount) or 1)
    local t = frame / math.max(1, KEY_PRESS_OUT_FRAMES)
    return fromAmount * (1 - easeOutQuad(t))
  end
  return 0
end

local function setKeyReleaseAnim(ctx, keyIdx, fromAmount)
  local idx = math.floor(tonumber(keyIdx) or 0)
  if idx <= 0 then return end
  if type(ctx.textInputKeyPressAnims) ~= "table" then
    ctx.textInputKeyPressAnims = {}
  end
  local amount = clamp01(tonumber(fromAmount) or 1)
  if amount <= 0.001 then
    ctx.textInputKeyPressAnims[idx] = nil
  else
    ctx.textInputKeyPressAnims[idx] = { phase = "out", frame = 0, fromAmount = amount }
  end
end

local function updateHeldKeyPressState(ctx, _, selectedKeyIdx, suppressPressVisuals)
  local crossMask = _.PAD_CROSS or 0
  local crossHeld = false
  if crossMask ~= 0 then
    local rawPad = getRawPadNow(ctx)
    if _.common and _.common.remapCrossCircleMask then
      rawPad = _.common.remapCrossCircleMask(rawPad)
    end
    crossHeld = (rawPad & crossMask) ~= 0
  end

  local entryGate = math.max(0, math.floor(tonumber(ctx.textInputPressAnimEntryGate) or 0))
  if entryGate == 1 then
    if crossHeld then
      ctx.textInputPressAnimEntryGate = 2
      ctx.textInputHeldPressKey = nil
      ctx.textInputKeyPressAnims = nil
      ctx.textInputCrossHeldPrev = true
      return
    end
    ctx.textInputPressAnimEntryGate = 0
  elseif entryGate == 2 then
    if crossHeld then
      ctx.textInputHeldPressKey = nil
      ctx.textInputKeyPressAnims = nil
      ctx.textInputCrossHeldPrev = true
      return
    end
    ctx.textInputPressAnimEntryGate = 0
    ctx.textInputCrossHeldPrev = false
    return
  end

  if suppressPressVisuals == true then
    ctx.textInputHeldPressKey = nil
    ctx.textInputKeyPressAnims = nil
    ctx.textInputCrossHeldPrev = crossHeld and true or false
    return
  end

  if ctx.textInputIgnoreCrossUntilRelease == true then
    if crossHeld then
      ctx.textInputIgnoreCrossReleaseFrames = 0
      ctx.textInputHeldPressKey = nil
      ctx.textInputCrossHeldPrev = true
      return
    end
    local releaseFrames = math.max(0, math.floor(tonumber(ctx.textInputIgnoreCrossReleaseFrames) or 0)) + 1
    ctx.textInputIgnoreCrossReleaseFrames = releaseFrames
    if releaseFrames < 2 then
      ctx.textInputHeldPressKey = nil
      ctx.textInputCrossHeldPrev = false
      return
    end
    ctx.textInputIgnoreCrossUntilRelease = nil
    ctx.textInputIgnoreCrossReleaseFrames = nil
    ctx.textInputCrossHeldPrev = false
    return
  end

  local prevHeld = (ctx.textInputCrossHeldPrev == true)
  if crossHeld and not prevHeld then
    local idx = math.floor(tonumber(selectedKeyIdx or ctx.textInputGridSel) or 0)
    if idx > 0 then
      local oldHeld = math.floor(tonumber(ctx.textInputHeldPressKey) or 0)
      if oldHeld > 0 and oldHeld ~= idx then
        setKeyReleaseAnim(ctx, oldHeld, getKeyPressAnimAmount(ctx, oldHeld))
      end
      if type(ctx.textInputKeyPressAnims) ~= "table" then
        ctx.textInputKeyPressAnims = {}
      end
      ctx.textInputHeldPressKey = idx
      ctx.textInputKeyPressAnims[idx] = { phase = "in_hold", frame = 0 }
    end
  elseif (not crossHeld) and prevHeld then
    local heldIdx = math.floor(tonumber(ctx.textInputHeldPressKey) or 0)
    if heldIdx > 0 then
      setKeyReleaseAnim(ctx, heldIdx, getKeyPressAnimAmount(ctx, heldIdx))
    end
    ctx.textInputHeldPressKey = nil
  end

  ctx.textInputCrossHeldPrev = crossHeld
end

local function advanceKeyPressAnims(ctx)
  local states = ctx and ctx.textInputKeyPressAnims
  if type(states) ~= "table" then return end
  for idx, st in pairs(states) do
    if type(st) ~= "table" then
      states[idx] = nil
    else
      local phase = tostring(st.phase or "")
      local frame = math.max(0, math.floor(tonumber(st.frame) or 0)) + 1
      if phase == "in_hold" then
        if frame >= KEY_PRESS_IN_FRAMES then
          if math.floor(tonumber(ctx.textInputHeldPressKey) or 0) == math.floor(tonumber(idx) or 0) then
            st.phase = "hold"
            st.frame = 0
          else
            st.phase = "out"
            st.frame = 0
            st.fromAmount = 1
          end
        else
          st.frame = frame
        end
      elseif phase == "hold" then
        if math.floor(tonumber(ctx.textInputHeldPressKey) or 0) ~= math.floor(tonumber(idx) or 0) then
          st.phase = "out"
          st.frame = 0
          st.fromAmount = 1
        end
      else
        if frame >= KEY_PRESS_OUT_FRAMES then
          states[idx] = nil
        else
          st.frame = frame
        end
      end
    end
  end
  if next(states) == nil then
    ctx.textInputKeyPressAnims = nil
  end
end

local TEXT_INPUT_BEL_MENU_OPEN_KEY = "textInputBelMenuOpen"
local TEXT_INPUT_BEL_MENU_ANIM_KEY = TEXT_INPUT_BEL_MENU_OPEN_KEY .. "_anim"
local TEXT_INPUT_BEL_MENU_CLOSING_KEY = TEXT_INPUT_BEL_MENU_OPEN_KEY .. "_closing"
local TEXT_INPUT_BEL_MENU_ROWS_CACHE_KEY = TEXT_INPUT_BEL_MENU_OPEN_KEY .. "_rowsCache"
local TEXT_INPUT_BEL_MENU_HINTS_CACHE_KEY = TEXT_INPUT_BEL_MENU_OPEN_KEY .. "_hintsCache"

local TEXT_INPUT_RUNTIME_CLEAR_FIELDS = {
  "_textInputBelBaselineCallback",
  "textInputBelBaseline",
  "textInputAllowBelAdd",
  "textInputEnableBelKey",
  "textInputBelProfile",
  "textInputHidePipeBackslash",
  "textInputSpaceReturnFromTopCol",
  "textInputSpaceReturnFromBottomCol",
  "textInputBelMenuOpen",
  "textInputBelMenuSel",
  "textInputBelMenuScroll",
  "textInputBelRowsByPage",
  "textInputBelRowsProfile",
  "textInputBelRowsText",
  "textInputBelPage",
  "textInputBelColumnMinWidths",
  "textInputBelMinIntrinsicW",
  "textInputBelLayoutProfile",
  "textInputBelLayoutScale",
  "textInputBelLayoutText",
  "textInputCursorPrevHeldMask",
  "textInputCursorHoldFrames",
  "textInputCursorHoldCountdown",
  "textInputBackspacePrevHeldMask",
  "textInputBackspaceHoldFrames",
  "textInputBackspaceHoldCountdown",
  "textInputGridHorizontalPrevHeldMask",
  "textInputGridHorizontalHoldFrames",
  "textInputGridHorizontalHoldCountdown",
  "textInputHeldPressKey",
  "textInputCrossHeldPrev",
  "textInputIgnoreCrossUntilRelease",
  "textInputIgnoreCrossReleaseFrames",
  "textInputSuppressPressVisualFrames",
  "textInputPressAnimEntryGate",
  "textInputPressGateSceneEpoch",
  "textInputKeyPressAnims",
  "textInputHintPadPressAnims",
  "textInputKeyboardDrawCache",
  "textInputKeyLabelFontByShrinkPx",
  "textInputKeyLabelFontByShrinkPxSig",
  "textInputKeyLabelWidthCache",
  "textInputKeyLabelWidthCacheSig",
  "textInputKeyLabelWidthWarmSig",
}

local function resetTextInputRuntime(ctx, clearCallback)
  if clearCallback == true then
    ctx.textInputCallback = nil
  end
  for i = 1, #TEXT_INPUT_RUNTIME_CLEAR_FIELDS do
    ctx[TEXT_INPUT_RUNTIME_CLEAR_FIELDS[i]] = nil
  end
  ctx[TEXT_INPUT_BEL_MENU_ANIM_KEY] = nil
  ctx[TEXT_INPUT_BEL_MENU_CLOSING_KEY] = nil
  ctx[TEXT_INPUT_BEL_MENU_ROWS_CACHE_KEY] = nil
  ctx[TEXT_INPUT_BEL_MENU_HINTS_CACHE_KEY] = nil
end

local function run(ctx)
  local _ = ctx._
  local belMenuOpenKey = TEXT_INPUT_BEL_MENU_OPEN_KEY
  local belMenuAnimKey = TEXT_INPUT_BEL_MENU_ANIM_KEY
  local belMenuClosingKey = TEXT_INPUT_BEL_MENU_CLOSING_KEY
  local belOverlayOpen = (ctx[belMenuOpenKey] == true)
  local transitionRenderPass = (_.common and _.common.isSceneTransitionInActive and _.common.isSceneTransitionInActive(ctx)) or
      false
  if not ctx.textInputCallback then
    -- When transitioning away from text input, we may intentionally keep
    -- rendering this scene for outgoing transition frames. Do not force-exit
    -- here or hints/buttons will hard-cut instead of fading.
    if transitionRenderPass then
      -- Keep drawing with existing text/layout snapshot; input is already
      -- blocked by transition gate in ui.lua.
    else
      resetTextInputRuntime(ctx, false)
      ctx.state = ctx.textInputReturnState or "editor"
      return
    end
  end
  local sceneEpoch = math.max(0, math.floor(tonumber(ctx._sceneEpoch) or 0))
  if math.max(-1, math.floor(tonumber(ctx.textInputPressGateSceneEpoch) or -1)) ~= sceneEpoch then
    ctx.textInputPressGateSceneEpoch = sceneEpoch
    local crossHeldOnEntry = isLogicalCrossHeldNow(ctx, _)
    if crossHeldOnEntry then
      ctx.textInputPressAnimEntryGate = 2
      ctx.textInputIgnoreCrossUntilRelease = true
      ctx.textInputIgnoreCrossReleaseFrames = 0
      ctx.textInputCrossHeldPrev = true
      ctx.textInputHeldPressKey = nil
      ctx.textInputKeyPressAnims = nil
      local suppressFrames = math.max(0, math.floor(tonumber(ctx.textInputSuppressPressVisualFrames) or 0))
      if suppressFrames < 6 then
        ctx.textInputSuppressPressVisualFrames = 6
      end
    else
      ctx.textInputPressAnimEntryGate = 1
      if ctx.textInputCrossHeldPrev == nil then
        ctx.textInputCrossHeldPrev = false
      end
    end
  end
  if ctx._textInputBelBaselineCallback ~= ctx.textInputCallback then
    ctx._textInputBelBaselineCallback = ctx.textInputCallback
    ctx.textInputBelBaseline = tostring(ctx.textInputValue or "")
  end
  if not ctx.textInputCursor then ctx.textInputCursor = #ctx.textInputValue + 1 end
  if ctx.textInputCursor < 1 then ctx.textInputCursor = 1 end
  if ctx.textInputCursor > #ctx.textInputValue + 1 then ctx.textInputCursor = #ctx.textInputValue + 1 end
  local TEXT_DISP_CHARS = 42
  if ctx.textInputCursor < ctx.textInputScroll then ctx.textInputScroll = ctx.textInputCursor end
  if ctx.textInputCursor > ctx.textInputScroll + TEXT_DISP_CHARS - 1 then
    ctx.textInputScroll = ctx.textInputCursor -
        TEXT_DISP_CHARS + 1
  end
  if ctx.textInputScroll < 1 then ctx.textInputScroll = 1 end
  if ctx.textInputScroll > #ctx.textInputValue + 1 then
    ctx.textInputScroll = math.max(1,
      #ctx.textInputValue - TEXT_DISP_CHARS + 2)
  end
  local segStart = ctx.textInputScroll
  local segEnd = math.min(segStart + TEXT_DISP_CHARS - 2, #ctx.textInputValue)
  local beforeCurs = ctx.textInputValue:sub(segStart, ctx.textInputCursor - 1)
  local afterCurs = ctx.textInputValue:sub(ctx.textInputCursor, segEnd)
  local formatBelForDisplay = (_.common and _.common.formatBelForDisplay) or function(text)
    return tostring(text or ""):gsub(BEL, "\226\150\161")
  end
  local beforeDisplay = formatBelForDisplay(beforeCurs)
  local afterDisplay = formatBelForDisplay(afterCurs)
  local keyboardLayout = ensureKeyboardLayoutCache(ctx, _)
  local rows = keyboardLayout.rows or {}
  local runtime = _G and _G.CONFIG_UI
  local nominalFps = getNominalFps(ctx, _)
  local transitionActive = type(runtime) == "table" and runtime.sceneTransitionAnimActive == true
  local transitionPhase = transitionActive and tostring(runtime.sceneTransitionAnimPhase or "") or ""
  local belEnabledRaw = (ctx.textInputEnableBelKey == true) and (not ctx.textInputTitleIdMode)
  if belEnabledRaw then
    ctx.textInputBelHintLatched = true
  elseif (not transitionActive) or transitionPhase ~= "out" then
    ctx.textInputBelHintLatched = false
  end
  local belEnabled = belEnabledRaw or
      (transitionActive and transitionPhase == "out" and ctx.textInputBelHintLatched == true)
  local glyphKeyLabel = (_.text_str and _.text_str.glyphs_key_label) or GLYPH_KEY_LABEL_FALLBACK
  local keyList = keyboardLayout.keyList or {}
  local specialKeys = keyboardLayout.specialKeys or {}
  local rowLen = keyboardLayout.rowLen or {}
  local rowStart = keyboardLayout.rowStart or {}
  local rowCount = tonumber(keyboardLayout.rowCount) or #rows
  local spaceIdx = keyboardLayout.spaceIdx
  local maxRow = tonumber(keyboardLayout.maxRow) or (rowCount + ((spaceIdx ~= nil) and 1 or 0))
  if ctx.textInputGridSel < 1 then ctx.textInputGridSel = 1 end
  if ctx.textInputGridSel > #keyList then ctx.textInputGridSel = #keyList end
  local suppressPressVisualFrames = math.max(0, math.floor(tonumber(ctx.textInputSuppressPressVisualFrames) or 0))
  local suppressPressVisualsForFrame = suppressPressVisualFrames > 0
  if not belOverlayOpen then
    updateHeldKeyPressState(ctx, _, ctx.textInputGridSel, suppressPressVisualsForFrame)
    advanceKeyPressAnims(ctx)
  end
  local pressAnimEntryGateActive = (math.max(0, math.floor(tonumber(ctx.textInputPressAnimEntryGate) or 0)) == 2)
  if suppressPressVisualFrames > 0 then
    ctx.textInputSuppressPressVisualFrames = suppressPressVisualFrames - 1
  else
    ctx.textInputSuppressPressVisualFrames = 0
  end
  local keyY = _.KEYBOARD_CENTER_Y - _.scaleY(50)
  local kw, kh = _.KEY_WIDTH - _.KEY_GAP, _.KEY_H - _.KEY_GAP
  local keyScale = KEY_LABEL_SCALE
  -- Keep keycap characters visible even while the glyph/BEL overlay is open.
  local drawKeyboardKeyLabels = true
  local keyFontBase = _.font
  local maxLabelShrinkPx = math.max(0, math.floor((tonumber(KEY_LABEL_PRESS_SHRINK_PX) or 0) + 0.5))
  local keyLabelBasePx = math.max(8, math.floor(((tonumber(_.common and _.common.FT_PIXEL_H) or 18) *
      math.max(0.1, tonumber(runtime and runtime.currentUiScale) or tonumber(ctx.uiScale) or 1)) + 0.5))
  local keyFontScaleSig = tostring(_.drawMode) .. "|" .. tostring(keyFontBase) .. "|" .. tostring(keyLabelBasePx) ..
      "|" .. tostring(maxLabelShrinkPx)
  local keyFontsByShrinkPx = ctx.textInputKeyLabelFontByShrinkPx
  if type(keyFontsByShrinkPx) ~= "table" or ctx.textInputKeyLabelFontByShrinkPxSig ~= keyFontScaleSig then
    keyFontsByShrinkPx = { [0] = keyFontBase }
    if _.drawMode == "ftPrint" then
      for shrinkPx = 1, maxLabelShrinkPx do
        keyFontsByShrinkPx[shrinkPx] = keyFontBase
      end
    end
    ctx.textInputKeyLabelFontByShrinkPx = keyFontsByShrinkPx
    ctx.textInputKeyLabelFontByShrinkPxSig = keyFontScaleSig
  end
  local keyFontCacheSig = keyFontScaleSig
  local keyLabelWidthCache = ctx.textInputKeyLabelWidthCache
  if type(keyLabelWidthCache) ~= "table" or ctx.textInputKeyLabelWidthCacheSig ~= keyFontCacheSig then
    keyLabelWidthCache = {}
    ctx.textInputKeyLabelWidthCache = keyLabelWidthCache
    ctx.textInputKeyLabelWidthCacheSig = keyFontCacheSig
  end

  local function getCachedKeyLabelWidth(fontHandle, label, drawLabelScale)
    if not label or label == "" then return 0 end
    if _.drawMode == "ftPrint" then
      local fontKey = tostring(fontHandle)
      local widthByLabel = keyLabelWidthCache[fontKey]
      if type(widthByLabel) ~= "table" then
        widthByLabel = {}
        keyLabelWidthCache[fontKey] = widthByLabel
      end
      local cached = widthByLabel[label]
      if cached ~= nil then return cached end
      local measured = (_.common.calcTextWidth and _.common.calcTextWidth(fontHandle, label, drawLabelScale)) or
          ((_.KEY_CHAR_W or 10) * #label)
      widthByLabel[label] = measured
      return measured
    end
    if #label <= 1 then
      return math.floor(((_.KEY_CHAR_W or 10) * drawLabelScale) + 0.5)
    end
    return (_.common.calcTextWidth and _.common.calcTextWidth(fontHandle, label, drawLabelScale)) or
        (((_.KEY_CHAR_W or 10) * #label) * drawLabelScale)
  end

  if _.drawMode == "ftPrint" and drawKeyboardKeyLabels then
    local warmSig = tostring(keyboardLayout.key or "") .. "|" .. keyFontCacheSig
    if ctx.textInputKeyLabelWidthWarmSig ~= warmSig then
      local fontsToWarm = {}
      if type(keyFontsByShrinkPx) == "table" then
        for shrinkPx = 0, maxLabelShrinkPx do
          fontsToWarm[#fontsToWarm + 1] = keyFontsByShrinkPx[shrinkPx] or keyFontBase
        end
      else
        fontsToWarm[1] = keyFontBase
      end
      for i = 1, #keyList do
        local label = tostring(keyList[i] or "")
        if label ~= "" then
          for fIdx = 1, #fontsToWarm do
            local f = fontsToWarm[fIdx]
            local key = tostring(f)
            local widthByLabel = keyLabelWidthCache[key]
            if type(widthByLabel) ~= "table" then
              widthByLabel = {}
              keyLabelWidthCache[key] = widthByLabel
            end
            if widthByLabel[label] == nil then
              widthByLabel[label] = (_.common.calcTextWidth and _.common.calcTextWidth(f, label, keyScale)) or
                  ((_.KEY_CHAR_W or 10) * #label)
            end
          end
        end
      end
      ctx.textInputKeyLabelWidthWarmSig = warmSig
    end
  end
  local rowOffsets = (ctx.textInputTitleIdMode and _.KEYBOARD_ROW_OFFSETS_TITLE_ID) or _.KEYBOARD_ROW_OFFSETS or
      { 0, 0, 0, 0 }
  local minOffset = 0
  local maxExtent = 0
  for r = 1, rowCount do
    local off = tonumber(rowOffsets[r]) or 0
    if r == 1 or off < minOffset then minOffset = off end
    -- Keep keyboard block centered from the base character rows.
    local extent = off + #(rows[r] or "")
    if extent > maxExtent then maxExtent = extent end
  end
  local keyboardBlockW = math.max(_.KEY_WIDTH, (maxExtent - minOffset) * _.KEY_WIDTH)
  local keyboardLeft = _.KEYBOARD_CENTER_X - keyboardBlockW / 2 - (minOffset * _.KEY_WIDTH)
  local textY = _.scaleY(108)
  local scale = 0.9
  local textLeftX = math.floor(keyboardLeft + (_.KEY_GAP / 2) + 0.5)
  _.drawText(_.font, _.drawMode, textLeftX, _.scaleY(88), 0.9,
    ctx.textInputPrompt or _.common_str.enter_text, _.DIM_COLOR)
  local x = textLeftX
  if beforeDisplay ~= "" then
    _.drawText(_.font, _.drawMode, x, textY, scale, beforeDisplay, _.WHITE)
    x = x + (_.common.calcTextWidth and _.common.calcTextWidth(_.font, beforeDisplay, scale) or (#beforeDisplay * 10))
  end
  _.drawText(_.font, _.drawMode, x, textY, scale, "|", _.TEXT_CURSOR_COLOR or _.WHITE)
  x = x + (_.common.calcTextWidth and _.common.calcTextWidth(_.font, "|", scale) or 10)
  if afterDisplay ~= "" then
    _.drawText(_.font, _.drawMode, x, textY, scale, afterDisplay, _.WHITE)
  end

  local function drawKey(kx, ky, w, h, label, sel, labelScale, keyIdx)
    local drawLabelScale = tonumber(labelScale) or keyScale
    local pressAmount = ((not belOverlayOpen) and drawKeyboardKeyLabels) and getKeyPressAnimAmount(ctx, keyIdx) or 0
    local labelShrinkPx = getPressShrinkPx(pressAmount)
    local inset = KEY_PRESS_MAX_INSET * pressAmount
    local darken = KEY_PRESS_MAX_DARKEN * pressAmount
    local bg = sel and _.KEY_BG_SEL or _.KEY_BG
    local border = sel and _.KEY_BORDER_SEL or _.KEY_BORDER
    if darken > 0.0001 then
      bg = darkenColor(bg, darken)
      border = darkenColor(border, darken * 0.85)
    end
    local ix = math.floor((kx + inset) + 0.5)
    local iy = math.floor((ky + inset) + 0.5)
    local iw = math.max(2, math.floor((w - (2 * inset)) + 0.5))
    local ih = math.max(2, math.floor((h - (2 * inset)) + 0.5))
    local glyphScaleMul = ih / math.max(1, h)
    local labelFont = keyFontBase
    if _.drawMode ~= "ftPrint" then
      -- Font.print/fmPrint can scale per-draw directly.
      local fontBasePx = math.max(1, tonumber(_.KEY_LH) or 14)
      local pressShrinkMul = 1 - (labelShrinkPx / fontBasePx)
      if pressShrinkMul < 0.65 then pressShrinkMul = 0.65 end
      drawLabelScale = drawLabelScale * glyphScaleMul * pressShrinkMul
      labelFont = _.font
    else
      labelFont = (type(keyFontsByShrinkPx) == "table" and keyFontsByShrinkPx[labelShrinkPx]) or keyFontBase
    end
    -- Hot path optimization: draw key border+fill in 2 rects instead of 5.
    _.Graphics.drawRect(ix, iy, iw, ih, border)
    if iw > 2 and ih > 2 then
      _.Graphics.drawRect(ix + 1, iy + 1, iw - 2, ih - 2, bg)
    end
    if not drawKeyboardKeyLabels or label == "" then
      return
    end
    local textW = getCachedKeyLabelWidth(labelFont, label, drawLabelScale)
    -- Anchor label positioning to the original key center so tiny inset-rounding
    -- differences during press/release do not create 1px jitter.
    local keyCenterX = (tonumber(kx) or 0) + ((tonumber(w) or 0) * 0.5)
    local keyCenterY = (tonumber(ky) or 0) + ((tonumber(h) or 0) * 0.5)
    local textX = math.floor(keyCenterX - (textW * 0.5) + 0.5)
    local textH
    if _.drawMode == "ftPrint" then
      local drawPx = math.max(8, keyLabelBasePx - labelShrinkPx)
      textH = math.max(8, drawPx)
    else
      textH = math.max(8, math.floor(((_.KEY_LH or 14) * drawLabelScale) + 0.5))
    end
    local textY = math.floor(keyCenterY - (textH * 0.5) + KEY_LABEL_Y_BIAS + 0.5)
    _.drawText(labelFont, _.drawMode, textX, textY, drawLabelScale, label, sel and _.KEYBOARD_SELECTED_COLOR or _.WHITE,
      textH)
  end
  local drawCache = ensureKeyboardDrawCache(ctx, _, keyboardLayout, keyboardLeft, keyY, kw, kh, rowOffsets) or {}
  local keysToDraw = drawCache.keys or {}
  for i = 1, #keysToDraw do
    local item = keysToDraw[i]
    drawKey(item.kx, item.ky, kw, kh, item.label, item.idx == ctx.textInputGridSel, nil, item.idx)
  end
  local spaceCenterX = _.KEYBOARD_CENTER_X
  local spaceSpec = drawCache.space
  if type(spaceSpec) == "table" then
    spaceCenterX = tonumber(spaceSpec.centerX) or spaceCenterX
    drawKey(spaceSpec.kx, spaceSpec.ky, spaceSpec.w, kh, "", spaceSpec.idx == ctx.textInputGridSel, nil, spaceSpec.idx)
  end

  local function moveTextCursorWrap(delta)
    local maxPos = #(ctx.textInputValue or "") + 1
    if maxPos < 1 then maxPos = 1 end
    local cursor = tonumber(ctx.textInputCursor) or 1
    if cursor < 1 then cursor = 1 end
    if cursor > maxPos then cursor = maxPos end
    if delta < 0 then
      cursor = cursor - 1
      if cursor < 1 then cursor = maxPos end
    elseif delta > 0 then
      cursor = cursor + 1
      if cursor > maxPos then cursor = 1 end
    end
    ctx.textInputCursor = cursor
  end

  if ctx[belMenuOpenKey] then
    local padSelect = _.PAD_SELECT or 0
    if padSelect ~= 0 and (_.padEffective & padSelect) ~= 0 then
      if ctx[belMenuClosingKey] ~= true then
        ctx[belMenuClosingKey] = true
        if tonumber(ctx[belMenuAnimKey]) == nil or tonumber(ctx[belMenuAnimKey]) < 0.001 then
          ctx[belMenuAnimKey] = 1
        end
      end
    end
    local cursorMoveMask = _.padEffective | getTextInputCursorHoldRepeatMask(ctx, _, nominalFps)
    if (cursorMoveMask & _.PAD_L1) ~= 0 then moveTextCursorWrap(-1) end
    if (cursorMoveMask & _.PAD_R1) ~= 0 then moveTextCursorWrap(1) end
    local belProfile = belProfileFromContext(ctx)
    local belPage = clampBelPage(ctx.textInputBelPage)
    ctx.textInputBelPage = belPage
    local belRowsByPage = ensureBelRowsByPage(ctx, belProfile, _.text_str)
    local uiScale = tonumber(ctx.uiScale) or 1
    if type(ctx.textInputBelColumnMinWidths) ~= "table" or ctx.textInputBelLayoutProfile ~= belProfile or
        ctx.textInputBelLayoutScale ~= uiScale or ctx.textInputBelLayoutText ~= _.text_str then
      local colMinW, maxIntrinsicW = buildBelMenuLayoutMetrics(_, belRowsByPage)
      ctx.textInputBelColumnMinWidths = colMinW
      ctx.textInputBelMinIntrinsicW = maxIntrinsicW
      ctx.textInputBelLayoutProfile = belProfile
      ctx.textInputBelLayoutScale = uiScale
      ctx.textInputBelLayoutText = _.text_str
    end
    local belRows = belRowsByPage[belPage] or {}
    local pageLabelFmt = glyphText(_.text_str, "page_label_format", "Page %d/%d")
    local pageLabel = string.format(pageLabelFmt, belPage, BEL_PAGE_COUNT)
    local belMenuMaxVisible = 8
    local handled = actions_menu.run(ctx, {
      openKey = belMenuOpenKey,
      selKey = "textInputBelMenuSel",
      scrollKey = "textInputBelMenuScroll",
      cacheRows = true,
      cacheHints = true,
      rowStateKeyPrefix = "text_input_bel_row_",
      columnLayout = true,
      columnMinWidths = ctx.textInputBelColumnMinWidths,
      minLabelIntrinsicW = ctx.textInputBelMinIntrinsicW,
      skipIntrinsicMeasure = true,
      titleOverride = glyphKeyLabel .. " " .. tostring(belPage) .. "/" .. tostring(BEL_PAGE_COUNT),
      anchorPad = "square",
      anchorSpanSlots = 3,
      forceAnchorSpanWidth = true,
      anchorLabel = pageLabel,
      onAnchorPress = function()
        local nextPage = belPage + 1
        if nextPage > BEL_PAGE_COUNT then nextPage = 1 end
        ctx.textInputBelPage = nextPage
        ctx.textInputBelMenuSel = 1
        ctx.textInputBelMenuScroll = 0
        return true
      end,
      rows = belRows,
      maxVisible = belMenuMaxVisible,
      minVisible = belMenuMaxVisible,
      closeOnSelect = false,
      onSelect = function(row)
        local token = row and row.token
        if token and #ctx.textInputValue + #token <= ctx.textInputMaxLen then
          ctx.textInputValue = ctx.textInputValue:sub(1, ctx.textInputCursor - 1) ..
              token .. ctx.textInputValue:sub(ctx.textInputCursor)
          ctx.textInputCursor = ctx.textInputCursor + #token
        end
      end,
      onCancel = function()
        ctx.textInputBelMenuOpen = nil
        ctx.textInputBelMenuSel = nil
        ctx.textInputBelMenuScroll = nil
        ctx.textInputBelPage = nil
      end,
      hints = {
        { pad = "cross", label = glyphText(_.text_str, "hint_insert", "Insert"), row = 1 },
        { pad = "square", label = glyphText(_.text_str, "hint_page", "Page"), row = 1 },
        { pad = "circle", label = glyphText(_.text_str, "hint_cancel", "Cancel"), row = 1 },
      },
    })
    if handled then
      -- Keep hold-repeat state while glyph overlay is open so L1/R1 cursor
      -- movement can continue accelerating like other repeat-driven navigation.
      return
    end
  end
  local rowSize = rowLen
  local spaceRow = spaceIdx and (rowCount + 1) or nil
  if not spaceRow then
    ctx.textInputSpaceReturnFromTopCol = nil
    ctx.textInputSpaceReturnFromBottomCol = nil
  end
  local function rowAt(r, col)
    local start = rowStart[r]
    local size = rowSize[r] or 0
    if not start or size <= 0 then return 1 end
    local c = col
    if c < 1 then c = 1 end
    if c > size then c = size end
    return start + c - 1
  end
  local function rowOf(s)
    for r = 1, maxRow do
      local start = rowStart[r]
      local size = rowSize[r] or 0
      if start and size > 0 and s >= start and s < (start + size) then
        return r
      end
    end
    return 1
  end
  local function keyCenterXForRowCol(r, col)
    if spaceRow and r == spaceRow then
      return spaceCenterX
    end
    local off = tonumber(rowOffsets[r]) or 0
    local startX = keyboardLeft + off * _.KEY_WIDTH
    return startX + ((col - 0.5) * _.KEY_WIDTH)
  end
  local function nearestColForRowX(r, centerX)
    local size = rowSize[r] or 0
    if size <= 1 then return 1 end
    if spaceRow and r == spaceRow then return 1 end
    local off = tonumber(rowOffsets[r]) or 0
    local startX = keyboardLeft + off * _.KEY_WIDTH
    local bestCol = 1
    local bestDist = nil
    local tieEpsilon = 0.001
    for c = 1, size do
      local cx = startX + ((c - 0.5) * _.KEY_WIDTH)
      local dist = math.abs(cx - centerX)
      if (bestDist == nil) or (dist < (bestDist - tieEpsilon)) or
          (math.abs(dist - bestDist) <= tieEpsilon and c > bestCol) then
        bestDist = dist
        bestCol = c
      end
    end
    return bestCol
  end
  local blockDpadWhileCrossHeld = isLogicalCrossHeldNow(ctx, _)
  local gridHorizontalMask = 0
  if not blockDpadWhileCrossHeld then
    gridHorizontalMask = _.padEffective | getTextInputGridHorizontalHoldRepeatMask(ctx, _, nominalFps)
  else
    -- Avoid stale repeat carry-over the frame Cross is released.
    ctx.textInputGridHorizontalPrevHeldMask = 0
    ctx.textInputGridHorizontalHoldFrames = 0
    ctx.textInputGridHorizontalHoldCountdown = 0
  end
  if (gridHorizontalMask & _.PAD_LEFT) ~= 0 then
    local r = rowOf(ctx.textInputGridSel)
    local start = rowStart[r]
    local size = rowSize[r] or 0
    if start and size > 0 then
      local colInRow = ctx.textInputGridSel - start + 1
      colInRow = colInRow - 1
      if colInRow < 1 then colInRow = size end
      ctx.textInputGridSel = rowAt(r, colInRow)
    end
  end
  if (gridHorizontalMask & _.PAD_RIGHT) ~= 0 then
    local r = rowOf(ctx.textInputGridSel)
    local start = rowStart[r]
    local size = rowSize[r] or 0
    if start and size > 0 then
      local colInRow = ctx.textInputGridSel - start + 1
      colInRow = colInRow + 1
      if colInRow > size then colInRow = 1 end
      ctx.textInputGridSel = rowAt(r, colInRow)
    end
  end
  if (not blockDpadWhileCrossHeld) and ((_.padEffective & _.PAD_UP) ~= 0) then
    local r = rowOf(ctx.textInputGridSel)
    local start = rowStart[r]
    local size = rowSize[r] or 0
    if start and size > 0 then
      local colInRow = ctx.textInputGridSel - start + 1
      local targetRow
      if r > 1 then
        targetRow = r - 1
      else
        targetRow = spaceRow or maxRow
      end
      local targetCol
      if spaceRow and targetRow == spaceRow and r == 1 then
        -- Remember top-row origin when wrapping up into the spacebar row.
        ctx.textInputSpaceReturnFromTopCol = colInRow
      end
      if spaceRow and r == spaceRow and targetRow == (spaceRow - 1) then
        local rememberedCol = tonumber(ctx.textInputSpaceReturnFromBottomCol)
        if rememberedCol and rememberedCol >= 1 then
          targetCol = rememberedCol
        end
      end
      if not targetCol then
        if spaceRow and r == spaceRow then
          local targetSize = rowSize[targetRow] or 1
          targetCol = math.max(1, math.floor(targetSize / 2) + 1)
        else
          local xCenter = keyCenterXForRowCol(r, colInRow)
          targetCol = nearestColForRowX(targetRow, xCenter)
        end
      end
      ctx.textInputGridSel = rowAt(targetRow, targetCol)
    end
  end
  if (not blockDpadWhileCrossHeld) and ((_.padEffective & _.PAD_DOWN) ~= 0) then
    local r = rowOf(ctx.textInputGridSel)
    local start = rowStart[r]
    local size = rowSize[r] or 0
    if start and size > 0 then
      local colInRow = ctx.textInputGridSel - start + 1
      local targetRow = (r < maxRow) and (r + 1) or 1
      if spaceRow and targetRow == spaceRow and r == (spaceRow - 1) then
        -- Remember bottom-row origin when moving down into the spacebar row.
        ctx.textInputSpaceReturnFromBottomCol = colInRow
      end
      local targetCol
      if spaceRow and r == spaceRow and targetRow == 1 then
        local rememberedCol = tonumber(ctx.textInputSpaceReturnFromTopCol)
        if rememberedCol and rememberedCol >= 1 then
          targetCol = rememberedCol
        end
      end
      if not targetCol then
        local xCenter = keyCenterXForRowCol(r, colInRow)
        targetCol = nearestColForRowX(targetRow, xCenter)
      end
      ctx.textInputGridSel = rowAt(targetRow, targetCol)
    end
  end
  local cursorMoveMask = _.padEffective | getTextInputCursorHoldRepeatMask(ctx, _, nominalFps)
  if (cursorMoveMask & _.PAD_L1) ~= 0 then moveTextCursorWrap(-1) end
  if (cursorMoveMask & _.PAD_R1) ~= 0 then moveTextCursorWrap(1) end
  local suppressCrossEnter = suppressPressVisualsForFrame or pressAnimEntryGateActive or
      (ctx.textInputIgnoreCrossUntilRelease == true)
  if (not suppressCrossEnter) and ((_.padEffective & _.PAD_CROSS) ~= 0) then
    local selIdx = ctx.textInputGridSel
    local sk = specialKeys[selIdx]
    if sk and sk.kind == "space" then
      if #ctx.textInputValue < ctx.textInputMaxLen then
        ctx.textInputValue = ctx.textInputValue:sub(1, ctx.textInputCursor - 1) ..
            " " .. ctx.textInputValue:sub(ctx.textInputCursor)
        ctx.textInputCursor = ctx.textInputCursor + 1
      end
    else
      local ch = keyList[selIdx]
      -- Safety guard: on-screen keyboard must never insert BEL control bytes.
      if ch and ch ~= BEL and #ctx.textInputValue < ctx.textInputMaxLen then
        ctx.textInputValue = ctx.textInputValue:sub(1, ctx.textInputCursor - 1) ..
            ch .. ctx.textInputValue:sub(ctx.textInputCursor)
        ctx.textInputCursor = ctx.textInputCursor + 1
      end
    end
  end
  if belEnabled and (not ctx[belMenuOpenKey]) and (_.padEffective & _.PAD_SELECT) ~= 0 then
    ctx[belMenuOpenKey] = true
    ctx[belMenuClosingKey] = nil
    ctx[belMenuAnimKey] = 0
    ctx.textInputBelPage = 1
    ctx.textInputBelMenuSel = ctx.textInputBelMenuSel or 1
    ctx.textInputBelMenuScroll = ctx.textInputBelMenuScroll or 0
  end
  if (_.padEffective & _.PAD_START) ~= 0 then
    local submitValue = tostring(ctx.textInputValue or "")
    if ctx.textInputAllowBelAdd ~= true then
      submitValue = clampBelCharsToBaseline(submitValue, ctx.textInputBelBaseline or "")
    end
    ctx.textInputCallback(submitValue)
    resetTextInputRuntime(ctx, true)
    -- Callback sets ctx.state (e.g. applyManualPath -> entry_paths); do not overwrite
  end
  if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
    resetTextInputRuntime(ctx, true)
    ctx.state = ctx.textInputReturnState or "menu_entry_edit"
  end
  if (_.padEffective & _.PAD_TRIANGLE) ~= 0 and not ctx.textInputTitleIdMode then
    ctx.textInputShift = not ctx
        .textInputShift
  end
  local backspaceMask = _.padEffective | getTextInputBackspaceHoldRepeatMask(ctx, _, nominalFps)
  if (backspaceMask & _.PAD_SQUARE) ~= 0 then
    if ctx.textInputCursor > 1 then
      ctx.textInputValue = ctx.textInputValue:sub(1, ctx.textInputCursor - 2) ..
          ctx.textInputValue:sub(ctx.textInputCursor)
      ctx.textInputCursor = ctx.textInputCursor - 1
    end
  end
  local hints = (ctx.textInputTitleIdMode and _.text_str.hint_items_title_id) or _.text_str.hint_items
  local suppressCrossEnter = suppressPressVisualsForFrame or pressAnimEntryGateActive or
      (ctx.textInputIgnoreCrossUntilRelease == true)
  local logicalEnterPad = (_.common and _.common.remapCrossCirclePadName and _.common.remapCrossCirclePadName("cross")) or "cross"
  _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, hints, nil, _.DIM_COLOR, _.w - 2 * _.MARGIN_X, {
    getIconPressAmount = function(padName)
      if suppressPressVisualsForFrame or pressAnimEntryGateActive then
        return 0
      end
      local key = tostring(padName or ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()
      if suppressCrossEnter and key == tostring(logicalEnterPad):lower() then
        return 0
      end
      if _.common and _.common.getHintPadPressAmount then
        return _.common.getHintPadPressAmount(key)
      end
      return 0
    end,
  })
  local shoulderHints = hints
  if belEnabled then
    shoulderHints = {}
    for i = 1, #(hints or {}) do
      shoulderHints[#shoulderHints + 1] = hints[i]
    end
    shoulderHints[#shoulderHints + 1] = { pad = "select", label = glyphKeyLabel, row = 2 }
  end
  drawKeyboardShoulderHints(ctx, _, shoulderHints, 0.7, _.w - 2 * _.MARGIN_X, _.DIM_COLOR)
end

local function drawShoulderHints(ctx, _, hintItems, scale, totalWidth, color)
  drawKeyboardShoulderHints(ctx, _, hintItems or {}, scale or 0.7, totalWidth, color)
end

return {
  run = run,
  drawShoulderHints = drawShoulderHints,
}
