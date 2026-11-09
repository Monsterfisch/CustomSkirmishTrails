---@diagnostic disable-next-line: undefined-global
local ucp = ucp or {internal = {
  resolveAliasedPath = function(...) error("resolveAliasedPath not found, ucp lib not found") end,
}}
local csv = require("customskirmishtrails.vendor.lua-csv")

local strictness = "warning"

local HEADERS = {
  "map_name", 
  "fairness",
	"start_levels",
	"num_players",
	"player1",
	"player2",
	"player3",
	"player4",
	"player5",
	"player6",
	"player7",
	"player8",
	"start_position1",
	"start_position2",
	"start_position3",
	"start_position4",
	"start_position5",
	"start_position6",
	"start_position7",
	"start_position8",
	"team1",
	"team2",
	"team3",
	"team4",
	"team5",
	"team6",
	"team7",
	"team8",
	"aiv_type1",
	"aiv_type2",
	"aiv_type3",
	"aiv_type4",
	"aiv_type5",
	"aiv_type6",
	"aiv_type7",
	"aiv_type8",
	}

local HEADERS_EXTRA = {
  "mission_name",
  "producible_bows",
  "producible_crossbows",
  "producible_maces",
  "producible_pikes",
  "producible_spears",
  "producible_swords",
  "recruitable_archers",
  "recruitable_spearmen",
  "recruitable_macemen",
  "recruitable_crossbowmen",
  "recruitable_pikemen",
  "recruitable_swordsmen",
  "recruitable_knights",
  "recruitable_arabian_bows",
  "recruitable_slaves",
  "recruitable_slingers",
  "recruitable_assassins",
  "recruitable_horse_archers",
  "recruitable_arabian_swordsmen",
  "recruitable_fire_throwers",
  "resource_wood",
  "resource_hops",
  "resource_stone",
  "resource_iron",
  "resource_pitch",
  "resource_wheat",
  "resource_bread",
  "resource_cheese",
  "resource_meat",
  "resource_apple",
  "resource_ale",
  "resource_flour",
  "resource_bow",
  "resource_crossbow",
  "resource_spear",
  "resource_pike",
  "resource_mace",
  "resource_sword",
  "resource_leatherarmor",
  "resource_ironarmor",
  "tradeable_wood",
  "tradeable_hops",
  "tradeable_stone",
  "tradeable_iron",
  "tradeable_pitch",
  "tradeable_wheat",
  "tradeable_bread",
  "tradeable_cheese",
  "tradeable_meat",
  "tradeable_apple",
  "tradeable_ale",
  "tradeable_beer",
  "tradeable_flour",
  "tradeable_bow",
  "tradeable_crossbow",
  "tradeable_spear",
  "tradeable_pike",
  "tradeable_mace",
  "tradeable_sword",
  "tradeable_leatherarmor",
  "tradeable_ironarmor",
  "text_description_line_01",
  "text_description_line_02",
  "text_description_line_03",
  "text_description_line_04",
  "text_description_line_05",
  "text_description_line_06",
  "text_description_line_07",
  "text_description_line_08",
  "gold_player_1",
  "gold_player_2",
  "gold_player_3",
  "gold_player_4",
  "gold_player_5",
  "gold_player_6",
  "gold_player_7",
  "gold_player_8",
  "player1_name",
  "player2_name",
  "player3_name",
  "player4_name",
  "player5_name",
  "player6_name",
  "player7_name",
  "player8_name",
  "player1_lord",
  "player1_skip_start_units",
  "mission_id",
}

---@alias binary 0|1

