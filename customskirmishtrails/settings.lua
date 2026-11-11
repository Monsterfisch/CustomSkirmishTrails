-- The trail settings file: one JSON file per trail with the settings that belong to the trail
-- as a whole (see resources/trail-settings.schema.json). Everything in it is optional; what is
-- missing, empty or invalid falls back to the game's own value, with a warning in ucp3.log.

local patches = require("customskirmishtrails.patches")

local settings = {}

settings.TRAIL_TYPES = {
  First = "firstEditionTrail",
  Warchest = "warchestTrail",
  Extreme = "extremeTrail",
}

settings.AI_KEYS = {
  "SK_RAT", "SK_SNAKE", "SK_PIG", "SK_WOLF", "SK_SALADIN", "SK_CALIPH", "SK_SULTAN", "SK_RICHARD",
  "SK_FREDERICK", "SK_PHILLIP", "SK_WAZIR", "SK_EMIR", "SK_NIZAR", "SK_SHERIFF", "SK_MARSHAL", "SK_ABBOT",
}

-- the trail screen is 800 x 600
local MAX_X, MAX_Y = 800, 600

local strict = false
local problems = {}

---Strict mode (Developer settings): every problem and every entry that falls back to the game's
---own value is logged. Otherwise only one line per file that has problems.
function settings.setStrict(value)
  strict = value == true
end

---A problem with one entry; the entry falls back to the game's own value.
local function warn(path, message, ...)
  problems[path] = (problems[path] or 0) + 1
  log(strict and WARNING or VERBOSE, string.format("custom-skirmish-trails: %s: " .. message, path, ...))
end

---A problem that makes the whole file unusable: always logged.
local function fail(path, message, ...)
  log(WARNING, string.format("custom-skirmish-trails: %s: " .. message, path, ...))
end

local function info(path, message, ...)
  if strict then
    log(INFO, string.format("custom-skirmish-trails: %s: " .. message, path, ...))
  end
end

local function readText(path)
  local resolved = ucp.internal.resolveAliasedPath(path)
  local handle, err = io.open(resolved, "rb")
  if handle == nil then
    return nil, err
  end
  local contents = handle:read("*all")
  handle:close()
  -- a UTF-8 byte order mark is not JSON
  if contents:sub(1, 3) == "\239\187\191" then
    contents = contents:sub(4)
  end
  return contents
end
settings.readText = readText

---The folder part of `path`, with its trailing slash ("" for a bare file name).
function settings.directoryOf(path)
  return path:match("^(.*[/\\])") or ""
end

---`path` taken relative to `baseDirectory`, unless it already starts at the game folder
---("ucp/...") or at a drive.
function settings.resolveRelative(baseDirectory, path)
  if path:match("^%a:[/\\]") or path:match("^[/\\]") or path:lower():match("^ucp[/\\]") then
    return path
  end
  return baseDirectory .. path
end

local function nonEmptyString(value)
  return type(value) == "string" and value ~= ""
end

local function integer(value)
  if type(value) ~= "number" then
    return nil
  end
  return math.tointeger(value)
end

local function readPositions(path, value, trailName)
  if value == nil then
    return nil
  end
  if type(value) ~= "table" or #value == 0 then
    warn(path, "trail_mission_positions must be a list of { \"x\": .., \"y\": .. }; the game's positions stay")
    return nil
  end
  local capacity = patches.CAPACITY[trailName]
  local positions = {}
  for index, entry in ipairs(value) do
    local x, y
    if type(entry) == "table" then
      x, y = integer(entry.x or entry[1]), integer(entry.y or entry[2])
    end
    if x == nil or y == nil or x < 0 or y < 0 or x > MAX_X or y > MAX_Y then
      warn(path, "trail_mission_positions entry %d is not a position inside 800 x 600; the game's positions stay", index)
      return nil
    end
    table.insert(positions, { x = x, y = y })
  end
  if #positions > capacity then
    warn(path, "this trail can have at most %d missions; only the first %d positions are used", capacity, capacity)
    while #positions > capacity do
      table.remove(positions)
    end
  end
  return positions
