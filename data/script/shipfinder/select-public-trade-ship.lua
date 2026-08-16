
local function getSelectedNativeRouteName()
    local gi = Variables:GetVariable("S3G") or 1
    local rp = Variables:GetVariable("S3RP") or 0
    local rs = Variables:GetVariable("S3L") or 1
    local arr = ui
        and ui.Scenes
        and ui.Scenes.TradeRoute
        and ui.Scenes.TradeRoute.TradeOverview
        and ui.Scenes.TradeRoute.TradeOverview.OverviewListData
        and ui.Scenes.TradeRoute.TradeOverview.OverviewListData.ArrayData
        or nil
    if not arr then return nil end

    local groups = {}
    local soloExists = false
    for i=0,511 do
        local row=arr[i]
        if row~=nil then
            local okOpen,isOpen=pcall(function()return row.IsGroupOpen end)
            local okBtn,btn=pcall(function()return row.ButtonData end)
            if okOpen and okBtn and type(isOpen)=="boolean" and btn~=nil then
                local f=nil
                pcall(function()f=btn.FolderID end)
                groups[#groups+1]=f
            else
                local rid=nil
                local f=nil
                pcall(function()rid=row.RouteID end)
                pcall(function()f=row.FolderID end)
                if type(rid)=="number" and rid>=0 and f==-1 then soloExists=true end
            end
        end
    end

    local folder=nil
    if gi<=#groups then folder=groups[gi]
    elseif gi==#groups+1 and soloExists then folder=-1 end

    local routes={}
    for i=0,511 do
        local row=arr[i]
        if row~=nil then
            local rid=nil
            local f=nil
            local n=nil
            pcall(function()rid=row.RouteID end)
            pcall(function()f=row.FolderID end)
            pcall(function()n=row.NameData and row.NameData.Text or nil end)
            if type(rid)=="number" and rid>=0 and f==folder then
                routes[#routes+1]=n
            end
        end
    end
    return routes[rp*3+rs]
end

local selectedNativeRouteName = getSelectedNativeRouteName()

system.log("[Ship Finder Public Category] handler entered")

local category = Variables:GetVariable("S3C") or 0
local page = Variables:GetVariable("S3Q") or 0
local slot = Variables:GetVariable("S3L") or 1

local records = {}
for _, object in pairs(Scripts:GetObjectGroupByProperty(Properties.ShipModuleOwner) or {}) do
    local nameable = object.Nameable
    local rawName = nameable and nameable.Name
    if rawName ~= nil then
        local name = tostring(rawName)
        local route = object.TradeRouteVehicle
        local assigned = route and route.IsAssignedOnTradeRoute or false
        local paused = route and route.IsPaused or false
        local unit = object.Unit
        local military = unit and unit.IsMilitaryUnit or false
        local include = false

        if category == 1 then
            include = assigned and not paused
        elseif category == 2 then
            include = (not military) and assigned and paused
        elseif category == 4 then
            include = military
        elseif category == 5 then
            include = (not military) and (not assigned)
        elseif category == 6 then
            local routeName = route and route.RouteName or nil
            include = assigned and (not paused)
                and routeName ~= nil
                and selectedNativeRouteName ~= nil
                and tostring(routeName) == tostring(selectedNativeRouteName)
        end

        if include then
            records[#records + 1] = {
                name = name,
                key = string.lower(name) .. "|" .. tostring(object.ID),
                object = object
            }
        end
    end
end

table.sort(records, function(a, b)
    return a.key < b.key
end)

local selected = records[page * 3 + slot]
system.log(
    "[Ship Finder Public Category] selection"
    .. " | category=" .. tostring(category)
    .. " | page=" .. tostring(page)
    .. " | slot=" .. tostring(slot)
    .. " | candidates=" .. tostring(#records)
    .. " | selected=" .. tostring(selected and selected.name or "<none>")
)

if selected then
    local ok, err = pcall(function()
        Selection:SelectByID(selected.object.ID)
        Scripts:JumpToObject(selected.object.ID)
    end)

    if ok then
        system.log(
            "[Ship Finder Public Category] jump completed"
            .. " | objectId=" .. tostring(selected.object.ID)
        )
    else
        system.log(
            "[Ship Finder Public Category] jump ERROR"
            .. " | objectId=" .. tostring(selected.object.ID)
            .. " | error=" .. tostring(err)
        )
    end
end
