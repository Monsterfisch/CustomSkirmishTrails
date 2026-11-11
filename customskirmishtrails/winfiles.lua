-- Writing files where UCP's io.open does not: UCP refuses to write inside ucp/plugins and
-- ucp/modules, which is where trail csv files usually live. Export and Import therefore write
-- through Windows' own ANSI functions: the game's kernel32 imports where it has them, the
-- kernel32 export table for the rest. Paths are game-relative ("ucp/plugins/...") or absolute.

local winfiles = {}

local IMAGE_BASE = 0x400000
local OFFSET_NT_HEADERS = 0x3C
local OFFSET_EXPORT_DIRECTORY = 0x78
local OFFSET_IMPORT_DIRECTORY = 0x80
local IMPORT_DESCRIPTOR_SIZE = 20
local MAX_FORWARDS = 4
local PATH_BUFFER_SIZE = 1024
local FIND_DATA_SIZE = 320
local FIND_DATA_ATTRIBUTES = 0x00
local FIND_DATA_NAME = 0x2C
local FILE_ATTRIBUTE_DIRECTORY = 0x10
local INVALID_HANDLE = 0xFFFFFFFF
local GENERIC_WRITE = 0x40000000
local CREATE_ALWAYS = 2
local FILE_ATTRIBUTE_NORMAL = 0x80
local ERROR_ALREADY_EXISTS = 183

local win = {}
local pathBuffer, findData, writtenBuffer, gameDirectory
local dataBuffer, dataBufferSize = nil, 0

local function findImportSlot(dllName, functionName)
  local ntHeaders = IMAGE_BASE + core.readInteger(IMAGE_BASE + OFFSET_NT_HEADERS)
  local descriptor = IMAGE_BASE + core.readInteger(ntHeaders + OFFSET_IMPORT_DIRECTORY)
  while core.readInteger(descriptor + 12) ~= 0 do
    local dll = core.readString(IMAGE_BASE + core.readInteger(descriptor + 12))
    if dll:lower() == dllName:lower() then
      local lookup = core.readInteger(descriptor)
      local addresses = core.readInteger(descriptor + 16)
      if lookup == 0 then
        lookup = addresses
      end
      local index = 0
      local entry = core.readInteger(IMAGE_BASE + lookup)
      while entry ~= 0 do
        if entry > 0 and core.readString(IMAGE_BASE + entry + 2) == functionName then
          return IMAGE_BASE + addresses + index * 4
        end
        index = index + 1
        entry = core.readInteger(IMAGE_BASE + lookup + index * 4)
      end
    end
    descriptor = descriptor + IMPORT_DESCRIPTOR_SIZE
  end
  return nil
end

---A cdecl function that forwards its arguments to the stdcall function whose pointer is at `slot`.
local function stdcallThunk(slot, argumentCount)
  local code = {}
  for _ = 1, argumentCount do
    for _, byte in ipairs({ 0xFF, 0x74, 0x24, 4 * argumentCount }) do -- push dword [esp + 4n]
      table.insert(code, byte)
    end
  end
  table.insert(code, 0xFF)
  table.insert(code, 0x15) -- call dword [slot]
  for _, byte in ipairs(core.itob(slot)) do
    table.insert(code, byte)
  end
  table.insert(code, 0xC3)
  return core.exposeCode(core.allocateCode(code), argumentCount, 0)
end

