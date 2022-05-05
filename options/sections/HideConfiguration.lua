local L = ShadowUF.L
local Config = ShadowUF.Config
local _Config = ShadowUF.Config.private

function _Config:loadHideOptions()
	Config.hideTable = {
		order = function(info) return info[#(info)] == "buffs" and 1 or 2 end,
		type = "toggle",
		name = function(info)
			local key = info[#(info)]
			if( key == "arena" ) then return string.format(L["Hide %s frames"], "arena/battleground") end
			return L.units[key] and string.format(L["Hide %s frames"], string.lower(L.units[key])) or string.format(L["Hide %s"], key == "cast" and L["player cast bar"] or key == "playerPower" and L["player power frames"] or key == "buffs" and L["buff frames"] or key == "playerAltPower" and L["player alt. power"])
		end,
		set = function(info, value)
			Config.set(info, value)
			if( value ) then ShadowUF:HideBlizzardFrames() end
		end,
		hidden = false,
		get = Config.get,
		arg = "hidden.$key",
	}

	return {
		type = "group",
		name = L["Hide Blizzard"],
		desc = _Config.getPageDescription,
		args = {
			help = {
				order = 0,
				type = "group",
				name = L["Help"],
				inline = true,
				args = {
					description = {
						type = "description",
						name = L["You will need to do a /console reloadui before a hidden frame becomes visible again.|nPlayer and other unit frames are automatically hidden depending on if you enable the unit in Shadowed Unit Frames."],
						width = "full",
					},
				},
			},
			hide = {
				order = 1,
				type = "group",
				name = L["Frames"],
				inline = true,
				args = {
					buffs = Config.hideTable,
					cast = Config.hideTable,
					party = Config.hideTable,
					raid = Config.hideTable,
					player = Config.hideTable,
					pet = Config.hideTable,
					target = Config.hideTable,
					focus = Config.hideTable,
					boss = Config.hideTable,
				},
			},
		}
	}
end