local HEADERS_TYPES = {
  ["map_name"] = "string", 
  ["fairness"] = "integer",
	["start_levels"] = "integer",
	["num_players"] = "integer",
	["player1"] = "string",
	["player2"] = "string",
	["player3"] = "string",
	["player4"] = "string",
	["player5"] = "string",
	["player6"] = "string",
	["player7"] = "string",
	["player8"] = "string",
	["start_position1"] = "integer",
	["start_position2"] = "integer",
	["start_position3"] = "integer",
	["start_position4"] = "integer",
	["start_position5"] = "integer",
	["start_position6"] = "integer",
	["start_position7"] = "integer",
	["start_position8"] = "integer",
	["team1"] = "integer",
	["team2"] = "integer",
	["team3"] = "integer",
	["team4"] = "integer",
	["team5"] = "integer",
	["team6"] = "integer",
	["team7"] = "integer",
	["team8"] = "integer",
	["aiv_type1"] = "integer",
	["aiv_type2"] = "integer",
	["aiv_type3"] = "integer",
	["aiv_type4"] = "integer",
	["aiv_type5"] = "integer",
	["aiv_type6"] = "integer",
	["aiv_type7"] = "integer",
	["aiv_type8"] = "integer",
  ["mission_name"] = "string",
  ["producible_bows"] = "binary",
  ["producible_crossbows"] = "binary",
  ["producible_maces"] = "binary",
  ["producible_pikes"] = "binary",
  ["producible_spears"] = "binary",
  ["producible_swords"] = "binary",
  ["recruitable_archers"] = "binary",
  ["recruitable_spearmen"] = "binary",
  ["recruitable_macemen"] = "binary",
  ["recruitable_crossbowmen"] = "binary",
  ["recruitable_pikemen"] = "binary",
  ["recruitable_swordsmen"] = "binary",
  ["recruitable_knights"] = "binary",
  ["recruitable_arabian_bows"] = "binary",
  ["recruitable_slaves"] = "binary",
  ["recruitable_slingers"] = "binary",
  ["recruitable_assassins"] = "binary",
  ["recruitable_horse_archers"] = "binary",
  ["recruitable_arabian_swordsmen"] = "binary",
  ["recruitable_fire_throwers"] = "binary",
  ["resource_wood"] = "integer",
  ["resource_hops"] = "integer",
  ["resource_stone"] = "integer",
  ["resource_iron"] = "integer",
  ["resource_pitch"] = "integer",
  ["resource_wheat"] = "integer",
  ["resource_bread"] = "integer",
  ["resource_cheese"] = "integer",
  ["resource_meat"] = "integer",
  ["resource_apple"] = "integer",
  ["resource_ale"] = "integer",
  ["resource_flour"] = "integer",
  ["resource_bow"] = "integer",
  ["resource_crossbow"] = "integer",
  ["resource_spear"] = "integer",
  ["resource_pike"] = "integer",
  ["resource_mace"] = "integer",
  ["resource_sword"] = "integer",
  ["resource_leatherarmor"] = "integer",
  ["resource_ironarmor"] = "integer",
  ["tradeable_wood"] = "binary",
  ["tradeable_hops"] = "binary",
  ["tradeable_stone"] = "binary",
  ["tradeable_iron"] = "binary",
  ["tradeable_pitch"] = "binary",
  ["tradeable_wheat"] = "binary",
  ["tradeable_bread"] = "binary",
  ["tradeable_cheese"] = "binary",
  ["tradeable_meat"] = "binary",
  ["tradeable_apple"] = "binary",
  ["tradeable_ale"] = "binary",
  ["tradeable_beer"] = "binary",
  ["tradeable_flour"] = "binary",
  ["tradeable_bow"] = "binary",
  ["tradeable_crossbow"] = "binary",
  ["tradeable_spear"] = "binary",
  ["tradeable_pike"] = "binary",
  ["tradeable_mace"] = "binary",
  ["tradeable_sword"] = "binary",
  ["tradeable_leatherarmor"] = "binary",
  ["tradeable_ironarmor"] = "binary",
  ["text_description_line_01"] = "string",
  ["text_description_line_02"] = "string",
  ["text_description_line_03"] = "string",
  ["text_description_line_04"] = "string",
  ["text_description_line_05"] = "string",
  ["text_description_line_06"] = "string",
  ["text_description_line_07"] = "string",
  ["text_description_line_08"] = "string",
  ["gold_player_1"] = "integer",
  ["gold_player_2"] = "integer",
  ["gold_player_3"] = "integer",
  ["gold_player_4"] = "integer",
  ["gold_player_5"] = "integer",
  ["gold_player_6"] = "integer",
  ["gold_player_7"] = "integer",
  ["gold_player_8"] = "integer",
  ["player1_name"] = "string",
  ["player2_name"] = "string",
  ["player3_name"] = "string",
  ["player4_name"] = "string",
  ["player5_name"] = "string",
  ["player6_name"] = "string",
  ["player7_name"] = "string",
  ["player8_name"] = "string",
  ["player1_lord"] = "string",
  ["player1_skip_start_units"] = "binary",
  ["mission_id"] = "string",
}

