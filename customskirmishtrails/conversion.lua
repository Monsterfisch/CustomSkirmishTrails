-- Export and Import of a trail csv file: Export writes every mission line into a JSON file of
-- its own, Import puts those files back together into the csv file.
--
--   ucp/plugins/mytrail/first.csv
--   ucp/plugins/mytrail/first/first_mission_01.json, first_mission_02.json, ...
--
-- The csv header gives the JSON keys and the mission line the values. Cells that are whole
-- numbers become JSON numbers, everything else stays a string, so Export followed by Import
-- gives the same csv data back. With an ai_character_mapping in the trail settings file,
-- player1 .. player8 hold the mapped names in the JSON files and the AI keys in the csv.

local winfiles = require("customskirmishtrails.winfiles")
local settingsModule = require("customskirmishtrails.settings")

local conversion = {}

local PLAYER_COLUMNS = {}
for player = 1, 8 do
  PLAYER_COLUMNS["player" .. player] = true
end

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
  -- blank lines carry no mission
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

-- JSON -----------------------------------------------------------------------------------

local ESCAPES = { ['"'] = '\\"', ['\\'] = '\\\\', ['\b'] = '\\b', ['\f'] = '\\f', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }

local function jsonString(value)
  return '"' .. value:gsub('[%c"\\]', function(char)
    return ESCAPES[char] or string.format("\\u%04x", char:byte())
  end) .. '"'
end

---True for cells that read as a whole number and print back the same way.
local function isPlainInteger(value)
  if not value:match("^%-?%d+$") or #value > 15 then
    return false
  end
  local number = math.tointeger(tonumber(value))
  return number ~= nil and tostring(number) == value
end

conversion.jsonString = jsonString

---A JSON object with its keys in the order given.
function conversion.formatJson(keys, values)
  local lines = {}
  for _, key in ipairs(keys) do
    local value = values[key] or ""
    local encoded = isPlainInteger(value) and value or jsonString(value)
    table.insert(lines, string.format("  %s: %s", jsonString(key), encoded))
  end
  return "{\n" .. table.concat(lines, ",\n") .. "\n}\n"
end

---The csv cell for a value read from a mission JSON file.
local function cellOf(value, key, file)
  local kind = type(value)
  if value == nil then
    return ""
  elseif kind == "string" then
    return value
  elseif kind == "number" then
    local whole = math.tointeger(value)
    return whole ~= nil and tostring(whole) or tostring(value)
  elseif kind == "boolean" then
    return value and "1" or "0"
  elseif kind == "table" and next(value) == nil then
    return "" -- null
  end
  error(string.format("%s: '%s' must be a text or a number", file, key))
end

-- Comparing language csv files -------------------------------------------------------------

-- texts that are meant to differ between the languages
conversion.TEXT_COLUMNS = {
  mission_name = true,
  text_description_line_01 = true, text_description_line_02 = true, text_description_line_03 = true,
  text_description_line_04 = true, text_description_line_05 = true, text_description_line_06 = true,
  text_description_line_07 = true, text_description_line_08 = true,
  player1_name = true, player2_name = true, player3_name = true, player4_name = true,
  player5_name = true, player6_name = true, player7_name = true, player8_name = true,
}

local function readRows(path)
  local text, err = settingsModule.readText(path)
  if text == nil then
    return nil, string.format("cannot read %s (%s)", path, tostring(err))
  end
  local rows = conversion.parseCsv(text)
  if #rows < 1 then
    return nil, path .. " is empty"
  end
  local header, missions = rows[1], {}
  for index = 2, #rows do
    local mission = {}
    for column, key in ipairs(header) do
      if key ~= "" then
        mission[key] = rows[index][column] or ""
      end
    end
    table.insert(missions, mission)
  end
  return { header = header, missions = missions }
end

