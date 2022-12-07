function FindGPU(w, h)
    gpu = computer.getPCIDevices(findClass("GPU_T1_C"))[1]
    screen = component.proxy(component.findComponent(findClass("Build_Screen_C")))[1]

    if not gpu then
        error("ERROR: GPU is missing in computer.")
    end

    if not screen then
        error("ERROR: No large screen connected.")
    end

    gpu:bindScreen(screen)
end

-----------------

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

----------------------------------------------------------------------------
----------------------------------------------------------------------------

local screenWidth = 60
local screenHeight = 20
local container = component.proxy("5A46EE4B44C616666A07958C95A23747")

FindGPU()

--Panel
panel = component.proxy("D34E25C94506EC76246E038305AB1BDB") -- Bryter panel
--Txt modul
textmodule = panel:getModule(0, 0, 0)
textmodule.size = 50

-- Button
button = panel:getModule(5, 0, 0)
button2 = panel:getModule(7, 0, 0)
event.listen(button, button2)
button:setColor(0, 0, 1, 0)
button2:setColor(0, 0, 1, 0)

while true do
    ClearScreen(screenWidth, screenHeight)
    gpu:setSize(screenWidth, screenHeight)
    --gpu:setBackground(0, 1, 0, 1)
    gpu:setForeground(1, 1, 1, 1)
    -----------------------------
    gpu:setText(2, 0, "Max fluid: ")
    gpu:setForeground(1, 0, 0, 1)
    gpu:setText(16, 0, container.maxFluidContent)
    ----------------
    gpu:setForeground(1, 1, 1, 1)
    gpu:setText(2, 1, "Fluid: ")
    gpu:setText(16, 1, container.fluidContent)
    gpu:flush()

    -- Text modul
    textmodule.text = container.fluidContent

    -- Button
    e, s = event.pull(2)
    if s == button then
        print("Button 1 trykket.")
        button:setColor(0, 1, 0, 5)
        sleep(30)
        button:setColor(0, 0, 1, 0)
    end

    if s == button2 then
        print("Button 2 trykket.")
        button2:setColor(1, 0, 0, 5)
        sleep(30)
        button2:setColor(0, 0, 1, 0)
    end

    if container.fluidContent >= container.maxFluidContent then
        container:Flush()
        print("Flush")
    end
end
