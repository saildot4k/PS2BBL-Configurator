--[[ Argument profile registry/resolver for app-specific add-argument presets. ]]

local arg_profiles = {}

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

local function makeRow(label, value, desc, extra)
  local row = cloneRow(extra or {})
  row.label = label or value or ""
  if value ~= nil then row.value = value end
  row.desc = desc or row.desc or ""
  return row
end

local function cloneProfile(base)
  local out = {}
  for k, v in pairs(base or {}) do
    if k ~= "rows" then out[k] = v end
  end
  out.rows = {}
  appendRows(out.rows, base and base.rows or {})
  return out
end

local rowManual = {
  label = "Enter manually",
  kind = "manual",
  desc = "Enter any custom argument manually.",
}

local rowsTitleApp = {
  makeRow("-appid", "-appid", "Enable visual game ID for app launches.", { uniqueKey = "appid" }),
  makeRow("-titleid=<11 chars>", nil, "Override title ID (up to 11 characters).",
    { kind = "titleid", uniqueKey = "titleid" }),
}

local rowsGsm = {
  makeRow("-gsm=<mode[:compat]>", nil, "Set eGSM value (example: fp2:1).", { kind = "gsm", uniqueKey = "gsm" }),
}

local rowsDev9Patinfo = {
  makeRow("-dev9=NICHDD", "-dev9=NICHDD", "Keep both DEV9 and HDD powered/on.", { uniqueKey = "dev9" }),
  makeRow("-dev9=NIC", "-dev9=NIC", "Keep DEV9/network on; put HDD into idle state.", { uniqueKey = "dev9" }),
  makeRow("-patinfo", "-patinfo", "PATINFO path: first remaining argument becomes target ELF path.",
    { uniqueKey = "patinfo" }),
}

local rowsLauncherBootHints = {
  makeRow("-osd", "-osd", "Launcher flag: request OSDSYS-style boot path.", { uniqueKey = "osd" }),
  makeRow("-hosd", "-hosd", "Launcher flag: request HOSDSYS-style boot path.", { uniqueKey = "hosd" }),
}

local rowsMbrOnly = {
  makeRow("-noflags", "-noflags", "OSDMenu MBR: disable configured flags for this path (keep last).",
    { uniqueKey = "noflags" }),
  makeRow("-patinfo", "-patinfo", "PATINFO path: first remaining argument becomes target ELF path.",
    { uniqueKey = "patinfo" }),
}

local rowsNhddl = {
  makeRow("-video=ntsc", "-video=ntsc", "NHDDL: force NTSC video mode.", { uniqueKey = "video" }),
  makeRow("-video=pal", "-video=pal", "NHDDL: force PAL video mode.", { uniqueKey = "video" }),
  makeRow("-video=480p", "-video=480p", "NHDDL: request 480p mode (build-dependent).", { uniqueKey = "video" }),

  makeRow("-mode=usb", "-mode=usb", "NHDDL: initialize USB mode only.", { modeValue = "usb" }),
  makeRow("-mode=mx4sio", "-mode=mx4sio", "NHDDL: initialize MX4SIO mode only.", { modeValue = "mx4sio" }),
  makeRow("-mode=mmce", "-mode=mmce", "NHDDL: initialize MMCE mode only.", { modeValue = "mmce" }),
  makeRow("-mode=ilink", "-mode=ilink", "NHDDL: initialize iLink mode only.", { modeValue = "ilink" }),
  makeRow("-mode=ata", "-mode=ata", "NHDDL: initialize ATA mode only.", { modeValue = "ata" }),
  makeRow("-mode=hdl", "-mode=hdl", "NHDDL: initialize HDL mode only.", { modeValue = "hdl" }),
  makeRow("-mode=udpbd", "-mode=udpbd", "NHDDL UDPBD mode; pairs with -udpbd_ip=<ip>.", { modeValue = "udpbd" }),
  makeRow("-udpbd_ip=<ip>", nil, "NHDDL UDPBD IP; pairs with -mode=udpbd.", { kind = "udpbd_ip", uniqueKey = "udpbd_ip" }),
}

