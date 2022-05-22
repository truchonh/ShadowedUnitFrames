local HealComm = LibStub("LibHealComm-4.0", true)
if( not HealComm ) then return end

local IncHeal = {}
local frames = {}
ShadowUF:RegisterModule(IncHeal, "incHeal", ShadowUF.L["Incoming heals"])
ShadowUF.Tags.customEvents["HEALCOMM"] = IncHeal

local myGUID = UnitGUID("player")

-- How far ahead to show heals at most
local INCOMING_SECONDS = 3

function IncHeal:OnEnable(frame)
	if ( not frame.healthBar ) then
		return
	end

	frames[frame] = true

	if( not frame.incHeal ) then
		-- Heal Prediction
		local otherBeforeBar = CreateFrame("StatusBar", nil, frame.healthBar)
		otherBeforeBar:SetStatusBarTexture([[Interface\ChatFrame\ChatFrameBackground]])
		otherBeforeBar:Hide()

		local myBar = CreateFrame("StatusBar", nil, frame.healthBar)
		myBar:SetStatusBarTexture([[Interface\ChatFrame\ChatFrameBackground]])
		otherBeforeBar:Hide()

		local otherAfterBar = CreateFrame("StatusBar", nil, frame.healthBar)
		otherAfterBar:SetStatusBarTexture([[Interface\ChatFrame\ChatFrameBackground]])
		otherBeforeBar:Hide()

		local hotBar = CreateFrame("StatusBar", nil, frame.healthBar)
		hotBar:SetStatusBarTexture([[Interface\ChatFrame\ChatFrameBackground]])
		otherBeforeBar:Hide()

		frame.incHeal = {
			otherBeforeBar = otherBeforeBar,
			myBar = myBar,
			otherAfterBar = otherAfterBar,
			hotBar = hotBar,
		}

		frame.healthBar:SetScript("OnSizeChanged", IncHeal.OnSizeChanged)
	end

	frame:RegisterUnitEvent("UNIT_MAXHEALTH", self, "UpdateFrame")
	frame:RegisterUnitEvent("UNIT_HEALTH_FREQUENT", self, "UpdateFrame")
	frame:RegisterUpdateFunc(self, "UpdateFrame")

	self:Setup()

	-- not sure what this does
	if(frame.incHeal.otherBeforeBar) then
		if(frame.incHeal.otherBeforeBar:IsObjectType("StatusBar") and not frame.incHeal.otherBeforeBar:GetStatusBarTexture()) then
			frame.incHeal.otherBeforeBar:SetStatusBarTexture([[Interface\TargetingFrame\UI-StatusBar]])
		end
	end

	if(frame.incHeal.myBar) then
		if(frame.incHeal.myBar:IsObjectType("StatusBar") and not frame.incHeal.myBar:GetStatusBarTexture()) then
			frame.incHeal.myBar:SetStatusBarTexture([[Interface\TargetingFrame\UI-StatusBar]])
		end
	end

	if(frame.incHeal.otherAfterBar) then
		if(frame.incHeal.otherAfterBar:IsObjectType("StatusBar") and not frame.incHeal.otherAfterBar:GetStatusBarTexture()) then
			frame.incHeal.otherAfterBar:SetStatusBarTexture([[Interface\TargetingFrame\UI-StatusBar]])
		end
	end

	if(frame.incHeal.hotBar) then
		if(frame.incHeal.hotBar:IsObjectType("StatusBar") and not frame.incHeal.hotBar:GetStatusBarTexture()) then
			frame.incHeal.hotBar:SetStatusBarTexture([[Interface\TargetingFrame\UI-StatusBar]])
		end
	end
end

function IncHeal:OnSizeChanged(healthBar)
	local frame = healthBar:GetParent()
	local otherBeforeBar, myBar, otherAfterBar, hotBar = frame.incHeal.otherBeforeBar, frame.incHeal.myBar, frame.incHeal.otherAfterBar, frame.incHeal.hotBar,
	otherBeforeBar:ClearAllPoints()
	myBar:ClearAllPoints()
	otherAfterBar:ClearAllPoints()
	hotBar:ClearAllPoints()

	otherBeforeBar:SetPoint("TOP")
	otherBeforeBar:SetPoint("BOTTOM")
	otherBeforeBar:SetPoint("LEFT", healthBar:GetStatusBarTexture(), "RIGHT")
	otherBeforeBar:SetWidth(healthBar:GetWidth())

	myBar:SetPoint("TOP")
	myBar:SetPoint("BOTTOM")
	myBar:SetPoint("LEFT", otherBeforeBar:GetStatusBarTexture(), "RIGHT")
	myBar:SetWidth(healthBar:GetWidth())

	otherAfterBar:SetPoint("TOP")
	otherAfterBar:SetPoint("BOTTOM")
	otherAfterBar:SetPoint("LEFT", myBar:GetStatusBarTexture(), "RIGHT")
	otherAfterBar:SetWidth(healthBar:GetWidth())

	hotBar:SetPoint("TOP")
	hotBar:SetPoint("BOTTOM")
	hotBar:SetPoint("LEFT", otherAfterBar:GetStatusBarTexture(), "RIGHT")
	hotBar:SetWidth(healthBar:GetWidth())
