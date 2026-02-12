--[[
	OnLocalPlayerStoredDataStreamLoaded.lua

	Description:
		Utility for client files that need to wait for DataStream.
		Queues functions until Stored data is available, then runs them.
		If already loaded, runs functions immediately.
--]]

local ClientDataStream = shared("ClientDataStream")
local Maid = shared("Maid")

local PendingFunctionsToRun = {}
local DetectionMaid = Maid.new()
local _PlayerStoredDataStream

local function AttemptToRunFunction(FunctionToRun)
	local Success, ErrorMessage = pcall(FunctionToRun, _PlayerStoredDataStream)
	if Success ~= true then
		warn(`[OnLocalPlayerStoredDataStreamLoaded]A function has failed to run! {ErrorMessage}`)
	end
end

local function RunPendingFunctions()
	for _, FunctionToRun in PendingFunctionsToRun do
		AttemptToRunFunction(FunctionToRun)
	end
	table.clear(PendingFunctionsToRun)
end

local function LoadedCallback(PlayerStoredDataStream)
	_PlayerStoredDataStream = PlayerStoredDataStream
	DetectionMaid:DoCleaning()
	RunPendingFunctions()
end

local function TryToGetStoredDataStreamFromAlreadyLoadedPlayersDataStream()
	local PlayerStoredDataStream = ClientDataStream.Stored
	if PlayerStoredDataStream then
		LoadedCallback(PlayerStoredDataStream)
		return true
	end
	return false
end

local function TryToGetStoredDataStreamFromClientDataStreamOnLoadedSignal()
	DetectionMaid:GiveTask(ClientDataStream.OnLoaded:Connect(function()
		local PlayerStoredDataStream = ClientDataStream.Stored
		if PlayerStoredDataStream then
			LoadedCallback(PlayerStoredDataStream)
		end
	end))
end

if not TryToGetStoredDataStreamFromAlreadyLoadedPlayersDataStream() then
	TryToGetStoredDataStreamFromClientDataStreamOnLoadedSignal()
end

return function(FunctionToRun)
	if _PlayerStoredDataStream then
		AttemptToRunFunction(FunctionToRun)
	else
		table.insert(PendingFunctionsToRun, FunctionToRun)
	end
end
