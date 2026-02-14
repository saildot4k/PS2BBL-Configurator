--[[
  Shared constants, colors, font, and helpers for configurator UI.
  No dependency on main loop state.
]]

local common                       = {}

-- Pad bits
common.PAD_UP                      = 0x0010
common.PAD_DOWN                    = 0x0040
common.PAD_LEFT                    = 0x0080
common.PAD_RIGHT                   = 0x0020
common.PAD_CROSS                   = 0x4000
common.PAD_CIRCLE                  = 0x2000
common.PAD_SELECT                  = 0x0001
common.PAD_START                   = 0x0008
common.PAD_TRIANGLE                = 0x1000
common.PAD_SQUARE                  = 0x8000
common.PAD_L1, common.PAD_R1       = 0x0400, 0x0800
common.PAD_L2, common.PAD_R2       = 0x0100, 0x0200

-- Colors
common.WHITE                       = Color.new(255, 255, 255)
common.GRAY                        = Color.new(160, 160, 160)
common.DIM                         = Color.new(96, 96, 96)
common.BGCOLOR                     = Color.new(20, 20, 20)
common.HIGHLIGHT                   = Color.new(255, 220, 100)
common.SELECTED_ENTRY              = Color.new(0x00, 0x72, 0xA0)
common.SELECTED_ENTRY_DIM          = Color.new(0, 50, 80)
common.TEXT_CURSOR_COLOR           = Color.new(0x00, 0x72, 0xA0)
common.PREFIX_W                    = 16

-- Layout
common.FONT_SCALE                  = 0.9
common.LINE_H                      = 22
common.ROW_H                       = 24
common.MARGIN_X, common.MARGIN_Y   = 40, 28
common.DEFAULT_W, common.DEFAULT_H = 640, 448
common.MAX_VISIBLE                 = 10
common.MAX_VISIBLE_LIST            = 12  -- menu entries, path picker, entry paths, entry args, eGSM editor
common.DIM_ENTRY                   = Color.new(56, 56, 56) -- darker than DIM for disabled list rows
common.VALUE_X                     = 360
common.VALUE_MAX_LEN               = 38
common.VALUE_MAX_LEN_LONG          = 22
common.HINT_Y                      = 424

