--[[
    Fish It! Combined Script v1.0
    ==============================
    Features:
    - Blatant fishing automation
    - Firebase heartbeat sync
    - Backpack scanning (Secret items)
    - Auto-favorite Secret/Mythic items
    - Teleport locations
    - FPS boost & misc utilities
    - Anti-AFK & auto-reconnect
    
    Usage:
    loadstring(game:HttpGet("URL"))()
--]]

--====================================
-- LOAD WINDUI
--====================================
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "Fish It! Script",
    Icon = "fish",
    Author = "by Alif",
    Folder = "FishItScript",
    Size = UDim2.fromOffset(580, 460),
    MinSize = Vector2.new(560, 350),
    MaxSize = Vector2.new(850, 560),
    Transparent = true,
    Theme = "Dark",
    Resizable = true,
    SideBarWidth = 200,
    HideSearchBar = true,
    ScrollBarEnabled = false,
    KeySystem = false
})

-- Mini Toggle Button (Logo) for minimize/restore
local MiniButtonGui = Instance.new("ScreenGui")
MiniButtonGui.Name = "FishItMiniButton"
MiniButtonGui.DisplayOrder = 999
MiniButtonGui.ResetOnSpawn = false
MiniButtonGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local MiniButton = Instance.new("ImageButton")
MiniButton.Name = "ToggleButton"
MiniButton.Size = UDim2.fromOffset(50, 50)
MiniButton.Position = UDim2.new(1, -60, 1, -60) -- Bottom-right corner
MiniButton.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
MiniButton.BackgroundTransparency = 0.2
MiniButton.Image = "rbxassetid://7733715400" -- Fish icon
MiniButton.ImageColor3 = Color3.fromRGB(100, 200, 255)
MiniButton.ScaleType = Enum.ScaleType.Fit
MiniButton.Parent = MiniButtonGui

local MiniCorner = Instance.new("UICorner")
MiniCorner.CornerRadius = UDim.new(0.5, 0)
MiniCorner.Parent = MiniButton

local MiniStroke = Instance.new("UIStroke")
MiniStroke.Color = Color3.fromRGB(100, 200, 255)
MiniStroke.Thickness = 2
MiniStroke.Parent = MiniButton

-- Draggable mini button with click/drag distinction
local dragging = false
local dragStart = nil
local startPos = nil
local totalDragDistance = 0
local DRAG_THRESHOLD = 5 -- pixels before considered a drag

MiniButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MiniButton.Position
        totalDragDistance = 0
    end
end)

MiniButton.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        local wasDragging = totalDragDistance >= DRAG_THRESHOLD
        dragging = false
        
        -- Only toggle if it was a click, not a drag
        if not wasDragging then
            -- Use Window.Closed to sync state with WindUI
            local isClosed = Window.Closed
            if isClosed then
                pcall(function() Window:Open() end)
                MiniButton.ImageColor3 = Color3.fromRGB(100, 200, 255)
                MiniStroke.Color = Color3.fromRGB(100, 200, 255)
            else
                pcall(function() Window:Close() end)
                MiniButton.ImageColor3 = Color3.fromRGB(150, 150, 150)
                MiniStroke.Color = Color3.fromRGB(150, 150, 150)
            end
        end
    end
end)

game:GetService("UserInputService").InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        totalDragDistance = math.abs(delta.X) + math.abs(delta.Y)
        MiniButton.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

pcall(function()
    MiniButtonGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
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
    
    -- Reconnect
    RECONNECT_DELAY = 5,
    MAX_RECONNECT_ATTEMPTS = 3,
    
    -- Fishing delays (seconds)
    COMPLETE_DELAY = 1.48,  -- Delay setelah request minigame sebelum complete
    CANCEL_DELAY = 0.33,    -- Delay setelah complete sebelum cancel/reset
    
    -- Debug
    DEBUG = false
}

--====================================
-- SETTINGS PERSISTENCE
--====================================
local SETTINGS_FILE = "FishItScript/settings.json"
local SavedSettings = {
    blatantEnabled = false,
    heartbeatEnabled = true,
    debugMode = false,
    hideNotifications = false,
    noFishingAnimations = false,
    -- AutoFavorite
    autoFavoriteEnabled = false,
    autoFavoriteRarities = {"SECRET", "MYTHIC"},
    autoFavoriteItemNames = {},
    autoFavoriteMutations = {},
    -- AutoUnfavorite
    autoUnfavoriteEnabled = false,
    -- FPS Boost
    fpsBoostEnabled = false
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
            pcall(function() makefolder("FishItScript") end)
            local data = game:GetService("HttpService"):JSONEncode(SavedSettings)
            writefile(SETTINGS_FILE, data)
        end
    end)
