--[[ eGSM value edit: video mode + compatibility (per loader README v:c format).
  Enable/Disable is toggled in the main list; here we only edit the value. Compatibility only applies when a video mode is set. ]]

local VIDEO_LABELS = { "video_240p", "video_480p", "video_1080i_1x", "video_1080i_2x", "video_1080i_3x" } -- EGSM_VIDEO indices 2..6
local COMPAT_LABELS = { "compat_none", "compat_1", "compat_2", "compat_3" }
local NUM_VIDEO_OPTS = 5                                                                                  -- fp1, fp2, 1080ix1, 1080ix2, 1080ix3
local NUM_COMPAT_OPTS = 4

local function run(ctx)
  local _ = ctx._
  if not ctx.lines then
    ctx.state = "egsm_editor"
    return
  end

  -- One-time init when entering: parse current value into video/compat indices
  if ctx.egsmVideoIdx == nil then
    local cur
    if ctx.egsmEditDefault then
      cur = select(1, _.config_parse.getEgsmDefault(ctx.lines))
    else
      cur = ""
      local entries = _.config_parse.getEgsmEntries(ctx.lines)
      for _, e in ipairs(entries) do
        if e.titleId == ctx.egsmEditTitleId then
          cur = e.value
          break
        end
      end
    end
    ctx.egsmVideoIdx, ctx.egsmCompatIdx = _.config_parse.parseEgsmValue(cur)
    ctx.egsmValueSel = 1
    if ctx.egsmEditCommented == nil then ctx.egsmEditCommented = false end
  end

  local total = NUM_VIDEO_OPTS + NUM_COMPAT_OPTS -- 5 video + 4 compat
  if ctx.egsmValueSel < 1 then ctx.egsmValueSel = 1 end
  if ctx.egsmValueSel > total then ctx.egsmValueSel = total end

  local videoOpts = _.config_parse.getEgsmVideoOptions()
  local compatOpts = _.config_parse.getEgsmCompatOptions()
  local hasVideo = (ctx.egsmVideoIdx and ctx.egsmVideoIdx > 1)

  local titleLabel = ctx.egsmEditDefault and _.strings.egsm.default_label or (ctx.egsmEditTitleId or "")
  _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1,
    _.strings.egsm.value_edit_title .. " — " .. titleLabel, _.WHITE)

  local resultStr = _.config_parse.buildEgsmValue(ctx.egsmVideoIdx, ctx.egsmCompatIdx)
  _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y + _.scaleY(22), 0.85,
    _.strings.egsm.result_prefix .. (resultStr == "" and "—" or resultStr), _.GRAY)

  local startY = _.MARGIN_Y + _.scaleY(50)
  local row = 0
  local LINE_H = _.LINE_H

  -- Video section: 5 options (sel 1–5 -> EGSM_VIDEO indices 2–6)
  do
    local headerText = _.strings.egsm.video_header
    local tw = _.common.calcTextWidth(_.font, headerText, 0.85)
    local x = _.common.centerX(_, tw)
    _.drawText(_.font, _.drawMode, x, startY + row * LINE_H, 0.85, headerText, _.DIM)
  end
  row = row + 1
  for i = 1, NUM_VIDEO_OPTS do
    local vi = i + 1 -- EGSM_VIDEO index 2..6
    local key = VIDEO_LABELS[i] or ("video_" .. (i + 1))
    local label = _.strings.egsm[key] or videoOpts[vi] or ""
    local y = startY + row * LINE_H
    local selForThisRow = row -- sel 1..5 for video
    local isCur = (ctx.egsmValueSel == selForThisRow)
    local isActive = (ctx.egsmVideoIdx == vi)
    _.drawListRow(_.MARGIN_X + 20, y, isCur, label, (isCur and _.SELECTED_ENTRY) or (isActive and _.WHITE) or _.GRAY)
    if isActive then
      _.drawText(_.font, _.drawMode, _.VALUE_X, y, _.FONT_SCALE, "✓", _.GRAY)
    end
    row = row + 1
  end

  -- Compatibility section: only applies when a video mode is set (dim when none)
  do
    local headerText = _.strings.egsm.compat_header
    local tw = _.common.calcTextWidth(_.font, headerText, 0.85)
    local x = _.common.centerX(_, tw)
    _.drawText(_.font, _.drawMode, x, startY + row * LINE_H, 0.85, headerText, _.DIM)
  end
  row = row + 1
  local compatDim = not hasVideo
  for i = 1, NUM_COMPAT_OPTS do
    local key = COMPAT_LABELS[i] or ("compat_" .. i)
    local label = _.strings.egsm[key] or compatOpts[i] or ""
    if label == "" then label = _.strings.egsm.compat_none end
    local y = startY + row * LINE_H
    local selForThisRow = row - 1 -- sel 6..9 for compat
    local isCur = (ctx.egsmValueSel == selForThisRow)
    local isActive = (ctx.egsmCompatIdx == i)
    local col = compatDim and _.DIM or ((isCur and _.SELECTED_ENTRY) or (isActive and _.WHITE) or _.GRAY)
    _.drawListRow(_.MARGIN_X + 20, y, isCur, label, col)
    if isActive and hasVideo then
      _.drawText(_.font, _.drawMode, _.VALUE_X, y, _.FONT_SCALE, "✓", _.GRAY)
    end
    row = row + 1
  end

  _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7,
    _.strings.egsm.value_edit_hint, nil, _.DIM, _.w - 2 * _.MARGIN_X)

  if (_.padEffective & _.PAD_UP) ~= 0 then
    ctx.egsmValueSel = ctx.egsmValueSel - 1
    if ctx.egsmValueSel < 1 then ctx.egsmValueSel = total end
  end
  if (_.padEffective & _.PAD_DOWN) ~= 0 then
    ctx.egsmValueSel = ctx.egsmValueSel + 1
    if ctx.egsmValueSel > total then ctx.egsmValueSel = 1 end
  end

  if (_.padEffective & _.PAD_CROSS) ~= 0 then
    local commented = ctx.egsmEditCommented and true or false
    if ctx.egsmValueSel >= 1 and ctx.egsmValueSel <= NUM_VIDEO_OPTS then
      local vi = ctx.egsmValueSel + 1 -- sel 1..5 -> EGSM_VIDEO index 2..6
      ctx.egsmVideoIdx = vi
      local val = _.config_parse.buildEgsmValue(ctx.egsmVideoIdx, ctx.egsmCompatIdx)
      if ctx.egsmEditDefault then
        _.config_parse.setEgsmDefault(ctx.lines, val, commented)
      else
        _.config_parse.setEgsmEntry(ctx.lines, ctx.egsmEditTitleId, val, commented)
      end
      ctx.configModified = true
    elseif ctx.egsmValueSel > NUM_VIDEO_OPTS and ctx.egsmValueSel <= total and hasVideo then
      local ci = ctx.egsmValueSel - NUM_VIDEO_OPTS -- sel 6..9 -> compat index 1..4
      ctx.egsmCompatIdx = ci
      local val = _.config_parse.buildEgsmValue(ctx.egsmVideoIdx, ctx.egsmCompatIdx)
      if ctx.egsmEditDefault then
        _.config_parse.setEgsmDefault(ctx.lines, val, commented)
      else
        _.config_parse.setEgsmEntry(ctx.lines, ctx.egsmEditTitleId, val, commented)
      end
      ctx.configModified = true
    end
  end

  if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
    ctx.egsmVideoIdx = nil
    ctx.egsmCompatIdx = nil
    ctx.egsmEditDefault = nil
    ctx.egsmEditTitleId = nil
    ctx.state = "egsm_editor"
  end
end

return { run = run }
