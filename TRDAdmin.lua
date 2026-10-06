--!strict
-- Delta Total Drama Simulation System
-- A comprehensive drama/elimination system for Roblox

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

-- Configuration
local CONFIG = {
    MinPlayers = 4,
    MaxPlayers = 12,
    ChallengeDuration = 60, -- seconds
    VotingDuration = 30,
    DramaChance = 0.35, -- chance for random drama events
    ImmunityChance = 0.2, -- chance for immunity
}

-- Create remote events
local Remotes = Instance.new("Folder")
Remotes.Name = "Remotes"
Remotes.Parent = ReplicatedStorage

local VoteEvent = Instance.new("RemoteEvent")
VoteEvent.Name = "Vote"
VoteEvent.Parent = Remotes

local ChallengeEvent = Instance.new("RemoteEvent")
ChallengeEvent.Name = "Challenge"
ChallengeEvent.Parent = Remotes

local DramaEvent = Instance.new("RemoteEvent")
DramaEvent.Name = "Drama"
DramaEvent.Parent = Remotes

-- Game state
local gameState = {
    isRunning = false,
    currentPhase = "lobby",
    contestants = {},
    eliminated = {},
    votes = {},
    immunity = {},
    dramaLog = {},
    currentChallenge = nil,
    allianceSystem = {},
}

-- Drama personalities system
local DRAMA_PERSONALITIES = {
    ["Backstabber"] = {
        color = Color3.fromRGB(255, 0, 0),
        description = "Will betray alliances at critical moments",
        effect = function(player, target)
            return {
                type = "betrayal",
                message = string.format("%s betrayed %s!", player.Name, target.Name),
                dramaLevel = 3
            }
        end
    },
    ["Hero"] = {
        color = Color3.fromRGB(0, 255, 0),
        description = "Protects allies and makes dramatic saves",
        effect = function(player, target)
            return {
                type = "protection",
                message = string.format("%s heroically saved %s!", player.Name, target.Name),
                dramaLevel = 2
            }
        end
    },
    ["Saboteur"] = {
        color = Color3.fromRGB(255, 255, 0),
        description = "Secretly works against others",
        effect = function(player, target)
            return {
                type = "sabotage",
                message = string.format("%s sabotaged %s's challenge!", player.Name, target.Name),
                dramaLevel = 3
            }
        end
    },
    ["Strategist"] = {
        color = Color3.fromRGB(0, 255, 255),
        description = "Makes calculated moves",
        effect = function(player, target)
            return {
                type = "strategy",
                message = string.format("%s outsmarted %s with a clever strategy!", player.Name, target.Name),
                dramaLevel = 2
            }
        end
    }
}

