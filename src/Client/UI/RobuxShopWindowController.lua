--[[
	RobuxShopWindowController.lua

	Description:
		Builds the Robux shop window from config and prompts purchases via MonetizationController.
--]]

-- Root --
local RobuxShopWindowController = {}

-- Dependencies --
local UIController = shared("UIController")
local MonetizationController = shared("MonetizationController")
local MonetizationProducts = shared("MonetizationProducts")
local RobuxShopConfig = shared("RobuxShopConfig")

-- Private Variables --
local _ScreenGui = nil
local _MainFrame = nil
local _OffersContainer = nil
local _OfferTemplate = nil
local _IsSetup = false
local _OfferCards = {}

-- Internal Functions --
local function SetText(target, text)
	if not target then
		return
	end

	if target:IsA("TextLabel") or target:IsA("TextButton") then
		target.Text = text
		return
	end

	local textLabel = target:FindFirstChild("TextLabel", true)
	if textLabel and textLabel:IsA("TextLabel") then
		textLabel.Text = text
	end
end

local function ResolveProductFallbackPriceText(productSku)
	local productConfig = MonetizationProducts:GetProductConfig(productSku)
	if not productConfig then
		return "R$?"
	end

	local idealCost = productConfig.IdealRobuxCost
	if type(idealCost) ~= "number" then
		return "R$?"
	end

	return "R$" .. tostring(idealCost)
end

local function SetOfferCardText(card, offer)
	local titleLabel = card:FindFirstChild("OfferName", true) or card:FindFirstChild("DisplayName", true)
	if titleLabel then
		SetText(titleLabel, offer.DisplayName or offer.Id or "Offer")
	end

	local descLabel = card:FindFirstChild("OfferDescription", true) or card:FindFirstChild("Description", true)
	if descLabel then
		SetText(descLabel, offer.Description or "")
	end

	local rewardLabel = card:FindFirstChild("RewardText", true) or card:FindFirstChild("Reward", true)
	if rewardLabel and offer.Reward and offer.Reward.Type == "Currency" then
		SetText(rewardLabel, "+" .. tostring(offer.Reward.Amount) .. " " .. tostring(offer.Reward.CurrencyId))
	end

	local buyButton = card:FindFirstChild("BuyButton", true)
	if buyButton and buyButton:IsA("GuiButton") then
		SetText(buyButton, ResolveProductFallbackPriceText(offer.ProductSKU))
	end
end

local function ResolveOffersContainer(mainFrame)
	return mainFrame:FindFirstChild("Offers", true)
		or mainFrame:FindFirstChild("OffersScroll", true)
		or mainFrame:FindFirstChild("ShopItems", true)
end

local function ResolveOfferTemplate(offersContainer)
	return offersContainer:FindFirstChild("_Template") or offersContainer:FindFirstChild("Template")
end

local function HookPurchaseButton(card, offer)
	local buyButton = card:FindFirstChild("BuyButton", true)
	if not buyButton or not buyButton:IsA("GuiButton") then
		return
	end

	buyButton.MouseButton1Click:Connect(function()
		MonetizationController:PromptPurchase(offer.ProductSKU)
	end)
end

local function PopulateOffers()
	if not _OffersContainer or not _OfferTemplate then
		return
	end

	for _, card in ipairs(_OfferCards) do
		card:Destroy()
	end
	table.clear(_OfferCards)

	for _, offer in ipairs(RobuxShopConfig.Offers or {}) do
		local card = _OfferTemplate:Clone()
		card.Name = offer.Id or offer.ProductSKU
		card.Visible = true
		card.LayoutOrder = offer.LayoutOrder or 1

		SetOfferCardText(card, offer)
		HookPurchaseButton(card, offer)

		card.Parent = _OffersContainer
		table.insert(_OfferCards, card)
	end
end

local function SetupUI(screenGui)
	if _IsSetup then
		return
	end

	_ScreenGui = screenGui
	_MainFrame = _ScreenGui:WaitForChild("MainFrame")
	_OffersContainer = ResolveOffersContainer(_MainFrame)

	if not _OffersContainer then
		warn("[RobuxShopWindowController] Offers container not found under MainFrame")
		return
	end

	_OfferTemplate = ResolveOfferTemplate(_OffersContainer)
	if not _OfferTemplate then
		warn("[RobuxShopWindowController] Offers template not found in offers container")
		return
	end

	_OfferTemplate.Visible = false
	_IsSetup = true
end

-- API Functions --
function RobuxShopWindowController:Refresh()
	PopulateOffers()
end

-- Initializers --
function RobuxShopWindowController:Init()
	UIController:WhenScreenGuiReady("RobuxShopWindow", function(screenGui)
		SetupUI(screenGui)
		self:Refresh()
	end)
end

-- Return Module --
return RobuxShopWindowController
