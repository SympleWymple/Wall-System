local function HitboxHandler(Player: Player, HRPPos, HRPCFrame)
    local StartPoint = HRPPos - HitboxSize / 2
    local EndPoint = HRPPos + HitboxSize / 2
    StartPoint += HRPCFrame.LookVector * Offset
    EndPoint += HRPCFrame.LookVector * Offset
    local Region3 = Region3.new(StartPoint, EndPoint)

    for _, part in (game.Workspace:FindPartsInRegion3(Region3, nil, 50)) do
        if part:GetAttribute("Table") ~= nil then
            if part:GetAttribute("Table") == false then
                return "Table", "Normal", part.Parent.Parent.Name, part.Parent
            elseif part:GetAttribute("Table") == true then
                return "Table", "Vip", part.Parent.Parent.Name, part.Parent
            end
        else
            if part:GetAttribute("Wall") ~= nil then
                return "Wall", nil, part.Parent.Parent.Name, part.Parent
            end
        end
    end
    return false
end
function RemoteService.Client:HeadButt(Player, delayTime, HRPPos, HPRCFrame)
    local DataService = Knit.GetService("DataService")

    local Type, Vip, World, Model = HitboxHandler(Player, HRPPos, HPRCFrame)
    if Type == "Table" then
        if Type == "Table" and Vip == "Normal" then
            task.delay(delayTime, function()
                givePowerStats(Player, World, Vip)
            end)

        elseif Type == "Table" and Vip == "Vip" then
            if Player.MembershipType == Enum.MembershipType.Premium or DataService:Get(Player, { "Gamepass", "VIP" }) == true  then
                task.delay(delayTime, function()
                    givePowerStats(Player, World, Vip)
                end)
            else
                MarketPlaceService:PromptGamePassPurchase(Player, 642637241)
            end
        else
            return 0,0,0
        end
        return Type, World, Model
    else
        if Type == "Wall" then
            return Type, World, Model
        end
    end
    return 0,0,0
end
