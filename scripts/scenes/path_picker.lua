--[[ Path picker: device list, partitions, or directory browse. ]]

-- Apply chosen path for MBR boot key and return next state. Returns nil if not a boot-key pick.
local function applyBootPathAndReturn(ctx, val)
  if not ctx.pathPickerBootKey or not ctx.lines then return nil end
  local _ = ctx._
  if ctx.pathPickerEditIdx then
    local paths = _.config_parse.getBootPaths(ctx.lines, ctx.pathPickerBootKey) or {}
    paths[ctx.pathPickerEditIdx] = val
    _.config_parse.setBootPaths(ctx.lines, ctx.pathPickerBootKey, paths)
  else
    _.config_parse.append(ctx.lines, ctx.pathPickerBootKey, val)
  end
  ctx.state = ctx.pathPickerReturnState or "editor"
  ctx.pathPickerBootKey = nil
  ctx.pathPickerReturnState = nil
  ctx.pathPickerForEntryIdx = nil
  ctx.pathPickerEditIdx = nil
  return true
end

-- Convert pfs path (pfs0:/ or pfs1:/...) to full partition path (hdd0:PART:pfs:...). Returns nil if not a pfs path.
local function pfsToPartitionPath(pfsPath, partitionPath)
  if not pfsPath or not partitionPath then return nil end
  local rest = pfsPath:match("^pfs[01]:/?(.*)$")
  if not rest then return nil end
  if rest == "" then return partitionPath .. ":pfs:/" end
  return partitionPath .. ":pfs:" .. rest
end

-- IOP reset (mx4sio/mmce) unloads all device drivers; clear all loaded flags.
local function clearLoadedIfIopReset(ctx)
  ctx.pathPickerLoadedDeviceTypes = {}
end

-- Apply a manually entered path and leave path picker (used by "Enter path manually" text input callback).
local function applyManualPath(ctx, val)
  if not val or val == "" then
    -- Done with empty path: return to entry paths or path_picker so we don't show "Choose device" / "No devices"
    if ctx.pathPickerForEntryIdx then
      ctx.entryIdx = ctx.pathPickerForEntryIdx
      ctx.state = (ctx.pathPickerEditIdx and "entry_paths") or "menu_entry_edit"
      ctx.pathPickerForEntryIdx = nil
      ctx.pathPickerEditIdx = nil
    else
      ctx.state = ctx.pathPickerReturnState or "editor"
    end
    ctx.pathList = nil
    ctx.pathPickerReturnState = nil
    return
  end
  local _ = ctx._
  if ctx.pfs0Mounted and System.fileXioUmount then System.fileXioUmount("pfs0:") end
  if ctx.pfs1Mounted and System.fileXioUmount then System.fileXioUmount("pfs1:") end
  ctx.pathList = nil
  ctx.pathBrowsePath = nil
  ctx.pfs0Mounted = nil
  ctx.pfs1Mounted = nil
  ctx.configModified = true
  if applyBootPathAndReturn(ctx, val) then
  elseif ctx.pathPickerForEntryIdx then
    local paths = _.config_parse.getMenuEntryPaths(ctx.lines, ctx.pathPickerForEntryIdx)
    if ctx.pathPickerEditIdx then paths[ctx.pathPickerEditIdx] = val else table.insert(paths, val) end
    _.config_parse.setMenuEntryPaths(ctx.lines, ctx.pathPickerForEntryIdx, paths)
    ctx.entryIdx = ctx.pathPickerForEntryIdx
    ctx.state = (ctx.pathPickerEditIdx and "entry_paths") or "menu_entry_edit"
    ctx.pathPickerForEntryIdx = nil
    ctx.pathPickerEditIdx = nil
  elseif ctx.isAddPath then
    local key = (ctx.addPathKey == "path1_OSDSYS_ITEM_1") and _.resolveNextOsdItemKey(ctx.lines) or ctx.addPathKey
    _.config_parse.append(ctx.lines, key, val)
    ctx.state = "editor"
  else
    _.config_parse.set(ctx.lines, ctx.editKey or "", val)
    ctx.state = "editor"
  end
  ctx.pathPickerBootKey = nil
  ctx.pathPickerReturnState = nil
  ctx.pathPickerBdmPrefix = nil
  ctx.pathPickerBdmMountpoint = nil
end

