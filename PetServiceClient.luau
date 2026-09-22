-- Discord: codaa1 | Roblox: Codaskii

--Services--
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--Modules--
local Packets = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Packets"))
local TroveModule = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))

--Variables--
local LocalPlayer = Players.LocalPlayer
local FollowingPetsFolder = workspace:WaitForChild("FollowingPets") :: Folder
local PetFollowEvent = Packets.PetFollow
local PetAction = Packets.PetAction

local PetServiceClient = {}
local ActivePets = {}
local PlayerSlotOrder = {}
local ShowOtherPets = true -- controlled from the settings menu

--slot config
local MAX_SLOTS = 6
local SLOT_OFFSETS = {
	[1] = Vector3.new(-6, 0, 5),
	[2] = Vector3.new(0, 0, 5),
	[3] = Vector3.new(6, 0, 5),
	[4] = Vector3.new(-6, 0, 10),
	[5] = Vector3.new(0, 0, 10),
	[6] = Vector3.new(6, 0, 10),
}

--follow and bobbing config
local FOLLOW_LERP_SPEED = 12
local BOB_SPEED = 2.5
local BOB_HEIGHT = 0.4

-- extra rotation for pets whose models were imported facing the wrong way
-- e.g. ["Hacker 1x1x1x1"] = Vector3.new(-90, 0, 0)
local PET_ROTATION_FIX: {[string]: Vector3} = {}

-- pets that look too big or small at the default scale
local PET_SCALE_OVERRIDE: {[string]: number} = {
	["Hacker 1x1x1x1"] = 0.7,
}


--Functions--
local function GetPlayer(UserId: number): Player?
	return Players:GetPlayerByUserId(UserId)
end


-- hides/shows a pet without destroying it, so the trove and follow loop keep running
local function SetPetVisible(PetModel: Model, Visible: boolean)
	for _, Object in ipairs(PetModel:GetDescendants()) do
		if Object:IsA("BasePart") then
			Object.LocalTransparencyModifier = if Visible then 0 else 1

		elseif Object:IsA("Decal") or Object:IsA("Texture") then
			Object.LocalTransparencyModifier = if Visible then 0 else 1

		elseif Object:IsA("ParticleEmitter") or Object:IsA("Trail") or Object:IsA("Beam") then
			Object.Enabled = Visible

		elseif Object:IsA("BillboardGui") or Object:IsA("SurfaceGui") then
			Object.Enabled = Visible
		end
	end
end


-- your own pets are always visible, other players' pets depend on the setting
local function RefreshPetVisibility(Player: Player, PetModel: Model)
	local ShouldShow = (Player == LocalPlayer) or ShowOtherPets
	SetPetVisible(PetModel, ShouldShow)
end


local function ConfigurePetModel(PetModel: Model, PetName: string)
	PetModel:ScaleTo(PET_SCALE_OVERRIDE[PetName] or 0.4)

	-- pets are decoration only, so they never collide with or block anything
	for _, Object in ipairs(PetModel:GetDescendants()) do
		if Object:IsA("BasePart") then
			Object.Anchored = true
			Object.CanCollide = false
			Object.CanTouch = false
			Object.CanQuery = false
		end
	end

	PetModel.Parent = FollowingPetsFolder
end


local function SetupPetModel(PetModel: Model)
	local Pet = PetModel:Clone()
	ConfigurePetModel(Pet, PetModel.Name)

	return Pet
end


-- slot index decides which offset a pet follows at, so it's rebuilt whenever the order changes
local function RefreshSlots(Player: Player)
	local Order = PlayerSlotOrder[Player]
	local PlayerPets = ActivePets[Player]
	if not Order or not PlayerPets then return end

	for Index, PetId in ipairs(Order) do
		local PetData = PlayerPets[PetId]
		if PetData then
			PetData.SlotIndex = Index
		end
	end
end


