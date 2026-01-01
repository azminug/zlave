--[[
    ZlaVe Script v2.9
    ==============================
    by Minervastra
    
    Features:
    - Fishing automation
    - Firebase heartbeat sync
    - Backpack management (Auto-favorite)
    - Discord webhook notifications
    - Teleport locations
    - FPS boost & misc utilities
    - Anti-AFK
    
    Usage:
    loadstring(game:HttpGet("URL"))()
--]]

--====================================
-- LOAD WINDUI
--====================================
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "ZlaVe",
    Icon = "zap",
    Author = "by Minervastra",
    Folder = "ZlaVeScript",
    Size = UDim2.fromOffset(560, 440),
    MinSize = Vector2.new(540, 340),
    MaxSize = Vector2.new(800, 540),
    Transparent = true,
    Theme = "Dark",
    Resizable = true,
    SideBarWidth = 180,
    HideSearchBar = true,
    ScrollBarEnabled = false,
    KeySystem = false
})

-- Mini Toggle Button (Logo) for minimize/restore - All in one table to save registers
local MiniBtn = {
    dragging = false,
    dragStart = nil,
    startPos = nil,
    totalDragDistance = 0,
    DRAG_THRESHOLD = 5,
}
MiniBtn.Gui = Instance.new("ScreenGui")
MiniBtn.Gui.Name = "ZlaVeMiniButton"
MiniBtn.Gui.DisplayOrder = 999
MiniBtn.Gui.ResetOnSpawn = false
MiniBtn.Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

MiniBtn.Button = Instance.new("ImageButton")
MiniBtn.Button.Name = "ToggleButton"
MiniBtn.Button.Size = UDim2.fromOffset(50, 50)
MiniBtn.Button.Position = UDim2.new(1, -60, 1, -60)
MiniBtn.Button.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
MiniBtn.Button.BackgroundTransparency = 0.2
MiniBtn.Button.Image = "rbxassetid://6031075938"
MiniBtn.Button.ImageColor3 = Color3.fromRGB(255, 200, 80)
MiniBtn.Button.ScaleType = Enum.ScaleType.Fit
MiniBtn.Button.Parent = MiniBtn.Gui

MiniBtn.Corner = Instance.new("UICorner")
MiniBtn.Corner.CornerRadius = UDim.new(0.5, 0)
MiniBtn.Corner.Parent = MiniBtn.Button

MiniBtn.Stroke = Instance.new("UIStroke")
MiniBtn.Stroke.Color = Color3.fromRGB(255, 200, 80)
MiniBtn.Stroke.Thickness = 2
MiniBtn.Stroke.Parent = MiniBtn.Button

MiniBtn.Button.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        MiniBtn.dragging = true
        MiniBtn.dragStart = input.Position
        MiniBtn.startPos = MiniBtn.Button.Position
        MiniBtn.totalDragDistance = 0
    end
end)

MiniBtn.Button.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        local wasDragging = MiniBtn.totalDragDistance >= MiniBtn.DRAG_THRESHOLD
        MiniBtn.dragging = false
        if not wasDragging then
            local isClosed = Window.Closed
            if isClosed then
                pcall(function() Window:Open() end)
                MiniBtn.Button.ImageColor3 = Color3.fromRGB(255, 200, 80)
                MiniBtn.Stroke.Color = Color3.fromRGB(255, 200, 80)
            else
                pcall(function() Window:Close() end)
                MiniBtn.Button.ImageColor3 = Color3.fromRGB(120, 120, 120)
                MiniBtn.Stroke.Color = Color3.fromRGB(120, 120, 120)
            end
        end
    end
end)

game:GetService("UserInputService").InputChanged:Connect(function(input)
    if MiniBtn.dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - MiniBtn.dragStart
        MiniBtn.totalDragDistance = math.abs(delta.X) + math.abs(delta.Y)
        MiniBtn.Button.Position = UDim2.new(MiniBtn.startPos.X.Scale, MiniBtn.startPos.X.Offset + delta.X, MiniBtn.startPos.Y.Scale, MiniBtn.startPos.Y.Offset + delta.Y)
    end
end)

pcall(function()
    MiniBtn.Gui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
end)

--====================================
-- CONFIGURATION
--====================================
local CONFIG = {
    -- Firebase
    FIREBASE_URL = "https://autofarm-861ab-default-rtdb.asia-southeast1.firebasedatabase.app",
    
    -- Intervals (seconds)
    HEARTBEAT_INTERVAL = 15,
    BACKPACK_INTERVAL = 60,
    AUTO_FAVORITE_INTERVAL = 30,
    
    -- Fishing delays (seconds)
    COMPLETE_DELAY = 1.48,  -- Delay setelah request minigame sebelum complete
    CANCEL_DELAY = 0.33,    -- Delay setelah complete sebelum cancel/reset
    
    -- Shared constants to avoid duplicate locals
    RARITY_OPTIONS = {"COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY", "MYTHIC", "SECRET"},
    
    -- Debug
    DEBUG = false
}

--====================================
-- SETTINGS PERSISTENCE
--====================================
local SETTINGS_FILE = "ZlaVeScript/settings.json"
local SavedSettings = {
    blatantEnabled = false,
    heartbeatEnabled = true,
    debugMode = false,
    hideNotifications = false,
    noAnimations = false,
    blockCutscene = false,
    removeSkinEffect = false,
    infiniteZoom = false,
    -- AutoFavorite
    autoFavoriteEnabled = false,
    autoFavoriteRarities = {"SECRET", "MYTHIC"},
    autoFavoriteItemNames = {},
    autoFavoriteMutations = {},
    -- AutoUnfavorite
    autoUnfavoriteEnabled = false,
    -- FPS Boost
    fpsBoostEnabled = false,
    -- FPS Cap
    fpsCapEnabled = false,
    fpsCapValue = 30,
    -- Event Auto-Join
    basePointName = "None",
    autoJoinChristmasCave = false,
    autoJoinLochness = false,
    -- v1.9: Inventory Management
    autoEquipRodEnabled = true,
    autoTotemEnabled = false,
    selectedTotemType = "Luck Totem",
    totemSpacing = 101, -- Default totem spacing (studs)
    autoBuyMerchantEnabled = false,
    merchantBuyList = {},
    -- v1.9.5: Rotation System (Multi-Select)
    rotationEnabled = false,
    rotationLocations = {"Crater Island"},
    rotationIntervalMinutes = 60,
    lastRotationIndex = 1, -- v2.6.2: Persist last rotation index across rejoins
    autoTotemAfterTeleport = false,
    -- v2.1: Timer-Based Auto Sell
    autoSellEnabled = false,
    autoSellInterval = 60, -- Seconds between auto sells
    -- v2.0: Discord Webhook
    webhookEnabled = false,
    webhookURL = "",
    webhookRarityFilter = {"SECRET", "MYTHIC"},
    webhookNotifyMutations = true,
    -- v2.3: Auto Weather
    autoWeatherEnabled = false,
    autoWeatherList = {}, -- List of weather types to maintain
    -- v2.4: Auto Consume Potion
    autoPotionEnabled = false,
    selectedPotions = {}, -- Multi-select potion list
    -- v2.8: Auto Ruin Door
    autoRuinDoorEnabled = false,
    -- v2.9: Auto Gift Santa
    autoGiftSantaEnabled = false,
    -- v3.0: Auto New Years Whale
    autoNewYearsWhaleEnabled = false,
}

local function LoadSettings()
    local success = pcall(function()
        if readfile and isfile and isfile(SETTINGS_FILE) then
            local data = readfile(SETTINGS_FILE)
            local parsed = game:GetService("HttpService"):JSONDecode(data)
            for k, v in pairs(parsed) do
                if SavedSettings[k] ~= nil then
                    SavedSettings[k] = v
                end
            end
            -- Migrate: convert rarity values to uppercase for parity with game data
            if SavedSettings.autoFavoriteRarities then
                local migrated = {}
                for _, r in ipairs(SavedSettings.autoFavoriteRarities) do
                    table.insert(migrated, r:upper())
                end
                SavedSettings.autoFavoriteRarities = migrated
            end
        end
    end)
    return success
end

local function SaveSettings()
    pcall(function()
        if writefile and makefolder then
            pcall(function() makefolder("ZlaVeScript") end)
            local data = game:GetService("HttpService"):JSONEncode(SavedSettings)
            writefile(SETTINGS_FILE, data)
        end
    end)
end

-- Load settings on startup
LoadSettings()
CONFIG.DEBUG = SavedSettings.debugMode

--====================================
-- SERVICES (v2.2: Consolidated into table)
--====================================
local Services = {
    Players = game:GetService("Players"),
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    Workspace = game:GetService("Workspace"),
    Lighting = game:GetService("Lighting"),
    HttpService = game:GetService("HttpService"),
    RunService = game:GetService("RunService"),
    TeleportService = game:GetService("TeleportService"),
    VirtualUser = game:GetService("VirtualUser"),
}

local Players = Services.Players
local ReplicatedStorage = Services.ReplicatedStorage
local LocalPlayer = Players.LocalPlayer
local HttpService = Services.HttpService
local RunService = Services.RunService

-- Player info stored in CONFIG to reduce top-level locals
CONFIG.Username = LocalPlayer and string.lower(LocalPlayer.Name) or "unknown"
CONFIG.UserId = LocalPlayer and LocalPlayer.UserId or 0
CONFIG.PlaceId = game.PlaceId
CONFIG.JobId = game.JobId

--====================================
-- NET & REMOTES (v2.2: Consolidated)
--====================================
local Net = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_net@0.2.0"):WaitForChild("net")

-- Remotes table to reduce local count
local Remotes = {}
pcall(function()
    Remotes.RF_Charge = Net:WaitForChild("RF/ChargeFishingRod", 5)
    Remotes.RF_Request = Net:WaitForChild("RF/RequestFishingMinigameStarted", 5)
    Remotes.RF_Cancel = Net:WaitForChild("RF/CancelFishingInputs", 5)
    Remotes.RE_Complete = Net:WaitForChild("RE/FishingCompleted", 5)
    Remotes.RF_SellAll = Net:WaitForChild("RF/SellAllItems", 5)
    Remotes.FavoriteEvent = Net:WaitForChild("RE/FavoriteItem", 5)
    Remotes.ObtainedNewFish = Net:WaitForChild("RE/ObtainedNewFishNotification", 5)
    Remotes.RE_SpawnTotem = Net:WaitForChild("RE/SpawnTotem", 5)
    Remotes.RE_EquipToolFromHotbar = Net:WaitForChild("RE/EquipToolFromHotbar", 5)
    Remotes.RF_PurchaseMarketItem = Net:WaitForChild("RF/PurchaseMarketItem", 5)
    Remotes.RF_SellItem = Net:WaitForChild("RF/SellItem", 5)
    -- v2.3: Weather remote
    Remotes.RF_PurchaseWeather = Net:WaitForChild("RF/PurchaseWeatherEvent", 5)
    -- v2.5: Oxygen tank remotes
    Remotes.RF_EquipOxygenTank = Net:WaitForChild("RF/EquipOxygenTank", 2)
    Remotes.RF_UnequipOxygenTank = Net:WaitForChild("RF/UnequipOxygenTank", 2)
    Remotes.RF_ConsumePotion = Net:WaitForChild("RF/ConsumePotion", 2)
    -- v2.9: Gift Santa remotes
    Remotes.RF_RedeemGift = Net:WaitForChild("RF/RedeemGift", 2)
    Remotes.RE_DialogueEnded = Net:WaitForChild("RE/DialogueEnded", 2)
    Remotes.RE_EquipItem = Net:WaitForChild("RE/EquipItem", 2)
end)

-- Note: Use Remotes.RF_Charge, Remotes.RF_Request, etc. directly
-- Removed redundant local aliases to stay under 200 register limit

--====================================
-- FISHDB PRE-BUILT DICTIONARY (from yes.lua AFv7 - O(1) tier lookup)
--====================================
local FishDB = {}
local TierMap = {
    COMMON = 1, UNCOMMON = 2, RARE = 3, EPIC = 4,
    LEGENDARY = 5, MYTHIC = 6, SECRET = 7, EXOTIC = 8, AZURE = 9
}
local TierToRarity = {}
for name, tier in pairs(TierMap) do TierToRarity[tier] = name end

local function BuildFishDB()
    local success = pcall(function()
        local itemsContainer = ReplicatedStorage:FindFirstChild("Items")
        if not itemsContainer then return end
        for _, module in ipairs(itemsContainer:GetChildren()) do
            if module:IsA("ModuleScript") then
                pcall(function()
                    local mod = require(module)
                    if mod and mod.Data and mod.Data.Type == "Fish" and mod.Data.Id then
                        FishDB[mod.Data.Id] = mod.Data.Tier
                    end
                end)
            end
        end
    end)
    if CONFIG.DEBUG then 
        local count = 0
        for _ in pairs(FishDB) do count = count + 1 end
        log("[FishDB] Built: " .. count .. " entries, success=" .. tostring(success)) 
    end
end

-- Deferred to reduce startup CPU spike
task.defer(function()
    task.wait(3) -- Wait for game to stabilize
    pcall(BuildFishDB)
end)

--====================================
-- STATE TRACKING
--====================================
local State = {
    -- Fishing
    fishingRunning = false,
    phase = "STEP123",
    lastStep123 = 0,
    lastStep4 = 0,
    
    -- Heartbeat
    heartbeatRunning = false,
    lastHeartbeat = 0,
    lastBackpack = 0,
    lastAutoFavorite = 0,
    
    -- Connection
    disconnectReason = nil,
    connectionStatus = "connected"
}

--====================================
-- CONNECTION REGISTRY
--====================================
local Connections = {}

local function RegisterConnection(conn)
    if conn then
        table.insert(Connections, conn)
    end
    return conn
end

local function CleanupConnections()
    for _, conn in ipairs(Connections) do
        pcall(function()
            if conn and conn.Disconnect then
                conn:Disconnect()
            end
        end)
    end
    Connections = {}
end

--====================================
-- MODULE LOADING
--====================================
local Replion, ItemUtility, TierUtility = nil, nil, nil

pcall(function()
    local packages = ReplicatedStorage:FindFirstChild("Packages")
    if packages then
        local replionModule = packages:FindFirstChild("Replion")
        if replionModule then Replion = require(replionModule) end
    end
end)

pcall(function()
    local shared = ReplicatedStorage:FindFirstChild("Shared")
    if shared then
        local itemUtilModule = shared:FindFirstChild("ItemUtility")
        if itemUtilModule then ItemUtility = require(itemUtilModule) end
    end
end)

pcall(function()
    local shared = ReplicatedStorage:FindFirstChild("Shared")
    if shared then
        local tierUtilModule = shared:FindFirstChild("TierUtility")
        if tierUtilModule then TierUtility = require(tierUtilModule) end
    end
end)

--====================================
-- DUPLICATE INSTANCE CHECK
--====================================
if getgenv().ZlaVeScriptRunning then
    warn("[ZlaVe] Another instance detected, stopping this one")
    return
end
getgenv().ZlaVeScriptRunning = true

--====================================
-- UTILITY FUNCTIONS
--====================================
local function log(msg, level)
    level = level or "INFO"
    if CONFIG.DEBUG or level == "ERROR" or level == "WARN" then
        print(string.format("[ZlaVe][%s] %s", level, msg))
    end
end

local function safeCall(fn, ...)
    local success, result = pcall(fn, ...)
    if not success and CONFIG.DEBUG then
        log("Error: " .. tostring(result), "ERROR")
    end
    return success, result
end

local function httpRequest(url, method, body)
    if not HttpService then
        if CONFIG.DEBUG then log("HttpService not available", "ERROR") end
        return nil
    end
    
    local bodyStr = nil
    if body then
        local encodeSuccess, encoded = pcall(function() return HttpService:JSONEncode(body) end)
        if encodeSuccess then bodyStr = encoded end
    end
    
    local requestFunc = syn and syn.request or request or http_request or (fluxus and fluxus.request) or nil
    
    if not requestFunc then
        if CONFIG.DEBUG then log("No HTTP function available", "ERROR") end
        return nil
    end
    
    local success, result = pcall(function()
        return requestFunc({
            Url = url,
            Method = method or "GET",
            Headers = { ["Content-Type"] = "application/json" },
            Body = bodyStr
        })
    end)
    
    if success and result then
        return result
    end
    return nil
end

local function firebasePatch(path, data)
    local url = CONFIG.FIREBASE_URL .. "/" .. path .. ".json"
    local result = httpRequest(url, "PATCH", data)
    return result and result.StatusCode == 200
end

local function firebasePut(path, data)
    local url = CONFIG.FIREBASE_URL .. "/" .. path .. ".json"
    local result = httpRequest(url, "PUT", data)
    return result and result.StatusCode == 200
end

--====================================
-- ITEM DATABASE
--====================================
local ItemDatabase = {}
local tierToRarity = {
    [1] = "Common", [2] = "Uncommon", [3] = "Rare",
    [4] = "Epic", [5] = "Legendary", [6] = "Mythic", [7] = "Secret"
}

local function BuildItemDatabase()
    local itemsFolder = ReplicatedStorage:FindFirstChild("Items")
    if not itemsFolder then 
        log("Items folder not found", "WARN")
        return 
    end
    
    local count = 0
    for _, itemModule in ipairs(itemsFolder:GetChildren()) do
        local ok, data = pcall(require, itemModule)
        if ok and type(data) == "table" and data.Data and data.Data.Id then
            local id = data.Data.Id
            local tierNum = data.Data.Tier or 0
            local rarity = tierToRarity[tierNum] or "Unknown"
            local sellPrice = data.SellPrice or (data.Data and data.Data.SellPrice) or 0
            
            ItemDatabase[id] = {
                Name = data.Data.Name or "Unknown",
                Type = data.Data.Type or "Unknown",
                Rarity = rarity,
                SellPrice = sellPrice
            }
            count = count + 1
        end
    end
    log("Item database: " .. count .. " items loaded")
end

local function GetItemInfo(itemId)
    return ItemDatabase[itemId] or { Name = "Unknown", Type = "Unknown", Rarity = "Unknown", SellPrice = 0 }
end

--====================================
-- BACKPACK SCANNER
--====================================
local function ScanBackpack()
    local result = {
        items = {},
        secretItems = {},
        totalValue = 0,
        rarityCount = {},
        itemCount = 0,
        timestamp = os.time()
    }
    
    if not Replion or not Replion.Client then
        log("Replion not available", "WARN")
        return result
    end
    
    local success = pcall(function()
        local DataReplion = Replion.Client:WaitReplion("Data")
        if not DataReplion then return end
        
        local inventoryItems = DataReplion:Get({"Inventory", "Items"})
        if not inventoryItems then return end
        
        local secretNames = {}
        
        for _, itemData in ipairs(inventoryItems) do
            local itemInfo = GetItemInfo(itemData.Id)
            local rarity = itemInfo.Rarity
            local price = itemInfo.SellPrice or 0
            local itemName = itemInfo.Name or "Unknown"
            
            result.rarityCount[rarity] = (result.rarityCount[rarity] or 0) + 1
            result.totalValue = result.totalValue + price
            result.itemCount = result.itemCount + 1
            
            if rarity == "Secret" then
                if not secretNames[itemName] then
                    secretNames[itemName] = { count = 0, favorited = false }
                end
                secretNames[itemName].count = secretNames[itemName].count + 1
                if itemData.Favorited then
                    secretNames[itemName].favorited = true
                end
            end
        end
        
        for name, data in pairs(secretNames) do
            local displayName = data.count > 1 and (name .. " x" .. data.count) or name
            table.insert(result.secretItems, {
                name = displayName,
                rarity = "Secret",
                count = data.count,
                favorited = data.favorited
            })
        end
        
        table.sort(result.secretItems, function(a, b) return a.count > b.count end)
        
        if #result.secretItems > 15 then
            local overflow = #result.secretItems - 15
            result.secretItems = {table.unpack(result.secretItems, 1, 14)}
            table.insert(result.secretItems, { name = "+" .. overflow .. " more", rarity = "info", count = 0 })
        end
    end)
    
    return result
end

--====================================
-- AUTO FAVORITE (Filter-Based + Persisted)
--====================================
local AutoFavoriteState = {
    cache = {},
    cacheCount = 0,
    MAX_CACHE_SIZE = 500,
    thread = nil,
    running = false,
    unfavoriteThread = nil,
    unfavoriteRunning = false,
    fishConnection = nil,
    -- Mutation options (moved from standalone local to save register)
    MUTATION_OPTIONS = {
        "Shiny", "Gemstone", "Corrupt", "Galaxy", "Holographic", "Ghost",
        "Lightning", "Fairy Dust", "Gold", "Midnight", "Radioactive",
        "Stone", "Albino", "Sandy", "Acidic", "Disco", "Frozen", "Noob"
    },
}

-- Get all item names from ReplicatedStorage.Items (use data.Data.Name for parity with GetFishNameAndRarity)
local function GetAllItemNames()
    local itemNames = {}
    local itemsContainer = ReplicatedStorage:FindFirstChild("Items")
    if not itemsContainer then return {} end
    
    for _, itemObj in ipairs(itemsContainer:GetChildren()) do
        local objName = itemObj.Name
        if type(objName) == "string" and #objName >= 3 and objName:sub(1, 3) ~= "!!!" then
            -- Try to get actual item name from module data
            local ok, data = pcall(require, itemObj)
            if ok and type(data) == "table" and data.Data and data.Data.Name then
                table.insert(itemNames, data.Data.Name)
            else
                table.insert(itemNames, objName)
            end
        end
    end
    table.sort(itemNames)
    -- Remove duplicates
    local seen = {}
    local unique = {}
    for _, name in ipairs(itemNames) do
        if not seen[name] then
            seen[name] = true
            table.insert(unique, name)
        end
    end
    return unique
end

-- Get tier from FishDB (O(1) lookup from yes.lua AFv7)
local function GetTierFromFishDB(itemId)
    return FishDB[itemId]
end

-- Get mutation string from item (EXACT copy from yesbgt.lua line 248-250)
local function GetItemMutationString(item)
    if item.Metadata and item.Metadata.Shiny == true then return "Shiny" end
    return item.Metadata and item.Metadata.VariantId or ""
end

-- Get item name and rarity using runtime ItemUtility (EXACT behavior from yesbgt.lua line 210-246)
local function GetFishNameAndRarity(item)
    local name = item.Identifier or "Unknown"
    local rarity = item.Metadata and item.Metadata.Rarity or "COMMON"
    local itemID = item.Id
    
    local itemData = nil
    
    if ItemUtility and itemID then
        pcall(function()
            itemData = ItemUtility:GetItemData(itemID)
            if not itemData then
                local numericID = tonumber(item.Id) or tonumber(item.Identifier)
                if numericID then
                    itemData = ItemUtility:GetItemData(numericID)
                end
            end
        end)
    end
    
    if itemData and itemData.Data and itemData.Data.Name then
        name = itemData.Data.Name
    end
    
    if item.Metadata and item.Metadata.Rarity then
        rarity = item.Metadata.Rarity
    elseif itemData and itemData.Probability and itemData.Probability.Chance and TierUtility then
        local tierObj = nil
        pcall(function()
            tierObj = TierUtility:GetTierFromRarity(itemData.Probability.Chance)
        end)
        if tierObj and tierObj.Name then
            rarity = tierObj.Name
        end
    end
    
    return name, rarity
end

local function PruneFavoritedCache()
    if AutoFavoriteState.cacheCount > AutoFavoriteState.MAX_CACHE_SIZE then
        local count = 0
        local toRemove = math.floor(AutoFavoriteState.MAX_CACHE_SIZE / 2)
        for uuid, _ in pairs(AutoFavoriteState.cache) do
            if count < toRemove then
                AutoFavoriteState.cache[uuid] = nil
                count = count + 1
            else
                break
            end
        end
        AutoFavoriteState.cacheCount = AutoFavoriteState.cacheCount - count
        if CONFIG.DEBUG then log("Pruned " .. count .. " entries from cache") end
    end
end

local function TryFavoriteItem(uuid, itemName, rarity, retries)
    retries = retries or 0
    local MAX_RETRIES = 2
    
    local success = pcall(function()
        if Remotes.FavoriteEvent then Remotes.FavoriteEvent:FireServer(uuid) end
    end)
    
    if success then
        AutoFavoriteState.cache[uuid] = true
        AutoFavoriteState.cacheCount = AutoFavoriteState.cacheCount + 1
        if CONFIG.DEBUG then log("Favorited: " .. itemName .. " (" .. rarity .. ")") end
        return true
    elseif retries < MAX_RETRIES then
        task.wait(0.5)
        return TryFavoriteItem(uuid, itemName, rarity, retries + 1)
    else
        if CONFIG.DEBUG then log("Failed to favorite after retries: " .. itemName, "WARN") end
        return false
    end
end

