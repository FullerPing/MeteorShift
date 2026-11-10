-- Ten new mesh pets and two eggs (2026-10-24). Built in Blender by tools/blender-assets/pets.py and environment.py,
-- re-exported with the palette texture embedded and uploaded with upload_open_cloud.py (ids below, from
-- blender/upload/asset-ids.json). Run once in Edit from the command bar or MCP; the result is saved with the place.
-- Rerunnable: every entry it makes replaces the same-named one.
--
-- Makes, like ApplyPetMeshes.luau / RobloxImport.luau do for the first fourteen:
--   ReplicatedStorage.PetModels.<petId>   mesh pet (Body PrimaryPart, Level10 folder, PetColor/PetName/Rarity/Flying/
--                                          WorkingStyle/Orientation/BlenderId/MeshPets/Triangles attributes)
--   ReplicatedStorage.MeshArt.eggs.egg_<x> the hatch-preview egg HatchController looks for
--   ServerStorage.MapArt.Egg_<eggId>       the pedestal egg the map stages place (pivot at its base)
--
-- Every uploaded mesh is named "<RobloxName>#<i>", i its index in the asset's Blender JSON "objects" (DATA below), so
-- names, Neon, white tint surfaces, hidden work props and AnimationGroup/AnimationPivot are restored from DATA, not
-- guessed from names. The upload's axis convention is measured, not assumed: each part's position is fitted against
-- its Blender bounds centre over the four upright yaw turns (plus a uniform scale), then the model is turned so the
-- Blender front (-Y) faces Roblox -Z, i.e. Blender (x, y, z) = Roblox (-x, z, y), as RobloxImport.luau does.
--
--   loadstring(game:GetService("HttpService"):GetAsync("http://127.0.0.1:8124/tools/blender-assets/ImportNewPets.luau", true))()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local DATA = {
	["pets_dustBunny"] = {
		id = 140622037443568, blender = "pets/dustBunny", triangles = 1916,
		parts = {
			{ name = "Body", center = {0, 0.15, 0.95}, tint = true },
			{ name = "Fluff", center = {0, 0.335, 1.1095} },
			{ name = "Head", center = {-0, -0.68, 1.58}, group = "Head", pivot = {0, -0.4, 1.32} },
			{ name = "Ears", center = {-0, -0.5539, 2.5805}, group = "Ears", pivot = {0, -0.55, 1.98} },
			{ name = "FrontLeg", center = {-0.42, -0.55, 0.21}, group = "FrontLeg", pivot = {-0.42, -0.55, 0.3486} },
			{ name = "BackLeg", center = {-0.42, 0.55, 0.21}, group = "BackLeg", pivot = {-0.42, 0.55, 0.3486} },
			{ name = "FrontLeg", center = {0.42, -0.55, 0.21}, group = "FrontLeg", pivot = {0.42, -0.55, 0.3486} },
			{ name = "BackLeg", center = {0.42, 0.55, 0.21}, group = "BackLeg", pivot = {0.42, 0.55, 0.3486} },
			{ name = "Tail", center = {0, 1.12, 1}, group = "Tail", pivot = {0, 0.9, 1} },
			{ name = "GreyChip", center = {0, -1.3, 0.24}, work = true, group = "GreyChip", pivot = {0, -1.3, 0.18} },
		},
	},
	["pets_dustBunny_lv10"] = {
		id = 104761920595186, blender = "pets/dustBunny_lv10", triangles = 2160,
		parts = {
			{ name = "Body", center = {0, 0.15, 0.95}, tint = true },
			{ name = "Fluff", center = {0, 0.335, 1.1095} },
			{ name = "Head", center = {-0, -0.68, 1.58}, group = "Head", pivot = {0, -0.4, 1.32} },
			{ name = "Ears", center = {-0, -0.5539, 2.5805}, group = "Ears", pivot = {0, -0.55, 1.98} },
			{ name = "FrontLeg", center = {-0.42, -0.55, 0.21}, group = "FrontLeg", pivot = {-0.42, -0.55, 0.3486} },
			{ name = "BackLeg", center = {-0.42, 0.55, 0.21}, group = "BackLeg", pivot = {-0.42, 0.55, 0.3486} },
			{ name = "FrontLeg", center = {0.42, -0.55, 0.21}, group = "FrontLeg", pivot = {0.42, -0.55, 0.3486} },
			{ name = "BackLeg", center = {0.42, 0.55, 0.21}, group = "BackLeg", pivot = {0.42, 0.55, 0.3486} },
			{ name = "Tail", center = {0, 1.12, 1}, group = "Tail", pivot = {0, 0.9, 1} },
			{ name = "GreyChip", center = {0, -1.3, 0.24}, work = true, group = "GreyChip", pivot = {0, -1.3, 0.18} },
			{ name = "AccentTrim", center = {0, -0.755, 1.05} },
			{ name = "EarsGlow", center = {0, -0.4066, 3.32}, neon = "FFC428", group = "Ears", pivot = {0, -0.55, 1.98} },
		},
	},
	["pets_emberNewt"] = {
		id = 126296594233394, blender = "pets/emberNewt", triangles = 3028,
		parts = {
			{ name = "Body", center = {-0, 0.2, 0.62}, tint = true },
			{ name = "Belly", center = {-0, -0.05, 0.4} },
			{ name = "Spots", center = {-0.015, 0.35, 0.952} },
			{ name = "Head", center = {-0, -1.065, 0.86}, group = "Head", pivot = {0, -0.62, 0.7} },
			{ name = "FrontLeg", center = {-0.5865, -0.5404, 0.346}, group = "FrontLeg", pivot = {-0.4, -0.5, 0.55} },
			{ name = "FrontToeGlow", center = {-0.82, -0.77, 0.06}, neon = "FA8028", group = "FrontLeg", pivot = {-0.4, -0.5, 0.55} },
			{ name = "BackLeg", center = {-0.5865, 0.7596, 0.346}, group = "BackLeg", pivot = {-0.4, 0.8, 0.55} },
			{ name = "BackToeGlow", center = {-0.82, 0.53, 0.06}, neon = "FA8028", group = "BackLeg", pivot = {-0.4, 0.8, 0.55} },
			{ name = "FrontLeg", center = {0.5865, -0.5404, 0.346}, group = "FrontLeg", pivot = {0.4, -0.5, 0.55} },
			{ name = "FrontToeGlow", center = {0.82, -0.77, 0.06}, neon = "FA8028", group = "FrontLeg", pivot = {0.4, -0.5, 0.55} },
			{ name = "BackLeg", center = {0.5865, 0.7596, 0.346}, group = "BackLeg", pivot = {0.4, 0.8, 0.55} },
			{ name = "BackToeGlow", center = {0.82, 0.53, 0.06}, neon = "FA8028", group = "BackLeg", pivot = {0.4, 0.8, 0.55} },
			{ name = "Tail", center = {0.1785, 1.7192, 0.5585}, group = "Tail", pivot = {0, 1, 0.6} },
			{ name = "TailGlow", center = {0.66, 2.4567, 0.4}, neon = "FA8028", group = "Tail", pivot = {0, 1, 0.6} },
			{ name = "HeatWave", center = {-0.008, -1.6999, 1.65}, neon = "FFD678", work = true, group = "HeatWave", pivot = {0, -1.55, 1.35} },
		},
	},
	["pets_emberNewt_lv10"] = {
		id = 99198938755482, blender = "pets/emberNewt_lv10", triangles = 3208,
		parts = {
			{ name = "Body", center = {-0, 0.2, 0.62}, tint = true },
			{ name = "Belly", center = {-0, -0.05, 0.4} },
			{ name = "Spots", center = {-0.015, 0.35, 0.952} },
			{ name = "Head", center = {-0, -1.065, 1.02}, group = "Head", pivot = {0, -0.62, 0.7} },
			{ name = "FrontLeg", center = {-0.5865, -0.5404, 0.346}, group = "FrontLeg", pivot = {-0.4, -0.5, 0.55} },
			{ name = "FrontToeGlow", center = {-0.82, -0.77, 0.06}, neon = "FA8028", group = "FrontLeg", pivot = {-0.4, -0.5, 0.55} },
			{ name = "BackLeg", center = {-0.5865, 0.7596, 0.346}, group = "BackLeg", pivot = {-0.4, 0.8, 0.55} },
			{ name = "BackToeGlow", center = {-0.82, 0.53, 0.06}, neon = "FA8028", group = "BackLeg", pivot = {-0.4, 0.8, 0.55} },
			{ name = "FrontLeg", center = {0.5865, -0.5404, 0.346}, group = "FrontLeg", pivot = {0.4, -0.5, 0.55} },
			{ name = "FrontToeGlow", center = {0.82, -0.77, 0.06}, neon = "FA8028", group = "FrontLeg", pivot = {0.4, -0.5, 0.55} },
			{ name = "BackLeg", center = {0.5865, 0.7596, 0.346}, group = "BackLeg", pivot = {0.4, 0.8, 0.55} },
			{ name = "BackToeGlow", center = {0.82, 0.53, 0.06}, neon = "FA8028", group = "BackLeg", pivot = {0.4, 0.8, 0.55} },
			{ name = "Tail", center = {0.1785, 1.7192, 0.5585}, group = "Tail", pivot = {0, 1, 0.6} },
			{ name = "TailGlow", center = {0.66, 2.4567, 0.4}, neon = "FA8028", group = "Tail", pivot = {0, 1, 0.6} },
			{ name = "HeatWave", center = {-0.008, -1.6999, 1.65}, neon = "FFD678", work = true, group = "HeatWave", pivot = {0, -1.55, 1.35} },
			{ name = "SpineGlow", center = {0, 0.2405, 1.0125}, neon = "FA8028" },
			{ name = "AccentTrim", center = {0, -0.55, 0.66} },
		},
	},
	["pets_geodeTurtle"] = {
		id = 97518557788593, blender = "pets/geodeTurtle", triangles = 1974,
		parts = {
			{ name = "Body", center = {0, 0.15, 0.92}, tint = true },
			{ name = "Rim", center = {0, 0.1552, 0.9087} },
			{ name = "Geode", center = {0, 0.2, 1.625} },
			{ name = "ShellGlow", center = {0.014, 0.2954, 1.9463}, neon = "A462F6" },
			{ name = "Head", center = {-0, -1.292, 0.9321}, group = "Head", pivot = {0, -0.8, 0.72} },
			{ name = "FrontLeg", center = {-0.88, -0.7, 0.275}, group = "FrontLeg", pivot = {-0.88, -0.7, 0.4565} },
			{ name = "BackLeg", center = {-0.88, 0.95, 0.275}, group = "BackLeg", pivot = {-0.88, 0.95, 0.4565} },
			{ name = "FrontLeg", center = {0.88, -0.7, 0.275}, group = "FrontLeg", pivot = {0.88, -0.7, 0.4565} },
			{ name = "BackLeg", center = {0.88, 0.95, 0.275}, group = "BackLeg", pivot = {0.88, 0.95, 0.4565} },
			{ name = "Tail", center = {0, 1.4999, 0.4907}, group = "Tail", pivot = {0, 1.25, 0.5} },
			{ name = "OreChunk", center = {0, 0.2, 2.05}, work = true, group = "OreChunk", pivot = {0, 0.2, 2.05} },
		},
	},
	["pets_geodeTurtle_lv10"] = {
		id = 124462582670639, blender = "pets/geodeTurtle_lv10", triangles = 2254,
		parts = {
			{ name = "Body", center = {0, 0.15, 0.92}, tint = true },
			{ name = "Rim", center = {0, 0.1552, 0.9087} },
			{ name = "Geode", center = {0, 0.2, 1.625} },
			{ name = "ShellGlow", center = {0.014, 0.2954, 2.1151}, neon = "A462F6" },
			{ name = "Head", center = {-0, -1.292, 0.9321}, group = "Head", pivot = {0, -0.8, 0.72} },
			{ name = "FrontLeg", center = {-0.88, -0.7, 0.275}, group = "FrontLeg", pivot = {-0.88, -0.7, 0.4565} },
			{ name = "BackLeg", center = {-0.88, 0.95, 0.275}, group = "BackLeg", pivot = {-0.88, 0.95, 0.4565} },
			{ name = "FrontLeg", center = {0.88, -0.7, 0.275}, group = "FrontLeg", pivot = {0.88, -0.7, 0.4565} },
			{ name = "BackLeg", center = {0.88, 0.95, 0.275}, group = "BackLeg", pivot = {0.88, 0.95, 0.4565} },
			{ name = "Tail", center = {0, 1.4999, 0.4907}, group = "Tail", pivot = {0, 1.25, 0.5} },
			{ name = "OreChunk", center = {0, 0.2, 2.05}, work = true, group = "OreChunk", pivot = {0, 0.2, 2.05} },
			{ name = "AccentTrim", center = {0, 0.15, 1.275} },
		},
	},
	["pets_cometFox"] = {
		id = 78961050891777, blender = "pets/cometFox", triangles = 2464,
		parts = {
			{ name = "Body", center = {-0, 0.2, 1.05}, tint = true },
			{ name = "Chest", center = {-0, -0.45, 0.98} },
			{ name = "Head", center = {0, -0.855, 1.78}, group = "Head", pivot = {0, -0.45, 1.5} },
			{ name = "Ears", center = {0, -0.6649, 2.4991}, group = "Ears", pivot = {0, -0.7, 2.1} },
			{ name = "FrontLeg", center = {-0.36, -0.489, 0.39}, group = "FrontLeg", pivot = {-0.36, -0.45, 0.6474} },
			{ name = "BackLeg", center = {-0.36, 0.741, 0.39}, group = "BackLeg", pivot = {-0.36, 0.78, 0.6474} },
			{ name = "FrontLeg", center = {0.36, -0.489, 0.39}, group = "FrontLeg", pivot = {0.36, -0.45, 0.6474} },
			{ name = "BackLeg", center = {0.36, 0.741, 0.39}, group = "BackLeg", pivot = {0.36, 0.78, 0.6474} },
			{ name = "Tail", center = {-0, 1.8136, 1.877}, group = "Tail", pivot = {0, 0.88, 1.18} },
			{ name = "TailGlow", center = {0.01, 2.365, 2.175}, neon = "FCFCFF", group = "Tail", pivot = {0, 0.88, 1.18} },
			{ name = "SparkLink", center = {0.016, -1.5891, 0.8701}, neon = "6DEFFF", work = true, group = "SparkLink", pivot = {0, -1.2, 0.54} },
		},
	},
	["pets_cometFox_lv10"] = {
		id = 82327246500826, blender = "pets/cometFox_lv10", triangles = 2670,
		parts = {
			{ name = "Body", center = {-0, 0.2, 1.05}, tint = true },
			{ name = "Chest", center = {-0, -0.45, 0.98} },
			{ name = "Head", center = {0, -0.855, 1.78}, group = "Head", pivot = {0, -0.45, 1.5} },
			{ name = "Ears", center = {0, -0.6649, 2.4991}, group = "Ears", pivot = {0, -0.7, 2.1} },
			{ name = "FrontLeg", center = {-0.36, -0.489, 0.39}, group = "FrontLeg", pivot = {-0.36, -0.45, 0.6474} },
			{ name = "BackLeg", center = {-0.36, 0.741, 0.39}, group = "BackLeg", pivot = {-0.36, 0.78, 0.6474} },
			{ name = "FrontLeg", center = {0.36, -0.489, 0.39}, group = "FrontLeg", pivot = {0.36, -0.45, 0.6474} },
			{ name = "BackLeg", center = {0.36, 0.741, 0.39}, group = "BackLeg", pivot = {0.36, 0.78, 0.6474} },
			{ name = "Tail", center = {-0, 1.8136, 1.877}, group = "Tail", pivot = {0, 0.88, 1.18} },
			{ name = "TailGlow", center = {0, 2.46, 2.285}, neon = "FCFCFF", group = "Tail", pivot = {0, 0.88, 1.18} },
			{ name = "SparkLink", center = {0.016, -1.5891, 0.8701}, neon = "6DEFFF", work = true, group = "SparkLink", pivot = {0, -1.2, 0.54} },
			{ name = "AccentTrim", center = {0, -0.42, 1.38} },
			{ name = "HeadGlow", center = {0, -1.181, 2.3602}, neon = "FFC428", group = "Head", pivot = {0, -0.45, 1.5} },
		},
	},
	["pets_nebulaJelly"] = {
		id = 105124463655032, blender = "pets/nebulaJelly", triangles = 2744,
		parts = {
			{ name = "Body", center = {0, 0, 0.35}, tint = true },
			{ name = "Rim", center = {0, 0, -0.3} },
			{ name = "Core", center = {-0, -0, -0.3}, neon = "FA78C8" },
			{ name = "Speckles", center = {0.0189, -0.0933, 0.6041}, neon = "FCFCFF" },
			{ name = "Face", center = {0, -0.883, 0.1212} },
			{ name = "Tail", center = {-0.0073, 0.0336, -1.0697}, group = "Tail", pivot = {0, 0, -0.3} },
		},
	},
	["pets_nebulaJelly_lv10"] = {
		id = 71646013780197, blender = "pets/nebulaJelly_lv10", triangles = 3056,
		parts = {
			{ name = "Body", center = {0, 0, 0.35}, tint = true },
			{ name = "Rim", center = {0, 0, -0.3} },
			{ name = "Core", center = {-0, -0, -0.3}, neon = "FA78C8" },
			{ name = "Speckles", center = {0.0189, -0.0933, 0.6041}, neon = "FCFCFF" },
			{ name = "Face", center = {0, -0.883, 0.1212} },
			{ name = "Tail", center = {-0.0073, 0.0336, -1.0697}, group = "Tail", pivot = {0, 0, -0.3} },
			{ name = "AccentTrim", center = {0, 0, -0.18} },
			{ name = "Halo", center = {0, 0, 1.45}, neon = "FFC95C", group = "Halo", pivot = {0, 0, 1.45} },
			{ name = "CrownGlow", center = {0, -0.0385, 1.2}, neon = "FFE66E" },
		},
	},
	["pets_magmaCrab"] = {
		id = 95277551270854, blender = "pets/magmaCrab", triangles = 1708,
		parts = {
			{ name = "Body", center = {-0, 0.1, 0.85}, tint = true },
			{ name = "Belly", center = {-0, 0.05, 0.58} },
			{ name = "Shell", center = {0, 0.085, 1.22} },
			{ name = "ShellGlow", center = {0.0148, 0.0678, 1.3007}, neon = "FA8028" },
			{ name = "Head", center = {0, -0.675, 1.322}, group = "Head", pivot = {0, -0.45, 1.05} },
			{ name = "Claw", center = {-1.2192, -1.1531, 1}, group = "FrontLeg", pivot = {-0.85, -0.4, 0.85} },
			{ name = "BackLeg", center = {-1.1926, 0.2777, 0.3954}, group = "BackLeg", pivot = {-0.85, 0.25, 0.7} },
			{ name = "Claw", center = {1.2192, -1.1531, 1}, group = "FrontLeg", pivot = {0.85, -0.4, 0.85} },
			{ name = "BackLeg", center = {1.1926, 0.2777, 0.3954}, group = "BackLeg", pivot = {0.85, 0.25, 0.7} },
			{ name = "GreyChip", center = {0, -1.5, 0.26}, work = true, group = "GreyChip", pivot = {0, -1.5, 0.2} },
		},
	},
	["pets_magmaCrab_lv10"] = {
		id = 136729751643506, blender = "pets/magmaCrab_lv10", triangles = 1796,
		parts = {
			{ name = "Body", center = {-0, 0.1, 0.85}, tint = true },
			{ name = "Belly", center = {-0, 0.05, 0.58} },
			{ name = "Shell", center = {0, 0.085, 1.22} },
			{ name = "ShellGlow", center = {0.0148, 0.0678, 1.3007}, neon = "FA8028" },
			{ name = "Head", center = {0, -0.675, 1.322}, group = "Head", pivot = {0, -0.45, 1.05} },
			{ name = "Claw", center = {-1.2192, -1.1531, 1}, group = "FrontLeg", pivot = {-0.85, -0.4, 0.85} },
			{ name = "BackLeg", center = {-1.1926, 0.2777, 0.3954}, group = "BackLeg", pivot = {-0.85, 0.25, 0.7} },
			{ name = "Claw", center = {1.2192, -1.1531, 1}, group = "FrontLeg", pivot = {0.85, -0.4, 0.85} },
			{ name = "BackLeg", center = {1.1926, 0.2777, 0.3954}, group = "BackLeg", pivot = {0.85, 0.25, 0.7} },
			{ name = "GreyChip", center = {0, -1.5, 0.26}, work = true, group = "GreyChip", pivot = {0, -1.5, 0.2} },
			{ name = "AccentTrim", center = {0, -0.2963, 1.5811} },
			{ name = "ClawGlow", center = {-1.3016, -1.1775, 1.2612}, neon = "FA8028", group = "FrontLeg", pivot = {-0.85, -0.4, 0.85} },
			{ name = "ClawGlow", center = {1.3016, -1.1775, 1.2612}, neon = "FA8028", group = "FrontLeg", pivot = {0.85, -0.4, 0.85} },
		},
	},
	["pets_frostYeti"] = {
		id = 100094685559993, blender = "pets/frostYeti", triangles = 2488,
		parts = {
			{ name = "Body", center = {-0, 0.1, 1.4}, tint = true },
			{ name = "Fur", center = {0, -0.0875, 2.2169} },
			{ name = "Head", center = {0, -0.603, 2.1008}, group = "Head", pivot = {0, -0.4, 1.65} },
			{ name = "FrontLeg", center = {-1.02, -0.135, 1.16}, group = "FrontLeg", pivot = {-0.86, -0.08, 1.85} },
			{ name = "BackLeg", center = {-0.5, -0.04, 0.33}, group = "BackLeg", pivot = {-0.5, 0.05, 0.62} },
			{ name = "FrontLeg", center = {1.02, -0.135, 1.16}, group = "FrontLeg", pivot = {0.86, -0.08, 1.85} },
			{ name = "BackLeg", center = {0.5, -0.04, 0.33}, group = "BackLeg", pivot = {0.5, 0.05, 0.62} },
			{ name = "Pannier", center = {0, 0.5183, 1.7623} },
			{ name = "OreChunk", center = {0, 1.05, 2.55}, work = true, group = "OreChunk", pivot = {0, 1.05, 2.55} },
		},
	},
	["pets_frostYeti_lv10"] = {
		id = 134984915323564, blender = "pets/frostYeti_lv10", triangles = 2944,
		parts = {
			{ name = "Body", center = {-0, 0.1, 1.4}, tint = true },
			{ name = "Fur", center = {0, -0.0875, 2.2169} },
			{ name = "Head", center = {0, -0.603, 2.1008}, group = "Head", pivot = {0, -0.4, 1.65} },
			{ name = "FrontLeg", center = {-1.05, -0.1406, 1.16}, group = "FrontLeg", pivot = {-0.86, -0.08, 1.85} },
			{ name = "BackLeg", center = {-0.5, -0.04, 0.33}, group = "BackLeg", pivot = {-0.5, 0.05, 0.62} },
			{ name = "FrontLeg", center = {1.05, -0.1406, 1.16}, group = "FrontLeg", pivot = {0.86, -0.08, 1.85} },
			{ name = "BackLeg", center = {0.5, -0.04, 0.33}, group = "BackLeg", pivot = {0.5, 0.05, 0.62} },
			{ name = "Pannier", center = {0, 0.5183, 1.7623} },
			{ name = "OreChunk", center = {0, 1.05, 2.55}, work = true, group = "OreChunk", pivot = {0, 1.05, 2.55} },
			{ name = "IceGlow", center = {-0.0404, 1.446, 1.7321}, neon = "6DEFFF" },
			{ name = "AccentTrim", center = {0, -0.42, 1.85} },
		},
	},
	["pets_quartzKitsune"] = {
		id = 91287643666070, blender = "pets/quartzKitsune", triangles = 2200,
		parts = {
			{ name = "Body", center = {-0, 0.2, 1.05}, tint = true },
			{ name = "Chest", center = {-0, -0.45, 0.98} },
			{ name = "Head", center = {0, -0.845, 1.78}, group = "Head", pivot = {0, -0.45, 1.5} },
			{ name = "Ears", center = {-0, -0.6645, 2.4796}, group = "Ears", pivot = {0, -0.7, 2.1} },
			{ name = "EarsGlow", center = {0, -0.6133, 2.96}, neon = "FA78C8", group = "Ears", pivot = {0, -0.7, 2.1} },
			{ name = "HeadGlow", center = {0, -1.1, 2.2199}, neon = "FA78C8", group = "Head", pivot = {0, -0.45, 1.5} },
			{ name = "FrontLeg", center = {-0.36, -0.489, 0.39}, group = "FrontLeg", pivot = {-0.36, -0.45, 0.6474} },
			{ name = "BackLeg", center = {-0.36, 0.741, 0.39}, group = "BackLeg", pivot = {-0.36, 0.78, 0.6474} },
			{ name = "FrontLeg", center = {0.36, -0.489, 0.39}, group = "FrontLeg", pivot = {0.36, -0.45, 0.6474} },
			{ name = "BackLeg", center = {0.36, 0.741, 0.39}, group = "BackLeg", pivot = {0.36, 0.78, 0.6474} },
			{ name = "Tail", center = {0, 1.3605, 1.8088}, group = "Tail", pivot = {0, 0.95, 1.18} },
			{ name = "TailGlow", center = {-0, 1.75, 2.6495}, neon = "FA78C8", group = "Tail", pivot = {0, 0.95, 1.18} },
			{ name = "TargetShard", center = {-0, -1.6095, 0.35}, neon = "FA78C8", work = true, group = "TargetShard", pivot = {0, -1.62, 0.27} },
		},
	},
	["pets_quartzKitsune_lv10"] = {
		id = 92363254902867, blender = "pets/quartzKitsune_lv10", triangles = 2908,
		parts = {
			{ name = "Body", center = {-0, 0.2, 1.05}, tint = true },
			{ name = "Chest", center = {-0, -0.45, 0.98} },
			{ name = "Head", center = {0, -0.845, 1.78}, group = "Head", pivot = {0, -0.45, 1.5} },
			{ name = "Ears", center = {-0, -0.6645, 2.4796}, group = "Ears", pivot = {0, -0.7, 2.1} },
			{ name = "EarsGlow", center = {0, -0.6133, 2.96}, neon = "FA78C8", group = "Ears", pivot = {0, -0.7, 2.1} },
			{ name = "HeadGlow", center = {0, -1.1, 2.2199}, neon = "FA78C8", group = "Head", pivot = {0, -0.45, 1.5} },
			{ name = "FrontLeg", center = {-0.36, -0.489, 0.39}, group = "FrontLeg", pivot = {-0.36, -0.45, 0.6474} },
			{ name = "BackLeg", center = {-0.36, 0.741, 0.39}, group = "BackLeg", pivot = {-0.36, 0.78, 0.6474} },
			{ name = "FrontLeg", center = {0.36, -0.489, 0.39}, group = "FrontLeg", pivot = {0.36, -0.45, 0.6474} },
			{ name = "BackLeg", center = {0.36, 0.741, 0.39}, group = "BackLeg", pivot = {0.36, 0.78, 0.6474} },
			{ name = "Tail", center = {0, 1.3605, 1.8088}, group = "Tail", pivot = {0, 0.95, 1.18} },
			{ name = "TailGlow", center = {-0, 1.75, 2.6495}, neon = "FA78C8", group = "Tail", pivot = {0, 0.95, 1.18} },
			{ name = "TargetShard", center = {-0, -1.6095, 0.35}, neon = "FA78C8", work = true, group = "TargetShard", pivot = {0, -1.62, 0.27} },
			{ name = "AccentTrim", center = {0, -0.42, 1.38} },
			{ name = "CollarGlow", center = {-0, -0.92, 1.12}, neon = "FA78C8" },
		},
	},
	["pets_galaxyGriffin"] = {
		id = 101500979009101, blender = "pets/galaxyGriffin", triangles = 3402,
		parts = {
			{ name = "Body", center = {-0, 0.15, -0.05}, tint = true },
			{ name = "Chest", center = {-0, -0.42, 0.02} },
			{ name = "Head", center = {-0, -0.63, 0.92}, group = "Head", pivot = {0, -0.3, 0.3} },
			{ name = "HeadGlow", center = {0.035, -0.5, 1.065}, neon = "FCFCFF", group = "Head", pivot = {0, -0.3, 0.3} },
			{ name = "Stars", center = {-0, 0.375, -0.05}, neon = "FFC428" },
			{ name = "WingsLeft", center = {-1.1, 0.178, 0.1547}, group = "WingsLeft", pivot = {-0.58, 0.08, 0.32} },
			{ name = "WingsLeftGlow", center = {-1.175, 0.14, 0.25}, neon = "FCFCFF", group = "WingsLeft", pivot = {-0.58, 0.08, 0.32} },
			{ name = "Feet", center = {0, -0.4341, -0.7191} },
			{ name = "BackLeg", center = {-0.42, 0.55, -0.55}, group = "BackLeg", pivot = {-0.42, 0.55, -0.35} },
			{ name = "WingsRight", center = {1.1, 0.178, 0.1547}, group = "WingsRight", pivot = {0.58, 0.08, 0.32} },
			{ name = "WingsRightGlow", center = {1.175, 0.14, 0.25}, neon = "FCFCFF", group = "WingsRight", pivot = {0.58, 0.08, 0.32} },
			{ name = "BackLeg", center = {0.42, 0.55, -0.55}, group = "BackLeg", pivot = {0.42, 0.55, -0.35} },
			{ name = "Tail", center = {-0, 1.449, 0.0004}, group = "Tail", pivot = {0, 0.8, -0.2} },
			{ name = "TailGlow", center = {-0, 1.95, 0.48}, neon = "FCFCFF", group = "Tail", pivot = {0, 0.8, -0.2} },
		},
	},
	["pets_galaxyGriffin_lv10"] = {
		id = 82663898071357, blender = "pets/galaxyGriffin_lv10", triangles = 3490,
		parts = {
			{ name = "Body", center = {-0, 0.15, -0.05}, tint = true },
			{ name = "Chest", center = {-0, -0.42, 0.02} },
			{ name = "Head", center = {-0, -0.63, 0.92}, group = "Head", pivot = {0, -0.3, 0.3} },
			{ name = "HeadGlow", center = {0.035, -0.5, 1.065}, neon = "FCFCFF", group = "Head", pivot = {0, -0.3, 0.3} },
			{ name = "Stars", center = {-0, 0.375, -0.05}, neon = "FFC428" },
			{ name = "WingsLeft", center = {-1.2, 0.178, 0.1564}, group = "WingsLeft", pivot = {-0.58, 0.08, 0.32} },
			{ name = "WingsLeftGlow", center = {-1.175, 0.14, 0.25}, neon = "FCFCFF", group = "WingsLeft", pivot = {-0.58, 0.08, 0.32} },
			{ name = "Feet", center = {0, -0.4341, -0.7191} },
			{ name = "BackLeg", center = {-0.42, 0.55, -0.55}, group = "BackLeg", pivot = {-0.42, 0.55, -0.35} },
			{ name = "WingsRight", center = {1.2, 0.178, 0.1564}, group = "WingsRight", pivot = {0.58, 0.08, 0.32} },
			{ name = "WingsRightGlow", center = {1.175, 0.14, 0.25}, neon = "FCFCFF", group = "WingsRight", pivot = {0.58, 0.08, 0.32} },
			{ name = "BackLeg", center = {0.42, 0.55, -0.55}, group = "BackLeg", pivot = {0.42, 0.55, -0.35} },
			{ name = "Tail", center = {-0, 1.449, 0.0004}, group = "Tail", pivot = {0, 0.8, -0.2} },
			{ name = "TailGlow", center = {-0, 1.95, 0.48}, neon = "FCFCFF", group = "Tail", pivot = {0, 0.8, -0.2} },
			{ name = "HeadTrim", center = {0, -0.6051, 1.3235}, group = "Head", pivot = {0, -0.3, 0.3} },
			{ name = "AccentGlow", center = {0, -0.5955, 0.2226}, neon = "FCFCFF" },
		},
	},
	["pets_voidLeviathan"] = {
		id = 74528759358046, blender = "pets/voidLeviathan", triangles = 3090,
		parts = {
			{ name = "Body", center = {-0, -0.35, 0}, tint = true },
			{ name = "Belly", center = {-0, -0.4, -0.3} },
			{ name = "BodyGlow", center = {0, -0.35, 0}, neon = "6DEFFF" },
			{ name = "Fin", center = {0, -0.55, 0.725} },
			{ name = "Tail", center = {0.2, 0.2, 0.2598}, group = "Tail", pivot = {0.2, -0.05, 0.15} },
			{ name = "TailGlow", center = {0.2, 0.2, 0.15}, neon = "6DEFFF", group = "Tail", pivot = {0.2, -0.05, 0.15} },
			{ name = "Tail", center = {0.12, 0.7, 0.5188}, group = "Tail", pivot = {0.12, 0.45, 0.42} },
			{ name = "Tail", center = {0.12, 0.7, 0.42}, neon = "6DEFFF", group = "Tail", pivot = {0.12, 0.45, 0.42} },
			{ name = "Tail", center = {-0.14, 1.12, 0.7478}, group = "Tail", pivot = {-0.14, 0.87, 0.66} },
			{ name = "Tail", center = {-0.14, 1.12, 0.66}, neon = "6DEFFF", group = "Tail", pivot = {-0.14, 0.87, 0.66} },
			{ name = "Tail", center = {-0.26, 1.5, 1.0268}, group = "Tail", pivot = {-0.26, 1.25, 0.95} },
			{ name = "Tail", center = {-0.26, 1.5, 0.95}, neon = "6DEFFF", group = "Tail", pivot = {-0.26, 1.25, 0.95} },
			{ name = "Tail", center = {-0.12, 1.819, 1.3158}, group = "Tail", pivot = {-0.12, 1.57, 1.25} },
			{ name = "Tail", center = {-0.12, 1.82, 1.25}, neon = "6DEFFF", group = "Tail", pivot = {-0.12, 1.57, 1.25} },
			{ name = "Tail", center = {0.14, 2.315, 1.55}, group = "Tail", pivot = {0.14, 1.8, 1.55} },
			{ name = "Tail", center = {0.14, 2.3375, 1.55}, neon = "6DEFFF", group = "Tail", pivot = {0.14, 1.8, 1.55} },
			{ name = "Head", center = {-0, -1.089, 0.295}, group = "Head", pivot = {0, -0.65, 0.1} },
			{ name = "HeadGlow", center = {0, -1.6174, 0.047}, neon = "6DEFFF", group = "Head", pivot = {0, -0.65, 0.1} },
			{ name = "FinGlow", center = {0, -0.7302, 0.8137}, neon = "6DEFFF" },
			{ name = "WingsLeft", center = {-0.735, -0.075, -0.3552}, group = "WingsLeft", pivot = {-0.42, -0.3, -0.15} },
			{ name = "WingsRight", center = {0.735, -0.075, -0.3552}, group = "WingsRight", pivot = {0.42, -0.3, -0.15} },
		},
	},
	["pets_voidLeviathan_lv10"] = {
		id = 128895591888255, blender = "pets/voidLeviathan_lv10", triangles = 3450,
		parts = {
			{ name = "Body", center = {-0, -0.35, 0}, tint = true },
			{ name = "Belly", center = {-0, -0.4, -0.3} },
			{ name = "BodyGlow", center = {0, -0.35, 0}, neon = "6DEFFF" },
			{ name = "Fin", center = {0, -0.55, 0.725} },
			{ name = "Tail", center = {0.2, 0.2, 0.2598}, group = "Tail", pivot = {0.2, -0.05, 0.15} },
			{ name = "TailGlow", center = {0.2, 0.2, 0.15}, neon = "6DEFFF", group = "Tail", pivot = {0.2, -0.05, 0.15} },
			{ name = "Tail", center = {0.12, 0.7, 0.5188}, group = "Tail", pivot = {0.12, 0.45, 0.42} },
			{ name = "Tail", center = {0.12, 0.7, 0.42}, neon = "6DEFFF", group = "Tail", pivot = {0.12, 0.45, 0.42} },
			{ name = "Tail", center = {-0.14, 1.12, 0.7478}, group = "Tail", pivot = {-0.14, 0.87, 0.66} },
			{ name = "Tail", center = {-0.14, 1.12, 0.66}, neon = "6DEFFF", group = "Tail", pivot = {-0.14, 0.87, 0.66} },
			{ name = "Tail", center = {-0.26, 1.5, 1.0268}, group = "Tail", pivot = {-0.26, 1.25, 0.95} },
			{ name = "Tail", center = {-0.26, 1.5, 0.95}, neon = "6DEFFF", group = "Tail", pivot = {-0.26, 1.25, 0.95} },
			{ name = "Tail", center = {-0.12, 1.819, 1.3158}, group = "Tail", pivot = {-0.12, 1.57, 1.25} },
			{ name = "Tail", center = {-0.12, 1.82, 1.25}, neon = "6DEFFF", group = "Tail", pivot = {-0.12, 1.57, 1.25} },
			{ name = "Tail", center = {0.14, 2.315, 1.55}, group = "Tail", pivot = {0.14, 1.8, 1.55} },
			{ name = "Tail", center = {0.14, 2.3375, 1.55}, neon = "6DEFFF", group = "Tail", pivot = {0.14, 1.8, 1.55} },
			{ name = "Head", center = {-0, -1.089, 0.295}, group = "Head", pivot = {0, -0.65, 0.1} },
			{ name = "HeadGlow", center = {0, -1.6174, 0.047}, neon = "6DEFFF", group = "Head", pivot = {0, -0.65, 0.1} },
			{ name = "FinGlow", center = {0, -0.7302, 0.8137}, neon = "6DEFFF" },
			{ name = "WingsLeft", center = {-0.735, -0.075, -0.3552}, group = "WingsLeft", pivot = {-0.42, -0.3, -0.15} },
			{ name = "WingsRight", center = {0.735, -0.075, -0.3552}, group = "WingsRight", pivot = {0.42, -0.3, -0.15} },
			{ name = "HeadTrim", center = {-0, -1.0517, 0.7544}, group = "Head", pivot = {0, -0.65, 0.1} },
			{ name = "AccentTrim", center = {0.07, 0.325, 0.1564} },
		},
	},
	["eggs_egg_magma"] = {
		id = 117254654570102, blender = "eggs/egg_magma", triangles = 716,
		parts = {
			{ name = "Shell", center = {0, 0, 1.5} },
			{ name = "Pattern", center = {0.0306, 0.0036, 1.53} },
			{ name = "Glow", center = {0.0101, -0.0316, 1.4389}, neon = "FFB030" },
		},
	},
	["eggs_egg_void"] = {
		id = 91891762221344, blender = "eggs/egg_void", triangles = 660,
		parts = {
			{ name = "Shell", center = {0, 0, 1.45} },
			{ name = "Pattern", center = {0, 0, 1.508} },
			{ name = "Glow", center = {0, 0, 1.508}, neon = "6DEFFF" },
			{ name = "Stars", center = {-0.0098, -0.1388, 1.537}, neon = "FCFCFF" },
		},
	},
}

