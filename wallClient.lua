local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Constant = require(ReplicatedStorage.Modules.Constants)
local Multipliers = require(ReplicatedStorage.Modules.Multiplier)
local WallData = require(ReplicatedStorage.Modules.SharedData.WallData)
local WorldInfo = require(ReplicatedStorage.Modules.SharedData.WorldData)
local NumberController = require(ReplicatedStorage.Modules.NumberController)

local WallHitController = Knit.CreateController({ Name = "WallHitController" })

local Remotes = ReplicatedStorage.Remotes
local SurfaceGui = script.SurfaceGui
local WallDataTable = {}
local GemsNames = {}
local GemSpawned = {}
local GemDebounce = false

local canRun = false

local smoke = ReplicatedStorage.Assets.Other.Smoke

local BaseTime = 0.03
local BaseMovementDistance = 0.3
local RepeatAmount = 1
local HPBarAnimationTime = 0.3

-- if you didnt change progress bar, don't change that value
local BasePixelSize = 385

local TIFirstMoveForward = TweenInfo.new(BaseTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TILastMoveBackward = TweenInfo.new(BaseTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local TIFullMove = TweenInfo.new(BaseTime * 2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

local TIProgressBar = TweenInfo.new(HPBarAnimationTime, Enum.EasingStyle.Linear)

local function PlayTween(Wall: Part, GoalPosition, info)
    local tween = TweenService:Create(Wall, info, { Position = GoalPosition })
    tween:Play()
    tween.Completed:Wait()
end

local function ChangeDamageBar(Wall: Part, CurrentWallHP: number, MaximumWallHP: number)
    task.spawn(function()
        local EndHP = CurrentWallHP
        if EndHP <= 0 then
            EndHP = 0
        end

        local EndHPWords = nil
        local MaxWallWords = nil

        if EndHP >= 1_000_000 then
            EndHPWords = NumberController.SuffixNumber(EndHP)
        else
            EndHPWords = NumberController.Comma(EndHP)
        end
        if MaximumWallHP >= 1_000_000 then
            MaxWallWords = NumberController.SuffixNumber(MaximumWallHP)
        else
            MaxWallWords = NumberController.Comma(MaximumWallHP)
        end

        Wall.SurfaceGui.Frame.Frame.TextLabel.Text = EndHPWords .. "/" ..MaxWallWords
        local ProgressBar = Wall.SurfaceGui.Frame.Frame.ProgressBar
        local Percent = EndHP / MaximumWallHP
        local PixelSize = math.floor(Percent * BasePixelSize)
        local tween = TweenService:Create(ProgressBar, TIProgressBar, { Size = UDim2.new(0, PixelSize, 0, 65) })
        tween:Play()
        tween.Completed:Wait()
    end)
end

local function shouldGemSpawn()
    local shouldGemSpawn = (function()
        local randomNumber = math.random(0, 100)
        --> if random number is below 33 then it can spawn
        if randomNumber <= 10 then
            return true
        end

        return false
    end)()

    return shouldGemSpawn
end

function IsGemThere(GemName)
    if GemSpawned[GemName] then
        local index = table.find(GemsNames, GemName)
        table.remove(GemsNames, index)
        local Gem = GemSpawned[GemName]
        Gem:Destroy()
        GemSpawned[GemName] = nil

        return true
    end

    return false
end

function WallHitController:GemSpawn(Wall: Part)
    local RemoteService = Knit.GetService("RemoteService")
    local shouldGemSpawn = shouldGemSpawn()
    if Wall:FindFirstChild("GemSpawner") then
        --> if not gem already spawned and if gem can be spawned then continue
        if not Wall:FindFirstChild("GemSpawner"):FindFirstChild("Gem") and shouldGemSpawn then
            local GemClone = ReplicatedStorage.Assets.Other.Gem:Clone()
            local GemName = "Gem" .. HttpService:GenerateGUID(false)
            GemClone.Parent = Wall:FindFirstChild("GemSpawner")
            GemClone.CFrame = Wall:FindFirstChild("GemSpawner").CFrame
            table.insert(GemsNames, GemName)
            GemSpawned[GemName] = GemClone

            GemClone.Touched:Connect(function(Hit)
                if GemDebounce == false then
                    if Hit.Parent:FindFirstChild("Humanoid") then
                        local clientPlayer = Players:GetPlayerFromCharacter(Hit.Parent)
                        if clientPlayer == Players.LocalPlayer then
                            GemDebounce = true
                            SoundService:PlayLocalSound(SoundService.SFX.WallSystem.ClaimGem)
                            RemoteService:AddGems(GemName, Wall.Parent.Name)
                            task.wait(0.5)
                            GemDebounce = false
                        end
                    end
                end
            end)
        end
    end
end

function WallHitController:ShakeWall(Wall: Part, CurrentWallHP: number, MaximumWallHP: number, WorldName)
    --Make this work again
    ChangeDamageBar(Wall, CurrentWallHP, MaximumWallHP)

    local StartPosition = Wall.Position
    local FarthestPosition = StartPosition + (Wall.CFrame.LookVector * BaseMovementDistance)
    local ClosestPosition = StartPosition - (Wall.CFrame.LookVector * BaseMovementDistance)

    local ClonedSmoke
    local DeleteWall = false
    if CurrentWallHP <= 0 then
        ClonedSmoke = smoke:Clone()
        ClonedSmoke.Parent = Wall
        DeleteWall = true
    end

    PlayTween(Wall, FarthestPosition, TIFirstMoveForward)
    PlayTween(Wall, ClosestPosition, TIFullMove)
    for i = 1, RepeatAmount do
        PlayTween(Wall, FarthestPosition, TIFullMove)
        PlayTween(Wall, ClosestPosition, TIFullMove)
    end
    PlayTween(Wall, StartPosition, TILastMoveBackward)

    if DeleteWall then
        local sound = game.SoundService.SFX.WallSystem.WallBreak:Clone()

        if WallDataTable[WorldName][tonumber(Wall.Name) + 1] ~= nil then
            WallHitController:LoadSurfaceGui(true, tonumber(Wall.Name) + 1, WorldName)
        end

        self:GemSpawn(Wall)

        sound.Parent = Wall
        sound.TimePosition = 0.9
        sound:Play()

        ClonedSmoke.Enabled = false
        Wall.Transparency = 1
        for i, v in pairs(Wall:GetChildren()) do
            if v:IsA("Texture") then
                v.Transparency = 1
            end
        end
        Wall.SurfaceGui.Enabled = false
        Wall.CanCollide = false
        task.delay(5, function()
            ClonedSmoke:Destroy()
            sound:Destroy()
        end)
    end
end

local function ReturnData(World)
    local count = 0
    for i, v in WallDataTable[World] do
        count = count + 1
    end
    return count
end

local function ReturnWallHitData(World, wallNumber)
    local DataController = Knit.GetController("DataController")
    local Replica = DataController:GetReplica("PlayerProfile")

    local TrainingPower = Replica.Data.Power * Multipliers.GetDamageMulti(Players.LocalPlayer)

    local tableInfo = {}
    for i = wallNumber, ReturnData(World) do
        if WallDataTable[World][i].MaxValue < TrainingPower then
            TrainingPower = TrainingPower - WallDataTable[World][i].CurrentValue
            table.insert(tableInfo, { i, 0 })
        else
            table.insert(tableInfo, { i, WallDataTable[World][i].CurrentValue - TrainingPower })
            return tableInfo
        end
    end

    return tableInfo
end

function WallHitController:WallHit(WorldName, Model)
    if Model.Transparency == 1 then
        return
    end
    local WallInfo = ReturnWallHitData(WorldName, tonumber(Model.Name))
    for index, info in WallInfo do
        self:ShakeWall(
            workspace.Walls[WorldName][info[1]],
            info[2],
            WallDataTable[WorldName][info[1]].MaxValue,
            WorldName
        )
        WallDataTable[WorldName][info[1]].CurrentValue = info[2]
        task.wait(0.1)
    end
end

function Reset(WorldName)
    --> reset values
    for wallIndex, wall_Data in WallData.BaseValue.Data do
        local GetWorldNumber = Constant.GetPlayerWorldNumber(WorldName)
        local value = Constant.GetRealValueWalls(wall_Data, GetWorldNumber)

        if not WallDataTable[WorldName][wallIndex] then
            continue
        end
        WallDataTable[WorldName][wallIndex].CurrentValue = value

        workspace.Walls[WorldName][tostring(wallIndex)].Transparency = 0
        workspace.Walls[WorldName][tostring(wallIndex)].CanCollide = true
        for i, v in pairs(workspace.Walls[WorldName][tostring(wallIndex)]:GetChildren()) do
            if v:IsA("Texture") then
                if WorldName == "Area-27" then
                    v.Transparency = 0.9
                else
                    v.Transparency = 0
                end
            end
            if v:IsA("SurfaceGui") then
                v:Destroy()
            end
        end
    end
    WallHitController:LoadSurfaceGui(true, 1, WorldName)
end

function WallHitController:AreAllWallsDestroyed(WorldName)
    local Destoryed = (function()
        for count, info in WallDataTable[WorldName] do
            if info.CurrentValue > 0 then
                return false
            end
        end
        return true
    end)()

    if Destoryed then
        Reset(WorldName)
    end

    return Destoryed
end

function WallHitController:LoadSurfaceGui(Override: boolean?, WallNumber: IntValue?, WorldName: string?)
    if Override and WallNumber and WorldName then
        local SurfaceGuiClone = SurfaceGui:Clone()
        local maxValue = WallDataTable[WorldName][WallNumber].MaxValue
        local maxValueWords = nil

        if maxValue >= 1_000_000 then
            maxValueWords = NumberController.SuffixNumber(maxValue)
        else
            maxValueWords = NumberController.Comma(maxValue)
        end

        SurfaceGuiClone.Frame.Frame.TextLabel.Text = maxValueWords .. "/" .. maxValueWords
        SurfaceGuiClone.Frame.Frame.ProgressBar.Size = UDim2.fromScale(0.96, 0.8)
        SurfaceGuiClone.Parent = workspace.Walls[WorldName][WallNumber]

        return Override and WallNumber and WorldName
    end

    for WorldNames, Data in WallDataTable do
        local SurfaceGuiClone = SurfaceGui:Clone()
        -- load ui for first wall
        local maxValue = Data[1].MaxValue
        local maxValueWords = nil

        if maxValue >= 1_000_000 then
            maxValueWords = NumberController.SuffixNumber(maxValue)
        else
            maxValueWords = NumberController.Comma(maxValue)
        end

        SurfaceGuiClone.Frame.Frame.TextLabel.Text = maxValueWords .. "/" .. maxValueWords
        SurfaceGuiClone.Frame.Frame.ProgressBar.Size = UDim2.fromScale(0.96, 0.8)

        local WallToParentTo = workspace.Walls:WaitForChild(WorldNames):FindFirstChild("1")
        if WallToParentTo then
            SurfaceGuiClone.Parent = WallToParentTo
        else
            warn("Incorrect Setup of Walls, Skipping World: " .. WorldNames)
        end
    end
end

function WallHitController:KnitStart()
    local RemoteService = Knit.GetService("RemoteService")

    repeat
        task.wait(1)
    until canRun == true
    self:LoadSurfaceGui()

    RemoteService.ClaimRingSound:Connect(function()
        SoundService:PlayLocalSound(SoundService.SFX.WallSystem.Claim)
    end)
end

function WallHitController:KnitInit()
    --> load all values
    task.spawn(function()
        for index, world_Info in WorldInfo do
            local worldName = world_Info.WorldName
            WallDataTable[worldName] = {}

            for wallIndex, wall_Data in WallData.BaseValue.Data do
                if workspace.Walls[worldName]:FindFirstChild(wallIndex) then

                    local value = Constant.GetRealValueWalls(wall_Data, index)
                    WallDataTable[worldName][wallIndex] = {}
                    WallDataTable[worldName][wallIndex].MaxValue = value
                    WallDataTable[worldName][wallIndex].CurrentValue = value
                end
            end
        end

        canRun = true
    end)

    Remotes.AreAllWallsDestroyed.OnClientInvoke = function(WorldName)
        return WallHitController:AreAllWallsDestroyed(WorldName)
    end
    Remotes.GemSpawned.OnClientInvoke = function(Gem)
        return IsGemThere(Gem)
    end
end

return WallHitController
