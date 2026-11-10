--!strict
-- Who gets the first-join "How to play" intro (Config.Intro). Only a player who has not
-- seen it and has not started the tutorial: anyone who already did a tutorial step,
-- finished it or skipped it is an existing player and never sees it.

local Intro = {}

function Intro.shouldShow(flags: { [string]: any }, tutorialStep: number): boolean
	return flags.introSeen ~= true and flags.tutorialDone ~= true and tutorialStep <= 1
end

return Intro
