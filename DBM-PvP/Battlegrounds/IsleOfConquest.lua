local mod	= DBM:NewMod("z628", "DBM-PvP", 2)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("@file-date-integer@")
mod:SetZone(DBM_DISABLE_ZONE_DETECTION)

mod:RegisterEvents(
	"ZONE_CHANGED_NEW_AREA"
)

local warnSiegeEngine 		= mod:NewAnnounce("WarnSiegeEngine", 3)
local warnSiegeEngineSoon 	= mod:NewAnnounce("WarnSiegeEngineSoon", 2)

local POITimer 			= mod:NewTimer(60, "TimerPOI", "136002")
local timerSiegeEngine 	= mod:NewTimer(180, "TimerSiegeEngine", 15048)

--mod:AddBoolOption("ShowGatesHealth", true)

local GetAreaPOIForMap, GetAreaPOIInfo = C_AreaPoiInfo.GetAreaPOIForMap, C_AreaPoiInfo.GetAreaPOIInfo

--local gateHP = {}

local function isInArgs(val, ...)
	for i=1, select("#", ...), 1 do
		local v = select(i,  ...)
		if v == val then
			return true
		end
	end
	return false
end

--[[
local updateInfoFrame
do
	local lines = {}
	updateInfoFrame = function()
		table.wipe(lines)
		if #gateHP == 0 then
			DBM.InfoFrame:Hide()
		end
		for i = 1, #gateHP do
			local currentHealth = gateHP[i]/6000
			lines[L.GatesHealthFrame] = math.floor(currentHealth).."%"
		end
		return lines
	end
end
--]]

local poi = {}
local function isPoi(id)
	return (id >= 16 and id <= 20) 		-- Quarry
		or (id >= 135 and id <= 139)	-- Workshop
		or (id >= 140 and id <= 144)	-- Hangar
		or (id >= 145 and id <= 149)	-- Docks
		or (id >= 150 and id <= 154)	-- Refinerie
		or (id >= 9 and id <= 12)		-- Keep
end
local function getPoiState(id)
	if isInArgs(id, 16, 135, 140, 145, 150) then			return -1 -- Neutral
	elseif isInArgs(id, 11, 18, 136, 141, 146, 151) then	return 1 -- Alliance controlled
	elseif isInArgs(id, 10, 20, 138, 143, 148, 153) then	return 2 -- Horde controlled
	elseif isInArgs(id, 9, 17, 137, 142, 147, 152) then		return 3 -- Alliance assaulted
	elseif isInArgs(id, 12, 19, 139, 144, 149, 154) then	return 4 -- Horde assaulted
	else return false
	end
end

local bgzone = false
do
	local function initialize(self)
		if DBM:GetCurrentArea() == 628 then
			bgzone = true
			self:RegisterShortTermEvents(
				"CHAT_MSG_MONSTER_YELL",
				"CHAT_MSG_BG_SYSTEM_ALLIANCE",
				"CHAT_MSG_BG_SYSTEM_HORDE",
				"CHAT_MSG_RAID_BOSS_EMOTE",
				"UNIT_DIED"
				--"SPELL_BUILDING_DAMAGE"
			)
			for _, areaPOIId in ipairs(GetAreaPOIForMap(628)) do
				local areaPOIInfo = GetAreaPOIInfo(628, areaPOIId)
				local name = areaPOIInfo.name
				local textureIndex = areaPOIInfo.textureIndex
				if name and textureIndex then
					if isPoi(textureIndex) then
						poi[i] = textureIndex
					end
				end
			end
			gateHP = {}
		elseif bgzone then
			self:UnregisterShortTermEvents()
			bgzone = false
			--if self.Options.ShowGatesHealth then
			--	DBM.InfoFrame:Hide()
			--end
		end
	end
	mod.OnInitialize = initialize

	function mod:ZONE_CHANGED_NEW_AREA()
		self:Schedule(1, initialize, self)
	end
end

