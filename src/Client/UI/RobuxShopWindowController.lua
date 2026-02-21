--[[
	RobuxShopWindowController.lua

	Description:
		Updates Robux shop product prices from Marketplace data and wires purchase prompts.
		Works with nested content groups (e.g. SPINS, CURRENCY) and product cards
		that contain a RobuxButton with a PriceLabel.
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
local _Content = nil
local _IsSetup = false
local _ConnectedButtons = {}
local _DevProductConfigBySKU = {}

-- Internal Functions --
local function NormalizeKey(value)
	if type(value) ~= "string" then
		return ""
	end
	return string.lower((value:gsub("[^%w]", "")))
end

local function BuildDevProductSkuIndex()
	_DevProductConfigBySKU = MonetizationProducts:GetAllProductConfigsOfType("DevProducts") or {}
end

local function FindPriceLabel(button)
	local direct = button:FindFirstChild("PriceLabel")
	if direct and (direct:IsA("TextLabel") or direct:IsA("TextButton")) then
		return direct
	end

	local nested = button:FindFirstChild("PriceLabel", true)
	if nested and (nested:IsA("TextLabel") or nested:IsA("TextButton")) then
		return nested
	end

	return nil
end

local function FindProductCardFromButton(button)
	local current = button.Parent
	while current and current ~= _ScreenGui do
		if current:IsA("GuiObject") and current.Name ~= "Content" and current.Name ~= "MainFrame" then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function GetSkuByExactName(name)
	if type(name) ~= "string" or name == "" then
		return nil
	end
	if _DevProductConfigBySKU[name] then
		return name
	end
	return nil
end

local function GetSkuByNormalizedName(name)
	local normalizedName = NormalizeKey(name)
	if normalizedName == "" then
		return nil
	end

	local matchedSku = nil
	for sku, _ in pairs(_DevProductConfigBySKU) do
		if NormalizeKey(sku) == normalizedName then
			if matchedSku then
				return nil
			end
			matchedSku = sku
		end
	end
	return matchedSku
end

local function GetSpinSkuFromName(name)
	local normalizedName = NormalizeKey(name)
	if normalizedName == "" then
		return nil
	end

	local spinCount = string.match(normalizedName, "spins?(%d+)")
	if not spinCount then
		return nil
	end

	local matchedSku = nil
	local spinSuffix = "spin" .. spinCount
	for sku, _ in pairs(_DevProductConfigBySKU) do
		local normalizedSku = NormalizeKey(sku)
		if normalizedSku:find(spinSuffix, 1, true) then
			if matchedSku then
				return nil
			end
			matchedSku = sku
		end
	end

	return matchedSku
end

local function GetCoinSkuFromName(name)
	local normalizedName = NormalizeKey(name)
	if normalizedName == "" or (not normalizedName:find("coin", 1, true)) then
		return nil
	end

	local packIndex = string.match(normalizedName, "coins?(%d+)")
	if not packIndex then
		return nil
	end

	local matchedSku = nil
	for sku, _ in pairs(_DevProductConfigBySKU) do
		local normalizedSku = NormalizeKey(sku)
		local skuPackIndex = string.match(normalizedSku, "pack(%d+)")
		if normalizedSku:find("coin", 1, true) and skuPackIndex == packIndex then
			if matchedSku then
				return nil
			end
			matchedSku = sku
		end
	end
	return matchedSku
end

local function GetProductSKU(button)
	local card = FindProductCardFromButton(button)
	if not card then
		return nil, nil
	end

	local cardName = card.Name

	local explicitSku = button:GetAttribute("ProductSKU") or card:GetAttribute("ProductSKU")
	if type(explicitSku) == "string" and _DevProductConfigBySKU[explicitSku] then
		return explicitSku, card
	end

	local uiMap = RobuxShopConfig.UIProductSKUByFrameName or {}
	local mappedSku = uiMap[cardName]
	if type(mappedSku) == "string" and _DevProductConfigBySKU[mappedSku] then
		return mappedSku, card
	end

	local fromExactName = GetSkuByExactName(cardName)
	if fromExactName then
		return fromExactName, card
	end

	local fromNormalizedName = GetSkuByNormalizedName(cardName)
	if fromNormalizedName then
		return fromNormalizedName, card
	end

	local fromSpinHeuristic = GetSpinSkuFromName(cardName)
	if fromSpinHeuristic then
		return fromSpinHeuristic, card
	end

	local fromCoinHeuristic = GetCoinSkuFromName(cardName)
	if fromCoinHeuristic then
		return fromCoinHeuristic, card
	end

	return nil, card
end

local function SetButtonPriceLabel(button, text)
	local priceLabel = FindPriceLabel(button)
	if priceLabel then
		priceLabel.Text = text
	end
end

local function GetDisplayPriceForSku(sku, productInfo)
	local productType = MonetizationProducts:GetProductType(sku)
	if productType == "DevProducts" then
		local price = productInfo and productInfo.PriceInRobux
		if type(price) == "number" then
			return tostring(price)
		end
	end

	local fallbackConfig = MonetizationProducts:GetProductConfig(sku)
	local fallbackCost = fallbackConfig and fallbackConfig.IdealRobuxCost
	if type(fallbackCost) == "number" then
		return tostring(fallbackCost)
	end

	return "?"
end

local function HookPurchase(button, sku)
	if _ConnectedButtons[button] then
		return
	end
	_ConnectedButtons[button] = true

	button.MouseButton1Click:Connect(function()
		MonetizationController:PromptPurchase(sku)
	end)
end

local function RefreshSingleButton(button)
	local sku = GetProductSKU(button)
	if not sku then
		SetButtonPriceLabel(button, "?")
		return
	end

	SetButtonPriceLabel(button, "...")
	HookPurchase(button, sku)

	MonetizationController:GetProductInfoPromise(sku)
		:andThen(function(productInfo)
			SetButtonPriceLabel(button, GetDisplayPriceForSku(sku, productInfo))
		end)
		:catch(function()
			SetButtonPriceLabel(button, GetDisplayPriceForSku(sku, nil))
		end)
end

local function RefreshAllProductButtons()
	if not _Content then
		return
	end

	for _, descendant in ipairs(_Content:GetDescendants()) do
		if descendant:IsA("ImageButton") and descendant.Name == "RobuxButton" then
			RefreshSingleButton(descendant)
		end
	end
end

local function SetupUI(screenGui)
	if _IsSetup then
		return
	end

	_ScreenGui = screenGui
	_MainFrame = _ScreenGui:WaitForChild("MainFrame")
	_Content = _MainFrame:WaitForChild("Content")

	BuildDevProductSkuIndex()
	_IsSetup = true
end

-- API Functions --
function RobuxShopWindowController:Refresh()
	RefreshAllProductButtons()
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
