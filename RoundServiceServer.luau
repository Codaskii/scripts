-- Discord: codaa1 | Roblox: Codaskii

--Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

--Modules
local Packets = require(ReplicatedStorage.Packages.Packets)
local TimerModule = require(ReplicatedStorage.Packages.Timer)
local TroveModule = require(ReplicatedStorage.Packages.Trove)
local RoundConfig = require(ReplicatedStorage.Configs.RoundConfig)
local StateHandler = require(ReplicatedStorage.Shared.Modules.StateHandler)
local Signal = require(ReplicatedStorage.Packages.Signal)

--Variables
local NeededPlayerCount = RoundConfig.NeededPlayerCount
local IntermissionTime = RoundConfig.IntermissionTime
local RoundTime = RoundConfig.RoundTime
local RoundCoinReward = RoundConfig.RoundCoinReward

local MapsFolder: Folder = ReplicatedStorage.Assets.Maps
local WorkspaceMapFolder: Folder = workspace.Map
local MapSpawnPosition: CFrame = WorkspaceMapFolder.MapPosition.CFrame

local RoundEvent = Packets.RoundEvent


local RoundServiceServer = {}
RoundServiceServer.EndRoundSignal = Signal.new()

--Functions

local function HasEnoughPlayers(): boolean
	return #Players:GetPlayers() >= NeededPlayerCount
end


-- the state is for server scripts, the attribute is there so clients can read it too
local function SetPlaying(Player: Player, Value: boolean)
	StateHandler.SetState(Player, "Playing", Value)
	Player:SetAttribute("Playing", Value)
end


-- only alive players with a loaded character join the round
local function TeleportPlayersToMap()
	for i, Player in Players:GetPlayers() do
		local Character = Player.Character
		if not Character then continue end

		local HumanoidRootPart: BasePart = Character:FindFirstChild("HumanoidRootPart")
		if not HumanoidRootPart then continue end

		local Humanoid: Humanoid = Character:FindFirstChild("Humanoid")
		if not Humanoid or Humanoid.Health <= 0 then continue end

		HumanoidRootPart:PivotTo(MapSpawnPosition * CFrame.new(0, 2, 0))
		SetPlaying(Player, true)
	end
end


local function TeleportPlayersToSpawn()
	for i, Player in Players:GetPlayers() do
		if StateHandler.GetState(Player, "Playing") == false then continue end
		SetPlaying(Player, false)

		local Character = Player.Character
		if not Character then continue end

		local HumanoidRootPart: BasePart = Character:FindFirstChild("HumanoidRootPart")
		if not HumanoidRootPart then continue end

		-- short delay so winners can see the round end before getting teleported
		task.delay(2, function()
			if not HumanoidRootPart.Parent then return end
			HumanoidRootPart:PivotTo(workspace.SpawnLocation.CFrame)
		end)
	end
end


local function GetPlayersInRound(): {Player}
	local PlayersInRound = {}
	for i, Player in Players:GetPlayers() do
		if StateHandler.GetState(Player, "Playing") == true then
			table.insert(PlayersInRound, Player)
		end
	end

	return PlayersInRound
end


-- ends the round early when one or no players are left
local function CheckForRoundEnd(self: RoundServiceServer)
	if self.RoundStatus == "Playing" and #GetPlayersInRound() <= 1 then
		RoundServiceServer.EndRound(self)
	end
end


-- dying takes you out of the round
local function SetupCharacter(self: RoundServiceServer, Player: Player, Character: Model)
	local Humanoid: Humanoid = Character:WaitForChild("Humanoid")

	Humanoid.Died:Connect(function()
		SetPlaying(Player, false)
		CheckForRoundEnd(self)
	end)
end


local function SetupPlayer(self: RoundServiceServer, Player: Player)
	SetPlaying(Player, false)

	Player.CharacterAdded:Connect(function(Character)
		SetupCharacter(self, Player, Character)
	end)

	-- character might have spawned before we connected
	if Player.Character then
		task.spawn(SetupCharacter, self, Player, Player.Character)
	end
end




--Methods
function RoundServiceServer.Init(self: RoundServiceServer)
	self.RoundStatus = "Waiting"
	workspace:SetAttribute("RoundStatus", self.RoundStatus)
	self.Map = nil
	self.Trove = TroveModule.new()

	Players.PlayerAdded:Connect(function(Player)
		SetupPlayer(self, Player)
	end)

	-- players who joined before Init ran
	for i, Player in Players:GetPlayers() do
		SetupPlayer(self, Player)
	end

	-- a leaving player still shows up in GetPlayers here, so mark them as not playing first
	Players.PlayerRemoving:Connect(function(Player)
		SetPlaying(Player, false)
		CheckForRoundEnd(self)
	end)

	RoundServiceServer.StartWaiting(self)

