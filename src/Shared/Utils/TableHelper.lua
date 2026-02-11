local TableHelper = {}

function TableHelper:CountDictionary(Dictionary)
    local Count = 0

    for _, _ in pairs(Dictionary) do
        Count += 1
    end

    return Count
end

function TableHelper:DeepClone(original)
    --// Source: https://create.roblox.com/docs/luau/tables#deep-clones

    if type(original) ~= "table" then
        return original -- Copy primitive values directly
    end

    local copy = {}

    for key, value in original do
        copy[key] = type(value) == "table" and TableHelper:DeepClone(value) or value
    end

    return copy
end

function TableHelper:DeepFreeze(target)
    --// Source: https://create.roblox.com/docs/luau/tables#deep-freezes

    table.freeze(target)

    for _, v in target do
        if type(v) == "table" and not table.isfrozen(v) then
            TableHelper:DeepFreeze(v)
        end
    end

    return target
end

function TableHelper:GetKeys(Dictionary)
    local Keys = {}

    for Key, _ in pairs(Dictionary) do
        table.insert(Keys, Key)
    end

    return Keys
end


return TableHelper