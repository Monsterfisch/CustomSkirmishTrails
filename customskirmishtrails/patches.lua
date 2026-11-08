-- Game code changes for the trail settings file and the per-mission player options:
-- how many missions a trail has, where their buttons are, the year a trail starts in,
-- player names and the human player's lord.
--
-- Every function is found by an AOB that is unique in both Stronghold Crusader.exe and
-- Stronghold_Crusader_Extreme.exe; the patch sites sit at the same offsets inside these
-- functions in both. Each site's bytes are checked before anything is written, so a game
-- version or another module that changed them only switches that one feature off.

local patches = {}

-- The game keeps 50 progress slots per trail in memory, but saves only 30 for the Warchest and
-- the Extreme trail. The button position tables hold 50 / 30 / 30 entries (the Extreme one is
-- padded), and the mission name texts of the three trails meet each other at 50 / 30 / 30.
patches.CAPACITY = { firstEditionTrail = 50, warchestTrail = 30, extremeTrail = 30 }
patches.VANILLA_COUNT = { firstEditionTrail = 50, warchestTrail = 30, extremeTrail = 20 }

local TRAIL_INDEX = { firstEditionTrail = 0, warchestTrail = 1, extremeTrail = 2 }

local FUNCTION_AOBS = {
  open = "A1 ? ? ? ? 56 57 33 FF 83 F8 02 89 3D ? ? ? ? 75 07 68 ? ? ? ?",
  click = "8B 44 24 04 3D E8 03 00 00 55 ? ? ? ? ? ? 83 3D ? ? ? ? 00 ? ? ? ? ? ?",
  win = "55 56 57 BF 03 00 00 00 33 ED 39 3D ? ? ? ? BE 9A 02 00 00 74 14 39 2D ? ? ? ?",
  brief = "81 EC 0C 01 00 00 53 33 DB 38 1D ? ? ? ? 0F 84 ? ? ? ? 56 57 53",
  render = "83 EC 08 F6 05 ? ? ? ? ? 53 55 8B 2D ? ? ? ? 56 57 75 0E 83 0D ? ? ? ? ?",
  setup = "8B 44 24 04 8B 0D ? ? ? ? 8D 04 C0 C1 E0 04 83 F9 02 56 8D B0 ? ? ? ?",
  setup2 = "8B 44 24 04 8B 0D ? ? ? ? 8D 04 C0 55 C1 E0 04 83 F9 02 56 8D A8 ? ? ? ?",
  dates = "53 55 56 57 8B 7C 24 14 85 FF 74 05 83 FF 01 75 0A C7 81 8C 1F 00 00 90 33 00 00",
  startbutton = "8B 0D ? ? ? ? 33 D2 33 C0 83 F9 02 89 15 ? ? ? ? 75 09 83 3D ? ? ? ? 14",
  restart = "8B 44 24 04 83 E8 16 53 56 57 74 7E BF 01 00 00 00 2B C7 0F 85 ? ? ? ?",
  ainames = "56 57 BF ? ? ? ? BE ? ? ? ? 8D 64 24 00 83 BE 70 FF FF FF FF ? ? ? ? ? ?",
  syncnames = "83 EC 08 53 55 56 57 89 4C 24 14 BE 01 00 00 00 C7 44 24 10 ? ? ? ? BB ? ? ? ? BD ? ? ? ?",
  -- stops before +0x1A, where aiSwapper detours the AI part of this function
  lordtype = "8B 44 24 04 83 3C 85 ? ? ? ? FF 75 2F 69 C0",
  configdefaults = "C7 05 ? ? ? ? 90 33 00 00 C7 05 ? ? ? ? F8 34 00 00 C7 05 ? ? ? ? 60 36 00 00",
}

