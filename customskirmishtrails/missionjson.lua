-- Mission JSON files, format 1: one trail csv line as a structured JSON object, and back.
--
--   {
--     "format": 1,
--     "map_name": "...",
--     "mission_name": "...",
--     "text_description": [ 8 lines ],
--     "advantage": "neutral",          fairness 1-5: human_large, human_small, neutral, ai_small, ai_large
--     "start_mode": "normal",          start_levels 1-3: normal, crusader, deathmatch
--     "players": [                      one entry per player (num_players = its length)
--       { "lord": "Arab", "skip_start_units": 1, "name": "", "start_position": 1, "team": 1,
--         "aiv_type": 0, "gold": 2000 },                                       player 1 (human)
--       { "ai": "SK_RAT", "name": "", "start_position": 2, "team": 2, "aiv_type": 3, "gold": 1000 }
--     ],
--     "producible": { "bows": 1 }, "recruitable": { ... }, "resources": { ... }, "tradeable": { ... },
--     "extra": { "column": "value" }    anything else, so that nothing is lost
--   }
--
-- Cells that are whole numbers become JSON numbers. An empty cell is left out. Values the game
-- ignores (the per-player columns of players past num_players) are left out when they hold the
-- column's usual empty value and kept in "extra" otherwise, so that csv -> JSON -> csv gives the
-- same csv back.

local missionjson = {}

missionjson.FORMAT = 1

local ADVANTAGE = { "human_large", "human_small", "neutral", "ai_small", "ai_large" }
local START_MODE = { "normal", "crusader", "deathmatch" }
local GROUPS = {
  { prefix = "producible_", key = "producible" },
  { prefix = "recruitable_", key = "recruitable" },
  { prefix = "resource_", key = "resources" },
  { prefix = "tradeable_", key = "tradeable" },
}
local TEXT_LINES = 8

-- per-player columns: csv column name, JSON key, the usual value of an unused slot
local function playerColumns(player)
  local columns = {
    { column = "player" .. player .. "_name", key = "name", empty = "" },
    { column = "start_position" .. player, key = "start_position", empty = "0" },
    { column = "team" .. player, key = "team", empty = "0" },
    { column = "aiv_type" .. player, key = "aiv_type", empty = "0" },
    { column = "gold_player_" .. player, key = "gold", empty = "" },
  }
  if player == 1 then
    table.insert(columns, 1, { column = "player1_skip_start_units", key = "skip_start_units", empty = "" })
    table.insert(columns, 1, { column = "player1_lord", key = "lord", empty = "" })
  else
    table.insert(columns, 1, { column = "player" .. player, key = "ai", empty = "0" })
  end
  return columns
end

-- JSON writing, in a fixed order ------------------------------------------------------------

local ESCAPES = { ['"'] = '\\"', ['\\'] = '\\\\', ['\b'] = '\\b', ['\f'] = '\\f', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }

function missionjson.jsonString(value)
  return '"' .. value:gsub('[%c"\\]', function(char)
    return ESCAPES[char] or string.format("\\u%04x", char:byte())
  end) .. '"'
end

local function isPlainInteger(value)
  if not value:match("^%-?%d+$") or #value > 15 then
    return false
  end
  local number = math.tointeger(tonumber(value))
  return number ~= nil and tostring(number) == value
end

local function object()
  return { order = {}, values = {} }
end

local function put(o, key, value)
  table.insert(o.order, key)
  o.values[key] = value
end

-- a csv cell as JSON: { raw = "123" } for a number, the string otherwise
local function cell(value)
  if isPlainInteger(value) then
    return { raw = value }
  end
  return value
end

local function encode(value, indent)
  if type(value) == "string" then
    return missionjson.jsonString(value)
  end
  if value.raw ~= nil then
    return value.raw
  end
  local inner = indent .. "  "
  if value.items ~= nil then
    if #value.items == 0 then
      return "[]"
    end
    local parts = {}
    for _, item in ipairs(value.items) do
      table.insert(parts, inner .. encode(item, inner))
    end
    return "[\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "]"
  end
  if #value.order == 0 then
    return "{}"
  end
  local parts = {}
  for _, key in ipairs(value.order) do
    table.insert(parts, inner .. missionjson.jsonString(key) .. ": " .. encode(value.values[key], inner))
  end
  return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "}"
end

-- csv line -> mission JSON --------------------------------------------------------------------

