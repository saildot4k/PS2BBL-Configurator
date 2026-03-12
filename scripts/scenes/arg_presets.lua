--[[ Shared argument helpers and profile override state for args editors. ]]

local arg_presets = {}

local function argValue(item)
  if type(item) == "table" then return item.value end
  return item
end

local function trimText(s)
  return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function ensureProfileOverrideMap(ctx)
  if type(ctx) ~= "table" then return nil end
  if type(ctx.argProfileOverrideByScope) ~= "table" then
    ctx.argProfileOverrideByScope = {}
  end
  return ctx.argProfileOverrideByScope
end

function arg_presets.getProfileOverride(ctx, scopeKey)
  local map = ensureProfileOverrideMap(ctx)
  if not map or not scopeKey or scopeKey == "" then return "auto" end
  local v = map[scopeKey]
  if type(v) ~= "string" or v == "" then return "auto" end
  return v
end

function arg_presets.setProfileOverride(ctx, scopeKey, profileId)
  local map = ensureProfileOverrideMap(ctx)
  if not map or not scopeKey or scopeKey == "" then return end
  if not profileId or profileId == "" or profileId == "auto" then
    map[scopeKey] = nil
    return
  end
  map[scopeKey] = tostring(profileId)
end

function arg_presets.normalizeArg(v)
  return trimText(v):lower()
end

function arg_presets.pathValue(item)
  local v = argValue(item)
  return tostring(v or "")
end

function arg_presets.isNhddlElfPath(path)
  local s = trimText(path):lower()
  return s:match("nhddl%.elf$") ~= nil
end

function arg_presets.hasNhddlElfPath(pathsOrPath)
  if type(pathsOrPath) == "string" then
    return arg_presets.isNhddlElfPath(pathsOrPath)
  end
  for _, item in ipairs(pathsOrPath or {}) do
    if arg_presets.isNhddlElfPath(arg_presets.pathValue(item)) then
      return true
    end
  end
  return false
end

function arg_presets.isApaPfsHddPath(path)
  local s = trimText(path):lower()
  if s == "" then return false end
  if s:match("^pfs%d:/") then return true end
  if s:match("^hdd%d:[^:]+:pfs:") then return true end
  if s:match("^hdd%d:[^:]+/") then return true end -- FMCB-style mapped pfs path
  if s:match("^hdd%d:[^:]+:patinfo$") then return true end
  return false
end

function arg_presets.pathsSupportPatinfo(pathsOrPath)
  if type(pathsOrPath) == "string" then
    return arg_presets.isApaPfsHddPath(pathsOrPath)
  end
  local hasAny = false
  for _, item in ipairs(pathsOrPath or {}) do
    local p = trimText(arg_presets.pathValue(item))
    if p ~= "" then
      hasAny = true
      if not arg_presets.isApaPfsHddPath(p) then
        return false
      end
    end
  end
  return hasAny
end

function arg_presets.hasCdromPath(pathsOrPath)
  if type(pathsOrPath) == "string" then
    return trimText(pathsOrPath):lower() == "cdrom"
  end
  for _, item in ipairs(pathsOrPath or {}) do
    if trimText(arg_presets.pathValue(item)):lower() == "cdrom" then
      return true
    end
  end
  return false
end

function arg_presets.collectUsedArgs(args)
  local usedKnown = {
    appid = false,
    titleid = false,
    dev9 = false,
    patinfo = false,
    video = false,
    udpbd_ip = false,
    egsm = false,
    gsm = false,
    osd = false,
    hosd = false,
    noflags = false,
    nologo = false,
    nogameid = false,
    dkwdrv = false,
    ps1fast = false,
    ps1smooth = false,
    ps1vneg = false,
  }
  local usedModes = {}
  for _, item in ipairs(args or {}) do
    local a = arg_presets.normalizeArg(argValue(item))
    if a == "-appid" then
      usedKnown.appid = true
    elseif a:match("^%-titleid%s*=") then
      usedKnown.titleid = true
    elseif a:match("^%-dev9%s*=") then
      usedKnown.dev9 = true
    elseif a == "-patinfo" then
      usedKnown.patinfo = true
    elseif a:match("^%-video%s*=") then
      usedKnown.video = true
    elseif a:match("^%-udpbd_ip%s*=") then
      usedKnown.udpbd_ip = true
    elseif a:match("^%-gsm%s*=") then
      usedKnown.egsm = true
      usedKnown.gsm = true
    elseif a == "-osd" then
      usedKnown.osd = true
    elseif a == "-hosd" then
      usedKnown.hosd = true
    elseif a == "-noflags" then
      usedKnown.noflags = true
    elseif a == "-nologo" then
      usedKnown.nologo = true
    elseif a == "-nogameid" then
      usedKnown.nogameid = true
    elseif a == "-dkwdrv" or a:match("^%-dkwdrv%s*=") then
      usedKnown.dkwdrv = true
    elseif a == "-ps1fast" then
      usedKnown.ps1fast = true
    elseif a == "-ps1smooth" then
      usedKnown.ps1smooth = true
    elseif a == "-ps1vneg" then
      usedKnown.ps1vneg = true
    else
      local mv = a:match("^%-mode%s*=%s*(.+)$")
      if mv and mv ~= "" then
        mv = trimText(mv)
        if mv ~= "" then usedModes[mv] = true end
      end
    end
  end
  return usedKnown, usedModes
