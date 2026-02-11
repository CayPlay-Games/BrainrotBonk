--[[
	RoundState.lua

	Description:
		Global DataStream schema for round state.
		Replicated to all clients for UI and game state awareness.
--]]

return {
	-- Current state of the round
	-- "Waiting" | "MapLoading" | "Spawning" | "Aiming" | "Revealing" | "Launching" | "Resolution" | "RoundEnd"
	State = "Waiting",

	-- Countdown timer (seconds remaining in current phase)
	TimeRemaining = 0,

	-- Round tracking
	RoundNumber = 0,

	-- Map information
	CurrentMapId = nil,
	CurrentMapName = "",

	-- Players in the current round
	-- Key: UserId (as string), Value: { DisplayName, IsAlive, EliminatedBy, PlacementPosition }
	Players = {},

	-- Current alive player count (for quick UI access)
	AliveCount = 0,

	-- Winner information (populated at RoundEnd)
	Winner = {
		UserId = nil,
		DisplayName = "",
	},

	-- Aim data (only populated during Revealing phase, cleared after)
	-- Key: UserId (as string), Value: { Direction = {X, Y, Z}, Power = number }
	RevealedAims = {},
}
