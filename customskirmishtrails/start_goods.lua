local memory = require("customskirmishtrails.memory")

local common = require("customskirmishtrails.common")

local function getStartGood(good)
  local g = common.resources[good]
  if g == nil then error(string.format("unknown good type: %s", good)) end

  local addr = memory.START_GOODS + (4*g)
  log(2, string.format("getStartGood: %s @ %X", good,addr))
  return core.readInteger(addr)
end

local function setStartGood(good, value)
  local g = common.resources[good]
  if g == nil then error(string.format("unknown good type: %s", good)) end

  local addr = memory.START_GOODS + (4*g)
  log(2, string.format("setStartGood: %s @ %X: %s", good,addr, value))
  core.writeInteger(addr, value)
end

local function hasPrefix(s, prefix)
  return s:sub(1, prefix:len()) == prefix
end

local function setStartGoods(entry)
  for name, offset in pairs(common.resources) do
    local names = {
      "resource_" .. name,
      "resources_" .. name,
    }
    for _, n in ipairs(names) do
      if entry[n] ~= nil then
        setStartGood(name, entry[n])
      end
    end
    
  end
end

-- The map loader writes each player's starting troops as 20 counts (one per unit type) into a
-- row per player; player 1's row is at memory.STARTING_TROOPS. The game spawns them from there
-- over the first ticks. The lord is not part of these counts.
local START_UNIT_TYPES = 20

---player1_skip_start_units = 1: player 1 gets no starting troops (the lord still comes).
---Called after the loader has filled the rows and before the game spawns them.
local function skipStartUnits(entry)
  if entry == nil or tonumber(entry.player1_skip_start_units) ~= 1 then
    return
  end
  for unitType = 0, START_UNIT_TYPES - 1 do
    core.writeInteger(memory.STARTING_TROOPS + unitType * 4, 0)
  end
  log(INFO, "custom-skirmish-trails: player 1 starts without starting troops")
end

return {
  getStartGood = getStartGood,
  setStartGood = setStartGood,
  setStartGoods = setStartGoods,
  skipStartUnits = skipStartUnits,
}