end

function arg_presets.rowDisabled(row, usedKnown, usedModes, total, maxArgs)
  if not row then return true, "invalid" end
  if row.kind == "profile" then return false, nil end

  local used = usedKnown or {}
  local modes = usedModes or {}
  local curTotal = math.max(0, math.floor(tonumber(total) or 0))
  local maxTotal = tonumber(maxArgs)
  local needUdpbdPair = (modes["udpbd"] ~= true and used.udpbd_ip ~= true)
  local enforceMax = (maxTotal ~= nil and maxTotal >= 0)

  if row.modeValue and row.modeValue ~= "" then
    if row.modeValue == "udpbd" and needUdpbdPair and enforceMax and curTotal > (maxTotal - 2) then
      return true, "needs_two_slots"
    end
    if modes[row.modeValue] == true then
      return true, "in_use"
    end
    return false, nil
  end

  if row.kind == "udpbd_ip" then
    if needUdpbdPair and enforceMax and curTotal > (maxTotal - 2) then
      return true, "needs_two_slots"
    end
    if used.udpbd_ip == true then
      return true, "in_use"
    end
    return false, nil
  end

  if not row.uniqueKey or row.uniqueKey == "" then return false, nil end
  if used[row.uniqueKey] == true then
    return true, "in_use"
  end
  return false, nil
end

function arg_presets.addUdpbdPair(args, ipValue, maxArgs)
  local ip = trimText(ipValue)
  local out = {}
  for i = 1, #(args or {}) do out[i] = args[i] end
  if ip == "" then return out, false end

  local hasModeUdpbd = false
  local hasUdpbdIp = false
  for _, item in ipairs(out) do
    local a = arg_presets.normalizeArg(argValue(item))
    if a:match("^%-mode%s*=%s*udpbd%s*$") then
      hasModeUdpbd = true
    elseif a:match("^%-udpbd_ip%s*=") then
      hasUdpbdIp = true
    end
  end

  local needMode = not hasModeUdpbd
  local needIp = not hasUdpbdIp
  local needCount = (needMode and 1 or 0) + (needIp and 1 or 0)
  if tonumber(maxArgs) and (#out + needCount) > tonumber(maxArgs) then
    return out, false
  end

  if needMode then table.insert(out, { value = "-mode=udpbd", disabled = false }) end
  if needIp then table.insert(out, { value = "-udpbd_ip=" .. ip, disabled = false }) end
  return out, true
end

function arg_presets.removeArgAndPairedUdpbd(args, removeIdx, removePair)
  local out = {}
  for i = 1, #(args or {}) do out[i] = args[i] end
  local idx = math.floor(tonumber(removeIdx) or 0)
  if idx < 1 or idx > #out then
    return out, false
  end

  local removed = table.remove(out, idx)
  if not removePair then
    return out, true
  end

  local removedVal = arg_presets.normalizeArg(argValue(removed))
  local removedModeUdpbd = removedVal:match("^%-mode%s*=%s*udpbd%s*$") ~= nil
  local removedUdpbdIp = removedVal:match("^%-udpbd_ip%s*=") ~= nil

  if removedModeUdpbd then
    for i = #out, 1, -1 do
      local a = arg_presets.normalizeArg(argValue(out[i]))
      if a:match("^%-udpbd_ip%s*=") then
        table.remove(out, i)
        break
      end
    end
  elseif removedUdpbdIp then
    for i = #out, 1, -1 do
      local a = arg_presets.normalizeArg(argValue(out[i]))
      if a:match("^%-mode%s*=%s*udpbd%s*$") then
        table.remove(out, i)
        break
      end
    end
  end

  return out, true
end

return arg_presets
