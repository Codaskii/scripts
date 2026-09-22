-- Discord: codaa1 | Roblox: Codaskii

--Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")

--Modules
local Packets = require(ReplicatedStorage.Packages.Packets)
local PetClass = require(ServerScriptService.Classes.Pet)
local DataService = require(ReplicatedStorage.Shared.Services.DataService).server

--Variables
local PlayersPets = {} -- [Player] = { [PetId] = Pet object }
local PlayerDataReady = {} -- true once a player's pets are loaded and equipped
local PetActionEvent = Packets.PetAction


--Functions

-- sends every equipped pet in the server to one player (used for late joiners)
local function SyncPetsToPlayer(TargetPlayer: Player)
	for i, Pets in pairs(PlayersPets) do
		for i, Pet in pairs(Pets) do
			Pet:SendTo(TargetPlayer)
		end
	end
end


-- every pet gets a unique id, so two of the same pet are still separate items
local function GeneratePetID()
	return HttpService:GenerateGUID(false)
end


-- pulls the player's saved pets out of the datastore
local function LoadPets(Player: Player): {}
	local Pets = {}
	local PlayerData = DataService:get(Player, {"Pets"})

	for i, Pet in pairs(PlayerData) do
		table.insert(Pets, Pet)
	end

	return Pets
end


-- turns the saved tables back into Pet objects
local function DeserializePets(Pets: {}, Player: Player)
	for i, Pet in pairs(Pets) do
		PlayersPets[Player][Pet.Id] = PetClass.Deserialize(Pet)
	end
end


-- data stores pets as an array, so we need the index to edit or remove one by its id
local function GetPetIndex(Player: Player, PetId: string)
	local PlayerData = DataService:get(Player, {"Pets"})

	for i, PetData in ipairs(PlayerData) do
		if PetData.Id == PetId then
			return i
		end
	end

	return nil
end


-- re-equips whatever the player had on when they left
local function EquipPets(Player: Player)
	for i, Pet in pairs(PlayersPets[Player]) do
		if Pet.EquippedBeforeLeave == true then
			Pet:Equip()
		end
	end
end


-- checks if the player still has room in their pet storage
local function CanClaimPet(Player: Player)
	local PlayerStats = Player:FindFirstChild("PlayerStats")
	if not PlayerStats then return false end

	local PetStorage = PlayerStats:FindFirstChild("PetStorage") :: IntValue?
	if not PetStorage then return false end

	-- counted from data, not from the object table, so it matches what's actually saved
	local PetCount = DataService:get(Player, {"Pets"})

	if #PetCount < PetStorage.Value then return true end

	return false
end


-- checks if the player can equip one more pet
local function CanEquip(Player: Player)
	local PlayerStats = Player:FindFirstChild("PlayerStats")
	if not PlayerStats then return false end

	local EquipCapacity = PlayerStats:FindFirstChild("PetEquipCapacity") :: IntValue?
	if not EquipCapacity then return false end

	local EquippedPetCount = 0

	for i, Pet in pairs(PlayersPets[Player]) do
		if Pet.Equipped then
			EquippedPetCount += 1
		end
	end

	if EquippedPetCount >= EquipCapacity.Value then return false end

	return true
end



local PetServiceServer = {}


function PetServiceServer.Init()

	-- load the player's pets, turn them into objects and re-equip the ones they had on
	Players.PlayerAdded:Connect(function(Player)
		PlayersPets[Player] = {}
		DataService:waitForData(Player)

		-- the stats have to exist before equipping, because the boosts are written onto them
		local PlayerStats = Player:WaitForChild("PlayerStats")
		PlayerStats:WaitForChild("BaseIncome")

		-- the player may have left while their data was loading
		if not PlayersPets[Player] then return end

		DeserializePets(LoadPets(Player), Player)
		EquipPets(Player)

		PlayerDataReady[Player] = true
	end)


	-- cleanup, unequip so other clients remove the pet models and the boosts are dropped
	Players.PlayerRemoving:Connect(function(Player)
		local Pets = PlayersPets[Player]
		if Pets then
			for i, Pet in pairs(Pets) do
				if Pet.Equipped then
					Pet:Unequip()
				end
			end
		end

		PlayersPets[Player] = nil
		PlayerDataReady[Player] = nil
	end)


	-- every pet request from the client comes through here
	-- Payload is a pet id for the single-pet actions and a list of ids for DeletePets
	PetActionEvent.OnServerInvoke = function(Player: Player, ActionType: string, Payload: any)
		local PlayerPets = PlayersPets[Player]
		if not PlayerPets then return false end


		-- client asks for all pets in the server, wait until this player's data is loaded first
		if ActionType == "RequestSync" then
			while not PlayerDataReady[Player] do
				task.wait()
			end

			SyncPetsToPlayer(Player)
			return true, "RequestSync"
		end


		if ActionType == "EquipBest" then
			local Success, EquippedIds = PetServiceServer:EquipBest(Player)
			if not Success then return false end

			return true, EquippedIds
		end


		if ActionType == "DeletePets" then
			local Success, Deleted = PetServiceServer:DeletePets(Player, Payload)
			if not Success then return false end

			return true, Deleted
		end


		-- everything below needs a pet the player actually owns
		local PetId = Payload
		local Pet = PetId and PlayerPets[PetId]
		if not Pet then return false end


		-- Equip / Unequip toggle
		if ActionType == "Equip" then
			-- the capacity check only applies when equipping, taking a pet off is always allowed
			if not Pet.Equipped and not CanEquip(Player) then
				return false, "CantEquip"
			end

			local Action = Pet:Equip()
			if not Action then return false end

			-- save the equip state so it comes back next time they join
			local PetIndex = GetPetIndex(Player, PetId)
			if PetIndex then
				DataService:set(Player, {"Pets", PetIndex, "EquippedBeforeLeave"}, Action == "Equip")
			end

			return true, Action


		-- Delete
		elseif ActionType == "Delete" then
			if not Pet:Delete() then
				return false, "Delete"
			end

			PetServiceServer:DeletePet(Player, PetId)

			return true, "Delete"
		end


		return false
	end


