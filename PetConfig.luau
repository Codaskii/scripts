-- Discord: codaa1 | Roblox: Codaskii

local PetConfig = {}

--RarityColors
PetConfig.RarityColors = {
	Common = Color3.new(0.72549, 0.72549, 0.72549),
	Uncommon = Color3.new(0.235294, 0.709804, 0),
	Rare = Color3.new(0, 0.666667, 1),
	Epic = Color3.new(0.592157, 0, 0.909804),
	Legendary = Color3.new(1, 0.862745, 0.0823529),
	Secret = Color3.new(0.356863, 0.321569, 0.498039),
	Hacker = Color3.new(0, 0.666667, 0)
}


-- gradients shared by every pet of the same rarity
local COMMON_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(185, 185, 185)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(185, 185, 185)),
})

local UNCOMMON_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 181, 0)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(85, 255, 0)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 181, 0)),
})

local RARE_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 170, 255)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 221, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 170, 255)),
})

local EPIC_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(151, 0, 232)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(170, 85, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(151, 0, 232)),
})

local LEGENDARY_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 170, 0)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 0)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 170, 0)),
})

local SECRET_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(91, 82, 127)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(225, 225, 225)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(91, 82, 127)),
})

local HACKER_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 0)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 170, 0)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 255, 0)),
})


--Pets
-- IconScale: 1 is the template size, 1.3 is 30% bigger
-- IconOffset: moves the icon inside its slot when the image isn't centred
-- HasRot: turns on the gradient spin script in the slot template
PetConfig.Pets = {

	--Basic Egg
	TungSahur = {
		Name = "Tung Sahur",
		Rarity = "Common",
		Icon = "rbxassetid://97427623172624",
		PetSlotColor = COMMON_GRADIENT,
		IconOffset = Vector2.new(0.5, 0.55),
		ShieldBoost = 1.2
	},

	ChimpanziniBananini = {
		Name = "Chimpanzini Bananini",
		Rarity = "Uncommon",
		Icon = "rbxassetid://72264677772741",
		PetSlotColor = UNCOMMON_GRADIENT,
		IconOffset = Vector2.new(0.55, 0.55),
		ShieldBoost = 1.5
	},

	BrrBrrPatapim = {
		Name = "Brr Brr Patapim",
		Rarity = "Rare",
		Icon = "rbxassetid://127942397118013",
		PetSlotColor = RARE_GRADIENT,
		ShieldBoost = 2
	},


	--Demonic Egg
	CappuccinoAssassino = {
		Name = "Cappuccino Assassino",
		Rarity = "Uncommon",
		Icon = "rbxassetid://84194661130482",
		PetSlotColor = UNCOMMON_GRADIENT,
		ShieldBoost = 2.5
	},

	TrippiTroppi = {
		Name = "Trippi Troppi",
		Rarity = "Rare",
		Icon = "rbxassetid://96335577182312",
		PetSlotColor = RARE_GRADIENT,
		IconOffset = Vector2.new(0.5, 0.6),
		ShieldBoost = 3
	},

	OdinDinDinDun = {
		Name = "Odin Din Din Dun",
		Rarity = "Epic",
		Icon = "rbxassetid://77583951416411",
		PetSlotColor = EPIC_GRADIENT,
		ShieldBoost = 4
	},

	KarkerkarKurkur = {
		Name = "Karkerkar Kurkur",
		Rarity = "Legendary",
		Icon = "rbxassetid://96081900984428",
		PetSlotColor = LEGENDARY_GRADIENT,
		ShieldBoost = 6.5
	},


	--Cyborg Egg
	TrippiTroppiTroppaTrippa = {
		Name = "Trippi Troppi Troppa Trippa",
		Rarity = "Uncommon",
		Icon = "rbxassetid://137103121751714",
		PetSlotColor = UNCOMMON_GRADIENT,
		IconScale = 1.3,
		ShieldBoost = 7.5
	},

	SvininaBombardino = {
		Name = "Svinina Bombardino",
		Rarity = "Rare",
		Icon = "rbxassetid://125099378463200",
		PetSlotColor = RARE_GRADIENT,
		ShieldBoost = 8
	},

	TaTaTaTaSahur = {
		Name = "Ta Ta Ta Ta Sahur",
		Rarity = "Epic",
		Icon = "rbxassetid://112944361464552",
		PetSlotColor = EPIC_GRADIENT,
		ShieldBoost = 10
	},

	EspressoSignora = {
		Name = "Espresso Signora",
		Rarity = "Legendary",
		Icon = "rbxassetid://111230958667835",
		PetSlotColor = LEGENDARY_GRADIENT,
		ShieldBoost = 12.5
	},


	--King Egg
	Garamararam = {
		Name = "Garamararam",
		Rarity = "Uncommon",
		Icon = "rbxassetid://137184088083987",
		PetSlotColor = UNCOMMON_GRADIENT,
		ShieldBoost = 13
	},

	Madudung = {
		Name = "Madudung",
		Rarity = "Rare",
		Icon = "rbxassetid://138837489657367",
		PetSlotColor = RARE_GRADIENT,
		ShieldBoost = 14
	},

	AvocadiniGuffo = {
		Name = "Avocadini Guffo",
		Rarity = "Epic",
		Icon = "rbxassetid://113024096495131",
		PetSlotColor = EPIC_GRADIENT,
		ShieldBoost = 15
	},

	LionelCactuseli = {
		Name = "Lionel Cactuseli",
		Rarity = "Legendary",
		Icon = "rbxassetid://121084936492575",
		PetSlotColor = LEGENDARY_GRADIENT,
		ShieldBoost = 18
	},


	--Secret
	PotHotspot = {
		Name = "Pot Hotspot",
		Rarity = "Secret",
		Icon = "rbxassetid://89573020665269",
		PetSlotColor = SECRET_GRADIENT,
		HasRot = true,
		ShieldBoost = 20
	},

	BlueberrinniOctopusini = {
		Name = "Blueberrinni Octopusini",
		Rarity = "Secret",
		Icon = "rbxassetid://117186099602487",
		PetSlotColor = SECRET_GRADIENT,
		HasRot = true,
		ShieldBoost = 5
	},

	GanganzelliTrulala = {
		Name = "Ganganzelli Trulala",
		Rarity = "Secret",
		Icon = "rbxassetid://102112963814992",
		PetSlotColor = SECRET_GRADIENT,
		HasRot = true,
		ShieldBoost = 20
	},

	SixSeven = {
		Name = "Six Seven",
		Rarity = "Secret",
		Icon = "rbxassetid://87114565423395",
		PetSlotColor = SECRET_GRADIENT,
		HasRot = true,
		ShieldBoost = 15
	},


	--Hacker
	HackerCappuccinoAssassino = {
		Name = "Hacker Cappuccino Assassino",
		Rarity = "Hacker",
		Icon = "rbxassetid://105821207878960",
		PetSlotColor = HACKER_GRADIENT,
		HasRot = true,
		IconScale = 1.4,
		ShieldBoost = 20
	},

	HackerOdinDinDinDun = {
		Name = "Hacker Odin Din Din Dun",
		Rarity = "Hacker",
		Icon = "rbxassetid://139948606792423",
		PetSlotColor = HACKER_GRADIENT,
		HasRot = true,
		IconScale = 1.3,
		ShieldBoost = 23.5
	},

	Hacker1x1x1x1 = {
		Name = "Hacker 1x1x1x1",
		Rarity = "Hacker",
		Icon = "rbxassetid://80449939767469",
		PetSlotColor = HACKER_GRADIENT,
		HasRot = true,
		IconScale = 1.3,
		ShieldBoost = 25
	},

}


