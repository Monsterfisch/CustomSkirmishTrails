-- Turns a picture file (.png, .jpg, .bmp, .gif) into the game's .tgx format, so a trail's
-- background can be given as a png. Windows' GDI+ decodes the picture; the tgx is written to
-- ucp/.cache and made again only when the picture file changes.
--
-- TGX: width and height (4 bytes each), then per line run tokens and one end-of-line token.
-- A token byte holds the run length - 1 in its low 5 bits and the run type in its high 3:
-- 0 = that many pixels follow, 2 = one pixel follows and repeats, 1 = transparent pixels,
-- 4 = end of the line. Pixels are 16-bit 1RRRRRGGGGGBBBBB (the game's files set the top bit).

local winfiles = require("customskirmishtrails.winfiles")

local tgx = {}

local MAX_RUN = 32
local TOKEN_LITERAL, TOKEN_TRANSPARENT, TOKEN_REPEAT, TOKEN_NEWLINE = 0x00, 0x20, 0x40, 0x80
local PIXEL_FLAG = 0x8000

local PIXEL_FORMAT_32BPP_ARGB = 0x26200A
local IMAGE_LOCK_MODE_READ = 1
local BITMAP_DATA_SIZE = 24 -- Width, Height, Stride, PixelFormat, Scan0, Reserved

---Encodes pixel lines into tgx bytes. `lines[y]` is a list of 16-bit pixels, or false for a
---transparent pixel.
function tgx.encode(width, height, lines)
  local parts = { string.pack("<I4I4", width, height) }
  for y = 1, height do
    local line = lines[y]
    local x = 1
    local literal = {}
    local function flushLiteral()
      if #literal > 0 then
        local bytes = { string.char(TOKEN_LITERAL | (#literal - 1)) }
        for _, pixel in ipairs(literal) do
          table.insert(bytes, string.pack("<I2", pixel))
        end
        table.insert(parts, table.concat(bytes))
        literal = {}
      end
    end
    while x <= width do
      local pixel = line[x]
      local run = 1
      while x + run <= width and run < MAX_RUN and line[x + run] == pixel do
        run = run + 1
      end
      if pixel == false then
        flushLiteral()
        table.insert(parts, string.char(TOKEN_TRANSPARENT | (run - 1)))
        x = x + run
      elseif run >= 2 then
        flushLiteral()
        table.insert(parts, string.char(TOKEN_REPEAT | (run - 1)) .. string.pack("<I2", pixel))
        x = x + run
      else
        table.insert(literal, pixel)
        if #literal == MAX_RUN then
          flushLiteral()
        end
        x = x + 1
      end
    end
    flushLiteral()
    table.insert(parts, string.char(TOKEN_NEWLINE))
  end
  return table.concat(parts)
end

---The 16-bit tgx pixel of a 32-bit ARGB pixel given as its bytes (B, G, R, A), or false when
---it is mostly transparent.
local function tgxPixel(blue, green, red, alpha)
  if alpha < 128 then
    return false
  end
  return PIXEL_FLAG | ((red >> 3) << 10) | ((green >> 3) << 5) | (blue >> 3)
end

local gdiplus = nil

local function loadGdiplus()
  if gdiplus ~= nil then
    return gdiplus
  end
  local functions = {
    { "GdiplusStartup", 3 }, { "GdiplusShutdown", 1 }, { "GdipCreateBitmapFromFile", 2 },
    { "GdipGetImageWidth", 2 }, { "GdipGetImageHeight", 2 }, { "GdipBitmapLockBits", 5 },
    { "GdipBitmapUnlockBits", 2 }, { "GdipDisposeImage", 1 },
  }
  local loaded = {}
  for _, entry in ipairs(functions) do
    local fn, err = winfiles.dllFunction("gdiplus.dll", entry[1], entry[2])
    if fn == nil then
      error(err)
    end
    loaded[entry[1]] = fn
  end
  gdiplus = loaded
  return gdiplus
end

---Decodes the picture file `path` into tgx bytes.
function tgx.fromPicture(path)
  local g = loadGdiplus()
  local token = core.allocate(4, true)
  local input = core.allocate(16, true) -- GdiplusStartupInput
  core.writeInteger(input, 1)            -- GdiplusVersion
  local bitmapOut = core.allocate(4, true)
  local value = core.allocate(4, true)
  local rect = core.allocate(16, true)
  local data = core.allocate(BITMAP_DATA_SIZE, true)
  local wide = winfiles.widePath(path)
  local bitmap = nil

  local function cleanup()
    if bitmap ~= nil then
      g.GdipDisposeImage(bitmap)
    end
    if core.readInteger(token) ~= 0 then
      g.GdiplusShutdown(core.readInteger(token))
    end
    for _, address in ipairs({ token, input, bitmapOut, value, rect, data }) do
      core.deallocate(address)
    end
    if wide ~= nil then
      core.deallocate(wide)
    end
  end

  local ok, result = pcall(function()
    if wide == nil then
      error("cannot make a path of " .. path)
    end
    local status = g.GdiplusStartup(token, input, 0)
    if status ~= 0 then
      error(string.format("GDI+ does not start (status %d)", status))
    end
    status = g.GdipCreateBitmapFromFile(wide, bitmapOut)
    if status ~= 0 then
      error(string.format("cannot read the picture %s (GDI+ status %d)", path, status))
    end
    bitmap = core.readInteger(bitmapOut)
    g.GdipGetImageWidth(bitmap, value)
    local width = core.readInteger(value)
    g.GdipGetImageHeight(bitmap, value)
    local height = core.readInteger(value)
    if width <= 0 or height <= 0 then
      error("the picture " .. path .. " is empty")
    end

    core.writeInteger(rect + 8, width)
    core.writeInteger(rect + 12, height)
    status = g.GdipBitmapLockBits(bitmap, rect, IMAGE_LOCK_MODE_READ, PIXEL_FORMAT_32BPP_ARGB, data)
    if status ~= 0 then
      error(string.format("cannot read the pixels of %s (GDI+ status %d)", path, status))
    end
    local stride = core.readInteger(data + 8)
    local scan0 = core.readInteger(data + 16)
    local lines = {}
    for y = 0, height - 1 do
      local bytes = core.readBytes(scan0 + y * stride, width * 4)
      local line = {}
      for x = 0, width - 1 do
        local i = x * 4 + 1
        line[x + 1] = tgxPixel(bytes[i] & 0xFF, bytes[i + 1] & 0xFF, bytes[i + 2] & 0xFF, bytes[i + 3] & 0xFF)
      end
      lines[y + 1] = line
    end
    g.GdipBitmapUnlockBits(bitmap, data)
    return { width = width, height = height, bytes = tgx.encode(width, height, lines) }
  end)
  cleanup()
  if not ok then
    error(result, 0)
  end
  return result
end

---The width and height in a tgx file, or nil.
function tgx.size(path)
  local handle = io.open(ucp.internal.resolveAliasedPath(path), "rb")
  if handle == nil then
    return nil
  end
  local header = handle:read(8)
  handle:close()
  if header == nil or #header < 8 then
    return nil
  end
  return string.unpack("<I4I4", header)
end

---A tgx file for the picture `path`, made in `cachePath` unless an earlier one is still up to
---date. Returns the tgx path and its size.
function tgx.cached(path, cachePath)
  local stamp = winfiles.fileStamp(path)
  if stamp == nil then
    error("the picture " .. path .. " does not exist")
  end
  local keyPath = cachePath .. ".source"
  local keyFile = io.open(keyPath, "rb")
  if keyFile ~= nil then
    local key = keyFile:read("*all")
    keyFile:close()
    if key == path .. "|" .. stamp then
      local width, height = tgx.size(cachePath)
      if width ~= nil then
        return cachePath, width, height
      end
    end
  end
  local picture = tgx.fromPicture(path)
  local ok, err = winfiles.writeFile(cachePath, picture.bytes)
  if not ok then
    error(err)
  end
  winfiles.writeFile(keyPath, path .. "|" .. stamp)
  log(INFO, string.format("custom-skirmish-trails: made %s (%d x %d) from %s", cachePath, picture.width,
    picture.height, path))
  return cachePath, picture.width, picture.height
end

return tgx
