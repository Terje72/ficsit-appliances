--- Helpers for interacting with Ficsit-Networks hardware
local hw = {}

function hw.pci(classname, index)
    local class = findClass(classname)
    if class == nil then
        computer.panic("[hw.pci] Requested class not found: " .. classname)
    end
    local devices = computer.getPCIDevices(class)

    if index == nil then
        if #devices == 0 then
            computer.panic("[hw.pci] No devices found for class " .. classname)
        end
        if #devices > 1 then
            computer.panic("[hw.pci] More than one device found for class " .. classname)
        end
        return devices[1]
    end

    local device = devices[index]
    if device == nil then
        computer.panic("[hw.pci] No device found for class " .. classname .. " at index " .. index)
    end
    return device
end

function hw.gpu(index)
    return hw.pci("GPU_T1_C", index)
end

return hw
