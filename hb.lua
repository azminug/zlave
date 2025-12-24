--[[
    Roblox Firebase Heartbeat Module v5
    ====================================
    Features:
    - Firebase heartbeat sync
    - Backpack scanning (only Secret rarity in special items)
    - Auto-favorite Secret/Mythic items
    - Disconnect detection with categorized reasons
    - Auto-reconnect logic
    - Memory-efficient design
    - Lowercase username normalization
    
    Usage:
    loadstring(game:HttpGet("URL"))()
--]]

-- ============================================
-- CONFIGURATION
-- ============================================
local CONFIG = {
    FIREBASE_URL = "https://autofarm-861ab-default-rtdb.asia-southeast1.firebasedatabase.app",
    HEARTBEAT_INTERVAL = 15,
    BACKPACK_INTERVAL = 60,
    AUTO_FAVORITE_INTERVAL = 30,
    RECONNECT_DELAY = 5,
    MAX_RECONNECT_ATTEMPTS = 3,
    DEBUG = false
}

-- ============================================
-- SERVICES
-- ============================================
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local Username = LocalPlayer and string.lower(LocalPlayer.Name) or "unknown"
local UserId = LocalPlayer and LocalPlayer.UserId or 0
local PlaceId = game.PlaceId
local JobId = game.JobId

-- ============================================
-- STATE TRACKING
-- ============================================
local State = {
    running = false,
    lastHeartbeat = 0,
    lastBackpack = 0,
    lastAutoFavorite = 0,
    reconnectAttempts = 0,
    disconnectReason = nil,
    connectionStatus = "connected"
}

-- ============================================
-- CONNECTION REGISTRY (prevent memory leaks)
-- ============================================
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

-- ============================================
-- MODULE LOADING
-- ============================================
local Replion = nil
local ItemUtility = nil
local FavoriteEvent = nil
local net = nil

pcall(function()
    Replion = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Replion"))
end)

pcall(function()
    ItemUtility = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ItemUtility"))
end)

pcall(function()
    net = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_net@0.2.0"):WaitForChild("net")
    FavoriteEvent = net:WaitForChild("RE/FavoriteItem", 5)
end)

-- ============================================
-- DUPLICATE INSTANCE CHECK
-- ============================================
if getgenv().HeartbeatRunning then
    warn("[HB] Another instance detected, stopping this one")
    return
end
getgenv().HeartbeatRunning = true

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================
local function log(msg, level)
    level = level or "INFO"
    if CONFIG.DEBUG or level == "ERROR" or level == "WARN" then
        print(string.format("[HB][%s] %s", level, msg))
    end
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
    else
        if CONFIG.DEBUG then log("HTTP failed: " .. tostring(result), "ERROR") end
        return nil
    end
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

-- ============================================
-- ITEM DATABASE
-- ============================================
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
    local errors = 0
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
        else
            errors = errors + 1
        end
    end
    log("Item database: " .. count .. " items loaded" .. (errors > 0 and (" (" .. errors .. " skipped)") or ""))
end

local function GetItemInfo(itemId)
    return ItemDatabase[itemId] or { Name = "Unknown", Type = "Unknown", Rarity = "Unknown", SellPrice = 0 }
end

