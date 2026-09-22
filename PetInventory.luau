-- Discord: codaa1 | Roblox: Codaskii

--Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

--Modules
local Packets = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Packets"))
local PetConfig = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("PetConfig"))
local GamepassConfig = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("GamepassConfig"))
local NotificationService = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Services"):WaitForChild("NotificationService"))
local DataService = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Services"):WaitForChild("DataService")).client
DataService:waitForData()


--Variables
local Player = Players.LocalPlayer
local PlayerStats = Player:WaitForChild("PlayerStats")
local EquipCapacity = PlayerStats:WaitForChild("PetEquipCapacity") :: IntValue
local PetStorage = PlayerStats:WaitForChild("PetStorage") :: IntValue

local MainFrame = Player.PlayerGui:WaitForChild("MainGui"):WaitForChild("Frames"):WaitForChild("Pets") :: Frame
local PetTemplate = MainFrame:WaitForChild("PetTemplate") :: Frame
local InventoryFrame = MainFrame:WaitForChild("PetContainer") :: ScrollingFrame
local ChoosenPetFrame = MainFrame:WaitForChild("ChoosenPetFrame") :: Frame
local EquipButton = ChoosenPetFrame:WaitForChild("Equip") :: ImageButton
local DeleteButton = ChoosenPetFrame:WaitForChild("Delete") :: ImageButton
local StorageText = MainFrame:WaitForChild("StorageText") :: TextLabel
local EquipCapacityText = MainFrame:WaitForChild("EquipCapacity") :: TextLabel
local EquipBestButton = MainFrame:WaitForChild("EquipBest") :: ImageButton
local MultiDeleteButton = MainFrame:WaitForChild("MultiDelete") :: ImageButton
local BuyStorageButton = MainFrame:WaitForChild("BuyStorage") :: ImageButton
local BuyEquipButton = MainFrame:WaitForChild("BuyEquip") :: ImageButton

local PetActionEvent = Packets.PetAction
local RarityColors = PetConfig.RarityColors

local SelectedPetId = nil
local EquippedPetCount: number = 0

-- multi delete mode, EquipBest doubles as the confirm button while it's on
local MultiMode = false
local SelectedForDelete: {[string]: boolean} = {}


-- how EquipBest looks in each mode
local EQUIP_BEST_STYLE = {
	Normal = {
		Text = "Equip Best",
		TextColor = Color3.fromRGB(255, 255, 255),
		Gradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 181, 0)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(85, 255, 0)),
		}),
	},

	Delete = {
		Text = "Delete Pets",
		TextColor = Color3.fromRGB(255, 255, 255),
		Gradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 0, 0)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 60, 60)),
		}),
	},
}

local MULTI_DELETE_STYLE = {
	Normal = { Text = "Multi Delete" },
	Cancel = { Text = "Cancel Delete" },
}


-- the server sends these codes back when an action is refused
local ERROR_TEXT = {
	CantEquip = "Pet Slot Full!",
}

local ERROR_STYLE = { Duration = 0.5, Tween = false, Fade = false, ShowBackground = false, TextSize = 0.5 }


-- shortcut buttons that sell a gamepass straight from the pet menu
local ShortcutButtons = {
	{ Button = BuyStorageButton, Key = "PetStorage100" },
	{ Button = BuyEquipButton, Key = "PetEquip3" },
}


--Functions

-- the server marks owned passes as an attribute, so no purchase check is needed here
local function RefreshShortcutButtons()
	for _, Info in ShortcutButtons do
		Info.Button.Visible = Player:GetAttribute("Gamepass_" .. Info.Key) ~= true
	end
end


-- slots are named after the pet id, so a pet's slot can be found directly
local function GetPetFrameById(PetId: string)
	if PetId == nil then return nil end

	return InventoryFrame:FindFirstChild(PetId)
end


local function UpdateEquipButton(PetFrame: Frame)
	if PetFrame:GetAttribute("Equipped") == true then
		EquipButton.ButtonName.Text = "Unequip"
		EquipButton.BackgroundColor3 = Color3.new(1, 0, 0)

	elseif PetFrame:GetAttribute("Equipped") == false then
		EquipButton.ButtonName.Text = "Equip"
		EquipButton.BackgroundColor3 = Color3.fromRGB(111, 255, 89)
	end
end