local PETS = {
	{ id = "dustBunny", name = "Dust Bunny", rarity = "common", color = "#D6C8B2", flying = false, style = "dig" },
	{ id = "emberNewt", name = "Ember Newt", rarity = "common", color = "#FF7846", flying = false, style = "dig" },
	{ id = "geodeTurtle", name = "Geode Turtle", rarity = "uncommon", color = "#966EC8", flying = false, style = "haul" },
	{ id = "cometFox", name = "Comet Fox", rarity = "rare", color = "#7FB6FF", flying = false, style = "flash" },
	{ id = "nebulaJelly", name = "Nebula Jelly", rarity = "rare", color = "#C882FF", flying = true, style = "chirp" },
	{ id = "magmaCrab", name = "Magma Crab", rarity = "rare", color = "#E65028", flying = false, style = "dig" },
	{ id = "frostYeti", name = "Frost Yeti", rarity = "epic", color = "#BEE6FF", flying = false, style = "haul" },
	{ id = "quartzKitsune", name = "Quartz Kitsune", rarity = "epic", color = "#FFBEE6", flying = false, style = "flash" },
	{ id = "galaxyGriffin", name = "Galaxy Griffin", rarity = "legendary", color = "#5A50C8", flying = true, style = "dive" },
	{ id = "voidLeviathan", name = "Void Leviathan", rarity = "legendary", color = "#3C286E", flying = true, style = "dive" },
}