-- Every hardcoded mission count in the trail screens. "N-1" sites hold the last mission's
-- index, "N" sites the mission count.
local COUNT_SITES = {
  { fn = "open", offset = 0x41, trail = "firstEditionTrail", value = "N-1", bytes = "B8 31 00 00 00", immOffset = 1, immSize = 4, old = 0x31 },
  { fn = "open", offset = 0x53, trail = "warchestTrail", value = "N-1", bytes = "B8 1D 00 00 00", immOffset = 1, immSize = 4, old = 0x1D },
  { fn = "open", offset = 0x65, trail = "extremeTrail", value = "N-1", bytes = "B8 13 00 00 00", immOffset = 1, immSize = 4, old = 0x13 },
  { fn = "click", offset = 0x2B, trail = "firstEditionTrail", value = "N-1", bytes = "83 F8 31", immOffset = 2, immSize = 1, old = 0x31 },
  { fn = "click", offset = 0x52, trail = "firstEditionTrail", value = "N-1", bytes = "83 3D ? ? ? ? 31", immOffset = 6, immSize = 1, old = 0x31 },
  { fn = "click", offset = 0x220, trail = "firstEditionTrail", value = "N", bytes = "83 FA 32", immOffset = 2, immSize = 1, old = 0x32 },
  { fn = "click", offset = 0xAD, trail = "warchestTrail", value = "N-1", bytes = "83 F8 1D", immOffset = 2, immSize = 1, old = 0x1D },
  { fn = "click", offset = 0xD4, trail = "warchestTrail", value = "N-1", bytes = "83 3D ? ? ? ? 1D", immOffset = 6, immSize = 1, old = 0x1D },
  { fn = "click", offset = 0x271, trail = "warchestTrail", value = "N", bytes = "83 FA 1E", immOffset = 2, immSize = 1, old = 0x1E },
  { fn = "click", offset = 0xFF, trail = "extremeTrail", value = "N-1", bytes = "83 F8 13", immOffset = 2, immSize = 1, old = 0x13 },
  { fn = "click", offset = 0x126, trail = "extremeTrail", value = "N-1", bytes = "83 3D ? ? ? ? 13", immOffset = 6, immSize = 1, old = 0x13 },
  { fn = "click", offset = 0x2C0, trail = "extremeTrail", value = "N", bytes = "83 FA 14", immOffset = 2, immSize = 1, old = 0x14 },
  { fn = "win", offset = 0x356, trail = "firstEditionTrail", value = "N-1", bytes = "83 F9 31", immOffset = 2, immSize = 1, old = 0x31 },
  { fn = "win", offset = 0x36C, trail = "firstEditionTrail", value = "N-1", bytes = "83 F9 31", immOffset = 2, immSize = 1, old = 0x31 },
  { fn = "win", offset = 0x37F, trail = "firstEditionTrail", value = "N-1", bytes = "83 F9 31", immOffset = 2, immSize = 1, old = 0x31 },
  { fn = "win", offset = 0x2F4, trail = "warchestTrail", value = "N-1", bytes = "83 FF 1D", immOffset = 2, immSize = 1, old = 0x1D },
  { fn = "win", offset = 0x30A, trail = "warchestTrail", value = "N-1", bytes = "83 FF 1D", immOffset = 2, immSize = 1, old = 0x1D },
  { fn = "win", offset = 0x31D, trail = "warchestTrail", value = "N-1", bytes = "83 FF 1D", immOffset = 2, immSize = 1, old = 0x1D },
  { fn = "win", offset = 0x283, trail = "extremeTrail", value = "N-1", bytes = "83 FA 13", immOffset = 2, immSize = 1, old = 0x13 },
  { fn = "win", offset = 0x299, trail = "extremeTrail", value = "N-1", bytes = "83 FA 13", immOffset = 2, immSize = 1, old = 0x13 },
  { fn = "win", offset = 0x2AC, trail = "extremeTrail", value = "N-1", bytes = "83 FA 13", immOffset = 2, immSize = 1, old = 0x13 },
  { fn = "brief", offset = 0xE7, trail = "firstEditionTrail", value = "N", bytes = "83 FF 32", immOffset = 2, immSize = 1, old = 0x32 },
  { fn = "brief", offset = 0x93, trail = "warchestTrail", value = "N", bytes = "83 FE 1E", immOffset = 2, immSize = 1, old = 0x1E },
  { fn = "brief", offset = 0x3E, trail = "extremeTrail", value = "N", bytes = "83 FA 14", immOffset = 2, immSize = 1, old = 0x14 },
  { fn = "render", offset = 0x143, trail = "firstEditionTrail", value = "N-1", bytes = "83 FD 31", immOffset = 2, immSize = 1, old = 0x31 },
  { fn = "render", offset = 0x306, trail = "firstEditionTrail", value = "N-1", bytes = "83 FA 31", immOffset = 2, immSize = 1, old = 0x31 },
  { fn = "render", offset = 0x382, trail = "firstEditionTrail", value = "N-1", bytes = "83 FE 31", immOffset = 2, immSize = 1, old = 0x31 },
  { fn = "render", offset = 0x387, trail = "firstEditionTrail", value = "N-1", bytes = "BE 31 00 00 00", immOffset = 1, immSize = 4, old = 0x31 },
  { fn = "render", offset = 0x63C, trail = "firstEditionTrail", value = "N", bytes = "83 3D ? ? ? ? 32", immOffset = 6, immSize = 1, old = 0x32 },
  { fn = "render", offset = 0x667, trail = "warchestTrail", value = "N-1", bytes = "83 FD 1D", immOffset = 2, immSize = 1, old = 0x1D },
  { fn = "render", offset = 0x7AC, trail = "warchestTrail", value = "N-1", bytes = "83 FA 1D", immOffset = 2, immSize = 1, old = 0x1D },
  { fn = "render", offset = 0x828, trail = "warchestTrail", value = "N-1", bytes = "83 FE 1D", immOffset = 2, immSize = 1, old = 0x1D },
  { fn = "render", offset = 0x82D, trail = "warchestTrail", value = "N-1", bytes = "BE 1D 00 00 00", immOffset = 1, immSize = 4, old = 0x1D },
  { fn = "render", offset = 0xAE3, trail = "warchestTrail", value = "N", bytes = "83 3D ? ? ? ? 1E", immOffset = 6, immSize = 1, old = 0x1E },
  { fn = "render", offset = 0xB10, trail = "extremeTrail", value = "N-1", bytes = "83 FD 13", immOffset = 2, immSize = 1, old = 0x13 },
  { fn = "render", offset = 0xC55, trail = "extremeTrail", value = "N-1", bytes = "83 FA 13", immOffset = 2, immSize = 1, old = 0x13 },
  { fn = "render", offset = 0xCD1, trail = "extremeTrail", value = "N-1", bytes = "83 FE 13", immOffset = 2, immSize = 1, old = 0x13 },
  { fn = "render", offset = 0xCD6, trail = "extremeTrail", value = "N-1", bytes = "BE 13 00 00 00", immOffset = 1, immSize = 4, old = 0x13 },
  -- the briefing's Start button: greyed out (draw) and refusing to start (click) when the
  -- selected mission is past the last one
  { fn = "startbutton", offset = 0x15, trail = "extremeTrail", value = "N", bytes = "83 3D ? ? ? ? 14", immOffset = 6, immSize = 1, old = 0x14 },
  { fn = "startbutton", offset = 0x23, trail = "warchestTrail", value = "N", bytes = "83 3D ? ? ? ? 1E", immOffset = 6, immSize = 1, old = 0x1E },
  { fn = "startbutton", offset = 0x30, trail = "firstEditionTrail", value = "N", bytes = "83 3D ? ? ? ? 32", immOffset = 6, immSize = 1, old = 0x32 },
  { fn = "startbutton", offset = 0x99, trail = "extremeTrail", value = "N", bytes = "83 F8 14", immOffset = 2, immSize = 1, old = 0x14 },
  { fn = "startbutton", offset = 0xA8, trail = "warchestTrail", value = "N", bytes = "83 F8 1E", immOffset = 2, immSize = 1, old = 0x1E },
  { fn = "startbutton", offset = 0xB2, trail = "firstEditionTrail", value = "N", bytes = "83 F8 32", immOffset = 2, immSize = 1, old = 0x32 },
  -- restarting a trail mission from the game's menu sets the mission up again the same way
  { fn = "restart", offset = 0x2F3, trail = "extremeTrail", value = "N", bytes = "83 F8 14", immOffset = 2, immSize = 1, old = 0x14 },
  { fn = "restart", offset = 0x31B, trail = "warchestTrail", value = "N", bytes = "83 F8 1E", immOffset = 2, immSize = 1, old = 0x1E },
  { fn = "restart", offset = 0x33F, trail = "firstEditionTrail", value = "N", bytes = "83 F8 32", immOffset = 2, immSize = 1, old = 0x32 },
  -- The vanilla code compares the Extreme trail's furthest mission with 30 here, a leftover
  -- that never matched with 20 missions. With a mission count of our own it gets that count.
  { fn = "render", offset = 0xF8C, trail = "extremeTrail", value = "N", bytes = "83 3D ? ? ? ? 1E", immOffset = 6, immSize = 1, old = 0x1E },
}