local ALLOW_NIL = {
  ["player1_name"] = true,
  ["player2_name"] = true,
  ["player3_name"] = true,
  ["player4_name"] = true,
  ["player5_name"] = true,
  ["player6_name"] = true,
  ["player7_name"] = true,
  ["player8_name"] = true,
  ["player1_lord"] = true,
  ["player1_skip_start_units"] = true,
  ["mission_id"] = true,
  ["gold_player_1"] = true,
  ["gold_player_2"] = true,
  ["gold_player_3"] = true,
  ["gold_player_4"] = true,
  ["gold_player_5"] = true,
  ["gold_player_6"] = true,
  ["gold_player_7"] = true,
  ["gold_player_8"] = true,

  ["resource_wood"] = true,
  ["resource_hops"] = true,
  ["resource_stone"] = true,
  ["resource_iron"] = true,
  ["resource_pitch"] = true,
  ["resource_wheat"] = true,
  ["resource_bread"] = true,
  ["resource_cheese"] = true,
  ["resource_meat"] = true,
  ["resource_apple"] = true,
  ["resource_ale"] = true,
  ["resource_flour"] = true,
  ["resource_bow"] = true,
  ["resource_crossbow"] = true,
  ["resource_spear"] = true,
  ["resource_pike"] = true,
  ["resource_mace"] = true,
  ["resource_sword"] = true,
  ["resource_leatherarmor"] = true,
  ["resource_ironarmor"] = true,
  ["producible_bows"] = true,
  ["producible_crossbows"] = true,
  ["producible_maces"] = true,
  ["producible_pikes"] = true,
  ["producible_spears"] = true,
  ["producible_swords"] = true,
  ["recruitable_archers"] = true,
  ["recruitable_spearmen"] = true,
  ["recruitable_macemen"] = true,
  ["recruitable_crossbowmen"] = true,
  ["recruitable_pikemen"] = true,
  ["recruitable_swordsmen"] = true,
  ["recruitable_knights"] = true,
  ["recruitable_arabian_bows"] = true,
  ["recruitable_slaves"] = true,
  ["recruitable_slingers"] = true,
  ["recruitable_assassins"] = true,
  ["recruitable_horse_archers"] = true,
  ["recruitable_arabian_swordsmen"] = true,
  ["recruitable_fire_throwers"] = true,
  ["tradeable_wood"] = true,
  ["tradeable_hops"] = true,
  ["tradeable_stone"] = true,
  ["tradeable_iron"] = true,
  ["tradeable_pitch"] = true,
  ["tradeable_wheat"] = true,
  ["tradeable_bread"] = true,
  ["tradeable_cheese"] = true,
  ["tradeable_meat"] = true,
  ["tradeable_apple"] = true,
  ["tradeable_ale"] = true,
  ["tradeable_beer"] = true,
  ["tradeable_flour"] = true,
  ["tradeable_bow"] = true,
  ["tradeable_crossbow"] = true,
  ["tradeable_spear"] = true,
  ["tradeable_pike"] = true,
  ["tradeable_mace"] = true,
  ["tradeable_sword"] = true,
  ["tradeable_leatherarmor"] = true,
  ["tradeable_ironarmor"] = true,
}

local function prefixHeaders(contents)
  return table.concat(HEADERS,",") .. "\r\n" .. contents
end

local function getContents(path)
  local path = ucp.internal.resolveAliasedPath(path)
  local handle, err = io.open(path,'rb')
  if handle == nil then error(debug.traceback(err)) end
  local contents = handle:read("*all")
  log(2, string.format("raw csv contents\n%s", contents))
  -- if contents:sub(1, ("map_name"):len()) ~= "map_name" then
  --   log(2, string.format("getContents: prefixing headers"))
  --    contents = prefixHeaders(contents)
  -- end
  handle:close()  
  return contents