-- Unified Auto-Favorite evaluation (Single-Path with OR logic)
-- Checks: Tier OR Name OR Mutation - fires ONCE if ANY match
-- Maintains yes.lua stability pattern: mark processed BEFORE action
local function EvaluateAndFavorite(item)
    if not item or not item.UUID then return false end
    
    local uuid = item.UUID
    
    -- Step 1: Skip if already processed (prevents double-firing)
    if AutoFavoriteState.cache[uuid] then return false end
    
    -- Step 2: Mark as processed IMMEDIATELY (before any logic)
    AutoFavoriteState.cache[uuid] = true
    AutoFavoriteState.cacheCount = AutoFavoriteState.cacheCount + 1
    
    -- Step 3: Skip if already favorited
    local fav = item.Favorited or item.IsFavorite
    if fav then return false end
    
    -- Step 4: Get filter settings
    local rarities = SavedSettings.autoFavoriteRarities or {}
    local names = SavedSettings.autoFavoriteItemNames or {}
    local mutations = SavedSettings.autoFavoriteMutations or {}
    
    -- If no filters configured, skip
    if #rarities == 0 and #names == 0 and #mutations == 0 then
        return false
    end
    
    local shouldFavorite = false
    local matchReason = ""
    
    -- Check 1: TIER (fastest - O(1) FishDB lookup)
    if not shouldFavorite and #rarities > 0 then
        local tier = GetTierFromFishDB(item.Id)
        if tier then
            for _, r in ipairs(rarities) do
                local targetTier = TierMap[r:upper()]
                if targetTier and targetTier == tier then
                    shouldFavorite = true
                    matchReason = "Tier:" .. tostring(tier)
                    break  -- Early exit on first match
                end
            end
        end
    end
    
    -- Check 2: NAME (only if tier didn't match)
    if not shouldFavorite and #names > 0 then
        local itemName, _ = GetFishNameAndRarity(item)
        local itemNameUpper = itemName and itemName:upper() or ""
        for _, n in ipairs(names) do
            if n:upper() == itemNameUpper then
                shouldFavorite = true
                matchReason = "Name:" .. itemName
                break  -- Early exit on first match
            end
        end
    end
    
    -- Check 3: MUTATION (only if tier and name didn't match)
    if not shouldFavorite and #mutations > 0 then
        local mutation = GetItemMutationString(item)
        if mutation and mutation ~= "" then
            for _, m in ipairs(mutations) do
                if m == mutation then
                    shouldFavorite = true
                    matchReason = "Mutation:" .. mutation
                    break  -- Early exit on first match
                end
            end
        end
    end
    
    -- Step 5: Fire ONCE if any filter matched
    if shouldFavorite then
        if CONFIG.DEBUG then
            log("[AFv8] Favoriting: " .. tostring(uuid) .. " (" .. matchReason .. ")")
        end
        pcall(function()
            if Remotes.FavoriteEvent then Remotes.FavoriteEvent:FireServer(uuid) end
        end)
        return true
    end
    
    return false
end

-- Alias for backward compatibility (used in some places)
local FavoriteIfMatchTier = EvaluateAndFavorite

-- Unified filter: OR logic (matches if ANY filter matches) - uses runtime resolution like yesbgt
local function ItemMatchesFilter(item)
    local rarities = SavedSettings.autoFavoriteRarities or {}
    local names = SavedSettings.autoFavoriteItemNames or {}
    local mutations = SavedSettings.autoFavoriteMutations or {}
    
    -- If no filters, don't match anything (same as yesbgt)
    if #rarities == 0 and #names == 0 and #mutations == 0 then
        return false
    end
    
    -- Get name and rarity using runtime resolution (like yesbgt)
    local itemName, rarity = GetFishNameAndRarity(item)
    local rarityUpper = rarity and rarity:upper() or "COMMON"
    
    -- Check rarity (case-insensitive like yesbgt L3230)
    for _, r in ipairs(rarities) do
        if r:upper() == rarityUpper then return true end
    end
    
    -- Check name
    for _, n in ipairs(names) do
        if n == itemName then return true end
    end
    
    -- Check mutation
    local mutation = GetItemMutationString(item)
    for _, m in ipairs(mutations) do
        if m == mutation then return true end
    end
    
    return false
end

local function AutoFavorite()
    if not Replion then
        if CONFIG.DEBUG then log("AutoFavorite: Replion not loaded", "WARN") end
        return 0
    end
    
    if not Replion.Client then
        log("AutoFavorite: Replion.Client not available", "WARN")
        return 0
    end
    
    if not Remotes.FavoriteEvent then
        log("AutoFavorite: FavoriteEvent not found", "WARN")
        return 0
    end
    
    -- Prune cache if too large
    PruneFavoritedCache()
    
    local favorited = 0
    local skipped = 0
    local failed = 0
    
    local success, err = pcall(function()
        local DataReplion = Replion.Client:WaitReplion("Data")
        if not DataReplion then 
            log("AutoFavorite: DataReplion timeout", "WARN")
            return 
        end
        
        local items = DataReplion:Get({"Inventory", "Items"})
        if not items or #items == 0 then 
            log("AutoFavorite: No items in inventory", "DEBUG")
            return 
        end
        
        for _, itemData in ipairs(items) do
            local uuid = itemData.UUID
            
            -- Skip already favorited (check BOTH flags like yesbgt)
            if itemData.Favorited or itemData.IsFavorite then
                skipped = skipped + 1
            elseif AutoFavoriteState.cache[uuid] then
                skipped = skipped + 1
            else
                -- Use runtime resolution via ItemMatchesFilter
                if ItemMatchesFilter(itemData) then
                    local itemName, rarity = GetFishNameAndRarity(itemData)
                    if TryFavoriteItem(uuid, itemName, rarity) then
                        favorited = favorited + 1
                    else
                        failed = failed + 1
                    end
                    task.wait(0.5)
                end
            end
        end
    end)
    
    if not success then
        log("AutoFavorite error: " .. tostring(err), "ERROR")
    end
    
    if favorited > 0 or failed > 0 then
        log("AutoFavorite: " .. favorited .. " done, " .. failed .. " failed, " .. skipped .. " skipped")
    end
    
    return favorited
end

-- Initial scan: favorite all matching items in inventory
-- Uses unified EvaluateAndFavorite (Tier OR Name OR Mutation)
local function InitialFavoriteScan()
    if not Replion or not Replion.Client then return end
    
    pcall(function()
        local DataReplion = Replion.Client:WaitReplion("Data")
        if not DataReplion then return end
        
        local inv = DataReplion:Get("Inventory")
        if not inv or not inv.Items then return end
        
        if CONFIG.DEBUG then log("[AFv8] InitialScan starting...") end
        
        local count = 0
        for _, item in pairs(inv.Items) do
            -- Unified evaluation (Tier OR Name OR Mutation)
            if EvaluateAndFavorite(item) then
                count = count + 1
            end
        end
        
        if CONFIG.DEBUG then log("[AFv8] InitialScan complete: " .. count .. " favorited") end
    end)
end

local function StartAutoFavorite()
    if AutoFavoriteState.running then return end
    AutoFavoriteState.running = true
    
    -- FIX from yes.lua: RESET CACHE SETIAP DI-ON (clean state)
    AutoFavoriteState.cache = {}
    AutoFavoriteState.cacheCount = 0
    
    if CONFIG.DEBUG then log("[AFv8] Auto Favorite ENABLED") end
    
    -- Initial scan once (from yes.lua AFv7)
    InitialFavoriteScan()
    
    -- Event-driven trigger - instant reaction on new fish
    -- Uses unified EvaluateAndFavorite (Tier OR Name OR Mutation)
    if Remotes.ObtainedNewFish then
        AutoFavoriteState.fishConnection = Remotes.ObtainedNewFish.OnClientEvent:Connect(function(...)
            if not SavedSettings.autoFavoriteEnabled then return end
            
            if CONFIG.DEBUG then log("[AFv8] New fish obtained → scanning...") end
            
            task.defer(function()
                pcall(function()
                    local DataReplion = Replion.Client:WaitReplion("Data")
                    if not DataReplion then return end
                    
                    local inv = DataReplion:Get("Inventory")
                    if not inv or not inv.Items then return end
                    
                    -- Unified evaluation (Tier OR Name OR Mutation)
                    for _, item in pairs(inv.Items) do
                        EvaluateAndFavorite(item)
                    end
                end)
            end)
        end)
    end
    
    -- Fallback polling loop (defensive)
    AutoFavoriteState.thread = task.spawn(function()
        while AutoFavoriteState.running do
            if SavedSettings.autoFavoriteEnabled then
                PruneFavoritedCache()
                -- Unified evaluation (Tier OR Name OR Mutation)
                pcall(function()
                    local DataReplion = Replion.Client:WaitReplion("Data")
                    if not DataReplion then return end
                    local inv = DataReplion:Get("Inventory")
                    if not inv or not inv.Items then return end
                    for _, item in pairs(inv.Items) do
                        EvaluateAndFavorite(item)
                    end
                end)
            end
            task.wait(5) -- Reduced polling (event-driven handles most cases)
        end
    end)
end

local function StopAutoFavorite()
    AutoFavoriteState.running = false
    
    -- Disconnect event listener (from yes.lua AFv7)
    if AutoFavoriteState.fishConnection then
        pcall(function() AutoFavoriteState.fishConnection:Disconnect() end)
        AutoFavoriteState.fishConnection = nil
    end
    
    if AutoFavoriteState.thread then
        pcall(function() task.cancel(AutoFavoriteState.thread) end)
        AutoFavoriteState.thread = nil
    end
    
    -- FIX from yes.lua: RESET CACHE SETIAP DI-OFF (clean state)
    AutoFavoriteState.cache = {}
    AutoFavoriteState.cacheCount = 0
    
    if CONFIG.DEBUG then log("[AFv8] Auto Favorite DISABLED") end
end

-- AutoUnfavorite: unfavorite items that match filter and ARE favorited
local function AutoUnfavorite()
    if not Replion or not Replion.Client or not Remotes.FavoriteEvent then return 0 end
    
    local unfavorited = 0
    
    pcall(function()
        local DataReplion = Replion.Client:WaitReplion("Data")
        if not DataReplion then return end
        
        local items = DataReplion:Get({"Inventory", "Items"})
        if not items or #items == 0 then return end
        
        for _, itemData in ipairs(items) do
            -- Only process already favorited items (check BOTH flags like yesbgt)
            if not (itemData.Favorited or itemData.IsFavorite) then continue end
            
            local uuid = itemData.UUID
            if type(uuid) ~= "string" or #uuid < 10 then continue end
            
            -- Unfavorite if matches filter (using runtime resolution)
            if ItemMatchesFilter(itemData) then
                pcall(function() if Remotes.FavoriteEvent then Remotes.FavoriteEvent:FireServer(uuid) end end)
                unfavorited = unfavorited + 1
                task.wait(0.5)
            end
        end
    end)
    
    if unfavorited > 0 and CONFIG.DEBUG then
        log("AutoUnfavorite: " .. unfavorited .. " items unfavorited")
    end
    
    return unfavorited
end

local function StartAutoUnfavorite()
    if AutoFavoriteState.unfavoriteRunning then return end
    
    -- Mutual exclusion: stop favorite if running
    if AutoFavoriteState.running then
        StopAutoFavorite()
        SavedSettings.autoFavoriteEnabled = false
        SaveSettings()
    end
    
    AutoFavoriteState.unfavoriteRunning = true
    
    AutoFavoriteState.unfavoriteThread = task.spawn(function()
        while AutoFavoriteState.unfavoriteRunning do
            if SavedSettings.autoUnfavoriteEnabled then
                AutoUnfavorite()
            end
            task.wait(1)
        end
    end)
end

local function StopAutoUnfavorite()
    AutoFavoriteState.unfavoriteRunning = false
    if AutoFavoriteState.unfavoriteThread then
        pcall(function() task.cancel(AutoFavoriteState.unfavoriteThread) end)
        AutoFavoriteState.unfavoriteThread = nil
    end
end

--====================================
-- FPS BOOST (Toggle + Persisted)
--====================================
-- FPS Boost state merged into CONFIG to save registers
CONFIG.fpsBoostActive = false
CONFIG.originalLighting = {}

local function ApplyFpsBoost(enabled)
    CONFIG.fpsBoostActive = enabled
    
    -- Guard: Ensure Lighting service is available
    local Lighting = Services.Lighting
    if not Lighting then return end
    
    if enabled then
        -- Save original values once
        if not next(CONFIG.originalLighting) then
            CONFIG.originalLighting.GlobalShadows = Lighting.GlobalShadows
            CONFIG.originalLighting.FogEnd = Lighting.FogEnd
            CONFIG.originalLighting.Brightness = Lighting.Brightness
            CONFIG.originalLighting.ClockTime = Lighting.ClockTime
            CONFIG.originalLighting.Ambient = Lighting.Ambient
            CONFIG.originalLighting.OutdoorAmbient = Lighting.OutdoorAmbient
        end
        
        -- Disable effects
        pcall(function()
            for _, v in pairs(Services.Workspace:GetDescendants()) do
                if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") then
                    v.Enabled = false
                elseif v:IsA("Beam") or v:IsA("Light") then
                    v.Enabled = false
                elseif v:IsA("Decal") or v:IsA("Texture") then
                    v.Transparency = 1
                end
            end
        end)
        
        -- Lighting adjustments
        pcall(function()
            for _, effect in pairs(Lighting:GetChildren()) do
                if effect:IsA("PostEffect") then effect.Enabled = false end
            end
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 9e9
            Lighting.Brightness = 3
            Lighting.ClockTime = 14
            Lighting.Ambient = Color3.fromRGB(128, 128, 128)
            Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
        end)
        
        -- Terrain
        if Services.Workspace.Terrain then
            pcall(function()
                Services.Workspace.Terrain.WaterWaveSize = 0
                Services.Workspace.Terrain.WaterWaveSpeed = 0
                Services.Workspace.Terrain.WaterReflectance = 0
                Services.Workspace.Terrain.WaterTransparency = 1
            end)
        end
        
        -- Quality settings
        pcall(function()
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        end)
        pcall(function() gcinfo() end)
    else
        -- Restore
        pcall(function()
            if CONFIG.originalLighting.GlobalShadows ~= nil then
                Lighting.GlobalShadows = CONFIG.originalLighting.GlobalShadows
                Lighting.FogEnd = CONFIG.originalLighting.FogEnd
                Lighting.Brightness = CONFIG.originalLighting.Brightness
                Lighting.ClockTime = CONFIG.originalLighting.ClockTime
                Lighting.Ambient = CONFIG.originalLighting.Ambient
                Lighting.OutdoorAmbient = CONFIG.originalLighting.OutdoorAmbient
            end
            settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
            for _, effect in pairs(Lighting:GetChildren()) do
                if effect:IsA("PostEffect") then effect.Enabled = true end
            end
        end)
    end
end

--====================================
-- UTILITY FEATURES (from inspired/yesbgt.lua)
--====================================

-- UI Feature States (consolidated to save locals)
local UIStates = {
    HideNotif = { connection = nil },
    NoAnimation = { active = false, originalAnimateEnabled = nil, charConnection = nil },
    Cutscene = { enabled = false, remote = nil, connection = nil },
    VFX = { enabled = false, controller = nil, originalHandle = nil },
    Zoom = { enabled = false, originalMax = nil, connection = nil },
}

local function ApplyHideNotifications(state)
    local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not PlayerGui then return end
    
    local SmallNotification = PlayerGui:FindFirstChild("Small Notification")
    if not SmallNotification then
        SmallNotification = PlayerGui:WaitForChild("Small Notification", 5)
        if not SmallNotification then return end
    end
    
    if state then
        -- Set once, then use property listener to catch game re-enabling
        SmallNotification.Enabled = false
        if UIStates.HideNotif.connection then UIStates.HideNotif.connection:Disconnect() end
        UIStates.HideNotif.connection = SmallNotification:GetPropertyChangedSignal("Enabled"):Connect(function()
            if SavedSettings.hideNotifications and SmallNotification.Enabled then
                SmallNotification.Enabled = false
            end
        end)
    else
        if UIStates.HideNotif.connection then
            UIStates.HideNotif.connection:Disconnect()
            UIStates.HideNotif.connection = nil
        end
        SmallNotification.Enabled = true
    end
end

local function DisableAnimations()
    local character = LocalPlayer.Character
    if not character then return end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    
    -- 1. Disable 'Animate' script
    local animateScript = character:FindFirstChild("Animate")
    if animateScript and animateScript:IsA("LocalScript") then
        UIStates.NoAnimation.originalAnimateEnabled = animateScript.Enabled
        animateScript.Enabled = false
    end
    
    -- 2. Destroy Animator to prevent all animations
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if animator then
        animator:Destroy()
    end
    
    -- 3. Stop all playing animations
    for _, track in pairs(humanoid:GetPlayingAnimationTracks()) do
        track:Stop()
    end
end

local function EnableAnimations()
    local character = LocalPlayer.Character
    if not character then return end
    
    -- 1. Restore 'Animate' script
    local animateScript = character:FindFirstChild("Animate")
    if animateScript and UIStates.NoAnimation.originalAnimateEnabled ~= nil then
        animateScript.Enabled = UIStates.NoAnimation.originalAnimateEnabled
    end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    
    -- 2. Recreate Animator if missing
    local existingAnimator = humanoid:FindFirstChildOfClass("Animator")
    if not existingAnimator then
        Instance.new("Animator").Parent = humanoid
    end
    UIStates.NoAnimation.originalAnimateEnabled = nil
end

local function ApplyNoAnimation(state)
    UIStates.NoAnimation.active = state
    
    if state then
        DisableAnimations()
        -- Connect to CharacterAdded for respawn
        if not UIStates.NoAnimation.charConnection then
            UIStates.NoAnimation.charConnection = LocalPlayer.CharacterAdded:Connect(function()
                if UIStates.NoAnimation.active then
                    task.wait(0.2)
                    DisableAnimations()
                end
            end)
        end
    else
        EnableAnimations()
        if UIStates.NoAnimation.charConnection then
            UIStates.NoAnimation.charConnection:Disconnect()
            UIStates.NoAnimation.charConnection = nil
        end
    end
end

local function SetupBlockCutscene()
    pcall(function()
        UIStates.Cutscene.remote = Net:WaitForChild("RE/ReplicateCutscene", 5)
        if UIStates.Cutscene.remote then
            UIStates.Cutscene.connection = UIStates.Cutscene.remote.OnClientEvent:Connect(function(rarity, player, position, fishName, data)
                if UIStates.Cutscene.enabled then
                    if CONFIG.DEBUG then log("[Cutscene] Blocked: " .. tostring(fishName)) end
                    return nil
                end
            end)
        end
    end)
end

local function ApplyBlockCutscene(state)
    UIStates.Cutscene.enabled = state
    -- Setup connection if not already done
    if not UIStates.Cutscene.connection then
        SetupBlockCutscene()
    end
end

local function SetupVFXController()
    pcall(function()
        local Controllers = ReplicatedStorage:FindFirstChild("Controllers")
        if Controllers then
            local vfxModule = Controllers:FindFirstChild("VFXController")
            if vfxModule then
                UIStates.VFX.controller = require(vfxModule)
                if UIStates.VFX.controller and UIStates.VFX.controller.Handle then
                    UIStates.VFX.originalHandle = UIStates.VFX.controller.Handle
                end
            end
        end
    end)
end

local function ApplyRemoveSkinEffect(state)
    UIStates.VFX.enabled = state
    
    -- Setup if not done
    if not UIStates.VFX.controller then
        SetupVFXController()
    end
    
    if not UIStates.VFX.controller then return end
    
    if state then
        -- Block VFX functions
        UIStates.VFX.controller.Handle = function(...) end
        pcall(function() UIStates.VFX.controller.RenderAtPoint = function(...) end end)
        pcall(function() UIStates.VFX.controller.RenderInstance = function(...) end end)
        
        -- Clear existing cosmetics
        local cosmeticFolder = Services.Workspace:FindFirstChild("CosmeticFolder")
        if cosmeticFolder then
            pcall(function() cosmeticFolder:ClearAllChildren() end)
        end
    else
        -- Restore original
        if UIStates.VFX.originalHandle then
            UIStates.VFX.controller.Handle = UIStates.VFX.originalHandle
        end
    end
end

local function ApplyInfiniteZoom(state)
    UIStates.Zoom.enabled = state
    
    if state then
        -- Save original
        UIStates.Zoom.originalMax = LocalPlayer.CameraMaxZoomDistance
        LocalPlayer.CameraMaxZoomDistance = 100000
        
        -- Throttled backup loop (game may reset it) - check every 2s instead of 60/s
        if UIStates.Zoom.connection then UIStates.Zoom.connection:Disconnect() end
        local lastZoomCheck = 0
        UIStates.Zoom.connection = RunService.Heartbeat:Connect(function()
            local now = tick()
            if now - lastZoomCheck < 2 then return end
            lastZoomCheck = now
            if LocalPlayer.CameraMaxZoomDistance ~= 100000 then
                LocalPlayer.CameraMaxZoomDistance = 100000
            end
        end)
    else
        if UIStates.Zoom.connection then
            UIStates.Zoom.connection:Disconnect()
            UIStates.Zoom.connection = nil
        end
        LocalPlayer.CameraMaxZoomDistance = UIStates.Zoom.originalMax or 128
    end
end

--====================================
-- DISCONNECT DETECTION
--====================================
-- DisconnectTypes consolidated into CONFIG
CONFIG.DisconnectTypes = {
    KICK = "kicked",
    TELEPORT_FAIL = "teleport_failed",
    CONNECTION_LOST = "connection_lost",
    NO_CHARACTER = "no_character",
    DEAD = "dead",
    AFK = "afk_kicked",
    UNKNOWN = "unknown"
}

local function DetectDisconnectReason()
    local char = LocalPlayer.Character
    if not char or not char.Parent then
        return CONFIG.DisconnectTypes.NO_CHARACTER
    end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return CONFIG.DisconnectTypes.NO_CHARACTER
    end
    
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Health <= 0 then
        return CONFIG.DisconnectTypes.DEAD
    end
    
    local dataConnected = true
    pcall(function()
        if Replion and Replion.Client then
            local data = Replion.Client:WaitReplion("Data")
            if not data then dataConnected = false end
        end
    end)
    
    if not dataConnected then
        return CONFIG.DisconnectTypes.CONNECTION_LOST
    end
    
    return nil
end

local function IsConnected()
    local reason = DetectDisconnectReason()
    if reason then
        State.disconnectReason = reason
        State.connectionStatus = reason
        return false
    end
    State.disconnectReason = nil
    State.connectionStatus = "connected"
    return true
end

--====================================
-- ANTI-AFK
--====================================
local function SetupAntiAFK()
    pcall(function()
        for _, v in next, getconnections(LocalPlayer.Idled) do
            v:Disable()
        end
    end)
    
    RegisterConnection(LocalPlayer.Idled:Connect(function()
        pcall(function()
            VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            task.wait(0.5)
            VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        end)
    end))
end

--====================================
-- HEARTBEAT FUNCTIONS
--====================================
local function GetHeartbeatInfo()
    local isConnected = IsConnected()
    
    local info = {
        username = CONFIG.Username,
        userId = CONFIG.UserId,
        displayName = LocalPlayer.DisplayName or CONFIG.Username,
        status = isConnected and "online" or State.connectionStatus,
        inGame = isConnected,
        connectionStatus = State.connectionStatus,
        disconnectReason = State.disconnectReason,
        gameId = CONFIG.PlaceId,
        serverId = CONFIG.JobId,
        fishingActive = State.fishingRunning,
        timestamp = os.time(),
        timestampISO = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }
    
    pcall(function()
        info.gameName = game:GetService("MarketplaceService"):GetProductInfo(CONFIG.PlaceId).Name
    end)
    
    if isConnected then
        pcall(function()
            local char = LocalPlayer.Character
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    info.position = {
                        x = math.floor(hrp.Position.X),
                        y = math.floor(hrp.Position.Y),
                        z = math.floor(hrp.Position.Z)
                    }
                end
            end
        end)
    end
    
    return info
end

local function SendHeartbeat()
    local info = GetHeartbeatInfo()
    local path = "accounts/" .. CONFIG.Username .. "/roblox"
    
    if firebasePatch(path, info) then
        State.lastHeartbeat = os.time()
        if CONFIG.DEBUG then log("Heartbeat sent") end
        return true
    end
    return false
end

local function SendBackpack()
    local data = ScanBackpack()
    local path = "accounts/" .. CONFIG.Username .. "/backpack"
    
    if firebasePut(path, data) then
        State.lastBackpack = os.time()
        if CONFIG.DEBUG then log("Backpack: " .. data.itemCount .. " items, " .. #data.secretItems .. " secrets") end
        return true
    end
    return false
end

--====================================
-- FISHING FUNCTIONS
--====================================
local function ForceStep123()
    task.spawn(function()
        pcall(function()
            if Remotes.RF_Cancel then Remotes.RF_Cancel:InvokeServer() end
            if Remotes.RF_Charge then Remotes.RF_Charge:InvokeServer({ [1] = { os.clock() } }) end
            if Remotes.RF_Request then Remotes.RF_Request:InvokeServer(1, 0, os.clock()) end
        end)
    end)
end

local function ForceStep4()
    task.spawn(function()
        pcall(function()
            if Remotes.RE_Complete then Remotes.RE_Complete:FireServer() end
        end)
    end)
end

local function ForceCancel()
    task.spawn(function()
        pcall(function()
            if Remotes.RF_Cancel then Remotes.RF_Cancel:InvokeServer() end
        end)
    end)
end

--====================================
-- MAIN LOOPS
--====================================

-- Fishing Loop
task.spawn(function()
    while true do
        -- Sleep longer when not running to save CPU
        if not State.fishingRunning then
            task.wait(2) -- Reduced from 0.5s to save CPU when idle
            continue
        end
        
        task.wait() -- ~0.03s when active
        local now = os.clock()
        
        if State.phase == "STEP123" then
            ForceStep123()
            State.lastStep123 = now
            State.phase = "WAIT_COMPLETE"
        end
        
        if State.phase == "WAIT_COMPLETE" and (now - State.lastStep123) >= CONFIG.COMPLETE_DELAY then
            State.phase = "STEP4"
        end
        
        if State.phase == "STEP4" then
            ForceStep4()
            State.lastStep4 = now
            State.phase = "WAIT_CANCEL"
        end
        
        if State.phase == "WAIT_CANCEL" and (now - State.lastStep4) >= CONFIG.CANCEL_DELAY then
            State.phase = "STEP123"
        end
    end
end)

-- Forward declaration
local StopHeartbeat

-- Heartbeat Loop
local function StartHeartbeat()
    if State.heartbeatRunning then
        log("Heartbeat already running", "WARN")
        return
    end
    
    State.heartbeatRunning = true
    log("Starting heartbeat for " .. CONFIG.Username)
    
    BuildItemDatabase()
    SetupAntiAFK()
    
    SendHeartbeat()
    SendBackpack()
    
    -- Start AutoFavorite thread if enabled
    if SavedSettings.autoFavoriteEnabled then
        StartAutoFavorite()
    end
    
    task.spawn(function()
        while State.heartbeatRunning do
            local now = os.time()
            local connected = IsConnected()
            
            if not connected then
                log("Disconnected: " .. tostring(State.disconnectReason), "WARN")
                SendHeartbeat()
                task.wait(3)
            else
                if now - State.lastHeartbeat >= CONFIG.HEARTBEAT_INTERVAL then
                    SendHeartbeat()
                end
                
                if now - State.lastBackpack >= CONFIG.BACKPACK_INTERVAL then
                    SendBackpack()
                end
                
                -- AutoFavorite now runs in its own thread, no periodic call needed
            end
            
            task.wait(1)
        end
    end)
    
    RegisterConnection(Players.PlayerRemoving:Connect(function(player)
        if player == LocalPlayer then
            StopHeartbeat()
        end
    end))
    
    LocalPlayer.OnTeleport:Connect(function(state)
        if state == Enum.TeleportState.Started then
            firebasePatch("accounts/" .. CONFIG.Username .. "/roblox", {
                status = "teleporting",
                timestamp = os.time()
            })
        elseif state == Enum.TeleportState.Failed then
            State.disconnectReason = CONFIG.DisconnectTypes.TELEPORT_FAIL
            -- Teleport failed, just log it
            log("Teleport failed", "WARN")
        end
    end)
end

StopHeartbeat = function()
    if not State.heartbeatRunning then return end
    
    State.heartbeatRunning = false
    getgenv().ZlaVeScriptRunning = false
    log("Stopping heartbeat")
    
    StopAutoFavorite()
    
    firebasePatch("accounts/" .. CONFIG.Username .. "/roblox", {
        inGame = false,
        status = "offline",
        timestamp = os.time(),
        timestampISO = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    
    CleanupConnections()
    AutoFavoriteState.cache = {}
    AutoFavoriteState.cacheCount = 0
end

--====================================
-- TELEPORT LOCATIONS (stored in CONFIG to save registers)
--====================================
CONFIG.TELEPORT_LOCATIONS = {
    ["Fisherman Island"] = CFrame.new(34, 26, 2776),
    ["Jungle"] = CFrame.new(1483, 11, -300),
    ["Ancient Ruin"] = CFrame.new(6052, -586, 4715),
    ["Crater Island"] = CFrame.new(991, 21, 5059),
    ["Christmas Island"] = CFrame.new(1135, 24, 1563),
    ["Christmas Cafe"] = CFrame.new(580, -581, 8930),
    ["Kohana"] = CFrame.new(-635, 16, 603),
    ["Volcano"] = CFrame.new(-597, 59, 106),
    ["Esetoric Depth"] = CFrame.new(3203, -1303, 1415),
    ["Sisyphus Statue"] = CFrame.new(-3712, -135, -1013),
    ["Treasure"] = CFrame.new(-3566, -279, -1681),
    ["Tropical"] = CFrame.new(-2093, 6, 3699),
    ["First Altar"] = CFrame.new(3240, -1301, 1397),
    ["Second Altar"] = CFrame.new(1479, 128, -603),
}
CONFIG.selectedTeleport = "Fisherman Island"

--====================================
-- EVENT AUTO-JOIN SYSTEM (from yes.lua & yesbgt.lua)
--====================================

-- Event State (consolidated to reduce registers)
local EventState = {
    savedPosition = nil,         -- {Pos, Look} saved before event teleport
    christmasCaveActive = false,
    christmasCaveStartUTC = 0,
    lochnessActive = false,
    christmasCaveConn = nil,
    lochnessConn = nil,
    isInEventZone = false,       -- Anti-loop: true when at event location
    initialLoadDone = false,     -- Prevent duplicate initial TP
    -- Consolidated constants
    COORDS = {
        ChristmasCave = Vector3.new(570, -581, 8933),
        Lochness = Vector3.new(6063.347, -585.925, 4713.696),
    },
    BASE_POINTS = {
        ["None"] = nil,
        ["Crater Island"] = Vector3.new(991, 21, 5059),
        ["Kohana"] = Vector3.new(-616, 3, 567),
        ["Christmas Island"] = Vector3.new(1154, 23, 1573),
        ["Ancient Ruin"] = Vector3.new(6052, -586, 4715),
    },
    CHRISTMAS_HOURS = {
        [0]=true, [2]=true, [4]=true, [6]=true,
        [8]=true, [10]=true, [12]=true,
        [14]=true, [16]=true, [18]=true,
        [20]=true, [22]=true,
    },
    CHRISTMAS_DURATION = 30 * 60, -- 30 minutes
    RUIN_DOOR = nil,
    -- v2.9: Object-based cave detection
    caveActiveSince = nil,       -- tick() when cave became active
    caveLastState = "unknown",   -- "active"|"closed"|"loading"
    caveDebugDumped = false,     -- one-time debug dump
    -- v3.0: New Years Whale (nested to save registers)
    NewYearsWhale = {
        enabled = false,
        platform = nil,
        lastTeleportAt = 0,
        lastEventCF = nil,
        statusText = "Idle",
        connection = nil,
        uiParagraph = nil,
        TELEPORT_COOLDOWN = 3,    -- seconds
        MOVE_THRESHOLD = 5,       -- studs
        PLATFORM_OFFSET_Y = 4,    -- studs below teleport destination
        TELEPORT_OFFSET_Y = 10,   -- studs above event for teleport
        -- v3.0.1: Streaming-safe caching
        cachedCFrame = nil,       -- last known event CFrame (persists during stream-out)
        cachedCountdown = nil,    -- last known countdown text
        lastSeenAt = 0,           -- tick() when event was last visible
        MISSING_GRACE_SECONDS = 30, -- how long to use cache before "not found"
        -- v3.0.2: Fisherman Island staging
        FISHERMAN_CFRAME = CFrame.new(34, 26, 2776),
        stagingPhase = false,     -- true when staging at Fisherman Island
        lastStagingAt = 0,        -- tick() of last staging teleport
        STAGING_COOLDOWN = 10,    -- seconds between staging attempts
        platformLockedY = nil,    -- locked Y position for stable platform
        -- v3.0.4: Rotation staging support
        rotationStagingAt = 0,    -- tick() of rotation-triggered staging
        rotationAttempts = 0,     -- consecutive staging attempts by rotation
        MAX_ROTATION_ATTEMPTS = 3, -- max attempts before allowing rotation skip
        ROTATION_STAGING_GRACE = 15, -- seconds to wait for event after staging
        -- v3.0.5: Rotation assist mode (delegation)
        assistMode = false,       -- true when rotation started the monitor
        assistStartedAt = 0,      -- tick() when assist was started
        ASSIST_TIMEOUT = 60,      -- seconds before assist gives up
    },
}

-- Try to find ancient ruin door
pcall(function()
    EventState.RUIN_DOOR = Services.Workspace:FindFirstChild("RUIN INTERACTIONS") and Services.Workspace["RUIN INTERACTIONS"]:FindFirstChild("Door")
end)

--====================================
-- CHRISTMAS CAVE OBJECT-BASED DETECTION (v2.9)
-- Stored as methods on EventState to save registers
--====================================
-- Safe finder: returns nil if any part of chain missing
EventState.FindCavernTeleporter = function()
    local map = Services.Workspace:FindFirstChild("Map")
    if not map then return nil end
    local cavern = map:FindFirstChild("CavernTeleporter")
    if not cavern then return nil end
    return cavern:FindFirstChild("StartTeleport")
end

-- Check if ProximityPrompt exists (event running indicator)
EventState.HasChristmasCavePrompt = function()
    local startTeleport = EventState.FindCavernTeleporter()
    if not startTeleport then return false end
    local teleportPrompt = startTeleport:FindFirstChild("TELEPORT_PROMPT")
    if not teleportPrompt then return false end
    return teleportPrompt:FindFirstChild("ProximityPrompt") ~= nil
end

-- Get label text from cave teleporter GUI
EventState.GetChristmasCaveLabelText = function()
    local startTeleport = EventState.FindCavernTeleporter()
    if not startTeleport then return nil end
    local gui = startTeleport:FindFirstChild("Gui")
    if not gui then return nil end
    local frame = gui:FindFirstChild("Frame")
    if not frame then return nil end
    local label = frame:FindFirstChild("NewLabel")
    if not label then return nil end
    return label.Text
end

-- Main detector: returns {isActive, state, timeLeftSeconds}
-- state: "active" | "closed" | "loading"
EventState.GetChristmasCaveStatus = function()
    local labelText = EventState.GetChristmasCaveLabelText()
    local hasPrompt = EventState.HasChristmasCavePrompt()
    
    -- Priority 1: Label explicitly says CLOSED
    if labelText and string.find(labelText, "CAVE CLOSED") then
        return {
            isActive = false,
            state = "closed",
            timeLeftSeconds = nil
        }
    end
    
    -- Priority 2: Label says Christmas Cave
    if labelText and string.find(labelText, "Christmas Cave") then
        local timeLeft = nil
        if EventState.caveActiveSince then
            local elapsed = tick() - EventState.caveActiveSince
            timeLeft = math.max(0, 1800 - elapsed) -- 30 min = 1800s
        end
        return {
            isActive = true,
            state = "active",
            timeLeftSeconds = timeLeft
        }
    end
    
    -- Priority 3: Prompt exists (fallback indicator)
    if hasPrompt then
        local timeLeft = nil
        if EventState.caveActiveSince then
            local elapsed = tick() - EventState.caveActiveSince
            timeLeft = math.max(0, 1800 - elapsed)
        end
        return {
            isActive = true,
            state = "active",
            timeLeftSeconds = timeLeft
        }
    end
    
    -- Priority 4: Objects not loaded / unknown
    if not labelText and not EventState.FindCavernTeleporter() then
        return {
            isActive = false,
            state = "loading",
            timeLeftSeconds = nil
        }
    end
    
    -- Default: closed
    return {
        isActive = false,
        state = "closed",
        timeLeftSeconds = nil
    }
end

--====================================
-- NEW YEARS WHALE METHODS (v3.0) - stored on EventState to save registers
--====================================
-- Get the 2026 Event instance safely
EventState.NewYearsWhale.GetEventInstance = function()
    local locations = Services.Workspace:FindFirstChild("Locations")
    if not locations then return nil end
    return locations:FindFirstChild("2026 Event")
end

-- Get event CFrame (handles both Part and Model)
EventState.NewYearsWhale.GetEventCFrame = function()
    local event = EventState.NewYearsWhale.GetEventInstance()
    if not event then return nil end
    if event:IsA("BasePart") then return event.CFrame end
    if event:IsA("Model") then return event:GetPivot() end
    -- Fallback: try PrimaryPart
    if event:IsA("Model") and event.PrimaryPart then
        return event.PrimaryPart.CFrame
    end
    return nil
end

-- Get countdown text from event GUI
EventState.NewYearsWhale.GetCountdown = function()
    local event = EventState.NewYearsWhale.GetEventInstance()
    if not event then return nil end
    local tag = event:FindFirstChild("Tag")
    if not tag then return nil end
    local frame = tag:FindFirstChild("Frame")
    if not frame then return nil end
    local countdown = frame:FindFirstChild("Countdown")
    if not countdown then return nil end
    local label1 = countdown:FindFirstChild("Label")
    if not label1 then return nil end
    local label2 = label1:FindFirstChild("Label")
    if not label2 then return nil end
    return label2.Text
end

-- Create anchored invisible platform (idempotent)
EventState.NewYearsWhale.CreatePlatform = function()
    -- Check if platform exists AND is still parented (not destroyed)
    local existing = EventState.NewYearsWhale.platform
    if existing and existing.Parent then return existing end
    
    -- Clean up reference if platform was destroyed externally
    if existing and not existing.Parent then
        EventState.NewYearsWhale.platform = nil
    end
    
    local platform = Instance.new("Part")
    platform.Name = "NewYearsWhalePlatform"
    platform.Anchored = true
    platform.CanCollide = true
    platform.Size = Vector3.new(16, 2, 16)
    platform.Material = Enum.Material.SmoothPlastic
    platform.Transparency = 1  -- Invisible
    platform.CastShadow = false
    platform.CanQuery = false  -- Don't interfere with raycasts
    platform.Parent = Services.Workspace
    EventState.NewYearsWhale.platform = platform
    return platform
end

-- Position platform at specific world coordinates (called on teleport, not every tick)
EventState.NewYearsWhale.SetPlatformPosition = function(worldX, worldY, worldZ)
    EventState.NewYearsWhale.CreatePlatform()
    local plat = EventState.NewYearsWhale.platform
    if not plat or not plat.Parent then return end
    
    -- Lock the Y position and set platform there
    local platformY = worldY - EventState.NewYearsWhale.PLATFORM_OFFSET_Y
    EventState.NewYearsWhale.platformLockedY = platformY
    plat.CFrame = CFrame.new(worldX, platformY, worldZ)
end

-- Update platform XZ only (keeps locked Y, prevents drift)
EventState.NewYearsWhale.UpdatePlatformXZ = function()
    local plat = EventState.NewYearsWhale.platform
    if not plat or not plat.Parent then
        EventState.NewYearsWhale.CreatePlatform()
        plat = EventState.NewYearsWhale.platform
        if not plat then return end
    end
    
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    -- Keep platform under player XZ, but use locked Y (no vertical drift)
    local pos = hrp.Position
    local lockedY = EventState.NewYearsWhale.platformLockedY
    if not lockedY then
        -- If no locked Y yet, use current HRP-based Y
        lockedY = pos.Y - EventState.NewYearsWhale.PLATFORM_OFFSET_Y
        EventState.NewYearsWhale.platformLockedY = lockedY
    end
    plat.CFrame = CFrame.new(pos.X, lockedY, pos.Z)
end

-- Destroy platform
EventState.NewYearsWhale.DestroyPlatform = function()
    if EventState.NewYearsWhale.platform then
        pcall(function()
            EventState.NewYearsWhale.platform:Destroy()
        end)
        EventState.NewYearsWhale.platform = nil
    end
    EventState.NewYearsWhale.platformLockedY = nil
end

-- Update status UI
EventState.NewYearsWhale.UpdateStatus = function(text)
    EventState.NewYearsWhale.statusText = text
    if EventState.NewYearsWhale.uiParagraph then
        EventState.NewYearsWhale.uiParagraph:SetDesc("Status: " .. text)
    end
end

-- Start the whale monitor
EventState.NewYearsWhale.Start = function()
    if EventState.NewYearsWhale.connection then return end
    EventState.NewYearsWhale.enabled = true
    EventState.NewYearsWhale.stagingPhase = false
    EventState.NewYearsWhale.CreatePlatform()
    EventState.NewYearsWhale.UpdateStatus("Starting...")
    
    local RS = Services.RunService or game:GetService("RunService")
    local lastCheck = 0
    
    EventState.NewYearsWhale.connection = RS.Heartbeat:Connect(function()
        if not EventState.NewYearsWhale.enabled then return end
        
        local now = tick()
        if now - lastCheck < 0.5 then return end  -- 2 checks/sec
        lastCheck = now
        
        local state = EventState.NewYearsWhale
        
        -- Update platform XZ (maintains locked Y, no vertical drift)
        state.UpdatePlatformXZ()
        
        -- Get character
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then
            state.UpdateStatus("No character")
            return
        end
        
        -- Get event CFrame (may be nil if streamed out)
        local eventCF = state.GetEventCFrame()
        local countdown = state.GetCountdown()
        
        -- v3.0.1: Streaming-safe caching
        if eventCF then
            -- Event visible: update cache, clear staging
            state.cachedCFrame = eventCF
            state.lastSeenAt = now
            state.stagingPhase = false
        end
        if countdown then
            state.cachedCountdown = countdown
        end
        
        -- Determine effective CFrame to use
        local effectiveCF = eventCF or state.cachedCFrame
        local effectiveCountdown = countdown or state.cachedCountdown or "???"
        local isUsingCache = (not eventCF) and state.cachedCFrame
        
        -- v3.0.2: Fisherman Island staging when event not visible and no cache
        if not effectiveCF then
            -- Event never seen - need to stage at Fisherman Island to trigger replication
            local stagingCooldownOK = (now - state.lastStagingAt) > state.STAGING_COOLDOWN
            
            if stagingCooldownOK and not state.stagingPhase then
                state.stagingPhase = true
                state.lastStagingAt = now
                state.UpdateStatus("🚢 Staging at Fisherman Island...")
                
                -- Teleport to Fisherman Island
                local stagingPos = state.FISHERMAN_CFRAME.Position
                hrp.CFrame = CFrame.new(stagingPos.X, stagingPos.Y + 5, stagingPos.Z)
                
                -- Set platform at staging location
                state.SetPlatformPosition(stagingPos.X, stagingPos.Y + 5, stagingPos.Z)
                return
            elseif state.stagingPhase then
                state.UpdateStatus("🚢 Waiting for event to load...")
                return
            else
                state.UpdateStatus("Event not found. Staging in " .. 
                    math.ceil(state.STAGING_COOLDOWN - (now - state.lastStagingAt)) .. "s")
                return
            end
        end
        
        -- Event found or cached - check grace period for cache
        if isUsingCache then
            local elapsed = now - state.lastSeenAt
            if elapsed > state.MISSING_GRACE_SECONDS then
                -- Cache expired - need re-staging
                state.cachedCFrame = nil
                state.UpdateStatus("Event lost. Re-staging...")
                return
            end
        end
        
        local playerPos = hrp.Position
        local eventPos = effectiveCF.Position
        local distToEvent = (playerPos - eventPos).Magnitude
        
        -- Check if event moved significantly from last teleport position
        local eventMoved = false
        if state.lastEventCF then
            local drift = (eventPos - state.lastEventCF.Position).Magnitude
            if drift > state.MOVE_THRESHOLD then
                eventMoved = true
            end
        else
            eventMoved = true  -- First run
        end
        
        -- Teleport if: far from event OR event moved, and cooldown passed
        local needTeleport = distToEvent > 20 or eventMoved
        local cooldownOK = (now - state.lastTeleportAt) > state.TELEPORT_COOLDOWN
        
        if needTeleport and cooldownOK then
            -- Teleport above event with vertical offset
            local targetY = eventPos.Y + state.TELEPORT_OFFSET_Y
            local targetCF = CFrame.new(eventPos.X, targetY, eventPos.Z)
            hrp.CFrame = targetCF
            
            -- Set platform at teleport destination (lock Y)
            state.SetPlatformPosition(eventPos.X, targetY, eventPos.Z)
            
            state.lastTeleportAt = now
            state.lastEventCF = effectiveCF
        else
            state.lastEventCF = effectiveCF
        end
        
        -- Update status with countdown + streaming indicator
        if isUsingCache then
            state.UpdateStatus("🐋 " .. effectiveCountdown .. " (cached)")
        else
            state.UpdateStatus("🐋 Countdown: " .. effectiveCountdown)
        end
    end)
end

-- Stop the whale monitor
EventState.NewYearsWhale.Stop = function()
    local wasActive = EventState.NewYearsWhale.enabled and EventState.NewYearsWhale.cachedCFrame
    local wasAssist = EventState.NewYearsWhale.assistMode  -- v3.0.5: Track if was assist
    
    EventState.NewYearsWhale.enabled = false
    EventState.NewYearsWhale.stagingPhase = false
    EventState.NewYearsWhale.assistMode = false  -- v3.0.5: Clear assist flag
    EventState.NewYearsWhale.assistStartedAt = 0
    if EventState.NewYearsWhale.connection then
        EventState.NewYearsWhale.connection:Disconnect()
        EventState.NewYearsWhale.connection = nil
    end
    EventState.NewYearsWhale.DestroyPlatform()
    EventState.NewYearsWhale.lastEventCF = nil
    EventState.NewYearsWhale.cachedCFrame = nil
    EventState.NewYearsWhale.cachedCountdown = nil
    EventState.NewYearsWhale.lastSeenAt = 0
    EventState.NewYearsWhale.lastTeleportAt = 0
    EventState.NewYearsWhale.lastStagingAt = 0
    EventState.NewYearsWhale.UpdateStatus("Stopped")
    
    -- v3.0.3: Return to base point after disabling (only if was actively tracking)
    -- v3.0.5: Skip return-to-base if was in assist mode (rotation handles navigation)
    if wasActive and not wasAssist then
        task.delay(0.5, function()
            -- Use SmartReturnToTarget which is defined later, so we call via pcall
            local ok = pcall(function()
                SmartReturnToTarget("NewYearsWhale disabled")
            end)
            if not ok then
                -- Fallback: direct teleport to base if SmartReturnToTarget not available
                local baseName = SavedSettings.basePointName
                if baseName and baseName ~= "None" and EventState.BASE_POINTS[baseName] then
                    local char = LocalPlayer.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local basePos = EventState.BASE_POINTS[baseName]
                        hrp.CFrame = CFrame.new(basePos + Vector3.new(0, 5, 0))
                    end
                end
            end
        end)
    end
end

-- v3.0.5: Start assist mode for rotation (lightweight start without return-to-base)
EventState.NewYearsWhale.StartAssist = function()
    -- Already running (user-enabled or assist)? Just flag assist
    if EventState.NewYearsWhale.enabled then
        return true
    end
    
    EventState.NewYearsWhale.assistMode = true
    EventState.NewYearsWhale.assistStartedAt = tick()
    EventState.NewYearsWhale.Start()  -- Start the full monitor
    return true
end

-- v3.0.5: Stop assist mode (only stops if started by assist)
EventState.NewYearsWhale.StopAssist = function()
    if not EventState.NewYearsWhale.assistMode then
        return  -- Not in assist mode, don't stop user-enabled monitor
    end
    
    -- Clear assist flags first so Stop() doesn't do return-to-base
    EventState.NewYearsWhale.assistMode = false
    EventState.NewYearsWhale.assistStartedAt = 0
    
    -- Minimal cleanup: stop monitor but don't return-to-base
    EventState.NewYearsWhale.enabled = false
    EventState.NewYearsWhale.stagingPhase = false
    if EventState.NewYearsWhale.connection then
        EventState.NewYearsWhale.connection:Disconnect()
        EventState.NewYearsWhale.connection = nil
    end
    EventState.NewYearsWhale.DestroyPlatform()
    -- Keep cache intact for rotation's final teleport
    EventState.NewYearsWhale.UpdateStatus("Assist stopped")
end

-- v3.0.5: Check if cache is ready for rotation
EventState.NewYearsWhale.IsCacheReady = function()
    local cache = EventState.NewYearsWhale.cachedCFrame
    if not cache then return false end
    
    -- Check if cache is still valid (within grace period)
    local age = tick() - EventState.NewYearsWhale.lastSeenAt
    return age < EventState.NewYearsWhale.MISSING_GRACE_SECONDS
end

--====================================
-- AUTO RUIN DOOR (v2.8)
--====================================
local RuinDoorState = {
    enabled = false,
    running = false,
    thread = nil,
    fishConnection = nil,
    lastPromptFire = 0,
    lastInventoryScan = 0,
    lastTeleport = 0,
    fishingForRarity = nil, -- Current rarity we need fish for
    statusText = "Idle",
    uiParagraph = nil,
    -- Target fish for Ruin Door quest (for auto-favorite)
    TARGET_FISH = {
        ["Freshwater Piranha"] = true,
        ["Goliath Tiger"] = true,
        ["Sacred Guardian Squid"] = true,
        ["Crocodile"] = true,
    },
    -- Plate configuration: rarity -> fish name
    PLATES = {
        Rare      = { fishName = "Freshwater Piranha" },
        Epic      = { fishName = "Goliath Tiger" },
        Legendary = { fishName = "Sacred Guardian Squid" },
        Mythic    = { fishName = "Crocodile" },
    },
    RARITIES_ORDER = {"Rare", "Epic", "Legendary", "Mythic"},
    SACRED_TEMPLE_CFRAME = CFrame.new(1506, -22, -641),
    -- Cooldowns (seconds)
    PROMPT_COOLDOWN = 1.5,
    INVENTORY_COOLDOWN = 2,
    TELEPORT_COOLDOWN = 5,
    PROMPT_DISTANCE = 15, -- Max studs to fire prompt
}

-- Get the PressurePlates root folder (safe)
local function GetRuinPlatesRoot()
    local success, result = pcall(function()
        local ruinInteractions = Services.Workspace:FindFirstChild("RUIN INTERACTIONS")
        if not ruinInteractions then return nil end
        return ruinInteractions:FindFirstChild("PressurePlates")
    end)
    return success and result or nil
end

-- Check if quest is active (PressurePlates folder exists = quest started)
-- Note: Prompts may not exist yet due to streaming
local function IsRuinQuestActive()
    local root = GetRuinPlatesRoot()
    return root ~= nil
end

-- Check if any prompts have streamed in (for loading state detection)
local function HasAnyRuinPrompts()
    local root = GetRuinPlatesRoot()
    if not root then return false end
    
    local success, result = pcall(function()
        for _, rarity in ipairs(RuinDoorState.RARITIES_ORDER) do
            local plate = root:FindFirstChild(rarity)
            if plate then
                local part = plate:FindFirstChild("Part")
                if part then
                    local prompt = part:FindFirstChildOfClass("ProximityPrompt")
                    if prompt then return true end
                end
            end
        end
        return false
    end)
    return success and result or false
end

-- Get ProximityPrompt for a specific rarity plate (safe lookup)
local function GetRuinPrompt(rarity)
    local root = GetRuinPlatesRoot()
    if not root then return nil end
    
    local success, prompt = pcall(function()
        local plate = root:FindFirstChild(rarity)
        if not plate then return nil end
        
        local part = plate:FindFirstChild("Part")
        if not part then return nil end
        
        return part:FindFirstChildOfClass("ProximityPrompt")
    end)
    return success and prompt or nil
end

-- Get plate Part position for distance check
local function GetRuinPlatePosition(rarity)
    local success, pos = pcall(function()
        local path = Services.Workspace
            :FindFirstChild("RUIN INTERACTIONS")
        if not path then return nil end
        
        path = path:FindFirstChild("PressurePlates")
        if not path then return nil end
        
        path = path:FindFirstChild(rarity)
        if not path then return nil end
        
        local part = path:FindFirstChild("Part")
        if not part then return nil end
        
        return part.Position
    end)
    return success and pos or nil
end

-- Safe inventory getter for RuinDoor (self-contained, avoids forward-ref issue)
local function GetRuinDoorInventory()
    if not Replion or not Replion.Client then return nil end
    local success, result = pcall(function()
        local data = Replion.Client:WaitReplion("Data", 2)
        if not data then return nil end
        local inv = data:GetExpect("Inventory")
        return inv
    end)
    return success and result or nil
end

-- Check if specific fish is in inventory (unfavorited, ready to place)
local function HasRuinFishInInventory(fishName)
    -- Use self-contained getter (not forward-ref GetPlayerInventory)
    local inventory = GetRuinDoorInventory()
    if not inventory then return false, nil end
    
    -- Handle different inventory shapes
    local items = inventory.Items or inventory.items or inventory
    if type(items) ~= "table" then return false, nil end
    
    local success, result = pcall(function()
        for _, item in pairs(items) do
            if type(item) == "table" then
                local name, _ = GetFishNameAndRarity(item)
                if name == fishName then
                    return true, item.UUID
                end
            elseif type(item) == "string" and item == fishName then
                return true, nil
            end
        end
        return false, nil
    end)
    
    if success and type(result) == "boolean" then
        return result, nil
    elseif success and result == true then
        return true, nil
    end
    return false, nil
end

-- Fire proximity prompt safely with cooldown and distance check
local function FireRuinPromptSafe(rarity)
    local now = tick()
    
    -- Cooldown check
    if now - RuinDoorState.lastPromptFire < RuinDoorState.PROMPT_COOLDOWN then
        return false, "cooldown"
    end
    
    -- Get prompt
    local prompt = GetRuinPrompt(rarity)
    if not prompt then
        return false, "no_prompt"
    end
    
    -- Distance check
    local platePos = GetRuinPlatePosition(rarity)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    
    if not hrp or not platePos then
        return false, "no_position"
    end
    
    local distance = (hrp.Position - platePos).Magnitude
    if distance > RuinDoorState.PROMPT_DISTANCE then
        return false, "too_far"
    end
    
    -- Fire prompt
    local success = pcall(function()
        fireproximityprompt(prompt)
    end)
    
    if success then
        RuinDoorState.lastPromptFire = now
        if CONFIG.DEBUG then log("[RuinDoor] Fired prompt for " .. rarity) end
        return true, "success"
    end
    
    return false, "fire_failed"
end

-- Inline safe teleport for RuinDoor (avoids forward-ref to SafeTeleport)
local function RuinDoorTeleport(targetPos)
    local success = pcall(function()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        
        -- Direct teleport with velocity reset (same logic as SafeTeleport)
        for _ = 1, 5 do
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 2, 0))
            task.wait(0.08)
        end
    end)
    return success
end

-- Teleport to Sacred Temple for fishing
local function TeleportToSacredTemple()
    local now = tick()
    
    -- Cooldown check
    if now - RuinDoorState.lastTeleport < RuinDoorState.TELEPORT_COOLDOWN then
        return false
    end
    
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    -- Only teleport if far from Sacred Temple
    local templePos = RuinDoorState.SACRED_TEMPLE_CFRAME.Position
    local distance = (hrp.Position - templePos).Magnitude
    
    if distance > 100 then
        local success = RuinDoorTeleport(templePos)
        if success then
            RuinDoorState.lastTeleport = now
            if CONFIG.DEBUG then log("[RuinDoor] Teleported to Sacred Temple") end
            return true
        end
        return false
    end
    
    return false -- Already at temple
end

-- Teleport close to a specific plate
local function TeleportToPlate(rarity)
    local platePos = GetRuinPlatePosition(rarity)
    if not platePos then return false end
    
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    local distance = (hrp.Position - platePos).Magnitude
    if distance > RuinDoorState.PROMPT_DISTANCE then
        local success = RuinDoorTeleport(platePos)
        if success and CONFIG.DEBUG then 
            log("[RuinDoor] Teleported to " .. rarity .. " plate") 
        end
        return success
    end
    
    return false
end

-- Check if a fish name is a Ruin Door target
local function IsRuinTargetFish(fishName)
    return RuinDoorState.TARGET_FISH[fishName] == true
end

-- Auto-favorite handler for Ruin Door target fish
local function HandleRuinFishCatch()
    if not SavedSettings.autoRuinDoorEnabled then return end
    if not Replion or not Replion.Client then return end
    
    task.defer(function()
        pcall(function()
            local DataReplion = Replion.Client:WaitReplion("Data")
            if not DataReplion then return end
            
            local inv = DataReplion:Get("Inventory")
            if not inv or not inv.Items then return end
            
            -- Check recently caught items for target fish
            for _, item in pairs(inv.Items) do
                local uuid = item.UUID
                if not uuid then continue end
                
                -- Skip if already favorited
                if item.Favorited or item.IsFavorite then continue end
                
                -- Skip if already processed by AutoFavorite cache
                if AutoFavoriteState.cache[uuid] then continue end
                
                local name, _ = GetFishNameAndRarity(item)
                if IsRuinTargetFish(name) then
                    -- Mark as processed
                    AutoFavoriteState.cache[uuid] = true
                    AutoFavoriteState.cacheCount = AutoFavoriteState.cacheCount + 1
                    
                    -- Favorite it
                    pcall(function()
                        if Remotes.FavoriteEvent then
                            Remotes.FavoriteEvent:FireServer(uuid)
                        end
                    end)
                    
                    if CONFIG.DEBUG then
                        log("[RuinDoor] Favorited target fish: " .. name)
                    end
                end
            end
        end)
    end)
end

-- Update UI status
local function UpdateRuinDoorStatus(text)
    RuinDoorState.statusText = text
    if RuinDoorState.uiParagraph then
        pcall(function()
            RuinDoorState.uiParagraph:SetDesc(text)
        end)
    end
end

-- Get missing fish list (plates that still need fish)
local function GetMissingRuinFish()
    local missing = {}
    for _, rarity in ipairs(RuinDoorState.RARITIES_ORDER) do
        local prompt = GetRuinPrompt(rarity)
        if prompt then -- Plate still needs fish
            local config = RuinDoorState.PLATES[rarity]
            if config then
                local hasFish, _ = HasRuinFishInInventory(config.fishName)
                table.insert(missing, {
                    rarity = rarity,
                    fishName = config.fishName,
                    hasFish = hasFish,
                })
            end
        end
    end
    return missing
end

-- Stop Auto Ruin Door (forward declaration)
local StopAutoRuinDoor

-- Main Auto Ruin Door Loop
local function StartAutoRuinDoor()
    if RuinDoorState.running then return end
    RuinDoorState.running = true
    RuinDoorState.enabled = true
    
    if CONFIG.DEBUG then log("[RuinDoor] Starting Auto Ruin Door") end
    UpdateRuinDoorStatus("Starting...")
    
    -- Hook into fish catch event for auto-favorite
    if Remotes.ObtainedNewFish and not RuinDoorState.fishConnection then
        RuinDoorState.fishConnection = Remotes.ObtainedNewFish.OnClientEvent:Connect(function(...)
            if SavedSettings.autoRuinDoorEnabled then
                HandleRuinFishCatch()
            end
        end)
    end
    
    -- Main loop
    RuinDoorState.thread = task.spawn(function()
        while RuinDoorState.running and SavedSettings.autoRuinDoorEnabled do
            -- Check if quest is active (PressurePlates folder exists)
            if not IsRuinQuestActive() then
                UpdateRuinDoorStatus("Quest not active. Waiting...")
                RuinDoorState.fishingForRarity = nil
                task.wait(3)
                continue
            end
            
            -- Quest is active, but check if prompts have streamed in
            if not HasAnyRuinPrompts() then
                UpdateRuinDoorStatus("Quest active. Loading plates...")
                task.wait(2)
                continue
            end
            
            -- Get list of missing fish/plates
            local missing = GetMissingRuinFish()
            
            if #missing == 0 then
                UpdateRuinDoorStatus("All plates filled! Quest complete.")
                task.wait(2)
                continue
            end
            
            -- Process plates in order
            local actionTaken = false
            
            for _, entry in ipairs(missing) do
                if not RuinDoorState.running then break end
                
                local rarity = entry.rarity
                local fishName = entry.fishName
                local hasFish = entry.hasFish
                
                if hasFish then
                    -- We have the fish → try to place it
                    UpdateRuinDoorStatus("Placing " .. fishName .. " on " .. rarity .. " plate...")
                    
                    -- Move close to plate
                    TeleportToPlate(rarity)
                    task.wait(0.5)
                    
                    -- Fire prompt
                    local success, reason = FireRuinPromptSafe(rarity)
                    if success then
                        UpdateRuinDoorStatus("Placed " .. fishName .. "!")
                        actionTaken = true
                        task.wait(RuinDoorState.PROMPT_COOLDOWN)
                    else
                        if reason == "too_far" then
                            -- Try teleporting closer
                            TeleportToPlate(rarity)
                        end
                        if CONFIG.DEBUG then 
                            log("[RuinDoor] Failed to fire prompt: " .. tostring(reason)) 
                        end
                    end
                    break -- Process one plate per loop iteration
                else
                    -- Don't have fish → go fishing
                    RuinDoorState.fishingForRarity = rarity
                    UpdateRuinDoorStatus("Need " .. fishName .. " (" .. rarity .. "). Fishing...")
                    
                    -- Teleport to Sacred Temple if not there
                    TeleportToSacredTemple()
                    
                    -- Wait for fishing to produce the fish (event-driven via HandleRuinFishCatch)
                    actionTaken = true
                    break -- Wait in fishing mode
                end
            end
            
            -- Idle wait between checks
            if actionTaken then
                task.wait(1.5)
            else
                task.wait(0.5)
            end
        end
        
        UpdateRuinDoorStatus("Stopped")
        RuinDoorState.fishingForRarity = nil
    end)
end

StopAutoRuinDoor = function()
    RuinDoorState.running = false
    RuinDoorState.enabled = false
    RuinDoorState.fishingForRarity = nil
    
    -- Disconnect fish catch listener
    if RuinDoorState.fishConnection then
        pcall(function() RuinDoorState.fishConnection:Disconnect() end)
        RuinDoorState.fishConnection = nil
    end
    
    -- Cancel thread
    if RuinDoorState.thread then
        pcall(function() task.cancel(RuinDoorState.thread) end)
        RuinDoorState.thread = nil
    end
    
    UpdateRuinDoorStatus("Stopped")
    if CONFIG.DEBUG then log("[RuinDoor] Stopped Auto Ruin Door") end
end

--====================================
-- AUTO GIFT SANTA (v2.9)
--====================================
local GiftSantaState = {
    enabled = false,
    running = false,
    thread = nil,
    lastRedeemAttempt = 0,
    statusText = "Idle",
    uiParagraph = nil,
    debugDumped = false, -- One-time debug flag for inventory keys
    itemsDumped = false, -- One-time debug flag for item samples
    verifyFailDumped = false, -- One-time debug flag for verify failure
    -- Present IDs and names (same pattern as PotionState.DATA)
    PRESENT_DATA = {
        ["Common Present"] = {Id = 996},
        ["Uncommon Present"] = {Id = 997},
        ["Rare Present"] = {Id = 998},
        ["Epic Present"] = {Id = 999},
    },
    -- Reverse lookup: Id -> Name
    PRESENT_ID_TO_NAME = {
        [996] = "Common Present",
        [997] = "Uncommon Present",
        [998] = "Rare Present",
        [999] = "Epic Present",
    },
    -- Legacy name set for tool fallback
    PRESENT_NAMES = {
        ["Common Present"] = true,
        ["Uncommon Present"] = true,
        ["Rare Present"] = true,
        ["Epic Present"] = true,
    },
    REDEEM_COOLDOWN = 2,
}

-- Update UI status for Gift Santa
local function UpdateGiftSantaStatus(text)
    GiftSantaState.statusText = text
    if GiftSantaState.uiParagraph then
        pcall(function()
            GiftSantaState.uiParagraph:SetDesc(text)
        end)
    end
end

-- Check if Christmas event is active (ToyFactory exists)
local function IsChristmasEventActive()
    local success, result = pcall(function()
        return Services.Workspace:FindFirstChild("ToyFactory") ~= nil
    end)
    return success and result or false
end

-- Find a present in player's inventory (self-contained inventory access)
local function FindOwnedPresent()
    -- Get inventory directly (self-contained, avoids forward-ref to GetPlayerInventory)
    local inventory = nil
    if Replion and Replion.Client then
        local success, result = pcall(function()
            local data = Replion.Client:WaitReplion("Data", 2)
            if data then return data:GetExpect("Inventory") end
            return nil
        end)
        if success then inventory = result end
    end
    
    if inventory then
        -- One-time debug: dump inventory structure keys
        if not GiftSantaState.debugDumped then
            GiftSantaState.debugDumped = true
            if CONFIG.DEBUG then
                local keys = {}
                for k, _ in pairs(inventory) do
                    table.insert(keys, tostring(k))
                end
                log("[GiftSanta] Inventory keys: " .. table.concat(keys, ", "))
            end
        end
        
        -- Check multiple possible sub-tables where presents might be stored
        -- Presents are Type="Gears" so check Gears, Items, and root
        local searchTables = {
            {name = "Gears", tbl = inventory.Gears},
            {name = "Items", tbl = inventory.Items},
            {name = "Tools", tbl = inventory.Tools},
        }
        
        for _, search in ipairs(searchTables) do
            if search.tbl and type(search.tbl) == "table" then
                for _, item in pairs(search.tbl) do
                    if type(item) == "table" and item.Id then
                        local itemId = tonumber(item.Id)
                        local presentName = GiftSantaState.PRESENT_ID_TO_NAME[itemId]
                        if presentName then
                            if CONFIG.DEBUG then
                                log("[GiftSanta] Found present in " .. search.name .. ": " .. presentName)
                            end
                            return {Name = presentName, UUID = item.UUID, Id = itemId}, false
                        end
                    end
                end
            end
        end
        
        -- Debug: show sample items from first non-empty table
        if CONFIG.DEBUG and not GiftSantaState.itemsDumped then
            GiftSantaState.itemsDumped = true
            for _, search in ipairs(searchTables) do
                if search.tbl and type(search.tbl) == "table" then
                    local samples = {}
                    local count = 0
                    for _, item in pairs(search.tbl) do
                        if count >= 3 then break end
                        if type(item) == "table" then
                            table.insert(samples, string.format("Id=%s", tostring(item.Id)))
                            count = count + 1
                        end
                    end
                    if count > 0 then
                        log("[GiftSanta] Sample from " .. search.name .. ": " .. table.concat(samples, ", "))
                    end
                end
            end
        end
    end
    
    -- METHOD 2: Fallback - check physical Backpack/Character tools
    local char = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    
    -- Check if already equipped (physical tool in character)
    if char then
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") and GiftSantaState.PRESENT_NAMES[tool.Name] then
                return {Name = tool.Name, Tool = tool}, true -- isEquipped = true
            end
        end
    end
    
    -- Check backpack for unequipped tools
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") and GiftSantaState.PRESENT_NAMES[tool.Name] then
                return {Name = tool.Name, Tool = tool}, false -- isEquipped = false
            end
        end
    end
    
    return nil, false
end

-- Verify present is truly equipped (multi-signal: Character tools OR Replion EquippedId)
-- Stored in GiftSantaState to avoid extra local
GiftSantaState.IsPresentEquipped = function(presentUUID)
    -- Signal 1: Check Character for equipped present tool
    local char = LocalPlayer.Character
    if char then
        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("Tool") then
                -- Check exact name match
                if GiftSantaState.PRESENT_NAMES[child.Name] then
                    return true, child.Name
                end
                -- Check if tool name contains "Present" (fallback for variant names)
                if string.find(child.Name, "Present") then
                    return true, child.Name
                end
            end
        end
    end
    
    -- Signal 2: Check Replion EquippedId matches our present UUID
    if presentUUID and Replion and Replion.Client then
        local success, equippedId = pcall(function()
            local data = Replion.Client:WaitReplion("Data", 1)
            if data then return data:GetExpect("EquippedId") end
            return nil
        end)
        if success and equippedId and equippedId == presentUUID then
            return true, "via_replion"
        end
    end
    
    return false, nil
end

-- Equip a present using two-step process: EquipItem + EquipToolFromHotbar
local function EquipPresent(presentInfo)
    if not presentInfo then return false end
    
    local char = LocalPlayer.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end
    
    -- If presentInfo has a physical Tool reference, use it directly
    if presentInfo.Tool then
        local success = pcall(function()
            humanoid:EquipTool(presentInfo.Tool)
        end)
        if success and CONFIG.DEBUG then
            log("[GiftSanta] Equipped physical tool: " .. presentInfo.Name)
        end
        return success
    end
    
    -- For Replion items: use two-step equip (EquipItem + EquipToolFromHotbar)
    if not presentInfo.UUID then
        if CONFIG.DEBUG then log("[GiftSanta] No UUID for present") end
        return false
    end
    
    -- Step 1: Add item to hotbar via RE/EquipItem (category = "Gears")
    if Remotes.RE_EquipItem then
        pcall(function()
            Remotes.RE_EquipItem:FireServer(presentInfo.UUID, "Gears")
        end)
        if CONFIG.DEBUG then log("[GiftSanta] Fired EquipItem for " .. presentInfo.Name) end
        task.wait(0.3) -- Wait for server to update hotbar
    end
    
    -- Step 2: Find slot index in EquippedItems array (inline lookup)
    local slotIndex = nil
    local maxRetries = 5
    for attempt = 1, maxRetries do
        -- Inline EquippedItems lookup
        if Replion and Replion.Client then
            local success, equippedItems = pcall(function()
                local data = Replion.Client:WaitReplion("Data", 1)
                if data then return data:GetExpect("EquippedItems") end
                return nil
            end)
            if success and equippedItems and type(equippedItems) == "table" then
                for slot, slotUUID in pairs(equippedItems) do
                    if slotUUID == presentInfo.UUID then
                        slotIndex = tonumber(slot)
                        break
                    end
                end
            end
        end
        if slotIndex then break end
        task.wait(0.2)
    end
    
    if not slotIndex then
        -- Fallback: scan slots 2-8 looking for present
        if CONFIG.DEBUG then log("[GiftSanta] UUID not found in EquippedItems, trying slot scan") end
        for trySlot = 2, 8 do
            pcall(function()
                Remotes.RE_EquipToolFromHotbar:FireServer(trySlot)
            end)
            -- Retry verification with UUID for up to 0.6s
            for verifyAttempt = 1, 3 do
                task.wait(0.2)
                if GiftSantaState.IsPresentEquipped(presentInfo.UUID) then
                    if CONFIG.DEBUG then log("[GiftSanta] Found present at slot " .. trySlot) end
                    return true
                end
            end
        end
        if CONFIG.DEBUG then log("[GiftSanta] Could not find slot for present") end
        return false
    end
    
    -- Step 3: Equip from hotbar using discovered slot
    if Remotes.RE_EquipToolFromHotbar then
        pcall(function()
            Remotes.RE_EquipToolFromHotbar:FireServer(slotIndex)
        end)
        if CONFIG.DEBUG then log("[GiftSanta] Fired EquipToolFromHotbar slot " .. slotIndex) end
    end
    
    -- Verify equipped with retry (up to 1.5s for replication delay)
    for verifyAttempt = 1, 6 do
        task.wait(0.25)
        if GiftSantaState.IsPresentEquipped(presentInfo.UUID) then
            if CONFIG.DEBUG then log("[GiftSanta] Present verified equipped: " .. presentInfo.Name) end
            return true
        end
    end
    
    -- Debug dump on failure (one-time)
    if not GiftSantaState.verifyFailDumped and CONFIG.DEBUG then
        GiftSantaState.verifyFailDumped = true
        local char = LocalPlayer.Character
        local tools = {}
        if char then
            for _, child in ipairs(char:GetChildren()) do
                if child:IsA("Tool") then
                    table.insert(tools, child.Name)
                end
            end
        end
        log("[GiftSanta] Verify failed. Character tools: " .. table.concat(tools, ", "))
        log("[GiftSanta] Expected UUID: " .. tostring(presentInfo.UUID))
    end
    
    if CONFIG.DEBUG then log("[GiftSanta] Equip verification failed after retries") end
    return false
end

-- Try direct redeem (RedeemGift:InvokeServer with no args)
local function TryRedeemGift()
    -- Use cached remote from Remotes table
    if not Remotes.RF_RedeemGift then
        if CONFIG.DEBUG then log("[GiftSanta] RedeemGift remote not found") end
        return false, "no_remote"
    end
    
    -- Invoke with no args (per christmashgift.lua)
    local invokeSuccess, redeemResult = pcall(function()
        return Remotes.RF_RedeemGift:InvokeServer()
    end)
    
    if not invokeSuccess then
        if CONFIG.DEBUG then log("[GiftSanta] InvokeServer failed") end
        return false, "invoke_error"
    end
    
    if redeemResult then
        if CONFIG.DEBUG then log("[GiftSanta] Redeem successful!") end
        return true, "success"
    end
    
    return false, "redeem_failed"
end

-- Fallback: Fire DialogueEnded then retry redeem
local function TryFallbackDialogue()
    if not Remotes.RE_DialogueEnded then return false end
    
    local success = pcall(function()
        Remotes.RE_DialogueEnded:FireServer("Santa", 1, 2)
    end)
    
    if success and CONFIG.DEBUG then
        log("[GiftSanta] DialogueEnded fired")
    end
    
    return success
end

-- Forward declaration
local StopAutoGiftSanta

-- Main Auto Gift Santa loop
local function StartAutoGiftSanta()
    if GiftSantaState.running then return end
    GiftSantaState.running = true
    GiftSantaState.enabled = true
    
    if CONFIG.DEBUG then log("[GiftSanta] Starting Auto Gift Santa") end
    UpdateGiftSantaStatus("Starting...")
    
    GiftSantaState.thread = task.spawn(function()
        while GiftSantaState.running and SavedSettings.autoGiftSantaEnabled do
            -- Check if event is active
            if not IsChristmasEventActive() then
                UpdateGiftSantaStatus("Event not active (no ToyFactory)")
                task.wait(5)
                continue
            end
            
            -- Find a present
            local present, isEquipped = FindOwnedPresent()
            
            if not present then
                UpdateGiftSantaStatus("No presents in inventory. Waiting...")
                task.wait(3)
                continue
            end
            
            -- Equip if not already verified (pass UUID for multi-signal check)
            if not GiftSantaState.IsPresentEquipped(present.UUID) then
                UpdateGiftSantaStatus("Equipping " .. present.Name .. "...")
                local equipSuccess = EquipPresent(present)
                if not equipSuccess then
                    UpdateGiftSantaStatus("Failed to equip. Retrying...")
                    task.wait(2)
                    continue
                end
                -- EquipPresent already does retry verification, so just double-check
                if not GiftSantaState.IsPresentEquipped(present.UUID) then
                    UpdateGiftSantaStatus("Equip not verified. Retrying...")
                    task.wait(1)
                    continue
                end
            end
            
            -- Cooldown check
            local now = tick()
            if now - GiftSantaState.lastRedeemAttempt < GiftSantaState.REDEEM_COOLDOWN then
                task.wait(GiftSantaState.REDEEM_COOLDOWN - (now - GiftSantaState.lastRedeemAttempt))
            end
            
            -- Try direct redeem
            UpdateGiftSantaStatus("Redeeming " .. present.Name .. "...")
            GiftSantaState.lastRedeemAttempt = tick()
            
            local success, reason = TryRedeemGift()
            
            if success then
                UpdateGiftSantaStatus("Redeemed " .. present.Name .. "!")
                task.wait(1.5)
                continue
            end
            
            -- Direct redeem failed - try fallback
            if reason == "redeem_failed" then
                UpdateGiftSantaStatus("Direct redeem failed. Trying dialogue...")
                TryFallbackDialogue()
                task.wait(0.5)
                
                -- Retry redeem once
                local retrySuccess, _ = TryRedeemGift()
                if retrySuccess then
                    UpdateGiftSantaStatus("Redeemed via fallback!")
                else
                    UpdateGiftSantaStatus("Fallback failed. Will retry...")
                end
            else
                UpdateGiftSantaStatus("Error: " .. tostring(reason))
            end
            
            task.wait(2)
        end
        
        UpdateGiftSantaStatus("Stopped")
    end)
end

StopAutoGiftSanta = function()
    GiftSantaState.running = false
    GiftSantaState.enabled = false
    
    if GiftSantaState.thread then
        pcall(function() task.cancel(GiftSantaState.thread) end)
        GiftSantaState.thread = nil
    end
    
    UpdateGiftSantaStatus("Stopped")
    if CONFIG.DEBUG then log("[GiftSanta] Stopped Auto Gift Santa") end
end

-- Time Helpers (UTC safe)
local function NowUTC()
    return os.time(os.date("!*t"))
end

local function FormatHMS(sec)
    sec = math.max(0, sec)
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = sec % 60
    return string.format("%02d:%02d:%02d", h, m, s)
end

local function FormatHM(ts, utc)
    local t = os.date(utc and "!*t" or "*t", ts)
    return string.format("%02d:%02d", t.hour, t.min)
end

-- Get next Christmas Cave event timestamp
local function GetNextChristmasCaveEvent()
    local now = NowUTC()
    local t = os.date("!*t", now)
    local nearest = nil
    
    -- Today (UTC)
    for h in pairs(EventState.CHRISTMAS_HOURS) do
        local ts = os.time({
            year=t.year, month=t.month, day=t.day,
            hour=h, min=0, sec=0, isdst=false
        })
        if ts > now and (not nearest or ts < nearest) then
            nearest = ts
        end
    end
    
    -- Tomorrow (UTC)
    if not nearest then
        for h in pairs(EventState.CHRISTMAS_HOURS) do
            local ts = os.time({
                year=t.year, month=t.month, day=t.day + 1,
                hour=h, min=0, sec=0, isdst=false
            })
            if not nearest or ts < nearest then
                nearest = ts
            end
        end
    end
    
    return nearest
end

-- Safe teleport with velocity reset
local function SafeTeleport(targetPos)
    if not LocalPlayer.Character then return end
    local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    for _ = 1, 5 do
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 2, 0))
        task.wait(0.08)
    end
end

--====================================
-- VERIFIED TELEPORT (Anti-Cheat Safe)
--====================================
CONFIG.VERIFIED_TP = {
    MAX_ATTEMPTS = 5,
    VERIFY_DISTANCE = 50,    -- Studs threshold for success
    RETRY_DELAY = 3,         -- Seconds between retries (anti-cheat)
    VELOCITY_RESET_COUNT = 3, -- Times to reset velocity per attempt
}

local function VerifiedTeleport(targetPos, onSuccess, onFail)
    if not LocalPlayer.Character then
        if onFail then onFail("No character") end
        return false
    end
    
    local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        if onFail then onFail("No HumanoidRootPart") end
        return false
    end
    
    local attempt = 0
    local success = false
    
    while attempt < CONFIG.VERIFIED_TP.MAX_ATTEMPTS and not success do
        attempt = attempt + 1
        
        -- Reset velocity multiple times for stability
        for _ = 1, CONFIG.VERIFIED_TP.VELOCITY_RESET_COUNT do
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
        
        -- Perform teleport
        hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 2, 0))
        task.wait(0.1)
        
        -- Final velocity reset after teleport
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        
        -- Verify position
        local distance = (hrp.Position - targetPos).Magnitude
        if distance <= CONFIG.VERIFIED_TP.VERIFY_DISTANCE then
            success = true
            if CONFIG.DEBUG then
                print(string.format("[VerifiedTP] Success on attempt %d (distance: %.1f)", attempt, distance))
            end
        else
            if CONFIG.DEBUG then
                print(string.format("[VerifiedTP] Attempt %d failed (distance: %.1f), retrying in %ds...", 
                    attempt, distance, CONFIG.VERIFIED_TP.RETRY_DELAY))
            end
            -- Anti-cheat delay before retry
            if attempt < CONFIG.VERIFIED_TP.MAX_ATTEMPTS then
                task.wait(CONFIG.VERIFIED_TP.RETRY_DELAY)
            end
        end
    end
    
    if success then
        if onSuccess then onSuccess() end
        return true
    else
        if CONFIG.DEBUG then
            print("[VerifiedTP] Failed after " .. attempt .. " attempts")
        end
        if onFail then onFail("Max attempts reached") end
        return false
    end
