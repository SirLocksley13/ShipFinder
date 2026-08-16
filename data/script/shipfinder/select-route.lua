local gi = Variables:GetVariable("S3G") or 1
local page = Variables:GetVariable("S3RP") or 0
local slot = Variables:GetVariable("S3L") or 1

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
        if tr and tr.IsAssignedOnTradeRoute and not tr.IsPaused and tr.RouteName ~= nil then
            names[tostring(tr.RouteName)] = true
        end
    end
    return names
end

local function getVisibleGroups()
    local arr = getOverviewArray()
    local visible = {}
    if not arr then return visible end

    local active = getActiveRouteNameSet()
    local nativeGroups = {}
    local soloExists = false

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
                if type(routeID) == "number" and routeID >= 0 and folderID == -1 then
                    soloExists = true
                end
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
                if type(routeID) == "number" and routeID >= 0
                    and rowFolder == folderID
                    and name ~= nil
                    and active[tostring(name)]
                then
                    routes[#routes + 1] = {
                        routeID=routeID,
                        name=tostring(name),
                        folderID=rowFolder
                    }
                end
            end
        end
        return routes
    end

    for _, group in ipairs(nativeGroups) do
        local routes = routesFor(group.folderID)
        if #routes > 0 then
            visible[#visible + 1] = {
                name=group.name,
                folderID=group.folderID,
                routes=routes
            }
        end
    end

    if soloExists then
        local routes = routesFor(-1)
        if #routes > 0 then
            visible[#visible + 1] = {
                name="Ungrouped routes",
                folderID=-1,
                routes=routes
            }
        end
    end

    return visible
end

local visibleGroups = getVisibleGroups()
local group = visibleGroups[gi]
local routes = group and group.routes or {}
local selectedRoute = routes[page * 3 + slot]
local routeName = selectedRoute and selectedRoute.name or nil
local records = {}

for _, object in pairs(Scripts:GetObjectGroupByProperty(Properties.ShipModuleOwner) or {}) do
    local name = object.Nameable and object.Nameable.Name
    local tr = object.TradeRouteVehicle
    if name ~= nil and tr and tr.IsAssignedOnTradeRoute and not tr.IsPaused
        and routeName ~= nil and tostring(tr.RouteName) == tostring(routeName)
    then
        records[#records + 1] = {
            name=tostring(name),
            key=string.lower(tostring(name)).."|"..tostring(object.ID),
            object=object
        }
    end
end

table.sort(records, function(a,b) return a.key < b.key end)

system.log("[Ship Finder Native Route 1.1.0] selected"
    .." | groupSlot="..tostring(gi)
    .." | group="..tostring(group and group.name or nil)
    .." | page="..tostring(page)
    .." | slot="..tostring(slot)
    .." | route="..tostring(routeName)
    .." | routeID="..tostring(selectedRoute and selectedRoute.routeID or nil)
    .." | ships="..tostring(#records))

if #records == 1 then
    local selected = records[1]
    local objectID = selected.object.ID

    -- Do not try to close NarrativeSequence from this Action context. The XML
    -- route Sequence has no output connector after this final script in v1.1.0.
    -- Anno therefore ends the Sequence naturally after the jump, matching the
    -- older runtime-proven Ship Finder lifecycle.
    local selectOk, selectErr = pcall(function()
        Selection:SelectByID(objectID)
    end)
    local jumpOk, jumpErr = pcall(function()
        Scripts:JumpToObject(objectID)
    end)

    system.log("[Ship Finder Native Route 1.1.0] DIRECT SHIP JUMP"
        .." | route="..tostring(routeName)
        .." | ship="..tostring(selected.name)
        .." | objectId="..tostring(objectID)
        .." | selectSuccess="..tostring(selectOk)
        .." | jumpSuccess="..tostring(jumpOk)
        .." | cleanup=natural-sequence-end"
        .." | selectError="..tostring(selectErr or "")
        .." | jumpError="..tostring(jumpErr or ""))
    return
end

if #records > 1 then
    local requestOk, requestErr = pcall(function()
        GovernorDecision:CheatStartGovernorDecisionForCurrentPlayerNet(2099040)
    end)

    system.log("[Ship Finder Multi Route 1.1.0] PREPARE"
        .." | route="..tostring(routeName)
        .." | ships="..tostring(#records)
        .." | requestSuccess="..tostring(requestOk)
        .." | requestError="..tostring(requestErr or "")
        .." | routeSequenceEndsNaturally=true")
    return
end

system.log("[Ship Finder Native Route 1.1.0] NO ACTIVE SHIP"
    .." | route="..tostring(routeName))
