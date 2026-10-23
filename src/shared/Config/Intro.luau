--!strict
-- The first-join intro: a short cinematic instead of pages to read. The camera opens wide over the crater, a meteor
-- streaks in and crashes into it under the game's title, then the camera glides back to the player. Words and timing
-- only; Shared/Intro decides who sees it and IntroController plays it.

local Intro = {
	Title = "METEOR MINING SIMULATOR",
	Tagline = "Meteors crash here. Mine them and get rich!",

	Fall = 1.8, -- seconds the meteor streaks down
	Hold = 2.6, -- seconds on the crash and the title
	Glide = 1.4, -- seconds for the camera to fly back to the player

	-- the wide shot, in studs from the crater floor: back toward the player and up; it pushes in to Push of it
	Distance = 150,
	Height = 95,
	Push = 0.72,
}

return Intro