end

--====================================
-- UNIFIED NAVIGATION SYSTEM (v2.6)
--====================================
-- Single source of truth for "where should I be?"
-- Priority: Event Zone > Rotation Location > Base Point

-- Forward declaration for RotationState access (defined later)
local GetCurrentRotationTarget -- Will be assigned after RotationState is defined

--====================================
-- UNIFIED LOCATION SYSTEM (v2.7)
--====================================
-- Base Point IS the current location. Rotation updates Base Point.
-- Event → Return to Base Point (which is synced with rotation)
-- Simple: One source of truth = basePointName

-- Get current target location
-- Returns: targetPos (Vector3|nil), targetName (string), source ("event"|"basepoint"|"none")
local function GetCurrentTargetLocation()
    -- PRIORITY 1: Active Event Zone (temporary override)
    if EventState.christmasCaveActive and SavedSettings.autoJoinChristmasCave then
        return EventState.COORDS.ChristmasCave, "Christmas Cave", "event"
    end
    
    if EventState.lochnessActive and SavedSettings.autoJoinLochness then
        if IsRuinDoorOpen() or GetRuinDoorStatus() == "UNKNOWN" then
            return EventState.COORDS.Lochness, "Lochness Event", "event"
        end
    end
    
    -- PRIORITY 2: Base Point (THE current location - synced with rotation)
    if SavedSettings.basePointName and SavedSettings.basePointName ~= "None" then
        local basePos = EventState.BASE_POINTS[SavedSettings.basePointName]
        local baseName = SavedSettings.basePointName
        
        -- Ancient Ruin guard
        if baseName == "Ancient Ruin" and basePos then
            if not IsRuinDoorOpen() then
                if CONFIG.DEBUG then log("[UnifiedNav] Ancient Ruin locked - falling back to Crater Island", "WARN") end
                basePos = EventState.BASE_POINTS["Crater Island"]
                baseName = "Crater Island (fallback)"
            end
        end
        
        if basePos then
            return basePos, baseName, "basepoint"
        end
    end
    
    return nil, "None", "none"
