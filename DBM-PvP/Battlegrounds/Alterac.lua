local mod	= DBM:NewMod("z30", "DBM-PvP", 2)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("@file-date-integer@")
mod:SetZone(DBM_DISABLE_ZONE_DETECTION)

mod:AddBoolOption("AutoTurnIn")

mod:RegisterEvents(
	"ZONE_CHANGED_NEW_AREA"
)

local GetAreaPOIForMap, GetAreaPOIInfo = C_AreaPoiInfo.GetAreaPOIForMap, C_AreaPoiInfo.GetAreaPOIInfo
local towerTimer	= mod:NewTimer(240, "TimerTower", "136001")
local gyTimer		= mod:NewTimer(240, "TimerGY", "136119")

local allyTowerIcon = "Interface\\AddOns\\DBM-PvP\\Textures\\GuardTower"
local hordeTowerIcon = "Interface\\AddOns\\DBM-PvP\\Textures\\OrcTower"

local graveyards = {}
local function is_graveyard(id)
	return id == 8 or id == 15 or id == 13 or id == 4 or id == 14
end

local function gy_state(id)
	if id == 8 then			return -1	-- Neutral
	elseif id == 15 then	return 1	-- Alliance controlled
	elseif id == 13 then 	return 2	-- Horde controlled
	elseif id == 4 then		return 3	-- Alliance assaulted
	elseif id == 14 then	return 4	-- Horde assaulted
	else return false
	end
end

local towers = {}
local function is_tower(id)
	return id == 6 or id == 11 or id == 10 or id == 9 or id == 12
end

local function tower_state(id)
	if id == 6 then			return -1	-- Neutral / Destroyed
	elseif id == 11 then	return 1	-- Alliance controlled
	elseif id == 10 then	return 2	-- Horde controlled
	elseif id == 9 then		return 3	-- Alliance assaulted
	elseif id == 12 then	return 4	-- Horde assaulted
	else return false
	end
end

local bgzone = false
do
	local function AV_Initialize(self)
		if DBM:GetCurrentArea() == 30 then
			bgzone = true
			self:RegisterShortTermEvents(
				"CHAT_MSG_MONSTER_YELL",
				"CHAT_MSG_BG_SYSTEM_ALLIANCE",
				"CHAT_MSG_BG_SYSTEM_HORDE",
				"CHAT_MSG_BG_SYSTEM_NEUTRAL",
				"RAID_BOSS_EMOTE",
				"GOSSIP_SHOW",
				"QUEST_PROGRESS",
				"QUEST_COMPLETE"
			)
			for _, areaPOIId in ipairs(GetAreaPOIForMap(30)) do
				local areaPOIInfo = GetAreaPOIInfo(30, areaPOIId)
				local name = areaPOIInfo.name
				local textureIndex = areaPOIInfo.textureIndex
				if name == "Friedhof des Sturmlanzen" then
					name = "Friedhof der Sturmlanzen"
				end
				if name and textureIndex then
					if is_graveyard(textureIndex) then
						graveyards[name] = gy_state(textureIndex)
					elseif is_tower(textureIndex) then
						towers[name] = tower_state(textureIndex)
					end
				end
			end
		elseif bgzone then
			bgzone = false
			self:UnregisterShortTermEvents()
		end
	end
	mod.OnInitialize = AV_Initialize

	function mod:ZONE_CHANGED_NEW_AREA()
		self:Schedule(1, AV_Initialize, self)
	end
end

