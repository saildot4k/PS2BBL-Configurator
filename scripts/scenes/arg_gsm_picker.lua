--[[ Shared eGSM picker helpers for profile-defined argument insertion. ]]

local arg_gsm_picker = {}

local VIDEO_LABEL_KEYS = {
  "video_240p",
  "video_480p",
  "video_1080i_1x",
  "video_1080i_2x",
  "video_1080i_3x",
}

local COMPAT_LABEL_KEYS = {
  "compat_none",
  "compat_1",
  "compat_2",
  "compat_3",
}

local function egsmStrings(_)
  local s = (_ and _.strings and _.strings.egsm) or {}
  return s
end

function arg_gsm_picker.videoTitle(_)
  local s = egsmStrings(_)
  return s.video_header or "Video mode"
end

function arg_gsm_picker.compatTitle(_, videoIdx)
  local s = egsmStrings(_)
  local rows = arg_gsm_picker.buildVideoRows(_)
  local selected = nil
  for i = 1, #rows do
    if rows[i].videoIdx == videoIdx then
      selected = rows[i]
      break
    end
  end
  local base = s.compat_header or "Compatibility"
  if selected and selected.value and selected.value ~= "" then
    return base .. " (" .. selected.value .. ")"
  end
  return base
end

function arg_gsm_picker.buildVideoRows(_)
  local rows = {}
  local s = egsmStrings(_)
  local opts = (_.config_parse and _.config_parse.getEgsmVideoOptions and _.config_parse.getEgsmVideoOptions()) or {}
  for i = 2, #opts do
    local v = tostring(opts[i] or "")
    if v ~= "" then
      local key = VIDEO_LABEL_KEYS[i - 1]
      local desc = (key and s[key]) or v
      rows[#rows + 1] = {
        label = v,
        value = v,
        videoIdx = i,
        desc = desc,
      }
    end
  end
  return rows
end

function arg_gsm_picker.buildCompatRows(_)
  local rows = {}
  local s = egsmStrings(_)
  local opts = (_.config_parse and _.config_parse.getEgsmCompatOptions and _.config_parse.getEgsmCompatOptions()) or {}
  for i = 1, #opts do
    local c = tostring(opts[i] or "")
    local key = COMPAT_LABEL_KEYS[i]
    local desc = (key and s[key]) or c
    local label
    if c == "" then
      label = s.compat_none or "none"
    else
      label = c
    end
    rows[#rows + 1] = {
      label = label,
      value = c,
      compatIdx = i,
      desc = desc,
    }
  end
  return rows
end

function arg_gsm_picker.buildArg(_, argKey, videoIdx, compatIdx)
  if not (_ and _.config_parse and _.config_parse.buildEgsmValue) then return nil end
  local value = _.config_parse.buildEgsmValue(videoIdx, compatIdx)
  if type(value) ~= "string" or value == "" then return nil end
  local key = tostring(argKey or "-gsm"):gsub("^%s+", ""):gsub("%s+$", "")
  if key == "" then key = "-gsm" end
  return key .. "=" .. value
end

return arg_gsm_picker
