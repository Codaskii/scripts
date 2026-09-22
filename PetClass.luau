-- Discord: codaa1 | Roblox: Codaskii

--Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

--Modules
local Packets = require(ReplicatedStorage.Packages.Packets)
local BoostService = require(ServerScriptService.Modules.BoostService)
local PetConfig = require(ReplicatedStorage.Configs.PetConfig)

--Variables
local PetsFolder = ReplicatedStorage.Assets.Pets
local PetFollowEvent = Packets.PetFollow


--Functions

-- FindFirstChild returns Instance, so we cast to the type we know it is
local function GetPetModel(PetName: string): Model?
	return PetsFolder:FindFirstChild(PetName) :: Model?
end


local function GetPlayer(UserID: number): Player?
	return Players:GetPlayerByUserId(UserID)
end


--Class
local Pet = {}
Pet.__index = Pet


function Pet.New(Id: string, Name: string, Rarity: string, ShieldBoost: number, OwnerID: number, EquippedBeforeLeave: boolean)
	local self = setmetatable({}, Pet)
	self.Id = Id
	self.Name = Name
	self.Model = GetPetModel(self.Name)

	-- boost and rarity always come from the config, so rebalancing it updates old saves too
	-- the saved values are only a fallback for a pet that's no longer in the config
	local ConfigData = PetConfig.PetsByName[Name]
	self.Rarity = (ConfigData and ConfigData.Rarity) or Rarity or "Common"
	self.ShieldBoost = (ConfigData and ConfigData.ShieldBoost) or ShieldBoost or 1

	self.Owner = OwnerID
	self.Equipped = false

	-- remembers if the pet was equipped last session so we can re-equip it on join
	self.EquippedBeforeLeave = EquippedBeforeLeave or false

	return self
end


-- works like a toggle, if it's already equipped it unequips instead
function Pet:Equip()
	local Player = GetPlayer(self.Owner)
	if not Player or not self.Model then return false end

	if self.Equipped then self:Unequip() return "Unequip" end

	self.Equipped = true

	-- the boost id is unique per pet, so two of the same pet both count
	BoostService:SetBoost(Player, "Pet_" .. self.Id, self.ShieldBoost)

	-- tell every client to spawn this pet behind the owner
	PetFollowEvent:Fire({
		UserId = self.Owner,
		Type = "Equip",
		Model = self.Model,
		Name = self.Name,
		PetId = self.Id
	})

	return "Equip"
end


function Pet:Unequip()
	if not self.Equipped then return false end

	self.Equipped = false

	-- the owner may already have left, the boost goes with them anyway
	local Player = GetPlayer(self.Owner)
	if Player then
		BoostService:RemoveBoost(Player, "Pet_" .. self.Id)
	end

	PetFollowEvent:Fire({
		UserId = self.Owner,
		Type = "Unequip",
		Model = self.Model,
		Name = self.Name,
		PetId = self.Id
	})

	return true
end


-- used when someone joins late, so they can see pets that were already equipped
function Pet:SendTo(Player: Player)
	if not self.Equipped or not self.Model then return end

	PetFollowEvent:FireClient(Player, {
		UserId = self.Owner,
		Type = "Equip",
		Model = self.Model,
		Name = self.Name,
		PetId = self.Id
	})
end


-- can't delete a pet while it's equipped
function Pet:Delete()
	if self.Equipped then return false end

	return true
end


-- turns the pet into a plain table so it can be saved to the datastore
function Pet:Serialize()
	return {
		Id = self.Id,
		Name = self.Name,
		Rarity = self.Rarity,
		ShieldBoost = self.ShieldBoost,
		Owner = self.Owner,
		EquippedBeforeLeave = self.EquippedBeforeLeave
	}
end


-- rebuilds the pet object from saved datastore data
function Pet.Deserialize(Data)
	return Pet.New(Data.Id, Data.Name, Data.Rarity, Data.ShieldBoost, Data.Owner, Data.EquippedBeforeLeave)
end


return Pet