-- ============================================
-- BACKPACK SCANNER
-- ============================================
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
        
        -- Track unique secrets by name (avoid duplicates)
        local secretNames = {}
        
        for _, itemData in ipairs(inventoryItems) do
            local itemInfo = GetItemInfo(itemData.Id)
            local rarity = itemInfo.Rarity
            local price = itemInfo.SellPrice or 0
            local itemName = itemInfo.Name or "Unknown"
            
            -- Count by rarity
            result.rarityCount[rarity] = (result.rarityCount[rarity] or 0) + 1
            result.totalValue = result.totalValue + price
            result.itemCount = result.itemCount + 1
            
            -- Only add SECRET items to secretItems list
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
        
        -- Build clean secretItems array
        for name, data in pairs(secretNames) do
            local displayName = data.count > 1 and (name .. " x" .. data.count) or name
            table.insert(result.secretItems, {
                name = displayName,
                rarity = "Secret",
                count = data.count,
                favorited = data.favorited
            })
        end
        
        -- Sort by count descending
        table.sort(result.secretItems, function(a, b) return a.count > b.count end)
        
        -- Limit to 15 unique secret items
        if #result.secretItems > 15 then
            local overflow = #result.secretItems - 15
            result.secretItems = {unpack(result.secretItems, 1, 14)}
            table.insert(result.secretItems, { name = "+" .. overflow .. " more", rarity = "info", count = 0 })
        end
    end)
    
    if not success then
        log("Backpack scan failed", "ERROR")
    end
    
    return result
end

-- ============================================
-- AUTO FAVORITE (Secret + Mythic)
-- ============================================
local FavoritedCache = {} -- Track already favorited UUIDs

local function AutoFavorite()
    if not Replion or not Replion.Client then 
        log("AutoFavorite: Replion not available", "WARN")
        return 0 
    end
    
    if not FavoriteEvent then
        log("AutoFavorite: FavoriteEvent not available", "WARN")
        return 0
    end
    
    local favorited = 0
    local skipped = 0
    
    local success, err = pcall(function()
        local DataReplion = Replion.Client:WaitReplion("Data")
        if not DataReplion then 
            log("AutoFavorite: DataReplion not available", "WARN")
            return 
        end
        
        local items = DataReplion:Get({"Inventory", "Items"})
        if not items or #items == 0 then 
            log("AutoFavorite: No items in inventory", "DEBUG")
            return 
        end
        
        for _, itemData in ipairs(items) do
            local uuid = itemData.UUID
            
            -- Skip if already favorited or in cache
            if itemData.Favorited or FavoritedCache[uuid] then
                skipped = skipped + 1
            else
                local itemInfo = GetItemInfo(itemData.Id)
                local rarity = itemInfo.Rarity
                
                -- Auto-favorite Secret and Mythic only
                if rarity == "Secret" or rarity == "Mythic" then
                    -- Fire server event to favorite
                    local fireSuccess = pcall(function()
                        FavoriteEvent:FireServer(uuid)
                    end)
                    
                    if fireSuccess then
                        FavoritedCache[uuid] = true
                        favorited = favorited + 1
                        log("Favorited: " .. itemInfo.Name .. " (" .. rarity .. ")")
                        task.wait(0.3) -- Small delay between favorites
                    end
                end
            end
        end
    end)
    
    if not success then
        log("AutoFavorite error: " .. tostring(err), "ERROR")
    end
    
    if favorited > 0 then
        log("Auto-favorited " .. favorited .. " items (skipped " .. skipped .. ")")
    end
    
    return favorited
end

-- ============================================
-- DISCONNECT DETECTION
-- ============================================
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
    -- Check character
    local char = LocalPlayer.Character
    if not char or not char.Parent then
        return DisconnectTypes.NO_CHARACTER
    end
    
    -- Check HRP
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return DisconnectTypes.NO_CHARACTER
    end
    
    -- Check if alive
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Health <= 0 then
        return DisconnectTypes.DEAD
    end
    
    -- Check Replion connection
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
    
    return nil -- Connected
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

-- ============================================
-- AUTO RECONNECT
-- ============================================
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
    
    -- Update Firebase
    firebasePatch("accounts/" .. Username .. "/roblox", {
        status = "reconnecting",
        reconnectAttempt = State.reconnectAttempts,
        timestamp = os.time()
    })
    
    -- Try to teleport back
    local success = pcall(function()
        TeleportService:Teleport(PlaceId, LocalPlayer)
    end)
    
    if not success then
        log("Teleport failed", "ERROR")
        return false
    end
    
    return true
end

