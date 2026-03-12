--[[ Shared preset and argument helpers for entry args and BBL hotkey args. ]]

local arg_presets = {}

local function cloneRow(row)
  local out = {}
  for k, v in pairs(row or {}) do out[k] = v end
  return out
end

local function appendRows(dst, src)
  for i = 1, #(src or {}) do
    dst[#dst + 1] = cloneRow(src[i])
  end
end

local function argValue(item)
  if type(item) == "table" then return item.value end
  return item
end

local function trimText(s)
  return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local manualRow = {
  label = "Enter manually",
  kind = "manual",
  desc = "Enter any custom argument manually.",
}

local bblNonNhddlRows = {
  {
    label = "-appid",
    value = "-appid",
    desc = "Forces app visual game ID even if APP_GAMEID = 0.",
    uniqueKey = "appid",
  },
  {
    label = "-titleid=<11 chars>",
    kind = "titleid",
    desc = "Overrides app title ID (up to 11 characters).",
    uniqueKey = "titleid",
  },
}

local nhddlCoreRows = {
  {
    label = "-video=ntsc",
    value = "-video=ntsc",
    desc = "NHDDL: force NTSC video mode.",
    uniqueKey = "video",
  },
  {
    label = "-video=pal",
    value = "-video=pal",
    desc = "NHDDL: force PAL video mode.",
    uniqueKey = "video",
  },
  {
    label = "-video=480p",
    value = "-video=480p",
    desc = "NHDDL/Neutrino: request 480p (build-dependent).",
    uniqueKey = "video",
  },
  {
    label = "-mode=usb",
    value = "-mode=usb",
    desc = "NHDDL: initialize USB mode only.",
    modeValue = "usb",
  },
  {
    label = "-mode=mx4sio",
    value = "-mode=mx4sio",
    desc = "NHDDL: initialize MX4SIO mode only.",
    modeValue = "mx4sio",
  },
  {
    label = "-mode=mmce",
    value = "-mode=mmce",
    desc = "NHDDL: initialize MMCE mode only.",
    modeValue = "mmce",
  },
  {
    label = "-mode=ilink",
    value = "-mode=ilink",
    desc = "NHDDL: initialize iLink mode only.",
    modeValue = "ilink",
  },
  {
    label = "-mode=ata",
    value = "-mode=ata",
    desc = "NHDDL: initialize ATA mode only.",
    modeValue = "ata",
  },
  {
    label = "-mode=hdl",
    value = "-mode=hdl",
    desc = "NHDDL: initialize HDL mode only.",
    modeValue = "hdl",
  },
  {
    label = "-mode=udpbd",
    value = "-mode=udpbd",
    desc = "NHDDL UDPBD mode; requires -udpbd_ip=<IP> (paired automatically).",
    modeValue = "udpbd",
  },
  {
    label = "-udpbd_ip=<ip>",
    kind = "udpbd_ip",
    desc = "NHDDL UDPBD IP; requires -mode=udpbd (paired automatically).",
    uniqueKey = "udpbd_ip",
  },
  {
    label = "-noinit",
    value = "-noinit",
    desc = "NHDDL: skip IOP initialization (advanced).",
    uniqueKey = "noinit",
  },
}

local sharedTailRows = {
  {
    label = "-dev9=NICHDD",
    value = "-dev9=NICHDD",
    desc = "Keep both DEV9 (network) and HDD powered/on.",
    uniqueKey = "dev9",
  },
  {
    label = "-dev9=NIC",
    value = "-dev9=NIC",
    desc = "Keep DEV9 on; unmount pfs0: and idle hdd0:/hdd1:.",
    uniqueKey = "dev9",
  },
  {
    label = "-patinfo",
    value = "-patinfo",
    desc = "Enable PATINFO launch handling for :PATINFO paths.",
    uniqueKey = "patinfo",
  },
}

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

function arg_presets.collectUsedArgs(args)
  local usedKnown = {
    appid = false,
    titleid = false,
    dev9 = false,
    patinfo = false,
    video = false,
    udpbd_ip = false,
    noinit = false,
  }
  local usedModes = {}
  for _, item in ipairs(args or {}) do
    local a = arg_presets.normalizeArg(argValue(item))
    if a == "-appid" then
      usedKnown.appid = true
    elseif a:match("^%-titleid=") then
      usedKnown.titleid = true
    elseif a:match("^%-dev9=") then
      usedKnown.dev9 = true
    elseif a == "-patinfo" then
      usedKnown.patinfo = true
    elseif a:match("^%-video=") then
      usedKnown.video = true
    elseif a:match("^%-udpbd_ip=") then
      usedKnown.udpbd_ip = true
    elseif a == "-noinit" then
      usedKnown.noinit = true
    else
      local mv = a:match("^%-mode=%s*(.+)$")
      if mv and mv ~= "" then
        mv = trimText(mv)
        if mv ~= "" then usedModes[mv] = true end
      end
    end
  end
  return usedKnown, usedModes
end

function arg_presets.buildEntryNhddlRows()
  local rows = { cloneRow(manualRow) }
  appendRows(rows, nhddlCoreRows)
  appendRows(rows, sharedTailRows)
  return rows
end

function arg_presets.buildBblRows(isNhddlElfPath)
  local rows = { cloneRow(manualRow) }
  if not isNhddlElfPath then
    appendRows(rows, bblNonNhddlRows)
  else
    appendRows(rows, nhddlCoreRows)
  end
  appendRows(rows, sharedTailRows)
  return rows
end

function arg_presets.rowDisabled(row, usedKnown, usedModes, total, maxArgs)
  if not row then return true, "invalid" end
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
    if a:match("^%-mode=%s*udpbd%s*$") then
      hasModeUdpbd = true
    elseif a:match("^%-udpbd_ip=") then
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
  local removedModeUdpbd = removedVal:match("^%-mode=%s*udpbd%s*$") ~= nil
  local removedUdpbdIp = removedVal:match("^%-udpbd_ip=") ~= nil

  if removedModeUdpbd then
    for i = #out, 1, -1 do
      local a = arg_presets.normalizeArg(argValue(out[i]))
      if a:match("^%-udpbd_ip=") then
        table.remove(out, i)
        break
      end
    end
  elseif removedUdpbdIp then
    for i = #out, 1, -1 do
      local a = arg_presets.normalizeArg(argValue(out[i]))
      if a:match("^%-mode=%s*udpbd%s*$") then
        table.remove(out, i)
        break
      end
    end
  end

  return out, true
end

return arg_presets
