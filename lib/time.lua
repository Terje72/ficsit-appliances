local time = {}

function time.timer()
    local start = computer.millis()
    return function()
        return computer.millis() - start
    end
end

return time