local function run(ctx)
  local _ = ctx._
  -- Wildcard confirm: path is mc0/mc1/mmce0/mmce1; Cross = Yes (use wildcard), Circle = No (use as-is)
  if ctx.pathPickerWildcardConfirm and ctx.pathPickerPendingPath then
    local val = ctx.pathPickerPendingPath
    local mode = ctx.pathPickerWildcardMode or "single"
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1, _.path_str.wildcard_confirm_title, _.WHITE)
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y + _.scaleY(28), _.FONT_SCALE, val, _.GRAY)
    _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, _.path_str.wildcard_confirm_hint, nil, _.DIM,
      _.w - 2 * _.MARGIN_X)
    local function applyAndExit(chosenVal)
      ctx.configModified = true
      if mode == "single" then
        _.config_parse.set(ctx.lines, ctx.editKey, chosenVal)
        ctx.state = "editor"
      elseif mode == "entry" then
        local paths = _.config_parse.getMenuEntryPaths(ctx.lines, ctx.pathPickerForEntryIdx)
        if ctx.pathPickerEditIdx then paths[ctx.pathPickerEditIdx] = chosenVal else table.insert(paths, chosenVal) end
        _.config_parse.setMenuEntryPaths(ctx.lines, ctx.pathPickerForEntryIdx, paths)
        ctx.entryIdx = ctx.pathPickerForEntryIdx
        ctx.state = ctx.pathPickerReturnState or (ctx.pathPickerEditIdx and "entry_paths") or "menu_entry_edit"
        ctx.pathPickerForEntryIdx = nil
        ctx.pathPickerEditIdx = nil
        ctx.pathPickerReturnState = nil
      elseif mode == "add" then
        local key = (ctx.addPathKey == "path1_OSDSYS_ITEM_1") and _.resolveNextOsdItemKey(ctx.lines) or ctx.addPathKey
        _.config_parse.append(ctx.lines, key, chosenVal)
        ctx.state = "editor"
      elseif mode == "boot" then
        if ctx.pathPickerEditIdx then
          local paths = _.config_parse.getBootPaths(ctx.lines, ctx.pathPickerBootKey) or {}
          paths[ctx.pathPickerEditIdx] = chosenVal
          _.config_parse.setBootPaths(ctx.lines, ctx.pathPickerBootKey, paths)
        else
          _.config_parse.append(ctx.lines, ctx.pathPickerBootKey, chosenVal)
        end
        ctx.state = ctx.pathPickerReturnState or "editor"
        ctx.pathPickerBootKey = nil
        ctx.pathPickerReturnState = nil
        ctx.pathPickerEditIdx = nil
      end
      ctx.pathPickerWildcardConfirm = nil
      ctx.pathPickerPendingPath = nil
      ctx.pathPickerWildcardMode = nil
      ctx.pathPickerBdmPrefix = nil
      ctx.pathPickerBdmMountpoint = nil
      if ctx.pfs0Mounted and System.fileXioUmount then System.fileXioUmount("pfs0:") end
      if ctx.pfs1Mounted and System.fileXioUmount then System.fileXioUmount("pfs1:") end
      ctx.pathList = nil
      ctx.pathBrowsePath = nil
      ctx.pfs0Mounted = nil
      ctx.pfs1Mounted = nil
    end
    if (_.padEffective & _.PAD_CROSS) ~= 0 then
      applyAndExit(_.file_selector.toWildcard(val))
    elseif (_.padEffective & _.PAD_CIRCLE) ~= 0 then
      applyAndExit(val)
    end
    return
  end
  if ctx.pathPickerSub == "device" then
    -- Loading state: probe every ~200ms, 3s timeout; show splash only when waiting
    if ctx.pathPickerLoading then
      local load = ctx.pathPickerLoading
      local PROBE_INTERVAL_FRAMES = 12 -- ~200ms at 60fps
      local LOAD_TIMEOUT_FRAMES = 180  -- 3s at 60fps
      -- Draw splash first so it shows before any blocking loadModules()
      if not (ctx.pathPickerLoadingFrames and ctx.pathPickerLoadingFrames >= LOAD_TIMEOUT_FRAMES) then
        local msg = _.path_str.waiting_for_device_drivers
        local tw = _.common.calcTextWidth(_.font, msg, 1)
        local cx = _.common.centerX(_, tw)
        local cy = math.floor((_.MARGIN_Y + _.HINT_Y) / 2) - math.floor((_.LINE_H or 20) / 2)
        _.drawText(_.font, _.drawMode, cx, cy, 1, msg, _.WHITE)
      end
      _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7,
        _.path_str.circle_back_items, nil, _.DIM, _.w - 2 * _.MARGIN_X)
      ctx.pathPickerLoadingFrames = (ctx.pathPickerLoadingFrames or 0) + 1
      -- Load drivers on frame 2 so the first splash frame is presented before blocking (same for all HDD/BDM)
      if ctx.pathPickerLoadingFrames == 2 and not ctx.pathPickerModulesLoaded and load.deviceType and System and System.loadModules then
        System.loadModules(load.deviceType)
        ctx.pathPickerModulesLoaded = true
      end
      local mp = nil
      if load.staticHdd then
        if ctx.pathPickerLoadingFrames > 0 and ctx.pathPickerLoadingFrames % PROBE_INTERVAL_FRAMES == 0 then
          if _.common.isHddPresent and _.common.isHddPresent() then
            ctx.pathPickerLoading = nil
            ctx.pathPickerLoadingFrames = nil
            ctx.pathPickerModulesLoaded = nil
            ctx.pathPickerLoadedDeviceTypes = ctx.pathPickerLoadedDeviceTypes or {}
            ctx.pathPickerLoadedDeviceTypes["hdd"] = true
            ctx.pathPickerSub = "partitions"
            ctx.pathList = _.file_selector.getHddPartitions(0) or {}
            ctx.pathBrowsePath = "hdd0:"
            ctx.pathPickerSel = 1
            ctx.pathPickerScroll = 0
          end
        end
      else
        if ctx.pathPickerLoadingFrames > 0 and ctx.pathPickerLoadingFrames % PROBE_INTERVAL_FRAMES == 0 then
          mp = (System and System.getDeviceMountpoint) and System.getDeviceMountpoint(load.deviceId) or nil
        end
        if mp and mp ~= "" then
          ctx.pathPickerLoading = nil
          ctx.pathPickerLoadingFrames = nil
          ctx.pathPickerModulesLoaded = nil
          ctx.pathPickerLoadedDeviceTypes = ctx.pathPickerLoadedDeviceTypes or {}
          ctx.pathPickerLoadedDeviceTypes[load.deviceType] = true
          local mpNorm = (mp:sub(-1) == ":") and mp or (mp .. ":")
          ctx.pathPickerBdmMountpoint = mpNorm
          ctx.pathPickerBdmPrefix = _.file_selector.getBdmPathPrefix(load.deviceId)
          ctx.pathBrowsePath = (mp:sub(-1) == ":") and (mp .. "/") or mp
          ctx.pathList = _.listDirectoryElfOnly(ctx.pathBrowsePath)
          ctx.pathPickerSub = "browse"
          ctx.pathPickerSel = 1
          ctx.pathPickerScroll = 0
        end
      end
      if ctx.pathPickerLoading and ctx.pathPickerLoadingFrames >= LOAD_TIMEOUT_FRAMES then
        ctx.pathPickerLoading = nil
        ctx.pathPickerLoadingFrames = nil
        ctx.pathPickerModulesLoaded = nil
        ctx.pathPickerLoadingTimeoutMsg = true
      end
    else
      if ctx.pathPickerLoadingTimeoutMsg then
        local msg = _.path_str.device_timeout
        local tw = _.common.calcTextWidth(_.font, msg, _.FONT_SCALE or 0.9)
        local cx = _.common.centerX(_, tw)
        local cy = math.floor((_.MARGIN_Y + _.HINT_Y) / 2) - math.floor((_.LINE_H or 20) / 2)
        _.drawText(_.font, _.drawMode, cx, cy, _.FONT_SCALE or 0.9, msg, _.DIM)
      end
    end
    if not ctx.pathPickerLoadingTimeoutMsg and not ctx.pathPickerLoading then
      _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1,
        ctx.isAddPath and _.path_str.add_path_choose_device or _.path_str.choose_device, _.WHITE)
      if ctx.pathList and #ctx.pathList > 0 and not ctx.pathPickerLoading then
        _.drawText(_.font, _.drawMode, _.w - 72, _.MARGIN_Y, 0.9, ctx.pathPickerSel .. " / " .. #ctx.pathList, _.DIM)
        local exclusiveSet = {}
        for _, dev in ipairs(ctx.pathList) do
          if dev.exclusive and dev.name then exclusiveSet[dev.name] = true end
        end
        local function pathIsExclusive(p)
          if not p or p == "" then return false end
          return exclusiveSet[p] or exclusiveSet[(p):upper()] == true
        end
        local entryHasOtherPaths = false
        local bootHasOtherPaths = false
        if ctx.pathPickerForEntryIdx and ctx.lines then
          local entryPaths = _.config_parse.getMenuEntryPaths(ctx.lines, ctx.pathPickerForEntryIdx)
          for _, p in ipairs(entryPaths) do
            if not pathIsExclusive(p) then
              entryHasOtherPaths = true; break
            end
          end
        end
        if ctx.pathPickerBootKey and ctx.lines then
          local bootPaths = _.config_parse.getBootPaths(ctx.lines, ctx.pathPickerBootKey) or {}
          for _, p in ipairs(bootPaths) do
            if not pathIsExclusive(p) then
              bootHasOtherPaths = true; break
            end
          end
        end
        local hasOtherPaths = entryHasOtherPaths or bootHasOtherPaths
        local function isGreyed(e)
          if not e then return true end
          return (e.exclusive and hasOtherPaths) or false
        end
        local totalCount = #ctx.pathList + 1  -- index 1 = "Enter path manually"
        if ctx.pathPickerSel < 1 then ctx.pathPickerSel = 1 end
        if ctx.pathPickerSel > totalCount then ctx.pathPickerSel = totalCount end
        if ctx.pathPickerSel >= 2 and isGreyed(ctx.pathList[ctx.pathPickerSel - 1]) then
          for idx = 1, #ctx.pathList do
            if not isGreyed(ctx.pathList[idx]) then
              ctx.pathPickerSel = idx + 1; break
            end
          end
          if ctx.pathPickerSel >= 2 and isGreyed(ctx.pathList[ctx.pathPickerSel - 1]) then
            ctx.pathPickerSel = 1
          end
        end
        if ctx.pathPickerSel > ctx.pathPickerScroll + _.MAX_VISIBLE_LIST then
          ctx.pathPickerScroll = ctx.pathPickerSel - _.MAX_VISIBLE_LIST
        end
        if ctx.pathPickerSel < ctx.pathPickerScroll + 1 then ctx.pathPickerScroll = ctx.pathPickerSel - 1 end
        for i = 1, math.min(_.MAX_VISIBLE_LIST, totalCount - ctx.pathPickerScroll) do
          local listIdx = ctx.pathPickerScroll + i
          local displayName
          local greyed = false
          local e = nil
          if listIdx == 1 then
            displayName = _.path_str.enter_path_manually or "Enter path manually"
          else
            e = ctx.pathList[listIdx - 1]
            displayName = e and (e.desc or e.name or _.common_str.empty) or _.common_str.empty
            greyed = isGreyed(e)
          end
          local y = _.MARGIN_Y + _.scaleY(50) + (i - 1) * _.LINE_H
          local col = greyed and _.DIM or ((listIdx == ctx.pathPickerSel) and _.SELECTED_ENTRY or _.GRAY)
          _.drawListRow(_.MARGIN_X + 20, y, listIdx == ctx.pathPickerSel, displayName, col)
        end
        if (_.padEffective & _.PAD_UP) ~= 0 then
          local idx = ctx.pathPickerSel
          for _ = 1, totalCount do
            idx = idx - 1; if idx < 1 then idx = totalCount end
            if idx == 1 or not isGreyed(ctx.pathList[idx - 1]) then
              ctx.pathPickerSel = idx; break
            end
          end
        end
        if (_.padEffective & _.PAD_DOWN) ~= 0 then
          local idx = ctx.pathPickerSel
          for _ = 1, totalCount do
            idx = idx + 1; if idx > totalCount then idx = 1 end
            if idx == 1 or not isGreyed(ctx.pathList[idx - 1]) then
              ctx.pathPickerSel = idx; break
            end
          end
        end
        if (_.padEffective & _.PAD_CROSS) ~= 0 then
          if ctx.pathPickerSel == 1 then
            ctx.textInputTitleIdMode = nil
            ctx.textInputPrompt = _.path_str.enter_path_prompt or "Enter path"
            ctx.textInputValue = ""
            ctx.textInputMaxLen = 79
            ctx.textInputCallback = function(val)
              applyManualPath(ctx, val)
            end
            ctx.textInputReturnState = "path_picker"
            ctx.textInputGridSel = 1
            ctx.textInputCursor = 1
            ctx.textInputScroll = 1
            ctx.state = "text_input"
          else
          local e = ctx.pathList[ctx.pathPickerSel - 1]
          if isGreyed(e) then
            -- exclusive and other paths exist; ignore
          elseif e.special then
            local pathVal = e.name or ""
            if ctx.pfs0Mounted and System.fileXioUmount then System.fileXioUmount("pfs0:") end
            if ctx.pfs1Mounted and System.fileXioUmount then System.fileXioUmount("pfs1:") end
            ctx.pathList = nil
            ctx.pfs0Mounted = nil
            ctx.pfs1Mounted = nil
            if ctx.pathPickerBootKey and ctx.lines then
              if ctx.pathPickerEditIdx then
                local paths = _.config_parse.getBootPaths(ctx.lines, ctx.pathPickerBootKey) or {}
                paths[ctx.pathPickerEditIdx] = pathVal
                _.config_parse.setBootPaths(ctx.lines, ctx.pathPickerBootKey, paths)
              else
                _.config_parse.append(ctx.lines, ctx.pathPickerBootKey, pathVal)
              end
              if e.noargs then _.config_parse.setBootArgs(ctx.lines, ctx.pathPickerBootKey, {}) end
              ctx.state = ctx.pathPickerReturnState or "editor"
              ctx.pathPickerBootKey = nil
              ctx.pathPickerReturnState = nil
              ctx.pathPickerForEntryIdx = nil
              ctx.pathPickerEditIdx = nil
            elseif ctx.pathPickerForEntryIdx then
              local paths = _.config_parse.getMenuEntryPaths(ctx.lines, ctx.pathPickerForEntryIdx)
              if ctx.pathPickerEditIdx then paths[ctx.pathPickerEditIdx] = pathVal else table.insert(paths, pathVal) end
              _.config_parse.setMenuEntryPaths(ctx.lines, ctx.pathPickerForEntryIdx, paths)
              if e.noargs then _.config_parse.setMenuEntryArgs(ctx.lines, ctx.pathPickerForEntryIdx, {}) end
              ctx.entryIdx = ctx.pathPickerForEntryIdx
              ctx.state = (ctx.pathPickerEditIdx and "entry_paths") or "menu_entry_edit"
              ctx.pathPickerForEntryIdx = nil
              ctx.pathPickerEditIdx = nil
            elseif ctx.isAddPath then
              local key = (ctx.addPathKey == "path1_OSDSYS_ITEM_1") and _.resolveNextOsdItemKey(ctx.lines) or
              ctx.addPathKey
              _.config_parse.append(ctx.lines, key, pathVal)
              ctx.state = "editor"
            else
              _.config_parse.set(ctx.lines, ctx.editKey or "", pathVal)
              ctx.state = "editor"
            end
            ctx.configModified = true
          else
            if e.deviceType == "hdd" and not e.deviceId then
              ctx.pathPickerDeviceSel = ctx.pathPickerSel
              ctx.pathPickerLoadedDeviceTypes = ctx.pathPickerLoadedDeviceTypes or {}
              if ctx.pathPickerLoadedDeviceTypes["hdd"] then
                if System and System.loadModules then System.loadModules("hdd") end
                if _.common.isHddPresent and _.common.isHddPresent() then
                  ctx.pathPickerSub = "partitions"
                  ctx.pathList = _.file_selector.getHddPartitions(0) or {}
                  ctx.pathBrowsePath = "hdd0:"
                  ctx.pathPickerSel = 1
                  ctx.pathPickerScroll = 0
                else
                  ctx.pathPickerLoading = { deviceType = "hdd", staticHdd = true }
                  ctx.pathPickerLoadingFrames = 0
                end
              else
                ctx.pathPickerLoading = { deviceType = "hdd", staticHdd = true }
                ctx.pathPickerLoadingFrames = 0
              end
            elseif e.deviceId and e.deviceType then
              ctx.pathPickerDeviceSel = ctx.pathPickerSel
              ctx.pathPickerLoadedDeviceTypes = ctx.pathPickerLoadedDeviceTypes or {}
              if e.deviceType == "mx4sio" and ctx.pathPickerLoadedDeviceTypes["mmce"] then clearLoadedIfIopReset(ctx) end
              if ctx.pathPickerLoadedDeviceTypes[e.deviceType] then
                if System and System.loadModules then System.loadModules(e.deviceType) end
                local mp = (System and System.getDeviceMountpoint) and System.getDeviceMountpoint(e.deviceId) or nil
                if mp and mp ~= "" then
                  local mpNorm = (mp:sub(-1) == ":") and mp or (mp .. ":")
                  ctx.pathPickerBdmMountpoint = mpNorm
                  ctx.pathPickerBdmPrefix = _.file_selector.getBdmPathPrefix(e.deviceId)
                  ctx.pathBrowsePath = (mp:sub(-1) == ":") and (mp .. "/") or mp
                  ctx.pathList = _.listDirectoryElfOnly(ctx.pathBrowsePath)
                  ctx.pathPickerSub = "browse"
                  ctx.pathPickerSel = 1
                  ctx.pathPickerScroll = 0
                else
                  ctx.pathPickerLoading = { deviceId = e.deviceId, deviceType = e.deviceType }
                  ctx.pathPickerLoadingFrames = 0
                end
              else
                ctx.pathPickerLoading = { deviceId = e.deviceId, deviceType = e.deviceType }
                ctx.pathPickerLoadingFrames = 0
              end
            else
              ctx.pathPickerDeviceSel = ctx.pathPickerSel
              -- Static device (mc, mmce) without deviceId: use name as path. Load MMCE module when selecting mmce.
              ctx.pathPickerLoadedDeviceTypes = ctx.pathPickerLoadedDeviceTypes or {}
              if e.deviceType == "mmce" and ctx.pathPickerLoadedDeviceTypes["mx4sio"] then clearLoadedIfIopReset(ctx) end
              if e.deviceType and System and System.loadModules then System.loadModules(e.deviceType) end
              local browsePath = e.name or ""
              if browsePath and browsePath ~= "" and browsePath:find(":") then
                ctx.pathBrowsePath = (browsePath:sub(-1) == ":") and (browsePath .. "/") or browsePath
                ctx.pathList = _.listDirectoryElfOnly(ctx.pathBrowsePath)
              else
                ctx.pathBrowsePath = nil
                ctx.pathList = {}
              end
              ctx.pathPickerSub = "browse"
              ctx.pathPickerSel = 1
              if e.deviceType then ctx.pathPickerLoadedDeviceTypes[e.deviceType] = true end
            end
          end
        end
        end
      else
        _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y + _.scaleY(60), _.FONT_SCALE, _.path_str.no_devices, _
          .GRAY)
      end
    end
    if ctx.pathPickerLoading then
    elseif ctx.pathPickerLoadingTimeoutMsg then
      _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, _.path_str.circle_back_items, nil, _.DIM,
        _.w - 2 * _.MARGIN_X)
    else
      _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, _.path_str.cross_select_circle_back_items, nil,
        _.DIM, _.w - 2 * _.MARGIN_X)
    end
    if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
      if ctx.pathPickerLoading or ctx.pathPickerLoadingTimeoutMsg then
        ctx.pathPickerLoading = nil
        ctx.pathPickerLoadingFrames = nil
        ctx.pathPickerModulesLoaded = nil
        ctx.pathPickerLoadingTimeoutMsg = nil
        ctx.pathList = _.file_selector.getDevices(ctx.pathPickerContext) or {}
      else
        if ctx.pfs0Mounted and System.fileXioUmount then System.fileXioUmount("pfs0:") end
        if ctx.pfs1Mounted and System.fileXioUmount then System.fileXioUmount("pfs1:") end
        if ctx.pathPickerBootKey then
          ctx.state = ctx.pathPickerReturnState or "editor"
          ctx.pathPickerBootKey = nil; ctx.pathPickerReturnState = nil
        elseif ctx.pathPickerForEntryIdx then
          ctx.entryIdx = ctx.pathPickerForEntryIdx
          ctx.state = (ctx.pathPickerEditIdx and "entry_paths") or "menu_entry_edit"
          ctx.pathPickerForEntryIdx = nil; ctx.pathPickerEditIdx = nil
        else
          ctx.state = "editor"
        end
        ctx.pathList = nil; ctx.pathBrowsePath = nil; ctx.pathPickerBdmPrefix = nil; ctx.pathPickerBdmMountpoint = nil
        ctx.pfs0Mounted = nil; ctx.pfs1Mounted = nil
      end
    end
  elseif ctx.pathPickerSub == "partitions" then
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 1, _.path_str.select_hdd_partition, _.WHITE)
    local parts = ctx.pathList or {}
    if ctx.pathPickerSel < 1 then ctx.pathPickerSel = 1 end
    if ctx.pathPickerSel > #parts then ctx.pathPickerSel = #parts end
    if ctx.pathPickerSel > ctx.pathPickerScroll + _.MAX_VISIBLE_LIST then
      ctx.pathPickerScroll = ctx.pathPickerSel -
          _.MAX_VISIBLE_LIST
    end
    if ctx.pathPickerSel < ctx.pathPickerScroll + 1 then ctx.pathPickerScroll = ctx.pathPickerSel - 1 end
    if #parts > 0 then
      _.drawText(_.font, _.drawMode, _.w - 72, _.MARGIN_Y, 0.9, ctx.pathPickerSel .. " / " .. #parts,
        _.DIM)
    end
    for i = ctx.pathPickerScroll + 1, math.min(ctx.pathPickerScroll + _.MAX_VISIBLE_LIST, #parts) do
      local p = parts[i]
      if not p then break end
      local y = _.MARGIN_Y + _.scaleY(50) + (i - ctx.pathPickerScroll - 1) * _.LINE_H
      local col = (i == ctx.pathPickerSel) and _.SELECTED_ENTRY or _.GRAY
      _.drawListRow(_.MARGIN_X + 20, y, i == ctx.pathPickerSel, p.name or _.common_str.empty, col)
    end
    if #parts == 0 then
      _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y + _.scaleY(60), _.FONT_SCALE, _.path_str.no_partitions, _
        .DIM)
    end
    _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7,
      _.path_str.cross_open_square_patinfo_circle_back_items or _.path_str.cross_open_circle_back_items, nil, _.DIM,
      _.w - 2 * _.MARGIN_X)
    if (_.padEffective & _.PAD_UP) ~= 0 then
      ctx.pathPickerSel = ctx.pathPickerSel - 1; if ctx.pathPickerSel < 1 then ctx.pathPickerSel = #parts end
    end
    if (_.padEffective & _.PAD_DOWN) ~= 0 then
      ctx.pathPickerSel = ctx.pathPickerSel + 1; if ctx.pathPickerSel > #parts then ctx.pathPickerSel = 1 end
    end
    if (_.padEffective & _.PAD_SQUARE) ~= 0 and #parts > 0 then
      local p = parts[ctx.pathPickerSel]
      if not p then p = {} end
      local partFull = p.full or ("hdd0:" .. (p.name or ""))
      local val = partFull .. ":PATINFO"
      if applyBootPathAndReturn(ctx, val) then
      elseif ctx.pathPickerForEntryIdx then
        local paths = _.config_parse.getMenuEntryPaths(ctx.lines, ctx.pathPickerForEntryIdx)
        if ctx.pathPickerEditIdx then paths[ctx.pathPickerEditIdx] = val else table.insert(paths, val) end
        _.config_parse.setMenuEntryPaths(ctx.lines, ctx.pathPickerForEntryIdx, paths)
        ctx.entryIdx = ctx.pathPickerForEntryIdx
        ctx.state = (ctx.pathPickerEditIdx and "entry_paths") or "menu_entry_edit"
        ctx.pathPickerForEntryIdx = nil; ctx.pathPickerEditIdx = nil
      elseif ctx.isAddPath then
        local key = (ctx.addPathKey == "path1_OSDSYS_ITEM_1") and _.resolveNextOsdItemKey(ctx.lines) or ctx.addPathKey
        _.config_parse.append(ctx.lines, key, val)
        ctx.state = "editor"
      else
        _.config_parse.set(ctx.lines, ctx.editKey, val); ctx.state = "editor"
      end
      ctx.configModified = true
      ctx.pathList = nil; ctx.pathBrowsePath = nil; ctx.pathPickerBdmPrefix = nil; ctx.pathPickerBdmMountpoint = nil
      ctx.pathPickerSub = "device"
    end
    if (_.padEffective & _.PAD_CROSS) ~= 0 and #parts > 0 then
      local p = parts[ctx.pathPickerSel]
      if not p then p = {} end
      ctx.pathPickerPartitionSel = ctx.pathPickerSel
      local partName = p.name or ""
      local partFull = p.full or ("hdd0:" .. partName)
      if partName == "__sysconf" then
        if System.fileXioMount then System.fileXioMount("pfs0:", partFull) end
        ctx.pfs0Mounted = partFull
        ctx.pathBrowsePath = "pfs0:/"
        ctx.pathList = _.listDirectoryElfOnly("pfs0:/")
        ctx.pathPickerSub = "browse"
        ctx.pathPickerSel = 1; ctx.pathPickerScroll = 0
      else
        if System.fileXioMount then System.fileXioMount("pfs1:", partFull) end
        ctx.pfs1Mounted = partFull
        ctx.pathBrowsePath = "pfs1:/"
        local ok, list = pcall(_.listDirectoryElfOnly, "pfs1:/")
        ctx.pathList = (ok and list) and list or {}
        ctx.pathPickerSub = "browse"
        ctx.pathPickerSel = 1; ctx.pathPickerScroll = 0
      end
    end
    if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
      ctx.pathPickerSub = "device"
      ctx.pathList = _.file_selector.getDevices(ctx.pathPickerContext) or {}
      ctx.pathBrowsePath = nil
      local n = #(ctx.pathList or {})
      ctx.pathPickerSel = math.max(1, math.min(ctx.pathPickerDeviceSel or 1, n))
      ctx.pathPickerScroll = math.max(0, math.min(ctx.pathPickerScroll or 0, math.max(0, n - _.MAX_VISIBLE_LIST)))
      if ctx.pathPickerSel > ctx.pathPickerScroll + _.MAX_VISIBLE_LIST then
        ctx.pathPickerScroll = ctx.pathPickerSel -
            _.MAX_VISIBLE_LIST
      end
      if ctx.pathPickerSel < ctx.pathPickerScroll + 1 then ctx.pathPickerScroll = ctx.pathPickerSel - 1 end
    end
  else
    local headerPath = ctx.pathBrowsePath or ""
    local partPath = ctx.pfs1Mounted or ctx.pfs0Mounted
    if partPath then
      local display = pfsToPartitionPath(headerPath, partPath)
      if display then headerPath = display end
    end
    _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y, 0.9, headerPath, _.DIM)
    local show = ctx.pathList or {}
    if #show == 0 then
      ctx.pathPickerSel = 0
    else
      ctx.pathPickerSel = math.max(1, math.min(ctx.pathPickerSel, #show))
    end
    if ctx.pathPickerSel > ctx.pathPickerScroll + _.MAX_VISIBLE_LIST then
      ctx.pathPickerScroll = ctx.pathPickerSel -
          _.MAX_VISIBLE_LIST
    end
    if ctx.pathPickerSel > 0 and ctx.pathPickerSel < ctx.pathPickerScroll + 1 then
      ctx.pathPickerScroll = ctx
          .pathPickerSel - 1
    end
    if #show > 0 then
      _.drawText(_.font, _.drawMode, _.w - 72, _.MARGIN_Y, 0.9, ctx.pathPickerSel .. " / " .. #show,
        _.DIM)
    end
    for i = ctx.pathPickerScroll + 1, math.min(ctx.pathPickerScroll + _.MAX_VISIBLE_LIST, #show) do
      local e = show[i]
      if not e then break end
      local y = _.MARGIN_Y + _.scaleY(50) + (i - ctx.pathPickerScroll - 1) * _.LINE_H
      local label = e.name or _.common_str.empty
      if e.directory and label ~= "" then label = label .. "/" end
      local col = (i == ctx.pathPickerSel) and _.SELECTED_ENTRY or _.GRAY
      _.drawListRow(_.MARGIN_X + 20, y, i == ctx.pathPickerSel, label, col)
    end
    if #show == 0 then
      _.drawText(_.font, _.drawMode, _.MARGIN_X, _.MARGIN_Y + _.scaleY(55), _.FONT_SCALE, _.path_str.no_elf_files, _.DIM)
    end
    _.common.drawHintLine(_.font, _.drawMode, _.MARGIN_X, _.HINT_Y, 0.7, _.path_str.cross_select_file_items, nil, _.DIM,
      _.w - 2 * _.MARGIN_X)
    if #show > 0 then
      if (_.padEffective & _.PAD_UP) ~= 0 then
        ctx.pathPickerSel = ctx.pathPickerSel - 1; if ctx.pathPickerSel < 1 then ctx.pathPickerSel = #show end
      end
      if (_.padEffective & _.PAD_DOWN) ~= 0 then
        ctx.pathPickerSel = ctx.pathPickerSel + 1; if ctx.pathPickerSel > #show then ctx.pathPickerSel = 1 end
      end
    end
    if (_.padEffective & _.PAD_CROSS) ~= 0 then
      local e = (ctx.pathPickerSel > 0 and ctx.pathPickerSel <= #show) and show[ctx.pathPickerSel] or nil
      if e then
        if e.directory then
          ctx.pathPickerBrowseSelStack = ctx.pathPickerBrowseSelStack or {}
          table.insert(ctx.pathPickerBrowseSelStack, ctx.pathPickerSel)
          ctx.pathBrowsePath = e.full
          ctx.pathList = _.listDirectoryElfOnly(ctx.pathBrowsePath)
          ctx.pathPickerSel = 1
          ctx.pathPickerScroll = 0
        else
          local rawPath = e.full and e.full:gsub("/$", "") or e.full
          local partPath = ctx.pfs1Mounted or ctx.pfs0Mounted
          local val = (partPath and pfsToPartitionPath(rawPath, partPath)) or rawPath
          if ctx.pathPickerBdmPrefix and ctx.pathPickerBdmMountpoint and rawPath then
            local mp = ctx.pathPickerBdmMountpoint
            if rawPath == mp or rawPath:sub(1, #mp) == mp then
              local rest = rawPath:sub(#mp + 1):gsub("^/", "")
              val = ctx.pathPickerBdmPrefix .. ":" .. (rest ~= "" and "/" .. rest or "")
            end
          end
          if _.file_selector.canWildcard and _.file_selector.canWildcard(val) then
            ctx.pathPickerPendingPath = val
            ctx.pathPickerWildcardConfirm = true
            if ctx.pathPickerBootKey then
              ctx.pathPickerWildcardMode = "boot"
            elseif ctx.pathPickerForEntryIdx then
              ctx.pathPickerWildcardMode = "entry"
            elseif ctx.isAddPath then
              ctx.pathPickerWildcardMode = "add"
            else
              ctx.pathPickerWildcardMode = "single"
            end
          elseif applyBootPathAndReturn(ctx, val) then
          elseif ctx.pathPickerForEntryIdx then
            local paths = _.config_parse.getMenuEntryPaths(ctx.lines, ctx.pathPickerForEntryIdx)
            if ctx.pathPickerEditIdx then paths[ctx.pathPickerEditIdx] = val else table.insert(paths, val) end
            _.config_parse.setMenuEntryPaths(ctx.lines, ctx.pathPickerForEntryIdx, paths)
            ctx.entryIdx = ctx.pathPickerForEntryIdx
            ctx.state = ctx.pathPickerReturnState or (ctx.pathPickerEditIdx and "entry_paths") or "menu_entry_edit"
            ctx.pathPickerForEntryIdx = nil
            ctx.pathPickerEditIdx = nil
            ctx.pathPickerReturnState = nil
          elseif ctx.isAddPath then
            local key = (ctx.addPathKey == "path1_OSDSYS_ITEM_1") and _.resolveNextOsdItemKey(ctx.lines) or
                ctx.addPathKey
            _.config_parse.append(ctx.lines, key, val)
            ctx.state = "editor"
          else
            _.config_parse.set(ctx.lines, ctx.editKey, val)
            ctx.state = "editor"
          end
          ctx.configModified = true
          if not ctx.pathPickerWildcardConfirm then
            if ctx.pfs0Mounted and System.fileXioUmount then System.fileXioUmount("pfs0:") end
            if ctx.pfs1Mounted and System.fileXioUmount then System.fileXioUmount("pfs1:") end
            ctx.pathList = nil
            ctx.pathBrowsePath = nil
            ctx.pathPickerBdmPrefix = nil
            ctx.pathPickerBdmMountpoint = nil
            ctx.pfs0Mounted = nil
            ctx.pfs1Mounted = nil
          end
        end
      end
    end
    if (_.padEffective & _.PAD_CIRCLE) ~= 0 then
      if ctx.pathBrowsePath then
        local norm = ctx.pathBrowsePath:gsub("/$", "")
        -- At partition root (pfs0 = __sysconf, pfs1 = other HDD partition): go back to partition list, not device
        if norm == "pfs1:" or norm == "pfs1" or norm == "pfs0:" or norm == "pfs0" then
          if ctx.pfs0Mounted and System.fileXioUmount then System.fileXioUmount("pfs0:") end
          if ctx.pfs1Mounted and System.fileXioUmount then System.fileXioUmount("pfs1:") end
          ctx.pfs0Mounted = nil; ctx.pfs1Mounted = nil
          ctx.pathPickerSub = "partitions"
          ctx.pathList = _.file_selector.getHddPartitions(0) or {}
          ctx.pathBrowsePath = "hdd0:"
          local n = #(ctx.pathList or {})
          ctx.pathPickerSel = math.max(1, math.min(ctx.pathPickerPartitionSel or 1, n))
          ctx.pathPickerScroll = math.max(0, math.min(ctx.pathPickerScroll or 0, math.max(0, n - _.MAX_VISIBLE_LIST)))
          if ctx.pathPickerSel > ctx.pathPickerScroll + _.MAX_VISIBLE_LIST then
            ctx.pathPickerScroll = ctx.pathPickerSel -
                _.MAX_VISIBLE_LIST
          end
          if ctx.pathPickerSel < ctx.pathPickerScroll + 1 then ctx.pathPickerScroll = ctx.pathPickerSel - 1 end
        else
          local up = ctx.pathBrowsePath:gsub("/$", ""):gsub("/[^/]+$", "")
          if up == ctx.pathBrowsePath:gsub("/$", "") then
            ctx.pathPickerSub = "device"
            ctx.pathPickerBrowseSelStack = nil
            ctx.pathPickerBdmPrefix = nil
            ctx.pathPickerBdmMountpoint = nil
            ctx.pathList = _.file_selector.getDevices(ctx.pathPickerContext) or {}
            ctx.pathBrowsePath = nil
            local n = #(ctx.pathList or {})
            ctx.pathPickerSel = math.max(1, math.min(ctx.pathPickerDeviceSel or 1, n))
            ctx.pathPickerScroll = math.max(0, math.min(ctx.pathPickerScroll or 0, math.max(0, n - _.MAX_VISIBLE_LIST)))
            if ctx.pathPickerSel > ctx.pathPickerScroll + _.MAX_VISIBLE_LIST then
              ctx.pathPickerScroll = ctx.pathPickerSel -
                  _.MAX_VISIBLE_LIST
            end
            if ctx.pathPickerSel < ctx.pathPickerScroll + 1 then ctx.pathPickerScroll = ctx.pathPickerSel - 1 end
          else
            ctx.pathBrowsePath = (up:sub(-1) == ":") and (up .. "/") or up
            ctx.pathList = _.listDirectoryElfOnly(ctx.pathBrowsePath)
            local stack = ctx.pathPickerBrowseSelStack or {}
            ctx.pathPickerSel = math.max(1, math.min(table.remove(stack) or 1, #(ctx.pathList or {})))
            ctx.pathPickerBrowseSelStack = #stack > 0 and stack or nil
            ctx.pathPickerScroll = math.max(0,
              math.min(ctx.pathPickerScroll or 0, math.max(0, #(ctx.pathList or {}) - _.MAX_VISIBLE_LIST)))
            if ctx.pathPickerSel > ctx.pathPickerScroll + _.MAX_VISIBLE_LIST then ctx.pathPickerScroll = ctx.pathPickerSel -
              _.MAX_VISIBLE_LIST end
            if ctx.pathPickerSel < ctx.pathPickerScroll + 1 then ctx.pathPickerScroll = ctx.pathPickerSel - 1 end
          end
        end
      else
        -- No path (e.g. unresolved device or empty): go back to device list, not editor
        ctx.pathPickerSub = "device"
        ctx.pathPickerBrowseSelStack = nil
        ctx.pathPickerBdmPrefix = nil
        ctx.pathPickerBdmMountpoint = nil
        ctx.pathList = _.file_selector.getDevices(ctx.pathPickerContext) or {}
        ctx.pathBrowsePath = nil
        local n = #(ctx.pathList or {})
        ctx.pathPickerSel = math.max(1, math.min(ctx.pathPickerDeviceSel or 1, n))
        ctx.pathPickerScroll = math.max(0, math.min(ctx.pathPickerScroll or 0, math.max(0, n - _.MAX_VISIBLE_LIST)))
        if ctx.pathPickerSel > ctx.pathPickerScroll + _.MAX_VISIBLE_LIST then
          ctx.pathPickerScroll = ctx.pathPickerSel -
              _.MAX_VISIBLE_LIST
        end
        if ctx.pathPickerSel < ctx.pathPickerScroll + 1 then ctx.pathPickerScroll = ctx.pathPickerSel - 1 end
      end
    end
  end
end

return { run = run }
