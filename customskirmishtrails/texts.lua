-- Language text files: the trail's csv (or mission) data holds one set of texts, the default
-- language. Every further language is one JSON file with only the texts:
--
--   {
--     "trail_title": "...", "trail_summary": "...",
--     "missions": {
--       "1": { "mission_name": "...", "text_description_line_01": "...", "player2_name": "..." },
--       "2": { ... }
--     }
--   }
--
-- A mission is found by its number (1, 2, ...). A text the language file does not have keeps
-- the default text from the csv.

local settingsModule = require("customskirmishtrails.settings")
local conversion = require("customskirmishtrails.conversion")

local texts = {}

-- the columns that hold texts, in the order they are written
texts.COLUMNS = {
  "mission_name",
  "text_description_line_01", "text_description_line_02", "text_description_line_03",
  "text_description_line_04", "text_description_line_05", "text_description_line_06",
  "text_description_line_07", "text_description_line_08",
  "player1_name", "player2_name", "player3_name", "player4_name",
  "player5_name", "player6_name", "player7_name", "player8_name",
}
local IS_TEXT = {}
for _, column in ipairs(texts.COLUMNS) do
  IS_TEXT[column] = true
end

local strict = false
function texts.setStrict(value)
  strict = value == true
end

---The key of a mission in a language file: its number.
function texts.missionKey(_, index)
  return tostring(index)
end

---The language file of `language` for a trail: `textFiles` is a folder (files named
---<language>.json) or a map of languages to files. Nil when there is none.
function texts.fileFor(textFiles, language)
  if textFiles == nil then
    return nil
  end
  language = (language or ""):lower()
  if textFiles.folder ~= nil then
    local candidates = { language }
    if language == "american" then
      table.insert(candidates, "english")
    end
    for _, candidate in ipairs(candidates) do
      local path = textFiles.folder .. candidate .. ".json"
      local handle = io.open(ucp.internal.resolveAliasedPath(path), "rb")
      if handle ~= nil then
        handle:close()
        return path
      end
    end
    return nil
  end
  return textFiles.files[language] or (language == "american" and textFiles.files.english) or nil
end

---Reads a language file. Returns { title, summary, missions = { [key] = { column = text } } },
---or nil (with a warning) when it cannot be used.
function texts.load(path)
  local ok, text = pcall(settingsModule.readText, path)
  if not ok or text == nil then
    log(WARNING, string.format("custom-skirmish-trails: cannot read the language file %s; the default texts are shown", path))
    return nil
  end
  local decoded, data = pcall(function() return json:decode(text) end)
  if not decoded or type(data) ~= "table" then
    log(WARNING, string.format("custom-skirmish-trails: the language file %s is not valid JSON (%s); the default texts are shown",
      path, tostring(data)))
    return nil
  end
  local result = { path = path, missions = {} }
  if type(data.trail_title) == "string" and data.trail_title ~= "" then
    result.title = data.trail_title
  end
  if type(data.trail_summary) == "string" and data.trail_summary ~= "" then
    result.summary = data.trail_summary
  end
  local problems = 0
  if type(data.missions) == "table" then
    for key, mission in pairs(data.missions) do
      if type(mission) == "table" then
        local columns = {}
        for column, value in pairs(mission) do
          if IS_TEXT[column] and type(value) == "string" then
            columns[column] = value
          else
            problems = problems + 1
            log(strict and WARNING or VERBOSE, string.format("custom-skirmish-trails: %s: mission %s: '%s' is not a text column",
              path, tostring(key), tostring(column)))
          end
        end
        result.missions[tostring(key)] = columns
      end
    end
  elseif data.missions ~= nil then
    problems = problems + 1
  end
  if problems > 0 and not strict then
    log(WARNING, string.format("custom-skirmish-trails: %d problems in the language file %s; turn on strict mode "
      .. "(Developer settings) to see them", problems, path))
  end
  return result
end

---Puts the texts of a language file over the missions read from the csv (in place).
function texts.apply(languageTexts, entries)
  if languageTexts == nil then
    return
  end
  local used = {}
  for index, entry in ipairs(entries) do
    local key = texts.missionKey(entry, index)
    local mission = languageTexts.missions[key]
    if mission ~= nil then
      used[key] = true
      for column, value in pairs(mission) do
        entry[column] = value
      end
    end
    if strict then
      for _, column in ipairs(texts.COLUMNS) do
        local default = entry[column]
        if type(default) == "string" and default ~= "" and (mission == nil or mission[column] == nil) then
          log(INFO, string.format("custom-skirmish-trails: %s has no %s for mission %s; the default text is shown",
            languageTexts.path, column, key))
        end
      end
    end
  end
  for key in pairs(languageTexts.missions) do
    if not used[key] then
      log(strict and WARNING or VERBOSE, string.format("custom-skirmish-trails: %s: there is no mission %s in the trail",
        languageTexts.path, key))
    end
  end
end

-- Writing language files -------------------------------------------------------------------

---The JSON text of a language file with the texts of `entries` (only non-empty texts).
function texts.format(entries, title, summary)
  local q = conversion.jsonString
  local lines = { "{" }
  if title ~= nil then
    table.insert(lines, '  "trail_title": ' .. q(title) .. ",")
  end
  if summary ~= nil then
    table.insert(lines, '  "trail_summary": ' .. q(summary) .. ",")
  end
  table.insert(lines, '  "missions": {')
  local missions = {}
  for index, entry in ipairs(entries) do
    local fields = {}
    for _, column in ipairs(texts.COLUMNS) do
      local value = entry[column]
      if type(value) == "string" and value ~= "" then
        table.insert(fields, string.format("      %s: %s", q(column), q(value)))
      end
    end
    table.insert(missions, string.format("    %s: {\n%s\n    }", q(texts.missionKey(entry, index)),
      table.concat(fields, ",\n")))
  end
  table.insert(lines, table.concat(missions, ",\n"))
  table.insert(lines, "  }")
  table.insert(lines, "}")
  return table.concat(lines, "\n") .. "\n"
end

return texts