-- Where the trail screen reads each trail's button positions (x at +0, y at +4, 8 bytes each):
-- "mov eax, [edx*8 + table]" in its click handler.
local POSITION_SITES = {
  firstEditionTrail = { fn = "click", offset = 0x1F4, bytes = "8B 04 D5 ? ? ? ?" },
  warchestTrail = { fn = "click", offset = 0x245, bytes = "8B 04 D5 ? ? ? ?" },
  extremeTrail = { fn = "click", offset = 0x294, bytes = "8B 04 D5 ? ? ? ?" },
}

-- The first trail's marker drawing moves mission 35's flag 30 pixels left at one screen size
-- ("cmp ebp, 0x22"). With positions of our own that shift is wrong, so it is switched off.
local FIRST_TRAIL_FLAG_SHIFT_SITES = {
  { fn = "render", offset = 0x154, bytes = "83 FD 22" },
  { fn = "render", offset = 0x205, bytes = "83 FD 22" },
}

-- Opening the trail screen clamps the selected Extreme mission into the Warchest's slot
-- ("mov [warchestSelected], eax"), a vanilla slip. With more Extreme missions it matters.
local EXTREME_CLAMP_SITE = { fn = "open", offset = 0x72, bytes = "A3 ? ? ? ?" }
local EXTREME_SELECTED_SITE = { fn = "click", offset = 0x108, bytes = "A3 ? ? ? ?" }

