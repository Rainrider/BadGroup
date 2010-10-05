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
	355, -- taunt
	1161, -- challenging shout
	694, -- mocking blow
	-- paladin
	31789, -- rghteous defense
	62124, -- hand of reckoning
	-- death knight
	49576, -- death grip
	56222, -- dark command
	-- druid
	6795, -- growl
	5209, -- challenging roar
	-- hunter
	20736, -- distracting shot
	-- hunter's pet
	2649, -- growl 1
	14916, -- growl 2
	14917, -- growl 3
	14918, -- growl 4
	14919, -- growl 5
	14920, -- growl 6
	14921, -- growl 7
	27047, -- growl 8
	61676, -- growl 9
	-- warlock's pets
	33698, -- anguish 1
	33699, -- anguish 2
	33700, -- anguish 3
	47993, -- anguish 4
	3716, -- torment 1
	7809, -- torment 2
	7810, -- torment 3
	7811, -- torment 4
	11774, -- torment 5
	11775, -- torment 6
	27270, -- torment 7
	47984, -- torment 8
	17735, -- suffering 1
	17750, -- suffering 2
	17751, -- suffering 3
	17752, -- suffering 4
	27271, -- suffering 5
	33701, -- suffering 6
	47989, -- suffering 7
	47990, -- suffering 8
}

local badAuras = {
	["DEATHKNIGHT"] = 48263, -- frost presence
	["PALADIN"] = 25780, -- righteous fury
	["WARRIOR"] = 71, -- defensive stance
}

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
	end
end

function BadGroup:PLAYER_ENTERING_WORLD()
	self:EventHandler()
end

function BadGroup:EventHandler()
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
	local subtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellid, spellname = select(2, ...)
	
	if (subtype == "SPELL_CAST_SUCCESS" and not self:IsOutsider(srcFlags) and not self:IsTank(srcName) and self:CheckSpellid(spellid)) then
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
	
	if (UnitGroupRolesAssigned(srcName) or GetPartyAssignment("MAINTANK", srcName, exactMatch) == 1) then
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
-- TODO: stolen this from crybaby, still have to understand why my version didn't work
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

function BadGroup:CheckAuras()
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
			local _, playerClass = UnitClass(groupType .. i)
			if (playerClass == "PALADIN" or playerClass == "DEATHKNIGHT" or playerClass == "WARRIOR") then	
				for k, auraId in pairs(badAuras) do
					local auraName = GetSpellInfo(auraId)
					if (select(11, UnitAura(groupType .. i, auraName)) == badAuras[playerClass]) then
						local playerName = UnitName(groupType .. i)
						if (BadGroupSV.socialOutput and not self:IsTank(playerName)) then
							SendChatMessage("Non-tank " .. self:RaidIcon(playerName, true) .. playerName .. " has " .. GetSpellLink(auraId) .. " on.", groupType == "raid" and "RAID" or "PARTY")
						elseif (not self:IsTank(playerName)) then
							self:Print(self:RaidIcon(playerName, false) .. self:ClassColoredName(playerName) .. " has " .. GetSpellLink(auraId) .. " on.")
						end
					end
				end
			end
		end
	end
	
	local _, playerClass = UnitClass("player")
	
	if (playerClass == "DEATHKNIGHT" or playerClass == "PALADIN" or playerClass == "WARRIOR") then
		for k, auraId in pairs(badAuras) do
			local auraName = GetSpellInfo(auraId)
			if (select(11, UnitAura("player", auraName)) == badAuras[playerClass]) then
				local playerName = UnitName("player")
				if (BadGroupSV.socialOutput and groupType and not self:IsTank(playerName)) then
					SendChatMessage("Non-tank " .. self:RaidIcon(playerName, true) .. playerName .. " has " .. GetSpellLink(auraId) .. " on.", groupType == "raid" and "RAID" or "PARTY")
				elseif (not self:IsTank(playerName)) then
					self:Print(self:RaidIcon(playerName, false) .. self:ClassColoredName(playerName) .. " has " .. GetSpellLink(auraId) .. " on.")
				end
			end
		end
	end
	
	self:Print("Auras check done.")
end
-- TODO: check if tank to add already there
function BadGroup:AddTank(tankName)
	if (tankName == UnitName("player") or tankName == UnitName("pet") or UnitPlayerOrPetInParty(tankName) == 1 or UnitPlayerOrPetInRaid(tankName) == 1) then
		table.insert(BadGroupSV.customTanks, tankName)
		self:Print("Added tank " .. self:ClassColoredName(tankName))
	else
		self:Print("You have to target a group member first.")
	end
end

-- TODO: does not remove all occurances of a tank (???)
function BadGroup:RemoveTank(tankName)
	for i, name in ipairs(BadGroupSV.customTanks) do
		if (tankName == name) then
			table.remove(BadGroupSV.customTanks, i)
			self:Print("Removed " .. tankName .. " from the list.")
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