local EGGS = {
	{ id = "magmaEgg", stem = "eggs_egg_magma", art = "egg_magma" },
	{ id = "voidEgg", stem = "eggs_egg_void", art = "egg_void" },
}

local ORIENTATION = 2

-- Blender -> Roblox as a rotation: Vector3 r = M:VectorToWorldSpace(blender)
local function rot(r0, r1, r2): CFrame
	return CFrame.new(0, 0, 0, r0[1], r0[2], r0[3], r1[1], r1[2], r1[3], r2[1], r2[2], r2[3])
end
local TARGET = rot({ -1, 0, 0 }, { 0, 0, 1 }, { 0, 1, 0 }) -- (x, y, z) -> (-x, z, y)
local CANDIDATES = { -- Blender Z up -> Roblox +Y, four yaw turns
	TARGET,
	rot({ 1, 0, 0 }, { 0, 0, 1 }, { 0, -1, 0 }), -- (x, z, -y)
	rot({ 0, 1, 0 }, { 0, 0, 1 }, { 1, 0, 0 }), -- (y, z, x)
	rot({ 0, -1, 0 }, { 0, 0, 1 }, { -1, 0, 0 }), -- (-y, z, -x)
}

local function vec(t): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

local function folder(parent: Instance, name: string): Instance
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end

