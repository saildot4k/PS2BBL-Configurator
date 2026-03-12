--[[ Shared eGSM picker for argument insertion. ]]

local arg_gsm_picker = {}

local VIDEO_LABEL_KEYS = { "video_240p", "video_480p", "video_1080i_1x", "video_1080i_2x", "video_1080i_3x" }
local COMPAT_LABEL_KEYS = { "compat_none", "compat_1", "compat_2", "compat_3" }
local NUM_VIDEO_OPTS = 5
local NUM_COMPAT_OPTS = 4

local function egsmStrings(_)
  return (_ and _.strings and _.strings.egsm) or {}
end

local function trimText(s)
  return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

function arg_gsm_picker.buildArg(_, argKey, videoIdx, compatIdx)
  if not (_ and _.config_parse and _.config_parse.buildEgsmValue) then return nil end
  local value = _.config_parse.buildEgsmValue(videoIdx, compatIdx)
  if type(value) ~= "string" or value == "" then return nil end
  local key = trimText(argKey or "-gsm")
  if key == "" then key = "-gsm" end
  return key .. "=" .. value
end

function arg_gsm_picker.clearState(ctx, keys)
  if type(ctx) ~= "table" or type(keys) ~= "table" then return end
  ctx[keys.openKey] = nil
  ctx[keys.selKey] = nil
  ctx[keys.videoKey] = nil
  ctx[keys.compatKey] = nil
  ctx[keys.argKeyKey] = nil
  if keys.lastVideoKey then ctx[keys.lastVideoKey] = nil end
  if keys.editIdxKey then ctx[keys.editIdxKey] = nil end
end

local function normalizeVideoIdx(videoIdx)
  local vi = math.floor(tonumber(videoIdx) or 0)
  if vi >= 2 and vi <= 6 then return vi end
  return nil
end

local function normalizeCompatIdx(compatIdx)
  local ci = math.floor(tonumber(compatIdx) or 1)
  if ci < 1 or ci > NUM_COMPAT_OPTS then ci = 1 end
  return ci
end

function arg_gsm_picker.open(ctx, keys, argKey, initialVideoIdx, initialCompatIdx)
  if type(ctx) ~= "table" or type(keys) ~= "table" then return end
  arg_gsm_picker.clearState(ctx, keys)
  local videoIdx = normalizeVideoIdx(initialVideoIdx)
  local compatIdx = normalizeCompatIdx(initialCompatIdx)
  ctx[keys.openKey] = true
  ctx[keys.selKey] = videoIdx and (NUM_VIDEO_OPTS + compatIdx) or 1
  ctx[keys.videoKey] = videoIdx
  ctx[keys.compatKey] = compatIdx
  if keys.lastVideoKey then
    ctx[keys.lastVideoKey] = videoIdx or 2
  end
  local key = trimText(argKey or "-gsm")
  if key == "" then key = "-gsm" end
  ctx[keys.argKeyKey] = key
end

function arg_gsm_picker.parseExistingGsmArg(_, rawArg)
  local s = trimText(rawArg)
  if s == "" then return nil end

  local value = s:match("^%-[Gg][Ss][Mm]%s*=%s*(.-)%s*$")
  if not value then return nil end

  local vi, ci = 1, 1
  if _ and _.config_parse and _.config_parse.parseEgsmValue then
    vi, ci = _.config_parse.parseEgsmValue(value)
  end
  vi = normalizeVideoIdx(vi)
  ci = normalizeCompatIdx(ci)
  return "-gsm", vi, ci
end

local function fitLabel(ctx, keyPrefix, text, selected)
  local _ = ctx._
  local maxLabelW = (_.w or 640) - (_.MARGIN_X + 24) - _.MARGIN_X
  local out = text
  if _.common.fitListRowText then
    out = _.common.fitListRowText(ctx, keyPrefix, _.font, out, maxLabelW, _.FONT_SCALE, selected)
  elseif _.common.truncateTextToWidth then
    out = _.common.truncateTextToWidth(_.font, out, maxLabelW, _.FONT_SCALE)
  end
  return out
end