end

-- Smart return to current target (unified replacement for VerifiedReturnToBase)
local function SmartReturnToTarget(forceReason)
    local targetPos, targetName, source = GetCurrentTargetLocation()
    
    if CONFIG.DEBUG then
        print(string.format("[SmartReturn] Target: %s (%s) | Reason: %s", 
            targetName, source, forceReason or "auto"))
    end
    
    if targetPos then
        VerifiedTeleport(targetPos, 
            function()
                if CONFIG.DEBUG then print("[SmartReturn] Success: " .. targetName) end
                -- Re-equip rod after teleport
                task.delay(0.5, EquipRod)
            end,
            function(reason)
                if CONFIG.DEBUG then print("[SmartReturn] Failed: " .. reason) end
            end
        )
        return true
    end
    return false
end

-- Legacy wrapper for backward compatibility
local function VerifiedReturnToBase()
    -- Check if we have a saved position from event (highest priority for event return)
    if EventState.savedPosition then
        local pos = EventState.savedPosition.Pos
        EventState.savedPosition = nil
        VerifiedTeleport(pos, 
            function()
                if CONFIG.DEBUG then print("[VerifiedReturn] Returned to saved position") end
            end,
            nil
        )
        return
    end
    
    -- Otherwise use unified system
    SmartReturnToTarget("VerifiedReturnToBase")
end

-- Save current position before event teleport
local function SaveCurrentPosition()
    if EventState.savedPosition then return end -- Already saved
    
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        EventState.savedPosition = {
            Pos = hrp.Position,
            Look = hrp.CFrame.LookVector
        }
        if CONFIG.DEBUG then log("[Event] Position saved: " .. tostring(hrp.Position)) end
    end
end

-- Return to saved position or current target (v2.6: uses unified system)
local function ReturnToBaseOrSaved()
    -- Check saved position first
    if EventState.savedPosition then
        local pos = EventState.savedPosition.Pos
        EventState.savedPosition = nil
        VerifiedTeleport(pos, nil, nil)
        return
    end
    -- Otherwise use unified system
    SmartReturnToTarget("ReturnToBaseOrSaved")
end

--====================================
-- ANCIENT RUIN DOOR GATEKEEPER (from yesbgt.lua)
--====================================
-- Returns "UNLOCKED" if player has access, "LOCKED" otherwise
local function GetRuinDoorStatus()
    if not EventState.RUIN_DOOR then return "UNKNOWN" end
    
    local status = "LOCKED"
    pcall(function()
        local ruinDoor = EventState.RUIN_DOOR
        if ruinDoor and ruinDoor:FindFirstChild("RuinDoor") then
            local LDoor = ruinDoor.RuinDoor:FindFirstChild("LDoor")
            if LDoor then
                local currentX = nil
                if LDoor:IsA("BasePart") then
                    currentX = LDoor.Position.X
                elseif LDoor:IsA("Model") then
                    local success, pivot = pcall(function() return LDoor:GetPivot() end)
                    if success and pivot then
                        currentX = pivot.Position.X
                    end
                end
                -- Threshold from yesbgt.lua: 6075
                if currentX and currentX > 6075 then
                    status = "UNLOCKED"
                end
            end
        end
    end)
    return status
end

local function IsRuinDoorOpen()
    return GetRuinDoorStatus() == "UNLOCKED"
end

-- Teleport to Base Point (with anti-loop protection)
local function TeleportToBasePoint(bypassEventCheck)
    -- Anti-loop: Don't teleport if currently in event zone (unless bypass)
    if not bypassEventCheck and EventState.isInEventZone then
        if CONFIG.DEBUG then log("[BasePoint] Blocked - currently in event zone") end
        return false
    end
    
    local basePointName = SavedSettings.basePointName
    if not basePointName or basePointName == "None" then
        return false
    end
    -- Resolve base point position (handle Ancient Ruin locked fallback)
    local function ResolveBasePointPosition(name)
        if not name then return nil end
        local pos = EventState.BASE_POINTS[name]
        -- If Ancient Ruin selected but door locked, fallback to Crater Island
        if name == "Ancient Ruin" and pos then
            if not IsRuinDoorOpen() then
                if CONFIG.DEBUG then log("[BasePoint] Ancient Ruin locked - falling back to Crater Island", "WARN") end
                pcall(function()
                    WindUI:Notify({Title = "Teleport Fallback", Content = "Ancient Ruin locked - teleporting to Crater Island", Duration = 3})
                end)
                return EventState.BASE_POINTS["Crater Island"]
            end
        end
        return pos
    end

    local targetPos = ResolveBasePointPosition(basePointName)
    if targetPos then
        SafeTeleport(targetPos)
        if CONFIG.DEBUG then log("[BasePoint] Teleported to: " .. basePointName) end
        return true
    end
    return false
end

-- Lochness Event GUI Detection (from x.lua - event-driven)
-- Variables consolidated into EventState
EventState.lochnessLabel = nil
EventState.lochnessLabelConn = nil

local function GetLochnessCountdownLabel()
    if EventState.lochnessLabel and EventState.lochnessLabel.Parent then
        return EventState.lochnessLabel
    end
    
    local success, label = pcall(function()
        return Services.Workspace:WaitForChild("!!! DEPENDENCIES", 3)
            :WaitForChild("Event Tracker", 2)
            :WaitForChild("Main", 2)
            :WaitForChild("Gui", 2)
            :WaitForChild("Content", 2)
            :WaitForChild("Items", 2)
            :WaitForChild("Countdown", 2)
            :WaitForChild("Label", 2)
    end)
    
    if success and label then
        EventState.lochnessLabel = label
    end
    return success and label or nil
end

local function GetLochnessEventGUI()
    local label = GetLochnessCountdownLabel()
    return label and { Countdown = label, Timer = label } or nil
end

local function ParseLochnessCountdown(text)
    if not text or text == "" then return nil end
    local h = tonumber(text:match("(%d+)H")) or 0
    local m = tonumber(text:match("(%d+)M")) or 0
    local s = tonumber(text:match("(%d+)S")) or 0
    return h * 3600 + m * 60 + s
end

local function IsLochnessEventActive()
    local label = GetLochnessCountdownLabel()
    if not label then return false end
    
    local text = ""
    pcall(function() text = label.Text or "" end)
    
    local totalSeconds = ParseLochnessCountdown(text)
    -- Event is "active" when countdown is low (under 15 seconds) or event in progress
    return totalSeconds ~= nil and totalSeconds <= 15 and totalSeconds > 0
end

-- Event-driven Lochness monitor (from x.lua pattern)
local function SetupLochnessListener()
    if EventState.lochnessLabelConn then return end
    
    local label = GetLochnessCountdownLabel()
    if not label then return end
    
    EventState.lochnessLabelConn = label:GetPropertyChangedSignal("Text"):Connect(function()
        if not SavedSettings.autoJoinLochness then return end
        
        local text = label.Text or ""
        local totalSeconds = ParseLochnessCountdown(text)
        
        -- Auto-teleport at 10 seconds before event
        if totalSeconds and totalSeconds <= 10 and totalSeconds >= 1 then
            if not EventState.lochnessActive then
                EventState.lochnessActive = true
                EventState.isInEventZone = true
                
                -- Pause rotation if active (Scenario 1)
                if RotationState and RotationState.isActive then
                    PauseRotation("Lochness event")
                end
                
                SaveCurrentPosition()
                
                local targetPos = EventState.COORDS.Lochness
                VerifiedTeleport(targetPos, function()
                    if CONFIG.DEBUG then print("[Lochness] Auto-teleported to event") end
                    WindUI:Notify({Title = "Lochness", Content = "Teleported to event!", Duration = 3})
                    
                    -- Run 9x totem if enabled (Scenario 1 & 2) - v2.6.2: smart polling
                    if SavedSettings.autoTotemAfterTeleport then
                        task.delay(1, function()
                            StartAutoTotemPolling("Lochness event")
                        end)
                    end
                end)
            end
        elseif totalSeconds and totalSeconds > 60 then
            -- Reset state when countdown is high (event ended)
            if EventState.lochnessActive then
                EventState.lochnessActive = false
                EventState.isInEventZone = false
                
                -- v2.6: Use unified navigation to return to correct target
                -- SmartReturnToTarget handles: rotation active? → go to rotation
                --                             rotation not active? → go to basepoint
                if RotationState and RotationState.isPaused then
                    -- Resume rotation (which will teleport to rotation location)
                    ResumeRotation()
                else
                    -- Use unified system to determine correct target
                    SmartReturnToTarget("Lochness event ended")
                end
            end
        end
    end)
    
    if CONFIG.DEBUG then print("[Lochness] Event listener connected") end
end

-- Initialize Lochness listener on load
task.defer(SetupLochnessListener)

--====================================
-- INVENTORY HANDLER SYSTEM (v1.9)
--====================================

-- 9-Totem Formation Coordinates (relative offsets from center)
-- TOTEM PLACEMENT PATTERN: 3-layer vertical triangle (like yesbgt.lua)
-- Server spawns totem at player's CURRENT position, so vertical placement works
--
-- Triangle layout (each layer):
--      1          (Front)
--    2   3        (Back-left, Back-right)
-- Y layers: 0, +S, -S (where S = spacing)

-- Totem State (Simplified - single snapshot table saves registers)
local TotemState = {
    active = false,
    thread = nil,
    currentIndex = 0,
    statusParagraph = nil,
    toggleElement = nil,
    diedConnection = nil,
    Snapshot = nil, -- Single table: {CFrame, WalkSpeed, JumpPower}
    spacing = SavedSettings.totemSpacing or 101, -- Totem spacing (studs)
    offsets = nil, -- Generated dynamically
    -- PATTERN_OFFSET: Shift entire totem pattern so player at startPos receives all 9 effects
    -- Based on user testing: pattern needs to shift Z-17 to center on startPos
    patternOffset = Vector3.new(0, 0, -17),
    -- Totem Data consolidated here to save registers
    DATA = {
        ["Luck Totem"] = {Id = 1, Duration = 3601},
        ["Mutation Totem"] = {Id = 2, Duration = 3601},
        ["Shiny Totem"] = {Id = 3, Duration = 3601},
    },
    NAMES = {"Luck Totem", "Mutation Totem", "Shiny Totem"},
    -- Safety State (merged to save locals)
    Safety = { enabled = false, safetyConnection = nil, originalCollisions = {} },
}

-- Generate offsets dynamically based on spacing (stored in TotemState)
-- Pattern: 3-layer vertical equilateral triangle, SHIFTED by patternOffset
TotemState.offsets = (function()
    local S = TotemState.spacing
    local offset = TotemState.patternOffset
    -- Inscribed equilateral triangle with centroid at origin
    local r = S / math.sqrt(3)  -- radius (centroid to vertex)
    local halfS = S / 2
    local halfR = r / 2
    
    return {
        -- LAYER 1: Middle (Y = 0) - Triangle shifted by patternOffset
        Vector3.new(0, 0, r) + offset,           -- 1: Front (apex)
        Vector3.new(-halfS, 0, -halfR) + offset, -- 2: Back-left
        Vector3.new(halfS, 0, -halfR) + offset,  -- 3: Back-right
        -- LAYER 2: Above (Y = +S)
        Vector3.new(0, S, r) + offset,
        Vector3.new(-halfS, S, -halfR) + offset,
        Vector3.new(halfS, S, -halfR) + offset,
        -- LAYER 3: Below (Y = -S)
        Vector3.new(0, -S, r) + offset,
        Vector3.new(-halfS, -S, -halfR) + offset,
        Vector3.new(halfS, -S, -halfR) + offset,
    }
end)()

-- =================================================================
-- AUTO CONSUME POTION SYSTEM (v2.4)
-- =================================================================
-- Forward-declare inventory reader to allow earlier usage
local GetPlayerInventory

local PotionState = {
    active = false,
    thread = nil,
    statusParagraph = nil,
    toggleElement = nil,
    timers = {}, -- {[potionName] = expireTime}
    -- Potion Data: Name -> {Id, Duration}
    DATA = {
        ["Luck I Potion"] = {Id = 1, Duration = 900},
        ["Coin I Potion"] = {Id = 2, Duration = 900},
        ["Mutation I Potion"] = {Id = 4, Duration = 900},
        ["Luck II Potion"] = {Id = 6, Duration = 900},
    },
    NAMES = {"Luck I Potion", "Coin I Potion", "Mutation I Potion", "Luck II Potion"},
}

-- Get potion UUID from inventory
local function GetPotionUUID(potionName)
    -- Use the unified inventory reader
    local inventory = GetPlayerInventory()
    if not inventory or not inventory.Potions then return nil end

    local targetId = PotionState.DATA[potionName] and PotionState.DATA[potionName].Id
    if not targetId then return nil end

    for _, potion in ipairs(inventory.Potions) do
        if tonumber(potion.Id) == targetId and (potion.Count or 1) >= 1 then
            return potion.UUID
        end
    end
    return nil
end

-- Get potion count from inventory
local function GetPotionCount(potionName)
    local inventory = GetPlayerInventory()
    if not inventory or not inventory.Potions then return 0 end

    local targetId = PotionState.DATA[potionName] and PotionState.DATA[potionName].Id
    if not targetId then return 0 end

    for _, potion in ipairs(inventory.Potions) do
        if tonumber(potion.Id) == targetId then
            return potion.Count or 1
        end
    end
    return 0
end

-- Consume a potion
local function ConsumePotion(potionName)
    local uuid = GetPotionUUID(potionName)
    if not uuid then return false end
    
    local success = pcall(function()
        if Remotes.RF_ConsumePotion then
            Remotes.RF_ConsumePotion:InvokeServer(uuid, 1)
        end
    end)
    return success
end

-- Auto Potion Loop
local function RunAutoPotionLoop()
    if PotionState.thread then
        pcall(function() task.cancel(PotionState.thread) end)
    end
    
    PotionState.thread = task.spawn(function()
        while PotionState.active do
            local curTime = os.time()
            local selectedList = SavedSettings.selectedPotions or {}
            
            for _, potionName in ipairs(selectedList) do
                local expireTime = PotionState.timers[potionName] or 0
                
                -- Check if potion expired or never consumed
                if curTime >= expireTime then
                    local consumed = ConsumePotion(potionName)
                    if consumed then
                        local duration = PotionState.DATA[potionName] and PotionState.DATA[potionName].Duration or 900
                        PotionState.timers[potionName] = curTime + duration + 2 -- +2 buffer
                        if CONFIG.DEBUG then
                            log("[Potion] Consumed: " .. potionName)
                        end
                    end
                end
            end
            
            -- Update UI status
            if PotionState.statusParagraph then
                local lines = {}
                for _, name in ipairs(selectedList) do
                    local remaining = (PotionState.timers[name] or 0) - curTime
                    if remaining > 0 then
                        local mins = math.floor(remaining / 60)
                        local secs = remaining % 60
                        table.insert(lines, string.format("[ON] %s: %d:%02d", name, mins, secs))
                    else
                        local count = GetPotionCount(name)
                        table.insert(lines, string.format("[WAIT] %s (x%d)", name, count))
                    end
                end
                if #lines > 0 then
                    PotionState.statusParagraph:SetDesc(table.concat(lines, "\n"))
                else
                    PotionState.statusParagraph:SetDesc("No potions selected")
                end
            end
            
            task.wait(1)
        end
    end)
end

-- Stop Auto Potion
local function StopAutoPotionLoop()
    PotionState.active = false
    if PotionState.thread then
        pcall(function() task.cancel(PotionState.thread) end)
        PotionState.thread = nil
    end
    if PotionState.statusParagraph then
        PotionState.statusParagraph:SetDesc("Status: OFF")
    end
end

-- =================================================================
-- TOTEM FLY ENGINE (BodyVelocity + BodyGyro - Server-side aware)
-- =================================================================

-- Get fly part (prefer Torso for R6, UpperTorso for R15, fallback HRP)
local function GetFlyPart()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("HumanoidRootPart")
end