-- Pad button hint icons (System/textures/*.png). Layout for icon+label.
common.PAD_ICON_W                  = 26
common.PAD_ICON_H                  = 26
common.PAD_HINT_GAP                = 5
common.PAD_HINT_GROUP_GAP          = 20
common.PAD_HINT_ROW_H              = 28
common.PAD_HINT_ROW_GAP            = 6
common.PAD_HINT_SIDE_MARGIN        = 16
common.PAD_HINT_ITEM_GAP           = 20
common.PAD_HINT_TOTAL_H            = common.PAD_HINT_ROW_H * 2 + common.PAD_HINT_ROW_GAP  -- height when 2 rows
common.DESC_TO_HINT_MARGIN         = 20
common.DESC_Y_BOTTOM               = common.HINT_Y - common.PAD_HINT_TOTAL_H - common.DESC_TO_HINT_MARGIN
common.PAD_HINT_DEFAULT_WIDTH      = 560
common.PAD_HINT_MAX_PER_ROW        = 4
local padIconCache                 = {}
local padIconNames                 = {
  up = "up",
  down = "down",
  left = "left",
  right = "right",
  cross = "cross",
  circle =
  "circle",
  square = "square",
  triangle = "triangle",
  start = "start",
  select = "select",
  l1 = "L1",
  l2 = "L2",
  l3 = "L3",
  r1 = "R1",
  r2 = "R2",
  r3 = "R3"
}

function common.getPadIcon(name)
  if not name then return nil end
  local key = name:lower()
  local file = padIconNames[key] or key
  if padIconCache[file] == nil then
    local ok, img = pcall(Graphics.loadImage, "scripts/textures/" .. file .. ".png")
    if ok and img and Graphics.setImageFilters and LINEAR then
      pcall(Graphics.setImageFilters, img, LINEAR)
    end
    padIconCache[file] = (ok and img) and img or false
  end
  return (padIconCache[file] ~= false) and padIconCache[file] or nil
end

-- Draw a hint line: list of { pad = "cross", label = "Select" [, row = 1|2 ] }. Uses pad textures when available; else falls back to text.
-- row: 1 = bottom row, 2 = top row. If any item has row=2, rows are from lang; else first PAD_HINT_MAX_PER_ROW on bottom, rest on top.
-- totalWidth: optional. y = bottom of hint area. Full width (minus side margin) divided into equal slots. Odd: icon+label centered in slot. Even: left half left-aligned, right half right-aligned. Uses Font.ftCalcDimensions when available for accurate text width.
function common.drawHintLine(font, drawMode, x, y, scale, hintItems, textFallback, color, totalWidth)
  if not color then color = common.DIM end
  if hintItems and #hintItems > 0 then
    local iconW, gap = common.PAD_ICON_W, common.PAD_HINT_GAP
    local rowH = common.PAD_HINT_ROW_H
    local approxCharW = math.floor(8 * (scale or 0.7))
    -- Use font pixel height for vertical alignment with icons (same as FT_PIXEL_H)
    local textH = common.FT_PIXEL_H or 18
    local n = #hintItems
    local width = (type(totalWidth) == "number" and totalWidth > 0) and totalWidth or common.PAD_HINT_DEFAULT_WIDTH
    local maxPerRow = common.PAD_HINT_MAX_PER_ROW or 4
    local sideMargin = common.PAD_HINT_SIDE_MARGIN or 0
    local xEff = x + sideMargin
    local widthEff = width - 2 * sideMargin
    local centerX = xEff + widthEff / 2
    local function getTextWidth(label)
      if not label or label == "" then return 0 end
      if drawMode == "ftPrint" and font and Font and Font.ftCalcDimensions then
        local w = Font.ftCalcDimensions(font, label)
        return (type(w) == "number" and w > 0) and w or math.floor(approxCharW * #label)
      end
      return math.floor(approxCharW * #label)
    end
    local groupWidths = {}
    for i = 1, n do
      local item = hintItems[i]
      local label = (item and item.label) or ""
      groupWidths[i] = iconW + gap + getTextWidth(label)
    end
    local bottomIndices, topIndices = {}, {}
    local hasExplicitRow = false
    for i = 1, n do
      if hintItems[i] and hintItems[i].row == 2 then
        hasExplicitRow = true; topIndices[#topIndices + 1] = i
      else
        bottomIndices[#bottomIndices + 1] = i
      end
    end
    if not hasExplicitRow then
      bottomIndices = {}
      topIndices = {}
      local bottomCount = (n <= maxPerRow) and n or maxPerRow
      for i = 1, bottomCount do bottomIndices[i] = i end
      for i = bottomCount + 1, n do topIndices[#topIndices + 1] = i end
    end
    local rowCount = (#topIndices > 0 and #bottomIndices > 0) and 2 or 1
    local rowGap = (rowCount > 1) and (common.PAD_HINT_ROW_GAP or 0) or 0
    local totalRowH = rowH * rowCount + rowGap * (rowCount - 1)
    local rowTop = math.floor(y) - totalRowH
    local function drawRow(indices, rowIndex)
      if not indices or #indices == 0 then return end
      local numInRow = #indices
      local slotW = widthEff / numInRow
      local rowLeft = (numInRow % 2 == 1) and (centerX - (numInRow * slotW) / 2) or xEff
      local rTop = rowTop + rowIndex * (rowH + rowGap)
      local textY = rTop + math.floor((rowH - textH) / 2)
      -- Align icon vertical center with text vertical center
      local iconY = textY + math.floor((textH - common.PAD_ICON_H) / 2)
      local leftCount = math.floor(numInRow / 2)
      for idx = 1, numInRow do
        local j = indices[idx]
        local item = hintItems[j]
        local padName = item and item.pad
        local label = (item and item.label) or ""
        local icon = common.getPadIcon(padName)
        local groupW = groupWidths[j]
        local slotLeft = rowLeft + (idx - 1) * slotW
        local px
        if numInRow % 2 == 1 then
          px = math.floor(slotLeft + (slotW - groupW) / 2)
        elseif idx <= leftCount then
          px = math.floor(slotLeft)
        else
          px = math.floor(slotLeft + slotW - groupW)
        end
        if icon then
          if Graphics.drawScaleImage then
            Graphics.drawScaleImage(icon, px, iconY, iconW, common.PAD_ICON_H)
          else
            Graphics.drawImage(icon, px, iconY)
          end
          common.drawText(font, drawMode, px + iconW + gap, textY, scale, label, color)
        else
          common.drawText(font, drawMode, px, textY, scale, (padName or "") .. (label ~= "" and "=" .. label or ""),
            color, textH)
        end
      end
    end
    if rowCount == 2 then
      drawRow(topIndices, 0)
      drawRow(bottomIndices, 1)
    else
      drawRow(#bottomIndices > 0 and bottomIndices or topIndices, 0)
    end
    return
  end
  if textFallback and textFallback ~= "" then
    local rowTop = math.floor(y) - common.PAD_HINT_ROW_H
    common.drawText(font, drawMode, x, rowTop + math.floor((common.PAD_HINT_ROW_H - 16) / 2), scale, textFallback, color)
  end
end

-- Build editor hint items: show ±1/±10/±50 only for int/string (enum: left/right only with enumHintLabels). Show Reset only when option has default.
function common.buildEditorHintItems(selOpt, hintEditItems, getDefaultFn, enumHintLabels)
  if not hintEditItems or #hintEditItems == 0 then return hintEditItems end
  local numericPads = { left = true, right = true, L1 = true, R1 = true, L2 = true, R2 = true }
  local showNumeric = selOpt and (selOpt.optType == "int" or selOpt.optType == "string" or selOpt.optType == "enum")
  local showReset = selOpt and selOpt.key and selOpt.key:sub(1, 1) ~= "_" and selOpt.optType ~= "header" and getDefaultFn and
      getDefaultFn(selOpt.key) ~= nil
  local out = {}
  for _, item in ipairs(hintEditItems) do
    local pad = (item.pad or ""):lower()
    if pad == "l1" or pad == "r1" or pad == "l2" or pad == "r2" then pad = pad:upper() end
    if numericPads[pad] then
      if showNumeric and (selOpt.optType ~= "enum" or pad == "left" or pad == "right") then
        local toInsert = item
        if selOpt.optType == "enum" and (pad == "left" or pad == "right") and enumHintLabels and enumHintLabels[pad] then
          toInsert = { pad = item.pad, label = enumHintLabels[pad], row = item.row }
        end
        table.insert(out, toInsert)
      end
    elseif pad == "triangle" then
      if showReset then table.insert(out, item) end
    else
      table.insert(out, item)
    end
  end
  return out
end

-- Keyboard: full QWERTY rows 1-=, q-], a-', z-/
common.KEYBOARD_ROWS = { "1234567890-=", "qwertyuiop[]", "asdfghjkl;'", "zxcvbnm,./" }
common.KEYBOARD_ROWS_SHIFTED = { "!@#$%^&*()_+", "QWERTYUIOP{}", "ASDFGHJKL:\"", "ZXCVBNM<>?" }
-- Title ID only: digits + uppercase letters, no shift (e.g. eGSM AAAA_000.00). No symbols.
common.KEYBOARD_ROWS_TITLE_ID = { "1234567890", "QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM" }
common.KEYBOARD_CENTER_X, common.KEYBOARD_CENTER_Y = 320, 220
common.KEY_WIDTH, common.KEY_HEIGHT = 34, 26
common.KEY_GAP = 2
common.KEY_BG = Color.new(56, 56, 56)
common.KEY_BG_SEL = Color.new(80, 80, 80)
common.KEY_BORDER = Color.new(100, 100, 100)
common.KEY_BORDER_SEL = Color.new(180, 160, 100)
common.KEY_CHAR_W = 10
common.KEY_LINE_H = 14

common.FT_PIXEL_H = 18
common.FT_DRAW_W, common.FT_DRAW_H = 620, 24

function common.tryOpen(path)
  local h = System.openFile(path, 0)
  if h and h >= 0 then
    System.closeFile(h); return true
  end
  return false
end

function common.isHddPresent()
  if not System or not System.listDirectory then return false end
  local ok, list = pcall(function() return System.listDirectory("hdd0:") end)
  return ok and type(list) == "table"
end

function common.getPresentMcSlots()
  local out = {}
  if common.tryOpen("mc0:/") then table.insert(out, 0) end
  if common.tryOpen("mc1:/") then table.insert(out, 1) end
  table.sort(out)
  return out
end

function common.findExistingPaths(locations)
  local out = {}
  for _, p in ipairs(locations) do
    if common.tryOpen(p) then table.insert(out, p) end
  end
  return out
end

function common.listDirectoryElfOnly(path, file_selector)
  local raw = file_selector.listDirectory(path) or {}
  local out = {}
  for _, e in ipairs(raw) do
    if e.directory then
      table.insert(out, e)
    else
      local name = e.name or ""
      if name:sub(-4):lower() == ".elf" then
        table.insert(out, e)
      end
    end
  end
  return out
end

local PAD_UP, PAD_DOWN, PAD_LEFT, PAD_RIGHT = 0x0010, 0x0040, 0x0080, 0x0020
local PAD_L1, PAD_R1, PAD_L2, PAD_R2 = 0x0400, 0x0800, 0x0100, 0x0200
common.REPEATABLE_MASK = PAD_UP | PAD_DOWN | PAD_LEFT | PAD_RIGHT | PAD_L1 | PAD_R1 | PAD_L2 | PAD_R2

-- Update ctx with layout values from current screen mode (for scene runner).
function common.runLayout(ctx)
  local vmode = Screen.getMode()
  local w = (vmode and vmode.width) or common.DEFAULT_W
  local h = (vmode and vmode.height) or common.DEFAULT_H
  local sy = h / common.DEFAULT_H
  if ctx then
    ctx.sy = sy
    ctx.MARGIN_Y = math.floor(common.MARGIN_Y * sy)
    ctx.LINE_H = common.LINE_H
    ctx.ROW_H = common.ROW_H
    ctx.HINT_Y = h - math.floor(24 * sy)
    ctx.DESC_Y_BOTTOM = ctx.HINT_Y - common.PAD_HINT_TOTAL_H - common.DESC_TO_HINT_MARGIN
    ctx.scaleY = function(y) return math.floor((y or 0) * sy) end
  end
end

-- Shared scene loop: clear, layout, getPadEffective, runHandler(ctx, pad), exit when ctx.state ~= sceneName.
function common.runSceneLoop(ctx, sceneName, runHandler)
  while true do
    Screen.clear(common.BGCOLOR)
    common.runLayout(ctx)
    local padEffective = common.getPadEffective(ctx)
    runHandler(ctx, padEffective)
    if ctx.state ~= sceneName then
      return ctx.state, ctx
    end
    Screen.flip()
    Screen.waitVblankStart()
  end
end

-- Get pad with repeat logic; updates ctx.prevPad and ctx.holdFrameCount. Returns padEffective.
function common.getPadEffective(ctx)
  local pad = Pads.get(0)
  local padJust = pad & ~(ctx.prevPad or 0)
  local fps = (Screen.getMode() and Screen.getMode().height == 512) and 50 or 60
  local REPEAT_DELAY_FRAMES = math.ceil(fps / 3)
  ctx.holdFrameCount = ctx.holdFrameCount or 0
  local padRepeat = 0
  if (pad & common.REPEATABLE_MASK) ~= 0 then
    ctx.holdFrameCount = ctx.holdFrameCount + 1
    if ctx.holdFrameCount >= REPEAT_DELAY_FRAMES then
      padRepeat = pad & common.REPEATABLE_MASK
      ctx.holdFrameCount = 0
    end
  else
    ctx.holdFrameCount = 0
  end
  ctx.prevPad = pad
  return padJust | padRepeat
end

function common.loadCustomFont()
  Font.ftInit()
  -- CWD first (user override)
  local f = Font.ftLoad("font.ttf")
  if f and f >= 0 then
    Font.ftSetPixelSize(f, 0, common.FT_PIXEL_H)
    return f, "ftPrint"
  end
  -- Try known font path inside the scripts directory (including VFS)
  f = Font.ftLoad("scripts/font/font.ttf")
  if f and f >= 0 then
    Font.ftSetPixelSize(f, 0, common.FT_PIXEL_H)
    return f, "ftPrint"
  end
  error("Failed to load font")
end

-- Approximate width of text for centering. Uses Font.ftCalcDimensions when available (ftPrint).
function common.calcTextWidth(font, text, scale)
  if not text or text == "" then return 0 end
  local s = scale or 0.72
  local approxCharW = math.floor(8 * s)
  if font and Font and Font.ftCalcDimensions then
    local w = Font.ftCalcDimensions(font, text)
    return (type(w) == "number" and w > 0) and w or math.floor(approxCharW * #text)
  end
  return math.floor(approxCharW * #text)
end

function common.drawText(font, mode, x, y, scale, text, color, drawHeight)
  local c = color or common.WHITE
  local ix, iy = math.floor(tonumber(x) or 0), math.floor(tonumber(y) or 0)
  local s = text or ""
  if mode == "fmPrint" then
    Font.fmPrint(ix, iy, scale, s, c)
  elseif mode == "ftPrint" then
    local w = (_G.CONFIG_UI and _G.CONFIG_UI.currentDrawWidth) or common.FT_DRAW_W
    local h = (drawHeight and drawHeight > 0) and drawHeight or (_G.CONFIG_UI and _G.CONFIG_UI.currentDrawHeight) or
        common.FT_DRAW_H
    Font.ftPrint(font, ix, iy, 0, w, h, s, c)
  else
    Font.print(font, ix, iy, scale, s, c)
  end
end

function common.parseColor(value)
  local r, g, b, a = 0, 0, 0, 128
  if value and value ~= "" then
    local h1, h2, h3, h4 = value:match("0x([%x]+)%s*,%s*0x([%x]+)%s*,%s*0x([%x]+)%s*,%s*0x([%x]+)")
    if h1 then r = math.max(0, math.min(255, tonumber(h1, 16) or 0)) end
    if h2 then g = math.max(0, math.min(255, tonumber(h2, 16) or 0)) end
    if h3 then b = math.max(0, math.min(255, tonumber(h3, 16) or 0)) end
    if h4 then a = math.max(0, math.min(255, tonumber(h4, 16) or 128)) end
  end
  return r, g, b, a
end

function common.formatColor(r, g, b, a)
  local function hex(n) return string.format("0x%02X", math.max(0, math.min(255, n))) end
  return hex(r or 0) .. "," .. hex(g or 0) .. "," .. hex(b or 0) .. "," .. hex(a or 128)
end

-- Map parse.save/load error string to localized editor string when available.
function common.localizeParseError(err, editor_str)
  if not err or not editor_str then return err end
  if err == "write failed" then return editor_str.error_write_failed end
  if err == "read failed" then return editor_str.error_read_failed end
  if err == "cannot get size" then return editor_str.error_cannot_get_size end
  local p1, p2 = err:match("^(cannot open for write )(.*)$")
  if p1 then return (editor_str.error_cannot_open_for_write or p1) .. p2 end
  p1, p2 = err:match("^(cannot open )(.*)$")
  if p1 then return (editor_str.error_cannot_open or p1) .. p2 end
  return err
end

-- Horizontal center for text (c = context with .w and .MARGIN_X).
function common.centerX(c, textWidth)
  local w = (c and c.w) or common.DEFAULT_W
  local mx = (c and c.MARGIN_X) or common.MARGIN_X
  return math.max(mx, math.floor((w - textWidth) / 2))
end

-- Draw "Saved." splash; decrement ctx.saveFlash. Returns true when flash finished and returnToSelectConfigAfterSaveFlash is set.
function common.drawSavedSplash(ctx)
  if not ctx.saveFlash or ctx.saveFlash <= 0 then return false end
  local _ = ctx._
  local msg = _.editor_str.saved
  local tw = common.calcTextWidth(_.font, msg, 1) or (#msg * 12)
  common.drawText(_.font, _.drawMode, common.centerX(_, tw),
    math.floor(((_.h or common.DEFAULT_H) / 2) - ((_.LINE_H or common.LINE_H) / 2)), 1, msg, _.HIGHLIGHT)
  ctx.saveFlash = ctx.saveFlash - 1
  return (ctx.saveFlash == 0 and ctx.returnToSelectConfigAfterSaveFlash)
end

-- Draw save error line and detail (ctx.saveError).
function common.drawSaveError(ctx)
  if not ctx.saveError or ctx.saveError == "" then return end
  local _ = ctx._
  local msg = _.editor_str.save_failed
  local tw = common.calcTextWidth(_.font, msg, 0.9) or (#msg * 11)
  common.drawText(_.font, _.drawMode, common.centerX(_, tw), _.MARGIN_Y + _.scaleY(50), 0.9, msg, _.HIGHLIGHT)
  common.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y + _.scaleY(72), 0.75, tostring(ctx.saveError):sub(1, 50),
    _.GRAY)
end

return common
