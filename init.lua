---@diagnostic disable-next-line: undefined-global
local yaml = yaml or {dump = function(...) error("missing function") end}

local memory = require("customskirmishtrails.memory")
local interface = require("customskirmishtrails.interface")
local cst_io = require("customskirmishtrails.io")
local description = require("customskirmishtrails.description")
local tradeability = require("customskirmishtrails.tradeability")
local producibility = require("customskirmishtrails.producibility")
local recruitability = require("customskirmishtrails.recruitability")
local startgold = require("customskirmishtrails.startgold")
local start_goods = require("customskirmishtrails.start_goods")
local patches = require("customskirmishtrails.patches")
local settingsModule = require("customskirmishtrails.settings")
local visuals = require("customskirmishtrails.visuals")
local menutext = require("customskirmishtrails.menutext")
local textsModule = require("customskirmishtrails.texts")
local conversion = require("customskirmishtrails.conversion")
local winfiles = require("customskirmishtrails.winfiles")

local TRAIL_PROGRESS_ADDRESSES = memory.TRAIL_PROGRESS_ADDRESSES
local REGISTRY = memory.REGISTRY
local fetchCurrentTrail = memory.fetchCurrentTrail

-- The three trails: their name in this module, their key in the GUI config and their
-- trail_type in trail settings files.
local TRAILS = {
  { name = "firstEditionTrail", key = "firstedition", type = "First" },
  { name = "warchestTrail", key = "warchest", type = "Warchest" },
  { name = "extremeTrail", key = "extremetrail", type = "Extreme" },
}

local REQUESTS_FILE = "ucp/.cache/custom-skirmish-trails-requests.json"

---The mission entry of the trail mission being prepared or played (or nil), and whether the
---game is in a trail mission.
local function currentEntry()
  local ok, isTrail, _, trailName, mission = pcall(fetchCurrentTrail)
  if not ok or trailName == nil then
    return nil, false
  end
  local missions = REGISTRY[trailName]
  return missions ~= nil and missions[mission] or nil, isTrail
end

local function insertPostSkirmishSetupDetour()
  log(2, "insertPostSkirmishSetupDetour: setting up detour")
  -- local detourLocation, detourSize = core.AOBScan("A1 ? ? ? ? 8D 0C 80 03 C9 89 ? ? ? ? ?"), 5
  local detourLocation, detourSize = core.AOBScan("8B 8C 24 ? ? 00 00 5f 5e 89 ? ? ? ? ? 89 ? ? ? ? ? 89 ? ? ? ? ? 89 ? ? ? ? ? 5B 33 CC"), 7
  core.detourCode(function(registers)
    local isTrail, trail, trailName, mission = fetchCurrentTrail()
    if not isTrail then
      log(2, "not in skirmish trail")
      return registers
    end

    if trailName == nil then error(string.format("invalid trail: %s", trail)) end

    log(2, string.format("trail: %s", trailName))

    local missions = REGISTRY[trailName]
    if missions == nil then
      log(2, string.format("No custom missions registered for trail name: %s", trailName))
      return registers
    end

    log(2, string.format("Committing extra parameters for %s mission: %s", trailName, mission))

    local entry = missions[mission]
    if entry == nil then
      log(-1, string.format("skirmish trail (%s) entry is unexpectedly nil: %s", trailName, mission))
      return registers
    end
    interface.commitEntryExtra(entry)

    return registers

  end, detourLocation, detourSize)

  core.detourCode(function(registers)
    if core.readInteger(memory.IS_SKIRMISH_TRAIL) ~= 1 then return registers end

    local isTrail, trail, trailName, mission = memory.fetchCurrentTrail()
    if not isTrail then return registers end
    local missions = REGISTRY[trailName]
    if missions == nil then
      log(2, string.format("No custom missions registered for trail name: %s", trailName))
      return registers
    end

    log(2, string.format("Committing start goods parameters for %s mission: %s", trailName, mission))

    local entry = missions[mission]
    if entry == nil then
      log(-1, string.format("skirmish trail (%s) entry is unexpectedly nil: %s", trailName, mission))
      return registers
    end
    -- the human player's starting troops are computed right after this from the lord type
    patches.applyLord(entry)
    interface.setStartGoods(entry)
  end, core.AOBScan("A3 ? ? ? ? A3 ? ? ? ? A3 ? ? ? ? A3 ? ? ? ? A3 ? ? ? ? A3 ? ? ? ? A3 ? ? ? ? A3 ? ? ? ? A3 ? ? ? ? A3 ? ? ? ? A3 ? ? ? ? A3 ? ? ? ? A3 ? ? ? ? A3 ? ? ? ? 89 44 24 10 "), 5)