end

settings.DATA_MODES = { csv = true, json_folder = true, automatic = true }

---trail_missions: { "base_name": "missions/trail", "data_mode": "csv" }. base_name names both the
---csv file (<base_name>.csv) and the folder of mission files (<base_name>/<name>_mission_NN.json).
local function readMissions(path, directory, value)
  if value == nil then
    return nil
  end
  if type(value) ~= "table" or not nonEmptyString(value.base_name) then
    warn(path, "trail_missions needs a \"base_name\" (the csv file without .csv)")
    return nil
  end
  local mode = value.data_mode
  if mode == nil or mode == "" then
    mode = "csv"
    info(path, "trail_missions.data_mode is not set; \"csv\" is used")
  elseif not settings.DATA_MODES[mode] then
    warn(path, "trail_missions.data_mode must be csv, json_folder or automatic, not '%s'; \"csv\" is used", tostring(mode))
    mode = "csv"
  end
  local base = settings.resolveRelative(directory, (value.base_name:gsub("%.[cC][sS][vV]$", "")))
  base = base:gsub("[/\\]+$", "")
  return {
    csv = base .. ".csv",
    folder = base,
    name = base:match("([^/\\]+)$") or base,
    mode = mode,
  }
end

---trail_text_files: a folder of <language>.json files, or a map of languages to files.
local function readTextFiles(path, directory, value)
  if value == nil then
    return nil
  end
  if type(value) == "string" then
    if value == "" then
      return nil
    end
    local folder = settings.resolveRelative(directory, value)
    if not folder:match("[/\\]$") then
      folder = folder .. "/"
    end
    return { folder = folder }
  end
  if type(value) ~= "table" then
    warn(path, "trail_text_files must be a folder or map languages to language files")
    return nil
  end
  local files, count = {}, 0
  for language, file in pairs(value) do
    if type(language) == "string" and nonEmptyString(file) then
      files[language:lower()] = settings.resolveRelative(directory, file)
      count = count + 1
    elseif file ~= "" then
      warn(path, "trail_text_files entry '%s' is not a file name", tostring(language))
    end
  end
  return count > 0 and { files = files } or nil
end

local function readAiMapping(path, value)
  local mapping = {}
  for _, key in ipairs(settings.AI_KEYS) do
    mapping[key] = key
  end
  if value == nil then
    return mapping, false
  end
  if type(value) ~= "table" then
    warn(path, "ai_character_mapping must be an object")
    return mapping, false
  end
  for key in pairs(value) do
    if mapping[key] == nil then
      warn(path, "ai_character_mapping has an unknown key '%s'", tostring(key))
    end
  end
  local seen = {}
  for _, key in ipairs(settings.AI_KEYS) do
    local alias = value[key]
    if nonEmptyString(alias) then
      -- every alias has to name one AI only, or Import could not turn it back
      if alias ~= key and mapping[alias] ~= nil then
        warn(path, "ai_character_mapping alias '%s' for %s is another AI's key; %s keeps its own name", alias, key, key)
      elseif seen[alias] ~= nil then
        warn(path, "ai_character_mapping gives '%s' to both %s and %s; %s keeps its own name", alias, seen[alias], key, key)
      else
        mapping[key] = alias
        seen[alias] = key
      end
    end
  end
  return mapping, true
end