-- The Extreme mission table holds 20 entries of 144 bytes and other data follows it, so for
-- more missions it moves to memory of our own: "lea esi/ebp, [eax + extremeTable]".
local EXTREME_TABLE_SITES = {
  { fn = "setup", offset = 0x1C, bytes = "8D B0 ? ? ? ?" },
  { fn = "setup2", offset = 0x1D, bytes = "8D A8 ? ? ? ?" },
}
local MISSION_SIZE = 144

-- Start dates, in months: the function that recomputes every trail's mission dates sets the
-- first trail to 13200 (1100 AD) and the Warchest and the Extreme trail both to 13560 (1130 AD,
-- through eax); the user config reader has its own defaults for a missing config.
local DATES_FIRST_SITE = { fn = "dates", offset = 0x11, bytes = "C7 81 8C 1F 00 00 90 33 00 00", immOffset = 6 }
local DATES_WARCHEST_SITE = { fn = "dates", offset = 0x1D, bytes = "B8 F8 34 00 00", immOffset = 1 }
local DATES_EXTREME_SITE = { fn = "dates", offset = 0x38, bytes = "89 81 D8 22 00 00" }
local VANILLA_START_MONTHS = { firstEditionTrail = 13200, warchestTrail = 13560, extremeTrail = 13560 }

-- The end of the loop that gives every AI player its name ("cmp esi, end / jl loop").
local AINAMES_EXIT_SITE = { fn = "ainames", offset = 0x30D, bytes = "81 FE ? ? ? ? 0F 8C F7 FC FF FF 5F 5E C3" }
local AINAMES_LOOP_OFFSET = 0x10
-- setup2 builds the players of the mission briefing; this is where it calls the naming loop.
local BRIEFING_NAMES_CALL = { fn = "setup2", offset = 0xF0, bytes = "E8 ? ? ? ?" }

local NAME_STRIDE = 0xFA
local SHORT_NAME_STRIDE = 0x5A

local functions = {}
local state = {
  namesHookInstalled = false,
  originalLord = nil,
}