-- fills the selected pet panel with the clicked pet's info
local function UpdatePetFrame(PetData: {})
	local PetConfigData = PetConfig.PetsByName[PetData.Name]
	if not PetConfigData then return end

	ChoosenPetFrame.Visible = true
	ChoosenPetFrame.PetName.Text = PetData.Name

	-- boost is read from the config, not from the save, so it's always the current value
	ChoosenPetFrame.ShieldBoost.Text = "x" .. tostring(PetConfigData.ShieldBoost)

	local RarityColor = RarityColors[PetConfigData.Rarity]
	ChoosenPetFrame.PetImage.UIGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, RarityColor),
		ColorSequenceKeypoint.new(1, RarityColor),
	})

	ChoosenPetFrame.PetImage.Icon.Image = PetConfigData.Icon

	SelectedPetId = PetData.Id

	local PetFrame = GetPetFrameById(PetData.Id)
	if PetFrame then
		UpdateEquipButton(PetFrame)
	end
end


-- equipped pets go to the top, the rest are sorted by boost, highest first
local EQUIPPED_PRIORITY = -1_000_000
local PetShieldBoosts = {}

-- LayoutOrder only takes integers, so decimal boosts (1.2, 23.5) are scaled up first
local BOOST_SCALE = 100

local function UpdatePetLayoutOrder(PetSlot: Frame)
	local ShieldBoost = PetShieldBoosts[PetSlot.Name] or 0
	local IsEquipped = PetSlot:GetAttribute("Equipped") == true

	PetSlot.LayoutOrder = (IsEquipped and EQUIPPED_PRIORITY or 0) - math.floor(ShieldBoost * BOOST_SCALE)
end


local function SetEquippedVisual(PetSlot: Frame, Type: string)
	if not PetSlot then return end

	local IsEquipped = Type == "Equip"

	PetSlot.ShadowFrame.Visible = IsEquipped
	PetSlot.UIStroke.Thickness = IsEquipped and 0.025 or 0.010
	PetSlot.UIStroke.Color = IsEquipped and Color3.fromRGB(85, 255, 0) or Color3.new(0, 0, 0)

	-- the attribute is the slot's own record of being equipped, read back by the sort and by multi mode
	PetSlot:SetAttribute("Equipped", IsEquipped)
	UpdatePetLayoutOrder(PetSlot)
end