do
	local function check_for_updates()
		if not bgzone then return end
		for _, areaPOIId in ipairs(GetAreaPOIForMap(mapId)) do
			local areaPOIInfo = GetAreaPOIInfo(mapId, areaPOIId)
			local name = areaPOIInfo.name
			local textureIndex = areaPOIInfo.textureIndex
			if name and textureIndex then
				if is_graveyard(textureIndex) then
					local curState = gy_state(textureIndex)
					if curState and (graveyards[name] ~= curState) then
						gyTimer:Stop(name)
						if curState > 2 then
							gyTimer:Start(nil, name)
							if curState == 3 then
								gyTimer:SetColor(allyColor, name)
							else
								gyTimer:SetColor(hordeColor, name)
							end
						end
						graveyards[name] = curState
					end
				elseif is_tower(textureIndex) then
					local curState = tower_state(textureIndex)
					if curState and (towers[name] ~= curState) then
						towerTimer:Stop(name)
						if curState > 2 then
							towerTimer:Start(nil, name)
							if curState == 3 then
								towerTimer:SetColor(0, 0, 1, name)
								towerTimer:UpdateIcon(hordeTowerIcon, name)
							else
								towerTimer:SetColor(1, 0, 0, name)
								towerTimer:UpdateIcon(allyTowerIcon, name)
							end
						end
						towers[name] = curState
					end
				end
			end
		end
	end

	local function schedule_check(self)
		self:Schedule(1, check_for_updates)
	end
	mod.CHAT_MSG_MONSTER_YELL = schedule_check
	mod.CHAT_MSG_BG_SYSTEM_ALLIANCE = schedule_check
	mod.CHAT_MSG_BG_SYSTEM_HORDE = schedule_check
	mod.RAID_BOSS_EMOTE = schedule_check
	mod.CHAT_MSG_BG_SYSTEM_NEUTRAL = schedule_check
end

local quests
do
	local getQuestName
	do
		local tooltip = CreateFrame("GameTooltip", "DBM-PvP_Tooltip")
		tooltip:SetOwner(UIParent, "ANCHOR_NONE")
		tooltip:AddFontStrings(tooltip:CreateFontString("$parentText", nil, "GameTooltipText"), tooltip:CreateFontString("$parentTextRight", nil, "GameTooltipText"))

		function getQuestName(id)
			tooltip:ClearLines()
			tooltip:SetHyperlink("quest:"..id)
			return _G[tooltip:GetName().."Text"]:GetText()
		end
	end

	local function loadQuests()
		for i, v in pairs(quests) do
			if type(v[1]) == "table" then
				for i, v in ipairs(v) do
					v[1] = getQuestName(v[1]) or v[1]
				end
			else
				v[1] = getQuestName(v[1]) or v[1]
			end
		end
	end

	quests = {
		[13442] = {
			{7386, 17423, 5},
			{6881, 17423},
		},
		[13236] = {
			{7385, 17306, 5},
			{6801, 17306},
		},
		[13257] = {6781, 17422, 20},
		[13176] = {6741, 17422, 20},
		[13577] = {7026, 17643},
		[13179] = {6825, 17326},
		[13438] = {6942, 17502},
		[13180] = {6826, 17327},
		[13181] = {6827, 17328},
		[13439] = {6941, 17503},
		[13437] = {6943, 17504},
		[13441] = {7002, 17642},
	}

	loadQuests()
	mod:Schedule(5, loadQuests)
	mod:Schedule(15, loadQuests)
end

local function isQuestAutoTurnInQuest(name)
	for i, v in pairs(quests) do
		if type(v[1]) == "table" then
			for i, v in ipairs(v) do
				if v[1] == name then return true end
			end
		else
			if v[1] == name then return true end
		end
	end
end

local function acceptQuestByName(name)
	for i = 1, select("#", GetGossipAvailableQuests()), 5 do
		if select(i, GetGossipAvailableQuests()) == name then
			SelectGossipAvailableQuest(math.ceil(i/5))
			break
		end
	end
end

local function checkItems(item, amount)
	local found = 0
	for bag = 0, NUM_BAG_SLOTS do
		for i = 1, GetContainerNumSlots(bag) do
			if tonumber((GetContainerItemLink(bag, i) or ""):match(":(%d+):") or 0) == item then
				found = found + select(2, GetContainerItemInfo(bag, i))
			end
		end
	end
	return found >= amount
end

function mod:GOSSIP_SHOW()
	if not bgzone or not self.Options.AutoTurnIn then return end
	local quest = quests[tonumber(self:GetCIDFromGUID(UnitGUID("target") or "")) or 0]
	if quest and type(quest[1]) == "table" then
		for i, v in ipairs(quest) do
			if checkItems(v[2], v[3] or 1) then
				acceptQuestByName(v[1])
				break
			end
		end
	elseif quest then
		if checkItems(quest[2], quest[3] or 1) then acceptQuestByName(quest[1]) end
	end
end

function mod:QUEST_PROGRESS()
	if bgzone and isQuestAutoTurnInQuest(GetTitleText()) then
		CompleteQuest()
	end
end

function mod:QUEST_COMPLETE()
	if bgzone and isQuestAutoTurnInQuest(GetTitleText()) then
		GetQuestReward(0)
	end
end