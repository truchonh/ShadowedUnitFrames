local Config = {}
local registered, options
local playerClass = select(2, UnitClass("player"))
local L = ShadowUF.L

Config.private = {}
Config.modifyUnits = {}
Config.globalConfig = {}

ShadowUF.Config = Config

--[[
	The part that makes configuration a pain when you actually try is it gets unwieldly when you're adding special code to deal with
	showing help for certain cases, swapping tabs etc that makes it work smoothly.

	I'm going to have to split it out into separate files for each type to clean everything up but that takes time and I have other things
	I want to get done with first.

	-- dated 2009

	In reality, this will never be cleaned up because jesus christ, I am not refactoring 7,000 lines of configuration.

	*** HERE BE DRAGONS ***

	-- 2014

	The Great Refactoring has begun.

	-- 2022
]]

local PAGE_DESC = {
	["general"] = L["General configuration to all enabled units."],
	["enableUnits"] = L["Various units can be enabled through this page, such as raid or party targets."],
	["hideBlizzard"] = L["Hiding and showing various aspects of the default UI such as the player buff frames."],
	["units"] = L["Configuration to specific unit frames."],
	["visibility"] = L["Disabling unit modules in various instances."],
	["tags"] = L["Advanced tag management, allows you to add your own custom tags."],
	["filter"] = L["Simple aura filtering by whitelists and blacklists."],
}
local INDICATOR_NAMES = {["leader"] = L["Leader / Assist"], ["masterLoot"] = L["Master Looter"], ["pvp"] = L["PvP Flag"], ["raidTarget"] = L["Raid Target"], ["ready"] = L["Ready Status"], ["role"] = L["Raid Role"], ["status"] = L["Combat Status"], ["class"] = L["Class Icon"], ["resurrect"] = L["Resurrect Status"], ["phase"] = L["Other Party/Phase Status"], ["happiness"] = L["Pet Happiness"]}
local AREA_NAMES = {["arena"] = L["Arenas"],["none"] = L["Everywhere else"], ["party"] = L["Party instances"], ["pvp"] = L["Battleground"], ["raid"] = L["Raid instances"]}
local INDICATOR_DESC = {
		["leader"] = L["Crown indicator for group leader or assistants."],
		["masterLoot"] = L["Bag indicator for master looters."], ["pvp"] = L["PVP flag indicator, Horde for Horde flagged pvpers and Alliance for Alliance flagged pvpers."],
		["raidTarget"] = L["Raid target indicator."], ["ready"] = L["Ready status of group members."], ["phase"] = L["Shows when a party member is in a different phase or another group."],
		["role"] = L["Raid role indicator, adds a shield indicator for main tanks and a sword icon for main assists."], ["status"] = L["Status indicator, shows if the unit is currently in combat. For the player it will also show if you are rested."], ["class"] = L["Class icon for players."],
		["happiness"] = L["Indicator for the current pet happiness."]
}
local TAG_GROUPS = {["classification"] = L["Classifications"], ["health"] = L["Health"], ["misc"] = L["Miscellaneous"], ["playerthreat"] = L["Player threat"], ["power"] = L["Power"], ["status"] = L["Status"], ["threat"] = L["Threat"], ["raid"] = L["Raid"], ["classspec"] = L["Class Specific"], ["classtimer"] = L["Class Timer"]}

local pointPositions = {["BOTTOM"] = L["Bottom"], ["TOP"] = L["Top"], ["LEFT"] = L["Left"], ["RIGHT"] = L["Right"], ["TOPLEFT"] = L["Top Left"], ["TOPRIGHT"] = L["Top Right"], ["BOTTOMLEFT"] = L["Bottom Left"], ["BOTTOMRIGHT"] = L["Bottom Right"], ["CENTER"] = L["Center"]}
local positionList = {["C"] = L["Center"], ["RT"] = L["Right Top"], ["RC"] = L["Right Center"], ["RB"] = L["Right Bottom"], ["LT"] = L["Left Top"], ["LC"] = L["Left Center"], ["LB"] = L["Left Bottom"], ["BL"] = L["Bottom Left"], ["BC"] = L["Bottom Center"], ["BR"] = L["Bottom Right"], ["TR"] = L["Top Right"], ["TC"] = L["Top Center"], ["TL"] = L["Top Left"]}

