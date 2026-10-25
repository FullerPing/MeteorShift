--!strict
-- Spec for Shared.Worlds: which world a server is and who may travel there.
return function(t: any)
	local Worlds = require(t.shared.Worlds)
	local Config = require(t.shared.Config.Worlds)
	local nebula = Worlds.find(2) :: any

	t.test("unknown places are World 1; either listed PlaceId picks its world", function()
		t.eq(Worlds.current(123, false, nil).Id, 1)
		t.eq(Worlds.current(0, false, nil).Id, 1, "PlaceId 0 never matches an uncreated world")
		local saved = nebula.PlaceIds
		nebula.PlaceIds = { 555, 666 }
		t.eq(Worlds.current(555, false, nil).Id, 2)
		t.eq(Worlds.current(666, false, nil).Id, 2)
		nebula.PlaceIds = saved
	end)

	t.test("travel stays in the same game: live to live, testing to testing", function()
		local home = Config.List[1]
		t.eq(Worlds.destination(nebula, home.PlaceIds[1]), nebula.PlaceIds[1])
		t.eq(Worlds.destination(nebula, home.PlaceIds[2]), nebula.PlaceIds[2])
		t.eq(Worlds.destination(home, nebula.PlaceIds[2]), home.PlaceIds[2])
		t.eq(Worlds.destination(nebula, 123), nebula.PlaceIds[1], "an unlisted place uses the live game's")
	end)

	t.test("DevWorld overrides only in Studio", function()
		t.eq(Worlds.current(123, true, 2).Id, 2)
		t.eq(Worlds.current(123, false, 2).Id, 1)
		t.eq(Worlds.current(123, true, 9).Id, 1, "an unknown override is ignored")
	end)

	t.test("Nebula Rift opens at rebirth 25", function()
		t.ok(Worlds.isOpen(Config.List[1], 0))
		t.ok(not Worlds.isOpen(nebula, 24))
		t.ok(Worlds.isOpen(nebula, 25))
	end)
end
