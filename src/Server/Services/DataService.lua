--[[
    DataService.lua

    Description:
        No description provided.

--]]

-- Root --
local DataService = {}

-- Roblox Services --
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Dependencies --
local ProfileStore = shared("ProfileStore")
local DataStream = shared("DataStream")
local StoredSchema = shared("Server/Utils/DataStream/Schemas/Player/Stored")
local GetSafeDataStoreName = shared("GetSafeDataStoreName")
local PlayerDataVersionService = shared("PlayerDataVersionService")

-- Object References --

-- Constants --
local MOCK_ENABLED_IN_STUDIO = true

-- Private Variables --
local _CachedDataOnLoadFunctions = {}

-- Public Variables --

-- Internal Functions --
local function HandleDataLoaded(Player)
	if _CachedDataOnLoadFunctions[Player] then
		for _, Function in pairs(_CachedDataOnLoadFunctions[Player]) do
			Function()
		end
		_CachedDataOnLoadFunctions[Player] = nil
	end
end

local function HandleDataUnloaded(Player)
	_CachedDataOnLoadFunctions[Player] = nil
end

local function InitProfileStore()
	local LoadStoreName = GetSafeDataStoreName("PlayerDataStore")

	local PlayerStore = ProfileStore.New(LoadStoreName, StoredSchema)
	if RunService:IsStudio() == true and MOCK_ENABLED_IN_STUDIO then
		PlayerStore = PlayerStore.Mock
		print("MOCK_ENABLED_IN_STUDIO is true, using mock data.")
	end

	local Profiles = {}

	local function PlayerAdded(player)
		-- Start a profile session for this player's data:

		local profile = PlayerStore:StartSessionAsync(`{player.UserId}`, {
			Cancel = function()
				return player.Parent ~= Players
			end,
		})

		-- Handling new profile session or failure to start it:

		if profile ~= nil then
			profile:AddUserId(player.UserId) -- GDPR compliance
			profile:Reconcile() -- Fill in missing variables from PROFILE_TEMPLATE (optional)

			profile.OnSessionEnd:Connect(function()
				Profiles[player] = nil
				player:Kick(`Profile session end - Please rejoin`)
			end)

			if player.Parent == Players then
				Profiles[player] = profile

				DataStream.Stored[player] = profile.Data

				PlayerDataVersionService:UpdatePlayerData(player, profile.Data)

				DataStream.Session[player].IsDataLoaded = true

				HandleDataLoaded(player)

				profile.OnSave:Connect(function()
					print(`Profile.Data is about to be saved to the DataStore`)
					local StoredPlayerData = DataStream.Stored[player]:Read()
					if StoredPlayerData then
						profile.Data = StoredPlayerData
					else
						warn(`StoredPlayerData is nil! (uh oh)`)
					end
				end)

				profile.OnLastSave:Connect(function(reason: "Manual" | "External" | "Shutdown")
					print(`Profile.Data is about to be saved to the DataStore for the last time; Reason: {reason}`)

					--// Get the cached data one last time
					local StoredPlayerData = DataStream.Stored[player]:Read()
					if StoredPlayerData then
						profile.Data = StoredPlayerData
					else
						warn(`StoredPlayerData somehow already nil! (uh oh pt 2)`)
					end

					--// Handle the DataStream removal (assumes DataStreamMeta HANDLE_PLAYER_REMOVAL is false)
					DataStream:HandlePlayerRemoved(player)

					HandleDataUnloaded(player)
				end)
			else
				-- The player has left before the profile session started
				profile:EndSession()
			end
		else
			-- This condition should only happen when the Roblox server is shutting down
			player:Kick(`Profile load fail - Please rejoin`)
		end
	end

	-- In case Players have joined the server earlier than this script ran:
	for _, player in Players:GetPlayers() do
		task.spawn(PlayerAdded, player)
	end

	Players.PlayerAdded:Connect(PlayerAdded)

	Players.PlayerRemoving:Connect(function(player)
		local profile = Profiles[player]
		if profile ~= nil then
			profile:EndSession()
		end
	end)
end

-- API Functions --
function DataService:HasPlayerDataLoaded(Player)
	local PlayerSessionData = DataStream.Session[Player]:Read()
	if PlayerSessionData then
		return PlayerSessionData.IsDataLoaded
	else
		return false
	end

	return false
end

function DataService:OnPlayerDataLoaded(Player, Callback)
	if DataService:HasPlayerDataLoaded(Player) then
		Callback()
	else
		_CachedDataOnLoadFunctions[Player] = _CachedDataOnLoadFunctions[Player] or {}
		table.insert(_CachedDataOnLoadFunctions[Player], Callback)
	end
end

-- Initializers --
function DataService:Init()
	InitProfileStore()
end

-- Return Module --
return DataService