-- Initialize game
local function initializeGame()
    gameState.contestants = {}
    gameState.eliminated = {}
    gameState.votes = {}
    gameState.immunity = {}
    gameState.dramaLog = {}
    gameState.allianceSystem = {}
    
    for _, player in ipairs(Players:GetPlayers()) do
        if #gameState.contestants < CONFIG.MaxPlayers then
            local personalityKeys = {}
            for key in pairs(DRAMA_PERSONALITIES) do
                table.insert(personalityKeys, key)
            end
            local randomPersonality = personalityKeys[math.random(1, #personalityKeys)]
            
            table.insert(gameState.contestants, {
                player = player,
                personality = randomPersonality,
                status = "active",
                score = 0,
                alliances = {},
                dramaPoints = 0,
            })
        end
    end
end

-- Challenge system
local CHALLENGES = {
    {
        name = "Drama Puzzle",
        description = "Solve puzzles while dealing with drama",
        duration = 30,
        function = function(contestant)
            -- Simulate puzzle solving
            local success = math.random() > 0.4
            return success and math.random(1, 100) or 0
        end
    },
    {
        name = "Social Strategy",
        description = "Form alliances and make deals",
        duration = 45,
        function = function(contestant)
            -- Simulate social gameplay
            local success = math.random() > 0.3
            return success and math.random(1, 100) or 0
        end
    },
    {
        name = "Survival Challenge",
        description = "Outlast other contestants",
        duration = 60,
        function = function(contestant)
            -- Simulate survival
            local success = math.random() > 0.5
            return success and math.random(1, 100) or 0
        end
    }
}

-- Drama event system
local function triggerDramaEvent()
    if #gameState.contestants < 2 then return end
    
    local dramaChance = math.random()
    if dramaChance <= CONFIG.DramaChance then
        local player = gameState.contestants[math.random(1, #gameState.contestants)]
        local target = gameState.contestants[math.random(1, #gameState.contestants)]
        
        if player ~= target and player.player and target.player then
            local personality = DRAMA_PERSONALITIES[player.personality]
            if personality then
                local drama = personality.effect(player.player, target.player)
                table.insert(gameState.dramaLog, drama)
                
                -- Broadcast drama
                DramaEvent:FireAllClients({
                    type = drama.type,
                    message = drama.message,
                    player = player.player.Name,
                    target = target.player.Name,
                    dramaLevel = drama.dramaLevel,
                    timestamp = os.time()
                })
                
                -- Update drama points
                player.dramaPoints = (player.dramaPoints or 0) + drama.dramaLevel
                
                -- Check for immunity
                if math.random() <= CONFIG.ImmunityChance then
                    gameState.immunity[target.player.UserId] = true
                    DramaEvent:FireAllClients({
                        type = "immunity",
                        message = string.format("%s has been granted immunity!", target.player.Name),
                        player = target.player.Name,
                        dramaLevel = 4
                    })
                end
            end
        end
    end
end

-- Voting system
local function processVotes()
    local voteCounts = {}
    
    for userId, votedFor in pairs(gameState.votes) do
        if voteCounts[votedFor] then
            voteCounts[votedFor] = voteCounts[votedFor] + 1
        else
            voteCounts[votedFor] = 1
        end
    end
    
    -- Find most voted player
    local maxVotes = 0
    local eliminatedPlayer = nil
    
    for playerName, count in pairs(voteCounts) do
        if count > maxVotes then
            maxVotes = count
            eliminatedPlayer = playerName
        end
    end
    
    -- Check immunity
    if eliminatedPlayer then
        local player = Players:FindFirstChild(eliminatedPlayer)
        if player and gameState.immunity[player.UserId] then
            DramaEvent:FireAllClients({
                type = "immunity_saved",
                message = string.format("%s was saved by immunity!", eliminatedPlayer),
                player = eliminatedPlayer,
                dramaLevel = 4
            })
            return
        end
        
        -- Eliminate player
        for i, contestant in ipairs(gameState.contestants) do
            if contestant.player.Name == eliminatedPlayer then
                contestant.status = "eliminated"
                table.insert(gameState.eliminated, contestant)
                table.remove(gameState.contestants, i)
                
                DramaEvent:FireAllClients({
                    type = "elimination",
                    message = string.format("%s has been eliminated!", eliminatedPlayer),
                    player = eliminatedPlayer,
                    dramaLevel = 3
                })
                break
            end
        end
    end
    
    -- Clear votes for next round
    gameState.votes = {}
    gameState.immunity = {}
end

-- Main game loop
local function startGameLoop()
    while gameState.isRunning and #gameState.contestants > 1 do
        -- Challenge phase
        gameState.currentPhase = "challenge"
        local challenge = CHALLENGES[math.random(1, #CHALLENGES)]
        gameState.currentChallenge = challenge
        
        ChallengeEvent:FireAllClients({
            type = "start",
            challenge = challenge.name,
            description = challenge.description,
            duration = challenge.duration
        })
        
        wait(challenge.duration)
        
        -- Score challenge
        for _, contestant in ipairs(gameState.contestants) do
            if contestant.status == "active" then
                contestant.score = challenge.function(contestant)
            end
        end
        
        -- Trigger random drama
        triggerDramaEvent()
        
        -- Voting phase
        gameState.currentPhase = "voting"
        VoteEvent:FireAllClients({
            type = "start",
            duration = CONFIG.VotingDuration
        })
        
        wait(CONFIG.VotingDuration)
        
        -- Process votes
        processVotes()
        
        -- Check win condition
        if #gameState.contestants <= 1 then
            gameState.isRunning = false
            local winner = gameState.contestants[1]
            if winner then
                DramaEvent:FireAllClients({
                    type = "winner",
                    message = string.format("%s is the Delta Total Drama winner!", winner.player.Name),
                    player = winner.player.Name,
                    dramaLevel = 5
                })
            end
        end
    end
end

-- Player connection handlers
local function onPlayerJoin(player)
    if not gameState.isRunning and #gameState.contestants < CONFIG.MaxPlayers then
        local personalityKeys = {}
        for key in pairs(DRAMA_PERSONALITIES) do
            table.insert(personalityKeys, key)
        end
        local randomPersonality = personalityKeys[math.random(1, #personalityKeys)]
        
        table.insert(gameState.contestants, {
            player = player,
            personality = randomPersonality,
            status = "active",
            score = 0,
            alliances = {},
            dramaPoints = 0,
        })
        
        DramaEvent:FireClient(player, {
            type = "join",
            message = string.format("Welcome to Delta Total Drama! Your personality is %s", randomPersonality),
            player = player.Name,
            dramaLevel = 1
        })
    end
end

local function onPlayerLeave(player)
    -- Handle player leaving
    for i, contestant in ipairs(gameState.contestants) do
        if contestant.player == player then
            contestant.status = "eliminated"
            table.insert(gameState.eliminated, contestant)
            table.remove(gameState.contestants, i)
            break
        end
    end
end

-- Remote event handlers
VoteEvent.OnServerEvent:Connect(function(player, vote)
    if gameState.currentPhase == "voting" then
        gameState.votes[player.UserId] = vote
    end
end)

-- Start game when enough players
local function checkAndStartGame()
    if not gameState.isRunning and #gameState.contestants >= CONFIG.MinPlayers then
        gameState.isRunning = true
        initializeGame()
        startGameLoop()
    end
end

-- Connect player events
Players.PlayerAdded:Connect(onPlayerJoin)
Players.PlayerRemoving:Connect(onPlayerLeave)

-- Initial check
task.wait(5)
checkAndStartGame()

-- Periodic check for game start
task.spawn(function()
    while true do
        task.wait(10)
        checkAndStartGame()
    end
end)

-- Cleanup
game:BindToClose(function()
    gameState.isRunning = false
end)
