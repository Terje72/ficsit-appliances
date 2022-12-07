local class = Deps("kikito/middleclass:middleclass", "v4.1.1")
local shellsort = Deps("third_party/shellsort")

local colors = Deps("lib/colors")

local TablePrinter = class("TablePrinter")
function TablePrinter:initialize(o)
    self.headings = {
        cells = o.headings
    }
    self.rows = {}
    self.rowcolors = {}
    self.widths = {}

    for i, heading in pairs(self.headings.cells) do
        self.widths[i] = #heading
    end
end

function TablePrinter:sort()
    shellsort(self.rows, function(a, b)
        return a.cells[1] < b.cells[1]
    end)
end

function TablePrinter:insert(color, row)
    local row_str = {}
    for _, col in pairs(row) do
        table.insert(row_str, tostring(col))
    end

    for i, cell in pairs(row_str) do
        if self.widths[i] == nil or #cell > self.widths[i] then
            self.widths[i] = #cell
        end
    end

    table.insert(self.rows, {
        color = color,
        cells = row_str
    })
end

function TablePrinter:align_columns(row)
    local padding
    local retval = {}
    for j, cell in pairs(row) do
        padding = self.widths[j] - #cell
        table.insert(retval, string.rep(" ", padding) .. " " .. cell .. " ")
    end
    return retval
end

function TablePrinter:colors(cell, highlight)
    local x, y, width = table.unpack(cell)
    if y == 0 then
        return colors.black, colors.white
    end
    local bgcolor = colors.black
    if highlight ~= nil and highlight[2] <= #self.rows then
        local x_hit = x < highlight[1] and x + width >= highlight[1]
        local y_hit = y == highlight[2]
        if x_hit and y_hit then
            bgcolor = colors.gray50
        elseif x_hit or y_hit then
            bgcolor = colors.gray30
        end
    end
    return self.rows[y].color, bgcolor
end

function TablePrinter:format_row(y, highlight, row)
    local retval = {}
    local x = 1
    for _, cell in pairs(self:align_columns(row.cells)) do
        local fg, bg = self:colors({x, y, #cell}, highlight)
        table.insert(retval, {cell, fg, bg})
        x = x + #cell
    end
    return retval
end

function TablePrinter:format(highlight)
    local retval = {}
    table.insert(retval, self:format_row(0, highlight, self.headings))
    for y, row in pairs(self.rows) do
        table.insert(retval, self:format_row(y, highlight, row))
    end
    return retval
end

function TablePrinter:print(highlight, gpu)
    local rows = self:format(highlight)
    local width = 0
    for _, row in pairs(rows) do
        local this_width = 0
        for _, cell in pairs(row) do
            this_width = this_width + #cell[1]
        end
        if this_width > width then
            width = this_width
        end
    end
    local height = #rows + 2
    gpu:setSize(width, height)
    gpu:setForeground(table.unpack(colors.white))
    gpu:setBackground(table.unpack(colors.black))
    gpu:fill(0, 0, width, height, "")
    for y, row in pairs(rows) do
        local x = 0
        for _, cellspec in pairs(row) do
            local cell, fg, bg = table.unpack(cellspec)
            gpu:setForeground(table.unpack(fg))
            gpu:setBackground(table.unpack(bg))
            gpu:setText(x, y - 1, cell)
            x = x + #cell
        end
    end

    return height
end

return TablePrinter
