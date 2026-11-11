-- trail_missions: a trail's missions as a csv file and as a folder of mission JSON files, kept in
-- step at every game start.
--
--   data_mode "csv":         the csv is the truth; the JSON files are written from it.
--   data_mode "json_folder": the JSON files are the truth; the csv is written from them.
--   data_mode "automatic":   per mission, whichever was edited last wins.
--
-- Before JSON files are changed, the folder's mission files are copied into <folder>/.bak (its
-- previous contents are deleted first). Before the csv is changed, it is copied to <csv>.bak.
-- When no file changed since the last start, nothing is read or written: the sizes and times
-- after each sync are kept in ucp/.cache.

local winfiles = require("customskirmishtrails.winfiles")
local settingsModule = require("customskirmishtrails.settings")
local conversion = require("customskirmishtrails.conversion")
local missionjson = require("customskirmishtrails.missionjson")
local texts = require("customskirmishtrails.texts")

local sync = {}

local function statePath(trailName)
  return string.format("ucp/.cache/custom-skirmish-trails-sync-%s.txt", trailName)
end

local function readState(trailName)
  local handle = io.open(statePath(trailName), "rb")
  if handle == nil then
    return nil
  end
  local state = { files = {} }
  for line in handle:read("*all"):gmatch("[^\r\n]+") do
    local key, value = line:match("^([^=]+)=(.*)$")
    if key == "mode" or key == "csv" then
      state[key] = value
    elseif key ~= nil and key:sub(1, 5) == "file:" then
      state.files[key:sub(6)] = value
    end
  end
  handle:close()
  return state
end

local function currentStamps(missions)
  local stamps = { csv = winfiles.fileStamp(missions.csv) or "missing", files = {} }
  for _, file in ipairs(conversion.listMissionFiles(missions.folder, missions.name)) do
    stamps.files[file.name] = winfiles.fileStamp(missions.folder .. "/" .. file.name) or "missing"
  end
  return stamps
end

local function writeState(trailName, mode, stamps)
  local lines = { "mode=" .. mode, "csv=" .. stamps.csv }
  local names = {}
  for name in pairs(stamps.files) do
    table.insert(names, name)
  end
  table.sort(names)
  for _, name in ipairs(names) do
    table.insert(lines, "file:" .. name .. "=" .. stamps.files[name])
  end
  winfiles.writeFile(statePath(trailName), table.concat(lines, "\n") .. "\n")
end

local function unchanged(state, mode, stamps)
  if state == nil or state.mode ~= mode or state.csv ~= stamps.csv then
    return false
  end
  for name, stamp in pairs(stamps.files) do
    if state.files[name] ~= stamp then
      return false
    end
  end
  for name in pairs(state.files) do
    if stamps.files[name] == nil then
      return false
    end
  end
  return true
end

local function rowsEqual(a, b)
  for key, value in pairs(a) do
    if key ~= "" and value ~= (b[key] or "") then
      return false
    end
  end
  for key, value in pairs(b) do
    if key ~= "" and value ~= (a[key] or "") then
      return false
    end
  end
  return true
end

