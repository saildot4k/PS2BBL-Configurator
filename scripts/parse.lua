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
      local afterHash = trim(rest:sub(2))
      local ke, ve = afterHash:match("^(.+)%s*=%s*(.*)$")
      if ke and ve ~= nil then
        table.insert(lines, { key = trim(ke), value = trim(ve), comment = true })
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
      table.insert(t, "# " .. entry.key .. " = " .. (entry.value or ""))
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

-- eGSM option: video (empty, fp1, fp2, 1080ix1, 1080ix2, 1080ix3) and optional :c (c = 1,2,3).
local EGSM_VIDEO = { "", "fp1", "fp2", "1080ix1", "1080ix2", "1080ix3" }
local EGSM_COMPAT = { "", "1", "2", "3" }

function config_parse.getEgsmVideoOptions()
  return EGSM_VIDEO
end

function config_parse.getEgsmCompatOptions()
  return EGSM_COMPAT
end

function config_parse.isValidEgsmOption(s)
  if type(s) ~= "string" then return false end
  if s == "" or s == "disabled" then return true end
  local v, c = s:match("^([^:]*):?(.*)$")
  if not v then return false end
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

-- eGSM enum options for UI: disabled, then video and video:compat (no empty/—).
function config_parse.getEgsmEnumOptions()
  local out = { "disabled" }
  for _, v in ipairs(EGSM_VIDEO) do
    if v ~= "" then
      table.insert(out, v)
      for _, c in ipairs(EGSM_COMPAT) do
        if c ~= "" then table.insert(out, v .. ":" .. c) end
      end
    end
  end
  return out
end

-- OSDGSM.CNF: default and per-title entries (title ID = AAAA_000.00). Commented = disabled; stored value is "" (empty), not "disabled".
function config_parse.getEgsmDefault(lines)
  for _, e in ipairs(lines) do
    if e.key == "default" then return (e.comment and "disabled") or (e.value or "") end
  end
  return ""
end

