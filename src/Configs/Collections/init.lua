local Collections = {}

local CollectionIds = {}
local _CachedModules = {}
for _, ModuleScript in pairs(script:GetChildren()) do
    local CollectionId = ModuleScript.Name
    local RequiredModule = require(ModuleScript)

    _CachedModules[CollectionId] = RequiredModule --// Already frozen

    table.insert(CollectionIds, CollectionId)

end

function Collections:GetConfig(CollectionId)
    return _CachedModules[CollectionId]
end

function Collections:GetItemsConfig(CollectionId)
    return _CachedModules[CollectionId].Items
end

function Collections:GetItemConfig(CollectionId, ItemId)
    return _CachedModules[CollectionId].Items[ItemId]
end

function Collections:GetCollectionIds()
    return CollectionIds
end

return Collections