--Eggs
-- PetId is the key in PetConfig.Pets above, not a pet's display name
-- Weight is relative, each egg's weights add up to 100 so they read as percentages
PetConfig.Eggs = {
	BasicEgg = {
		DisplayName = "Basic Egg",
		Price = 50,
		CurrencyName = "Wins",
		Pets = {
			{ PetId = "TungSahur", Weight = 60 },
			{ PetId = "ChimpanziniBananini", Weight = 30 },
			{ PetId = "BrrBrrPatapim", Weight = 10 }
		},
	},

	DemonicEgg = {
		DisplayName = "Demonic Egg",
		Price = 10000,
		CurrencyName = "Wins",
		Pets = {
			{ PetId = "CappuccinoAssassino", Weight = 60 },
			{ PetId = "TrippiTroppi", Weight = 25 },
			{ PetId = "OdinDinDinDun", Weight = 10 },
			{ PetId = "KarkerkarKurkur", Weight = 5 }
		},
	},

	CyborgEgg = {
		DisplayName = "Cyborg Egg",
		Price = 150000,
		CurrencyName = "Wins",
		Pets = {
			{ PetId = "TrippiTroppiTroppaTrippa", Weight = 60 },
			{ PetId = "SvininaBombardino", Weight = 35 },
			{ PetId = "TaTaTaTaSahur", Weight = 4 },
			{ PetId = "EspressoSignora", Weight = 1 }
		},
	},

	KingEgg = {
		DisplayName = "King Egg",
		Price = 1500000,
		CurrencyName = "Wins",
		Pets = {
			{ PetId = "Garamararam", Weight = 63 },
			{ PetId = "Madudung", Weight = 34 },
			{ PetId = "AvocadiniGuffo", Weight = 2.2 },
			{ PetId = "LionelCactuseli", Weight = 0.8 }
		},
	},

	-- paid egg, the price is handled by the dev product instead of a currency
	HackerEgg = {
		DisplayName = "Hacker Egg",
		Price = "Robux",
		CurrencyName = "DevProduct",
		Pets = {
			{ PetId = "HackerCappuccinoAssassino", Weight = 50 },
			{ PetId = "HackerOdinDinDinDun", Weight = 45 },
			{ PetId = "Hacker1x1x1x1", Weight = 5 },
		},
	},
}


-- pets are saved by display name, so this lookup avoids searching the table every time
PetConfig.PetsByName = {}

for _, Data in pairs(PetConfig.Pets) do
	PetConfig.PetsByName[Data.Name] = Data
end


return PetConfig