function arg_gsm_picker.run(ctx, opts)
  if type(ctx) ~= "table" then return false end
  local _ = ctx._
  if type(opts) ~= "table" or type(opts.keys) ~= "table" then return false end
  local keys = opts.keys
  if not ctx[keys.openKey] then return false end

  local s = egsmStrings(_)
  local videoOpts = (_.config_parse and _.config_parse.getEgsmVideoOptions and _.config_parse.getEgsmVideoOptions()) or {}
  local compatOpts = (_.config_parse and _.config_parse.getEgsmCompatOptions and _.config_parse.getEgsmCompatOptions()) or {}

  local total = NUM_VIDEO_OPTS + NUM_COMPAT_OPTS
  local videoIdx = normalizeVideoIdx(ctx[keys.videoKey])
  local compatIdx = normalizeCompatIdx(ctx[keys.compatKey])
  local hasVideo = (videoIdx ~= nil)
  local selectableTotal = hasVideo and total or NUM_VIDEO_OPTS
  local sel = math.floor(tonumber(ctx[keys.selKey]) or 1)
  if sel < 1 then sel = 1 end
  if sel > selectableTotal then sel = selectableTotal end
  ctx[keys.selKey] = sel
  if keys.lastVideoKey and sel >= 1 and sel <= NUM_VIDEO_OPTS then
    ctx[keys.lastVideoKey] = sel + 1
  end

  _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1, s.value_edit_title or "eGSM value", _.WHITE)
  local preview = (_.config_parse and _.config_parse.buildEgsmValue and _.config_parse.buildEgsmValue(videoIdx, compatIdx)) or ""
  _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y + _.scaleY(22), 0.85,
    (s.result_prefix or "Value: ") .. ((preview == "" and "—") or preview), _.GRAY)

  local startY = _.MARGIN_Y + _.scaleY(50)
  local row = 0

  local videoHeader = s.video_header or "Video mode"
  _.drawText(_.font, _.drawMode, _.common.centerX(_, _.common.calcTextWidth(_.font, videoHeader, 0.85)),
    startY + row * _.LINE_H, 0.85, videoHeader, _.DIM)
  row = row + 1

  for i = 1, NUM_VIDEO_OPTS do
    local label = s[VIDEO_LABEL_KEYS[i]] or tostring(videoOpts[i + 1] or "")
    if label == "" then label = tostring(videoOpts[i + 1] or "") end
    local isCur = (sel == i)
    local isActive = (videoIdx == (i + 1))
    label = fitLabel(ctx, (keys.rowStateKeyPrefix or "arg_gsm_picker_row_") .. "video_" .. tostring(i), label, isCur)
    local y = startY + row * _.LINE_H
    _.drawListRow(_.MARGIN_X + 20, y, isCur, label, (isCur and _.SELECTED_ENTRY) or (isActive and _.WHITE) or _.GRAY)
    if isActive then
      _.drawText(_.font, _.drawMode, _.VALUE_X, y, _.FONT_SCALE, "✓", _.GRAY)
    end
    row = row + 1
  end

  local compatHeader = s.compat_header or "Compatibility"
  _.drawText(_.font, _.drawMode, _.common.centerX(_, _.common.calcTextWidth(_.font, compatHeader, 0.85)),
    startY + row * _.LINE_H, 0.85, compatHeader, _.DIM)
  row = row + 1

  local compatDim = not hasVideo
  for i = 1, NUM_COMPAT_OPTS do
    local label = s[COMPAT_LABEL_KEYS[i]] or tostring(compatOpts[i] or "")
    if label == "" then label = s.compat_none or "None" end
    local rowSel = NUM_VIDEO_OPTS + i
    local isCur = (sel == rowSel)
    local isActive = (compatIdx == i)
    label = fitLabel(ctx, (keys.rowStateKeyPrefix or "arg_gsm_picker_row_") .. "compat_" .. tostring(i), label, isCur)
    local y = startY + row * _.LINE_H
    local col = compatDim and _.DIM or ((isCur and _.SELECTED_ENTRY) or (isActive and _.WHITE) or _.GRAY)
    _.drawListRow(_.MARGIN_X + 20, y, isCur, label, col)
    if isActive and hasVideo then
      _.drawText(_.font, _.drawMode, _.VALUE_X, y, _.FONT_SCALE, "✓", _.GRAY)
    end
    row = row + 1
  end

  _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7,
    s.value_edit_hint or { { pad = "cross", label = "Select", row = 1 }, { pad = "circle", label = "Back", row = 1 } },
    nil, _.DIM, _.w - 2 * _.MARGIN_X)

  if (_.padEffective & _.PAD_UP) ~= 0 then
    sel = sel - 1
    if sel < 1 then sel = selectableTotal end
    ctx[keys.selKey] = sel
    if keys.lastVideoKey and sel >= 1 and sel <= NUM_VIDEO_OPTS then
      ctx[keys.lastVideoKey] = sel + 1
    end
  end
  if (_.padEffective & _.PAD_DOWN) ~= 0 then
    sel = sel + 1
    if sel > selectableTotal then sel = 1 end
    ctx[keys.selKey] = sel
    if keys.lastVideoKey and sel >= 1 and sel <= NUM_VIDEO_OPTS then
      ctx[keys.lastVideoKey] = sel + 1
    end
  end

  if (_.padEffective & _.PAD_CROSS) ~= 0 then
    if sel >= 1 and sel <= NUM_VIDEO_OPTS then
      videoIdx = sel + 1
      ctx[keys.videoKey] = videoIdx
      ctx[keys.compatKey] = compatIdx
      ctx[keys.selKey] = NUM_VIDEO_OPTS + 1
      return true
    end

    if sel > NUM_VIDEO_OPTS then
      if not hasVideo then
        local fallbackVideo = normalizeVideoIdx(keys.lastVideoKey and ctx[keys.lastVideoKey] or nil) or 2
        videoIdx = fallbackVideo
        ctx[keys.videoKey] = videoIdx
        hasVideo = true
      end
      compatIdx = sel - NUM_VIDEO_OPTS
      ctx[keys.compatKey] = compatIdx
      local arg = arg_gsm_picker.buildArg(_, ctx[keys.argKeyKey], videoIdx, compatIdx)
      local editIdx = keys.editIdxKey and ctx[keys.editIdxKey] or nil
      arg_gsm_picker.clearState(ctx, keys)
      if arg and arg ~= "" and opts.onSubmit then
        opts.onSubmit(arg, editIdx)
      elseif opts.onCancel then
        opts.onCancel(editIdx)
      end
      return true
    end
  end

  if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
    local editIdx = keys.editIdxKey and ctx[keys.editIdxKey] or nil
    arg_gsm_picker.clearState(ctx, keys)
    if opts.onCancel then opts.onCancel(editIdx) end
    return true
  end

  return true
end

return arg_gsm_picker