local profiles = {}

profiles.ps2bbl_generic = {
  id = "ps2bbl_generic",
  label = "PS2BBL/PSXBBL",
  menuTag = "PS2BBL/PSXBBL",
  usesNhddlArgs = false,
  rows = {},
}
appendRows(profiles.ps2bbl_generic.rows, rowsTitleApp)
appendRows(profiles.ps2bbl_generic.rows, rowsGsm)
appendRows(profiles.ps2bbl_generic.rows, rowsDev9Patinfo)

profiles.ps2bbl_nhddl = {
  id = "ps2bbl_nhddl",
  label = "PS2BBL/PSXBBL + NHDDL",
  menuTag = "NHDDL",
  usesNhddlArgs = true,
  rows = {},
}
appendRows(profiles.ps2bbl_nhddl.rows, rowsNhddl)
appendRows(profiles.ps2bbl_nhddl.rows, rowsTitleApp)
appendRows(profiles.ps2bbl_nhddl.rows, rowsGsm)
appendRows(profiles.ps2bbl_nhddl.rows, rowsDev9Patinfo)

profiles.osdmenu_global = {
  id = "osdmenu_global",
  label = "OSDMenu Launcher",
  menuTag = "OSDMenu",
  usesNhddlArgs = false,
  rows = {},
}
appendRows(profiles.osdmenu_global.rows, rowsTitleApp)
appendRows(profiles.osdmenu_global.rows, rowsGsm)
appendRows(profiles.osdmenu_global.rows, rowsDev9Patinfo)
appendRows(profiles.osdmenu_global.rows, rowsLauncherBootHints)

profiles.osdmenu_nhddl = {
  id = "osdmenu_nhddl",
  label = "OSDMenu + NHDDL",
  menuTag = "NHDDL",
  usesNhddlArgs = true,
  rows = {},
}
appendRows(profiles.osdmenu_nhddl.rows, rowsNhddl)
appendRows(profiles.osdmenu_nhddl.rows, rowsTitleApp)
appendRows(profiles.osdmenu_nhddl.rows, rowsGsm)
appendRows(profiles.osdmenu_nhddl.rows, rowsDev9Patinfo)
appendRows(profiles.osdmenu_nhddl.rows, rowsLauncherBootHints)

profiles.hosdmenu_global = cloneProfile(profiles.osdmenu_global)
profiles.hosdmenu_global.id = "hosdmenu_global"
profiles.hosdmenu_global.label = "HOSDMenu Launcher"
profiles.hosdmenu_global.menuTag = "HOSDMenu"

profiles.hosdmenu_nhddl = cloneProfile(profiles.osdmenu_nhddl)
profiles.hosdmenu_nhddl.id = "hosdmenu_nhddl"
profiles.hosdmenu_nhddl.label = "HOSDMenu + NHDDL"
profiles.hosdmenu_nhddl.menuTag = "NHDDL"

profiles.osdmbr_global = {
  id = "osdmbr_global",
  label = "OSDMenu MBR",
  menuTag = "OSDMenu MBR",
  usesNhddlArgs = false,
  rows = {},
}
appendRows(profiles.osdmbr_global.rows, rowsMbrOnly)

profiles.osdmbr_nhddl = {
  id = "osdmbr_nhddl",
  label = "OSDMenu MBR + NHDDL",
  menuTag = "NHDDL",
  usesNhddlArgs = true,
  rows = {},
}
appendRows(profiles.osdmbr_nhddl.rows, rowsNhddl)
appendRows(profiles.osdmbr_nhddl.rows, rowsMbrOnly)

local appProfileIds = {
  ps2bbl = { "ps2bbl_generic", "ps2bbl_nhddl" },
  osdmenu = { "osdmenu_global", "osdmenu_nhddl" },
  hosdmenu = { "hosdmenu_global", "hosdmenu_nhddl" },
  osdmbr = { "osdmbr_global", "osdmbr_nhddl" },
}

