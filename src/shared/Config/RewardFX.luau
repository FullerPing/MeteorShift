--!strict
-- Reward effects (client/RewardFX.luau): bursts, light pillars, coin flights and puffs for
-- level ups, upgrades, evolutions, rebirths, sales and teleports. The sprites are white so
-- each effect tints them; they are drawn by tools/store-art/draw_fx_sprites.py (assets/fx/).

local RewardFX = {
	Sprites = {
		Sparkle = "rbxassetid://112650242895059",
		Ring = "rbxassetid://84363305327906",
		Rays = "rbxassetid://130598341247661",
		Smoke = "rbxasset://textures/particles/smoke_main.dds",
		Square = "rbxasset://textures/particles/SquareParticle.png",
	},

	Colors = {
		Upgrade = Color3.fromRGB(110, 230, 255),
		Evolve = Color3.fromRGB(255, 200, 70),
		LevelUp = Color3.fromRGB(140, 255, 150),
		Rebirth = Color3.fromRGB(210, 130, 255),
		Bonus = Color3.fromRGB(255, 214, 64),
		Pet = Color3.fromRGB(255, 150, 210),
		Teleport = Color3.fromRGB(150, 220, 255),
		Full = Color3.fromRGB(255, 96, 72),
	},
	Confetti = {
		Color3.fromRGB(255, 92, 92), Color3.fromRGB(255, 196, 60), Color3.fromRGB(120, 230, 120),
		Color3.fromRGB(90, 180, 255), Color3.fromRGB(210, 130, 255),
	},

	-- burst(): ring + sparkles at the feet. Size scales the ring; Count the sparkles.
	Burst = { Ring = 16, Seconds = 0.55, Count = 22, Light = 10 },
	-- pillar(): a light column. Height in studs; Seconds it holds.
	Pillar = { Height = 26, Width = 3.4, Seconds = 1, Rise = 24, Transparency = 0.6 },
	-- coins(): icons flying to the HUD wallet
	Coins = { Max = 10, Size = 34, Seconds = 0.7, Stagger = 0.05 },
	-- Crit: a short decaying camera shake (skipped with Reduce camera shake)
	CritPunch = { Degrees = 0.45, Seconds = 0.14 },
}

return RewardFX
