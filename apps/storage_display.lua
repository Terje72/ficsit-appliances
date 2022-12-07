local fs = Deps("lib/fs")
local binser = Deps("bakpakin/binser:binser", "0.0-8")
local class = Deps("kikito/middleclass:middleclass", "v4.1.1")

local time = Deps("lib/time")
local hw = Deps("lib/hw")
local TablePrinter = Deps("lib/table_printer")
local colors = Deps("lib/colors")

CONFIG = CONFIG or CONFIG {
    main_display = "DF30A4BB4EB3755EEF429BA7FC6B405D",
    history_file = "/storage_display/history.binser",
    retention = 650,
    frequency = 25,
    rates = { { "30s", 30 }, { "5m", 5 * 60 }, { "10m", 10 * 60 } }
}

local ItemTypeRegistry = class("ItemTypeRegistry")
function ItemTypeRegistry:initialize()
    self.entries = {}
    self.lookup = {}
end

function ItemTypeRegistry:register(item_type)
    if self.lookup[item_type.name] == nil then
        table.insert(self.entries, {
            name = item_type.name,
            max = item_type.max
        })
        self.lookup[item_type.name] = #self.entries
    end
    return self.lookup[item_type.name]
end

function ItemTypeRegistry:get(index)
    return self.entries[index]
end

function ItemTypeRegistry:_serialize()
    return self.entries
end

function ItemTypeRegistry._deserialize(entries)
    local registry = ItemTypeRegistry:new()
    registry.entries = entries
    for i, entry in pairs(entries) do
        registry.lookup[entry.name] = i
    end
    return registry
end

binser.registerClass(ItemTypeRegistry)
local item_type_registry = ItemTypeRegistry:new()

DB = class("DB")
function DB:initialize()
    self.entries = {}
end

function DB:entry(item_type)
    local item_type_index = item_type_registry:register(item_type)
    if self.entries[item_type_index] == nil then
        self.entries[item_type_index] = DBEntry:new {
            item_type_index = item_type_index
        }
    end
    return self.entries[item_type_index]
end

DBEntry = class("DBEntry")
function DBEntry:initialize(o)
    self.item_type_index = o.item_type_index
    self.count = o.count or 0
    self.storage_capacity = o.storage_capacity or 0
end

function DBEntry:record_items(count)
    self.count = self.count + count
    return self
end

function DBEntry:record_capacity(stacks)
    self.storage_capacity = self.storage_capacity + stacks * self:item_type().max
    return self
end

function DBEntry:get_fill_percent()
    return math.floor(self.count / self.storage_capacity * 100)
end

function DBEntry:item_type()
    return item_type_registry:get(self.item_type_index)
end

History = class("History")
function History:initialize(o)
    o = o or {}
    self.entries = o.entries or {}
    self.retention = o.retention or CONFIG.retention
    self.frequency = o.frequency or CONFIG.frequency
end

function History:record(db, duration)
    table.insert(self.entries, HistoryEntry:new {
        db = db,
        duration = duration
    })
    self:prune()
end

function History:size()
    return #self.entries
end

function History:prune()
    local cutoff = computer.millis() / 1000 - self.retention
    local i = 1
    while i <= #self.entries do
        if self.entries[i].time < cutoff then
            table.remove(self.entries, i)
        else
            i = i + 1
        end
    end
end

