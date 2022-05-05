local L = ShadowUF.L
local Config = ShadowUF.Config
local _Config = ShadowUF.Config.private

function _Config:loadFilterOptions()
	local hasWhitelist, hasBlacklist, hasOverridelist, rebuildFilters
	local filterMap, spellMap = {}, {}
	local filterOptions

	local function reloadUnitAuras()
		for _, frame in pairs(ShadowUF.Units.unitFrames) do
			if( UnitExists(frame.unit) and frame.visibility.auras ) then
				ShadowUF.modules.auras:UpdateFilter(frame)
				frame:FullUpdate()
			end
		end
	end

	local function setFilterType(info, value)
		local filter = filterMap[info[#(info) - 2]]
		local filterType = info[#(info) - 3]

		ShadowUF.db.profile.filters[filterType][filter][info[#(info)]] = value
		reloadUnitAuras()
	end

	local function getFilterType(info)
		local filter = filterMap[info[#(info) - 2]]
		local filterType = info[#(info) - 3]

		return ShadowUF.db.profile.filters[filterType][filter][info[#(info)]]
	end

	--- Container widget for the filter listing
	local filterEditTable = {
		order = 0,
		type = "group",
		name = function(info) return filterMap[info[#(info)]] end,
		hidden = function(info) return not ShadowUF.db.profile.filters[info[#(info) - 1]][filterMap[info[#(info)]]] end,
		args = {
			general = {
				order = 0,
				type = "group",
				name = function(info) return filterMap[info[#(info) - 1]] end,
				hidden = false,
				inline = true,
				args = {
					add = {
						order = 0,
						type = "input",
						name = L["Aura name or spell ID"],
						--dialogControl = "Aura_EditBox",
						hidden = false,
						set = function(info, value)
							local filterType = info[#(info) - 3]
							local filter = filterMap[info[#(info) - 2]]

							ShadowUF.db.profile.filters[filterType][filter][value] = true

							reloadUnitAuras()
							rebuildFilters()
						end,
					},
					delete = {
						order = 1,
						type = "execute",
						name = L["Delete filter"],
						hidden = false,
						confirmText = L["Are you sure you want to delete this filter?"],
						confirm = true,
						func = function(info, value)
							local filterType = info[#(info) - 3]
							local filter = filterMap[info[#(info) - 2]]

							ShadowUF.db.profile.filters[filterType][filter] = nil

							-- Delete anything that used this filter too
							local filterList = filterType == "whitelists" and ShadowUF.db.profile.filters.zonewhite or filterType == "blacklists" and ShadowUF.db.profile.filters.zoneblack or filterType == "overridelists" and ShadowUF.db.profile.filters.zoneoverride
							if filterList then
								for id, filterUsed in pairs(filterList) do
									if( filterUsed == filter ) then
										filterList[id] = nil
									end
								end
							end

							reloadUnitAuras()
							rebuildFilters()
						end,
					},
				},
			},
			filters = {
				order = 2,
				type = "group",
				inline = true,
				hidden = false,
				name = L["Aura types to filter"],
				args = {
					buffs = {
						order = 4,
						type = "toggle",
						name = L["Buffs"],
						desc = L["When this filter is active, apply the filter to buffs."],
						set = setFilterType,
						get = getFilterType,
					},
					debuffs = {
						order = 5,
						type = "toggle",
						name = L["Debuffs"],
						desc = L["When this filter is active, apply the filter to debuffs."],
						set = setFilterType,
						get = getFilterType,
					},
				},
			},
			spells = {
				order = 3,
				type = "group",
				inline = true,
				name = L["Auras"],
				hidden = false,
				args = {

				},
			},
		},
	}

	-- Spell list for manage aura filters
	local spellLabel = {
		order = function(info) return tonumber(string.match(info[#(info)], "(%d+)")) end,
		type = "description",
		width = "double",
		fontSize = "medium",
		name = function(info)
			local name = spellMap[info[#(info)]]
			if tonumber(name) then
				local spellName, _, icon = GetSpellInfo(name)
				name = string.format("|T%s:14:14:0:0|t %s (#%i)", icon or "Interface\\Icons\\Inv_misc_questionmark", spellName or L["Unknown"], name)
			end
			return name
		end,
	}

	local spellRow = {
		order = function(info) return tonumber(string.match(info[#(info)], "(%d+)")) + 0.5 end,
		type = "execute",
		name = L["Delete"],
		width = "half",
		func = function(info)
			local spell = spellMap[info[#(info)]]
			local filter = filterMap[info[#(info) - 2]]
			local filterType = info[#(info) - 3]

			ShadowUF.db.profile.filters[filterType][filter][spell] = nil

			reloadUnitAuras()
			rebuildFilters()
		end
	}

	local noSpells = {
		order = 0,
		type = "description",
		name = L["This filter has no auras in it, you will have to add some using the dialog above."],
	}

	-- The filter [View] widgets for manage aura filters
	local filterLabel = {
		order = function(info) return tonumber(string.match(info[#(info)], "(%d+)")) end,
		type = "description",
		width = "", -- Odd I know, AceConfigDialog-3.0 expands descriptions to full width if width is nil
		fontSize = "medium",
		name = function(info) return filterMap[info[#(info)]] end,
	}

	local filterRow = {
		order = function(info) return tonumber(string.match(info[#(info)], "(%d+)")) + 0.5 end,
		type = "execute",
		name = L["View"],
		width = "half",
		func = function(info)
			local filterType = info[#(info) - 2]

			Config.AceDialog.Status.ShadowedUF.children.filter.children.filters.status.groups.groups[filterType] = true
			Config.selectTabGroup("filter", "filters", filterType .. "\001" .. string.match(info[#(info)], "(%d+)"))
		end
	}

	local noFilters = {
		order = 0,
		type = "description",
		name = L["You do not have any filters of this type added yet, you will have to create one in the management panel before this page is useful."],
	}

	-- Container table for a filter zone
	local globalSettings = {}
	local zoneList = {"none", "pvp", "arena", "party", "raid"}
	local filterTable = {
		order = function(info) return info[#(info)] == "global" and 1 or info[#(info)] == "none" and 2 or 3 end,
		type = "group",
		inline = true,
		hidden = function() return not hasWhitelist and not hasBlacklist and not hasOverridelist end,
		name = function(info) return Config.const.AREA_NAMES[info[#(info)]] or L["Global"] end,
		set = function(info, value)
			local filter = filterMap[info[#(info)]]
			local zone = info[#(info) - 1]
			local unit = info[#(info) - 2]
			local filterKey = ShadowUF.db.profile.filters.whitelists[filter] and "zonewhite" or ShadowUF.db.profile.filters.blacklists[filter] and "zoneblack" or "zoneoverride"

			for _, zoneConfig in pairs(zoneList) do
				if( zone == "global" or zoneConfig == zone ) then
					if( unit == "global" ) then
						globalSettings[zoneConfig .. filterKey] = value and filter or false

						for _, unitEntry in pairs(ShadowUF.unitList) do
							ShadowUF.db.profile.filters[filterKey][zoneConfig .. unitEntry] = value and filter or nil
						end
					else
						ShadowUF.db.profile.filters[filterKey][zoneConfig .. unit] = value and filter or nil
					end
				end
			end

			if( zone == "global" ) then
				globalSettings[zone .. unit .. filterKey] = value and filter or false
			end

			reloadUnitAuras()
		end,
		get = function(info)
			local filter = filterMap[info[#(info)]]
			local zone = info[#(info) - 1]
			local unit = info[#(info) - 2]

			if( unit == "global" or zone == "global" ) then
				local id = zone == "global" and zone .. unit or zone
				local filterKey = ShadowUF.db.profile.filters.whitelists[filter] and "zonewhite" or ShadowUF.db.profile.filters.blacklists[filter] and "zoneblack" or "zoneoverride"

				if( info[#(info)] == "nofilter" ) then
					return globalSettings[id .. "zonewhite"] == false and globalSettings[id .. "zoneblack"] == false and globalSettings[id .. "zoneoverride"] == false
				end

				return globalSettings[id .. filterKey] == filter
			end

			if( info[#(info)] == "nofilter" ) then
				return not ShadowUF.db.profile.filters.zonewhite[zone .. unit] and not ShadowUF.db.profile.filters.zoneblack[zone .. unit] and not ShadowUF.db.profile.filters.zoneoverride[zone .. unit]
			end

			return ShadowUF.db.profile.filters.zonewhite[zone .. unit] == filter or ShadowUF.db.profile.filters.zoneblack[zone .. unit] == filter or ShadowUF.db.profile.filters.zoneoverride[zone .. unit] == filter
		end,
		args = {
			nofilter = {
				order = 0,
				type = "toggle",
				name = L["Don't use a filter"],
				hidden = false,
				set = function(info, value)
					local filter = filterMap[info[#(info)]]
					local zone = info[#(info) - 1]
					local unit = info[#(info) - 2]

					for _, zoneConfig in pairs(zoneList) do
						if( zone == "global" or zoneConfig == zone ) then
							if( unit == "global" ) then
								globalSettings[zoneConfig .. "zonewhite"] = false
								globalSettings[zoneConfig .. "zoneblack"] = false
								globalSettings[zoneConfig .. "zoneoverride"] = false

								for _, unitEntry in pairs(ShadowUF.unitList) do
									ShadowUF.db.profile.filters.zonewhite[zoneConfig .. unitEntry] = nil
									ShadowUF.db.profile.filters.zoneblack[zoneConfig .. unitEntry] = nil
									ShadowUF.db.profile.filters.zoneoverride[zoneConfig .. unitEntry] = nil
								end
							else
								ShadowUF.db.profile.filters.zonewhite[zoneConfig .. unit] = nil
								ShadowUF.db.profile.filters.zoneblack[zoneConfig .. unit] = nil
								ShadowUF.db.profile.filters.zoneoverride[zoneConfig .. unit] = nil
							end
						end
					end

					if( zone == "global" ) then
						globalSettings[zone .. unit .. "zonewhite"] = false
						globalSettings[zone .. unit .. "zoneblack"] = false
						globalSettings[zone .. unit .. "zoneoverride"] = false
					end

					reloadUnitAuras()
				end,
			},
			white = {
				order = 1,
				type = "header",
				name = "|cffffffff" .. L["Whitelists"] .. "|r",
				hidden = function(info) return not hasWhitelist end
			},
			black = {
				order = 3,
				type = "header",
				name = L["Blacklists"], -- In theory I would make this black, but as black doesn't work with a black background I'll skip that
				hidden = function(info) return not hasBlacklist end
			},
			override = {
				order = 5,
				type = "header",
				name = L["Override lists"], -- In theory I would make this black, but as black doesn't work with a black background I'll skip that
				hidden = function(info) return not hasOverridelist end
			},
		},
	}

	-- Toggle used for set filter zones to enable filters
	local filterToggle = {
		order = function(info) return ShadowUF.db.profile.filters.whitelists[filterMap[info[#(info)]]] and 2 or ShadowUF.db.profile.filters.blacklists[filterMap[info[#(info)]]] and 4 or 6 end,
		type = "toggle",
		name = function(info) return filterMap[info[#(info)]] end,
		desc = function(info)
			local filter = filterMap[info[#(info)]]
			filter = ShadowUF.db.profile.filters.whitelists[filter] or ShadowUF.db.profile.filters.blacklists[filter] or ShadowUF.db.profile.filters.overridelists[filter]
			if( filter.buffs and filter.debuffs ) then
				return L["Filtering both buffs and debuffs"]
			elseif( filter.buffs ) then
				return L["Filtering buffs only"]
			elseif( filter.debuffs ) then
				return L["Filtering debuffs only"]
			end

			return L["This filter has no aura types set to filter out."]
		end,
	}

	-- Load existing filters in
	-- This needs to be cleaned up later
	local filterID, spellID = 0, 0
	local function buildList(type)
		local manageFiltersTableEntry = {
			order = type == "whitelists" and 1 or type == "blacklists" and 2 or 3,
			type = "group",
			name = type == "whitelists" and L["Whitelists"] or type == "blacklists" and L["Blacklists"] or L["Override lists"],
			args = {
				groups = {
					order = 0,
					type = "group",
					inline = true,
					name = function(info) return info[#(info) - 1] == "whitelists" and L["Whitelist filters"] or info[#(info) - 1] == "blacklists" and L["Blacklist filters"] or L["Override list filters"] end,
					args = {
					},
				},
			},
		}

		local hasFilters
		for name, spells in pairs(ShadowUF.db.profile.filters[type]) do
			hasFilters = true
			filterID = filterID + 1
			filterMap[tostring(filterID)] = name
			filterMap[filterID .. "label"] = name
			filterMap[filterID .. "row"] = name

			manageFiltersTableEntry.args[tostring(filterID)] = CopyTable(filterEditTable)
			manageFiltersTableEntry.args.groups.args[filterID .. "label"] = filterLabel
			manageFiltersTableEntry.args.groups.args[filterID .. "row"] = filterRow
			filterTable.args[tostring(filterID)] = filterToggle

			local hasSpells
			for spellName in pairs(spells) do
				if( spellName ~= "buffs" and spellName ~= "debuffs" ) then
					hasSpells = true
					spellID = spellID + 1
					spellMap[tostring(spellID)] = spellName
					spellMap[spellID .. "label"] = spellName

					manageFiltersTableEntry.args[tostring(filterID)].args.spells.args[spellID .. "label"] = spellLabel
					manageFiltersTableEntry.args[tostring(filterID)].args.spells.args[tostring(spellID)] = spellRow
				end
			end

			if( not hasSpells ) then
				manageFiltersTableEntry.args[tostring(filterID)].args.spells.args.noSpells = noSpells
			end
		end

		if( not hasFilters ) then
			if( type == "whitelists" ) then hasWhitelist = nil elseif( type == "blacklists" ) then hasBlacklist = nil else hasOverridelist = nil end
			manageFiltersTableEntry.args.groups.args.noFilters = noFilters
		end

		return manageFiltersTableEntry
	end

	rebuildFilters = function()
		for id in pairs(filterMap) do filterTable.args[id] = nil end

		spellID = 0
		filterID = 0
		hasBlacklist = true
		hasWhitelist = true
		hasOverridelist = true

		table.wipe(filterMap)
		table.wipe(spellMap)

		filterOptions.args.filters.args.whitelists = buildList("whitelists")
		filterOptions.args.filters.args.blacklists = buildList("blacklists")
		filterOptions.args.filters.args.overridelists = buildList("overridelists")
	end

	local unitFilterSelection = {
		order = function(info) return info[#(info)] == "global" and 1 or (Config.getUnitOrder(info) + 1) end,
		type = "group",
		name = function(info) return info[#(info)] == "global" and L["Global"] or Config.getName(info) end,
		disabled = function(info)
			if( info[#(info)] == "global" ) then
				return false
			end

			return not hasWhitelist and not hasBlacklist
		end,
		args = {
			help = {
				order = 0,
				type = "group",
				inline = true,
				name = L["Help"],
				hidden = function() return hasWhitelist or hasBlacklist or hasOverridelist end,
				args = {
					help = {
						type = "description",
						name = L["You will need to create an aura filter before you can set which unit to enable aura filtering on."],
						width = "full",
					}
				},
			},
			header = {
				order = 0,
				type = "header",
				name = function(info) return (info[#(info) - 1] == "global" and L["Global"] or L.units[info[#(info) - 1]]) end,
				hidden = function() return not hasWhitelist and not hasBlacklist and not hasOverridelist end,
			},
			global = filterTable,
			none = filterTable,
			pvp = filterTable,
			arena = filterTable,
			battleground = filterTable,
			party = filterTable,
			raid = filterTable,
		}
	}

	local addFilter = {type = "whitelists"}

	filterOptions = {
		type = "group",
		name = L["Aura Filters"],
		childGroups = "tab",
		desc = _Config.getPageDescription,
		args = {
			groups = {
				order = 1,
				type = "group",
				name = L["Set Filter Zones"],
				args = {
					help = {
						order = 0,
						type = "group",
						inline = true,
						name = L["Help"],
						args = {
							help = {
								type = "description",
								name = L["You can set what unit frame should use what filter group and in what zone type here, if you want to change what auras goes into what group then see the \"Manage aura groups\" option."],
								width = "full",
							}
						},
					},
				}
			},
			filters = {
				order = 2,
				type = "group",
				name = L["Manage Aura Filters"],
				childGroups = "tree",
				args = {
					manage = {
						order = 1,
						type = "group",
						name = L["Management"],
						args = {
							help = {
								order = 0,
								type = "group",
								inline = true,
								name = L["Help"],
								args = {
									help = {
										type = "description",
										name = L["Whitelists will hide any aura not in the filter group.|nBlacklists will hide auras that are in the filter group.|nOverride lists will bypass any filter and always be shown."],
										width = "full",
									}
								},
							},
							error = {
								order = 1,
								type = "group",
								inline = true,
								hidden = function() return not addFilter.error end,
								name = L["Error"],
								args = {
									error = {
										order = 0,
										type = "description",
										name = function() return addFilter.error end,
										width = "full",
									},
								},
							},
							add = {
								order = 2,
								type = "group",
								inline = true,
								name = L["New filter"],
								get = function(info) return addFilter[info[#(info)]] end,
								args = {
									name = {
										order = 0,
										type = "input",
										name = L["Name"],
										set = function(info, value)
											addFilter[info[#(info)]] = string.trim(value) ~= "" and value or nil
											addFilter.error = nil
										end,
										get = function(info) return addFilter.errorName or addFilter.name end,
										validate = function(info, value)
											local name = string.lower(string.trim(value))
											for filter in pairs(ShadowUF.db.profile.filters.whitelists) do
												if( string.lower(filter) == name ) then
													addFilter.error = string.format(L["The whitelist \"%s\" already exists."], value)
													addFilter.errorName = value
													Config.AceRegistry:NotifyChange("ShadowedUF")
													return ""
												end
											end

											for filter in pairs(ShadowUF.db.profile.filters.blacklists) do
												if( string.lower(filter) == name ) then
													addFilter.error = string.format(L["The blacklist \"%s\" already exists."], value)
													addFilter.errorName = value
													Config.AceRegistry:NotifyChange("ShadowedUF")
													return ""
												end
											end

											for filter in pairs(ShadowUF.db.profile.filters.overridelists) do
												if( string.lower(filter) == name ) then
													addFilter.error = string.format(L["The override list \"%s\" already exists."], value)
													addFilter.errorName = value
													Config.AceRegistry:NotifyChange("ShadowedUF")
													return ""
												end
											end

											addFilter.error = nil
											addFilter.errorName = nil
											return true
										end,
									},
									type = {
										order = 1,
										type = "select",
										name = L["Filter type"],
										set = function(info, value) addFilter[info[#(info)]] = value end,
										values = {["whitelists"] = L["Whitelist"], ["blacklists"] = L["Blacklist"], ["overridelists"] = L["Override list"]},
									},
									add = {
										order = 2,
										type = "execute",
										name = L["Create"],
										disabled = function(info) return not addFilter.name end,
										func = function(info)
											ShadowUF.db.profile.filters[addFilter.type][addFilter.name] = {buffs = true, debuffs = true}
											rebuildFilters()

											local id
											for key, value in pairs(filterMap) do
												if( value == addFilter.name ) then
													id = key
													break
												end
											end

											Config.AceDialog.Status.ShadowedUF.children.filter.children.filters.status.groups.groups[addFilter.type] = true
											Config.selectTabGroup("filter", "filters", addFilter.type .. "\001" .. id)

											table.wipe(addFilter)
											addFilter.type = "whitelists"
										end,
									},
								},
							},
						},
					},
				},
			},
		},
	}

	filterOptions.args.groups.args.global = unitFilterSelection
	for _, unit in pairs(ShadowUF.unitList) do
		filterOptions.args.groups.args[unit] = unitFilterSelection
	end

	rebuildFilters()

	return filterOptions
end
