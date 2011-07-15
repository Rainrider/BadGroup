local redColor = "|cffff0000"
local greenColor = "|cff00ff00"
local yellowColor = "|cffffff00"

local coloredAddonName = "|cff0099CCBadGroup:|r "

local defaults = {
	["socialOutput"] = true,
	["debug"] = false,
	["customTanks"] = {}
}

local spellList = {
	-- warrior
	355,	-- taunt
	1161,	-- challenging shout
	694,	-- mocking blow
	-- paladin
	31789,	-- rghteous defense
	62124,	-- hand of reckoning
	-- death knight
	49576,	-- death grip
	56222,	-- dark command
	-- druid
	6795,	-- growl
	5209,	-- challenging roar
	-- hunter
	20736,	-- distracting shot
	-- hunter's pet
	2649,	-- growl
	-- warlock's pets
	33698,	-- anguish 
	3716,	-- torment
	17735,	-- suffering
}

local badAuras = {
	["DEATHKNIGHT"] = 48263,	-- blood presence
	["PALADIN"] = 25780,		-- righteous fury
	["WARRIOR"] = 71,			-- defensive stance
}

local numMembers = 0
local groupType = ""

local raidIcons = {}
local rtmask

local metaSV = {
	__tostring = function(tbl)
		local str = ""
		
		for k, v in pairs(tbl) do
			str = str .. greenColor .. k .. ":|r " .. tostring(v) .. " "
		end
		return str
	end
}

local BadGroup = CreateFrame("Frame", "BadGroup", UIParent)
BadGroup:SetScript("OnEvent", function(self, event, ...) self[event](self, event, ...) end)
BadGroup:RegisterEvent("ADDON_LOADED")

function BadGroup:ADDON_LOADED(event, name)
	if (name == self:GetName()) then
		-- set slash commands
		SLASH_BadGroup1 = "/bgrp"
		SLASH_BadGroup2 = "/badgroup"
		SlashCmdList[name] = self.Command
		
		-- set SavedVariables
		BadGroupSV = BadGroupSV or defaults
		BadGroupSV = setmetatable(BadGroupSV, metaSV)
		BadGroupSV.customTanks = setmetatable(BadGroupSV.customTanks, metaSV)
		
		-- register events
		self:RegisterEvent("PLAYER_ENTERING_WORLD")
		self:RegisterEvent("PARTY_MEMBERS_CHANGED")
		self:RegisterEvent("RAID_ROSTER_UPDATE")
	end
end

function BadGroup:PARTY_MEMBERS_CHANGED()
	self:CountGroupMembers()
end

function BadGroup:RAID_ROSTER_UPDATE()
	self:CountGroupMembers()
end

function BadGroup:PLAYER_ENTERING_WORLD()
	local _, locType = GetInstanceInfo()

	if locType ~= "raid" or locType ~= "party" then
		if (self:IsEventRegistered("COMBAT_LOG_EVENT_UNFILTERED")) then
			self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
			self:Debug("Idle ... zzZZzz")
		end
	end
	
	if locType == "raid" or locType == "party" then
		if (not self:IsEventRegistered("COMBAT_LOG_EVENT_UNFILTERED")) then
			self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
			self:Debug("Now repoting!")
		end
	end
	
	self:CreateRaidIcons()
	self:CountGroupMembers()
end

function BadGroup:COMBAT_LOG_EVENT_UNFILTERED(event, ...)
	local _, subtype, hideCaster, srcGUID, srcName, srcFlags, srcRaidFlags, dstGUID, dstName, dstFlags, dstRaidFlags, spellid, spellname = ...
	
	if (subtype == "SPELL_CAST_SUCCESS" and not self:IsOutsider(srcFlags) and self:CheckSpellid(spellid) and not self:IsTank(srcName)) then
		return self:ChatOutput(srcName, srcGUID, srcRaidFlags, dstName, dstRaidFlags, spellid)
	end
end

