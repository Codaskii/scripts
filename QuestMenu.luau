-- Discord: codaa1 | Roblox: Codaskii

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

--Modules
local DataService = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Services"):WaitForChild("DataService")).client
DataService:init()
DataService:waitForData()

--Variables
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer.PlayerGui
local QuestUI: ScreenGui = PlayerGui:WaitForChild("QuestsUI")
local QuestsFrame: Frame = QuestUI:WaitForChild("QuestsFrame")
local VisualContainer: Frame = QuestsFrame:WaitForChild("VisualContainer")
VisualContainer.Size = UDim2.new(0, 0, 0, 0)

local QuestTemplate: Frame = VisualContainer:WaitForChild("QuestTemplate")
local QuestContainer: ScrollingFrame = VisualContainer:WaitForChild("QuestContainer")

local UISounds = SoundService:WaitForChild("UI")
local ToggleSound = UISounds:WaitForChild("ToggleSound")

local IsTweening = false

local QuestMenu = {}

--Functions

-- quest frames are named after the quest id so they can be found directly
local function GetQuestFrameById(QuestId: string): Frame?
	if not QuestId then return nil end
	return QuestContainer:FindFirstChild(QuestId)
end


local function GetProgressPercent(Quest: {}): number
	if Quest.Goal <= 0 then return 0 end
	return math.clamp(Quest.Progress / Quest.Goal, 0, 1)
end


-- same texts are used for new and updated frames, so they're set in one place
local function SetQuestTexts(QuestFrame: Frame, Quest: {})
	QuestFrame.QuestName.Text = Quest.QuestName
	QuestFrame.Reward.Text = "Reward: " .. tostring(Quest.Reward) .. " " .. Quest.RewardType .. "s"
	QuestFrame.ProgressText.Text = tostring(Quest.Progress) .. "/" .. tostring(Quest.Goal)
end


local function AddQuestFrame(Quest: {})
	if not Quest then return end
	if GetQuestFrameById(Quest.QuestId) then return end

	local QuestFrame = QuestTemplate:Clone()
	QuestFrame.Name = Quest.QuestId
	QuestFrame.Parent = QuestContainer
	QuestFrame.Visible = true
	SetQuestTexts(QuestFrame, Quest)

	local EmptyBar: Frame = QuestFrame:FindFirstChild("EmptyBar")
	local FillBar: Frame = EmptyBar:FindFirstChild("FillBar")

	-- anchored to the left so the bar fills from left to right
	FillBar.AnchorPoint = Vector2.new(0, 0)
	FillBar.Position = UDim2.new(0, 0, 0, 0)
	FillBar.Size = UDim2.new(GetProgressPercent(Quest), 0, 1, 0)
end


local function UpdateQuestFrame(Quest: {})
	if not Quest or not Quest.QuestId then return end

	local QuestFrame = GetQuestFrameById(Quest.QuestId)
	if not QuestFrame then AddQuestFrame(Quest) return end

	SetQuestTexts(QuestFrame, Quest)

	local EmptyBar = QuestFrame:FindFirstChild("EmptyBar")
	local FillBar = EmptyBar and EmptyBar:FindFirstChild("FillBar")
	if not FillBar then return end

	-- tween instead of snapping so the player sees the progress go up
	TweenService:Create(FillBar, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = UDim2.new(GetProgressPercent(Quest), 0, 1, 0)}):Play()
end


local function UpdateQuestFrames()
	local Quests = DataService:get({"Quests"})
	if not Quests then return end

	for _, Quest in ipairs(Quests) do
		UpdateQuestFrame(Quest)
	end
end

--Methods

function QuestMenu.Init()
	QuestMenu:LoadQuests()

	DataService:getArrayInsertedSignal({"Quests"}):Connect(function(i, Quest)
		AddQuestFrame(Quest)
	end)

	DataService:getArrayRemovedSignal({"Quests"}):Connect(function(i, Quest)
		if not Quest then return end

		local Frame = GetQuestFrameById(Quest.QuestId)
		if Frame then
			Frame:Destroy()
		end
	end)

	DataService:getChangedSignal({"Quests"}):Connect(function()
		UpdateQuestFrames()
	end)

end



function QuestMenu:ToggleVisibility()
	if IsTweening then return end

	if not VisualContainer.Visible then
		VisualContainer.Visible = true
		IsTweening = true
		QuestsFrame.Interactable = true
		local Tween: Tween = TweenService:Create(VisualContainer, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Size = UDim2.new(1, 0, 1, 0)})
		Tween:Play()

		Tween.Completed:Connect(function()
			IsTweening = false
		end)

	else
		IsTweening = true
		local Tween: Tween = TweenService:Create(VisualContainer, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Size = UDim2.new(0, 0, 0, 0)})
		Tween:Play()

		-- only hide it after the close animation is done
		Tween.Completed:Connect(function()
			VisualContainer.Visible = false
			QuestsFrame.Interactable = false
			IsTweening = false
		end)
	end

	ToggleSound:Play()
end


-- adds a frame for every quest the player already has when they join
function QuestMenu:LoadQuests()
	local PlayersQuests = DataService:get({"Quests"})
	for i, Quest in pairs(PlayersQuests) do
		AddQuestFrame(Quest)
	end
end

return QuestMenu
