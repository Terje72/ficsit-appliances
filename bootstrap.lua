BOOTSTRAP_APP = { "apps/shellsort_example", "411d553" } -- Update this for the location / commit of the app you want to run on this computer
DEPS_DISK_UUID = nil -- Replace this with the disk UUID to use for the dependency cache if you have more than one disks in the system
BOOTSTRAP_REPO = "Terje72/ficsit-appliances"
DEPS_COMMIT = "master"

-- YOU SHOULD NOT HAVE TO EDIT ANYTHING BELOW THIS LINE --
Deps = nil
local function _bootstrap()
    -- Initialize FS
    if filesystem.initFileSystem("/dev") == false then
        computer.panic("Cannot initialize /dev")
    end

    -- Find the disk where we'll cache dependencies
    if DEPS_DISK_UUID == nil then
        local drives = filesystem.childs("/dev")
        for idx, drive in pairs(drives) do
            if drive == "serial" then
                table.remove(drives, idx)
            end
        end
        if #drives == 0 then
            computer.panic("No drives found")
        end
        if #drives > 1 then
            computer.panic("Multiple drives found")
        end
        DEPS_DISK_UUID = drives[1]
    end

    -- Mount the FS
    filesystem.mount("/dev/" .. DEPS_DISK_UUID, "/")
    print("[bootstrap] Mounted /dev/" .. DEPS_DISK_UUID .. " to /")

    -- Fetch deps.lua if needed
    local path = "/deps-" .. DEPS_COMMIT .. ".lua"
    if not filesystem.exists(path) then
        local url = "https://raw.githubusercontent.com/" .. BOOTSTRAP_REPO .. "/" .. DEPS_COMMIT .. "/lib/deps.lua"
        local internet = computer.getPCIDevices(findClass("FINInternetCard"))[1]
        local req = internet:request(url, "GET", "", "User-Agent", "Ficsit-Appliances/Bootstrap https://github.com/" ..
            BOOTSTRAP_REPO .. "@" .. DEPS_COMMIT)
        local _, Deps_source = req:await()
        local file = filesystem.open(path, "w")
        file:write(Deps_source)
        file:close()
        print("[bootstrap] Fetched " .. path .. " from " .. url)
    end
    Deps = filesystem.doFile(path)

    -- Run the app
    local target, version = table.unpack(BOOTSTRAP_APP)
    print("[bootstrap] Loading: " .. target .. " @ " .. version)
    local app = Deps(target, version)
    print("[bootstrap] Starting: " .. target .. " @ " .. version)
    app()
end

_bootstrap()
