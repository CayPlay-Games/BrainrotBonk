--[[
	RankWindowController.lua

	Description:
		Manages the RankWindow UI - populates CardScroll with all ranks,
		shows claimed/locked status, and displays current XP progress.
--]]

-- Root --
local RankWindowController = {}

-- Roblox Services --
local Players = game:GetService("Players")

-- Dependencies --
local ClientDataStream = shared("ClientDataStream")
local RankConfig = shared("RankConfig")
local RankHelper = shared("RankHelper")
local RoundConfig = shared("RoundConfig")

-- Object References --
local LocalPlayer = Players.LocalPlayer
local PlayerGui

-- Private Variables --
local _ScreenGui = nil
local _CardScroll = nil
local _CardTemplate = nil
local _XPBarFill = nil
local _XPText = nil
local _NextRankLabel = nil
local _RankCards = {} -- rankIndex -> card
local _IsSetup = false

-- Internal Functions --

local function DebugLog(...)
	if RoundConfig.DEBUG_LOG_STATE_CHANGES then
		print("[RankWindowController]", ...)
	end
end

-- Updates the XP bar display
local function UpdateXPBar()
	local stored = ClientDataStream.Stored
	if not stored then
		DebugLog("UpdateXPBar: No stored data")
		return
	end

	local currentXP = stored.Rank.XP:Read() or 0
	local progress = RankHelper:GetXPProgress(currentXP)

	DebugLog("UpdateXPBar: XP =", currentXP, "Progress =", progress.PrevXP, "->", progress.NextXP)

	-- Calculate ratio within current tier
	local ratio = 0
	if not progress.IsMaxRank then
		ratio = (currentXP - progress.PrevXP) / math.max(1, progress.NextXP - progress.PrevXP)
	else
		ratio = 1 -- Full bar at max rank
	end

	DebugLog("UpdateXPBar: Ratio =", ratio, "Fill =", _XPBarFill ~= nil, "Text =", _XPText ~= nil)

	if _XPBarFill then
		_XPBarFill.Size = UDim2.new(math.clamp(ratio, 0, 1), 0, 1, 0)
	end

	if _XPText then
		_XPText.Text = currentXP .. " / " .. progress.NextXP .. " Experience"
	end
end

-- Updates the claimed/locked status of a card
local function UpdateCardStatus(card, rankIndex)
	local stored = ClientDataStream.Stored
	if not stored then return end

	local lastRewarded = stored.Rank.LastRankRewarded:Read() or 0
	local statusFrame = card:FindFirstChild("StatusFrame")
	if not statusFrame then return end

	local claimedFrame = statusFrame:FindFirstChild("Claimed")
	local lockedFrame = statusFrame:FindFirstChild("Locked")

	if rankIndex <= lastRewarded then
		-- Rank is claimed
		if claimedFrame then claimedFrame.Visible = true end
		if lockedFrame then lockedFrame.Visible = false end
	else
		-- Rank is locked
		if claimedFrame then claimedFrame.Visible = false end
		if lockedFrame then lockedFrame.Visible = true end
	end
end

-- Updates all card statuses
local function UpdateAllCardStatuses()
	for rankIndex, card in pairs(_RankCards) do
		UpdateCardStatus(card, rankIndex)
	end
end

-- Creates a rank card for the CardScroll
local function CreateRankCard(rankIndex, rankConfig)
	local card = _CardTemplate:Clone()
	card.Name = "Card_" .. rankConfig.Name:gsub(" ", "_")
	card.Visible = true

	-- Set rank name
	local rankName = card:FindFirstChild("RankName")
	if rankName then
		rankName.Text = rankConfig.Name
	end

	-- Set reward label
	local rewardBox = card:FindFirstChild("RewardBox")
	if rewardBox then
		local rewardLabel = rewardBox:FindFirstChild("RewardLabel")
		if rewardLabel then
			rewardLabel.Text = "Reward:\n" .. RankHelper:GetRewardText(rankConfig.Reward)
		end
	end

	-- Set lock amount (XP required)
	local statusFrame = card:FindFirstChild("StatusFrame")
	if statusFrame then
		local lockedFrame = statusFrame:FindFirstChild("Locked")
		if lockedFrame then
			local lockAmount = lockedFrame:FindFirstChild("LockAmount")
			if lockAmount then
				lockAmount.Text = tostring(rankConfig.XPRequired)
			end
		end
	end

	-- Apply tier gradient
	local gradient = RankHelper:GetRankGradient(rankIndex)
	if gradient then
		local uiGradient = card:FindFirstChildOfClass("UIGradient")
		if not uiGradient then
			uiGradient = Instance.new("UIGradient")
			uiGradient.Parent = card
		end
		uiGradient.Color = gradient
		uiGradient.Rotation = 90 -- Top to bottom
	end

	-- Update claimed/locked status
	UpdateCardStatus(card, rankIndex)

	card.Parent = _CardScroll
	_RankCards[rankIndex] = card

	return card