local function replace(parent: Instance, child: Instance)
	local old = parent:FindFirstChild(child.Name)
	if old then old:Destroy() end
	child.Parent = parent
end

local notes = {}

-- Loads one uploaded asset as a Model at the origin: Blender origin at (0, 0, 0), front toward -Z.
local function load(stem: string): Model
	local info = assert(DATA[stem], stem)
	local root = game:GetObjects("rbxassetid://" .. info.id)[1]
	local found = {}
	for _, d in root:GetDescendants() do
		if d:IsA("MeshPart") then
			local index = tonumber(d.Name:match("#(%d+)$"))
			if index then found[index + 1] = d end
		end
	end
	local model = Instance.new("Model")
	model.Name = stem
	local parts = {}
	for i, o in info.parts do
		local part = found[i]
		assert(part, ("%s: no mesh #%d (%s) in asset %d"):format(stem, i - 1, o.name, info.id))
		parts[i] = part
		part.Parent = model
	end
	root:Destroy()

	-- fit the upload's orientation and scale from the part centres
	local n = #parts
	local rc, bc = Vector3.zero, Vector3.zero
	for i, o in info.parts do
		rc += parts[i].Position / n
		bc += vec(o.center) / n
	end
	local best, bestErr, bestScale = TARGET, math.huge, 1
	for _, m in CANDIDATES do
		local num, den = 0, 0
		for i, o in info.parts do
			local p = m:VectorToWorldSpace(vec(o.center) - bc)
			num += (parts[i].Position - rc):Dot(p)
			den += p:Dot(p)
		end
		local s = if den > 1e-6 then num / den else 1
		local err = 0
		for i, o in info.parts do
			err += ((parts[i].Position - rc) - m:VectorToWorldSpace(vec(o.center) - bc) * s).Magnitude ^ 2
		end
		if err < bestErr then best, bestErr, bestScale = m, err, s end
	end
	if bestScale <= 0 or math.sqrt(bestErr / n) > 0.05 * math.max(bestScale, 1) then
		table.insert(notes, ("%s: orientation fit is poor (rms %.3f, scale %.3f), check it by eye"):format(stem, math.sqrt(bestErr / n), bestScale))
	end
	model.WorldPivot = CFrame.new(rc)
	model:PivotTo(CFrame.new(rc) * TARGET * best:Inverse())
	if bestScale > 0 and math.abs(bestScale - 1) > 0.01 then model:ScaleTo(model:GetScale() / bestScale) end
	local origin = rc - TARGET:VectorToWorldSpace(bc)

	for i, o in info.parts do
		local part = parts[i]
		part.Name = o.name
		part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery, part.Massless = true, false, false, false, true
		part.CastShadow = false
		part:SetAttribute("BlenderIndex", i - 1)
		if o.neon then
			part.Material, part.Color, part.TextureID = Enum.Material.Neon, Color3.fromHex(o.neon), ""
		else
			part.Material = Enum.Material.SmoothPlastic
		end
		if o.tint then
			part:SetAttribute("Tint", true)
			part.Color, part.TextureID = Color3.new(1, 1, 1), ""
		end
		if o.neon or o.tint then
			for _, x in part:GetChildren() do
				if x:IsA("SurfaceAppearance") then x:Destroy() end
			end
		elseif part.TextureID == "" and not part:FindFirstChildWhichIsA("SurfaceAppearance") then
			table.insert(notes, ("%s: %s has no palette texture"):format(stem, o.name))
		end
		if o.work then
			part:SetAttribute("WorkProp", true)
			part.Transparency = 1
		end
		if o.group then
			part:SetAttribute("AnimationGroup", o.group)
			-- world space with the model at the origin, as PetModel reads it
			part:SetAttribute("AnimationPivot", TARGET:VectorToWorldSpace(vec(o.pivot)))
		end
		if o.name == "Pannier" then part:SetAttribute("Pannier", true) end
	end
	local primary = (model:FindFirstChild("Body") or model:FindFirstChild("Shell") or parts[1]) :: BasePart
	model.PrimaryPart = primary
	primary.PivotOffset = primary.CFrame:ToObjectSpace(CFrame.new(origin))
	model:PivotTo(CFrame.new())
	model:SetAttribute("BlenderId", info.blender)
	model:SetAttribute("Orientation", ORIENTATION)
	model:SetAttribute("Triangles", info.triangles)
	return model
