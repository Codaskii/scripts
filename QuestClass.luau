-- Discord: codaa1 | Roblox: Codaskii

--Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--Modules
local Trove = require(ReplicatedStorage.Packages.Trove)


--Class
local Quest = {}
Quest.__index = Quest


--Methods
function Quest.New(PlayerId: number, QuestName: string, QuestType: "WinRound", RewardType: "Coin", Reward: number, Goal: number, QuestId: string)
	local self = setmetatable({}, Quest)
	self.PlayerId = PlayerId
	self.QuestName = QuestName
	self.QuestType = QuestType
	self.RewardType = RewardType
	self.Reward = Reward
	self.Progress = 0
	self.Goal = Goal
	self.Completed = false
	self.Claimed = false
	self.QuestId = QuestId
	self.Trove = Trove.new()

	return self
end


-- returns false if the quest is already done, so the service knows not to save anything
function Quest:AddProgress(Amount: number)
	if self.Completed then return false end

	self.Progress += Amount

	-- cap progress at the goal so the UI never shows something like 4/3
	if self.Progress >= self.Goal then
		self.Completed = true
		self.Progress = self.Goal
	end

	return true
end


function Quest:Claim(Player: Player)
	if not self.Completed or self.Claimed then return false end

	-- only mark it as claimed once the reward actually went through
	if not self:RewardPlayer(Player) then return false end

	self.Claimed = true
	return true
end


function Quest:RewardPlayer(Player: Player)
	local Leaderstats: Folder = Player:FindFirstChild("leaderstats")
	if not Leaderstats then return false end

	local Coins: NumberValue = Leaderstats:FindFirstChild("Coins")
	if not Coins then return false end

	if self.RewardType == "Coin" then
		Coins.Value += self.Reward
	end

	return true
end


-- turns the quest into a plain table so it can be saved to the datastore
function Quest:Serialize()
	return {
		PlayerId = self.PlayerId,
		QuestName = self.QuestName,
		QuestType = self.QuestType,
		RewardType = self.RewardType,
		Reward = self.Reward,
		Progress = self.Progress,
		Goal = self.Goal,
		QuestId = self.QuestId,
	}
end

-- rebuilds the quest object from saved datastore data
function Quest.Deserialize(Data)
	local NewQuest = Quest.New(
		Data.PlayerId,
		Data.QuestName,
		Data.QuestType,
		Data.RewardType,
		Data.Reward,
		Data.Goal,
		Data.QuestId
	)

	NewQuest.Progress = Data.Progress or 0
	NewQuest.Completed = NewQuest.Progress >= NewQuest.Goal

	return NewQuest
end

function Quest:Remove()
	self.Trove:Destroy()
end


return Quest