function History:rate_per_minute(item_type, duration)
    local oldest_i = 1
    while oldest_i < #self.entries and self.entries[oldest_i]:age() > duration do
        oldest_i = oldest_i + 1
    end
    local oldest = self.entries[oldest_i]
    local newest = self.entries[#self.entries]

    local delta = newest.db:entry(item_type).count - oldest.db:entry(item_type).count
    local elapsed_seconds = newest.time - oldest.time
    local elapsed_minutes = elapsed_seconds / 60
    return math.floor(delta / elapsed_minutes)
end

function History:time_to_next_snapshot()
    if #self.entries == 0 then
        return 0
    end
    return math.ceil(self.frequency - self:last():age())
end

function History:last()
    return self.entries[#self.entries]
end

function History:_serialize()
    local raw_history_entries = {}
    for i, history_entry in pairs(self.entries) do
        local raw_db_entries = {}
        for j, db_entry in pairs(history_entry.db.entries) do
            raw_db_entries[j] = { db_entry.count, db_entry.storage_capacity, db_entry.item_type_index }
        end
        raw_history_entries[i] = { history_entry.time, history_entry.duration, raw_db_entries }
    end
    return raw_history_entries
end

function History._deserialize(raw_history_entries)
    local now = computer.millis() / 1000
    local last = raw_history_entries[#raw_history_entries][1]

    local h = History:new()
    for i, raw_history_entry in pairs(raw_history_entries) do
        local history_entry = HistoryEntry:new {
            -- Timekeeping is messy (see https://github.com/Panakotta00/FicsIt-Networks/issues/200),
            -- so pretend that the last snapshot happened NOW.
            time = now - (last - raw_history_entry[1]),
            duration = raw_history_entry[2],
            db = DB:new()
        }
        for j, raw_db_entry in pairs(raw_history_entry[3]) do
            local db_entry = DBEntry:new {
                count = raw_db_entry[1],
                storage_capacity = raw_db_entry[2],
                item_type_index = raw_db_entry[3]
            }
            history_entry.db.entries[j] = db_entry
        end
        h.entries[i] = history_entry
    end
    return h
end

binser.registerClass(History)

HistoryEntry = class("HistoryEntry")
function HistoryEntry:initialize(o)
    self.time = o.time or computer.millis() / 1000
    self.db = o.db
    self.duration = o.duration
end

function HistoryEntry:age()
    return math.floor(computer.millis() / 1000 - self.time)
end

local function count_items(db, container)
    local inventories = container:getInventories()
    for _, inventory in pairs(inventories) do
        local db_entry = nil
        for nStack = 0, inventory.size - 1, 1 do
            local stack = inventory:getStack(nStack)
            if stack ~= nil and stack.count ~= 0 then
                if db_entry == nil then
                    db_entry = db:entry(stack.item.type)
                elseif db_entry:item_type().name ~= stack.item.type.name then
                    computer.panic("ERROR: multiple items in container " .. container:getHash() .. " inventory " ..
                        inventory:getHash() .. ": " .. db_entry:item_type().name .. " and " ..
                        stack.item.type.name)
                end
                db_entry:record_items(stack.count)
            end
        end
        if db_entry ~= nil then
            db_entry:record_capacity(inventory.size)
        end
    end
end

local function display_status(gpu, y, status)
    gpu:setForeground(table.unpack(colors.gray30))
    gpu:setBackground(table.unpack(colors.black))
    gpu:setText(0, y, status)
    gpu:setForeground(table.unpack(colors.white))
end

local function display(history, highlight, gpu, status)
    local headings = { "NAME", "COUNT", "CAPACITY", "FILL%" }
    for _, rate in pairs(CONFIG.rates) do
        table.insert(headings, "RATE@" .. rate[1])
    end
    local table_printer = TablePrinter:new {
        headings = headings
    }
    local width = #status

    local max_rate = 0
    for _, rate in pairs(CONFIG.rates) do
        if rate[2] > max_rate then
            max_rate = rate[2]
        end
    end

    local history_entry = history:last()
    if history_entry ~= nil then
        local db = history_entry.db
        for _, entry in pairs(db.entries) do
            local fill_percent = entry:get_fill_percent()
            local rate_longest = history:rate_per_minute(entry:item_type(), max_rate)
            local color
            if fill_percent >= 99 then
                color = colors.green
            elseif fill_percent > 75 and rate_longest > 0 then
                color = colors.white
            elseif rate_longest > 0 then
                color = colors.yellow
            else
                color = colors.red
            end
            local cells = { entry:item_type().name, entry.count, entry.storage_capacity, entry:get_fill_percent() }
            for _, rate in pairs(CONFIG.rates) do
                table.insert(cells, string.format("%s/m", history:rate_per_minute(entry:item_type(), rate[2])))
            end
            table_printer:insert(color, cells)
        end
        table_printer:sort()

        local height = table_printer:print(highlight, gpu)
        display_status(gpu, height - 1, status)
    else
        display_status(gpu, 0, status)
    end

    gpu:flush()
end

local function snapshot(history, containers)
    local timer = time.timer()
    local db = DB:new()
    for _, container in pairs(containers) do
        count_items(db, container)
    end
    history:record(db, timer())
end

local function highlight_changed(old, new)
    if old == nil then
        return new ~= nil
    end
    if new == nil then
        return old ~= nil
    end
    return old[1] ~= new[1] or old[2] ~= new[2]
end

local function load_history()
    local timer = time.timer()
    local content = fs.read_all(CONFIG.history_file)
    print("Read " .. #content .. " bytes from " .. CONFIG.history_file .. " in " .. timer() .. "ms")

    timer = time.timer()
    local registry, history = binser.deserializeN(content, 2)
    print("Deserialized history with " .. history:size() .. " entries in " .. timer() .. "ms")

    return registry, history
end

local history_saving_coro = coroutine.create(function(registry, history)
    while true do
        local timer = time.timer()
        local content = binser.serialize(registry, history)
        print("Serialized history with " .. history:size() .. " entries in " .. timer() .. "ms")

        timer = time.timer()
        fs.mkdir_p(fs.dirname(CONFIG.history_file))
        fs.write_all(CONFIG.history_file, content)
        print("Wrote " .. #content .. " bytes to " .. CONFIG.history_file .. " in " .. timer() .. "ms")

        _, registry, history = coroutine.yield()
    end
end)

local function save_history(registry, history)
    if coroutine.status(history_saving_coro) == "running" then
        print("Previous history save in progress, ignoring request")
        return
    end
    coroutine.resume(history_saving_coro, registry, history)
end

local function main()
    local containers = component.proxy(component.findComponent(findClass("Build_StorageContainerMk2_C")))
    local gpu = hw.gpu()
    local main_display = component.proxy("DF30A4BB4EB3755EEF429BA7FC6B405D")

    local history = nil
    if fs.exists(CONFIG.history_file) then
        local status, registry_or_error, new_history = pcall(load_history)
        if status then
            item_type_registry = registry_or_error
            history = new_history
        else
            print("Error loading history: " .. registry_or_error)
        end
    end
    if history == nil then
        history = History:new {
            retention = CONFIG.retention,
            frequency = CONFIG.frequency
        }
        print("Created new history")
    end

    gpu:bindScreen(main_display)
    event.listen(gpu)

    local last_highlight = nil
    local last_time_to_next_snapshot = nil
    while true do
        local highlight = nil
        local dirty = false
        local force_update = false

        -- Process the event queue
        local e, s, x, y = event.pull(1.0)
        while e ~= nil do
            if e == "OnMouseMove" then
                highlight = { x, y }
                if highlight_changed(last_highlight, highlight) then
                    dirty = true
                    last_highlight = highlight
                end
            end
            if e == "OnMouseDown" then
                force_update = true
            end
            e, s, x, y = event.pull(0)
        end

        local time_to_next_snapshot = history:time_to_next_snapshot()
        if last_time_to_next_snapshot ~= time_to_next_snapshot then
            dirty = true
        end
        if time_to_next_snapshot <= 0 or force_update then
            snapshot(history, containers)
            last_time_to_next_snapshot = time_to_next_snapshot
            dirty = true
            save_history(item_type_registry, history)
        end

        if dirty then
            local status = string.format("Last update %ss ago (took %sms). Next update in %ss or on click.",
                history:last():age(), history:last().duration, time_to_next_snapshot)
            display(history, last_highlight, gpu, status)
        end
    end
end

return main