local function inferAppKey(info)
  local ft = tostring((info and info.fileType) or "")
  local ctx = tostring((info and info.context) or "")
  local surface = tostring((info and info.surface) or "")
  if surface == "bbl_hotkey" or ft == "ps2bbl_ini" or ft == "psxbbl_ini" then
    return "ps2bbl"
  end
  if ctx == "mbr" or ft == "osdmbr_cnf" or (info and info.isBoot) then
    return "osdmbr"
  end
  if ctx == "hosdmenu" then
    return "hosdmenu"
  end
  return "osdmenu"
end

local function getProfilesForApp(appKey)
  local out = {}
  local ids = appProfileIds[appKey] or {}
  for i = 1, #ids do
    local p = profiles[ids[i]]
    if p then out[#out + 1] = p end
  end
  return out
end

local function getAutoProfileId(profileList, hasNhddlPath)
  local fallback = (profileList[1] and profileList[1].id) or nil
  if hasNhddlPath then
    for i = 1, #profileList do
      if profileList[i].usesNhddlArgs then return profileList[i].id end
    end
  else
    for i = 1, #profileList do
      if not profileList[i].usesNhddlArgs then return profileList[i].id end
    end
  end
  return fallback
end

local function resolveProfileById(profileList, profileId)
  for i = 1, #profileList do
    if profileList[i].id == profileId then return profileList[i] end
  end
  return nil
end

function arg_profiles.resolve(info, overrideProfileId)
  local appKey = inferAppKey(info or {})
  local profileList = getProfilesForApp(appKey)
  local autoId = getAutoProfileId(profileList, not not (info and info.hasNhddlPath))
  local autoProfile = resolveProfileById(profileList, autoId)

  local activeProfile = autoProfile
  local activeId = autoId
  local appliedOverrideId = "auto"
  if overrideProfileId and overrideProfileId ~= "" and overrideProfileId ~= "auto" then
    local p = resolveProfileById(profileList, overrideProfileId)
    if p then
      activeProfile = p
      activeId = p.id
      appliedOverrideId = p.id
    end
  end

  local options = {
    {
      id = "auto",
      label = "Auto",
      desc = "Automatically choose a preset from current app/path context.",
    },
  }
  for i = 1, #profileList do
    options[#options + 1] = {
      id = profileList[i].id,
      label = profileList[i].label,
      desc = "Use this preset regardless of detected path type.",
    }
  end

  return {
    appKey = appKey,
    profiles = profileList,
    options = options,
    autoProfileId = autoId,
    autoProfile = autoProfile,
    activeProfileId = activeId,
    activeProfile = activeProfile,
    overrideProfileId = appliedOverrideId,
  }
end

function arg_profiles.nextOverrideId(state)
  local order = { "auto" }
  for i = 1, #(state and state.profiles or {}) do
    order[#order + 1] = state.profiles[i].id
  end
  if #order == 0 then return "auto" end

  local current = (state and state.overrideProfileId) or "auto"
  local idx = 1
  for i = 1, #order do
    if order[i] == current then
      idx = i
      break
    end
  end
  idx = idx + 1
  if idx > #order then idx = 1 end
  return order[idx]
end

function arg_profiles.buildAddRows(state)
  local rows = {}
  local autoLabel = (state and state.autoProfile and state.autoProfile.label) or "None"
  local currentLabel
  if state and state.overrideProfileId and state.overrideProfileId ~= "auto" and state.activeProfile then
    currentLabel = state.activeProfile.label
  else
    currentLabel = "Auto -> " .. autoLabel
  end

  rows[#rows + 1] = {
    label = "Profile: " .. currentLabel,
    kind = "profile",
    desc = "Press Cross to cycle profile preset.",
  }
  rows[#rows + 1] = cloneRow(rowManual)

  local active = state and state.activeProfile
  if active and active.rows then
    appendRows(rows, active.rows)
  end
  return rows
end

function arg_profiles.profileUsesNhddl(profileId)
  local p = profiles[profileId]
  return not not (p and p.usesNhddlArgs)
end

function arg_profiles.getMenuTag(state)
  return (state and state.activeProfile and state.activeProfile.menuTag) or "Custom"
end

return arg_profiles
