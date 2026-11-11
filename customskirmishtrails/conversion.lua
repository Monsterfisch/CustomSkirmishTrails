-- Trail csv files and mission JSON files (format 1, see missionjson.lua):
--
--   <base>.csv
--   <base>/<name>_mission_01.json, <name>_mission_02.json, ...
--
-- Export writes one JSON file per csv line, Import puts the JSON files back together into the
-- csv. Export followed by Import gives the same csv back. The trail settings file's
-- ai_character_mapping, when given, turns the AI keys of the csv into the names used in the JSON.

local winfiles = require("customskirmishtrails.winfiles")
local settingsModule = require("customskirmishtrails.settings")
local missionjson = require("customskirmishtrails.missionjson")

local conversion = {}

conversion.jsonString = missionjson.jsonString

-- CSV ------------------------------------------------------------------------------------

---Parses csv text into rows of raw strings. Returns rows and the line ending it used.
function conversion.parseCsv(text)
  if text:sub(1, 3) == "\239\187\191" then
    text = text:sub(4)
  end
  local newline = text:find("\r\n", 1, true) and "\r\n" or "\n"
  local rows, row, field = {}, {}, {}
  local position, length = 1, #text
  local quoted, fieldStarted = false, false

  local function endField()
    table.insert(row, table.concat(field))
    field, fieldStarted = {}, false
  end
  local function endRow()
    endField()
    table.insert(rows, row)
    row = {}
  end

  while position <= length do
    local char = text:sub(position, position)
    if quoted then
      if char == '"' then
        if text:sub(position + 1, position + 1) == '"' then
          table.insert(field, '"')
          position = position + 1
        else
          quoted = false
        end
      else
        table.insert(field, char)
      end
    elseif char == '"' and not fieldStarted then
      quoted, fieldStarted = true, true
    elseif char == "," then
      endField()
    elseif char == "\r" and text:sub(position + 1, position + 1) == "\n" then
      endRow()
      position = position + 1
    elseif char == "\n" then
      endRow()
    else
      table.insert(field, char)
      fieldStarted = true
    end
    position = position + 1
  end
  if fieldStarted or #row > 0 or #field > 0 then
    endRow()
  end
  local result = {}
  for _, r in ipairs(rows) do
    if not (#r == 1 and r[1] == "") then
      table.insert(result, r)
    end
  end
  return result, newline
end

local function csvField(value)
  if value:find('[,"\r\n]') then
    return '"' .. value:gsub('"', '""') .. '"'
  end
  return value
end

function conversion.formatCsv(rows, newline)
  local lines = {}
  for _, row in ipairs(rows) do
    local fields = {}
    for index, value in ipairs(row) do
      fields[index] = csvField(value)
    end
    table.insert(lines, table.concat(fields, ","))
  end
  return table.concat(lines, newline) .. newline
end

---A trail csv file as { text, header, missions = { column -> cell }, newline }, or nil and an error.
function conversion.readTable(path)
  local text, err = settingsModule.readText(path)
  if text == nil then
    return nil, string.format("cannot read %s (%s)", path, tostring(err))
  end
  local rows, newline = conversion.parseCsv(text)
  if #rows < 1 then
    return nil, path .. " is empty"
  end
  local header, missions = rows[1], {}
  for index = 2, #rows do
    local cells = {}
    for column, key in ipairs(header) do
      if key ~= "" then
        cells[key] = rows[index][column] or ""
      end
    end
    table.insert(missions, cells)
  end
  return { text = text, header = header, missions = missions, newline = newline }
end

---The csv columns for missions put together from JSON files: the csv's own header when there is
---one, the known columns otherwise; columns only the JSON files have go at the end.
function conversion.columnOrder(existingHeader, missions, knownHeaders)
  local order, seen = {}, {}
  local function add(key)
    if key ~= "" and not seen[key] then
      seen[key] = true
      table.insert(order, key)
    end
  end
  if existingHeader ~= nil then
    for _, key in ipairs(existingHeader) do
      add(key)
    end
  end
  local present = {}
  for _, mission in ipairs(missions) do
    for key, value in pairs(mission) do
      present[key] = present[key] or value ~= ""
    end
  end
  for _, key in ipairs(knownHeaders or {}) do
    if existingHeader == nil or present[key] then
      add(key)
    end
  end
  local extra = {}
  for key, filled in pairs(present) do
    if filled and not seen[key] then
      table.insert(extra, key)
    end
  end
  table.sort(extra)
  for _, key in ipairs(extra) do
    add(key)
  end
  -- keep the existing header's empty-named columns where they were
  if existingHeader ~= nil then
    local withBlanks = {}
    local index = 1
    for _, key in ipairs(existingHeader) do
      if key == "" then
        table.insert(withBlanks, "")
      else
        table.insert(withBlanks, order[index])
        index = index + 1
      end
    end
    for rest = index, #order do
      table.insert(withBlanks, order[rest])
    end
    return withBlanks
  end
  return order
end

---The csv text for `header` and `missions` (column -> cell).
function conversion.csvText(header, missions, newline)
  local rows = { header }
  for _, mission in ipairs(missions) do
    local row = {}
    for column, key in ipairs(header) do
      row[column] = key ~= "" and (mission[key] or "") or ""
    end
    table.insert(rows, row)
  end
  return conversion.formatCsv(rows, newline or "\r\n")
end

-- mission files ----------------------------------------------------------------------------

---The folder and file name base of a csv file: "a/b/trail.csv" -> "a/b/trail", "trail".
function conversion.folderOf(csvPath)
  local base = csvPath:gsub("%.[cC][sS][vV]$", "")
  local name = base:match("([^/\\]+)$") or base
  return base, name
end

function conversion.missionFileName(name, number)
  return string.format("%s_mission_%02d.json", name, number)
end

---The mission files in `folder`: a list of { number, name } sorted by number.
function conversion.listMissionFiles(folder, name)
  local pattern = "^" .. name:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"):lower() .. "_mission_(%d+)%.json$"
  local files = {}
  for _, file in ipairs(winfiles.listFiles(folder, "*.json")) do
    local number = file:lower():match(pattern)
    if number ~= nil then
      table.insert(files, { number = tonumber(number), name = file })
    end
  end
  table.sort(files, function(a, b) return a.number < b.number end)
  return files
end

function conversion.reverseMapping(mapping)
  if mapping == nil then
    return nil
  end
  local reverse = {}
  for key, alias in pairs(mapping) do
    reverse[alias] = key
  end
  return reverse
end

---Reads and converts one mission file into csv cells. Raises an error for a broken file.
function conversion.readMission(path, reverse)
  local text, err = settingsModule.readText(path)
  if text == nil then
    error(string.format("cannot read %s (%s)", path, tostring(err)))
  end
  local ok, data = pcall(function() return json:decode(text) end)
  if not ok then
    error(string.format("%s is not valid JSON: %s", path, tostring(data)))
  end
  return missionjson.toRow(data, reverse, path)
end

-- Export and Import (the GUI's CSV data panel) ---------------------------------------------

---Writes one JSON file per mission line of the csv file `csvPath`.
function conversion.export(csvPath, aiMapping)
  local csv, err = conversion.readTable(csvPath)
  if csv == nil then
    return false, err
  end
  local folder, name = conversion.folderOf(csvPath)
  local ok, folderError = winfiles.createDirectory(folder)
  if not ok then
    return false, folderError
  end
  for index, cells in ipairs(csv.missions) do
    local file = folder .. "/" .. conversion.missionFileName(name, index)
    local done, writeError = winfiles.writeFile(file, missionjson.fromRow(csv.header, cells, aiMapping))
    if not done then
      return false, writeError
    end
  end
  return true, string.format("exported %d missions of %s to %s", #csv.missions, csvPath, folder)
end

---Puts the mission JSON files next to `csvPath` back together into `csvPath`.
function conversion.import(csvPath, aiMapping, knownHeaders)
  local folder, name = conversion.folderOf(csvPath)
  local files = conversion.listMissionFiles(folder, name)
  if #files == 0 then
    return false, string.format("no %s files in %s; %s stays as it is",
      (conversion.missionFileName(name, 1):gsub("01", "NN")), folder, csvPath)
  end
  local reverse = conversion.reverseMapping(aiMapping)
  local missions = {}
  for _, file in ipairs(files) do
    table.insert(missions, conversion.readMission(folder .. "/" .. file.name, reverse))
  end
  local existing = conversion.readTable(csvPath)
  local header = conversion.columnOrder(existing and existing.header or nil, missions, knownHeaders)
  local text = conversion.csvText(header, missions, existing and existing.newline or "\r\n")
  if existing ~= nil then
    winfiles.writeFile(csvPath .. ".bak", existing.text)
  end
  local done, writeError = winfiles.writeFile(csvPath, text)
  if not done then
    return false, writeError
  end
  return true, string.format("imported %d missions from %s into %s", #missions, folder, csvPath)
end

return conversion