-- ============================================
-- ANTI-AFK
-- ============================================
local function SetupAntiAFK()
    -- Disable default idle connections
    pcall(function()
        for _, v in next, getconnections(LocalPlayer.Idled) do
            v:Disable()
        end
    end)
    
    -- Setup custom anti-AFK
    RegisterConnection(LocalPlayer.Idled:Connect(function()
        pcall(function()
            VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            task.wait(0.5)
            VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        end)
    end))
end

-- ============================================
-- HEARTBEAT
-- ============================================
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
        timestamp = os.time(),
        timestampISO = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }
    
    -- Game name
    pcall(function()
        info.gameName = game:GetService("MarketplaceService"):GetProductInfo(PlaceId).Name
    end)
    
    -- Position if connected
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
        log("Backpack: " .. data.itemCount .. " items, " .. #data.secretItems .. " secrets, " .. math.floor(data.totalValue) .. " value")
        return true
    end
    return false
end

-- ============================================
-- MAIN LOOP
-- ============================================
local function StartHeartbeat()
    if State.running then
        log("Already running", "WARN")
        return
    end
    
    State.running = true
    log("Starting heartbeat for " .. Username)
    
    -- Build item database
    BuildItemDatabase()
    
    -- Setup anti-AFK
    SetupAntiAFK()
    
    -- Initial sync
    SendHeartbeat()
    SendBackpack()
    AutoFavorite()
    
    -- Main loop
    task.spawn(function()
        while State.running do
            local now = os.time()
            
            -- Check connection
            local connected = IsConnected()
            
            if not connected then
                -- Disconnected - try reconnect
                log("Disconnected: " .. tostring(State.disconnectReason), "WARN")
                
                SendHeartbeat() -- Update status in Firebase
                
                if State.disconnectReason == DisconnectTypes.DEAD then
                    -- Wait for respawn
                    task.wait(3)
                else
                    -- Try reconnect
                    task.wait(CONFIG.RECONNECT_DELAY)
                    if not IsConnected() then
                        AttemptReconnect()
                    end
                end
            else
                -- Connected - reset reconnect counter
                State.reconnectAttempts = 0
                
                -- Heartbeat
                if now - State.lastHeartbeat >= CONFIG.HEARTBEAT_INTERVAL then
                    SendHeartbeat()
                end
                
                -- Backpack
                if now - State.lastBackpack >= CONFIG.BACKPACK_INTERVAL then
                    SendBackpack()
                end
                
                -- Auto-favorite
                if now - State.lastAutoFavorite >= CONFIG.AUTO_FAVORITE_INTERVAL then
                    AutoFavorite()
                    State.lastAutoFavorite = now
                end
            end
            
            task.wait(1)
        end
    end)
    
    -- Handle player leaving
    RegisterConnection(Players.PlayerRemoving:Connect(function(player)
        if player == LocalPlayer then
            StopHeartbeat()
        end
    end))
    
    -- Handle teleport
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

local function StopHeartbeat()
    if not State.running then return end
    
    State.running = false
    getgenv().HeartbeatRunning = false
    log("Stopping heartbeat")
    
    -- Final update
    firebasePatch("accounts/" .. Username .. "/roblox", {
        inGame = false,
        status = "offline",
        timestamp = os.time(),
        timestampISO = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    
    CleanupConnections()
    FavoritedCache = {}
end

-- ============================================
-- INITIALIZATION
-- ============================================
if not game:IsLoaded() then
    game.Loaded:Wait()
end
task.wait(2)

StartHeartbeat()

-- Export globals
getgenv().Heartbeat = {
    Start = StartHeartbeat,
    Stop = StopHeartbeat,
    SendHeartbeat = SendHeartbeat,
    SendBackpack = SendBackpack,
    AutoFavorite = AutoFavorite,
    IsConnected = IsConnected,
    State = State
}

print("[HB] Heartbeat v5 started for: " .. Username)
print("[HB] Replion: " .. tostring(Replion ~= nil) .. " | FavoriteEvent: " .. tostring(FavoriteEvent ~= nil))