end

local function applyTrail(trailName, path, missions, limit, languageTexts)
  local result, err = cst_io.readCSV(path, limit + 1) -- one for the header
  if result == nil then error(err) end
  -- the game language's texts over the default texts of the csv
  textsModule.apply(languageTexts, result)

  local f = io.open(string.format("ucp/.cache/custom-skirmish-trails-config-%s.yml", trailName), 'w')
  if f ~= nil then
    f:write(yaml.dump(result))
    f:close()
  end

  REGISTRY[trailName] = result

  for index, entry in pairs(REGISTRY[trailName]) do
    interface.commitEntry(missions, index, entry, trailName)
  end
end

local function detourSwitchToMenu()
  core.detourCode(function(registers)
    log(2, string.format("detour: SetupSkirmishMode: %s", ""))

    -- we aren't in a trail setting yet (we are preparting for it), so we ignore the isTrail part of the return values
    local _, trail, trailName, mission = fetchCurrentTrail()
    if trail ~= nil then
      local missions = REGISTRY[trailName]
      if missions == nil then
        log(VERBOSE, string.format("No custom missions registered for trail name: %s", trailName))
        patches.applyLord(nil)
        return registers
      end

      local entry = missions[mission]
      if entry == nil then
        log(-1, string.format("skirmish trail (%s) entry is unexpectedly nil: %s", trailName, mission))
        patches.applyLord(nil)
        return registers
      end

      interface.commitTextDescription(entry)
      interface.commitStartGoldDisplay(entry)
      patches.applyLord(entry)

    else
      log(2, "detourSwitchMenu: no text description to set")
    end
  end, core.AOBScan("C7 ? ? ? ? ? ? ? ? ? ? E8 ? ? ? ? 5D C3"), 11)
end

---Player names and the human player's lord: every time the game names its players (for a
---trail mission's briefing and when a map starts), a trail mission puts its own in.
local function hookPlayerNaming()
  patches.hookPlayerNaming(function(isTrailBriefing)
    local entry, isTrail = currentEntry()
    if isTrailBriefing or isTrail then
      patches.applyPlayerNames(entry)
      patches.applyLord(entry)
    else
      patches.applyLord(nil)
    end
  end)
end

-- Settings -------------------------------------------------------------------------------

local function nonEmpty(value)
  return type(value) == "string" and value ~= ""
end

local function trailConfig(config, trail)
  return type(config[trail.key]) == "table" and config[trail.key] or {}
end

---The default csv file and the language csv files set in the GUI for a trail.
local function guiCsv(config, trail)
  local csv = trailConfig(config, trail).csv
  if type(csv) ~= "table" then
    return nil, {}
  end
  local languages = {}
  if type(csv.languages) == "table" then
    for language, path in pairs(csv.languages) do
      if nonEmpty(path) then
        languages[tostring(language):lower()] = path
      end
    end
  end
  return nonEmpty(csv.path) and csv.path or nil, languages
end

local function loadTrailSettings(config, trail)
  local settingsConfig = trailConfig(config, trail).settings
  local path = type(settingsConfig) == "table" and settingsConfig.path or nil
  if not nonEmpty(path) then
    return nil
  end
  local ok, result = pcall(settingsModule.load, path, trail.name)
  if not ok then
    log(WARNING, string.format("custom-skirmish-trails: %s: %s", path, tostring(result)))
    return nil
  end
  if result ~= nil then
    log(INFO, string.format("custom-skirmish-trails: %s trail settings from %s", trail.type, path))
  end
  return result
end

-- Export / Import requests from the GUI ------------------------------------------------------

local function readRequests()
  local handle = io.open(REQUESTS_FILE, "rb")
  if handle == nil then
    return {}
  end
  local text = handle:read("*all")
  handle:close()
  local ok, data = pcall(function() return json:decode(text) end)
  return (ok and type(data) == "table") and data or {}
