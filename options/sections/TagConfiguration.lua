local L = ShadowUF.L
local Config = ShadowUF.Config
local _Config = ShadowUF.Config.private

function _Config:loadTagOptions()
	local tagsOptions

	local tagData = {search = ""}
	local function set(info, value, key)
		key = key or info[#(info)]
		if( ShadowUF.Tags.defaultHelp[tagData.name] ) then
			return
		end

		-- Reset loaded function + reload tags
		if( key == "funct" ) then
			ShadowUF.tagFunc[tagData.name] = nil
			ShadowUF.Tags:Reload()
		elseif( key == "category" ) then
			local cat = ShadowUF.db.profile.tags[tagData.name][key]
			if( cat and cat ~= value ) then
				Config.tagTextTable.args[cat].args[tagData.name] = nil
				Config.tagTextTable.args[value].args[tagData.name] = Config.tagTable
			end
		end

		ShadowUF.db.profile.tags[tagData.name][key] = value
	end

	local function stripCode(text)
		if( not text ) then
			return ""
		end

		return string.gsub(string.gsub(text, "|", "||"), "\t", "")
	end

	local function get(info, key)
		key = key or info[#(info)]

		if( key == "help" and ShadowUF.Tags.defaultHelp[tagData.name] ) then
			return ShadowUF.Tags.defaultHelp[tagData.name] or ""
		elseif( key == "events" and ShadowUF.Tags.defaultEvents[tagData.name] ) then
			return ShadowUF.Tags.defaultEvents[tagData.name] or ""
		elseif( key == "frequency" and ShadowUF.Tags.defaultFrequents[tagData.name] ) then
			return ShadowUF.Tags.defaultFrequents[tagData.name] or ""
		elseif( key == "category" and ShadowUF.Tags.defaultCategories[tagData.name] ) then
			return ShadowUF.Tags.defaultCategories[tagData.name] or ""
		elseif( key == "name" and ShadowUF.Tags.defaultNames[tagData.name] ) then
			return ShadowUF.Tags.defaultNames[tagData.name] or ""
		elseif( key == "funct" and ShadowUF.Tags.defaultTags[tagData.name] ) then
			return ShadowUF.Tags.defaultTags[tagData.name] or ""
		end

		return ShadowUF.db.profile.tags[tagData.name] and ShadowUF.db.profile.tags[tagData.name][key] or ""
	end

	local function isSearchHidden(info)
		return tagData.search ~= "" and not string.match(info[#(info)], tagData.search) or false
	end

	local function editTag(info)
		tagData.name = info[#(info)]

		if( ShadowUF.Tags.defaultHelp[tagData.name] ) then
			tagData.error = L["You cannot edit this tag because it is one of the default ones included in this mod. This function is here to provide an example for your own custom tags."]
		else
			tagData.error = nil
		end

		Config.selectDialogGroup("tags", "edit")
	end

	-- Create all of the tag editor options, if it's a default tag will show it after any custom ones
	local tagTable = {
		type = "execute",
		order = function(info) return ShadowUF.Tags.defaultTags[info[#(info)]] and 100 or 1 end,
		name = Config.getTagName,
		desc = Config.getTagHelp,
		hidden = isSearchHidden,
		func = editTag,
	}

	local tagCategories = {}
	local function getTagCategories(info)
		for k in pairs(tagCategories) do tagCategories[k] = nil end

		for _, cat in pairs(ShadowUF.Tags.defaultCategories) do
			tagCategories[cat] = Config.const.TAG_GROUPS[cat]
		end

		return tagCategories
	end

	-- Tag configuration
	tagsOptions = {
		type = "group",
		childGroups = "tab",
		name = L["Add Tags"],
		desc = Config.getPageDescription,
		hidden = Config.hideAdvancedOption,
		args = {
			general = {
				order = 0,
				type = "group",
				name = L["Tag list"],
				args = {
					help = {
						order = 0,
						type = "group",
						inline = true,
						name = L["Help"],
						hidden = function() return ShadowUF.db.profile.advanced end,
						args = {
							description = {
								order = 0,
								type = "description",
								name = L["You can add new custom tags through this page, if you're looking to change what tags are used in text look under the Text tab for an Units configuration."],
							},
						},
					},
					search = {
						order = 1,
						type = "group",
						inline = true,
						name = L["Search"],
						args = {
							search = {
								order = 1,
								type = "input",
								name = L["Search tags"],
								set = function(info, text) tagData.search = text end,
								get = function(info) return tagData.search end,
							},
						},
					},
					list = {
						order = 2,
						type = "group",
						inline = true,
						name = L["Tags"],
						args = {},
					},
				},
			},
			add = {
				order = 1,
				type = "group",
				name = L["Add new tag"],
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
								name = L["You can find more information on creating your own custom tags in the \"Help\" tab above."],
							},
						},
					},
					add = {
						order = 1,
						type = "group",
						inline = true,
						name = L["Add new tag"],
						args = {
							error = {
								order = 0,
								type = "description",
								name = function() return tagData.addError or "" end,
								hidden = function() return not tagData.addError end,
							},
							errorHeader = {
								order = 0.50,
								type = "header",
								name = "",
								hidden = function() return not tagData.addError end,
							},
							tag = {
								order = 1,
								type = "input",
								name = L["Tag name"],
								desc = L["Tag that you will use to access this code, do not wrap it in brackets or parenthesis it's automatically done. For example, you would enter \"foobar\" and then access it with [foobar]."],
								validate = function(info, text)
									if( text == "" ) then
										tagData.addError = L["You must enter a tag name."]
									elseif( string.match(text, "[%[%]%(%)]") ) then
										tagData.addError = string.format(L["You cannot name a tag \"%s\", tag names should contain no brackets or parenthesis."], text)
									elseif( ShadowUF.tagFunc[text] ) then
										tagData.addError = string.format(L["The tag \"%s\" already exists."], text)
									else
										tagData.addError = nil
									end

									Config.AceRegistry:NotifyChange("ShadowedUF")
									return tagData.addError and "" or true
								end,
								set = function(info, tag)
									tagData.name = tag
									tagData.error = nil
									tagData.addError = nil

									ShadowUF.db.profile.tags[tag] = {func = "function(unit, unitOwner)\n\nend", category = "misc"}
									tagsOptions.args.general.args.list.args[tag] = tagTable
									Config.tagTextTable.args.misc.args[tag] = Config.tagTable

									Config.selectDialogGroup("tags", "edit")
								end,
							},
						},
					},
				},
			},
			edit = {
				order = 2,
				type = "group",
				name = L["Edit tag"],
				hidden = function() return not tagData.name end,
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
								name = L["You can find more information on creating your own custom tags in the \"Help\" tab above.|nSUF will attempt to automatically detect what events your tag will need, so you do not generally need to fill out the events field."],
							},
						},
					},
					tag = {
						order = 1,
						type = "group",
						inline = true,
						name = function() return string.format(L["Editing %s"], tagData.name or "") end,
						args = {
							error = {
								order = 0,
								type = "description",
								name = function()
									if( tagData.error ) then
										return "|cffff0000" .. tagData.error .. "|r"
									end
									return ""
								end,
								hidden = function() return not tagData.error end,
							},
							errorHeader = {
								order = 1,
								type = "header",
								name = "",
								hidden = function() return not tagData.error end,
							},
							discovery = {
								order = 1,
								type = "toggle",
								name = L["Disable event discovery"],
								desc = L["This will disable the automatic detection of what events this tag will need, you should leave this unchecked unless you know what you are doing."],
								set = function(info, value) tagData.discovery = value end,
								get = function() return tagData.discovery end,
								width = "full",
							},
							frequencyEnable = {
								order = 1.10,
								type = "toggle",
								name = L["Enable frequent updates"],
								desc = L["Flags the tag for frequent updating, it will update the tag on a timer regardless of any events firing."],
								set = function(info, value)
									tagData.frequency = value and 5 or nil
									set(info, tagData.frequency, "frequency")
								end,
								get = function(info) return get(info, "frequency") ~= "" and true or false end,
								width = "full",
							},
							frequency = {
								order = 1.20,
								type = "input",
								name = L["Update interval"],
								desc = L["How many seconds between updates.|n[WARNING] By setting the frequency to 0 it will update every single frame redraw, if you want to disable frequent updating uncheck it don't set this to 0."],
								disabled = function(info) return get(info) == "" end,
								validate = function(info, value)
									value = tonumber(value)
									if( not value ) then
										tagData.error = L["Invalid interval entered, must be a number."]
									elseif( value < 0 ) then
										tagData.error = L["You must enter a number that is 0 or higher, negative numbers are not allowed."]
									else
										tagData.error = nil
									end

									if( tagData.error ) then
										Config.AceRegistry:NotifyChange("ShadowedUF")
										return ""
									end

									return true
								end,
								set = function(info, value)
									tagData.frequency = tonumber(value)
									tagData.frequency = tagData.frequency < 0 and 0 or tagData.frequency

									set(info, tagData.frequency)
								end,
								get = function(info) return tostring(get(info) or "") end,
								width = "half",
							},
							name = {
								order = 2,
								type = "input",
								name = L["Tag name"],
								set = set,
								get = get,
							},
							category = {
								order = 2.5,
								type = "select",
								name = L["Category"],
								values = getTagCategories,
								set = set,
								get = get,
							},

							sep = {
								order = 2.75,
								type = "description",
								name = "",
								width = "full",
							},
							events = {
								order = 3,
								type = "input",
								name = L["Events"],
								desc = L["Events that should be used to trigger an update of this tag. Separate each event with a single space."],
								width = "full",
								validate = function(info, text)
									if( ShadowUF.Tags.defaultTags[tagData.name] ) then
										return true
									end

									if( text == "" or string.match(text, "[^_%a%s]") ) then
										tagData.error = L["You have to set the events to fire, you can only enter letters and underscores, \"FOO_BAR\" for example is valid, \"APPLE_5_ORANGE\" is not because it contains a number."]
										tagData.eventError = text
										Config.AceRegistry:NotifyChange("ShadowedUF")
										return ""
									end

									tagData.eventError = text
									tagData.error = nil
									return true
								end,
								set = set,
								get = function(info)
									if( tagData.eventError ) then
										return tagData.eventError
									end

									return get(info)
								end,
							},
							func = {
								order = 4,
								type = "input",
								multiline = true,
								name = L["Code"],
								desc = L["Your code must be wrapped in a function, for example, if you were to make a tag to return the units name you would do:|n|nfunction(unit, unitOwner)|nreturn UnitName(unitOwner)|nend"],
								width = "full",
								validate = function(info, text)
									if( ShadowUF.Tags.defaultTags[tagData.name] ) then
										return true
									end

									local funct, msg = loadstring("return " .. text)
									if( not string.match(text, "function") ) then
										tagData.error = L["You must wrap your code in a function."]
										tagData.funcError = text
									elseif( not funct and msg ) then
										tagData.error = string.format(L["Failed to save tag, error:|n %s"], msg)
										tagData.funcError = text
									else
										tagData.error = nil
										tagData.funcError = nil
									end

									Config.AceRegistry:NotifyChange("ShadowedUF")
									return tagData.error and "" or true
								end,
								set = function(info, value)
									value = string.gsub(value, "||", "|")
									set(info, value)

									-- Try and automatically identify the events this tag is going to want to use
									if( not tagData.discovery ) then
										tagData.eventError = nil
										ShadowUF.db.profile.tags[tagData.name].events = ShadowUF.Tags:IdentifyEvents(value) or ""
									end

									ShadowUF.Tags:Reload(tagData.name)
								end,
								get = function(info)
									if( tagData.funcError ) then
										return stripCode(tagData.funcError)
									end
									return stripCode(ShadowUF.Tags.defaultTags[tagData.name] or ( ShadowUF.db.profile.tags[tagData.name] and ShadowUF.db.profile.tags[tagData.name].func))
								end,
							},
							delete = {
								order = 5,
								type = "execute",
								name = L["Delete"],
								hidden = function() return ShadowUF.Tags.defaultTags[tagData.name] end,
								confirm = true,
								confirmText = L["Are you sure you want to delete this tag?"],
								func = function(info)
									local category = ShadowUF.db.profile.tags[tagData.name].category
									if( category ) then
										Config.tagTextTable.args[category].args[tagData.name] = nil
									end

									tagsOptions.args.general.args.list.args[tagData.name] = nil

									ShadowUF.db.profile.tags[tagData.name] = nil
									ShadowUF.tagFunc[tagData.name] = nil
									ShadowUF.Tags:Reload(tagData.name)

									tagData.name = nil
									tagData.error = nil
									Config.selectDialogGroup("tags", "general")
								end,
							},
						},
					},
				},
			},
			help = {
				order = 3,
				type = "group",
				name = L["Help"],
				args = {
					general = {
						order = 0,
						type = "group",
						name = L["General"],
						inline = true,
						args = {
							general = {
								order = 0,
								type = "description",
								name = L["See the documentation below for information and examples on creating tags, if you just want basic Lua or WoW API information then see the Programming in Lua and WoW Programming links."],
							},
						},
					},
					documentation = {
						order = 1,
						type = "group",
						name = L["Documentation"],
						inline = true,
						args = {
							doc = {
								order = 0,
								type = "input",
								name = L["Documentation"],
								set = false,
								get = function() return "http://wiki.github.com/Shadowed/ShadowedUnitFrames/tag-documentation" end,
								width = "full",
							},
						},
					},
					resources = {
						order = 2,
						type = "group",
						inline = true,
						name = L["Resources"],
						args = {
							lua = {
								order = 0,
								type = "input",
								name = L["Programming in Lua"],
								desc = L["This is a good guide on how to get started with programming in Lua, while you do not need to read the entire thing it is a helpful for understanding the basics of Lua syntax and API's."],
								set = false,
								get = function() return "http://www.lua.org/pil/" end,
								width = "full",
							},
							wow = {
								order = 1,
								type = "input",
								name = L["WoW Programming"],
								desc = L["WoW Programming is a good resource for finding out what difference API's do and how to call them."],
								set = false,
								get = function() return "http://wowprogramming.com/docs" end,
								width = "full",
							},
						},
					},
				},
			},
		},
	}

	-- Load the initial tag list
	for tag in pairs(ShadowUF.Tags.defaultTags) do
		tagsOptions.args.general.args.list.args[tag] = tagTable
	end

	for tag, data in pairs(ShadowUF.db.profile.tags) do
		tagsOptions.args.general.args.list.args[tag] = tagTable
	end

	return tagsOptions
end
