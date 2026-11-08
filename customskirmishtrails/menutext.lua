-- The trail's title and summary under its button in the skirmish menu.
--
-- The game draws both as one centred line each (title at y + 400, summary at y + 440). A trail
-- with a title or summary of its own gets both moved up by 10 pixels, and a summary wider than
-- 540 pixels is split at a space into two centred lines: the game's draw call for that summary
-- goes through a small stub that draws the two lines instead of the one.

local visuals = require("customskirmishtrails.visuals")
local winfiles = require("customskirmishtrails.winfiles")

local menutext = {}

local SUMMARY_MAX_WIDTH = 540
local SUMMARY_LINE_HEIGHT = 20
local SUMMARY_FONT = 0x11
local MOVE_UP = 10
local LINE_BUFFER_SIZE = 1000

-- Each block: "add eax, y" (imm at +1), push the text id, getText, "mov ecx, textManager"
-- (imm at +0x20), "call renderTextToScreen" (at +0x24). Same layout in both exes.
local BLOCKS = {
  firstEditionTrail = {
    title = "05 90 01 00 00 50 ? ? ? ? 00 00 51 6A 01 68 F2 00 00 00 B9 ? ? ? ? E8 ? ? ? ? 50 B9 ? ? ? ? E8 ? ? ? ?",
    summary = "05 B8 01 00 00 50 ? ? ? ? 00 00 51 6A 02 68 F2 00 00 00 B9 ? ? ? ? E8 ? ? ? ? 50 B9 ? ? ? ? E8 ? ? ? ?",
  },
  warchestTrail = {
    title = "05 90 01 00 00 50 ? ? ? ? 00 00 51 6A 15 68 FA 00 00 00 B9 ? ? ? ? E8 ? ? ? ? 50 B9 ? ? ? ? E8 ? ? ? ?",
    summary = "05 B8 01 00 00 50 ? ? ? ? 00 00 51 6A 16 68 FA 00 00 00 B9 ? ? ? ? E8 ? ? ? ? 50 B9 ? ? ? ? E8 ? ? ? ?",
  },
  extremeTrail = {
    title = "05 90 01 00 00 50 ? ? ? ? 00 00 51 6A 17 68 FA 00 00 00 B9 ? ? ? ? E8 ? ? ? ? 50 B9 ? ? ? ? E8 ? ? ? ?",
    summary = "05 B8 01 00 00 50 ? ? ? ? 00 00 51 6A 18 68 FA 00 00 00 B9 ? ? ? ? E8 ? ? ? ? 50 B9 ? ? ? ? E8 ? ? ? ?",
  },
}
local TEXT_MANAGER_OFFSET = 0x20
local RENDER_CALL_OFFSET = 0x24

-- The stub replaces "call renderTextToScreen" (thiscall, 8 arguments: text, x, y, alignment,
-- colour, font, keepOffset, blend). With an empty second line it simply jumps on; otherwise it
-- draws line one and line two (y + LINE_HEIGHT) with the same arguments.
local STUB = [[
  cmp byte [LINE2], 0
  jne split
  jmp near RENDER
split:
  mov dword [SAVEDECX], ecx
  push dword [esp + 32]
  push dword [esp + 32]
  push dword [esp + 32]
  push dword [esp + 32]
  push dword [esp + 32]
  push dword [esp + 32]
  push dword [esp + 32]
  push dword [esp + 32]
  mov dword [esp], LINE1
  mov ecx, dword [SAVEDECX]
  call near RENDER
  push dword [esp + 32]
  push dword [esp + 32]
  push dword [esp + 32]
  push dword [esp + 32]
  push dword [esp + 32]
  push dword [esp + 32]
  push dword [esp + 32]
  push dword [esp + 32]
  mov dword [esp], LINE2
  add dword [esp + 8], LINEHEIGHT
  mov ecx, dword [SAVEDECX]
  call near RENDER
  ret 32
]]

