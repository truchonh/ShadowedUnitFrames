local L = ShadowUF.L
local Config = ShadowUF.Config

function Config:loadVisibilityOptions()
	-- As zone units are only enabled in a certain zone... it's pointless to provide visibility options for them
	local unitBlacklist = {}
	for unit in pairs(ShadowUF.Units.zoneUnits) do unitBlacklist[unit] = true end
	for unit, parent in pairs(ShadowUF.Units.childUnits) do
		if( ShadowUF.Units.zoneUnits[parent] ) then
			unitBlacklist[unit] = true
		end
	end

	local globalVisibility = {}
	local function set(info, value)
		local key = info[#(info)]
		local unit = info[#(info) - 1]
		local area = info[#(info) - 2]

		if( key == "enabled" ) then
			key = ""
		end

		if( value == nil ) then
			value = false
		elseif( value == false ) then
			value = nil
		end

		for _, configUnit in pairs(ShadowUF.unitList) do
			if( ( configUnit == unit or unit == "global" ) and not unitBlacklist[configUnit] ) then
				ShadowUF.db.profile.visibility[area][configUnit .. key] = value
			end
		end

		-- Annoying yes, but only way that works
		ShadowUF.Units:CheckPlayerZone(true)

		if( unit == "global" ) then
			globalVisibility[area .. key] = value
		end
	end

	local function get(info)
		local key = info[#(info)]
		local unit = info[#(info) - 1]
		local area = info[#(info) - 2]

		if( key == "enabled" ) then
			key = ""
		end

		if( unit == "global" ) then
			if( globalVisibility[area .. key] == false ) then
				return nil
			elseif( globalVisibility[area .. key] == nil ) then
				return false
			end

			return globalVisibility[area .. key]
		elseif( ShadowUF.db.profile.visibility[area][unit .. key] == false ) then
			return nil
		elseif( ShadowUF.db.profile.visibility[area][unit .. key] == nil ) then
			return false
		end

		return ShadowUF.db.profile.visibility[area][unit .. key]
	end

	local function getHelp(info)
		local unit = info[#(info) - 1]
		local area  = info[#(info) - 2]
		local key = info[#(info)]
		if( key == "enabled" ) then
			key = ""
		end

		local current
		if( unit == "global" ) then
			current = globalVisibility[area .. key]
		else
			current = ShadowUF.db.profile.visibility[area][unit .. key]
		end

		if( current == false ) then
			return string.format(L["Disabled in %s"], Config.const.AREA_NAMES[area])
		elseif( current == true ) then
			return string.format(L["Enabled in %s"], Config.const.AREA_NAMES[area])
		end

		return L["Using unit settings"]
	end

	local areaTable = {
		type = "group",
		order = function(info) return info[#(info)] == "none" and 2 or 1 end,
		childGroups = "tree",
		name = function(info)
			return Config.const.AREA_NAMES[info[#(info)]]
		end,
		get = get,
		set = set,
		args = {},
	}

	Config.visibilityTable = {
		type = "group",
		order = function(info) return info[#(info)] == "global" and 1 or (Config.getUnitOrder(info) + 1) end,
		name = function(info) return info[#(info)] == "global" and L["Global"] or Config.getName(info) end,
		args = {
			help = {
				order = 0,
				type = "group",
				name = L["Help"],
				inline = true,
				hidden = Config.hideBasicOption,
				args = {
					help = {
						order = 0,
						type = "description",
						name = function(info)
							return string.format(L["Disabling a module on this page disables it while inside %s. Do not disable a module here if you do not want this to happen!."], string.lower(Config.const.AREA_NAMES[info[2]]))
						end,
					},
				},
			},
			enabled = {
				order = 0.25,
				type = "toggle",
				name = function(info)
					local unit = info[#(info) - 1]
					if( unit == "global" ) then return "" end
					return string.format(L["%s frames"], L.units[unit])
				end,
				hidden = function(info) return info[#(info) - 1] == "global" end,
				desc = getHelp,
				tristate = true,
				width = "double",
			},
			sep = {
				order = 0.5,
				type = "description",
				name = "",
				width = "full",
				hidden = function(info) return info[#(info) - 1] == "global" end,
			},
		}
	}

	local moduleTable = {
		order = 1,
		type = "toggle",
		name = Config.getName,
		desc = getHelp,
		tristate = true,
		hidden = function(info)
			if( info[#(info) - 1] == "global" ) then return false end
			return Config.hideRestrictedOption(info)
		end,
		arg = 1,
	}

	for key, module in pairs(ShadowUF.modules) do
		if( module.moduleName ) then
			Config.visibilityTable.args[key] = moduleTable
		end
	end

	areaTable.args.global = Config.visibilityTable
	for _, unit in pairs(ShadowUF.unitList) do
		if( not unitBlacklist[unit] ) then
			areaTable.args[unit] = Config.visibilityTable
		end
	end

	return {
		type = "group",
		childGroups = "tab",
		name = L["Zone Configuration"],
		desc = Config.getPageDescription,
		args = {
			start = {
				order = 0,
				type = "group",
				name = L["Help"],
				inline = true,
				hidden = Config.hideBasicOption,
				args = {
					help = {
						order = 0,
						type = "description",
						name = L["Gold checkmark - Enabled in this zone / Grey checkmark - Disabled in this zone / No checkmark - Use the default unit settings"],
					},
				},
			},
			pvp = areaTable,
			arena = areaTable,
			party = areaTable,
			raid = areaTable,
		},
	}
end