end

---The status file as JSON. Written by hand: UCP's json:encode_pretty crashed the game here.
local function formatRequests(requests)
  local q = conversion.jsonString
  local keys = {}
  for key in pairs(requests) do
    table.insert(keys, key)
  end
  table.sort(keys)
  local trails = {}
  for _, key in ipairs(keys) do
    local entry = requests[key]
    if type(entry) == "table" then
      local results = {}
      for _, line in ipairs(type(entry.results) == "table" and entry.results or {}) do
        table.insert(results, "      " .. q(tostring(line)))
      end
      table.insert(trails, table.concat({
        "  " .. q(key) .. ": {",
        '    "action": ' .. q(tostring(entry.action or "")) .. ",",
        '    "request": ' .. q(tostring(entry.request or "")) .. ",",
        '    "time": ' .. q(tostring(entry.time or "")) .. ",",
        '    "results": [',
        table.concat(results, ",\n"),
        "    ]",
        "  }",
      }, "\n"))
    end
  end
  return "{\n" .. table.concat(trails, ",\n") .. "\n}\n"
end

local function writeRequests(requests)
  -- through Windows: UCP's io.open left this file empty in the game
  local ok, err = winfiles.writeFile(REQUESTS_FILE, formatRequests(requests))
  if not ok then
    log(WARNING, "custom-skirmish-trails: cannot write " .. REQUESTS_FILE .. ": " .. tostring(err))
  end
end

local function knownHeaders()
  local headers = {}
  for _, header in ipairs(cst_io.HEADERS) do table.insert(headers, header) end
  for _, header in ipairs(cst_io.HEADERS_EXTRA) do table.insert(headers, header) end
  return headers
end

---Runs an Export or Import CSV Data request the GUI saved, once per request.
local function runConversions(config, trailSettings)
  local requests = nil
  for _, trail in ipairs(TRAILS) do
    local request = trailConfig(config, trail).conversion
    if type(request) == "table" and (request.action == "export" or request.action == "import"
      or request.action == "texts") and nonEmpty(request.request) then
      requests = requests or readRequests()
      local previous = requests[trail.key]
      if type(previous) ~= "table" or previous.request ~= request.request then
        local settings = trailSettings[trail.name]
        local mapping = (settings ~= nil and settings.hasAiMapping) and settings.aiMapping or nil
        local default, languages = guiCsv(config, trail)
        local files = settingsModule.allCsvFiles(settings, languages, default)
        local results = {}
        if #files == 0 then
          table.insert(results, "no csv file is set for this trail")
        end
        if request.action == "texts" then
          -- language csv files -> language text files next to the default csv
          local base = (settings ~= nil and settings.csvFiles ~= nil and settings.csvFiles.default) or default
          local languageCsvs = {}
          if settings ~= nil and settings.csvFiles ~= nil then
            for language, file in pairs(settings.csvFiles) do
              if language ~= "default" then languageCsvs[language] = file end
            end
          else
            for language, file in pairs(languages) do languageCsvs[language] = file end
          end
          if not nonEmpty(base) then
            table.insert(results, "there is no default csv file for this trail")
          else
            local okTexts, lines = pcall(textsModule.makeFromCsvs, base, languageCsvs)
            for _, line in ipairs(okTexts and lines or { tostring(lines) }) do
              log(INFO, "custom-skirmish-trails: " .. tostring(line))
              table.insert(results, tostring(line))
            end
          end
          files = {}
        end
        for _, file in ipairs(files) do
          local ok, done, message
          if request.action == "export" then
            ok, done, message = pcall(conversion.export, file, mapping)
          else
            ok, done, message = pcall(conversion.import, file, mapping, knownHeaders())
          end
          if not ok then
            message = string.format("%s: %s", file, tostring(done))
          end
          log((ok and done) and INFO or WARNING, "custom-skirmish-trails: " .. tostring(message))
          table.insert(results, tostring(message))
        end
        requests[trail.key] = {
          action = request.action,
          request = request.request,
          time = os.date("%Y-%m-%d %H:%M:%S"),
          results = results,
        }
      end
    end
  end
  if requests ~= nil then
    writeRequests(requests)
  end
