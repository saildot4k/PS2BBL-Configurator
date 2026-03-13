--[[
  CNF parse/serialize for OSDMENU.CNF, OSDMBR.CNF, OSDGSM.CNF.
  Line-based key = value; # comments; empty lines allowed.
  Preserves comments and order. Multi-value keys use same key with multiple entries.
  Each line in the table: { comment = "..." } or { key = "...", value = "..." }.
  Nil checks: use ~= nil when the value can be "" or false (e.g. config get); use truthiness for match results.
]]

local config_parse = {}
local System = System

-- Open modes. Write uses O_TRUNC so the file is recreated (truncated), not appended.
local MODE_READ = O_RDONLY
local MODE_WRITE = O_WRONLY | O_CREAT | O_TRUNC

local function trim(s)
  if type(s) ~= "string" then return s end
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- Parse CNF content string into list of line entries.
-- Returns { { comment = "..." }, { key = "k", value = "v" }, ... }
function config_parse.parse(content)
  local lines = {}
  if not content or content == "" then return lines end
  for line in (content .. "\n"):gmatch("(.-)\n") do
    local rest = trim(line)
    if rest:match("^#") then
      local doubleComment = rest:match("^##") and true or false
      local afterHash = trim(rest:sub(doubleComment and 3 or 2))
      local ke, ve = afterHash:match("^(.+)%s*=%s*(.*)$")
      if ke and ve ~= nil then
        table.insert(lines, { key = trim(ke), value = trim(ve), comment = doubleComment and 2 or true })
      else
        table.insert(lines, { comment = line })
      end
    elseif rest == "" then
      table.insert(lines, { comment = "" })
    else
      local eq = rest:find("=", 1, true)
      if eq then
        local key = trim(rest:sub(1, eq - 1))
        local value = trim(rest:sub(eq + 1))
        table.insert(lines, { key = key, value = value })
      else
        table.insert(lines, { comment = line })
      end
    end
  end
  return lines
end

-- Serialize line list back to string.
function config_parse.serialize(lines)
  local t = {}
  for _, entry in ipairs(lines) do
    if entry.key and entry.comment then
      local prefix = (entry.comment == 2) and "## " or "# "
      table.insert(t, prefix .. entry.key .. " = " .. (entry.value or ""))
    elseif type(entry.comment) == "string" then
      table.insert(t, entry.comment == "" and "" or entry.comment)
    elseif entry.key then
      table.insert(t, entry.key .. " = " .. (entry.value or ""))
    end
  end
  return table.concat(t, "\n")
end

-- Read file at path and parse. Returns lines or nil, err.
function config_parse.load(path)
  local h = System.openFile(path, MODE_READ)
  if not h or h < 0 then return nil, "cannot open " .. tostring(path) end
  local size = System.sizeFile(h)
  if not size or size < 0 then
    System.closeFile(h)
    return nil, "cannot get size"
  end
  local content = System.readFile(h, size)
  System.closeFile(h)
  if not content then return nil, "read failed" end
  return config_parse.parse(content)
end

