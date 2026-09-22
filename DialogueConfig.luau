-- Discord: codaa1 | Roblox: Codaskii

--Services
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--Modules
local QuestConfig = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("QuestConfig"))

--Variables
local DialogueSounds = SoundService:WaitForChild("DialogueSounds")
local Quests = QuestConfig.Quests

--Types
export type DialogueOption = {
	Text: string,
	Next: string?, -- no Next means this option ends the dialogue
}

export type DialogueNode = {
	Text: string,
	Options: {DialogueOption},
	Close: boolean?, -- closes the dialogue a moment after the text finishes
	Quest: string?, -- quest name from QuestConfig, given when this node plays
}

export type DialogueData = {
	DisplayName: string,
	TextSound: Sound,
	StartNode: string,
	Nodes: {[string]: DialogueNode},
}

export type SettingsData = {
	TypeSpeed: number,
	MaxDistance: number,
}

--Config
-- annotated instead of cast so the type checker warns if a field is missing or wrong
local Settings: SettingsData = {
	TypeSpeed = 0.03,
	MaxDistance = 12,
}

local Dialogues: {[string]: DialogueData} = {
	["Coda"] = {
		DisplayName = "Coda",
		TextSound = DialogueSounds:WaitForChild("Coda") :: Sound,
		StartNode = "Start",
		Nodes = {
			["Start"] = {
				Text = "Hello there! How can I help you?",
				Options = {
					{Text = "Quest", Next = "QuestInfo"},
				},
			},

			["QuestInfo"] = {
				Text = "I need you to Win 3 Rounds",
				Options = {
					{Text = "Accept", Next = "Accepted"},
					{Text = "What will I get afterwards?", Next = "RewardInfo"},
				},
			},

			["RewardInfo"] = {
				-- read from the quest config so this text never gets out of date
				Text = "You will get " .. tostring(Quests["Win 3 Rounds"].Reward) .. " Coins.",
				Options = {
					{Text = "Accept", Next = "Accepted"},
				},
			},

			["Accepted"] = {
				Text = "Good luck!",
				Options = {},
				Close = true,
				Quest = "Win 3 Rounds",
			},
		},
	},


	["Dummy"] = {
		DisplayName = "Dummy",
		TextSound = DialogueSounds:WaitForChild("Dummy") :: Sound,
		StartNode = "Start",
		Nodes = {
			["Start"] = {
				Text = "hey",
				Options = {
					{Text = "hello", Next = "hey"},
				},
			},

			["hey"] = {
				Text = "bye",
				Options = {},
				Close = true,
			},
		},
	},
}

local DialogueConfig = {}
DialogueConfig.Settings = Settings
DialogueConfig.Dialogues = Dialogues

return DialogueConfig