function BadGroup:CountGroupMembers(event)
	numMembers = GetNumRaidMembers()
	if (numMembers > 0) then
		groupType = "raid"
		return
	end
	
	numMembers = GetNumPartyMembers()
	if (numMembers > 0) then
		groupType = "party"
		return
	end
	
	numMembers = 0
	groupType = ""
end

function BadGroup:IsOutsider(srcFlags)
	return bit.band(srcFlags, COMBATLOG_OBJECT_AFFILIATION_MASK) >= COMBATLOG_OBJECT_AFFILIATION_OUTSIDER
end

function BadGroup:IsTank(srcName)
	for i, tankName in ipairs(BadGroupSV.customTanks) do
		if (srcName == tankName) then
			return true
		end
	end
	
	if ((groupType == "party" and UnitGroupRolesAssigned(srcName) == "TANK")
			or (groupType == "raid" and GetPartyAssignment("MAINTANK", srcName, exactMatch))) then
		return true
	end
end

function BadGroup:CheckSpellid(spellid)
	for i, v in ipairs(spellList) do
		if v == spellid then
			return true
		end
	end
end

function BadGroup:GetPetOwner(srcGUID)
	local petGUID
	
	if (numMembers > 0) then
		for i = 1, numMembers do
			petGUID = UnitGUID(groupType .. "pet" .. i)
			if (petGUID and petGUID == srcGUID) then
				return UnitName(groupType .. i)
			end
		end
	end
	
	petGUID = UnitGUID("pet");
	if (petGUID and petGUID == srcGUID) then
		return UnitName("player")
	end
end

function BadGroup:ClassColoredName(srcName)
	local _, playerClass = UnitClass(srcName)
	local classColor = RAID_CLASS_COLORS[playerClass]
	return string.format("|cff%02x%02x%02x%s|r", classColor.r * 255, classColor.g * 255, classColor.b * 255, srcName)
end

function BadGroup:CreateRaidIcons()
	rtmask = _G.COMBATLOG_OBJECT_RAIDTARGET_MASK
	
	for i = 1, #_G.ICON_LIST do
		local iconbit = _G["COMBATLOG_OBJECT_RAIDTARGET" .. i]
		local icon = _G["COMBATLOG_ICON_RAIDTARGET" .. i]
		raidIcons[iconbit] = {
			iconString = TEXT_MODE_A_STRING_DEST_ICON:format(iconbit, icon),
			icon	   = icon,
			rt		   = i,
		}
	end
end

function BadGroup:GetRaidIcon(flag, social)
	if (flag == nil) then return "" end
	
	local icon = raidIcons[bit.band(flag, rtmask)]
	if not icon then return "" end
	
	if (social) then
		return ("{rt%d}"):format(icon.rt)
	else
		return icon.iconString
	end
end

function BadGroup:ChatOutput(srcName, srcGUID, srcRaidFlags, dstName, dstRaidFlags, spellid)

	local spellLink = GetSpellLink(spellid)
	local srcRaidIcon = self:GetRaidIcon(srcRaidFlags, BadGroupSV.socialOutput)
	local owner = self:GetPetOwner(srcGUID)

	local message
	local prvtMessage

	if (not owner) then
		message = ("%s used by %s%s"):format(spellLink, srcRaidIcon, srcName)
		prvtMessage = ("%s used by %s%s"):format(spellLink, srcRaidIcon, self:ClassColoredName(srcName))
	else
		message = ("%s used by %s's pet %s"):format(spellLink, owner, srcName)
		prvtMessage = ("%s used by %s's pet %s%s|r"):format(spellLink, self:ClassColoredName(owner), greenColor, srcName)
	end

	if (dstName) then
		local dstRaidIcon = self:GetRaidIcon(dstRaidFlags, BadGroupSV.socialOutput)
		message = ("%s on %s%s"):format(message, dstRaidIcon, dstName)
		prvtMessage = ("%s on %s%s%s|r"):format(prvtMessage, dstRaidIcon, redColor, dstName)
	end

	if(BadGroupSV.socialOutput and numMembers > 0) then
		SendChatMessage(message, string.upper(groupType))
	else
		self:Print(prvtMessage)
	end