end


function RoundServiceServer.StartWaiting(self: RoundServiceServer)
	local Task = task.spawn(function()

		if self.Map then
			self.Map:Destroy()
			self.Map = nil
		end

		self.RoundStatus = "Waiting"
		workspace:SetAttribute("RoundStatus", self.RoundStatus)
		self.Trove:Clean()

		repeat task.wait(1)
		until HasEnoughPlayers()

		RoundServiceServer.StartIntermission(self)

	end)

	self.Trove:Add(Task)
end


function RoundServiceServer.StartIntermission(self: RoundServiceServer)
	if not HasEnoughPlayers() then RoundServiceServer.StartWaiting(self) return end

	RoundServiceServer.SpawnMap(self, "ClassicMap")
	self.RoundStatus = "Intermission"
	workspace:SetAttribute("Time", IntermissionTime)
	workspace:SetAttribute("RoundStatus", self.RoundStatus)

	-- timer goes in the trove so switching states always stops it
	local Timer = TimerModule.new(1)
	self.Trove:Add(Timer)

	local Time = IntermissionTime
	Timer:Start()

	Timer.Tick:Connect(function()
		-- someone left during intermission, go back to waiting
		if not HasEnoughPlayers() then RoundServiceServer.StartWaiting(self) return end

		workspace:SetAttribute("Time", Time)
		if Time <= 0 then
			self.Trove:Clean()
			RoundServiceServer.StartRound(self)
		end
		Time -= 1
	end)

end


function RoundServiceServer.StartRound(self: RoundServiceServer)
	self.RoundStatus = "Playing"
	workspace:SetAttribute("RoundStatus", self.RoundStatus)
	workspace:SetAttribute("Time", RoundTime)
	TeleportPlayersToMap()

	-- some players might have been dead or loading, so check again after teleporting
	if #GetPlayersInRound() < NeededPlayerCount then RoundServiceServer.EndRound(self) return false end

	local Timer = TimerModule.new(1)
	self.Trove:Add(Timer)

	local Time = RoundTime
	Timer:Start()

	Timer.Tick:Connect(function()
		workspace:SetAttribute("Time", Time)
		if Time <= 0 then
			self.Trove:Clean()
			RoundServiceServer.EndRound(self)
		end
		Time -= 1
	end)

end


function RoundServiceServer.EndRound(self: RoundServiceServer)
	-- only a running round can end, this also stops it from ending twice
	if self.RoundStatus ~= "Playing" then return end

	self.Trove:Clean()

	self.RoundStatus = "Ending"
	workspace:SetAttribute("RoundStatus", self.RoundStatus)

	-- everyone still playing when the round ends is a winner
	local Winners = GetPlayersInRound()
	RoundServiceServer.RewardPlayers(self, Winners)

	RoundEvent:Fire({
		Winners = Winners
	})

	RoundServiceServer.EndRoundSignal:Fire(Winners)

	TeleportPlayersToSpawn()

	-- wait until players are teleported out before removing the map
	task.delay(2, function()
		if self.Map then
			self.Map:Destroy()
			self.Map = nil
		end
		task.wait(2)
		RoundServiceServer.StartIntermission(self)
	end)

end


function RoundServiceServer.SpawnMap(self: RoundServiceServer, MapName: Map)
	local MapTemplate = MapsFolder:FindFirstChild(MapName)
	if not MapTemplate then warn("Map not found: " .. tostring(MapName)) return end

	local Map: Model = MapTemplate:Clone()
	Map.Parent = WorkspaceMapFolder
	Map:PivotTo(MapSpawnPosition)
	self.Map = Map
end


function RoundServiceServer.RewardPlayers(self: RoundServiceServer, Winners: {Player})
	for i, Winner: Player in Winners do
		local Leaderstats: Folder = Winner:FindFirstChild("leaderstats")
		if not Leaderstats then continue end

		local Coins: NumberValue = Leaderstats:FindFirstChild("Coins")
		if not Coins then continue end

		Coins.Value += RoundCoinReward
	end
end


--Types
export type RoundStatus = "Waiting" | "Intermission" | "Playing" | "Ending"
export type Map = "ClassicMap" | "TestMap"

type RoundServiceServer = typeof(RoundServiceServer) & {
	RoundStatus: RoundStatus,
	Trove: TroveModule.Trove,
	Map: Model?
}


return RoundServiceServer :: RoundServiceServer
