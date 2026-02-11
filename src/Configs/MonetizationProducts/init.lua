--[[
    MonetizationProducts.lua

    Description:
        No description provided.

--]]

-- Root --
local MonetizationProducts = {}

-- Roblox Services --

-- Dependencies --

-- Object References --

-- Constants --

-- Private Variables --

local _ProductConfigBySKU = {}
local _ProductConfigsByTypeAndGroup = {}
local _ProductSKUsByTypeAndGroup = {}
local _ProductConfigsByType = {}
local _ProductTypeForSKU = {}
local _ProductGroupForSKU = {}

local _DevProductSKUByDevProductId = {}

-- Public Variables --

-- Internal Functions --
local function Load()
    for _, ProductTypeFolder in pairs(script:GetChildren()) do
        if ProductTypeFolder.ClassName ~= "Folder" then continue end

        local ProductType = ProductTypeFolder.Name

        _ProductConfigsByTypeAndGroup[ProductType] = {}
        _ProductSKUsByTypeAndGroup[ProductType] = {}
        _ProductConfigsByType[ProductType] = {}

        for _, ProductGroupModule in pairs(ProductTypeFolder:GetChildren()) do
            if ProductGroupModule.ClassName ~= "ModuleScript" then continue end

            local ProductGroup = ProductGroupModule.Name

            _ProductConfigsByTypeAndGroup[ProductType][ProductGroup] = {}
            _ProductSKUsByTypeAndGroup[ProductType][ProductGroup] = {}

            local ProductsInGroup = require(ProductGroupModule)

            for ProductSKU, ProductConfig in ProductsInGroup do
                if _ProductConfigBySKU[ProductSKU] then
                    warn(`Duplicate ProductSKU present! '{ProductSKU}'`)
                end

                _ProductConfigBySKU[ProductSKU] = ProductConfig
                _ProductConfigsByTypeAndGroup[ProductType][ProductGroup][ProductSKU] = ProductConfig
                table.insert(_ProductSKUsByTypeAndGroup[ProductType][ProductGroup], ProductSKU)
                _ProductConfigsByType[ProductType][ProductSKU] = ProductConfig
                _ProductTypeForSKU[ProductSKU] = ProductType
                _ProductGroupForSKU[ProductSKU] = ProductGroup

                if ProductType == "DevProducts" then
                    _DevProductSKUByDevProductId[ProductConfig.DevProductId] = ProductSKU
                end

            end

        end

    end

end
Load()

-- API Functions --

-- ## General
function MonetizationProducts:GetProductConfig(ProductSKU)
    return _ProductConfigBySKU[ProductSKU]
end

function MonetizationProducts:GetProductsConfig(ProductType, ProductGroup)
    return _ProductConfigsByTypeAndGroup[ProductType][ProductGroup]
end

function MonetizationProducts:GetProductSKUs(ProductType, ProductGroup)
    return _ProductSKUsByTypeAndGroup[ProductType][ProductGroup]
end

function MonetizationProducts:GetProductType(ProductSKU)
    return _ProductTypeForSKU[ProductSKU]
end

function MonetizationProducts:GetProductGroup(ProductSKU)
    return _ProductGroupForSKU[ProductSKU]
end

function MonetizationProducts:GetAllProductConfigsOfType(ProductType)
    return _ProductConfigsByType[ProductType]
end

-- ## Dev Products
function MonetizationProducts:GetProductSKUForDevProductId(DevProductId)
    return _DevProductSKUByDevProductId[DevProductId]
end

-- Initializers --
function MonetizationProducts:Init()

end

-- Return Module --
return MonetizationProducts