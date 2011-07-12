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

local partyTargets = {}

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
		-- TODO: for keeping the tank list
		-- self:RegisterEvent("PARTY_MEMBERS_CHANGED")
		-- self:RegisterEvent("PLAYER_ROLES_ASSIGNED") -- check what this is for
		-- self:RegisterEvent("ROLE_CHANGED_INFORM")
		-- self:RegisterEvent("LFG_ROLE_UPDATE") -- check what this is for
		-- self:RegisterEvent("RAID_ROSTER_UPDATE")
	end
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
end

function BadGroup:COMBAT_LOG_EVENT_UNFILTERED(event, ...)
	local subtype, hideCaster, srcGUID, srcName, srcFlags, srcRaidFlags, dstGUID, dstName, dstFlags, dstRaidFlags, spellid, spellname = select(2, ...)
	
	if (subtype == "SPELL_CAST_SUCCESS" and not self:IsOutsider(srcFlags) and self:CheckSpellid(spellid) and not self:IsTank(srcName)) then
		return self:ChatOutput(srcName, srcGUID, dstName, spellid)
	end
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

	if (not UnitIsPlayer(srcName) or UnitHasVehicleUI(srcName)) then
		return false
	end
	
	if (UnitGroupRolesAssigned(srcName) == "TANK" or GetPartyAssignment("MAINTANK", srcName, exactMatch) == 1) then
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
	local pet
	local numMembers
	local groupType
	
	if (GetNumRaidMembers() > 0) then
		numMembers = GetNumRaidMembers()
		groupType = "raid"
	elseif (GetNumPartyMembers() > 0) then
		numMembers = GetNumPartyMembers()
		groupType = "party"
	end
	
	if (numMembers and groupType) then
		for i = 1, numMembers do
			pet = UnitGUID(groupType .. "pet" .. i)
			if (pet and pet == srcGUID) then
				return UnitName(groupType .. i)
			end
		end
	end
	
	pet = UnitGUID("pet");
	if (pet and pet == srcGUID) then
		return UnitName("player")
	end
end

function BadGroup:ClassColoredName(srcName)
	local _, playerClass = UnitClass(srcName)
	local classColor = RAID_CLASS_COLORS[playerClass]
	return string.format("|cff%02x%02x%02x%s|r", classColor.r * 255, classColor.g * 255, classColor.b * 255, srcName)
end

-- NOTES: GetRaidTargetIndex works only with player names. else it always returns 1
-- TODO: switch this to using bit.band on src(Raid)Flags and dst(Raid)Flags as in crybaby
function BadGroup:RaidIcon(name, social)
	local index = GetRaidTargetIndex(name)
	local format = _G.string.format
	local iconlist = _G.ICON_LIST
	local iconformat = "%s16|t " -- 16 is the size of the icon
	
	if index and social then
		return "{rt" .. index .. "} "
	elseif index and not social then
		return iconformat:format(iconlist[index])
	else
		return ""
	end
end

-- TODO: player hyperlink
-- TODO: mob hyperlink
-- NOTE: hyperlinks will error on right click as they are not in the combat log
-- |Hunit:unitGUID|hname|h
function BadGroup:ChatOutput(srcName, srcGUID, dstName, spellid)
	local start = GetTime()
	local message = GetSpellLink(spellid) .. " used by " .. self:RaidIcon(srcName, true) .. srcName
	local prvtMessage = GetSpellLink(spellid) .. " used by " .. self:RaidIcon(srcName, false) .. self:ClassColoredName(srcName)
	local owner = self:GetPetOwner(srcGUID)

	if (owner) then
		message = GetSpellLink(spellid) .. " used by " .. owner .. "'s pet " .. srcName
		prvtMessage = GetSpellLink(spellid) .. " used by " .. self:ClassColoredName(owner) .. "'s pet " .. greenColor .. srcName .. "|r"
	end

	if (dstName) then
		message = message .. " on " .. self:RaidIcon(srcName .. "-target", true) .. dstName
		prvtMessage = prvtMessage .. " on " .. self:RaidIcon(srcName .. "-target", false) .. redColor .. dstName .. "|r"
	end

	if(GetNumRaidMembers() > 0 and BadGroupSV.socialOutput) then
		SendChatMessage(message, "RAID")
	elseif (GetNumPartyMembers() > 0 and BadGroupSV.socialOutput) then
		SendChatMessage(message, "PARTY")
	else
		self:Print(prvtMessage)
	end
	self:Debug("chatoutput: ", GetTime() - start)
end

function BadGroup:ScanAuras(unitID, groupType)
	local _, playerClass = UnitClass(unitID)
	local auraID = badAuras[playerClass]
	local auraName = GetSpellInfo(auraID)
	local playerName = UnitName(unitID)
	
	if (select(11, UnitAura(unitID, auraName)) == auraID) then
		if (BadGroupSV.socialOutput and groupType and not self:IsTank(playerName)) then
			SendChatMessage("Non-tank " .. self:RaidIcon(playerName, true) .. playerName .. " has " .. GetSpellLink(auraID) .. " on.", groupType == "raid" and "RAID" or "PARTY")
		elseif (not self:IsTank(playerName)) then
			self:Print(self:RaidIcon(playerName, false) .. self:ClassColoredName(playerName) .. " has " .. GetSpellLink(auraID) .. " on.")
		end
	end
end

function BadGroup:CheckAuras()
	local numMembers
	local groupType

	numMembers = GetNumRaidMembers()
	if (numMembers and numMembers > 0) then
		groupType = "raid"
	else
		numMembers = GetNumPartyMembers()
		if (numMembers and numMembers > 0) then
			groupType = "party"
		end
	end

	if (numMembers and groupType) then
		for i = 1, numMembers do
			self:ScanAuras(groupType .. i, groupType)
		end
	end
	
	self:ScanAuras("player", groupType)
	
	self:Print("Auras check done.")
end

-- TODO: check if tank to add already there
function BadGroup:AddTank(tankName)
	if (tankName == UnitName("player") or tankName == UnitName("pet") or UnitPlayerOrPetInParty(tankName) or UnitPlayerOrPetInRaid(tankName)) then
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
			i = i - 1
			if (i < 1) then break end
		end
	end
end

function BadGroup:WipeTanks()
	BadGroupSV.customTanks = {}
	self:Print("All custom tanks removed.")
end

function BadGroup:Debug(...)
	if (BadGroupSV.debug or debugTest) then
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