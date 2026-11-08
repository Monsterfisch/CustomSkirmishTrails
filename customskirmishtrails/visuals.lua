-- Trail visuals and texts from the trail settings file: the trail's button in the skirmish
-- menu (idle and highlighted picture), the trail screen's background, and the trail's title
-- and summary under the button.

local tgx = require("customskirmishtrails.tgx")

local visuals = {}
local backgroundTgx

-- The skirmish menu's trail buttons are image buttons: the idle picture is the frame shown,
-- the highlighted one the next frame. Stronghold Crusader shows the first and the Warchest
-- trail, Crusader Extreme only the Extreme trail. Frames are 0-based.
local BUTTON_FRAMES = {
  crusader = {
    firstEditionTrail = { gm = 46, idle = 667, highlighted = 668 },  -- interface_icons2
    warchestTrail = { gm = 46, idle = 758, highlighted = 759 },      -- interface_icons2
  },
  extreme = {
    extremeTrail = { gm = 156, idle = 305, highlighted = 306 },      -- interface_icons3
  },
}

local BACKGROUND_FILES = {
  firstEditionTrail = "skirmish_trail.tgx",
  warchestTrail = "skirmish_trail2.tgx",
  extremeTrail = "shcx_map.tgx",
}

-- text group, line: the title and the summary shown under the trail's button
local TEXTS = {
  firstEditionTrail = { title = { 0xF2, 1 }, summary = { 0xF2, 2 } },
  warchestTrail = { title = { 0xFA, 0x15 }, summary = { 0xFA, 0x16 } },
  extremeTrail = { title = { 0xFA, 0x17 }, summary = { 0xFA, 0x18 } },
}

local backgrounds = {}
local overrideRegistered = false

local function isExtreme()
  local ok, extreme = pcall(function() return data.version.isExtreme() end)
  return ok and extreme == true
end

local function loadImage(path)
  local gm = modules.gmResourceModifier
  if gm == nil or gm.LoadResourceFromImage == nil then
    log(WARNING, "custom-skirmish-trails: gmResourceModifier is not active; trail button pictures stay")
    return nil
  end
  local resolved = ucp.internal.resolveAliasedPath(path)
  local ok, resource = pcall(function() return gm:LoadResourceFromImage(resolved) end)
  if not ok or resource == nil or resource < 0 then
    log(WARNING, string.format("custom-skirmish-trails: cannot load the picture %s", path))
    return nil
  end
  return resource
end

local function setFrame(gmId, frame, path)
  local resource = loadImage(path)
  if resource == nil then
    return
  end
  local ok, done = pcall(function() return modules.gmResourceModifier:SetGm(gmId, frame, resource, 0) end)
  if not ok or done == false then
    log(WARNING, string.format("custom-skirmish-trails: the picture %s does not fit gm %d frame %d", path, gmId, frame))
  end
end

local function registerBackgroundOverride()
  if overrideRegistered then
    return
  end
  local files = modules.files
  if files == nil or files.registerOverrideFunction == nil then
    log(WARNING, "custom-skirmish-trails: the files module is not active; trail backgrounds stay")
    return
  end
  files:registerOverrideFunction(function(file)
    local name = tostring(file):lower():match("([^/\\]+)$")
    return name ~= nil and backgrounds[name] or nil
  end)
  overrideRegistered = true
end

---The .tgx file to show for a trail_background: a .tgx is used as it is, any other picture
---(.png, .jpg, .bmp, .gif) is turned into a .tgx in ucp/.cache first.
function backgroundTgx(trailName, path)
  local original = "gfx/" .. BACKGROUND_FILES[trailName]
  local result, width, height = path, nil, nil
  if not path:lower():match("%.tgx$") then
    local ok, made, madeWidth, madeHeight = pcall(tgx.cached, path,
      string.format("ucp/.cache/custom-skirmish-trails-background-%s.tgx", trailName))
    if not ok then
      log(WARNING, string.format("custom-skirmish-trails: the trail background stays: %s", tostring(made)))
      return nil
    end
    result, width, height = made, madeWidth, madeHeight
  else
    width, height = tgx.size(path)
  end
  local originalWidth, originalHeight = tgx.size(original)
  if width ~= nil and originalWidth ~= nil and (width ~= originalWidth or height ~= originalHeight) then
    log(WARNING, string.format("custom-skirmish-trails: %s is %d x %d, the game's %s is %d x %d",
      path, width, height, original, originalWidth, originalHeight))
  end
  return result
end

---Applies the trail_visuals of a trail settings file.
function visuals.applyVisuals(trailName, trailVisuals)
  if trailVisuals == nil then
    return
  end
  if trailVisuals.buttonIdle ~= nil or trailVisuals.buttonHighlighted ~= nil then
    local frames = BUTTON_FRAMES[isExtreme() and "extreme" or "crusader"][trailName]
    if frames == nil then
      log(INFO, string.format("custom-skirmish-trails: this game version has no menu button for the %s", trailName))
    else
      if trailVisuals.buttonIdle ~= nil then
        setFrame(frames.gm, frames.idle, trailVisuals.buttonIdle)
      end
      if trailVisuals.buttonHighlighted ~= nil then
        setFrame(frames.gm, frames.highlighted, trailVisuals.buttonHighlighted)
      end
    end
  end
  if trailVisuals.background ~= nil then
    local background = backgroundTgx(trailName, trailVisuals.background)
    if background ~= nil then
      backgrounds[BACKGROUND_FILES[trailName]] = background
      registerBackgroundOverride()
    end
  end
end

---Applies trail_title and trail_summary of a trail settings file.
function visuals.applyTexts(trailName, title, summary)
  local texts = TEXTS[trailName]
  if title ~= nil then
    modules.textResourceModifier:SetText(texts.title[1], texts.title[2], title)
  end
  if summary ~= nil then
    modules.textResourceModifier:SetText(texts.summary[1], texts.summary[2], summary)
  end
end

return visuals
