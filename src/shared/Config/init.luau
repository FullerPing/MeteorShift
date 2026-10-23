--!strict
local Meteor = require(script.Meteor)
local Home = require(script.Home)
local Index = require(script.Index)
local Sounds = require(script.Sounds)
local LeaderboardsConfig = require(script.Leaderboards)

export type MeteorType = Meteor.MeteorType
export type SoundEntry = Sounds.Entry
export type Level = Home.Level
export type Station = Home.Station
export type Mineral = Index.Mineral
export type IndexPage = Index.Page
export type LeaderboardBoard = LeaderboardsConfig.Board

return {
	Meteor = Meteor,
	Index = Index,
	Pickaxes = require(script.Pickaxes),
	Backpacks = require(script.Backpacks),
	Gear = require(script.Gear),
	Pets = require(script.Pets),
	Levels = require(script.Levels),
	Debris = require(script.Debris),
	Crown = require(script.Crown),
	Home = Home,
	Tutorial = require(script.Tutorial),
	Intro = require(script.Intro),
	Store = require(script.Store),
	Net = require(script.Net),
	Rebirth = require(script.Rebirth),
	Hooks = require(script.Hooks),
	Perks = require(script.Perks),
	Telemetry = require(script.Telemetry),
	Monetization = require(script.Monetization),
	Hud = require(script.Hud),
	Loading = require(script.Loading),
	HudIcons = require(script.HudIcons),
	HudEdit = require(script.HudEdit),
	Balance = require(script.Balance),
	Atmosphere = require(script.Atmosphere),
	LandingFX = require(script.LandingFX),
	ImpactFX = require(script.ImpactFX),
	SurfaceFX = require(script.SurfaceFX),
	Sounds = Sounds,
	Music = require(script.Music),
	RewardFX = require(script.RewardFX),
	Leaderboards = LeaderboardsConfig,
	Daily = require(script.Daily),
	Quests = require(script.Quests),
	Feedback = require(script.Feedback),
	Badges = require(script.Badges),
	Codes = require(script.Codes),
}