end


-- PetData is the pet's entry from the config
function PetServiceServer:GivePet(Player: Player, PetData: {})
	if not Player then return false end

	if not CanClaimPet(Player) then return false end

	local NewPet = PetClass.New(GeneratePetID(), PetData.Name, PetData.Rarity, PetData.ShieldBoost, Player.UserId)
	PlayersPets[Player][NewPet.Id] = NewPet

	DataService:arrayInsert(Player, {"Pets"}, NewPet:Serialize())

	return true
end


-- unequips everything, then equips the highest boosts up to the player's capacity
function PetServiceServer:EquipBest(Player: Player)
	local PlayerPets = PlayersPets[Player]
	if not PlayerPets then return false end

	local PlayerStats = Player:FindFirstChild("PlayerStats")
	local EquipCapacity = PlayerStats and PlayerStats:FindFirstChild("PetEquipCapacity")
	if not EquipCapacity then return false end

	-- clearing first means Equip() below never hits the capacity limit
	for _, Pet in pairs(PlayerPets) do
		if Pet.Equipped then
			Pet:Unequip()
		end
	end

	local Sorted = {}
	for _, Pet in pairs(PlayerPets) do
		table.insert(Sorted, Pet)
	end

	-- highest boost first, and the id breaks ties so the result is the same every run
	table.sort(Sorted, function(A, B)
		local ABoost = A.ShieldBoost or 0
		local BBoost = B.ShieldBoost or 0

		if ABoost == BBoost then
			return A.Id < B.Id
		end

		return ABoost > BBoost
	end)

	local EquippedIds = {}

	for Index = 1, math.min(EquipCapacity.Value, #Sorted) do
		local Pet = Sorted[Index]

		if Pet:Equip() == "Equip" then
			table.insert(EquippedIds, Pet.Id)
		end
	end

	-- one pass over the saved array instead of a lookup per pet, and only changed flags are written
	local PlayerData = DataService:get(Player, {"Pets"})

	for Index, PetData in ipairs(PlayerData) do
		local ShouldEquip = table.find(EquippedIds, PetData.Id) ~= nil

		if PetData.EquippedBeforeLeave ~= ShouldEquip then
			DataService:set(Player, {"Pets", Index, "EquippedBeforeLeave"}, ShouldEquip)
		end
	end

	return true, EquippedIds
end


function PetServiceServer:DeletePet(Player: Player, PetId: string)
	local Index = GetPetIndex(Player, PetId)
	if not Index then return false end

	PlayersPets[Player][PetId] = nil

	DataService:arrayRemove(Player, {"Pets"}, Index)

	return true
end


-- deletes several pets at once, equipped ones are skipped
function PetServiceServer:DeletePets(Player: Player, PetIds: {string})
	local PlayerPets = PlayersPets[Player]
	if not PlayerPets or typeof(PetIds) ~= "table" then return false end

	local Deleted = {}

	for _, PetId in ipairs(PetIds) do
		local Pet = PlayerPets[PetId]

		-- checked here as well, in case the client's own check was bypassed
		-- DeletePet looks the index up again each time, because every removal shifts the array
		if Pet and not Pet.Equipped and Pet:Delete() then
			if PetServiceServer:DeletePet(Player, PetId) then
				table.insert(Deleted, PetId)
			end
		end
	end

	return true, Deleted
end


return PetServiceServer
