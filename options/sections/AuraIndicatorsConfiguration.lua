local L = ShadowUF.L
local Config = ShadowUF.Config

function Config:loadAuraIndicatorsOptions()
	local auraIndicatorsOptions

	local Indicators = ShadowUF.modules.auraIndicators
	local auraFilters = Indicators.auraFilters

	local unitTable

	local groupAliases = {
		["pvpflags"] = L["PvP Flags"],
		["food"] = L["Food"],
		["miscellaneous"] = L["Miscellaneous"]
	}

	for token, name in pairs(LOCALIZED_CLASS_NAMES_MALE) do
		groupAliases[string.lower(token)] = name
	end

	local groupList = {}
	local function getAuraGroup(info)
		for k in pairs(groupList) do groupList[k] = nil end
		for name in pairs(ShadowUF.db.profile.auraIndicators.auras) do
			local aura = Indicators.auraConfig[name]
			groupList[aura.group] = aura.group
		end

		return groupList
	end

	local auraList = {}
	local function getAuraList(info)
		for k in pairs(auraList) do auraList[k] = nil end
		for name in pairs(ShadowUF.db.profile.auraIndicators.auras) do
			if( tonumber(name) ) then
				local spellID = name
				name = GetSpellInfo(name) or L["Unknown"]
				auraList[name] = string.format("%s (#%i)", name, spellID)
			else
				auraList[name] = name
			end
		end

		return auraList
	end

	local indicatorList = {}
	local function getIndicatorList(info)
		for k in pairs(indicatorList) do indicatorList[k] = nil end
		indicatorList[""] = L["None (Disabled)"]
		for key, indicator in pairs(ShadowUF.db.profile.auraIndicators.indicators) do
			indicatorList[key] = indicator.name
		end

		return indicatorList
	end

	local function writeAuraTable(name)
		ShadowUF.db.profile.auraIndicators.auras[name] = Config.writeTable(Indicators.auraConfig[name])
		Indicators.auraConfig[name] = nil

		local spellID = tonumber(name)
		if( spellID ) then
			Indicators.auraConfig[spellID] = nil
		end
	end

	local groupMap, auraMap, linkMap = {}, {}, {}
	local groupID, auraID, linkID = 0, 0, 0

	local reverseClassMap = {}
	for token, text in pairs(LOCALIZED_CLASS_NAMES_MALE) do
		reverseClassMap[text] = token
	end

	local function groupName(name)
		local converted = string.lower(string.gsub(name, " ", ""))
		return groupAliases[converted] or name
	end

	-- Actual aura configuration
	local auraGroupTable = {
		order = function(info)
			return reverseClassMap[groupName(groupMap[info[#(info)]])] and 1 or 2
		end,
		type = "group",
		name = function(info)
			local name = groupName(groupMap[info[#(info)]])

			local token = reverseClassMap[name]
			if( not token ) then return name end

			return ShadowUF:Hex(ShadowUF.db.profile.classColors[token]) .. name .. "|r"
		end,
		desc = function(info)
			local group = groupMap[info[#(info)]]
			local totalInGroup = 0
			for _, aura in pairs(Indicators.auraConfig) do
				if( type(aura) == "table" and aura.group == group ) then
					totalInGroup = totalInGroup + 1
				end
			end

			return string.format(L["%d auras in group"], totalInGroup)
		end,
		args = {},
	}

	local auraConfigTable = {
		order = 0,
		type = "group",
		icon = function(info)
			local aura = auraMap[info[#(info)]]
			return tonumber(aura) and (select(3, GetSpellInfo(aura))) or nil
		end,
		name = function(info)
			local aura = auraMap[info[#(info)]]
			return tonumber(aura) and string.format("%s (#%i)", GetSpellInfo(aura) or "Unknown", aura) or aura
		end,
		hidden = function(info)
			local group = groupMap[info[#(info) - 1]]
			local aura = Indicators.auraConfig[auraMap[info[#(info)]]]
			return aura.group ~= group
		end,
		set = function(info, value, g, b, a)
			local aura = auraMap[info[#(info) - 1]]
			local key = info[#(info)]

			-- So I don't have to load every aura to see if it only triggers if it's missing
			if( key == "missing" ) then
				ShadowUF.db.profile.auraIndicators.missing[aura] = value and true or nil
				-- Changing the color
			elseif( key == "color" ) then
				Indicators.auraConfig[aura].r = value
				Indicators.auraConfig[aura].g = g
				Indicators.auraConfig[aura].b = b
				Indicators.auraConfig[aura].alpha = a

				writeAuraTable(aura)
				ShadowUF.Layout:Reload()
				return
			elseif( key == "selfColor" ) then
				Indicators.auraConfig[aura].selfColor = Indicators.auraConfig[aura].selfColor or {}
				Indicators.auraConfig[aura].selfColor.r = value
				Indicators.auraConfig[aura].selfColor.g = g
				Indicators.auraConfig[aura].selfColor.b = b
				Indicators.auraConfig[aura].selfColor.alpha = a

				writeAuraTable(aura)
				ShadowUF.Layout:Reload()
				return
			end

			Indicators.auraConfig[aura][key] = value
			writeAuraTable(aura)
			ShadowUF.Layout:Reload()
		end,
		get = function(info)
			local aura = auraMap[info[#(info) - 1]]
			local key = info[#(info)]
			local config = Indicators.auraConfig[aura]
			if( key == "color" ) then
				return config.r, config.g, config.b, config.alpha
			elseif( key == "selfColor" ) then
				if( not config.selfColor ) then return 0, 0, 0, 1 end
				return config.selfColor.r, config.selfColor.g, config.selfColor.b, config.selfColor.alpha
			end

			return config[key]
		end,
		args = {
			indicator = {
				order = 1,
				type = "select",
				name = L["Show inside"],
				desc = L["Indicator this aura should be displayed in."],
				values = getIndicatorList,
				hidden = false,
			},
			priority = {
				order = 2,
				type = "range",
				name = L["Priority"],
				desc = L["If multiple auras are shown in the same indicator, the higher priority one is shown first."],
				min = 0, max = 100, step = 1,
				hidden = false,
			},
			sep1 = {
				order = 3,
				type = "description",
				name = "",
				width = "full",
				hidden = false,
			},
			color = {
				order = 4,
				type = "color",
				name = L["Indicator color"],
				desc = L["Solid color to use in the indicator, only used if you do not have use aura icon enabled."],
				disabled = function(info) return Indicators.auraConfig[auraMap[info[#(info) - 1]]].icon end,
				hidden = false,
				hasAlpha = true,
			},
			selfColor = {
				order = 4.5,
				type = "color",
				name = L["Your aura color"],
				desc = L["This color will be used if the indicator shown is your own, only applies if icons are not used.\nHandy if you want to know if a target has a Rejuvenation on them, but you also want to know if you were the one who casted the Rejuvenation."],
				hidden = false,
				disabled = function(info)
					if( Indicators.auraConfig[auraMap[info[#(info) - 1]]].icon ) then return true end
					return Indicators.auraConfig[auraMap[info[#(info) - 1]]].player
				end,
				hasAlpha = true,
			},
			sep2 = {
				order = 5,
				type = "description",
				name = "",
				width = "full",
				hidden = false,
			},
			icon = {
				order = 6,
				type = "toggle",
				name = L["Show aura icon"],
				desc = L["Instead of showing a solid color inside the indicator, the icon of the aura will be shown."],
				hidden = false,
			},
			duration = {
				order = 7,
				type = "toggle",
				name = L["Show aura duration"],
				desc = L["Shows a cooldown wheel on the indicator with how much time is left on the aura."],
				hidden = false,
			},
			player = {
				order = 8,
				type = "toggle",
				name = L["Only show self cast auras"],
				desc = L["Only auras you specifically cast will be shown."],
				hidden = false,
			},
			missing = {
				order = 9,
				type = "toggle",
				name = L["Only show if missing"],
				desc = L["Only active this aura inside an indicator if the group member does not have the aura."],
				hidden = false,
			},
			delete = {
				order = 10,
				type = "execute",
				name = L["Delete"],
				hidden = function(info)
					return ShadowUF.db.defaults.profile.auraIndicators.auras[auraMap[info[#(info) - 1]]]
				end,
				confirm = true,
				confirmText = L["Are you sure you want to delete this aura?"],
				func = function(info)
					local key = info[#(info) - 1]
					local aura = auraMap[key]

					auraGroupTable.args[key] = nil
					ShadowUF.db.profile.auraIndicators.auras[aura] = nil
					ShadowUF.db.profile.auraIndicators.missing[aura] = nil
					Indicators.auraConfig[aura] = nil

					-- Check if the group should disappear
					local groupList = getAuraGroup(info)
					for groupID, name in pairs(groupMap) do
						if( not groupList[name] ) then
							unitTable.args[tostring(groupID)] = nil
							auraIndicatorsOptions.args.units.args.global.args.groups.args[tostring(groupID)] = nil
							auraIndicatorsOptions.args.auras.args.groups.args[tostring(groupID)] = nil
							groupMap[groupID] = nil
						end
					end

					ShadowUF.Layout:Reload()
				end,
			},
		},
	}

	local auraFilterConfigTable = {
		order = 0,
		type = "group",
		hidden = false,
		name = function(info)
			return ShadowUF.db.profile.auraIndicators.indicators[info[#(info)]].name
		end,
		set = function(info, value)
			local key = info[#(info)]
			local indicator = info[#(info) - 2]
			local filter = info[#(info) - 1]
			ShadowUF.db.profile.auraIndicators.filters[indicator][filter][key] = value
			ShadowUF.Layout:Reload()
		end,
		get = function(info)
			local key = info[#(info)]
			local indicator = info[#(info) - 2]
			local filter = info[#(info) - 1]
			if( not ShadowUF.db.profile.auraIndicators.filters[indicator][filter] ) then
				ShadowUF.db.profile.auraIndicators.filters[indicator][filter] = {}
			end

			return ShadowUF.db.profile.auraIndicators.filters[indicator][filter][key]
		end,
		args = {
			help = {
				order = 0,
				type = "group",
				name = L["Help"],
				inline = true,
				args = {
					help = {
						type = "description",
						name = L["Auras matching a criteria will automatically show up in the indicator when enabled."]
					}
				}
			},
			boss = {
				order = 1,
				type = "group",
				name = L["Boss Auras"],
				inline = true,
				args = {
					enabled = {
						order = 1,
						type = "toggle",
						name = L["Show boss debuffs"],
						desc = L["Shows debuffs cast by a boss."]
					},
					duration = {
						order = 2,
						type = "toggle",
						name = L["Show aura duration"],
						desc = L["Shows a cooldown wheel on the indicator with how much time is left on the aura."]
					},
					priority = {
						order = 3,
						type = "range",
						name = L["Priority"],
						desc = L["If multiple auras are shown in the same indicator, the higher priority one is shown first."],
						min = 0, max = 100, step = 1
					}
				}
			},
			curable = {
				order = 2,
				type = "group",
				name = L["Curable Auras"],
				inline = true,
				args = {
					enabled = {
						order = 1,
						type = "toggle",
						name = L["Show curable debuffs"],
						desc = L["Shows debuffs that you can cure."]
					},
					duration = {
						order = 2,
						type = "toggle",
						name = L["Show aura duration"],
						desc = L["Shows a cooldown wheel on the indicator with how much time is left on the aura."]
					},
					priority = {
						order = 3,
						type = "range",
						name = L["Priority"],
						desc = L["If multiple auras are shown in the same indicator, the higher priority one is shown first."],
						min = 0, max = 100, step = 1
					}
				}
			}
		}
	}

	local indicatorTable = {
		order = 1,
		type = "group",
		name = function(info) return ShadowUF.db.profile.auraIndicators.indicators[info[#(info)]].name end,
		args = {
			config = {
				order = 0,
				type = "group",
				inline = true,
				name = function(info) return ShadowUF.db.profile.auraIndicators.indicators[info[#(info) - 1]].name end,
				set = function(info, value)
					local indicator = info[#(info) - 2]
					local key = info[#(info)]

					ShadowUF.db.profile.auraIndicators.indicators[indicator][key] = value
					ShadowUF.Layout:Reload()
				end,
				get = function(info)
					local indicator = info[#(info) - 2]
					local key = info[#(info)]
					return ShadowUF.db.profile.auraIndicators.indicators[indicator][key]
				end,
				args = {
					showStack = {
						order = 1,
						type = "toggle",
						name = L["Show auras stack"],
						desc = L["Any auras shown in this indicator will have their total stack displayed."],
						width = "full",
					},
					friendly = {
						order = 2,
						type = "toggle",
						name = L["Enable for friendlies"],
						desc = L["Checking this will show the indicator on friendly units."],
					},
					hostile = {
						order = 3,
						type = "toggle",
						name = L["Enable for hostiles"],
						desc = L["Checking this will show the indciator on hostile units."],
					},
					anchorPoint = {
						order = 4,
						type = "select",
						name = L["Anchor point"],
						values = {["BRI"] = L["Inside Bottom Right"], ["BLI"] = L["Inside Bottom Left"], ["TRI"] = L["Inside Top Right"], ["TLI"] = L["Inside Top Left"], ["CLI"] = L["Inside Center Left"], ["C"] = L["Center"], ["CRI"] = L["Inside Center Right"]},
					},
					size = {
						order = 5,
						name = L["Size"],
						type = "range",
						min = 0, max = 50, step = 1,
						set = function(info, value)
							local indicator = info[#(info) - 2]
							ShadowUF.db.profile.auraIndicators.indicators[indicator].height = value
							ShadowUF.db.profile.auraIndicators.indicators[indicator].width = value
							ShadowUF.Layout:Reload()
						end,
						get = function(info)
							local indicator = info[#(info) - 2]
							return ShadowUF.db.profile.auraIndicators.indicators[indicator].height
						end,
					},
					x = {
						order = 6,
						type = "range",
						name = L["X Offset"],
						min = -50, max = 50, step = 1,
					},
					y = {
						order = 7,
						type = "range",
						name = L["Y Offset"],
						min = -50, max = 50, step = 1,
					},
					delete = {
						order = 8,
						type = "execute",
						name = L["Delete"],
						confirm = true,
						confirmText = L["Are you sure you want to delete this indicator?"],
						func = function(info)
							local indicator = info[#(info) - 2]

							auraIndicatorsOptions.args.indicators.args[indicator] = nil
							auraIndicatorsOptions.args.auras.args.filters.args[indicator] = nil

							ShadowUF.db.profile.auraIndicators.indicators[indicator] = nil
							ShadowUF.db.profile.auraIndicators.filters[indicator] = nil

							-- Any aura that was set to us should be swapped back to none
							for name in pairs(ShadowUF.db.profile.auraIndicators.auras) do
								local aura = Indicators.auraConfig[name]
								if( aura.indicator == indicator ) then
									aura.indicator = ""
									writeAuraTable(name)
								end
							end

							ShadowUF.Layout:Reload()
						end,
					},
				},
			},
		},
	}

	local parentLinkTable = {
		order = 3,
		type = "group",
		icon = function(info)
			local aura = auraMap[info[#(info)]]
			return tonumber(aura) and (select(3, GetSpellInfo(aura))) or nil
		end,
		name = function(info)
			local aura = linkMap[info[#(info)]]
			return tonumber(aura) and string.format("%s (#%i)", GetSpellInfo(aura) or "Unknown", aura) or aura
		end,
		args = {},
	}

	local childLinkTable = {
		order = 1,
		icon = function(info)
			local aura = auraMap[info[#(info)]]
			return tonumber(aura) and (select(3, GetSpellInfo(aura))) or nil
		end,
		name = function(info)
			local aura = linkMap[info[#(info)]]
			return tonumber(aura) and string.format("%s (#%i)", GetSpellInfo(aura) or "Unknown", aura) or aura
		end,
		hidden = function(info)
			local aura = linkMap[info[#(info)]]
			local parent = linkMap[info[#(info) - 1]]

			return ShadowUF.db.profile.auraIndicators.linked[aura] ~= parent
		end,
		type = "group",
		inline = true,
		args = {
			delete = {
				type = "execute",
				name = L["Delete link"],
				hidden = false,
				func = function(info)
					local auraID = info[#(info) - 1]
					local aura = linkMap[auraID]
					local parent = ShadowUF.db.profile.auraIndicators.linked[aura]
					ShadowUF.db.profile.auraIndicators.linked[aura] = nil
					parentLinkTable.args[auraID] = nil

					local found
					for _, to in pairs(ShadowUF.db.profile.auraIndicators.linked) do
						if( to == parent ) then
							found = true
							break
						end
					end

					if( not found ) then
						for id, name in pairs(linkMap) do
							if( name == parent ) then
								auraIndicatorsOptions.args.linked.args[tostring(id)] = nil
								linkMap[id] = nil
							end
						end
					end

					ShadowUF.Layout:Reload()
				end,
			},
		},
	}

	local addAura, addLink, setGlobalUnits, globalConfig = {}, {}, {}, {}

	-- Per unit enabled status
	unitTable = {
		order = ShadowUF.Config.getUnitOrder or 1,
		type = "group",
		name = function(info) return L.units[info[3]] end,
		hidden = function(info) return not ShadowUF.db.profile.units[info[3]].enabled end,
		desc = function(info)
			local totalDisabled = 0
			for key, enabled in pairs(ShadowUF.db.profile.units[info[3]].auraIndicators) do
				if( key ~= "enabled" and enabled ) then
					totalDisabled = totalDisabled + 1
				end
			end

			if( totalDisabled == 1 ) then return L["1 aura group disabled"] end
			return totalDisabled > 0 and string.format(L["%s aura groups disabled"], totalDisabled) or L["All aura groups enabled for unit."]
		end,
		args = {
			enabled = {
				order = 1,
				inline = true,
				type = "group",
				name = function(info) return string.format(L["On %s units"], L.units[info[3]]) end,
				args = {
					enabled = {
						order = 1,
						type = "toggle",
						name = L["Enable Indicators"],
						desc = function(info) return string.format(L["Unchecking this will completely disable aura indicators for %s."], L.units[info[3]]) end,
						set = function(info, value) ShadowUF.db.profile.units[info[3]].auraIndicators.enabled = value; ShadowUF.Layout:Reload() end,
						get = function(info) return ShadowUF.db.profile.units[info[3]].auraIndicators.enabled end,
					},
				},
			},
			filters = {
				order = 2,
				inline = true,
				type = "group",
				name = L["Aura Filters"],
				disabled = function(info) return not ShadowUF.db.profile.units[info[3]].auraIndicators.enabled end,
				args = {},
			},
			groups = {
				order = 3,
				inline = true,
				type = "group",
				name = L["Aura Groups"],
				disabled = function(info) return not ShadowUF.db.profile.units[info[3]].auraIndicators.enabled end,
				args = {},
			},
		}
	}

	local unitFilterTable = {
		order = 1,
		type = "toggle",
		name = function(info) return info[#(info)] == "boss" and L["Boss Auras"] or L["Curable Auras"] end,
		desc = function(info)
			local auraIndicators = ShadowUF.db.profile.units[info[3]].auraIndicators
			return auraIndicators["filter-" .. info[#(info)]] and string.format(L["Disabled for %s."], L.units[info[3]]) or string.format(L["Enabled for %s."], L.units[info[3]])
		end,
		set = function(info, value) ShadowUF.db.profile.units[info[3]].auraIndicators["filter-" .. info[#(info)]] = not value and true or nil end,
		get = function(info, value) return not ShadowUF.db.profile.units[info[3]].auraIndicators["filter-" .. info[#(info)]] end
	}

	local globalUnitFilterTable = {
		order = 1,
		type = "toggle",
		name = function(info) return info[#(info)] == "boss" and L["Boss Auras"] or L["Curable Auras"] end,
		disabled = function(info) for unit in pairs(setGlobalUnits) do return false end return true end,
		set = function(info, value)
			local key = "filter-" .. info[#(info)]
			globalConfig[key] = not value and true or nil

			for unit in pairs(setGlobalUnits) do
				ShadowUF.db.profile.units[unit].auraIndicators[key] = globalConfig[key]
			end
		end,
		get = function(info, value) return not globalConfig["filter-" .. info[#(info)]] end
	}

	local unitGroupTable = {
		order = function(info)
			return reverseClassMap[groupName(groupMap[info[#(info)]])] and 1 or 2
		end,
		type = "toggle",
		name = function(info)
			local name = groupName(groupMap[info[#(info)]])
			local token = reverseClassMap[name]
			if( not token ) then return name end
			return ShadowUF:Hex(ShadowUF.db.profile.classColors[token]) .. name .. "|r"
		end,
		desc = function(info)
			local auraIndicators = ShadowUF.db.profile.units[info[3]].auraIndicators
			local group = groupName(groupMap[info[#(info)]])

			return auraIndicators[group] and string.format(L["Disabled for %s."], L.units[info[3]]) or string.format(L["Enabled for %s."], L.units[info[3]])
		end,
		set = function(info, value) ShadowUF.db.profile.units[info[3]].auraIndicators[groupMap[info[#(info)]]] = not value and true or nil end,
		get = function(info, value) return not ShadowUF.db.profile.units[info[3]].auraIndicators[groupMap[info[#(info)]]] end
	}

	local globalUnitGroupTable = {
		type = "toggle",
		order = function(info)
			return reverseClassMap[groupName(groupMap[info[#(info)]])] and 1 or 2
		end,
		name = function(info)
			local name = groupName(groupMap[info[#(info)]])
			local token = reverseClassMap[name]
			if( not token ) then return name end
			return ShadowUF:Hex(ShadowUF.db.profile.classColors[token]) .. name .. "|r"
		end,
		disabled = function(info) for unit in pairs(setGlobalUnits) do return false end return true end,
		set = function(info, value)
			local auraGroup = groupMap[info[#(info)]]
			globalConfig[auraGroup] = not value and true or nil

			for unit in pairs(setGlobalUnits) do
				ShadowUF.db.profile.units[unit].auraIndicators[auraGroup] = globalConfig[auraGroup]
			end
		end,
		get = function(info, value) return not globalConfig[groupMap[info[#(info)]]] end
	}

	local enabledUnits = {}
	local function getEnabledUnits()
		table.wipe(enabledUnits)
		for unit, config in pairs(ShadowUF.db.profile.units) do
			if( config.enabled and config.auraIndicators.enabled ) then
				enabledUnits[unit] = L.units[unit]
			end
		end

		return enabledUnits
	end

	local widthReset

	-- Actual tab view thing
	auraIndicatorsOptions = {
		order = 4.5,
		type = "group",
		name = L["Aura Indicators"],
		desc = L["For configuring aura indicators on unit frames."],
		childGroups = "tab",
		hidden = false,
		args = {
			indicators = {
				order = 1,
				type = "group",
				name = L["Indicators"],
				childGroups = "tree",
				args = {
					add = {
						order = 0,
						type = "group",
						name = L["Add Indicator"],
						args = {
							add = {
								order = 0,
								type = "group",
								inline = true,
								name = L["Add new indicator"],
								args = {
									name = {
										order = 0,
										type = "input",
										name = L["Indicator name"],
										width = "full",
										set = function(info, value)
											local id = string.format("%d", GetTime() + math.random(100))
											ShadowUF.db.profile.auraIndicators.indicators[id] = {enabled = true, friendly = true, hostile = true, name = value, anchorPoint = "C", anchorTo = "$parent", height = 10, width = 10, alpha = 1.0, x = 0, y = 0}
											ShadowUF.db.profile.auraIndicators.filters[id] = {boss = {}, curable = {}}

											auraIndicatorsOptions.args.indicators.args[id] = indicatorTable
											auraIndicatorsOptions.args.auras.args.filters.args[id] = auraFilterConfigTable

											Config.AceDialog.Status.ShadowedUF.children.auraIndicators.children.indicators.status.groups.selected = id
											Config.AceRegistry:NotifyChange("ShadowedUF")
										end,
										get = function() return "" end,
									},
								},
							},
						},
					},
				},
			},
			auras = {
				order = 2,
				type = "group",
				name = L["Auras"],
				hidden = function(info)
					if( not widthReset and Config.AceDialog.Status.ShadowedUF.children.auraIndicators ) then
						if( Config.AceDialog.Status.ShadowedUF.children.auraIndicators.children.auras ) then
							widthReset = true

							Config.AceDialog.Status.ShadowedUF.children.auraIndicators.children.auras.status.groups.treewidth = 230

							Config.AceDialog.Status.ShadowedUF.children.auraIndicators.children.auras.status.groups.groups = {}
							Config.AceDialog.Status.ShadowedUF.children.auraIndicators.children.auras.status.groups.groups.filters = true
							Config.AceDialog.Status.ShadowedUF.children.auraIndicators.children.auras.status.groups.groups.groups = true

							Config.AceRegistry:NotifyChange("ShadowedUF")
						end
					end

					return false
				end,
				args = {
					add = {
						order = 0,
						type = "group",
						name = L["Add Aura"],
						set = function(info, value) addAura[info[#(info)]] = value end,
						get = function(info) return addAura[info[#(info)]] end,
						args = {
							name = {
								order = 0,
								type = "input",
								name = L["Spell Name/ID"],
								desc = L["If name is entered, it must be exact as it is case sensitive. Alternatively, you can use spell id instead."]
							},
							group = {
								order = 1,
								type = "select",
								name = L["Aura group"],
								desc = L["What group this aura belongs to, this is where you will find it when configuring."],
								values = getAuraGroup,
							},
							custom = {
								order = 2,
								type = "input",
								name = L["New aura group"],
								desc = L["Allows you to enter a new aura group."],
							},
							create = {
								order = 3,
								type = "execute",
								name = L["Add aura"],
								disabled = function(info) return not addAura.name or (not addAura.group and not addAura.custom) end,
								func = function(info)
									local group = string.trim(addAura.custom or "")
									if( group == "" ) then group = string.trim(addAura.group or "") end
									if( group == "" ) then group = L["Miscellaneous"] end

									-- Don't overwrite an existing group, but don't tell them either, mostly because I don't want to add error reporting code
									if( not ShadowUF.db.profile.auraIndicators.auras[addAura.name] ) then
										-- Odds are, if they are saying to show it only if a buff is missing it's cause they want to know when their own class buff is not there
										-- so will cheat it, and jump start it by storing the texture if we find it from GetSpellInfo directly
										Indicators.auraConfig[addAura.name] = {indicator = "", group = group, iconTexture = select(3, GetSpellInfo(addAura.name)), priority = 0, r = 0, g = 0, b = 0}
										writeAuraTable(addAura.name)

										auraID = auraID + 1
										auraMap[tostring(auraID)] = addAura.name
										auraGroupTable.args[tostring(auraID)] = auraConfigTable
									end

									addAura.name = nil
									addAura.custom = nil
									addAura.group = nil

									-- Check if the group exists
									local gID
									for id, name in pairs(groupMap) do
										if( name == group ) then
											gID = id
											break
										end
									end

									if( not gID ) then
										groupID = groupID + 1
										groupMap[tostring(groupID)] = group

										unitTable.args.groups.args[tostring(groupID)] = unitGroupTable
										auraIndicatorsOptions.args.units.args.global.args.groups.args[tostring(groupID)] = globalUnitGroupTable
										auraIndicatorsOptions.args.auras.args.groups.args[tostring(groupID)] = auraGroupTable
									end

									-- Shunt the user to the this groups page
									Config.AceDialog.Status.ShadowedUF.children.auraIndicators.children.auras.status.groups.selected = tostring(gID or groupID)
									Config.AceRegistry:NotifyChange("ShadowedUF")

									ShadowUF.Layout:Reload()
								end,
							},
						},
					},
					filters = {
						order = 1,
						type = "group",
						name = L["Automatic Auras"],
						args = {}
					},
					groups = {
						order = 2,
						type = "group",
						name = L["Groups"],
						args = {}
					},
				},
			},
			linked = {
				order = 3,
				type = "group",
				name = L["Linked spells"],
				childGroups = "tree",
				hidden = true,
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
								name = L["You can link auras together using this, for example you can link Mark of the Wild to Gift of the Wild so if the player has Mark of the Wild but not Gift of the Wild, it will still show Mark of the Wild as if they had Gift of the Wild."],
								width = "full",
							},
						},
					},
					add = {
						order = 1,
						type = "group",
						name = L["Add link"],
						inline = true,
						set = function(info, value)
							addLink[info[#(info)] ] = value
						end,
						get = function(info) return addLink[info[#(info)] ] end,
						args = {
							from = {
								order = 0,
								type = "input",
								name = L["Link from"],
								desc = L["Spell you want to link to a primary aura, the casing must be exact."],
							},
							to = {
								order = 1,
								type = "select",
								name = L["Link to"],
								values = getAuraList,
							},
							link = {
								order = 3,
								type = "execute",
								name = L["Link"],
								disabled = function() return not addLink.from or not addLink.to or addLink.from == "" end,
								func = function(info)
									local lID, pID
									for id, name in pairs(linkMap) do
										if( name == addLink.from ) then
											lID = id
										elseif( name == addLink.to ) then
											pID = id
										end
									end

									if( not pID ) then
										linkID = linkID + 1
										pID = linkID
										linkMap[tostring(linkID)] = addLink.to
									end

									if( not lID ) then
										linkID = linkID + 1
										lID = linkID
										linkMap[tostring(linkID)] = addLink.from
									end

									ShadowUF.db.profile.auraIndicators.linked[addLink.from] = addLink.to
									auraIndicatorsOptions.args.linked.args[tostring(pID)] = parentLinkTable
									parentLinkTable.args[tostring(lID)] = childLinkTable

									addLink.from = nil
									addLink.to = nil

									ShadowUF.Layout:Reload()
								end,
							},
						},
					},
				},
			},
			units = {
				order = 4,
				type = "group",
				name = L["Enable Indicators"],
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
								name = L["You can disable aura filters and groups for units here. For example, you could set an aura group that shows DPS debuffs to only show on the target."],
								width = "full",
							},
						},
					},
					global = {
						order = 0,
						type = "group",
						name = L["Global"],
						desc = L["Global configurating will let you mass enable or disable aura groups for multiple units at once."],
						args = {
							units = {
								order = 0,
								type = "multiselect",
								name = L["Units to change"],
								desc = L["Units that should have the aura groups settings changed below."],
								values = getEnabledUnits,
								set = function(info, unit, enabled) setGlobalUnits[unit] = enabled or nil end,
								get = function(info, unit) return setGlobalUnits[unit] end,
							},
							filters = {
								order = 1,
								type = "group",
								inline = true,
								name = L["Aura filters"],
								args = {}
							},
							groups = {
								order = 2,
								type = "group",
								inline = true,
								name = L["Aura groups"],
								args = {}
							},
						},
					},
				},
			},
			classes = {
				order = 5,
				type = "group",
				name = L["Disable Auras by Class"],
				childGroups = "tree",
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
								name = L["You can override what aura is enabled on a per-class basis, note that if the aura is disabled through the main listing, then your class settings here will not matter."],
								width = "full",
							},
						},
					}
				},
			},
		},
	}

	local classTable = {
		order = 1,
		type = "group",
		name = function(info)
			return ShadowUF:Hex(ShadowUF.db.profile.classColors[info[#(info)]]) .. LOCALIZED_CLASS_NAMES_MALE[info[#(info)]] .. "|r"
		end,
		args = {},
	}

	local classAuraTable = {
		order = 1,
		type = "toggle",
		icon = function(info)
			local aura = auraMap[info[#(info)]]
			return tonumber(aura) and (select(3, GetSpellInfo(aura))) or nil
		end,
		name = function(info)
			local aura = tonumber(auraMap[info[#(info)]])
			if( not aura ) then	return auraMap[info[#(info)]] end

			local name, _, icon = GetSpellInfo(aura)
			if( not name ) then return name end

			return "|T" .. icon .. ":18:18:0:0|t " .. name
		end,
		desc = function(info)
			local aura = auraMap[info[#(info)]]
			if( tonumber(aura) ) then
				return string.format(L["Spell ID %s"], aura)
			else
				return aura
			end
		end,
		set = function(info, value)
			local aura = auraMap[info[#(info)]]
			local class = info[#(info) - 1]
			value = not value

			if( value == false ) then value = nil end
			ShadowUF.db.profile.auraIndicators.disabled[class][aura] = value
			ShadowUF.Layout:Reload()
		end,
		get = function(info)
			local aura = auraMap[info[#(info)]]
			local class = info[#(info) - 1]

			return not ShadowUF.db.profile.auraIndicators.disabled[class][aura]
		end,
	}

	-- Build links
	local addedFrom = {}
	for from, to in pairs(ShadowUF.db.profile.auraIndicators.linked) do
		local pID = addedFrom[to]
		if( not pID ) then
			linkID = linkID + 1
			pID = linkID

			addedFrom[to] = pID
		end

		linkID = linkID + 1

		ShadowUF.db.profile.auraIndicators.linked[from] = to
		auraIndicatorsOptions.args.linked.args[tostring(pID)] = parentLinkTable
		parentLinkTable.args[tostring(linkID)] = childLinkTable

		linkMap[tostring(linkID)] = from
		linkMap[tostring(pID)] = to
	end

	-- Build the aura configuration
	local groups = {}
	for name in pairs(ShadowUF.db.profile.auraIndicators.auras) do
		local aura = Indicators.auraConfig[name]
		if( aura.group ) then
			auraMap[tostring(auraID)] = name
			auraGroupTable.args[tostring(auraID)] = auraConfigTable
			classTable.args[tostring(auraID)] = classAuraTable
			auraID = auraID + 1

			groups[aura.group] = true
		end
	end

	-- Now create all of the parent stuff
	for group in pairs(groups) do
		groupMap[tostring(groupID)] = group
		unitTable.args.groups.args[tostring(groupID)] = unitGroupTable

		auraIndicatorsOptions.args.units.args.global.args.groups.args[tostring(groupID)] = globalUnitGroupTable
		auraIndicatorsOptions.args.auras.args.groups.args[tostring(groupID)] = auraGroupTable

		groupID = groupID + 1
	end

	for _, type in pairs(auraFilters) do
		unitTable.args.filters.args[type] = unitFilterTable
		auraIndicatorsOptions.args.units.args.global.args.filters.args[type] = globalUnitFilterTable
	end

	-- Aura status by unit
	for unit, config in pairs(ShadowUF.db.profile.units) do
		auraIndicatorsOptions.args.units.args[unit] = unitTable
	end

	-- Build class status thing
	for classToken in pairs(Config.const.CLASSIC_RAID_CLASS_COLORS) do
		auraIndicatorsOptions.args.classes.args[classToken] = classTable
	end

	-- Quickly build the indicator one
	for key in pairs(ShadowUF.db.profile.auraIndicators.indicators) do
		auraIndicatorsOptions.args.indicators.args[key] = indicatorTable
		auraIndicatorsOptions.args.auras.args.filters.args[key] = auraFilterConfigTable
	end

	-- Automatically unlock the advanced text configuration for raid frames, regardless of advanced being enabled
	local advanceTextTable = ShadowUF.Config.advanceTextTable
	local originalHidden = advanceTextTable.args.sep.hidden
	local function unlockRaidText(info)
		if( info[2] == "raid" ) then return false end
		return originalHidden(info)
	end

	advanceTextTable.args.anchorPoint.hidden = unlockRaidText
	advanceTextTable.args.sep.hidden = unlockRaidText
	advanceTextTable.args.x.hidden = unlockRaidText
	advanceTextTable.args.y.hidden = unlockRaidText

	return auraIndicatorsOptions
end
