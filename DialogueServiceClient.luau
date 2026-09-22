-- Discord: codaa1 | Roblox: Codaskii

--Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")

--Modules
local Packets = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Packets"))
local DialogueConfig = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("DialogueConfig"))

type DialogueData = DialogueConfig.DialogueData
type DialogueOption = DialogueConfig.DialogueOption

--Variables
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer.PlayerGui

-- WaitForChild returns Instance, so we cast to the type we know it is
local DialogueUI = PlayerGui:WaitForChild("DialogueUI") :: ScreenGui
local MainFrame = DialogueUI:WaitForChild("MainFrame") :: Frame
local DialogueText = MainFrame:WaitForChild("DialogueText") :: TextLabel
local NpcNameText = MainFrame:WaitForChild("NpcName") :: TextLabel

local LeaveFrame = MainFrame:WaitForChild("LeaveFrame") :: Frame
local LeaveTextButton = LeaveFrame:WaitForChild("TextButton") :: TextButton

local OptionContainer = MainFrame:WaitForChild("OptionContainer") :: Frame
local OptionTemplate = MainFrame:WaitForChild("Option1Frame") :: Frame
OptionTemplate.Visible = false

local QuestEvent = Packets.QuestEvent
local DialoguePrompts: {ProximityPrompt} = {}

local DialogueServiceClient = {}

--Functions

-- every character plays its own clone so fast typing doesn't cut the sound off
local function PlayTextSound(Sound: Sound)
	local SoundClone = Sound:Clone()
	SoundClone.Parent = SoundService.Dump
	SoundClone:Play()
	-- TimeLength is 0 if the sound hasn't loaded yet, so keep it for at least a second
	Debris:AddItem(SoundClone, math.max(SoundClone.TimeLength, 1))
end


-- the prompt stores which npc it belongs to as an attribute
local function GetDialogueData(ProximityPrompt: ProximityPrompt): DialogueData?
	local DialogueName = ProximityPrompt:GetAttribute("DialogueData")
	if not DialogueName then return nil end

	return DialogueConfig.Dialogues[DialogueName]
end


-- prompts are turned off during a dialogue so you can't start a second one
local function SetProximityPrompts(Enabled: boolean)
	for i, ProximityPrompt in DialoguePrompts do
		ProximityPrompt.Enabled = Enabled
	end
end


local function OnPromptTriggered(self: DialogueServiceClient, ProximityPrompt: ProximityPrompt)
	local Npc = GetDialogueData(ProximityPrompt)
	if not Npc then return end

	DialogueServiceClient.PlayDialogue(self, Npc)
end


--Methods
function DialogueServiceClient.Init(self: DialogueServiceClient)
	self.DialogueStatus = "Ready"
	self.OptionButtons = {}
	self.CurrentNpc = nil
	self.TypingId = 0

	LeaveTextButton.Activated:Connect(function()
		DialogueServiceClient.EndDialogue(self)
	end)

	-- the tag could end up on something else by mistake, so only keep actual prompts
	for i, Object in CollectionService:GetTagged("Dialogue") do
		if not Object:IsA("ProximityPrompt") then continue end

		table.insert(DialoguePrompts, Object)
		Object.Triggered:Connect(function()
			OnPromptTriggered(self, Object)
		end)
	end

end


function DialogueServiceClient.ClearOptions(self: DialogueServiceClient)
	for i, Button in self.OptionButtons do
		Button.Parent:Destroy()
	end

	table.clear(self.OptionButtons)
end


function DialogueServiceClient.ShowOptions(self: DialogueServiceClient, Options: {DialogueOption})
	DialogueServiceClient.ClearOptions(self)

	for i, OptionData in Options do
		local NewFrame = OptionTemplate:Clone()
		NewFrame.Name = "Option" .. i .. "Frame"
		NewFrame.LayoutOrder = i
		NewFrame.Visible = true
		NewFrame.Parent = OptionContainer

		local Button = NewFrame:WaitForChild("TextButton") :: TextButton
		Button.Text = OptionData.Text

		Button.Activated:Connect(function()
			DialogueServiceClient.SelectOption(self, OptionData)
		end)

		table.insert(self.OptionButtons, Button)
	end
end


function DialogueServiceClient.SelectOption(self: DialogueServiceClient, OptionData: DialogueOption)
	if OptionData.Next then
		DialogueServiceClient.PlayNode(self, OptionData.Next)
	else
		DialogueServiceClient.EndDialogue(self)
	end
end


function DialogueServiceClient.PlayDialogue(self: DialogueServiceClient, Npc: DialogueData)
	if self.DialogueStatus == "Playing" then return end
	self.DialogueStatus = "Playing"
	SetProximityPrompts(false)

	self.CurrentNpc = Npc
	NpcNameText.Text = Npc.DisplayName
	MainFrame.Visible = true

	DialogueServiceClient.PlayNode(self, Npc.StartNode)
end


function DialogueServiceClient.PlayNode(self: DialogueServiceClient, NodeId: string)
	DialogueServiceClient.ClearOptions(self)

	local Npc = self.CurrentNpc
	if not Npc then return end

	-- a typo in the config shouldn't leave the player stuck in the dialogue
	local Node = Npc.Nodes[NodeId]
	if not Node then DialogueServiceClient.EndDialogue(self) return end

	local Text = Node.Text

	-- ask the server first so the npc can say something else if we already have the quest
	if Node.Quest then
		local Success = QuestEvent:Fire(Node.Quest)
		if not Success then
			Text = "You already have that quest."
		end
	end

	DialogueServiceClient.TypeText(self, Text, Npc.TextSound, Node.Options, Node.Close == true)
end


function DialogueServiceClient.TypeText(self: DialogueServiceClient, Text: string, TextSound: Sound, Options: {DialogueOption}, CloseAfter: boolean)
	-- every new line gets a new id, the old typing loop stops when it sees the id changed
	self.TypingId += 1
	local ThisTypingId = self.TypingId

	DialogueText.Text = ""

	task.spawn(function()
		local CharCount = utf8.len(Text) or #Text

		for i = 1, CharCount do
			if self.TypingId ~= ThisTypingId then return end

			-- utf8.offset so characters like emojis don't get cut in half
			local ByteOffset = utf8.offset(Text, i + 1)
			DialogueText.Text = if ByteOffset then string.sub(Text, 1, ByteOffset - 1) else Text

			PlayTextSound(TextSound)
			task.wait(DialogueConfig.Settings.TypeSpeed)
		end

		if self.TypingId ~= ThisTypingId then return end

		LeaveFrame.Visible = true
		DialogueServiceClient.ShowOptions(self, Options)

		if CloseAfter then
			task.delay(2, function()
				-- don't close if the player already left or started another dialogue
				if self.TypingId ~= ThisTypingId then return end
				DialogueServiceClient.EndDialogue(self)
			end)
		end
	end)
end


function DialogueServiceClient.EndDialogue(self: DialogueServiceClient)
	-- bumping the id stops any typing that's still running
	self.TypingId += 1

	SetProximityPrompts(true)
	self.DialogueStatus = "Ready"
	MainFrame.Visible = false
	DialogueText.Text = ""
	self.CurrentNpc = nil
	LeaveFrame.Visible = false
	DialogueServiceClient.ClearOptions(self)
end

--Types
export type DialogueStatus = "Playing" | "Ready"

type DialogueServiceClient = typeof(DialogueServiceClient) & {
	DialogueStatus: DialogueStatus,
	OptionButtons: {TextButton},
	CurrentNpc: DialogueData?,
	TypingId: number,
}

return DialogueServiceClient
