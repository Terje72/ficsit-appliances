function FindGPU(w, h)
    gpu = computer.getPCIDevices(findClass("GPU_T1_C"))[1]
    screen = component.proxy("C1474A8742A4F5D26628068A7821EBB2")

    if not gpu then
        error("ERROR: GPU is missing in computer.")
    end

    if not screen then
        error("ERROR: No large screen connected.")
    end

    gpu:bindScreen(screen)
end


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


function sleep(n)
    local t0 = computer.time()
    while computer.time() - t0 <= n do end
end

FindGPU()
sleeo(1)