---The differences between the csv files `basePath` and `otherPath`, leaving out the text columns.
function conversion.compareCsv(basePath, otherPath)
  local base, baseError = readRows(basePath)
  if base == nil then
    return { baseError }
  end
  local other, otherError = readRows(otherPath)
  if other == nil then
    return { otherError }
  end
  local differences = {}
  local function add(message, ...)
    table.insert(differences, string.format(message, ...))
  end
  if #base.missions ~= #other.missions then
    add("%d missions in %s, %d in %s", #base.missions, basePath, #other.missions, otherPath)
  end
  local columns, inBase, inOther = {}, {}, {}
  for _, key in ipairs(base.header) do
    if key ~= "" then
      inBase[key] = true
      table.insert(columns, key)
    end
  end
  for _, key in ipairs(other.header) do
    if key ~= "" then
      inOther[key] = true
    end
  end
  for _, key in ipairs(base.header) do
    if key ~= "" and not inOther[key] and not conversion.TEXT_COLUMNS[key] then
      add("column %s is only in %s", key, basePath)
    end
  end
  for _, key in ipairs(other.header) do
    if key ~= "" and not inBase[key] and not conversion.TEXT_COLUMNS[key] then
      add("column %s is only in %s", key, otherPath)
    end
  end
  for index = 1, math.min(#base.missions, #other.missions) do
    local a, b = base.missions[index], other.missions[index]
    for _, key in ipairs(columns) do
      if inOther[key] and not conversion.TEXT_COLUMNS[key] and a[key] ~= b[key] then
        add("mission %d, %s: '%s' in %s, '%s' in %s", index, key, a[key], basePath, b[key], otherPath)
      end
    end
  end
  return differences
end

-- Export and Import ----------------------------------------------------------------------

local function folderOf(csvPath)
  local base = csvPath:gsub("%.[cC][sS][vV]$", "")
  local name = base:match("([^/\\]+)$") or base
  return base, name
end

local function missionFileName(name, number)
  return string.format("%s_mission_%02d.json", name, number)
end

local function reverseMapping(mapping)
  local reverse = {}
  for key, alias in pairs(mapping) do
    reverse[alias] = key
  end
  return reverse
end

---Writes one JSON file per mission line of the csv file `csvPath`.
function conversion.export(csvPath, aiMapping)
  local text, err = settingsModule.readText(csvPath)
  if text == nil then
    return false, string.format("cannot read %s (%s)", csvPath, tostring(err))
  end
  local rows = conversion.parseCsv(text)
  if #rows < 1 then
    return false, csvPath .. " is empty"
  end
  local header = rows[1]
  local folder, name = folderOf(csvPath)
  local ok, folderError = winfiles.createDirectory(folder)
  if not ok then
    return false, folderError
  end
  local written = 0
  for index = 2, #rows do
    local values = {}
    for column, key in ipairs(header) do
      local value = rows[index][column] or ""
      if aiMapping ~= nil and PLAYER_COLUMNS[key] and aiMapping[value] ~= nil then
        value = aiMapping[value]
      end
      values[key] = value
    end
    local file = folder .. "/" .. missionFileName(name, index - 1)
    local done, writeError = winfiles.writeFile(file, conversion.formatJson(header, values))
    if not done then
      return false, writeError
    end
    written = written + 1
  end
  return true, string.format("exported %d missions of %s to %s", written, csvPath, folder)
end

---The column order for a csv file put together from JSON files: the csv's own header when
---there is one, the known columns otherwise; columns only the JSON files have go at the end.
local function columnOrder(existingHeader, missions, knownHeaders)
  local order, seen = {}, {}
  local function add(key)
    if not seen[key] then
      seen[key] = true
      table.insert(order, key)
    end
  end
  local base = existingHeader or knownHeaders
  local present = {}
  for _, mission in ipairs(missions) do
    for key in pairs(mission) do
      present[key] = true
    end
  end
  for _, key in ipairs(base) do
    if existingHeader ~= nil or present[key] then
      add(key)
    end
  end
  local extra = {}
  for key in pairs(present) do
    if not seen[key] then
      table.insert(extra, key)
    end
  end
  table.sort(extra)
  for _, key in ipairs(extra) do
    add(key)
  end
  return order
end

---Puts the mission JSON files next to `csvPath` back together into `csvPath`.
function conversion.import(csvPath, aiMapping, knownHeaders)
  local folder, name = folderOf(csvPath)
  local pattern = "^" .. name:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"):lower() .. "_mission_(%d+)%.json$"
  local files = {}
  for _, file in ipairs(winfiles.listFiles(folder, "*.json")) do
    local number = file:lower():match(pattern)
    if number ~= nil then
      table.insert(files, { number = tonumber(number), name = file })
    end
  end
  if #files == 0 then
    return false, string.format("no %s files in %s; %s stays as it is", missionFileName(name, 1):gsub("01", "NN"), folder, csvPath)
  end
  table.sort(files, function(a, b) return a.number < b.number end)

  local reverse = aiMapping ~= nil and reverseMapping(aiMapping) or nil
  local missions = {}
  for _, file in ipairs(files) do
    local path = folder .. "/" .. file.name
    local text, err = settingsModule.readText(path)
    if text == nil then
      return false, string.format("cannot read %s (%s)", path, tostring(err))
    end
    local ok, data = pcall(function() return json:decode(text) end)
    if not ok or type(data) ~= "table" then
      return false, string.format("%s is not valid JSON: %s", path, tostring(data))
    end
    local mission = {}
    for key, value in pairs(data) do
      local cell = cellOf(value, key, path)
      if reverse ~= nil and PLAYER_COLUMNS[key] and reverse[cell] ~= nil then
        cell = reverse[cell]
      end
      mission[key] = cell
    end
    table.insert(missions, mission)
  end

  local existingText = settingsModule.readText(csvPath)
  local existingHeader, newline = nil, "\r\n"
  if existingText ~= nil then
    local rows
    rows, newline = conversion.parseCsv(existingText)
    existingHeader = rows[1]
    -- keep the previous file in the cache, in case the import was not meant
    winfiles.writeFile(string.format("ucp/.cache/custom-skirmish-trails-backup-%s.csv", name), existingText)
  end

  local header = columnOrder(existingHeader, missions, knownHeaders)
  local rows = { header }
  for _, mission in ipairs(missions) do
    local row = {}
    for column, key in ipairs(header) do
      row[column] = mission[key] or ""
    end
    table.insert(rows, row)
  end
  local done, writeError = winfiles.writeFile(csvPath, conversion.formatCsv(rows, newline))
  if not done then
    return false, writeError
  end
  return true, string.format("imported %d missions from %s into %s", #missions, folder, csvPath)
end

return conversion
