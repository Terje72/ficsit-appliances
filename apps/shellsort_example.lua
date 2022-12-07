local shellsort = Deps("third_party/shellsort")

local function main()
    local t = { 1391376, 463792, 198768, 86961, 33936, 13776, 4592, 1968, 861, 336, 112, 48, 21, 7, 3, 1 }
    shellsort(t)
    for _, n in pairs(t) do
        print(n)
    end
end

return main