---Runs the sync of one trail. `missions` = { csv, folder, name, mode } from the trail settings
---file. Returns a list of messages (empty when nothing had to be done).
function sync.run(trailName, missions, aiMapping, knownHeaders, textFolder)
  local messages = {}
  local function say(message, ...)
    table.insert(messages, string.format(message, ...))
  end

  local stamps = currentStamps(missions)
  if unchanged(readState(trailName), missions.mode, stamps) then
    return messages
  end

  local csv = conversion.readTable(missions.csv)
  local reverse = conversion.reverseMapping(aiMapping)
  local files = conversion.listMissionFiles(missions.folder, missions.name)
  local byNumber, broken, highest = {}, false, 0
  for _, file in ipairs(files) do
    local path = missions.folder .. "/" .. file.name
    local ok, cells = pcall(conversion.readMission, path, reverse)
    if ok then
      byNumber[file.number] = { cells = cells, path = path, time = winfiles.fileTime(path) or 0, name = file.name }
    else
      broken = true
      byNumber[file.number] = { broken = true, path = path, name = file.name }
      say("%s cannot be read and is left as it is: %s", path, tostring(cells))
    end
    highest = math.max(highest, file.number)
  end

  local mode = missions.mode
  if mode == "automatic" then
    if csv == nil and #files == 0 then
      say("neither %s nor mission files in %s exist", missions.csv, missions.folder)
      return messages
    end
    if csv == nil then
      mode = "json_folder"
    elseif #files == 0 then
      mode = "csv"
    end
  end

  local header = csv ~= nil and csv.header or knownHeaders
  local newRows = nil              -- the csv's missions after the sync (nil: csv unchanged)
  local writes, deletes = {}, {}   -- mission files to write (number -> text) and to delete (names)

  local function exportText(cells)
    return missionjson.fromRow(header, cells, aiMapping)
  end

  if mode == "csv" then
    if csv == nil then
      say("%s does not exist; with data_mode \"csv\" there is nothing to load", missions.csv)
      return messages
    end
    for index, cells in ipairs(csv.missions) do
      local existing = byNumber[index]
      local text = exportText(cells)
      local current = existing ~= nil and settingsModule.readText(existing.path) or nil
      if current ~= text then
        writes[index] = text
      end
    end
    for number, existing in pairs(byNumber) do
      if number > #csv.missions then
        table.insert(deletes, existing.name)
      end
    end
  elseif mode == "json_folder" then
    if #files == 0 then
      say("there are no mission files in %s; with data_mode \"json_folder\" the csv stays as it is", missions.folder)
      return messages
    end
    if broken then
      say("%s is not written while a mission file cannot be read", missions.csv)
      return messages
    end
    newRows = {}
    for number = 1, highest do
      if byNumber[number] ~= nil then
        table.insert(newRows, byNumber[number].cells)
      end
    end
  else
    local csvTime = winfiles.fileTime(missions.csv) or 0
    newRows = {}
    local changedCsv = false
    for number = 1, math.max(#csv.missions, highest) do
      local row = csv.missions[number]
      local file = byNumber[number]
      if file ~= nil and file.broken then
        if row ~= nil then
          table.insert(newRows, row)
        end
      elseif row ~= nil and file == nil then
        table.insert(newRows, row)
        writes[number] = exportText(row)
      elseif row == nil and file ~= nil then
        if file.time > csvTime then
          table.insert(newRows, file.cells)
          changedCsv = true
        else
          table.insert(deletes, file.name)
        end
      elseif row ~= nil and file ~= nil then
        if rowsEqual(row, file.cells) then
          table.insert(newRows, row)
        elseif file.time > csvTime then
          table.insert(newRows, file.cells)
          changedCsv = true
        else
          table.insert(newRows, row)
          writes[number] = exportText(row)
        end
      end
    end
    if not changedCsv then
      newRows = nil
    end
  end

  -- the csv
  if newRows ~= nil then
    local newHeader = conversion.columnOrder(csv ~= nil and csv.header or nil, newRows, knownHeaders)
    local text = conversion.csvText(newHeader, newRows, csv ~= nil and csv.newline or "\r\n")
    if csv == nil or text ~= csv.text then
      if csv ~= nil then
        winfiles.writeFile(missions.csv .. ".bak", csv.text)
      end
      local ok, err = winfiles.writeFile(missions.csv, text)
      if ok then
        say("wrote %s from the mission files%s", missions.csv,
          csv ~= nil and string.format(" (previous version: %s.bak)", missions.csv) or "")
      else
        say("%s", tostring(err))
      end
      header = newHeader
    end
  end

  -- the mission files
  if next(writes) ~= nil or #deletes > 0 then
    local made, folderError = winfiles.createDirectory(missions.folder)
    if not made then
      say("%s", tostring(folderError))
    else
      if #files > 0 then
        local backup = missions.folder .. "/.bak"
        winfiles.createDirectory(backup)
        for _, old in ipairs(conversion.listMissionFiles(backup, missions.name)) do
          winfiles.deleteFile(backup .. "/" .. old.name)
        end
        for _, file in ipairs(files) do
          local text = settingsModule.readText(missions.folder .. "/" .. file.name)
          if text ~= nil then
            winfiles.writeFile(backup .. "/" .. file.name, text)
          end
        end
      end
      local count = 0
      for number, text in pairs(writes) do
        local ok, err = winfiles.writeFile(missions.folder .. "/" .. conversion.missionFileName(missions.name, number), text)
        if ok then
          count = count + 1
        else
          say("%s", tostring(err))
        end
      end
      for _, name in ipairs(deletes) do
        winfiles.deleteFile(missions.folder .. "/" .. name)
      end
      say("wrote %d and removed %d mission files in %s from %s%s", count, #deletes, missions.folder, missions.csv,
        #files > 0 and string.format(" (previous versions: %s/.bak)", missions.folder) or "")
    end
  end

  -- a template for translators, with the default texts
  if textFolder ~= nil and (newRows ~= nil or next(writes) ~= nil or #deletes > 0) then
    local current = conversion.readTable(missions.csv)
    if current ~= nil then
      winfiles.createDirectory(textFolder:gsub("[/\\]$", ""))
      winfiles.writeFile(textFolder .. "_template.json", texts.format(current.missions))
    end
  end

  writeState(trailName, missions.mode, currentStamps(missions))
  return messages
end

return sync