---Reads the trail settings file at `path`, meant for `trailName`. Returns nil when the file
---cannot be used at all.
function settings.load(path, trailName)
  local contents, err = readText(path)
  if contents == nil then
    fail(path, "cannot read the trail settings file (%s)", tostring(err))
    return nil
  end
  local ok, data = pcall(function() return json:decode(contents) end)
  if not ok or type(data) ~= "table" then
    fail(path, "the trail settings file is not valid JSON: %s", tostring(data))
    return nil
  end

  if data.trail_type ~= nil then
    local declared = settings.TRAIL_TYPES[data.trail_type]
    if declared == nil then
      fail(path, "trail_type must be First, Warchest or Extreme, not '%s'", tostring(data.trail_type))
      return nil
    end
    if declared ~= trailName then
      fail(path, "this file is for the %s trail but is set for another trail; it is not used", data.trail_type)
      return nil
    end
  end

  local directory = settings.directoryOf(path)
  local result = { path = path, trail = trailName }

  for key, field in pairs({ trail_title = "title", trail_summary = "summary" }) do
    local value = data[key]
    if nonEmptyString(value) then
      result[field] = value
    elseif value ~= nil and value ~= "" then
      warn(path, "%s must be a text", key)
    end
  end

  if data.starting_year ~= nil then
    local year = integer(data.starting_year)
    if year == nil or year < 1 or year > 9999 then
      warn(path, "starting_year must be a whole year between 1 and 9999")
    else
      result.startingYear = year
    end
  end

  local visuals = data.trail_visuals
  if visuals ~= nil and type(visuals) ~= "table" then
    warn(path, "trail_visuals must be an object")
    visuals = nil
  end
  result.visuals = {}
  for jsonKey, key in pairs({ trail_button_idle = "buttonIdle", trail_button_highlighted = "buttonHighlighted",
                              trail_background = "background" }) do
    local value = visuals and visuals[jsonKey]
    if nonEmptyString(value) then
      result.visuals[key] = settings.resolveRelative(directory, value)
    end
  end

  result.positions = readPositions(path, data.trail_mission_positions, trailName)
  result.missions = readMissions(path, directory, data.trail_missions)
  result.textFiles = readTextFiles(path, directory, data.trail_text_files)
  result.aiMapping, result.hasAiMapping = readAiMapping(path, data.ai_character_mapping)

  -- what falls back to the game's own values (strict mode only)
  if data.trail_type == nil then
    info(path, "trail_type is not set; the file is used for the trail it is set for in the GUI")
  end
  if result.title == nil then
    info(path, "trail_title is not set; the game's own title is shown (unless a language file has one)")
  end
  if result.summary == nil then
    info(path, "trail_summary is not set; the game's own summary is shown (unless a language file has one)")
  end
  if result.startingYear == nil then
    info(path, "starting_year is not set; the trail starts in the game's own year")
  end
  for _, jsonKey in ipairs({ "trail_button_idle", "trail_button_highlighted", "trail_background" }) do
    local key = ({ trail_button_idle = "buttonIdle", trail_button_highlighted = "buttonHighlighted",
                   trail_background = "background" })[jsonKey]
    if result.visuals[key] == nil then
      info(path, "trail_visuals.%s is not set; the game's own picture is shown", jsonKey)
    end
  end
  if result.positions == nil then
    info(path, "trail_mission_positions is not set; the trail keeps the game's mission count and button positions")
  end
  if result.missions == nil then
    info(path, "trail_missions is not set; the csv file set in the GUI is used")
  end
  if result.textFiles == nil then
    info(path, "trail_text_files is not set; every game language shows the texts of the mission data")
  end
  if not result.hasAiMapping then
    info(path, "ai_character_mapping is not set; Export and Import keep the AI keys (SK_RAT, ...)")
  else
    local value = type(data.ai_character_mapping) == "table" and data.ai_character_mapping or {}
    for _, key in ipairs(settings.AI_KEYS) do
      if not nonEmptyString(value[key]) then
        info(path, "ai_character_mapping.%s is not set; it keeps its own name", key)
      end
    end
  end

  if not strict and (problems[path] or 0) > 0 then
    log(WARNING, string.format("custom-skirmish-trails: %d problems in the trail settings file %s; those entries use "
      .. "the game's own values. Turn on strict mode (Developer settings) to see them.", problems[path], path))
  end
  return result
end

return settings
