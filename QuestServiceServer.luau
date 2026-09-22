-- Discord: codaa1 | Roblox: Codaskii

--Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")

--Modules
local Packets = require(ReplicatedStorage.Packages.Packets)
local QuestConfig = require(ReplicatedStorage.Configs.QuestConfig)
local QuestClass = require(ServerScriptService.Classes.Quest)
local DataService = require(ReplicatedStorage.Shared.Services.DataService).server
local RoundService = require(ServerScriptService.Services.RoundService.RoundServiceServer)

--Variables
local QuestEvent = Packets.QuestEvent
local RoundEndSignal = RoundService.EndRoundSignal

local PlayersQuests: {[Player]: {[string]: any}} = {}

local QuestServiceServer = {}

--Functions

-- every quest gets a unique id so it can be found in data by id
local function GenerateQuestId()
	return HttpService:GenerateGUID(false)
end


-- pulls the player's saved quests out of the datastore
local function LoadQuests(Player: Player): {}
	local Quests = {}
	local PlayerData = DataService:get(Player, {"Quests"})
	for i, Quest in pairs(PlayerData) do
		table.insert(Quests, Quest)
	end

	return Quests
end


-- turns the saved tables back into Quest objects
local function DeserializeQuests(Quests: {}, Player: Player)
	for i, Quest in pairs(Quests) do
		PlayersQuests[Player][Quest.QuestId] = QuestClass.Deserialize(Quest)
	end
end


-- data stores quests as an array, so we need the index to edit or remove one by its id
local function GetQuestIndex(Player: Player, QuestId: string)
	local PlayerData = DataService:get(Player, {"Quests"})
	for i, QuestData in ipairs(PlayerData) do
		if QuestData.QuestId == QuestId then
			return i
		end
	end

	return nil
end


local function HasQuest(Player: Player, QuestName: string): boolean
	for i, Quest in PlayersQuests[Player] do
		if Quest.QuestName == QuestName then
			return true
		end
	end

	return false
end


local function SetupPlayer(Player: Player)
	-- table is created first so other code never finds it missing while data loads
	PlayersQuests[Player] = {}
	DataService:waitForData(Player)

	-- player might have left while their data was loading
	if not PlayersQuests[Player] then return end

	DeserializeQuests(LoadQuests(Player), Player)
end


-- every winner gets progress on their WinRound quests
local function OnRoundEnded(Winners: {Player})
	for i, Player in Winners do
		local Quests = PlayersQuests[Player]
		if not Quests then continue end

		for QuestId, Quest in Quests do
			if Quest.QuestType == "WinRound" then
				QuestServiceServer:AddProgress(Player, 1, Quest)
			end
		end
	end
end


--Methods
function QuestServiceServer.Init()

	Players.PlayerAdded:Connect(SetupPlayer)

	-- players who joined before Init ran
	for i, Player in Players:GetPlayers() do
		task.spawn(SetupPlayer, Player)
	end

	Players.PlayerRemoving:Connect(function(Player)
		PlayersQuests[Player] = nil
	end)

	-- client sends the quest name, the server looks up the real quest data from the config
	QuestEvent.OnServerInvoke = function(Player: Player, QuestName: string)
		local QuestData = QuestConfig.Quests[QuestName]
		if not QuestData then return false end

		return QuestServiceServer:AssignQuest(Player, QuestData)
	end

	RoundEndSignal:Connect(OnRoundEnded)

end


function QuestServiceServer:AssignQuest(Player: Player, QuestData)
	if not Player or not PlayersQuests[Player] then return false end

	-- only one of each quest at a time
	if HasQuest(Player, QuestData.QuestName) then return false end

	local NewQuest = QuestClass.New(Player.UserId, QuestData.QuestName, QuestData.QuestType, QuestData.RewardType, QuestData.Reward, QuestData.Goal, GenerateQuestId())
	PlayersQuests[Player][NewQuest.QuestId] = NewQuest
	DataService:arrayInsert(Player, {"Quests"}, NewQuest:Serialize())

	return true
end


function QuestServiceServer:AddProgress(Player: Player, Amount: number, Quest)
	local QuestIndex = GetQuestIndex(Player, Quest.QuestId)
	if not QuestIndex then return false end

	if Quest:AddProgress(Amount) then
		DataService:set(Player, {"Quests", QuestIndex, "Progress"}, Quest.Progress)
	end

	-- quests are claimed automatically as soon as they're done
	if Quest.Progress >= Quest.Goal then
		QuestServiceServer:ClaimQuest(Player, Quest)
	end
end


function QuestServiceServer:ClaimQuest(Player: Player, Quest)
	local QuestIndex = GetQuestIndex(Player, Quest.QuestId)
	if not QuestIndex then return false end

	local Rewarded = Quest:Claim(Player)
	if not Rewarded then return false end

	QuestServiceServer:DeleteQuest(Player, Quest.QuestId)

	return true
end


function QuestServiceServer:DeleteQuest(Player: Player, QuestId: string)
	local Index = GetQuestIndex(Player, QuestId)
	if not Index then return false end

	local Quests = PlayersQuests[Player]
	if Quests and Quests[QuestId] then
		Quests[QuestId]:Remove()
		Quests[QuestId] = nil
	end

	DataService:arrayRemove(Player, {"Quests"}, Index)

	return true
end



return QuestServiceServer
