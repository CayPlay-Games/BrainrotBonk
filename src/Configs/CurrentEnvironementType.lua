local PlacesConfig = shared("PlacesConfig")
local CurrentPlaceId = game.PlaceId

local CurrentEnvironementType

for _, Environements in PlacesConfig do
	for EnvironementType, PlaceIds in Environements do
		if table.find(PlaceIds, CurrentPlaceId) then
			return EnvironementType
		end
	end
end

if not CurrentEnvironementType then
	warn(`No EnvironementType for PlaceId {CurrentPlaceId}`)

	return "Dev"
end

return CurrentEnvironementType
