--!strict
local Meteor = require(script.Meteor)

export type MeteorType = Meteor.MeteorType

return {
	Meteor = Meteor,
	Pickaxes = require(script.Pickaxes),
	Backpacks = require(script.Backpacks),
	Debris = require(script.Debris),
}
