local fs = require("@lune/fs")
local luau = require("@lune/luau")
for _, path in {
	"src/client/Controllers/RebirthController.luau", "src/shared/RebirthLayout.luau", "src/shared/DebrisOre.luau",
	"src/server/Services/RebirthService.luau", "src/server/Lib/RebirthReset.luau", "src/server/Lib/ProfileTemplate.luau",
	"src/server/Services/PlayerStateService.luau", "src/server/Services/RefineryService.luau", "src/server/Services/DebrisService.luau",
	"tests/RebirthLayout.spec.luau", "tests/RebirthReset.spec.luau", "tests/DebrisOre.spec.luau",
} do
	luau.load(fs.readFile(path), { debugName = path })
	print("Compiled " .. path)
end