local function UpdateStatIndicators()
	local Pets = DataService:get({"Pets"})

	StorageText.Text = tostring(#Pets) .. "/" .. tostring(PetStorage.Value)
	EquipCapacityText.Text = tostring(EquippedPetCount) .. "/" .. tostring(EquipCapacity.Value)
end


-- recalculates every slot from the id list the server sent back, instead of tracking each change
local function RefreshAllSlots(EquippedIds: {string})
	EquippedPetCount = 0

	for _, Slot in ipairs(InventoryFrame:GetChildren()) do
		if not Slot:IsA("GuiObject") then continue end

		local IsEquipped = table.find(EquippedIds, Slot.Name) ~= nil
		SetEquippedVisual(Slot, IsEquipped and "Equip" or "Unequip")

		if IsEquipped then
			EquippedPetCount += 1
		end
	end

	-- the selected pet's button may now say the wrong thing
	if SelectedPetId then
		local PetFrame = GetPetFrameById(SelectedPetId)
		if PetFrame then
			UpdateEquipButton(PetFrame)
		end
	end

	UpdateStatIndicators()
end


local function SetSlotSelected(Slot: GuiObject, Selected: boolean)
	local Frame = Slot:FindFirstChild("ChoosedDeleteFrame")
	if Frame and Frame:IsA("GuiObject") then
		Frame.Visible = Selected
	end
end


-- switches every slot and both buttons between normal and multi delete mode
local function RefreshMultiMode()
	for _, Slot in ipairs(InventoryFrame:GetChildren()) do
		if not Slot:IsA("GuiButton") then continue end

		local IsEquipped = Slot:GetAttribute("Equipped") == true

		if MultiMode then
			-- equipped pets can't be picked, so a boost can't disappear by accident
			Slot.Interactable = not IsEquipped
			SetSlotSelected(Slot, SelectedForDelete[Slot.Name] == true)
		else
			Slot.Interactable = true
			SetSlotSelected(Slot, false)
		end
	end

	local EquipStyle = if MultiMode then EQUIP_BEST_STYLE.Delete else EQUIP_BEST_STYLE.Normal

	local EquipBestLabel = EquipBestButton:FindFirstChild("ButtonName", true)
	if EquipBestLabel and EquipBestLabel:IsA("TextLabel") then
		EquipBestLabel.Text = EquipStyle.Text
		EquipBestLabel.TextColor3 = EquipStyle.TextColor
	end

	local EquipGradient = EquipBestButton:FindFirstChildOfClass("UIGradient")
	if EquipGradient then
		EquipGradient.Color = EquipStyle.Gradient
	end

	local MultiLabel = MultiDeleteButton:FindFirstChild("ButtonName", true)
	if MultiLabel and MultiLabel:IsA("TextLabel") then
		MultiLabel.Text = if MultiMode then MULTI_DELETE_STYLE.Cancel.Text else MULTI_DELETE_STYLE.Normal.Text
	end

	-- the single pet panel stays closed while picking pets to delete
	if MultiMode then
		ChoosenPetFrame.Visible = false
	end
end


local function ExitMultiMode()
	MultiMode = false
	table.clear(SelectedForDelete)
	RefreshMultiMode()
end


-- creates the inventory slot for one pet
local function AddFrame(Pet: {})
	if not Pet then return end
	local PetId = Pet.Id

	local PetConfigData = PetConfig.PetsByName[Pet.Name]
	if not PetConfigData then return end

	local PetSlot = PetTemplate:Clone()

	PetSlot.Name = PetId
	PetSlot.PetName.Text = Pet.Name
	PetSlot.Parent = InventoryFrame
	PetSlot.Visible = true
	PetSlot:SetAttribute("Equipped", false)

	PetSlot.Icon.Image = PetConfigData.Icon

	-- centred anchor so a scaled icon grows from the middle instead of the corner
	PetSlot.Icon.AnchorPoint = Vector2.new(0.5, 0.5)
	PetSlot.Icon.Position = UDim2.fromScale(0.5, 0.5)

	-- some icons have a lot of empty space, so the config can scale them up
	local IconScale = PetConfigData.IconScale or 1
	if IconScale ~= 1 then
		local Base = PetSlot.Icon.Size
		PetSlot.Icon.Size = UDim2.new(
			Base.X.Scale * IconScale,
			Base.X.Offset * IconScale,
			Base.Y.Scale * IconScale,
			Base.Y.Offset * IconScale
		)
	end

	-- and some sit off centre inside their image, so the config can nudge them
	local IconOffset = PetConfigData.IconOffset
	if IconOffset then
		PetSlot.Icon.Position = UDim2.fromScale(IconOffset.X, IconOffset.Y)
	end

	if PetConfigData.PetSlotColor then
		PetSlot.UIGradient.Color = PetConfigData.PetSlotColor
	else
		-- no custom gradient in the config, fall back to a flat rarity colour
		local RarityColor = RarityColors[PetConfigData.Rarity]
		PetSlot.UIGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, RarityColor),
			ColorSequenceKeypoint.new(1, RarityColor),
		})
	end

	-- the gradient spin script only runs on pets the config marks for it
	local Rot = PetSlot.UIGradient:FindFirstChild("Rot")
	if Rot and Rot:IsA("BaseScript") then
		Rot.Enabled = PetConfigData.HasRot == true
	end

	-- kept in a table because LayoutOrder is recalculated on every equip change
	PetShieldBoosts[PetId] = tonumber(PetConfigData.ShieldBoost) or 0
	UpdatePetLayoutOrder(PetSlot)

	-- pet was equipped when the player left, show it as equipped
	if Pet.EquippedBeforeLeave == true then
		SetEquippedVisual(PetSlot, "Equip")
		UpdateEquipButton(PetSlot)
		EquippedPetCount += 1
		UpdateStatIndicators()
	end


	PetSlot.MouseButton1Click:Connect(function()
		if MultiMode then
			if PetSlot:GetAttribute("Equipped") == true then return end

			-- storing nil instead of false keeps the table to just the picked pets
			local NowSelected = not SelectedForDelete[PetId]
			SelectedForDelete[PetId] = NowSelected or nil
			SetSlotSelected(PetSlot, NowSelected)
			return
		end

		UpdatePetFrame(Pet)
	end)


	-- a pet added while multi mode is on has to follow the mode too
	if MultiMode then
		PetSlot.Interactable = PetSlot:GetAttribute("Equipped") ~= true
	end

end


local PetInventory = {}


