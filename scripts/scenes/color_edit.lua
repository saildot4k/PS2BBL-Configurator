--[[ Color editor (RGBA channels). ]]

local function run(ctx)
  local _ = ctx._
  if ctx.colorOpt and ctx.colorVals and ctx.lines then
    local colorLabel = (_.strings.options and _.strings.options[ctx.colorOpt.key] and _.strings.options[ctx.colorOpt.key].label) or
        ctx.colorOpt.key
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1, colorLabel .. _.editor_str.edit_color_suffix, _.WHITE)
    local r, g, b, a = ctx.colorVals[1], ctx.colorVals[2], ctx.colorVals[3], ctx.colorVals[4]
    local rawStr = _.formatColor(r, g, b, a)
    local rawW = (_.common and _.common.calcTextWidth and _.common.calcTextWidth(_.font, rawStr, 0.8)) or (22 * #rawStr)
    local boxSize = math.max(40, math.min(220, rawW))
    local centerY = math.floor((_.MARGIN_Y + _.HINT_Y) / 2)
    local row0Y = centerY - 2 * _.LINE_H
    local rightBlockH = boxSize + 4 + _.LINE_H
    local previewTop = centerY - math.floor(rightBlockH / 2)
    local rightX = _.w - _.MARGIN_X - boxSize
    _.Graphics.drawRect(rightX, previewTop, boxSize, boxSize, _.Color.new(r, g, b, a))
    _.drawText(_.font, _.drawMode, rightX, previewTop + boxSize + 4, 0.8, rawStr, _.GRAY)
    local valueColRight = rightX - 48
    local chNames = { _.editor_str.red, _.editor_str.green, _.editor_str.blue, _.editor_str.alpha }
    for ch = 1, 4 do
      local y = row0Y + (ch - 1) * _.LINE_H
      local labelCol = (ch == ctx.colorCh) and _.SELECTED_ENTRY or _.WHITE
      local valCol = (ch == ctx.colorCh) and _.WHITE or _.GRAY
      _.drawListRow(_.MARGIN_X + 20, y, ch == ctx.colorCh, chNames[ch], labelCol)
      local valStr = string.format("%3d", ctx.colorVals[ch])
      local valW = (_.common and _.common.calcTextWidth and _.common.calcTextWidth(_.font, valStr, _.FONT_SCALE)) or
          (18 * #valStr)
      _.drawText(_.font, _.drawMode, valueColRight - valW, y, _.FONT_SCALE, valStr, valCol)
    end
    if (_.padEffective & _.PAD_UP) ~= 0 then
      ctx.colorCh = ctx.colorCh - 1; if ctx.colorCh < 1 then ctx.colorCh = 4 end
    end
    if (_.padEffective & _.PAD_DOWN) ~= 0 then
      ctx.colorCh = ctx.colorCh + 1; if ctx.colorCh > 4 then ctx.colorCh = 1 end
    end
    local delta = 0
    if (_.padEffective & _.PAD_RIGHT) ~= 0 then delta = 1 end
    if (_.padEffective & _.PAD_LEFT) ~= 0 then delta = -1 end
    if (_.padEffective & _.PAD_R1) ~= 0 then delta = 10 end
    if (_.padEffective & _.PAD_L1) ~= 0 then delta = -10 end
    if (_.padEffective & _.PAD_R2) ~= 0 then delta = 50 end
    if (_.padEffective & _.PAD_L2) ~= 0 then delta = -50 end
    if delta ~= 0 then
      ctx.colorVals[ctx.colorCh] = math.max(0, math.min(255, ctx.colorVals[ctx.colorCh] + delta))
    end
    if (_.padEffective & _.PAD_CROSS) ~= 0 then
      _.config_parse.set(ctx.lines, ctx.colorOpt.key,
        _.formatColor(ctx.colorVals[1], ctx.colorVals[2], ctx.colorVals[3], ctx.colorVals[4]))
      ctx.configModified = true
      ctx.state = "editor"
      ctx.colorOpt = nil
    end
    if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
      ctx.state = "editor"; ctx.colorOpt = nil
    end
    _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, _.editor_str.color_edit_hint_items, nil, _.DIM,
      _.w - 2 * _.MARGIN_X)
  else
    ctx.state = "editor"
  end
end

return { run = run }