-- Serialize lines and write to path. Ensures parent dir exists if createDir is provided.
function config_parse.save(path, lines, createDir)
  local s = config_parse.serialize(lines)
  if createDir and createDir ~= "" then
    System.createDirectory(createDir)
  end
  local h = System.openFile(path, MODE_WRITE)
  if not h or h < 0 then return nil, "cannot open for write " .. tostring(path) end
  local written = System.writeFile(h, s, #s)
  System.closeFile(h)
  if written ~= #s then return nil, "write failed" end
  return true
end

-- Get first value for key from lines. Skips commented-out lines.
function config_parse.get(lines, key)
  for _, entry in ipairs(lines) do
    if entry.key and entry.key == key and not entry.comment then return entry.value end
  end
  return nil
end

-- Get value and comment flag for key (first match, commented or not). For menu entry display / "has key" checks.
function config_parse.getWithComment(lines, key)
  for _, entry in ipairs(lines) do
    if entry.key and entry.key == key then
      return entry.value, entry.comment
    end
  end
  return nil, nil
end

-- Get all values for key (multi-value). Skips commented-out lines.
function config_parse.getMulti(lines, key)
  local out = {}
  for _, entry in ipairs(lines) do
    if entry.key and entry.key == key and not entry.comment then
      table.insert(out, entry.value)
    end
  end
  return out
end

-- Get all entries whose key has given prefix (e.g. "path1_OSDSYS_ITEM_"). Skips commented-out lines.
function config_parse.getByPrefix(lines, prefix)
  local out = {}
  for _, entry in ipairs(lines) do
    if entry.key and not entry.comment and entry.key:sub(1, #prefix) == prefix then
      table.insert(out, { key = entry.key, value = entry.value })
    end
  end
  return out
end

-- Set first occurrence of key to value (commented or not); uncomments that line. If not found, append.
function config_parse.set(lines, key, value)
  for _, entry in ipairs(lines) do
    if entry.key and entry.key == key then
      entry.value = value
      entry.comment = nil
      return
    end
  end
  table.insert(lines, { key = key, value = value })
end

-- Append a new key=value line (for multi-value keys like boot_auto).
function config_parse.append(lines, key, value)
  table.insert(lines, { key = key, value = value })
end

-- OSDMBR.CNF: boot_auto, boot_start, etc. can have multiple path lines; args as key_arg1, key_arg2, ... or arg_key (multi).
function config_parse.getBootPaths(lines, key)
  return config_parse.getMulti(lines, key)
end

function config_parse.setBootPaths(lines, key, paths)
  local i = 1
  while i <= #lines do
    if lines[i].key == key then
      table.remove(lines, i)
    else
      i = i + 1
    end
  end
  for _, p in ipairs(paths or {}) do
    config_parse.append(lines, key, p)
  end
end

-- Boot args: key_arg or key_argN (suffix ignored); collect in file order. Fallback: legacy arg_key (multi).
function config_parse.getBootArgs(lines, key)
  local prefix = key .. "_arg"
  local out = {}
  for _, entry in ipairs(lines) do
    if entry.key and not entry.comment and entry.key:sub(1, #prefix) == prefix then
      table.insert(out, entry.value)
    end
  end
  if #out > 0 then return out end
  return config_parse.getMulti(lines, "arg_" .. key)
end

function config_parse.setBootArgs(lines, key, args)
  local prefix = key .. "_arg"
  local argKey = "arg_" .. key
  local i = 1
  while i <= #lines do
    local k = lines[i].key
    if k and (k == argKey or k:sub(1, #prefix) == prefix) then
      table.remove(lines, i)
    else
      i = i + 1
    end
  end
  for idx, v in ipairs(args or {}) do
    config_parse.append(lines, prefix .. tostring(idx), v)
  end
end

-- PS2BBL/PSXBBL key IDs and limits.
local BBL_KEYS_ALL = {
  "AUTO", "TRIANGLE", "CIRCLE", "CROSS", "SQUARE", "UP", "DOWN", "LEFT", "RIGHT",
  "L1", "L2", "L3", "R1", "R2", "R3", "SELECT", "START"
}
local BBL_HOTKEYS = {
  "TRIANGLE", "CIRCLE", "CROSS", "SQUARE", "UP", "DOWN", "LEFT", "RIGHT",
  "L1", "L2", "L3", "R1", "R2", "R3", "SELECT", "START"
}
local BBL_MAX_ENTRIES = 10
local BBL_MAX_ARGS_PER_ENTRY = 8
local BBL_MAX_IRX_ENTRIES = 10

function config_parse.getBblHotkeys()
  return BBL_HOTKEYS
end

function config_parse.getBblMaxEntries()
  return BBL_MAX_ENTRIES
end

function config_parse.getBblMaxArgsPerEntry()
  return BBL_MAX_ARGS_PER_ENTRY
end

function config_parse.getBblMaxIrxEntries()
  return BBL_MAX_IRX_ENTRIES
end

local function bblIrxKey(entryIdx)
  return "LOAD_IRX_E" .. tostring(entryIdx or "")
end

local function isValidBblIrxIdx(entryIdx)
  return type(entryIdx) == "number" and entryIdx >= 1 and entryIdx <= BBL_MAX_IRX_ENTRIES
end

function config_parse.getBblIrxEntryIndices(lines)
  local byIdx = {}
  for _, entry in ipairs(lines or {}) do
    if entry.key then
      local n = entry.key:match("^LOAD_IRX_E(%d+)$")
      if n then
        local idx = tonumber(n)
        if idx and idx >= 1 and idx <= BBL_MAX_IRX_ENTRIES then
          byIdx[idx] = not not entry.comment
        end
      end
    end
  end
  local out = {}
  for idx, disabled in pairs(byIdx) do
    out[#out + 1] = { idx = idx, disabled = disabled }
  end
  table.sort(out, function(a, b) return a.idx < b.idx end)
  return out
end

function config_parse.getBblIrxEntry(lines, entryIdx)
  if not isValidBblIrxIdx(entryIdx) then return nil, false end
  local value, commented = config_parse.getWithComment(lines, bblIrxKey(entryIdx))
  return value, commented and true or false
end

function config_parse.setBblIrxEntry(lines, entryIdx, value, disabled)
  if not isValidBblIrxIdx(entryIdx) then return false end
  local key = bblIrxKey(entryIdx)
  local insertAt = nil
  local i = 1
  while i <= #lines do
    if lines[i].key == key then
      if not insertAt then insertAt = i end
      table.remove(lines, i)
    else
      i = i + 1
    end
  end
  if value == nil then return true end
  local newEntry = { key = key, value = value or "", comment = disabled and true or nil }
  if insertAt then
    table.insert(lines, insertAt, newEntry)
  else
    table.insert(lines, newEntry)
  end
  return true
end

function config_parse.setBblIrxEntryDisabled(lines, entryIdx, disabled)
  local value = config_parse.getBblIrxEntry(lines, entryIdx)
  if value == nil then return false end
  return config_parse.setBblIrxEntry(lines, entryIdx, value, disabled)
end

function config_parse.removeBblIrxEntry(lines, entryIdx)
  if not isValidBblIrxIdx(entryIdx) then return false end
  local key = bblIrxKey(entryIdx)
  local removed = false
  local i = 1
  while i <= #lines do
    if lines[i].key == key then
      table.remove(lines, i)
      removed = true
    else
      i = i + 1
    end
  end
  return removed
end

function config_parse.changeBblIrxEntryIndex(lines, oldIdx, newIdx)
  if not isValidBblIrxIdx(oldIdx) or not isValidBblIrxIdx(newIdx) then return false end
  if oldIdx == newIdx then return true end
  local newValue = config_parse.getBblIrxEntry(lines, newIdx)
  if newValue ~= nil then return false end
  local oldKey = bblIrxKey(oldIdx)
  local newKey = bblIrxKey(newIdx)
  for _, entry in ipairs(lines or {}) do
    if entry.key == oldKey then
      entry.key = newKey
      return true
    end
  end
  return false
end

function config_parse.insertBblIrxEntryBelow(lines, belowIdx, value, disabled)
  local entries = config_parse.getBblIrxEntryIndices(lines)
  if #entries == 0 then
    config_parse.setBblIrxEntry(lines, 1, value == nil and "" or value, disabled)
    return 1
  end
  local insertIdx = tonumber(belowIdx) and (belowIdx + 1) or 1
  if insertIdx < 1 then insertIdx = 1 end
  if insertIdx > BBL_MAX_IRX_ENTRIES then insertIdx = BBL_MAX_IRX_ENTRIES end
  local occupied = {}
  for _, e in ipairs(entries) do
    occupied[e.idx] = true
  end
  local gapIdx = insertIdx
  while gapIdx <= BBL_MAX_IRX_ENTRIES and occupied[gapIdx] do
    gapIdx = gapIdx + 1
  end
  if gapIdx > BBL_MAX_IRX_ENTRIES then
    return nil
  end
  for idx = gapIdx - 1, insertIdx, -1 do
    config_parse.changeBblIrxEntryIndex(lines, idx, idx + 1)
  end
  config_parse.setBblIrxEntry(lines, insertIdx, value == nil and "" or value, disabled)
  return insertIdx
end

function config_parse.swapBblIrxEntryContent(lines, idxA, idxB)
  if not isValidBblIrxIdx(idxA) or not isValidBblIrxIdx(idxB) then return false end
  if idxA == idxB then return true end
  local keyA = bblIrxKey(idxA)
  local keyB = bblIrxKey(idxB)
  local entryA, entryB = nil, nil
  for _, entry in ipairs(lines or {}) do
    if entry.key == keyA then
      entryA = entry
    elseif entry.key == keyB then
      entryB = entry
    end
  end
  if not entryA or not entryB then return false end
  entryA.value, entryB.value = entryB.value, entryA.value
  entryA.comment, entryB.comment = entryB.comment, entryA.comment
  return true
end

local function canonicalBblHotkeyId(keyId)
  if type(keyId) ~= "string" then return nil end
  local upper = keyId:upper()
  for _, k in ipairs(BBL_KEYS_ALL) do
    if k == upper then return upper end
  end
  return nil
end

local function isBblHotkeyId(keyId)
  return canonicalBblHotkeyId(keyId) ~= nil
end

local function bblHotkeyIdVariants(keyId)
  local canonical = canonicalBblHotkeyId(keyId)
  if not canonical then return {} end
  local out = { canonical }
  if canonical:match("^[A-Z]+$") then
    local title = canonical:sub(1, 1) .. canonical:sub(2):lower()
    if title ~= canonical then out[#out + 1] = title end
  end
  return out
end

local function removeAllKeys(lines, keys)
  local keep = {}
  for i = 1, #keys do keep[keys[i]] = true end
  local i = 1
  while i <= #lines do
    if keep[lines[i].key] then
      table.remove(lines, i)
    else
      i = i + 1
    end
  end
end

local function getWithCommentAnyKey(lines, keys)
  if not lines or not keys then return nil, nil end
  local want = {}
  for i = 1, #keys do want[keys[i]] = true end
  for _, entry in ipairs(lines) do
    local k = entry and entry.key
    if k and want[k] then
      return entry.value, entry.comment and true or false
    end
  end
  return nil, nil
end

local function bblNameKey(keyId)
  return "NAME_" .. tostring(keyId or "")
end

local function bblPathKey(keyId, entryIdx)
  return "LK_" .. tostring(keyId or "") .. "_E" .. tostring(entryIdx or "")
end

local function bblArgKey(keyId, entryIdx)
  return "ARG_" .. tostring(keyId or "") .. "_E" .. tostring(entryIdx or "")
end

local function removeAllKey(lines, key)
  local i = 1
  while i <= #lines do
    if lines[i].key == key then
      table.remove(lines, i)
    else
      i = i + 1
    end
  end
end

local function isValidBblEntryIdx(entryIdx)
  return type(entryIdx) == "number" and entryIdx >= 1 and entryIdx <= BBL_MAX_ENTRIES
end

-- BBL hotkey name (NAME_<HOTKEY>). Returns "" when not set.
function config_parse.getBblHotkeyName(lines, keyId)
  local ids = bblHotkeyIdVariants(keyId)
  if #ids == 0 then return "" end
  local keys = {}
  for i = 1, #ids do keys[#keys + 1] = bblNameKey(ids[i]) end
  local val = getWithCommentAnyKey(lines, keys)
  return val or ""
end

function config_parse.setBblHotkeyName(lines, keyId, value)
  local canonical = canonicalBblHotkeyId(keyId)
  if not canonical then return false end
  local ids = bblHotkeyIdVariants(canonical)
  local keys = {}
  for i = 1, #ids do keys[#keys + 1] = bblNameKey(ids[i]) end
  removeAllKeys(lines, keys)
  config_parse.set(lines, bblNameKey(canonical), value or "")
  return true
end

-- BBL path entry (LK_<HOTKEY>_E#). Returns path (or nil) and disabled state.
function config_parse.getBblHotkeyPath(lines, keyId, entryIdx)
  if not isValidBblEntryIdx(entryIdx) then return nil, false end
  local ids = bblHotkeyIdVariants(keyId)
  if #ids == 0 then return nil, false end
  local keys = {}
  for i = 1, #ids do keys[#keys + 1] = bblPathKey(ids[i], entryIdx) end
  local value, commented = getWithCommentAnyKey(lines, keys)
  return value, (commented and true or false)
end

function config_parse.setBblHotkeyPath(lines, keyId, entryIdx, value, disabled)
  local canonical = canonicalBblHotkeyId(keyId)
  if not canonical or not isValidBblEntryIdx(entryIdx) then return false end
  local ids = bblHotkeyIdVariants(canonical)
  local keys = {}
  for i = 1, #ids do keys[#keys + 1] = bblPathKey(ids[i], entryIdx) end
  removeAllKeys(lines, keys)
  if value == nil then return true end
  table.insert(lines, { key = bblPathKey(canonical, entryIdx), value = value or "", comment = disabled and true or nil })
  return true
end

function config_parse.setBblHotkeyPathDisabled(lines, keyId, entryIdx, disabled)
  local value = config_parse.getBblHotkeyPath(lines, keyId, entryIdx)
  if value == nil then return false end
  return config_parse.setBblHotkeyPath(lines, keyId, entryIdx, value, disabled)
end

-- BBL args for one entry (ARG_<HOTKEY>_E#). Each item = { value, disabled }.
function config_parse.getBblHotkeyArgs(lines, keyId, entryIdx)
  local out = {}
  if not isValidBblEntryIdx(entryIdx) then return out end
  local ids = bblHotkeyIdVariants(keyId)
  if #ids == 0 then return out end
  local keySet = {}
  for i = 1, #ids do keySet[bblArgKey(ids[i], entryIdx)] = true end
  for _, entry in ipairs(lines) do
    if entry.key and keySet[entry.key] then
      table.insert(out, { value = entry.value or "", disabled = not not entry.comment, comment = entry.comment })
    end
  end
  return out
end

function config_parse.setBblHotkeyArgs(lines, keyId, entryIdx, args)
  local canonical = canonicalBblHotkeyId(keyId)
  if not canonical or not isValidBblEntryIdx(entryIdx) then return false end
  local ids = bblHotkeyIdVariants(canonical)
  local keys = {}
  for i = 1, #ids do keys[#keys + 1] = bblArgKey(ids[i], entryIdx) end
  removeAllKeys(lines, keys)
  local key = bblArgKey(canonical, entryIdx)
  local maxArgs = BBL_MAX_ARGS_PER_ENTRY
  local count = 0
  for _, item in ipairs(args or {}) do
    if count >= maxArgs then break end
    local value = type(item) == "table" and item.value or item
    local disabled = false
    if type(item) == "table" then
      -- Prefer explicit disabled flag; fallback to comment for legacy call sites.
      if item.disabled ~= nil then
        disabled = item.disabled and true or false
      else
        disabled = item.comment and true or false
      end
    end
    table.insert(lines, { key = key, value = value or "", comment = disabled and true or nil })
    count = count + 1
  end
  return true
end

function config_parse.setBblHotkeyArgDisabled(lines, keyId, entryIdx, argIdx, disabled)
  if type(argIdx) ~= "number" or argIdx < 1 then return false end
  local args = config_parse.getBblHotkeyArgs(lines, keyId, entryIdx)
  if argIdx > #args then return false end
  args[argIdx].disabled = disabled and true or false
  args[argIdx].comment = args[argIdx].disabled and true or nil
  return config_parse.setBblHotkeyArgs(lines, keyId, entryIdx, args)
end

function config_parse.removeBblHotkeySlot(lines, keyId, entryIdx)
  local canonical = canonicalBblHotkeyId(keyId)
  if not canonical or not isValidBblEntryIdx(entryIdx) then return false end
  local ids = bblHotkeyIdVariants(canonical)
  local pathKeys, argKeys = {}, {}
  for i = 1, #ids do
    pathKeys[#pathKeys + 1] = bblPathKey(ids[i], entryIdx)
    argKeys[#argKeys + 1] = bblArgKey(ids[i], entryIdx)
  end
  removeAllKeys(lines, pathKeys)
  removeAllKeys(lines, argKeys)
  return true
end

function config_parse.getBblHotkeySlot(lines, keyId, entryIdx)
  local path, disabled = config_parse.getBblHotkeyPath(lines, keyId, entryIdx)
  local args = config_parse.getBblHotkeyArgs(lines, keyId, entryIdx)
  local used = ((path ~= nil and path ~= "") or #args > 0)
  return {
    slot = entryIdx,
    used = used,
    path = path or "",
    pathExists = (path ~= nil),
    disabled = disabled and true or false,
    args = args,
    argCount = #args,
  }
end

function config_parse.getBblHotkeyUsedSlots(lines, keyId)
  local out = {}
  if not isBblHotkeyId(keyId) then return out end
  for i = 1, BBL_MAX_ENTRIES do
    local slot = config_parse.getBblHotkeySlot(lines, keyId, i)
    if slot.used then table.insert(out, slot) end
  end
  return out
end

function config_parse.swapBblHotkeySlots(lines, keyId, slotA, slotB)
  if not isBblHotkeyId(keyId) then return false end
  if not isValidBblEntryIdx(slotA) or not isValidBblEntryIdx(slotB) then return false end
  if slotA == slotB then return true end

  local slotAData = config_parse.getBblHotkeySlot(lines, keyId, slotA)
  local slotBData = config_parse.getBblHotkeySlot(lines, keyId, slotB)

  config_parse.setBblHotkeyPath(lines, keyId, slotA, slotBData.pathExists and slotBData.path or nil, slotBData.disabled)
  config_parse.setBblHotkeyArgs(lines, keyId, slotA, slotBData.args)

  config_parse.setBblHotkeyPath(lines, keyId, slotB, slotAData.pathExists and slotAData.path or nil, slotAData.disabled)
  config_parse.setBblHotkeyArgs(lines, keyId, slotB, slotAData.args)
  return true
end

-- OSDGSM: validate title ID format AAAA_000.00 (4 uppercase letters, _, 3 digits, ., 2 digits; 11 chars).
function config_parse.isValidTitleId(s)
  if type(s) ~= "string" or #s ~= 11 then return false end
  return s:match("^%u%u%u%u_%d%d%d%.%d%d$") ~= nil
end

-- Build title ID from user input: first 4 letters (uppercase) + 5 digits → AAAA_000.00. Returns nil if not enough.
function config_parse.parseTitleIdInput(s)
  if type(s) ~= "string" then return nil end
  local letters = (s:gsub("[^%a]", ""):sub(1, 4)):upper()
  local digits = s:gsub("%D", ""):sub(1, 5)
  if #letters == 4 and #digits == 5 then
    return letters .. "_" .. digits:sub(1, 3) .. "." .. digits:sub(4, 5)
  end
  return nil
end

-- eGSM option arrays live in config_options (options.lua). Parse delegates to them for getters and uses them for parse/build/validate.
local function getEgsmVideoOpts()
  local opt = _G.CONFIG_UI and _G.CONFIG_UI.config_options
  return opt and opt.getEgsmVideoOptions and opt.getEgsmVideoOptions()
end
local function getEgsmCompatOpts()
  local opt = _G.CONFIG_UI and _G.CONFIG_UI.config_options
  return opt and opt.getEgsmCompatOptions and opt.getEgsmCompatOptions()
end

function config_parse.getEgsmVideoOptions()
  return getEgsmVideoOpts()
end

function config_parse.getEgsmCompatOptions()
  return getEgsmCompatOpts()
end

-- Parse eGSM value string into 1-based video and compat indices. "disabled" or "" -> 1, 1.
function config_parse.parseEgsmValue(s)
  if type(s) ~= "string" or s == "" or s == "disabled" then return 1, 1 end
  local v, c = s:match("^([^:]*):?(.*)$")
  if not v then return 1, 1 end
  local EGSM_VIDEO, EGSM_COMPAT = getEgsmVideoOpts(), getEgsmCompatOpts()
  local vi, ci = 1, 1
  for i, opt in ipairs(EGSM_VIDEO) do if opt == v then
      vi = i
      break
    end end
  for i, opt in ipairs(EGSM_COMPAT) do if opt == c then
      ci = i
      break
    end end
  return vi, ci
end

-- Build eGSM value string from 1-based video and compat indices (per loader README v:c format).
function config_parse.buildEgsmValue(videoIdx, compatIdx)
  local EGSM_VIDEO, EGSM_COMPAT = getEgsmVideoOpts(), getEgsmCompatOpts()
  local v = EGSM_VIDEO[videoIdx] or ""
  local c = EGSM_COMPAT[compatIdx] or ""
  if v == "" then return "" end
  return v .. (c ~= "" and (":" .. c) or "")
end

function config_parse.isValidEgsmOption(s)
  if type(s) ~= "string" then return false end
  if s == "" or s == "disabled" then return true end
  local v, c = s:match("^([^:]*):?(.*)$")
  if not v then return false end
  local EGSM_VIDEO, EGSM_COMPAT = getEgsmVideoOpts(), getEgsmCompatOpts()
  for _, opt in ipairs(EGSM_VIDEO) do
    if v == opt then
      if c == "" then return true end
      for _, co in ipairs(EGSM_COMPAT) do
        if co ~= "" and c == co then return true end
      end
      return false
    end
  end
  return false
end

-- OSDGSM.CNF: default and per-title entries (title ID = AAAA_000.00). Commented = disabled; value is always stored (even when commented).
function config_parse.getEgsmDefault(lines)
  for _, e in ipairs(lines) do
    if e.key == "default" then return (e.value or ""), (e.comment and true or false) end
  end
  return "", false
end

function config_parse.setEgsmDefault(lines, value, commented)
  local storeVal = value or ""
  for _, e in ipairs(lines) do
    if e.key == "default" then
      e.value = storeVal
      e.comment = commented and true or false
      return
    end
  end
  config_parse.append(lines, "default", storeVal)
  local e = lines[#lines]
  if e and e.key == "default" then e.comment = commented and true or false end
end

function config_parse.getEgsmEntries(lines)
  local out = {}
  for _, e in ipairs(lines) do
    if e.key and config_parse.isValidTitleId(e.key) then
      table.insert(out, { titleId = e.key, value = (e.value or ""), commented = (e.comment and true or false) })
    end
  end
  table.sort(out, function(a, b) return (a.titleId or "") < (b.titleId or "") end)
  return out
end

function config_parse.setEgsmEntry(lines, titleId, value, commented)
  if not config_parse.isValidTitleId(titleId) then return false end
  local storeVal = value or ""
  for _, e in ipairs(lines) do
    if e.key == titleId then
      e.value = storeVal
      e.comment = commented and true or false
      return true
    end
  end
  table.insert(lines, { key = titleId, value = storeVal, comment = commented and true or false })
  return true
end

function config_parse.removeEgsmEntry(lines, titleId)
  for i = #lines, 1, -1 do
    if lines[i].key == titleId then
      table.remove(lines, i)
      return true
    end
  end
  return false
end

-- Regenerate OSDGSM.CNF lines: default first, then per-title entries (sorted). Commented = disabled but value is preserved.
function config_parse.regenerateLinesOsdgsm(lines)
  local defVal, defCommented = config_parse.getEgsmDefault(lines)
  local out = {}
  table.insert(out, { key = "default", value = defVal or "", comment = defCommented })
  for _, ent in ipairs(config_parse.getEgsmEntries(lines)) do
    table.insert(out, { key = ent.titleId, value = ent.value or "", comment = ent.commented })
  end
  return out
end

-- OSDMENU.CNF character limits (enforce in UI to avoid truncation on save)
config_parse.LIMIT_NAME = 79
config_parse.LIMIT_CURSOR = 19
config_parse.LIMIT_DELIMITER = 79
config_parse.LIMIT_DKWDRV = 49

function config_parse.clampLength(s, limit)
  if type(s) ~= "string" or type(limit) ~= "number" then return s end
  if #s <= limit then return s end
  return s:sub(1, limit)
end

-- OSDMENU.CNF menu entries: name_OSDSYS_ITEM_<N>, path1_OSDSYS_ITEM_<N>, path2_..., arg_OSDSYS_ITEM_<N> (multi).
-- Commented-out name_/path_/arg_ lines form a "disabled" entry; show in list and allow enabling (triangle).

-- Return sorted list of menu entries: { idx = number, disabled = boolean } (includes commented entries).
function config_parse.getMenuEntryIndices(lines)
  local byIdx = {}
  for _, entry in ipairs(lines) do
    if entry.key then
      local n = entry.key:match("^name_OSDSYS_ITEM_(%d+)$")
      if n then
        local idx = tonumber(n)
        byIdx[idx] = not not entry.comment
      end
    end
  end
  local out = {}
  for k, disabled in pairs(byIdx) do table.insert(out, { idx = k, disabled = disabled }) end
  table.sort(out, function(a, b) return a.idx < b.idx end) -- config order (lowest idx first)
  return out
end

-- Insert a new menu entry below the given index (so it appears right after that entry in the list).
-- belowIdx is the actual config index of the entry to insert after (there may be gaps in indices).
-- Shift only existing entries with idx > belowIdx to idx+1 (descending order), then add at belowIdx+1.
-- If belowIdx is 0 (no entries), adds at index 1. Returns the new entry's index.
function config_parse.insertMenuEntryBelow(lines, belowIdx, name)
  local entries = config_parse.getMenuEntryIndices(lines)
  if #entries == 0 then
    config_parse.addMenuEntry(lines, 1, name)
    return 1
  end
  local indicesToShift = {}
  for _, e in ipairs(entries) do
    if e.idx > belowIdx then table.insert(indicesToShift, e.idx) end
  end
  table.sort(indicesToShift, function(a, b) return a > b end)
  for _, idx in ipairs(indicesToShift) do
    config_parse.changeMenuEntryIndex(lines, idx, idx + 1)
  end
  config_parse.addMenuEntry(lines, belowIdx + 1, name)
  return belowIdx + 1
end

-- Name for display (from commented or uncommented name_ line).
function config_parse.getMenuEntryName(lines, idx)
  local val = config_parse.getWithComment(lines, "name_OSDSYS_ITEM_" .. tostring(idx))
  return val
end

-- True if the menu entry at idx is commented (disabled).
function config_parse.isMenuEntryDisabled(lines, idx)
  local _, commented = config_parse.getWithComment(lines, "name_OSDSYS_ITEM_" .. tostring(idx))
  return commented and true or false
end

-- Set all lines for this menu entry (name, path*, arg) to commented or not.
-- When disabling: use comment = 2 (##) for path/arg lines that were already commented (per-item disabled), so enabling the entry later restores their disabled state.
-- When enabling: uncomment only lines with comment == true; leave comment = true where comment == 2 (was double-disabled).
function config_parse.setMenuEntryDisabled(lines, idx, disabled)
  local idxStr = tostring(idx)
  local nameKey = "name_OSDSYS_ITEM_" .. idxStr
  local pathPat = "^path%d+_OSDSYS_ITEM_" .. idxStr .. "$"
  local argKey = "arg_OSDSYS_ITEM_" .. idxStr
  for _, entry in ipairs(lines) do
    if entry.key and (entry.key == nameKey or entry.key:match(pathPat) or entry.key == argKey) then
      if disabled then
        entry.comment = entry.comment and 2 or true                                  -- already commented (per-item) -> ## (2)
      else
        if entry.comment == 2 then entry.comment = true else entry.comment = nil end -- ## -> keep commented; # -> uncomment
      end
    end
  end
end

function config_parse.setMenuEntryName(lines, idx, name)
  config_parse.set(lines, "name_OSDSYS_ITEM_" .. tostring(idx), name or "")
end

-- Paths: path1_OSDSYS_ITEM_<idx>, path2_..., etc. Return in order: { value, disabled [, comment] } (includes commented lines).
-- When entry is disabled: only comment == 2 (##) is "individually disabled"; comment == true (#) shows as enabled.
-- When entry is enabled: any comment (true or 2) means disabled. comment is preserved for regenerateLines.
function config_parse.getMenuEntryPaths(lines, idx)
  local idxStr = tostring(idx)
  local entryDisabled = config_parse.isMenuEntryDisabled(lines, idx)
  local pattern = "^path(%d+)_OSDSYS_ITEM_" .. idxStr .. "$"
  local byNum = {}
  for _, entry in ipairs(lines) do
    if entry.key then
      local num = entry.key:match(pattern)
      if num then
        local c = entry.comment
        local disabled = entryDisabled and (c == 2) or (not entryDisabled and (not not c))
        byNum[tonumber(num)] = { value = entry.value, disabled = disabled, comment = c }
      end
    end
  end
  local out = {}
  for n = 1, 200 do
    if byNum[n] then table.insert(out, byNum[n]) else break end
  end
  return out
end

-- Replace all path*_OSDSYS_ITEM_<idx> with the given list. Each item is { value, disabled } or a plain value (treated as enabled).
function config_parse.setMenuEntryPaths(lines, idx, paths)
  local idxStr = tostring(idx)
  local pattern = "^path(%d+)_OSDSYS_ITEM_" .. idxStr .. "$"
  local i = 1
  while i <= #lines do
    local e = lines[i]
    if e.key and e.key:match(pattern) then
      table.remove(lines, i)
    else
      i = i + 1
    end
  end
  local entryDisabled = config_parse.isMenuEntryDisabled(lines, idx)
  for pnum, item in ipairs(paths or {}) do
    local v = type(item) == "table" and item.value or item
    local disabled = type(item) == "table" and item.disabled
    table.insert(lines,
      { key = "path" .. tostring(pnum) .. "_OSDSYS_ITEM_" .. idxStr, value = v, comment = disabled and
      (entryDisabled and 2 or true) or nil })
  end
end

-- Args for this entry (includes commented lines). Return in order: { value, disabled [, comment] }.
-- When entry is disabled: only comment == 2 (##) is "individually disabled"; comment == true (#) shows as enabled.
-- When entry is enabled: any comment (true or 2) means disabled. comment is preserved for regenerateLines.
function config_parse.getMenuEntryArgs(lines, idx)
  local key = "arg_OSDSYS_ITEM_" .. tostring(idx)
  local entryDisabled = config_parse.isMenuEntryDisabled(lines, idx)
  local out = {}
  for _, entry in ipairs(lines) do
    if entry.key and entry.key == key then
      local c = entry.comment
      local disabled = entryDisabled and (c == 2) or (not entryDisabled and (not not c))
      table.insert(out, { value = entry.value, disabled = disabled, comment = c })
    end
  end
  return out
end

-- Replace all arg_OSDSYS_ITEM_<idx> with the given list. Each item is { value, disabled } or a plain value (treated as enabled).
function config_parse.setMenuEntryArgs(lines, idx, args)
  local key = "arg_OSDSYS_ITEM_" .. tostring(idx)
  local i = 1
  while i <= #lines do
    if lines[i].key == key then
      table.remove(lines, i)
    else
      i = i + 1
    end
  end
  local entryDisabled = config_parse.isMenuEntryDisabled(lines, idx)
  for _, item in ipairs(args or {}) do
    local v = type(item) == "table" and item.value or item
    local disabled = type(item) == "table" and item.disabled
    table.insert(lines, { key = key, value = v, comment = disabled and (entryDisabled and 2 or true) or nil })
  end
end

-- Set disabled state of one path (1-based path index). Menu entry only.
-- When entry is disabled, use comment = 2 (##) so path shows as individually disabled.
function config_parse.setPathDisabled(lines, idx, pathNum, disabled)
  local key = "path" .. tostring(pathNum) .. "_OSDSYS_ITEM_" .. tostring(idx)
  for _, entry in ipairs(lines) do
    if entry.key and entry.key == key then
      entry.comment = disabled and (config_parse.isMenuEntryDisabled(lines, idx) and 2 or true) or nil
      return
    end
  end
end

-- Set disabled state of one argument (1-based arg index). Menu entry only.
-- When entry is disabled, use comment = 2 (##) so arg shows as individually disabled.
function config_parse.setArgDisabled(lines, idx, argNum, disabled)
  local key = "arg_OSDSYS_ITEM_" .. tostring(idx)
  local n = 0
  for _, entry in ipairs(lines) do
    if entry.key and entry.key == key then
      n = n + 1
      if n == argNum then
        entry.comment = disabled and (config_parse.isMenuEntryDisabled(lines, idx) and 2 or true) or nil
        return
      end
    end
  end
end

-- Remove all lines for this menu entry (name, path*, arg).
function config_parse.removeMenuEntry(lines, idx)
  local idxStr = tostring(idx)
  local i = 1
  while i <= #lines do
    local e = lines[i]
    if e.key then
      if e.key == "name_OSDSYS_ITEM_" .. idxStr then
        table.remove(lines, i); goto again
      end
      if e.key == "arg_OSDSYS_ITEM_" .. idxStr then
        table.remove(lines, i); goto again
      end
      if e.key:match("^path%d+_OSDSYS_ITEM_" .. idxStr .. "$") then
        table.remove(lines, i); goto again
      end
    end
    i = i + 1
    ::again::
  end
end

-- Add a new menu entry with given index (name only; paths/args empty). Caller can set paths after. name may be "" (empty).
function config_parse.addMenuEntry(lines, idx, name)
  config_parse.set(lines, "name_OSDSYS_ITEM_" .. tostring(idx), name == nil and "New entry" or name)
end

-- Move menu entry from oldIdx to newIdx (copy name/paths/args to new index, then remove old). Fails if newIdx is used by another entry.
-- Preserves disabled (commented) state.
function config_parse.changeMenuEntryIndex(lines, oldIdx, newIdx)
  if oldIdx == newIdx then return true end
  local newStr = tostring(newIdx)
  local existing = config_parse.getWithComment(lines, "name_OSDSYS_ITEM_" .. newStr)
  if existing ~= nil then return false end -- already used
  local disabled = config_parse.isMenuEntryDisabled(lines, oldIdx)
  local name = config_parse.getMenuEntryName(lines, oldIdx)
  local paths = config_parse.getMenuEntryPaths(lines, oldIdx)
  local args = config_parse.getMenuEntryArgs(lines, oldIdx)
  config_parse.set(lines, "name_OSDSYS_ITEM_" .. newStr, name or "")
  config_parse.setMenuEntryPaths(lines, newIdx, paths)
  config_parse.setMenuEntryArgs(lines, newIdx, args)
  config_parse.setMenuEntryDisabled(lines, newIdx, disabled)
  config_parse.removeMenuEntry(lines, oldIdx)
  return true
end

-- Swap content of two menu entries (name, paths, args). Both indices must exist. Used for reordering.
-- Preserves disabled (commented) state for each entry.
function config_parse.swapMenuEntryContent(lines, idxA, idxB)
  if idxA == idxB then return true end
  local nameA = config_parse.getMenuEntryName(lines, idxA)
  local nameB = config_parse.getMenuEntryName(lines, idxB)
  if not nameA or not nameB then return false end
  local disabledA = config_parse.isMenuEntryDisabled(lines, idxA)
  local disabledB = config_parse.isMenuEntryDisabled(lines, idxB)
  local pathsA = config_parse.getMenuEntryPaths(lines, idxA)
  local pathsB = config_parse.getMenuEntryPaths(lines, idxB)
  local argsA = config_parse.getMenuEntryArgs(lines, idxA)
  local argsB = config_parse.getMenuEntryArgs(lines, idxB)
  config_parse.removeMenuEntry(lines, idxA)
  config_parse.removeMenuEntry(lines, idxB)
  config_parse.set(lines, "name_OSDSYS_ITEM_" .. tostring(idxA), nameB)
  config_parse.setMenuEntryPaths(lines, idxA, pathsB)
  config_parse.setMenuEntryArgs(lines, idxA, argsB)
  config_parse.setMenuEntryDisabled(lines, idxA, disabledB)
  config_parse.set(lines, "name_OSDSYS_ITEM_" .. tostring(idxB), nameA)
  config_parse.setMenuEntryPaths(lines, idxB, pathsA)
  config_parse.setMenuEntryArgs(lines, idxB, argsA)
  config_parse.setMenuEntryDisabled(lines, idxB, disabledA)
  return true
end

-- True if key is a menu entry key (name/path/arg for OSDSYS_ITEM_*).
local function isMenuKey(key)
  if type(key) ~= "string" then return false end
  return key:match("^name_OSDSYS_ITEM_%d+$") or key:match("^path%d+_OSDSYS_ITEM_%d+$") or
      key:match("^arg_OSDSYS_ITEM_%d+$")
end

local SEPARATOR = "#----------------------------------"

local function toFreemcbootKeyId(keyId)
  local canonical = canonicalBblHotkeyId(keyId)
  if not canonical then return tostring(keyId or "") end
  if canonical:match("^[A-Z]+$") then
    return canonical:sub(1, 1) .. canonical:sub(2):lower()
  end
  return canonical
end

local function appendFreemcbootLaunchKeys(out, lines, maxEntries)
  local keys = { "AUTO" }
  for _, k in ipairs(config_parse.getBblHotkeys() or {}) do
    keys[#keys + 1] = k
  end
  for _, keyId in ipairs(keys) do
    local added = false
    for slot = 1, maxEntries do
      local path, disabled = config_parse.getBblHotkeyPath(lines, keyId, slot)
      if path ~= nil then
        local saveKeyId = toFreemcbootKeyId(keyId)
        out[#out + 1] = {
          key = "LK_" .. tostring(saveKeyId) .. "_E" .. tostring(slot),
          value = path or "",
          comment = disabled and true or nil
        }
        added = true
      end
    end
    if added then
      out[#out + 1] = { comment = SEPARATOR }
    end
  end
end

-- Regenerate OSDMENU lines from in-memory state. Optional categories: list of { name, options = { { key }, ... } }
-- so globals are output by category with a separator after each category; then each menu entry block with a separator after each. No unknown keys.
-- When categories is nil, globals are output in original order with no separators.
-- includeArgs=false skips arg_OSDSYS_ITEM_* lines. maxEntries / maxPathsPerEntry apply per output order when provided.
function config_parse.regenerateLines(lines, categories, includeArgs, maxEntries, maxPathsPerEntry)
  local out = {}
  local allowArgs = includeArgs ~= false
  local function addSep()
    table.insert(out, { comment = SEPARATOR })
  end

  if categories and #categories > 0 then
    for _, cat in ipairs(categories) do
      local added = false
      for _, o in ipairs(cat.options or {}) do
        local k = o.key
        if k and k:sub(1, 1) ~= "_" then
          local v = config_parse.get(lines, k)
          if v ~= nil then
            table.insert(out, { key = k, value = v }); added = true
          end
        end
      end
      if added then addSep() end
    end
  else
    for _, e in ipairs(lines) do
      if e.key and not isMenuKey(e.key) and not e.comment then
        table.insert(out, { key = e.key, value = e.value })
      end
    end
  end

  local entries = config_parse.getMenuEntryIndices(lines)
  for entPos, ent in ipairs(entries) do
    if type(maxEntries) == "number" and maxEntries >= 0 and entPos > maxEntries then
      break
    end
    local idx = ent.idx
    local disabled = ent.disabled
    local name = config_parse.getMenuEntryName(lines, idx) or ""
    table.insert(out, { key = "name_OSDSYS_ITEM_" .. tostring(idx), value = name, comment = disabled })
    local paths = config_parse.getMenuEntryPaths(lines, idx)
    local pathLimit = #paths
    if type(maxPathsPerEntry) == "number" and maxPathsPerEntry >= 0 then
      pathLimit = math.min(pathLimit, maxPathsPerEntry)
    end
    for i = 1, pathLimit do
      local p = paths[i]
      local pv = type(p) == "table" and p.value or p
      local pc = type(p) == "table" and p.comment or nil
      -- ## only when entry disabled AND path was individually disabled (comment == 2); else # or nil
      local pcomment = disabled and (pc == 2 and 2 or true) or (pc and true or nil)
      table.insert(out,
        { key = "path" .. tostring(i) .. "_OSDSYS_ITEM_" .. tostring(idx), value = pv, comment = pcomment })
    end
    if allowArgs then
      local args = config_parse.getMenuEntryArgs(lines, idx)
      for _, a in ipairs(args) do
        local av = type(a) == "table" and a.value or a
        local ac = type(a) == "table" and a.comment or nil
        local acomment = disabled and (ac == 2 and 2 or true) or (ac and true or nil)
        table.insert(out, { key = "arg_OSDSYS_ITEM_" .. tostring(idx), value = av, comment = acomment })
      end
    end
    addSep()
  end
  return out
end

-- Regenerate OSDMBR.CNF: paths+args per boot_* with separator after each; then cdrom_/ps1drv_ options + separator; then prefer_bbn and osd_* options. No unknown keys.
function config_parse.regenerateLinesMBR(lines, options)
  if not options or #options == 0 then return lines end
  local out = {}
  -- Segment 1: each boot_* paths + args, separator after each
  for _, o in ipairs(options) do
    local k = o.key
    if not k or k:sub(1, 1) == "_" then goto continue end
    if o.optType == "boot_paths" then
      local paths = config_parse.getBootPaths(lines, k)
      for _, p in ipairs(paths) do
        table.insert(out, { key = k, value = p })
      end
      local args = config_parse.getBootArgs(lines, k)
      for idx, a in ipairs(args) do
        table.insert(out, { key = k .. "_arg" .. tostring(idx), value = a })
      end
      table.insert(out, { comment = SEPARATOR })
    end
    ::continue::
  end
  -- Segment 2: cdrom_* and ps1drv_* options
  for _, o in ipairs(options) do
    local k = o.key
    if not k or k:sub(1, 1) == "_" or o.optType == "boot_paths" then goto continue end
    if k:match("^cdrom_") or k:match("^ps1drv_") then
      local v = config_parse.get(lines, k)
      if v ~= nil then
        table.insert(out, { key = k, value = v })
      end
    end
    ::continue::
  end
  table.insert(out, { comment = SEPARATOR })
  -- Segment 3: prefer_bbn, app_gameid, and osd_* options
  for _, o in ipairs(options) do
    local k = o.key
    if not k or k:sub(1, 1) == "_" or o.optType == "boot_paths" then goto continue end
    if k == "prefer_bbn" or k == "app_gameid" or k:match("^osd_") then
      local v = config_parse.get(lines, k)
      if v ~= nil then
        table.insert(out, { key = k, value = v })
      end
    end
    ::continue::
  end
  return out
end

-- Regenerate lines for save based on file type. options = config_options table (osdmenu_cnf_categories, osdmbr_cnf, etc.).
function config_parse.regenerateForSave(lines, fileType, options)
  if not lines or not fileType then return lines end
  local opt = options or {}
  if fileType == "osdmenu_cnf" then
    return config_parse.regenerateLines(lines, opt.osdmenu_cnf_categories or {})
  end
  if fileType == "freemcboot_cnf" then
    local cats = opt.freemcboot_cnf_categories or opt.osdmenu_cnf_categories or {}
    local maxEntries = (type(opt.FMCB_MAX_ENTRIES) == "number" and opt.FMCB_MAX_ENTRIES) or 99
    local maxPathsPerEntry = (type(opt.FMCB_MAX_PATHS_PER_ENTRY) == "number" and opt.FMCB_MAX_PATHS_PER_ENTRY) or 3
    local out = config_parse.regenerateLines(lines, cats, false, maxEntries, maxPathsPerEntry)
    local cnfVersion = config_parse.get(lines, "CNF_version") or "1"
    table.insert(out, 1, { key = "CNF_version", value = cnfVersion })
    table.insert(out, 2, { comment = SEPARATOR })
    local maxLaunchKeyEntries = (type(opt.FMCB_BBL_MAX_ENTRIES) == "number" and opt.FMCB_BBL_MAX_ENTRIES) or 3
    appendFreemcbootLaunchKeys(out, lines, maxLaunchKeyEntries)
    return out
  end
  if fileType == "osdmbr_cnf" then
    return config_parse.regenerateLinesMBR(lines, opt.osdmbr_cnf or {})
  end
  if fileType == "osdgsm_cnf" then
    return config_parse.regenerateLinesOsdgsm(lines)
  end
  return lines
end

return config_parse
