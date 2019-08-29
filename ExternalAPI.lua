--[[
	API overrides from external addons that augment the data missing in the Classic API
]]
ShadowUF = select(2, ...)
ShadowUF.API = {}

ShadowUF.API.UnitHealth = function(unit)
	if RealMobHealth then
		local cur, max = RealMobHealth.GetUnitHealth(unit)
		if cur then return cur end
	end
	return UnitHealth(unit)
end

ShadowUF.API.UnitHealthMax = function(unit)
	if RealMobHealth then
		local cur, max = RealMobHealth.GetUnitHealth(unit)
		if max then return max end
	end
	return UnitHealthMax(unit)
end
