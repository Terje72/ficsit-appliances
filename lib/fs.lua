--- Filesystem helpers. Exposes all functions of the build-in "filesystem" module.
local fs = setmetatable({}, {
    __index = filesystem
})

function fs.mkdir_p(dir)
    local path = ""
    for part in string.gmatch(dir, "[^/]+") do
        path = path .. "/" .. part
        if not filesystem.isDir(path) then
            if filesystem.createDir(path) then
                print("[fs.mkdir_p] Created directory " .. path)
            else
                computer.panic("[fs.mkdir_p] Cannot create directory " .. path)
            end
        end
    end
end

function fs.dirname(path)
    return string.match(path, "^(.*)/[^/]+$")
end

function fs.write_all(path, content)
    local file = filesystem.open(path, "wb")
    file:write(content)
    file:close()
end

function fs.read_all(path)
    -- Work around https://github.com/Panakotta00/FicsIt-Networks/issues/201
    local all, buf = "", ""
    local file = fs.open(path, "rb")
    repeat
        buf = file:read(0x10000)
        if buf ~= nil then
            all = all .. buf
        end
    until buf == nil
    file:close()
    return all
end

return fs
