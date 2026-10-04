local fs = require("@lune/fs")
local luau = require("@lune/luau")
for _, path in {
	"src/server/Services/RefineryService.luau",
	"src/server/Services/PlayerStateService.luau",
	"src/server/Lib/ProfileTemplate.luau",
	".tmp/refinery-priority-runtime-qa.luau",
} do
	luau.load(fs.readFile(path), { debugName = path })
	print("Syntax OK: " .. path)
end
