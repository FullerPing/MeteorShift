local fs = require("@lune/fs")
local luau = require("@lune/luau")
for _, path in { "src/client/Controllers/ShopController.luau", "src/shared/EquipmentShopLayout.luau", "tests/EquipmentShopLayout.spec.luau" } do
	luau.load(fs.readFile(path), { debugName = path })
	print("Compiled " .. path)
end
