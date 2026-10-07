--!strict
-- Who may use the dev chat commands (/meteor, /pickaxe, /backpack). Server-only, so the list never
-- reaches clients. Studio always allows them so playtesting needs no setup; a live server allows
-- only the user ids below. Add a teammate by appending a line: `[<userId>] = "<name>",`.
local Admins = {}

Admins.List = {
	[3245458673] = "FullPinger",
}

-- `list` and `isStudio` are parameters so the rule can be tested without a running place
function Admins.can(userId: number, isStudio: boolean, list: { [number]: string }?): boolean
	if isStudio then
		return true
	end
	return (list or Admins.List)[userId] ~= nil
end

return Admins
