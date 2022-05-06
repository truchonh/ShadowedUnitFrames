local L = ShadowUF.L
local Config = ShadowUF.Config
local _Config = ShadowUF.Config.private

local unitCategories = {
	player = {"player", "pet"},
	general = {"target", "targettarget", "targettargettarget", "focus", "focustarget", "pettarget"},
	party = {"party", "partypet", "partytarget", "partytargettarget", "party"},
	raid = {"raid", "raidpet"},
	raidmisc = {"maintank", "maintanktarget", "maintanktargettarget", "mainassist", "mainassisttarget", "mainassisttargettarget"},
	boss = {"boss", "bosstarget", "bosstargettarget"},
	arena = {"arena", "arenapet", "arenatarget", "arenatargettarget"},
	battleground = {"battleground", "battlegroundpet", "battlegroundtarget", "battlegroundtargettarget"}
}

local UNIT_DESC = {
	["boss"] = L["Boss units are for only certain fights, such as Blood Princes or the Gunship battle, you will not see them for every boss fight."],
	["mainassist"] = L["Main Assists's are set by the Blizzard Main Assist system or mods that use it."],
	["maintank"] = L["Main Tank's are set through the Raid frames, or through selecting the Tank role."],
	["battleground"] = L["Currently used in battlegrounds for showing flag carriers."],
	["battlegroundpet"] = L["Current pet used by a battleground unit."],
	["battlegroundtarget"] = L["Current target of a battleground unit."],
	["battlegroundtargettarget"] = L["Current target of target of a battleground unit."]
}