end

return (function(): string
	local report = {}
	local pets = folder(ReplicatedStorage, "PetModels")
	for _, pet in PETS do
		local model = load("pets_" .. pet.id)
		model.Name = pet.id
		model:SetAttribute("PetColor", Color3.fromHex(pet.color))
		model:SetAttribute("PetName", pet.name)
		model:SetAttribute("Rarity", pet.rarity)
		model:SetAttribute("Flying", pet.flying)
		model:SetAttribute("WorkingStyle", pet.style)
		model:SetAttribute("MeshPets", true)
		-- both looks sit at the origin, so the level 10 pieces line up without moving
		local up = load("pets_" .. pet.id .. "_lv10")
		local level10 = Instance.new("Folder")
		level10.Name = "Level10"
		for _, child in up:GetChildren() do child.Parent = level10 end
		up:Destroy()
		level10.Parent = model
		replace(pets, model)
		local count = 0
		for _, p in model:GetDescendants() do if p:IsA("BasePart") then count += 1 end end
		table.insert(report, ("%s: %d mesh parts"):format(pet.id, count))
		task.wait()
	end

	local eggArt = folder(folder(ReplicatedStorage, "MeshArt"), "eggs")
	local mapArt = folder(ServerStorage, "MapArt")
	for _, egg in EGGS do
		local model = load(egg.stem)
		model.Name = egg.art
		replace(eggArt, model)
		local pedestal = model:Clone()
		pedestal.Name = "Egg_" .. egg.id
		replace(mapArt, pedestal)
		table.insert(report, ("%s: MeshArt.eggs.%s and MapArt.%s"):format(egg.id, egg.art, pedestal.Name))
	end
	table.sort(report)
	return table.concat(report, "\n") .. (if #notes > 0 then "\nCHECK:\n" .. table.concat(notes, "\n") else "")
end)()