function PetInventory.Init()

	PetInventory:LoadPets()
	UpdateStatIndicators()


	-- fires when the server gives the player a new pet
	DataService:getArrayInsertedSignal({"Pets"}):Connect(function(i, Pet)
		AddFrame(Pet)
		UpdateStatIndicators()
	end)

	DataService:getArrayRemovedSignal({"Pets"}):Connect(function()
		UpdateStatIndicators()
	end)


	EquipButton.MouseButton1Click:Connect(function()
		local Response, EquipType = PetActionEvent:Fire("Equip", SelectedPetId)

		-- the server refused, show why instead of changing the UI
		if not Response then
			local Text = ERROR_TEXT[EquipType]
			if Text then
				NotificationService:Error(Text, ERROR_STYLE)
			end
			return
		end

		local PetFrame = GetPetFrameById(SelectedPetId)
		if not PetFrame then return end

		SetEquippedVisual(PetFrame, EquipType)
		UpdateEquipButton(PetFrame)

		if EquipType == "Equip" then
			EquippedPetCount += 1
		elseif EquipType == "Unequip" then
			EquippedPetCount -= 1
		end

		UpdateStatIndicators()
	end)


	-- the server can also change a pet's equip state on its own
	PetActionEvent.OnClientInvoke = function(PetId, Action, PetIds)
		local PetFrame = GetPetFrameById(PetId)
		if not PetFrame then return false end

		SetEquippedVisual(PetFrame, Action)
		UpdateEquipButton(PetFrame)

		if Action == "Equip" then
			EquippedPetCount += 1
		elseif Action == "Unequip" then
			EquippedPetCount -= 1
		end

		UpdateStatIndicators()
		return true, Action
	end


	DeleteButton.MouseButton1Click:Connect(function()
		local Response = PetActionEvent:Fire("Delete", SelectedPetId)
		if not Response then return end

		local PetFrame = GetPetFrameById(SelectedPetId)
		if PetFrame then
			PetFrame:Destroy()
		end

		ChoosenPetFrame.Visible = false
		PetShieldBoosts[SelectedPetId] = nil
		SelectedPetId = nil
	end)


	EquipBestButton.MouseButton1Click:Connect(function()
		-- in multi mode this same button confirms the deletion instead
		if MultiMode then
			local Ids = {}
			for PetId in SelectedForDelete do
				table.insert(Ids, PetId)
			end

			if #Ids == 0 then
				ExitMultiMode()
				return
			end

			-- the server returns the ids it actually deleted, so nothing is removed on a failure
			local Response, Deleted = PetActionEvent:Fire("DeletePets", Ids)
			if Response and typeof(Deleted) == "table" then
				for _, PetId in ipairs(Deleted) do
					local Slot = InventoryFrame:FindFirstChild(PetId)
					if Slot then
						Slot:Destroy()
					end

					PetShieldBoosts[PetId] = nil

					if SelectedPetId == PetId then
						ChoosenPetFrame.Visible = false
						SelectedPetId = nil
					end
				end
			end

			ExitMultiMode()
			UpdateStatIndicators()
			return
		end

		local Response, EquippedIds = PetActionEvent:Fire("EquipBest")
		if Response and typeof(EquippedIds) == "table" then
			RefreshAllSlots(EquippedIds)
		end
	end)


	MultiDeleteButton.MouseButton1Click:Connect(function()
		if MultiMode then
			ExitMultiMode()
		else
			MultiMode = true
			table.clear(SelectedForDelete)
			RefreshMultiMode()
		end
	end)

	RefreshMultiMode()


	for _, Info in ShortcutButtons do
		local Data = GamepassConfig.Gamepasses[Info.Key]

		Info.Button.MouseButton1Click:Connect(function()
			if Player:GetAttribute("Gamepass_" .. Info.Key) == true then return end

			if Data then
				MarketplaceService:PromptGamePassPurchase(Player, Data.GamepassId)
			end
		end)

		-- the button hides itself the moment the purchase goes through
		Player:GetAttributeChangedSignal("Gamepass_" .. Info.Key):Connect(RefreshShortcutButtons)
	end

	RefreshShortcutButtons()


	-- gamepasses and upgrades can raise these limits while the player is in game
	PetStorage:GetPropertyChangedSignal("Value"):Connect(UpdateStatIndicators)
	EquipCapacity:GetPropertyChangedSignal("Value"):Connect(UpdateStatIndicators)

end


-- adds a slot for every pet the player already has when they join
function PetInventory:LoadPets()
	local PlayersPets = DataService:get({"Pets"})

	for i, Pet in pairs(PlayersPets) do
		AddFrame(Pet)
	end
end


return PetInventory