local function getModuleOrder(info)
	local key = info[#(info)]
	return key == "healthBar" and 1 or key == "powerBar" and 2 or key == "castBar" and 3 or 4
end

function _Config:loadUnitOptions()
	local enableUnitsOptions, unitsOptions

	Config.AceDialog = Config.AceDialog or LibStub("AceConfigDialog-3.0")
	Config.AceRegistry = Config.AceRegistry or LibStub("AceConfigRegistry-3.0")

	-- This makes sure  we don't end up with any messed up positioning due to two different anchors being used
	local function fixPositions(info)
		local unit = info[2]
		local key = info[#(info)]

		if( key == "point" or key == "relativePoint" ) then
			ShadowUF.db.profile.positions[unit].anchorPoint = ""
			ShadowUF.db.profile.positions[unit].movedAnchor = nil
		elseif( key == "anchorPoint" ) then
			ShadowUF.db.profile.positions[unit].point = ""
			ShadowUF.db.profile.positions[unit].relativePoint = ""
		end

		-- Reset offset if it was a manually positioned frame, and it got anchored
		-- Why 100/-100 you ask? Because anything else requires some sort of logic applied to it
		-- and this means the frames won't directly overlap too which is a nice bonus
		if( key == "anchorTo" ) then
			ShadowUF.db.profile.positions[unit].x = 100
			ShadowUF.db.profile.positions[unit].y = -100
		end
	end

	-- Hide raid option in party config
	local function hideRaidOrAdvancedOption(info)
		if( info[2] == "party" and ShadowUF.db.profile.advanced ) then return false end

		return info[2] ~= "raid" and info[2] ~= "raidpet" and info[2] ~= "maintank" and info[2] ~= "mainassist"
	end

	local function hideRaidOption(info)
		return info[2] ~= "raid" and info[2] ~= "raidpet" and info[2] ~= "maintank" and info[2] ~= "mainassist"
	end

	local function hideSplitOrRaidOption(info)
		if( info[2] == "raid" and ShadowUF.db.profile.units.raid.frameSplit ) then
			return true
		end

		return hideRaidOption(info)
	end

	local function checkNumber(info, value)
		return tonumber(value)
	end

	local function setPosition(info, value)
		ShadowUF.db.profile.positions[info[2]][info[#(info)]] = value
		fixPositions(info)

		if( info[2] == "raid" or info[2] == "raidpet" or info[2] == "maintank" or info[2] == "mainassist" or info[2] == "party" or info[2] == "boss" or info[2] == "arena" ) then
			ShadowUF.Units:ReloadHeader(info[2])
		else
			ShadowUF.Layout:Reload(info[2])
		end
	end

	local function getPosition(info)
		return ShadowUF.db.profile.positions[info[2]][info[#(info)]]
	end

	local function setNumber(info, value)
		local unit = info[2]
		local key = info[#(info)]

		-- Apply effective scaling if it's anchored to UIParent
		if( ShadowUF.db.profile.positions[unit].anchorTo == "UIParent" ) then
			value = value * (ShadowUF.db.profile.units[unit].scale * UIParent:GetScale())
		end

		setPosition(info, tonumber(value))
	end

	local function getString(info)
		local unit = info[2]
		local key = info[#(info)]
		local id = unit .. key
		local coord = getPosition(info)

		-- If the frame is created and it's anchored to UIParent, will return the number modified by scale
		if( ShadowUF.db.profile.positions[unit].anchorTo == "UIParent" ) then
			coord = coord / (ShadowUF.db.profile.units[unit].scale * UIParent:GetScale())
		end

		-- OCD, most definitely.
		-- Pain to check coord == math.floor(coord) because floats are handled oddly with frames and return 0.99999999999435
		return string.gsub(string.format("%.2f", coord), "%.00$", "")
	end


	-- TAG WIZARD
	local tagWizard = {}
	Config.tagWizard = tagWizard
	do
		-- Load tag list
		Config.advanceTextTable = {
			order = 1,
			name = function(info) return Config.getVariable(info[2], "text", Config.private.quickIDMap[info[#(info)]], "name") end,
			type = "group",
			inline = true,
			hidden = function(info)
				if( not Config.getVariable(info[2], "text", nil, Config.private.quickIDMap[info[#(info)]]) ) then return true end
				return string.sub(Config.getVariable(info[2], "text", Config.private.quickIDMap[info[#(info)]], "anchorTo"), 2) ~= info[#(info) - 1]
			end,
			set = function(info, value)
				info.arg = string.format("text.%s.%s", Config.private.quickIDMap[info[#(info) - 1]], info[#(info)])
				Config.setUnit(info, value)
			end,
			get = function(info)
				info.arg = string.format("text.%s.%s", Config.private.quickIDMap[info[#(info) - 1]], info[#(info)])
				return Config.getUnit(info)
			end,
			args = {
				anchorPoint = {
					order = 1,
					type = "select",
					name = L["Anchor point"],
					values = {["LC"] = L["Left Center"], ["RT"] = L["Right Top"], ["RB"] = L["Right Bottom"], ["LT"] = L["Left Top"], ["LB"] = L["Left Bottom"], ["RC"] = L["Right Center"],["TRI"] = L["Inside Top Right"], ["TLI"] = L["Inside Top Left"], ["CLI"] = L["Inside Center Left"], ["C"] = L["Inside Center"], ["CRI"] = L["Inside Center Right"], ["TR"] = L["Top Right"], ["TL"] = L["Top Left"], ["BR"] = L["Bottom Right"], ["BL"] = L["Bottom Left"]},
					hidden = Config.hideAdvancedOption,
				},
				sep = {
					order = 2,
					type = "description",
					name = "",
					width = "full",
					hidden = Config.hideAdvancedOption,
				},
				width = {
					order = 3,
					name = L["Width weight"],
					desc = L["How much weight this should use when figuring out the total text width."],
					type = "range",
					min = 0, max = 10, step = 0.1,
					hidden = function(info)
						return Config.hideAdvancedOption(info) or Config.getVariable(info[2], "text", Config.private.quickIDMap[info[#(info) - 1]], "block")
					end,
				},
				size = {
					order = 4,
					name = L["Size"],
					desc = L["Let's you modify the base font size to either make it larger or smaller."],
					type = "range",
					min = -20, max = 20, step = 1, softMin = -5, softMax = 5,
					hidden = false,
				},
				sep2 = {
					order = 4.5,
					type = "description",
					name = "",
					width = "full",
					hidden = function(info)
						return Config.hideAdvancedOption(info) or not Config.getVariable(info[2], "text", Config.private.quickIDMap[info[#(info) - 1]], "block")
					end
				},
				x = {
					order = 5,
					type = "range",
					name = L["X Offset"],
					min = -1000, max = 1000, step = 1, softMin = -100, softMax = 100,
					hidden = false,
				},
				y = {
					order = 6,
					type = "range",
					name = L["Y Offset"],
					min = -1000, max = 1000, step = 1, softMin = -100, softMax = 100,
					hidden = false,
				},
			},
		}

		Config.parentTable = {
			order = 0,
			type = "group",
			name = function(info) return Config.getName(info) or string.sub(info[#(info)], 1) end,
			hidden = function(info) return not Config.getVariable(info[2], info[#(info)], nil, "enabled") end,
			args = {}
		}

		local function hideBlacklistedTag(info)
			local unit = info[2]
			local id = tonumber(info[#(info) - 2])
			local tag = info[#(info)]
			local cat = info[#(info) - 1]

			if( unit == "global" ) then
				for modUnit in pairs(Config.modifyUnits) do
					if( ShadowUF.Tags.unitRestrictions[tag] == modUnit ) then
						return false
					end
				end
			end

			if( ShadowUF.Tags.unitRestrictions[tag] and ShadowUF.Tags.unitRestrictions[tag] ~= unit ) then
				return true

			elseif( ShadowUF.Tags.anchorRestriction[tag] ) then
				if( ShadowUF.Tags.anchorRestriction[tag] ~= Config.getVariable(unit, "text", id, "anchorTo") ) then
					return true
				else
					return false
				end
			end

			return false
		end

		local function hideBlacklistedGroup(info)
			local unit = info[2]
			local id = tonumber(info[#(info) - 1])
			local tagGroup = info[#(info)]

			if( unit ~= "global" ) then
				if( ShadowUF.Tags.unitBlacklist[tagGroup] and string.match(unit, ShadowUF.Tags.unitBlacklist[tagGroup]) ) then
					return true
				end
			else
				-- If the only units that are in the global configuration have the tag filtered, then don't bother showing it
				for modUnit in pairs(Config.modifyUnits) do
					if( not ShadowUF.Tags.unitBlacklist[tagGroup] or not string.match(modUnit, ShadowUF.Tags.unitBlacklist[tagGroup]) ) then
						return false
					end
				end
			end

			local block = Config.getVariable(unit, "text", id, "block")
			if( ( block and tagGroup ~= "classtimer" ) or ( not block and tagGroup == "classtimer" ) ) then
				return true
			end

			return false
		end

		local savedTagTexts = {}
		local function selectTag(info, value)
			local unit = info[2]
			local id = tonumber(info[#(info) - 2])
			local tag = info[#(info)]
			local text = Config.getVariable(unit, "text", id, "text")

			if( value ) then
				if( unit == "global" ) then
					table.wipe(savedTagTexts)

					-- Set special tag texts based on the unit, so targettarget won't get a tag that will cause errors
					local tagGroup = ShadowUF.Tags.defaultCategories[tag]
					for modUnit in pairs(Config.modifyUnits) do
						savedTagTexts[modUnit] = Config.getVariable(modUnit, "text", id, "text")
						if( not ShadowUF.Tags.unitBlacklist[tagGroup] or not string.match(modUnit, ShadowUF.Tags.unitBlacklist[tagGroup]) ) then
							if( not ShadowUF.Tags.unitRestrictions[tag] or ShadowUF.Tags.unitRestrictions[tag] == modUnit ) then
								if( text == "" ) then
									savedTagTexts[modUnit] = string.format("[%s]", tag)
								else
									savedTagTexts[modUnit] = string.format("%s[( )%s]", savedTagTexts[modUnit], tag)
								end

								savedTagTexts.global = savedTagTexts[modUnit]
							end
						end
					end
				else
					if( text == "" ) then
						text = string.format("[%s]", tag)
					else
						text = string.format("%s[( )%s]", text, tag)
					end
				end

				-- Removing a tag from a single unit, super easy :<
			else
				-- Ugly, but it works
				for matchedTag in string.gmatch(text, "%[(.-)%]") do
					local safeTag = "[" .. matchedTag .. "]"
					if( string.match(safeTag, "%[" .. tag .. "%]") or string.match(safeTag, "%)" .. tag .. "%]") or string.match(safeTag, "%[" .. tag .. "%(") or string.match(safeTag, "%)" .. tag .. "%(") ) then
						text = string.gsub(text, "%[" .. string.gsub(string.gsub(matchedTag, "%)", "%%)"), "%(", "%%(") .. "%]", "")
						text = string.gsub(text, "  ", "")
						text = string.trim(text)
						break
					end
				end
			end

			if( unit == "global" ) then
				for modUnit in pairs(Config.modifyUnits) do
					if( savedTagTexts[modUnit] ) then
						Config.setVariable(modUnit, "text", id, "text", savedTagTexts[modUnit])
					end
				end

				Config.setVariable("global", "text", id, "text", savedTagTexts.global)
			else
				Config.setVariable(unit, "text", id, "text", text)
			end
		end

		local function getTag(info)
			local text = Config.getVariable(info[2], "text", tonumber(info[#(info) - 2]), "text")
			local tag = info[#(info)]

			-- FUN WITH PATTERN MATCHING
			if( string.match(text, "%[" .. tag .. "%]") or string.match(text, "%)" .. tag .. "%]") or string.match(text, "%[" .. tag .. "%(") or string.match(text, "%)" .. tag .. "%(") ) then
				return true
			end

			return false
		end

		Config.tagTextTable = {
			type = "group",
			name = function(info) return Config.getVariable(info[2], "text", nil, tonumber(info[#(info)])) and Config.getVariable(info[2], "text", tonumber(info[#(info)]), "name") or "" end,
			hidden = function(info)
				if( not Config.getVariable(info[2], "text", nil, tonumber(info[#(info)])) ) then return true end
				return string.sub(Config.getVariable(info[2], "text", tonumber(info[#(info)]), "anchorTo"), 2) ~= info[#(info) - 1] end,
			set = false,
			get = false,
			args = {
				text = {
					order = 0,
					type = "input",
					name = L["Text"],
					width = "full",
					hidden = false,
					set = function(info, value) Config.setUnit(info, string.gsub(value, "||", "|")) end,
					get = function(info) return string.gsub(Config.getUnit(info), "|", "||") end,
					arg = "text.$parent.text",
				},
			},
		}


		local function getCategoryOrder(info)
			return info[#(info)] == "health" and 1 or info[#(info)] == "power" and 2 or info[#(info)] == "misc" and 3 or 4
		end

		for _, cat in pairs(ShadowUF.Tags.defaultCategories) do
			Config.tagTextTable.args[cat] = Config.tagTextTable.args[cat] or {
				order = getCategoryOrder,
				type = "group",
				inline = true,
				name = Config.getName,
				hidden = hideBlacklistedGroup,
				set = selectTag,
				get = getTag,
				args = {},
			}
		end

		Config.tagTable = {
			order = 0,
			type = "toggle",
			hidden = hideBlacklistedTag,
			name = _Config.getTagName,
			desc = _Config.getTagHelp,
		}

		for tag in pairs(ShadowUF.Tags.defaultTags) do
			local category = ShadowUF.Tags.defaultCategories[tag] or "misc"
			Config.tagTextTable.args[category].args[tag] = Config.tagTable
		end

		for tag, data in pairs(ShadowUF.db.profile.tags) do
			local category = data.category or "misc"
			Config.tagTextTable.args[category].args[tag] = Config.tagTable
		end

		local parentList = {}
		for id, text in pairs(ShadowUF.db.profile.units.player.text) do
			if (text.anchorTo ~= "$runeBar" and text.anchorTo ~= "$staggerBar") then
				parentList[text.anchorTo] = parentList[text.anchorTo] or {}
				parentList[text.anchorTo][id] = text
			end
		end

		local nagityNagNagTable = {
			order = 0,
			type = "group",
			name = L["Help"],
			inline = true,
			hidden = false,
			args = {
				help = {
					order = 0,
					type = "description",
					name = L["Selecting a tag text from the left panel to change tags. Truncating width, sizing, and offsets can be done in the current panel."],
				},
			},
		}

		for parent, list in pairs(parentList) do
			parent = string.sub(parent, 2)
			tagWizard[parent] = Config.parentTable
			Config.parentTable.args.help = nagityNagNagTable

			for id in pairs(list) do
				tagWizard[parent].args[tostring(id)] = Config.tagTextTable
				tagWizard[parent].args[tostring(id) .. ":adv"] = Config.advanceTextTable

				Config.private.quickIDMap[tostring(id) .. ":adv"] = id
			end
		end
	end

	local function disableAnchoredTo(info)
		local auras = Config.getVariable(info[2], "auras", nil, info[#(info) - 2])

		return auras.anchorOn or not auras.enabled
	end

	local function disableSameAnchor(info)
		local buffs = Config.getVariable(info[2], "auras", nil, "buffs")
		local debuffs = Config.getVariable(info[2], "auras", nil, "debuffs")
		local anchor = buffs.enabled and buffs.prioritize and "buffs" or "debuffs"

		if( not Config.getVariable(info[2], "auras", info[#(info) - 2], "enabled") ) then
			return true
		end

		if( ( info[#(info)] == "x" or info[#(info)] == "y" ) and ( info[#(info) - 2] == "buffs" and buffs.anchorOn or info[#(info) - 2] == "debuffs" and debuffs.anchorOn ) ) then
			return true
		end

		if( anchor == info[#(info) - 2] or buffs.anchorOn or debuffs.anchorOn ) then
			return false
		end

		return buffs.anchorPoint == debuffs.anchorPoint
	end

	local defaultAuraList = {["BL"] = L["Bottom"], ["TL"] = L["Top"], ["LT"] = L["Left"], ["RT"] = L["Right"]}
	local advancedAuraList = {["BL"] = L["Bottom Left"], ["BR"] = L["Bottom Right"], ["TL"] = L["Top Left"], ["TR"] = L["Top Right"], ["RT"] = L["Right Top"], ["RB"] = L["Right Bottom"], ["LT"] = L["Left Top"], ["LB"] = L["Left Bottom"]}
	local function getAuraAnchors()
		return ShadowUF.db.profile.advanced and advancedAuraList or defaultAuraList
	end

	local function hideStealable(info)
		if( not ShadowUF.db.profile.advanced ) then return true end
		if( info[2] == "player" or info[2] == "pet" or info[#(info) - 2] == "debuffs" ) then return true end

		return false
	end

	local function hideBuffOption(info)
		return info[#(info) - 2] ~= "buffs"
	end

	local function hideDebuffOption(info)
		return info[#(info) - 2] ~= "debuffs"
	end

	local function reloadUnitAuras()
		for _, frame in pairs(ShadowUF.Units.unitFrames) do
			if( UnitExists(frame.unit) and frame.visibility.auras ) then
				ShadowUF.modules.auras:UpdateFilter(frame)
				frame:FullUpdate()
			end
		end
	end

	Config.auraTable = {
		type = "group",
		hidden = false,
		name = function(info) return info[#(info)] == "buffs" and L["Buffs"] or L["Debuffs"] end,
		order = function(info) return info[#(info)] == "buffs" and 1 or 2 end,
		disabled = false,
		args = {
			general = {
				type = "group",
				name = L["General"],
				order = 0,
				args = {
					enabled = {
						order = 1,
						type = "toggle",
						name = function(info) if( info[#(info) - 2] == "buffs" ) then return L["Enable buffs"] end return L["Enable debuffs"] end,
						disabled = false,
						width = "full",
						arg = "auras.$parentparent.enabled",
					},
					temporary = {
						order = 2,
						type = "toggle",
						name = L["Enable temporary enchants"],
						desc = L["Adds temporary enchants to the buffs for the player."],
						width = "full",
						hidden = function(info) return info[2] ~= "player" or info[#(info) - 2] ~= "buffs" end,
						disabled = function(info) return not Config.getVariable(info[2], "auras", "buffs", "enabled") end,
						arg = "auras.buffs.temporary",
					},
					approximateEnemyData = {
						order = 3,
						type = "toggle",
						name = L["Enable enemy buff tracking"],
						desc = L["Display enemy buffs using LibClassicDuration data."],
						width = "full",
						hidden = function(info) return info[2] ~= "target" or info[#(info) - 2] ~= "buffs" end,
						disabled = function(info) return not Config.getVariable(info[2], "auras", "buffs", "enabled") end,
						arg = "auras.buffs.approximateEnemyData",
					}
				}
			},
			filters = {
				type = "group",
				name = L["Filters"],
				order = 1,
				set = function(info, value)
					Config.getVariable(info[2], "auras", info[#(info) - 2], "show")[info[#(info)]] = value
					reloadUnitAuras()
				end,
				get = function(info)
					return Config.getVariable(info[2], "auras", info[#(info) - 2], "show")[info[#(info)]]
				end,
				args = {
					player = {
						order = 1,
						type = "toggle",
						name = L["Show your auras"],
						desc = L["Whether auras you casted should be shown"],
						width = "full"
					},
					raid = {
						order = 2,
						type = "toggle",
						name = function(info) return info[#(info) - 2] == "buffs" and L["Show castable on other auras"] or L["Show curable/removable auras"] end,
						desc = function(info) return info[#(info) - 2] == "buffs" and L["Whether to show buffs that you cannot cast."] or L["Whether to show any debuffs you can remove, cure or steal."] end,
						width = "full"
					},
					boss = {
						order = 3,
						type = "toggle",
						name = L["Show casted by boss"],
						desc = L["Whether to show any auras casted by the boss"],
						width = "full"
					},
					misc = {
						order = 5,
						type = "toggle",
						name = L["Show any other auras"],
						desc = L["Whether to show auras that do not fall into the above categories."],
						width = "full"
					},
					relevant = {
						order = 6,
						type = "toggle",
						name = L["Smart Friendly/Hostile Filter"],
						desc = L["Only apply the selected filters to buffs on friendly units and debuffs on hostile units, and otherwise show all auras."],
						width = "full"
					},
				}
			},
			display = {
				type = "group",
				name = L["Display"],
				order = 2,
				args = {
					prioritize = {
						order = 1,
						type = "toggle",
						name = L["Prioritize buffs"],
						desc = L["Show buffs before debuffs when sharing the same anchor point."],
						hidden = hideBuffOption,
						disabled = function(info)
							if( not Config.getVariable(info[2], "auras", info[#(info) - 2], "enabled") ) then return true end

							local buffs = Config.getVariable(info[2], "auras", nil, "buffs")
							local debuffs = Config.getVariable(info[2], "auras", nil, "debuffs")

							return buffs.anchorOn or debuffs.anchorOn or buffs.anchorPoint ~= debuffs.anchorPoint
						end,
						arg = "auras.$parentparent.prioritize"
					},
					sep1 = {order = 1.5, type = "description", name = "", width = "full"},
					selfScale = {
						order = 2,
						type = "range",
						name = L["Scaled aura size"],
						desc = L["Scale for auras that you casted or can Spellsteal, any number above 100% is bigger than default, any number below 100% is smaller than default."],
						min = 1, max = 3, step = 0.10,
						isPercent = true,
						hidden = Config.hideAdvancedOption,
						arg = "auras.$parentparent.selfScale",
					},
					sep12 = {order = 2.5, type = "description", name = "", width = "full"},
					timers = {
						order = 3,
						type = "multiselect",
						name = L["Cooldown rings for"],
						desc = L["When to show cooldown rings on auras"],
						hidden = Config.hideAdvancedOption,
						values = function(info)
							local tbl = {["ALL"] = L["All Auras"], ["SELF"] = L["Your Auras"]}
							local type = info[#(info) - 2]
							if( type == "debuffs" ) then
								tbl["BOSS"] = L["Boss Debuffs"]
							end

							return tbl;
						end,
						set = function(info, key, value)
							local tbl = Config.getVariable(info[2], "auras", info[#(info) - 2], "timers")
							if( key == "ALL" and value ) then
								tbl = {["ALL"] = true}
							elseif( key ~= "ALL" and value ) then
								tbl["ALL"] = nil
								tbl[key] = value
							else
								tbl[key] = value
							end

							Config.setVariable(info[2], "auras", info[#(info) - 2], "timers", tbl)
							reloadUnitAuras()
						end,
						get = function(info, key)
							return Config.getVariable(info[2], "auras", info[#(info) - 2], "timers")[key]
						end
					},
					sep3 = {order = 3.5, type = "description", name = "", width = "full"},
					enlarge = {
						order = 4,
						type = "multiselect",
						name = L["Enlarge auras for"],
						desc = L["What type of auras should be enlarged, use the scaled aura size option to change the size."],
						values = function(info)
							local tbl = {["SELF"] = L["Your Auras"]}
							local type = info[#(info) - 2]
							if( type == "debuffs" ) then
								tbl["BOSS"] = L["Boss Debuffs"]
							end

							if( type == "debuffs" ) then
								tbl["REMOVABLE"] = L["Curable"]
							elseif( info[2] ~= "player" and info[2] ~= "pet" and info[2] ~= "party" and info[2] ~= "raid" and type == "buffs" ) then
								tbl["REMOVABLE"] = L["Dispellable/Stealable"]
							end

							return tbl;
						end,
						set = function(info, key, value)
							local tbl = Config.getVariable(info[2], "auras", info[#(info) - 2], "enlarge")
							tbl[key] = value

							Config.setVariable(info[2], "auras", info[#(info) - 2], "enlarge", tbl)
							reloadUnitAuras()
						end,
						get = function(info, key)
							return Config.getVariable(info[2], "auras", info[#(info) - 2], "enlarge")[key]
						end
					}
				}
			},
			positioning = {
				type = "group",
				name = L["Positioning"],
				order = 3,
				args = {
					anchorOn = {
						order = 1,
						type = "toggle",
						name = function(info) return info[#(info) - 2] == "buffs" and L["Anchor to debuffs"] or L["Anchor to buffs"] end,
						desc = L["Allows you to anchor the aura group to another, you can then choose where it will be anchored using the position.|n|nUse this if you want to duplicate the default ui style where buffs and debuffs are separate groups."],
						set = function(info, value)
							Config.setVariable(info[2], "auras", info[#(info) - 2] == "buffs" and "debuffs" or "buffs", "anchorOn", false)
							Config.setUnit(info, value)
						end,
						width = "full",
						arg = "auras.$parentparent.anchorOn",
					},
					anchorPoint = {
						order = 1.5,
						type = "select",
						name = L["Position"],
						desc = L["How you want this aura to be anchored to the unit frame."],
						values = getAuraAnchors,
						disabled = disableAnchoredTo,
						arg = "auras.$parentparent.anchorPoint",
					},
					size = {
						order = 2,
						type = "range",
						name = L["Icon Size"],
						min = 1, max = 30, step = 1,
						arg = "auras.$parentparent.size",
					},
					sep1 = {order = 3, type = "description", name = "", width = "full"},
					perRow = {
						order = 13,
						type = "range",
						name = function(info)
							local anchorPoint = Config.getVariable(info[2], "auras", info[#(info) - 2], "anchorPoint")
							if( ShadowUF.Layout:GetColumnGrowth(anchorPoint) == "LEFT" or ShadowUF.Layout:GetColumnGrowth(anchorPoint) == "RIGHT" ) then
								return L["Per column"]
							end

							return L["Per row"]
						end,
						desc = L["How many auras to show in a single row."],
						min = 1, max = 100, step = 1, softMin = 1, softMax = 50,
						disabled = disableSameAnchor,
						arg = "auras.$parentparent.perRow",
					},
					maxRows = {
						order = 14,
						type = "range",
						name = L["Max rows"],
						desc = L["How many rows total should be used, rows will be however long the per row value is set at."],
						min = 1, max = 10, step = 1, softMin = 1, softMax = 5,
						disabled = disableSameAnchor,
						hidden = function(info)
							local anchorPoint = Config.getVariable(info[2], "auras", info[#(info) - 2], "anchorPoint")
							if( ShadowUF.Layout:GetColumnGrowth(anchorPoint) == "LEFT" or ShadowUF.Layout:GetColumnGrowth(anchorPoint) == "RIGHT" ) then
								return true
							end

							return false
						end,
						arg = "auras.$parentparent.maxRows",
					},
					maxColumns = {
						order = 14,
						type = "range",
						name = L["Max columns"],
						desc = L["How many auras per a column for example, entering two her will create two rows that are filled up to whatever per row is set as."],
						min = 1, max = 100, step = 1, softMin = 1, softMax = 50,
						hidden = function(info)
							local anchorPoint = Config.getVariable(info[2], "auras", info[#(info) - 2], "anchorPoint")
							if( ShadowUF.Layout:GetColumnGrowth(anchorPoint) == "LEFT" or ShadowUF.Layout:GetColumnGrowth(anchorPoint) == "RIGHT" ) then
								return false
							end

							return true
						end,
						disabled = disableSameAnchor,
						arg = "auras.$parentparent.maxRows",
					},
					x = {
						order = 18,
						type = "range",
						name = L["X Offset"],
						min = -1000, max = 1000, step = 1, softMin = -100, softMax = 100,
						disabled = disableSameAnchor,
						hidden = Config.hideAdvancedOption,
						arg = "auras.$parentparent.x",
					},
					y = {
						order = 19,
						type = "range",
						name = L["Y Offset"],
						min = -1000, max = 1000, step = 1, softMin = -100, softMax = 100,
						disabled = disableSameAnchor,
						hidden = Config.hideAdvancedOption,
						arg = "auras.$parentparent.y",
					},

				}
			}
		}
	}

	local function hideBarOption(info)
		local module = info[#(info) - 1]
		if( ShadowUF.modules[module].moduleHasBar or Config.getVariable(info[2], module, nil, "isBar") ) then
			return false
		end

		return true
	end

	Config.barTable = {
		order = getModuleOrder,
		name = Config.getName,
		type = "group",
		inline = false,
		hidden = function(info) return Config.hideRestrictedOption(info) or not Config.getVariable(info[2], info[#(info)], nil, "enabled") end,
		args = {
			enableBar = {
				order = 1,
				type = "toggle",
				name = L["Show as bar"],
				desc = L["Turns this widget into a bar that can be resized and ordered just like health and power bars."],
				hidden = function(info) return ShadowUF.modules[info[#(info) - 1]].moduleHasBar end,
				arg = "$parent.isBar",
			},
			sep1 = {order = 1.25, type = "description", name = "", hidden = function(info) return (info[#(info) - 1] ~= "burningEmbersBar" or not Config.getVariable(info[2], info[#(info) - 1], nil, "backgroundColor") or not Config.getVariable(info[2], info[#(info) - 1], nil, "background")) end},
			background = {
				order = 1.5,
				type = "toggle",
				name = L["Show background"],
				desc = L["Show a background behind the bars with the same texture/color but faded out."],
				hidden = hideBarOption,
				arg = "$parent.background",
			},
			sep2 = {order = 1.55, type = "description", name = "", hidden = function(info) return not (not ShadowUF.modules[info[#(info) - 1]] or not ShadowUF.db.profile.advanced or ShadowUF.modules[info[#(info) - 1]].isComboPoints) end},
			overrideBackground = {
				order = 1.6,
				type = "toggle",
				name = L["Override background"],
				desc = L["Show a background behind the bars with the same texture/color but faded out."],
				disabled = function(info) return not Config.getVariable(info[2], info[#(info) - 1], nil, "background") end,
				hidden = function(info) return info[#(info) - 1] ~= "burningEmbersBar" end,
				set = function(info, toggle)
					if( toggle ) then
						Config.setVariable(info[2], info[#(info) - 1], nil, "backgroundColor", {r = 0, g = 0, b = 0, a = 0.70})
					else
						Config.setVariable(info[2], info[#(info) - 1], nil, "backgroundColor", nil)
					end
				end,
				get = function(info)
					return not not Config.getVariable(info[2], info[#(info) - 1], nil, "backgroundColor")
				end
			},
			overrideColor = {
				order = 1.65,
				type = "color",
				hasAlpha = true,
				name = L["Background color"],
				hidden = function(info) return info[#(info) - 1] ~= "burningEmbersBar" or not Config.getVariable(info[2], info[#(info) - 1], nil, "backgroundColor") or not Config.getVariable(info[2], info[#(info) - 1], nil, "background") end,
				set = function(info, r, g, b, a)
					local color = Config.getUnit(info) or {}
					color.r = r
					color.g = g
					color.b = b
					color.a = a

					Config.setUnit(info, color)
				end,
				get = function(info)
					local color = Config.getUnit(info)
					if( not color ) then
						return 0, 0, 0, 1
					end

					return color.r, color.g, color.b, color.a

				end,
				arg = "$parent.backgroundColor",
			},
			vertical = {
				order = 1.70,
				type = "toggle",
				name = L["Vertical growth"],
				desc = L["Rather than bars filling from left -> right, they will fill from bottom -> top."],
				arg = "$parent.vertical",
				hidden = function(info) return not ShadowUF.db.profile.advanced or ShadowUF.modules[info[#(info) - 1]].isComboPoints end,
			},
			reverse = {
				order = 1.71,
				type = "toggle",
				name = L["Reverse fill"],
				desc = L["Will fill right -> left when using horizontal growth, or top -> bottom when using vertical growth."],
				arg = "$parent.reverse",
				hidden = function(info) return not ShadowUF.db.profile.advanced or ShadowUF.modules[info[#(info) - 1]].isComboPoints end,
			},
			invert = {
				order = 2,
				type = "toggle",
				name = L["Invert colors"],
				desc = L["Flips coloring so the bar color is shown as the background color and the background as the bar"],
				hidden = function(info) return not ShadowUF.modules[info[#(info) - 1]] or not ShadowUF.db.profile.advanced or ShadowUF.modules[info[#(info) - 1]].isComboPoints end,
				arg = "$parent.invert",
			},
			sep3 = {order = 3, type = "description", name = "", hidden = function(info) return not ShadowUF.modules[info[#(info) - 1]] or not ShadowUF.db.profile.advanced or ShadowUF.modules[info[#(info) - 1]].isComboPoints end,},
			order = {
				order = 4,
				type = "range",
				name = L["Order"],
				min = 0, max = 100, step = 5,
				hidden = hideBarOption,
				arg = "$parent.order",
			},
			height = {
				order = 5,
				type = "range",
				name = L["Height"],
				desc = L["How much of the frames total height this bar should get, this is a weighted value, the higher it is the more it gets."],
				min = 0, max = 10, step = 0.1,
				hidden = hideBarOption,
				arg = "$parent.height",
			}
		},
	}

	Config.indicatorTable = {
		order = 0,
		name = function(info)
			if( info[#(info)] == "status" and info[2] == "player" ) then
				return L["Combat/resting status"]
			end

			return Config.getName(info)
		end,
		desc = function(info) return Config.const.INDICATOR_DESC[info[#(info)]] end,
		type = "group",
		hidden = Config.hideRestrictedOption,
		args = {
			enabled = {
				order = 0,
				type = "toggle",
				name = L["Enable indicator"],
				hidden = false,
				arg = "indicators.$parent.enabled",
			},
			sep1 = {
				order = 1,
				type = "description",
				name = "",
				width = "full",
				hidden = function() return not ShadowUF.db.profile.advanced end,
			},
			anchorPoint = {
				order = 2,
				type = "select",
				name = L["Anchor point"],
				values = Config.const.positionList,
				hidden = false,
				arg = "indicators.$parent.anchorPoint",
			},
			size = {
				order = 4,
				type = "range",
				name = L["Size"],
				min = 1, max = 40, step = 1,
				hidden = Config.hideAdvancedOption,
				arg = "indicators.$parent.size",
			},
			x = {
				order = 5,
				type = "range",
				name = L["X Offset"],
				min = -100, max = 100, step = 1, softMin = -50, softMax = 50,
				hidden = false,
				arg = "indicators.$parent.x",
			},
			y = {
				order = 6,
				type = "range",
				name = L["Y Offset"],
				min = -100, max = 100, step = 1, softMin = -50, softMax = 50,
				hidden = false,
				arg = "indicators.$parent.y",
			},
		},
	}

	Config.unitTable = {
		type = "group",
		childGroups = "tab",
		order = Config.getUnitOrder,
		name = Config.getName,
		hidden = Config.isUnitDisabled,
		args = {
			general = {
				order = 1,
				name = L["General"],
				type = "group",
				hidden = Config.isModifiersSet,
				set = Config.setUnit,
				get = Config.getUnit,
				args = {
					portrait = {
						order = 2,
						type = "group",
						inline = true,
						hidden = false,
						name = L["Portrait"],
						args = {
							portrait = {
								order = 0,
								type = "toggle",
								name = string.format(L["Enable %s"], L["Portrait"]),
								arg = "portrait.enabled",
							},
							portraitType = {
								order = 1,
								type = "select",
								name = L["Portrait type"],
								values = {["class"] = L["Class icon"], ["2D"] = L["2D"], ["3D"] = L["3D"]},
								arg = "portrait.type",
							},
							alignment = {
								order = 2,
								type = "select",
								name = L["Position"],
								values = {["LEFT"] = L["Left"], ["RIGHT"] = L["Right"]},
								arg = "portrait.alignment",
							},
						},
					},
					fader = {
						order = 3,
						type = "group",
						inline = true,
						name = L["Combat fader"],
						hidden = Config.hideRestrictedOption,
						args = {
							fader = {
								order = 0,
								type = "toggle",
								name = string.format(L["Enable %s"], L["Combat fader"]),
								desc = L["Combat fader will fade out all your frames while they are inactive and fade them back in once you are in combat or active."],
								hidden = false,
								arg = "fader.enabled"
							},
							combatAlpha = {
								order = 1,
								type = "range",
								name = L["Combat alpha"],
								desc = L["Frame alpha while this unit is in combat."],
								min = 0, max = 1.0, step = 0.1,
								arg = "fader.combatAlpha",
								hidden = false,
								isPercent = true,
							},
							inactiveAlpha = {
								order = 2,
								type = "range",
								name = L["Inactive alpha"],
								desc = L["Frame alpha when you are out of combat while having no target and 100% mana or energy."],
								min = 0, max = 1.0, step = 0.1,
								arg = "fader.inactiveAlpha",
								hidden = false,
								isPercent = true,
							},
						}
					},
					range = {
						order = 3,
						type = "group",
						inline = true,
						name = L["Range indicator"],
						hidden = Config.hideRestrictedOption,
						args = {
							fader = {
								order = 0,
								type = "toggle",
								name = string.format(L["Enable %s"], L["Range indicator"]),
								desc = L["Fades out the unit frames of people who are not within range of you."],
								arg = "range.enabled",
								hidden = false,
							},
							inAlpha = {
								order = 1,
								type = "range",
								name = L["In range alpha"],
								desc = L["Frame alpha while this unit is in combat."],
								min = 0, max = 1.0, step = 0.05,
								arg = "range.inAlpha",
								hidden = false,
								isPercent = true,
							},
							oorAlpha = {
								order = 2,
								type = "range",
								name = L["Out of range alpha"],
								min = 0, max = 1.0, step = 0.05,
								arg = "range.oorAlpha",
								hidden = false,
								isPercent = true,
							},
						}
					},
					highlight = {
						order = 3.5,
						type = "group",
						inline = true,
						name = L["Border highlighting"],
						hidden = Config.hideRestrictedOption,
						args = {
							mouseover = {
								order = 3,
								type = "toggle",
								name = L["On mouseover"],
								desc = L["Highlight units when you mouse over them."],
								arg = "highlight.mouseover",
								hidden = false,
							},
							attention = {
								order = 4,
								type = "toggle",
								name = L["For target/focus"],
								desc = L["Highlight units that you are targeting or have focused."],
								arg = "highlight.attention",
								hidden = function(info) return info[2] == "target" or info[2] == "focus" end,
							},
							aggro = {
								order = 5,
								type = "toggle",
								name = L["On aggro"],
								desc = L["Highlight units that have aggro on any mob."],
								arg = "highlight.aggro",
								hidden = function(info) return ShadowUF.Units.zoneUnits[info[2]] or info[2] == "battlegroundpet" or info[2] == "arenapet" or ShadowUF.fakeUnits[info[2]] end,
							},
							debuff = {
								order = 6,
								type = "toggle",
								name = L["On curable debuff"],
								desc = L["Highlight units that are debuffed with something you can cure."],
								arg = "highlight.debuff",
								hidden = function(info) return info[2] ~= "boss" and ( ShadowUF.Units.zoneUnits[info[2]] or info[2] == "battlegroundpet" or info[2] == "arenapet" ) end,
							},
							raremob = {
								order = 6.10,
								type = "toggle",
								name = L["On rare mobs"],
								desc = L["Highlight units that are rare."],
								arg = "highlight.rareMob",
								hidden = function(info) return not (info[2] == "target" or info[2] == "targettarget" or info[2] == "focus" or info[2] == "focustarget") end,
							},
							elitemob = {
								order = 6.15,
								type = "toggle",
								name = L["On elite mobs"],
								desc = L["Highlight units that are "],
								arg = "highlight.eliteMob",
								hidden = function(info) return not (info[2] == "target" or info[2] == "targettarget" or info[2] == "focus" or info[2] == "focustarget") end,
							},
							sep = {
								order = 6.5,
								type = "description",
								name = "",
								width = "full",
								hidden = function(info) return not (ShadowUF.Units.zoneUnits[info[2]] or info[2] == "battlegroundpet" or info[2] == "arenapet" or ShadowUF.fakeUnits[info[2]]) and not (info[2] == "target" or info[2] == "targettarget" or info[2] == "focus" or info[2] == "focustarget") end,
							},
							alpha = {
								order = 7,
								type = "range",
								name = L["Border alpha"],
								min = 0, max = 1, step = 0.05,
								isPercent = true,
								hidden = false,
								arg = "highlight.alpha",
							},
							size = {
								order = 8,
								type = "range",
								name = L["Border thickness"],
								min = 0, max = 50, step = 1,
								arg = "highlight.size",
								hidden = false,
							},
						},
					},

					-- COMBO POINTS
					barComboPoints = {
						order = 4,
						type = "group",
						inline = true,
						name = L["Combo points"],
						hidden = function(info) return not Config.getVariable(info[2], "comboPoints", nil, "isBar") or not Config.getVariable(info[2], nil, nil, "comboPoints") end,
						args = {
							enabled = {
								order = 1,
								type = "toggle",
								name = string.format(L["Enable %s"], L["Combo points"]),
								hidden = false,
								arg = "comboPoints.enabled",
							},
							growth = {
								order = 2,
								type = "select",
								name = L["Growth"],
								values = {["LEFT"] = L["Left"], ["RIGHT"] = L["Right"]},
								hidden = false,
								arg = "comboPoints.growth",
							},
							showAlways = {
								order = 3,
								type = "toggle",
								name = L["Don't hide when empty"],
								hidden = false,
								arg = "comboPoints.showAlways",
							},
						},
					},
					comboPoints = {
						order = 4,
						type = "group",
						inline = true,
						name = L["Combo points"],
						hidden = function(info) if( info[2] == "global" or Config.getVariable(info[2], "comboPoints", nil, "isBar") ) then return true end return Config.hideRestrictedOption(info) end,
						args = {
							enabled = {
								order = 0,
								type = "toggle",
								name = string.format(L["Enable %s"], L["Combo points"]),
								hidden = false,
								arg = "comboPoints.enabled",
							},
							sep1 = {
								order = 1,
								type = "description",
								name = "",
								width = "full",
								hidden = Config.hideAdvancedOption,
							},
							growth = {
								order = 2,
								type = "select",
								name = L["Growth"],
								values = {["UP"] = L["Up"], ["LEFT"] = L["Left"], ["RIGHT"] = L["Right"], ["DOWN"] = L["Down"]},
								hidden = false,
								arg = "comboPoints.growth",
							},
							size = {
								order = 2,
								type = "range",
								name = L["Size"],
								min = 0, max = 50, step = 1, softMin = 0, softMax = 20,
								hidden = Config.hideAdvancedOption,
								arg = "comboPoints.size",
							},
							spacing = {
								order = 3,
								type = "range",
								name = L["Spacing"],
								min = -30, max = 30, step = 1, softMin = -15, softMax = 15,
								hidden = Config.hideAdvancedOption,
								arg = "comboPoints.spacing",
							},
							sep2 = {
								order = 4,
								type = "description",
								name = "",
								width = "full",
								hidden = Config.hideAdvancedOption,
							},
							anchorPoint = {
								order = 5,
								type = "select",
								name = L["Anchor point"],
								values = Config.const.positionList,
								hidden = false,
								arg = "comboPoints.anchorPoint",
							},
							x = {
								order = 6,
								type = "range",
								name = L["X Offset"],
								min = -30, max = 30, step = 1,
								hidden = false,
								arg = "comboPoints.x",
							},
							y = {
								order = 7,
								type = "range",
								name = L["Y Offset"],
								min = -30, max = 30, step = 1,
								hidden = false,
								arg = "comboPoints.y",
							},
						},
					},
					combatText = {
						order = 5,
						type = "group",
						inline = true,
						name = L["Combat text"],
						hidden = Config.hideRestrictedOption,
						args = {
							combatText = {
								order = 0,
								type = "toggle",
								name = string.format(L["Enable %s"], L["Combat text"]),
								desc = L["Shows combat feedback, last healing the unit received, last hit did it miss, resist, dodged and so on."],
								arg = "combatText.enabled",
								hidden = false,
							},
							sep = {
								order = 1,
								type = "description",
								name = "",
								width = "full",
								hidden = Config.hideAdvancedOption,
							},
							anchorPoint = {
								order = 3,
								type = "select",
								name = L["Anchor point"],
								values = Config.const.positionList,
								arg = "combatText.anchorPoint",
								hidden = Config.hideAdvancedOption,
							},
							x = {
								order = 4,
								type = "range",
								name = L["X Offset"],
								min = -50, max = 50, step = 1,
								arg = "combatText.x",
								hidden = Config.hideAdvancedOption,
							},
							y = {
								order = 5,
								type = "range",
								name = L["Y Offset"],
								min = -50, max = 50, step = 1,
								arg = "combatText.y",
								hidden = Config.hideAdvancedOption,
							},
						},
					},
				},
			},
			attributes = {
				order = 1.5,
				type = "group",
				name = function(info)
					return L.shortUnits[info[#(info) - 1]] or L.units[info[#(info) - 1]]
				end,
				hidden = function(info)
					local unit = info[#(info) - 1]
					return unit ~= "raid" and unit ~= "raidpet" and unit ~= "party" and unit ~= "mainassist" and unit ~= "maintank" and not ShadowUF.Units.zoneUnits[unit]
				end,
				set = function(info, value)
					Config.setUnit(info, value)

					ShadowUF.Units:ReloadHeader(info[2])
					ShadowUF.modules.movers:Update()
				end,
				get = Config.getUnit,
				args = {
					show = {
						order = 0.5,
						type = "group",
						inline = true,
						name = L["Visibility"],
						hidden = function(info) return info[2] ~= "party" and info[2] ~= "raid" end,
						args = {
							showPlayer = {
								order = 0,
								type = "toggle",
								name = L["Show player in party"],
								desc = L["The player frame will not be hidden regardless, you will have to manually disable it either entirely or per zone type."],
								hidden = function(info) return info[2] ~= "party" end,
								arg = "showPlayer",
							},
							hideSemiRaidParty = {
								order = 1,
								type = "toggle",
								name = L["Hide in >5-man raids"],
								desc = L["Party frames are hidden while in a raid group with more than 5 people inside."],
								hidden = function(info) return info[2] ~= "party" end,
								set = function(info, value)
									if( value ) then
										Config.setVariable(info[2], nil, nil, "hideAnyRaid", false)
									end

									Config.setVariable(info[2], nil, nil, "hideSemiRaid", value)
									ShadowUF.Units:ReloadHeader(info[#(info) - 3])
								end,
								arg = "hideSemiRaid",
							},
							hideRaid = {
								order = 2,
								type = "toggle",
								name = L["Hide in any raid"],
								desc = L["Party frames are hidden while in any sort of raid no matter how many people."],
								hidden = function(info) return info[2] ~= "party" end,
								set = function(info, value)
									if( value ) then
										Config.setVariable(info[2], nil, nil, "hideSemiRaid", false)
									end

									Config.setVariable(info[2], nil, nil, "hideAnyRaid", value)
									ShadowUF.Units:ReloadHeader(info[#(info) - 3])
								end,
								arg = "hideAnyRaid",
							},
							separateFrames = {
								order = 3,
								type = "toggle",
								name = L["Separate raid frames"],
								desc = L["Splits raid frames into individual frames for each raid group instead of one single frame.|nNOTE! You cannot drag each group frame individualy, but how they grow is set through the column and row growth options."],
								hidden = function(info) return info[2] ~= "raid" end,
								arg = "frameSplit",
							},
							hideSemiRaidRaid = {
								order = 3.5,
								type = "toggle",
								name = L["Hide in <=5-man raids"],
								desc = L["Raid frames are hidden while in a raid group with 5 or less people inside."],
								hidden = function(info) return info[2] ~= "raid" end,
								set = function(info, value)
									Config.setVariable(info[2], nil, nil, "hideSemiRaid", value)
									ShadowUF.Units:ReloadHeader(info[#(info) - 3])
								end,
								arg = "hideSemiRaid"
							},
							showInRaid = {
								order = 4,
								type = "toggle",
								name = L["Show party as raid"],
								hidden = hideRaidOption,
								set = function(info, value)
									Config.setUnit(info, value)

									ShadowUF.Units:ReloadHeader("party")
									ShadowUF.Units:ReloadHeader("raid")
									ShadowUF.modules.movers:Update()
								end,
								arg = "showParty",
							},
						},
					},
					general = {
						order = 1,
						type = "group",
						inline = true,
						name = L["General"],
						hidden = false,
						args = {
							offset = {
								order = 2,
								type = "range",
								name = L["Row offset"],
								desc = L["Spacing between each row"],
								min = -10, max = 100, step = 1,
								arg = "offset",
							},
							attribPoint = {
								order = 3,
								type = "select",
								name = L["Row growth"],
								desc = L["How the rows should grow when new group members are added."],
								values = {["TOP"] = L["Down"], ["BOTTOM"] = L["Up"], ["LEFT"] = L["Right"], ["RIGHT"] = L["Left"]},
								arg = "attribPoint",
								set = function(info, value)
									-- If you set the frames to grow left, the columns have to grow down or up as well
									local attribAnchorPoint = Config.getVariable(info[2], nil, nil, "attribAnchorPoint")
									if( ( value == "LEFT" or value == "RIGHT" ) and attribAnchorPoint ~= "BOTTOM" and attribAnchorPoint ~= "TOP" ) then
										ShadowUF.db.profile.units[info[2]].attribAnchorPoint = "BOTTOM"
									elseif( ( value == "TOP" or value == "BOTTOM" ) and attribAnchorPoint ~= "LEFT" and attribAnchorPoint ~= "RIGHT" ) then
										ShadowUF.db.profile.units[info[2]].attribAnchorPoint = "RIGHT"
									end

									Config.setUnit(info, value)

									local position = ShadowUF.db.profile.positions[info[2]]
									if( position.top and position.bottom ) then
										local point = ShadowUF.db.profile.units[info[2]].attribAnchorPoint == "RIGHT" and "RIGHT" or "LEFT"
										position.point = (ShadowUF.db.profile.units[info[2]].attribPoint == "BOTTOM" and "BOTTOM" or "TOP") .. point
										position.y = ShadowUF.db.profile.units[info[2]].attribPoint == "BOTTOM" and position.bottom or position.top
									end

									ShadowUF.Units:ReloadHeader(info[2])
									ShadowUF.modules.movers:Update()
								end,
							},
							sep2 = {
								order = 4,
								type = "description",
								name = "",
								width = "full",
								hidden = false,
							},
							columnSpacing = {
								order = 5,
								type = "range",
								name = L["Column spacing"],
								min = -30, max = 100, step = 1,
								hidden = hideRaidOrAdvancedOption,
								arg = "columnSpacing",
							},
							attribAnchorPoint = {
								order = 6,
								type = "select",
								name = L["Column growth"],
								desc = L["How the frames should grow when a new column is added."],
								values = function(info)
									local attribPoint = Config.getVariable(info[2], nil, nil, "attribPoint")
									if( attribPoint == "LEFT" or attribPoint == "RIGHT" ) then
										return {["TOP"] = L["Down"], ["BOTTOM"] = L["Up"]}
									end

									return {["LEFT"] = L["Right"], ["RIGHT"] = L["Left"]}
								end,
								hidden = hideRaidOrAdvancedOption,
								set = function(info, value)
									-- If you set the frames to grow left, the columns have to grow down or up as well
									local attribPoint = Config.getVariable(info[2], nil, nil, "attribPoint")
									if( ( value == "LEFT" or value == "RIGHT" ) and attribPoint ~= "BOTTOM" and attribPoint ~= "TOP" ) then
										ShadowUF.db.profile.units[info[2]].attribPoint = "BOTTOM"
									end

									Config.setUnit(info, value)

									ShadowUF.Units:ReloadHeader(info[2])
									ShadowUF.modules.movers:Update()
								end,
								arg = "attribAnchorPoint",
							},
							sep3 = {
								order = 7,
								type = "description",
								name = "",
								width = "full",
								hidden = false,
							},
							maxColumns = {
								order = 8,
								type = "range",
								name = L["Max columns"],
								min = 1, max = 20, step = 1,
								arg = "maxColumns",
								hidden = function(info) return ShadowUF.Units.zoneUnits[info[2]] or hideSplitOrRaidOption(info) end,
							},
							unitsPerColumn = {
								order = 8,
								type = "range",
								name = L["Units per column"],
								min = 1, max = 40, step = 1,
								arg = "unitsPerColumn",
								hidden = function(info) return ShadowUF.Units.zoneUnits[info[2]] or hideSplitOrRaidOption(info) end,
							},
							partyPerColumn = {
								order = 9,
								type = "range",
								name = L["Units per column"],
								min = 1, max = 5, step = 1,
								arg = "unitsPerColumn",
								hidden = function(info) return info[2] ~= "party" or not ShadowUF.db.profile.advanced end,
							},
							groupsPerRow = {
								order = 8,
								type = "range",
								name = L["Groups per row"],
								desc = L["How many groups should be shown per row."],
								min = 1, max = 8, step = 1,
								arg = "groupsPerRow",
								hidden = function(info) return info[2] ~= "raid" or not ShadowUF.db.profile.units.raid.frameSplit end,
							},
							groupSpacing = {
								order = 9,
								type = "range",
								name = L["Group row spacing"],
								desc = L["How much spacing should be between each new row of groups."],
								min = -50, max = 50, step = 1,
								arg = "groupSpacing",
								hidden = function(info) return info[2] ~= "raid" or not ShadowUF.db.profile.units.raid.frameSplit end,
							},
						},
					},
					sort = {
						order = 2,
						type = "group",
						inline = true,
						name = L["Sorting"],
						hidden = function(info) return ShadowUF.Units.zoneUnits[info[2]] or ( info[2] ~= "raid" and not ShadowUF.db.profile.advanced ) end,
						args = {
							sortMethod = {
								order = 2,
								type = "select",
								name = L["Sort method"],
								values = {["INDEX"] = L["Index"], ["NAME"] = L["Name"]},
								arg = "sortMethod",
								hidden = false,
							},
							sortOrder = {
								order = 2,
								type = "select",
								name = L["Sort order"],
								values = {["ASC"] = L["Ascending"], ["DESC"] = L["Descending"]},
								arg = "sortOrder",
								hidden = false,
							},
						},
					},
					raid = {
						order = 3,
						type = "group",
						inline = true,
						name = L["Groups"],
						hidden = hideRaidOption,
						args = {
							groupBy = {
								order = 4,
								type = "select",
								name = L["Group by"],
								values = {["GROUP"] = L["Group number"], ["CLASS"] = L["Class"], ["ASSIGNEDROLE"] = L["Assigned Role (DPS/Tank/etc)"]},
								arg = "groupBy",
								hidden = hideSplitOrRaidOption,
							},
							selectedGroups = {
								order = 7,
								type = "multiselect",
								name = L["Groups to show"],
								values = {string.format(L["Group %d"], 1), string.format(L["Group %d"], 2), string.format(L["Group %d"], 3), string.format(L["Group %d"], 4), string.format(L["Group %d"], 5), string.format(L["Group %d"], 6), string.format(L["Group %d"], 7), string.format(L["Group %d"], 8)},
								set = function(info, key, value)
									local tbl = Config.getVariable(info[2], nil, nil, "filters")
									tbl[key] = value

									Config.setVariable(info[2], "filters", nil, tbl)
									ShadowUF.Units:ReloadHeader(info[2])
									ShadowUF.modules.movers:Update()
								end,
								get = function(info, key)
									return Config.getVariable(info[2], nil, nil, "filters")[key]
								end,
								hidden = function(info) return info[2] ~= "raid" and info[2] ~= "raidpet" end,
							},
						},
					},
				},
			},
			frame = {
				order = 2,
				name = L["Frame"],
				type = "group",
				hidden = Config.isModifiersSet,
				set = Config.setUnit,
				get = Config.getUnit,
				args = {
					size = {
						order = 0,
						type = "group",
						inline = true,
						name = L["Size"],
						hidden = false,
						set = function(info, value)
							Config.setUnit(info, value)
							ShadowUF.modules.movers:Update()
						end,
						args = {
							scale = {
								order = 0,
								type = "range",
								name = L["Scale"],
								min = 0.25, max = 2, step = 0.01,
								isPercent = true,
								arg = "scale",
							},
							height = {
								order = 1,
								type = "range",
								name = L["Height"],
								min = 0, softMax = 100, step = 1,
								arg = "height",
							},
							width = {
								order = 2,
								type = "range",
								name = L["Width"],
								min = 0, softMax = 300, step = 1,
								arg = "width",
							},
						},
					},
					anchor = {
						order = 1,
						type = "group",
						inline = true,
						hidden = function(info) return info[2] == "global" end,
						name = L["Anchor to another frame"],
						set = setPosition,
						get = getPosition,
						args = {
							anchorPoint = {
								order = 0.50,
								type = "select",
								name = L["Anchor point"],
								values = Config.const.positionList,
								hidden = false,
								get = function(info)
									local position = ShadowUF.db.profile.positions[info[2]]
									if( ShadowUF.db.profile.advanced ) then
										return position[info[#(info)]]
									end


									return position.movedAnchor or position[info[#(info)]]
								end,
							},
							anchorTo = {
								order = 1,
								type = "select",
								name = L["Anchor to"],
								values = Config.getAnchorParents,
								hidden = false,
							},
							sep = {
								order = 2,
								type = "description",
								name = "",
								width = "full",
								hidden = false,
							},
							x = {
								order = 3,
								type = "input",
								name = L["X Offset"],
								validate = checkNumber,
								set = setNumber,
								get = getString,
								hidden = false,
							},
							y = {
								order = 4,
								type = "input",
								name = L["Y Offset"],
								validate = checkNumber,
								set = setNumber,
								get = getString,
								hidden = false,
							},
						},
					},
					orHeader = {
						order = 1.5,
						type = "header",
						name = L["Or you can set a position manually"],
						hidden = function(info) if( info[2] == "global" or Config.hideAdvancedOption() ) then return true else return false end end,
					},
					position = {
						order = 2,
						type = "group",
						hidden = function(info) if( info[2] == "global" or Config.hideAdvancedOption() ) then return true else return false end end,
						inline = true,
						name = L["Manual position"],
						set = setPosition,
						get = getPosition,
						args = {
							point = {
								order = 0,
								type = "select",
								name = L["Point"],
								values = Config.const.pointPositions,
								hidden = false,
							},
							anchorTo = {
								order = 0.50,
								type = "select",
								name = L["Anchor to"],
								values = Config.getAnchorParents,
								hidden = false,
							},
							relativePoint = {
								order = 1,
								type = "select",
								name = L["Relative point"],
								values = Config.const.pointPositions,
								hidden = false,
							},
							sep = {
								order = 2,
								type = "description",
								name = "",
								width = "full",
								hidden = false,
							},
							x = {
								order = 3,
								type = "input",
								name = L["X Offset"],
								validate = checkNumber,
								set = setNumber,
								get = getString,
								hidden = false,
							},
							y = {
								order = 4,
								type = "input",
								name = L["Y Offset"],
								validate = checkNumber,
								set = setNumber,
								get = getString,
								hidden = false,
							},
						},
					},
				},
			},
			bars = {
				order = 3,
				name = L["Bars"],
				type = "group",
				hidden = Config.isModifiersSet,
				set = Config.setUnit,
				get = Config.getUnit,
				args = {
					powerbar = {
						order = 1,
						type = "group",
						inline = false,
						name = L["Power bar"],
						hidden = false,
						args = {
							powerBar = {
								order = 1,
								type = "toggle",
								name = string.format(L["Enable %s"], L["Power bar"]),
								arg = "powerBar.enabled",
							},
							altPowerBar = {
								order = 3,
								type = "toggle",
								name = string.format(L["Enable %s"], L["Alt. Power bar"]),
								desc = L["Shows a bar for alternate power info (used in some encounters)"],
								hidden = function(info) return ShadowUF.fakeUnits[info[2]] or Config.hideRestrictedOption(info) end,
								arg = "altPowerBar.enabled",
							},
							colorType = {
								order = 5,
								type = "select",
								name = L["Color power by"],
								desc = L["Primary means of coloring the power bar. Coloring by class only applies to players, for non-players it will default to the power type."],
								values = {["class"] = L["Class"], ["type"] = L["Power Type"]},
								arg = "powerBar.colorType",
							},
							onlyMana = {
								order = 6,
								type = "toggle",
								name = L["Only show when mana"],
								desc = L["Hides the power bar unless the class has mana."],
								hidden = function(info) return not ShadowUF.Units.headerUnits[info[2]] end,
								arg = "powerBar.onlyMana",
							}
						},
					},
					classmiscbars = {
						order = 2,
						type = "group",
						inline = false,
						name = L["Class/misc bars"],
						hidden = function(info)
							local unit = info[2]
							if( unit == "global" ) then
								return not Config.globalConfig.totemBar and not Config.globalConfig.druidBar and not Config.globalConfig.xpBar
							else
								return unit ~= "player" and unit ~= "pet"
							end
						end,
						args = {
							druidBar = {
								order = 3,
								type = "toggle",
								name = string.format(L["Enable %s"], L["Druid mana bar"]),
								desc = L["Adds another mana bar to the player frame when you are in Bear or Cat form showing you how much mana you have."],
								hidden = Config.hideRestrictedOption,
								arg = "druidBar.enabled",
							},
							xpBar = {
								order = 4,
								type = "toggle",
								name = string.format(L["Enable %s"], L["XP/Rep bar"]),
								desc = L["This bar will automatically hide when you are at the level cap, or you do not have any reputations tracked."],
								hidden = Config.hideRestrictedOption,
								arg = "xpBar.enabled",
							},
						},
					},
					healthBar = {
						order = 2,
						type = "group",
						inline = false,
						name = L["Health bar"],
						hidden = false,
						args = {
							enabled = {
								order = 1,
								type = "toggle",
								name = string.format(L["Enable %s"], L["Health bar"]),
								arg = "healthBar.enabled"
							},
							sep = {
								order = 3.5,
								type = "description",
								name = "",
								hidden = function(info) return not (info[2] == "player" or info[2] == "pet") end,
							},
							colorAggro = {
								order = 4,
								type = "toggle",
								name = L["Color on aggro"],
								desc = L["Changes the health bar to the set hostile color (Red by default) when the unit takes aggro."],
								arg = "healthBar.colorAggro",
								hidden = Config.hideRestrictedOption,
							},
							colorDispel = {
								order = 5,
								type = "toggle",
								name = L["Color on curable debuff"],
								desc = L["Changes the health bar to the color of any curable debuff."],
								arg = "healthBar.colorDispel",
								hidden = Config.hideRestrictedOption,
								width = "full",
							},
							healthColor = {
								order = 6,
								type = "select",
								name = L["Color health by"],
								desc = L["Primary means of coloring the health bar, color on aggro and color by reaction will override this if necessary."],
								values = function(info)
									if info[2] == "pet" or info[2] == "partypet" or info[2] == "raidpet" or info[2] == "arenapet" then
										return {["class"] = L["Class"], ["static"] = L["Static"], ["percent"] = L["Health percent"], ["playerclass"] = L["Player Class"]}
									else
										return {["class"] = L["Class"], ["static"] = L["Static"], ["percent"] = L["Health percent"]}
									end
								end,
								arg = "healthBar.colorType",
							},
							reaction = {
								order = 7,
								type = "select",
								name = L["Color by reaction on"],
								desc = L["When to color the health bar by the units reaction, overriding the color health by option."],
								arg = "healthBar.reactionType",
								values = {["none"] = L["Never (Disabled)"], ["player"] = L["Players only"], ["npc"] = L["NPCs only"], ["both"] = L["Both"]},
								hidden = function(info) return info[2] == "player" or info[2] == "pet" end,
							}
						},
					},
					totemBar = {
						order = 3.6,
						type = "group",
						inline = false,
						name = ShadowUF.modules.totemBar.moduleName,
						hidden = function(info)
							local unit = info[2]
							if( unit == "global" ) then
								return not Config.globalConfig.totemBar
							else
								return unit ~= "player" and unit ~= "pet"
							end
						end,
						args = {
							enabled = {
								order = 1,
								type = "toggle",
								name = string.format(L["Enable %s"], ShadowUF.modules.totemBar.moduleName),
								desc = L["Adds totem bars with timers before they expire to the player frame."],
								arg = "totemBar.enabled",
							},
							icon = {
								order = 2,
								type = "toggle",
								name = L["Show icon durations"],
								desc = L["Uses the icon of the totem being shown instead of a status bar."],
								arg = "totemBar.icon",
							},
							secure = {
								order = 3,
								type = "toggle",
								name = L["Dismissable Totem bars"],
								hidden = function()
									return not ShadowUF.modules.totemBar:SecureLockable()
								end,
								desc = function(info)
									return L["Allows you to disable the totem by right clicking it.|n|nWarning: Inner bars for this unit will not resize in combat if you enable this."]
								end,
								arg = "totemBar.secure",
							}
						},
					},
					incHeal = {
						order = 3,
						type = "group",
						inline = false,
						name = L["Incoming heals"],
						hidden = function(info) return ShadowUF.Units.zoneUnits[info[2]] or Config.hideRestrictedOption(info) end,
						disabled = function(info) return not Config.getVariable(info[2], "healthBar", nil, "enabled") end,
						args = {
							heals = {
								order = 1,
								type = "toggle",
								name = L["Show incoming heals"],
								desc = L["Adds a bar inside the health bar indicating how much healing someone will receive."],
								arg = "incHeal.enabled",
								hidden = false,
								set = function(info, value)
									Config.setUnit(info, value)
									_Config.setDirectUnit(info[2], "incHeal", nil, "enabled", Config.getVariable(info[2], "incHeal", nil, "enabled"))
								end
							},
							cap = {
								order = 3,
								type = "range",
								name = L["Outside bar limit"],
								desc = L["Percentage value of how far outside the unit frame the incoming heal bar can go. 130% means it will go 30% outside the frame, 100% means it will not go outside."],
								min = 1, max = 1.50, step = 0.05, isPercent = true,
								arg = "incHeal.cap",
								hidden = false,
							},
						},
					},
					emptyBar = {
						order = 4,
						type = "group",
						inline = false,
						name = L["Empty bar"],
						hidden = false,
						args = {
							enabled = {
								order = 1,
								type = "toggle",
								name = string.format(L["Enable %s"], L["Empty bar"]),
								desc = L["Adds an empty bar that you can put text into as a way of uncluttering other bars."],
								arg = "emptyBar.enabled",
								width = "full"
							},
							overrideColor = {
								order = 4,
								type = "color",
								name = L["Background color"],
								disabled = function(info)
									local emptyBar = Config.getVariable(info[2], nil, nil, "emptyBar")
									return emptyBar.class and emptyBar.reaciton
								end,
								set = function(info, r, g, b)
									local color = Config.getUnit(info) or {}
									color.r = r
									color.g = g
									color.b = b

									Config.setUnit(info, color)
								end,
								get = function(info)
									local color = Config.getUnit(info)
									if( not color ) then
										return 0, 0, 0
									end

									return color.r, color.g, color.b

								end,
								arg = "emptyBar.backgroundColor",
								width = "full"
							},
							reaction = {
								order = 2,
								type = "select",
								name = L["Color by reaction on"],
								desc = L["When to color the empty bar by reaction, overriding the default color by option."],
								arg = "emptyBar.reactionType",
								values = {["none"] = L["Never (Disabled)"], ["player"] = L["Players only"], ["npc"] = L["NPCs only"], ["both"] = L["Both"]},
							},
							colorType = {
								order = 3,
								type = "toggle",
								name = L["Color by class"],
								desc = L["Players will be colored by class."],
								arg = "emptyBar.class",
							},
						},
					},
					castBar = {
						order = 5,
						type = "group",
						inline = false,
						name = L["Cast bar"],
						hidden = Config.hideRestrictedOption,
						args = {
							enabled = {
								order = 1,
								type = "toggle",
								name = string.format(L["Enable %s"], L["Cast bar"]),
								desc = function(info) return ShadowUF.fakeUnits[info[2]] and string.format(L["Due to the nature of fake units, cast bars for %s are not super efficient and can take at most 0.10 seconds to notice a change in cast."], L.units[info[2]] or info[2]) end,
								hidden = false,
								arg = "castBar.enabled",
								width = "full"
							},
							autoHide = {
								order = 2,
								type = "toggle",
								name = L["Hide bar when empty"],
								desc = L["Hides the cast bar if there is no cast active."],
								hidden = false,
								arg = "castBar.autoHide",
							},
							castIcon = {
								order = 2.5,
								type = "select",
								name = L["Cast icon"],
								arg = "castBar.icon",
								values = {["LEFT"] = L["Left"], ["RIGHT"] = L["Right"], ["HIDE"] = L["Disabled"]},
								hidden = false,
							},
							castName = {
								order = 3,
								type = "header",
								name = L["Cast name"],
								hidden = Config.hideAdvancedOption,
							},
							nameEnabled = {
								order = 4,
								type = "toggle",
								name = L["Show cast name"],
								arg = "castBar.name.enabled",
								hidden = Config.hideAdvancedOption,
							},
							nameAnchor = {
								order = 5,
								type = "select",
								name = L["Anchor point"],
								desc = L["Where to anchor the cast name text."],
								values = {["CLI"] = L["Inside Center Left"], ["CRI"] = L["Inside Center Right"]},
								hidden = Config.hideAdvancedOption,
								arg = "castBar.name.anchorPoint",
							},
							nameSize = {
								order = 7,
								type = "range",
								name = L["Size"],
								desc = L["Let's you modify the base font size to either make it larger or smaller."],
								min = -10, max = 10, step = 1, softMin = -5, softMax = 5,
								hidden = Config.hideAdvancedOption,
								arg = "castBar.name.size",
							},
							nameX = {
								order = 8,
								type = "range",
								name = L["X Offset"],
								min = -20, max = 20, step = 1,
								hidden = Config.hideAdvancedOption,
								arg = "castBar.name.x",
							},
							nameY = {
								order = 9,
								type = "range",
								name = L["Y Offset"],
								min = -20, max = 20, step = 1,
								hidden = Config.hideAdvancedOption,
								arg = "castBar.name.y",
							},
							castTime = {
								order = 10,
								type = "header",
								name = L["Cast time"],
								hidden = Config.hideAdvancedOption,
							},
							timeEnabled = {
								order = 11,
								type = "toggle",
								name = L["Show cast time"],
								arg = "castBar.time.enabled",
								hidden = Config.hideAdvancedOption,
								width = "full"
							},
							timeAnchor = {
								order = 12,
								type = "select",
								name = L["Anchor point"],
								desc = L["Where to anchor the cast time text."],
								values = {["CLI"] = L["Inside Center Left"], ["CRI"] = L["Inside Center Right"]},
								hidden = Config.hideAdvancedOption,
								arg = "castBar.time.anchorPoint",
							},
							timeSize = {
								order = 14,
								type = "range",
								name = L["Size"],
								desc = L["Let's you modify the base font size to either make it larger or smaller."],
								min = -10, max = 10, step = 1, softMin = -5, softMax = 5,
								hidden = Config.hideAdvancedOption,
								arg = "castBar.time.size",
							},
							timeX = {
								order = 15,
								type = "range",
								name = L["X Offset"],
								min = -20, max = 20, step = 1,
								hidden = Config.hideAdvancedOption,
								arg = "castBar.time.x",
							},
							timeY = {
								order = 16,
								type = "range",
								name = L["Y Offset"],
								min = -20, max = 20, step = 1,
								hidden = Config.hideAdvancedOption,
								arg = "castBar.time.y",
							},
						},
					},
				},
			},
			widgetSize = {
				order = 4,
				name = L["Widget Size"],
				type = "group",
				hidden = Config.isModifiersSet,
				set = Config.setUnit,
				get = Config.getUnit,
				args = {
					help = {
						order = 0,
						type = "group",
						name = L["Help"],
						inline = true,
						hidden = false,
						args = {
							help = {
								order = 0,
								type = "description",
								name = L["Bars with an order higher or lower than the full size options will use the entire unit frame width.|n|nBar orders between those two numbers are shown next to the portrait."],
							},
						},
					},
					portrait = {
						order = 0.5,
						type = "group",
						name = L["Portrait"],
						inline = false,
						hidden = false,
						args = {
							enableBar = {
								order = 1,
								type = "toggle",
								name = L["Show as bar"],
								desc = L["Changes this widget into a bar, you will be able to change the height and ordering like you can change health and power bars."],
								arg = "$parent.isBar",
							},
							sep = {
								order = 1.5,
								type = "description",
								name = "",
								width = "full",
								hidden = function(info) return Config.getVariable(info[2], "portrait", nil, "isBar") end,
							},
							width = {
								order = 2,
								type = "range",
								name = L["Width percent"],
								desc = L["Percentage of width the portrait should use."],
								min = 0, max = 1.0, step = 0.01, isPercent = true,
								hidden = function(info) return Config.getVariable(info[2], "portrait", nil, "isBar") end,
								arg = "$parent.width",
							},
							before = {
								order = 3,
								type = "range",
								name = L["Full size before"],
								min = 0, max = 100, step = 5,
								hidden = function(info) return Config.getVariable(info[2], "portrait", nil, "isBar") end,
								arg = "$parent.fullBefore",
							},
							after = {
								order = 4,
								type = "range",
								name = L["Full size after"],
								min = 0, max = 100, step = 5,
								hidden = function(info) return Config.getVariable(info[2], "portrait", nil, "isBar") end,
								arg = "$parent.fullAfter",
							},
							order = {
								order = 3,
								type = "range",
								name = L["Order"],
								min = 0, max = 100, step = 5,
								hidden = hideBarOption,
								arg = "portrait.order",
							},
							height = {
								order = 4,
								type = "range",
								name = L["Height"],
								desc = L["How much of the frames total height this bar should get, this is a weighted value, the higher it is the more it gets."],
								min = 0, max = 10, step = 0.1,
								hidden = hideBarOption,
								arg = "portrait.height",
							},
						},
					},
				},
			},
			auras = {
				order = 5,
				name = L["Auras"],
				type = "group",
				hidden = Config.isModifiersSet,
				set = Config.setUnit,
				get = Config.getUnit,
				childGroups = "tree",
				args = {
					buffs = Config.auraTable,
					debuffs = Config.auraTable,
				},
			},
			indicators = {
				order = 5.5,
				type = "group",
				name = L["Indicators"],
				hidden = Config.isModifiersSet,
				childGroups = "tree",
				set = Config.setUnit,
				get = Config.getUnit,
				args = {
				},
			},
			tag = {
				order = 7,
				name = L["Text/Tags"],
				type = "group",
				hidden = Config.isModifiersSet,
				childGroups = "tree",
				args = tagWizard,
			},
		},
	}

	for _, indicator in pairs(ShadowUF.modules.indicators.list) do
		Config.unitTable.args.indicators.args[indicator] = Config.indicatorTable
	end

	-- Check for unit conflicts
	local function hideZoneConflict()
		for _, zone in pairs(ShadowUF.db.profile.visibility) do
			for unit, status in pairs(zone) do
				if( L.units[unit] and ( not status and ShadowUF.db.profile.units[unit].enabled or status and not ShadowUF.db.profile.units[unit].enabled ) ) then
					return nil
				end
			end
		end

		return true
	end

	enableUnitsOptions = {
		type = "group",
		name = L["Enabled Units"],
		desc = Config.getPageDescription,
		args = {
			help = {
				order = 1,
				type = "group",
				inline = true,
				name = L["Help"],
				hidden = function()
					if( not hideZoneConflict() or Config.hideBasicOption() ) then
						return true
					end

					return nil
				end,
				args = {
					help = {
						order = 0,
						type = "description",
						name = L["The check boxes below will allow you to enable or disable units.|n|n|cffff2020Warning!|r Target of Target units have a higher performance cost compared to other units. If you have performance issues, please disable those units or reduce the features enabled for those units."],
					},
				},
			},
			zoneenabled = {
				order = 1.5,
				type = "group",
				inline = true,
				name = L["Zone configuration units"],
				hidden = hideZoneConflict,
				args = {
					help = {
						order = 1,
						type = "description",
						name = L["|cffff2020Warning!|r Some units have overrides set in zone configuration, and may show (or not show up) in certain zone. Regardless of the settings below."]
					},
					sep = {
						order = 2,
						type = "header",
						name = "",
					},
					units = {
						order = 3,
						type = "description",
						name = function()
							local text = {}

							for zoneType, zone in pairs(ShadowUF.db.profile.visibility) do
								local errors = {}
								for unit, status in pairs(zone) do
									if( L.units[unit] ) then
										if ( not status and ShadowUF.db.profile.units[unit].enabled ) then
											table.insert(errors, string.format(L["|cffff2020%s|r units disabled"], L.units[unit]))
										elseif( status and not ShadowUF.db.profile.units[unit].enabled ) then
											table.insert(errors, string.format(L["|cff20ff20%s|r units enabled"], L.units[unit]))
										end
									end
								end

								if( #(errors) > 1 ) then
									table.insert(text, string.format("|cfffed000%s|r have the following overrides: %s", Config.const.AREA_NAMES[zoneType], table.concat(errors, ", ")))
								elseif( #(errors) == 1 ) then
									table.insert(text, string.format("|cfffed000%s|r has the override: %s", Config.const.AREA_NAMES[zoneType], errors[1]))
								end
							end

							return #(text) > 0 and table.concat(text, "|n") or ""
						end,
					},
				},
			},
			enabled = {
				order = 2,
				type = "group",
				inline = true,
				name = L["Enable units"],
				args = {},
			},
		},
	}

	local sort_units = function(a, b)
		return a < b
	end

	unitsOptions = {
		type = "group",
		name = L["Unit Configuration"],
		desc = Config.getPageDescription,
		args = {
			help = {
				order = 1,
				type = "group",
				inline = true,
				name = L["Help"],
				args = {
					help = {
						order = 0,
						type = "description",
						name = L["Wondering what all of the tabs for the unit configuration mean? Here's some information:|n|n|cfffed000General:|r Portrait, range checker, combat fader, border highlighting|n|cfffed000Frame:|r Unit positioning and frame anchoring|n|cfffed000Bars:|r Health, power, empty and cast bar, and combo point configuration|n|cfffed000Widget size:|r All bar and portrait sizing and ordering options|n|cfffed000Auras:|r All aura configuration for enabling/disabling/enlarging self/etc|n|cfffed000Indicators:|r All indicator configuration|n|cfffed000Text/Tags:|r Tag management as well as text positioning and width settings.|n|n|n*** Frequently looked for options ***|n|n|cfffed000Raid frames by group|r - Unit configuration -> Raid -> Raid -> Separate raid frames|n|cfffed000Class coloring:|r Bars -> Color health by|n|cfffed000Timers on auras:|r You need OmniCC for that|n|cfffed000Showing/Hiding default buff frames:|r Hide Blizzard -> Hide buff frames|n|cfffed000Percentage HP/MP text:|r Tags/Text tab, use the [percenthp] or [percentpp] tags|n|cfffed000Hiding party based on raid|r - Unit configuration -> Party -> Party -> Hide in 6-man raid/Hide in any raid"],
						fontSize = "medium",
					},
				},
			},
			global = {
				type = "group",
				childGroups = "tab",
				order = 0,
				name = L["Global"],
				args = {
					test = {
						order = 0,
						type = "group",
						name = L["Currently modifying"],
						inline = true,
						hidden = function()
							for k in pairs(Config.modifyUnits) do return false end
							return true
						end,
						args = {
							info = {
								order = 0,
								type = "description",
								name = function()
									local units = {};
									for unit, enabled in pairs(Config.modifyUnits) do
										if( enabled ) then
											table.insert(units, L.units[unit])
										end
									end

									table.sort(units, sort_units)
									return table.concat(units, ", ")
								end,
							}
						}
					},
					units = {
						order = 1,
						type = "group",
						name = L["Units"],
						set = function(info, value)
							if( IsShiftKeyDown() ) then
								for _, unit in pairs(ShadowUF.unitList) do
									if( ShadowUF.db.profile.units[unit].enabled ) then
										Config.modifyUnits[unit] = value and true or nil

										if( value ) then
											Config.globalConfig = _Config.mergeTables(Config.globalConfig, ShadowUF.db.profile.units[unit])
										end
									end
								end
							else
								local unit = info[#(info)]
								Config.modifyUnits[unit] = value and true or nil

								if( value ) then
									Config.globalConfig = _Config.mergeTables(Config.globalConfig, ShadowUF.db.profile.units[unit])
								end
							end

							-- Check if we have nothing else selected, if so wipe it
							local hasUnit
							for k in pairs(Config.modifyUnits) do hasUnit = true break end
							if( not hasUnit ) then
								Config.globalConfig = {}
							end

							Config.AceRegistry:NotifyChange("ShadowedUF")
						end,
						get = function(info) return Config.modifyUnits[info[#(info)]] end,
						args = {
							help = {
								order = 0,
								type = "group",
								name = L["Help"],
								inline = true,
								args = {
									help = {
										order = 0,
										type = "description",
										name = L["Select the units that you want to modify, any settings changed will change every unit you selected. If you want to anchor or change raid/party unit specific settings you will need to do that through their options.|n|nShift click a unit to select all/unselect all."],
									},
								},
							},
							units = {
								order = 1,
								type = "group",
								name = L["Units"],
								inline = true,
								args = {},
							},
						},
					},
				},
			},
		},
	}

	-- Load modules into the unit table
	for key, module in pairs(ShadowUF.modules) do
		local canHaveBar = module.moduleHasBar
		for _, data in pairs(ShadowUF.defaults.profile.units) do
			if( data[key] and data[key].isBar ~= nil ) then
				canHaveBar = true
				break
			end
		end

		if( canHaveBar ) then
			Config.unitTable.args.widgetSize.args[key] = Config.barTable
		end
	end

	-- Load global unit
	for k, v in pairs(Config.unitTable.args) do
		unitsOptions.args.global.args[k] = v
	end

	-- Load all of the per unit settings
	local perUnitList = {
		order = Config.getUnitOrder,
		type = "toggle",
		name = Config.getName,
		hidden = Config.isUnitDisabled,
		desc = function(info)
			return string.format(L["Adds %s to the list of units to be modified when you change values in this tab."], L.units[info[#(info)]])
		end,
	}

	-- Enabled units list
	local unitCatOrder = {}
	local enabledUnits = {
		order = function(info) return unitCatOrder[info[#(info)]] + Config.getUnitOrder(info) end,
		type = "toggle",
		name = Config.getName,
		set = function(info, value)
			local unit = info[#(info)]
			for child, parent in pairs(ShadowUF.Units.childUnits) do
				if( unit == parent and not value ) then
					ShadowUF.db.profile.units[child].enabled = false
				end
			end

			ShadowUF.modules.movers:Update()
			ShadowUF.db.profile.units[unit].enabled = value
			ShadowUF:LoadUnits()

			-- Update party frame visibility
			if( unit == "raid" and ShadowUF.Units.headerFrames.party ) then
				ShadowUF.Units:SetHeaderAttributes(ShadowUF.Units.headerFrames.party, "party")
			end

			ShadowUF.modules.movers:Update()
		end,
		get = function(info)
			return ShadowUF.db.profile.units[info[#(info)]].enabled
		end,
		desc = function(info)
			local unit = info[#(info)]
			local unitDesc = UNIT_DESC[unit] or ""

			if( ShadowUF.db.profile.units[unit].enabled and ShadowUF.Units.childUnits[unit] ) then
				if( unitDesc ~= "" ) then unitDesc = unitDesc .. "\n\n" end
				return unitDesc .. string.format(L["This unit depends on another to work, disabling %s will disable %s."], L.units[ShadowUF.Units.childUnits[unit]], L.units[unit])
			elseif( not ShadowUF.db.profile.units[unit].enabled ) then
				for child, parent in pairs(ShadowUF.Units.childUnits) do
					if( parent == unit ) then
						if( unitDesc ~= "" ) then unitDesc = unitDesc .. "\n\n" end
						return unitDesc .. L["This unit has child units that depend on it, you need to enable this unit before you can enable its children."]
					end
				end
			end

			return unitDesc ~= "" and unitDesc
		end,
		disabled = function(info)
			local unit = info[#(info)]
			if( ShadowUF.Units.childUnits[unit] ) then
				return not ShadowUF.db.profile.units[ShadowUF.Units.childUnits[unit]].enabled
			end

			return false
		end,
	}

	local unitCategory = {
		order = function(info)
			local cat = info[#(info)]
			return cat == "playercat" and 50 or cat == "generalcat" and 100 or cat == "partycat" and 200 or cat == "raidcat" and 300 or cat == "raidmisccat" and 400 or cat == "bosscat" and 500 or cat == "arenacat" and 600 or 700
		end,
		type = "header",
		name = function(info)
			local cat = info[#(info)]
			return cat == "playercat" and L["Player"] or cat == "generalcat" and L["General"] or cat == "raidcat" and L["Raid"] or cat == "partycat" and L["Party"] or cat == "arenacat" and L["Arena"] or cat == "battlegroundcat" and L["Battlegrounds"] or cat == "raidmisccat" and L["Raid Misc"] or cat == "bosscat" and L["Boss"]
		end,
		width = "full",
	}

	for cat, list in pairs(unitCategories) do
		enableUnitsOptions.args.enabled.args[cat .. "cat"] = unitCategory

		for _, unit in pairs(list) do
			unitCatOrder[unit] = cat == "player" and 50 or cat == "general" and 100 or cat == "party" and 200 or cat == "raid" and 300 or cat == "raidmisc" and 400 or cat == "boss" and 500 or cat == "arena" and 600 or 700
		end
	end

	for order, unit in pairs(ShadowUF.unitList) do
		enableUnitsOptions.args.enabled.args[unit] = enabledUnits
		unitsOptions.args.global.args.units.args.units.args[unit] = perUnitList
		unitsOptions.args[unit] = Config.unitTable

		unitCatOrder[unit] = unitCatOrder[unit] or 100
	end

	return enableUnitsOptions, unitsOptions
end
