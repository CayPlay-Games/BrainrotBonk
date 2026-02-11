--[[
    PromiseWaitForDataStream.lua

    Description:
        Utility function to wait for a DataStream path to be loaded/defined using Promises.
        Works with both ClientDataStream and server-side DataStream.
        Waits until the value is not nil and not an empty table.

    Usage Examples:
        -- Wait for player stored data to load
        PromiseWaitForDataStream(ClientDataStream.Stored)
            :andThen(function(storedData)
                print("Data loaded:", storedData)
            end)

        -- Wait with timeout
        PromiseWaitForDataStream(ClientDataStream.GlobalDataStream.CurrentMatchData, 10)
            :andThen(function(matchData)
                print("Match data loaded:", matchData)
            end)
            :catch(function(err)
                warn("Timeout:", err)
            end)

--]]

-- Dependencies --
local Promise = shared("Promise")
local Maid = shared("Maid")

-- Helper Functions --
local function isValueLoaded(value)
	-- Check if value is not nil
	if value == nil then
		return false
	end

	-- For tables, check if it's truly empty or just not initialized yet
	-- We need to distinguish between:
	-- 1. Empty table {} that IS the actual data (valid, loaded)
	-- 2. Empty proxy table {} that represents "not yet replicated" (invalid, not loaded)
	--
	-- The way to tell: if a table has __index metamethod, it's likely a proxy
	-- If it's a plain table (even if empty), it's actual data
	if type(value) == "table" then
		local metatable = getmetatable(value)
		-- If it has no metatable, it's actual data (even if empty)
		if not metatable then
			return true
		end

		-- If it has a metatable with __index, it might be a proxy
		-- In that case, check if it has any keys
		if metatable.__index then
			return next(value) ~= nil
		end

		-- Otherwise, treat as loaded
		return true
	end

	return true
end

-- API Functions --

--[[
    Waits for a DataStream path to be loaded and returns a Promise.

    @param dataStreamProxy - The DataStream proxy object (e.g., ClientDataStream.Stored)
    @param timeout - Optional timeout in seconds (number or nil)

    @return Promise - Resolves with the value when it's loaded (not nil and not empty table)
]]
local function PromiseWaitForDataStream(dataStreamProxy, timeout)
	local promise = Promise.new(function(resolve)
		local maid = Maid.new()

		-- Check if data already exists
		local currentValue = dataStreamProxy:Read()
		if isValueLoaded(currentValue) then
			resolve(dataStreamProxy)
			return
		end

		-- Set up change listener
		maid:GiveTask(dataStreamProxy:Changed(function(newValue)
			if isValueLoaded(newValue) then
				maid:DoCleaning()
				resolve(dataStreamProxy)
			end
		end))

		-- Handle cleanup if Promise is cancelled
		return function()
			maid:DoCleaning()
		end
	end)

	-- Only apply timeout if one was provided
	if timeout then
		promise = promise:timeout(timeout, "DataStream path did not load within timeout")
	end

	return promise
end

-- Return Module --
return PromiseWaitForDataStream
