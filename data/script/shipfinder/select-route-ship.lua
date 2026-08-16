local gi = Variables:GetVariable("S3G") or 1
local rp = Variables:GetVariable("S3RP") or 0
local rs = Variables:GetVariable("S3RS") or 1
local shipSlot = Variables:GetVariable("S3L") or 1

local function getOverviewArray()
    return ui and ui.Scenes and ui.Scenes.TradeRoute
        and ui.Scenes.TradeRoute.TradeOverview
        and ui.Scenes.TradeRoute.TradeOverview.OverviewListData
        and ui.Scenes.TradeRoute.TradeOverview.OverviewListData.ArrayData or nil
end

local function getActiveRouteNameSet()
    local names = {}
    for _, object in pairs(Scripts:GetObjectGroupByProperty(Properties.ShipModuleOwner) or {}) do
        local tr = object.TradeRouteVehicle
        if tr and tr.IsAssignedOnTradeRoute and not tr.IsPaused and tr.RouteName ~= nil then names[tostring(tr.RouteName)] = true end
    end
    return names
end

local function getSelectedRouteName()
    local arr = getOverviewArray()
    if not arr then return nil, nil end
    local active = getActiveRouteNameSet()
    local nativeGroups, soloExists = {}, false

    for i = 0, 511 do
        local row = arr[i]
        if row ~= nil then
            local okOpen, isOpen = pcall(function() return row.IsGroupOpen end)
            local okBtn, btn = pcall(function() return row.ButtonData end)
            if okOpen and okBtn and type(isOpen) == "boolean" and btn ~= nil then
                local folderID, name = nil, nil
                pcall(function() folderID = btn.FolderID end)
                pcall(function() name = btn.NameData and btn.NameData.Text or nil end)
                nativeGroups[#nativeGroups + 1] = {folderID=folderID, name=name or ""}
            else
                local routeID, folderID = nil, nil
                pcall(function() routeID = row.RouteID end)
                pcall(function() folderID = row.FolderID end)
                if type(routeID) == "number" and routeID >= 0 and folderID == -1 then soloExists = true end
            end
        end
    end

    local function routesFor(folderID)
        local routes = {}
        for i = 0, 511 do
            local row = arr[i]
            if row ~= nil then
                local routeID, rowFolder, name = nil, nil, nil
                pcall(function() routeID = row.RouteID end)
                pcall(function() rowFolder = row.FolderID end)
                pcall(function() name = row.NameData and row.NameData.Text or nil end)
                if type(routeID) == "number" and routeID >= 0 and rowFolder == folderID
                    and name ~= nil and active[tostring(name)] then routes[#routes + 1] = tostring(name) end
            end
        end
        return routes
    end

    local visible = {}
    for _, group in ipairs(nativeGroups) do
        local routes = routesFor(group.folderID)
        if #routes > 0 then visible[#visible + 1] = {name=group.name, routes=routes} end
    end
    if soloExists then
        local routes = routesFor(-1)
        if #routes > 0 then visible[#visible + 1] = {name="Ungrouped routes", routes=routes} end
    end

    local group = visible[gi]
    if not group then return nil, nil end
    return group.routes[rp * 3 + rs], group.name
end

local routeName, groupName = getSelectedRouteName()
local records = {}
for _, object in pairs(Scripts:GetObjectGroupByProperty(Properties.ShipModuleOwner) or {}) do
    local name = object.Nameable and object.Nameable.Name
    local tr = object.TradeRouteVehicle
    if name ~= nil and tr and tr.IsAssignedOnTradeRoute and not tr.IsPaused
        and routeName ~= nil and tostring(tr.RouteName) == tostring(routeName) then
        records[#records + 1] = {name=tostring(name), key=string.lower(tostring(name)).."|"..tostring(object.ID), object=object}
    end
end

table.sort(records, function(a,b) return a.key < b.key end)
local selected = records[shipSlot]

system.log("[Ship Finder Route Ship 1.1.0] selection"
    .." | group="..tostring(groupName).." | routePage="..tostring(rp).." | routeSlot="..tostring(rs)
    .." | route="..tostring(routeName).." | shipSlot="..tostring(shipSlot)
    .." | candidates="..tostring(#records).." | selected="..tostring(selected and selected.name or "<none>"))

if selected then
    local objectID = selected.object.ID
    local selectOk, selectErr = pcall(function() Selection:SelectByID(objectID) end)
    local jumpOk, jumpErr = pcall(function() Scripts:JumpToObject(objectID) end)
    system.log("[Ship Finder Route Ship 1.1.0] jump"
        .." | ship="..tostring(selected.name).." | objectId="..tostring(objectID)
        .." | selectSuccess="..tostring(selectOk).." | jumpSuccess="..tostring(jumpOk)
        .." | selectError="..tostring(selectErr or "").." | jumpError="..tostring(jumpErr or ""))
end