end

-- Populates the CardScroll with all ranks
local function PopulateCards()
	-- Clear existing cards
	for _, card in pairs(_RankCards) do
		card:Destroy()
	end
	_RankCards = {}

	-- Create cards for each rank
	for index, rankConfig in ipairs(RankConfig.Ranks) do
		local card = CreateRankCard(index, rankConfig)
		if card then
			card.LayoutOrder = index
		end
	end

	-- Update XP bar
	UpdateXPBar()

	DebugLog("Populated", #RankConfig.Ranks, "rank cards")
end

-- Sets up UI references
local function SetupUI()
	if _IsSetup then return end

	PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

	_ScreenGui = PlayerGui:WaitForChild("RankWindow")
	local mainFrame = _ScreenGui:WaitForChild("MainFrame")
	local innerFrame = mainFrame:WaitForChild("InnerFrame")

	-- CardScroll references
	_CardScroll = innerFrame:WaitForChild("CardScroll")
	_CardTemplate = _CardScroll:FindFirstChild("_Template")
	if _CardTemplate then
		_CardTemplate.Visible = false
	end

	-- Set canvas size based on rank count (11.5 scale works for 37 ranks = ~0.311 per rank)
	local scalePerRank = 12 / 37
	local canvasScale = #RankConfig.Ranks * scalePerRank
	_CardScroll.CanvasSize = UDim2.new(canvasScale, 0, .8, 0)

	-- XP bar references (check both InnerFrame and MainFrame)
	local xpBarContainer = innerFrame:FindFirstChild("XPBarContainer") or mainFrame:FindFirstChild("XPBarContainer")
	if xpBarContainer then
		local xpBarBg = xpBarContainer:FindFirstChild("XPBarBg")
		if xpBarBg then
			_XPBarFill = xpBarBg:FindFirstChild("XPBarFill")
		end
		_XPText = xpBarBg:FindFirstChild("XPText")
		DebugLog("XP bar found - Fill:", _XPBarFill ~= nil, "Text:", _XPText ~= nil)
	else
		DebugLog("XPBarContainer not found!")
	end

	_IsSetup = true
	DebugLog("UI setup complete")
end

-- Scrolls to show the last claimed rank
local function ScrollToLastClaimed()
	local stored = ClientDataStream.Stored
	if not stored or not _CardScroll or not _CardTemplate then return end

	local lastRewarded = stored.Rank.LastRankRewarded:Read() or 0
	if lastRewarded <= 0 then return end

	-- Get layout padding from UIListLayout
	local listLayout = _CardScroll:FindFirstChildOfClass("UIListLayout")
	local padding = listLayout and listLayout.Padding.Offset or 0

	-- Calculate position based on card index (0-indexed for position calculation)
	local cardWidth = _CardTemplate.Size.X.Scale * _CardScroll.AbsoluteSize.X + _CardTemplate.Size.X.Offset
	local scrollWidth = _CardScroll.AbsoluteSize.X

	-- Position = (cardIndex - 1) * (cardWidth + padding)
	local cardPosition = (lastRewarded - 1) * (cardWidth + padding)

	-- Center the card in view (add 1.5 cards offset adjustment)
	local targetScroll = cardPosition - (scrollWidth / 2) + (cardWidth / 2) + (1.5 * (cardWidth + padding))
	targetScroll = math.max(0, targetScroll)

	_CardScroll.CanvasPosition = Vector2.new(targetScroll, 0)
	DebugLog("Scrolled to rank", lastRewarded, "at position", targetScroll)
end

-- API Functions --

function RankWindowController:Refresh()
	PopulateCards()
	ScrollToLastClaimed()
end

function RankWindowController:ScrollToLastClaimed()
	ScrollToLastClaimed()
end

-- Initializers --
function RankWindowController:Init()
	DebugLog("Initializing...")

	task.defer(function()
		task.wait(1) -- Wait for DataStream

		SetupUI()

		-- Listen for rank data changes
		local stored = ClientDataStream.Stored
		if stored and stored.Rank then
			stored.Rank.XP:Changed(function()
				UpdateXPBar()
			end)

			stored.Rank.LastRankRewarded:Changed(function()
				UpdateAllCardStatuses()
			end)
		end

		-- Initial population
		PopulateCards()

		-- Scroll to last claimed rank when window becomes visible
		if _ScreenGui then
			_ScreenGui:GetPropertyChangedSignal("Enabled"):Connect(function()
				if _ScreenGui.Enabled then
					ScrollToLastClaimed()
				end
			end)
		end
	end)
end

-- Return Module --
return RankWindowController