-- Anti-fall state manager (force Swimming state to float)
local function MaintainAntiFallState(enable)
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChild("Humanoid")
    if not hum then return end
    
    if enable then
        -- Disable ALL fall-related states
        hum:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Flying, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Landed, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Running, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.StrafingNoPhysics, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
    else
        -- v2.7.2: Restore only states that are TRUE by default in normal character
        -- Flying, GettingUp, PlatformStanding, RunningNoPhysics, Seated, StrafingNoPhysics, Swimming = FALSE by default!
        hum:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
        hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
        hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
        hum:SetStateEnabled(Enum.HumanoidStateType.Landed, true)
        hum:SetStateEnabled(Enum.HumanoidStateType.Physics, true)
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
        hum:SetStateEnabled(Enum.HumanoidStateType.Running, true)
        
        -- These should remain FALSE (default values)
        hum:SetStateEnabled(Enum.HumanoidStateType.Flying, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.StrafingNoPhysics, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
        
        -- Final state: RunningNoPhysics for clean landing (yesbgt.lua style)
        hum:ChangeState(Enum.HumanoidStateType.RunningNoPhysics)
    end
end

-- Enable fly physics for totem placement
EnableTotemSafety = function()
    if TotemState.Safety.enabled then return end
    TotemState.Safety.enabled = true
    
    local char = LocalPlayer.Character
    if not char then return end
    
    local mainPart = GetFlyPart()
    local hum = char:FindFirstChild("Humanoid")
    if not mainPart or not hum then return end
    
    -- 1. DEATH HANDLER
    if TotemState.diedConnection then
        TotemState.diedConnection:Disconnect()
    end
    TotemState.diedConnection = hum.Died:Connect(function()
        TotemState.active = false
        DisableTotemSafety()
        if TotemState.toggleElement then
            pcall(function() TotemState.toggleElement:Set(false) end)
        end
        WindUI:Notify({
            Title = "Ritual Aborted",
            Content = "Player died during totem placement",
            Duration = 3
        })
    end)
    
    -- 2. OXYGEN TANK
    if Remotes.RF_EquipOxygenTank then
        pcall(function() Remotes.RF_EquipOxygenTank:InvokeServer(105) end)
    end
    
    -- 3. DISABLE ANIMATIONS (for stability)
    if char:FindFirstChild("Animate") then
        char.Animate.Disabled = true
    end
    
    -- 4. PLATFORM STAND
    hum.PlatformStand = true
    
    -- 5. ANTI-FALL STATE
    MaintainAntiFallState(true)
    
    -- 6. CREATE FLY MOVERS (BodyVelocity + BodyGyro)
    local bg = mainPart:FindFirstChild("TotemFlyGyro") or Instance.new("BodyGyro")
    bg.Name = "TotemFlyGyro"
    bg.P = 9e4
    bg.maxTorque = Vector3.new(9e9, 9e9, 9e9)
    bg.CFrame = mainPart.CFrame
    bg.Parent = mainPart
    
    local bv = mainPart:FindFirstChild("TotemFlyVelocity") or Instance.new("BodyVelocity")
    bv.Name = "TotemFlyVelocity"
    bv.Velocity = Vector3.new(0, 0.1, 0) -- Idle hover
    bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    bv.Parent = mainPart
    
    -- 7. NOCLIP LOOP (Swimming state for aerial stability)
    if TotemState.Safety.safetyConnection then
        TotemState.Safety.safetyConnection:Disconnect()
    end
    TotemState.Safety.safetyConnection = RunService.Heartbeat:Connect(function()
        if not TotemState.Safety.enabled then return end
        
        local c = LocalPlayer.Character
        local h = c and c:FindFirstChild("Humanoid")
        
        -- Force Swimming state (most stable for aerial positioning)
        -- yesbgt.lua uses this for vertical totem placement
        if h and TotemState.active then
            h:ChangeState(Enum.HumanoidStateType.Swimming)
            h:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
        end
        
        -- Noclip self
        if c then
            for _, v in ipairs(c:GetDescendants()) do
                if v:IsA("BasePart") then v.CanCollide = false end
            end
        end
        
        -- Noclip other players
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local otherChar = player.Character
                if otherChar then
                    for _, v in ipairs(otherChar:GetDescendants()) do
                        if v:IsA("BasePart") then v.CanCollide = false end
                    end
                end
            end
        end
    end)
    
    if CONFIG.DEBUG then log("[TotemSafety] ENABLED: fly mode + swimming state + noclip") end
end

-- Disable safety features and restore normal state (v2.7.3: Respawn method - cleanest solution)
DisableTotemSafety = function()
    if not TotemState.Safety.enabled then return end
    TotemState.Safety.enabled = false
    
    -- 1. DISCONNECT LOOPS FIRST
    if TotemState.Safety.safetyConnection then
        TotemState.Safety.safetyConnection:Disconnect()
        TotemState.Safety.safetyConnection = nil
    end
    
    -- 2. DISCONNECT DEATH HANDLER
    if TotemState.diedConnection then
        TotemState.diedConnection:Disconnect()
        TotemState.diedConnection = nil
    end
    
    local char = LocalPlayer.Character
    if not char then return end
    
    local mainPart = GetFlyPart()
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    
    -- 3. REMOVE FLY MOVERS FIRST
    if mainPart then
        local bg = mainPart:FindFirstChild("TotemFlyGyro")
        local bv = mainPart:FindFirstChild("TotemFlyVelocity")
        if bg then bg:Destroy() end
        if bv then bv:Destroy() end
    end
    
    -- 4. UNEQUIP OXYGEN TANK (before state changes)
    if Remotes.RF_UnequipOxygenTank then
        pcall(function() Remotes.RF_UnequipOxygenTank:InvokeServer() end)
    end
    
    -- 5. Get ORIGINAL position (before totem ritual started, NOT current fly position)
    -- TotemState.Snapshot.CFrame was saved at the START of Run9TotemRitual
    local returnPos = nil
    if TotemState.Snapshot and TotemState.Snapshot.CFrame then
        returnPos = TotemState.Snapshot.CFrame.Position
        if CONFIG.DEBUG then log("[TotemSafety] Using original position from Snapshot") end
    elseif hrp then
        -- Fallback to current position if no snapshot
        returnPos = hrp.Position
        if CONFIG.DEBUG then log("[TotemSafety] Fallback to current position (no Snapshot)") end
    end
    
    -- 6. RESPAWN METHOD (cleanest - yesbgt.lua style)
    if hum and returnPos then
        task.spawn(function()
            -- Kill character to respawn
            hum:TakeDamage(999999)
            
            -- Wait for new character
            LocalPlayer.CharacterAdded:Wait()
            task.wait(0.5)
            
            -- Teleport back to ORIGINAL position (before ritual)
            local newChar = LocalPlayer.Character
            local newHRP = newChar and newChar:WaitForChild("HumanoidRootPart", 5)
            
            if newHRP then
                newHRP.CFrame = CFrame.new(returnPos + Vector3.new(0, 3, 0))
                if CONFIG.DEBUG then log("[TotemSafety] Respawned at original position") end
                
                -- Re-equip rod after respawn
                task.delay(0.5, function()
                    EquipRod()
                end)
            end
            
            -- Clear snapshot after use
            TotemState.Snapshot = nil
        end)
    else
        -- Fallback: just restore states manually if no humanoid
        if char:FindFirstChild("Animate") then
            char.Animate.Disabled = false
        end
        MaintainAntiFallState(false)
    end
    
    if CONFIG.DEBUG then log("[TotemSafety] DISABLED: respawn method") end
end

-- FLY TO POSITION: Physics-based movement (server-side aware)
-- Uses BodyVelocity to fly to target - server sees position updates
local function FlyToPosition(targetPos)
    local mainPart = GetFlyPart()
    if not mainPart then return false end
    
    local bv = mainPart:FindFirstChild("TotemFlyVelocity")
    local bg = mainPart:FindFirstChild("TotemFlyGyro")
    
    if not bv or not bg then
        -- Re-enable fly if movers missing
        EnableTotemSafety()
        bv = mainPart:FindFirstChild("TotemFlyVelocity")
        bg = mainPart:FindFirstChild("TotemFlyGyro")
        if not bv or not bg then return false end
    end
    
    local FLY_SPEED = 100 -- studs per second
    local ARRIVAL_THRESHOLD = 2 -- studs
    local MAX_FLY_TIME = 5 -- seconds max
    local startTime = tick()
    
    while TotemState.active and (tick() - startTime) < MAX_FLY_TIME do
        local currentPos = mainPart.Position
        local diff = targetPos - currentPos
        local distance = diff.Magnitude
        
        -- Face target direction
        bg.CFrame = CFrame.lookAt(currentPos, targetPos)
        
        if distance <= ARRIVAL_THRESHOLD then
            -- Arrived - stop and hover
            bv.Velocity = Vector3.new(0, 0.1, 0)
            return true
        else
            -- Fly towards target
            bv.Velocity = diff.Unit * FLY_SPEED
        end
        
        RunService.Heartbeat:Wait()
    end
    
    -- Timeout - stop anyway
    bv.Velocity = Vector3.new(0, 0.1, 0)
    
    -- Check if close enough
    local finalDist = (mainPart.Position - targetPos).Magnitude
    return finalDist <= (ARRIVAL_THRESHOLD * 2)
end

-- Get player inventory via Replion
GetPlayerInventory = function()
    if not Replion then return nil end
    local success, data = pcall(function()
        return Replion.Client:WaitReplion("Data", 2)
    end)
    if not success or not data then return nil end
    
    local invSuccess, inventory = pcall(function()
        return data:GetExpect("Inventory")
    end)
    return invSuccess and inventory or nil
end

-- Count totems of specific type in inventory
local function GetTotemCount(totemName)
    local inventory = GetPlayerInventory()
    if not inventory or not inventory.Totems then return 0 end
    
    local totemId = TotemState.DATA[totemName] and TotemState.DATA[totemName].Id
    if not totemId then return 0 end
    
    local count = 0
    for _, item in ipairs(inventory.Totems) do
        if tonumber(item.Id) == totemId then
            count = count + (item.Count or 1)
        end
    end
    return count
end

-- Get UUID of a totem for spawning (REFRESHED each call)
local function GetTotemUUID(totemName)
    -- Force fresh inventory read
    local inventory = nil
    if Replion then
        local success, data = pcall(function()
            return Replion.Client:WaitReplion("Data", 2)
        end)
        if success and data then
            local invSuccess, inv = pcall(function()
                return data:GetExpect("Inventory")
            end)
            if invSuccess then inventory = inv end
        end
    end
    
    if not inventory or not inventory.Totems then return nil end
    
    local totemId = TotemState.DATA[totemName] and TotemState.DATA[totemName].Id
    if not totemId then return nil end
    
    for _, item in ipairs(inventory.Totems) do
        if tonumber(item.Id) == totemId and (item.Count or 1) >= 1 then
            return item.UUID
        end
    end
    return nil
end

-- RESTORE PLAYER: Single source of truth for state restoration
local function RestorePlayer(forceReturn)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChild("Humanoid")
    
    -- Disable safety first (removes fly movers, restores physics)
    DisableTotemSafety()
    
    -- Small delay to let DisableTotemSafety complete
    task.wait(0.1)
    
    -- Restore from snapshot (return to ORIGINAL start position)
    if TotemState.Snapshot and hrp and hum then
        -- Restore position
        if forceReturn and TotemState.Snapshot.CFrame then
            -- Reset velocity before teleport
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            
            -- Teleport to original position
            hrp.CFrame = TotemState.Snapshot.CFrame
            
            -- Reset velocity again after teleport
            task.wait(0.05)
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
        
        -- Restore movement stats
        if TotemState.Snapshot.WalkSpeed then
            hum.WalkSpeed = TotemState.Snapshot.WalkSpeed
        end
        if TotemState.Snapshot.JumpPower then
            hum.JumpPower = TotemState.Snapshot.JumpPower
        end
        if TotemState.Snapshot.JumpHeight then
            hum.JumpHeight = TotemState.Snapshot.JumpHeight
        end
        if TotemState.Snapshot.AutoRotate ~= nil then
            hum.AutoRotate = TotemState.Snapshot.AutoRotate
        end
        
        -- Force normal state after position restore
        task.spawn(function()
            task.wait(0.15)
            if hum and hum.Parent then
                hum:ChangeState(Enum.HumanoidStateType.Landed)
                task.wait(0.05)
                hum:ChangeState(Enum.HumanoidStateType.Running)
            end
        end)
    end
    
    -- Clear snapshot to free memory
    TotemState.Snapshot = nil
    TotemState.active = false
    TotemState.currentIndex = 0
    
    -- Reset UI toggle
    if TotemState.toggleElement then
        pcall(function() TotemState.toggleElement:Set(false) end)
    end
end

-- CLEANUP RITUAL: Handles all exit scenarios (with duplicate prevention)
-- cleanupInProgress moved into TotemState
TotemState.cleanupInProgress = false
local function CleanupTotemRitual(reason, placedCount)
    -- Prevent duplicate cleanup calls
    if TotemState.cleanupInProgress then return end
    TotemState.cleanupInProgress = true
    
    placedCount = placedCount or 0
    
    -- Restore player state (ALWAYS return to start position)
    RestorePlayer(true)
    
    -- Update status UI
    if TotemState.statusParagraph then
        if placedCount == 9 then
            TotemState.statusParagraph:SetDesc("Complete! 9/9 placed")
        elseif placedCount > 0 then
            TotemState.statusParagraph:SetDesc(string.format("Stopped: %d/9", placedCount))
        else
            TotemState.statusParagraph:SetDesc("Idle")
        end
    end
    
    -- Notify user (only once)
    if reason then
        WindUI:Notify({
            Title = placedCount == 9 and "Ritual Complete" or "Ritual Stopped",
            Content = string.format("%s (%d/9 placed)", reason, placedCount),
            Duration = 3,
            Icon = placedCount == 9 and "check" or "x"
        })
    end
    
    if CONFIG.DEBUG then log(string.format("[Totem] Cleanup: %s, %d/9", reason or "unknown", placedCount)) end
    
    -- Reset flag after small delay
    task.delay(0.5, function() TotemState.cleanupInProgress = false end)
end

-- Auto Equip Rod (after teleport settles)
local function EquipRod()
    local character = LocalPlayer.Character
    if not character then return false end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    
    -- Check if already holding a rod
    for _, tool in ipairs(character:GetChildren()) do
        if tool:IsA("Tool") and (tool.Name:lower():find("rod") or tool.Name:lower():find("fishing")) then
            return true -- Already equipped
        end
    end
    
    -- Method 1: Try RE_EquipToolFromHotbar (slot 1 = rod)
    if Remotes.RE_EquipToolFromHotbar then
        local success = pcall(function()
            Remotes.RE_EquipToolFromHotbar:FireServer(1)
        end)
        if success then
            if CONFIG.DEBUG then print("[EquipRod] FireServer(1) called") end
            return true
        end
    end
    
    -- Method 2: Fallback - Find rod in backpack and equip via Humanoid
    if backpack and humanoid then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") and (tool.Name:lower():find("rod") or tool.Name:lower():find("fishing")) then
                pcall(function() humanoid:EquipTool(tool) end)
                if CONFIG.DEBUG then print("[EquipRod] Equipped via Humanoid: " .. tool.Name) end
                return true
            end
        end
    end
    
    return false
end

--====================================
-- AUTO-EQUIP MONITOR (Aggressive Spam like yesbgt.lua)
--====================================
local EquipMonitorState = {
    toolRemovedConnection = nil,
    characterAddedConnection = nil,
    idleCheckThread = nil,
    isActive = false,
    _equipInProgress = false, -- Debounce flag to prevent race conditions
    IDLE_CHECK_INTERVAL = 5, -- Check every 5 seconds (low frequency)
}

local function IsHoldingRod()
    local character = LocalPlayer.Character
    if not character then return false end
    
    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("Tool") and (child.Name:lower():find("rod") or child.Name:lower():find("fishing")) then
            return true
        end
    end
    return false
end

-- Single equip attempt (non-blocking, with debounce)
local function TryEquipRodOnce()
    if not SavedSettings.autoEquipRodEnabled then return end
    if IsHoldingRod() then return end -- Already holding, do nothing
    if EquipMonitorState._equipInProgress then return end -- Debounce
    
    EquipMonitorState._equipInProgress = true
    pcall(function() Remotes.RE_EquipToolFromHotbar:FireServer(1) end)
    task.delay(0.2, function() EquipMonitorState._equipInProgress = false end)
end

-- Equip with retry (blocking, limited attempts, with debounce)
local function TryEquipRodWithRetry(maxAttempts)
    if EquipMonitorState._equipInProgress then return end -- Debounce
    EquipMonitorState._equipInProgress = true
    
    maxAttempts = maxAttempts or 5
    for _ = 1, maxAttempts do
        if not SavedSettings.autoEquipRodEnabled then break end
        if IsHoldingRod() then break end -- Success, stop
        pcall(function() Remotes.RE_EquipToolFromHotbar:FireServer(1) end)
        task.wait(0.15)
    end
    
    EquipMonitorState._equipInProgress = false
end

local function StartEquipMonitor()
    -- Stop existing monitors
    if EquipMonitorState.toolRemovedConnection then
        EquipMonitorState.toolRemovedConnection:Disconnect()
        EquipMonitorState.toolRemovedConnection = nil
    end
    if EquipMonitorState.idleCheckThread then
        pcall(function() task.cancel(EquipMonitorState.idleCheckThread) end)
        EquipMonitorState.idleCheckThread = nil
    end
    
    EquipMonitorState.isActive = true
    
    -- Setup tool removed listener for current character
    local function setupToolRemovedListener(character)
        if EquipMonitorState.toolRemovedConnection then
            EquipMonitorState.toolRemovedConnection:Disconnect()
        end
        
        EquipMonitorState.toolRemovedConnection = character.ChildRemoved:Connect(function(child)
            if not EquipMonitorState.isActive then return end -- Guard: monitor must be active
            if not SavedSettings.autoEquipRodEnabled then return end
            if not child:IsA("Tool") then return end
            
            -- Only re-equip if the removed tool was a rod
            local wasRod = child.Name:lower():find("rod") or child.Name:lower():find("fishing")
            if wasRod then
                task.delay(0.2, function()
                    TryEquipRodWithRetry(5)
                end)
            end
        end)
    end
    
    -- Setup for current character
    if LocalPlayer.Character then
        setupToolRemovedListener(LocalPlayer.Character)
        -- Initial equip if not holding
        task.delay(0.5, TryEquipRodOnce)
    end
    
    -- Re-setup when character respawns
    EquipMonitorState.characterAddedConnection = LocalPlayer.CharacterAdded:Connect(function(character)
        task.wait(0.5)
        setupToolRemovedListener(character)
        -- Equip on respawn
        TryEquipRodWithRetry(5)
    end)
    RegisterConnection(EquipMonitorState.characterAddedConnection)
    
    -- LOW-FREQUENCY IDLE CHECK (fallback for edge cases)
    -- Only fires single equip if rod is NOT held, every 5 seconds
    EquipMonitorState.idleCheckThread = task.spawn(function()
        while EquipMonitorState.isActive do
            task.wait(EquipMonitorState.IDLE_CHECK_INTERVAL)
            if EquipMonitorState.isActive and SavedSettings.autoEquipRodEnabled then
                TryEquipRodOnce() -- Single attempt, no spam
            end
        end
    end)
    
    if CONFIG.DEBUG then print("[EquipMonitor] Started (event-driven + 5s idle check)") end
end

local function StopEquipMonitor()
    EquipMonitorState.isActive = false
    EquipMonitorState._equipInProgress = false -- Reset debounce
    
    if EquipMonitorState.toolRemovedConnection then
        EquipMonitorState.toolRemovedConnection:Disconnect()
        EquipMonitorState.toolRemovedConnection = nil
    end
    if EquipMonitorState.characterAddedConnection then
        EquipMonitorState.characterAddedConnection:Disconnect()
        EquipMonitorState.characterAddedConnection = nil
    end
    if EquipMonitorState.idleCheckThread then
        pcall(function() task.cancel(EquipMonitorState.idleCheckThread) end)
        EquipMonitorState.idleCheckThread = nil
    end
    if CONFIG.DEBUG then print("[EquipMonitor] Stopped") end
end

-- Enhanced SafeTeleport with auto-equip
local function SafeTeleportWithEquip(targetPos)
    SafeTeleport(targetPos)
    
    if SavedSettings.autoEquipRodEnabled then
        task.delay(0.8, EquipRod) -- Single delayed equip after teleport
    end
end

--====================================
-- FORWARD DECLARATIONS (for functions used before definition)
--====================================
local ScanForNearbyTotems -- Defined at L~2600
local FormatTotemSensorStatus -- Defined at L~2680
local PauseRotation -- Defined at L~2860
local ResumeRotation -- Defined at L~2880
local Run9TotemRitual -- Defined at L~2405
-- NOTE: EnableTotemSafety, DisableTotemSafety, AnchoredTeleport defined above at L1978-2175
local TotemSensorState = {
    statusParagraph = nil,
    updateThread = nil,
    lastDetectedCount = 0,
    isTotemNearby = false,
    maxTimeRemaining = 0,      -- Maximum time remaining among all detected totems (seconds)
    foundTotems = {},          -- Array of detected totems with details
    -- Config consolidated here
    CONFIG = {
        DETECTION_RADIUS = 120,
        SCAN_INTERVAL = 5,
        MIN_TIME_THRESHOLD = 30,
    },
}

--====================================
-- 9X TOTEM RITUAL SYSTEM (v2.0 - ANCHORED TELEPORT)
--====================================

-- Check if totem ritual should be interrupted
-- v2.7.2: FIXED - Do NOT interrupt if we're IN the event zone (we WANT totem at event)
-- Only interrupt if event is STARTING and we need to TELEPORT there
local function ShouldInterruptTotem()
    -- If we're already IN event zone, DON'T interrupt - we want totem here!
    if EventState.isInEventZone then
        return false, nil  -- Allow totem at event zone
    end
    
    -- Check if event is STARTING and we need to teleport (not already there)
    local nowT = os.date("!*t", NowUTC())
    if SavedSettings.autoJoinChristmasCave and EventState.CHRISTMAS_HOURS[nowT.hour] and nowT.min == 0 then
        -- Only interrupt if we're NOT in event zone (need to teleport)
        return true, "Christmas Cave event starting - need to teleport"
    end
    
    if SavedSettings.autoJoinLochness and IsLochnessEventActive() then
        -- Only interrupt if we're NOT in event zone (need to teleport)
        return true, "Lochness event starting - need to teleport"
    end
    
    return false, nil
end

--====================================
-- AUTO TOTEM POLLING SYSTEM (v2.6.2)
--====================================
-- Efficient polling that waits for totem conditions to be met
local AutoTotemPolling = {
    thread = nil,
    isActive = false,
    MAX_WAIT_TIME = 30 * 60, -- Max 30 minutes waiting
    CHECK_INTERVAL = 30,     -- Check every 30 seconds
}

-- Cancel any existing polling
local function CancelAutoTotemPolling()
    if AutoTotemPolling.thread then
        pcall(function() task.cancel(AutoTotemPolling.thread) end)
        AutoTotemPolling.thread = nil
    end
    AutoTotemPolling.isActive = false
end

-- Start polling for totem placement opportunity
-- Will keep checking until <3 totems active, then run ritual
local function StartAutoTotemPolling(reason)
    -- Cancel existing polling first
    CancelAutoTotemPolling()
    
    if not SavedSettings.autoTotemAfterTeleport then return end
    
    AutoTotemPolling.isActive = true
    AutoTotemPolling.thread = task.spawn(function()
        local startTime = os.time()
        local attempts = 0
        
        while AutoTotemPolling.isActive do
            -- Timeout check
            if os.time() - startTime > AutoTotemPolling.MAX_WAIT_TIME then
                if CONFIG.DEBUG then print("[AutoTotem] Polling timeout after 30 minutes") end
                break
            end
            
            -- Check totem conditions
            if ScanForNearbyTotems then
                local count, hasNearby, maxTime = ScanForNearbyTotems()
                
                -- Condition met: <3 totems OR totems expiring soon
                if not hasNearby or count < 3 or maxTime <= 60 then
                    if CONFIG.DEBUG then 
                        print(string.format("[AutoTotem] Conditions met: %d totems, %s remaining", 
                            count, hasNearby and FormatTimeRemaining(maxTime) or "none"))
                    end
                    
                    -- Run the ritual (skip the active check since we just checked)
                    if Run9TotemRitual then
                        Run9TotemRitual(true) -- skipActiveCheck = true
                    end
                    break
                else
                    -- Still waiting
                    attempts = attempts + 1
                    if CONFIG.DEBUG and attempts % 4 == 1 then -- Log every 2 minutes
                        print(string.format("[AutoTotem] Waiting... %d totems active (%s left)", 
                            count, FormatTimeRemaining(maxTime)))
                    end
                end
            else
                -- ScanForNearbyTotems not available, just run ritual
                if Run9TotemRitual then Run9TotemRitual(true) end
                break
            end
            
            -- Wait before next check (efficient interval)
            task.wait(AutoTotemPolling.CHECK_INTERVAL)
        end
        
        AutoTotemPolling.isActive = false
        AutoTotemPolling.thread = nil
    end)
    
    if CONFIG.DEBUG then print("[AutoTotem] Polling started: " .. (reason or "teleport")) end
end

-- Run 9x Totem Placement (FLY ENGINE - Server-aware, Register-optimized)
-- v2.6: Added skipActiveCheck parameter for manual override
Run9TotemRitual = function(skipActiveCheck)
    -- Cancel existing thread
    if TotemState.thread then
        pcall(function() task.cancel(TotemState.thread) end)
    end
    
    local totemName = SavedSettings.selectedTotemType or "Luck Totem"
    
    -- GUARD 1: Check if active totems already exist (unless skip requested)
    -- v2.6.1: Only skip if 3+ totems active (1-2 totems = allow ritual)
    if not skipActiveCheck and ScanForNearbyTotems then
        local count, hasNearby, maxTime = ScanForNearbyTotems()
        if hasNearby and count >= 3 and maxTime > 60 then -- 3+ totems with >1 minute remaining
            local msg = string.format("%d totem(s) active (%s left)", count, FormatTimeRemaining(maxTime))
            if CONFIG.DEBUG then print("[Ritual] Skipped: " .. msg) end
            WindUI:Notify({Title = "Ritual Skipped", Content = msg, Duration = 3})
            -- Reset toggle if it was turned on
            if TotemState.toggleElement then
                pcall(function() TotemState.toggleElement:SetValue(false) end)
            end
            return false, "active_totems"
        end
    end
    
    TotemState.active = true
    
    -- GUARD 2: Check totem count in inventory
    if GetTotemCount(totemName) < 9 then
        CleanupTotemRitual("Need 9 " .. totemName, 0)
        return false, "not_enough"
    end
    
    TotemState.thread = task.spawn(function()
        local char, hrp, hum = LocalPlayer.Character, nil, nil
        if char then
            hrp = char:FindFirstChild("HumanoidRootPart")
            hum = char:FindFirstChild("Humanoid")
        end
        
        if not hrp or not hum then
            CleanupTotemRitual("Character not found", 0)
            return
        end
        
        -- WAIT FOR POSITION TO STABILIZE (max 1.5s with early exit)
        -- Prevents wrong startPos when called immediately after teleport
        local lastPos = hrp.Position
        local stableCount = 0
        for _ = 1, 15 do -- Max 1.5 seconds (15 x 0.1s)
            task.wait(0.1)
            local currentPos = hrp.Position
            local delta = (currentPos - lastPos).Magnitude
            if delta < 2 then -- Position stable (moved less than 2 studs)
                stableCount = stableCount + 1
                if stableCount >= 3 then break end -- 3 consecutive stable readings
            else
                stableCount = 0
            end
            lastPos = currentPos
        end
        if CONFIG.DEBUG then
            print(string.format("[Ritual] Position stabilized at: %.1f, %.1f, %.1f", hrp.Position.X, hrp.Position.Y, hrp.Position.Z))
        end
        
        -- SNAPSHOT: Single table saves registers (save ALL relevant humanoid properties)
        TotemState.Snapshot = {
            CFrame = hrp.CFrame,
            WalkSpeed = hum.WalkSpeed,
            JumpPower = hum.JumpPower,
            JumpHeight = hum.JumpHeight,
            AutoRotate = hum.AutoRotate,
        }
        
        local startPos, placedCount = hrp.Position, 0
        
        EnableTotemSafety()
        WindUI:Notify({ Title = "Ritual Started", Content = "Placing 9 " .. totemName, Duration = 2 })
        
        -- MAIN LOOP: Iterate through offsets
        for i = 1, 9 do
            if not TotemState.active then
                CleanupTotemRitual("Stopped", placedCount)
                return
            end
            
            -- Check interrupt
            local shouldStop, reason = ShouldInterruptTotem()
            if shouldStop then
                CleanupTotemRitual(reason, placedCount)
                return
            end
            
            TotemState.currentIndex = i
            if TotemState.statusParagraph then
                TotemState.statusParagraph:SetDesc(string.format("Flying %d/9...", i))
            end
            
            -- Fly to position
            local targetPos = startPos + TotemState.offsets[i]
            if not FlyToPosition(targetPos) then
                task.wait(0.5)
                FlyToPosition(targetPos) -- Retry once
            end
            
            -- HOLD POSITION: Lock CFrame during spawn (anti-drift)
            local mainPart = GetFlyPart()
            local bv = mainPart and mainPart:FindFirstChild("TotemFlyVelocity")
            local bg = mainPart and mainPart:FindFirstChild("TotemFlyGyro")
            local targetCFrame = CFrame.new(targetPos) * CFrame.Angles(0, math.rad(hrp.Orientation.Y), 0)
            
            -- Stop all movement
            if bv then bv.Velocity = Vector3.zero end
            if bg then bg.CFrame = targetCFrame end
            if hrp then
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
                hrp.CFrame = targetCFrame
            end
            
            -- Hold position for server sync (0.5s with CFrame lock)
            for _ = 1, 5 do
                task.wait(0.1)
                if hrp and TotemState.active then
                    hrp.CFrame = targetCFrame
                    hrp.AssemblyLinearVelocity = Vector3.zero
                end
            end
            
            -- Get fresh UUID and spawn totem (while holding position)
            local uuid = GetTotemUUID(totemName)
            if uuid and Remotes.RE_SpawnTotem then
                if TotemState.statusParagraph then
                    TotemState.statusParagraph:SetDesc(string.format("Spawning %d/9...", i))
                end
                
                -- Hold position during spawn
                hrp.CFrame = targetCFrame
                hrp.AssemblyLinearVelocity = Vector3.zero
                
                pcall(function() Remotes.RE_SpawnTotem:FireServer(uuid) end)
                placedCount = placedCount + 1
                
                -- Re-equip rod
                if Remotes.RE_EquipToolFromHotbar then
                    task.spawn(function()
                        for _ = 1, 3 do
                            pcall(function() Remotes.RE_EquipToolFromHotbar:FireServer(1) end)
                            task.wait(0.1)
                        end
                    end)
                end
                
                -- Hold position during delay between placements
                for _ = 1, 15 do
                    task.wait(0.1)
                    if hrp and TotemState.active then
                        hrp.CFrame = targetCFrame
                        hrp.AssemblyLinearVelocity = Vector3.zero
                    end
                end
            else
                CleanupTotemRitual("Inventory depleted", placedCount)
                return
            end
        end
        
        -- RITUAL COMPLETE
        CleanupTotemRitual(placedCount == 9 and "Success" or "Partial", placedCount)
        
        if placedCount > 0 then
            task.delay(1, function()
                if ScanForNearbyTotems then ScanForNearbyTotems() end
            end)
        end
    end)
    
    return true
end

local function StopTotemRitual()
    CleanupTotemRitual("Stopped by user", TotemState.currentIndex)
    if TotemState.thread then
        pcall(function() task.cancel(TotemState.thread) end)
        TotemState.thread = nil
    end
end

--====================================
-- MERCHANT SYSTEM (v1.9 - FIXED)
--====================================

local MerchantState = {
    replion = nil,
    thread = nil,
    lastBuyTime = 0,
    isMonitoring = false,
    statusParagraph = nil,
    -- Merchant Static Items consolidated here
    ITEMS = {
        {Name = "Fluorescent Rod", ID = 1, Price = 685000},
        {Name = "Hazmat Rod", ID = 2, Price = 1380000},
        {Name = "Singularity Bait", ID = 3, Price = 8200000},
        {Name = "Royal Bait", ID = 4, Price = 425000},
        {Name = "Luck Totem", ID = 5, Price = 650000},
        {Name = "Shiny Totem", ID = 7, Price = 400000},
        {Name = "Mutation Totem", ID = 8, Price = 800000},
    },
}

-- Get Merchant Replion for stock checking
local function GetMerchantReplion()
    if MerchantState.replion then return MerchantState.replion end
    
    pcall(function()
        local ReplionClient = Replion and Replion.Client
        if ReplionClient then
            MerchantState.replion = ReplionClient:WaitReplion("Merchant", 3)
        end
    end)
    
    return MerchantState.replion
end

-- Get player's coins safely (Replion -> leaderstats fallback)
local function GetPlayerCoins()
    local coins = 0
    pcall(function()
        if Replion and Replion.Client then
            local DataReplion = Replion.Client:WaitReplion("Data", 1)
            if DataReplion then
                coins = DataReplion:Get("Coins") or DataReplion:Get({"Coins"}) or coins
            end
        end
    end)
    -- Leaderstats fallback
    pcall(function()
        local ls = LocalPlayer:FindFirstChild("leaderstats")
        if ls and ls:FindFirstChild("Coins") then
            coins = ls.Coins.Value or coins
        end
    end)
    return coins or 0
end

-- Get current merchant stock details
local function GetMerchantStockDetails()
    local merchantReplion = GetMerchantReplion()
    if not merchantReplion or not merchantReplion.Data or not merchantReplion.Data.Items then
        return {}
    end
    
    local itemDetails = {}
    local MarketItemData = nil
    
    pcall(function()
        local shared = ReplicatedStorage:FindFirstChild("Shared")
        if shared then
            local marketModule = shared:FindFirstChild("MarketItemData")
            if marketModule then MarketItemData = require(marketModule) end
        end
    end)
    
    if not MarketItemData then return {} end
    
    for _, itemID in ipairs(merchantReplion.Data.Items) do
        for _, data in ipairs(MarketItemData) do
            if data.Id == itemID and not data.SkinCrate then
                local name = data.Identifier or "Unknown"
                table.insert(itemDetails, {
                    ID = itemID,
                    Name = name,
                    Price = data.Price or 0,
                    Currency = data.Currency or "Coins",
                })
            end
        end
    end
    
    return itemDetails
end

-- Buy item from merchant
local function BuyMerchantItem(itemID, itemName)
    print("[DEBUG] BuyMerchantItem called: ID=" .. tostring(itemID) .. ", Name=" .. tostring(itemName))
    
    -- Get remote from Remotes table (with lazy retry if nil)
    local purchaseRemote = Remotes.RF_PurchaseMarketItem
    if not purchaseRemote then
        -- Attempt lazy discovery (in case init failed)
        pcall(function()
            purchaseRemote = Net:WaitForChild("RF/PurchaseMarketItem", 3)
            if purchaseRemote then
                Remotes.RF_PurchaseMarketItem = purchaseRemote
            end
        end)
    end
    
    if not purchaseRemote then
        print("[DEBUG] BuyMerchantItem: Remotes.RF_PurchaseMarketItem is nil!")
        WindUI:Notify({
            Title = "Remote Not Found",
            Content = "RF/PurchaseMarketItem not available",
            Duration = 3
        })
        return false
    end
    
    -- Cooldown check (0.6 seconds)
    if os.time() - MerchantState.lastBuyTime < 0.6 then
        if CONFIG.DEBUG then print("[DEBUG] BuyMerchantItem: Cooldown active") end
        return false
    end
    
    print("[DEBUG] BuyMerchantItem: Invoking server with ID=" .. tostring(itemID))
    local success, result = pcall(function()
        return purchaseRemote:InvokeServer(itemID)
    end)
    
    MerchantState.lastBuyTime = os.time()
    
    if success then
        print("[DEBUG] BuyMerchantItem: SUCCESS - " .. itemName)
        WindUI:Notify({
            Title = "Purchase Success",
            Content = "Bought: " .. itemName,
            Duration = 2
        })
    else
        print("[DEBUG] BuyMerchantItem: FAILED - " .. tostring(result))
        WindUI:Notify({
            Title = "Purchase Failed",
            Content = "Failed: " .. tostring(result),
            Duration = 2
        })
    end
    
    return success
end

-- Auto-Buy Monitoring Loop
local function RunAutoBuyLoop()
    if MerchantState.thread then
        pcall(function() task.cancel(MerchantState.thread) end)
    end
    
    MerchantState.isMonitoring = true
    
    MerchantState.thread = task.spawn(function()
        print("[DEBUG] RunAutoBuyLoop: Started")
        
        while MerchantState.isMonitoring and SavedSettings.autoBuyMerchantEnabled do
            -- Get current stock
            local stock = GetMerchantStockDetails()
            
            if #stock > 0 then
                print("[DEBUG] RunAutoBuyLoop: Merchant has " .. #stock .. " items")
                
                if MerchantState.statusParagraph then
                    MerchantState.statusParagraph:SetDesc("Merchant Active - " .. #stock .. " items")
                end
                
                -- Check if any wanted items are in stock
                local buyList = SavedSettings.merchantBuyList or {}
                for _, stockItem in ipairs(stock) do
                    for _, wantedName in ipairs(buyList) do
                        if stockItem.Name:lower():find(wantedName:lower()) then
                            print("[DEBUG] RunAutoBuyLoop: Found wanted item: " .. stockItem.Name)
                            -- Pre-check coins to avoid futile purchase attempts
                            local coins = GetPlayerCoins()
                            if coins < (stockItem.Price or 0) then
                                if MerchantState.statusParagraph then
                                    MerchantState.statusParagraph:SetDesc("Insufficient coins for: " .. stockItem.Name)
                                end
                                -- Wait longer before retrying to avoid busy loops
                                task.wait(30)
                                break
                            end

                            local ok = BuyMerchantItem(stockItem.ID, stockItem.Name)
                            if not ok then
                                -- If purchase failed, wait a bit longer before retry
                                task.wait(5)
                            else
                                -- Short delay between successful purchases
                                task.wait(0.6)
                            end
                        end
                    end
                end
            else
                if MerchantState.statusParagraph then
                    MerchantState.statusParagraph:SetDesc("⏳ Waiting for Merchant...")
                end
            end
            
            task.wait(3) -- Check every 3 seconds
        end
        
        print("[DEBUG] RunAutoBuyLoop: Stopped")
    end)
end

local function StopAutoBuyLoop()
    MerchantState.isMonitoring = false
    if MerchantState.thread then
        pcall(function() task.cancel(MerchantState.thread) end)
        MerchantState.thread = nil
    end
end

-- Remote Logger Helper (for finding unknown remotes)
local function LogAllRemotes()
    local remotes = {}
    local function scan(parent, path)
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then
                table.insert(remotes, {
                    Name = child.Name,
                    Type = child.ClassName,
                    Path = path .. "/" .. child.Name
                })
            end
            if #child:GetChildren() > 0 then
                scan(child, path .. "/" .. child.Name)
            end
        end
    end
    
    pcall(function() scan(Net, "Net") end)
    
    print("=== REMOTE LOGGER ===")
    for _, r in ipairs(remotes) do
        print(string.format("[%s] %s @ %s", r.Type, r.Name, r.Path))
    end
    print("=== END (" .. #remotes .. " remotes) ===")
    
    return remotes
end

--====================================
-- ROTATION MANAGER (v1.9.5)
--====================================
local RotationState = {
    thread = nil,
    currentLocationIndex = 0, -- Will be loaded from SavedSettings.lastRotationIndex
    lastRotationTime = 0,
    statusParagraph = nil,
    isActive = false,
    -- v2.5: Event integration state
    isPaused = false,           -- Paused by event
    savedPosition = nil,        -- Position before event teleport
    savedLocationName = nil,    -- Location name for resume
    -- Constants consolidated here
    LOCATIONS = {
        ["Crater Island"] = Vector3.new(991, 21, 5059),
        ["Kohana"] = Vector3.new(-616, 3, 567),
        ["Christmas Island"] = Vector3.new(1154, 23, 1573),
        ["Ancient Ruin"] = Vector3.new(6052, -586, 4715),
        -- v3.0.3: New Years 2026 Event (dynamic, updated by guard)
        ["New Years 2026"] = Vector3.new(0, 0, 0), -- Placeholder, updated dynamically
    },
    LOCATION_NAMES = {"Crater Island", "Kohana", "Christmas Island", "Ancient Ruin", "New Years 2026"},
    GUARDS = {
        ["Ancient Ruin"] = function()
            return IsRuinDoorOpen()
        end,
        -- v3.0.9: New Years 2026 guard is defined AFTER table to fix upvalue issue
    },
}

-- v3.0.9: New Years 2026 guard - MUST be defined after RotationState exists
-- (Defining inside the table literal causes nil reference because RotationState
-- doesn't exist yet during table construction)
RotationState.GUARDS["New Years 2026"] = function()
    -- VERSION MARKER: v3.0.9
    if CONFIG.DEBUG then
        print("[Guard] New Years 2026 v3.0.9 invoked")
    end
    
    local state = EventState.NewYearsWhale
    if not state then return false end
    
    local now = tick()
    
    -- Priority 1: Cache is ready - use it (ACCESSIBLE)
    if state.cachedCFrame and state.lastSeenAt then
        local age = now - state.lastSeenAt
        local graceSeconds = state.MISSING_GRACE_SECONDS or 30
        if age < graceSeconds then
            local pos = state.cachedCFrame.Position
            if pos then
                RotationState.LOCATIONS["New Years 2026"] = Vector3.new(pos.X, pos.Y + 10, pos.Z)
                return true
            end
        end
    end
    
    -- Priority 2: Try to get live event CFrame directly (ACCESSIBLE)
    if state.GetEventCFrame then
        local eventCF = nil
        pcall(function() eventCF = state.GetEventCFrame() end)
        if eventCF and typeof(eventCF) == "CFrame" then
            local pos = eventCF.Position
            if pos then
                RotationState.LOCATIONS["New Years 2026"] = Vector3.new(pos.X, pos.Y + 10, pos.Z)
                state.cachedCFrame = eventCF
                state.lastSeenAt = now
                return true
            end
        end
    end
    
    -- Event not visible - start assist mode to trigger staging
    if not state.enabled and state.StartAssist then
        pcall(function()
            state.StartAssist()
            if CONFIG.DEBUG then
                print("[Rotation] New Years 2026: Started assist mode for staging")
            end
        end)
    end
    
    -- Check if assist is timing out (INACCESSIBLE after timeout)
    if state.assistMode and state.assistStartedAt and state.assistStartedAt > 0 then
        local assistAge = now - state.assistStartedAt
        local timeout = state.ASSIST_TIMEOUT or 60
        if assistAge > timeout then
            if state.StopAssist then
                pcall(state.StopAssist)
            end
            if CONFIG.DEBUG then
                print("[Rotation] New Years 2026: Assist timed out, skipping")
            end
            return false  -- Timed out, allow skip
        end
    end
    
    -- Set staging destination for rotation to use
    local fishermanCF = state.FISHERMAN_CFRAME
    if fishermanCF and typeof(fishermanCF) == "CFrame" then
        local fishermanPos = fishermanCF.Position
        if fishermanPos then
            RotationState.LOCATIONS["New Years 2026"] = Vector3.new(fishermanPos.X, fishermanPos.Y + 5, fishermanPos.Z)
        end
    end
    
    -- Return PENDING - don't skip, rotation should wait
    return "PENDING"
end

-- v3.0.8: Unified guard invocation helper (avoids duplicated logic)
-- Returns: status ("ok"/"pending"/"skip"/"error"), position or nil, errorMsg or nil
RotationState.InvokeGuard = function(locationName)
    local guard = RotationState.GUARDS and RotationState.GUARDS[locationName]
    
    -- No guard = accessible
    if not guard then
        return "ok", RotationState.LOCATIONS[locationName], nil
    end
    
    -- Guard exists but isn't a function
    if type(guard) ~= "function" then
        local errMsg = "guard is " .. type(guard) .. ", not function"
        if CONFIG.DEBUG then
            print("[Rotation] " .. locationName .. " guard error: " .. errMsg)
        end
        return "error", nil, errMsg
    end
    
    -- Invoke guard with pcall
    local ok, result = pcall(guard)
    
    if not ok then
        -- pcall failed - result is the error message
        local errMsg = tostring(result)
        if CONFIG.DEBUG then
            print("[Rotation] " .. locationName .. " guard threw: " .. errMsg)
        end
        return "error", nil, errMsg
    end
    
    -- Guard returned successfully
    if result == "PENDING" then
        return "pending", RotationState.LOCATIONS[locationName], nil
    elseif result == true then
        return "ok", RotationState.LOCATIONS[locationName], nil
    else
        -- false or nil = skip
        return "skip", nil, nil
    end
end

-- v2.7: Sync rotation index from basePointName on startup
-- This ensures rotation continues from where basePointName is set
task.defer(function()
    local enabled = SavedSettings.rotationLocations or {}
    local baseName = SavedSettings.basePointName
    
    -- Find index of basePointName in rotation locations
    if baseName and #enabled > 0 then
        for i, name in ipairs(enabled) do
            if name == baseName then
                RotationState.currentLocationIndex = i
                if CONFIG.DEBUG then 
                    print("[Rotation] Synced index from basePoint: " .. baseName .. " (index " .. i .. ")")
                end
                return
            end
        end
    end
    
    -- Fallback: use saved index or start at 1
    if SavedSettings.lastRotationIndex and SavedSettings.lastRotationIndex > 0 then
        RotationState.currentLocationIndex = SavedSettings.lastRotationIndex
        if CONFIG.DEBUG then 
            print("[Rotation] Loaded last index: " .. RotationState.currentLocationIndex)
        end
    end
end)

-- Get enabled rotation locations from settings (v1.9.5: array-based)
local function GetEnabledRotationLocations()
    return SavedSettings.rotationLocations or {}
end

-- Get next rotation location (round-robin with guard check)
-- v3.0.6: Supports PENDING guard state (wait, don't skip)
local function GetNextRotationLocation()
    local enabled = GetEnabledRotationLocations()
    if #enabled == 0 then return nil, nil end
    
    local startIndex = RotationState.currentLocationIndex
    local attempts = 0
    local hasPending = false  -- Track if any location is PENDING
    
    while attempts < #enabled do
        RotationState.currentLocationIndex = (RotationState.currentLocationIndex % #enabled) + 1
        local locationName = enabled[RotationState.currentLocationIndex]
        
        -- v2.7: Update basePointName to sync with rotation (SINGLE SOURCE OF TRUTH)
        SavedSettings.basePointName = locationName
        SavedSettings.lastRotationIndex = RotationState.currentLocationIndex
        pcall(SaveSettings)
        
        -- v2.7: Update UI dropdown to reflect current location
        if EventState.basePointDropdown then
            pcall(function()
                EventState.basePointDropdown:SetValue(locationName)
            end)
        end
        
        if CONFIG.DEBUG then
            print("[Rotation] Base point synced to: " .. locationName)
        end
        
        -- Check location guard using unified helper
        -- v3.0.8: Use InvokeGuard helper for consistent handling
        local guardStatus, guardPos, guardErr = RotationState.InvokeGuard(locationName)
        
        if guardStatus == "error" then
            if CONFIG.DEBUG then
                print("[Rotation] Skipping " .. locationName .. " (guard error: " .. tostring(guardErr) .. ")")
            end
            attempts = attempts + 1
            continue
        end
        
        if guardStatus == "pending" then
            if CONFIG.DEBUG then
                print("[Rotation] " .. locationName .. " is PENDING (staging in progress)")
            end
            hasPending = true
            return locationName, guardPos
        end
        
        if guardStatus == "skip" then
            if CONFIG.DEBUG then
                print("[Rotation] Skipping " .. locationName .. " (locked/inaccessible)")
            end
            attempts = attempts + 1
            continue
        end
        
        -- guardStatus == "ok" - accessible
        
        -- v3.0.5: Stop assist mode if moving away from New Years 2026
        if locationName ~= "New Years 2026" then
            local state = EventState.NewYearsWhale
            if state and state.assistMode and state.StopAssist then
                state.StopAssist()
                if CONFIG.DEBUG then
                    print("[Rotation] Stopped New Years assist (moving to " .. locationName .. ")")
                end
            end
        end
        
        return locationName, RotationState.LOCATIONS[locationName]
    end
    
    -- All locations locked/inaccessible (but not if any was PENDING)
    if hasPending then
        -- Don't print "all inaccessible" if something is pending
        return nil, nil
    end
    if CONFIG.DEBUG then print("[Rotation] All locations inaccessible") end
    return nil, nil
end

-- Get CURRENT rotation target (not next - used by unified nav)
-- Returns: position, name of current rotation location (based on index)
-- v3.0.8: Uses unified InvokeGuard helper
local function GetCurrentRotationTargetImpl()
    local enabled = GetEnabledRotationLocations()
    if #enabled == 0 then return nil, nil end
    
    -- Clamp index to valid range
    local idx = RotationState.currentLocationIndex
    if idx < 1 or idx > #enabled then
        idx = 1
    end
    
    local locationName = enabled[idx]
    
    -- Check guard for current location using unified helper
    local guardStatus, guardPos, _ = RotationState.InvokeGuard(locationName)
    
    -- Handle accessible or pending (both return position)
    if guardStatus == "ok" or guardStatus == "pending" then
        return guardPos, locationName
    end
    
    -- Handle inaccessible (error or skip) - try to find any accessible one
    for i, name in ipairs(enabled) do
        local status, pos, _ = RotationState.InvokeGuard(name)
        if status == "ok" or status == "pending" then
            return pos, name
        end
    end
    
    return nil, nil -- All locked
end

-- Assign to forward declaration (declared in Unified Navigation System)
GetCurrentRotationTarget = GetCurrentRotationTargetImpl

--====================================
-- WORLD TOTEM SENSOR (v1.9.7 - Time Remaining Detection)
--====================================
-- ParseTimer helper function (used by totem detection)
local function ParseTotemTimer(timerText)
    if not timerText or timerText == "" then return 0 end
    timerText = timerText:gsub("[^%d:]", "")
    local parts = {}
    for part in timerText:gmatch("(%d+)") do
        table.insert(parts, tonumber(part) or 0)
    end
    if #parts == 3 then return parts[1] * 3600 + parts[2] * 60 + parts[3]
    elseif #parts == 2 then return parts[1] * 60 + parts[2]
    elseif #parts == 1 then return parts[1]
    end
    return 0
end

-- Format seconds to readable time string (used by multiple features)
FormatTimeRemaining = function(seconds)
    if seconds <= 0 then return "0:00" end
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
    return string.format("%d:%02d", m, s)
end

-- Scan workspace.Totems for active totems near player
-- Returns: count, hasNearby, maxTimeRemaining, foundTotems
ScanForNearbyTotems = function()
    local character = LocalPlayer.Character
    if not character then return 0, false, 0, {} end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return 0, false, 0, {} end
    
    local playerPos = hrp.Position
    local detectedCount = 0
    local foundTotems = {}
    local maxTime = 0
    
    -- Primary detection: workspace.Totems folder
    local totemsFolder = Workspace:FindFirstChild("Totems")
    if totemsFolder then
        for _, totem in ipairs(totemsFolder:GetChildren()) do
            local handle = totem:FindFirstChild("Handle")
            if handle then
                local totemPos = handle.Position
                local distance = (playerPos - totemPos).Magnitude
                
                if distance <= TotemSensorState.CONFIG.DETECTION_RADIUS then
                    local overhead = handle:FindFirstChild("Overhead")
                    local content = overhead and overhead:FindFirstChild("Content")
                    local timerLabel = content and content:FindFirstChild("TimerLabel")
                    
                    if timerLabel and timerLabel:IsA("TextLabel") then
                        local timerText = timerLabel.Text or ""
                        local timeSeconds = ParseTotemTimer(timerText)
                        
                        detectedCount = detectedCount + 1
                        table.insert(foundTotems, {
                            Name = totem.Name,
                            Distance = math.floor(distance),
                            TimerText = timerText,
                            TimeSeconds = timeSeconds
                        })
                        
                        if timeSeconds > maxTime then
                            maxTime = timeSeconds
                        end
                    end
                end
            end
        end
    end
    
    TotemSensorState.lastDetectedCount = detectedCount
    TotemSensorState.isTotemNearby = detectedCount > 0
    TotemSensorState.maxTimeRemaining = maxTime
    TotemSensorState.foundTotems = foundTotems
    
    if CONFIG.DEBUG and detectedCount > 0 then
        print(string.format("[TotemSensor] %d totems, max time: %s", detectedCount, FormatTimeRemaining(maxTime)))
    end
    
    return detectedCount, TotemSensorState.isTotemNearby, maxTime, foundTotems
end

-- Check if we should place totems at CURRENT location
-- Returns: shouldPlace, reason
-- Logic: ONLY place if NO totems nearby (regardless of time)
-- The "expiring" logic is for rotation decision, not placement
local function ShouldPlaceTotem()
    local count, hasNearby, maxTime = ScanForNearbyTotems()
    
    if not hasNearby then
        return true, "No totems nearby"
    end
    
    -- If there ARE totems (any time remaining), don't place more
    return false, string.format("%d active (%s)", count, FormatTimeRemaining(maxTime))
end

-- Check if totem time is low (for rotation/warning purposes)
local function IsTotemExpiringSoon()
    local count, hasNearby, maxTime = ScanForNearbyTotems()
    if not hasNearby then return true, 0 end
    return maxTime < TotemSensorState.CONFIG.MIN_TIME_THRESHOLD, maxTime
end

-- Format totem sensor status for UI
FormatTotemSensorStatus = function()
    local count, hasNearby, maxTime, totems = ScanForNearbyTotems()
    
    if hasNearby then
        local lines = {
            string.format("%d Totem(s) Active", count),
            string.format("Max Time: %s", FormatTimeRemaining(maxTime)),
        }
        
        for i, t in ipairs(totems) do
            if i > 3 then 
                table.insert(lines, string.format("  ... +%d more", count - 3))
                break 
            end
            table.insert(lines, string.format("  %d. %s", i, t.TimerText))
        end
        
        if maxTime > 0 and maxTime < TotemSensorState.CONFIG.MIN_TIME_THRESHOLD then
            table.insert(lines, "WARNING: Expiring soon!")
        end
        
        return table.concat(lines, "\n")
    else
        return "No Totem Nearby\nReady to place"
    end
end

-- Start totem sensor updater (low-frequency)
local function StartTotemSensorUpdater()
    if TotemSensorState.updateThread then
        pcall(function() task.cancel(TotemSensorState.updateThread) end)
    end
    
    TotemSensorState.isActive = true
    TotemSensorState.updateThread = task.spawn(function()
        while TotemSensorState.isActive do
            if TotemSensorState.statusParagraph then
                TotemSensorState.statusParagraph:SetDesc(FormatTotemSensorStatus())
            end
            task.wait(TotemSensorState.CONFIG.SCAN_INTERVAL)
        end
    end)
end

--====================================
-- SMART NAVIGATION HIERARCHY (v1.9.5)
--====================================
-- Priority: Active Event > Physical Totem > Hourly Rotation
-- Sequence: Teleport First → Verify Position → Check Totem → Place if needed

local function ShouldBlockRotation()
    -- Block if totem ritual is active (HIGHEST PRIORITY)
    if TotemState and TotemState.active then
        return true, "Totem ritual active"
    end
    
    -- Block if rotation is paused (by event)
    if RotationState.isPaused then
        return true, "Paused for event"
    end
    
    -- Block if any event is active (HIGHEST PRIORITY)
    if EventState.isInEventZone then
        return true, "Event zone active"
    end
    
    if EventState.christmasCaveActive then
        return true, "Christmas Cave active"
    end
    
    if EventState.lochnessActive then
        return true, "Lochness active"
    end
    
    -- v1.9.7: Block if totem nearby with sufficient time remaining
    if TotemSensorState.isTotemNearby then
        local maxTime = TotemSensorState.maxTimeRemaining or 0
        -- Only block if totems have more than threshold time
        if maxTime >= TotemSensorState.CONFIG.MIN_TIME_THRESHOLD then
            return true, string.format("%d totems (%s left)", TotemSensorState.lastDetectedCount, FormatTimeRemaining(maxTime))
        end
        -- Allow rotation if totems expiring soon (will trigger auto-place)
    end
    
    return false, nil
end

--====================================
-- SMART EXECUTION SEQUENCE (v1.9.5)
--====================================
-- Teleport → Verify → Scan Totem → Place if needed

local function ExecuteSmartSequence(targetPos, locationName, onComplete)
    if CONFIG.DEBUG then
        print("[SmartSeq] Starting sequence for: " .. locationName)
    end
    
    -- STEP 1: Teleport with verification
    VerifiedTeleport(targetPos, 
        function()
            if CONFIG.DEBUG then
                print("[SmartSeq] STEP 1 Complete: Teleported to " .. locationName)
            end
            
            -- STEP 2: Wait for physics to settle
            task.wait(1.0) -- Increased from 0.5s for better physics settle
            
            -- STEP 3: Equip rod
            EquipRod()
            
            -- STEP 4: Check for physical totems (only if auto-totem enabled)
            if SavedSettings.autoTotemAfterTeleport then
                task.wait(0.5) -- Brief delay before scanning
                
                -- v2.6.2: Use polling system for smart totem placement
                StartAutoTotemPolling("rotation teleport")
            end
            
            if onComplete then onComplete(true) end
        end,
        function(failReason)
            if CONFIG.DEBUG then
                print("[SmartSeq] Failed: " .. failReason)
            end
            if onComplete then onComplete(false) end
        end
    )
end

--====================================
-- ROTATION PAUSE/RESUME (v2.5: Event Integration)
--====================================

-- Pause rotation and save current state (assigned to forward declaration)
PauseRotation = function(reason)
    if not RotationState.isActive then return end
    
    RotationState.isPaused = true
    
    -- Save current position for return
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        RotationState.savedPosition = hrp.Position
    end
    
    if CONFIG.DEBUG then
        print("[Rotation] Paused: " .. (reason or "Event"))
    end
    
    if RotationState.statusParagraph then
        RotationState.statusParagraph:SetDesc("PAUSED: " .. (reason or "Event active"))
    end
end

-- Resume rotation after event ends (assigned to forward declaration)
ResumeRotation = function()
    if not RotationState.isActive then return end
    
    RotationState.isPaused = false
    
    -- v2.7: Simply return to basePointName (which IS the current rotation location)
    local targetPos, targetName, source = GetCurrentTargetLocation()
    
    if targetPos then
        VerifiedTeleport(targetPos, function()
            if CONFIG.DEBUG then
                print("[Rotation] Resumed: teleported to " .. targetName)
            end
            RotationState.savedPosition = nil
            RotationState.lastRotationTime = os.time() -- Reset timer
        end)
    else
        RotationState.lastRotationTime = os.time() -- Reset timer
    end
    
    if CONFIG.DEBUG then
        print("[Rotation] Resumed")
    end
end

-- Rotation Manager Loop (v1.9.7: Totem-Primary + Interval-Fallback)
-- Logic:
-- 1. If totem has enough time (>= 5 min) → STAY (ignore interval)
-- 2. If totem expiring (< 5 min) → ROTATE immediately
-- 3. If no totem detected → use interval as fallback
local function StartRotationManager()
    if RotationState.thread then
        pcall(function() task.cancel(RotationState.thread) end)
    end
    
    RotationState.isActive = true
    RotationState.isPaused = false
    RotationState.lastRotationTime = os.time()
    
    RotationState.thread = task.spawn(function()
        while RotationState.isActive and SavedSettings.rotationEnabled do
            local enabled = GetEnabledRotationLocations()
            local intervalSeconds = (SavedSettings.rotationIntervalMinutes or 60) * 60
            local timeSinceRotation = os.time() - RotationState.lastRotationTime
            local timeUntilRotation = intervalSeconds - timeSinceRotation
            
            -- Scan for totems
            local totemCount, hasTotem, maxTotemTime = ScanForNearbyTotems()
            local totemExpiring = hasTotem and maxTotemTime < TotemSensorState.CONFIG.MIN_TIME_THRESHOLD
            
            -- Determine rotation trigger
            local shouldRotate = false
            local rotateReason = ""
            
            if hasTotem and maxTotemTime >= TotemSensorState.CONFIG.MIN_TIME_THRESHOLD then
                -- Totem has enough time → STAY (override interval)
                shouldRotate = false
                rotateReason = string.format("Totem active (%s left)", FormatTimeRemaining(maxTotemTime))
            elseif totemExpiring then
                -- Totem expiring → ROTATE immediately
                shouldRotate = true
                rotateReason = string.format("Totem expiring (%s left)", FormatTimeRemaining(maxTotemTime))
            elseif not hasTotem and timeSinceRotation >= intervalSeconds then
                -- No totem + interval reached → ROTATE (fallback)
                shouldRotate = true
                rotateReason = "Interval reached (no totem)"
            end
            
            -- Update UI status
            if RotationState.statusParagraph then
                local blocked, blockReason = ShouldBlockRotation()
                if blocked and not totemExpiring then
                    RotationState.statusParagraph:SetDesc("Paused: " .. blockReason)
                elseif #enabled == 0 then
                    RotationState.statusParagraph:SetDesc("No locations selected")
                else
                    local nextLocation = enabled[(RotationState.currentLocationIndex % #enabled) + 1]
                    local statusLines = {
                        string.format("Next: %s", nextLocation),
                    }
                    if hasTotem then
                        statusLines[#statusLines + 1] = string.format("Totem: %s", FormatTimeRemaining(maxTotemTime))
                        if totemExpiring then
                            statusLines[#statusLines + 1] = "Expiring soon!"
                        end
                    else
                        statusLines[#statusLines + 1] = string.format("Fallback: %s", FormatHMS(math.max(0, timeUntilRotation)))
                    end
                    statusLines[#statusLines + 1] = string.format("%d location(s)", #enabled)
                    RotationState.statusParagraph:SetDesc(table.concat(statusLines, "\n"))
                end
            end
            
            -- Execute rotation if triggered
            if shouldRotate and #enabled > 0 then
                local blocked, blockReason = ShouldBlockRotation()
                -- Allow rotation if totem expiring (override other blocks except events)
                local canRotate = not blocked or (totemExpiring and not EventState.isInEventZone)
                
                if canRotate then
                    local locationName, targetPos = GetNextRotationLocation()
                    
                    if targetPos then
                        if CONFIG.DEBUG then
                            print("[Rotation] " .. rotateReason .. " → " .. locationName)
                        end
                        
                        ExecuteSmartSequence(targetPos, locationName, function(success)
                            if success then
                                RotationState.lastRotationTime = os.time()
                            end
                        end)
                    end
                else
                    if CONFIG.DEBUG then
                        print("[Rotation] Blocked: " .. blockReason)
                    end
                end
            end
            
            task.wait(5) -- Poll every 5 seconds
        end
        
        if CONFIG.DEBUG then print("[Rotation] Manager stopped") end
    end)
end

local function StopRotationManager()
    RotationState.isActive = false
    if RotationState.thread then
        pcall(function() task.cancel(RotationState.thread) end)
        RotationState.thread = nil
    end
end

--====================================
-- v2.2: WEBHOOK MODULE (yesbgt.lua Style + SafeRequire)
--====================================

-- SafeRequire: Load module with timeout to avoid Infinite Yield
-- Cache stored in WebhookModule to reduce top-level locals
-- local cache to avoid referencing WebhookModule before it's defined
local _itemUtilityCache = nil

local function SafeRequireItemUtility()
    if _itemUtilityCache then return _itemUtilityCache end
    
    local success, result = pcall(function()
        -- yesbgt.lua path: RepStorage.Shared.ItemUtility
        local shared = ReplicatedStorage:FindFirstChild("Shared")
        if shared then
            local itemUtil = shared:FindFirstChild("ItemUtility")
            if itemUtil then
                return require(itemUtil)
            end
        end
        
        -- Fallback: Try Modules path
        local modules = ReplicatedStorage:FindFirstChild("Modules")
        if modules then
            local itemUtil = modules:FindFirstChild("ItemUtility")
            if itemUtil then
                return require(itemUtil)
            end
        end
        
        return nil
    end)
    
    if success and result then
        _itemUtilityCache = result
        if CONFIG.DEBUG then log("[Webhook] ItemUtility loaded successfully") end
        return result
    end
    
    if CONFIG.DEBUG then log("[Webhook] ItemUtility not found, using fallback") end
    return nil
end

local WebhookModule = {
    imageCache = {},
    totalCaught = 0,
    
    -- Rarity Colors (yesbgt.lua style)
    RarityColors = {
        SECRET = 0xFFD700,    -- Gold
        MYTHIC = 0x9400D3,    -- Purple
        LEGENDARY = 0xFF4500, -- Orange-Red
        EPIC = 0x8A2BE2,      -- Blue-Violet
        RARE = 0x0000FF,      -- Blue
        UNCOMMON = 0x00FF00,  -- Green
        COMMON = 0x808080,    -- Gray
        DEFAULT = 0x00BFFF    -- Light Blue
    },
}

function WebhookModule.FormatNumber(n)
    if not n then return "0" end
    local formatted = tostring(math.floor(n))
    local result = ""
    local len = #formatted
    for i = 1, len do
        if i > 1 and (len - i + 1) % 3 == 0 then
            result = result .. "."
        end
        result = result .. formatted:sub(i, i)
    end
    return result
end

function WebhookModule.GetRarityColor(rarity)
    local upper = rarity and string.upper(tostring(rarity)) or ""
    return WebhookModule.RarityColors[upper] or WebhookModule.RarityColors.DEFAULT
end

function WebhookModule.GetRobloxAssetImage(assetId)
    if not assetId then return nil end
    
    -- Cache eviction: limit to 100 entries
    local cacheCount = 0
    for _ in pairs(WebhookModule.imageCache) do cacheCount = cacheCount + 1 end
    if cacheCount > 100 then
        local toRemove = cacheCount - 50
        for k in pairs(WebhookModule.imageCache) do
            if toRemove <= 0 then break end
            WebhookModule.imageCache[k] = nil
            toRemove = toRemove - 1
        end
        if CONFIG.DEBUG then log("[Webhook] Image cache pruned to 50 entries") end
    end
    
    -- Check cache first
    if WebhookModule.imageCache[assetId] then
        return WebhookModule.imageCache[assetId]
    end
    
    local success, result = pcall(function()
        local url = string.format(
            "https://thumbnails.roblox.com/v1/assets?assetIds=%s&size=420x420&format=Png&isCircular=false",
            tostring(assetId)
        )
        local response = game:GetService("HttpService"):JSONDecode(
            game:HttpGet(url)
        )
        if response and response.data and response.data[1] then
            return response.data[1].imageUrl
        end
        return nil
    end)
    
    if success and result then
        WebhookModule.imageCache[assetId] = result
        return result
    end
    return nil
end

function WebhookModule.SendWebhook(embedData)
    if not SavedSettings.webhookEnabled or SavedSettings.webhookURL == "" then
        return false
    end
    
    -- Async send via task.spawn
    task.spawn(function()
        local maxRetries = 5
        local retryDelay = 1.5
        
        for attempt = 1, maxRetries do
            local success, err = pcall(function()
                local HttpService = game:GetService("HttpService")
                local payload = HttpService:JSONEncode({
                    embeds = {embedData}
                })
                
                -- Use syn.request or request if available
                local httpFunc = syn and syn.request or request or http_request
                if httpFunc then
                    httpFunc({
                        Url = SavedSettings.webhookURL,
                        Method = "POST",
                        Headers = {["Content-Type"] = "application/json"},
                        Body = payload
                    })
                end
            end)
            
            if success then
                if CONFIG.DEBUG then log("[Webhook] Sent successfully (attempt " .. attempt .. ")") end
                return true
            else
                if CONFIG.DEBUG then log("[Webhook] Attempt " .. attempt .. " failed: " .. tostring(err)) end
                if attempt < maxRetries then
                    task.wait(retryDelay)
                end
            end
        end
        return false
    end)
    
    return true
end

-- Helper: Get fish name and rarity from ItemUtility (v2.7.1: Fixed rarity detection)
function WebhookModule.GetFishInfo(itemId, metadata)
    local fishName = tostring(itemId) -- Fallback to ID as string
    local fishRarity = "COMMON"
    local sellPrice = 0
    local assetId = nil
    
    -- Debug: Log incoming data
    if CONFIG.DEBUG then
        log(string.format("[Webhook] GetFishInfo called: itemId=%s, type=%s", tostring(itemId), type(itemId)))
        if metadata then
            log(string.format("[Webhook] Metadata: Rarity=%s, Weight=%.2f", tostring(metadata.Rarity or "nil"), metadata.Weight or 0))
        end
    end
    
    -- PRIORITY 1: Check metadata.Rarity first (yesbgt.lua style)
    if metadata and metadata.Rarity then
        fishRarity = metadata.Rarity
        if CONFIG.DEBUG then
            log(string.format("[Webhook] Rarity from metadata: %s", fishRarity))
        end
    end
    
    local ItemUtility = SafeRequireItemUtility()
    if ItemUtility and ItemUtility.GetItemData then
        local success, itemData = pcall(function()
            return ItemUtility:GetItemData(itemId)
        end)
        
        if success and itemData then
            -- Get fish name from itemData.Data.Name (yesbgt.lua style)
            if itemData.Data and itemData.Data.Name then
                fishName = itemData.Data.Name
            elseif itemData.Name then
                fishName = itemData.Name
            end
            
            -- PRIORITY 2: If no metadata.Rarity, use TierUtility (yesbgt.lua style)
            if fishRarity == "COMMON" and itemData.Probability and itemData.Probability.Chance and TierUtility then
                local tierSuccess, tierObj = pcall(function()
                    return TierUtility:GetTierFromRarity(itemData.Probability.Chance)
                end)
                if tierSuccess and tierObj and tierObj.Name then
                    fishRarity = tierObj.Name
                    if CONFIG.DEBUG then
                        log(string.format("[Webhook] Rarity from TierUtility: %s (chance: %s)", fishRarity, tostring(itemData.Probability.Chance)))
                    end
                end
            end
            
            sellPrice = (itemData.SellPrice or 0) * (metadata and metadata.SellMultiplier or 1)
            
            -- Get asset ID for thumbnail (yesbgt.lua style)
            if itemData.Data then
                local iconRaw = itemData.Data.Icon or itemData.Data.ImageId
                if iconRaw then
                    assetId = tonumber(string.match(tostring(iconRaw), "%d+"))
                end
            end
            
            if CONFIG.DEBUG then
                log(string.format("[Webhook] Final resolved: name=%s, rarity=%s", fishName, fishRarity))
            end
        else
            if CONFIG.DEBUG then
                log("[Webhook] ItemUtility:GetItemData failed or returned nil")
            end
        end
    else
        -- Fallback: Try FishDB
        if FishDB and FishDB[itemId] then
            fishRarity = TierToRarity[FishDB[itemId]] or fishRarity
            if CONFIG.DEBUG then
                log(string.format("[Webhook] FishDB fallback: rarity=%s", fishRarity))
            end
        end
    end
    
    return fishName, fishRarity, sellPrice, assetId
end

-- Valid mutations list (yesbgt.lua style - VariantId values that are actual mutations)
local VALID_MUTATIONS = {
    ["Shiny"] = true,
    ["Sparkling"] = true,
    ["Albino"] = true,
    ["Giant"] = true,
    ["Golden"] = true,
    ["Mythic"] = true,
    ["Negative"] = true,
    ["Electric"] = true,
    ["Frozen"] = true,
}

-- Helper: Get mutation string from metadata (v2.7.1: Fixed - only real mutations)
function WebhookModule.GetMutationString(metadata)
    if not metadata then return "None" end
    local mutations = {}
    
    -- Check boolean mutations
    if metadata.Shiny == true then table.insert(mutations, "Shiny") end
    if metadata.Sparkling == true then table.insert(mutations, "Sparkling") end
    if metadata.Albino == true then table.insert(mutations, "Albino") end
    if metadata.Giant == true then table.insert(mutations, "Giant") end
    
    -- Check VariantId - only if it's a valid mutation name (not a random UUID)
    if metadata.VariantId and type(metadata.VariantId) == "string" then
        local variantUpper = string.upper(metadata.VariantId)
        -- Only add if it's a known mutation and not already added
        if VALID_MUTATIONS[metadata.VariantId] or string.len(metadata.VariantId) < 20 then
            -- Short strings are likely mutation names, long ones are UUIDs
            if not table.find(mutations, metadata.VariantId) then
                table.insert(mutations, metadata.VariantId)
            end
        end
    end
    
    return #mutations > 0 and table.concat(mutations, ", ") or "None"
end

-- Helper: Check if fish has any mutation (for filter bypass)
function WebhookModule.HasMutation(metadata)
    if not metadata then return false end
    if metadata.Shiny == true then return true end
    if metadata.Sparkling == true then return true end
    if metadata.Albino == true then return true end
    if metadata.Giant == true then return true end
    -- VariantId check - only short strings (mutation names), not UUIDs
    if metadata.VariantId and type(metadata.VariantId) == "string" and string.len(metadata.VariantId) < 20 then
        return true
    end
    return false
end

-- Helper: Get current map/location
function WebhookModule.GetCurrentMap()
    local mapName = "Unknown"
    pcall(function()
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local pos = char.HumanoidRootPart.Position
            -- Check closest known location
            for name, coords in pairs(TELEPORT_LOCATIONS or {}) do
                if (pos - coords).Magnitude < 500 then
                    mapName = name
                    break
                end
            end
        end
    end)
    return mapName
end

-- Main: OnFishCaught (yesbgt.lua style - handles itemId, metadata, fullData)
function WebhookModule.OnFishCaught(itemId, metadata, fullData)
    if not SavedSettings.webhookEnabled then return end
    
    -- Validate arguments (fix index error)
    if type(itemId) ~= "string" and type(itemId) ~= "number" then
        -- Maybe old-style object was passed
        if type(itemId) == "table" then
            metadata = itemId.Metadata or itemId
            itemId = itemId.ItemId or itemId.Id or itemId.Name or "Unknown"
        else
            return -- Invalid data
        end
    end
    
    metadata = metadata or {}
    
    -- Get fish info using ItemUtility (yesbgt.lua style)
    local fishName, fishRarity, sellPrice, assetId = WebhookModule.GetFishInfo(itemId, metadata)
    local rarityUpper = string.upper(tostring(fishRarity))
    local weight = metadata.Weight or 0
    local mutation = WebhookModule.GetMutationString(metadata)
    local mapLocation = WebhookModule.GetCurrentMap()
    
    -- Check rarity filter
    local shouldNotify = false
    for _, allowedRarity in ipairs(SavedSettings.webhookRarityFilter or {}) do
        if string.upper(allowedRarity) == rarityUpper then
            shouldNotify = true
            break
        end
    end
    
    -- Check mutation notifications (only if fish has REAL mutation)
    if SavedSettings.webhookNotifyMutations and WebhookModule.HasMutation(metadata) then
        shouldNotify = true
    end
    
    -- DEBUG: Log filter decision
    if CONFIG.DEBUG then
        log(string.format("[Webhook] Filter check: fish=%s, rarity=%s, mutation=%s, shouldNotify=%s", 
            fishName, rarityUpper, mutation, tostring(shouldNotify)))
        log(string.format("[Webhook] Filter settings: rarityFilter=%s, notifyMutations=%s", 
            table.concat(SavedSettings.webhookRarityFilter or {}, ","), 
            tostring(SavedSettings.webhookNotifyMutations)))
    end
    
    if not shouldNotify then return end
    
    WebhookModule.totalCaught = WebhookModule.totalCaught + 1
    
    -- Get player coins (yesbgt.lua style)
    local coins = 0
    pcall(function()
        local DataReplion = Replion.Client:WaitReplion("Data")
        if DataReplion then
            coins = DataReplion:Get("Coins") or DataReplion:Get({"Coins"}) or 0
        end
    end)
    
    -- Get total caught from leaderstats
    local totalCaught = "N/A"
    pcall(function()
        local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
        if leaderstats then
            local caught = leaderstats:FindFirstChild("Caught")
            if caught then totalCaught = WebhookModule.FormatNumber(caught.Value) end
        end
    end)
    
    -- Get thumbnail
    local imageUrl = "https://tr.rbxcdn.com/53eb9b170bea9855c45c9356fb33c070/420/420/Image/Png" -- Default
    if assetId then
        local cached = WebhookModule.GetRobloxAssetImage(assetId)
        if cached then imageUrl = cached end
    end
    
    -- Build embed (yesbgt.lua style with fields)
    local embed = {
        author = {
            name = "ZlaVe ",
            icon_url = "https://cdn.discordapp.com/icons/384225409882914816/7bb6ad0a0875913d274bdb120f0eb636.png"
        },
        title = "||" .. (LocalPlayer.DisplayName or LocalPlayer.Name) .. "|| | Caught " .. tostring(fishName) .. "!",
        color = WebhookModule.GetRarityColor(rarityUpper),
        fields = {
            { name = "<:fishi:1423810463845584976> Fish Name", value = string.format("`%s`", tostring(fishName)), inline = true },
            { name = "<:chance:1423810456447090789> Rarity", value = string.format("`%s`", rarityUpper), inline = true },
            { name = "<:weight:1423810471089274911> Weight", value = string.format("`%.2f kg`", weight), inline = true },
            { name = "<:mutation:1423810466022559764> Mutation", value = string.format("`%s`", mutation), inline = true },
            { name = "<:dollar:1423810459215073371> Sell Price", value = string.format("`%s$`", WebhookModule.FormatNumber(sellPrice)), inline = true },
            { name = "<:dollar:1423810459215073371> Coins", value = string.format("`%s`", WebhookModule.FormatNumber(coins)), inline = true },
        },
        thumbnail = { url = imageUrl },
        footer = {
            text = string.format("Total Caught: %s | %s", totalCaught, os.date("%Y-%m-%d %H:%M:%S"))
        },
    }
    
    WebhookModule.SendWebhook(embed)
end

--====================================
-- v2.1: AUTO SELL MODULE (Timer-Based)
--====================================
local AutoSellModule = {
    isActive = false,
    thread = nil,
    lastSellTime = 0,
}

function AutoSellModule.ExecuteSell()
    task.spawn(function()
        pcall(function()
            if Remotes.RF_SellAll then
                Remotes.RF_SellAll:InvokeServer()
                if CONFIG.DEBUG then log("[AutoSell] Timer sell executed") end
            end
        end)
    end)
end

function AutoSellModule.Start()
    if AutoSellModule.isActive then return end
    AutoSellModule.isActive = true
    
    AutoSellModule.thread = task.spawn(function()
        while AutoSellModule.isActive and SavedSettings.autoSellEnabled do
            local interval = math.max(SavedSettings.autoSellInterval or 60, 10) -- Min 10 seconds
            task.wait(interval)
            
            if AutoSellModule.isActive and SavedSettings.autoSellEnabled then
                AutoSellModule.ExecuteSell()
                AutoSellModule.lastSellTime = tick()
            end
        end
    end)
    
    if CONFIG.DEBUG then log("[AutoSell] Timer started: " .. (SavedSettings.autoSellInterval or 60) .. "s interval") end
end

function AutoSellModule.Stop()
    AutoSellModule.isActive = false
    if AutoSellModule.thread then
        pcall(function() task.cancel(AutoSellModule.thread) end)
        AutoSellModule.thread = nil
    end
    if CONFIG.DEBUG then log("[AutoSell] Timer stopped") end
end

function AutoSellModule.Restart()
    AutoSellModule.Stop()
    if SavedSettings.autoSellEnabled then
        AutoSellModule.Start()
    end
end

-- Start on load if enabled
task.defer(function()
    if SavedSettings.autoSellEnabled then
        AutoSellModule.Start()
    end
end)

--====================================
-- v2.3: AUTO WEATHER MODULE (Fixed for WeatherMachine array)
--====================================
local AutoWeatherModule = {
    isActive = false,
    insertConnection = nil,
    removeConnection = nil,
    pollingThread = nil,
    eventsReplion = nil,
    -- Weather types populated from ReplicatedStorage.Events
    TYPES = {},
}

-- Initialize weather types from Events module
local function InitWeatherTypes()
    if #AutoWeatherModule.TYPES > 0 then return end
    
    pcall(function()
        local EventsModule = require(ReplicatedStorage:WaitForChild("Events"))
        for eventName, eventData in pairs(EventsModule) do
            if type(eventData) == "table" and eventData.WeatherMachine and eventData.WeatherMachinePrice then
                table.insert(AutoWeatherModule.TYPES, eventName)
            end
        end
        table.sort(AutoWeatherModule.TYPES)
        if CONFIG.DEBUG then log("[AutoWeather] Found weather types: " .. table.concat(AutoWeatherModule.TYPES, ", ")) end
    end)
    
    -- Fallback if module loading fails
    if #AutoWeatherModule.TYPES == 0 then
        AutoWeatherModule.TYPES = {"Luck", "Bounty", "Resilience", "Precision", "Velocity"}
    end
end

-- Initialize Events Replion for weather monitoring
local function InitEventsReplion()
    if AutoWeatherModule.eventsReplion then return AutoWeatherModule.eventsReplion end
    
    -- v2.6: Check if Replion is available first
    if not Replion or not Replion.Client then
        if CONFIG.DEBUG then log("[AutoWeather] Replion not available", "WARN") end
        return nil
    end
    
    local success, result = pcall(function()
        return Replion.Client:WaitReplion("Events", 5)
    end)
    
    if success and result then
        AutoWeatherModule.eventsReplion = result
        return result
    end
    return nil
end

-- Check if a weather type is currently active (array search)
local function IsWeatherActive(weatherName)
    local events = InitEventsReplion()
    if not events then return false end
    
    -- Use Find method for array (from decompiled: v_u_16:Find("WeatherMachine", weatherName))
    local success, found = pcall(function()
        return events:Find("WeatherMachine", weatherName)
    end)
    
    if success and found then
        return true
    end
    
    -- Fallback: manual array search
    local ok, list = pcall(function()
        return events:GetExpect("WeatherMachine")
    end)
    
    if not ok then
        ok, list = pcall(function()
            return events:Get("WeatherMachine")
        end)
    end
    
    if not ok or not list or type(list) ~= "table" then return false end
    
    for _, v in ipairs(list) do
        if v == weatherName then
            return true
        end
    end
    return false
end

-- Purchase missing weathers from the selected list
local function PurchaseMissingWeathers()
    if not SavedSettings.autoWeatherEnabled then return end
    if not SavedSettings.autoWeatherList or #SavedSettings.autoWeatherList == 0 then return end
    if not Remotes.RF_PurchaseWeather then return end
    
    for _, weather in ipairs(SavedSettings.autoWeatherList) do
        if not IsWeatherActive(weather) then
            if CONFIG.DEBUG then log("[AutoWeather] Purchasing: " .. weather) end
            local success, result = pcall(function()
                return Remotes.RF_PurchaseWeather:InvokeServer(weather)
            end)
            if CONFIG.DEBUG then log("[AutoWeather] Purchase result: " .. tostring(result)) end
            task.wait(0.5) -- Delay between purchases
        end
    end
end

function AutoWeatherModule.Start()
    if AutoWeatherModule.isActive then return end
    AutoWeatherModule.isActive = true
    
    InitWeatherTypes()
    
    local events = InitEventsReplion()
    if not events then
        warn("[AutoWeather] Failed to connect to Events Replion")
        AutoWeatherModule.isActive = false
        return
    end
    
    -- Disconnect old connections
    if AutoWeatherModule.insertConnection then
        pcall(function() AutoWeatherModule.insertConnection:Disconnect() end)
    end
    if AutoWeatherModule.removeConnection then
        pcall(function() AutoWeatherModule.removeConnection:Disconnect() end)
    end
    if AutoWeatherModule.pollingThread then
        pcall(function() task.cancel(AutoWeatherModule.pollingThread) end)
    end
    
    -- Listen for array changes (WeatherMachine is an array)
    pcall(function()
        AutoWeatherModule.insertConnection = events:OnArrayInsert("WeatherMachine", function(_, value)
            if CONFIG.DEBUG then log("[AutoWeather] Weather added: " .. tostring(value)) end
        end)
    end)
    
    pcall(function()
        AutoWeatherModule.removeConnection = events:OnArrayRemove("WeatherMachine", function(_, value)
            if CONFIG.DEBUG then log("[AutoWeather] Weather removed: " .. tostring(value)) end
            task.defer(PurchaseMissingWeathers)
        end)
    end)
    
    -- Polling fallback (every 30 seconds check and repurchase if needed)
    AutoWeatherModule.pollingThread = task.spawn(function()
        while AutoWeatherModule.isActive do
            task.wait(30)
            if AutoWeatherModule.isActive and SavedSettings.autoWeatherEnabled then
                PurchaseMissingWeathers()
            end
        end
    end)
    
    -- Initial scan
    task.defer(PurchaseMissingWeathers)
    
    if CONFIG.DEBUG then log("[AutoWeather] Started monitoring with array listeners + polling") end
end

function AutoWeatherModule.Stop()
    AutoWeatherModule.isActive = false
    
    if AutoWeatherModule.insertConnection then
        pcall(function() AutoWeatherModule.insertConnection:Disconnect() end)
        AutoWeatherModule.insertConnection = nil
    end
    if AutoWeatherModule.removeConnection then
        pcall(function() AutoWeatherModule.removeConnection:Disconnect() end)
        AutoWeatherModule.removeConnection = nil
    end
    if AutoWeatherModule.pollingThread then
        pcall(function() task.cancel(AutoWeatherModule.pollingThread) end)
        AutoWeatherModule.pollingThread = nil
    end
    
    if CONFIG.DEBUG then log("[AutoWeather] Stopped") end
end

function AutoWeatherModule.Restart()
    AutoWeatherModule.Stop()
    if SavedSettings.autoWeatherEnabled then
        AutoWeatherModule.Start()
    end
end

-- Initialize weather types early
task.defer(InitWeatherTypes)

-- Start on load if enabled
task.defer(function()
    if SavedSettings.autoWeatherEnabled then
        AutoWeatherModule.Start()
    end
end)

--====================================
-- v2.2: WEBHOOK EVENT HOOK (ObtainedNewFish) + Debug Logger
--====================================
-- Connection stored in WebhookModule to reduce top-level locals
WebhookModule.fishConnection = nil
local function StartWebhookListener()
    if WebhookModule.fishConnection then return end
    
    if Remotes.ObtainedNewFish then
        -- Event passes (itemId, metadata, fullData) - yesbgt.lua style
        WebhookModule.fishConnection = Remotes.ObtainedNewFish.OnClientEvent:Connect(function(itemId, metadata, fullData)
            -- v2.2: Debug Logger - Always log catch detection
            if CONFIG.DEBUG then
                log(string.format("[Webhook] CATCH DETECTED: itemId=%s, type=%s", tostring(itemId), type(itemId)))
                if metadata then
                    log(string.format("[Webhook] Metadata: Weight=%.2f, Shiny=%s, Variant=%s", 
                        metadata.Weight or 0, 
                        tostring(metadata.Shiny or false),
                        tostring(metadata.VariantId or "none")))
                end
            end
            
            if SavedSettings.webhookEnabled then
                task.spawn(function()
                    WebhookModule.OnFishCaught(itemId, metadata, fullData)
                end)
            end
        end)
        
        if CONFIG.DEBUG then 
            log("[Webhook] Listener connected to ObtainedNewFish") 
        else
            print("[ZlaVe] Webhook listener connected")
        end
    else
        warn("[ZlaVe] WARNING: ObtainedNewFish event not found!")
    end
end

-- Start webhook listener on load
task.defer(StartWebhookListener)

--====================================
-- UI: TAB FISHING
--====================================
local FishingTab = Window:Tab({Title = "Fishing", Icon = "anchor"})

FishingTab:Toggle({
    Title = "Auto Fish",
    Desc = "Enable/Disable automatic fishing",
    Value = SavedSettings.blatantEnabled,
    Callback = function(state)
        State.fishingRunning = state
        SavedSettings.blatantEnabled = state
        SaveSettings()
        if not state then ForceCancel() end
    end
})

-- Apply saved state on load
if SavedSettings.blatantEnabled then
    State.fishingRunning = true
end

FishingTab:Input({
    Title = "Complete Delay",
    Desc = "",
    Value = tostring(CONFIG.COMPLETE_DELAY),
    Placeholder = "Seconds",
    Callback = function(text)
        local num = tonumber(text)
        if num then CONFIG.COMPLETE_DELAY = math.max(0, num) end
    end
})

FishingTab:Input({
    Title = "Cancel Delay",
    Desc = "",
    Value = tostring(CONFIG.CANCEL_DELAY),
    Placeholder = "Seconds",
    Callback = function(text)
        local num = tonumber(text)
        if num then CONFIG.CANCEL_DELAY = math.max(0, num) end
    end
})

FishingTab:Divider()

-- Smart Rotation Section (moved from Events)
FishingTab:Section({Title = "Rotation", TextSize = 16})

RotationState.statusParagraph = FishingTab:Paragraph({
    Title = "Rotation Status",
    Content = "Status: Disabled",
})

TotemSensorState.statusParagraph = FishingTab:Paragraph({
    Title = "Totem Sensor",
    Content = "Scanning...",
})

StartTotemSensorUpdater()

FishingTab:Toggle({
    Title = "Enable Rotation",
    Desc = "Auto-rotate between selected locations",
    Value = SavedSettings.rotationEnabled or false,
    Callback = function(state)
        SavedSettings.rotationEnabled = state
        SaveSettings()
        if state then
            StartRotationManager()
            WindUI:Notify({Title = "Rotation ON", Content = "Smart rotation enabled", Duration = 2})
        else
            StopRotationManager()
            if RotationState.statusParagraph then
                RotationState.statusParagraph:SetDesc("Status: Disabled")
            end
            WindUI:Notify({Title = "Rotation OFF", Content = "Disabled", Duration = 2})
        end
    end
})

FishingTab:Dropdown({
    Title = "Rotation Locations",
    Desc = "Select locations to include in rotation",
    SearchBarEnabled = true,
    Values = RotationState.LOCATION_NAMES,
    Value = SavedSettings.rotationLocations or {"Crater Island"},
    Multi = true,
    AllowNone = true,
    Callback = function(values)
        SavedSettings.rotationLocations = values or {}
        SaveSettings()
        if CONFIG.DEBUG then
            print("[Rotation] Locations updated: " .. table.concat(values or {}, ", "))
        end
    end
})

FishingTab:Toggle({
    Title = "Auto-Totem After Teleport",
    Desc = "Place 9x totems after arriving if none nearby",
    Value = SavedSettings.autoTotemAfterTeleport or false,
    Callback = function(state)
        SavedSettings.autoTotemAfterTeleport = state
        SaveSettings()
    end
})

FishingTab:Input({
    Title = "Interval (Minutes)",
    Desc = "Time between rotations",
    Value = tostring(SavedSettings.rotationIntervalMinutes or 60),
    Placeholder = "60",
    Callback = function(text)
        local num = tonumber(text)
        if num and num >= 1 then
            SavedSettings.rotationIntervalMinutes = num
            SaveSettings()
        end
    end
})

FishingTab:Button({
    Title = "Scan Totems Now",
    Desc = "Manually scan for nearby totems",
    Callback = function()
        local count, hasNearby = ScanForNearbyTotems()
        if TotemSensorState.statusParagraph then
            TotemSensorState.statusParagraph:SetDesc(FormatTotemSensorStatus())
        end
    end
})

--====================================
-- UI: TAB TELEPORT
--====================================
local TeleportTab = Window:Tab({Title = "Teleport", Icon = "map-pin"})

TeleportTab:Dropdown({
    Title = "Select Location",
    Desc = "Choose a location to teleport",
    SearchBarEnabled = true,
    Values = (function()
        local t = {}
        for k, _ in pairs(CONFIG.TELEPORT_LOCATIONS) do table.insert(t, k) end
        table.sort(t)
        return t
    end)(),
    Value = CONFIG.selectedTeleport,
    Callback = function(option)
        CONFIG.selectedTeleport = option
    end
})

TeleportTab:Button({
    Title = "Teleport",
    Callback = function()
        local targetCFrame = CONFIG.TELEPORT_LOCATIONS[CONFIG.selectedTeleport]
        if targetCFrame and LocalPlayer.Character and LocalPlayer.Character.PrimaryPart then
            LocalPlayer.Character:SetPrimaryPartCFrame(targetCFrame)
        elseif not targetCFrame then
            WindUI:Notify({
                Title = "Teleport",
                Content = "Invalid location: " .. tostring(CONFIG.selectedTeleport),
                Duration = 3
            })
        end
    end
})

--====================================
-- UI: TAB EVENTS
--====================================
local EventsTab = Window:Tab({Title = "Events", Icon = "calendar"})

-- Base Point Section
EventsTab:Section({Title = "Base Point (Return Location)", TextSize = 16})

-- v2.7: Store dropdown reference for dynamic updates
local BasePointDropdown = EventsTab:Dropdown({
    Title = "Select Base Point",
    Desc = "Select to teleport immediately. Also used as return location after events.",
    SearchBarEnabled = true,
    Values = {"None", "Crater Island", "Kohana", "Christmas Island", "Ancient Ruin", },
    Value = SavedSettings.basePointName or "None",
    Callback = function(option)
        SavedSettings.basePointName = option
        SaveSettings()
        
        -- INSTANT TELEPORT on dropdown change (if not "None")
        if option ~= "None" then
            TeleportToBasePoint(true) -- bypass event check for manual selection
            WindUI:Notify({
                Title = "Base Point",
                Content = "Teleported to " .. option,
                Duration = 2
            })
            
            -- v2.7: Sync rotation index when base point manually changed
            if SavedSettings.rotationEnabled then
                local enabled = SavedSettings.rotationLocations or {}
                for i, name in ipairs(enabled) do
                    if name == option then
                        RotationState.currentLocationIndex = i
                        SavedSettings.lastRotationIndex = i
                        if CONFIG.DEBUG then 
                            print("[BasePoint] Synced rotation to index " .. i) 
                        end
                        break
                    end
                end
            end
        end
        
        if CONFIG.DEBUG then log("[Event] Base point set to: " .. option) end
    end
})

-- v2.7: Store reference globally for rotation updates
EventState.basePointDropdown = BasePointDropdown

EventsTab:Divider()

-- Christmas Cave Section
EventsTab:Section({Title = "Christmas Cave (Timed Event)", TextSize = 16})

EventState.christmasCaveParagraph = EventsTab:Paragraph({
    Title = "Christmas Cave Status",
    Content = "Status: Checking...",
})

local function StartChristmasCaveMonitor(uiParagraph)
    if EventState.christmasCaveConn then
        EventState.christmasCaveConn:Disconnect()
        EventState.christmasCaveConn = nil
    end
    
    -- Guard: Ensure RunService is available
    local RS = Services.RunService or game:GetService("RunService")
    if not RS then return end
    
    -- v2.9: Object-based detection (replaces time-based)
    local lastChristmasCheck = 0
    local hasTeleportedThisSession = false  -- Prevent spam teleports
    
    EventState.christmasCaveConn = RS.Heartbeat:Connect(function()
        if not SavedSettings.autoJoinChristmasCave then return end
        
        local now = tick()
        if now - lastChristmasCheck < 1 then return end
        lastChristmasCheck = now
        
        -- v2.9: Use object-based detection (method on EventState)
        local caveStatus = EventState.GetChristmasCaveStatus()
        local wasActive = EventState.christmasCaveActive
        local newState = caveStatus.state
        
        -- Handle state transitions
        if caveStatus.isActive and not wasActive then
            -- TRANSITION: closed/loading → active
            SaveCurrentPosition()
            EventState.christmasCaveActive = true
            EventState.caveActiveSince = tick()
            EventState.caveLastState = "active"
            EventState.isInEventZone = true
            hasTeleportedThisSession = false  -- Reset for new event
            
            -- Pause rotation if active
            if RotationState and RotationState.isActive then
                PauseRotation("Christmas Cave event")
            end
            
            -- Teleport to cave (only once per event)
            if not hasTeleportedThisSession then
                hasTeleportedThisSession = true
                VerifiedTeleport(EventState.COORDS.ChristmasCave, function()
                    if CONFIG.DEBUG then log("[Event] Teleported to Christmas Cave (object-detected)") end
                    WindUI:Notify({Title = "Christmas Cave", Content = "Event detected! Teleported.", Duration = 3})
                    
                    if SavedSettings.autoTotemAfterTeleport then
                        task.delay(1, function()
                            StartAutoTotemPolling("Christmas Cave event")
                        end)
                    end
                end)
            end
            
        elseif not caveStatus.isActive and wasActive and newState == "closed" then
            -- TRANSITION: active → closed
            EventState.christmasCaveActive = false
            EventState.caveActiveSince = nil
            EventState.caveLastState = "closed"
            EventState.isInEventZone = false
            hasTeleportedThisSession = false
            
            if RotationState and RotationState.isPaused then
                ResumeRotation()
            else
                SmartReturnToTarget("Christmas Cave event ended")
            end
            if CONFIG.DEBUG then log("[Event] Christmas Cave closed (object-detected)") end
        end
        
        -- Update state tracking
        EventState.caveLastState = newState
        
        -- UI UPDATE
        if uiParagraph then
            if newState == "loading" then
                uiParagraph:SetDesc("⏳ Loading... (Map not streamed)")
            elseif newState == "active" then
                local timeLeftStr = "Unknown"
                if caveStatus.timeLeftSeconds then
                    timeLeftStr = FormatHMS(caveStatus.timeLeftSeconds)
                end
                uiParagraph:SetDesc("🎄 EVENT ACTIVE\nTime Left: " .. timeLeftStr)
            else
                -- closed - show next scheduled time
                local nextTs = GetNextChristmasCaveEvent()
                if nextTs then
                    local nowUTC = NowUTC()
                    uiParagraph:SetDesc(string.format(
                        "Cave Closed\nNext (UTC): %s\nCountdown: %s",
                        FormatHM(nextTs, true),
                        FormatHMS(nextTs - nowUTC)
                    ))
                else
                    uiParagraph:SetDesc("Cave Closed\nNext: --:--")
                end
            end
        end
    end)
end

local function StopChristmasCaveMonitor()
    if EventState.christmasCaveConn then
        EventState.christmasCaveConn:Disconnect()
        EventState.christmasCaveConn = nil
    end
    EventState.christmasCaveActive = false
    EventState.caveActiveSince = nil
    EventState.caveLastState = "closed"
    EventState.isInEventZone = false
    -- v2.6: Use unified navigation
    SmartReturnToTarget("Christmas monitor stopped")
end

EventsTab:Toggle({
    Title = "Auto Join Christmas Cave",
    Desc = "Teleport to Christmas Cave during event hours (every 2h UTC)",
    Value = SavedSettings.autoJoinChristmasCave or false,
    Callback = function(state)
        SavedSettings.autoJoinChristmasCave = state
        SaveSettings()
        if state then
            StartChristmasCaveMonitor(EventState.christmasCaveParagraph)
        else
            StopChristmasCaveMonitor()
            EventState.christmasCaveParagraph:SetDesc("Status: Off")
        end
    end
})

EventsTab:Divider()

-- Lochness Section
EventsTab:Section({Title = "Ancient Lochness Event", TextSize = 16})

EventState.lochnessParagraph = EventsTab:Paragraph({
    Title = "Lochness Status",
    Content = "Status: Checking...",
})

local function StartLochnessMonitor(uiParagraph)
    if EventState.lochnessConn then
        EventState.lochnessConn:Disconnect()
        EventState.lochnessConn = nil
    end
    
    local isTeleportedToEvent = false
    
    EventState.lochnessConn = task.spawn(function()
        while SavedSettings.autoJoinLochness do
            local isActive = IsLochnessEventActive()
            local doorOpen = IsRuinDoorOpen()
            
            -- GATEKEEPER: Only allow teleport if door is open (or unknown)
            if isActive and not isTeleportedToEvent then
                if doorOpen or GetRuinDoorStatus() == "UNKNOWN" then
                    SaveCurrentPosition()
                    SafeTeleport(EventState.COORDS.Lochness)
                    isTeleportedToEvent = true
                    EventState.lochnessActive = true
                    EventState.isInEventZone = true  -- Anti-loop flag
                    if uiParagraph then uiParagraph:SetDesc("EVENT ACTIVE - Teleported!") end
                    if CONFIG.DEBUG then log("[Event] Teleported to Lochness") end
                else
                    -- Door LOCKED - stay at base point
                    if uiParagraph then uiParagraph:SetDesc("DOOR LOCKED - Staying at base") end
                    if CONFIG.DEBUG then log("[Event] Lochness blocked - door not open") end
                end
                
            elseif not isActive and isTeleportedToEvent then
                -- Wait 15 seconds before returning (like yesbgt.lua)
                if uiParagraph then uiParagraph:SetDesc("Event ended. Returning in 15s...") end
                task.wait(15)
                EventState.isInEventZone = false  -- Clear anti-loop flag
                -- v2.6: Use unified navigation
                SmartReturnToTarget("Lochness event ended (monitor)")
                isTeleportedToEvent = false
                EventState.lochnessActive = false
                if CONFIG.DEBUG then log("[Event] Lochness event ended, returned") end
            end
            
            -- Update UI
            if uiParagraph and not isTeleportedToEvent then
                local gui = GetLochnessEventGUI()
                local doorStatus = GetRuinDoorStatus()
                local doorIcon = doorStatus == "UNLOCKED" and "[OK]" or (doorStatus == "LOCKED" and "[LOCKED]" or "[?]")
                
                if gui and gui.Countdown then
                    local countdownText = ""
                    pcall(function() countdownText = gui.Countdown.ContentText or gui.Countdown.Text or "N/A" end)
                    uiParagraph:SetDesc("Next: " .. countdownText .. "\nDoor: " .. doorIcon .. " " .. doorStatus)
                else
                    uiParagraph:SetDesc("Monitoring...\nDoor: " .. doorIcon .. " " .. doorStatus)
                end
            end
            
            task.wait(0.5)
        end
    end)
end

local function StopLochnessMonitor()
    SavedSettings.autoJoinLochness = false
    if EventState.lochnessConn then
        pcall(function() task.cancel(EventState.lochnessConn) end)
        EventState.lochnessConn = nil
    end
    EventState.lochnessActive = false
    EventState.isInEventZone = false
    -- v2.6: Use unified navigation
    SmartReturnToTarget("Lochness monitor stopped")
end

EventsTab:Toggle({
    Title = "Auto Join Ancient Lochness",
    Desc = "Teleport to Lochness when event is active (GUI-based detection)",
    Value = SavedSettings.autoJoinLochness or false,
    Callback = function(state)
        SavedSettings.autoJoinLochness = state
        SaveSettings()
        if state then
            StartLochnessMonitor(EventState.lochnessParagraph)
        else
            StopLochnessMonitor()
            EventState.lochnessParagraph:SetDesc("Status: Off")
        end
    end
})

EventsTab:Button({
    Title = "Teleport to Christmas Cave",
    Desc = "Manual teleport",
    Callback = function()
        SafeTeleport(EventState.COORDS.ChristmasCave)
    end
})

EventsTab:Button({
    Title = "Teleport to Lochness",
    Desc = "Manual teleport",
    Callback = function()
        SafeTeleport(EventState.COORDS.Lochness)
    end
})

-- Ruin Door Quest Section
EventsTab:Divider()
EventsTab:Section({Title = "Ruin Door Quest (v2.8)", TextSize = 16})

RuinDoorState.uiParagraph = EventsTab:Paragraph({
    Title = "Ruin Door Status",
    Content = "Status: " .. RuinDoorState.statusText,
})

EventsTab:Toggle({
    Title = "Auto Ruin Door",
    Desc = "Auto-place fish on pressure plates. Fishes at Sacred Temple if missing fish.",
    Value = SavedSettings.autoRuinDoorEnabled or false,
    Callback = function(state)
        SavedSettings.autoRuinDoorEnabled = state
        SaveSettings()
        if state then
            StartAutoRuinDoor()
        else
            StopAutoRuinDoor()
        end
    end
})

EventsTab:Button({
    Title = "Check Quest Status",
    Desc = "Show current Ruin Door quest progress",
    Callback = function()
        local isActive = IsRuinQuestActive()
        if not isActive then
            WindUI:Notify({
                Title = "Ruin Door",
                Content = "Quest not active (no pressure plates found)",
                Duration = 3
            })
            return
        end
        
        local missing = GetMissingRuinFish()
        local statusParts = {}
        for _, entry in ipairs(missing) do
            local icon = entry.hasFish and "✓" or "✗"
            table.insert(statusParts, entry.rarity .. ": " .. icon .. " " .. entry.fishName)
        end
        
        if #missing == 0 then
            WindUI:Notify({
                Title = "Ruin Door",
                Content = "All plates filled!",
                Duration = 3
            })
        else
            WindUI:Notify({
                Title = "Ruin Door - " .. #missing .. " plates remaining",
                Content = table.concat(statusParts, "\n"),
                Duration = 5
            })
        end
    end
})

EventsTab:Button({
    Title = "Teleport to Sacred Temple",
    Desc = "Manual teleport to fishing spot",
    Callback = function()
        SafeTeleport(RuinDoorState.SACRED_TEMPLE_CFRAME.Position)
    end
})

-- Auto Gift Santa Section (v2.9)
EventsTab:Divider()
EventsTab:Section({Title = "Auto Gift Santa (v2.9)", TextSize = 16})

GiftSantaState.uiParagraph = EventsTab:Paragraph({
    Title = "Gift Santa Status",
    Content = "Status: " .. GiftSantaState.statusText,
})

EventsTab:Toggle({
    Title = "Auto Gift Santa",
    Desc = "Automatically equip presents and give to Santa at Toy Factory",
    Value = SavedSettings.autoGiftSantaEnabled or false,
    Callback = function(state)
        SavedSettings.autoGiftSantaEnabled = state
        SaveSettings()
        if state then
            StartAutoGiftSanta()
        else
            StopAutoGiftSanta()
        end
    end
})

EventsTab:Button({
    Title = "Check Present Inventory",
    Desc = "Show presents you currently own",
    Callback = function()
        local present, isEquipped = FindOwnedPresent()
        if present then
            local status = isEquipped and "(Equipped)" or "(In Backpack)"
            WindUI:Notify({
                Title = "Present Found",
                Content = present.Name .. " " .. status,
                Duration = 3
            })
        else
            WindUI:Notify({
                Title = "No Presents",
                Content = "No presents found in inventory",
                Duration = 3
            })
        end
    end
})

-- Auto New Years Whale Section (v3.0)
EventsTab:Divider()
EventsTab:Section({Title = "New Years Whale (v3.0)", TextSize = 16})

EventState.NewYearsWhale.uiParagraph = EventsTab:Paragraph({
    Title = "New Years Whale Status",
    Content = "Status: " .. EventState.NewYearsWhale.statusText,
})

EventsTab:Toggle({
    Title = "Auto New Years Whale",
    Desc = "Follow the 2026 Event and stay on a platform. Shows countdown.",
    Value = SavedSettings.autoNewYearsWhaleEnabled or false,
    Callback = function(state)
        SavedSettings.autoNewYearsWhaleEnabled = state
        SaveSettings()
        if state then
            EventState.NewYearsWhale.Start()
        else
            EventState.NewYearsWhale.Stop()
        end
    end
})

--====================================
-- UI: TAB INVENTORY (v1.9)
--====================================
local InventoryTab = Window:Tab({Title = "Inventory", Icon = "package"})

-- Auto Equip Section
InventoryTab:Section({Title = "Auto Equip Rod", TextSize = 16})

InventoryTab:Toggle({
    Title = "Auto Equip Rod",
    Desc = "Event-driven + throttled (every 5s backup check)",
    Value = SavedSettings.autoEquipRodEnabled,
    Callback = function(state)
        SavedSettings.autoEquipRodEnabled = state
        SaveSettings()
        
        if state then
            StartEquipMonitor()
            WindUI:Notify({Title = "Auto-Equip ON", Content = "Rod will auto-equip when dropped", Duration = 2})
        else
            StopEquipMonitor()
            WindUI:Notify({Title = "Auto-Equip OFF", Content = "Disabled", Duration = 2})
        end
    end
})

InventoryTab:Button({
    Title = "Equip Rod Now",
    Desc = "Force equip rod from slot 1 or backpack",
    Callback = function()
        local success = EquipRod()
        if success then
            WindUI:Notify({Title = "Rod Equipped", Content = "Fishing rod equipped", Duration = 2})
        else
            WindUI:Notify({Title = "Equip Failed", Content = "No rod found", Duration = 2})
        end
    end
})

InventoryTab:Divider()

-- Totem Section
InventoryTab:Section({Title = "9x Totem Ritual", TextSize = 16})

-- v1.9.5: Physical Totem Sensor Status (moved here for visibility)
InventoryTab:Paragraph({
    Title = "Physical Totem Detection",
    Content = "Totem placement uses real-time Workspace scanning instead of timers.",
})

InventoryTab:Dropdown({
    Title = "Totem Type",
    Desc = "Select totem type for ritual",
    SearchBarEnabled = true,
    Values = TotemState.NAMES,
    Value = SavedSettings.selectedTotemType or "Luck Totem",
    Callback = function(option)
        SavedSettings.selectedTotemType = option
        SaveSettings()
    end
})

InventoryTab:Dropdown({
    Title = "Totem Spacing",
    Desc = "Distance between totems (studs)",
    Values = {"101", "101.5", "102", "102.5"},
    Value = tostring(TotemState.spacing),
    Callback = function(option)
        local S = tonumber(option) or 101
        SavedSettings.totemSpacing = S
        TotemState.spacing = S
        -- Regenerate offsets with centered triangle formula + patternOffset
        local offset = TotemState.patternOffset
        local r = S / math.sqrt(3)
        local halfS = S / 2
        local halfR = r / 2
        TotemState.offsets = {
            Vector3.new(0, 0, r) + offset, Vector3.new(-halfS, 0, -halfR) + offset, Vector3.new(halfS, 0, -halfR) + offset,
            Vector3.new(0, S, r) + offset, Vector3.new(-halfS, S, -halfR) + offset, Vector3.new(halfS, S, -halfR) + offset,
            Vector3.new(0, -S, r) + offset, Vector3.new(-halfS, -S, -halfR) + offset, Vector3.new(halfS, -S, -halfR) + offset,
        }
        SaveSettings()
        if CONFIG.DEBUG then print("[Totem] Spacing set to " .. S .. " studs") end
    end
})

TotemState.statusParagraph = InventoryTab:Paragraph({
    Title = "Ritual Status",
    Content = "Ready. Select totem and enable below.",
})

-- Store toggle element reference for auto-reset
TotemState.toggleElement = InventoryTab:Toggle({
    Title = "Start 9x Totem Ritual",
    Desc = "Place 9 totems (checks active totems first)",
    Value = false,
    Callback = function(state)
        if state then
            -- v2.6: Run9TotemRitual checks for active totems (pass false to enable check)
            -- User can still manually place if they want by scanning totems first
            Run9TotemRitual(false)
        else
            StopTotemRitual()
            if TotemState.statusParagraph then
                TotemState.statusParagraph:SetDesc("Stopped by user")
            end
        end
    end
})

InventoryTab:Button({
    Title = "Check Totem Count",
    Desc = "Show totem inventory in static label",
    Callback = function()
        local counts = {}
        for _, name in ipairs(TotemState.NAMES) do
            counts[name] = GetTotemCount(name)
        end
        
        local lines = {}
        for name, count in pairs(counts) do
            table.insert(lines, name .. ": " .. count)
        end
        
        -- Update static label instead of notification (RAM optimized)
        if TotemState.statusParagraph then
            TotemState.statusParagraph:SetDesc("Inventory:\n" .. table.concat(lines, "\n"))
        end
    end
})

InventoryTab:Button({
    Title = "Scan Nearby Totems",
    Desc = "Check for totems and time remaining",
    Callback = function()
        local count, hasNearby, minTime, totems = ScanForNearbyTotems()
        
        if hasNearby then
            local lines = {string.format("Found %d totem(s)", count)}
            for i, t in ipairs(totems) do
                if i > 5 then break end
                lines[#lines + 1] = string.format("  %d. %s (%d studs)", i, t.TimerText, t.Distance)
            end
            lines[#lines + 1] = string.format("Min: %s", FormatTimeRemaining(minTime))
            
            if TotemState.statusParagraph then
                TotemState.statusParagraph:SetDesc(table.concat(lines, "\n"))
            end
        else
            if TotemState.statusParagraph then
                TotemState.statusParagraph:SetDesc("No totems detected nearby")
            end
        end
    end
})

InventoryTab:Divider()

-- Auto Consume Potion Section (v2.4)
InventoryTab:Section({Title = "Auto Consume Potions", TextSize = 16})

PotionState.statusParagraph = InventoryTab:Paragraph({
    Title = "Potion Status",
    Content = "Status: OFF",
})

InventoryTab:Dropdown({
    Title = "Select Potions",
    Desc = "Choose potions to auto-consume",
    SearchBarEnabled = true,
    Multi = true,
    AllowNone = true,
    Values = PotionState.NAMES,
    Value = SavedSettings.selectedPotions or {},
    Callback = function(selected)
        SavedSettings.selectedPotions = selected or {}
        SaveSettings()
    end
})

PotionState.toggleElement = InventoryTab:Toggle({
    Title = "Enable Auto Potion",
    Desc = "Auto-consume selected potions when effect expires",
    Value = SavedSettings.autoPotionEnabled or false,
    Callback = function(state)
        SavedSettings.autoPotionEnabled = state
        SaveSettings()
        
        if state then
            PotionState.active = true
            RunAutoPotionLoop()
            WindUI:Notify({Title = "Auto Potion ON", Content = "Will consume selected potions", Duration = 2})
        else
            StopAutoPotionLoop()
            WindUI:Notify({Title = "Auto Potion OFF", Content = "Stopped", Duration = 2})
        end
    end
})

InventoryTab:Button({
    Title = "Check Potion Count",
    Desc = "Show potion inventory",
    Callback = function()
        local lines = {}
        for _, name in ipairs(PotionState.NAMES) do
            local count = GetPotionCount(name)
            table.insert(lines, string.format("%s: x%d", name, count))
        end
        
        if PotionState.statusParagraph then
            PotionState.statusParagraph:SetDesc("Inventory:\n" .. table.concat(lines, "\n"))
        end
    end
})

InventoryTab:Divider()

-- Merchant Section
InventoryTab:Section({Title = "Merchant Auto-Buy", TextSize = 16})

MerchantState.statusParagraph = InventoryTab:Paragraph({
    Title = "Merchant Status",
    Content = "Status: Idle",
})

-- Build merchant item names inline to save a register
do
    local names = {}
    for _, item in ipairs(MerchantState.ITEMS) do
        table.insert(names, item.Name)
    end
    InventoryTab:Dropdown({
        Title = "Items to Auto-Buy",
        Desc = "Select items to buy when merchant appears",
        SearchBarEnabled = true,
        Values = names,
        Value = SavedSettings.merchantBuyList or {},
        Multi = true,
        AllowNone = true,
        Callback = function(values)
            SavedSettings.merchantBuyList = values or {}
            SaveSettings()
        end
    })
end

InventoryTab:Toggle({
    Title = "Auto-Buy Merchant Items",
    Desc = "Automatically purchase selected items from merchant",
    Value = SavedSettings.autoBuyMerchantEnabled or false,
    Callback = function(state)
        SavedSettings.autoBuyMerchantEnabled = state
        SaveSettings()
        
        if state then
            print("[DEBUG] Auto-Buy Merchant: ENABLED")
            RunAutoBuyLoop()
            WindUI:Notify({
                Title = "Merchant Auto-Buy ON",
                Content = "Monitoring merchant stock...",
                Duration = 3
            })
        else
            print("[DEBUG] Auto-Buy Merchant: DISABLED")
            StopAutoBuyLoop()
            if MerchantState.statusParagraph then
                MerchantState.statusParagraph:SetDesc("Status: Disabled")
            end
        end
    end
})

InventoryTab:Button({
    Title = "Check Merchant Stock Now",
    Desc = "Manually check current merchant items",
    Callback = function()
        local stock = GetMerchantStockDetails()
        if #stock > 0 then
            local lines = {}
            for _, item in ipairs(stock) do
                table.insert(lines, "• " .. item.Name .. " (" .. tostring(item.Price) .. " " .. (item.Currency or "Coins") .. ")")
            end
            local stockText = table.concat(lines, "\n")
            
            -- Update UI Paragraph (persistent display)
            if MerchantState.statusParagraph then
                MerchantState.statusParagraph:SetDesc("Current Stock:\n" .. stockText)
            end
            
            if CONFIG.DEBUG then print("[Merchant] Stock: " .. table.concat(lines, ", ")) end
        else
            if MerchantState.statusParagraph then
                MerchantState.statusParagraph:SetDesc("No items available or merchant not spawned")
            end
        end
    end
})

InventoryTab:Button({
    Title = "Log Remotes",
    Desc = "Print remote events to console (debugging)",
    Callback = function()
        LogAllRemotes()
        WindUI:Notify({
            Title = "Remote Logger",
            Content = "Check F9 console for remote list",
            Duration = 4
        })
    end
})

InventoryTab:Divider()

-- Auto Favorite Section (moved from Misc)
InventoryTab:Section({Title = "Auto Favorite", TextSize = 16})

InventoryTab:Dropdown({
    Title = "Filter by Rarity",
    SearchBarEnabled = true,
    Values = CONFIG.RARITY_OPTIONS,
    Value = SavedSettings.autoFavoriteRarities or {"SECRET", "MYTHIC"},
    Multi = true,
    AllowNone = true,
    Callback = function(values)
        SavedSettings.autoFavoriteRarities = values or {}
        SaveSettings()
    end
})

InventoryTab:Dropdown({
    Title = "Filter by Name",
    Desc = "Favorite items with these names (OR logic)",
    SearchBarEnabled = true,
    Values = GetAllItemNames(),
    Value = SavedSettings.autoFavoriteItemNames or {},
    Multi = true,
    AllowNone = true,
    Callback = function(values)
        SavedSettings.autoFavoriteItemNames = values or {}
        SaveSettings()
    end
})

InventoryTab:Dropdown({
    Title = "Filter by Mutation",
    Desc = "Favorite items with these mutations (OR logic)",
    SearchBarEnabled = true,
    Values = AutoFavoriteState.MUTATION_OPTIONS,
    Value = SavedSettings.autoFavoriteMutations or {},
    Multi = true,
    AllowNone = true,
    Callback = function(values)
        SavedSettings.autoFavoriteMutations = values or {}
        SaveSettings()
    end
})

local autoFavToggle
autoFavToggle = InventoryTab:Toggle({
    Title = "Enable Auto Favorite",
    Desc = "Favorite matching items automatically",
    Value = SavedSettings.autoFavoriteEnabled,
    Callback = function(state)
        SavedSettings.autoFavoriteEnabled = state
        SaveSettings()
        if state then
            StartAutoFavorite()
        else
            StopAutoFavorite()
        end
    end
})

InventoryTab:Divider()

-- Auto Sell Section (moved from Settings)
InventoryTab:Section({Title = "Auto Sell", TextSize = 16})

InventoryTab:Toggle({
    Title = "Enable Auto Sell",
    Desc = "Sell fish at set intervals",
    Value = SavedSettings.autoSellEnabled,
    Callback = function(state)
        SavedSettings.autoSellEnabled = state
        SaveSettings()
        if state then
            AutoSellModule.Start()
        else
            AutoSellModule.Stop()
        end
    end
})

InventoryTab:Input({
    Title = "Interval (Seconds)",
    Desc = "Time between sells (min: 10s)",
    Value = tostring(SavedSettings.autoSellInterval or 60),
    Placeholder = "60",
    Callback = function(text)
        local num = tonumber(text)
        if num then
            SavedSettings.autoSellInterval = math.max(num, 10)
            SaveSettings()
            if SavedSettings.autoSellEnabled then
                AutoSellModule.Restart()
            end
        end
    end
})

InventoryTab:Button({
    Title = "Sell All",
    Callback = function()
        pcall(function()
            if Remotes.RF_SellAll then Remotes.RF_SellAll:InvokeServer() end
        end)
    end
})

InventoryTab:Divider()

-- Auto Weather Section
InventoryTab:Section({Title = "Auto Weather", TextSize = 16})

-- Ensure weather types are initialized before showing dropdown
InitWeatherTypes()

InventoryTab:Toggle({
    Title = "Enable Auto Weather",
    Desc = "Auto-purchase selected weather types when expired",
    Value = SavedSettings.autoWeatherEnabled,
    Callback = function(state)
        SavedSettings.autoWeatherEnabled = state
        SaveSettings()
        if state then
            AutoWeatherModule.Start()
        else
            AutoWeatherModule.Stop()
        end
    end
})

InventoryTab:Dropdown({
    Title = "Weather Types",
    Desc = "Select weather types to maintain (costs coins)",
    SearchBarEnabled = true,
    Multi = true,
    Values = (#AutoWeatherModule.TYPES > 0) and AutoWeatherModule.TYPES or {"Luck", "Bounty", "Resilience", "Precision", "Velocity"},
    Value = SavedSettings.autoWeatherList or {},
    Callback = function(selected)
        SavedSettings.autoWeatherList = selected
        SaveSettings()
        if SavedSettings.autoWeatherEnabled then
            task.defer(PurchaseMissingWeathers)
        end
    end
})

InventoryTab:Button({
    Title = "Purchase Now",
    Desc = "Manually purchase selected weathers",
    Callback = function()
        PurchaseMissingWeathers()
        WindUI:Notify({
            Title = "Weather",
            Content = "Purchasing selected weathers...",
            Duration = 2
        })
    end
})

InventoryTab:Button({
    Title = "Show Active Weathers",
    Desc = "Check currently active weather events",
    Callback = function()
        local events = InitEventsReplion()
        if events then
            local ok, list = pcall(function()
                return events:Get("WeatherMachine") or events:GetExpect("WeatherMachine")
            end)
            if ok and list and type(list) == "table" then
                local activeStr = #list > 0 and table.concat(list, ", ") or "None"
                WindUI:Notify({
                    Title = "Active Weathers",
                    Content = activeStr,
                    Duration = 5
                })
            else
                WindUI:Notify({
                    Title = "Weather",
                    Content = "Could not fetch active weathers",
                    Duration = 3
                })
            end
        end
    end
})

--====================================
-- UI: TAB WEBHOOK
--====================================
local WebhookTab = Window:Tab({Title = "Webhook", Icon = "bell"})

WebhookTab:Section({Title = "Discord Webhook", TextSize = 16})

WebhookTab:Input({
    Title = "Webhook URL",
    Desc = "Discord webhook URL for notifications",
    Value = SavedSettings.webhookURL or "",
    Placeholder = "https://discord.com/api/webhooks/...",
    Callback = function(text)
        SavedSettings.webhookURL = text or ""
        SaveSettings()
    end
})

WebhookTab:Toggle({
    Title = "Enable Webhook",
    Desc = "Send fish catch notifications to Discord",
    Value = SavedSettings.webhookEnabled,
    Callback = function(state)
        SavedSettings.webhookEnabled = state
        SaveSettings()
    end
})

WebhookTab:Dropdown({
    Title = "Notify Rarities",
    Desc = "Only send webhook for these rarities",
    SearchBarEnabled = true,
    Values = CONFIG.RARITY_OPTIONS,
    Value = SavedSettings.webhookRarityFilter or {"SECRET", "MYTHIC"},
    Multi = true,
    AllowNone = true,
    Callback = function(values)
        SavedSettings.webhookRarityFilter = values or {}
        SaveSettings()
    end
})

WebhookTab:Toggle({
    Title = "Notify Mutations",
    Desc = "Also notify when catching any mutation",
    Value = SavedSettings.webhookNotifyMutations,
    Callback = function(state)
        SavedSettings.webhookNotifyMutations = state
        SaveSettings()
    end
})

WebhookTab:Button({
    Title = "Test Webhook",
    Callback = function()
        if SavedSettings.webhookURL == "" then
            warn("[Webhook] No URL configured")
            return
        end
        WebhookModule.SendWebhook({
            title = "Webhook Test",
            description = "ZlaVe webhook is working!",
            color = 0xFFC850,
            fields = {
                { name = "Player", value = LocalPlayer.Name, inline = true },
                { name = "Status", value = "Connected ✓", inline = true },
            },
            footer = { text = "ZlaVe v2.5" },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        })
    end
})

--====================================
-- UI: TAB SETTINGS
--====================================
local SettingsTab = Window:Tab({Title = "Settings", Icon = "settings"})

-- Firebase Section (merged from Heartbeat)
SettingsTab:Section({Title = "Firebase Sync", TextSize = 16})

SettingsTab:Toggle({
    Title = "Firebase Sync",
    Desc = "Enable heartbeat sync to Firebase",
    Value = SavedSettings.heartbeatEnabled,
    Callback = function(state)
        SavedSettings.heartbeatEnabled = state
        SaveSettings()
        if state then
            StartHeartbeat()
        else
            StopHeartbeat()
        end
    end
})

SettingsTab:Button({
    Title = "Force Sync",
    Desc = "Send heartbeat immediately",
    Callback = function()
        SendHeartbeat()
    end
})

SettingsTab:Button({
    Title = "Scan Items",
    Desc = "Scan and sync backpack now",
    Callback = function()
        SendBackpack()
    end
})

SettingsTab:Button({
    Title = "Auto-Favorite Now",
    Desc = "Favorite matching items now",
    Callback = function()
        local count = AutoFavorite()
        print("[ZlaVe] Favorited " .. count .. " items")
    end
})

SettingsTab:Divider()

-- Performance Section (moved from Misc)
SettingsTab:Section({Title = "Performance", TextSize = 16})

SettingsTab:Toggle({
    Title = "FPS Boost",
    Desc = "Reduce visual effects for performance",
    Value = SavedSettings.fpsBoostEnabled,
    Callback = function(state)
        SavedSettings.fpsBoostEnabled = state
        SaveSettings()
        ApplyFpsBoost(state)
    end
})

SettingsTab:Toggle({
    Title = "FPS Cap",
    Desc = "Limit FPS to save resources (use slider below)",
    Value = SavedSettings.fpsCapEnabled or false,
    Callback = function(state)
        SavedSettings.fpsCapEnabled = state
        SaveSettings()
        if setfpscap then
            if state then
                setfpscap(SavedSettings.fpsCapValue or 30)
                WindUI:Notify({Title = "FPS Cap", Content = "Capped at " .. (SavedSettings.fpsCapValue or 30) .. " FPS", Duration = 2})
            else
                setfpscap(9999) -- Unlimited
                WindUI:Notify({Title = "FPS Cap", Content = "Unlimited FPS", Duration = 2})
            end
        else
            WindUI:Notify({Title = "FPS Cap", Content = "setfpscap not available", Duration = 2})
        end
    end
})

SettingsTab:Slider({
    Title = "FPS Cap Value",
    Desc = "Set FPS limit (10-240)",
    Value = {Min = 10, Max = 240, Default = SavedSettings.fpsCapValue or 30},
    Callback = function(value)
        SavedSettings.fpsCapValue = value
        SaveSettings()
        -- Apply immediately if FPS cap is enabled
        if SavedSettings.fpsCapEnabled and setfpscap then
            setfpscap(value)
        end
    end
})

SettingsTab:Toggle({
    Title = "Hide Notifications",
    Desc = "Hide fish popup notifications",
    Value = SavedSettings.hideNotifications,
    Callback = function(state)
        SavedSettings.hideNotifications = state
        SaveSettings()
        ApplyHideNotifications(state)
    end
})

SettingsTab:Toggle({
    Title = "No Animations",
    Desc = "Disable character animations",
    Value = SavedSettings.noAnimations,
    Callback = function(state)
        SavedSettings.noAnimations = state
        SaveSettings()
        ApplyNoAnimation(state)
    end
})

SettingsTab:Toggle({
    Title = "Block Cutscene",
    Desc = "Skip catch cutscenes",
    Value = SavedSettings.blockCutscene,
    Callback = function(state)
        SavedSettings.blockCutscene = state
        SaveSettings()
        ApplyBlockCutscene(state)
    end
})

SettingsTab:Toggle({
    Title = "Remove Skin Effect",
    Desc = "Hide cosmetic/skin VFX effects",
    Value = SavedSettings.removeSkinEffect,
    Callback = function(state)
        SavedSettings.removeSkinEffect = state
        SaveSettings()
        ApplyRemoveSkinEffect(state)
    end
})

SettingsTab:Toggle({
    Title = "Infinite Zoom Out",
    Desc = "Unlock camera zoom limit",
    Value = SavedSettings.infiniteZoom,
    Callback = function(state)
        SavedSettings.infiniteZoom = state
        SaveSettings()
        ApplyInfiniteZoom(state)
    end
})

SettingsTab:Divider()

-- Debug Section
SettingsTab:Section({Title = "Debug", TextSize = 16})

SettingsTab:Toggle({
    Title = "Debug Mode",
    Desc = "Show debug logs in console",
    Value = SavedSettings.debugMode or false,
    Callback = function(state)
        CONFIG.DEBUG = state
        SavedSettings.debugMode = state
        SaveSettings()
    end
})

--====================================
-- INITIALIZATION
--====================================
if not game:IsLoaded() then
    game.Loaded:Wait()
end
task.wait(2)

-- Auto-start heartbeat if enabled in settings
if SavedSettings.heartbeatEnabled then
    StartHeartbeat()
end

-- Apply FPS Boost if last setting was ON
if SavedSettings.fpsBoostEnabled then
    ApplyFpsBoost(true)
end

-- Apply FPS Cap if last setting was ON
if SavedSettings.fpsCapEnabled and setfpscap then
    setfpscap(SavedSettings.fpsCapValue or 30)
    if CONFIG.DEBUG then log("[FPSCap] Applied: " .. (SavedSettings.fpsCapValue or 30)) end
end

-- Apply utility features if enabled
if SavedSettings.hideNotifications then
    task.delay(1, function() ApplyHideNotifications(true) end)
end
if SavedSettings.noAnimations then
    task.delay(1, function() ApplyNoAnimation(true) end)
end
if SavedSettings.blockCutscene then
    task.delay(0.5, function() ApplyBlockCutscene(true) end)
end
if SavedSettings.removeSkinEffect then
    task.delay(0.5, function() ApplyRemoveSkinEffect(true) end)
end
if SavedSettings.infiniteZoom then
    task.delay(0.5, function() ApplyInfiniteZoom(true) end)
end

-- Start AutoFavorite if enabled (in case heartbeat is off)
-- NOTE: AutoUnfavorite REMOVED - not in yes.lua, was causing flip-flop bug
if SavedSettings.autoFavoriteEnabled and not State.heartbeatRunning then
    StartAutoFavorite()
end

-- Start Event Monitors if enabled in settings
if SavedSettings.autoJoinChristmasCave then
    StartChristmasCaveMonitor(EventState.christmasCaveParagraph)
end
if SavedSettings.autoJoinLochness then
    StartLochnessMonitor(EventState.lochnessParagraph)
end

-- INITIAL LOAD: Smart Navigator (v2.6 - Unified Navigation)
task.spawn(function()
    -- Wait for character to fully load
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = character:WaitForChild("HumanoidRootPart", 5)
    if not hrp then return end
    task.wait(1) -- Physics settle
    
    -- Only run once
    if EventState.initialLoadDone then return end
    EventState.initialLoadDone = true
    
    -- Check: Christmas Cave active? (UTC hour check + minute < 29)
    local nowT = os.date("!*t", NowUTC())
    local christmasEventNow = EventState.CHRISTMAS_HOURS[nowT.hour] and nowT.min < 29
    
    -- Check: Lochness active?
    local lochnessEventNow = IsLochnessEventActive()
    local lochnessEligible = lochnessEventNow and (IsRuinDoorOpen() or GetRuinDoorStatus() == "UNKNOWN")
    
    -- PRIORITY 1: Active Events (set state and teleport)
    if christmasEventNow and SavedSettings.autoJoinChristmasCave then
        if CONFIG.DEBUG then print("[StartupNav] Christmas Cave active! Teleporting...") end
        EventState.isInEventZone = true
        EventState.christmasCaveActive = true
        EventState.christmasCaveStartUTC = NowUTC() - (nowT.min * 60) -- Approx start time
        SaveCurrentPosition()
        -- v2.7.2: Use VerifiedTeleport with callback for proper totem timing
        VerifiedTeleport(EventState.COORDS.ChristmasCave, function()
            EquipRod()
            -- v2.6.2: Auto totem after event teleport (polling)
            if SavedSettings.autoTotemAfterTeleport then
                task.delay(1, function()
                    StartAutoTotemPolling("startup Christmas")
                end)
            end
        end)
        return
    end
    
    if lochnessEligible and SavedSettings.autoJoinLochness then
        if CONFIG.DEBUG then print("[StartupNav] Lochness active & eligible! Teleporting...") end
        EventState.isInEventZone = true
        EventState.lochnessActive = true
        SaveCurrentPosition()
        -- v2.7.2: Use VerifiedTeleport with callback for proper totem timing
        VerifiedTeleport(EventState.COORDS.Lochness, function()
            EquipRod()
            -- v2.6.2: Auto totem after event teleport (polling)
            if SavedSettings.autoTotemAfterTeleport then
                task.delay(1, function()
                    StartAutoTotemPolling("startup Lochness")
                end)
            end
        end)
        return
    end
    
    -- PRIORITY 2: Base Point (v2.7: unified with rotation - basePointName IS current location)
    -- Start rotation manager if enabled (it will continue from basePointName)
    if SavedSettings.rotationEnabled and not RotationState.isActive then
        StartRotationManager()
    end
    
    -- GetCurrentTargetLocation now just returns basePointName (synced with rotation)
    local targetPos, targetName, source = GetCurrentTargetLocation()
    
    if targetPos then
        if CONFIG.DEBUG then 
            print(string.format("[StartupNav] Teleporting to: %s (%s)", targetName, source)) 
        end
        
        -- v2.7.2: Use VerifiedTeleport with callback for proper totem timing
        VerifiedTeleport(targetPos, function()
            EquipRod()
            -- v2.6.2: Auto totem after teleport (polling)
            if SavedSettings.autoTotemAfterTeleport then
                task.delay(1, function()
                    StartAutoTotemPolling("startup unified nav")
                end)
            end
        end)
    else
        if CONFIG.DEBUG then print("[StartupNav] No target location configured") end
    end
end)

-- Start Equip Monitor if enabled
if SavedSettings.autoEquipRodEnabled then
    task.spawn(function()
        task.wait(2)
        StartEquipMonitor()
    end)
end

-- Export globals
getgenv().ZlaVe = {
    Start = StartHeartbeat,
    Stop = StopHeartbeat,
    SendHeartbeat = SendHeartbeat,
    SendBackpack = SendBackpack,
    AutoFavorite = AutoFavorite,
    AutoUnfavorite = AutoUnfavorite,
    StartAutoFavorite = StartAutoFavorite,
    StopAutoFavorite = StopAutoFavorite,
    StartAutoUnfavorite = StartAutoUnfavorite,
    StopAutoUnfavorite = StopAutoUnfavorite,
    ApplyFpsBoost = ApplyFpsBoost,
    IsConnected = IsConnected,
    State = State,
    CONFIG = CONFIG,
    Settings = SavedSettings
}

-- Select Fishing tab as default and auto-minimize on startup
task.spawn(function()
    task.wait(0.1) -- Brief delay to ensure WindUI fully initialized
    pcall(function() FishingTab:Select() end)
    task.wait(0.1)
    pcall(function() Window:Close() end)
    -- Update Mini button to closed state colors
    pcall(function()
        MiniBtn.Button.ImageColor3 = Color3.fromRGB(120, 120, 120)
        MiniBtn.Stroke.Color = Color3.fromRGB(120, 120, 120)
    end)
end)

-- Start merchant monitoring if enabled on load
if SavedSettings.autoBuyMerchantEnabled then
    task.spawn(function()
        task.wait(2)
        RunAutoBuyLoop()
    end)
end

-- Start equip monitor if enabled on load
if SavedSettings.autoEquipRodEnabled then
    task.spawn(function()
        task.wait(2)
        StartEquipMonitor()
    end)
end

-- Start rotation manager if enabled on load (v1.9.5)
if SavedSettings.rotationEnabled then
    task.spawn(function()
        task.wait(3)
        StartRotationManager()
    end)
end

-- Start Auto Potion if enabled on load (v2.7.1)
if SavedSettings.autoPotionEnabled then
    task.spawn(function()
        task.wait(2)
        PotionState.active = true
        RunAutoPotionLoop()
        if CONFIG.DEBUG then log("[AutoPotion] Resumed from saved settings") end
    end)
end

-- Start Auto Ruin Door if enabled on load (v2.8)
if SavedSettings.autoRuinDoorEnabled then
    task.spawn(function()
        task.wait(3)
        StartAutoRuinDoor()
        if CONFIG.DEBUG then log("[RuinDoor] Resumed from saved settings") end
    end)
end

--====================================
-- v2.7.3: ANTI-AFK (yesbgt.lua style - simple & clean)
-- Just disable all Idled connections - no reconnect needed
--====================================
pcall(function()
    -- Disable all existing Idled event connections
    for _, conn in pairs(getconnections(LocalPlayer.Idled)) do
        if conn.Disable then
            conn:Disable()
        end
    end
    if CONFIG.DEBUG then log("[AntiAFK] Idled connections disabled") end
end)

print("[ZlaVe] Script v2.5 | Event: " .. (Remotes.ObtainedNewFish and "OK" or "X") .. " | Webhook: " .. (SavedSettings.webhookEnabled and "Y" or "N") .. " | AntiAFK: Y")