end

function IncHeal:OnDisable(frame)
	frame:UnregisterAll(self)

	local element = frame.incHeal
	if ( element ) then
		if(element.otherBeforeBar) then
			element.otherBeforeBar:Hide()
		end

		if(element.myBar) then
			element.myBar:Hide()
		end

		if(element.otherAfterBar) then
			element.otherAfterBar:Hide()
		end

		if(element.hotBar) then
			element.hotBar:Hide()
		end
	end

	if( not frame.hasHCTag ) then
		frames[frame] = nil
		self:Setup()
	end
end

function IncHeal:OnLayoutApplied(frame)
	if( frame.visibility.incHeal and frame.visibility.healthBar and frame.incHeal ) then
		local color = ShadowUF.db.profile.healthColors.inc
		frame.incHeal.otherBeforeBar:SetStatusBarColor(color.r, color.g, color.b, ShadowUF.db.profile.bars.alpha * 0.8)
		frame.incHeal.otherAfterBar:SetStatusBarColor(color.r, color.g, color.b, ShadowUF.db.profile.bars.alpha * 0.8)
		color = ShadowUF.db.profile.healthColors.ownInc
		frame.incHeal.myBar:SetStatusBarColor(color.r, color.g, color.b, ShadowUF.db.profile.bars.alpha * 0.8)
		color = ShadowUF.db.profile.healthColors.hotInc
		frame.incHeal.hotBar:SetStatusBarColor(color.r, color.g, color.b, ShadowUF.db.profile.bars.alpha * 0.8)

		for _, bar in pairs(frame.incHeal) do
			bar:SetHeight(frame.healthBar:GetHeight())
		end
	end
end

-- Since I don't want a more complicated system where both incheal.lua and tags.lua are watching the same events
-- I'll update the HC tags through here instead
function IncHeal:EnableTag(frame)
	frames[frame] = true
	frame.hasHCTag = true

	self:Setup()
end

function IncHeal:DisableTag(frame)
	frame.hasHCTag = nil

	if( not frame.visibility.incHeal ) then
		frames[frame] = nil
		self:Setup()
	end
end

-- Check if we need to register callbacks
function IncHeal:Setup()
	local enabled
	for frame in pairs(frames) do
		enabled = true
		break
	end

	if( not enabled ) then
		if( HealComm ) then
			HealComm:UnregisterAllCallbacks(IncHeal)
		end
		return
	end

	HealComm.RegisterCallback(self, "HealComm_HealStarted", "HealComm_HealUpdated")
	HealComm.RegisterCallback(self, "HealComm_HealStopped")
	HealComm.RegisterCallback(self, "HealComm_HealDelayed", "HealComm_HealUpdated")
	HealComm.RegisterCallback(self, "HealComm_HealUpdated")
	HealComm.RegisterCallback(self, "HealComm_ModifierChanged")
	HealComm.RegisterCallback(self, "HealComm_GUIDDisappeared")
end

-- Update any tags using HC
function IncHeal:UpdateTags(frame, amount)
	if( not frame.fontStrings or not frame.hasHCTag ) then return end

	for _, fontString in pairs(frame.fontStrings) do
		if( fontString.HEALCOMM ) then
			fontString.incoming = amount > 0 and amount or nil
			fontString:UpdateTags()
		end
	end
end

