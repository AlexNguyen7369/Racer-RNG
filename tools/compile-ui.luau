local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local count = 0
local function check(path)
    if fs.isDir(path) then
        for _, name in ipairs(fs.readDir(path)) do check(path .. "/" .. name) end
    elseif path:match("%.luau$") then
        local ok, result = pcall(luau.load, fs.readFile(path))
        assert(ok, path .. ": " .. tostring(result))
        count += 1
        print("COMPILE PASS " .. path)
    end
end
for _, path in ipairs(process.args) do check(path) end
assert(count > 0, "No Luau sources checked")
print("Validated " .. tostring(count) .. " Luau sources")