Config.const = {}
Config.const.PAGE_DESC = PAGE_DESC
Config.const.INDICATOR_NAMES = INDICATOR_NAMES
Config.const.AREA_NAMES = AREA_NAMES
Config.const.INDICATOR_DESC = INDICATOR_DESC
Config.const.TAG_GROUPS = TAG_GROUPS
Config.const.pointPositions = pointPositions
Config.const.positionList = positionList

local unitOrder = {}
for order, unit in pairs(ShadowUF.unitList) do unitOrder[unit] = order end
local fullReload = {["bars"] = true, ["auras"] = true, ["backdrop"] = true, ["font"] = true, ["classColors"] = true, ["powerColors"] = true, ["healthColors"] = true, ["xpColors"] = true, ["omnicc"] = true}

-- Helper functions
local function getPageDescription(info)
	return PAGE_DESC[info[#(info)]]
end

local function getFrameName(unit)
	if( unit == "raidpet" or unit == "raid" or unit == "party" or unit == "maintank" or unit == "mainassist" or unit == "boss" or unit == "arena" ) then
		return string.format("#SUFHeader%s", unit)
	end

	return string.format("#SUFUnit%s", unit)
end

local anchorList = {}
local function getAnchorParents(info)
	local unit = info[2]
	for k in pairs(anchorList) do anchorList[k] = nil end

	if( ShadowUF.Units.childUnits[unit] ) then
		anchorList["$parent"] = string.format(L["%s member"], L.units[ShadowUF.Units.childUnits[unit]])
		return anchorList
	end

	anchorList["UIParent"] = L["Screen"]

	-- Don't let a frame anchor to a frame thats anchored to it already (Stop infinite loops-o-doom)
	local currentName = getFrameName(unit)
	for _, unitID in pairs(ShadowUF.unitList) do
		if( unitID ~= unit and ShadowUF.db.profile.positions[unitID] and ShadowUF.db.profile.positions[unitID].anchorTo ~= currentName ) then
			anchorList[getFrameName(unitID)] = string.format(L["%s frames"], L.units[unitID] or unitID)
		end
	end

	return anchorList
end

local function selectDialogGroup(group, key)
	Config.AceDialog.Status.ShadowedUF.children[group].status.groups.selected = key
	Config.AceRegistry:NotifyChange("ShadowedUF")
end

local function selectTabGroup(group, subGroup, key)
	Config.AceDialog.Status.ShadowedUF.children[group].status.groups.selected = subGroup
	Config.AceDialog.Status.ShadowedUF.children[group].children[subGroup].status.groups.selected = key
	Config.AceRegistry:NotifyChange("ShadowedUF")
end

local function hideAdvancedOption(info)
	return not ShadowUF.db.profile.advanced
end

local function hideBasicOption(info)
	return ShadowUF.db.profile.advanced
end

local function isUnitDisabled(info)
	local unit = info[#(info)]
	local enabled = ShadowUF.db.profile.units[unit].enabled
	for _, visibility in pairs(ShadowUF.db.profile.visibility) do
		if( visibility[unit] ) then
			enabled = visibility[unit]
			break
		end
	end

	return not enabled
end

local function mergeTables(parent, child)
	for key, value in pairs(child) do
		if( type(parent[key]) == "table" ) then
			parent[key] = mergeTables(parent[key], value)
		elseif( type(value) == "table" ) then
			parent[key] = CopyTable(value)
		elseif( parent[key] == nil ) then
			parent[key] = value
		end
	end

	return parent
end

local function getName(info)
	local key = info[#(info)]
	if( ShadowUF.modules[key] and ShadowUF.modules[key].moduleName ) then
		return ShadowUF.modules[key].moduleName
	end

	return LOCALIZED_CLASS_NAMES_MALE[key] or INDICATOR_NAMES[key] or L.units[key] or TAG_GROUPS[key] or L[key]
end

local function getUnitOrder(info)
	return unitOrder[info[#(info)]]
end

local function isModifiersSet(info)
	if( info[2] ~= "global" ) then return false end
	for k in pairs(Config.modifyUnits) do return false end
	return true
end

-- These are for setting simple options like bars.texture = "Default" or locked = true
local function set(info, value)
	local cat, key = string.split(".", info.arg)
	if( key == "$key" ) then key = info[#(info)] end

	if( not key ) then
		ShadowUF.db.profile[cat] = value
	else
		ShadowUF.db.profile[cat][key] = value
	end

	if( cat and fullReload[cat] ) then
		ShadowUF.Layout:CheckMedia()
		ShadowUF.Layout:Reload()
	end
end

local function get(info)
	local cat, key = string.split(".", info.arg)
	if( key == "$key" ) then key = info[#(info)] end
	if( not key ) then
		return ShadowUF.db.profile[cat]
	else
		return ShadowUF.db.profile[cat][key]
	end
end

local function setColor(info, r, g, b, a)
	local color = get(info) or {}
	color.r, color.g, color.b, color.a = r, g, b, a
	set(info, color)
end

local function getColor(info)
	local color = get(info) or {}
	return color.r, color.g, color.b, color.a
end

-- These are for setting complex options like units.player.auras.buffs.enabled = true or units.player.portrait.enabled = true
local function setVariable(unit, moduleKey, moduleSubKey, key, value)
	local configTable = unit == "global" and Config.globalConfig or ShadowUF.db.profile.units[unit]

	-- For setting options like units.player.auras.buffs.enabled = true
	if( moduleKey and moduleSubKey and configTable[moduleKey][moduleSubKey] ) then
		configTable[moduleKey][moduleSubKey][key] = value
		ShadowUF.Layout:Reload(unit)
	-- For setting options like units.player.portrait.enabled = true
	elseif( moduleKey and not moduleSubKey and configTable[moduleKey] ) then
		configTable[moduleKey][key] = value
		ShadowUF.Layout:Reload(unit)
	-- For setting options like units.player.height = 50
	elseif( not moduleKey and not moduleSubKey ) then
		configTable[key] = value
		ShadowUF.Layout:Reload(unit)
	end
end

local function specialRestricted(unit, moduleKey, moduleSubKey, key)
	if( ShadowUF.fakeUnits[unit] and ( key == "colorAggro" or key == "aggro" or key == "colorDispel" or moduleKey == "castBar" or moduleKey == "incHeal" ) ) then
		return true
	elseif( moduleKey == "healthBar" and unit == "player" and key == "reaction" ) then
		return true
	end
end

local function setDirectUnit(unit, moduleKey, moduleSubKey, key, value)
	if( unit == "global" ) then
		for globalUnit in pairs(Config.modifyUnits) do
			if( not specialRestricted(globalUnit, moduleKey, moduleSubKey, key) ) then
				Config.setVariable(globalUnit, moduleKey, moduleSubKey, key, value)
			end
		end

		Config.setVariable("global", moduleKey, moduleSubKey, key, value)
	else
		Config.setVariable(unit, moduleKey, moduleSubKey, key, value)
	end
end

local function setUnit(info, value)
	local unit = info[2]
	-- auras, buffs, enabled / text, 1, text / portrait, enabled
	local moduleKey, moduleSubKey, key = string.split(".", info.arg)
	if( not moduleSubKey ) then key = moduleKey moduleKey = nil end
	if( moduleSubKey and not key ) then key = moduleSubKey moduleSubKey = nil end
	if( moduleSubKey == "$parent" ) then moduleSubKey = info[#(info) - 1] end
	if( moduleKey == "$parent" ) then moduleKey = info[#(info) - 1] end
	if( moduleSubKey == "$parentparent" ) then moduleSubKey = info[#(info) - 2] end
	if( moduleKey == "$parentparent" ) then moduleKey = info[#(info) - 2] end
	if( tonumber(moduleSubKey) ) then moduleSubKey = tonumber(moduleSubKey) end

	setDirectUnit(unit, moduleKey, moduleSubKey, key, value)
end

local function getVariable(unit, moduleKey, moduleSubKey, key)
	local configTbl = unit == "global" and Config.globalConfig or ShadowUF.db.profile.units[unit]
	if( moduleKey and moduleSubKey ) then
		return configTbl[moduleKey][moduleSubKey] and configTbl[moduleKey][moduleSubKey][key]
	elseif( moduleKey and not moduleSubKey ) then
		return configTbl[moduleKey] and configTbl[moduleKey][key]
	end

	return configTbl[key]
end

local function getUnit(info)
	local moduleKey, moduleSubKey, key = string.split(".", info.arg)
	if( not moduleSubKey ) then key = moduleKey moduleKey = nil end
	if( moduleSubKey and not key ) then key = moduleSubKey moduleSubKey = nil end
	if( moduleSubKey == "$parent" ) then moduleSubKey = info[#(info) - 1] end
	if( moduleKey == "$parent" ) then moduleKey = info[#(info) - 1] end
	if( moduleSubKey == "$parentparent" ) then moduleSubKey = info[#(info) - 2] end
	if( moduleKey == "$parentparent" ) then moduleKey = info[#(info) - 2] end
	if( tonumber(moduleSubKey) ) then moduleSubKey = tonumber(moduleSubKey) end

	return getVariable(info[2], moduleKey, moduleSubKey, key)
end

-- Tag functions
local function getTagName(info)
	local tag = info[#(info)]
	if( ShadowUF.db.profile.tags[tag] and ShadowUF.db.profile.tags[tag].name ) then
		return ShadowUF.db.profile.tags[tag].name
	end

	return ShadowUF.Tags.defaultNames[tag] or tag
end

local function getTagHelp(info)
	local tag = info[#(info)]
	return ShadowUF.Tags.defaultHelp[tag] or ShadowUF.db.profile.tags[tag] and ShadowUF.db.profile.tags[tag].help
end

-- Module functions
local function hideRestrictedOption(info)
	local unit = type(info.arg) == "number" and info[#(info) - info.arg] or info[2]
	local key = info[#(info)]
	if( ShadowUF.modules[key] and ShadowUF.modules[key].moduleClass and ShadowUF.modules[key].moduleClass ~= playerClass ) then
		return true
	elseif( ( key == "incHeal" and not ShadowUF.modules.incHeal ) or ( key == "incAbsorb" and not ShadowUF.modules.incAbsorb ) or ( key == "healAbsorb" and not ShadowUF.modules.healAbsorb ) )  then
		return true
	-- Non-standard units do not support color by aggro or incoming heal
	elseif( key == "colorAggro" or key == "colorDispel" or key == "aggro" ) then
		return string.match(unit, "%w+target" )
	-- Fall back for indicators, no variable table so it shouldn't be shown
	elseif( info[#(info) - 1] == "indicators" ) then
		if( ( unit == "global" and not Config.globalConfig.indicators[key] ) or ( unit ~= "global" and not ShadowUF.db.profile.units[unit].indicators[key] ) ) then
			return true
		end
	-- Fall back, no variable table so it shouldn't be shown
	elseif( ( unit == "global" and not Config.globalConfig[key] ) or ( unit ~= "global" and not ShadowUF.db.profile.units[unit][key] ) ) then
		return true
	end

	return false
end

local function writeTable(tbl)
	local data = ""
	for key, value in pairs(tbl) do
		local valueType = type(value)

		-- Wrap the key in brackets if it's a number
		if( type(key) == "number" ) then
			key = string.format("[%s]", key)
			-- Wrap the string with quotes if it has a space in it
		elseif( string.match(key, "[%p%s%c]") or string.match(key, "^[0-9]+$") ) then
			key = string.format("['%s']", string.gsub(key, "'", "\\'"))
		end

		-- foo = {bar = 5}
		if( valueType == "table" ) then
			data = string.format("%s%s=%s;", data, key, writeTable(value))
			-- foo = true / foo = 5
		elseif( valueType == "number" or valueType == "boolean" ) then
			data = string.format("%s%s=%s;", data, key, tostring(value))
			-- foo = "bar"
		else
			value = tostring(value)
			if value and string.match(value, "[\n]") then
				local token = ""
				while string.find(value, "%["..token.."%[") or string.find(value, "%]"..token.."%]") do
					token = token .. "="
				end
				value = string.format("[%s[%s]%s]", token, value, token)
			else
				value = string.format("%q", value)
			end
			data = string.format("%s%s=%s;", data, key, value)
		end
	end

	return "{" .. data .. "}"
end

-- Expose these for modules
Config.getAnchorParents = getAnchorParents
Config.hideAdvancedOption = hideAdvancedOption
Config.isUnitDisabled = isUnitDisabled
Config.selectDialogGroup = selectDialogGroup
Config.selectTabGroup = selectTabGroup
Config.getName = getName
Config.getUnitOrder = getUnitOrder
Config.isModifiersSet = isModifiersSet
Config.set = set
Config.get = get
Config.setUnit = setUnit
Config.setVariable = setVariable
Config.getUnit = getUnit
Config.getVariable = getVariable
Config.hideRestrictedOption = hideRestrictedOption
Config.hideBasicOption = hideBasicOption
-- Private methods
Config.private.getPageDescription = getPageDescription
Config.private.setColor = setColor
Config.private.getColor = getColor
Config.private.writeTable = writeTable
Config.private.getTagName = getTagName
Config.private.getTagHelp = getTagHelp
Config.private.mergeTables = mergeTables
Config.private.setDirectUnit = setDirectUnit

Config.private.quickIDMap = {}

local function loadOptions()
	local enableUnitsOptions, unitsOptions = Config.private:loadUnitOptions()

	options = {
		type = "group",
		name = "Shadowed UF",
		args = {
			hideBlizzard = Config.private:loadHideOptions(),
			filter = Config.private:loadFilterOptions(),
			visibility = Config.private:loadVisibilityOptions(),
			general = Config.private:loadGeneralOptions(),
			tags = Config.private:loadTagOptions(),
			auraIndicators = Config.private:loadAuraIndicatorsOptions(),
			profile = LibStub("AceDBOptions-3.0"):GetOptionsTable(ShadowUF.db, true),
			enableUnits = enableUnitsOptions,
			units = unitsOptions
		}
	}

	-- Ordering
	options.args.general.order = 1
	options.args.profile.order = 1.5
	options.args.enableUnits.order = 2
	options.args.units.order = 3
	options.args.filter.order = 4
	options.args.auraIndicators.order = 4.5
	options.args.hideBlizzard.order = 5
	options.args.visibility.order = 6
	options.args.tags.order = 7

	-- So modules can access it easier/debug
	Config.options = options

	-- Options finished loading, fire callback for any non-default modules that want to be included
	ShadowUF:FireModuleEvent("OnConfigurationLoad")
end

local defaultToggles
function Config:Open()
	Config.AceDialog = Config.AceDialog or LibStub("AceConfigDialog-3.0")
	Config.AceRegistry = Config.AceRegistry or LibStub("AceConfigRegistry-3.0")

	if( not registered ) then
		loadOptions()

		Config.AceRegistry:RegisterOptionsTable("ShadowedUF", options, true)
		Config.AceDialog:SetDefaultSize("ShadowedUF", 895, 570)
		registered = true
	end

	Config.AceDialog:Open("ShadowedUF")

	if( not defaultToggles ) then
		defaultToggles = true

		Config.AceDialog.Status.ShadowedUF.status.groups.groups.units = true
		Config.AceRegistry:NotifyChange("ShadowedUF")
	end
end