do
	local function checkForUpdates()
		if not bgzone then
			return
		end
		for _, areaPOIId in ipairs(GetAreaPOIForMap(mapId)) do
			local areaPOIInfo = GetAreaPOIInfo(mapId, areaPOIId)
			local name = areaPOIInfo.name
			local textureIndex = areaPOIInfo.textureIndex
			if name and textureIndex then
				local curState = getPoiState(textureIndex)
				if curState and getPoiState(v) ~= curState then
					POITimer:Stop(name)
					if curState > 2 then
						POITimer:Start(nil, name)
						if curState == 3 then
							POITimer:SetColor(0, 0, 1, name)
							POITimer:UpdateIcon("Interface\\AddOns\\DBM-PvP\\Textures\\GuardTower", name)
						else
							POITimer:SetColor(1, 0, 0, name)
							POITimer:UpdateIcon("Interface\\AddOns\\DBM-PvP\\Textures\\OrcTower", name)
						end
					end
					if k == 13 then
						timerSiegeEngine:Cancel()
						warnSiegeEngineSoon:Cancel()
					end
				end
				poi[k] = textureIndex
			end
		end
	end

	local function scheduleCheck(self)
		self:Schedule(1, checkForUpdates)
	end
	mod.CHAT_MSG_BG_SYSTEM_ALLIANCE = scheduleCheck
	mod.CHAT_MSG_BG_SYSTEM_HORDE = scheduleCheck
	mod.CHAT_MSG_RAID_BOSS_EMOTE = scheduleCheck

	function mod:CHAT_MSG_MONSTER_YELL(msg)
		if msg == L.GoblinStartAlliance or msg == L.GoblinBrokenAlliance or msg:find(L.GoblinStartAlliance) or msg:find(L.GoblinBrokenAlliance) then
			self:SendSync("SEStart", "Alliance")
		elseif msg == L.GoblinStartHorde or msg == L.GoblinBrokenHorde or msg:find(L.GoblinStartHorde) or msg:find(L.GoblinBrokenHorde) then
			self:SendSync("SEStart", "Horde")
		elseif msg == L.GoblinHalfwayAlliance or msg:find(L.GoblinHalfwayAlliance) then
			self:SendSync("SEHalfway", "Alliance")
		elseif msg == L.GoblinHalfwayHorde or msg:find(L.GoblinHalfwayHorde) then
			self:SendSync("SEHalfway", "Horde")
		elseif msg == L.GoblinFinishedAlliance or msg:find(L.GoblinFinishedAlliance) then
			self:SendSync("SEFinish", "Alliance")
		elseif msg == L.GoblinFinishedHorde or msg:find(L.GoblinFinishedHorde) then
			self:SendSync("SEFinish", "Horde")
		else
			checkForUpdates()
		end
	end
end

function mod:UNIT_DIED(args)
	local cid = self:GetCIDFromGUID(args.destGUID)
	if cid == 34476 then
		self:SendSync("SEBroken", "Alliance")
	elseif cid == 35069 then
		self:SendSync("SEBroken", "Horde")
	end
end

--[[
function mod:SPELL_BUILDING_DAMAGE(sourceGUID, _, _, _, destGUID, destName, _, _, _, _, _, amount)
	if sourceGUID == nil or destName == nil or destGUID == nil or amount == nil or not bgzone then
		return
	end
	local guid = destGUID
	if gateHP[guid] == nil then -- first hit
		gateHP[guid] = 600000 -- initial gate health: 600000
		if self.Options.ShowGatesHealth then
			if not DBM.InfoFrame:IsShown() then
				DBM.InfoFrame:Show(7, "function", updateInfoFrame, false, false, true)
			else
				DBM.InfoFrame:Update()
			end
		end
	end
	if gateHP[guid] > amount then
		gateHP[guid] = gateHP[guid] - amount
	else
		gateHP[guid] = 0
	end
	if self.Options.ShowGatesHealth then
		DBM.InfoFrame:Update()
	end
end
--]]

function mod:OnSync(msg, arg)
	if msg == "SEStart" then
		timerSiegeEngine:Start(178)
		warnSiegeEngineSoon:Schedule(168)
		if arg == "Alliance" then
			timerSiegeEngine:SetColor(allyColor)
		elseif arg == "Horde" then
			timerSiegeEngine:SetColor(hordeColor)
		end
	elseif msg == "SEHalfway" then
		warnSiegeEngineSoon:Cancel()
		timerSiegeEngine:Start(89)
		warnSiegeEngineSoon:Schedule(79)
		if arg == "Alliance" then
			timerSiegeEngine:SetColor(allyColor)
		elseif arg == "Horde" then
			timerSiegeEngine:SetColor(hordeColor)
		end
	elseif msg == "SEFinish" then
		warnSiegeEngineSoon:Cancel()
		timerSiegeEngine:Cancel()
		warnSiegeEngine:Show()
	end
end