local function updateHealthBar(frame, interrupted)
	local element = frame.incHeal

	local guid = frame.unitGUID
	local timeFrame = GetTime() + INCOMING_SECONDS
	local preHeal, myHeal, afterHeal, hotHeal, totalHeal = 0, 0, 0, 0, 0
	local health, maxHealth = UnitHealth(frame.unit), UnitHealthMax(frame.unit)
	local mod = HealComm:GetHealModifier(guid) or 1

	totalHeal = HealComm:GetHealAmount(guid, HealComm.DIRECT_HEALS, timeFrame) or 0

	-- Update any tags that are using HC data
	IncHeal:UpdateTags(frame, totalHeal * mod)

	if( not frame.visibility.incHeal or not frame.visibility.healthBar ) then
		return
	end

	myHeal = HealComm:GetHealAmount(guid, HealComm.DIRECT_HEALS, timeFrame, myGUID) or 0
	-- We can only scout up to 2 direct heals that would land before ours but thats good enough for most cases
	local _, healFrom, healAmount = HealComm:GetNextHealAmount(guid, HealComm.DIRECT_HEALS, timeFrame)
	if healFrom and healFrom ~= myGUID and myHeal > 0 then
		preHeal = healAmount
		_, healFrom, healAmount = HealComm:GetNextHealAmount(guid, HealComm.DIRECT_HEALS, timeFrame, healFrom)
		if healFrom and healFrom ~= myGUID then
			preHeal = preHeal + healAmount
		end
	end
	afterHeal = totalHeal - preHeal - myHeal
	hotHeal = HealComm:GetHealAmount(guid, bit.bor(HealComm.HOT_HEALS, HealComm.CHANNEL_HEALS, HealComm.BOMB_HEALS), timeFrame) or 0
	totalHeal = totalHeal + hotHeal

	local maxOverflow = ShadowUF.db.profile.units[frame.unitType].incHeal.cap
	local maxBar = (maxHealth * maxOverflow - health)
	if preHeal >= maxBar then
		preHeal = maxBar
		myHeal = 0
		afterHeal = 0
		hotHeal = 0
	elseif (preHeal + myHeal) >= maxBar then
		myHeal = maxBar - preHeal
		afterHeal = 0
		hotHeal = 0
	elseif (preHeal + myHeal + afterHeal) >= maxBar then
		afterHeal = maxBar - preHeal - myHeal
		hotHeal = 0
	elseif (preHeal + myHeal + afterHeal + hotHeal) >= maxBar then
		hotHeal = maxBar - preHeal - myHeal - afterHeal
	end

	if(element.otherBeforeBar) then
		element.otherBeforeBar:SetMinMaxValues(0, maxHealth)
		element.otherBeforeBar:SetValue(preHeal*mod)
		if totalHeal > 0 then -- This needs to be totalHeal because only shown bars are size updated and bars might depend on another like in the example
			element.otherBeforeBar:Show()
		else
			element.otherBeforeBar:Hide()
		end
	end

	if(element.myBar) then
		element.myBar:SetMinMaxValues(0, maxHealth)
		element.myBar:SetValue(myHeal*mod)
		if totalHeal > 0 then
			element.myBar:Show()
		else
			element.myBar:Hide()
		end
	end

	if(element.otherAfterBar) then
		element.otherAfterBar:SetMinMaxValues(0, maxHealth)
		element.otherAfterBar:SetValue(afterHeal*mod)
		if totalHeal > 0 then
			element.otherAfterBar:Show()
		else
			element.otherAfterBar:Hide()
		end
	end

	if(element.hotBar) then
		element.hotBar:SetMinMaxValues(0, maxHealth)
		element.hotBar:SetValue(hotHeal*mod)
		if totalHeal > 0 then
			element.hotBar:Show()
		else
			element.hotBar:Hide()
		end
	end


	-- Bar is also supposed to be enabled, lets update that too
	--if( frame.visibility.incHeal and frame.visibility.healthBar ) then
	--	if( healed > 0 ) then
	--		frame.incHeal.healed = healed
	--		frame.incHeal:Show()
	--
	--		local health, maxHealth = UnitHealth(frame.unit), UnitHealthMax(frame.unit)
	--		local healthWidth = frame.incHeal.healthWidth * (health / maxHealth)
	--		local incWidth = frame.healthBar:GetWidth() * (healed / health)
	--		if( (healthWidth + incWidth) > frame.incHeal.maxWidth ) then
	--			incWidth = frame.incHeal.cappedWidth
	--		end
	--
	--		frame.incHeal:SetWidth(incWidth)
	--		frame.incHeal:SetPoint("TOPLEFT", frame, "TOPLEFT", frame.incHeal.healthX + healthWidth, frame.incHeal.healthY)
	--	else
	--		frame.incHeal.total = nil
	--		frame.incHeal.healed = nil
	--		frame.incHeal:Hide()
	--	end
	--end
end

function IncHeal:UpdateFrame(frame)
	updateHealthBar(frame, true)
end

function IncHeal:UpdateIncoming(interrupted, ...)
	for frame in pairs(frames) do
		for i=1, select("#", ...) do
			if( select(i, ...) == frame.unitGUID ) then
				updateHealthBar(frame, interrupted)
			end
		end
	end
end

-- Handle callbacks from HealComm
function IncHeal:HealComm_HealUpdated(event, casterGUID, spellID, healType, endTime, ...)
	self:UpdateIncoming(nil, ...)
end

function IncHeal:HealComm_HealStopped(event, casterGUID, spellID, healType, interrupted, ...)
	self:UpdateIncoming(interrupted, ...)
end

function IncHeal:HealComm_ModifierChanged(event, guid)
	self:UpdateIncoming(nil, guid)
end

function IncHeal:HealComm_GUIDDisappeared(event, guid)
	self:UpdateIncoming(true, guid)
end