---The mission JSON text of one csv line. `header` is the csv's column list, `cells` maps column
---names to cell texts, `aiMapping` (optional) maps AI keys to the names to show.
function missionjson.fromRow(header, cells, aiMapping)
  local used = {}
  local function take(column)
    used[column] = true
    return cells[column] or ""
  end

  local mission = object()
  put(mission, "format", { raw = tostring(missionjson.FORMAT) })
  put(mission, "map_name", take("map_name"))
  put(mission, "mission_name", take("mission_name"))
  local lines = { items = {} }
  for line = 1, TEXT_LINES do
    table.insert(lines.items, take(string.format("text_description_line_%02d", line)))
  end
  put(mission, "text_description", lines)

  local fairness = take("fairness")
  put(mission, "advantage", ADVANTAGE[tonumber(fairness) or 0] ~= nil and isPlainInteger(fairness)
    and ADVANTAGE[tonumber(fairness)] or cell(fairness))
  local startLevels = take("start_levels")
  put(mission, "start_mode", START_MODE[tonumber(startLevels) or 0] ~= nil and isPlainInteger(startLevels)
    and START_MODE[tonumber(startLevels)] or cell(startLevels))

  local extra = object()
  local numPlayers = math.tointeger(tonumber(take("num_players"))) or 1
  if numPlayers < 1 then
    numPlayers = 1
  end
  local players = { items = {} }
  for player = 1, 8 do
    local entry = object()
    for _, spec in ipairs(playerColumns(player)) do
      local value = take(spec.column)
      if player <= numPlayers then
        if spec.key == "ai" then
          put(entry, "ai", aiMapping ~= nil and aiMapping[value] or value)
        elseif value ~= "" then
          put(entry, spec.key, cell(value))
        end
      elseif value ~= spec.empty then
        put(extra, spec.column, value)
      end
    end
    -- player 1 has no AI; its column normally holds 0
    if player == 1 then
      local human = take("player1")
      if human ~= "0" then
        put(extra, "player1", human)
      end
    end
    if player <= numPlayers then
      table.insert(players.items, entry)
    end
  end
  put(mission, "players", players)

  for _, group in ipairs(GROUPS) do
    local values = object()
    for _, column in ipairs(header) do
      if not used[column] and column:sub(1, #group.prefix) == group.prefix then
        used[column] = true
        local value = cells[column] or ""
        if value ~= "" then
          put(values, column:sub(#group.prefix + 1), cell(value))
        end
      end
    end
    put(mission, group.key, values)
  end

  for _, column in ipairs(header) do
    if column ~= "" and not used[column] and (cells[column] or "") ~= "" then
      put(extra, column, cells[column])
    end
  end
  if #extra.order > 0 then
    put(mission, "extra", extra)
  end
  return encode(mission, "") .. "\n"
end

-- mission JSON -> csv line --------------------------------------------------------------------

local function cellOf(value, where)
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
    return ""
  end
  error(where .. " must be a text or a number")
end

local function named(value, names, where)
  if type(value) == "string" then
    for number, name in ipairs(names) do
      if value:lower() == name then
        return tostring(number)
      end
    end
  end
  return cellOf(value, where)
end

---The csv cells (column -> text) of a decoded mission JSON file. `reverseMapping` (optional) maps
---the names shown in the JSON back to AI keys. Raises an error for a malformed file.
function missionjson.toRow(data, reverseMapping, file)
  if type(data) ~= "table" then
    error(file .. " is not a JSON object")
  end
  if data.format ~= nil and data.format ~= missionjson.FORMAT then
    error(string.format("%s has format %s; this version reads format %d", file, tostring(data.format), missionjson.FORMAT))
  end
  local cells = {}
  cells.map_name = cellOf(data.map_name, file .. ": map_name")
  cells.mission_name = cellOf(data.mission_name, file .. ": mission_name")
  local lines = type(data.text_description) == "table" and data.text_description or {}
  for line = 1, TEXT_LINES do
    cells[string.format("text_description_line_%02d", line)] = cellOf(lines[line], file .. ": text_description")
  end
  cells.fairness = named(data.advantage, ADVANTAGE, file .. ": advantage")
  cells.start_levels = named(data.start_mode, START_MODE, file .. ": start_mode")

  local players = type(data.players) == "table" and data.players or {}
  if #players > 8 then
    error(file .. ": at most 8 players")
  end
  cells.num_players = tostring(#players)
  cells.player1 = "0"
  for player = 1, 8 do
    local entry = players[player]
    for _, spec in ipairs(playerColumns(player)) do
      if entry == nil then
        cells[spec.column] = spec.empty
      else
        local value = entry[spec.key]
        if spec.key == "ai" then
          value = cellOf(value, string.format("%s: players[%d].ai", file, player))
          cells[spec.column] = (reverseMapping ~= nil and reverseMapping[value]) or (value ~= "" and value or "0")
        else
          cells[spec.column] = cellOf(value, string.format("%s: players[%d].%s", file, player, spec.key))
        end
      end
    end
  end
  if type(players[1]) == "table" and players[1].ai ~= nil then
    error(file .. ": players[1] is the human player and has no \"ai\"")
  end
  for player = 2, #players do
    if type(players[player]) == "table" and players[player].lord ~= nil then
      error(string.format("%s: players[%d] is an AI; only players[1] has a \"lord\"", file, player))
    end
  end

  for _, group in ipairs(GROUPS) do
    local values = data[group.key]
    if type(values) == "table" then
      for key, value in pairs(values) do
        cells[group.prefix .. key] = cellOf(value, string.format("%s: %s.%s", file, group.key, key))
      end
    end
  end
  if type(data.extra) == "table" then
    for column, value in pairs(data.extra) do
      cells[column] = cellOf(value, file .. ": extra." .. column)
    end
  end
  return cells
end

return missionjson
