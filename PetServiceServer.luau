-- Discord: codaa1 | Roblox: Codaskii
-- Open source packages used:
--   Packet by Suphi Kaner (networking)
--   DataService by Leif (player data)

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
-- [Player] = { [PetId] = Pet }, a dictionary so a pet is found straight from the id the client sends
local PlayersPets = {}

-- loading yields, so a request can arrive before a player's pets exist, this flag
-- is what RequestSync waits on instead of guessing with an arbitrary task.wait
local PlayerDataReady = {}

local PetActionEvent = Packets.PetAction


--Functions

-- pets equipped before this client joined were broadcast to the clients that already existed
local function SyncPetsToPlayer(TargetPlayer: Player)
	for i, Pets in pairs(PlayersPets) do
		for i, Pet in pairs(Pets) do
			Pet:SendTo(TargetPlayer)
		end
	end
end


-- a GUID rather than the pet's name, because a player can own several of the same
-- pet and each one needs its own equip state, boost entry and inventory slot
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


-- saved pets are plain tables, these are rebuilt into objects that carry the behaviour
local function DeserializePets(Pets: {}, Player: Player)
	for i, Pet in pairs(Pets) do
		PlayersPets[Player][Pet.Id] = PetClass.Deserialize(Pet)
	end
end


-- data holds pets as an array, so editing or removing one by id means finding its
-- index first, and the array is re-read on every call rather than cached, because
-- any removal shifts every index after it and a stale cache would edit the wrong pet
local function GetPetIndex(Player: Player, PetId: string)
	local PlayerData = DataService:get(Player, {"Pets"})

	for i, PetData in ipairs(PlayerData) do
		if PetData.Id == PetId then
			return i
		end
	end

	return nil
end


-- puts back what the player had on when they left, so boosts and pets carry over
local function EquipPets(Player: Player)
	for i, Pet in pairs(PlayersPets[Player]) do
		if Pet.EquippedBeforeLeave == true then
			Pet:Equip()
		end
	end
end


-- storage limit, enforced here rather than in the UI because a client can be modified,
-- and counted from data rather than the object table so it cannot drift from what is saved
local function CanClaimPet(Player: Player)
	local PlayerStats = Player:FindFirstChild("PlayerStats")
	if not PlayerStats then return false end

	local PetStorage = PlayerStats:FindFirstChild("PetStorage") :: IntValue?
	if not PetStorage then return false end

	local PetCount = DataService:get(Player, {"Pets"})

	if #PetCount < PetStorage.Value then return true end

	return false
end


-- equip limit, counted from the live objects because that is what the boosts are
-- built from, and checked on the server for the same reason as the storage limit
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


--Methods
function PetServiceServer.Init()

	Players.PlayerAdded:Connect(function(Player)
		-- created before the yields below, so anything in between finds an empty table, not nil
		PlayersPets[Player] = {}
		DataService:waitForData(Player)

		-- the stats must exist before equipping, since equipping writes boosts onto them
		local PlayerStats = Player:WaitForChild("PlayerStats")
		PlayerStats:WaitForChild("BaseIncome")

		-- three yields have passed by now, so the player may already be gone
		if not PlayersPets[Player] then return end

		DeserializePets(LoadPets(Player), Player)
		EquipPets(Player)

		PlayerDataReady[Player] = true
	end)


	Players.PlayerRemoving:Connect(function(Player)
		-- unequipped on the way out so every other client destroys the pet models and
		-- the boost entries are released, only then are the tables dropped
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


	-- one entry point for every pet request, so ownership is checked in a single place,
	-- Payload is a pet id for the single-pet actions and a list of ids for DeletePets
	PetActionEvent.OnServerInvoke = function(Player: Player, ActionType: string, Payload: any)
		local PlayerPets = PlayersPets[Player]
		if not PlayerPets then return false end


		-- a joining client asks for the pets it missed, and waits here rather than
		-- getting an empty list, because its own data may still be loading above
		if ActionType == "RequestSync" then
			while not PlayerDataReady[Player] do
				task.wait()
			end

			SyncPetsToPlayer(Player)
			return true, "RequestSync"
		end


		-- these two act on many pets at once, so they run before the single-pet lookup
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


		-- the id is only looked up inside this player's own table, so a client cannot
		-- reach another player's pet by sending someone else's id
		local PetId = Payload
		local Pet = PetId and PlayerPets[PetId]
		if not Pet then return false end


		if ActionType == "Equip" then
			-- the capacity check only applies when equipping, taking a pet off is always allowed
			if not Pet.Equipped and not CanEquip(Player) then
				return false, "CantEquip"
			end

			-- Equip is a toggle and reports which way it went, so the saved flag is set
			-- from its result rather than assumed
			local Action = Pet:Equip()
			if not Action then return false end

			local PetIndex = GetPetIndex(Player, PetId)
			if PetIndex then
				DataService:set(Player, {"Pets", PetIndex, "EquippedBeforeLeave"}, Action == "Equip")
			end

			return true, Action


		elseif ActionType == "Delete" then
			-- the pet decides whether it may be deleted, an equipped one refuses
			if not Pet:Delete() then
				return false, "Delete"
			end

			PetServiceServer:DeletePet(Player, PetId)

			return true, "Delete"
		end


		return false
	end


end


-- called by eggs, rewards and anything else that hands out a pet, PetData is the config entry
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

	-- clearing first frees every slot, so the loop below can never be refused by the capacity limit
	for _, Pet in pairs(PlayerPets) do
		if Pet.Equipped then
			Pet:Unequip()
		end
	end

	local Sorted = {}
	for _, Pet in pairs(PlayerPets) do
		table.insert(Sorted, Pet)
	end

	-- highest boost first, and the id breaks ties so two pets with the same boost always
	-- come out in the same order, since the pairs loop above guarantees none
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

	-- one pass instead of a GetPetIndex search per pet, and only changed flags are written
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


-- reports back which pets actually went, so the client removes exactly those slots
function PetServiceServer:DeletePets(Player: Player, PetIds: {string})
	local PlayerPets = PlayersPets[Player]
	if not PlayerPets or typeof(PetIds) ~= "table" then return false end

	local Deleted = {}

	for _, PetId in ipairs(PetIds) do
		local Pet = PlayerPets[PetId]

		-- equipped pets are skipped here too, not only in the UI, so a modified client
		-- cannot delete a pet out from under its own boost
		if Pet and not Pet.Equipped and Pet:Delete() then
			if PetServiceServer:DeletePet(Player, PetId) then
				table.insert(Deleted, PetId)
			end
		end
	end

	return true, Deleted
end


return PetServiceServer
