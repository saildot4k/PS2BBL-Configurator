--[[ eGSM value edit: video mode + compatibility (per loader README v:c format).
  "Disabled" = don't force / no override (single option). Compatibility only applies when a video mode is set. ]]

local VIDEO_LABELS = { "video_240p", "video_480p", "video_1080i_1x", "video_1080i_2x", "video_1080i_3x" }  -- EGSM_VIDEO indices 2..6
local COMPAT_LABELS = { "compat_none", "compat_1", "compat_2", "compat_3" }
local NUM_VIDEO_OPTS = 5   -- fp1, fp2, 1080ix1, 1080ix2, 1080ix3 (no "don't force" - same as Disabled)
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
      cur = _.config_parse.getEgsmDefault(ctx.lines)
    else
      cur = "disabled"
      local entries = _.config_parse.getEgsmEntries(ctx.lines)
      for _, e in ipairs(entries) do
        if e.titleId == ctx.egsmEditTitleId then
          cur = (e.commented and "disabled") or e.value
          break
        end
      end
    end
    ctx.egsmVideoIdx, ctx.egsmCompatIdx = _.config_parse.parseEgsmValue(cur)
    ctx.egsmValueSel = 1
  end

  local total = 1 + NUM_VIDEO_OPTS + NUM_COMPAT_OPTS  -- Disabled + 5 video + 4 compat
  if ctx.egsmValueSel < 1 then ctx.egsmValueSel = 1 end
  if ctx.egsmValueSel > total then ctx.egsmValueSel = total end

  local videoOpts = _.config_parse.getEgsmVideoOptions()
  local compatOpts = _.config_parse.getEgsmCompatOptions()
  local hasVideo = (ctx.egsmVideoIdx and ctx.egsmVideoIdx > 1)

  local titleLabel = ctx.egsmEditDefault and _.strings.egsm.default_label or (ctx.egsmEditTitleId or "")
  _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1,
    _.strings.egsm.value_edit_title .. " — " .. titleLabel, _.WHITE)

  local resultStr = _.config_parse.buildEgsmValue(ctx.egsmVideoIdx, ctx.egsmCompatIdx)
  if resultStr == "" then resultStr = _.strings.egsm.disabled end
  _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y + _.scaleY(22), 0.85,
    _.strings.egsm.result_prefix .. resultStr, _.GRAY)

  local startY = _.MARGIN_Y + _.scaleY(50)
  local row = 0
  local LINE_H = _.LINE_H

  -- Row 0: Disabled (same as "don't force" — no video override)
  local y = startY + row * LINE_H
  _.drawListRow(_.MARGIN_X + 20, y, ctx.egsmValueSel == 1, _.strings.egsm.disabled,
    (ctx.egsmValueSel == 1) and _.SELECTED_ENTRY or _.WHITE)
  row = row + 1

  -- Video section: 5 options only (indices 2..6 in EGSM_VIDEO; index 1 = don't force = Disabled)
  do
    local headerText = _.strings.egsm.video_header
    local tw = _.common.calcTextWidth(_.font, headerText, 0.85)
    local x = _.common.centerX(_, tw)
    _.drawText(_.font, _.drawMode, x, startY + row * LINE_H, 0.85, headerText, _.DIM)
  end
  row = row + 1
  for i = 1, NUM_VIDEO_OPTS do
    local vi = i + 1  -- EGSM_VIDEO index 2..6
    local key = VIDEO_LABELS[i] or ("video_" .. (i + 1))
    local label = _.strings.egsm[key] or videoOpts[vi] or ""
    local y = startY + row * LINE_H
    local selForThisRow = row  -- sel 2..6 for video rows 2..6
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
    local selForThisRow = row - 1  -- sel 7..10 for compat rows 8..11
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
    if ctx.egsmValueSel == 1 then
      -- Disabled (don't force) — same option
      if ctx.egsmEditDefault then
        _.config_parse.setEgsmDefault(ctx.lines, "disabled")
      else
        _.config_parse.setEgsmEntry(ctx.lines, ctx.egsmEditTitleId, "disabled", true)
      end
      ctx.configModified = true
      ctx.egsmVideoIdx = nil
      ctx.egsmCompatIdx = nil
      ctx.egsmEditDefault = nil
      ctx.egsmEditTitleId = nil
      ctx.state = "egsm_editor"
    elseif ctx.egsmValueSel >= 2 and ctx.egsmValueSel <= 1 + NUM_VIDEO_OPTS then
      local vi = ctx.egsmValueSel  -- sel 2..6 -> EGSM_VIDEO index 2..6 (fp1..1080ix3)
      ctx.egsmVideoIdx = vi
      local val = _.config_parse.buildEgsmValue(ctx.egsmVideoIdx, ctx.egsmCompatIdx)
      if ctx.egsmEditDefault then
        _.config_parse.setEgsmDefault(ctx.lines, val)
      else
        _.config_parse.setEgsmEntry(ctx.lines, ctx.egsmEditTitleId, val, false)
      end
      ctx.configModified = true
    elseif ctx.egsmValueSel > 1 + NUM_VIDEO_OPTS and ctx.egsmValueSel <= total and hasVideo then
      -- Compatibility: only apply when a video mode is set
      local ci = ctx.egsmValueSel - 1 - NUM_VIDEO_OPTS
      ctx.egsmCompatIdx = ci
      local val = _.config_parse.buildEgsmValue(ctx.egsmVideoIdx, ctx.egsmCompatIdx)
      if ctx.egsmEditDefault then
        _.config_parse.setEgsmDefault(ctx.lines, val)
      else
        _.config_parse.setEgsmEntry(ctx.lines, ctx.egsmEditTitleId, val, false)
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