end

function BadGroup:ScanAuras(unitID, groupType)
	local _, playerClass = UnitClass(unitID)
	local auraID = badAuras[playerClass]
	local auraName
	
	if (auraID) then
		auraName = GetSpellInfo(auraID)
	else
		return
	end
	
	if (UnitAura(unitID, auraName) == auraName) then
		local playerName = UnitName(unitID)
		if (BadGroupSV.socialOutput and groupType == "raid" or groupType == "party" and not self:IsTank(playerName)) then
			SendChatMessage("Non-tank " .. playerName .. " has " .. GetSpellLink(auraID) .. " on.", groupType == "raid" and "RAID" or "PARTY")
		elseif (not self:IsTank(playerName)) then
			self:Print("Non-tank " .. self:ClassColoredName(playerName) .. " has " .. GetSpellLink(auraID) .. " on.")
		end
	end
end

function BadGroup:CheckAuras()
	if (numMembers > 0) then
		for i = 1, numMembers do
			self:ScanAuras(groupType .. i, groupType)
		end
	end
	
	self:ScanAuras("player", groupType)
	
	self:Print("Auras check done.")
end

function BadGroup:AddTank(tankName)
	if (tankName == UnitName("player") or tankName == UnitName("pet") or UnitPlayerOrPetInParty(tankName) or UnitPlayerOrPetInRaid(tankName)) then
		for i, v in ipairs(BadGroupSV.customTanks) do
			if (v == tankName) then
				self:Print(tankName .. " is already in the list.")
				return
			end
		end
	
		table.insert(BadGroupSV.customTanks, tankName)
		self:Print("Added tank " .. self:ClassColoredName(tankName))
	else
		self:Print("You have to target a group member first.")
	end
end

function BadGroup:RemoveTank(tankName)
	for i, name in ipairs(BadGroupSV.customTanks) do
		if (tankName == name) then
			table.remove(BadGroupSV.customTanks, i)
			self:Print("Removed " .. tankName .. " from the list.")
		end
	end
end

function BadGroup:WipeTanks()
	table.wipe(BadGroupSV.customTanks)
	self:Print("All custom tanks removed.")
end

function BadGroup:Debug(...)
	if (BadGroupSV.debug) then
		print(coloredAddonName .. redColor .. "debug:|r ", ...)
	end
end

function BadGroup:Print(...)
	local str = tostring(...)
	DEFAULT_CHAT_FRAME:AddMessage(coloredAddonName .. str)
end

function BadGroup.Command(str, editbox)
	if (str == "social") then
		BadGroupSV.socialOutput = true
		BadGroup:Print("Output set to " .. yellowColor .. "social|r.")
	elseif (str == "private") then
		BadGroupSV.socialOutput = false
		BadGroup:Print("Output set to " .. yellowColor .. "private|r.")
	elseif (str == "debug" and BadGroupSV.debug) then
		BadGroupSV.debug = false
		BadGroup:Print(greenColor .. "Stopped debugging|r.")
	elseif (str == "debug" and not BadGroupSV.debug) then
		BadGroupSV.debug = true
		BadGroup:Print(redColor .. "Started debugging|r.")
	elseif (str == "status") then 
		BadGroup:Print(BadGroupSV)
	elseif (str == "add") then
		if (not UnitExists("target")) then
			BadGroup:Print("You have to target something")
		else
			BadGroup:AddTank(UnitName("target"))
		end
	elseif (str == "del") then
		if (not UnitExists("target")) then
			BadGroup:Print("You have to target something")
		else
			BadGroup:RemoveTank(UnitName("target"))
		end
	elseif (str == "wipe") then
		BadGroup:WipeTanks()
	elseif (str == "tanks") then
		BadGroup:Print(BadGroupSV.customTanks)
	elseif (str == "auras") then
		BadGroup:CheckAuras()
	else
		BadGroup:Print(redColor .. "Unknown command:|r " .. str)
	end
end