local function StartFollowing(PetModel: Model, Player: Player, Data: {})
	-- random phase so pets in different slots don't bob in sync
	Data.BobOffset = math.random() * math.pi * 2

	-- the rotation fix is worked out once here instead of every frame
	local Fix = PET_ROTATION_FIX[PetModel.Name]
	local BaseRotation = CFrame.Angles(math.rad(90), 0, 0)
	if Fix then
		BaseRotation = BaseRotation * CFrame.Angles(math.rad(Fix.X), math.rad(Fix.Y), math.rad(Fix.Z))
	end

	local Initialized = false

	-- if the character is already loaded, place the pet right away
	local StartRoot = Player.Character and Player.Character.PrimaryPart
	if StartRoot then
		PetModel:PivotTo(StartRoot.CFrame)
		Initialized = true
	end

	return RunService.Heartbeat:Connect(function(DeltaTime)
		local Character = Player.Character
		local Root = Character and Character.PrimaryPart
		if not Root then
			Initialized = false -- reset so the pet snaps back after a respawn
			return
		end

		local SlotIndex = Data.SlotIndex or 1
		local Offset = SLOT_OFFSETS[SlotIndex] or SLOT_OFFSETS[MAX_SLOTS]

		-- offset is applied in the character's own space, so pets turn with the player
		local TargetCFrame = Root.CFrame * CFrame.new(Offset)

		local BobY = math.sin(os.clock() * BOB_SPEED + Data.BobOffset) * BOB_HEIGHT
		TargetCFrame = TargetCFrame * CFrame.new(0, BobY, 0) * BaseRotation

		if not Initialized then
			PetModel:PivotTo(TargetCFrame) -- teleport on the first valid frame instead of lerping from far away
			Initialized = true
			return
		end

		-- DeltaTime in the alpha keeps the follow speed the same on any frame rate
		local Alpha = math.clamp(DeltaTime * FOLLOW_LERP_SPEED, 0, 1)
		PetModel:PivotTo(PetModel:GetPivot():Lerp(TargetCFrame, Alpha))
	end)
end


--Methods--

-- called from settings, true = other players' pets are visible
function PetServiceClient:SetShowOtherPets(Show: boolean)
	if ShowOtherPets == Show then return end
	ShowOtherPets = Show

	for Player, PlayerPets in pairs(ActivePets) do
		for _, PetData in pairs(PlayerPets) do
			if PetData.Model and PetData.Model.Parent then
				RefreshPetVisibility(Player, PetData.Model)
			end
		end
	end
end


function PetServiceClient.Init()

	-- players who were already here before this ran
	for _, Player in Players:GetPlayers() do
		ActivePets[Player] = {}
		PlayerSlotOrder[Player] = {}
	end


	PetFollowEvent.OnClientEvent:Connect(function(Data: {})
		local Player = GetPlayer(Data.UserId)
		if not Player then return end

		if not ActivePets[Player] then
			ActivePets[Player] = {}
		end

		if not PlayerSlotOrder[Player] then
			PlayerSlotOrder[Player] = {}
		end


		if Data.Type == "Equip" then
			-- an old model for this pet id would be left behind otherwise
			local ExistingPetData = ActivePets[Player][Data.PetId]
			if ExistingPetData and ExistingPetData.Trove then
				ExistingPetData.Trove:Destroy()
			end

			local Order = PlayerSlotOrder[Player]
			if not table.find(Order, Data.PetId) and #Order < MAX_SLOTS then
				table.insert(Order, Data.PetId)
			end

			local Pet = SetupPetModel(Data.Model)
			local NewTrove = TroveModule.new()

			-- the trove holds the model and the heartbeat connection, so one Destroy cleans up both
			NewTrove:Add(Pet)
			Data.Model = Pet

			NewTrove:Add(StartFollowing(Pet, Player, Data))

			Data.Trove = NewTrove
			ActivePets[Player][Data.PetId] = Data

			RefreshPetVisibility(Player, Pet) -- new pets follow the current setting too

			RefreshSlots(Player)


		elseif Data.Type == "Unequip" then
			local PetData = ActivePets[Player][Data.PetId]

			if PetData and PetData.Trove then
				PetData.Trove:Destroy()
			end

			ActivePets[Player][Data.PetId] = nil

			local Order = PlayerSlotOrder[Player]
			local Index = table.find(Order, Data.PetId)
			if Index then
				table.remove(Order, Index)
			end

			-- removing a pet shifts every pet behind it up one slot
			RefreshSlots(Player)
		end
	end)


	Players.PlayerAdded:Connect(function(Player)
		ActivePets[Player] = {}
		PlayerSlotOrder[Player] = {}
	end)


	Players.PlayerRemoving:Connect(function(Player)
		-- destroy the leaving player's pets here, the server's Unequip can't reach them anymore
		local PlayerPets = ActivePets[Player]
		if PlayerPets then
			for _, PetData in pairs(PlayerPets) do
				if PetData.Trove then
					PetData.Trove:Destroy()
				end
			end
		end

		ActivePets[Player] = nil
		PlayerSlotOrder[Player] = nil
	end)


	-- ask the server for pets that were equipped before we joined
	task.spawn(function()
		PetAction:Fire("RequestSync")
	end)

end


return PetServiceClient