local function scan(pattern, purpose)
  local ok, address = pcall(core.AOBScan, pattern)
  if not ok or address == nil then
    log(WARNING, "custom-skirmish-trails: could not find " .. purpose .. "; it stays as the game draws it")
    return nil
  end
  return address
end

local function writeCString(address, text)
  winfiles.writeMemory(address, text)
  core.writeByte(address + #text, 0)
end

local textWidth = nil

local function measure(textManager, text)
  if textWidth == nil then
    local computeTextWidth = scan("56 8B 74 24 08 85 F6 75 06 33 C0 5E C2 08 00 8B C6", "the text width function")
    if computeTextWidth == nil then
      return nil
    end
    textWidth = core.exposeCode(computeTextWidth, 3, 1)
  end
  local buffer = core.allocate(#text + 1, true)
  writeCString(buffer, text)
  local width = textWidth(textManager, buffer, SUMMARY_FONT)
  core.deallocate(buffer)
  return width
end

---Splits `text` (in the game's encoding) at spaces into a first line no wider than the limit
---and the rest.
local function split(textManager, text)
  local width = measure(textManager, text)
  if width == nil or width <= SUMMARY_MAX_WIDTH then
    return text, ""
  end
  local words = {}
  for word in text:gmatch("%S+") do
    table.insert(words, word)
  end
  local first = words[1] or ""
  local used = 1
  for index = 2, #words do
    local candidate = first .. " " .. words[index]
    if measure(textManager, candidate) > SUMMARY_MAX_WIDTH then
      break
    end
    first, used = candidate, index
  end
  local rest = table.concat(words, " ", used + 1)
  if rest ~= "" and measure(textManager, rest) > SUMMARY_MAX_WIDTH then
    log(WARNING, "custom-skirmish-trails: a trail summary needs more than two lines of 540 pixels; the second line is cut")
  end
  return first, rest
end

local stubs = {}

---Sets the title and summary of `trailName` (UTF-8 texts, nil keeps the game's own).
function menutext.apply(trailName, title, summary)
  if title == nil and summary == nil then
    return
  end
  visuals.applyTexts(trailName, title, summary)

  local blocks = BLOCKS[trailName]
  local titleBlock = scan(blocks.title, trailName .. " title")
  local summaryBlock = scan(blocks.summary, trailName .. " summary")
  if titleBlock == nil or summaryBlock == nil then
    return
  end

  -- both up by 10 pixels
  core.writeCodeInteger(titleBlock + 1, core.readInteger(titleBlock + 1) - MOVE_UP)
  core.writeCodeInteger(summaryBlock + 1, core.readInteger(summaryBlock + 1) - MOVE_UP)

  if summary == nil then
    return
  end
  local textManager = core.readInteger(summaryBlock + TEXT_MANAGER_OFFSET)
  local call = summaryBlock + RENDER_CALL_OFFSET
  local render = call + 5 + core.readInteger(call + 1)
  local first, second = split(textManager, modules.textResourceModifier:TransformText(summary))
  if second == "" then
    return
  end

  local lines = stubs[trailName]
  if lines == nil then
    lines = {
      first = core.allocate(LINE_BUFFER_SIZE, true),
      second = core.allocate(LINE_BUFFER_SIZE, true),
      ecx = core.allocate(4, true),
    }
    local stub = core.allocateAssembly(STUB, {
      LINE1 = lines.first, LINE2 = lines.second, SAVEDECX = lines.ecx,
      RENDER = render, LINEHEIGHT = SUMMARY_LINE_HEIGHT,
    })
    core.writeCodeInteger(call + 1, core.getRelativeAddress(call, stub, -5))
    stubs[trailName] = lines
  end
  writeCString(lines.first, first:sub(1, LINE_BUFFER_SIZE - 1))
  writeCString(lines.second, second:sub(1, LINE_BUFFER_SIZE - 1))
  log(INFO, string.format("custom-skirmish-trails: the %s summary is shown in two lines", trailName))
end

return menutext