function config_parse.setEgsmDefault(lines, value)
  local isDisabled = (value == "disabled")
  local storeVal = isDisabled and "" or (value or "")
  for _, e in ipairs(lines) do
    if e.key == "default" then
      e.value = storeVal
      e.comment = isDisabled
      return
    end
  end
  config_parse.append(lines, "default", storeVal)
  local e = lines[#lines]
  if e and e.key == "default" then e.comment = isDisabled end
end

function config_parse.getEgsmEntries(lines)
  local out = {}
  for _, e in ipairs(lines) do
    if e.key and config_parse.isValidTitleId(e.key) then
      local commented = not not e.comment
      local displayVal = (commented and "disabled") or (e.value or "")
      table.insert(out, { titleId = e.key, value = displayVal, commented = commented })
    end
  end
  table.sort(out, function(a, b) return (a.titleId or "") < (b.titleId or "") end)
  return out
end

function config_parse.setEgsmEntry(lines, titleId, value, commented)
  if not config_parse.isValidTitleId(titleId) then return false end
  local isDisabled = (value == "disabled" or commented)
  local storeVal = isDisabled and "" or (value or "")
  for _, e in ipairs(lines) do
    if e.key == titleId then
      e.value = storeVal
      e.comment = isDisabled
      return true
    end
  end
  table.insert(lines, { key = titleId, value = storeVal, comment = isDisabled })
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

-- Regenerate OSDGSM.CNF lines: default first, then per-title entries (sorted). Disabled = comment with empty value.
function config_parse.regenerateLinesOsdgsm(lines)
  local def = config_parse.getEgsmDefault(lines)
  local out = {}
  table.insert(out, { key = "default", value = (def == "disabled") and "" or def, comment = (def == "disabled") })
  for _, ent in ipairs(config_parse.getEgsmEntries(lines)) do
    table.insert(out, { key = ent.titleId, value = ent.commented and "" or ent.value, comment = ent.commented })
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
function config_parse.setMenuEntryDisabled(lines, idx, disabled)
  local idxStr = tostring(idx)
  local nameKey = "name_OSDSYS_ITEM_" .. idxStr
  local pathPat = "^path%d+_OSDSYS_ITEM_" .. idxStr .. "$"
  local argKey = "arg_OSDSYS_ITEM_" .. idxStr
  for _, entry in ipairs(lines) do
    if entry.key and (entry.key == nameKey or entry.key:match(pathPat) or entry.key == argKey) then
      entry.comment = disabled and true or nil
    end
  end
end

function config_parse.setMenuEntryName(lines, idx, name)
  config_parse.set(lines, "name_OSDSYS_ITEM_" .. tostring(idx), name or "")
end

-- Paths: path1_OSDSYS_ITEM_<idx>, path2_..., etc. Return values in order (includes commented lines).
function config_parse.getMenuEntryPaths(lines, idx)
  local idxStr = tostring(idx)
  local pattern = "^path(%d+)_OSDSYS_ITEM_" .. idxStr .. "$"
  local byNum = {}
  for _, entry in ipairs(lines) do
    if entry.key then
      local num = entry.key:match(pattern)
      if num then byNum[tonumber(num)] = entry.value end
    end
  end
  local out = {}
  for n = 1, 200 do
    if byNum[n] then table.insert(out, byNum[n]) else break end
  end
  return out
end

-- Replace all path*_OSDSYS_ITEM_<idx> with the given list.
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
  for pnum, pval in ipairs(paths or {}) do
    config_parse.append(lines, "path" .. tostring(pnum) .. "_OSDSYS_ITEM_" .. idxStr, pval)
  end
end

-- Args for this entry (includes commented lines so disabled entries keep their args).
function config_parse.getMenuEntryArgs(lines, idx)
  local key = "arg_OSDSYS_ITEM_" .. tostring(idx)
  local out = {}
  for _, entry in ipairs(lines) do
    if entry.key and entry.key == key then table.insert(out, entry.value) end
  end
  return out
end

-- Replace all arg_OSDSYS_ITEM_<idx> with the given list.
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
  for _, v in ipairs(args or {}) do
    config_parse.append(lines, key, v)
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

-- Add a new menu entry with given index (name only; paths/args empty). Caller can set paths after.
function config_parse.addMenuEntry(lines, idx, name)
  config_parse.set(lines, "name_OSDSYS_ITEM_" .. tostring(idx), name or "New entry")
end

-- Move menu entry from oldIdx to newIdx (copy name/paths/args to new index, then remove old). Fails if newIdx is used by another entry.
-- Preserves disabled (commented) state.
function config_parse.changeMenuEntryIndex(lines, oldIdx, newIdx)
  if oldIdx == newIdx then return true end
  local oldStr = tostring(oldIdx)
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

-- Regenerate OSDMENU lines from in-memory state. Optional categories: list of { name, options = { { key }, ... } }
-- so globals are output by category with a separator after each category; then each menu entry block with a separator after each. No unknown keys.
-- When categories is nil, globals are output in original order with no separators.
function config_parse.regenerateLines(lines, categories)
  local out = {}
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
  for _, ent in ipairs(entries) do
    local idx = ent.idx
    local disabled = ent.disabled
    local name = config_parse.getMenuEntryName(lines, idx) or ""
    table.insert(out, { key = "name_OSDSYS_ITEM_" .. tostring(idx), value = name, comment = disabled })
    local paths = config_parse.getMenuEntryPaths(lines, idx)
    for i, p in ipairs(paths) do
      table.insert(out,
        { key = "path" .. tostring(i) .. "_OSDSYS_ITEM_" .. tostring(idx), value = p, comment = disabled })
    end
    local args = config_parse.getMenuEntryArgs(lines, idx)
    for _, a in ipairs(args) do
      table.insert(out, { key = "arg_OSDSYS_ITEM_" .. tostring(idx), value = a, comment = disabled })
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
  if fileType == "osdmbr_cnf" then
    return config_parse.regenerateLinesMBR(lines, opt.osdmbr_cnf or {})
  end
  if fileType == "osdgsm_cnf" then
    return config_parse.regenerateLinesOsdgsm(lines)
  end
  return lines
end

return config_parse
