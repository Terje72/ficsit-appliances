function ClearScreen(w, h)
    gpu:setBackground(0, 0, 0, 0)
    gpu:setForeground(0, 0, 0, 1)
    gpu:fill(0, 0, w, h, " ")
    gpu:flush()
end

------------------

function sleep(n)
    local t0 = computer.time()
    while computer.time() - t0 <= n do end
end

FindGPU()
    gpu:setForeground(0, 0, 0, 1)
    gpu:fill(0, 0, w, h, " ")
    gpu:flush()
end

------------------

function sleep(n)
    local t0 = computer.time()
    while computer.time() - t0 <= n do end
end

FindGPU()
