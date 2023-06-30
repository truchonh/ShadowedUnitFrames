local L = ShadowUF.L
local Config = ShadowUF.Config
local playerClass = select(2, UnitClass("player"))

function Config:loadGeneralOptions()
	Config.SML = Config.SML or LibStub:GetLibrary("LibSharedMedia-3.0")

	local generalOptions = {}

	local MediaList = {}
	local function getMediaData(info)
		local mediaType = info[#(info)]

		MediaList[mediaType] = MediaList[mediaType] or {}

		for k in pairs(MediaList[mediaType]) do	MediaList[mediaType][k] = nil end
		for _, name in pairs(Config.SML:List(mediaType)) do
			MediaList[mediaType][name] = name
		end

		return MediaList[mediaType]
	end


	local barModules = {}
	for	key, module in pairs(ShadowUF.modules) do
		if( module.moduleHasBar ) then
			barModules["$" .. key] = module.moduleName
		end
	end

	local addTextParent = {
		order = 4,
		type = "group",
		inline = true,
		name = function(info) return barModules[info[#(info)]] or string.sub(info[#(info)], 2) end,
		hidden = function(info)
			for _, text in pairs(ShadowUF.db.profile.units.player.text) do
				if( text.anchorTo == info[#(info)] ) then
					return false
				end
			end

			return true
		end,
		args = {},
	}

	local addTextLabel = {
		order = function(info) return tonumber(string.match(info[#(info)], "(%d+)")) end,
		type = "description",
		width = "",
		fontSize = "medium",
		hidden = function(info)
			local id = tonumber(string.match(info[#(info)], "(%d+)"))
			if( not Config.getVariable("player", "text", nil, id) ) then return true end
			return Config.getVariable("player", "text", id, "anchorTo") ~= info[#(info) - 1]
		end,
		name = function(info)
			return Config.getVariable("player", "text", tonumber(string.match(info[#(info)], "(%d+)")), "name")
		end,
	}

	local addTextSep = {
		order = function(info) return tonumber(string.match(info[#(info)], "(%d+)")) + 0.75 end,
		type = "description",
		width = "full",
		hidden = function(info)
			local id = tonumber(string.match(info[#(info)], "(%d+)"))
			if( not Config.getVariable("player", "text", nil, id) ) then return true end
			return Config.getVariable("player", "text", id, "anchorTo") ~= info[#(info) - 1]
		end,
		name = "",
	}

	local addText = {
		order = function(info) return info[#(info)] + 0.5 end,
		type = "execute",
		width = "half",
		name = L["Delete"],
		hidden = function(info)
			local id = tonumber(info[#(info)])
			if( not Config.getVariable("player", "text", nil, id) ) then return true end
			return Config.getVariable("player", "text", id, "anchorTo") ~= info[#(info) - 1]
		end,
		disabled = function(info)
			local id = tonumber(info[#(info)])
			for _, unit in pairs(ShadowUF.unitList) do
				if( ShadowUF.db.profile.units[unit].text[id] and ShadowUF.db.profile.units[unit].text[id].default ) then
					return true
				end
			end

			return false
		end,
		confirmText = L["Are you sure you want to delete this text? All settings for it will be deleted."],
		confirm = true,
		func = function(info)
			local id = tonumber(info[#(info)])
			for _, unit in pairs(ShadowUF.unitList) do
				table.remove(ShadowUF.db.profile.units[unit].text, id)
			end

			addTextParent.args[info[#(info)]] = nil
			ShadowUF.Layout:Reload()
		end,
	}

	local function validateSpell(info, spell)
		if( spell and spell ~= "" and not GetSpellInfo(spell) ) then
			return string.format(L["Invalid spell \"%s\" entered."], spell or "")
		end

		return true
	end

	local function setRange(info, spell)
		ShadowUF.db.profile.range[info[#(info)] .. playerClass] = spell and spell ~= "" and spell or nil
		ShadowUF.Layout:Reload()
	end

	local function getRange(info)
		return ShadowUF.db.profile.range[info[#(info)] .. playerClass]
	end

	local function rangeWithIcon(info)
		local name = getRange(info)
		local text = L["Spell Name"]
		if( string.match(info[#(info)], "Alt") ) then
			text = L["Alternate Spell Name"]
		end

		local icon = select(3, GetSpellInfo(name))
		if( not icon ) then
			icon = "Interface\\Icons\\Inv_misc_questionmark"
		end

		return "|T" .. icon .. ":18:18:0:0|t " .. text
	end

	local textData = {}

	local layoutData = {positions = true, visibility = true, modules = false}
	local layoutManager = {
		type = "group",
		order = 7,
		name = L["Layout manager"],
		childGroups = "tab",
		hidden = Config.hideAdvancedOption,
		args = {
			import = {
				order = 1,
				type = "group",
				name = L["Import"],
				hidden = false,
				args = {
					help = {
						order = 1,
						type = "group",
						inline = true,
						name = function(info) return layoutData.error and L["Error"] or L["Help"] end,
						args = {
							help = {
								order = 1,
								type = "description",
								name = function(info)
									if( ShadowUF.db:GetCurrentProfile() == "Import Backup" ) then
										return L["Your active layout is the profile used for import backup, this cannot be overwritten by an import. Change your profiles to something else and try again."]
									end

									return layoutData.error or L["You can import another Shadowed Unit Frame users configuration by entering the export code they gave you below. This will backup your old layout to \"Import Backup\".|n|nIt will take 30-60 seconds for it to load your layout when you paste it in, please by patient."]
								end
							},
						},
					},
					positions = {
						order = 2,
						type = "toggle",
						name = L["Import unit frame positions"],
						set = function(info, value) layoutData[info[#(info)]] = value end,
						get = function(info) return layoutData[info[#(info)]] end,
						width = "double",
					},
					visibility = {
						order = 3,
						type = "toggle",
						name = L["Import visibility settings"],
						set = function(info, value) layoutData[info[#(info)]] = value end,
						get = function(info) return layoutData[info[#(info)]] end,
						width = "double",
					},
					import = {
						order = 5,
						type = "input",
						name = L["Code"],
						multiline = true,
						width = "full",
						get = false,
						disabled = function() return ShadowUF.db:GetCurrentProfile() == "Import Backup" end,
						set = function(info, import)
							local layout, err = loadstring(string.format([[return %s]], import))
							if( err ) then
								layoutData.error = string.format(L["Failed to import layout, error:|n|n%s"], err)
								return
							end

							layout = layout()

							-- Strip position settings
							if( not layoutData.positions ) then
								layout.positions = nil
							end

							-- Strip visibility settings
							if( not layoutData.visibility ) then
								layout.visibility = nil
							end

							-- Strip any units we don't have included by default
							for unit in pairs(layout.units) do
								if( not ShadowUF.defaults.profile.units[unit] ) then
									layout.units[unit] = nil
								end
							end

							-- Check if we need move over the visibility and positions info
							layout.positions = layout.positions or CopyTable(ShadowUF.db.profile.positions)
							layout.visibility = layout.visibility or CopyTable(ShadowUF.db.profile.positions)

							-- Now backup the profile
							local currentLayout = ShadowUF.db:GetCurrentProfile()
							ShadowUF.layoutImporting = true
							ShadowUF.db:SetProfile("Import Backup")
							ShadowUF.db:CopyProfile(currentLayout)
							ShadowUF.db:SetProfile(currentLayout)
							ShadowUF.db:ResetProfile()
							ShadowUF.layoutImporting = nil

							-- Overwrite everything we did import
							ShadowUF:LoadDefaultLayout()
							for key, data in pairs(layout) do
								if( type(data) == "table" ) then
									ShadowUF.db.profile[key] = CopyTable(data)
								else
									ShadowUF.db.profile[key] = data
								end
							end

							ShadowUF:ProfilesChanged()
						end,
					},
				},
			},
			export = {
				order = 2,
				type = "group",
				name = L["Export"],
				hidden = false,
				args = {
					help = {
						order = 1,
						type = "group",
						inline = true,
						name = L["Help"],
						args = {
							help = {
								order = 1,
								type = "description",
								name = L["After you hit export, you can give the below code to other Shadowed Unit Frames users and they will get your exact layout."],
							},
						},
					},
					doExport = {
						order = 2,
						type = "execute",
						name = L["Export"],
						func = function(info)
							layoutData.export = Config.writeTable(ShadowUF.db.profile)
						end,
					},
					export = {
						order = 3,
						type = "input",
						name = L["Code"],
						multiline = true,
						width = "full",
						set = false,
						get = function(info) return layoutData[info[#(info)]] end,
					},
				},
			},
		},
	}

	generalOptions = {
		type = "group",
		childGroups = "tab",
		name = L["General"],
		args = {
			general = {
				type = "group",
				order = 1,
				name = L["General"],
				set = Config.set,
				get = Config.get,
				args = {
					general = {
						order = 1,
						type = "group",
						inline = true,
						name = L["General"],
						args = {
							locked = {
								order = 1,
								type = "toggle",
								name = L["Lock frames"],
								desc = L["Enables configuration mode, letting you move and giving you example frames to setup."],
								set = function(info, value)
									Config.set(info, value)
									ShadowUF.modules.movers:Update()
								end,
								arg = "locked",
							},
							advanced = {
								order = 1.5,
								type = "toggle",
								name = L["Advanced"],
								desc = L["Enabling advanced settings will give you access to more configuration options. This is meant for people who want to tweak every single thing, and should not be enabled by default as it increases the options."],
								arg = "advanced",
							},
							sep = {
								order = 2,
								type = "description",
								name = "",
								width = "full",
							},
							omnicc = {
								order = 2.5,
								type = "toggle",
								name = L["Disable OmniCC Cooldown Count"],
								desc = L["Disables showing Cooldown Count timers in all Shadowed Unit Frame auras."],
								arg = "omnicc",
								width = "double",
							},
							blizzardcc = {
								order = 2.5,
								type = "toggle",
								name = L["Disable Blizzard Cooldown Count"],
								desc = L["Disables showing Cooldown Count timers in all Shadowed Unit Frame auras."],
								arg = "blizzardcc",
								width = "double",
							},
							hideCombat = {
								order = 3,
								type = "toggle",
								name = L["Hide tooltips in combat"],
								desc = L["Prevents unit tooltips from showing while in combat."],
								arg = "tooltipCombat",
								width = "double",
							},
							sep2 = {
								order = 3.5,
								type = "description",
								name = "",
								width = "full",
							},
							auraBorder = {
								order = 5,
								type = "select",
								name = L["Aura border style"],
								desc = L["Style of borders to show for all auras."],
								values = {["dark"] = L["Dark"], ["light"] = L["Light"], ["blizzard"] = L["Blizzard"], [""] = L["None"]},
								arg = "auras.borderType",
							},
							statusbar = {
								order = 6,
								type = "select",
								name = L["Bar texture"],
								dialogControl = "LSM30_Statusbar",
								values = getMediaData,
								arg = "bars.texture",
							},
							spacing = {
								order = 7,
								type = "range",
								name = L["Bar spacing"],
								desc = L["How much spacing should be provided between all of the bars inside a unit frame, negative values move them farther apart, positive values bring them closer together. 0 for no spacing."],
								min = -10, max = 10, step = 0.05, softMin = -5, softMax = 5,
								arg = "bars.spacing",
								hidden = Config.hideAdvancedOption,
							},
						},
					},
					backdrop = {
						order = 2,
						type = "group",
						inline = true,
						name = L["Background/border"],
						args = {
							backgroundColor = {
								order = 1,
								type = "color",
								name = L["Background color"],
								hasAlpha = true,
								set = Config.setColor,
								get = Config.getColor,
								arg = "backdrop.backgroundColor",
							},
							borderColor = {
								order = 2,
								type = "color",
								name = L["Border color"],
								hasAlpha = true,
								set = Config.setColor,
								get = Config.getColor,
								arg = "backdrop.borderColor",
							},
							sep = {
								order = 3,
								type = "description",
								name = "",
								width = "full",
							},
							background = {
								order = 4,
								type = "select",
								name = L["Background"],
								dialogControl = "LSM30_Background",
								values = getMediaData,
								arg = "backdrop.backgroundTexture",
							},
							border = {
								order = 5,
								type = "select",
								name = L["Border"],
								dialogControl = "LSM30_Border",
								values = getMediaData,
								arg = "backdrop.borderTexture",
							},
							inset = {
								order = 5.5,
								type = "range",
								name = L["Inset"],
								desc = L["How far the background should be from the unit frame border."],
								min = -10, max = 10, step = 1,
								hidden = Config.hideAdvancedOption,
								arg = "backdrop.inset",
							},
							sep2 = {
								order = 6,
								type = "description",
								name = "",
								width = "full",
								hidden = Config.hideAdvancedOption,
							},
							edgeSize = {
								order = 7,
								type = "range",
								name = L["Edge size"],
								desc = L["How large the edges should be."],
								hidden = Config.hideAdvancedOption,
								min = 0, max = 20, step = 1,
								arg = "backdrop.edgeSize",
							},
							tileSize = {
								order = 8,
								type = "range",
								name = L["Tile size"],
								desc = L["How large the background should tile"],
								hidden = Config.hideAdvancedOption,
								min = 0, max = 20, step = 1,
								arg = "backdrop.tileSize",
							},
							clip = {
								order = 9,
								type = "range",
								name = L["Clip"],
								desc = L["How close the frame should clip with the border."],
								hidden = Config.hideAdvancedOption,
								min = 0, max = 20, step = 1,
								arg = "backdrop.clip",
							},
						},
					},
					font = {
						order = 3,
						type = "group",
						inline = true,
						name = L["Font"],
						args = {
							color = {
								order = 1,
								type = "color",
								name = L["Default color"],
								desc = L["Default font color, any color tags inside individual tag texts will override this."],
								hasAlpha = true,
								set = Config.setColor,
								get = Config.getColor,
								arg = "font.color",
								hidden = Config.hideAdvancedOption,
							},
							sep = {order = 1.25, type = "description", name = "", hidden = Config.hideAdvancedOption},
							font = {
								order = 1.5,
								type = "select",
								name = L["Font"],
								dialogControl = "LSM30_Font",
								values = getMediaData,
								arg = "font.name",
							},
							size = {
								order = 2,
								type = "range",
								name = L["Size"],
								min = 1, max = 50, step = 1, softMin = 1, softMax = 20,
								arg = "font.size",
							},
							outline = {
								order = 3,
								type = "select",
								name = L["Outline"],
								values = {["OUTLINE"] = L["Thin outline"], ["THICKOUTLINE"] = L["Thick outline"], ["MONOCHROMEOUTLINE"] = L["Monochrome Outline"], [""] = L["None"]},
								arg = "font.extra",
								hidden = Config.hideAdvancedOption,
							},
						},
					},
					bar = {
						order = 4,
						type = "group",
						inline = true,
						name = L["Bars"],
						hidden = Config.hideAdvancedOption,
						args = {
							override = {
								order = 0,
								type = "toggle",
								name = L["Override color"],
								desc = L["Forces a static color to be used for the background of all bars"],
								set = function(info, value)
									if( value and not ShadowUF.db.profile.bars.backgroundColor ) then
										ShadowUF.db.profile.bars.backgroundColor = {r = 0, g = 0, b = 0}
									elseif( not value ) then
										ShadowUF.db.profile.bars.backgroundColor = nil
									end

									ShadowUF.Layout:Reload()
								end,
								get = function(info)
									return ShadowUF.db.profile.bars.backgroundColor and true or false
								end,
							},
							color = {
								order = 1,
								type = "color",
								name = L["Background color"],
								desc = L["This will override all background colorings for bars including custom set ones."],
								set = Config.setColor,
								get = function(info)
									if( not ShadowUF.db.profile.bars.backgroundColor ) then
										return {r = 0, g = 0, b = 0}
									end

									return Config.getColor(info)
								end,
								disabled = function(info) return not ShadowUF.db.profile.bars.backgroundColor end,
								arg = "bars.backgroundColor",
							},
							sep = { order = 2, type = "description", name = "", width = "full"},
							barAlpha = {
								order = 3,
								type = "range",
								name = L["Bar alpha"],
								desc = L["Alpha to use for bar."],
								arg = "bars.alpha",
								min = 0, max = 1, step = 0.05,
								isPercent = true
							},
							backgroundAlpha = {
								order = 4,
								type = "range",
								name = L["Background alpha"],
								desc = L["Alpha to use for bar backgrounds."],
								arg = "bars.backgroundAlpha",
								min = 0, max = 1, step = 0.05,
								isPercent = true
							},
						},
					},
				},
			},
			color = {
				order = 2,
				type = "group",
				name = L["Colors"],
				args = {
					health = {
						order = 1,
						type = "group",
						inline = true,
						name = L["Health"],
						set = Config.setColor,
						get = Config.getColor,
						args = {
							green = {
								order = 1,
								type = "color",
								name = L["High health"],
								desc = L["Health bar color used as the transitional color for 100% -> 50% on players, as well as when your pet is happy."],
								arg = "healthColors.green",
							},
							yellow = {
								order = 2,
								type = "color",
								name = L["Half health"],
								desc = L["Health bar color used as the transitional color for 100% -> 0% on players, as well as when your pet is mildly unhappy."],
								arg = "healthColors.yellow",
							},
							red = {
								order = 3,
								type = "color",
								name = L["Low health"],
								desc = L["Health bar color used as the transitional color for 50% -> 0% on players, as well as when your pet is very unhappy."],
								arg = "healthColors.red",
							},
							friendly = {
								order = 4,
								type = "color",
								name = L["Friendly"],
								desc = L["Health bar color for friendly units."],
								arg = "healthColors.friendly",
							},
							neutral = {
								order = 5,
								type = "color",
								name = L["Neutral"],
								desc = L["Health bar color for neutral units."],
								arg = "healthColors.neutral",
							},
							hostile = {
								order = 6,
								type = "color",
								name = L["Hostile"],
								desc = L["Health bar color for hostile units."],
								arg = "healthColors.hostile",
							},
							aggro = {
								order = 6.5,
								type = "color",
								name = L["Has Aggro"],
								desc = L["Health bar color for units with aggro."],
								arg = "healthColors.aggro",
							},
							static = {
								order = 7,
								type = "color",
								name = L["Static"],
								desc = L["Color to use for health bars that are set to be colored by a static color."],
								arg = "healthColors.static",
							},
							inc = {
								order = 8,
								type = "color",
								name = L["Incoming heal"],
								desc = L["Bar color to use to show how much healing someone is about to receive."],
								arg = "healthColors.inc",
							},
							ownInc = {
								order = 9,
								type = "color",
								name = "Own incoming heal",
								desc = L["Bar color to use to show how much healing someone is about to receive."],
								arg = "healthColors.ownInc",
							},
							hotInc = {
								order = 10,
								type = "color",
								name = "Incoming HoT heal",
								desc = L["Bar color to use to show how much healing someone is about to receive."],
								arg = "healthColors.hotInc",
							},
							enemyUnattack = {
								order = 11,
								type = "color",
								name = L["Unattackable hostile"],
								desc = L["Health bar color to use for hostile units who you cannot attack, used for reaction coloring."],
								hidden = Config.hideAdvancedOption,
								arg = "healthColors.enemyUnattack",
							}
						},
					},
					power = {
						order = 2,
						type = "group",
						inline = true,
						name = L["Power"],
						set = Config.setColor,
						get = Config.getColor,
						args = {
							MANA = {
								order = 0,
								type = "color",
								name = L["Mana"],
								width = "half",
								arg = "powerColors.MANA",
							},
							RAGE = {
								order = 1,
								type = "color",
								name = L["Rage"],
								width = "half",
								arg = "powerColors.RAGE",
							},
							FOCUS = {
								order = 2,
								type = "color",
								name = L["Focus"],
								arg = "powerColors.FOCUS",
								width = "half",
							},
							ENERGY = {
								order = 3,
								type = "color",
								name = L["Energy"],
								arg = "powerColors.ENERGY",
								width = "half",
							},
							RUNIC_POWER = {
								order = 6,
								type = "color",
								name = L["Runic Power"],
								arg = "powerColors.RUNIC_POWER",
							},
							RUNES_BLOOD = {
								order = 7,
								type = "color",
								name = "Runes (Blood)",
								arg = "powerColors.RUNES_BLOOD",
								hidden = function(info) return select(2, UnitClass("player")) ~= "DEATHKNIGHT" end,
							},
							RUNES_FROST = {
								order = 8,
								type = "color",
								name = "Runes (Frost)",
								arg = "powerColors.RUNES_FROST",
								hidden = function(info) return select(2, UnitClass("player")) ~= "DEATHKNIGHT" end,
							},
							RUNES_UNHOLY = {
								order = 9,
								type = "color",
								name = "Runes (Unholy)",
								arg = "powerColors.RUNES_UNHOLY",
								hidden = function(info) return select(2, UnitClass("player")) ~= "DEATHKNIGHT" end,
							},
							RUNES_DEATH = {
								order = 10,
								type = "color",
								name = "Runes (Death)",
								arg = "powerColors.RUNES_DEATH",
								hidden = function(info) return select(2, UnitClass("player")) ~= "DEATHKNIGHT" end,
							},
							COMBOPOINTS = {
								order = 11,
								type = "color",
								name = L["Combo Points"],
								arg = "powerColors.COMBOPOINTS",
							},
						},
					},
					cast = {
						order = 3,
						type = "group",
						inline = true,
						name = L["Cast"],
						set = Config.setColor,
						get = Config.getColor,
						args = {
							cast = {
								order = 0,
								type = "color",
								name = L["Casting"],
								desc = L["Color used when an unit is casting a spell."],
								arg = "castColors.cast",
							},
							channel = {
								order = 1,
								type = "color",
								name = L["Channelling"],
								desc = L["Color used when a cast is a channel."],
								arg = "castColors.channel",
							},
							sep = {
								order = 2,
								type = "description",
								name = "",
								hidden = Config.hideAdvancedOption,
								width = "full",
							},
							finished = {
								order = 3,
								type = "color",
								name = L["Finished cast"],
								desc = L["Color used when a cast is successfully finished."],
								hidden = Config.hideAdvancedOption,
								arg = "castColors.finished",
							},
							interrupted = {
								order = 4,
								type = "color",
								name = L["Cast interrupted"],
								desc = L["Color used when a cast is interrupted either by the caster themselves or by another unit."],
								hidden = Config.hideAdvancedOption,
								arg = "castColors.interrupted",
							},
							uninterruptible = {
								order = 5,
								type = "color",
								name = L["Cast uninterruptible"],
								desc = L["Color used when a cast cannot be interrupted, this is only used for PvE mobs."],
								arg = "castColors.uninterruptible",
							},
						},
					},
					auras = {
						order = 3.5,
						type = "group",
						inline = true,
						name = L["Aura borders"],
						set = Config.setColor,
						get = Config.getColor,
						hidden = Config.hideAdvancedOption,
						args = {
							removableColor = {
								order = 0,
								type = "color",
								name = L["Stealable/Curable/Dispellable"],
								desc = L["Border coloring of stealable, curable and dispellable auras."],
								arg = "auraColors.removable",
								width = "double"
							}
						}
					},
					classColors = {
						order = 4,
						type = "group",
						inline = true,
						name = L["Classes"],
						set = Config.setColor,
						get = Config.getColor,
						args = {}
					},
				},
			},
			range = {
				order = 5,
				type = "group",
				name = L["Range Checker"],
				args = {
					help = {
						order = 0,
						type = "group",
						inline = true,
						name = L["Help"],
						args = {
							help = {
								order = 0,
								type = "description",
								name = L["This will be set for your current class only.\nIf no custom spells are set, defaults appropriate for your class will be used."],
							},
						},
					},
					friendly = {
						order = 1,
						inline = true,
						type = "group",
						name = L["On Friendly Units"],
						args = {
							friendly = {
								order = 1,
								type = "input",
								name = rangeWithIcon,
								desc = L["Name of a friendly spell to check range."],
								validate = validateSpell,
								set = setRange,
								get = getRange,
							},
							spacer = {
								order = 2,
								type = "description",
								width = "normal",
								name = ""
							},
							friendlyAlt = {
								order = 3,
								type = "input",
								name = rangeWithIcon,
								desc = L["Alternatively friendly spell to use to check range."],
								hidden = Config.hideAdvancedOption,
								validate = validateSpell,
								set = setRange,
								get = getRange,
							},
						}
					},
					hostile = {
						order = 2,
						inline = true,
						type = "group",
						name = L["On Hostile Units"],
						args = {
							hostile = {
								order = 1,
								type = "input",
								name = rangeWithIcon,
								desc = L["Name of a friendly spell to check range."],
								validate = validateSpell,
								set = setRange,
								get = getRange,
							},
							spacer = {
								order = 2,
								type = "description",
								width = "normal",
								name = ""
							},
							hostileAlt = {
								order = 3,
								type = "input",
								name = rangeWithIcon,
								desc = L["Alternatively friendly spell to use to check range."],
								hidden = Config.hideAdvancedOption,
								validate = validateSpell,
								set = setRange,
								get = getRange,
							},
						}
					},
				},
			},
			text = {
				type = "group",
				order = 6,
				name = L["Text Management"],
				hidden = false,
				args = {
					help = {
						order = 0,
						type = "group",
						inline = true,
						name = L["Help"],
						args = {
							help = {
								order = 0,
								type = "description",
								name = L["You can add additional text with tags enabled using this configuration, note that any additional text added (or removed) effects all units, removing text will reset their settings as well.|n|nKeep in mind, you cannot delete the default text included with the units."],
							},
						},
					},
					add = {
						order = 1,
						name = L["Add new text"],
						inline = true,
						type = "group",
						set = function(info, value) textData[info[#(info)] ] = value end,
						get = function(info, value) return textData[info[#(info)] ] end,
						args = {
							name = {
								order = 0,
								type = "input",
								name = L["Text name"],
								desc = L["Text name that you can use to identify this text from others when configuring."],
							},
							parent = {
								order = 1,
								type = "select",
								name = L["Text parent"],
								desc = L["Where inside the frame the text should be anchored to."],
								values = barModules,
							},
							add = {
								order = 2,
								type = "execute",
								name = L["Add"],
								disabled = function() return not textData.name or textData.name == "" or not textData.parent end,
								func = function(info)
									-- Verify we entered a good name
									textData.name = string.trim(textData.name)
									textData.name = textData.name ~= "" and textData.name or nil

									-- Add the new entry
									for _, unit in pairs(ShadowUF.unitList) do
										table.insert(ShadowUF.db.profile.units[unit].text, {enabled = true, name = textData.name or "??", text = "", anchorTo = textData.parent, x = 0, y = 0, anchorPoint = "C", size = 0, width = 0.50})
									end

									-- Add it to the GUI
									local id = tostring(#(ShadowUF.db.profile.units.player.text))
									addTextParent.args[id .. ":label"] = addTextLabel
									addTextParent.args[id] = addText
									addTextParent.args[id .. ":sep"] = addTextSep
									generalOptions.args.text.args[textData.parent] = generalOptions.args.text.args[textData.parent] or addTextParent

									local parent = string.sub(textData.parent, 2)
									Config.tagWizard[parent] = Config.tagWizard[parent] or Config.parentTable
									Config.tagWizard[parent].args[id] = Config.tagTextTable
									Config.tagWizard[parent].args[id .. ":adv"] = Config.advanceTextTable

									Config.quickIDMap[id .. ":adv"] = #(ShadowUF.db.profile.units.player.text)

									-- Reset
									textData.name = nil
									textData.parent = nil

								end,
							},
						},
					},
				},
			},
			layout = layoutManager,
		},
	}

	-- Load text
	for id, text in pairs(ShadowUF.db.profile.units.player.text) do
		if( text.anchorTo ~= "" and not text.default ) then
			addTextParent.args[id .. ":label"] = addTextLabel
			addTextParent.args[tostring(id)] = addText
			addTextParent.args[id .. ":sep"] = addTextSep
			generalOptions.args.text.args[text.anchorTo] = addTextParent
		end
	end


	Config.classTable = {
		order = 0,
		type = "color",
		name = Config.getName,
		hasAlpha = true,
		width = "half",
		arg = "classColors.$key",
	}

	for classToken in pairs(Config.const.CLASSIC_RAID_CLASS_COLORS) do
		generalOptions.args.color.args.classColors.args[classToken] = Config.classTable
	end

	generalOptions.args.color.args.classColors.args.PET = Config.classTable
	--generalOptions.args.color.args.classColors.args.VEHICLE = Config.classTable

	return generalOptions
end