local function scan(pattern, purpose)
  local ok, address = pcall(core.AOBScan, pattern)
  if not ok or address == nil then
    log(WARNING, string.format("custom-skirmish-trails: could not find %s; that part is disabled", purpose))
    return nil
  end
  return address
end

local function locate(name)
  if functions[name] == nil then
    functions[name] = scan(FUNCTION_AOBS[name], name) or false
  end
  return functions[name] or nil
end

---True when the bytes at `address` match `pattern` ("8B 04 D5 ? ? ? ?").
local function matches(address, pattern)
  local tokens = {}
  for token in pattern:gmatch("%S+") do
    table.insert(tokens, token)
  end
  local bytes = core.readBytes(address, #tokens)
  for index, token in ipairs(tokens) do
    if token ~= "?" and (bytes[index] & 0xFF) ~= tonumber(token, 16) then
      return false
    end
  end
  return true
end

---The address of a patch site, or nil (with a warning) when its bytes are not what we expect.
local function siteAddress(site, purpose)
  local base = locate(site.fn)
  if base == nil then
    return nil
  end
  local address = base + site.offset
  if not matches(address, site.bytes) then
    log(WARNING, string.format("custom-skirmish-trails: unexpected game code for %s at 0x%X; that part is disabled",
      purpose, address))
    return nil
  end
  return address
end

local function writeImmediate(address, size, value)
  if size == 1 then
    core.writeCodeByte(address, value)
  else
    core.writeCodeInteger(address, value)
  end
end

---Sets how many missions `trailName` has. All sites are checked first; one unexpected site
---leaves the trail at its vanilla count.
function patches.setMissionCount(trailName, count)
  local addresses = {}
  for _, site in ipairs(COUNT_SITES) do
    if site.trail == trailName then
      local address = siteAddress(site, trailName .. " mission count")
      if address == nil then
        return false
      end
      table.insert(addresses, { site = site, address = address })
    end
  end
  for _, entry in ipairs(addresses) do
    local value = entry.site.value == "N" and count or (count - 1)
    writeImmediate(entry.address + entry.site.immOffset, entry.site.immSize, value)
  end

  if trailName == "extremeTrail" then
    local clamp = siteAddress(EXTREME_CLAMP_SITE, "the Extreme trail's selected mission")
    local selected = siteAddress(EXTREME_SELECTED_SITE, "the Extreme trail's selected mission")
    if clamp ~= nil and selected ~= nil then
      core.writeCodeInteger(clamp + 1, core.readInteger(selected + 1))
    end
  end
  log(INFO, string.format("custom-skirmish-trails: %s has %d missions", trailName, count))
  return true
end

---The address of the button position table of `trailName` (x, y pairs of 4-byte integers).
function patches.positionTable(trailName)
  local address = siteAddress(POSITION_SITES[trailName], trailName .. " button positions")
  if address == nil then
    return nil
  end
  return core.readInteger(address + 3)
end

---Writes the button positions of `trailName`; `positions` is a list of { x = , y = }.
function patches.setPositions(trailName, positions)
  local positionTable = patches.positionTable(trailName)
  if positionTable == nil then
    return false
  end
  for index, position in ipairs(positions) do
    if index > patches.CAPACITY[trailName] then
      break
    end
    core.writeInteger(positionTable + (index - 1) * 8, position.x)
    core.writeInteger(positionTable + (index - 1) * 8 + 4, position.y)
  end
  if trailName == "firstEditionTrail" then
    for _, site in ipairs(FIRST_TRAIL_FLAG_SHIFT_SITES) do
      local address = siteAddress(site, "the first trail's flag shift")
      if address ~= nil then
        core.writeCodeByte(address + 2, 0x7F) -- mission index 127 never exists
      end
    end
  end
  return true
end

---Moves the Extreme trail's mission table to memory with room for `capacity` missions and
---returns its new address (or the old one when the move is not possible).
function patches.growExtremeTable(currentTable, capacity)
  local addresses = {}
  for _, site in ipairs(EXTREME_TABLE_SITES) do
    local address = siteAddress(site, "the Extreme trail's mission table")
    if address == nil then
      return currentTable
    end
    if core.readInteger(address + 2) ~= currentTable then
      log(WARNING, "custom-skirmish-trails: the Extreme trail's mission table is not where expected; it keeps 20 missions")
      return currentTable
    end
    table.insert(addresses, address)
  end
  local vanilla = patches.VANILLA_COUNT.extremeTrail
  local newTable = core.allocate(capacity * MISSION_SIZE, true)
  for index = 0, capacity - 1 do
    -- missions without a csv line play the last vanilla mission
    local source = math.min(index, vanilla - 1)
    core.copyMemory(newTable + index * MISSION_SIZE, currentTable + source * MISSION_SIZE, MISSION_SIZE)
  end
  for _, address in ipairs(addresses) do
    core.writeCodeInteger(address + 2, newTable)
  end
  return newTable
end

---Sets the year each trail starts in. `years` maps trail names to a year, or nil to keep the
---game's own year.
function patches.setStartYears(years)
  local any = false
  for _, year in pairs(years) do
    if year ~= nil then
      any = true
    end
  end
  if not any then
    return
  end
  local months = {}
  for trailName, vanilla in pairs(VANILLA_START_MONTHS) do
    months[trailName] = years[trailName] ~= nil and years[trailName] * 12 or vanilla
  end

  local first = siteAddress(DATES_FIRST_SITE, "the first trail's start year")
  local warchest = siteAddress(DATES_WARCHEST_SITE, "the Warchest trail's start year")
  local extreme = siteAddress(DATES_EXTREME_SITE, "the Extreme trail's start year")
  if first == nil or warchest == nil or extreme == nil then
    return
  end
  core.writeCodeInteger(first + DATES_FIRST_SITE.immOffset, months.firstEditionTrail)
  core.writeCodeInteger(warchest + DATES_WARCHEST_SITE.immOffset, months.warchestTrail)

  -- The Extreme trail shares eax with the Warchest one; give it a store of its own:
  -- mov dword [ecx + 0x22D8], months ; jmp back
  local cave = core.allocateCode({ 0xC7, 0x81, 0xD8, 0x22, 0x00, 0x00, 0, 0, 0, 0, 0xE9, 0, 0, 0, 0 })
  core.writeCodeInteger(cave + 6, months.extremeTrail)
  core.writeCodeInteger(cave + 11, core.getRelativeAddress(cave + 10, extreme + 6, -5))
  core.writeCodeBytes(extreme, { 0xE9, table.unpack(core.itob(core.getRelativeAddress(extreme, cave, -5))) })
  core.writeCodeByte(extreme + 5, 0x90)

  -- the defaults the game uses when it has no user config yet
  local defaults = locate("configdefaults")
  if defaults ~= nil then
    core.writeCodeInteger(defaults + 6, months.firstEditionTrail)
    core.writeCodeInteger(defaults + 16, months.warchestTrail)
    core.writeCodeInteger(defaults + 26, months.extremeTrail)
  end
  log(INFO, string.format("custom-skirmish-trails: trails start in %d, %d and %d",
    months.firstEditionTrail // 12, months.warchestTrail // 12, months.extremeTrail // 12))
end

-- Player names ---------------------------------------------------------------------------

local function nameArrays()
  if state.names == nil then
    local sync = locate("syncnames")
    if sync == nil then
      return nil
    end
    -- syncAIPlayerNames: "mov ebx, shortNames[1]" and "mov ebp, names[1]"
    state.names = {
      short = core.readInteger(sync + 0x19) - SHORT_NAME_STRIDE,
      long = core.readInteger(sync + 0x1E) - NAME_STRIDE,
    }
  end
  return state.names
end

local function writeName(address, text, size)
  local bytes = text
  if #bytes > size - 1 then
    bytes = bytes:sub(1, size - 1)
  end
  core.writeString(address, bytes)
  core.writeByte(address + #bytes, 0)
end

---Writes the names a mission entry gives its players into the game's two name tables.
function patches.applyPlayerNames(entry)
  if entry == nil then
    return
  end
  local arrays = nameArrays()
  if arrays == nil then
    return
  end
  for player = 1, 8 do
    local name = entry[string.format("player%d_name", player)]
    if type(name) == "string" and name ~= "" then
      local text = modules.textResourceModifier:TransformText(name)
      writeName(arrays.long + player * NAME_STRIDE, text, NAME_STRIDE)
      writeName(arrays.short + player * SHORT_NAME_STRIDE, text, SHORT_NAME_STRIDE)
    end
  end
end

-- Lord type ------------------------------------------------------------------------------

local LORD_TYPES = { arab = 1, europ = 0 }

local function lordAddress()
  if state.lordTypes == nil then
    local getLordType = locate("lordtype")
    if getLordType == nil then
      state.lordTypes = false
    elseif matches(getLordType + 0x3D, "8B 04 85 ? ? ? ?") then
      state.lordTypes = core.readInteger(getLordType + 0x40)
    else
      log(WARNING, "custom-skirmish-trails: unexpected game code for the lord type; player1_lord is disabled")
      state.lordTypes = false
    end
  end
  return state.lordTypes and (state.lordTypes + 4) or nil -- player 1
end

---The lord type a csv value names: 1 Arabian, 0 European, nil when the value is empty or unknown.
function patches.lordType(value)
  if type(value) ~= "string" then
    return nil
  end
  local key = value:lower():gsub("^%s+", ""):gsub("%s+$", "")
  for prefix, lord in pairs(LORD_TYPES) do
    if key:sub(1, #prefix) == prefix then
      return lord
    end
  end
  if key ~= "" then
    log(WARNING, string.format("custom-skirmish-trails: unknown player1_lord '%s', use Arab or Europ", value))
  end
  return nil
end

---Gives the human player the lord a mission entry asks for, and puts the player's own lord
---back for missions (and games) that ask for none.
function patches.applyLord(entry)
  local address = lordAddress()
  if address == nil then
    return
  end
  local lord = entry ~= nil and patches.lordType(entry.player1_lord) or nil
  if lord ~= nil then
    if state.originalLord == nil then
      state.originalLord = core.readInteger(address)
    end
    core.writeInteger(address, lord)
  elseif state.originalLord ~= nil then
    core.writeInteger(address, state.originalLord)
    state.originalLord = nil
  end
end

---Calls `onNamed(isTrailBriefing, callerReturn)` every time the game has named its AI players
---(for a mission briefing and when a map starts).
function patches.hookPlayerNaming(onNamed)
  if state.namesHookInstalled then
    return
  end
  local exit = siteAddress(AINAMES_EXIT_SITE, "player names")
  local briefingCall = siteAddress(BRIEFING_NAMES_CALL, "player names in the briefing")
  if exit == nil or briefingCall == nil then
    return
  end
  local loop = locate("ainames") + AINAMES_LOOP_OFFSET
  local briefingReturn = briefingCall + 5

  -- a stub the Lua detour sits on: 5 nops, ret
  local stub = core.allocateCode({ 0x90, 0x90, 0x90, 0x90, 0x90, 0xC3 })
  core.detourCode(function(registers)
    -- stack: [stub return into the cave], saved edi, saved esi, return to the naming loop's caller
    local callerReturn = core.readInteger(registers.ESP + 12)
    local ok, err = pcall(onNamed, callerReturn == briefingReturn, callerReturn)
    if not ok then
      log(WARNING, "custom-skirmish-trails: player names: " .. tostring(err))
    end
    return registers
  end, stub, 5)

  -- cave: jl loop / call stub / pop edi / pop esi / ret
  local cave = core.allocateCode({ 0x0F, 0x8C, 0, 0, 0, 0, 0xE8, 0, 0, 0, 0, 0x5F, 0x5E, 0xC3 })
  core.writeCodeInteger(cave + 2, core.getRelativeAddress(cave, loop, -6))
  core.writeCodeInteger(cave + 7, core.getRelativeAddress(cave + 6, stub, -5))
  -- the loop's own "jl loop" (6 bytes) becomes "jmp cave / nop"; the cmp before it stays
  local jump = exit + 6
  core.writeCodeBytes(jump, { 0xE9, table.unpack(core.itob(core.getRelativeAddress(jump, cave, -5))) })
  core.writeCodeByte(jump + 5, 0x90)
  state.namesHookInstalled = true
end

patches.TRAIL_INDEX = TRAIL_INDEX

return patches