end

local fails = {}

local function fail(name, index, expected, received, value)
  local text = tostring(value or "")
  local msg = string.format("header %s: entry %s, expected a '%s' but received a '%s' (length: %d): %s ", name, index, expected, received, text:len(), text)
  table.insert(fails, msg)
  -- every single problem only in strict mode; otherwise one summary line per file
  log(strictness == "warning" and VERBOSE or WARNING, msg)
end

local function numberify(name, index, expected, received, value)
  local nvalue = tonumber(value)
  if nvalue == nil then
    if ALLOW_NIL[name] then return nvalue end
  end

  if nvalue == nil then
    fail(name, index, expected, received, value)
  elseif expected == "binary" and (nvalue ~= 1 and nvalue ~= 0) then
    fail(name, index, expected, received, value)
  elseif expected == "integer" then
    local ivalue = tonumber(tostring(nvalue), 10)
    if (ivalue == nil and not ALLOW_NIL[name]) or ivalue ~= nvalue then
      fail(name, index, expected, received, value)
    end
    return ivalue
  end

  return nvalue
end

local function validateInput(input, index)
  index = index or "<NA>"

  for name, value in pairs(input) do
    local t = HEADERS_TYPES[name]
    if name == "" then
      -- an unnamed column, from a trailing comma in the header line
      input[name] = nil
    elseif t == nil then 
      fail(name, index, "nil", type(value), value)
    else
      local ty = type(value)
      if ty == "string" then
        -- always fine?
        if t == "binary" then
          input[name] = numberify(name, index,t, ty, value)
        elseif t == "number" or t == "integer" then
          input[name] = numberify(name, index,t, ty, value)
        elseif t ~= "string" then
          fail(name, index, t, ty, value)
        end
      elseif ty == "number" then
        if t == "integer" then
          input[name] = numberify(name, index,t, ty, value)
        elseif t == "binary" then
          input[name] = numberify(name, index,t, ty, value)
        else
          fail(name, index, t, ty, value)
        end
      elseif ty == "boolean" then
        if t ~= "boolean" then fail(name, index, t, ty, value) end
      else
        error(string.format("unsupported type for '%s': %s", name, value))
      end
    end
  end

end

local function pvalidateInput(input, index)
  return pcall(validateInput, input, index)
end

local function readCSV(path, limit)
  log(2, string.format("readCSV: %s", path))
  local contents = getContents(path)
  local c = csv.openstring(contents, {header = true, })

  local entries = {}
  for line in c:lines() do
    limit = limit - 1
    if limit < 1 then
      break
    end
    table.insert(entries, line)
  end

  -- clear fails table
  fails = {}

  for index, entry in ipairs(entries) do
    local valid, err = pvalidateInput(entry, index)
    if not valid then
      local msg = string.format("entry #%i contains invalid information: %s", index, err)
      log(WARNING, msg)
      table.insert(fails, msg)
    end
  end

  if table.length(fails) > 0 then
    local ll = WARNING
    if strictness == "warning" then
      ll = WARNING
    elseif strictness == "error" then
      ll = ERROR
    elseif strictness == "fatal" then
      ll = FATAL
    end
    if strictness == "warning" then
      log(WARNING, string.format("custom-skirmish-trails: %d problems in the trail csv file %s; turn on strict mode (Developer settings) to see them", #fails, path))
    else
      log(ll, string.format("There were %d warnings related to the skirmish trail csv file %s, consult the log for details", #fails, path))
    end

    
  end

  return entries
end

-- local originalContents
-- local handle = io.open("extremeTrail.csv",'rb')
-- originalContents =  prefixHeaders(handle:read("*all"))
-- handle:close()

return {
  setStrictness = function(s) strictness = s end,
  isStrict = function() return strictness ~= "warning" end,
  readCSV = readCSV,
  HEADERS =  HEADERS,
  HEADERS_EXTRA = HEADERS_EXTRA,
  HEADERS_TYPES = HEADERS_TYPES,
}