local function writeCString(buffer, text)
  core.writeString(buffer, text)
  core.writeByte(buffer + #text, 0)
end

local function setPath(path)
  if #path >= PATH_BUFFER_SIZE then
    error("path too long: " .. path)
  end
  writeCString(pathBuffer, path)
  return pathBuffer
end

local function findExport(base, functionName, depth)
  local ntHeaders = base + core.readInteger(base + OFFSET_NT_HEADERS)
  local directoryRva = core.readInteger(ntHeaders + OFFSET_EXPORT_DIRECTORY)
  local directorySize = core.readInteger(ntHeaders + OFFSET_EXPORT_DIRECTORY + 4)
  local directory = base + directoryRva
  local nameCount = core.readInteger(directory + 0x18)
  local functionTable = base + core.readInteger(directory + 0x1C)
  local nameTable = base + core.readInteger(directory + 0x20)
  local ordinalTable = base + core.readInteger(directory + 0x24)
  for index = 0, nameCount - 1 do
    if core.readString(base + core.readInteger(nameTable + index * 4)) == functionName then
      local ordinal = core.readSmallInteger(ordinalTable + index * 2) & 0xFFFF
      local rva = core.readInteger(functionTable + ordinal * 4)
      if rva >= directoryRva and rva < directoryRva + directorySize then
        -- a forwarder, "OTHERDLL.Function"
        local dll, forwarded = core.readString(base + rva):match("^(.-)%.(.+)$")
        if dll == nil or depth >= MAX_FORWARDS then
          return nil
        end
        local forwardBase = win.LoadLibraryA(setPath(dll .. ".dll")) & 0xFFFFFFFF
        if forwardBase == 0 then
          return nil
        end
        return findExport(forwardBase, forwarded, depth + 1)
      end
      return base + rva
    end
  end
  return nil
end

local initialized = false

local function initialize()
  if initialized then
    return
  end
  pathBuffer = core.allocate(PATH_BUFFER_SIZE, true)
  findData = core.allocate(FIND_DATA_SIZE, true)
  writtenBuffer = core.allocate(4, true)

  local loadLibrarySlot = findImportSlot("kernel32.dll", "LoadLibraryA")
  if loadLibrarySlot == nil then
    error("the game does not import LoadLibraryA")
  end
  win.LoadLibraryA = stdcallThunk(loadLibrarySlot, 1)
  local kernel32 = win.LoadLibraryA(setPath("kernel32.dll")) & 0xFFFFFFFF

  local functions = {
    { "CreateDirectoryA", 2 }, { "FindFirstFileA", 2 }, { "FindNextFileA", 2 }, { "FindClose", 1 },
    { "GetModuleFileNameA", 3 }, { "CreateFileA", 7 }, { "WriteFile", 5 }, { "CloseHandle", 1 },
    { "GetLastError", 0 }, { "MultiByteToWideChar", 6 }, { "GetFileAttributesExA", 3 },
    { "DeleteFileA", 1 },
  }
  for _, entry in ipairs(functions) do
    local name, argumentCount = entry[1], entry[2]
    local slot = findImportSlot("kernel32.dll", name)
    if slot == nil then
      local address = kernel32 ~= 0 and findExport(kernel32, name, 0) or nil
      if address == nil then
        error("kernel32 has no " .. name)
      end
      slot = core.allocate(4, true)
      core.writeInteger(slot, address)
    end
    win[name] = stdcallThunk(slot, argumentCount)
  end

  local length = win.GetModuleFileNameA(0, pathBuffer, PATH_BUFFER_SIZE)
  gameDirectory = core.readString(pathBuffer, length):match("^(.*[/\\])") or ""
  initialized = true
end

---The absolute Windows path of a game-relative path, aliases resolved.
function winfiles.absolute(path)
  initialize()
  local resolved = ucp.internal.resolveAliasedPath(path):gsub("/", "\\")
  if resolved:match("^%a:\\") or resolved:match("^\\\\") then
    return resolved
  end
  return gameDirectory .. resolved
end

local function lastError()
  return string.format("Windows error %d", win.GetLastError())
end

---Creates the folder `path` (one level). True when it exists afterwards.
function winfiles.createDirectory(path)
  initialize()
  local absolute = winfiles.absolute(path)
  if win.CreateDirectoryA(setPath(absolute), 0) ~= 0 then
    return true
  end
  local err = win.GetLastError()
  if err == ERROR_ALREADY_EXISTS then
    return true
  end
  return false, string.format("cannot create the folder %s (Windows error %d)", absolute, err)
end

---The names of the files (not folders) in the folder `path` that match `pattern` ("*.json").
function winfiles.listFiles(path, pattern)
  initialize()
  local absolute = winfiles.absolute(path):gsub("\\$", "")
  local handle = win.FindFirstFileA(setPath(absolute .. "\\" .. pattern), findData) & 0xFFFFFFFF
  local names = {}
  if handle == INVALID_HANDLE then
    return names
  end
  repeat
    local attributes = core.readInteger(findData + FIND_DATA_ATTRIBUTES) & 0xFFFFFFFF
    if attributes & FILE_ATTRIBUTE_DIRECTORY == 0 then
      table.insert(names, core.readString(findData + FIND_DATA_NAME))
    end
  until win.FindNextFileA(handle, findData) == 0
  win.FindClose(handle)
  return names
end

---Copies the bytes of a Lua string to `address`. Binary safe (zero bytes included), unlike
---core.writeString.
local COPY_CHUNK = 4096
function winfiles.writeMemory(address, contents)
  for offset = 1, #contents, COPY_CHUNK do
    local last = math.min(offset + COPY_CHUNK - 1, #contents)
    core.writeBytes(address + offset - 1, { contents:byte(offset, last) })
  end
end

---A Lua function calling the stdcall function `name` exported by `dll` (loaded if needed).
function winfiles.dllFunction(dll, name, argumentCount)
  initialize()
  local base = win.LoadLibraryA(setPath(dll)) & 0xFFFFFFFF
  if base == 0 then
    return nil, "cannot load " .. dll
  end
  local address = findExport(base, name, 0)
  if address == nil then
    return nil, dll .. " has no " .. name
  end
  local slot = core.allocate(4, true)
  core.writeInteger(slot, address)
  return stdcallThunk(slot, argumentCount)
end

---A new zero-terminated UTF-16 copy of the ANSI path `path` (for GDI+). Free it with core.deallocate.
function winfiles.widePath(path)
  initialize()
  local absolute = winfiles.absolute(path)
  local characters = win.MultiByteToWideChar(0, 0, setPath(absolute), -1, 0, 0)
  if characters <= 0 then
    return nil
  end
  local buffer = core.allocate(characters * 2 + 2, true)
  win.MultiByteToWideChar(0, 0, setPath(absolute), -1, buffer, characters)
  return buffer
end

---"size:time" of the file `path` (changes whenever the file does), or nil when it is missing.
function winfiles.fileStamp(path)
  initialize()
  local data = core.allocate(36, true) -- WIN32_FILE_ATTRIBUTE_DATA
  local stamp = nil
  if win.GetFileAttributesExA(setPath(winfiles.absolute(path)), 0, data) ~= 0 then
    stamp = string.format("%u:%u:%u", core.readInteger(data + 32) & 0xFFFFFFFF,
      core.readInteger(data + 20) & 0xFFFFFFFF, core.readInteger(data + 24) & 0xFFFFFFFF)
  end
  core.deallocate(data)
  return stamp
end

---The last write time of the file `path` as a number (larger = newer), or nil when it is missing.
function winfiles.fileTime(path)
  initialize()
  local data = core.allocate(36, true)
  local time = nil
  if win.GetFileAttributesExA(setPath(winfiles.absolute(path)), 0, data) ~= 0 then
    time = (core.readInteger(data + 24) & 0xFFFFFFFF) * 4294967296 + (core.readInteger(data + 20) & 0xFFFFFFFF)
  end
  core.deallocate(data)
  return time
end

---Deletes the file `path`. True when it is gone afterwards.
function winfiles.deleteFile(path)
  initialize()
  if win.DeleteFileA(setPath(winfiles.absolute(path))) ~= 0 then
    return true
  end
  return winfiles.fileStamp(path) == nil
end

---Writes `contents` (any bytes) to the file `path`, replacing it.
function winfiles.writeFile(path, contents)
  initialize()
  local absolute = winfiles.absolute(path)
  local handle = win.CreateFileA(setPath(absolute), GENERIC_WRITE, 0, 0, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0)
    & 0xFFFFFFFF
  if handle == INVALID_HANDLE then
    return false, string.format("cannot write %s (%s)", absolute, lastError())
  end
  local ok, err = true, nil
  if #contents > 0 then
    if #contents + 1 > dataBufferSize then
      if dataBuffer ~= nil then
        core.deallocate(dataBuffer)
      end
      dataBufferSize = math.max(#contents + 1, 64 * 1024)
      dataBuffer = core.allocate(dataBufferSize, true)
    end
    winfiles.writeMemory(dataBuffer, contents)
    if win.WriteFile(handle, dataBuffer, #contents, writtenBuffer, 0) == 0
      or core.readInteger(writtenBuffer) ~= #contents then
      ok, err = false, string.format("cannot write %s (%s)", absolute, lastError())
    end
  end
  win.CloseHandle(handle)
  return ok, err
end

return winfiles