end

-- Load settings on startup
LoadSettings()
CONFIG.DEBUG = SavedSettings.debugMode

--====================================
-- SERVICES
--====================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local Username = LocalPlayer and string.lower(LocalPlayer.Name) or "unknown"
local UserId = LocalPlayer and LocalPlayer.UserId or 0
local PlaceId = game.PlaceId
local JobId = game.JobId

--====================================
-- NET & REMOTES
--====================================
local Net = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_net@0.2.0"):WaitForChild("net")

-- Fishing Remotes
local RF_Charge   = Net:WaitForChild("RF/ChargeFishingRod")
local RF_Request  = Net:WaitForChild("RF/RequestFishingMinigameStarted")
local RF_Cancel   = Net:WaitForChild("RF/CancelFishingInputs")
local RE_Complete = Net:WaitForChild("RE/FishingCompleted")
local RF_SellAll  = Net:WaitForChild("RF/SellAllItems")

-- Favorite Event
local FavoriteEvent = nil
pcall(function()
    FavoriteEvent = Net:WaitForChild("RE/FavoriteItem", 5)
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
    reconnectAttempts = 0,
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
local Replion = nil
local ItemUtility = nil
local TierUtility = nil

pcall(function()
    Replion = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Replion"))
end)

pcall(function()
    ItemUtility = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ItemUtility"))
end)

pcall(function()
    TierUtility = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TierUtility"))
end)

--====================================
-- DUPLICATE INSTANCE CHECK
--====================================
if getgenv().FishItScriptRunning then
    warn("[FishIt] Another instance detected, stopping this one")
    return
end
getgenv().FishItScriptRunning = true

--====================================
-- UTILITY FUNCTIONS
--====================================
local function log(msg, level)
    level = level or "INFO"
    if CONFIG.DEBUG or level == "ERROR" or level == "WARN" then
        print(string.format("[FishIt][%s] %s", level, msg))
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
    local bodyStr = body and HttpService:JSONEncode(body) or nil
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
local FavoritedCache = {}
local FavoritedCacheCount = 0
local MAX_CACHE_SIZE = 500
local autoFavoriteThread = nil
local autoFavoriteRunning = false
local autoUnfavoriteThread = nil
local autoUnfavoriteRunning = false

-- Mutation options (from yesbgt.lua line 2563-2568)
local MUTATION_OPTIONS = {
    "Shiny", "Gemstone", "Corrupt", "Galaxy", "Holographic", "Ghost",
    "Lightning", "Fairy Dust", "Gold", "Midnight", "Radioactive",
    "Stone", "Albino", "Sandy", "Acidic", "Disco", "Frozen", "Noob"
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
    if FavoritedCacheCount > MAX_CACHE_SIZE then
        local count = 0
        local toRemove = math.floor(MAX_CACHE_SIZE / 2)
        for uuid, _ in pairs(FavoritedCache) do
            if count < toRemove then
                FavoritedCache[uuid] = nil
                count = count + 1
            else
                break
            end
        end
        FavoritedCacheCount = FavoritedCacheCount - count
        if CONFIG.DEBUG then log("Pruned " .. count .. " entries from FavoritedCache") end
    end
end

local function TryFavoriteItem(uuid, itemName, rarity, retries)
    retries = retries or 0
    local MAX_RETRIES = 2
    
    local success = pcall(function()
        FavoriteEvent:FireServer(uuid)
    end)
    
    if success then
        FavoritedCache[uuid] = true
        FavoritedCacheCount = FavoritedCacheCount + 1
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
    
    if not FavoriteEvent then
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
            elseif FavoritedCache[uuid] then
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

local function StartAutoFavorite()
    if autoFavoriteRunning then return end
    autoFavoriteRunning = true
    
    autoFavoriteThread = task.spawn(function()
        while autoFavoriteRunning do
            if SavedSettings.autoFavoriteEnabled then
                PruneFavoritedCache()
                AutoFavorite()
            end
            task.wait(1) -- 1s polling interval
        end
    end)
end

local function StopAutoFavorite()
    autoFavoriteRunning = false
    if autoFavoriteThread then
        pcall(function() task.cancel(autoFavoriteThread) end)
        autoFavoriteThread = nil
    end
end

-- AutoUnfavorite: unfavorite items that match filter and ARE favorited
local function AutoUnfavorite()
    if not Replion or not Replion.Client or not FavoriteEvent then return 0 end
    
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
                pcall(function() FavoriteEvent:FireServer(uuid) end)
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
    if autoUnfavoriteRunning then return end
    
    -- Mutual exclusion: stop favorite if running
    if autoFavoriteRunning then
        StopAutoFavorite()
        SavedSettings.autoFavoriteEnabled = false
        SaveSettings()
    end
    
    autoUnfavoriteRunning = true
    
    autoUnfavoriteThread = task.spawn(function()
        while autoUnfavoriteRunning do
            if SavedSettings.autoUnfavoriteEnabled then
                AutoUnfavorite()
            end
            task.wait(1)
        end
    end)
end

local function StopAutoUnfavorite()
    autoUnfavoriteRunning = false
    if autoUnfavoriteThread then
        pcall(function() task.cancel(autoUnfavoriteThread) end)
        autoUnfavoriteThread = nil
    end
end

--====================================
-- FPS BOOST (Toggle + Persisted)
--====================================
local isFpsBoostActive = false
local originalLightingValues = {}

local function ApplyFpsBoost(enabled)
    isFpsBoostActive = enabled
    
    if enabled then
        -- Save original values once
        if not next(originalLightingValues) then
            originalLightingValues.GlobalShadows = Lighting.GlobalShadows
            originalLightingValues.FogEnd = Lighting.FogEnd
            originalLightingValues.Brightness = Lighting.Brightness
            originalLightingValues.ClockTime = Lighting.ClockTime
            originalLightingValues.Ambient = Lighting.Ambient
            originalLightingValues.OutdoorAmbient = Lighting.OutdoorAmbient
        end
        
        -- Disable effects
        pcall(function()
            for _, v in pairs(Workspace:GetDescendants()) do
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
        if Workspace.Terrain then
            pcall(function()
                Workspace.Terrain.WaterWaveSize = 0
                Workspace.Terrain.WaterWaveSpeed = 0
                Workspace.Terrain.WaterReflectance = 0
                Workspace.Terrain.WaterTransparency = 1
            end)
        end
        
        -- Quality settings
        pcall(function()
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        end)
        if type(setfpscap) == "function" then pcall(function() setfpscap(100) end) end
        if type(collectgarbage) == "function" then collectgarbage("collect") end
    else
        -- Restore
        pcall(function()
            if originalLightingValues.GlobalShadows ~= nil then
                Lighting.GlobalShadows = originalLightingValues.GlobalShadows
                Lighting.FogEnd = originalLightingValues.FogEnd
                Lighting.Brightness = originalLightingValues.Brightness
                Lighting.ClockTime = originalLightingValues.ClockTime
                Lighting.Ambient = originalLightingValues.Ambient
                Lighting.OutdoorAmbient = originalLightingValues.OutdoorAmbient
            end
            settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
            for _, effect in pairs(Lighting:GetChildren()) do
                if effect:IsA("PostEffect") then effect.Enabled = true end
            end
        end)
        if type(setfpscap) == "function" then pcall(function() setfpscap(60) end) end
    end
end

--====================================
-- DISCONNECT DETECTION
--====================================
local DisconnectTypes = {
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
        return DisconnectTypes.NO_CHARACTER
    end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return DisconnectTypes.NO_CHARACTER
    end
    
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Health <= 0 then
        return DisconnectTypes.DEAD
    end
    
    local dataConnected = true
    pcall(function()
        if Replion and Replion.Client then
            local data = Replion.Client:WaitReplion("Data")
            if not data then dataConnected = false end
        end
    end)
    
    if not dataConnected then
        return DisconnectTypes.CONNECTION_LOST
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
-- AUTO RECONNECT
--====================================
local function AttemptReconnect()
    if State.reconnectAttempts >= CONFIG.MAX_RECONNECT_ATTEMPTS then
        log("Max reconnect attempts reached", "ERROR")
        firebasePatch("accounts/" .. Username .. "/roblox", {
            inGame = false,
            status = "reconnect_failed",
            disconnectReason = State.disconnectReason,
            timestamp = os.time()
        })
        return false
    end
    
    State.reconnectAttempts = State.reconnectAttempts + 1
    log("Reconnect attempt " .. State.reconnectAttempts .. "/" .. CONFIG.MAX_RECONNECT_ATTEMPTS)
    
    firebasePatch("accounts/" .. Username .. "/roblox", {
        status = "reconnecting",
        reconnectAttempt = State.reconnectAttempts,
        timestamp = os.time()
    })
    
    pcall(function()
        TeleportService:Teleport(PlaceId, LocalPlayer)
    end)
    
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
        username = Username,
        userId = UserId,
        displayName = LocalPlayer.DisplayName or Username,
        status = isConnected and "online" or State.connectionStatus,
        inGame = isConnected,
        connectionStatus = State.connectionStatus,
        disconnectReason = State.disconnectReason,
        gameId = PlaceId,
        serverId = JobId,
        fishingActive = State.fishingRunning,
        timestamp = os.time(),
        timestampISO = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }
    
    pcall(function()
        info.gameName = game:GetService("MarketplaceService"):GetProductInfo(PlaceId).Name
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
    local path = "accounts/" .. Username .. "/roblox"
    
    if firebasePatch(path, info) then
        State.lastHeartbeat = os.time()
        if CONFIG.DEBUG then log("Heartbeat sent") end
        return true
    end
    return false
end

local function SendBackpack()
    local data = ScanBackpack()
    local path = "accounts/" .. Username .. "/backpack"
    
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
            RF_Cancel:InvokeServer()
            RF_Charge:InvokeServer({ [1] = { os.clock() } })
            RF_Request:InvokeServer(1, 0, os.clock())
        end)
    end)
end

local function ForceStep4()
    task.spawn(function()
        pcall(function()
            RE_Complete:FireServer()
        end)
    end)
end

local function ForceCancel()
    task.spawn(function()
        pcall(function()
            RF_Cancel:InvokeServer()
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
            task.wait(0.5)
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
    log("Starting heartbeat for " .. Username)
    
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
                
                if State.disconnectReason == DisconnectTypes.DEAD then
                    task.wait(3)
                else
                    task.wait(CONFIG.RECONNECT_DELAY)
                    if not IsConnected() then
                        AttemptReconnect()
                    end
                end
            else
                State.reconnectAttempts = 0
                
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
            firebasePatch("accounts/" .. Username .. "/roblox", {
                status = "teleporting",
                timestamp = os.time()
            })
        elseif state == Enum.TeleportState.Failed then
            State.disconnectReason = DisconnectTypes.TELEPORT_FAIL
            AttemptReconnect()
        end
    end)
end

StopHeartbeat = function()
    if not State.heartbeatRunning then return end
    
    State.heartbeatRunning = false
    getgenv().FishItScriptRunning = false
    log("Stopping heartbeat")
    
    StopAutoFavorite()
    
    firebasePatch("accounts/" .. Username .. "/roblox", {
        inGame = false,
        status = "offline",
        timestamp = os.time(),
        timestampISO = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    
    CleanupConnections()
    FavoritedCache = {}
    FavoritedCacheCount = 0
end

--====================================
-- TELEPORT LOCATIONS
--====================================
local teleportLocations = {
    ["Fisherman Island"] = CFrame.new(34, 26, 2776),
    ["Jungle"] = CFrame.new(1483, 11, -300),
    ["Ancient Ruin"] = CFrame.new(6085, -586, 4639),
    ["Crater Island"] = CFrame.new(1013, 23, 5079),
    ["Christmas Island"] = CFrame.new(1135, 24, 1563),
    ["Christmas Cafe"] = CFrame.new(580, -581, 8930),
    ["Kohana"] = CFrame.new(-635, 16, 603),
    ["Volcano"] = CFrame.new(-597, 59, 106),
    ["Esetoric Depth"] = CFrame.new(3203, -1303, 1415),
    ["Sisyphus Statue"] = CFrame.new(-3712, -135, -1013),
    ["Treasure"] = CFrame.new(-3566, -279, -1681),
    ["Tropical"] = CFrame.new(-2093, 6, 3699),
}

local selectedTeleport = "Fisherman Island"

--====================================
-- UI: TAB BLATANT
--====================================
local BlatantTab = Window:Tab({Title = "Blatant", Icon = "fish"})

BlatantTab:Toggle({
    Title = "Blatant On/Off",
    Desc = "Enable/Disable blatant fishing",
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

BlatantTab:Input({
    Title = "Complete Delay",
    Desc = "Delay in seconds for STEP123 -> STEP4",
    Value = tostring(CONFIG.COMPLETE_DELAY),
    Placeholder = "Seconds",
    Callback = function(text)
        local num = tonumber(text)
        if num then CONFIG.COMPLETE_DELAY = math.max(0, num) end
    end
})

BlatantTab:Input({
    Title = "Cancel Delay",
    Desc = "Delay in seconds for STEP4 -> STEP123",
    Value = tostring(CONFIG.CANCEL_DELAY),
    Placeholder = "Seconds",
    Callback = function(text)
        local num = tonumber(text)
        if num then CONFIG.CANCEL_DELAY = math.max(0, num) end
    end
})

BlatantTab:Button({
    Title = "Sell All",
    Callback = function()
        pcall(function()
            RF_SellAll:InvokeServer()
        end)
    end
})

--====================================
-- UI: TAB HEARTBEAT
--====================================
local HeartbeatTab = Window:Tab({Title = "Heartbeat", Icon = "heart"})

HeartbeatTab:Toggle({
    Title = "Heartbeat On/Off",
    Desc = "Enable/Disable Firebase heartbeat sync",
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

HeartbeatTab:Button({
    Title = "Force Heartbeat",
    Desc = "Send heartbeat immediately",
    Callback = function()
        SendHeartbeat()
    end
})

HeartbeatTab:Button({
    Title = "Force Backpack Scan",
    Desc = "Scan and sync backpack now",
    Callback = function()
        SendBackpack()
    end
})

HeartbeatTab:Button({
    Title = "Force Auto-Favorite",
    Desc = "Favorite items matching rarity filter now",
    Callback = function()
        local count = AutoFavorite()
        print("[FishIt] Favorited " .. count .. " items")
    end
})

HeartbeatTab:Toggle({
    Title = "Debug Mode",
    Desc = "Enable verbose logging",
    Value = SavedSettings.debugMode,
    Callback = function(state)
        CONFIG.DEBUG = state
        SavedSettings.debugMode = state
        SaveSettings()
    end
})

--====================================
-- UI: TAB TELEPORT
--====================================
local TeleportTab = Window:Tab({Title = "Teleport", Icon = "map"})

TeleportTab:Dropdown({
    Title = "Select Location",
    Desc = "Choose a location to teleport",
    SearchBarEnabled = true,
    Values = (function()
        local t = {}
        for k, _ in pairs(teleportLocations) do table.insert(t, k) end
        table.sort(t)
        return t
    end)(),
    Value = selectedTeleport,
    Callback = function(option)
        selectedTeleport = option
    end
})

TeleportTab:Button({
    Title = "Teleport",
    Callback = function()
        local targetCFrame = teleportLocations[selectedTeleport]
        if targetCFrame and LocalPlayer.Character and LocalPlayer.Character.PrimaryPart then
            LocalPlayer.Character:SetPrimaryPartCFrame(targetCFrame)
        end
    end
})

--====================================
-- UI: TAB MISC
--====================================
local MiscTab = Window:Tab({Title = "Misc", Icon = "settings"})

-- Favorite Section
local FavoriteSection = MiscTab:Section({Title = "Auto Favorite / Unfavorite", TextSize = 16})

-- Rarity Filter (Persisted) - uppercase to match game's item.Metadata.Rarity
local rarityOptions = {"COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY", "MYTHIC", "SECRET"}
MiscTab:Dropdown({
    Title = "Filter by Rarity",
    SearchBarEnabled = true,
    Values = rarityOptions,
    Value = SavedSettings.autoFavoriteRarities or {"SECRET", "MYTHIC"},
    Multi = true,
    AllowNone = true,
    Callback = function(values)
        SavedSettings.autoFavoriteRarities = values or {}
        SaveSettings()
    end
})

-- Item Name Filter (Persisted)
local allItemNames = GetAllItemNames()
MiscTab:Dropdown({
    Title = "Filter by Item Name",
    SearchBarEnabled = true,
    Values = allItemNames,
    Value = SavedSettings.autoFavoriteItemNames or {},
    Multi = true,
    AllowNone = true,
    Callback = function(values)
        SavedSettings.autoFavoriteItemNames = values or {}
        SaveSettings()
    end
})

-- Mutation Filter (Persisted)
MiscTab:Dropdown({
    Title = "Filter by Mutation",
    SearchBarEnabled = true,
    Values = MUTATION_OPTIONS,
    Value = SavedSettings.autoFavoriteMutations or {},
    Multi = true,
    AllowNone = true,
    Callback = function(values)
        SavedSettings.autoFavoriteMutations = values or {}
        SaveSettings()
    end
})

-- AutoFavorite Toggle (Persisted)
local autoFavToggle
autoFavToggle = MiscTab:Toggle({
    Title = "Enable Auto Favorite",
    Desc = "Auto-favorite items matching ANY filter above",
    Value = SavedSettings.autoFavoriteEnabled,
    Callback = function(state)
        SavedSettings.autoFavoriteEnabled = state
        SaveSettings()
        
        if state then
            -- Mutual exclusion
            if SavedSettings.autoUnfavoriteEnabled then
                SavedSettings.autoUnfavoriteEnabled = false
                SaveSettings()
                StopAutoUnfavorite()
            end
            StartAutoFavorite()
        else
            StopAutoFavorite()
        end
    end
})

-- AutoUnfavorite Toggle (Persisted)
local autoUnfavToggle
autoUnfavToggle = MiscTab:Toggle({
    Title = "Enable Auto Unfavorite",
    Desc = "Unfavorite items matching ANY filter above",
    Value = SavedSettings.autoUnfavoriteEnabled,
    Callback = function(state)
        SavedSettings.autoUnfavoriteEnabled = state
        SaveSettings()
        
        if state then
            -- Mutual exclusion
            if SavedSettings.autoFavoriteEnabled then
                SavedSettings.autoFavoriteEnabled = false
                SaveSettings()
                StopAutoFavorite()
            end
            StartAutoUnfavorite()
        else
            StopAutoUnfavorite()
        end
    end
})

MiscTab:Divider()

-- FPS Boost Toggle (Persisted)
MiscTab:Toggle({
    Title = "FPS Boost (Aggressive)",
    Desc = "Enable/Disable aggressive FPS optimizations",
    Value = SavedSettings.fpsBoostEnabled,
    Callback = function(state)
        SavedSettings.fpsBoostEnabled = state
        SaveSettings()
        ApplyFpsBoost(state)
    end
})

MiscTab:Toggle({
    Title = "Hide Notifications",
    Desc = "Hide the small notification display",
    Value = SavedSettings.hideNotifications,
    Callback = function(state)
        SavedSettings.hideNotifications = state
        SaveSettings()
        local notif = LocalPlayer.PlayerGui:FindFirstChild("Small Notification")
        if notif and notif:FindFirstChild("Display") then
            notif.Display.Visible = not state
        end
    end
})

-- Apply saved hide notifications on load
if SavedSettings.hideNotifications then
    task.delay(1, function()
        local notif = LocalPlayer.PlayerGui:FindFirstChild("Small Notification")
        if notif and notif:FindFirstChild("Display") then
            notif.Display.Visible = false
        end
    end)
end

MiscTab:Toggle({
    Title = "No Fishing Animations",
    Desc = "Stop fishing animations",
    Value = SavedSettings.noFishingAnimations,
    Callback = function(state)
        SavedSettings.noFishingAnimations = state
        SaveSettings()
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            for _, anim in pairs(LocalPlayer.Character.Humanoid:GetPlayingAnimationTracks()) do
                if state then anim:Stop() else anim:Play() end
            end
        end
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

-- Start AutoFavorite if enabled (in case heartbeat is off)
if SavedSettings.autoFavoriteEnabled and not State.heartbeatRunning then
    StartAutoFavorite()
elseif SavedSettings.autoUnfavoriteEnabled then
    StartAutoUnfavorite()
end

-- Export globals
getgenv().FishIt = {
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

-- Select Blatant tab as default and auto-minimize on startup
task.spawn(function()
    task.wait(0.1) -- Brief delay to ensure WindUI fully initialized
    pcall(function() BlatantTab:Select() end)
    task.wait(0.1)
    pcall(function() Window:Close() end)
    -- Update MiniButton to closed state colors
    MiniButton.ImageColor3 = Color3.fromRGB(150, 150, 150)
    MiniStroke.Color = Color3.fromRGB(150, 150, 150)
end)

print("[FishIt] Script v1.5 loaded | Replion: " .. tostring(Replion ~= nil) .. " | ItemUtility: " .. tostring(ItemUtility ~= nil) .. " | TierUtility: " .. tostring(TierUtility ~= nil) .. " | Favorite: " .. tostring(FavoriteEvent ~= nil))
