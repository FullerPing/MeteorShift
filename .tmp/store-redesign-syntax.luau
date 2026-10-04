local fs = require("@lune/fs")
local luau = require("@lune/luau")
local path = "src/client/Controllers/StoreController.luau"
luau.load(fs.readFile(path), { debugName = path })
print("Syntax OK: " .. path)