end

return {
  enable = function(self, config)
    config = config or {}
    local strict = type(config.csv) == "table" and config.csv.strict_format == true
    if strict then
      cst_io.setStrictness("error")
    else
      cst_io.setStrictness("warning")
    end
    settingsModule.setStrict(strict)
    textsModule.setStrict(strict)

    local _, skirmishTrailMissions, extremeTrailMissions, warchestTrailMissions = utils.AOBExtract("8D ? I(? ? ? ?) 75 08 8D ? I(? ? ? ?) EB 0B 83 F9 01 75 06 8D ? I(? ? ? ?) 53")
    local missionTables = {
      firstEditionTrail = skirmishTrailMissions,
      warchestTrail = warchestTrailMissions,
      extremeTrail = extremeTrailMissions,
    }

    -- trail settings files: mission count and positions, start years, texts, visuals
    local trailSettings = {}
    local missionCounts = {}
    local startYears = {}
    for _, trail in ipairs(TRAILS) do
      local settings = loadTrailSettings(config, trail)
      trailSettings[trail.name] = settings
      missionCounts[trail.name] = patches.VANILLA_COUNT[trail.name]

      if settings ~= nil then
        if settings.positions ~= nil then
          local count = #settings.positions
          if trail.name == "extremeTrail" and count > patches.VANILLA_COUNT.extremeTrail then
            local grown = patches.growExtremeTable(missionTables.extremeTrail, patches.CAPACITY.extremeTrail)
            if grown == missionTables.extremeTrail then
              count = patches.VANILLA_COUNT.extremeTrail -- the table could not move
            end
            missionTables.extremeTrail = grown
          end
          if count == patches.VANILLA_COUNT[trail.name] or patches.setMissionCount(trail.name, count) then
            missionCounts[trail.name] = count
          end
          -- Extreme missions past the game's 20 have no name in the game's texts; a csv
          -- line's mission_name replaces this one
          for index = patches.VANILLA_COUNT[trail.name] + 1, missionCounts[trail.name] do
            modules.textResourceModifier:SetText(0xF5, 0x51 + (index - 1), string.format("Mission %d", index))
          end
          local positions = {}
          for index = 1, math.min(missionCounts[trail.name], #settings.positions) do
            positions[index] = settings.positions[index]
          end
          patches.setPositions(trail.name, positions)
        end
        startYears[trail.name] = settings.startingYear
        visuals.applyVisuals(trail.name, settings.visuals)
        if settings.hasAiMapping then
          interface.setAiAliases(trail.name, settings.aiMapping)
        end
      end
    end
    patches.setStartYears(startYears)

    -- strict mode: how the language csv files of a trail differ from its default one
    if strict then
      for _, trail in ipairs(TRAILS) do
        local settings = trailSettings[trail.name]
        local default, languages = guiCsv(config, trail)
        local base = (settings ~= nil and settings.csvFiles ~= nil and settings.csvFiles.default) or default
        if nonEmpty(base) then
          for _, other in ipairs(settingsModule.allCsvFiles(settings, languages, default)) do
            if other ~= base then
              local okCompare, differences = pcall(conversion.compareCsv, base, other)
              if not okCompare then
                differences = { tostring(differences) }
              end
              if #differences == 0 then
                log(INFO, string.format("custom-skirmish-trails: %s and %s differ only in their texts", base, other))
              end
              for _, difference in ipairs(differences) do
                log(INFO, "custom-skirmish-trails: " .. difference)
              end
            end
          end
        end
      end
    end

    -- Export / Import CSV Data requested in the GUI
    local ok, err = pcall(runConversions, config, trailSettings)
    if not ok then
      log(WARNING, "custom-skirmish-trails: Export / Import CSV Data: " .. tostring(err))
    end

    hooks.registerHookCallback("afterInit", function()
      local language = ""
      local texts = modules.textResourceModifier
      if texts ~= nil and texts.GetLanguage ~= nil then
        local gotLanguage, value = pcall(function() return texts:GetLanguage() end)
        if gotLanguage and type(value) == "string" then
          language = value:lower()
        end
      end

      for _, trail in ipairs(TRAILS) do
        local trailSettingsForTexts = trailSettings[trail.name]
        -- the game language's text file, if the trail settings file names one
        local languageTexts = nil
        if trailSettingsForTexts ~= nil then
          local textFile = textsModule.fileFor(trailSettingsForTexts.textFiles, language)
          if textFile ~= nil then
            languageTexts = textsModule.load(textFile)
            if languageTexts ~= nil then
              log(INFO, string.format("custom-skirmish-trails: %s trail texts (%s): %s", trail.type, language, textFile))
            end
          elseif trailSettingsForTexts.textFiles ~= nil then
            log(INFO, string.format("custom-skirmish-trails: no %s text file for the %s trail; the default texts are shown",
              language, trail.type))
          end
          local okTexts, textError = pcall(menutext.apply, trail.name,
            (languageTexts and languageTexts.title) or settingsModule.localized(trailSettingsForTexts.title, language),
            (languageTexts and languageTexts.summary) or settingsModule.localized(trailSettingsForTexts.summary, language))
          if not okTexts then
            log(WARNING, "custom-skirmish-trails: trail title and summary: " .. tostring(textError))
          end
        end
        local default, languages = guiCsv(config, trail)
        local path = settingsModule.chooseCsv(trailSettings[trail.name], languages, default, language)
        if nonEmpty(path) then
          log(INFO, string.format("custom-skirmish-trails: %s trail (%s): %s", trail.type, language, path))
          local okTrail, trailError = pcall(applyTrail, trail.name, path, missionTables[trail.name],
            missionCounts[trail.name], languageTexts)
          if not okTrail then
            log(WARNING, string.format("custom-skirmish-trails: the trail csv file %s cannot be used, so the %s "
              .. "trail keeps the game's own missions: %s", path, trail.type, tostring(trailError)))
          end
        end
      end

      self.REGISTRY = REGISTRY -- debug line
    end)

    insertPostSkirmishSetupDetour()


    -- -- detour to get the map text displayed right...
    -- core.detourCode(function(registers)
    --   if core.readInteger(memory.IS_SKIRMISH_TRAIL) ~= 1 then
    --     return registers
    --   end

    --   if core.readInteger(memory.CURRENT_TRAIL_TYPE) ~= 2 then
    --     return registers
    --   end

    --   local mission = core.readInteger(memory.EXTREME_TRAIL_PROGRESS) + 1
    --   local entry = REGISTRY.extremeTrail[mission]
    --   -- todo
    -- end, core.AOBScan("83 C2 51 52", 9))

    log(2, "enable description hijack")
    description.enable()
    tradeability.enable()
    producibility.enable()
    startgold.enable()

    detourSwitchToMenu()
    hookPlayerNaming()
  end,
  disable = function(self, config) end,
  getTrailProgress = function(self, trail)
    local progressAddr = TRAIL_PROGRESS_ADDRESSES[trail]

    if progressAddr == nil then
      error(string.format("no such trail: %s", trail))
    end

    return core.readInteger(progressAddr)
  end,
  setTrailProgress = function(self, trail, progress)
    local progressAddr = TRAIL_PROGRESS_ADDRESSES[trail]

    if progressAddr == nil then
      error(string.format("no such trail: %s", trail))
    end

    core.writeInteger(progressAddr, progress)
  end,
  setText = function(self, line, text)
    description.setText(line, text)
  end,
  getStartGood = function(self, good)
    return start_goods.getStartGood(good)
  end,
  setStartGood = function(self, good, value)
    start_goods.setStartGood(good, value)
  end,
  getTradeable = function(self, resource)
    return tradeability.getTradeable(resource)
  end,
  setTradeable = function(self, resource, tradeable)
    tradeability.setTradeable(resource, tradeable)
  end,
  setProducible = function(self, weapon, producible)
    producibility.setWeaponProducible(weapon, producible)
  end,
  getRecruitable = function(self, unit)
    return recruitability.getUnitRecruitable(unit)
  end,
  setRecruitable = function(self, unit, value)
    recruitability.setUnitRecruitable(unit, value)
  end,
  getTextDescription = function(self, index)
    return description.getText(index)
  end,
  setTextDescription = function(self, index, value)
    return description.setText(index, value)
  end,
},
{
  public = {
    "setTrailProgress",
    "setText",
    "setTradeable",
    "setProducible",
  }
}
