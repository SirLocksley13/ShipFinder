local CombinedRoot = {}

-- Generic Ship Finder deep-probe build.
-- No player-name or Sir Locksley naming-convention detection.
local PUBLIC_STORYLINE = 2035050
local TAG = "[Ship Finder Route Group Deep Probe 1.1.0]"

local function logValue(label, key, value)
    if value ~= nil then
        system.log(
            TAG .. " " .. label
            .. " | " .. tostring(key) .. "=" .. tostring(value)
            .. " | type=" .. tostring(type(value))
        )
    end
end

local function safeRead(label, object, key)
    local ok, value = pcall(function()
        return object and object[key]
    end)
    if ok and value ~= nil then
        logValue(label, key, value)
        return value
    end
    return nil
end

local function safeCallNoArgs(label, object, key)
    local member = safeRead(label, object, key)
    if type(member) == "function" then
        local ok, value = pcall(function() return member(object) end)
        if ok and value ~= nil then
            logValue(label .. " CALL", key .. "()", value)
            return value
        end
    end
    return nil
end

local function probeObjectSurface(label, object)
    if not object then return end

    local keys = {
        -- route identity / naming
        "Name", "RouteName", "TradeRouteName", "DisplayName", "Description",
        "ID", "GUID", "RouteID", "RouteGUID", "TradeRouteID", "TradeRouteGUID",

        -- likely group/category/container members
        "Group", "GroupID", "GroupGUID", "GroupName",
        "RouteGroup", "RouteGroupID", "RouteGroupGUID", "RouteGroupName",
        "TradeRouteGroup", "TradeRouteGroupID", "TradeRouteGroupGUID", "TradeRouteGroupName",
        "Category", "CategoryID", "CategoryGUID", "CategoryName",
        "Folder", "FolderID", "FolderGUID", "FolderName",
        "Parent", "ParentID", "ParentGUID", "ParentName",
        "Container", "ContainerID", "ContainerGUID", "ContainerName",
        "Owner", "OwnerID", "OwnerGUID", "OwnerName",

        -- likely direct object references
        "TradeRoute", "Route", "CurrentRoute", "AssignedTradeRoute",
        "TradeRouteData", "RouteData", "GroupData", "RouteGroupData",

        -- state / index hints
        "IsAssignedOnTradeRoute", "IsPaused", "Index", "GroupIndex", "RouteIndex",
        "Position", "Slot", "SlotIndex"
    }

    local nested = {}
    for _, key in ipairs(keys) do
        local value = safeRead(label, object, key)
        local t = type(value)
        if value ~= nil and (t == "table" or t == "userdata") then
            nested[#nested + 1] = { key = key, value = value }
        end
    end

    -- Probe common no-arg getter spellings if bindings expose methods rather than properties.
    local getters = {
        "GetName", "GetRouteName", "GetTradeRouteName",
        "GetID", "GetGUID", "GetRouteID", "GetTradeRouteID",
        "GetGroup", "GetGroupID", "GetGroupName",
        "GetRouteGroup", "GetRouteGroupID", "GetRouteGroupName",
        "GetTradeRouteGroup", "GetTradeRouteGroupID", "GetTradeRouteGroupName",
        "GetCategory", "GetCategoryName", "GetFolder", "GetFolderName", "GetParent", "GetParentName"
    }
    for _, key in ipairs(getters) do
        local value = safeCallNoArgs(label, object, key)
        local t = type(value)
        if value ~= nil and (t == "table" or t == "userdata") then
            nested[#nested + 1] = { key = key .. "()", value = value }
        end
    end

    -- One level deeper only, to avoid runaway probing.
    local nestedKeys = {
        "Name", "DisplayName", "ID", "GUID",
        "GroupName", "RouteGroupName", "TradeRouteGroupName",
        "CategoryName", "FolderName", "ParentName",
        "GroupID", "RouteGroupID", "TradeRouteGroupID", "CategoryID", "FolderID", "ParentID"
    }
    for _, entry in ipairs(nested) do
        for _, key in ipairs(nestedKeys) do
            safeRead(label .. " -> " .. tostring(entry.key), entry.value, key)
        end
    end

end

local function probeRouteGroupSurface()
    local objects = Scripts:GetObjectGroupByProperty(Properties.ShipModuleOwner) or {}
    local probed = 0

    for _, object in pairs(objects) do
        if probed >= 8 then break end

        local route = object.TradeRouteVehicle
        if route then
            local name = object.Nameable and object.Nameable.Name or "<unnamed>"
            local assigned = false
            local paused = false
            pcall(function() assigned = route.IsAssignedOnTradeRoute == true end)
            pcall(function() paused = route.IsPaused == true end)

            if assigned or paused then
                probed = probed + 1
                local label = "ship=" .. tostring(name) .. " id=" .. tostring(object.ID)
                system.log(
                    TAG .. " ROUTE SHIP"
                    .. " | " .. label
                    .. " | assigned=" .. tostring(assigned)
                    .. " | paused=" .. tostring(paused)
                )

                probeObjectSurface(label .. " route", route)
                probeObjectSurface(label .. " ship", object)
            end
        end
    end

    system.log(
        TAG .. " COMPLETE"
        .. " | routeShipsProbed=" .. tostring(probed)
        .. " | send logfile after opening Ship Finder once"
    )
end




local ROUTE_GROUP_MANAGER_CANDIDATES = {
    "TradeRouteManager",
    "TradeRoutes",
    "TradeRoute",
    "TradeRouteGroups",
    "TradeRouteGroupManager",
    "RouteManager",
    "RouteGroups",
}

local ROUTE_GROUP_SCENE_CANDIDATES = {
    "TradeRoute",
    "TradeRoutes",
    "TradeRouteMenu",
    "TradeRouteOverview",
    "TradeRouteManagement",
    "TradeRouteSelection",
    "TradeRouteScreen",
    "TradeRouteEditor",
}

local ROUTE_GROUP_MEMBER_CANDIDATES = {
    "Name", "ID", "GUID",
    "Groups", "Group", "GroupList",
    "RouteGroups", "TradeRouteGroups",
    "Routes", "RouteList", "TradeRoutes",
    "SelectedGroup", "CurrentGroup", "ActiveGroup",
    "SelectedRoute", "CurrentRoute", "ActiveRoute",
    "GroupName", "GroupID", "GroupGUID",
    "RouteGroupName", "RouteGroupID", "RouteGroupGUID",
    "TradeRouteGroupName", "TradeRouteGroupID", "TradeRouteGroupGUID",
}

local function safeReadCandidate(ownerLabel, object, member)
    if not object then
        return
    end

    local ok, value = pcall(function()
        return object[member]
    end)

    if ok and value ~= nil then
        system.log(
            "[Ship Finder Route Group Surface Probe 1.1.0]"
            .. " | owner=" .. tostring(ownerLabel)
            .. " | member=" .. tostring(member)
            .. " | value=" .. tostring(value)
            .. " | type=" .. tostring(type(value))
        )
    end
end

local function probeObjectMembers(ownerLabel, object)
    if not object then
        return
    end

    system.log(
        "[Ship Finder Route Group Surface Probe 1.1.0]"
        .. " | OBJECT FOUND"
        .. " | owner=" .. tostring(ownerLabel)
        .. " | type=" .. tostring(type(object))
    )

    for _, member in ipairs(ROUTE_GROUP_MEMBER_CANDIDATES) do
        safeReadCandidate(ownerLabel, object, member)
    end

    -- Probe one level of common nested data containers.
    local nestedNames = {
        "SceneData", "Data", "Model", "ViewModel",
        "Manager", "RouteManager", "TradeRouteManager",
        "Groups", "RouteGroups", "TradeRouteGroups",
    }

    for _, nestedName in ipairs(nestedNames) do
        local okNested, nested = pcall(function()
            return object[nestedName]
        end)

        if okNested and nested ~= nil then
            local nestedLabel = tostring(ownerLabel) .. "." .. tostring(nestedName)
            system.log(
                "[Ship Finder Route Group Surface Probe 1.1.0]"
                .. " | NESTED FOUND"
                .. " | owner=" .. tostring(nestedLabel)
                .. " | type=" .. tostring(type(nested))
            )

            for _, member in ipairs(ROUTE_GROUP_MEMBER_CANDIDATES) do
                safeReadCandidate(nestedLabel, nested, member)
            end
        end
    end
end

local function probeRouteGroupManagersAndUI()
    system.log("[Ship Finder Route Group Surface Probe 1.1.0] START")

    -- Global manager candidates.
    for _, globalName in ipairs(ROUTE_GROUP_MANAGER_CANDIDATES) do
        local okGlobal, object = pcall(function()
            return _G[globalName]
        end)

        if okGlobal and object ~= nil then
            probeObjectMembers("global." .. globalName, object)
        end
    end

    -- GameSession / session-level candidates.
    if GameSession then
        for _, memberName in ipairs(ROUTE_GROUP_MANAGER_CANDIDATES) do
            local okMember, object = pcall(function()
                return GameSession[memberName]
            end)

            if okMember and object ~= nil then
                probeObjectMembers("GameSession." .. memberName, object)
            end
        end
    end

    -- UI scene candidates. Route groups may only exist in the trade-route UI model.
    if ui and ui.Scenes then
        for _, sceneName in ipairs(ROUTE_GROUP_SCENE_CANDIDATES) do
            local okScene, scene = pcall(function()
                return ui.Scenes[sceneName]
            end)

            if okScene and scene ~= nil then
                probeObjectMembers("ui.Scenes." .. sceneName, scene)
            end
        end
    end

    system.log(
        "[Ship Finder Route Group Surface Probe 1.1.0] COMPLETE"
        .. " | purpose=find route-group manager/UI surface"
    )
end


local function logProbeValue(prefix, key, value)
    system.log(
        "[Ship Finder Route Group Targeted Probe 1.1.0]"
        .. " | " .. tostring(prefix)
        .. " | key=" .. tostring(key)
        .. " | value=" .. tostring(value)
        .. " | type=" .. tostring(type(value))
    )
end

local function enumerateLuaTable(label, tbl, maxEntries)
    if type(tbl) ~= "table" then
        return
    end

    local count = 0
    local okPairs, err = pcall(function()
        for k, v in pairs(tbl) do
            count = count + 1
            logProbeValue(label, k, v)

            -- If the value itself is a small Lua table, enumerate one nested level.
            if type(v) == "table" then
                local nestedCount = 0
                pcall(function()
                    for nk, nv in pairs(v) do
                        nestedCount = nestedCount + 1
                        logProbeValue(label .. "." .. tostring(k), nk, nv)
                        if nestedCount >= 40 then
                            break
                        end
                    end
                end)
            end

            if count >= maxEntries then
                break
            end
        end
    end)

    system.log(
        "[Ship Finder Route Group Targeted Probe 1.1.0]"
        .. " | TABLE ENUM COMPLETE"
        .. " | label=" .. tostring(label)
        .. " | success=" .. tostring(okPairs)
        .. " | entries=" .. tostring(count)
        .. " | error=" .. tostring(err)
    )
end

local TARGETED_SCENE_MEMBERS = {
    "SceneData",
    "Data",
    "Model",
    "ViewModel",
    "Controller",
    "Manager",
    "RouteManager",
    "TradeRouteManager",
    "TradeRouteData",
    "TradeRoutes",
    "Routes",
    "Groups",
    "RouteGroups",
    "TradeRouteGroups",
    "GroupList",
    "RouteList",
    "SelectedGroup",
    "CurrentGroup",
    "SelectedRoute",
    "CurrentRoute",
    "GroupName",
    "GroupID",
    "GroupGUID",
    "RouteGroupName",
    "RouteGroupID",
    "RouteGroupGUID",
    "TradeRouteGroupName",
    "TradeRouteGroupID",
    "TradeRouteGroupGUID",
    "IsVisible",
}

local TARGETED_NESTED_MEMBERS = {
    "Data",
    "Model",
    "ViewModel",
    "Controller",
    "Manager",
    "RouteManager",
    "TradeRouteManager",
    "TradeRouteData",
    "TradeRoutes",
    "Routes",
    "Groups",
    "RouteGroups",
    "TradeRouteGroups",
    "GroupList",
    "RouteList",
    "SelectedGroup",
    "CurrentGroup",
    "SelectedRoute",
    "CurrentRoute",
    "Name",
    "ID",
    "GUID",
    "GroupName",
    "GroupID",
    "GroupGUID",
    "RouteName",
    "RouteID",
    "RouteGUID",
    "RouteGroupName",
    "RouteGroupID",
    "RouteGroupGUID",
}

local function probeUserdataMembers(label, object, memberList)
    if object == nil then
        return
    end

    for _, member in ipairs(memberList) do
        local ok, value = pcall(function()
            return object[member]
        end)

        if ok and value ~= nil then
            logProbeValue(label, member, value)

            -- If a property yields a normal Lua table, enumerate it.
            if type(value) == "table" then
                enumerateLuaTable(label .. "." .. member, value, 80)
            end
        end
    end
end

local function runTargetedRouteGroupProbe()
    system.log("[Ship Finder Route Group Targeted Probe 1.1.0] START")

    -- 1) We KNOW this exists and is a Lua table from v1.1.17.
    local tradeRouteGlobal = nil
    local okGlobal = pcall(function()
        tradeRouteGlobal = _G["TradeRoute"]
    end)

    system.log(
        "[Ship Finder Route Group Targeted Probe 1.1.0]"
        .. " | global.TradeRoute"
        .. " | lookupSuccess=" .. tostring(okGlobal)
        .. " | present=" .. tostring(tradeRouteGlobal ~= nil)
        .. " | type=" .. tostring(type(tradeRouteGlobal))
    )

    if tradeRouteGlobal ~= nil then
        enumerateLuaTable("global.TradeRoute", tradeRouteGlobal, 200)
    end

    -- 2) We KNOW this scene exists as userdata from v1.1.17.
    local tradeRouteScene = nil
    local okScene = pcall(function()
        if ui and ui.Scenes then
            tradeRouteScene = ui.Scenes.TradeRoute
        end
    end)

    system.log(
        "[Ship Finder Route Group Targeted Probe 1.1.0]"
        .. " | ui.Scenes.TradeRoute"
        .. " | lookupSuccess=" .. tostring(okScene)
        .. " | present=" .. tostring(tradeRouteScene ~= nil)
        .. " | type=" .. tostring(type(tradeRouteScene))
    )

    if tradeRouteScene ~= nil then
        probeUserdataMembers(
            "ui.Scenes.TradeRoute",
            tradeRouteScene,
            TARGETED_SCENE_MEMBERS
        )

        -- If SceneData exists, inspect its likely route/group data members.
        local sceneData = nil
        pcall(function()
            sceneData = tradeRouteScene.SceneData
        end)

        if sceneData ~= nil then
            system.log(
                "[Ship Finder Route Group Targeted Probe 1.1.0]"
                .. " | SceneData FOUND"
                .. " | type=" .. tostring(type(sceneData))
            )

            probeUserdataMembers(
                "ui.Scenes.TradeRoute.SceneData",
                sceneData,
                TARGETED_NESTED_MEMBERS
            )
        end
    end

    system.log(
        "[Ship Finder Route Group Targeted Probe 1.1.0] COMPLETE"
        .. " | next=inspect exact TradeRoute table functions/keys and TradeRoute SceneData"
    )
end


local TRADE_ROUTE_MANAGER_MEMBER_CANDIDATES = {
    "Routes", "TradeRoutes", "RouteList", "TradeRouteList",
    "Groups", "RouteGroups", "TradeRouteGroups", "GroupList",
    "GetRoutes", "GetTradeRoutes", "GetRouteList", "GetTradeRouteList",
    "GetGroups", "GetRouteGroups", "GetTradeRouteGroups", "GetGroupList",
    "GetRoute", "GetTradeRoute", "FindRoute", "FindTradeRoute",
    "GetGroup", "GetRouteGroup", "GetTradeRouteGroup",
    "SelectedRoute", "CurrentRoute", "ActiveRoute",
    "SelectedGroup", "CurrentGroup", "ActiveGroup",
    "RouteCount", "TradeRouteCount", "GroupCount", "RouteGroupCount",
    "Name", "ID", "GUID",
}

local function logManagerProbe(label, member, ok, value)
    system.log(
        "[Ship Finder CTradeRouteManager Probe 1.1.0]"
        .. " | object=" .. tostring(label)
        .. " | member=" .. tostring(member)
        .. " | success=" .. tostring(ok)
        .. " | value=" .. tostring(value)
        .. " | type=" .. tostring(type(value))
    )
end

local function inspectManagerReturnedObject(label, object)
    if object == nil then
        return
    end

    local members = {
        "Name", "ID", "GUID",
        "RouteName", "RouteID", "RouteGUID",
        "GroupName", "GroupID", "GroupGUID",
        "RouteGroupName", "RouteGroupID", "RouteGroupGUID",
        "TradeRouteGroupName", "TradeRouteGroupID", "TradeRouteGroupGUID",
        "IsPaused", "IsActive",
        "Routes", "TradeRoutes", "Groups", "RouteGroups",
        "Ships", "Vehicles", "AssignedShips",
    }

    for _, member in ipairs(members) do
        local ok, value = pcall(function()
            return object[member]
        end)

        if ok and value ~= nil then
            system.log(
                "[Ship Finder CTradeRouteManager Probe 1.1.0]"
                .. " | returned=" .. tostring(label)
                .. " | member=" .. tostring(member)
                .. " | value=" .. tostring(value)
                .. " | type=" .. tostring(type(value))
            )
        end
    end
end

local function inspectReturnedCollection(label, value)
    if type(value) ~= "table" then
        if type(value) == "userdata" then
            inspectManagerReturnedObject(label, value)
        end
        return
    end

    local count = 0
    pcall(function()
        for k, v in pairs(value) do
            count = count + 1
            system.log(
                "[Ship Finder CTradeRouteManager Probe 1.1.0]"
                .. " | collection=" .. tostring(label)
                .. " | key=" .. tostring(k)
                .. " | value=" .. tostring(v)
                .. " | type=" .. tostring(type(v))
            )

            if type(v) == "userdata" or type(v) == "table" then
                inspectManagerReturnedObject(
                    label .. "[" .. tostring(k) .. "]",
                    v
                )
            end

            if count >= 100 then
                break
            end
        end
    end)
end

local function runCTradeRouteManagerProbe()
    system.log("[Ship Finder CTradeRouteManager Probe 1.1.0] START")

    if type(TradeRoute) ~= "table" or type(TradeRoute.get) ~= "function" then
        system.log(
            "[Ship Finder CTradeRouteManager Probe 1.1.0] ABORT"
            .. " | TradeRoute.get unavailable"
        )
        return
    end

    local manager = nil
    local okManager = pcall(function()
        manager = TradeRoute.get()
    end)

    system.log(
        "[Ship Finder CTradeRouteManager Probe 1.1.0]"
        .. " | managerLookupSuccess=" .. tostring(okManager)
        .. " | manager=" .. tostring(manager)
        .. " | type=" .. tostring(type(manager))
    )

    if not okManager or manager == nil then
        return
    end

    local discoveredFunctions = {}

    for _, member in ipairs(TRADE_ROUTE_MANAGER_MEMBER_CANDIDATES) do
        local ok, value = pcall(function()
            return manager[member]
        end)

        if ok and value ~= nil then
            logManagerProbe("manager", member, ok, value)

            if type(value) == "function" then
                discoveredFunctions[#discoveredFunctions + 1] = member
            else
                inspectReturnedCollection("manager." .. member, value)
            end
        end
    end

    -- Safely invoke only getter/list/count-style methods that were actually discovered.
    for _, member in ipairs(discoveredFunctions) do
        if string.sub(member, 1, 3) == "Get"
            or string.find(member, "Count", 1, true)
        then
            local okCall, result = pcall(function()
                return manager[member](manager)
            end)

            system.log(
                "[Ship Finder CTradeRouteManager Probe 1.1.0]"
                .. " | call=" .. tostring(member) .. "()"
                .. " | success=" .. tostring(okCall)
                .. " | result=" .. tostring(result)
                .. " | type=" .. tostring(type(result))
            )

            if okCall and result ~= nil then
                inspectReturnedCollection(
                    "manager:" .. tostring(member) .. "()",
                    result
                )
            end
        end
    end

    system.log(
        "[Ship Finder CTradeRouteManager Probe 1.1.0] COMPLETE"
        .. " | discoveredFunctions=" .. tostring(#discoveredFunctions)
    )
end


local function logGetRouteCandidate(label, ok, value)
    system.log(
        "[Ship Finder GetRoute Signature Probe 1.1.0]"
        .. " | test=" .. tostring(label)
        .. " | success=" .. tostring(ok)
        .. " | value=" .. tostring(value)
        .. " | type=" .. tostring(type(value))
    )
end

local function inspectGetRouteResult(label, object)
    if object == nil then
        return
    end

    local members = {
        "Name", "ID", "GUID",
        "RouteName", "RouteID", "RouteGUID",
        "Group", "GroupID", "GroupGUID", "GroupName",
        "RouteGroup", "RouteGroupID", "RouteGroupGUID", "RouteGroupName",
        "TradeRouteGroup", "TradeRouteGroupID", "TradeRouteGroupGUID", "TradeRouteGroupName",
        "Owner", "SessionGUID",
        "IsPaused", "IsActive",
        "Ships", "Vehicles", "AssignedShips",
        "Stations", "Waypoints", "Stops",
    }

    for _, member in ipairs(members) do
        local ok, value = pcall(function()
            return object[member]
        end)

        if ok and value ~= nil then
            system.log(
                "[Ship Finder GetRoute Signature Probe 1.1.0]"
                .. " | result=" .. tostring(label)
                .. " | member=" .. tostring(member)
                .. " | value=" .. tostring(value)
                .. " | type=" .. tostring(type(value))
            )
        end
    end
end

local function runGetRouteSignatureProbe()
    system.log("[Ship Finder GetRoute Signature Probe 1.1.0] START")

    if type(TradeRoute) ~= "table" or type(TradeRoute.get) ~= "function" then
        system.log(
            "[Ship Finder GetRoute Signature Probe 1.1.0] ABORT"
            .. " | TradeRoute.get unavailable"
        )
        return
    end

    local manager = nil
    local okManager = pcall(function()
        manager = TradeRoute.get()
    end)

    if not okManager or manager == nil then
        system.log(
            "[Ship Finder GetRoute Signature Probe 1.1.0] ABORT"
            .. " | manager unavailable"
        )
        return
    end

    local getRoute = nil
    local okMethod = pcall(function()
        getRoute = manager.GetRoute
    end)

    if not okMethod or type(getRoute) ~= "function" then
        system.log(
            "[Ship Finder GetRoute Signature Probe 1.1.0] ABORT"
            .. " | GetRoute unavailable"
        )
        return
    end

    -- Pick one assigned ship and use its live objects/values as candidate argument types.
    local ship = nil
    local trv = nil
    local shipID = nil
    local routeName = nil

    for _, object in pairs(Scripts:GetObjectGroupByProperty(Properties.ShipModuleOwner) or {}) do
        local tr = object.TradeRouteVehicle
        if tr and tr.IsAssignedOnTradeRoute == true then
            ship = object
            trv = tr
            shipID = object.ID
            pcall(function()
                routeName = tr.RouteName
            end)
            break
        end
    end

    system.log(
        "[Ship Finder GetRoute Signature Probe 1.1.0]"
        .. " | sampleShip=" .. tostring(ship)
        .. " | sampleTRV=" .. tostring(trv)
        .. " | sampleShipID=" .. tostring(shipID)
        .. " | sampleRouteName=" .. tostring(routeName)
    )

    local candidates = {
        {"manager_dot_noarg", function() return manager.GetRoute() end},
        {"manager_colon_noarg", function() return manager:GetRoute() end},
        {"ship_userdata_colon", function() return manager:GetRoute(ship) end},
        {"trv_userdata_colon", function() return manager:GetRoute(trv) end},
        {"ship_id_colon", function() return manager:GetRoute(shipID) end},
        {"route_name_colon", function() return manager:GetRoute(routeName) end},
        {"session_guid_colon", function()
            return manager:GetRoute(GameSession and GameSession.SessionGUID or 0)
        end},
        {"player_41_colon", function() return manager:GetRoute(41) end},
        {"zero_colon", function() return manager:GetRoute(0) end},
        {"one_colon", function() return manager:GetRoute(1) end},
        {"two_colon", function() return manager:GetRoute(2) end},
        {"three_colon", function() return manager:GetRoute(3) end},

        -- Also test dot-call form, in case binding already captures self.
        {"ship_userdata_dot", function() return manager.GetRoute(ship) end},
        {"trv_userdata_dot", function() return manager.GetRoute(trv) end},
        {"ship_id_dot", function() return manager.GetRoute(shipID) end},
        {"route_name_dot", function() return manager.GetRoute(routeName) end},
        {"zero_dot", function() return manager.GetRoute(0) end},
        {"one_dot", function() return manager.GetRoute(1) end},
    }

    for _, candidate in ipairs(candidates) do
        local label = candidate[1]
        local fn = candidate[2]

        local ok, value = pcall(fn)
        logGetRouteCandidate(label, ok, value)

        if ok and value ~= nil then
            if type(value) == "userdata" or type(value) == "table" then
                inspectGetRouteResult(label, value)
            end
        end
    end

    system.log("[Ship Finder GetRoute Signature Probe 1.1.0] COMPLETE")
end


local SESSION_ROUTE_MEMBER_CANDIDATES = {
    "Name", "ID", "GUID", "Index",
    "RouteName", "RouteID", "RouteGUID", "RouteIndex",
    "Group", "GroupID", "GroupGUID", "GroupName", "GroupIndex",
    "RouteGroup", "RouteGroupID", "RouteGroupGUID", "RouteGroupName", "RouteGroupIndex",
    "TradeRouteGroup", "TradeRouteGroupID", "TradeRouteGroupGUID", "TradeRouteGroupName", "TradeRouteGroupIndex",
    "Folder", "FolderID", "FolderGUID", "FolderName", "FolderIndex",
    "Category", "CategoryID", "CategoryGUID", "CategoryName", "CategoryIndex",
    "Parent", "ParentID", "ParentGUID", "ParentName",
    "Owner", "SessionGUID",
    "IsPaused", "IsActive",
    "Ships", "Vehicles", "AssignedShips",
    "Stations", "Stops", "Waypoints",

    "GetName", "GetID", "GetGUID", "GetIndex",
    "GetGroup", "GetGroupID", "GetGroupGUID", "GetGroupName", "GetGroupIndex",
    "GetRouteGroup", "GetRouteGroupID", "GetRouteGroupGUID", "GetRouteGroupName", "GetRouteGroupIndex",
    "GetTradeRouteGroup", "GetTradeRouteGroupID", "GetTradeRouteGroupGUID", "GetTradeRouteGroupName", "GetTradeRouteGroupIndex",
    "GetFolder", "GetFolderID", "GetFolderGUID", "GetFolderName", "GetFolderIndex",
    "GetCategory", "GetCategoryID", "GetCategoryGUID", "GetCategoryName", "GetCategoryIndex",
    "GetParent", "GetParentID", "GetParentGUID", "GetParentName",
}

local function logRouteObjectMember(routeIndex, routeName, member, value)
    system.log(
        "[Ship Finder SessionTradeRoute Probe 1.1.0]"
        .. " | routeIndex=" .. tostring(routeIndex)
        .. " | routeName=" .. tostring(routeName)
        .. " | member=" .. tostring(member)
        .. " | value=" .. tostring(value)
        .. " | type=" .. tostring(type(value))
    )
end

local function inspectSessionTradeRoute(routeIndex, routeObject)
    if routeObject == nil then
        return
    end

    local routeName = nil
    pcall(function()
        routeName = routeObject.Name
    end)

    local getterFunctions = {}

    for _, member in ipairs(SESSION_ROUTE_MEMBER_CANDIDATES) do
        local ok, value = pcall(function()
            return routeObject[member]
        end)

        if ok and value ~= nil then
            logRouteObjectMember(routeIndex, routeName, member, value)

            if type(value) == "function" and string.sub(member, 1, 3) == "Get" then
                getterFunctions[#getterFunctions + 1] = member
            end
        end
    end

    -- Call only no-argument getter-style methods that actually exist.
    for _, member in ipairs(getterFunctions) do
        local okCall, result = pcall(function()
            return routeObject[member](routeObject)
        end)

        system.log(
            "[Ship Finder SessionTradeRoute Probe 1.1.0]"
            .. " | routeIndex=" .. tostring(routeIndex)
            .. " | routeName=" .. tostring(routeName)
            .. " | call=" .. tostring(member) .. "()"
            .. " | success=" .. tostring(okCall)
            .. " | result=" .. tostring(result)
            .. " | type=" .. tostring(type(result))
        )
    end
end

local function runSessionTradeRouteEnumerationProbe()
    system.log("[Ship Finder SessionTradeRoute Probe 1.1.0] START")

    if type(TradeRoute) ~= "table" or type(TradeRoute.get) ~= "function" then
        system.log(
            "[Ship Finder SessionTradeRoute Probe 1.1.0] ABORT"
            .. " | TradeRoute.get unavailable"
        )
        return
    end

    local manager = nil
    local okManager = pcall(function()
        manager = TradeRoute.get()
    end)

    if not okManager or manager == nil then
        system.log(
            "[Ship Finder SessionTradeRoute Probe 1.1.0] ABORT"
            .. " | manager unavailable"
        )
        return
    end

    local found = 0
    local names = {}

    -- v1.1.21 proved numeric values are accepted by GetRoute.
    -- Probe a broad but bounded range to discover the real route identifier space.
    for routeIndex = 0, 127 do
        local ok, route = pcall(function()
            return manager:GetRoute(routeIndex)
        end)

        if ok and route ~= nil then
            local routeString = tostring(route)

            -- Weak-null userdata stringify includes "null"; skip those.
            if not string.find(routeString, "null", 1, true) then
                found = found + 1

                local name = nil
                pcall(function()
                    name = route.Name
                end)

                names[#names + 1] =
                    tostring(routeIndex) .. "=" .. tostring(name)

                system.log(
                    "[Ship Finder SessionTradeRoute Probe 1.1.0]"
                    .. " | FOUND ROUTE"
                    .. " | routeIndex=" .. tostring(routeIndex)
                    .. " | route=" .. tostring(route)
                    .. " | name=" .. tostring(name)
                )

                inspectSessionTradeRoute(routeIndex, route)

                if found >= 50 then
                    system.log(
                        "[Ship Finder SessionTradeRoute Probe 1.1.0]"
                        .. " | enumeration capped at 50 real routes"
                    )
                    break
                end
            end
        end
    end

    system.log(
        "[Ship Finder SessionTradeRoute Probe 1.1.0] COMPLETE"
        .. " | found=" .. tostring(found)
        .. " | routes=" .. table.concat(names, " || ")
    )
end

local ACTIVE_TRADE_ROUTE_UI_MEMBERS = {
    "SceneData", "Data", "Model", "ViewModel",
    "Routes", "TradeRoutes", "Groups", "RouteGroups", "TradeRouteGroups",
    "GroupList", "RouteList",
    "SelectedGroup", "CurrentGroup", "ActiveGroup",
    "SelectedRoute", "CurrentRoute", "ActiveRoute",
    "GroupName", "GroupID", "GroupGUID", "GroupIndex",
    "RouteGroupName", "RouteGroupID", "RouteGroupGUID", "RouteGroupIndex",
}

local function probeTradeRouteUIWhileOpen()
    system.log("[Ship Finder Active TradeRoute UI Probe 1.1.0] START")

    local scene = nil
    pcall(function()
        if ui and ui.Scenes then
            scene = ui.Scenes.TradeRoute
        end
    end)

    if scene == nil then
        system.log(
            "[Ship Finder Active TradeRoute UI Probe 1.1.0] COMPLETE"
            .. " | scene=false"
        )
        return
    end

    for _, member in ipairs(ACTIVE_TRADE_ROUTE_UI_MEMBERS) do
        local ok, value = pcall(function()
            return scene[member]
        end)

        if ok and value ~= nil then
            system.log(
                "[Ship Finder Active TradeRoute UI Probe 1.1.0]"
                .. " | sceneMember=" .. tostring(member)
                .. " | value=" .. tostring(value)
                .. " | type=" .. tostring(type(value))
            )
        end
    end

    local data = nil
    pcall(function()
        data = scene.SceneData
    end)

    if data ~= nil then
        system.log(
            "[Ship Finder Active TradeRoute UI Probe 1.1.0]"
            .. " | SceneData FOUND"
            .. " | type=" .. tostring(type(data))
        )

        for _, member in ipairs(ACTIVE_TRADE_ROUTE_UI_MEMBERS) do
            local ok, value = pcall(function()
                return data[member]
            end)

            if ok and value ~= nil then
                system.log(
                    "[Ship Finder Active TradeRoute UI Probe 1.1.0]"
                    .. " | dataMember=" .. tostring(member)
                    .. " | value=" .. tostring(value)
                    .. " | type=" .. tostring(type(value))
                )
            end
        end
    end

    system.log("[Ship Finder Active TradeRoute UI Probe 1.1.0] COMPLETE")
end


local function metaLog(label, detail)
    system.log(
        "[Ship Finder Userdata Metatable Probe 1.1.0]"
        .. " | " .. tostring(label)
        .. " | " .. tostring(detail)
    )
end

local function enumerateMetaTable(label, mt)
    if type(mt) ~= "table" then
        metaLog(label, "metatableType=" .. tostring(type(mt)) .. " value=" .. tostring(mt))
        return
    end

    local count = 0
    local okPairs, err = pcall(function()
        for k, v in pairs(mt) do
            count = count + 1
            metaLog(
                label,
                "metaKey=" .. tostring(k)
                .. " value=" .. tostring(v)
                .. " type=" .. tostring(type(v))
            )

            if k == "__index" and type(v) == "table" then
                local indexCount = 0
                for ik, iv in pairs(v) do
                    indexCount = indexCount + 1
                    metaLog(
                        label .. ".__index",
                        "key=" .. tostring(ik)
                        .. " value=" .. tostring(iv)
                        .. " type=" .. tostring(type(iv))
                    )
                    if indexCount >= 250 then
                        break
                    end
                end
                metaLog(label .. ".__index", "entries=" .. tostring(indexCount))
            end

            if count >= 100 then
                break
            end
        end
    end)

    metaLog(
        label,
        "metatableEnumerationSuccess=" .. tostring(okPairs)
        .. " entries=" .. tostring(count)
        .. " error=" .. tostring(err)
    )
end

local function inspectUserdataMetatable(label, object)
    if object == nil then
        metaLog(label, "object=nil")
        return
    end

    metaLog(label, "object=" .. tostring(object) .. " type=" .. tostring(type(object)))

    -- Standard Lua metatable access.
    local okMeta, mt = pcall(function()
        return getmetatable(object)
    end)

    metaLog(
        label,
        "getmetatableSuccess=" .. tostring(okMeta)
        .. " result=" .. tostring(mt)
        .. " type=" .. tostring(type(mt))
    )

    if okMeta and mt ~= nil then
        enumerateMetaTable(label .. ".getmetatable", mt)
    end

    -- Some game userdata protects the standard metatable but debug.getmetatable may expose it.
    local debugMeta = nil
    local okDebugMeta = false

    if debug and type(debug.getmetatable) == "function" then
        okDebugMeta, debugMeta = pcall(function()
            return debug.getmetatable(object)
        end)

        metaLog(
            label,
            "debug.getmetatableSuccess=" .. tostring(okDebugMeta)
            .. " result=" .. tostring(debugMeta)
            .. " type=" .. tostring(type(debugMeta))
        )

        if okDebugMeta and debugMeta ~= nil then
            enumerateMetaTable(label .. ".debugMeta", debugMeta)
        end
    else
        metaLog(label, "debug.getmetatable unavailable")
    end

    -- Test whether userdata implements __pairs directly.
    local pairCount = 0
    local okObjectPairs, pairErr = pcall(function()
        for k, v in pairs(object) do
            pairCount = pairCount + 1
            metaLog(
                label .. ".pairs",
                "key=" .. tostring(k)
                .. " value=" .. tostring(v)
                .. " type=" .. tostring(type(v))
            )
            if pairCount >= 250 then
                break
            end
        end
    end)

    metaLog(
        label,
        "objectPairsSuccess=" .. tostring(okObjectPairs)
        .. " entries=" .. tostring(pairCount)
        .. " error=" .. tostring(pairErr)
    )
end

local function runUserdataMetatableProbe()
    system.log("[Ship Finder Userdata Metatable Probe 1.1.0] START")

    local manager = nil
    pcall(function()
        if TradeRoute and type(TradeRoute.get) == "function" then
            manager = TradeRoute.get()
        end
    end)

    inspectUserdataMetatable("CTradeRouteManager", manager)

    -- Get a proven real route. v1.1.22 showed index 2 is valid in this save.
    local realRoute = nil
    if manager ~= nil then
        pcall(function()
            realRoute = manager:GetRoute(2)
        end)
    end

    if realRoute == nil or string.find(tostring(realRoute), "null", 1, true) then
        -- Fall back to the first non-null route found in a small range.
        if manager ~= nil then
            for i = 0, 127 do
                local ok, route = pcall(function()
                    return manager:GetRoute(i)
                end)
                if ok and route ~= nil
                    and not string.find(tostring(route), "null", 1, true)
                then
                    realRoute = route
                    break
                end
            end
        end
    end

    inspectUserdataMetatable("CSessionTradeRoute", realRoute)

    local tradeRouteScene = nil
    pcall(function()
        if ui and ui.Scenes then
            tradeRouteScene = ui.Scenes.TradeRoute
        end
    end)

    inspectUserdataMetatable("ui.Scenes.TradeRoute", tradeRouteScene)

    if tradeRouteScene ~= nil then
        local sceneData = nil
        pcall(function()
            sceneData = tradeRouteScene.SceneData
        end)

        if sceneData ~= nil then
            inspectUserdataMetatable(
                "ui.Scenes.TradeRoute.SceneData",
                sceneData
            )
        else
            metaLog("ui.Scenes.TradeRoute.SceneData", "nil")
        end
    end

    system.log("[Ship Finder Userdata Metatable Probe 1.1.0] COMPLETE")
end


local EDIT_ROUTE_MEMBER_CANDIDATES = {
    "Name", "ID", "GUID", "Index",
    "RouteName", "RouteID", "RouteGUID", "RouteIndex",

    "Group", "GroupID", "GroupGUID", "GroupName", "GroupIndex",
    "RouteGroup", "RouteGroupID", "RouteGroupGUID", "RouteGroupName", "RouteGroupIndex",
    "TradeRouteGroup", "TradeRouteGroupID", "TradeRouteGroupGUID", "TradeRouteGroupName", "TradeRouteGroupIndex",

    "Folder", "FolderID", "FolderGUID", "FolderName", "FolderIndex",
    "Category", "CategoryID", "CategoryGUID", "CategoryName", "CategoryIndex",
    "Parent", "ParentID", "ParentGUID", "ParentName",

    "ActiveErrorCount",
    "NoShipsActive",
    "AllShipsPausedActive",
    "NoGoodsActive",

    "GetName", "GetID", "GetGUID", "GetIndex",
    "GetGroup", "GetGroupID", "GetGroupGUID", "GetGroupName", "GetGroupIndex",
    "GetRouteGroup", "GetRouteGroupID", "GetRouteGroupGUID", "GetRouteGroupName", "GetRouteGroupIndex",
    "GetTradeRouteGroup", "GetTradeRouteGroupID", "GetTradeRouteGroupGUID", "GetTradeRouteGroupName", "GetTradeRouteGroupIndex",
    "GetFolder", "GetFolderID", "GetFolderGUID", "GetFolderName", "GetFolderIndex",
    "GetCategory", "GetCategoryID", "GetCategoryGUID", "GetCategoryName", "GetCategoryIndex",
    "GetParent", "GetParentID", "GetParentGUID", "GetParentName",

    "GetStation",
    "GetActiveErrorCount",
    "GetNoShipsActive",
    "GetAllShipsPausedActive",
    "GetNoGoodsActive",
}

local function editSurfaceLog(label, member, ok, value)
    system.log(
        "[Ship Finder TradeRoute Editor Surface Probe 1.1.0]"
        .. " | object=" .. tostring(label)
        .. " | member=" .. tostring(member)
        .. " | success=" .. tostring(ok)
        .. " | value=" .. tostring(value)
        .. " | type=" .. tostring(type(value))
    )
end

local function inspectEditRouteObject(label, object)
    if object == nil then
        system.log(
            "[Ship Finder TradeRoute Editor Surface Probe 1.1.0]"
            .. " | object=" .. tostring(label)
            .. " | nil"
        )
        return
    end

    system.log(
        "[Ship Finder TradeRoute Editor Surface Probe 1.1.0]"
        .. " | object=" .. tostring(label)
        .. " | value=" .. tostring(object)
        .. " | type=" .. tostring(type(object))
    )

    for _, member in ipairs(EDIT_ROUTE_MEMBER_CANDIDATES) do
        local ok, value = pcall(function()
            return object[member]
        end)

        if ok and value ~= nil then
            editSurfaceLog(label, member, ok, value)

            if type(value) == "function"
                and string.sub(member, 1, 3) == "Get"
                and member ~= "GetStation"
            then
                local okCall, result = pcall(function()
                    return object[member](object)
                end)

                system.log(
                    "[Ship Finder TradeRoute Editor Surface Probe 1.1.0]"
                    .. " | object=" .. tostring(label)
                    .. " | call=" .. tostring(member) .. "()"
                    .. " | success=" .. tostring(okCall)
                    .. " | result=" .. tostring(result)
                    .. " | type=" .. tostring(type(result))
                )
            end
        end
    end
end

local function runTradeRouteEditorSurfaceProbe()
    system.log("[Ship Finder TradeRoute Editor Surface Probe 1.1.0] START")

    -- A) Existing global wrapper used by Ship Finder.
    local manager = nil
    pcall(function()
        if TradeRoute and type(TradeRoute.get) == "function" then
            manager = TradeRoute.get()
        end
    end)

    if manager ~= nil then
        local managerMembers = {
            "UIEditRoute",
            "GetUIEditRoute",
            "SetShowRouteUI",
            "GetRoute",
        }

        for _, member in ipairs(managerMembers) do
            local ok, value = pcall(function()
                return manager[member]
            end)

            if ok and value ~= nil then
                editSurfaceLog("TradeRoute.get()", member, ok, value)
            end
        end

        local directEdit = nil
        pcall(function()
            directEdit = manager.UIEditRoute
        end)
        inspectEditRouteObject("TradeRoute.get().UIEditRoute", directEdit)

        local getter = nil
        pcall(function()
            getter = manager.GetUIEditRoute
        end)

        if type(getter) == "function" then
            local okCall, result = pcall(function()
                return manager:GetUIEditRoute()
            end)

            system.log(
                "[Ship Finder TradeRoute Editor Surface Probe 1.1.0]"
                .. " | call=TradeRoute.get():GetUIEditRoute()"
                .. " | success=" .. tostring(okCall)
                .. " | result=" .. tostring(result)
                .. " | type=" .. tostring(type(result))
            )

            if okCall and result ~= nil then
                inspectEditRouteObject(
                    "TradeRoute.get():GetUIEditRoute()",
                    result
                )
            end
        end
    end

    -- B) Text-source surface, if this runtime exposes it.
    local tsRoot = nil
    pcall(function()
        tsRoot = ts
    end)

    system.log(
        "[Ship Finder TradeRoute Editor Surface Probe 1.1.0]"
        .. " | tsPresent=" .. tostring(tsRoot ~= nil)
        .. " | tsType=" .. tostring(type(tsRoot))
    )

    if tsRoot ~= nil then
        local tsTradeRoute = nil
        local okTsTradeRoute = pcall(function()
            tsTradeRoute = tsRoot.TradeRoute
        end)

        system.log(
            "[Ship Finder TradeRoute Editor Surface Probe 1.1.0]"
            .. " | ts.TradeRoute lookupSuccess=" .. tostring(okTsTradeRoute)
            .. " | value=" .. tostring(tsTradeRoute)
            .. " | type=" .. tostring(type(tsTradeRoute))
        )

        if tsTradeRoute ~= nil then
            local tsManagerMembers = {
                "UIEditRoute",
                "GetUIEditRoute",
                "SetShowRouteUI",
                "GetRoute",
            }

            for _, member in ipairs(tsManagerMembers) do
                local ok, value = pcall(function()
                    return tsTradeRoute[member]
                end)

                if ok and value ~= nil then
                    editSurfaceLog("ts.TradeRoute", member, ok, value)
                end
            end

            local tsEdit = nil
            pcall(function()
                tsEdit = tsTradeRoute.UIEditRoute
            end)
            inspectEditRouteObject("ts.TradeRoute.UIEditRoute", tsEdit)

            local tsGetter = nil
            pcall(function()
                tsGetter = tsTradeRoute.GetUIEditRoute
            end)

            if type(tsGetter) == "function" then
                local okCall, result = pcall(function()
                    return tsTradeRoute:GetUIEditRoute()
                end)

                system.log(
                    "[Ship Finder TradeRoute Editor Surface Probe 1.1.0]"
                    .. " | call=ts.TradeRoute:GetUIEditRoute()"
                    .. " | success=" .. tostring(okCall)
                    .. " | result=" .. tostring(result)
                    .. " | type=" .. tostring(type(result))
                )

                if okCall and result ~= nil then
                    inspectEditRouteObject(
                        "ts.TradeRoute:GetUIEditRoute()",
                        result
                    )
                end
            end

            -- Probe the same known route through the text-source manager.
            local tsGetRoute = nil
            pcall(function()
                tsGetRoute = tsTradeRoute.GetRoute
            end)

            if type(tsGetRoute) == "function" then
                for _, routeIndex in ipairs({2, 11, 22, 43, 44}) do
                    local okCall, route = pcall(function()
                        return tsTradeRoute:GetRoute(routeIndex)
                    end)

                    system.log(
                        "[Ship Finder TradeRoute Editor Surface Probe 1.1.0]"
                        .. " | call=ts.TradeRoute:GetRoute(" .. tostring(routeIndex) .. ")"
                        .. " | success=" .. tostring(okCall)
                        .. " | result=" .. tostring(route)
                        .. " | type=" .. tostring(type(route))
                    )

                    if okCall and route ~= nil
                        and not string.find(tostring(route), "null", 1, true)
                    then
                        inspectEditRouteObject(
                            "ts.TradeRoute:GetRoute(" .. tostring(routeIndex) .. ")",
                            route
                        )
                    end
                end
            end
        end

        -- C) Direct alternate text-source names, in case groups are separate manager objects.
        local alternateNames = {
            "TradeRouteGroup",
            "TradeRouteGroups",
            "RouteGroup",
            "RouteGroups",
        }

        for _, name in ipairs(alternateNames) do
            local okAlt, value = pcall(function()
                return tsRoot[name]
            end)

            system.log(
                "[Ship Finder TradeRoute Editor Surface Probe 1.1.0]"
                .. " | alternate=" .. tostring(name)
                .. " | success=" .. tostring(okAlt)
                .. " | value=" .. tostring(value)
                .. " | type=" .. tostring(type(value))
            )
        end
    end

    system.log("[Ship Finder TradeRoute Editor Surface Probe 1.1.0] COMPLETE")
end


local routeGroupDiffBaseline = nil
local routeGroupDiffPress = 0

local DIFF_MEMBER_NAMES = {
    -- generic identity
    "Name", "ID", "GUID", "Index", "Count",

    -- route terminology
    "Route", "Routes", "RouteList", "RouteCount",
    "TradeRoute", "TradeRoutes", "TradeRouteList", "TradeRouteCount",
    "SelectedRoute", "CurrentRoute", "ActiveRoute", "UIEditRoute",

    -- group terminology
    "Group", "Groups", "GroupList", "GroupCount",
    "SelectedGroup", "CurrentGroup", "ActiveGroup",
    "RouteGroup", "RouteGroups", "RouteGroupList", "RouteGroupCount",
    "TradeRouteGroup", "TradeRouteGroups", "TradeRouteGroupList", "TradeRouteGroupCount",

    -- alternate terminology
    "Folder", "Folders", "FolderList", "FolderCount",
    "Category", "Categories", "CategoryList", "CategoryCount",
    "Parent", "ParentID", "ParentGUID", "ParentName",

    -- UI/model containers
    "SceneData", "Data", "Model", "ViewModel", "Controller",
    "Manager", "RouteManager", "TradeRouteManager",

    -- route metadata candidates
    "RouteName", "RouteID", "RouteGUID", "RouteIndex",
    "GroupName", "GroupID", "GroupGUID", "GroupIndex",
    "RouteGroupName", "RouteGroupID", "RouteGroupGUID", "RouteGroupIndex",
    "TradeRouteGroupName", "TradeRouteGroupID", "TradeRouteGroupGUID", "TradeRouteGroupIndex",
    "FolderName", "FolderID", "FolderGUID", "FolderIndex",
    "CategoryName", "CategoryID", "CategoryGUID", "CategoryIndex",
}

local function diffString(value)
    if value == nil then
        return "<nil>"
    end
    return tostring(value) .. " [" .. tostring(type(value)) .. "]"
end

local function snapshotMembers(snapshot, prefix, object)
    if object == nil then
        snapshot[prefix .. ".__object"] = "<nil>"
        return
    end

    snapshot[prefix .. ".__object"] = diffString(object)

    for _, member in ipairs(DIFF_MEMBER_NAMES) do
        local ok, value = pcall(function()
            return object[member]
        end)
        if ok then
            snapshot[prefix .. "." .. member] = diffString(value)
        else
            snapshot[prefix .. "." .. member] = "<error>"
        end
    end
end

local function snapshotGlobalRouteGroupTables(snapshot)
    -- Enumerate _G safely and record every global whose key suggests route/group/folder UI.
    local ok = pcall(function()
        for k, v in pairs(_G) do
            local key = tostring(k)
            local lower = string.lower(key)

            if string.find(lower, "route", 1, true)
                or string.find(lower, "group", 1, true)
                or string.find(lower, "folder", 1, true)
            then
                snapshot["globalKey." .. key] = diffString(v)

                -- If it is a normal Lua table, record its direct keys.
                if type(v) == "table" then
                    local count = 0
                    pcall(function()
                        for sk, sv in pairs(v) do
                            count = count + 1
                            snapshot[
                                "globalTable." .. key .. "." .. tostring(sk)
                            ] = diffString(sv)
                            if count >= 100 then
                                break
                            end
                        end
                    end)
                end
            end
        end
    end)

    snapshot["globalEnumeration.success"] = tostring(ok)
end

local function snapshotTradeRoutes(snapshot)
    local manager = nil
    pcall(function()
        if TradeRoute and type(TradeRoute.get) == "function" then
            manager = TradeRoute.get()
        end
    end)

    snapshotMembers(snapshot, "manager", manager)

    if manager == nil then
        return
    end

    -- The selected/edited route is especially important for a move-between-groups test.
    local editRoute = nil
    pcall(function()
        editRoute = manager.UIEditRoute
    end)
    snapshotMembers(snapshot, "manager.UIEditRoute", editRoute)

    -- Enumerate route index/name pairs. Group moves might alter ordering/index identity
    -- even if route names do not change.
    local realCount = 0
    for i = 0, 255 do
        local ok, route = pcall(function()
            return manager:GetRoute(i)
        end)

        if ok and route ~= nil
            and not string.find(tostring(route), "null", 1, true)
        then
            realCount = realCount + 1
            local name = nil
            pcall(function()
                name = route.Name
            end)

            snapshot["route." .. tostring(i) .. ".object"] = diffString(route)
            snapshot["route." .. tostring(i) .. ".name"] = diffString(name)

            -- Snapshot all guessed metadata on a few relevant route objects as well.
            if realCount <= 80 then
                snapshotMembers(snapshot, "route." .. tostring(i), route)
            end
        end
    end
    snapshot["route.realCount"] = tostring(realCount)
end

local function snapshotTradeRouteUI(snapshot)
    local scene = nil
    pcall(function()
        if ui and ui.Scenes then
            scene = ui.Scenes.TradeRoute
        end
    end)

    snapshotMembers(snapshot, "ui.Scenes.TradeRoute", scene)

    if scene ~= nil then
        local data = nil
        pcall(function()
            data = scene.SceneData
        end)
        snapshotMembers(snapshot, "ui.Scenes.TradeRoute.SceneData", data)
    end

    -- ui.Scenes itself may be a Lua table in some contexts. If so, enumerate names
    -- containing route/group/folder and record their values.
    pcall(function()
        if ui and type(ui.Scenes) == "table" then
            for k, v in pairs(ui.Scenes) do
                local key = tostring(k)
                local lower = string.lower(key)
                if string.find(lower, "route", 1, true)
                    or string.find(lower, "group", 1, true)
                    or string.find(lower, "folder", 1, true)
                then
                    snapshot["uiSceneKey." .. key] = diffString(v)
                end
            end
        end
    end)
end

local function buildRouteGroupDiffSnapshot()
    local snapshot = {}
    snapshotGlobalRouteGroupTables(snapshot)
    snapshotTradeRoutes(snapshot)
    snapshotTradeRouteUI(snapshot)
    return snapshot
end

local function logSnapshotSummary(snapshot)
    local count = 0
    for _ in pairs(snapshot) do
        count = count + 1
    end

    system.log(
        "[Ship Finder Route Group Differential Probe 1.1.0]"
        .. " | snapshotEntries=" .. tostring(count)
        .. " | realRoutes=" .. tostring(snapshot["route.realCount"])
        .. " | uiEditRoute=" .. tostring(snapshot["manager.UIEditRoute.Name"])
    )
end

local function compareRouteGroupSnapshots(before, after)
    local changes = {}
    local seen = {}

    for k, oldValue in pairs(before) do
        seen[k] = true
        local newValue = after[k]
        if oldValue ~= newValue then
            changes[#changes + 1] = {
                key = k,
                before = oldValue,
                after = newValue or "<missing>",
            }
        end
    end

    for k, newValue in pairs(after) do
        if not seen[k] then
            changes[#changes + 1] = {
                key = k,
                before = "<missing>",
                after = newValue,
            }
        end
    end

    table.sort(changes, function(a, b)
        return tostring(a.key) < tostring(b.key)
    end)

    system.log(
        "[Ship Finder Route Group Differential Probe 1.1.0]"
        .. " | DIFF START"
        .. " | changeCount=" .. tostring(#changes)
    )

    for i, change in ipairs(changes) do
        system.log(
            "[Ship Finder Route Group Differential Probe 1.1.0]"
            .. " | CHANGE #" .. tostring(i)
            .. " | key=" .. tostring(change.key)
            .. " | BEFORE=" .. tostring(change.before)
            .. " | AFTER=" .. tostring(change.after)
        )
    end

    system.log(
        "[Ship Finder Route Group Differential Probe 1.1.0]"
        .. " | DIFF COMPLETE"
        .. " | changeCount=" .. tostring(#changes)
    )
end

local function runRouteGroupDifferentialProbe()
    routeGroupDiffPress = routeGroupDiffPress + 1

    system.log(
        "[Ship Finder Route Group Differential Probe 1.1.0]"
        .. " | PRESS=" .. tostring(routeGroupDiffPress)
    )

    local current = buildRouteGroupDiffSnapshot()
    logSnapshotSummary(current)

    if routeGroupDiffBaseline == nil then
        routeGroupDiffBaseline = current
        system.log(
            "[Ship Finder Route Group Differential Probe 1.1.0]"
            .. " | BASELINE STORED"
            .. " | now create/rename a route group or move a route, then press Ctrl+Alt+F again"
        )
    else
        compareRouteGroupSnapshots(routeGroupDiffBaseline, current)
        routeGroupDiffBaseline = current
        system.log(
            "[Ship Finder Route Group Differential Probe 1.1.0]"
            .. " | NEW BASELINE STORED"
            .. " | you can mutate again and press Ctrl+Alt+F for another differential"
        )
    end
end


local routePositionBaseline = nil
local routePositionPress = 0

local function buildRoutePositionSnapshot()
    local result = {
        byIndex = {},
        byName = {},
        realCount = 0,
    }

    local manager = nil
    pcall(function()
        if TradeRoute and type(TradeRoute.get) == "function" then
            manager = TradeRoute.get()
        end
    end)

    if manager == nil then
        return result
    end

    for i = 0, 511 do
        local ok, route = pcall(function()
            return manager:GetRoute(i)
        end)

        if ok and route ~= nil
            and not string.find(tostring(route), "null", 1, true)
        then
            local name = nil
            pcall(function()
                name = route.Name
            end)

            if name ~= nil then
                result.realCount = result.realCount + 1

                local objectText = tostring(route)
                result.byIndex[i] = {
                    name = tostring(name),
                    object = objectText,
                }

                local nameKey = tostring(name)
                if result.byName[nameKey] == nil then
                    result.byName[nameKey] = {}
                end

                result.byName[nameKey][#result.byName[nameKey] + 1] = {
                    index = i,
                    object = objectText,
                }
            end
        end
    end

    return result
end

local function positionsToString(list)
    if list == nil then
        return "<none>"
    end

    local parts = {}
    for _, item in ipairs(list) do
        parts[#parts + 1] =
            tostring(item.index) .. "@" .. tostring(item.object)
    end
    return table.concat(parts, ",")
end

local function compareRoutePositions(before, after)
    local names = {}
    local seen = {}

    for name in pairs(before.byName) do
        seen[name] = true
        names[#names + 1] = name
    end
    for name in pairs(after.byName) do
        if not seen[name] then
            names[#names + 1] = name
        end
    end

    table.sort(names)

    local changedNames = 0

    system.log(
        "[Ship Finder Route Position Differential 1.1.0]"
        .. " | COMPARE START"
        .. " | beforeRoutes=" .. tostring(before.realCount)
        .. " | afterRoutes=" .. tostring(after.realCount)
    )

    for _, name in ipairs(names) do
        local oldPos = positionsToString(before.byName[name])
        local newPos = positionsToString(after.byName[name])

        if oldPos ~= newPos then
            changedNames = changedNames + 1
            system.log(
                "[Ship Finder Route Position Differential 1.1.0]"
                .. " | ROUTE CHANGED"
                .. " | name=" .. tostring(name)
                .. " | BEFORE=" .. tostring(oldPos)
                .. " | AFTER=" .. tostring(newPos)
            )
        end
    end

    -- Also log changed numeric slots, because a group move may reorder a contiguous block.
    local maxIndex = 511
    local changedSlots = 0

    for i = 0, maxIndex do
        local old = before.byIndex[i]
        local new = after.byIndex[i]

        local oldText = old and (old.name .. "@" .. old.object) or "<empty>"
        local newText = new and (new.name .. "@" .. new.object) or "<empty>"

        if oldText ~= newText then
            changedSlots = changedSlots + 1
            system.log(
                "[Ship Finder Route Position Differential 1.1.0]"
                .. " | SLOT CHANGED"
                .. " | index=" .. tostring(i)
                .. " | BEFORE=" .. tostring(oldText)
                .. " | AFTER=" .. tostring(newText)
            )
        end
    end

    system.log(
        "[Ship Finder Route Position Differential 1.1.0]"
        .. " | COMPARE COMPLETE"
        .. " | changedNames=" .. tostring(changedNames)
        .. " | changedSlots=" .. tostring(changedSlots)
    )
end

local function runRoutePositionDifferential()
    routePositionPress = routePositionPress + 1

    local current = buildRoutePositionSnapshot()

    system.log(
        "[Ship Finder Route Position Differential 1.1.0]"
        .. " | PRESS=" .. tostring(routePositionPress)
        .. " | realRoutes=" .. tostring(current.realCount)
    )

    if routePositionBaseline == nil then
        routePositionBaseline = current

        system.log(
            "[Ship Finder Route Position Differential 1.1.0]"
            .. " | BASELINE STORED"
            .. " | now MOVE EXACTLY ONE EXISTING ROUTE to another group"
            .. " | do not create/rename/delete anything"
            .. " | then press Ctrl+Alt+F again"
        )
    else
        compareRoutePositions(routePositionBaseline, current)
        routePositionBaseline = current

        system.log(
            "[Ship Finder Route Position Differential 1.1.0]"
            .. " | NEW BASELINE STORED"
            .. " | move the same route back and press again for confirmation"
        )
    end
end


local NATIVE_INTROSPECTION_PREFIX = "[Ship Finder Native Introspection Probe 1.1.0]"
local nativeInspectNodeCount = 0
local nativeInspectEntryCount = 0
local nativeInspectSeen = {}

local function niLog(text)
    system.log(NATIVE_INTROSPECTION_PREFIX .. " | " .. tostring(text))
end

local function niSafeToString(value)
    local ok, result = pcall(function()
        return tostring(value)
    end)
    if ok then
        return result
    end
    return "<tostring error: " .. tostring(result) .. ">"
end

local function niIsNullLike(value)
    if value == nil then
        return true
    end
    local text = niSafeToString(value)
    return string.find(text, "weak null", 1, true) ~= nil
        or string.find(text, " null", 1, true) ~= nil
end

local function niIdentity(value)
    return tostring(type(value)) .. "|" .. niSafeToString(value)
end

local function niLogCall(label, fn)
    local ok, result = pcall(fn)
    niLog(
        tostring(label)
        .. " | success=" .. tostring(ok)
        .. " | type=" .. tostring(type(result))
        .. " | result=" .. niSafeToString(result)
    )
    return ok, result
end

local function niGetInspectInfo(label, object)
    if type(inspect) ~= "function" then
        niLog(label .. " | inspect unavailable")
        return nil
    end

    local ok, info = pcall(function()
        return inspect(object)
    end)

    niLog(
        label
        .. " | inspectSuccess=" .. tostring(ok)
        .. " | infoType=" .. tostring(type(info))
        .. " | info=" .. niSafeToString(info)
    )

    if ok and type(info) == "table" then
        local fq = info.fullQualifiedName
        local isClass = info.isClass
        niLog(
            label
            .. " | CLASS"
            .. " | fullQualifiedName=" .. tostring(fq)
            .. " | isClass=" .. tostring(isClass)
        )

        local funcs = info[":functions:"]
        if type(funcs) == "table" then
            local names = {}
            for name, desc in pairs(funcs) do
                names[#names + 1] = tostring(name)
            end
            table.sort(names)
            for _, name in ipairs(names) do
                local desc = funcs[name]
                niLog(
                    label
                    .. " | FUNCTION"
                    .. " | name=" .. tostring(name)
                    .. " | desc=" .. niSafeToString(desc)
                )
            end
        end

        local props = info[":properties:"]
        if type(props) == "table" then
            local names = {}
            for name, desc in pairs(props) do
                names[#names + 1] = tostring(name)
            end
            table.sort(names)
            for _, name in ipairs(names) do
                local desc = props[name]
                niLog(
                    label
                    .. " | PROPERTY DEF"
                    .. " | name=" .. tostring(name)
                    .. " | desc=" .. niSafeToString(desc)
                )
            end
        end
        return info
    end

    return nil
end

local function niLogBuiltInHelpers(label, object)
    if type(help) == "function" then
        niLogCall(label .. " | help()", function()
            return help(object)
        end)
    else
        niLog(label .. " | help unavailable")
    end

    if type(getTypeInfo) == "function" then
        niLogCall(label .. " | getTypeInfo()", function()
            return getTypeInfo(object)
        end)
    else
        niLog(label .. " | getTypeInfo unavailable")
    end

    if type(dir) == "function" then
        niLogCall(label .. " | dir()", function()
            return dir(object)
        end)
    else
        niLog(label .. " | dir unavailable")
    end
end

local function niTargetCheck(path, value)
    if type(value) ~= "string" then
        return
    end

    -- These are diagnostic-only strings from the currently visible test case.
    -- They are NOT used by Ship Finder classification/navigation.
    if string.find(value, "Villa Augusta", 1, true)
        or string.find(value, "Soap Myt - Vil", 1, true)
    then
        niLog(
            "TARGET STRING HIT"
            .. " | path=" .. tostring(path)
            .. " | value=" .. tostring(value)
        )
    end
end

local niWalk

local function niWalkTable(path, object, depth)
    local count = 0
    local ok, err = pcall(function()
        for k, v in pairs(object) do
            count = count + 1
            nativeInspectEntryCount = nativeInspectEntryCount + 1

            local childPath = tostring(path) .. "[" .. tostring(k) .. "]"
            niLog(
                "TABLE ENTRY"
                .. " | path=" .. childPath
                .. " | type=" .. tostring(type(v))
                .. " | value=" .. niSafeToString(v)
            )
            niTargetCheck(childPath, v)

            if nativeInspectEntryCount >= 1500 then
                break
            end

            if depth < 5 and (type(v) == "table" or type(v) == "userdata") then
                niWalk(childPath, v, depth + 1)
            end
        end
    end)

    niLog(
        "TABLE ENUM"
        .. " | path=" .. tostring(path)
        .. " | success=" .. tostring(ok)
        .. " | count=" .. tostring(count)
        .. " | error=" .. tostring(err)
    )
end

local function niWalkUserdata(path, object, depth)
    local info = niGetInspectInfo(path, object)

    if info then
        local props = info[":properties:"]
        if type(props) == "table" then
            local names = {}
            for name in pairs(props) do
                names[#names + 1] = tostring(name)
            end
            table.sort(names)

            for _, propName in ipairs(names) do
                local ok, value = pcall(function()
                    return object[propName]
                end)

                niLog(
                    "PROPERTY VALUE"
                    .. " | path=" .. tostring(path) .. "." .. tostring(propName)
                    .. " | success=" .. tostring(ok)
                    .. " | type=" .. tostring(type(value))
                    .. " | value=" .. niSafeToString(value)
                )

                if ok then
                    niTargetCheck(
                        tostring(path) .. "." .. tostring(propName),
                        value
                    )

                    if depth < 5
                        and not niIsNullLike(value)
                        and (type(value) == "table" or type(value) == "userdata")
                    then
                        niWalk(
                            tostring(path) .. "." .. tostring(propName),
                            value,
                            depth + 1
                        )
                    end
                end

                nativeInspectEntryCount = nativeInspectEntryCount + 1
                if nativeInspectEntryCount >= 1500 then
                    break
                end
            end
        end
    end

    -- LuaBridge userdata may support __pairs even where a normal table does not.
    local pairCount = 0
    local okPairs, pairErr = pcall(function()
        for k, v in pairs(object) do
            pairCount = pairCount + 1
            nativeInspectEntryCount = nativeInspectEntryCount + 1

            local childPath = tostring(path) .. "[pairs:" .. tostring(k) .. "]"
            niLog(
                "USERDATA PAIR"
                .. " | path=" .. childPath
                .. " | type=" .. tostring(type(v))
                .. " | value=" .. niSafeToString(v)
            )
            niTargetCheck(childPath, v)

            if depth < 5
                and not niIsNullLike(v)
                and (type(v) == "table" or type(v) == "userdata")
            then
                niWalk(childPath, v, depth + 1)
            end

            if pairCount >= 100 or nativeInspectEntryCount >= 1500 then
                break
            end
        end
    end)

    niLog(
        "USERDATA PAIRS"
        .. " | path=" .. tostring(path)
        .. " | success=" .. tostring(okPairs)
        .. " | count=" .. tostring(pairCount)
        .. " | error=" .. tostring(pairErr)
    )
end

niWalk = function(path, object, depth)
    if object == nil then
        niLog("WALK NIL | path=" .. tostring(path))
        return
    end

    if nativeInspectNodeCount >= 350 or nativeInspectEntryCount >= 1500 then
        return
    end

    local t = type(object)
    if t ~= "table" and t ~= "userdata" then
        niTargetCheck(path, object)
        return
    end

    local identity = niIdentity(object)
    if nativeInspectSeen[identity] then
        niLog(
            "CYCLE/SAME OBJECT"
            .. " | path=" .. tostring(path)
            .. " | identity=" .. tostring(identity)
        )
        return
    end
    nativeInspectSeen[identity] = true

    nativeInspectNodeCount = nativeInspectNodeCount + 1
    niLog(
        "WALK"
        .. " | path=" .. tostring(path)
        .. " | depth=" .. tostring(depth)
        .. " | node=" .. tostring(nativeInspectNodeCount)
        .. " | type=" .. tostring(t)
        .. " | value=" .. niSafeToString(object)
    )

    if t == "table" then
        niWalkTable(path, object, depth)
    else
        niWalkUserdata(path, object, depth)
    end
end

local function niEnumerateNamespace(namespaceName, namespace)
    niLog(
        "NAMESPACE"
        .. " | name=" .. tostring(namespaceName)
        .. " | present=" .. tostring(namespace ~= nil)
        .. " | type=" .. tostring(type(namespace))
    )

    if type(namespace) ~= "table" then
        return
    end

    local matches = {}
    local ok, err = pcall(function()
        for k, v in pairs(namespace) do
            local key = tostring(k)
            local lower = string.lower(key)

            if string.find(lower, "trade", 1, true)
                or string.find(lower, "route", 1, true)
                or string.find(lower, "group", 1, true)
                or string.find(lower, "folder", 1, true)
                or string.find(lower, "scene", 1, true)
                or string.find(lower, "tree", 1, true)
                or string.find(lower, "list", 1, true)
            then
                matches[#matches + 1] = {
                    key = key,
                    value = v,
                }
            end
        end
    end)

    table.sort(matches, function(a, b)
        return a.key < b.key
    end)

    niLog(
        "NAMESPACE ENUM"
        .. " | name=" .. tostring(namespaceName)
        .. " | success=" .. tostring(ok)
        .. " | matches=" .. tostring(#matches)
        .. " | error=" .. tostring(err)
    )

    for _, item in ipairs(matches) do
        niLog(
            "NAMESPACE MATCH"
            .. " | namespace=" .. tostring(namespaceName)
            .. " | key=" .. tostring(item.key)
            .. " | type=" .. tostring(type(item.value))
            .. " | value=" .. niSafeToString(item.value)
        )
    end
end

local function runNativeTradeRouteIntrospectionProbe()
    nativeInspectNodeCount = 0
    nativeInspectEntryCount = 0
    nativeInspectSeen = {}

    niLog("START")
    niLog(
        "HELPERS"
        .. " | inspect=" .. tostring(type(inspect))
        .. " | getTypeInfo=" .. tostring(type(getTypeInfo))
        .. " | help=" .. tostring(type(help))
        .. " | dir=" .. tostring(type(dir))
        .. " | rdgs.IntrospectionHelper="
            .. tostring(rdgs and type(rdgs.IntrospectionHelper) or "nil")
    )

    -- 1) Exact runtime type of the TradeRoute manager.
    local manager = nil
    local okManager, managerResult = pcall(function()
        return TradeRoute.get()
    end)
    if okManager then
        manager = managerResult
    end

    niLog(
        "MANAGER"
        .. " | success=" .. tostring(okManager)
        .. " | type=" .. tostring(type(manager))
        .. " | value=" .. niSafeToString(manager)
    )

    if manager ~= nil then
        niLogBuiltInHelpers("TradeRoute.get()", manager)
        niWalk("TradeRoute.get()", manager, 0)

        -- Check the exact members documented in the scripts.rda dump too.
        for _, member in ipairs({
            "TradeRoutesWithIssues",
            "UIEditRoute",
            "GetRoute",
            "ShowRouteUI",
            "isValid",
        }) do
            local ok, value = pcall(function()
                return manager[member]
            end)
            niLog(
                "EXACT MANAGER MEMBER"
                .. " | member=" .. tostring(member)
                .. " | success=" .. tostring(ok)
                .. " | type=" .. tostring(type(value))
                .. " | value=" .. niSafeToString(value)
            )
        end
    end

    -- 2) One real route, selected generically rather than by a hard-coded ID.
    local realRoute = nil
    local realRouteIndex = nil
    if manager ~= nil then
        for i = 0, 511 do
            local ok, route = pcall(function()
                return manager:GetRoute(i)
            end)

            if ok and not niIsNullLike(route) then
                realRoute = route
                realRouteIndex = i
                break
            end
        end
    end

    niLog(
        "REAL ROUTE"
        .. " | index=" .. tostring(realRouteIndex)
        .. " | type=" .. tostring(type(realRoute))
        .. " | value=" .. niSafeToString(realRoute)
    )

    if realRoute ~= nil then
        niLogBuiltInHelpers(
            "CSessionTradeRoute[" .. tostring(realRouteIndex) .. "]",
            realRoute
        )
        niWalk(
            "CSessionTradeRoute[" .. tostring(realRouteIndex) .. "]",
            realRoute,
            0
        )
    end

    -- 3) The actual live native Trade Route UI scene and its discoverable descendants.
    local scenes = nil
    local tradeScene = nil
    pcall(function()
        scenes = ui and ui.Scenes or nil
        tradeScene = scenes and scenes.TradeRoute or nil
    end)

    niLog(
        "UI SCENES"
        .. " | type=" .. tostring(type(scenes))
        .. " | value=" .. niSafeToString(scenes)
    )
    if scenes ~= nil then
        niLogBuiltInHelpers("ui.Scenes", scenes)
        niGetInspectInfo("ui.Scenes", scenes)

        -- Do not recursively walk every scene; enumerate only scene keys with relevant names.
        local okScenePairs, scenePairErr = pcall(function()
            local count = 0
            for k, v in pairs(scenes) do
                local key = tostring(k)
                local lower = string.lower(key)
                if string.find(lower, "trade", 1, true)
                    or string.find(lower, "route", 1, true)
                    or string.find(lower, "group", 1, true)
                then
                    count = count + 1
                    niLog(
                        "SCENE MATCH"
                        .. " | key=" .. tostring(key)
                        .. " | type=" .. tostring(type(v))
                        .. " | value=" .. niSafeToString(v)
                    )
                end
                if count >= 100 then
                    break
                end
            end
        end)
        niLog(
            "SCENE ENUM"
            .. " | success=" .. tostring(okScenePairs)
            .. " | error=" .. tostring(scenePairErr)
        )
    end

    niLog(
        "TRADE ROUTE SCENE"
        .. " | type=" .. tostring(type(tradeScene))
        .. " | value=" .. niSafeToString(tradeScene)
    )
    if tradeScene ~= nil then
        niLogBuiltInHelpers("ui.Scenes.TradeRoute", tradeScene)
        niWalk("ui.Scenes.TradeRoute", tradeScene, 0)
    end

    -- 4) Search actual runtime namespaces for class names we may never have guessed.
    niEnumerateNamespace("rdgs", rdgs)
    niEnumerateNamespace("rdui", _G and _G["rdui"] or nil)

    -- 5) Inspect the IntrospectionHelper itself when exposed.
    if rdgs and rdgs.IntrospectionHelper ~= nil then
        niLogBuiltInHelpers(
            "rdgs.IntrospectionHelper",
            rdgs.IntrospectionHelper
        )
        niGetInspectInfo(
            "rdgs.IntrospectionHelper",
            rdgs.IntrospectionHelper
        )
    end

    -- 6) Old-engine compatibility avenue: inspect lowercase game and current Game manager.
    local lowerGame = _G and _G["game"] or nil
    niLog(
        "LOWERCASE game"
        .. " | present=" .. tostring(lowerGame ~= nil)
        .. " | type=" .. tostring(type(lowerGame))
        .. " | value=" .. niSafeToString(lowerGame)
    )
    if lowerGame ~= nil then
        niLogBuiltInHelpers("game", lowerGame)
        niGetInspectInfo("game", lowerGame)
        local okGUI, guiMember = pcall(function()
            return lowerGame.GUIManager
        end)
        niLog(
            "game.GUIManager"
            .. " | lookupSuccess=" .. tostring(okGUI)
            .. " | type=" .. tostring(type(guiMember))
            .. " | value=" .. niSafeToString(guiMember)
        )
        if okGUI and type(guiMember) == "function" then
            local okCall, gui = pcall(function()
                return lowerGame:GUIManager()
            end)
            niLog(
                "game:GUIManager()"
                .. " | success=" .. tostring(okCall)
                .. " | type=" .. tostring(type(gui))
                .. " | value=" .. niSafeToString(gui)
            )
            if okCall and gui ~= nil then
                niLogBuiltInHelpers("game:GUIManager()", gui)
                niWalk("game:GUIManager()", gui, 0)
            end
        end
    end

    if Game ~= nil then
        niLogBuiltInHelpers("Game", Game)
        niGetInspectInfo("Game", Game)
    end

    niLog(
        "COMPLETE"
        .. " | nodes=" .. tostring(nativeInspectNodeCount)
        .. " | entries=" .. tostring(nativeInspectEntryCount)
    )
end


local PATCH_AWARE_PREFIX = "[Ship Finder Patch-Aware Group Probe 1.1.0]"

local function paLog(text)
    system.log(PATCH_AWARE_PREFIX .. " | " .. tostring(text))
end

local function paText(v)
    local ok, r = pcall(function() return tostring(v) end)
    return ok and r or "<tostring error>"
end

local function paInteresting(name)
    local s = string.lower(tostring(name))
    local words = {"group","folder","parent","tree","list","entry","item","rename","move","assign","context","menu","route"}
    for _, w in ipairs(words) do
        if string.find(s, w, 1, true) then return true end
    end
    return false
end

local function paInspect(label, object)
    if object == nil then paLog(label .. " | nil"); return nil end
    local fq, def = nil, nil
    if rdgs and rdgs.IntrospectionHelper then
        local okFQ, v = pcall(function() return rdgs.IntrospectionHelper.getFQClassName(object) end)
        paLog(label .. " | FQ success=" .. tostring(okFQ) .. " | value=" .. paText(v))
        if okFQ then fq = v end
        if fq ~= nil then
            local okDef, d = pcall(function() return rdgs.IntrospectionHelper.getClassDefinition(fq) end)
            paLog(label .. " | DEF success=" .. tostring(okDef) .. " | type=" .. tostring(type(d)) .. " | value=" .. paText(d))
            if okDef then def = d end
        end
    else
        paLog(label .. " | IntrospectionHelper unavailable")
    end
    if type(def) == "table" then
        for section, values in pairs(def) do
            if paInteresting(section) then
                paLog(label .. " | INTERESTING DEF | section=" .. tostring(section) .. " | value=" .. paText(values))
            end
            if type(values) == "table" then
                for key, value in pairs(values) do
                    if paInteresting(key) then
                        paLog(label .. " | INTERESTING MEMBER DEF | section=" .. tostring(section) .. " | key=" .. tostring(key) .. " | value=" .. paText(value))
                    end
                end
            end
        end
    end
    return def
end

local function paExact(label, object)
    if object == nil then return end
    local names = {
        "Groups","GroupList","GroupEntries","GroupItems","SelectedGroup","CurrentGroup","ActiveGroup",
        "RouteGroups","RouteGroupList","RouteGroupEntries","TradeRouteGroups","TradeRouteGroupList","TradeRouteGroupEntries",
        "Folders","FolderList","FolderEntries","Tree","TreeData","TreeModel","TreeItems",
        "List","ListData","ListModel","ListItems","Entries","Items","Children","Rows",
        "SelectedRoute","CurrentRoute","ActiveRoute","SelectedItem","CurrentItem","SelectedEntry","UIEditRoute",
        "ContextMenu","ContextMenuData","Menu","MenuData",
        "Rename","RenameGroup","RenameRouteGroup","RenameTradeRouteGroup",
        "Move","MoveRoute","MoveToGroup","MoveRouteToGroup",
        "CreateGroup","AddGroup","DeleteGroup","AssignGroup","AssignToGroup","SetGroup",
        "SceneData","Data","Model","ViewModel","Controller","Manager","RouteManager","TradeRouteManager"
    }
    for _, n in ipairs(names) do
        local ok, v = pcall(function() return object[n] end)
        if ok and v ~= nil then paLog(label .. " | EXACT MEMBER | " .. n .. " | type=" .. tostring(type(v)) .. " | value=" .. paText(v)) end
    end
end

local paSeen = {}
local paNodes = 0
local paEntries = 0
local function paWalk(label, object, depth)
    if object == nil or depth > 5 or paNodes >= 300 or paEntries >= 1800 then return end
    local t = type(object)
    if t ~= "table" and t ~= "userdata" then return end
    local ident = t .. "|" .. paText(object)
    if paSeen[ident] then return end
    paSeen[ident] = true; paNodes = paNodes + 1
    paLog("WALK | path=" .. label .. " | depth=" .. tostring(depth) .. " | type=" .. t .. " | value=" .. paText(object))
    paInspect(label, object); paExact(label, object)
    local info = nil
    if type(inspect) == "function" then
        local ok, v = pcall(function() return inspect(object) end)
        if ok and type(v) == "table" then info = v end
    end
    if info and type(info[":properties:"]) == "table" then
        local props={}; for p in pairs(info[":properties:"]) do props[#props+1]=tostring(p) end; table.sort(props)
        for _, p in ipairs(props) do
            local ok, v = pcall(function() return object[p] end); paEntries=paEntries+1
            if ok and v ~= nil then
                if paInteresting(p) then paLog(label .. " | ACTUAL PROPERTY | " .. p .. " | type=" .. tostring(type(v)) .. " | value=" .. paText(v)) end
                if type(v)=="string" and (string.find(v,"Villa Augusta",1,true) or string.find(v,"Soap Myt - Vil",1,true)) then
                    paLog("TARGET STRING HIT | path=" .. label .. "." .. p .. " | value=" .. v)
                end
                if type(v)=="table" or type(v)=="userdata" then paWalk(label .. "." .. p, v, depth+1) end
            end
        end
    end
    if t=="table" then
        pcall(function()
            local c=0
            for k,v in pairs(object) do c=c+1; paEntries=paEntries+1
                if paInteresting(k) then paLog(label .. " | TABLE ENTRY | " .. tostring(k) .. " | type=" .. tostring(type(v)) .. " | value=" .. paText(v)) end
                if type(v)=="string" and (string.find(v,"Villa Augusta",1,true) or string.find(v,"Soap Myt - Vil",1,true)) then paLog("TARGET STRING HIT | path=" .. label .. "["..tostring(k).."] | value="..v) end
                if depth<5 and (type(v)=="table" or type(v)=="userdata") then paWalk(label.."["..tostring(k).."]",v,depth+1) end
                if c>=300 or paEntries>=1800 then break end
            end
        end)
    end
end

local function runPatchAwareTradeRouteGroupProbe()
    paSeen={}; paNodes=0; paEntries=0
    paLog("START | groups predate Patch 1.5; focus=separate UI/model hierarchy and patch-era group workflow")
    local manager=nil; local okM=pcall(function() manager=TradeRoute and TradeRoute.get and TradeRoute.get() or nil end)
    paLog("MANAGER | success="..tostring(okM).." | type="..tostring(type(manager)).." | value="..paText(manager))
    if manager then
        paInspect("TradeRoute.get()",manager); paExact("TradeRoute.get()",manager)
        for _,n in ipairs({"TradeRoutesWithIssues","UIEditRoute","GetRoute","ShowRouteUI","isValid"}) do
            local ok,v=pcall(function() return manager[n] end)
            paLog("KNOWN MANAGER MEMBER | "..n.." | success="..tostring(ok).." | type="..tostring(type(v)).." | value="..paText(v))
        end
    end
    local scenes,scene=nil,nil
    pcall(function() scenes=ui and ui.Scenes or nil; scene=scenes and scenes.TradeRoute or nil end)
    paLog("TRADE ROUTE SCENE | type="..tostring(type(scene)).." | value="..paText(scene))
    if scene then paWalk("ui.Scenes.TradeRoute",scene,0) end
    if scenes then
        pcall(function()
            for k,v in pairs(scenes) do if paInteresting(k) then paLog("SCENE KEY | "..tostring(k).." | type="..tostring(type(v)).." | value="..paText(v)) end end
        end)
    end
    if type(rdgs)=="table" then
        local names={}; pcall(function() for k in pairs(rdgs) do if paInteresting(k) then names[#names+1]=tostring(k) end end end); table.sort(names)
        for _,k in ipairs(names) do local v=rdgs[k]; paLog("RDGS MATCH | "..k.." | type="..tostring(type(v)).." | value="..paText(v)) end
        paLog("RDGS MATCH COUNT="..tostring(#names))
    end
    paLog("COMPLETE | nodes="..tostring(paNodes).." | entries="..tostring(paEntries))
end


local PHOENIX_PREFIX = "[Ship Finder Trade Route Group Array Probe 1.1.0]"

local function phLog(text)
    system.log(PHOENIX_PREFIX .. " | " .. tostring(text))
end

local function phString(value)
    local ok, text = pcall(function()
        return tostring(value)
    end)
    if ok then
        return text
    end
    return "<tostring error>"
end

local function phNull(value)
    if value == nil then
        return true
    end
    local s = phString(value)
    return string.find(s, "weak null", 1, true) ~= nil
        or string.find(s, " null", 1, true) ~= nil
end

local function phInspectObject(label, object)
    if object == nil or phNull(object) then
        phLog(label .. " | object=null")
        return
    end

    phLog(
        label
        .. " | OBJECT"
        .. " | type=" .. tostring(type(object))
        .. " | value=" .. phString(object)
    )

    if type(help) == "function" then
        local ok, result = pcall(function()
            return help(object)
        end)
        phLog(
            label
            .. " | help"
            .. " | success=" .. tostring(ok)
            .. " | result=" .. phString(result)
        )
    end

    if type(getTypeInfo) == "function" then
        local ok, result = pcall(function()
            return getTypeInfo(object)
        end)
        phLog(
            label
            .. " | getTypeInfo"
            .. " | success=" .. tostring(ok)
            .. " | result=" .. phString(result)
        )
    end

    if type(inspect) == "function" then
        local ok, info = pcall(function()
            return inspect(object)
        end)

        if ok and type(info) == "table" then
            phLog(
                label
                .. " | CLASS"
                .. " | fq=" .. tostring(info.fullQualifiedName)
            )

            local props = info[":properties:"]
            if type(props) == "table" then
                local names = {}
                for name in pairs(props) do
                    names[#names + 1] = tostring(name)
                end
                table.sort(names)

                for _, name in ipairs(names) do
                    local okValue, value = pcall(function()
                        return object[name]
                    end)

                    phLog(
                        label
                        .. " | PROPERTY"
                        .. " | name=" .. tostring(name)
                        .. " | success=" .. tostring(okValue)
                        .. " | type=" .. tostring(type(value))
                        .. " | value=" .. phString(value)
                    )
                end
            end

            local functions = info[":functions:"]
            if type(functions) == "table" then
                local names = {}
                for name in pairs(functions) do
                    names[#names + 1] = tostring(name)
                end
                table.sort(names)
                for _, name in ipairs(names) do
                    phLog(
                        label
                        .. " | FUNCTION"
                        .. " | name=" .. tostring(name)
                        .. " | desc=" .. phString(functions[name])
                    )
                end
            end
        else
            phLog(
                label
                .. " | inspect"
                .. " | success=" .. tostring(ok)
                .. " | result=" .. phString(info)
            )
        end
    end
end

local function phProbeArray(label, array)
    if array == nil then
        phLog(label .. " | array=nil")
        return
    end

    phLog(
        label
        .. " | ARRAY"
        .. " | type=" .. tostring(type(array))
        .. " | value=" .. phString(array)
    )

    -- Native type info is useful because PhoenixArray may expose only metamethods.
    if type(help) == "function" then
        local ok, result = pcall(function()
            return help(array)
        end)
        phLog(
            label
            .. " | help"
            .. " | success=" .. tostring(ok)
            .. " | result=" .. phString(result)
        )
    end

    if type(getTypeInfo) == "function" then
        local ok, result = pcall(function()
            return getTypeInfo(array)
        end)
        phLog(
            label
            .. " | getTypeInfo"
            .. " | success=" .. tostring(ok)
            .. " | result=" .. phString(result)
        )
    end

    local okLen, length = pcall(function()
        return #array
    end)
    phLog(
        label
        .. " | LEN"
        .. " | success=" .. tostring(okLen)
        .. " | value=" .. phString(length)
    )

    -- PhoenixArray userdata is not pairs()-iterable, but numeric __index may work.
    -- Test both 0-based and 1-based access over a safe bounded range.
    local unique = {}
    local successful = 0
    local consecutiveEmpty = 0

    for i = 0, 63 do
        local ok, value = pcall(function()
            return array[i]
        end)

        phLog(
            label
            .. " | INDEX"
            .. " | i=" .. tostring(i)
            .. " | success=" .. tostring(ok)
            .. " | type=" .. tostring(type(value))
            .. " | value=" .. phString(value)
        )

        if ok and not phNull(value) then
            consecutiveEmpty = 0
            local identity = tostring(type(value)) .. "|" .. phString(value)

            if not unique[identity] then
                unique[identity] = true
                successful = successful + 1
                phInspectObject(
                    label .. "[" .. tostring(i) .. "]",
                    value
                )
            end
        else
            consecutiveEmpty = consecutiveEmpty + 1
        end

        -- Once we have found entries and then hit a long empty tail, stop.
        if successful > 0 and consecutiveEmpty >= 8 then
            phLog(
                label
                .. " | STOP"
                .. " | reason=8 consecutive empty indexes"
                .. " | lastIndex=" .. tostring(i)
            )
            break
        end
    end

    -- Also test common array-access spellings, but only call them if lookup
    -- really yields a Lua function.
    local methodNames = {
        "Get", "GetAt", "At", "GetItem", "GetElement",
        "Size", "GetSize", "Count", "GetCount", "Length", "GetLength"
    }

    for _, method in ipairs(methodNames) do
        local okLookup, fn = pcall(function()
            return array[method]
        end)

        phLog(
            label
            .. " | METHOD LOOKUP"
            .. " | name=" .. tostring(method)
            .. " | success=" .. tostring(okLookup)
            .. " | type=" .. tostring(type(fn))
            .. " | value=" .. phString(fn)
        )

        if okLookup and type(fn) == "function" then
            if method == "Size" or method == "GetSize"
                or method == "Count" or method == "GetCount"
                or method == "Length" or method == "GetLength"
            then
                local okCall, result = pcall(function()
                    return fn(array)
                end)
                phLog(
                    label
                    .. " | METHOD CALL"
                    .. " | name=" .. tostring(method)
                    .. " | success=" .. tostring(okCall)
                    .. " | result=" .. phString(result)
                )
            else
                for i = 0, 3 do
                    local okCall, result = pcall(function()
                        return fn(array, i)
                    end)
                    phLog(
                        label
                        .. " | METHOD CALL"
                        .. " | name=" .. tostring(method)
                        .. " | i=" .. tostring(i)
                        .. " | success=" .. tostring(okCall)
                        .. " | type=" .. tostring(type(result))
                        .. " | result=" .. phString(result)
                    )
                end
            end
        end
    end
end

local function runTradeRouteGroupArrayProbe()
    phLog("START")

    local scene = nil
    pcall(function()
        scene = ui and ui.Scenes and ui.Scenes.TradeRoute or nil
    end)

    if scene == nil then
        phLog("ABORT | TradeRoute scene unavailable")
        return
    end

    -- Most important: the actual overview group data shown on screen.
    local overview = nil
    local groupData = nil
    local soloData = nil
    local overviewAny = nil

    pcall(function()
        overview = scene.TradeOverview
    end)

    if overview ~= nil then
        phInspectObject("TradeOverview", overview)

        pcall(function()
            groupData = overview.TradeRouteGroupData
        end)
        pcall(function()
            soloData = overview.TradeRouteSoloData
        end)
        pcall(function()
            overviewAny = overview.OverviewListData.ArrayData
        end)
    end

    phProbeArray(
        "TradeOverview.TradeRouteGroupData",
        groupData
    )

    phProbeArray(
        "TradeOverview.TradeRouteSoloData",
        soloData
    )

    phProbeArray(
        "TradeOverview.OverviewListData.ArrayData",
        overviewAny
    )

    -- Secondary: the group assignment/management popup array.
    local managerData = nil
    local popupData = nil
    local groupButtonArray = nil

    pcall(function()
        managerData = scene.RouteGroupManagerData
    end)
    if managerData ~= nil then
        phInspectObject("RouteGroupManagerData", managerData)
        pcall(function()
            popupData = managerData.PopupData
        end)
    end

    if popupData ~= nil then
        phInspectObject("RouteGroupManagerData.PopupData", popupData)
        pcall(function()
            groupButtonArray = popupData.GroupArrayData
        end)
    end

    phProbeArray(
        "RouteGroupManagerData.PopupData.GroupArrayData",
        groupButtonArray
    )

    phLog("COMPLETE")
end


local GROUP_MAP_PREFIX = "[Ship Finder Trade Route Group Mapper 1.1.0]"

local function gmLog(text)
    system.log(GROUP_MAP_PREFIX .. " | " .. tostring(text))
end

local function gmString(value)
    local ok, result = pcall(function()
        return tostring(value)
    end)
    if ok then
        return result
    end
    return "<tostring error>"
end

local function gmIsNull(value)
    if value == nil then
        return true
    end
    local s = gmString(value)
    return string.find(s, "weak null", 1, true) ~= nil
        or string.find(s, " null", 1, true) ~= nil
end

local function gmClassName(object)
    if object == nil then
        return "<nil>"
    end

    if type(inspect) == "function" then
        local ok, info = pcall(function()
            return inspect(object)
        end)
        if ok and type(info) == "table" and info.fullQualifiedName then
            return tostring(info.fullQualifiedName)
        end
    end

    return gmString(object)
end

local function gmCollectStrings(object, depth, seen, out, path)
    if object == nil or depth > 4 then
        return
    end

    local t = type(object)
    if t == "string" then
        if object ~= "" then
            out[#out + 1] = {
                path = path,
                value = object,
            }
        end
        return
    end

    if t ~= "userdata" and t ~= "table" then
        return
    end

    local identity = t .. "|" .. gmString(object)
    if seen[identity] then
        return
    end
    seen[identity] = true

    if t == "table" then
        local count = 0
        pcall(function()
            for k, v in pairs(object) do
                count = count + 1
                gmCollectStrings(
                    v,
                    depth + 1,
                    seen,
                    out,
                    tostring(path) .. "[" .. tostring(k) .. "]"
                )
                if count >= 100 then
                    break
                end
            end
        end)
        return
    end

    if type(inspect) ~= "function" then
        return
    end

    local ok, info = pcall(function()
        return inspect(object)
    end)
    if not ok or type(info) ~= "table" then
        return
    end

    local props = info[":properties:"]
    if type(props) ~= "table" then
        return
    end

    local names = {}
    for name in pairs(props) do
        names[#names + 1] = tostring(name)
    end
    table.sort(names)

    for _, name in ipairs(names) do
        local okValue, value = pcall(function()
            return object[name]
        end)

        if okValue then
            gmCollectStrings(
                value,
                depth + 1,
                seen,
                out,
                tostring(path) .. "." .. tostring(name)
            )
        end
    end
end

local function gmBestVisibleText(object, label)
    if object == nil then
        return nil
    end

    -- First try the most likely direct paths.
    local candidates = {
        function() return object.Text end,
        function() return object.Name end,
        function() return object.Label end,
        function() return object.Title end,
        function() return object.TextData and object.TextData.Text end,
        function() return object.Data and object.Data.Text end,
        function() return object.Data and object.Data.TextData and object.Data.TextData.Text end,
        function() return object.NameData and object.NameData.Text end,
        function() return object.NameData and object.NameData.TextData and object.NameData.TextData.Text end,
        function() return object.NameData and object.NameData.Data and object.NameData.Data.Text end,
    }

    for _, getter in ipairs(candidates) do
        local ok, value = pcall(getter)
        if ok and type(value) == "string" and value ~= "" then
            return value
        end
    end

    -- Fallback: recursively collect all exposed non-empty strings.
    local strings = {}
    gmCollectStrings(object, 0, {}, strings, label or "object")

    for _, entry in ipairs(strings) do
        gmLog(
            "STRING CANDIDATE"
            .. " | owner=" .. tostring(label)
            .. " | path=" .. tostring(entry.path)
            .. " | value=" .. tostring(entry.value)
        )
    end

    if #strings == 1 then
        return strings[1].value
    end

    -- Prefer strings coming from names/text fields if several are present.
    for _, entry in ipairs(strings) do
        local lowerPath = string.lower(tostring(entry.path))
        if string.find(lowerPath, "name", 1, true)
            or string.find(lowerPath, "text", 1, true)
            or string.find(lowerPath, "label", 1, true)
            or string.find(lowerPath, "title", 1, true)
        then
            return entry.value
        end
    end

    return strings[1] and strings[1].value or nil
end

local function gmGetRouteName(routeID)
    if routeID == nil or routeID < 0 then
        return nil
    end

    local manager = nil
    pcall(function()
        manager = TradeRoute and TradeRoute.get and TradeRoute.get() or nil
    end)

    if manager == nil then
        return nil
    end

    local ok, route = pcall(function()
        return manager:GetRoute(routeID)
    end)

    if not ok or gmIsNull(route) then
        return nil
    end

    local name = nil
    pcall(function()
        name = route.Name
    end)

    if type(name) == "string" and name ~= "" then
        return name
    end
    return nil
end

local function gmReadTradeRouteData(data, label)
    if data == nil then
        return nil
    end

    local result = {
        label = label,
        className = gmClassName(data),
        folderID = nil,
        routeID = nil,
        isGroupBtn = nil,
        isUsedInRouteGroup = nil,
        name = nil,
        nameData = nil,
    }

    pcall(function() result.folderID = data.FolderID end)
    pcall(function() result.routeID = data.RouteID end)
    pcall(function() result.isGroupBtn = data.IsGroupBtn end)
    pcall(function() result.isUsedInRouteGroup = data.IsUsedInRouteGroup end)
    pcall(function() result.nameData = data.NameData end)

    if result.nameData ~= nil then
        result.name = gmBestVisibleText(
            result.nameData,
            tostring(label) .. ".NameData"
        )
    end

    if (result.name == nil or result.name == "")
        and type(result.routeID) == "number"
        and result.routeID >= 0
        and result.isGroupBtn ~= true
    then
        result.name = gmGetRouteName(result.routeID)
    end

    return result
end

local function runTradeRouteGroupMapper()
    gmLog("START")

    local scene = nil
    local overview = nil
    local listData = nil
    local array = nil

    pcall(function()
        scene = ui and ui.Scenes and ui.Scenes.TradeRoute or nil
        overview = scene and scene.TradeOverview or nil
        listData = overview and overview.OverviewListData or nil
        array = listData and listData.ArrayData or nil
    end)

    if array == nil then
        gmLog("ABORT | OverviewListData.ArrayData unavailable")
        return
    end

    gmLog(
        "ARRAY"
        .. " | class=" .. gmClassName(array)
        .. " | value=" .. gmString(array)
    )

    local currentGroup = nil
    local groupCount = 0
    local routeCount = 0
    local soloCount = 0
    local headlineCount = 0
    local nonNilSeen = false
    local emptyTail = 0

    for i = 0, 511 do
        local ok, item = pcall(function()
            return array[i]
        end)

        if ok and item ~= nil and not gmIsNull(item) then
            nonNilSeen = true
            emptyTail = 0

            local className = gmClassName(item)

            if string.find(className, "TradeRouteOverviewListHeadlineData", 1, true) then
                headlineCount = headlineCount + 1
                local headlineData = nil
                pcall(function() headlineData = item.HeadlineData end)
                local text = gmBestVisibleText(
                    headlineData,
                    "index[" .. tostring(i) .. "].HeadlineData"
                )

                gmLog(
                    "HEADLINE"
                    .. " | index=" .. tostring(i)
                    .. " | text=" .. tostring(text)
                )

                -- Headline usually separates groups from solo routes.
                currentGroup = nil

            elseif string.find(className, "TradeRouteOverviewGroupBtnData", 1, true) then
                local buttonData = nil
                local isOpen = nil

                pcall(function() buttonData = item.ButtonData end)
                pcall(function() isOpen = item.IsGroupOpen end)

                local groupData = gmReadTradeRouteData(
                    buttonData,
                    "index[" .. tostring(i) .. "].ButtonData"
                )

                groupCount = groupCount + 1

                currentGroup = {
                    index = i,
                    folderID = groupData and groupData.folderID or nil,
                    name = groupData and groupData.name or nil,
                    isOpen = isOpen,
                }

                gmLog(
                    "GROUP"
                    .. " | index=" .. tostring(i)
                    .. " | name=" .. tostring(currentGroup.name)
                    .. " | folderID=" .. tostring(currentGroup.folderID)
                    .. " | isOpen=" .. tostring(currentGroup.isOpen)
                    .. " | buttonClass=" .. tostring(groupData and groupData.className)
                    .. " | buttonIsGroupBtn=" .. tostring(groupData and groupData.isGroupBtn)
                    .. " | buttonRouteID=" .. tostring(groupData and groupData.routeID)
                )

            elseif string.find(className, "TradeRouteData", 1, true) then
                local route = gmReadTradeRouteData(
                    item,
                    "index[" .. tostring(i) .. "]"
                )

                routeCount = routeCount + 1

                local belongsToCurrent =
                    currentGroup ~= nil
                    and route.folderID ~= nil
                    and currentGroup.folderID ~= nil
                    and route.folderID == currentGroup.folderID

                if route.isUsedInRouteGroup == true or (route.folderID and route.folderID >= 0) then
                    gmLog(
                        "GROUPED ROUTE"
                        .. " | index=" .. tostring(i)
                        .. " | name=" .. tostring(route.name)
                        .. " | routeID=" .. tostring(route.routeID)
                        .. " | folderID=" .. tostring(route.folderID)
                        .. " | currentGroupName=" .. tostring(currentGroup and currentGroup.name)
                        .. " | currentGroupFolderID=" .. tostring(currentGroup and currentGroup.folderID)
                        .. " | folderMatchesCurrent=" .. tostring(belongsToCurrent)
                        .. " | IsUsedInRouteGroup=" .. tostring(route.isUsedInRouteGroup)
                    )
                else
                    soloCount = soloCount + 1
                    gmLog(
                        "SOLO ROUTE"
                        .. " | index=" .. tostring(i)
                        .. " | name=" .. tostring(route.name)
                        .. " | routeID=" .. tostring(route.routeID)
                        .. " | folderID=" .. tostring(route.folderID)
                        .. " | IsUsedInRouteGroup=" .. tostring(route.isUsedInRouteGroup)
                    )
                end
            else
                gmLog(
                    "OTHER"
                    .. " | index=" .. tostring(i)
                    .. " | class=" .. tostring(className)
                    .. " | value=" .. gmString(item)
                )
            end
        else
            if nonNilSeen then
                emptyTail = emptyTail + 1
                if emptyTail >= 16 then
                    gmLog(
                        "STOP"
                        .. " | reason=16 consecutive empty indexes"
                        .. " | index=" .. tostring(i)
                    )
                    break
                end
            end
        end
    end

    gmLog(
        "COMPLETE"
        .. " | groups=" .. tostring(groupCount)
        .. " | routeRows=" .. tostring(routeCount)
        .. " | soloRoutes=" .. tostring(soloCount)
        .. " | headlines=" .. tostring(headlineCount)
    )
end


local ROUTE_BRIDGE_PREFIX = "[Ship Finder Route-ID Bridge Probe 1.1.0]"

local function rbLog(text)
    system.log(ROUTE_BRIDGE_PREFIX .. " | " .. tostring(text))
end

local function rbString(value)
    local ok, result = pcall(function()
        return tostring(value)
    end)
    if ok then
        return result
    end
    return "<tostring error>"
end

local function rbInspect(label, object)
    if object == nil then
        rbLog(label .. " | object=nil")
        return
    end

    rbLog(
        label
        .. " | OBJECT"
        .. " | type=" .. tostring(type(object))
        .. " | value=" .. rbString(object)
    )

    if type(help) == "function" then
        local ok, result = pcall(function()
            return help(object)
        end)
        rbLog(
            label
            .. " | HELP"
            .. " | success=" .. tostring(ok)
            .. " | result=" .. rbString(result)
        )
    end

    if type(inspect) ~= "function" then
        rbLog(label .. " | inspect unavailable")
        return
    end

    local ok, info = pcall(function()
        return inspect(object)
    end)

    if not ok or type(info) ~= "table" then
        rbLog(
            label
            .. " | INSPECT FAILED"
            .. " | success=" .. tostring(ok)
            .. " | result=" .. rbString(info)
        )
        return
    end

    rbLog(
        label
        .. " | CLASS"
        .. " | fullQualifiedName=" .. tostring(info.fullQualifiedName)
    )

    local props = info[":properties:"]
    if type(props) == "table" then
        local names = {}
        for name in pairs(props) do
            names[#names + 1] = tostring(name)
        end
        table.sort(names)

        for _, name in ipairs(names) do
            local okValue, value = pcall(function()
                return object[name]
            end)

            rbLog(
                label
                .. " | PROPERTY"
                .. " | name=" .. tostring(name)
                .. " | success=" .. tostring(okValue)
                .. " | type=" .. tostring(type(value))
                .. " | value=" .. rbString(value)
            )
        end
    end

    local funcs = info[":functions:"]
    if type(funcs) == "table" then
        local names = {}
        for name in pairs(funcs) do
            names[#names + 1] = tostring(name)
        end
        table.sort(names)

        for _, name in ipairs(names) do
            rbLog(
                label
                .. " | FUNCTION"
                .. " | name=" .. tostring(name)
                .. " | desc=" .. rbString(funcs[name])
            )
        end
    end
end

local function runRouteIDBridgeProbe()
    rbLog("START")
    rbLog(
        "TEST STATE"
        .. " | expected=normal world view"
        .. " | TradeRoute screen should be CLOSED"
    )

    local scene = nil
    local overview = nil
    local isPanelOpen = nil
    local isGroupsVisible = nil
    local array = nil

    pcall(function()
        scene = ui and ui.Scenes and ui.Scenes.TradeRoute or nil
        overview = scene and scene.TradeOverview or nil
        isPanelOpen = overview and overview.IsPanelOpen
        isGroupsVisible = overview and overview.IsGroupsVisible
        array = overview and overview.OverviewListData
            and overview.OverviewListData.ArrayData or nil
    end)

    rbLog(
        "TRADE ROUTE UI STATE"
        .. " | scenePresent=" .. tostring(scene ~= nil)
        .. " | overviewPresent=" .. tostring(overview ~= nil)
        .. " | IsPanelOpen=" .. tostring(isPanelOpen)
        .. " | IsGroupsVisible=" .. tostring(isGroupsVisible)
        .. " | arrayPresent=" .. tostring(array ~= nil)
        .. " | array=" .. rbString(array)
    )

    -- Native introspection of assigned ships' TradeRouteVehicle objects.
    -- This is the exact bridge we need from a world ship to RouteID/FolderID.
    local objects = Scripts:GetObjectGroupByProperty(Properties.ShipModuleOwner) or {}
    local assignedSeen = 0

    local ordered = {}
    for _, object in pairs(objects) do
        local route = object.TradeRouteVehicle
        local assigned = false
        pcall(function()
            assigned = route and route.IsAssignedOnTradeRoute == true
        end)

        if route and assigned then
            local name = object.Nameable and object.Nameable.Name or "<unnamed>"
            ordered[#ordered + 1] = {
                object = object,
                route = route,
                name = tostring(name),
                id = tostring(object.ID),
            }
        end
    end

    table.sort(ordered, function(a, b)
        local ak = string.lower(a.name) .. "|" .. a.id
        local bk = string.lower(b.name) .. "|" .. b.id
        return ak < bk
    end)

    for _, entry in ipairs(ordered) do
        assignedSeen = assignedSeen + 1

        local routeName = nil
        pcall(function()
            routeName = entry.route.RouteName
        end)

        rbLog(
            "ASSIGNED SHIP"
            .. " | ordinal=" .. tostring(assignedSeen)
            .. " | ship=" .. tostring(entry.name)
            .. " | objectID=" .. tostring(entry.object.ID)
            .. " | RouteName=" .. tostring(routeName)
        )

        rbInspect(
            "TradeRouteVehicle[" .. tostring(assignedSeen) .. "]",
            entry.route
        )

        if assignedSeen >= 3 then
            break
        end
    end

    rbLog(
        "COMPLETE"
        .. " | assignedTradeRouteVehiclesInspected=" .. tostring(assignedSeen)
    )
end


local AUTO_PRIME_PREFIX = "[Ship Finder Route Group Auto-Prime 1.1.0]"
local routeGroupPrimeActive = false
local routeGroupPrimeStage = 0
local routeGroupPrimeTicks = 0
local routeGroupPrimeOriginalPanelOpen = false
local routeGroupPrimeOriginalGroupsVisible = false
local routeGroupPrimeChangedPanelOpen = false
local routeGroupPrimeChangedGroupsVisible = false
local routeGroupPrimeRequestedFocus = false

local function apLog(text)
    system.log(AUTO_PRIME_PREFIX .. " | " .. tostring(text))
end

local function apGetSceneState()
    local scene = nil
    local overview = nil
    local array = nil
    local panelOpen = nil
    local groupsVisible = nil

    pcall(function()
        scene = ui and ui.Scenes and ui.Scenes.TradeRoute or nil
        overview = scene and scene.TradeOverview or nil
        array = overview and overview.OverviewListData
            and overview.OverviewListData.ArrayData or nil
        panelOpen = overview and overview.IsPanelOpen
        groupsVisible = overview and overview.IsGroupsVisible
    end)

    return scene, overview, array, panelOpen, groupsVisible
end

local function apCountRows(array)
    if array == nil then
        return 0
    end

    local count = 0
    local seenAny = false
    local emptyTail = 0

    for i = 0, 511 do
        local ok, item = pcall(function()
            return array[i]
        end)

        if ok and item ~= nil then
            local text = tostring(item)
            if string.find(text, "weak null", 1, true) == nil then
                count = count + 1
                seenAny = true
                emptyTail = 0
            else
                if seenAny then
                    emptyTail = emptyTail + 1
                end
            end
        else
            if seenAny then
                emptyTail = emptyTail + 1
            end
        end

        if seenAny and emptyTail >= 16 then
            break
        end
    end

    return count
end

local function apLogState(label)
    local scene, overview, array, panelOpen, groupsVisible = apGetSceneState()
    local rows = apCountRows(array)

    apLog(
        tostring(label)
        .. " | scenePresent=" .. tostring(scene ~= nil)
        .. " | overviewPresent=" .. tostring(overview ~= nil)
        .. " | IsPanelOpen=" .. tostring(panelOpen)
        .. " | IsGroupsVisible=" .. tostring(groupsVisible)
        .. " | arrayPresent=" .. tostring(array ~= nil)
        .. " | rows=" .. tostring(rows)
    )

    return rows, scene, overview, array, panelOpen, groupsVisible
end

local function apRestoreAndClose()
    local scene, overview = apGetSceneState()

    if overview ~= nil then
        if routeGroupPrimeChangedGroupsVisible then
            pcall(function()
                overview.IsGroupsVisible = routeGroupPrimeOriginalGroupsVisible
            end)
        end

        if routeGroupPrimeChangedPanelOpen then
            pcall(function()
                overview.IsPanelOpen = routeGroupPrimeOriginalPanelOpen
            end)
        end
    end

    if routeGroupPrimeRequestedFocus and scene ~= nil then
        local closeFn = nil
        pcall(function()
            closeFn = scene.CloseTradeRouteScene
        end)

        if type(closeFn) == "function" then
            local ok, result = pcall(function()
                return scene:CloseTradeRouteScene()
            end)

            apLog(
                "RESTORE"
                .. " | CloseTradeRouteScene success=" .. tostring(ok)
                .. " | result=" .. tostring(result)
            )
        else
            apLog("RESTORE | CloseTradeRouteScene unavailable")
        end
    end
end

local function apStartNormalShipFinderMenu()
    ShipFinderPersonalLabelCache = {}
    ShipFinderAlphabeticalDynamicCache = nil
    ShipFinderPersonalMode = false

    system.log(
        "[Ship Finder Route Cache 1.1.0] before menu"
        .. " | groups=" .. tostring(#(ShipFinderTradeRouteGroups or {}))
        .. " | soloRoutes=" .. tostring(#(ShipFinderTradeRouteSoloRoutes or {}))
    )

    system.log(
        "[Ship Finder Combined Root 1.1.0] opening generic storyline"
        .. " | storyline=" .. tostring(PUBLIC_STORYLINE)
    )

    GovernorDecision:CheatStartGovernorDecisionForCurrentPlayerNet(PUBLIC_STORYLINE)

    system.log(
        "[Ship Finder Direct Menu Open 1.1.0] POST-STORYLINE"
        .. " | openerType=" .. tostring(type(tryDirectOpenGovernorRequest))
    )

    directOpenAttempt = 0
    local immediateOpened = tryDirectOpenGovernorRequest("POST_PRIME_IMMEDIATE")
    directOpenPending = not immediateOpened

    system.log(
        "[Ship Finder Combined Root 1.1.0] storyline call returned"
        .. " | immediateOpened=" .. tostring(immediateOpened)
        .. " | delayedRetryArmed=" .. tostring(directOpenPending)
        .. " | path=ui.Scenes.GovernorRequests.SceneData.Notification[0].ButtonData.States"
    )
end

local function apFinish(success, method)
    local rows = apLogState("FINAL STATE BEFORE RESTORE")

    if success then
        apLog(
            "SUCCESS"
            .. " | method=" .. tostring(method)
            .. " | rows=" .. tostring(rows)
        )

        -- Log the complete proven mapping while the data is populated.
        pcall(runTradeRouteGroupMapper)
    else
        apLog(
            "FAILED"
            .. " | method=" .. tostring(method)
            .. " | rows=" .. tostring(rows)
        )
    end

    apRestoreAndClose()

    routeGroupPrimeActive = false
    routeGroupPrimeStage = 0
    routeGroupPrimeTicks = 0

    apStartNormalShipFinderMenu()
end

local function apBegin()
    routeGroupPrimeActive = true
    routeGroupPrimeStage = 1
    routeGroupPrimeTicks = 0
    routeGroupPrimeChangedPanelOpen = false
    routeGroupPrimeChangedGroupsVisible = false
    routeGroupPrimeRequestedFocus = false

    local rows, scene, overview, array, panelOpen, groupsVisible =
        apLogState("BASELINE")

    routeGroupPrimeOriginalPanelOpen = panelOpen == true
    routeGroupPrimeOriginalGroupsVisible = groupsVisible == true

    if rows > 0 then
        apFinish(true, "already-populated")
        return
    end

    if overview == nil then
        apFinish(false, "overview-unavailable")
        return
    end

    -- Stage 1: lowest-impact attempt. The runtime type information proves
    -- TradeRouteOverviewData has OverviewTabPressed().
    local fn = nil
    pcall(function()
        fn = overview.OverviewTabPressed
    end)

    if type(fn) == "function" then
        local ok, result = pcall(function()
            return overview:OverviewTabPressed()
        end)

        apLog(
            "STAGE 1"
            .. " | action=OverviewTabPressed"
            .. " | success=" .. tostring(ok)
            .. " | result=" .. tostring(result)
        )
    else
        apLog("STAGE 1 | action=OverviewTabPressed | function unavailable")
    end
end

local function apTick()
    if not routeGroupPrimeActive then
        return false
    end

    routeGroupPrimeTicks = routeGroupPrimeTicks + 1

    local rows, scene, overview, array, panelOpen, groupsVisible =
        apLogState(
            "TICK"
            .. " | stage=" .. tostring(routeGroupPrimeStage)
            .. " | tick=" .. tostring(routeGroupPrimeTicks)
        )

    if rows > 0 then
        if routeGroupPrimeStage == 1 then
            apFinish(true, "OverviewTabPressed-only")
        elseif routeGroupPrimeStage == 2 then
            apFinish(true, "viewmodel-flags")
        else
            apFinish(true, "RequestFocus")
        end
        return true
    end

    if routeGroupPrimeStage == 1 and routeGroupPrimeTicks >= 1 then
        -- Stage 2: set only the exposed TradeOverview view-model flags.
        if overview ~= nil then
            local okGroups = pcall(function()
                overview.IsGroupsVisible = true
            end)
            local okPanel = pcall(function()
                overview.IsPanelOpen = true
            end)

            routeGroupPrimeChangedGroupsVisible =
                okGroups and routeGroupPrimeOriginalGroupsVisible ~= true
            routeGroupPrimeChangedPanelOpen =
                okPanel and routeGroupPrimeOriginalPanelOpen ~= true

            local fn = nil
            pcall(function()
                fn = overview.OverviewTabPressed
            end)

            local okTab, resultTab = false, nil
            if type(fn) == "function" then
                okTab, resultTab = pcall(function()
                    return overview:OverviewTabPressed()
                end)
            end

            apLog(
                "STAGE 2"
                .. " | set IsGroupsVisible=true success=" .. tostring(okGroups)
                .. " | set IsPanelOpen=true success=" .. tostring(okPanel)
                .. " | OverviewTabPressed success=" .. tostring(okTab)
                .. " | result=" .. tostring(resultTab)
            )
        end

        routeGroupPrimeStage = 2
        routeGroupPrimeTicks = 0
        return true
    end

    if routeGroupPrimeStage == 2 and routeGroupPrimeTicks >= 1 then
        -- Stage 3: final test. Ask the native TradeRoute scene for focus,
        -- then press its Overview tab. If this activates the UI, we harvest
        -- the data and CloseTradeRouteScene() immediately afterward.
        if scene ~= nil then
            local focusFn = nil
            pcall(function()
                focusFn = scene.RequestFocus
            end)

            local okFocus, resultFocus = false, nil
            if type(focusFn) == "function" then
                okFocus, resultFocus = pcall(function()
                    return scene:RequestFocus()
                end)
            end

            routeGroupPrimeRequestedFocus = okFocus

            local currentOverview = nil
            pcall(function()
                currentOverview = scene.TradeOverview
            end)

            local tabFn = nil
            if currentOverview ~= nil then
                pcall(function()
                    tabFn = currentOverview.OverviewTabPressed
                end)
            end

            local okTab, resultTab = false, nil
            if type(tabFn) == "function" then
                okTab, resultTab = pcall(function()
                    return currentOverview:OverviewTabPressed()
                end)
            end

            apLog(
                "STAGE 3"
                .. " | RequestFocus success=" .. tostring(okFocus)
                .. " | result=" .. tostring(resultFocus)
                .. " | OverviewTabPressed success=" .. tostring(okTab)
                .. " | result=" .. tostring(resultTab)
            )
        end

        routeGroupPrimeStage = 3
        routeGroupPrimeTicks = 0
        return true
    end

    if routeGroupPrimeStage == 3 and routeGroupPrimeTicks >= 6 then
        apFinish(false, "all-auto-prime-methods")
        return true
    end

    return true
end


local MACROMAP_PREFIX = "[Ship Finder MacroMap TradeRoute Control Probe 1.1.0]"
local macroProbeVisited = {}
local macroProbeNodes = 0
local macroProbeEntries = 0

local function mmLog(text)
    system.log(MACROMAP_PREFIX .. " | " .. tostring(text))
end

local function mmString(value)
    local ok, result = pcall(function()
        return tostring(value)
    end)
    if ok then
        return result
    end
    return "<tostring error>"
end

local function mmInteresting(name)
    local s = string.lower(tostring(name))
    return string.find(s, "trade", 1, true)
        or string.find(s, "route", 1, true)
        or string.find(s, "macro", 1, true)
        or string.find(s, "map", 1, true)
        or string.find(s, "button", 1, true)
        or string.find(s, "tab", 1, true)
        or string.find(s, "focus", 1, true)
        or string.find(s, "state", 1, true)
        or string.find(s, "navigation", 1, true)
        or string.find(s, "menu", 1, true)
end

local function mmIdentity(value)
    return tostring(type(value)) .. "|" .. mmString(value)
end

local mmWalk

local function mmLogObjectInfo(path, object)
    if type(inspect) ~= "function" then
        return nil
    end

    local ok, info = pcall(function()
        return inspect(object)
    end)

    if not ok or type(info) ~= "table" then
        mmLog(
            "INSPECT FAILED"
            .. " | path=" .. tostring(path)
            .. " | success=" .. tostring(ok)
            .. " | result=" .. mmString(info)
        )
        return nil
    end

    mmLog(
        "CLASS"
        .. " | path=" .. tostring(path)
        .. " | fq=" .. tostring(info.fullQualifiedName)
    )

    local funcs = info[":functions:"]
    if type(funcs) == "table" then
        local names = {}
        for name in pairs(funcs) do
            if mmInteresting(name) then
                names[#names + 1] = tostring(name)
            end
        end
        table.sort(names)
        for _, name in ipairs(names) do
            mmLog(
                "FUNCTION"
                .. " | path=" .. tostring(path)
                .. " | name=" .. tostring(name)
                .. " | desc=" .. mmString(funcs[name])
            )
        end
    end

    return info
end

local function mmWalkTable(path, object, depth)
    local count = 0
    pcall(function()
        for k, v in pairs(object) do
            count = count + 1
            macroProbeEntries = macroProbeEntries + 1

            if mmInteresting(k) then
                mmLog(
                    "TABLE ENTRY"
                    .. " | path=" .. tostring(path)
                    .. " | key=" .. tostring(k)
                    .. " | type=" .. tostring(type(v))
                    .. " | value=" .. mmString(v)
                )
            end

            if depth < 5 and (type(v) == "table" or type(v) == "userdata") then
                mmWalk(
                    tostring(path) .. "[" .. tostring(k) .. "]",
                    v,
                    depth + 1
                )
            end

            if count >= 200 or macroProbeEntries >= 1800 then
                break
            end
        end
    end)
end

local function mmWalkUserdata(path, object, depth)
    local info = mmLogObjectInfo(path, object)
    if info == nil then
        return
    end

    local props = info[":properties:"]
    if type(props) ~= "table" then
        return
    end

    local names = {}
    for name in pairs(props) do
        names[#names + 1] = tostring(name)
    end
    table.sort(names)

    for _, name in ipairs(names) do
        local ok, value = pcall(function()
            return object[name]
        end)

        macroProbeEntries = macroProbeEntries + 1

        if ok and mmInteresting(name) then
            mmLog(
                "PROPERTY"
                .. " | path=" .. tostring(path)
                .. " | name=" .. tostring(name)
                .. " | type=" .. tostring(type(value))
                .. " | value=" .. mmString(value)
            )
        end

        if ok and depth < 5 and (type(value) == "table" or type(value) == "userdata") then
            mmWalk(
                tostring(path) .. "." .. tostring(name),
                value,
                depth + 1
            )
        end

        if macroProbeEntries >= 1800 then
            break
        end
    end
end

mmWalk = function(path, object, depth)
    if object == nil or depth > 5 then
        return
    end

    local t = type(object)
    if t ~= "table" and t ~= "userdata" then
        return
    end

    if macroProbeNodes >= 400 or macroProbeEntries >= 1800 then
        return
    end

    local id = mmIdentity(object)
    if macroProbeVisited[id] then
        return
    end
    macroProbeVisited[id] = true
    macroProbeNodes = macroProbeNodes + 1

    mmLog(
        "WALK"
        .. " | path=" .. tostring(path)
        .. " | depth=" .. tostring(depth)
        .. " | type=" .. tostring(t)
        .. " | value=" .. mmString(object)
    )

    if t == "table" then
        mmWalkTable(path, object, depth)
    else
        mmWalkUserdata(path, object, depth)
    end
end

local function runMacroMapTradeRouteControlProbe()
    macroProbeVisited = {}
    macroProbeNodes = 0
    macroProbeEntries = 0

    mmLog("START")
    mmLog(
        "PURPOSE"
        .. " | find the actual native control/action that enters MacroMap -> TradeRoute"
        .. " | do not open Trade Routes manually"
    )

    local scenes = nil
    pcall(function()
        scenes = ui and ui.Scenes or nil
    end)

    if scenes == nil then
        mmLog("ABORT | ui.Scenes unavailable")
        return
    end

    local matches = {}
    pcall(function()
        for k, v in pairs(scenes) do
            local key = tostring(k)
            if mmInteresting(key) then
                matches[#matches + 1] = { key = key, value = v }
            end
        end
    end)
    table.sort(matches, function(a, b) return a.key < b.key end)

    for _, item in ipairs(matches) do
        mmLog(
            "SCENE MATCH"
            .. " | key=" .. tostring(item.key)
            .. " | type=" .. tostring(type(item.value))
            .. " | value=" .. mmString(item.value)
        )
    end

    local candidates = {
        "MacroMap",
        "TradeRoute",
        "HUD",
        "MainHud",
        "BottomBar",
        "TopBar",
        "Navigation",
        "MetaGame",
    }

    for _, sceneName in ipairs(candidates) do
        local scene = nil
        pcall(function()
            scene = scenes[sceneName]
        end)

        if scene ~= nil then
            mmLog(
                "CANDIDATE SCENE"
                .. " | name=" .. tostring(sceneName)
                .. " | type=" .. tostring(type(scene))
                .. " | value=" .. mmString(scene)
            )
            mmWalk("ui.Scenes." .. tostring(sceneName), scene, 0)
        end
    end

    mmLogObjectInfo("ui.Scenes", scenes)

    for _, nsInfo in ipairs({
        { name = "rdgs", value = rdgs },
        { name = "rdui", value = _G and _G["rdui"] or nil },
    }) do
        local ns = nsInfo.value
        if type(ns) == "table" then
            local nsMatches = {}
            pcall(function()
                for k, v in pairs(ns) do
                    if mmInteresting(k) then
                        nsMatches[#nsMatches + 1] = {
                            key = tostring(k),
                            value = v,
                        }
                    end
                end
            end)
            table.sort(nsMatches, function(a, b) return a.key < b.key end)

            for _, item in ipairs(nsMatches) do
                mmLog(
                    "NAMESPACE MATCH"
                    .. " | namespace=" .. tostring(nsInfo.name)
                    .. " | key=" .. tostring(item.key)
                    .. " | type=" .. tostring(type(item.value))
                    .. " | value=" .. mmString(item.value)
                )
            end
        end
    end

    mmLog(
        "COMPLETE"
        .. " | nodes=" .. tostring(macroProbeNodes)
        .. " | entries=" .. tostring(macroProbeEntries)
    )
end


local MACRO_TAB_PREFIX = "[Ship Finder TradeRoute-Open Tab Probe 1.1.0]"

local function mtLog(text)
    system.log(MACRO_TAB_PREFIX .. " | " .. tostring(text))
end

local function mtString(value)
    local ok, result = pcall(function()
        return tostring(value)
    end)
    if ok then
        return result
    end
    return "<tostring error>"
end

local function mtIsNull(value)
    if value == nil then
        return true
    end
    local s = mtString(value)
    return string.find(s, "weak null", 1, true) ~= nil
        or string.find(s, " null", 1, true) ~= nil
end

local function mtInspect(label, object)
    if object == nil or mtIsNull(object) then
        mtLog(label .. " | object=null")
        return
    end

    mtLog(
        label
        .. " | OBJECT"
        .. " | type=" .. tostring(type(object))
        .. " | value=" .. mtString(object)
    )

    if type(inspect) ~= "function" then
        return
    end

    local ok, info = pcall(function()
        return inspect(object)
    end)

    if not ok or type(info) ~= "table" then
        mtLog(
            label
            .. " | inspectSuccess=" .. tostring(ok)
            .. " | result=" .. mtString(info)
        )
        return
    end

    mtLog(
        label
        .. " | CLASS"
        .. " | fq=" .. tostring(info.fullQualifiedName)
    )

    local props = info[":properties:"]
    if type(props) == "table" then
        local names = {}
        for name in pairs(props) do
            names[#names + 1] = tostring(name)
        end
        table.sort(names)

        for _, name in ipairs(names) do
            local okValue, value = pcall(function()
                return object[name]
            end)

            mtLog(
                label
                .. " | PROPERTY"
                .. " | name=" .. tostring(name)
                .. " | success=" .. tostring(okValue)
                .. " | type=" .. tostring(type(value))
                .. " | value=" .. mtString(value)
            )
        end
    end

    local funcs = info[":functions:"]
    if type(funcs) == "table" then
        local names = {}
        for name in pairs(funcs) do
            names[#names + 1] = tostring(name)
        end
        table.sort(names)

        for _, name in ipairs(names) do
            mtLog(
                label
                .. " | FUNCTION"
                .. " | name=" .. tostring(name)
                .. " | desc=" .. mtString(funcs[name])
            )
        end
    end
end

local function mtReadTextFromObject(object)
    if object == nil then
        return nil
    end

    local candidates = {
        function() return object.Text end,
        function() return object.Label end,
        function() return object.Name end,
        function() return object.Title end,
        function() return object.Data and object.Data.Text end,
        function() return object.Data and object.Data.TextData and object.Data.TextData.Text end,
        function() return object.TextData and object.TextData.Text end,
        function() return object.BtnData and object.BtnData.Data and object.BtnData.Data.TextData and object.BtnData.Data.TextData.Text end,
        function() return object.ButtonData and object.ButtonData.Data and object.ButtonData.Data.TextData and object.ButtonData.Data.TextData.Text end,
    }

    for _, getter in ipairs(candidates) do
        local ok, value = pcall(getter)
        if ok and type(value) == "string" and value ~= "" then
            return value
        end
    end

    return nil
end

local function mtProbeInteraction(label, states)
    if states == nil then
        return
    end

    mtInspect(label, states)

    for _, method in ipairs({
        "RequestFocus",
        "EventPrimary",
        "EventSecondary",
        "EventTertiary",
        "EventAccept",
        "EventCancel",
    }) do
        local ok, fn = pcall(function()
            return states[method]
        end)

        mtLog(
            label
            .. " | INTERACTION METHOD"
            .. " | name=" .. tostring(method)
            .. " | lookupSuccess=" .. tostring(ok)
            .. " | type=" .. tostring(type(fn))
            .. " | value=" .. mtString(fn)
        )
    end
end

local function runMacroMapTabProbe()
    mtLog("START")

    local tradeScene = nil
    local tradeOverview = nil
    local tradePanelOpen = nil
    local tradeGroupsVisible = nil
    local tradeRows = 0

    pcall(function()
        tradeScene = ui and ui.Scenes and ui.Scenes.TradeRoute or nil
        tradeOverview = tradeScene and tradeScene.TradeOverview or nil
        tradePanelOpen = tradeOverview and tradeOverview.IsPanelOpen
        tradeGroupsVisible = tradeOverview and tradeOverview.IsGroupsVisible

        local arr = tradeOverview
            and tradeOverview.OverviewListData
            and tradeOverview.OverviewListData.ArrayData
            or nil

        if arr ~= nil then
            local seen = false
            local emptyTail = 0
            for i = 0, 511 do
                local ok, item = pcall(function() return arr[i] end)
                if ok and item ~= nil then
                    local s = tostring(item)
                    if string.find(s, "weak null", 1, true) == nil then
                        tradeRows = tradeRows + 1
                        seen = true
                        emptyTail = 0
                    elseif seen then
                        emptyTail = emptyTail + 1
                    end
                elseif seen then
                    emptyTail = emptyTail + 1
                end

                if seen and emptyTail >= 16 then
                    break
                end
            end
        end
    end)

    mtLog(
        "TRADE ROUTE STATE"
        .. " | scenePresent=" .. tostring(tradeScene ~= nil)
        .. " | overviewPresent=" .. tostring(tradeOverview ~= nil)
        .. " | IsPanelOpen=" .. tostring(tradePanelOpen)
        .. " | IsGroupsVisible=" .. tostring(tradeGroupsVisible)
        .. " | overviewRows=" .. tostring(tradeRows)
    )

    local macroScene = nil
    local macroData = nil
    local tabsData = nil
    local tabsArray = nil

    pcall(function()
        macroScene = ui and ui.Scenes and ui.Scenes.MacroMap or nil
        macroData = macroScene and macroScene.MacroMapData or nil
        tabsData = macroData and macroData.TabsData or nil
        tabsArray = tabsData and tabsData.TabsBtnsList or nil
    end)

    mtLog(
        "MACROMAP"
        .. " | scene=" .. mtString(macroScene)
        .. " | data=" .. mtString(macroData)
        .. " | tabsData=" .. mtString(tabsData)
        .. " | tabsArray=" .. mtString(tabsArray)
    )

    if tabsData ~= nil then
        mtInspect("MacroMap.TabsData", tabsData)

        local selected = nil
        pcall(function()
            selected = tabsData.SelectedTabID
        end)
        mtLog("SELECTED TAB | id=" .. tostring(selected))
    end

    if tabsArray == nil then
        mtLog("ABORT | TabsBtnsList unavailable")
        return
    end

    if type(help) == "function" then
        local ok, result = pcall(function()
            return help(tabsArray)
        end)
        mtLog(
            "TABS ARRAY HELP"
            .. " | success=" .. tostring(ok)
            .. " | result=" .. mtString(result)
        )
    end

    local okLen, len = pcall(function()
        return #tabsArray
    end)
    mtLog(
        "TABS ARRAY LEN"
        .. " | success=" .. tostring(okLen)
        .. " | value=" .. tostring(len)
    )

    local found = 0
    local emptyTail = 0

    for i = 0, 31 do
        local ok, tab = pcall(function()
            return tabsArray[i]
        end)

        mtLog(
            "TAB INDEX"
            .. " | i=" .. tostring(i)
            .. " | success=" .. tostring(ok)
            .. " | type=" .. tostring(type(tab))
            .. " | value=" .. mtString(tab)
        )

        if ok and not mtIsNull(tab) then
            found = found + 1
            emptyTail = 0

            local label = mtReadTextFromObject(tab)
            mtLog(
                "TAB"
                .. " | i=" .. tostring(i)
                .. " | label=" .. tostring(label)
            )

            mtInspect("TAB[" .. tostring(i) .. "]", tab)

            -- Probe common tab/button data containers.
            for _, member in ipairs({
                "BtnData",
                "ButtonData",
                "States",
                "InteractionStates",
                "TabData",
                "Data",
                "InfoTip",
                "Infotip",
            }) do
                local okMember, value = pcall(function()
                    return tab[member]
                end)

                if okMember and value ~= nil then
                    mtLog(
                        "TAB MEMBER"
                        .. " | i=" .. tostring(i)
                        .. " | name=" .. tostring(member)
                        .. " | type=" .. tostring(type(value))
                        .. " | value=" .. mtString(value)
                    )

                    if member == "States" or member == "InteractionStates" then
                        mtProbeInteraction(
                            "TAB[" .. tostring(i) .. "]." .. tostring(member),
                            value
                        )
                    elseif member == "BtnData" or member == "ButtonData" then
                        mtInspect(
                            "TAB[" .. tostring(i) .. "]." .. tostring(member),
                            value
                        )

                        local states = nil
                        pcall(function()
                            states = value.States
                        end)

                        if states ~= nil then
                            mtProbeInteraction(
                                "TAB[" .. tostring(i) .. "]." .. tostring(member) .. ".States",
                                states
                            )
                        end
                    end
                end
            end
        else
            if found > 0 then
                emptyTail = emptyTail + 1
                if emptyTail >= 6 then
                    mtLog(
                        "STOP"
                        .. " | reason=6 consecutive empty indexes"
                        .. " | index=" .. tostring(i)
                    )
                    break
                end
            end
        end
    end

    mtLog(
        "COMPLETE"
        .. " | tabsFound=" .. tostring(found)
    )
end




-- Production cache populated from the native Trade Route overview.
ShipFinderTradeRouteGroups = ShipFinderTradeRouteGroups or {}
ShipFinderTradeRouteRoutesByFolder = ShipFinderTradeRouteRoutesByFolder or {}
ShipFinderTradeRouteSoloRoutes = ShipFinderTradeRouteSoloRoutes or {}
ShipFinderTradeRouteRouteByName = ShipFinderTradeRouteRouteByName or {}

local function buildProductionTradeRouteCache()
    ShipFinderTradeRouteGroups = {}
    ShipFinderTradeRouteRoutesByFolder = {}
    ShipFinderTradeRouteSoloRoutes = {}
    ShipFinderTradeRouteRouteByName = {}

    local arr = nil
    pcall(function()
        local scene = ui and ui.Scenes and ui.Scenes.TradeRoute or nil
        local overview = scene and scene.TradeOverview or nil
        arr = overview and overview.OverviewListData
            and overview.OverviewListData.ArrayData or nil
    end)

    if arr == nil then
        system.log("[Ship Finder Route Cache 1.1.0] unavailable")
        return false
    end

    local currentGroupName = nil
    local currentFolderID = nil
    local seen = false
    local emptyTail = 0

    for i = 0, 511 do
        local ok, row = pcall(function() return arr[i] end)

        if ok and row ~= nil then
            local s = tostring(row)
            if string.find(s, "weak null", 1, true) == nil then
                seen = true
                emptyTail = 0

                local isOpen = nil
                local buttonData = nil
                local isGroup = false

                local okOpen = pcall(function() isOpen = row.IsGroupOpen end)
                local okButton = pcall(function() buttonData = row.ButtonData end)

                if okOpen and okButton and type(isOpen) == "boolean" and buttonData ~= nil then
                    isGroup = true
                end

                if isGroup then
                    local name = nil
                    local folderID = nil
                    pcall(function()
                        name = buttonData.NameData and buttonData.NameData.Text or nil
                    end)
                    pcall(function() folderID = buttonData.FolderID end)

                    currentGroupName = name
                    currentFolderID = folderID

                    if folderID ~= nil and folderID ~= -1 then
                        ShipFinderTradeRouteGroups[#ShipFinderTradeRouteGroups + 1] = {
                            name = name or ("Group " .. tostring(folderID)),
                            folderID = folderID,
                        }
                        ShipFinderTradeRouteRoutesByFolder[folderID] =
                            ShipFinderTradeRouteRoutesByFolder[folderID] or {}
                    end
                else
                    local routeID = nil
                    local folderID = nil
                    local routeName = nil
                    local usedInGroup = false
                    local isRoute = false

                    local okRoute = pcall(function() routeID = row.RouteID end)
                    if okRoute and type(routeID) == "number" and routeID >= 0 then
                        isRoute = true
                    end

                    if isRoute then
                        pcall(function() folderID = row.FolderID end)
                        pcall(function()
                            routeName = row.NameData and row.NameData.Text or nil
                        end)
                        pcall(function() usedInGroup = row.IsUsedInRouteGroup end)

                        local rec = {
                            name = routeName or ("Route " .. tostring(routeID)),
                            routeID = routeID,
                            folderID = folderID,
                            groupName = currentGroupName,
                        }

                        if usedInGroup == true and folderID ~= nil and folderID ~= -1 then
                            ShipFinderTradeRouteRoutesByFolder[folderID] =
                                ShipFinderTradeRouteRoutesByFolder[folderID] or {}
                            table.insert(ShipFinderTradeRouteRoutesByFolder[folderID], rec)
                        elseif folderID == -1 or usedInGroup ~= true then
                            table.insert(ShipFinderTradeRouteSoloRoutes, rec)
                        end

                        local key = string.lower(rec.name or "")
                        if key ~= "" then
                            ShipFinderTradeRouteRouteByName[key] =
                                ShipFinderTradeRouteRouteByName[key] or {}
                            table.insert(ShipFinderTradeRouteRouteByName[key], rec)
                        end
                    end
                end
            elseif seen then
                emptyTail = emptyTail + 1
            end
        elseif seen then
            emptyTail = emptyTail + 1
        end

        if seen and emptyTail >= 16 then
            break
        end
    end

    table.sort(ShipFinderTradeRouteGroups, function(a, b)
        return string.lower(a.name or "") < string.lower(b.name or "")
    end)

    for _, group in ipairs(ShipFinderTradeRouteGroups) do
        local routes = ShipFinderTradeRouteRoutesByFolder[group.folderID] or {}
        table.sort(routes, function(a, b)
            return string.lower(a.name or "") < string.lower(b.name or "")
        end)
    end

    table.sort(ShipFinderTradeRouteSoloRoutes, function(a, b)
        return string.lower(a.name or "") < string.lower(b.name or "")
    end)

    system.log(
        "[Ship Finder Route Cache 1.1.0] complete"
        .. " | groups=" .. tostring(#ShipFinderTradeRouteGroups)
        .. " | soloRoutes=" .. tostring(#ShipFinderTradeRouteSoloRoutes)
    )

    for _, g in ipairs(ShipFinderTradeRouteGroups) do
        system.log(
            "[Ship Finder Route Cache 1.1.0] group"
            .. " | name=" .. tostring(g.name)
            .. " | folderID=" .. tostring(g.folderID)
            .. " | routes=" .. tostring(#(ShipFinderTradeRouteRoutesByFolder[g.folderID] or {}))
        )
    end

    return true
end

-- Forward declarations required by the native TradeRoute state machine.
-- These functions are used above their implementation point.
local directOpenPending
local directOpenAttempt
local DIRECT_OPEN_MAX_ATTEMPTS
local tryDirectOpenGovernorRequest


-- ============================================================================
-- Ships by Island foundation probe
--
-- Goal:
--   Find the cheapest native route -> island source before implementing the
--   public Island -> Ships menu. This deliberately does NOT infer anything
--   from player ship names or route names.
--
-- First candidate:
--   TradeRouteData.TradeRouteItems (PhoenixArray<halo::CIconData>)
--
-- The probe is read-only and samples only a few active routes in the current
-- province, so it adds virtually no visible delay.
-- ============================================================================
local function runShipFinderIslandRouteItemsProbe()
    local PREFIX = "[Ship Finder Island RouteItems Probe 1.1.0]"

    local overview = ui
        and ui.Scenes
        and ui.Scenes.TradeRoute
        and ui.Scenes.TradeRoute.TradeOverview
        or nil

    local array = overview
        and overview.OverviewListData
        and overview.OverviewListData.ArrayData
        or nil

    if not array then
        system.log(PREFIX .. " ABORT | overview array unavailable")
        return
    end

    -- Current-province, active trade routes are derived from actual ships.
    local activeRouteNames = {}
    local activeShipCount = 0

    local okShips, ships = pcall(function()
        return Scripts:GetObjectGroupByProperty(Properties.ShipModuleOwner)
    end)

    if okShips and ships then
        for _, object in pairs(ships) do
            local tr = nil
            pcall(function() tr = object.TradeRouteVehicle end)

            if tr then
                local assigned = false
                local paused = false
                local routeName = nil

                pcall(function() assigned = tr.IsAssignedOnTradeRoute == true end)
                pcall(function() paused = tr.IsPaused == true end)
                pcall(function() routeName = tr.RouteName end)

                if assigned and not paused and routeName ~= nil then
                    activeRouteNames[tostring(routeName)] = true
                    activeShipCount = activeShipCount + 1
                end
            end
        end
    end

    local iconArrayHelper =
        halo and halo["PhoenixArray<halo::CIconData>"] or nil

    local candidates = {}

    for i = 0, 511 do
        local row = array[i]
        if row ~= nil then
            local routeID = nil
            local routeName = nil
            local items = nil

            pcall(function() routeID = row.RouteID end)
            pcall(function()
                routeName = row.NameData and row.NameData.Text or nil
            end)
            pcall(function() items = row.TradeRouteItems end)

            if type(routeID) == "number"
                and routeID >= 0
                and routeName ~= nil
                and activeRouteNames[tostring(routeName)]
                and items ~= nil
            then
                local size = -1

                if iconArrayHelper and iconArrayHelper.GetSize then
                    pcall(function()
                        size = iconArrayHelper.GetSize(items)
                    end)
                end

                candidates[#candidates + 1] = {
                    rowIndex = i,
                    routeID = routeID,
                    routeName = tostring(routeName),
                    items = items,
                    size = size,
                }
            end
        end
    end

    table.sort(candidates, function(a, b)
        if a.size ~= b.size then
            return a.size > b.size
        end
        if a.routeName ~= b.routeName then
            return a.routeName:lower() < b.routeName:lower()
        end
        return a.routeID < b.routeID
    end)

    system.log(
        PREFIX
        .. " START"
        .. " | activeShips=" .. tostring(activeShipCount)
        .. " | matchedActiveRouteRows=" .. tostring(#candidates)
        .. " | sampleStrategy=largest TradeRouteItems arrays first"
    )

    local sampleCount = math.min(#candidates, 5)
    local typeInfoLogged = false

    for n = 1, sampleCount do
        local rec = candidates[n]

        system.log(
            PREFIX
            .. " ROUTE"
            .. " | sample=" .. tostring(n)
            .. " | overviewIndex=" .. tostring(rec.rowIndex)
            .. " | routeID=" .. tostring(rec.routeID)
            .. " | routeName=" .. tostring(rec.routeName)
            .. " | TradeRouteItemsSize=" .. tostring(rec.size)
            .. " | itemsType=" .. tostring(type(rec.items))
            .. " | itemsValue=" .. tostring(rec.items)
        )

        if rec.size and rec.size > 0
            and iconArrayHelper
            and iconArrayHelper.GetElement
        then
            local maxItems = math.min(rec.size, 8)

            for k = 0, maxItems - 1 do
                local icon = nil
                local getOk, getErr = pcall(function()
                    icon = iconArrayHelper.GetElement(rec.items, k)
                end)

                system.log(
                    PREFIX
                    .. " ITEM"
                    .. " | routeID=" .. tostring(rec.routeID)
                    .. " | routeName=" .. tostring(rec.routeName)
                    .. " | itemIndex=" .. tostring(k)
                    .. " | getSuccess=" .. tostring(getOk)
                    .. " | type=" .. tostring(type(icon))
                    .. " | value=" .. tostring(icon)
                    .. " | error=" .. tostring(getErr)
                )

                if icon ~= nil then
                    if not typeInfoLogged then
                        typeInfoLogged = true

                        local helpOk, helpValue = pcall(function()
                            return help(icon)
                        end)
                        system.log(
                            PREFIX
                            .. " ICON HELP"
                            .. " | success=" .. tostring(helpOk)
                            .. " | value=" .. tostring(helpValue)
                        )

                        local tiOk, tiValue = pcall(function()
                            return getTypeInfo(icon)
                        end)
                        system.log(
                            PREFIX
                            .. " ICON TYPEINFO"
                            .. " | success=" .. tostring(tiOk)
                            .. " | value=" .. tostring(tiValue)
                        )
                    end

                    local props = {
                        "Icon",
                        "IconData",
                        "IconGUID",
                        "IconGuid",
                        "Guid",
                        "GUID",
                        "RefGuid",
                        "InfoTip",
                        "InfoTipData",
                        "Text",
                        "Name",
                        "NameData",
                        "Label",
                        "Title",
                        "Value",
                        "Amount",
                        "Filename",
                        "IconFilename",
                        "Texture",
                        "Sprite",
                        "ContextData",
                    }

                    for _, prop in ipairs(props) do
                        local value = nil
                        local ok = pcall(function()
                            value = icon[prop]
                        end)

                        if ok and value ~= nil then
                            system.log(
                                PREFIX
                                .. " ITEM PROPERTY"
                                .. " | routeID=" .. tostring(rec.routeID)
                                .. " | itemIndex=" .. tostring(k)
                                .. " | name=" .. tostring(prop)
                                .. " | type=" .. tostring(type(value))
                                .. " | value=" .. tostring(value)
                            )
                        end
                    end
                end
            end
        end
    end

    system.log(
        PREFIX
        .. " COMPLETE"
        .. " | sampledRoutes=" .. tostring(sampleCount)
        .. " | next=determine whether overview icons expose native station/island identity"
    )
end



-- ============================================================================
-- Ships by Island: direct route -> station probe
--
-- v1.1.52 proved that TradeRouteData.TradeRouteItems contains cargo icons only.
-- This probe tests the much more promising backend path without opening each
-- route in the editor:
--
--   TradeRoute.get():GetRoute(routeID):GetStation(stationID)
--
-- It also checks whether TradeGoodSelection.TradeRouteGoodData already exposes
-- a stationID -> islandName dictionary while the normal Trade Route overview is
-- open. If both pieces work, production Ships by Island can scan many routes in
-- one Lua pass instead of opening 70+ route editors one by one.
-- ============================================================================
local function runShipFinderIslandDirectStationProbe()
    local PREFIX = "[Ship Finder Island Direct Station Probe 1.1.0]"

    local manager = nil
    local managerOk, managerErr = pcall(function()
        if TradeRoute and type(TradeRoute.get) == "function" then
            manager = TradeRoute.get()
        end
    end)

    system.log(
        PREFIX
        .. " START"
        .. " | managerLookupSuccess=" .. tostring(managerOk)
        .. " | manager=" .. tostring(manager)
        .. " | managerError=" .. tostring(managerErr)
    )

    if manager == nil then
        system.log(PREFIX .. " ABORT | TradeRoute manager unavailable")
        return
    end

    -- 1) Probe the overview's station list as a possible native station-name map.
    local selection = ui
        and ui.Scenes
        and ui.Scenes.TradeRoute
        and ui.Scenes.TradeRoute.TradeGoodSelection
        or nil

    local stationArray = nil
    if selection ~= nil then
        pcall(function()
            stationArray = selection.TradeRouteGoodData
        end)
    end

    local stationHelper = halo
        and halo["PhoenixArray<halo::CTradeRouteGoodData>"]
        or nil

    local stationArraySize = -1
    if stationArray ~= nil and stationHelper ~= nil and stationHelper.GetSize then
        pcall(function()
            stationArraySize = stationHelper.GetSize(stationArray)
        end)
    end

    system.log(
        PREFIX
        .. " STATION MAP SURFACE"
        .. " | selectionPresent=" .. tostring(selection ~= nil)
        .. " | arrayPresent=" .. tostring(stationArray ~= nil)
        .. " | helperPresent=" .. tostring(stationHelper ~= nil)
        .. " | size=" .. tostring(stationArraySize)
        .. " | array=" .. tostring(stationArray)
    )

    local stationNameByID = {}
    local stationRowsWithName = 0
    local stationRowsWithID = 0
    local firstStationRowIntrospected = false

    if stationArraySize and stationArraySize > 0
        and stationHelper and stationHelper.GetElement
    then
        for i = 0, math.min(stationArraySize - 1, 63) do
            local row = nil
            local getOk, getErr = pcall(function()
                row = stationHelper.GetElement(stationArray, i)
            end)

            if getOk and row ~= nil then
                local islandName = nil
                local stationID = nil
                local foundIDField = nil

                pcall(function() islandName = row.IslandName end)

                local idFields = {
                    "StationID", "StationId", "stationID", "stationId",
                    "ID", "Id", "Index", "StationIndex"
                }
                for _, field in ipairs(idFields) do
                    if stationID == nil then
                        local value = nil
                        local ok = pcall(function() value = row[field] end)
                        if ok and type(value) == "number" then
                            stationID = value
                            foundIDField = field
                        end
                    end
                end

                if islandName ~= nil and tostring(islandName) ~= "" then
                    stationRowsWithName = stationRowsWithName + 1
                end
                if stationID ~= nil then
                    stationRowsWithID = stationRowsWithID + 1
                end

                if stationID ~= nil and islandName ~= nil and tostring(islandName) ~= "" then
                    stationNameByID[stationID] = tostring(islandName)
                end

                if i < 12 or (stationID ~= nil and islandName ~= nil) then
                    system.log(
                        PREFIX
                        .. " STATION MAP ROW"
                        .. " | arrayIndex=" .. tostring(i)
                        .. " | islandName=" .. tostring(islandName)
                        .. " | stationID=" .. tostring(stationID)
                        .. " | idField=" .. tostring(foundIDField)
                        .. " | rowType=" .. tostring(type(row))
                        .. " | row=" .. tostring(row)
                        .. " | getError=" .. tostring(getErr)
                    )
                end

                if not firstStationRowIntrospected then
                    firstStationRowIntrospected = true
                    local helpOk, helpValue = pcall(function() return help(row) end)
                    system.log(
                        PREFIX .. " STATION ROW HELP"
                        .. " | success=" .. tostring(helpOk)
                        .. " | value=" .. tostring(helpValue)
                    )
                    local tiOk, tiValue = pcall(function() return getTypeInfo(row) end)
                    system.log(
                        PREFIX .. " STATION ROW TYPEINFO"
                        .. " | success=" .. tostring(tiOk)
                        .. " | value=" .. tostring(tiValue)
                    )
                end
            end
        end
    end

    system.log(
        PREFIX
        .. " STATION MAP SUMMARY"
        .. " | rowsWithName=" .. tostring(stationRowsWithName)
        .. " | rowsWithNumericID=" .. tostring(stationRowsWithID)
    )

    -- 2) Find active current-province routes from the actual ships, then match
    --    those names to exact native route IDs from the expanded overview.
    local activeRouteNames = {}
    local activeShipCount = 0
    local okShips, ships = pcall(function()
        return Scripts:GetObjectGroupByProperty(Properties.ShipModuleOwner)
    end)

    if okShips and ships then
        for _, object in pairs(ships) do
            local tr = nil
            pcall(function() tr = object.TradeRouteVehicle end)
            if tr then
                local assigned, paused, routeName = false, false, nil
                pcall(function() assigned = tr.IsAssignedOnTradeRoute == true end)
                pcall(function() paused = tr.IsPaused == true end)
                pcall(function() routeName = tr.RouteName end)
                if assigned and not paused and routeName ~= nil then
                    activeRouteNames[tostring(routeName)] = true
                    activeShipCount = activeShipCount + 1
                end
            end
        end
    end

    local overview = ui
        and ui.Scenes
        and ui.Scenes.TradeRoute
        and ui.Scenes.TradeRoute.TradeOverview
        or nil
    local overviewArray = overview
        and overview.OverviewListData
        and overview.OverviewListData.ArrayData
        or nil

    local candidates = {}
    if overviewArray ~= nil then
        for i = 0, 511 do
            local row = overviewArray[i]
            if row ~= nil then
                local routeID, routeName = nil, nil
                pcall(function() routeID = row.RouteID end)
                pcall(function()
                    routeName = row.NameData and row.NameData.Text or nil
                end)
                if type(routeID) == "number" and routeID >= 0
                    and routeName ~= nil and activeRouteNames[tostring(routeName)]
                then
                    candidates[#candidates + 1] = {
                        routeID = routeID,
                        routeName = tostring(routeName),
                        overviewIndex = i,
                    }
                end
            end
        end
    end

    table.sort(candidates, function(a, b)
        if a.routeID ~= b.routeID then return a.routeID < b.routeID end
        return a.routeName:lower() < b.routeName:lower()
    end)

    system.log(
        PREFIX
        .. " ROUTE CANDIDATES"
        .. " | activeShips=" .. tostring(activeShipCount)
        .. " | matchedRoutes=" .. tostring(#candidates)
    )

    -- Sample three backend routes. Direct GetStation calls are read-only and
    -- require no route-editor transition.
    local sampleCount = math.min(#candidates, 3)
    local routeTypeInfoLogged = false
    local stationTypeInfoLogged = false

    for n = 1, sampleCount do
        local rec = candidates[n]
        local route = nil
        local getRouteOk, getRouteErr = pcall(function()
            route = manager:GetRoute(rec.routeID)
        end)

        local liveName = nil
        if route ~= nil then
            pcall(function() liveName = route.Name end)
        end

        system.log(
            PREFIX
            .. " ROUTE"
            .. " | sample=" .. tostring(n)
            .. " | routeID=" .. tostring(rec.routeID)
            .. " | overviewName=" .. tostring(rec.routeName)
            .. " | getRouteSuccess=" .. tostring(getRouteOk)
            .. " | route=" .. tostring(route)
            .. " | liveName=" .. tostring(liveName)
            .. " | error=" .. tostring(getRouteErr)
        )

        if route ~= nil then
            if not routeTypeInfoLogged then
                routeTypeInfoLogged = true
                local helpOk, helpValue = pcall(function() return help(route) end)
                system.log(
                    PREFIX .. " ROUTE HELP"
                    .. " | success=" .. tostring(helpOk)
                    .. " | value=" .. tostring(helpValue)
                )
                local tiOk, tiValue = pcall(function() return getTypeInfo(route) end)
                system.log(
                    PREFIX .. " ROUTE TYPEINFO"
                    .. " | success=" .. tostring(tiOk)
                    .. " | value=" .. tostring(tiValue)
                )
            end

            local getStationFn = nil
            pcall(function() getStationFn = route.GetStation end)

            system.log(
                PREFIX
                .. " GETSTATION SURFACE"
                .. " | routeID=" .. tostring(rec.routeID)
                .. " | functionType=" .. tostring(type(getStationFn))
                .. " | functionValue=" .. tostring(getStationFn)
            )

            local callsSucceeded = 0
            local validStations = 0
            local firstCallError = nil

            if type(getStationFn) == "function" then
                for stationID = 0, 63 do
                    local station = nil
                    local callOk, callErr = pcall(function()
                        station = route:GetStation(stationID)
                    end)

                    if callOk then
                        callsSucceeded = callsSucceeded + 1
                    elseif firstCallError == nil then
                        firstCallError = tostring(callErr)
                    end

                    if callOk and station ~= nil then
                        local valid = false
                        local validOk = pcall(function()
                            if type(station.isValid) == "function" then
                                valid = station:isValid() == true
                            else
                                valid = not string.find(tostring(station), "null", 1, true)
                            end
                        end)

                        if validOk and valid then
                            validStations = validStations + 1

                            system.log(
                                PREFIX
                                .. " ROUTE STATION"
                                .. " | routeID=" .. tostring(rec.routeID)
                                .. " | routeName=" .. tostring(rec.routeName)
                                .. " | getStationArg=" .. tostring(stationID)
                                .. " | overviewIslandName=" .. tostring(stationNameByID[stationID])
                                .. " | station=" .. tostring(station)
                            )

                            if not stationTypeInfoLogged then
                                stationTypeInfoLogged = true

                                local helpOk, helpValue = pcall(function()
                                    return help(station)
                                end)
                                system.log(
                                    PREFIX
                                    .. " STATION HELP"
                                    .. " | success=" .. tostring(helpOk)
                                    .. " | value=" .. tostring(helpValue)
                                )

                                local tiOk, tiValue = pcall(function()
                                    return getTypeInfo(station)
                                end)
                                system.log(
                                    PREFIX
                                    .. " STATION TYPEINFO"
                                    .. " | success=" .. tostring(tiOk)
                                    .. " | value=" .. tostring(tiValue)
                                )

                                -- Probe plausible scalar/object surfaces. All reads are protected
                                -- and read-only. The TYPEINFO output tells us which one is native.
                                local props = {
                                    "ID", "Id",
                                    "StationID", "StationId",
                                    "Index", "StationIndex",
                                    "GUID", "Guid", "RefGUID", "RefGuid",
                                    "ObjectID", "ObjectId",
                                    "SessionID", "SessionId",
                                    "IslandID", "IslandId",
                                    "IslandGUID", "IslandGuid",
                                    "IslandName",
                                    "Name",
                                    "NameData",
                                    "StationName",
                                    "TargetID", "TargetId",
                                    "KontorID", "KontorId",
                                    "HarborID", "HarbourID",
                                    "PierID", "PierId",
                                    "TradePostID", "TradePostId",
                                    "OwnerID", "OwnerId",
                                    "Session", "Island", "Object",
                                    "Kontor", "Harbor", "Harbour",
                                    "Pier", "TradePost",
                                    "Position", "WorldPosition",
                                }

                                for _, prop in ipairs(props) do
                                    local value = nil
                                    local ok = pcall(function()
                                        value = station[prop]
                                    end)

                                    if ok and value ~= nil then
                                        system.log(
                                            PREFIX
                                            .. " STATION PROPERTY"
                                            .. " | name=" .. tostring(prop)
                                            .. " | type=" .. tostring(type(value))
                                            .. " | value=" .. tostring(value)
                                        )

                                        -- If a nested userdata/object is exposed, inspect only the
                                        -- first one so the log stays small.
                                        if type(value) == "userdata" then
                                            local nestedHelpOk, nestedHelp = pcall(function()
                                                return help(value)
                                            end)
                                            system.log(
                                                PREFIX
                                                .. " STATION NESTED HELP"
                                                .. " | property=" .. tostring(prop)
                                                .. " | success=" .. tostring(nestedHelpOk)
                                                .. " | value=" .. tostring(nestedHelp)
                                            )

                                            local nestedTiOk, nestedTi = pcall(function()
                                                return getTypeInfo(value)
                                            end)
                                            system.log(
                                                PREFIX
                                                .. " STATION NESTED TYPEINFO"
                                                .. " | property=" .. tostring(prop)
                                                .. " | success=" .. tostring(nestedTiOk)
                                                .. " | value=" .. tostring(nestedTi)
                                            )
                                            break
                                        end
                                    end
                                end

                                -- Also test likely zero-argument methods if they exist.
                                local methods = {
                                    "GetID", "GetStationID", "GetObjectID",
                                    "GetSessionID", "GetIslandID", "GetIslandName",
                                    "GetName", "GetObject", "GetIsland",
                                    "GetKontor", "GetHarbor", "GetHarbour",
                                    "GetPier", "GetPosition",
                                }

                                for _, methodName in ipairs(methods) do
                                    local fn = nil
                                    local lookupOk = pcall(function()
                                        fn = station[methodName]
                                    end)

                                    if lookupOk and type(fn) == "function" then
                                        local result = nil
                                        local callOk, callErr = pcall(function()
                                            result = fn(station)
                                        end)

                                        system.log(
                                            PREFIX
                                            .. " STATION METHOD"
                                            .. " | name=" .. tostring(methodName)
                                            .. " | success=" .. tostring(callOk)
                                            .. " | type=" .. tostring(type(result))
                                            .. " | value=" .. tostring(result)
                                            .. " | error=" .. tostring(callErr)
                                        )
                                    end
                                end
                            end
                        end
                    end
                end
            end

            system.log(
                PREFIX
                .. " ROUTE STATION SUMMARY"
                .. " | routeID=" .. tostring(rec.routeID)
                .. " | routeName=" .. tostring(rec.routeName)
                .. " | callsSucceeded=" .. tostring(callsSucceeded)
                .. " | validStations=" .. tostring(validStations)
                .. " | firstCallError=" .. tostring(firstCallError)
            )
        end
    end

    system.log(
        PREFIX
        .. " COMPLETE"
        .. " | sampledRoutes=" .. tostring(sampleCount)
        .. " | purpose=introspect CSessionTradeRouteStationInfo for native island identity"
    )
end


-- Shared Ships-by-Island probe state.
-- Must be declared before the probe functions so Lua closures and the native
-- TradeRoute state machine reference the same local variables.
local islandFocusProbePending = false
local islandFocusProbeRouteName = nil
local islandFocusProbeRouteID = nil
local islandFocusProbeTicks = 0
local islandSequentialProbeRoutes = {}
local islandSequentialProbeIndex = 0
local islandSequentialProbePhase = 0
local islandSequentialProbeStartClock = nil
local islandFullIndex = {}
local islandFullIndexRouteCount = 0
local islandScanRequested = false
local islandScanStartDelay = 0
local islandScanReason = nil
local islandScanMarkerHandled = false
local islandReportMarkerHandled = false
local ISLAND_REPORT_STORYLINE = 2099200

-- ============================================================================
-- Ships by Island: focus one native route and read the same station-name array
-- that Goods Finder previously proved exposes IslandName + StationID.
-- ============================================================================

local function islandFullIndexReset()
    islandFullIndex = {}
    islandFullIndexRouteCount = 0

    if ShipFinderIslandCache and ShipFinderIslandCache.invalidate then
        ShipFinderIslandCache.invalidate("new full scan started")
    end
end

local function islandFullIndexShipsForRoute(routeName)
    local ships = {}

    for _, object in pairs(Scripts:GetObjectGroupByProperty(Properties.ShipModuleOwner) or {}) do
        local tr = object.TradeRouteVehicle
        if tr
            and tr.IsAssignedOnTradeRoute
            and not tr.IsPaused
            and tr.RouteName ~= nil
            and tostring(tr.RouteName) == tostring(routeName)
        then
            local shipName = nil
            pcall(function()
                shipName = object.Nameable and object.Nameable.Name or nil
            end)
            if shipName == nil or tostring(shipName) == "" then
                pcall(function() shipName = object.Name end)
            end
            local shipIDText = ""
            pcall(function()
                shipIDText = tostring(object.ID)
            end)

            ships[#ships + 1] = {
                name = tostring(shipName or object),
                objectKey = tostring(object),
                idText = shipIDText,
                routeName = tostring(routeName or ""),
            }
        end
    end

    table.sort(ships, function(a, b)
        return string.lower(a.name) < string.lower(b.name)
    end)

    return ships
end

local function islandFullIndexAddRoute(routeID, routeName, islandEntries)
    islandFullIndexRouteCount = islandFullIndexRouteCount + 1
    local ships = islandFullIndexShipsForRoute(routeName)

    for _, island in ipairs(islandEntries or {}) do
        local name = island.name and tostring(island.name) or nil
        if name and name ~= "" then
            local rec = islandFullIndex[name]
            if not rec then
                rec = {
                    name = name,
                    routes = {},
                    ships = {},
                    shipSeen = {},
                }
                islandFullIndex[name] = rec
            end

            rec.routes[#rec.routes + 1] = {
                routeID = routeID,
                routeName = tostring(routeName),
            }

            for _, ship in ipairs(ships) do
                local key = ship.name .. "|" .. ship.objectKey
                if not rec.shipSeen[key] then
                    rec.shipSeen[key] = true
                    rec.ships[#rec.ships + 1] = ship
                end
            end
        end
    end
end

local function islandFullIndexLogSummary()
    local PREFIX = "[Ship Finder Island Full Index 1.1.0]"
    local names = {}
    local allShipKeys = {}

    for name in pairs(islandFullIndex) do
        names[#names + 1] = name
    end

    table.sort(names, function(a, b)
        return string.lower(a) < string.lower(b)
    end)

    system.log(
        PREFIX
        .. " SUMMARY"
        .. " | islands=" .. tostring(#names)
        .. " | routesScanned=" .. tostring(islandFullIndexRouteCount)
    )

    for i, name in ipairs(names) do
        local rec = islandFullIndex[name]
        table.sort(rec.ships, function(a, b)
            return string.lower(a.name) < string.lower(b.name)
        end)

        local shipNames = {}
        for _, ship in ipairs(rec.ships) do
            shipNames[#shipNames + 1] = ship.name
            allShipKeys[ship.name .. "|" .. ship.objectKey] = true
        end

        system.log(
            PREFIX
            .. " ISLAND"
            .. " | index=" .. tostring(i)
            .. " | name=" .. tostring(name)
            .. " | routes=" .. tostring(#rec.routes)
            .. " | ships=" .. tostring(#rec.ships)
            .. " | shipNames=" .. table.concat(shipNames, ",")
        )
    end

    local distinctShips = 0
    for _ in pairs(allShipKeys) do
        distinctShips = distinctShips + 1
    end

    system.log(
        PREFIX
        .. " COMPLETE"
        .. " | islands=" .. tostring(#names)
        .. " | routesScanned=" .. tostring(islandFullIndexRouteCount)
        .. " | distinctShipsAcrossIndex=" .. tostring(distinctShips)
    )
end

local function startIslandFocusedRouteProbe()
    local PREFIX = "[Ship Finder Island Focused Route Probe 1.1.0]"

    islandFullIndexReset()

    local arr = ui
        and ui.Scenes
        and ui.Scenes.TradeRoute
        and ui.Scenes.TradeRoute.TradeOverview
        and ui.Scenes.TradeRoute.TradeOverview.OverviewListData
        and ui.Scenes.TradeRoute.TradeOverview.OverviewListData.ArrayData
        or nil

    if not arr then
        system.log(PREFIX .. " ABORT | overview array unavailable")
        return false
    end

    local activeNames = {}
    for _, object in pairs(Scripts:GetObjectGroupByProperty(Properties.ShipModuleOwner) or {}) do
        local tr = object.TradeRouteVehicle
        if tr and tr.IsAssignedOnTradeRoute and not tr.IsPaused and tr.RouteName ~= nil then
            activeNames[tostring(tr.RouteName)] = true
        end
    end

    for i = 0, 511 do
        local row = arr[i]
        if row ~= nil then
            local routeID, routeName, button = nil, nil, nil
            pcall(function() routeID = row.RouteID end)
            pcall(function() routeName = row.NameData and row.NameData.Text or nil end)
            pcall(function() button = row.ButtonData end)

            if type(routeID) == "number"
                and routeID >= 0
                and routeName ~= nil
                and activeNames[tostring(routeName)]
            then
                local pressed = false
                local result = nil

                if button ~= nil then
                    local fn = nil
                    pcall(function() fn = button.PrimaryButtonPressed end)
                    if type(fn) == "function" then
                        local ok, r = pcall(function()
                            return button:PrimaryButtonPressed()
                        end)
                        pressed = ok
                        result = r
                    end
                end

                if not pressed then
                    local fn = nil
                    pcall(function() fn = row.PrimaryButtonPressed end)
                    if type(fn) == "function" then
                        local ok, r = pcall(function()
                            return row:PrimaryButtonPressed()
                        end)
                        pressed = ok
                        result = r
                    end
                end

                system.log(
                    PREFIX
                    .. " FOCUS REQUEST"
                    .. " | overviewIndex=" .. tostring(i)
                    .. " | routeID=" .. tostring(routeID)
                    .. " | routeName=" .. tostring(routeName)
                    .. " | buttonPresent=" .. tostring(button ~= nil)
                    .. " | success=" .. tostring(pressed)
                    .. " | result=" .. tostring(result)
                )

                if pressed then
                    islandFocusProbePending = true
                    islandFocusProbeRouteName = tostring(routeName)
                    islandFocusProbeRouteID = routeID
                    islandFocusProbeTicks = 0

                    system.log(
                        PREFIX
                        .. " ARMED"
                        .. " | pending=" .. tostring(islandFocusProbePending)
                        .. " | routeID=" .. tostring(islandFocusProbeRouteID)
                        .. " | routeName=" .. tostring(islandFocusProbeRouteName)
                    )

                    return true
                end
            end
        end
    end

    system.log(PREFIX .. " ABORT | no focusable active route")
    return false
end

local function tickIslandFocusedRouteProbe()
    if not islandFocusProbePending then
        return false
    end

    local PREFIX = "[Ship Finder Island Focused Route Probe 1.1.0]"

    if islandSequentialProbePhase > 0 and #islandSequentialProbeRoutes > 0 then
        local rec = islandSequentialProbeRoutes[islandSequentialProbeIndex]

        if not rec then
            local elapsed = nil
            if islandSequentialProbeStartClock and os and os.clock then
                elapsed = os.clock() - islandSequentialProbeStartClock
            end

            system.log(
                PREFIX
                .. " PIPELINE COMPLETE"
                .. " | tested=" .. tostring(#islandSequentialProbeRoutes)
                .. " | cpuClockElapsed=" .. tostring(elapsed)
                .. " | model=read current route and focus next route in same UI tick"
            )

            islandFullIndexLogSummary()

            if ShipFinderIslandCache and ShipFinderIslandCache.commit then
                ShipFinderIslandCache.commit(
                    islandFullIndex,
                    islandFullIndexRouteCount
                )
            end

            islandSequentialProbeRoutes = {}
            islandSequentialProbeIndex = 0
            islandSequentialProbePhase = 0
            islandFocusProbePending = false
            return true
        end

        -- Phase 1 happens only once: focus the first queued route.
        if islandSequentialProbePhase == 1 then
            local pressed = false
            local fn = nil
            pcall(function() fn = rec.row.PrimaryButtonPressed end)

            if type(fn) == "function" then
                pressed = pcall(function()
                    rec.row:PrimaryButtonPressed()
                end)
            else
                local btn = nil
                pcall(function() btn = rec.row.ButtonData end)
                if btn ~= nil then
                    local btnFn = nil
                    pcall(function() btnFn = btn.PrimaryButtonPressed end)
                    if type(btnFn) == "function" then
                        pressed = pcall(function()
                            btn:PrimaryButtonPressed()
                        end)
                    end
                end
            end

            system.log(
                PREFIX
                .. " PIPELINE PRIME"
                .. " | n=" .. tostring(islandSequentialProbeIndex)
                .. " | routeID=" .. tostring(rec.routeID)
                .. " | routeName=" .. tostring(rec.routeName)
                .. " | success=" .. tostring(pressed)
            )

            islandSequentialProbePhase = 2
            return true
        end

        -- From here on, every tick does both jobs:
        --   1) read the route focused on the previous tick
        --   2) immediately focus the next route before returning
        local selection = ui
            and ui.Scenes
            and ui.Scenes.TradeRoute
            and ui.Scenes.TradeRoute.TradeGoodSelection
            or nil
        local data = selection and selection.TradeRouteGoodData or nil
        local helper = halo and halo["PhoenixArray<halo::CTradeRouteGoodData>"] or nil
        local size = -1

        if data and helper and helper.GetSize then
            pcall(function() size = helper.GetSize(data) end)
        end

        local islands = {}
        local islandEntries = {}

        if size > 0 and helper and helper.GetElement then
            for i = 0, size - 1 do
                local e = nil
                pcall(function() e = helper.GetElement(data, i) end)
                if e ~= nil then
                    local islandName, stationID = nil, nil
                    pcall(function() islandName = e.IslandName end)
                    pcall(function() stationID = e.StationID end)

                    islandEntries[#islandEntries + 1] = {
                        name = islandName,
                        stationID = stationID,
                    }

                    islands[#islands + 1] =
                        tostring(islandName) .. "#" .. tostring(stationID)
                end
            end
        end

        islandFullIndexAddRoute(rec.routeID, rec.routeName, islandEntries)

        system.log(
            PREFIX
            .. " PIPELINE READ"
            .. " | n=" .. tostring(islandSequentialProbeIndex)
            .. " | expectedRouteID=" .. tostring(rec.routeID)
            .. " | expectedRouteName=" .. tostring(rec.routeName)
            .. " | size=" .. tostring(size)
            .. " | islands=" .. table.concat(islands, ",")
        )

        islandSequentialProbeIndex = islandSequentialProbeIndex + 1
        local nextRec = islandSequentialProbeRoutes[islandSequentialProbeIndex]

        if nextRec then
            local pressed = false
            local fn = nil
            pcall(function() fn = nextRec.row.PrimaryButtonPressed end)

            if type(fn) == "function" then
                pressed = pcall(function()
                    nextRec.row:PrimaryButtonPressed()
                end)
            else
                local btn = nil
                pcall(function() btn = nextRec.row.ButtonData end)
                if btn ~= nil then
                    local btnFn = nil
                    pcall(function() btnFn = btn.PrimaryButtonPressed end)
                    if type(btnFn) == "function" then
                        pressed = pcall(function()
                            btn:PrimaryButtonPressed()
                        end)
                    end
                end
            end

            system.log(
                PREFIX
                .. " PIPELINE NEXT"
                .. " | n=" .. tostring(islandSequentialProbeIndex)
                .. " | routeID=" .. tostring(nextRec.routeID)
                .. " | routeName=" .. tostring(nextRec.routeName)
                .. " | success=" .. tostring(pressed)
            )
        end

        return true
    end

    islandFocusProbeTicks = islandFocusProbeTicks + 1
    local selection = ui
        and ui.Scenes
        and ui.Scenes.TradeRoute
        and ui.Scenes.TradeRoute.TradeGoodSelection
        or nil

    local data = selection and selection.TradeRouteGoodData or nil
    local helper = halo and halo["PhoenixArray<halo::CTradeRouteGoodData>"] or nil
    local size = -1

    if data and helper and helper.GetSize then
        pcall(function() size = helper.GetSize(data) end)
    end

    system.log(
        PREFIX
        .. " TICK"
        .. " | tick=" .. tostring(islandFocusProbeTicks)
        .. " | routeID=" .. tostring(islandFocusProbeRouteID)
        .. " | routeName=" .. tostring(islandFocusProbeRouteName)
        .. " | selectionPresent=" .. tostring(selection ~= nil)
        .. " | dataPresent=" .. tostring(data ~= nil)
        .. " | size=" .. tostring(size)
    )

    if size > 0 and helper and helper.GetElement then
        local initialIslandEntries = {}

        for i = 0, size - 1 do
            local entry = nil
            local ok = pcall(function()
                entry = helper.GetElement(data, i)
            end)

            if ok and entry ~= nil then
                local islandName, stationID = nil, nil
                pcall(function() islandName = entry.IslandName end)
                pcall(function() stationID = entry.StationID end)

                initialIslandEntries[#initialIslandEntries + 1] = {
                    name = islandName,
                    stationID = stationID,
                }

                system.log(
                    PREFIX
                    .. " STATION"
                    .. " | arrayIndex=" .. tostring(i)
                    .. " | islandName=" .. tostring(islandName)
                    .. " | stationID=" .. tostring(stationID)
                    .. " | entry=" .. tostring(entry)
                )
            end
        end

        islandFullIndexAddRoute(
            islandFocusProbeRouteID,
            islandFocusProbeRouteName,
            initialIslandEntries
        )

        -- Efficiency experiment v1.1.0:
        -- Same-tick route switching was proven stale in v1.1.57.
        -- Build a short queue of five additional active routes and process exactly
        -- one route per UI tick. This measures the real per-route cost and verifies
        -- that the island data updates correctly after each event-loop turn.
        islandSequentialProbeRoutes = {}

        local arr = ui
            and ui.Scenes
            and ui.Scenes.TradeRoute
            and ui.Scenes.TradeRoute.TradeOverview
            and ui.Scenes.TradeRoute.TradeOverview.OverviewListData
            and ui.Scenes.TradeRoute.TradeOverview.OverviewListData.ArrayData
            or nil

        local activeNames = {}
        for _, object in pairs(Scripts:GetObjectGroupByProperty(Properties.ShipModuleOwner) or {}) do
            local tr = object.TradeRouteVehicle
            if tr and tr.IsAssignedOnTradeRoute and not tr.IsPaused and tr.RouteName ~= nil then
                activeNames[tostring(tr.RouteName)] = true
            end
        end

        if arr then
            for overviewIndex = 0, 511 do
                local row = arr[overviewIndex]
                if row ~= nil then
                    local routeID, routeName = nil, nil
                    pcall(function() routeID = row.RouteID end)
                    pcall(function()
                        routeName = row.NameData and row.NameData.Text or nil
                    end)

                    if type(routeID) == "number"
                        and routeID >= 0
                        and routeName ~= nil
                        and activeNames[tostring(routeName)]
                        and routeID ~= islandFocusProbeRouteID
                    then
                        islandSequentialProbeRoutes[#islandSequentialProbeRoutes + 1] = {
                            row = row,
                            overviewIndex = overviewIndex,
                            routeID = routeID,
                            routeName = tostring(routeName),
                        }
                    end
                end
            end
        end

        islandSequentialProbeIndex = 1
        islandSequentialProbePhase = 1
        islandSequentialProbeStartClock = os and os.clock and os.clock() or nil

        system.log(
            PREFIX
            .. " SEQUENTIAL ARMED"
            .. " | routes=" .. tostring(#islandSequentialProbeRoutes)
            .. " | model=pipelined one UI tick per route after prime"
        )

        if #islandSequentialProbeRoutes == 0 then
            islandFocusProbePending = false
        end

        system.log(
            PREFIX
            .. " COMPLETE"
            .. " | routeID=" .. tostring(islandFocusProbeRouteID)
            .. " | routeName=" .. tostring(islandFocusProbeRouteName)
            .. " | stationRows=" .. tostring(size)
        )
        return true
    end

    if islandFocusProbeTicks >= 3 then
        islandFocusProbePending = false
        system.log(
            PREFIX
            .. " TIMEOUT"
            .. " | routeID=" .. tostring(islandFocusProbeRouteID)
            .. " | routeName=" .. tostring(islandFocusProbeRouteName)
            .. " | lastSize=" .. tostring(size)
        )
    end

    return true
end



-- ============================================================================
-- Ship Finder v1.5.0 on-demand production Attention detail
--
-- Ctrl+Alt+F no longer opens/scans the native Trade Route UI. The main menu
-- opens immediately. Only after Ships Needing Attention is selected and the
-- Governor NarrativeSequence has safely left do we start the native Trade
-- Route UI scan. Route-wide All Ships Paused is read directly; unresolved live
-- routes use real TradeRouteGoodData station rows read-only. No route settings
-- are changed.
-- ============================================================================
ShipFinderAttentionWarningDetailCache =
    ShipFinderAttentionWarningDetailCache or {}

ShipFinderAttentionWarningStatesProbe =
    ShipFinderAttentionWarningStatesProbe or {
        active = false,
        queue = {},
        index = 0,
        phase = "idle",
        focusedName = nil,
    }

function ShipFinderAttentionWarningStatesTruthy(value)
    if value == true then return true end
    if value == 1 then return true end
    local text = string.lower(tostring(value or ""))
    return text == "true" or text == "1"
end

function ShipFinderAttentionWarningStatesAdvanceRoute()
    local state = ShipFinderAttentionWarningStatesProbe
    state.index = state.index + 1

    if state.index > #state.queue then
        state.active = false
        state.phase = "done"

        local count = 0
        for _ in pairs(
            ShipFinderAttentionWarningDetailCache or {}
        ) do
            count = count + 1
        end

        system.log(
            "[Ship Finder Attention Detail 1.5.0] COMPLETE"
            .. " | routesDetailed=" .. tostring(count)
        )
        return true
    end

    state.phase = "focusRoute"
    ShipFinderAttentionWarningStatesFocusCurrent()
    return true
end

function ShipFinderAttentionWarningStatesStart()
    local state = ShipFinderAttentionWarningStatesProbe
    state.active = false
    state.queue = {}
    state.index = 0
    state.phase = "idle"
    state.focusedName = nil

    ShipFinderAttentionWarningDetailCache = {}

    local issueSnapshot =
        ShipFinderNativeIssueRouteCache
        or ShipFinderNativeIssueRouteSnapshot()

    -- Only collect expensive station detail for routes that can actually
    -- appear in the current province's Attention parchment and whose
    -- route-wide warning is not already solved by AllShipsPausedActive.
    local wanted = {}

    for _, object in pairs(
        Scripts:GetObjectGroupByProperty(Properties.ShipModuleOwner) or {}
    ) do
        local vehicle = object.TradeRouteVehicle
        local military =
            object.Unit and object.Unit.IsMilitaryUnit == true
        local assigned =
            vehicle and vehicle.IsAssignedOnTradeRoute == true
        local routeName =
            vehicle and vehicle.RouteName or nil

        if assigned
            and not military
            and routeName ~= nil
        then
            local key =
                ShipFinderNativeRouteKey(routeName)
            local issue = issueSnapshot[key]

            if issue ~= nil
                and issue.allShipsPaused ~= true
                and (tonumber(issue.activeErrorCount) or 0) > 0
            then
                wanted[key] = issue
            end
        end
    end

    local wantedCount = 0
    for _ in pairs(wanted) do
        wantedCount = wantedCount + 1
    end

    if wantedCount == 0 then
        system.log(
            "[Ship Finder Attention Detail 1.5.0] START"
            .. " | success=false"
            .. " | reason=no-live-unresolved-issue-routes"
        )
        return false
    end

    local arr = nil
    pcall(function()
        arr = ui
            and ui.Scenes
            and ui.Scenes.TradeRoute
            and ui.Scenes.TradeRoute.TradeOverview
            and ui.Scenes.TradeRoute.TradeOverview.OverviewListData
            and ui.Scenes.TradeRoute.TradeOverview.OverviewListData.ArrayData
            or nil
    end)

    if arr == nil then
        system.log(
            "[Ship Finder Attention Detail 1.5.0] START"
            .. " | success=false"
            .. " | reason=overview-array-missing"
        )
        return false
    end

    local seen = false
    local emptyTail = 0

    for i = 0, 511 do
        local okRow, row = pcall(function()
            return arr[i]
        end)

        if okRow and row ~= nil then
            local rowText = tostring(row)
            if string.find(rowText, "weak null", 1, true) == nil then
                seen = true
                emptyTail = 0

                local routeID, routeName = nil, nil
                pcall(function() routeID = row.RouteID end)
                pcall(function()
                    routeName =
                        row.NameData and row.NameData.Text or nil
                end)

                if type(routeID) == "number"
                    and routeID >= 0
                    and routeName ~= nil
                then
                    local key =
                        ShipFinderNativeRouteKey(tostring(routeName))

                    if wanted[key] ~= nil then
                        state.queue[#state.queue + 1] = {
                            row = row,
                            routeID = routeID,
                            routeName = tostring(routeName),
                        }
                    end
                end
            elseif seen then
                emptyTail = emptyTail + 1
            end
        elseif seen then
            emptyTail = emptyTail + 1
        end

        if seen and emptyTail >= 16 then break end
    end

    table.sort(state.queue, function(a, b)
        return string.lower(a.routeName or "")
            < string.lower(b.routeName or "")
    end)

    if #state.queue == 0 then
        system.log(
            "[Ship Finder Attention Detail 1.5.0] START"
            .. " | success=false"
            .. " | reason=no-live-issue-route-rows"
        )
        return false
    end

    state.active = true
    state.index = 1
    state.phase = "focusRoute"

    system.log(
        "[Ship Finder Attention Detail 1.5.0] START"
        .. " | success=true"
        .. " | liveUnresolvedRoutes="
        .. tostring(#state.queue)
        .. " | detail=warning-station-and-wait-setting"
    )

    return true
end

function ShipFinderAttentionWarningStatesFocusCurrent()
    local state = ShipFinderAttentionWarningStatesProbe
    local rec = state.queue[state.index]
    if rec == nil then return false end

    local pressed = false
    local errorText = ""

    local fn = nil
    pcall(function()
        fn = rec.row.PrimaryButtonPressed
    end)

    if type(fn) == "function" then
        local ok, err = pcall(function()
            return rec.row:PrimaryButtonPressed()
        end)
        pressed = ok
        errorText = tostring(err or "")
    else
        local button = nil
        pcall(function()
            button = rec.row.ButtonData
        end)

        local buttonFn = nil
        if button ~= nil then
            pcall(function()
                buttonFn = button.PrimaryButtonPressed
            end)
        end

        if type(buttonFn) == "function" then
            local ok, err = pcall(function()
                return button:PrimaryButtonPressed()
            end)
            pressed = ok
            errorText = tostring(err or "")
        end
    end

    state.focusedName = rec.routeName
    state.phase = "readRoute"

    if not pressed then
        system.log(
            "[Ship Finder Attention Detail 1.5.0] FOCUS FAILED"
            .. " | index=" .. tostring(state.index)
            .. "/" .. tostring(#state.queue)
            .. " | routeID=" .. tostring(rec.routeID)
            .. " | routeName=" .. tostring(rec.routeName)
            .. " | error=" .. errorText
        )
    end

    return pressed
end

function ShipFinderAttentionWarningStatesReadRoute()
    local state = ShipFinderAttentionWarningStatesProbe
    local rec = state.queue[state.index]
    if rec == nil then return false end

    local selection = ui
        and ui.Scenes
        and ui.Scenes.TradeRoute
        and ui.Scenes.TradeRoute.TradeGoodSelection
        or nil

    local data = nil
    pcall(function()
        data = selection and selection.TradeRouteGoodData or nil
    end)

    local helper =
        halo and halo["PhoenixArray<halo::CTradeRouteGoodData>"]
        or nil

    local size = 0
    local sizeOk, sizeErr = pcall(function()
        size = helper and data and helper.GetSize(data) or 0
    end)

    local warningStations = {}

    if sizeOk and helper ~= nil and data ~= nil then
        for i = 0, (tonumber(size) or 0) - 1 do
            local row = nil
            local rowOk = pcall(function()
                row = helper.GetElement(data, i)
            end)

            if rowOk and row ~= nil then
                local stationHasWarning = nil
                pcall(function()
                    stationHasWarning = row.StationHasWarning
                end)

                if ShipFinderAttentionWarningStatesTruthy(
                    stationHasWarning
                ) then
                    local islandName = nil
                    local stationID = nil
                    local waitGoods = nil
                    local waitUnload = nil
                    local waitGoodsActive = false
                    local waitUnloadActive = false

                    pcall(function() islandName = row.IslandName end)
                    pcall(function() stationID = row.StationID end)
                    pcall(function()
                        waitGoods = row.WaitForGoodsButtonData
                    end)
                    pcall(function()
                        waitUnload = row.WaitToUnloadButtonData
                    end)

                    if waitGoods ~= nil then
                        pcall(function()
                            waitGoodsActive =
                                waitGoods.IsActive == true
                        end)
                    end

                    if waitUnload ~= nil then
                        pcall(function()
                            waitUnloadActive =
                                waitUnload.IsActive == true
                        end)
                    end

                    warningStations[#warningStations + 1] = {
                        islandName = tostring(islandName or ""),
                        stationID = stationID,
                        waitForGoods = waitGoodsActive,
                        waitToUnload = waitUnloadActive,
                    }
                end
            end
        end
    end

    local detail = {
        kind = "route_warning",
        islandName = "",
        stationCount = #warningStations,
    }

    if #warningStations == 1 then
        local station = warningStations[1]
        detail.islandName = station.islandName
        detail.stationID = station.stationID
        detail.waitForGoods = station.waitForGoods == true
        detail.waitToUnload = station.waitToUnload == true

        -- Runtime validation across both provinces repeatedly showed:
        -- native station warning + WaitForGoods=true, while same-route controls
        -- were false; cargo-slot and ship warning surfaces were not active.
        -- We intentionally report the proven UI state and do NOT claim that
        -- the inaccessible low-level enum is LongWaitingTimeActive.
        if station.waitForGoods == true
            and station.waitToUnload ~= true
        then
            detail.kind = "wait_for_goods"
        elseif station.waitToUnload == true then
            detail.kind = "wait_to_unload"
        else
            detail.kind = "station_warning"
        end
    elseif #warningStations > 1 then
        detail.kind = "station_warning"
        local islands = {}
        for _, station in ipairs(warningStations) do
            if station.islandName ~= "" then
                islands[#islands + 1] = station.islandName
            end
        end
        detail.islandName = table.concat(islands, ", ")
    end

    ShipFinderAttentionWarningDetailCache[
        ShipFinderNativeRouteKey(rec.routeName)
    ] = detail

    system.log(
        "[Ship Finder Attention Detail 1.5.0] DETAIL"
        .. " | routeID=" .. tostring(rec.routeID)
        .. " | routeName=" .. tostring(rec.routeName)
        .. " | kind=" .. tostring(detail.kind)
        .. " | islandName=" .. tostring(detail.islandName)
        .. " | warningStations="
        .. tostring(detail.stationCount)
        .. " | waitForGoods="
        .. tostring(detail.waitForGoods)
        .. " | waitToUnload="
        .. tostring(detail.waitToUnload)
        .. " | sizeReadSuccess="
        .. tostring(sizeOk)
        .. " | sizeReadError="
        .. tostring(sizeErr or "")
    )

    return ShipFinderAttentionWarningStatesAdvanceRoute()
end

function ShipFinderAttentionWarningStatesTick()
    local state = ShipFinderAttentionWarningStatesProbe
    if state.active ~= true then return false end

    if state.phase == "focusRoute" then
        ShipFinderAttentionWarningStatesFocusCurrent()
        return true
    end

    if state.phase == "readRoute" then
        ShipFinderAttentionWarningStatesReadRoute()
        return true
    end

    state.active = false
    return false
end

local TRUE_TOGGLE_PREFIX = "[Ship Finder Native TradeRoute Toggle 1.1.0]"
ShipFinderAttentionScanRequested =
    ShipFinderAttentionScanRequested or false

local nativeTradeRouteToggleActive = false
local nativeTradeRouteToggleStage = 0
local nativeTradeRouteToggleTicks = 0
local nativeTradeRouteToggleOpenedByUs = false
local nativeTradeRouteRowsAtOpen = 0
local nativeTradeRouteExpandedGroups = 0
local nativeTradeRouteNormalizePending = false


local function ntLog(text)
    system.log(TRUE_TOGGLE_PREFIX .. " | " .. tostring(text))
end

local function islandScanTimingText()
    local nowWall = nil
    local nowCpu = nil
    pcall(function()
        if os and type(os.time) == "function" then nowWall = os.time() end
    end)
    pcall(function()
        if os and type(os.clock) == "function" then nowCpu = os.clock() end
    end)

    local wall = ShipFinderIslandCache
        and ShipFinderIslandCache.scanStartedWallTime
        and nowWall
        and (nowWall - ShipFinderIslandCache.scanStartedWallTime) or nil
    local cpu = ShipFinderIslandCache
        and ShipFinderIslandCache.scanStartedCpuClock
        and nowCpu
        and (nowCpu - ShipFinderIslandCache.scanStartedCpuClock) or nil

    return "scanElapsedWallSec=" .. tostring(wall)
        .. " | scanElapsedCpuSec=" .. tostring(cpu)
end

local function ntGetOverviewArray()
    local arr = nil
    local panelOpen = nil
    local groupsVisible = nil

    pcall(function()
        local scene = ui and ui.Scenes and ui.Scenes.TradeRoute or nil
        local overview = scene and scene.TradeOverview or nil
        panelOpen = overview and overview.IsPanelOpen
        groupsVisible = overview and overview.IsGroupsVisible
        arr = overview and overview.OverviewListData
            and overview.OverviewListData.ArrayData or nil
    end)

    return arr, panelOpen, groupsVisible
end

local function ntCountOverviewRows()
    local arr, panelOpen, groupsVisible = ntGetOverviewArray()
    local rows = 0

    if arr ~= nil then
        local seen = false
        local emptyTail = 0

        for i = 0, 511 do
            local ok, item = pcall(function()
                return arr[i]
            end)

            if ok and item ~= nil then
                local s = tostring(item)
                if string.find(s, "weak null", 1, true) == nil then
                    rows = rows + 1
                    seen = true
                    emptyTail = 0
                elseif seen then
                    emptyTail = emptyTail + 1
                end
            elseif seen then
                emptyTail = emptyTail + 1
            end

            if seen and emptyTail >= 16 then
                break
            end
        end
    end

    return rows, panelOpen, groupsVisible
end

local function ntLogState(label)
    local rows, panelOpen, groupsVisible = ntCountOverviewRows()
    ntLog(
        tostring(label)
        .. " | rows=" .. tostring(rows)
        .. " | IsPanelOpen=" .. tostring(panelOpen)
        .. " | IsGroupsVisible=" .. tostring(groupsVisible)
    )
    return rows, panelOpen, groupsVisible
end

local function ntOpenShipFinderMenu()
    ShipFinderPersonalLabelCache = {}
    ShipFinderAlphabeticalDynamicCache = nil
    ShipFinderPersonalMode = false

    system.log(
        "[Ship Finder Combined Root 1.1.0] opening generic storyline"
        .. " | storyline=" .. tostring(PUBLIC_STORYLINE)
    )

    GovernorDecision:CheatStartGovernorDecisionForCurrentPlayerNet(PUBLIC_STORYLINE)

    directOpenAttempt = 0
    local immediateOpened = tryDirectOpenGovernorRequest("POST_NATIVE_TOGGLE_IMMEDIATE")
    directOpenPending = not immediateOpened

    system.log(
        "[Ship Finder Combined Root 1.1.0] storyline call returned"
        .. " | immediateOpened=" .. tostring(immediateOpened)
        .. " | delayedRetryArmed=" .. tostring(directOpenPending)
        .. " | path=ui.Scenes.GovernorRequests.SceneData.Notification[0].ButtonData.States"
    )
end

local function ntFinish(reason)
    ntLog(
        "FINISH | reason=" .. tostring(reason)
        .. " | " .. islandScanTimingText()
    )
    nativeTradeRouteToggleActive = false
    nativeTradeRouteToggleStage = 0
    nativeTradeRouteToggleTicks = 0

    if islandScanRequested then
        islandScanRequested = false
        islandReportMarkerHandled = false

        if ShipFinderIslandUI and ShipFinderIslandUI.reset then
            ShipFinderIslandUI.reset()
        end

        system.log(
            "[Ship Finder Ships by Island 1.1.0] SCAN COMPLETE"
            .. " | openingReportStoryline=" .. tostring(ISLAND_REPORT_STORYLINE)
            .. " | uiStateReset=islands"
        )

        local ok, err = pcall(function()
            GovernorDecision:CheatStartGovernorDecisionForCurrentPlayerNet(
                ISLAND_REPORT_STORYLINE
            )
        end)

        system.log(
            "[Ship Finder Ships by Island 1.1.0] REPORT REQUEST"
            .. " | success=" .. tostring(ok)
            .. " | error=" .. tostring(err or "")
        )
        return
    end

    if ShipFinderAttentionScanRequested == true then
        ShipFinderAttentionScanRequested = false

        system.log(
            "[Ship Finder Attention On-Demand 1.5.0] SCAN COMPLETE"
            .. " | action=open-attention-parchment"
            .. " | reason=" .. tostring(reason)
        )

        CombinedRoot:_sf1425OpenAttentionParchmentNow()
        return
    end

    ntOpenShipFinderMenu()
end

local function ntExpandCollapsedGroups()
    local arr = ntGetOverviewArray()
    if arr == nil then
        ntLog("EXPAND | overview array unavailable")
        return 0
    end

    local expanded = 0
    local seen = false
    local emptyTail = 0

    -- Important: every flattened group row IS already
    -- halo.TradeRouteOverviewGroupBtnData.
    for i = 0, 127 do
        local ok, item = pcall(function()
            return arr[i]
        end)

        if ok and item ~= nil then
            local s = tostring(item)

            if string.find(s, "weak null", 1, true) == nil then
                seen = true
                emptyTail = 0

                local isOpen = nil
                local buttonData = nil
                local isGroupRow = false

                -- Directly probe the row itself. Non-group rows simply fail
                -- these property reads inside pcall.
                local okOpen = pcall(function()
                    isOpen = item.IsGroupOpen
                end)

                local okButton = pcall(function()
                    buttonData = item.ButtonData
                end)

                if okOpen and okButton and type(isOpen) == "boolean"
                    and buttonData ~= nil
                then
                    isGroupRow = true
                end

                if isGroupRow then
                    local groupName = nil
                    local folderID = nil

                    pcall(function()
                        groupName = buttonData.NameData
                            and buttonData.NameData.Text
                            or nil
                    end)

                    pcall(function()
                        folderID = buttonData.FolderID
                    end)

                    ntLog(
                        "GROUP ROW"
                        .. " | index=" .. tostring(i)
                        .. " | name=" .. tostring(groupName)
                        .. " | folderID=" .. tostring(folderID)
                        .. " | isOpen=" .. tostring(isOpen)
                    )

                    if isOpen == false then
                        local fn = nil
                        pcall(function()
                            fn = buttonData.PrimaryButtonPressed
                        end)

                        if type(fn) == "function" then
                            local pressOk, pressResult = pcall(function()
                                return buttonData:PrimaryButtonPressed()
                            end)

                            ntLog(
                                "EXPAND"
                                .. " | index=" .. tostring(i)
                                .. " | name=" .. tostring(groupName)
                                .. " | folderID=" .. tostring(folderID)
                                .. " | success=" .. tostring(pressOk)
                                .. " | result=" .. tostring(pressResult)
                            )

                            if pressOk then
                                expanded = expanded + 1
                            end
                        else
                            ntLog(
                                "EXPAND"
                                .. " | index=" .. tostring(i)
                                .. " | name=" .. tostring(groupName)
                                .. " | folderID=" .. tostring(folderID)
                                .. " | PrimaryButtonPressed unavailable"
                            )
                        end
                    end
                end
            elseif seen then
                emptyTail = emptyTail + 1
            end
        elseif seen then
            emptyTail = emptyTail + 1
        end

        if seen and emptyTail >= 16 then
            break
        end
    end

    ntLog("EXPAND COMPLETE | requested=" .. tostring(expanded))
    return expanded
end

local function ntBegin()
    nativeTradeRouteToggleActive = true
    nativeTradeRouteToggleStage = 0
    nativeTradeRouteToggleTicks = 0
    nativeTradeRouteToggleOpenedByUs = false
    nativeTradeRouteRowsAtOpen = 0
    nativeTradeRouteExpandedGroups = 0
    nativeTradeRouteNormalizePending = false

    local rows, panelOpen = ntLogState("BASELINE")

    -- Anno keeps stale TradeRoute view-model data after the UI has already closed.
    -- Never trust rows/IsPanelOpen alone as proof that the screen is genuinely active.
    -- If any old TradeRoute state is present, explicitly close/reset it first.
    if panelOpen == true or rows > 0 then
        local closeOk, closeResult = pcall(function()
            local scene = ui and ui.Scenes and ui.Scenes.TradeRoute or nil
            if scene and scene.CloseTradeRouteScene then
                return scene:CloseTradeRouteScene()
            end
            return nil
        end)

        ntLog(
            "NORMALIZE CLOSE"
            .. " | staleRows=" .. tostring(rows)
            .. " | stalePanelOpen=" .. tostring(panelOpen)
            .. " | success=" .. tostring(closeOk)
            .. " | result=" .. tostring(closeResult)
        )

        nativeTradeRouteNormalizePending = true
        nativeTradeRouteToggleStage = 0
        nativeTradeRouteToggleTicks = 0
        return
    end

    nativeTradeRouteToggleStage = 1

    local fn = nil
    local lookupOk = pcall(function()
        fn = Scripts and Scripts.ToggleTraderouteMenu or nil
    end)

    ntLog(
        "LOOKUP"
        .. " | ScriptsPresent=" .. tostring(Scripts ~= nil)
        .. " | success=" .. tostring(lookupOk)
        .. " | type=" .. tostring(type(fn))
        .. " | value=" .. tostring(fn)
    )

    if type(fn) ~= "function" then
        ntFinish("ToggleTraderouteMenu unavailable")
        return
    end

    local ok, result = pcall(function()
        return Scripts:ToggleTraderouteMenu()
    end)

    ntLog(
        "OPEN CALL"
        .. " | success=" .. tostring(ok)
        .. " | result=" .. tostring(result)
    )

    if not ok then
        ntFinish("open-call-failed")
        return
    end

    nativeTradeRouteToggleOpenedByUs = true
end

local function ntTick()
    if not nativeTradeRouteToggleActive then
        return false
    end

    nativeTradeRouteToggleTicks = nativeTradeRouteToggleTicks + 1
    local rows, panelOpen, groupsVisible =
        ntLogState(
            "TICK"
            .. " | stage=" .. tostring(nativeTradeRouteToggleStage)
            .. " | tick=" .. tostring(nativeTradeRouteToggleTicks)
        )

    if nativeTradeRouteToggleStage == 0 and nativeTradeRouteNormalizePending then
        -- Give the native UI one tick to finish any real close transition,
        -- then always open a fresh Trade Routes screen.
        if nativeTradeRouteToggleTicks >= 1 then
            local fn = nil
            pcall(function()
                fn = Scripts and Scripts.ToggleTraderouteMenu or nil
            end)

            if type(fn) ~= "function" then
                ntFinish("normalize-reopen-unavailable")
                return true
            end

            local ok, result = pcall(function()
                return Scripts:ToggleTraderouteMenu()
            end)

            ntLog(
                "NORMALIZE REOPEN"
                .. " | success=" .. tostring(ok)
                .. " | result=" .. tostring(result)
            )

            if not ok then
                ntFinish("normalize-reopen-failed")
                return true
            end

            nativeTradeRouteNormalizePending = false
            nativeTradeRouteToggleOpenedByUs = true
            nativeTradeRouteToggleStage = 1
            nativeTradeRouteToggleTicks = 0
            return true
        end

        return true
    end

    if nativeTradeRouteToggleStage == 1 then
        if panelOpen == true and rows > 0 then
            nativeTradeRouteRowsAtOpen = rows
            ntLog(
                "OPENED"
                .. " | rows=" .. tostring(rows)
                .. " | groupsVisible=" .. tostring(groupsVisible)
                .. " | " .. islandScanTimingText()
            )

            nativeTradeRouteExpandedGroups = ntExpandCollapsedGroups()
            nativeTradeRouteToggleStage = 2
            nativeTradeRouteToggleTicks = 0
            return true
        end

        if nativeTradeRouteToggleTicks >= 12 then
            ntFinish("open-timeout")
            return true
        end

        return true
    end

    if nativeTradeRouteToggleStage == 2 then
        -- Allow one UI rebuild tick after pressing all collapsed group headers.
        if nativeTradeRouteToggleTicks >= 1 then
            local expandedRows = rows

            ntLog(
                "HARVEST"
                .. " | rowsBefore=" .. tostring(nativeTradeRouteRowsAtOpen)
                .. " | rowsAfterExpand=" .. tostring(expandedRows)
                .. " | groupsRequested=" .. tostring(nativeTradeRouteExpandedGroups)
                .. " | " .. islandScanTimingText()
            )

            -- Normal Ctrl+Alt+F stays fast. The expensive island scan is only
            -- started after the player explicitly selects Ships by Island.
            if islandScanRequested then
                local fastStarted = false
                local fastReady = CombinedRoot:IsIslandFilterFastReady()

                ntLog(
                    "ISLAND FILTER FAST PRECHECK"
                    .. " | ready=" .. tostring(fastReady)
                    .. " | helper=" .. tostring(CombinedRoot.islandFilterFast)
                )

                if fastReady then
                    local fastOk, fastResult = pcall(function()
                        return CombinedRoot.islandFilterFast:Start()
                    end)
                    fastStarted = fastOk and fastResult == true
                    ntLog(
                        "ISLAND FILTER FAST START"
                        .. " | callSuccess=" .. tostring(fastOk)
                        .. " | started=" .. tostring(fastStarted)
                        .. " | result=" .. tostring(fastResult)
                        .. " | " .. islandScanTimingText()
                    )
                end

                if not fastStarted then
                    ntLog(
                        "ISLAND FILTER FAST NOT STARTED"
                        .. " | fastReady=" .. tostring(fastReady)
                        .. " | fallback=proven sequential scan"
                        .. " | " .. islandScanTimingText()
                    )
                    pcall(startIslandFocusedRouteProbe)
                end
            end

            -- Production path: the native hierarchy is proven. Build the cache directly;
            -- do not run the expensive 119-row introspection diagnostic mapper anymore.
            pcall(buildProductionTradeRouteCache)

            -- v1.4.41 diagnostic: while the Trade Route overview is already open,
            -- focus only the native issue routes and inspect the UI's WarningStates.
            -- Skip this extra diagnostic when a Ships-by-Island scan is running.
            if not islandScanRequested
                and ShipFinderAttentionWarningStatesStart()
            then
                nativeTradeRouteToggleStage = 30
                nativeTradeRouteToggleTicks = 0
                return true
            end

            if nativeTradeRouteToggleOpenedByUs then
                if islandFocusProbePending
                    or (CombinedRoot.islandFilterFast
                        and CombinedRoot.islandFilterFast.IsActive
                        and CombinedRoot.islandFilterFast:IsActive())
                then
                    if CombinedRoot.islandFilterFast
                        and CombinedRoot.islandFilterFast.IsActive
                        and CombinedRoot.islandFilterFast:IsActive()
                    then
                        ntLog("ISLAND FILTER FAST WAIT | native filter scanner active")
                    else
                        ntLog(
                            "ISLAND FOCUS PROBE WAIT"
                            .. " | routeID=" .. tostring(islandFocusProbeRouteID)
                            .. " | routeName=" .. tostring(islandFocusProbeRouteName)
                        )
                    end
                    nativeTradeRouteToggleStage = 20
                    nativeTradeRouteToggleTicks = 0
                    return true
                end

                local ok, result = pcall(function()
                    return Scripts:ToggleTraderouteMenu()
                end)

                ntLog(
                    "CLOSE CALL"
                    .. " | success=" .. tostring(ok)
                    .. " | result=" .. tostring(result)
                )

                nativeTradeRouteToggleStage = 3
                nativeTradeRouteToggleTicks = 0
                return true
            end

            ntFinish("harvested-existing-screen")
            return true
        end

        return true
    end

    if nativeTradeRouteToggleStage == 30 then
        if ShipFinderAttentionWarningStatesProbe
            and ShipFinderAttentionWarningStatesProbe.active == true
        then
            ShipFinderAttentionWarningStatesTick()
            return true
        end

        local ok, result = pcall(function()
            return Scripts:ToggleTraderouteMenu()
        end)

        ntLog(
            "CLOSE CALL AFTER WARNINGSTATES PROBE"
            .. " | success=" .. tostring(ok)
            .. " | result=" .. tostring(result)
        )

        nativeTradeRouteToggleStage = 3
        nativeTradeRouteToggleTicks = 0
        return true
    end

    if nativeTradeRouteToggleStage == 20 then
        if CombinedRoot.islandFilterFast
            and CombinedRoot.islandFilterFast.IsActive
            and CombinedRoot.islandFilterFast:IsActive()
        then
            local fastOk, fastStatus = pcall(function()
                return CombinedRoot.islandFilterFast:Tick()
            end)

            if not fastOk then
                ntLog(
                    "ISLAND FILTER FAST ERROR"
                    .. " | error=" .. tostring(fastStatus)
                    .. " | fallback=proven sequential scan"
                    .. " | " .. islandScanTimingText()
                )
                pcall(startIslandFocusedRouteProbe)
                return true
            end

            if fastStatus == "accepted" then
                local fastIndex, fastRouteCount, fastRouteIslandMap =
                    CombinedRoot.islandFilterFast:GetResult()
                islandFullIndex = fastIndex or {}
                islandFullIndexRouteCount = fastRouteCount or 0
                islandFullIndexLogSummary()

                if ShipFinderIslandCache and ShipFinderIslandCache.commit then
                    ShipFinderIslandCache.commit(
                        islandFullIndex,
                        islandFullIndexRouteCount,
                        fastRouteIslandMap
                    )
                end

                islandFocusProbePending = false
                ntLog(
                    "ISLAND FILTER FAST ACCEPTED"
                    .. " | routes=" .. tostring(islandFullIndexRouteCount)
                    .. " | " .. islandScanTimingText()
                )
            elseif fastStatus == "rejected" then
                ntLog(
                    "ISLAND FILTER FAST REJECTED | starting proven sequential fallback"
                    .. " | " .. islandScanTimingText()
                )
                pcall(startIslandFocusedRouteProbe)
                return true
            else
                return true
            end
        elseif CombinedRoot.islandFilterFast
            and CombinedRoot.islandFilterFast.pendingStatus == "rejected"
            and not islandFocusProbePending
        then
            ntLog(
                "ISLAND FILTER FAST REJECTED | starting proven sequential fallback"
                .. " | " .. islandScanTimingText()
            )
            CombinedRoot.islandFilterFast.pendingStatus = nil
            pcall(startIslandFocusedRouteProbe)
            return true
        end

        if islandFocusProbePending then
            tickIslandFocusedRouteProbe()
        end

        if not islandFocusProbePending
            and not (CombinedRoot.islandFilterFast
                and CombinedRoot.islandFilterFast.IsActive
                and CombinedRoot.islandFilterFast:IsActive())
        then
            local ok, result = pcall(function()
                return Scripts:ToggleTraderouteMenu()
            end)

            ntLog(
                "CLOSE CALL AFTER ISLAND SCAN"
                .. " | success=" .. tostring(ok)
                .. " | result=" .. tostring(result)
            )

            nativeTradeRouteToggleStage = 3
            nativeTradeRouteToggleTicks = 0
        end

        return true
    end

    if nativeTradeRouteToggleStage == 3 then
        -- The TradeRoute view-model intentionally keeps stale values after the
        -- actual UI state has already left TradeRoute/MacroMap, so do not wait
        -- for IsPanelOpen=false. A short fixed delay is enough for the visual
        -- close transition before opening the Governor Decision.
        if nativeTradeRouteToggleTicks >= 1 then
            ntLog(
                "POST-CLOSE DELAY COMPLETE"
                .. " | ticks=" .. tostring(nativeTradeRouteToggleTicks)
                .. " | stalePanelOpen=" .. tostring(panelOpen)
                .. " | staleRows=" .. tostring(rows)
            )
            ntFinish("success")
            return true
        end

        return true
    end

    return true
end

directOpenPending = false
directOpenAttempt = 0
DIRECT_OPEN_MAX_ATTEMPTS = 20

tryDirectOpenGovernorRequest = function(phase)
    directOpenAttempt = directOpenAttempt + 1

    local governorScene = nil
    local sceneData = nil
    local notification = nil
    local states = nil

    local okLookup = pcall(function()
        if ui and ui.Scenes then
            governorScene = ui.Scenes.GovernorRequests
        end

        if governorScene then
            sceneData = governorScene.SceneData
        end

        if sceneData and sceneData.Notification then
            notification = sceneData.Notification[0]
        end

        if notification
            and notification.ButtonData
            and notification.ButtonData.States
        then
            states = notification.ButtonData.States
        end
    end)

    if not okLookup then
        system.log(
            "[Ship Finder Direct Menu Open 1.1.0]"
            .. " | phase=" .. tostring(phase)
            .. " | attempt=" .. tostring(directOpenAttempt)
            .. " | lookup=false"
        )
        return false
    end

    if not states then
        system.log(
            "[Ship Finder Direct Menu Open 1.1.0]"
            .. " | phase=" .. tostring(phase)
            .. " | attempt=" .. tostring(directOpenAttempt)
            .. " | governorScene=" .. tostring(governorScene ~= nil)
            .. " | sceneData=" .. tostring(sceneData ~= nil)
            .. " | notificationPresent=" .. tostring(notification ~= nil)
            .. " | statesPresent=false"
        )
        return false
    end

    local focusOk, focusResult = pcall(function()
        return states:RequestFocus()
    end)

    local primaryOk, primaryResult = pcall(function()
        return states:EventPrimary()
    end)

    system.log(
        "[Ship Finder Direct Menu Open 1.1.0]"
        .. " | phase=" .. tostring(phase)
        .. " | attempt=" .. tostring(directOpenAttempt)
        .. " | governorScene=true"
        .. " | sceneData=true"
        .. " | notificationPresent=true"
        .. " | statesPresent=true"
        .. " | requestFocusSuccess=" .. tostring(focusOk)
        .. " | requestFocusResult=" .. tostring(focusResult)
        .. " | eventPrimarySuccess=" .. tostring(primaryOk)
        .. " | eventPrimaryResult=" .. tostring(primaryResult)
    )

    return focusOk and primaryOk
end


local function islandReportText()
    if ShipFinderIslandUI and ShipFinderIslandUI.pageText then
        local text = ShipFinderIslandUI.pageText(
            ShipFinderIslandUI.page or 0
        )
        return text
    end

    if tostring(ShipFinderUILanguage or "") == "de" then
        return "SCHIFFE NACH INSEL\n\nBericht nicht verfügbar."
    elseif tostring(ShipFinderUILanguage or "") == "fr" then
        return "NAVIRES PAR ÎLE\n\nRapport indisponible."
    end
    return "SHIPS BY ISLAND\n\nReport unavailable."
end

local function getTextPopupContent()
    local content = nil
    pcall(function()
        content = ui
            and ui.Scenes
            and ui.Scenes.TextPopup
            and ui.Scenes.TextPopup.SceneData
            and ui.Scenes.TextPopup.SceneData.Content
            or nil
    end)
    return content
end

function CombinedRoot:_sf1199NormalizeLocalizedMarker(text)
    local raw = tostring(text or "")
    local base = string.match(raw, "^(SF_.+)_DE$")
    if base ~= nil then
        ShipFinderUILanguage = "de"
        system.log(
            "[Ship Finder Localization 1.1.0] MARKER"
            .. " | raw=" .. raw
            .. " | language=de"
        )
        return base
    end

    base = string.match(raw, "^(SF_.+)_FR$")
    if base ~= nil then
        ShipFinderUILanguage = "fr"
        system.log(
            "[Ship Finder Localization 1.1.0] MARKER"
            .. " | raw=" .. raw
            .. " | language=fr"
        )
        return base
    end

    base = string.match(raw, "^(SF_.+)_EN$")
    if base ~= nil then
        ShipFinderUILanguage = "en"
        system.log(
            "[Ship Finder Localization 1.1.0] MARKER"
            .. " | raw=" .. raw
            .. " | language=en"
        )
        return base
    end

    return raw
end

local function tickShipsByIslandUI()
    local content = getTextPopupContent()

    if content ~= nil then
        local text = nil
        pcall(function() text = content.Text end)
        text = CombinedRoot:_sf1199NormalizeLocalizedMarker(text)

        if text == "SF_SHIPFINDER_CLOSE" then
            local okClose, closeErr = pcall(function()
                Scripts:PopUI()
            end)
            system.log(
                "[Ship Finder Close 1.1.0] COMPLETE"
                .. " | markerPopupClose=" .. tostring(okClose)
                .. " | error=" .. tostring(closeErr or "")
            )
            return true
        end

        if text == "SF_SHIP_UNAVAILABLE" then
            local d = ShipFinderIslandUnavailable or {}
            local de = tostring(ShipFinderUILanguage or "") == "de"
            local fr = tostring(ShipFinderUILanguage or "") == "fr"
            local shipName = tostring(
                d.shipName
                or (de and "Dieses Schiff"
                    or (fr and "Ce navire" or "This ship"))
            )
            local routeName = tostring(d.routeName or "")
            local message = nil
            if de then
                message = "SCHIFF NICHT VERFÜGBAR\n\n"
                    .. shipName
                    .. " befindet sich derzeit außerhalb dieser Provinz und kann momentan nicht angezeigt werden."
                if routeName ~= "" then message = message .. "\n\nHandelsroute: " .. routeName end
            elseif fr then
                message = "NAVIRE INDISPONIBLE\n\n"
                    .. shipName
                    .. " se trouve actuellement hors de cette province et ne peut pas être affiché pour le moment."
                if routeName ~= "" then message = message .. "\n\nRoute commerciale : " .. routeName end
            else
                message = "SHIP NOT AVAILABLE\n\n"
                    .. shipName
                    .. " is currently outside this province and cannot be shown right now."
                if routeName ~= "" then message = message .. "\n\nTrade route: " .. routeName end
            end
            local okWrite, writeErr = pcall(function() content.Text = message end)
            system.log(
                "[Ship Finder Island Navigation 1.1.0] UNAVAILABLE PARCHMENT WRITE"
                .. " | language=" .. (de and "de" or (fr and "fr" or "en"))
                .. " | success=" .. tostring(okWrite)
                .. " | ship=" .. tostring(shipName)
                .. " | error=" .. tostring(writeErr or "")
            )
            return true
        end

        if text == "SF_FLEET_OVERVIEW" then
            if ShipFinderFleetReport ~= nil then
                ShipFinderFleetReport.opening = false
                ShipFinderFleetReport.active = true
                ShipFinderFleetReport.mode = "summary"
                ShipFinderFleetReport.page = 0
                ShipFinderFleetReport.visible = {}
            end

            local de = tostring(ShipFinderUILanguage or "") == "de"
            local fr = tostring(ShipFinderUILanguage or "") == "fr"
            local report = CombinedRoot:FleetOverviewParchmentText(de)
            local okWrite, writeErr = pcall(function()
                content.Text = report
            end)
            system.log(
                "[Ship Finder Fleet Analysis 1.4.36] REPORT WRITE"
                .. " | language=" .. tostring(de and "de" or (fr and "fr" or "en"))
                .. " | success=" .. tostring(okWrite)
                .. " | chars=" .. tostring(#tostring(report or ""))
                .. " | error=" .. tostring(writeErr or "")
            )
            return true
        end

        if text == "SF_SHIPS_BY_ISLAND_SCAN_INFO" then
            local info = nil
            if tostring(ShipFinderUILanguage or "") == "de" then
                info = "SCHIFFE NACH INSEL — SCAN-INFORMATIONEN\n\nScan-Informationen nicht verfügbar."
            elseif tostring(ShipFinderUILanguage or "") == "fr" then
                info = "NAVIRES PAR ÎLE — INFORMATIONS SUR L’ANALYSE\n\nInformations d’analyse indisponibles."
            else
                info = "SHIPS BY ISLAND — SCAN INFORMATION\n\nScan information unavailable."
            end
            if ShipFinderIslandCache and ShipFinderIslandCache.scanInfoText then
                info = ShipFinderIslandCache.scanInfoText()
            end
            local okWrite, writeErr = pcall(function()
                content.Text = info
            end)
            system.log(
                "[Ship Finder Ships by Island 1.1.0] SCAN INFO WRITE"
                .. " | success=" .. tostring(okWrite)
                .. " | chars=" .. tostring(#tostring(info or ""))
                .. " | cacheValid=" .. tostring(ShipFinderIslandCache and ShipFinderIslandCache.valid == true)
                .. " | language=" .. tostring(ShipFinderUILanguage or "unset")
                .. " | markerLanguage=localized-popup-marker"
                .. " | error=" .. tostring(writeErr or "")
            )
            return true
        end

        if text == "SF_SHIPS_BY_ISLAND_FORCE_SCAN"
            and not islandScanMarkerHandled
        then
            islandScanReason = "manual-rescan"
            if ShipFinderIslandCache then
                ShipFinderIslandCache.invalidate("manual-rescan")
            end

            system.log(
                "[Ship Finder Ships by Island Cache 1.1.0] MANUAL RESCAN"
                .. " | action=cache-invalidated"
                .. " | bridge=distinct-popup-marker"
            )

            -- Reuse the proven normal scan-marker path in this same Tick.
            text = "SF_SHIPS_BY_ISLAND_SCAN"
        end

        if text == "SF_SHIPS_BY_ISLAND_SCAN" and not islandScanMarkerHandled then
            islandScanMarkerHandled = true
            islandReportMarkerHandled = false

            if ShipFinderIslandCache
                and ShipFinderIslandCache.matchesCurrentFleet
            then
                local cacheMatch, cacheReason =
                    ShipFinderIslandCache.matchesCurrentFleet()

                if cacheMatch then
                    local cachedIndex, cachedRouteCount =
                        ShipFinderIslandCache.restore()

                    islandFullIndex = cachedIndex or islandFullIndex
                    islandFullIndexRouteCount =
                        cachedRouteCount or islandFullIndexRouteCount

                    system.log(
                        "[Ship Finder Ships by Island Cache 1.1.0] CHECK"
                        .. " | result=match"
                        .. " | action=reuse"
                    )

                    pcall(function()
                        Scripts:PopUI()
                    end)

                    islandScanStartDelay = -2
                    islandScanReason = nil
                    return true
                end

                if islandScanReason == nil then
                    islandScanReason = tostring(cacheReason or "cache-miss")
                end

                system.log(
                    "[Ship Finder Ships by Island Cache 1.1.0] CHECK"
                    .. " | result=miss"
                    .. " | reason=" .. tostring(cacheReason)
                    .. " | action=rescan"
                )
            end

            if islandScanReason == nil then
                islandScanReason = "cache-api-unavailable"
            end

            local okWrite, writeErr = pcall(function()
                local manualRescan = islandScanReason == "manual-rescan"
                if tostring(ShipFinderUILanguage or "") == "de" then
                    if manualRescan then
                        content.Text =
                            "SCHIFFE NACH INSEL\n\n"
                            .. "Inselverbindungen werden erneut erfasst. Bei großen Spielständen kann dies etwas länger dauern."
                    else
                        content.Text =
                            "SCHIFFE NACH INSEL\n\n"
                            .. "Inselverbindungen werden zum ersten Mal erfasst. Bei großen Spielständen kann dies etwas länger dauern. Spätere Aufrufe verwenden zwischengespeicherte Ergebnisse."
                    end
                elseif tostring(ShipFinderUILanguage or "") == "fr" then
                    if manualRescan then
                        content.Text =
                            "NAVIRES PAR ÎLE\n\n"
                            .. "Nouvelle analyse des liaisons entre îles. Cela peut prendre un peu plus de temps sur les grandes sauvegardes."
                    else
                        content.Text =
                            "NAVIRES PAR ÎLE\n\n"
                            .. "Première analyse des liaisons entre îles. Cela peut prendre un peu plus de temps sur les grandes sauvegardes. Les ouvertures suivantes utilisent les résultats mis en cache."
                    end
                else
                    if manualRescan then
                        content.Text =
                            "SHIPS BY ISLAND\n\n"
                            .. "Rescanning island connections. Large savegames may take a little longer."
                    else
                        content.Text =
                            "SHIPS BY ISLAND\n\n"
                            .. "Scanning island connections for the first time. Large savegames may take a little longer. Later openings use cached results."
                    end
                end
            end)

            system.log(
                "[Ship Finder Ships by Island 1.1.0] SCAN MARKER"
                .. " | reason=" .. tostring(islandScanReason)
                .. " | writeSuccess=" .. tostring(okWrite)
                .. " | error=" .. tostring(writeErr or "")
            )

            local okClose, closeErr = pcall(function()
                Scripts:PopUI()
            end)

            system.log(
                "[Ship Finder Ships by Island 1.1.0] SCAN PAPER CLOSE"
                .. " | success=" .. tostring(okClose)
                .. " | error=" .. tostring(closeErr or "")
            )

            islandScanStartDelay = 2
            return true
        end

        local nativePage =
            ShipFinderIslandUI
            and ShipFinderIslandUI.pageFromMarker
            and ShipFinderIslandUI.pageFromMarker(text)
            or nil

        if nativePage ~= nil then
            islandReportMarkerHandled = true
            islandScanMarkerHandled = false

            if ShipFinderFleetReport ~= nil
                and (ShipFinderFleetReport.opening == true
                    or ShipFinderFleetReport.active == true)
            then
                ShipFinderFleetReport.opening = false
                ShipFinderFleetReport.active = true

                local report = nil
                local reportOk, reportErr = pcall(function()
                    report = ShipFinderFleetReport.pageText(nativePage)
                end)

                if not reportOk then
                    local de = tostring(ShipFinderUILanguage or "") == "de"
                    local fr = tostring(ShipFinderUILanguage or "") == "fr"
                    report = de
                        and "FLOTTENÜBERSICHT\n\nBericht konnte nicht aufgebaut werden."
                        or (fr
                            and "VUE D’ENSEMBLE DE LA FLOTTE\n\nLe rapport n’a pas pu être généré."
                            or "FLEET OVERVIEW\n\nReport could not be built.")

                    system.log(
                        "[Ship Finder Fleet Analysis 1.4.36] REPORT BUILD ERROR"
                        .. " | mode=" .. tostring(ShipFinderFleetReport.mode or "")
                        .. " | nativePage=" .. tostring(nativePage + 1)
                        .. " | error=" .. tostring(reportErr or "")
                    )
                end

                local okWrite, writeErr = pcall(function()
                    content.Text = report
                end)
                system.log(
                    "[Ship Finder Fleet Analysis 1.4.36] REPORT WRITE"
                    .. " | mode=" .. tostring(ShipFinderFleetReport.mode or "")
                    .. " | nativePage=" .. tostring(nativePage + 1)
                    .. " | effectivePage=" .. tostring((ShipFinderFleetReport.page or 0) + 1)
                    .. " | buildSuccess=" .. tostring(reportOk)
                    .. " | success=" .. tostring(okWrite)
                    .. " | chars=" .. tostring(#tostring(report or ""))
                    .. " | error=" .. tostring(writeErr or "")
                )
                return true
            end

            if ShipFinderAttentionParchmentTest ~= nil
                and (ShipFinderAttentionParchmentTest.opening == true
                    or ShipFinderAttentionParchmentTest.active == true)
            then
                ShipFinderAttentionParchmentTest.opening = false
                ShipFinderAttentionParchmentTest.active = true
                local report = ShipFinderAttentionParchmentTest.pageText(nativePage)
                local okWrite, writeErr = pcall(function()
                    content.Text = report
                end)
                system.log(
                    "[Ship Finder Attention Report 1.4.31] REPORT WRITE"
                    .. " | sharedStoryline=2099200"
                    .. " | sharedPopup=2099191"
                    .. " | nativePage=" .. tostring(nativePage + 1)
                    .. " | effectivePage=" .. tostring(ShipFinderAttentionParchmentTest.page + 1)
                    .. " | success=" .. tostring(okWrite)
                    .. " | chars=" .. tostring(#tostring(report or ""))
                    .. " | error=" .. tostring(writeErr or "")
                )
                return true
            end

            local reportMode = "island-index"
            if ShipFinderIslandUI then
                ShipFinderIslandUI.jumpInProgress = false
                if ShipFinderIslandUI.resumeMode
                    and ShipFinderIslandUI.resumeIslandPageText
                then
                    local _, _, resumePage =
                        ShipFinderIslandUI.resumeIslandPageText(nativePage)
                    ShipFinderIslandUI.page = resumePage or 0
                    reportMode = "last-island-resume"
                elseif ShipFinderIslandUI.mode == "ships"
                    and ShipFinderIslandUI.shipPageText
                then
                    ShipFinderIslandUI.shipPage = nativePage
                    reportMode = "selected-island"
                else
                    ShipFinderIslandUI.mode = "islands"
                    ShipFinderIslandUI.islandPage = nativePage
                end
            end

            local report = nil
            if ShipFinderIslandUI
                and ShipFinderIslandUI.resumeMode
                and ShipFinderIslandUI.resumeIslandPageText
            then
                report = ShipFinderIslandUI.resumeIslandPageText(
                    ShipFinderIslandUI.page or 0
                )
            elseif ShipFinderIslandUI
                and ShipFinderIslandUI.mode == "ships"
                and ShipFinderIslandUI.shipPageText
            then
                report = ShipFinderIslandUI.shipPageText()
            elseif ShipFinderIslandUI and ShipFinderIslandUI.islandPageText then
                report = ShipFinderIslandUI.islandPageText()
            else
                report = islandReportText()
            end
            local islandCount = 0
            for _ in pairs(islandFullIndex or {}) do
                islandCount = islandCount + 1
            end

            local okWrite, writeErr = pcall(function()
                content.Text = report
            end)

            system.log(
                "[Ship Finder Ships by Island 1.1.0] REPORT WRITE"
                .. " | success=" .. tostring(okWrite)
                .. " | mode=" .. tostring(reportMode)
                .. " | nativePage=" .. tostring(nativePage + 1)
                .. " | effectivePage=" .. tostring((ShipFinderIslandUI.page or 0) + 1)
                .. " | chars=" .. tostring(#report)
                .. " | islands=" .. tostring(islandCount)
                .. " | routesScanned=" .. tostring(islandFullIndexRouteCount)
                .. " | language=" .. tostring(ShipFinderUILanguage or "unset")
                .. " | markerLanguage=localized-popup-marker"
                .. " | error=" .. tostring(writeErr or "")
            )
            return true
        end
    end

    if islandScanStartDelay > 0 then
        islandScanStartDelay = islandScanStartDelay - 1
        if islandScanStartDelay == 0 then
            islandScanRequested = true
            islandFullIndexReset()
            if ShipFinderIslandCache then
                ShipFinderIslandCache.scanStartedPlayTime = nil
                ShipFinderIslandCache.scanStartedWallTime = nil
                ShipFinderIslandCache.scanStartedCpuClock = nil
                ShipFinderIslandCache.scanStartReason = islandScanReason
                pcall(function()
                    ShipFinderIslandCache.scanStartedPlayTime = Game and Game.PlayTime or nil
                end)
                pcall(function()
                    if os and type(os.time) == "function" then
                        ShipFinderIslandCache.scanStartedWallTime = os.time()
                    end
                end)
                pcall(function()
                    if os and type(os.clock) == "function" then
                        ShipFinderIslandCache.scanStartedCpuClock = os.clock()
                    end
                end)
            end

            system.log(
                "[Ship Finder Ships by Island 1.1.0] ON-DEMAND SCAN START"
                .. " | reason=" .. tostring(islandScanReason)
                .. " | cacheValid="
                .. tostring(ShipFinderIslandCache and ShipFinderIslandCache.valid == true)
            )

            directOpenPending = false
            directOpenAttempt = 0
            ntBegin()
        end
        return true
    end

    if islandScanStartDelay < 0 then
        islandScanStartDelay = islandScanStartDelay + 1

        if islandScanStartDelay == 0 then
            if ShipFinderIslandUI and ShipFinderIslandUI.reset then
                ShipFinderIslandUI.reset()
            end

            system.log(
                "[Ship Finder Ships by Island Cache 1.1.0] REUSE"
                .. " | openingReportStoryline="
                .. tostring(ISLAND_REPORT_STORYLINE)
                .. " | uiStateReset=islands"
            )

            pcall(function()
                GovernorDecision:CheatStartGovernorDecisionForCurrentPlayerNet(
                    ISLAND_REPORT_STORYLINE
                )
            end)
        end

        return true
    end

    return false
end


-- Ship Finder Multi Route Bridge 1.1.0
-- Runtime v1.1.0 proved that select-route.lua can create the dedicated multi-ship
-- Governor request successfully, while any Sequence connector after ActionExecuteScript
-- does not advance. State and helpers live on CombinedRoot so this already-large module
-- does not consume additional top-level Lua locals (Lua chunk limit: 200 locals).
CombinedRoot.MultiRouteBridge = {
    baselineSignature = nil,
    candidateSignature = nil,
    candidateStates = nil,
    stableTicks = 0
}

function CombinedRoot:_sf1192Read(obj, key)
    if obj == nil then
        return nil
    end
    local ok, value = pcall(function()
        return obj[key]
    end)
    if ok then
        return value
    end
    return nil
end

function CombinedRoot:_sf1192GovernorRequestState()
    local governorScene = ui and ui.Scenes and ui.Scenes.GovernorRequests or nil
    local sceneData = governorScene and self:_sf1192Read(governorScene, "SceneData") or nil
    local notifications = sceneData and self:_sf1192Read(sceneData, "Notification") or nil
    local notification = notifications and self:_sf1192Read(notifications, 0) or nil
    local buttonData = notification and self:_sf1192Read(notification, "ButtonData") or nil
    local states = buttonData and self:_sf1192Read(buttonData, "States") or nil
    if states == nil then
        return nil, nil
    end
    return states, tostring(notification) .. "|" .. tostring(buttonData) .. "|" .. tostring(states)
end

function CombinedRoot:_sf1192NarrativeSequenceActive()
    local scene = ui and ui.Scenes and ui.Scenes.NarrativeSequence or nil
    if scene == nil then
        return false
    end

    local visible = self:_sf1192Read(scene, "IsVisible")
    if type(visible) == "boolean" then
        return visible
    end

    local sceneData = self:_sf1192Read(scene, "SceneData")
    return sceneData ~= nil
end

function CombinedRoot:_sf1192ResetCandidate()
    self.MultiRouteBridge.candidateSignature = nil
    self.MultiRouteBridge.candidateStates = nil
    self.MultiRouteBridge.stableTicks = 0
end

function CombinedRoot:_sf1192TickMultiRouteBridge()
    local states, signature = self:_sf1192GovernorRequestState()
    if signature == nil then
        return false
    end

    if self.MultiRouteBridge.baselineSignature == nil then
        self.MultiRouteBridge.baselineSignature = signature
        self:_sf1192ResetCandidate()
        return false
    end

    if signature == self.MultiRouteBridge.baselineSignature then
        self:_sf1192ResetCandidate()
        return false
    end

    if not self:_sf1192NarrativeSequenceActive() then
        self.MultiRouteBridge.baselineSignature = signature
        self:_sf1192ResetCandidate()
        return false
    end

    if signature ~= self.MultiRouteBridge.candidateSignature then
        self.MultiRouteBridge.candidateSignature = signature
        self.MultiRouteBridge.candidateStates = states
        self.MultiRouteBridge.stableTicks = 1
        system.log(
            "[Ship Finder Multi Route Bridge 1.1.0] DETECT"
            .. " | narrativeActive=true"
            .. " | action=confirm-next-tick"
        )
        return false
    end

    self.MultiRouteBridge.stableTicks = self.MultiRouteBridge.stableTicks + 1
    if self.MultiRouteBridge.stableTicks < 2 then
        return false
    end

    local targetStates = self.MultiRouteBridge.candidateStates or states
    local focusOk, focusErr = pcall(function()
        targetStates:RequestFocus()
    end)
    local primaryOk, primaryErr = pcall(function()
        targetStates:EventPrimary()
    end)

    system.log(
        "[Ship Finder Multi Route Bridge 1.1.0] OPEN"
        .. " | focus=" .. tostring(focusOk)
        .. " | pop=not-used"
        .. " | primary=" .. tostring(primaryOk)
        .. " | routeSequence=natural-end"
        .. " | focusError=" .. tostring(focusErr or "")
        .. " | primaryError=" .. tostring(primaryErr or "")
    )

    self.MultiRouteBridge.baselineSignature = signature
    self:_sf1192ResetCandidate()
    return true
end


CombinedRoot.IslandJumpWatch = CombinedRoot.IslandJumpWatch or {
    pending = false, page = 0, shipName = "", routeName = "", ticks = 0,
    baselineSignature = ""
}

-- v1.1.0: SceneData can remain allocated after OMShipUnit has closed.  v1.1.0
-- therefore mistook stale scene data for a successful Traveler jump.  Build a
-- best-effort signature and require a FRESH post-jump transition instead of mere
-- SceneData existence.  No reflection and no mutation of the ship/route model.
function CombinedRoot:_sf1197ShipViewSignature()
    local scene = ui and ui.Scenes and ui.Scenes.OMShipUnit or nil
    if scene == nil then return "scene:nil" end

    local visible = self:_sf1192Read(scene, "IsVisible")
    local sceneData = self:_sf1192Read(scene, "SceneData")
    local content = sceneData and self:_sf1192Read(sceneData, "Content") or nil
    local parts = {
        "visible=" .. tostring(visible),
        "sceneData=" .. tostring(sceneData),
        "content=" .. tostring(content),
    }

    local keys = {
        "ObjectID", "ObjectId", "ShipID", "ShipId", "UnitID", "UnitId",
        "SelectedObjectID", "SelectedObjectId", "SelectedShipID", "SelectedShipId",
        "Object", "Ship", "Unit", "Selection"
    }
    for _, key in ipairs(keys) do
        local value = content and self:_sf1192Read(content, key) or nil
        if value == nil and sceneData ~= nil then
            value = self:_sf1192Read(sceneData, key)
        end
        if value ~= nil then
            parts[#parts + 1] = key .. "=" .. tostring(value)
        end
    end
    return table.concat(parts, ";")
end

function CombinedRoot:_sf1197OpenUnavailable(shipName, routeName, reason, closeCurrentPopup)
    ShipFinderIslandUnavailable = {
        shipName = tostring(shipName or ""),
        routeName = tostring(routeName or ""),
        reason = tostring(reason or "")
    }

    if closeCurrentPopup then
        pcall(function() Scripts:PopUI() end)
    end

    local ok, err = pcall(function()
        GovernorDecision:CheatStartGovernorDecisionForCurrentPlayerNet(2099400)
    end)

    system.log(
        "[Ship Finder Island Navigation 1.1.0] UNAVAILABLE PARCHMENT REQUEST"
        .. " | ship=" .. tostring(shipName or "")
        .. " | route=" .. tostring(routeName or "")
        .. " | reason=" .. tostring(reason or "")
        .. " | closeCurrent=" .. tostring(closeCurrentPopup == true)
        .. " | requestSuccess=" .. tostring(ok)
        .. " | error=" .. tostring(err or "")
    )
    return ok
end

function CombinedRoot:_sf1197TickIslandJumpWatch()
    local w = self.IslandJumpWatch
    if w and w.pending then
        -- v1.1.0 migration guard: never emit an availability warning from the old
        -- signature/timeout heuristic. Only deterministic checks in IslandShortcut
        -- may open the unavailable parchment.
        w.pending = false
        w.ticks = 0
        system.log("[Ship Finder Island Navigation 1.1.0] LEGACY WATCH CLEARED | action=no-false-unavailable")
    end
    return false
end



-- Ship Finder v1.4.31 Attention immediate post-yield handoff.
-- Runtime v1.4.30 timing proved:
--   Leave NarrativeSequence -> signal visible ~0.34 s later
--   signal -> next global Tick StoryLine request ~0.49 s later
--   request -> TextPopup visible ~0.38 s later
--
-- The S3L +1000 signal is already only visible AFTER the menu NarrativeSequence
-- has yielded. Therefore v1.4.31 removes the final artificial next-Tick delay:
-- when the post-yield signal is detected from normal global Tick context, it
-- requests the already-proven Attention StoryLine immediately in that same Tick.
--
-- This is still fundamentally different from the old freezing builds:
-- nothing is opened from inside the Decision/Action context and no UI close is
-- issued by Lua. The proven Safe Close path 2035152 -> 2099398 finishes first.
CombinedRoot.AttentionMenuParchmentBridge = CombinedRoot.AttentionMenuParchmentBridge or {
    observedSignal = nil,
    phase = "idle",
    ticks = 0,
}

function CombinedRoot:_sf1425AttentionSignal()
    local ok, value = pcall(function()
        return Variables:GetVariable("S3L")
    end)
    if not ok or value == nil then return 0 end
    return tonumber(value) or 0
end

function CombinedRoot:_sf1425ResetAttentionMenuBridge()
    local bridge = self.AttentionMenuParchmentBridge
    bridge.observedSignal = self:_sf1425AttentionSignal()
    bridge.phase = "idle"
    bridge.ticks = 0
    system.log(
        "[Ship Finder Attention Immediate Bridge 1.4.31] RESET"
        .. " | signal=" .. tostring(bridge.observedSignal)
        .. " | attentionConnector=2099398"
        .. " | extraSettleTicks=0"
        .. " | extraPendingTick=false"
    )
end

function CombinedRoot:_sf1425OpenAttentionParchmentNow()
    if ShipFinderAttentionParchmentTest == nil then
        system.log(
            "[Ship Finder Attention Immediate Bridge 1.4.31] ABORT"
            .. " | reason=parchment-state-missing"
        )
        return false
    end

    ShipFinderAttentionParchmentTest.pendingOpen = false
    ShipFinderAttentionParchmentTest.active = false
    ShipFinderAttentionParchmentTest.opening = true
    ShipFinderAttentionParchmentTest.page = 0
    ShipFinderAttentionParchmentTest.visible = {}

    local attentionCount = #ShipFinderAttentionParchmentTest.records()
    local attentionStoryline =
        attentionCount <= 9 and 2099210 or ISLAND_REPORT_STORYLINE

    local ok, err = pcall(function()
        GovernorDecision:CheatStartGovernorDecisionForCurrentPlayerNet(
            attentionStoryline
        )
    end)

    system.log(
        "[Ship Finder Attention Report 1.4.31] STORYLINE REQUEST"
        .. " | deferredTicks=0"
        .. " | source=post-yield-signal-same-tick"
        .. " | ships=" .. tostring(attentionCount)
        .. " | mode=" .. tostring(attentionCount <= 9 and "single-page" or "multi-page")
        .. " | storyline=" .. tostring(attentionStoryline)
        .. " | success=" .. tostring(ok)
        .. " | error=" .. tostring(err or "")
    )

    if not ok then
        ShipFinderAttentionParchmentTest.opening = false
        ShipFinderAttentionParchmentTest.active = false
        return false
    end
    return true
end

function CombinedRoot:_sf1425TickAttentionMenuBridge()
    local bridge = self.AttentionMenuParchmentBridge
    local signal = self:_sf1425AttentionSignal()

    if bridge.observedSignal == nil then
        bridge.observedSignal = signal
    end

    local oldSignal = tonumber(bridge.observedSignal) or 0
    local delta = signal - oldSignal

    if delta < 1000 then
        if signal ~= oldSignal then
            bridge.observedSignal = signal
        end
        return false
    end

    -- v1.4.41 reserves S3L increments >=10000 for the robust Fleet Summary
    -- handoff. The current production Attention entry no longer uses S3L;
    -- it uses the proven S3F +6000 path from v1.4.37.
    if delta >= 10000 then
        bridge.observedSignal = signal
        system.log(
            "[Ship Finder Attention Immediate Bridge 1.4.41] IGNORE"
            .. " | source=S3L-reserved-fleet-summary"
            .. " | previous=" .. tostring(oldSignal)
            .. " | current=" .. tostring(signal)
            .. " | delta=" .. tostring(delta)
        )
        return false
    end

    bridge.observedSignal = signal

    system.log(
        "[Ship Finder Attention Immediate Bridge 1.4.31] SIGNAL"
        .. " | source=S3L-existing-variable"
        .. " | previous=" .. tostring(oldSignal)
        .. " | current=" .. tostring(signal)
        .. " | delta=" .. tostring(delta)
        .. " | category=" .. tostring(Variables:GetVariable("S3C") or 0)
        .. " | action=request-proven-parchment-now"
    )

    self:_sf1425OpenAttentionParchmentNow()
    return true
end



-- Ship Finder v1.4.34 analytical Fleet parchments.
-- Menus choose the analytical view; parchments show the fleet together.
ShipFinderFleetReport = ShipFinderFleetReport or {
    active = false,
    opening = false,
    mode = nil,
    page = 0,
    visible = {},
    pageStorylines = { [1] = 2099601, [2] = 2099602, [3] = 2099603, [4] = 2099604, [5] = 2099605, [6] = 2099606, [7] = 2099607, [8] = 2099608, [9] = 2099609, [10] = 2099610, [11] = 2099611, [12] = 2099612 },
}

function ShipFinderFleetReport.getPopupContent()
    local content = nil
    pcall(function()
        content = ui
            and ui.Scenes
            and ui.Scenes.TextPopup
            and ui.Scenes.TextPopup.SceneData
            and ui.Scenes.TextPopup.SceneData.Content
            or nil
    end)
    return content
end

function ShipFinderFleetReport.records(mode)
    local records = {}
    local issues = ShipFinderNativeIssueRouteSnapshot()

    for _, object in pairs(
        Scripts:GetObjectGroupByProperty(Properties.ShipModuleOwner) or {}
    ) do
        local rawName = object.Nameable and object.Nameable.Name
        if rawName ~= nil then
            local name = tostring(rawName)
            local route = object.TradeRouteVehicle
            local assigned = route
                and route.IsAssignedOnTradeRoute == true
            local routeName = route and route.RouteName or nil
            local military = object.Unit
                and object.Unit.IsMilitaryUnit == true
            local issue = routeName ~= nil
                and issues[ShipFinderNativeRouteKey(routeName)]
                or nil

            local include = false
            local group = ""
            local groupOrder = 9

            if mode == "all" then
                include = true
                if military then
                    group = "warships"
                    groupOrder = 3
                elseif assigned then
                    group = "assigned"
                    groupOrder = 1
                else
                    group = "independent"
                    groupOrder = 2
                end
            elseif mode == "routes" then
                include = assigned and routeName ~= nil
                group = tostring(routeName or "")
                groupOrder = issue ~= nil and 1 or 2
            elseif mode == "independent" then
                include = not military and not assigned
                group = "independent"
                groupOrder = 1
            elseif mode == "warships" then
                include = military
                group = "warships"
                groupOrder = 1
            end

            if include then
                local routeText = tostring(routeName or "")
                local key = ""

                if mode == "routes" then
                    key = tostring(groupOrder)
                        .. "|" .. string.lower(routeText)
                        .. "|" .. string.lower(name)
                        .. "|" .. tostring(object.ID)
                else
                    key = tostring(groupOrder)
                        .. "|" .. string.lower(name)
                        .. "|" .. string.lower(routeText)
                        .. "|" .. tostring(object.ID)
                end

                records[#records + 1] = {
                    name = name,
                    id = tostring(object.ID),
                    routeName = routeText,
                    group = group,
                    key = key,
                    warning = issue ~= nil,
                    military = military,
                    assigned = assigned,
                }
            end
        end
    end

    table.sort(records, function(a, b)
        return a.key < b.key
    end)

    return records
end

function ShipFinderFleetReport.groupCount(records, group)
    local count = 0
    for _, record in ipairs(records or {}) do
        if record.group == group then
            count = count + 1
        end
    end
    return count
end

function ShipFinderFleetReport.title(mode, de)
    local fr = not de and tostring(ShipFinderUILanguage or "") == "fr"
    if mode == "all" then
        return de and "FLOTTE — ALLE SCHIFFE"
            or (fr and "FLOTTE — TOUS LES NAVIRES"
                or "FLEET — ALL SHIPS")
    elseif mode == "routes" then
        return de and "FLOTTE — ROUTENZUWEISUNG"
            or (fr and "FLOTTE — AFFECTATION AUX ROUTES COMMERCIALES"
                or "FLEET — ROUTE ALLOCATION")
    elseif mode == "independent" then
        return de and "FLOTTE — UNABHÄNGIGE SCHIFFE"
            or (fr and "FLOTTE — NAVIRES INDÉPENDANTS"
                or "FLEET — INDEPENDENT SHIPS")
    elseif mode == "warships" then
        return de and "FLOTTE — KRIEGSSCHIFFE"
            or (fr and "FLOTTE — NAVIRES DE GUERRE"
                or "FLEET — WARSHIPS")
    end
    return de and "FLOTTENÜBERSICHT"
        or (fr and "VUE D’ENSEMBLE DE LA FLOTTE" or "FLEET OVERVIEW")
end

function ShipFinderFleetReport.pageText(pageIndex)
    local mode = ShipFinderFleetReport.mode or "all"
    local de = tostring(ShipFinderUILanguage or "") == "de"
    local fr = tostring(ShipFinderUILanguage or "") == "fr"
    local records = ShipFinderFleetReport.records(mode)
    local pages = math.max(1, math.ceil(#records / 9))
    local page = math.max(0, tonumber(pageIndex) or 0)

    if page >= pages then
        page = pages - 1
    end

    ShipFinderFleetReport.page = page
    ShipFinderFleetReport.visible = {}

    local first = page * 9 + 1
    local last = math.min(first + 8, #records)

    local subtitle = ""
    if mode == "routes" then
        local representedRoutes = {}
        local representedRouteCount = 0

        for _, record in ipairs(records) do
            local routeName = tostring(record.routeName or "")
            if routeName ~= "" and representedRoutes[routeName] ~= true then
                representedRoutes[routeName] = true
                representedRouteCount = representedRouteCount + 1
            end
        end

        subtitle = de
            and (tostring(#records) .. " zugewiesene Schiffe • "
                .. tostring(representedRouteCount) .. " Routen")
            or (fr
                and (tostring(#records) .. " navires affectés • "
                    .. tostring(representedRouteCount) .. " routes commerciales")
                or (tostring(#records) .. " assigned ships • "
                    .. tostring(representedRouteCount) .. " routes"))
    else
        subtitle = tostring(#records)
            .. (de and " Schiffe • Aktuelle Provinz/Sitzung"
                or (fr and " navires • Province/session actuelle"
                    or " ships • Current province/session"))
    end

    local lines = {
        ShipFinderFleetReport.title(mode, de),
        "",
        subtitle,
        de and "Strg+Alt+1-9: Zum nummerierten Schiff springen"
            or (fr and "Ctrl+Alt+1-9 : accéder au navire numéroté"
                or "Ctrl+Alt+1-9: Jump to numbered ship"),
        de and "Strg+Alt+0: Zurueck zum Ship Finder-Menue"
            or (fr and "Ctrl+Alt+0 : retour au menu Ship Finder"
                or "Ctrl+Alt+0: Back to Ship Finder menu"),
    }

    if pages > 1 then
        lines[#lines + 1] =
            (de and "Seite " or (fr and "Page " or "Page "))
            .. tostring(page + 1) .. "/" .. tostring(pages)
    end

    lines[#lines + 1] = ""

    if #records == 0 then
        if mode == "independent" then
            lines[#lines + 1] = de
                and "Keine unabhängigen zivilen Schiffe in dieser Provinz."
                or (fr and "Aucun navire civil indépendant dans cette province."
                    or "No independent non-military ships in this province.")
        elseif mode == "warships" then
            lines[#lines + 1] = de
                and "Keine Kriegsschiffe in dieser Provinz."
                or (fr and "Aucun navire de guerre dans cette province."
                    or "No warships in this province.")
        elseif mode == "routes" then
            lines[#lines + 1] = de
                and "Keine aktuell zugewiesenen Schiffe auf Handelsrouten."
                or (fr and "Aucun navire n’est actuellement affecté à une route commerciale."
                    or "No ships are currently assigned to trade routes.")
        else
            lines[#lines + 1] = de
                and "Keine sichtbaren Schiffe in dieser Provinz."
                or (fr and "Aucun navire visible dans cette province."
                    or "No visible ships in this province.")
        end
        return table.concat(lines, "\n")
    end

    local lastGroup = nil

    for index = first, last do
        local record = records[index]
        local slot = index - first + 1

        if record.group ~= lastGroup then
            if lastGroup ~= nil then
                lines[#lines + 1] = ""
            end

            local count =
                ShipFinderFleetReport.groupCount(records, record.group)

            if mode == "all" then
                if record.group == "assigned" then
                    lines[#lines + 1] = de
                        and ("▶ HANDELSROUTEN-SCHIFFE — "
                            .. tostring(count))
                        or (fr and ("▶ NAVIRES DES ROUTES COMMERCIALES — "
                            .. tostring(count))
                            or ("▶ TRADE ROUTE SHIPS — "
                                .. tostring(count)))
                elseif record.group == "independent" then
                    lines[#lines + 1] = de
                        and ("UNABHÄNGIGE ZIVILE SCHIFFE — "
                            .. tostring(count))
                        or (fr and ("NAVIRES CIVILS INDÉPENDANTS — "
                            .. tostring(count))
                            or ("INDEPENDENT NON-MILITARY SHIPS — "
                                .. tostring(count)))
                else
                    lines[#lines + 1] = de
                        and ("KRIEGSSCHIFFE — " .. tostring(count))
                        or (fr and ("NAVIRES DE GUERRE — " .. tostring(count))
                            or ("WARSHIPS — " .. tostring(count)))
                end
            elseif mode == "routes" then
                lines[#lines + 1] =
                    (record.warning and "⚠ " or "")
                    .. "▶ " .. record.routeName
                    .. " — " .. tostring(count)
                    .. (de
                        and (count == 1 and " Schiff" or " Schiffe")
                        or (fr
                            and (count == 1 and " navire" or " navires")
                            or (count == 1 and " ship" or " ships")))
            end

            lastGroup = record.group
        end

        ShipFinderFleetReport.visible[slot] = {
            id = record.id,
            name = record.name,
            routeName = record.routeName,
        }

        if mode == "all"
            and record.group == "assigned"
            and record.routeName ~= ""
        then
            lines[#lines + 1] = tostring(slot)
                .. ". ★ " .. record.name
                .. " — ▶ " .. record.routeName
        else
            lines[#lines + 1] = tostring(slot)
                .. ". ★ " .. record.name
        end
    end

    return table.concat(lines, "\n")
end

function ShipFinderFleetReport.isReportOpen()
    if ShipFinderFleetReport.active ~= true then
        return false
    end

    local content = ShipFinderFleetReport.getPopupContent()
    if content == nil then
        return false
    end

    local text = ""
    pcall(function()
        text = tostring(content.Text or "")
    end)

    return text:find("FLEET — ", 1, true) == 1
        or text:find("FLOTTE — ", 1, true) == 1
        or text:find("FLEET SUMMARY", 1, true) == 1
        or text:find("FLOTTENZUSAMMENFASSUNG", 1, true) == 1
        or text:find("RÉSUMÉ DE LA FLOTTE", 1, true) == 1
        or text:find("VUE D’ENSEMBLE DE LA FLOTTE", 1, true) == 1
end

function CombinedRoot:FleetReportShortcut(slot)
    slot = tonumber(slot) or 0
    if slot < 1 or slot > 9 then
        return false
    end

    if not ShipFinderFleetReport.isReportOpen() then
        return false
    end

    local record = ShipFinderFleetReport.visible[slot]
    if record == nil then
        system.log(
            "[Ship Finder Fleet Analysis 1.4.36] SLOT EMPTY"
            .. " | mode=" .. tostring(ShipFinderFleetReport.mode or "")
            .. " | page=" .. tostring((ShipFinderFleetReport.page or 0) + 1)
            .. " | slot=" .. tostring(slot)
        )
        return false
    end

    local fresh = nil
    for _, object in pairs(
        Scripts:GetObjectGroupByProperty(Properties.ShipModuleOwner) or {}
    ) do
        if tostring(object.ID) == tostring(record.id) then
            fresh = object
            break
        end
    end

    if fresh == nil then
        system.log(
            "[Ship Finder Fleet Analysis 1.4.36] SHIP UNAVAILABLE"
            .. " | name=" .. tostring(record.name)
            .. " | id=" .. tostring(record.id)
        )
        return false
    end

    local nativeID = fresh.ID
    local closeOk, closeErr = pcall(function()
        Scripts:PopUI()
    end)
    local selectOk, selectErr = pcall(function()
        Selection:SelectByID(nativeID)
    end)
    local jumpOk, jumpErr = pcall(function()
        Scripts:JumpToObject(nativeID)
    end)

    ShipFinderFleetReport.active = false
    ShipFinderFleetReport.opening = false
    ShipFinderFleetReport.visible = {}

    system.log(
        "[Ship Finder Fleet Analysis 1.4.36] SHIP JUMP"
        .. " | mode=" .. tostring(ShipFinderFleetReport.mode or "")
        .. " | page=" .. tostring((ShipFinderFleetReport.page or 0) + 1)
        .. " | slot=" .. tostring(slot)
        .. " | name=" .. tostring(record.name)
        .. " | objectId=" .. tostring(nativeID)
        .. " | closeSuccess=" .. tostring(closeOk)
        .. " | selectSuccess=" .. tostring(selectOk)
        .. " | jumpSuccess=" .. tostring(jumpOk)
        .. " | closeError=" .. tostring(closeErr or "")
        .. " | selectError=" .. tostring(selectErr or "")
        .. " | jumpError=" .. tostring(jumpErr or "")
    )

    return jumpOk
end

-- Ship Finder v1.4.34 Fleet Overview analytical parchment bridge.
-- S3F increments encode which Fleet report was chosen:
-- +1000 Summary, +2000 All Ships, +3000 Route Allocation,
-- +4000 Independent Ships, +5000 Warships, +6000 Attention.
-- Each signal routes through the proven Safe Close component before Tick sees it.
CombinedRoot.FleetOverviewParchmentBridge = CombinedRoot.FleetOverviewParchmentBridge or {
    observedSignal = nil,
    observedSummarySignal = nil,
}

function CombinedRoot:_sf1432FleetOverviewSignal()
    local ok, value = pcall(function()
        return Variables:GetVariable("S3F")
    end)
    if not ok or value == nil then return 0 end
    return tonumber(value) or 0
end

function CombinedRoot:_sf1441FleetSummarySignal()
    local ok, value = pcall(function()
        return Variables:GetVariable("S3L")
    end)
    if not ok or value == nil then return 0 end
    return tonumber(value) or 0
end

function CombinedRoot:_sf1432ResetFleetOverviewBridge()
    local bridge = self.FleetOverviewParchmentBridge
    bridge.observedSignal = self:_sf1432FleetOverviewSignal()
    bridge.observedSummarySignal = self:_sf1441FleetSummarySignal()

    if ShipFinderFleetReport ~= nil then
        ShipFinderFleetReport.active = false
        ShipFinderFleetReport.opening = false
        ShipFinderFleetReport.mode = nil
        ShipFinderFleetReport.page = 0
        ShipFinderFleetReport.visible = {}
    end

    system.log(
        "[Ship Finder Fleet Analysis Bridge 1.4.41] RESET"
        .. " | signal=" .. tostring(bridge.observedSignal)
        .. " | summarySignal=" .. tostring(bridge.observedSummarySignal)
        .. " | safeClose=2099398"
    )
end

function CombinedRoot:_sf1432TickFleetOverviewBridge()
    local bridge = self.FleetOverviewParchmentBridge

    local summarySignal = self:_sf1441FleetSummarySignal()
    if bridge.observedSummarySignal == nil then
        bridge.observedSummarySignal = summarySignal
    end

    local oldSummarySignal =
        tonumber(bridge.observedSummarySignal) or 0
    local summaryDelta = summarySignal - oldSummarySignal

    if summaryDelta >= 10000 then
        bridge.observedSummarySignal = summarySignal

        ShipFinderFleetReport.mode = "summary"
        ShipFinderFleetReport.page = 0
        ShipFinderFleetReport.visible = {}
        ShipFinderFleetReport.active = false
        ShipFinderFleetReport.opening = true

        system.log(
            "[Ship Finder Fleet Summary Robust Handoff 1.4.41] SIGNAL"
            .. " | previous=" .. tostring(oldSummarySignal)
            .. " | current=" .. tostring(summarySignal)
            .. " | delta=" .. tostring(summaryDelta)
            .. " | storyline=2099540"
            .. " | action=request-now"
        )

        local ok, err = pcall(function()
            GovernorDecision:CheatStartGovernorDecisionForCurrentPlayerNet(
                2099540
            )
        end)

        system.log(
            "[Ship Finder Fleet Summary Robust Handoff 1.4.41] REQUEST"
            .. " | storyline=2099540"
            .. " | success=" .. tostring(ok)
            .. " | error=" .. tostring(err or "")
        )

        if not ok then
            ShipFinderFleetReport.opening = false
            ShipFinderFleetReport.active = false
        end

        return true
    elseif summarySignal ~= oldSummarySignal then
        -- Track ordinary small S3L changes from legacy ship-navigation menus.
        bridge.observedSummarySignal = summarySignal
    end

    local signal = self:_sf1432FleetOverviewSignal()

    if bridge.observedSignal == nil then
        bridge.observedSignal = signal
    end

    local oldSignal = tonumber(bridge.observedSignal) or 0
    local delta = signal - oldSignal

    if delta < 1000 then
        if signal ~= oldSignal then
            bridge.observedSignal = signal
        end
        return false
    end

    bridge.observedSignal = signal

    local reportNumber = math.floor(delta / 1000)
    local mode = nil
    if reportNumber == 1 then
        mode = "summary"
    elseif reportNumber == 2 then
        mode = "all"
    elseif reportNumber == 3 then
        mode = "routes"
    elseif reportNumber == 4 then
        mode = "independent"
    elseif reportNumber == 5 then
        mode = "warships"
    elseif reportNumber == 6 then
        mode = "attention"
    end

    if mode == nil then
        system.log(
            "[Ship Finder Fleet Analysis Bridge 1.4.37] ABORT"
            .. " | reason=unknown-mode"
            .. " | delta=" .. tostring(delta)
        )
        return false
    end

    if mode == "attention" then
        system.log(
            "[Ship Finder Attention On-Demand 1.5.0] SIGNAL"
            .. " | source=S3F-proven-post-yield-bridge"
            .. " | previous=" .. tostring(oldSignal)
            .. " | current=" .. tostring(signal)
            .. " | delta=" .. tostring(delta)
            .. " | action=start-attention-scan"
        )

        -- This signal is observed only after Safe Close has allowed the
        -- active NarrativeSequence to leave. Starting the native Trade Route
        -- scan here therefore preserves the proven freeze-safe architecture.
        ShipFinderAttentionScanRequested = true
        islandScanRequested = false
        ShipFinderAttentionWarningDetailCache = {}
        ShipFinderAttentionRealRouteCache = nil
        ShipFinderNativeIssueRouteCache =
            ShipFinderNativeIssueRouteSnapshot()

        if ShipFinderAttentionWarningStatesProbe ~= nil then
            ShipFinderAttentionWarningStatesProbe.active = false
            ShipFinderAttentionWarningStatesProbe.queue = {}
            ShipFinderAttentionWarningStatesProbe.index = 0
            ShipFinderAttentionWarningStatesProbe.phase = "idle"
            ShipFinderAttentionWarningStatesProbe.focusedName = nil
        end

        directOpenPending = false
        directOpenAttempt = 0

        ntBegin()
        return true
    end

    local storyline = 2099540
    local count = 0
    local pages = 1

    if mode == "summary" then
        ShipFinderFleetReport.mode = "summary"
        ShipFinderFleetReport.page = 0
        ShipFinderFleetReport.visible = {}
        ShipFinderFleetReport.active = false
        ShipFinderFleetReport.opening = true
    else
        ShipFinderFleetReport.mode = mode
        ShipFinderFleetReport.page = 0
        ShipFinderFleetReport.visible = {}
        ShipFinderFleetReport.active = false
        ShipFinderFleetReport.opening = true

        count = #ShipFinderFleetReport.records(mode)
        pages = math.max(1, math.ceil(count / 9))

        if pages <= 12 then
            storyline =
                ShipFinderFleetReport.pageStorylines[pages]
        else
            storyline = ISLAND_REPORT_STORYLINE
        end
    end

    system.log(
        "[Ship Finder Fleet Analysis Bridge 1.4.37] SIGNAL"
        .. " | previous=" .. tostring(oldSignal)
        .. " | current=" .. tostring(signal)
        .. " | delta=" .. tostring(delta)
        .. " | mode=" .. tostring(mode)
        .. " | ships=" .. tostring(count)
        .. " | pages=" .. tostring(pages)
        .. " | storyline=" .. tostring(storyline)
        .. " | action=request-now"
    )

    local ok, err = pcall(function()
        GovernorDecision:CheatStartGovernorDecisionForCurrentPlayerNet(
            storyline
        )
    end)

    system.log(
        "[Ship Finder Fleet Analysis 1.4.36] STORYLINE REQUEST"
        .. " | mode=" .. tostring(mode)
        .. " | storyline=" .. tostring(storyline)
        .. " | success=" .. tostring(ok)
        .. " | error=" .. tostring(err or "")
    )

    if not ok and ShipFinderFleetReport ~= nil then
        ShipFinderFleetReport.active = false
        ShipFinderFleetReport.opening = false
    end

    return true
end

function CombinedRoot:Tick()
    if nativeTradeRouteToggleActive then
        ntTick()
        return
    end

    if ShipFinderFleetReport ~= nil
        and ShipFinderFleetReport.returnMainPending == true
    then
        ShipFinderFleetReport.returnMainPending = false

        system.log(
            "[Ship Finder Fleet Analysis 1.4.36] RETURN MAIN"
            .. " | action=proven-native-menu-opener"
            .. " | rescan=false"
        )

        ntOpenShipFinderMenu()
        return
    end

    if self:_sf1425TickAttentionMenuBridge() then
        return
    end

    if self:_sf1432TickFleetOverviewBridge() then
        return
    end

    if ShipFinderAttentionParchmentTest ~= nil
        and ShipFinderAttentionParchmentTest.pendingOpen == true
    then
        ShipFinderAttentionParchmentTest.pendingOpen = false
        ShipFinderAttentionParchmentTest.opening = true

        local attentionCount = #ShipFinderAttentionParchmentTest.records()
        local attentionStoryline =
            attentionCount <= 9 and 2099210 or ISLAND_REPORT_STORYLINE

        local ok, err = pcall(function()
            GovernorDecision:CheatStartGovernorDecisionForCurrentPlayerNet(
                attentionStoryline
            )
        end)
        system.log(
            "[Ship Finder Attention Report 1.4.31] STORYLINE REQUEST"
            .. " | deferredTicks=1"
            .. " | ships=" .. tostring(attentionCount)
            .. " | mode=" .. tostring(attentionCount <= 9 and "single-page" or "multi-page")
            .. " | storyline=" .. tostring(attentionStoryline)
            .. " | success=" .. tostring(ok)
            .. " | error=" .. tostring(err or "")
        )
        if not ok then
            ShipFinderAttentionParchmentTest.opening = false
            ShipFinderAttentionParchmentTest.active = false
        end
        return
    end

    if ShipFinderIslandUI and ShipFinderIslandUI.pendingIslandOpen then
        ShipFinderIslandUI.pendingIslandOpen = false
        local ok, err = pcall(function()
            GovernorDecision:CheatStartGovernorDecisionForCurrentPlayerNet(
                ISLAND_REPORT_STORYLINE
            )
        end)
        system.log(
            "[Ship Finder Island Navigation 1.1.1] ISLAND REPORT OPEN"
            .. " | island=" .. tostring(ShipFinderIslandUI.selectedIsland or "")
            .. " | deferredTicks=1"
            .. " | success=" .. tostring(ok)
            .. " | error=" .. tostring(err or "")
        )
        return
    end

    if tickShipsByIslandUI() then
        return
    end

    if ShipFinderAttentionParchmentTest ~= nil
        and ShipFinderAttentionParchmentTest.active == true
        and ShipFinderAttentionParchmentTest.opening ~= true
        and ShipFinderAttentionParchmentTest.getPopupContent() == nil
    then
        ShipFinderAttentionParchmentTest.active = false
        ShipFinderAttentionParchmentTest.visible = {}
        system.log(
            "[Ship Finder Attention Report 1.4.31] CLOSED"
            .. " | action=state-cleared"
        )
    end

    if self:_sf1197TickIslandJumpWatch() then
        return
    end

    if self:_sf1192TickMultiRouteBridge() then
        return
    end

    if not directOpenPending then
        return
    end

    if tryDirectOpenGovernorRequest("DELAYED_RETRY") then
        directOpenPending = false
        system.log(
            "[Ship Finder Direct Menu Open 1.1.0] COMPLETE"
            .. " | menu request activated automatically"
            .. " | attempt=" .. tostring(directOpenAttempt)
        )
        return
    end

    if directOpenAttempt >= DIRECT_OPEN_MAX_ATTEMPTS then
        directOpenPending = false
        system.log(
            "[Ship Finder Direct Menu Open 1.1.0] TIMEOUT"
            .. " | attempts=" .. tostring(directOpenAttempt)
        )
    end
end


function CombinedRoot:IslandShortcut(slot)
    slot = tonumber(slot) or 0

    if ShipFinderFleetReport ~= nil
        and ShipFinderFleetReport.isReportOpen ~= nil
        and ShipFinderFleetReport.isReportOpen()
    then
        return self:FleetReportShortcut(slot)
    end

    if ShipFinderAttentionParchmentTest ~= nil
        and ShipFinderAttentionParchmentTest.isReportOpen ~= nil
        and ShipFinderAttentionParchmentTest.isReportOpen()
    then
        return self:AttentionParchmentTestShortcut(slot)
    end

    if slot < 1 or slot > 9 then
        return false
    end

    if not ShipFinderIslandUI or not ShipFinderIslandUI.isReportOpen() then
        return false
    end

    if ShipFinderIslandUI.jumpInProgress then
        system.log(
            "[Ship Finder Island Navigation 1.1.0] DUPLICATE SHORTCUT IGNORED"
            .. " | slot=" .. tostring(slot)
        )
        return false
    end

    if not ShipFinderIslandUI.resumeMode
        and ShipFinderIslandUI.mode == "islands"
        and ShipFinderIslandUI.islandForShortcutSlot
    then
        local islandName = ShipFinderIslandUI.islandForShortcutSlot(slot)
        if islandName == nil then
            system.log(
                "[Ship Finder Island Navigation 1.1.1] ISLAND SLOT EMPTY"
                .. " | islandPage="
                .. tostring((ShipFinderIslandUI.islandPage or 0) + 1)
                .. " | slot=" .. tostring(slot)
            )
            return false
        end

        ShipFinderIslandUI.mode = "ships"
        ShipFinderIslandUI.selectedIsland = islandName
        ShipFinderIslandUI.shipPage = 0
        islandReportMarkerHandled = false
        islandScanMarkerHandled = false

        local closeOk, closeErr = pcall(function() Scripts:PopUI() end)
        ShipFinderIslandUI.pendingIslandOpen = closeOk

        system.log(
            "[Ship Finder Island Navigation 1.1.1] ISLAND SELECT"
            .. " | island=" .. tostring(islandName)
            .. " | islandPage="
            .. tostring((ShipFinderIslandUI.islandPage or 0) + 1)
            .. " | slot=" .. tostring(slot)
            .. " | closeSuccess=" .. tostring(closeOk)
            .. " | reportOpen=deferred-next-tick"
            .. " | closeError=" .. tostring(closeErr or "")
        )
        return closeOk
    end

    local ship = nil
    local resumeIsland = nil
    if ShipFinderIslandUI.resumeMode
        and ShipFinderIslandUI.resumeIslandPageText
    then
        local _, ships = ShipFinderIslandUI.resumeIslandPageText(
            ShipFinderIslandUI.page or 0
        )
        ship = ships and ships[slot] or nil
        resumeIsland = ShipFinderIslandUI.selectedIsland
    elseif ShipFinderIslandUI.mode == "ships"
        and ShipFinderIslandUI.shipPageText
    then
        local _, ships = ShipFinderIslandUI.shipPageText()
        ship = ships and ships[slot] or nil
        resumeIsland = ShipFinderIslandUI.selectedIsland
    elseif ShipFinderIslandUI.pageEntry then
        ship, resumeIsland = ShipFinderIslandUI.pageEntry(
            ShipFinderIslandUI.page or 0,
            slot
        )
    else
        local _, ships = ShipFinderIslandUI.pageText(
            ShipFinderIslandUI.page or 0
        )
        ship = ships and ships[slot] or nil
    end

    if not ship then
        system.log(
            "[Ship Finder Island Navigation 1.1.0] SHIP SLOT EMPTY"
            .. " | page=" .. tostring((ShipFinderIslandUI.page or 0) + 1)
            .. " | slot=" .. tostring(slot)
        )
        return false
    end

    local liveShip, resolveMethod =
        ShipFinderIslandUI.resolveLiveShip(ship)

    local function showUnavailable(reason, shipSession, currentSession)
        local shipName = tostring(ship.name or "This ship")
        local routeName = tostring(ship.routeName or "")
        ShipFinderIslandUI.jumpInProgress = false
        system.log(
            "[Ship Finder Island Navigation 1.1.0] SHIP UNAVAILABLE DEFERRED"
            .. " | page=" .. tostring((ShipFinderIslandUI.page or 0) + 1)
            .. " | slot=" .. tostring(slot)
            .. " | ship=" .. shipName
            .. " | route=" .. routeName
            .. " | reason=" .. tostring(reason or "")
            .. " | shipSession=" .. tostring(shipSession or "")
            .. " | currentSession=" .. tostring(currentSession or "")
            .. " | action=no-message-no-jump-report-stays-open"
        )
        return false
    end

    if liveShip == nil then
        -- The report is built from live assignments, so a ship disappearing before the
        -- click normally means it moved out of the current session between report build
        -- and selection. Keep the parchment open and tell the player instead of jumping
        -- to an invalid/stale object.
        return showUnavailable(resolveMethod, nil, ShipFinderIslandCache.currentSessionGUID())
    end

    local liveSession = nil
    local currentSession = nil
    pcall(function() liveSession = liveShip.SessionGuid end)
    pcall(function()
        currentSession = GameSession and GameSession.SessionGUID or nil
    end)

    if liveSession ~= nil
        and currentSession ~= nil
        and tostring(liveSession) ~= tostring(currentSession)
    then
        return showUnavailable("session-mismatch", liveSession, currentSession)
    end

    local liveID = liveShip.ID
    ShipFinderIslandUI.jumpInProgress = true

    system.log(
        "[Ship Finder Island Navigation 1.1.0] SHIP SELECT"
        .. " | page=" .. tostring((ShipFinderIslandUI.page or 0) + 1)
        .. " | slot=" .. tostring(slot)
        .. " | ship=" .. tostring(ship.name)
        .. " | liveObjectId=" .. tostring(liveID)
        .. " | resolveMethod=" .. tostring(resolveMethod)
        .. " | shipSession=" .. tostring(liveSession or "")
        .. " | currentSession=" .. tostring(currentSession or "")
    )

    -- Proven Ships-by-Island path: close parchment first, then select/jump using the
    -- fresh object's native ID. Do not convert the native ID to a Lua number.
    -- Capture OMShipUnit BEFORE the jump so stale SceneData cannot be mistaken for
    -- a newly opened ship window (Traveler 1 v1.1.0 runtime proof).
    local preJumpShipViewSignature = self:_sf1197ShipViewSignature()
    local closeOk, closeErr = pcall(function()
        Scripts:PopUI()
    end)

    local selectOk, selectErr = pcall(function()
        Selection:SelectByID(liveID)
    end)

    local jumpOk, jumpErr = pcall(function()
        Scripts:JumpToObject(liveID)
    end)

    -- v1.1.0: do not infer availability from stale OMShipUnit SceneData. Runtime
    -- proof in v1.1.0 showed that a VALID local ship can open OMShipUnit while every
    -- readable SceneData signature remains unchanged, causing a false warning only
    -- after the player closes the ship window. Keep warnings deterministic instead:
    -- missing live object, real session mismatch, or an actual select/jump call failure.
    self.IslandJumpWatch.pending = false
    self.IslandJumpWatch.ticks = 0

    local ok = closeOk and selectOk and jumpOk
    ShipFinderIslandUI.jumpInProgress = false

    if ok and resumeIsland ~= nil and ShipFinderIslandUI.armResume then
        ShipFinderIslandUI.armResume(resumeIsland)
    end

    if not ok then
        local failure = not closeOk and "popup-close-failed"
            or (not selectOk and "select-failed")
            or "jump-failed"
        system.log(
            "[Ship Finder Island Navigation 1.1.0] SHIP JUMP API FAILURE"
            .. " | ship=" .. tostring(ship.name)
            .. " | reason=" .. tostring(failure)
            .. " | action=no-message-deferred"
        )
    end

    system.log(
        "[Ship Finder Island Navigation 1.1.0] SHIP JUMP"
        .. " | ship=" .. tostring(ship.name)
        .. " | liveObjectId=" .. tostring(liveID)
        .. " | resolveMethod=" .. tostring(resolveMethod)
        .. " | shipSession=" .. tostring(liveSession or "")
        .. " | currentSession=" .. tostring(currentSession or "")
        .. " | closeSuccess=" .. tostring(closeOk)
        .. " | selectSuccess=" .. tostring(selectOk)
        .. " | jumpSuccess=" .. tostring(jumpOk)
        .. " | availabilityWatch=deterministic-only"
        .. " | baselineShipView=" .. tostring(preJumpShipViewSignature)
        .. " | closeError=" .. tostring(closeErr or "")
        .. " | selectError=" .. tostring(selectErr or "")
        .. " | jumpError=" .. tostring(jumpErr or "")
    )

    return ok
end

function CombinedRoot:IslandAllIslands()
    if ShipFinderFleetReport ~= nil
        and ShipFinderFleetReport.isReportOpen ~= nil
        and ShipFinderFleetReport.isReportOpen()
    then
        local mode = tostring(ShipFinderFleetReport.mode or "")
        local closeOk, closeErr = pcall(function()
            Scripts:PopUI()
        end)

        ShipFinderFleetReport.active = false
        ShipFinderFleetReport.opening = false
        ShipFinderFleetReport.page = 0
        ShipFinderFleetReport.visible = {}
        ShipFinderFleetReport.returnMainPending = closeOk

        system.log(
            "[Ship Finder Fleet Analysis 1.4.36] CTRL ALT 0"
            .. " | mode=" .. mode
            .. " | action=return-main-menu-deferred"
            .. " | closeSuccess=" .. tostring(closeOk)
            .. " | error=" .. tostring(closeErr or "")
        )

        return closeOk
    end

    if ShipFinderAttentionParchmentTest ~= nil
        and ShipFinderAttentionParchmentTest.isReportOpen ~= nil
        and ShipFinderAttentionParchmentTest.isReportOpen()
    then
        local closeOk, closeErr = pcall(function()
            Scripts:PopUI()
        end)

        ShipFinderAttentionParchmentTest.active = false
        ShipFinderAttentionParchmentTest.opening = false
        ShipFinderAttentionParchmentTest.pendingOpen = false
        ShipFinderAttentionParchmentTest.page = 0
        ShipFinderAttentionParchmentTest.visible = {}

        if ShipFinderFleetReport ~= nil then
            ShipFinderFleetReport.returnMainPending = closeOk
        end

        system.log(
            "[Ship Finder Fleet Analysis 1.4.36] CTRL ALT 0"
            .. " | mode=attention"
            .. " | action=return-main-menu-deferred"
            .. " | closeSuccess=" .. tostring(closeOk)
            .. " | error=" .. tostring(closeErr or "")
        )

        return closeOk
    end

    if not ShipFinderIslandUI
        or not ShipFinderIslandUI.isReportOpen
        or not ShipFinderIslandUI.isReportOpen()
        or (not ShipFinderIslandUI.resumeMode
            and ShipFinderIslandUI.mode ~= "ships")
    then
        return false
    end

    ShipFinderIslandUI.resumeMode = false
    ShipFinderIslandUI.mode = "islands"
    ShipFinderIslandUI.page = 0
    ShipFinderIslandUI.islandPage = 0
    ShipFinderIslandUI.shipPage = 0
    ShipFinderIslandUI.jumpInProgress = false
    islandReportMarkerHandled = false
    islandScanMarkerHandled = false

    -- Reopen the existing report at native page 1. This resets the parchment's
    -- arrow state while preserving the proven topology cache and avoiding a scan.
    local closeOk, closeErr = pcall(function() Scripts:PopUI() end)
    ShipFinderIslandUI.pendingIslandOpen = closeOk
    system.log(
        "[Ship Finder Fast Resume 1.4.10] ALL ISLANDS"
        .. " | cachePreserved=true"
        .. " | topologyRescan=false"
        .. " | reportOpen=deferred-next-tick"
        .. " | success=" .. tostring(closeOk)
        .. " | error=" .. tostring(closeErr or "")
    )
    return closeOk
end

function CombinedRoot:IslandNextPage()
    return false
end

function CombinedRoot:IslandBack()
    return false
end


function CombinedRoot:SetIslandFilterFast(helper)
    self.islandFilterFast = helper

    local ready =
        helper ~= nil
        and type(helper.Start) == "function"
        and type(helper.Tick) == "function"
        and type(helper.IsActive) == "function"
        and type(helper.GetResult) == "function"

    system.log(
        "[Ship Finder Island Filter Bridge 1.1.0]"
        .. " ATTACH"
        .. " | helperPresent=" .. tostring(helper ~= nil)
        .. " | start=" .. tostring(helper and type(helper.Start) == "function")
        .. " | tick=" .. tostring(helper and type(helper.Tick) == "function")
        .. " | isActive=" .. tostring(helper and type(helper.IsActive) == "function")
        .. " | getResult=" .. tostring(helper and type(helper.GetResult) == "function")
        .. " | ready=" .. tostring(ready)
    )

    return ready
end

function CombinedRoot:IsIslandFilterFastReady()
    local helper = self.islandFilterFast
    return
        helper ~= nil
        and type(helper.Start) == "function"
        and type(helper.Tick) == "function"
        and type(helper.IsActive) == "function"
        and type(helper.GetResult) == "function"
end

function CombinedRoot:Load()
    system.log(
        "[Ship Finder Island Filter Bridge 1.1.0]"
        .. " LOAD CHECK"
        .. " | ready=" .. tostring(self:IsIslandFilterFastReady())
        .. " | helper=" .. tostring(self.islandFilterFast)
    )
    
-- Ships by Island cache.
-- Deliberately implemented as a GLOBAL table/functions so this very large
-- Combined Root chunk does not consume additional top-level local slots.
ShipFinderIslandCache = ShipFinderIslandCache or {}

function ShipFinderIslandCache.currentSessionGUID()
    local value = nil
    pcall(function()
        value = GameSession and GameSession.SessionGUID or nil
    end)
    return value
end

function ShipFinderIslandCache.currentRouteTopologySignature()
    local rows = ui
        and ui.Scenes
        and ui.Scenes.TradeRoute
        and ui.Scenes.TradeRoute.TradeOverview
        and ui.Scenes.TradeRoute.TradeOverview.OverviewListData
        and ui.Scenes.TradeRoute.TradeOverview.OverviewListData.ArrayData
        or nil

    if rows == nil then
        return nil
    end

    local records = {}
    local seenAny = false
    local emptyTail = 0

    for i = 0, 511 do
        local row = nil
        pcall(function() row = rows[i] end)

        if row ~= nil and string.find(tostring(row), "weak null", 1, true) == nil then
            seenAny = true
            emptyTail = 0

            local routeID, routeName, folderID = nil, nil, nil
            pcall(function() routeID = row.RouteID end)
            pcall(function() routeName = row.NameData and row.NameData.Text or nil end)
            pcall(function() folderID = row.FolderID end)

            if type(routeID) == "number" and routeID >= 0 and routeName ~= nil then
                records[#records + 1] =
                    tostring(routeID)
                    .. "|" .. tostring(routeName)
                    .. "|" .. tostring(folderID or "")
            end
        elseif seenAny then
            emptyTail = emptyTail + 1
        end

        if seenAny and emptyTail >= 16 then
            break
        end
    end

    table.sort(records)
    return table.concat(records, ";")
end

function ShipFinderIslandCache.currentAssignedShipsByRoute()
    local byRoute = {}

    for _, object in pairs(
        Scripts:GetObjectGroupByProperty(Properties.ShipModuleOwner) or {}
    ) do
        local tr = object.TradeRouteVehicle
        if tr and tr.IsAssignedOnTradeRoute and tr.RouteName ~= nil then
            local routeName = tostring(tr.RouteName)
            local shipName = nil
            pcall(function()
                shipName = object.Nameable and object.Nameable.Name or nil
            end)
            if shipName == nil or tostring(shipName) == "" then
                pcall(function() shipName = object.Name end)
            end

            local shipIDText = ""
            pcall(function() shipIDText = tostring(object.ID) end)

            local list = byRoute[routeName]
            if list == nil then
                list = {}
                byRoute[routeName] = list
            end

            list[#list + 1] = {
                name = tostring(shipName or object),
                objectKey = tostring(object),
                idText = shipIDText,
                routeName = routeName,
            }
        end
    end

    for _, list in pairs(byRoute) do
        table.sort(list, function(a, b)
            return string.lower(a.name) < string.lower(b.name)
        end)
    end

    return byRoute
end

function ShipFinderIslandCache.deriveRouteIslandMap(index)
    local map = {}

    for islandName, islandRec in pairs(index or {}) do
        for _, routeRec in ipairs(islandRec.routes or {}) do
            local routeID = routeRec.routeID
            if type(routeID) == "number" and routeID >= 0 then
                local rec = map[routeID]
                if rec == nil then
                    rec = {
                        routeID = routeID,
                        routeName = tostring(routeRec.routeName or ""),
                        islands = {},
                    }
                    map[routeID] = rec
                end
                rec.routeName = tostring(routeRec.routeName or rec.routeName or "")
                rec.islands[tostring(islandName)] = true
            end
        end
    end

    return map
end

function ShipFinderIslandCache.routeMapContainsAssignedRoutes(byRoute)
    local knownNames = {}
    for _, routeRec in pairs(ShipFinderIslandCache.routeIslandMap or {}) do
        if routeRec.routeName ~= nil and tostring(routeRec.routeName) ~= "" then
            knownNames[tostring(routeRec.routeName)] = true
        end
    end

    for routeName in pairs(byRoute or {}) do
        if not knownNames[tostring(routeName)] then
            return false, tostring(routeName)
        end
    end

    return true, nil
end

function ShipFinderIslandCache.rebuildCurrentIndex()
    local routeMap = ShipFinderIslandCache.routeIslandMap or {}
    local shipsByRoute = ShipFinderIslandCache.currentAssignedShipsByRoute()
    local index = {}
    local activeRouteSeen = {}

    for routeID, routeRec in pairs(routeMap) do
        local routeName = tostring(routeRec.routeName or "")
        local ships = shipsByRoute[routeName]

        if ships ~= nil and #ships > 0 then
            activeRouteSeen[routeID] = true

            for islandName in pairs(routeRec.islands or {}) do
                local rec = index[islandName]
                if rec == nil then
                    rec = {
                        name = tostring(islandName),
                        routes = {},
                        ships = {},
                        shipSeen = {},
                    }
                    index[islandName] = rec
                end

                local hasRoute = false
                for _, existing in ipairs(rec.routes) do
                    if existing.routeID == routeID then
                        hasRoute = true
                        break
                    end
                end
                if not hasRoute then
                    rec.routes[#rec.routes + 1] = {
                        routeID = routeID,
                        routeName = routeName,
                    }
                end

                for _, ship in ipairs(ships) do
                    local key = tostring(ship.idText or "")
                        .. "|" .. tostring(ship.name or "")
                    if not rec.shipSeen[key] then
                        rec.shipSeen[key] = true
                        rec.ships[#rec.ships + 1] = ship
                    end
                end
            end
        end
    end

    for _, rec in pairs(index) do
        table.sort(rec.routes, function(a, b)
            return string.lower(tostring(a.routeName or ""))
                < string.lower(tostring(b.routeName or ""))
        end)
        table.sort(rec.ships, function(a, b)
            return string.lower(tostring(a.name or ""))
                < string.lower(tostring(b.name or ""))
        end)
        rec.shipSeen = nil
    end

    local routeCount = 0
    for _ in pairs(activeRouteSeen) do
        routeCount = routeCount + 1
    end

    return index, routeCount, shipsByRoute
end

function ShipFinderIslandCache.invalidate(reason)
    ShipFinderIslandCache.valid = false
    ShipFinderIslandCache.reason = tostring(reason or "invalidated")

    system.log(
        "[Ship Finder Ships by Island Cache 1.1.0] INVALIDATE"
        .. " | reason=" .. ShipFinderIslandCache.reason
    )
end

function ShipFinderIslandCache.commit(index, routeCount, routeIslandMap)
    ShipFinderIslandCache.valid = true
    ShipFinderIslandCache.sessionGUID =
        ShipFinderIslandCache.currentSessionGUID()
    ShipFinderIslandCache.topologySignature =
        ShipFinderIslandCache.currentRouteTopologySignature()
    ShipFinderIslandCache.routeIslandMap = routeIslandMap
        or ShipFinderIslandCache.deriveRouteIslandMap(index)
    ShipFinderIslandCache.index = index
    ShipFinderIslandCache.routeCount = routeCount

    local nowRaw = ShipFinderIslandCache._sf1194PlayTimeRaw and ShipFinderIslandCache._sf1194PlayTimeRaw() or nil
    local startRaw = ShipFinderIslandCache.scanStartedPlayTime
    local nowWall = nil
    local nowCpu = nil
    pcall(function()
        if os and type(os.time) == "function" then nowWall = os.time() end
    end)
    pcall(function()
        if os and type(os.clock) == "function" then nowCpu = os.clock() end
    end)
    local wallDuration = ShipFinderIslandCache.scanStartedWallTime and nowWall
        and (nowWall - ShipFinderIslandCache.scanStartedWallTime) or nil
    local cpuDuration = ShipFinderIslandCache.scanStartedCpuClock and nowCpu
        and (nowCpu - ShipFinderIslandCache.scanStartedCpuClock) or nil
    local nowSeconds = ShipFinderIslandCache._sf1194SecondsFromPlayTime and ShipFinderIslandCache._sf1194SecondsFromPlayTime(nowRaw) or nil
    local startSeconds = ShipFinderIslandCache._sf1194SecondsFromPlayTime and ShipFinderIslandCache._sf1194SecondsFromPlayTime(startRaw) or nil
    ShipFinderIslandCache.lastScanPlayTimeRaw = nowRaw
    ShipFinderIslandCache.lastScanPlayTimeSeconds = nowSeconds
    if nowSeconds ~= nil and startSeconds ~= nil and nowSeconds >= startSeconds then
        ShipFinderIslandCache.lastScanDurationSeconds = nowSeconds - startSeconds
    else
        ShipFinderIslandCache.lastScanDurationSeconds = nil
    end
    ShipFinderIslandCache.scanStartedPlayTime = nil

    local islandCount = 0
    for _ in pairs(index or {}) do
        islandCount = islandCount + 1
    end

    local topologyRoutes = 0
    for _ in pairs(ShipFinderIslandCache.routeIslandMap or {}) do
        topologyRoutes = topologyRoutes + 1
    end

    system.log(
        "[Ship Finder Ships by Island Cache 1.1.0] COMMIT"
        .. " | session=" .. tostring(ShipFinderIslandCache.sessionGUID)
        .. " | islands=" .. tostring(islandCount)
        .. " | routesScanned=" .. tostring(routeCount)
        .. " | topologyRoutes=" .. tostring(topologyRoutes)
        .. " | scanReason=" .. tostring(ShipFinderIslandCache.scanStartReason)
        .. " | durationGameSec="
        .. tostring(ShipFinderIslandCache.lastScanDurationSeconds)
        .. " | durationWallSec=" .. tostring(wallDuration)
        .. " | durationCpuSec=" .. tostring(cpuDuration)
        .. " | topologySignatureChars="
        .. tostring(#(ShipFinderIslandCache.topologySignature or ""))
    )

    ShipFinderIslandCache.scanStartedWallTime = nil
    ShipFinderIslandCache.scanStartedCpuClock = nil
end

function ShipFinderIslandCache._sf1194PlayTimeRaw()
    local value = nil
    pcall(function() value = Game and Game.PlayTime or nil end)
    return value
end

function ShipFinderIslandCache._sf1194SecondsFromPlayTime(value)
    local n = tonumber(value)
    if n == nil then return nil end
    -- Support either seconds or milliseconds without pretending the unit is known.
    if n > 10000000 then return n / 1000 end
    return n
end

function ShipFinderIslandCache._sf1194FormatDuration(seconds)
    local n = tonumber(seconds)
    if n == nil or n < 0 then return "Not available" end
    local total = math.floor(n + 0.5)
    local days = math.floor(total / 86400)
    local hours = math.floor((total % 86400) / 3600)
    local minutes = math.floor((total % 3600) / 60)
    local secs = total % 60
    if days > 0 then
        return tostring(days) .. "d " .. tostring(hours) .. "h " .. tostring(minutes) .. "m"
    end
    if hours > 0 then
        return tostring(hours) .. "h " .. tostring(minutes) .. "m"
    end
    if minutes > 0 then
        return tostring(minutes) .. "m " .. tostring(secs) .. "s"
    end
    return tostring(secs) .. "s"
end

function ShipFinderIslandCache._sf1194ProvinceName()
    local id = ShipFinderIslandCache.currentSessionGUID()
    if id == 3245 then return "Latium" end
    if id == 6627 then return "Albion" end
    return "Session " .. tostring(id or "unknown")
end

function ShipFinderIslandCache._sf1194Stats()
    local index = ShipFinderIslandCache.index or islandFullIndex or {}
    local islands, ships, seenShips = 0, 0, {}
    for _, rec in pairs(index) do
        islands = islands + 1
        for _, ship in ipairs(rec.ships or {}) do
            local key = tostring(ship.idText or "") .. "|" .. tostring(ship.name or "")
            if not seenShips[key] then seenShips[key] = true; ships = ships + 1 end
        end
    end
    local mapped = 0
    for _ in pairs(ShipFinderIslandCache.routeIslandMap or {}) do mapped = mapped + 1 end
    return islands, mapped, tonumber(ShipFinderIslandCache.routeCount) or 0, ships
end

function ShipFinderIslandCache.scanInfoText()
    local islands, mappedRoutes, activeRoutes, ships = ShipFinderIslandCache._sf1194Stats()
    local de = tostring(ShipFinderUILanguage or "") == "de"
    local fr = tostring(ShipFinderUILanguage or "") == "fr"
    local cacheState = de
        and (ShipFinderIslandCache.valid and "Im Cache" or "Noch nicht im Cache")
        or (fr
            and (ShipFinderIslandCache.valid and "En cache" or "Pas encore en cache")
            or (ShipFinderIslandCache.valid and "Cached" or "Not cached yet"))
    local lastPlay = ShipFinderIslandCache.lastScanPlayTimeSeconds
    local scanDuration = ShipFinderIslandCache.lastScanDurationSeconds
    local nowRaw = ShipFinderIslandCache._sf1194PlayTimeRaw()
    local nowPlay = ShipFinderIslandCache._sf1194SecondsFromPlayTime(nowRaw)
    local ageSeconds = nil
    if lastPlay ~= nil and nowPlay ~= nil and nowPlay >= lastPlay then
        ageSeconds = nowPlay - lastPlay
    end
    local ageCompact = ageSeconds ~= nil
        and ShipFinderIslandCache._sf1194FormatDuration(ageSeconds)
        or nil
    if de and ageCompact then
        ageCompact = ageCompact
            :gsub("(%d+)d", "%1 T")
            :gsub("(%d+)h", "%1 Std.")
            :gsub("(%d+)m", "%1 Min.")
            :gsub("(%d+)s", "%1 Sek.")
    elseif fr and ageCompact then
        ageCompact = ageCompact
            :gsub("(%d+)d", "%1 j")
            :gsub("(%d+)h", "%1 h")
            :gsub("(%d+)m", "%1 min")
            :gsub("(%d+)s", "%1 s")
    end
    local lastText = nil
    if de then
        lastText = ageCompact and ("vor " .. ageCompact) or "Noch kein vollständiger Scan gespeichert"
    elseif fr then
        lastText = ageCompact and ("il y a " .. ageCompact) or "Aucune analyse complète enregistrée"
    else
        lastText = ageCompact and (ageCompact .. " ago") or "No full scan recorded"
    end
    local durationText = scanDuration
        and (string.format("%.1f", scanDuration)
            .. (de and " Sek." or (fr and " s" or " sec")))
        or (de and "Nicht verfügbar"
            or (fr and "Indisponible" or "Not available"))

    if de then
        return "SCHIFFE NACH INSEL — SCAN-INFORMATIONEN\n\n"
            .. "Provinz: " .. ShipFinderIslandCache._sf1194ProvinceName() .. "\n\n"
            .. "Letzter vollständiger Scan: " .. lastText .. "\n"
            .. "Dauer des Scans: " .. durationText .. "\n\n"
            .. "Gefundene Inseln: " .. tostring(islands) .. "\n"
            .. "Erfasste Routen: " .. tostring(mappedRoutes) .. "\n"
            .. "Aktive Routen: " .. tostring(activeRoutes) .. "\n"
            .. "Gefundene Schiffe: " .. tostring(ships) .. "\n\n"
            .. "Inselverbindungen: " .. cacheState .. "\n"
            .. "Schiffzuweisungen: Automatisch aktualisiert\n\n"
            .. "Inselverbindungen neu scannen, nachdem Routenstopps geändert wurden\n"
            .. "oder wenn Ergebnisse nicht korrekt erscheinen."
    elseif fr then
        return "NAVIRES PAR ÎLE — INFORMATIONS SUR L’ANALYSE\n\n"
            .. "Province : " .. ShipFinderIslandCache._sf1194ProvinceName() .. "\n\n"
            .. "Dernière analyse complète : " .. lastText .. "\n"
            .. "Durée de l’analyse : " .. durationText .. "\n\n"
            .. "Îles trouvées : " .. tostring(islands) .. "\n"
            .. "Routes répertoriées : " .. tostring(mappedRoutes) .. "\n"
            .. "Routes actives : " .. tostring(activeRoutes) .. "\n"
            .. "Navires trouvés : " .. tostring(ships) .. "\n\n"
            .. "Liaisons entre îles : " .. cacheState .. "\n"
            .. "Affectations des navires : actualisées automatiquement\n\n"
            .. "Utilisez « Réanalyser les liaisons entre îles » après avoir modifié les escales d’une route\n"
            .. "ou si les résultats semblent incorrects."
    end

    return "SHIPS BY ISLAND — SCAN INFORMATION\n\n"
        .. "Province: " .. ShipFinderIslandCache._sf1194ProvinceName() .. "\n\n"
        .. "Last full scan: " .. lastText .. "\n"
        .. "Scan duration: " .. durationText .. "\n\n"
        .. "Islands found: " .. tostring(islands) .. "\n"
        .. "Routes mapped: " .. tostring(mappedRoutes) .. "\n"
        .. "Active routes: " .. tostring(activeRoutes) .. "\n"
        .. "Ships found: " .. tostring(ships) .. "\n\n"
        .. "Island connections: " .. cacheState .. "\n"
        .. "Ship assignments: Updated automatically\n\n"
        .. "Use Rescan Island Connections after changing route stops\n"
        .. "or if the results appear incorrect."
end

function ShipFinderIslandCache.matchesCurrentFleet()
    if not ShipFinderIslandCache.valid then
        return false, "cache-invalid"
    end

    local currentSession = ShipFinderIslandCache.currentSessionGUID()
    if currentSession ~= ShipFinderIslandCache.sessionGUID then
        return false, "session-changed"
    end

    local currentTopology = ShipFinderIslandCache.currentRouteTopologySignature()
    if currentTopology ~= nil
        and ShipFinderIslandCache.topologySignature ~= nil
        and currentTopology ~= ShipFinderIslandCache.topologySignature
    then
        return false, "route-topology-changed"
    end

    local shipsByRoute = ShipFinderIslandCache.currentAssignedShipsByRoute()
    local allCovered, missingRoute =
        ShipFinderIslandCache.routeMapContainsAssignedRoutes(shipsByRoute)
    if not allCovered then
        return false, "assigned-route-not-cached:" .. tostring(missingRoute)
    end

    local count = 0
    for _ in pairs(ShipFinderIslandCache.index or {}) do
        count = count + 1
    end

    if count == 0 then
        return false, "empty-index"
    end

    return true, "match"
end

function ShipFinderIslandCache.restore()
    if not ShipFinderIslandCache.valid then
        return nil, nil
    end

    if ShipFinderIslandCache.routeIslandMap ~= nil then
        local rebuiltIndex, rebuiltRouteCount =
            ShipFinderIslandCache.rebuildCurrentIndex()

        local islandCount = 0
        for _ in pairs(rebuiltIndex or {}) do
            islandCount = islandCount + 1
        end

        if islandCount > 0 then
            ShipFinderIslandCache.index = rebuiltIndex
            ShipFinderIslandCache.routeCount = rebuiltRouteCount

            system.log(
                "[Ship Finder Ships by Island Cache 1.1.0] REFRESH SHIPS"
                .. " | islands=" .. tostring(islandCount)
                .. " | activeRoutes=" .. tostring(rebuiltRouteCount)
                .. " | action=no-rescan"
            )

            return rebuiltIndex, rebuiltRouteCount
        end
    end

    return ShipFinderIslandCache.index, ShipFinderIslandCache.routeCount
end

system.log(
    "[Ship Finder Ships by Island Cache 1.1.0] LOAD"
    .. " | success=true"
    .. " | architecture=embedded-global-table"
)


ShipFinderIslandUI = ShipFinderIslandUI or {
    page = 0,
    jumpInProgress = false,
}

ShipFinderIslandUI.resumeAvailable =
    ShipFinderIslandUI.resumeAvailable == true
ShipFinderIslandUI.resumeMode = false
ShipFinderIslandUI.selectedIsland =
    ShipFinderIslandUI.selectedIsland or nil
ShipFinderIslandUI.resumeSessionGUID =
    ShipFinderIslandUI.resumeSessionGUID or nil
ShipFinderIslandUI.pendingIslandOpen = false

function ShipFinderIslandUI.sortedIslandNames()
    local names = {}
    for name in pairs(ShipFinderIslandCache.index or {}) do
        names[#names + 1] = tostring(name)
    end

    table.sort(names, function(a, b)
        return string.lower(a) < string.lower(b)
    end)

    return names
end

function ShipFinderIslandUI.sortedShipsForIsland(name)
    local rec = name and ShipFinderIslandCache.index
        and ShipFinderIslandCache.index[name] or nil
    local ships = {}
    for _, ship in ipairs(rec and rec.ships or {}) do
        ships[#ships + 1] = ship
    end

    table.sort(ships, function(a, b)
        return string.lower(tostring(a.name))
            < string.lower(tostring(b.name))
    end)

    return ships
end

-- Build smart pages with at most 9 jumpable ship rows.
-- A normal island is never split merely to fill unused space:
-- if 5 rows are already used and the next island has 6 ships,
-- that island starts on the next page.
-- Islands larger than 9 ships are the only unavoidable split case.
function ShipFinderIslandUI.buildPages()
    local pages = {}
    local current = { sections = {}, ships = {}, used = 0 }

    local function pushCurrent()
        if current.used > 0 then
            pages[#pages + 1] = current
        end
        current = { sections = {}, ships = {}, used = 0 }
    end

    local names = ShipFinderIslandUI.sortedIslandNames()

    for _, islandName in ipairs(names) do
        local ships = ShipFinderIslandUI.sortedShipsForIsland(islandName)
        local total = #ships

        if total <= 9 then
            if current.used > 0 and current.used + total > 9 then
                pushCurrent()
            end

            local section = {
                island = islandName,
                continued = false,
                ships = {},
            }

            for _, ship in ipairs(ships) do
                section.ships[#section.ships + 1] = ship
                current.ships[#current.ships + 1] = ship
                current.used = current.used + 1
            end

            current.sections[#current.sections + 1] = section
        else
            -- Large islands get clean dedicated chunks.
            if current.used > 0 then
                pushCurrent()
            end

            local pos = 1
            local part = 1
            while pos <= total do
                local section = {
                    island = islandName,
                    continued = part > 1,
                    ships = {},
                }

                local page = {
                    sections = { section },
                    ships = {},
                    used = 0,
                }

                for _ = 1, 9 do
                    local ship = ships[pos]
                    if not ship then
                        break
                    end

                    section.ships[#section.ships + 1] = ship
                    page.ships[#page.ships + 1] = ship
                    page.used = page.used + 1
                    pos = pos + 1
                end

                pages[#pages + 1] = page
                part = part + 1
            end
        end
    end

    if current.used > 0 then
        pushCurrent()
    end

    return pages
end

-- Resolve the island heading that owns an exact visible shortcut row. A ship can
-- serve several islands, so searching the cache by ship identity alone is not
-- sufficient to preserve the user's current island context.
function ShipFinderIslandUI.pageEntry(pageIndex, slot)
    local pages = ShipFinderIslandUI.buildPages()
    local page = pages[(math.max(0, tonumber(pageIndex) or 0)) + 1]
    if page == nil then return nil, nil end

    local currentSlot = 0
    for _, section in ipairs(page.sections or {}) do
        for _, ship in ipairs(section.ships or {}) do
            currentSlot = currentSlot + 1
            if currentSlot == slot then
                return ship, tostring(section.island or "")
            end
        end
    end
    return nil, nil
end

function ShipFinderIslandUI.shipRowText(number, ship, de)
    local text = tostring(number) .. ". ★ " .. tostring(ship and ship.name or "")
    local routeName = tostring(ship and ship.routeName or "")
    if routeName ~= "" then
        text = text .. " — ▶ " .. routeName
    end
    if ship and ship.paused == true then
        local fr = not de and tostring(ShipFinderUILanguage or "") == "fr"
        text = text .. (de and " [PAUSIERT]"
            or (fr and " [EN PAUSE]" or " [PAUSED]"))
    end
    return text
end

function ShipFinderIslandUI.armResume(islandName)
    local name = tostring(islandName or "")
    if name == "" then return false end

    ShipFinderIslandUI.selectedIsland = name
    ShipFinderIslandUI.resumeSessionGUID =
        ShipFinderIslandCache.currentSessionGUID()
    ShipFinderIslandUI.resumeAvailable = true

    system.log(
        "[Ship Finder Fast Resume 1.1.1] ARM"
        .. " | island=" .. name
        .. " | session=" .. tostring(ShipFinderIslandUI.resumeSessionGUID)
        .. " | nextCtrlAltF=resume-island"
    )
    return true
end

function ShipFinderIslandUI.resumeIslandPageText(pageIndex)
    local name = tostring(ShipFinderIslandUI.selectedIsland or "")
    local ships = ShipFinderIslandUI.sortedShipsForIsland(name)
    local de = tostring(ShipFinderUILanguage or "") == "de"
    local fr = tostring(ShipFinderUILanguage or "") == "fr"
    local pageCount = math.max(1, math.ceil(#ships / 9))
    local page = math.max(0, tonumber(pageIndex) or 0)
    if page >= pageCount then page = pageCount - 1 end
    local first = page * 9 + 1
    local last = math.min(first + 8, #ships)
    local visibleShips = {}
    local lines = {
        (de and "SCHIFFE FÜR "
            or (fr and "NAVIRES DESSERVANT " or "SHIPS SERVING ")) .. string.upper(name),
        "",
        de and "Schnellrückkehr zur zuletzt verwendeten Insel."
            or (fr and "Retour rapide à la dernière île utilisée."
                or "Fast resume to your last used island."),
        de and "Ctrl+Alt+1-9 springt direkt zum nummerierten Schiff."
            or (fr and "Ctrl+Alt+1-9 : accéder directement au navire numéroté."
                or "Ctrl+Alt+1-9 jumps directly to the numbered ship."),
        de and "Ctrl+Alt+0 — ◀ Alle Inseln"
            or (fr and "Ctrl+Alt+0 — ◀ Toutes les îles"
                or "Ctrl+Alt+0 — ◀ All Islands"),
        "",
        (de and "Schiffe " or (fr and "Navires " or "Ships "))
            .. tostring(first) .. "-" .. tostring(last)
            .. (de and " von " or (fr and " sur " or " of ")) .. tostring(#ships)
            .. (de and "   Seite " or (fr and "   Page " or "   Page ")) .. tostring(page + 1)
            .. "/" .. tostring(pageCount),
        "",
    }

    for index = first, last do
        local ship = ships[index]
        if ship then
            visibleShips[#visibleShips + 1] = ship
            lines[#lines + 1] = ShipFinderIslandUI.shipRowText(
                #visibleShips,
                ship,
                de
            )
        end
    end

    if #ships == 0 then
        lines[#lines + 1] = de
            and "Keine aktuell zugewiesenen Schiffe gefunden."
            or (fr and "Aucun navire actuellement affecté."
                or "No currently assigned ships found.")
    end

    return table.concat(lines, "\n"), visibleShips, page
end

function ShipFinderIslandUI.tryFastResume()
    if not ShipFinderIslandUI.resumeAvailable then return false end

    -- A resume token is deliberately one-shot. Jumping another ship arms it
    -- again; closing the resumed report without a jump makes the following
    -- Ctrl+Alt+F return to the normal Ship Finder menu.
    ShipFinderIslandUI.resumeAvailable = false

    local currentSession = ShipFinderIslandCache.currentSessionGUID()
    if tostring(currentSession) ~= tostring(ShipFinderIslandUI.resumeSessionGUID) then
        system.log(
            "[Ship Finder Fast Resume 1.1.1] FALLBACK"
            .. " | reason=session-changed"
            .. " | cachedSession=" .. tostring(ShipFinderIslandUI.resumeSessionGUID)
            .. " | currentSession=" .. tostring(currentSession)
        )
        ShipFinderIslandUI.resumeMode = false
        return false
    end

    local matches, reason = ShipFinderIslandCache.matchesCurrentFleet()
    if not matches then
        system.log(
            "[Ship Finder Fast Resume 1.1.1] FALLBACK"
            .. " | reason=" .. tostring(reason)
            .. " | action=normal-menu"
        )
        ShipFinderIslandUI.resumeMode = false
        return false
    end

    local index, routeCount = ShipFinderIslandCache.restore()
    islandFullIndex = index or islandFullIndex
    islandFullIndexRouteCount = routeCount or islandFullIndexRouteCount

    local islandName = tostring(ShipFinderIslandUI.selectedIsland or "")
    if islandName == ""
        or ShipFinderIslandCache.index == nil
        or ShipFinderIslandCache.index[islandName] == nil
    then
        system.log(
            "[Ship Finder Fast Resume 1.1.1] FALLBACK"
            .. " | reason=last-island-unavailable"
            .. " | island=" .. islandName
            .. " | action=normal-menu"
        )
        ShipFinderIslandUI.resumeMode = false
        return false
    end

    ShipFinderIslandUI.resumeMode = true
    ShipFinderIslandUI.page = 0
    ShipFinderIslandUI.jumpInProgress = false
    islandReportMarkerHandled = false
    islandScanMarkerHandled = false

    local ok, err = pcall(function()
        GovernorDecision:CheatStartGovernorDecisionForCurrentPlayerNet(
            ISLAND_REPORT_STORYLINE
        )
    end)

    system.log(
        "[Ship Finder Fast Resume 1.1.1] OPEN"
        .. " | island=" .. islandName
        .. " | cache=match"
        .. " | liveAssignments=refreshed"
        .. " | success=" .. tostring(ok)
        .. " | error=" .. tostring(err or "")
    )
    if not ok then
        ShipFinderIslandUI.resumeMode = false
    end
    return ok
end

function ShipFinderIslandUI.markerForPage(page)
    return "SF_SHIPS_BY_ISLAND_REPORT_P" .. tostring((tonumber(page) or 0) + 1)
end

function ShipFinderIslandUI.pageFromMarker(text)
    if text == nil then
        return nil
    end

    local n = string.match(
        tostring(text),
        "^SF_SHIPS_BY_ISLAND_REPORT_P(%d+)$"
    )

    if n == nil then
        return nil
    end

    return math.max(0, tonumber(n) - 1)
end

function ShipFinderIslandUI.pageText(pageIndex)
    local pages = ShipFinderIslandUI.buildPages()
    local pageCount = #pages
    local de = tostring(ShipFinderUILanguage or "") == "de"
    local fr = tostring(ShipFinderUILanguage or "") == "fr"

    if pageCount == 0 then
        if de then
            return "SCHIFFE NACH INSEL\n\nKeine Schiffe sind aktiven Handelsrouten zugewiesen.", {}
        elseif fr then
            return "NAVIRES PAR ÎLE\n\nAucun navire n’est affecté à une route commerciale active.", {}
        end
        return "SHIPS BY ISLAND\n\nNo ships assigned to active trade routes.", {}
    end

    local p = math.max(0, tonumber(pageIndex) or 0)
    if p >= pageCount then p = pageCount - 1 end

    local page = pages[p + 1]
    local lines = {
        de and "SCHIFFE NACH INSEL"
            or (fr and "NAVIRES PAR ÎLE" or "SHIPS BY ISLAND"),
        "",
        de and "Ctrl+Alt+1-9 springt direkt zum nummerierten Schiff."
            or (fr and "Ctrl+Alt+1-9 : accéder directement au navire numéroté."
                or "Ctrl+Alt+1-9 jumps directly to the numbered ship."),
        "",
    }

    local slot = 0
    for _, section in ipairs(page.sections or {}) do
        local headline = "=== " .. tostring(section.island)
        if section.continued then
            headline = headline .. (de and " (Fortsetzung)"
                or (fr and " (suite)" or " (continued)"))
        end
        headline = headline .. " ==="
        lines[#lines + 1] = headline

        for _, ship in ipairs(section.ships or {}) do
            slot = slot + 1
            lines[#lines + 1] = ShipFinderIslandUI.shipRowText(slot, ship, de)
        end
        lines[#lines + 1] = ""
    end

    if de then
        lines[#lines + 1] = "Seite " .. tostring(p + 1) .. " von " .. tostring(pageCount)
    elseif fr then
        lines[#lines + 1] = "Page " .. tostring(p + 1) .. " sur " .. tostring(pageCount)
    else
        lines[#lines + 1] = "Page " .. tostring(p + 1) .. " of " .. tostring(pageCount)
    end

    return table.concat(lines, "\n"), page.ships or {}
end

function ShipFinderIslandUI.getPopupContent()
    local content = nil
    pcall(function()
        content = ui
            and ui.Scenes
            and ui.Scenes.TextPopup
            and ui.Scenes.TextPopup.SceneData
            and ui.Scenes.TextPopup.SceneData.Content
            or nil
    end)
    return content
end

function ShipFinderIslandUI.isReportOpen()
    return ShipFinderIslandUI.getPopupContent() ~= nil
end

function ShipFinderIslandUI.writeCurrentPage()
    local content = ShipFinderIslandUI.getPopupContent()
    if not content then
        return false
    end

    local text = ShipFinderIslandUI.pageText(
        ShipFinderIslandUI.page or 0
    )

    local ok, err = pcall(function()
        content.Text = text
    end)

    system.log(
        "[Ship Finder Island Navigation 1.1.0] WRITE"
        .. " | page=" .. tostring((ShipFinderIslandUI.page or 0) + 1)
        .. " | success=" .. tostring(ok)
        .. " | error=" .. tostring(err or "")
    )

    return ok
end

function ShipFinderIslandUI.reset()
    ShipFinderIslandUI.page = 0
    ShipFinderIslandUI.jumpInProgress = false
    ShipFinderIslandUI.pendingIslandOpen = false
end


function ShipFinderIslandUI.resolveLiveShip(cachedShip)
    if cachedShip == nil then
        return nil, "cached ship missing"
    end

    local targetIDText = tostring(cachedShip.idText or "")
    local targetName = tostring(cachedShip.name or "")
    local targetRoute = tostring(cachedShip.routeName or "")
    local nameRouteFallback = nil

    for _, object in pairs(
        Scripts:GetObjectGroupByProperty(Properties.ShipModuleOwner) or {}
    ) do
        local liveIDText = ""
        local liveName = ""
        local liveRoute = ""

        pcall(function()
            liveIDText = tostring(object.ID)
        end)

        pcall(function()
            if object.Nameable and object.Nameable.Name ~= nil then
                liveName = tostring(object.Nameable.Name)
            elseif object.Name ~= nil then
                liveName = tostring(object.Name)
            end
        end)

        pcall(function()
            local tr = object.TradeRouteVehicle
            if tr and tr.RouteName ~= nil then
                liveRoute = tostring(tr.RouteName)
            end
        end)

        -- Strongest match: stable textual object ID, but use the FRESH
        -- object's native ID userdata for Selection/JumpToObject.
        if targetIDText ~= "" and liveIDText == targetIDText then
            return object, "idText"
        end

        -- Safe fallback if the engine recreated the ship wrapper.
        if liveName == targetName and liveRoute == targetRoute then
            if nameRouteFallback == nil then
                nameRouteFallback = object
            end
        end
    end

    if nameRouteFallback ~= nil then
        return nameRouteFallback, "name+route"
    end

    return nil, "not found in live current-session fleet"
end

function ShipFinderIslandUI.getPopupContent()
    local content = nil
    pcall(function()
        content = ui
            and ui.Scenes
            and ui.Scenes.TextPopup
            and ui.Scenes.TextPopup.SceneData
            and ui.Scenes.TextPopup.SceneData.Content
            or nil
    end)
    return content
end

function ShipFinderIslandUI.isReportOpen()
    return ShipFinderIslandUI.getPopupContent() ~= nil
end

function ShipFinderIslandUI.islandPageText()
    local names = ShipFinderIslandUI.sortedIslandNames()
    local page = math.max(0, tonumber(ShipFinderIslandUI.islandPage) or 0)
    local first = page * 9 + 1
    local last = math.min(first + 8, #names)
    local pages = math.max(1, math.ceil(#names / 9))
    local de = tostring(ShipFinderUILanguage or "") == "de"
    local fr = tostring(ShipFinderUILanguage or "") == "fr"

    local lines = {
        de and "SCHIFFE NACH INSEL"
            or (fr and "NAVIRES PAR ÎLE" or "SHIPS BY ISLAND"),
        "",
        de and "Wähle eine Insel mit Ctrl+Alt+1-9."
            or (fr and "Choisissez une île avec Ctrl+Alt+1-9."
                or "Choose an island with Ctrl+Alt+1-9."),
        de and "Nutze die Pfeile auf dem Pergament, um die Seiten zu wechseln."
            or (fr and "Utilisez les flèches du parchemin pour changer de page."
                or "Use the parchment arrows to change pages."),
        "",
        (de and "Inseln " or (fr and "Îles " or "Islands "))
            .. tostring(first) .. "-" .. tostring(last)
            .. (de and " von " or (fr and " sur " or " of ")) .. tostring(#names)
            .. (de and "   Seite " or (fr and "   Page " or "   Page "))
            .. tostring(page + 1) .. "/" .. tostring(pages),
        ""
    }

    for slot = 1, 9 do
        local index = page * 9 + slot
        local name = names[index]
        if name then
            local rec = ShipFinderIslandCache.index[name]
            local ships = rec and rec.ships or {}
            local unit = de and (#ships == 1 and " Schiff" or " Schiffe")
                or (fr and (#ships == 1 and " navire" or " navires")
                    or (" ship" .. (#ships == 1 and "" or "s")))
            lines[#lines + 1] = tostring(slot) .. ". " .. tostring(name)
                .. " — " .. tostring(#ships) .. unit
        end
    end
    return table.concat(lines, "\n")
end


function ShipFinderIslandUI.islandForShortcutSlot(slot)
    local page = math.max(0, tonumber(ShipFinderIslandUI.islandPage) or 0)
    local index = page * 9 + (tonumber(slot) or 0)
    local names = ShipFinderIslandUI.sortedIslandNames()
    return names[index]
end

function ShipFinderIslandUI.shipPageText()
    local name = ShipFinderIslandUI.selectedIsland
    local rec = name and ShipFinderIslandCache.index and ShipFinderIslandCache.index[name] or nil
    local ships = rec and rec.ships or {}
    local de = tostring(ShipFinderUILanguage or "") == "de"
    local fr = tostring(ShipFinderUILanguage or "") == "fr"

    table.sort(ships, function(a, b)
        return string.lower(tostring(a.name)) < string.lower(tostring(b.name))
    end)

    local page = math.max(0, tonumber(ShipFinderIslandUI.shipPage) or 0)
    local first = page * 9 + 1
    local last = math.min(first + 8, #ships)
    local pages = math.max(1, math.ceil(#ships / 9))

    local lines = {
        (de and "SCHIFFE FÜR "
            or (fr and "NAVIRES DESSERVANT " or "SHIPS SERVING "))
            .. string.upper(tostring(name or "")),
        "",
        de and "Wähle ein Schiff mit Ctrl+Alt+1-9, um direkt dorthin zu springen."
            or (fr and "Choisissez un navire avec Ctrl+Alt+1-9 pour y accéder directement."
                or "Choose a ship with Ctrl+Alt+1-9 to jump directly to it."),
        de and "Nutze die Pfeile auf dem Pergament, um die Seiten zu wechseln."
            or (fr and "Utilisez les flèches du parchemin pour changer de page."
                or "Use the parchment arrows to change pages."),
        de and "Ctrl+Alt+0 — ◀ Alle Inseln"
            or (fr and "Ctrl+Alt+0 — ◀ Toutes les îles"
                or "Ctrl+Alt+0 — ◀ All Islands"),
        "",
        (de and "Schiffe " or (fr and "Navires " or "Ships "))
            .. tostring(first) .. "-" .. tostring(last)
            .. (de and " von " or (fr and " sur " or " of ")) .. tostring(#ships)
            .. (de and "   Seite " or (fr and "   Page " or "   Page "))
            .. tostring(page + 1) .. "/" .. tostring(pages),
        ""
    }

    local visibleShips = {}
    for slot = 1, 9 do
        local index = page * 9 + slot
        local ship = ships[index]
        if ship then
            visibleShips[#visibleShips + 1] = ship
            lines[#lines + 1] = tostring(slot) .. ". >>> " .. tostring(ship.name)
        end
    end
    return table.concat(lines, "\n"), visibleShips, page
end

function ShipFinderIslandUI.writeCurrentPage()
    local content = ShipFinderIslandUI.getPopupContent()
    if not content then
        return false
    end

    local text = nil
    if ShipFinderIslandUI.mode == "ships" then
        text = ShipFinderIslandUI.shipPageText()
    else
        text = ShipFinderIslandUI.islandPageText()
    end

    local ok, err = pcall(function()
        content.Text = text
    end)

    system.log(
        "[Ship Finder Island Navigation 1.1.0] WRITE"
        .. " | mode=" .. tostring(ShipFinderIslandUI.mode)
        .. " | islandPage=" .. tostring(ShipFinderIslandUI.islandPage)
        .. " | shipPage=" .. tostring(ShipFinderIslandUI.shipPage)
        .. " | selectedIsland=" .. tostring(ShipFinderIslandUI.selectedIsland)
        .. " | success=" .. tostring(ok)
        .. " | error=" .. tostring(err or "")
    )

    return ok
end

function ShipFinderIslandUI.reset()
    ShipFinderIslandUI.mode = "islands"
    ShipFinderIslandUI.resumeMode = false
    ShipFinderIslandUI.islandPage = 0
    ShipFinderIslandUI.shipPage = 0
    ShipFinderIslandUI.selectedIsland = nil
    ShipFinderIslandUI.jumpInProgress = false
end

system.log("[Ship Finder 1.5.0] Load complete | EN/DE/FR | fast Ctrl+Alt+F menu | on-demand Attention scan | Ships by Island | Fleet Overview | direct jumps")
end

-- Keep these helpers global. This combined chunk is already at Anno's
-- top-level Lua local-variable limit; adding more top-level locals prevents
-- the complete menu module from loading.
function ShipFinderNativeRouteKey(value)
    if value == nil then return nil end
    return string.lower(
        (tostring(value):gsub("^%s+", ""):gsub("%s+$", ""))
    )
end

-- Ship Finder v1.4.40 Attention real-route probe.
-- Diagnostic only.
--
-- v1.4.39 proved that objects exposed through TradeRoutesWithIssues are good
-- property snapshots but are not accepted as callable CSessionTradeRoute
-- userdata by the method bindings.
--
-- This build resolves each issue route name back to a real route object via
-- CTradeRouteManager:GetRoute(id), then invokes warning getters only on that
-- resolved CSessionTradeRoute.
ShipFinderAttentionRealRouteCache =
    ShipFinderAttentionRealRouteCache or nil

function ShipFinderAttentionBuildRealRouteCache()
    local cache = {
        byName = {},
        scanned = 0,
        valid = 0,
        maxID = 512,
    }

    local manager = nil
    local okManager, managerValue = pcall(function()
        return TradeRoute.get()
    end)

    if okManager then
        manager = managerValue
    end

    if manager == nil then
        system.log(
            "[Ship Finder Attention Real Route Probe 1.4.40] CACHE"
            .. " | managerAvailable=false"
        )
        ShipFinderAttentionRealRouteCache = cache
        return cache
    end

    for routeID = 0, cache.maxID do
        cache.scanned = cache.scanned + 1

        local okRoute, route = pcall(function()
            return manager:GetRoute(routeID)
        end)

        if okRoute and route ~= nil then
            local okValid, isValid = pcall(function()
                if type(route.isValid) == "function" then
                    return route:isValid()
                end
                return true
            end)

            if not okValid then
                isValid = true
            end

            if isValid == true then
                local okName, name = pcall(function()
                    return route.Name
                end)

                if okName and name ~= nil and tostring(name) ~= "" then
                    cache.valid = cache.valid + 1
                    local nameText = tostring(name)
                    if cache.byName[nameText] == nil then
                        cache.byName[nameText] = {
                            id = routeID,
                            route = route,
                        }
                    end
                end
            end
        end
    end

    system.log(
        "[Ship Finder Attention Real Route Probe 1.4.40] CACHE"
        .. " | managerAvailable=true"
        .. " | scannedIDs=" .. tostring(cache.scanned)
        .. " | validNamedRoutes=" .. tostring(cache.valid)
        .. " | maxID=" .. tostring(cache.maxID)
    )

    ShipFinderAttentionRealRouteCache = cache
    return cache
end

function ShipFinderAttentionResolveRealRoute(routeName)
    local cache = ShipFinderAttentionRealRouteCache
    if cache == nil then
        cache = ShipFinderAttentionBuildRealRouteCache()
    end

    local key = tostring(routeName or "")
    local found = cache.byName and cache.byName[key] or nil

    if found ~= nil then
        return found.route, found.id
    end

    return nil, nil
end

function ShipFinderNativeAttentionCategoryProbe(issueRoute, routeName, errorCount)
    if issueRoute == nil then return end

    local realRoute, routeID =
        ShipFinderAttentionResolveRealRoute(routeName)

    local issueType = tostring(type(issueRoute))
    local realType = tostring(type(realRoute))

    local issueString = ""
    pcall(function()
        issueString = tostring(issueRoute)
    end)

    local realString = ""
    pcall(function()
        realString = tostring(realRoute)
    end)

    system.log(
        "[Ship Finder Attention Real Route Probe 1.4.40] RESOLVE"
        .. " | name=" .. tostring(routeName or "")
        .. " | routeID=" .. tostring(routeID)
        .. " | issueType=" .. issueType
        .. " | issueObject=" .. issueString
        .. " | realType=" .. realType
        .. " | realObject=" .. realString
        .. " | resolved=" .. tostring(realRoute ~= nil)
    )

    -- Preserve the four proven direct properties from the issue snapshot.
    local direct = {
        {"NoShipsActive", "NO_SHIPS"},
        {"AllShipsPausedActive", "ALL_SHIPS_PAUSED"},
        {"NoGoodsActive", "NO_GOODS"},
        {"NotEnoughStationsActive", "NOT_ENOUGH_STATIONS"},
    }

    -- Warning getters which appear argument-free from the binding names.
    -- These are now called only on a manager-resolved CSessionTradeRoute.
    local methods = {
        {"ConfiguredGoodNotTradedActive", "CONFIGURED_GOOD_NOT_TRADED"},
        {"GoodsDontMatchActive", "GOODS_DONT_MATCH"},
        {"MismatchingGoodActive", "MISMATCHING_GOOD"},
        {"LongWaitingTimeActive", "LONG_WAITING_TIME"},
        {"StorageEmptyActive", "STORAGE_EMPTY"},
        {"StorageFullActive", "STORAGE_FULL"},
        {"LoadedGoodNeverUnloadedActive", "LOADED_GOOD_NEVER_UNLOADED"},
        {"UnloadedGoodNeverLoadedActive", "UNLOADED_GOOD_NEVER_LOADED"},
        {"NoTradeRightsActive", "NO_TRADE_RIGHTS"},
        {"NoValidPierActive", "NO_VALID_PIER"},
        {"IslandUnderSiegeActive", "ISLAND_UNDER_SIEGE"},
        {"NotEnoughSlotsErrorActive", "NOT_ENOUGH_SLOTS"},
        {"NotEnoughSlotsForShipsErrorActive", "NOT_ENOUGH_SLOTS_FOR_SHIPS"},
    }

    local active = {}
    local states = {}
    local callErrors = {}

    for _, entry in ipairs(direct) do
        local member = entry[1]
        local label = entry[2]
        local ok, value = pcall(function()
            return issueRoute[member]
        end)

        if ok then
            states[#states + 1] =
                member .. "=" .. tostring(value)
            if value == true then
                active[#active + 1] = label
            end
        else
            states[#states + 1] =
                member .. "=ERROR"
        end
    end

    if realRoute ~= nil then
        for _, entry in ipairs(methods) do
            local member = entry[1]
            local label = entry[2]

            local okMember, fn = pcall(function()
                return realRoute[member]
            end)

            if not okMember or type(fn) ~= "function" then
                states[#states + 1] =
                    member .. "=UNAVAILABLE"
            else
                local okCall, value = pcall(function()
                    return fn(realRoute)
                end)

                if not okCall then
                    states[#states + 1] =
                        member .. "=CALL_ERROR"
                    callErrors[#callErrors + 1] =
                        member .. "{" .. tostring(value or "") .. "}"
                else
                    states[#states + 1] =
                        member .. "=" .. tostring(value)
                    if value == true then
                        active[#active + 1] = label
                    end
                end
            end
        end
    else
        states[#states + 1] = "REAL_ROUTE=NOT_FOUND"
    end

    system.log(
        "[Ship Finder Attention Real Route Probe 1.4.40] ROUTE"
        .. " | name=" .. tostring(routeName or "")
        .. " | routeID=" .. tostring(routeID)
        .. " | activeErrorCount=" .. tostring(errorCount or 0)
        .. " | activeCategories="
        .. (#active > 0 and table.concat(active, ",") or "NONE")
        .. " | callErrors=" .. tostring(#callErrors)
    )

    system.log(
        "[Ship Finder Attention Real Route Probe 1.4.40] STATES"
        .. " | name=" .. tostring(routeName or "")
        .. " | routeID=" .. tostring(routeID)
        .. " | " .. table.concat(states, " | ")
    )

    if #callErrors > 0 then
        system.log(
            "[Ship Finder Attention Real Route Probe 1.4.40] CALL ERRORS"
            .. " | name=" .. tostring(routeName or "")
            .. " | routeID=" .. tostring(routeID)
            .. " | " .. table.concat(callErrors, " || ")
        )
    end

    -- Detail functions remain type-only. Their argument contracts are unknown.
    local extraMembers = {
        "MismatchingGoodActiveForGood",
        "IsErrorActive",
        "GetLostShipName",
        "GetStation",
    }
    local extras = {}

    if realRoute ~= nil then
        for _, member in ipairs(extraMembers) do
            local ok, value = pcall(function()
                return realRoute[member]
            end)

            if ok then
                extras[#extras + 1] =
                    member .. ":" .. tostring(type(value))
            else
                extras[#extras + 1] =
                    member .. ":ERROR"
            end
        end
    end

    system.log(
        "[Ship Finder Attention Real Route Probe 1.4.40] EXTRA"
        .. " | name=" .. tostring(routeName or "")
        .. " | routeID=" .. tostring(routeID)
        .. " | " .. table.concat(extras, " | ")
    )
end

function ShipFinderNativeIssueRouteSnapshot()
    local result = {}
    local manager = nil
    local list = nil

    pcall(function()
        manager = TradeRoute and TradeRoute.get and TradeRoute.get() or nil
        list = manager and manager.TradeRoutesWithIssues or nil
    end)

    if type(list) == "table" then
        for _, route in pairs(list) do
            local valid = route ~= nil
            pcall(function()
                if route.isValid then valid = route:isValid() end
            end)

            if valid then
                local name, errorCount, allPaused = nil, 0, false
                pcall(function() name = route.Name end)
                pcall(function() errorCount = tonumber(route.ActiveErrorCount) or 0 end)
                pcall(function() allPaused = route.AllShipsPausedActive == true end)

                if name ~= nil and tostring(name) ~= "" then
                    -- v1.4.42: low-level route warning method probing is
                    -- retired from the active path. Anno's own
                    -- TradeRouteWarningStateData is now the proven surface.
                    result[ShipFinderNativeRouteKey(name)] = {
                        name = tostring(name),
                        activeErrorCount = errorCount,
                        allShipsPaused = allPaused,
                    }
                end
            end
        end
    end

    local count = 0
    for _ in pairs(result) do count = count + 1 end

    local assignedCount, matchedCount = 0, 0
    local liveRouteNames = {}
    for _, object in pairs(
        Scripts:GetObjectGroupByProperty(Properties.ShipModuleOwner) or {}
    ) do
        local vehicle = object.TradeRouteVehicle
        if vehicle and vehicle.IsAssignedOnTradeRoute == true
            and vehicle.RouteName ~= nil
        then
            assignedCount = assignedCount + 1
            local key = ShipFinderNativeRouteKey(vehicle.RouteName)
            liveRouteNames[key] = true
            if result[key] ~= nil then matchedCount = matchedCount + 1 end
        end
    end

    local unmatchedIssueNames = {}
    for key, issue in pairs(result) do
        if not liveRouteNames[key] then
            unmatchedIssueNames[#unmatchedIssueNames + 1] = issue.name
        end
    end
    table.sort(unmatchedIssueNames)
    system.log(
        "[Ship Finder Native Attention 1.5.0] REFRESH"
        .. " | nativeIssueRoutes=" .. tostring(count)
        .. " | sourceAvailable=" .. tostring(type(list) == "table")
        .. " | assignedLiveShips=" .. tostring(assignedCount)
        .. " | matchedLiveShips=" .. tostring(matchedCount)
        .. " | issueRoutesWithoutLiveShip="
        .. table.concat(unmatchedIssueNames, ",")
    )
    return result
end

-- Production Attention parchment state and renderer.
-- Originally introduced while proving the standalone parchment path; it is now
-- used by the normal Ships Needing Attention flow after the freeze-safe
-- post-yield handoff. There is no standalone public shortcut.
ShipFinderAttentionParchmentTest = ShipFinderAttentionParchmentTest or {
    active = false,
    pendingOpen = false,
    opening = false,
    page = 0,
    visible = {},
}

function ShipFinderAttentionParchmentTest.getPopupContent()
    local content = nil
    pcall(function()
        content = ui
            and ui.Scenes
            and ui.Scenes.TextPopup
            and ui.Scenes.TextPopup.SceneData
            and ui.Scenes.TextPopup.SceneData.Content
            or nil
    end)
    return content
end

function ShipFinderAttentionParchmentTest.records()
    local issues = ShipFinderNativeIssueRouteSnapshot()
    local records = {}

    for _, object in pairs(
        Scripts:GetObjectGroupByProperty(Properties.ShipModuleOwner) or {}
    ) do
        local rawName = object.Nameable and object.Nameable.Name
        local route = object.TradeRouteVehicle
        local assigned = route and route.IsAssignedOnTradeRoute == true
        local military = object.Unit and object.Unit.IsMilitaryUnit == true
        local routeName = route and route.RouteName or nil
        local issue = routeName ~= nil
            and issues[ShipFinderNativeRouteKey(routeName)]
            or nil

        if rawName ~= nil and assigned and not military and issue ~= nil then
            local name = tostring(rawName)
            local detail =
                ShipFinderAttentionWarningDetailCache
                and ShipFinderAttentionWarningDetailCache[
                    ShipFinderNativeRouteKey(routeName)
                ]
                or nil

            local detailKind =
                detail and tostring(detail.kind or "")
                or ""

            local detailTopic = "4"
            if issue.allShipsPaused == true then
                detailTopic = "0"
            elseif detailKind == "wait_for_goods" then
                detailTopic = "1"
            elseif detailKind == "wait_to_unload" then
                detailTopic = "2"
            elseif detailKind == "station_warning" then
                detailTopic = "3"
            end

            records[#records + 1] = {
                name = name,
                routeName = tostring(routeName),
                id = tostring(object.ID),
                key = detailTopic
                    .. "|" .. string.lower(name)
                    .. "|" .. string.lower(tostring(routeName))
                    .. "|" .. tostring(object.ID),
                allShipsPaused = issue.allShipsPaused == true,
                activeErrorCount = tonumber(issue.activeErrorCount) or 0,
                warningKind = detailKind,
                warningIsland =
                    detail and tostring(detail.islandName or "")
                    or "",
            }
        end
    end

    table.sort(records, function(a, b) return a.key < b.key end)
    return records
end

function ShipFinderAttentionParchmentTest.reasonText(record, de)
    local fr = not de and tostring(ShipFinderUILanguage or "") == "fr"
    if record ~= nil and record.allShipsPaused == true then
        return de and "Alle Schiffe pausiert"
            or (fr and "Tous les navires en pause" or "All ships paused")
    end

    local kind = record and record.warningKind or ""
    local island = record and record.warningIsland or ""

    if kind == "wait_for_goods" then
        local base = de and "Auf Waren warten"
            or (fr and "Attendre avant de charger" or "Wait for goods")
        if island ~= nil and tostring(island) ~= "" then
            return base .. " — " .. tostring(island)
        end
        return base
    end

    if kind == "wait_to_unload" then
        local base = de and "Auf Entladen warten"
            or (fr and "Attendre avant de décharger" or "Wait to unload")
        if island ~= nil and tostring(island) ~= "" then
            return base .. " — " .. tostring(island)
        end
        return base
    end

    if kind == "station_warning" then
        local base = de and "Stationswarnung"
            or (fr and "Avertissement de station" or "Station warning")
        if island ~= nil and tostring(island) ~= "" then
            return base .. " — " .. tostring(island)
        end
        return base
    end

    return de and "Handelsrouten-Warnung"
        or (fr and "Avertissement de route commerciale"
            or "Trade route warning")
end

function ShipFinderAttentionParchmentTest.pageText(pageIndex)
    local records = ShipFinderAttentionParchmentTest.records()
    local pages = math.max(1, math.ceil(#records / 9))
    local requestedPage = math.max(0, tonumber(pageIndex) or 0)
    local page = requestedPage
    if page >= pages then page = pages - 1 end

    ShipFinderAttentionParchmentTest.page = page
    ShipFinderAttentionParchmentTest.visible = {}

    local de = tostring(ShipFinderUILanguage or "") == "de"
    local fr = tostring(ShipFinderUILanguage or "") == "fr"
    local first = page * 9 + 1
    local last = math.min(first + 8, #records)
    local lines = {
        de and "SCHIFFE MIT HANDLUNGSBEDARF"
            or (fr and "NAVIRES NÉCESSITANT VOTRE ATTENTION"
                or "SHIPS NEEDING ATTENTION"),
        "",
        tostring(#records)
            .. (de and " Schiffe • Aktuelle Provinz"
                or (fr and " navires • Province actuelle"
                    or " ships • Current province")),
        de and "Strg+Alt+1-9: Zum nummerierten Schiff springen"
            or (fr and "Ctrl+Alt+1-9 : accéder au navire numéroté"
                or "Ctrl+Alt+1-9: Jump to numbered ship"),
        de and "Strg+Alt+0: Zurueck zum Ship Finder-Menue"
            or (fr and "Ctrl+Alt+0 : retour au menu Ship Finder"
                or "Ctrl+Alt+0: Back to Ship Finder menu"),
    }

    if pages > 1 then
        lines[#lines + 1] = (de and "Seite "
            or (fr and "Page " or "Page "))
            .. tostring(page + 1) .. "/" .. tostring(pages)
    end

    lines[#lines + 1] = ""

    if #records == 0 then
        lines[#lines + 1] = de
            and "Keine aktuell sichtbaren zugewiesenen zivilen Schiffe befinden sich auf Routen mit nativen Warnungen."
            or (fr
                and "Aucun navire civil affecté et actuellement visible ne se trouve sur une route signalée par le jeu."
                or "No currently visible assigned non-military ships are on routes with native warnings.")
    else
        local lastWarningKey = nil

        for index = first, last do
            local record = records[index]
            local slot = index - first + 1
            local warningKey = "route"
            if record.allShipsPaused == true then
                warningKey = "paused"
            elseif record.warningKind == "wait_for_goods" then
                warningKey = "wait_for_goods"
            elseif record.warningKind == "wait_to_unload" then
                warningKey = "wait_to_unload"
            elseif record.warningKind == "station_warning" then
                warningKey = "station"
            end

            if warningKey ~= lastWarningKey then
                if lastWarningKey ~= nil then
                    lines[#lines + 1] = ""
                end

                if warningKey == "paused" then
                    lines[#lines + 1] = de
                        and "⚠ ALLE SCHIFFE PAUSIERT"
                        or (fr and "⚠ TOUS LES NAVIRES EN PAUSE"
                            or "⚠ ALL SHIPS PAUSED")
                elseif warningKey == "wait_for_goods" then
                    lines[#lines + 1] = de
                        and "⚠ AUF WAREN WARTEN"
                        or (fr and "⚠ ATTENDRE AVANT DE CHARGER"
                            or "⚠ WAIT FOR GOODS")
                elseif warningKey == "wait_to_unload" then
                    lines[#lines + 1] = de
                        and "⚠ AUF ENTLADEN WARTEN"
                        or (fr and "⚠ ATTENDRE AVANT DE DÉCHARGER"
                            or "⚠ WAIT TO UNLOAD")
                elseif warningKey == "station" then
                    lines[#lines + 1] = de
                        and "⚠ STATIONSWARNUNG"
                        or (fr and "⚠ AVERTISSEMENT DE STATION"
                            or "⚠ STATION WARNING")
                else
                    lines[#lines + 1] = de
                        and "⚠ HANDELSROUTEN-WARNUNG"
                        or (fr and "⚠ AVERTISSEMENT DE ROUTE COMMERCIALE"
                            or "⚠ TRADE ROUTE WARNING")
                end

                lastWarningKey = warningKey
            end

            ShipFinderAttentionParchmentTest.visible[slot] = {
                id = record.id,
                name = record.name,
                routeName = record.routeName,
            }

            local locationSuffix = ""
            if record.warningIsland ~= nil
                and tostring(record.warningIsland) ~= ""
                and warningKey ~= "paused"
                and warningKey ~= "route"
            then
                locationSuffix =
                    " — " .. tostring(record.warningIsland)
            end

            lines[#lines + 1] = tostring(slot) .. ". ★ "
                .. record.name .. " — ▶ " .. record.routeName
                .. locationSuffix
        end
    end

    return table.concat(lines, "\n")
end

function ShipFinderAttentionParchmentTest.isReportOpen()
    if ShipFinderAttentionParchmentTest.active ~= true then return false end
    local content = ShipFinderAttentionParchmentTest.getPopupContent()
    if content == nil then return false end

    local text = nil
    pcall(function() text = content.Text end)
    text = tostring(text or "")
    return string.match(text, "^SHIPS NEEDING ATTENTION") ~= nil
        or string.match(text, "^SCHIFFE MIT HANDLUNGSBEDARF") ~= nil
        or string.match(text, "^NAVIRES NÉCESSITANT VOTRE ATTENTION") ~= nil
end

function CombinedRoot:AttentionParchmentTestShortcut(slot)
    slot = tonumber(slot) or 0
    if slot < 1 or slot > 9
        or not ShipFinderAttentionParchmentTest.isReportOpen()
    then
        return false
    end

    local target = ShipFinderAttentionParchmentTest.visible[slot]
    if target == nil then
        system.log(
            "[Ship Finder Attention Report 1.4.31] EMPTY SLOT"
            .. " | page=" .. tostring(ShipFinderAttentionParchmentTest.page + 1)
            .. " | slot=" .. tostring(slot)
        )
        return false
    end

    local fresh = nil
    for _, object in pairs(
        Scripts:GetObjectGroupByProperty(Properties.ShipModuleOwner) or {}
    ) do
        if tostring(object.ID) == tostring(target.id) then
            fresh = object
            break
        end
    end

    if fresh == nil then
        system.log(
            "[Ship Finder Attention Report 1.4.31] SHIP UNAVAILABLE"
            .. " | name=" .. tostring(target.name)
            .. " | objectId=" .. tostring(target.id)
        )
        return false
    end

    local nativeID = fresh.ID
    local closeOk, closeErr = pcall(function() Scripts:PopUI() end)
    local selectOk, selectErr = pcall(function()
        Selection:SelectByID(nativeID)
    end)
    local jumpOk, jumpErr = pcall(function()
        Scripts:JumpToObject(nativeID)
    end)

    ShipFinderAttentionParchmentTest.active = false
    ShipFinderAttentionParchmentTest.pendingOpen = false
    ShipFinderAttentionParchmentTest.opening = false

    system.log(
        "[Ship Finder Attention Report 1.4.31] SHIP JUMP"
        .. " | page=" .. tostring(ShipFinderAttentionParchmentTest.page + 1)
        .. " | slot=" .. tostring(slot)
        .. " | name=" .. tostring(target.name)
        .. " | objectId=" .. tostring(nativeID)
        .. " | closeSuccess=" .. tostring(closeOk)
        .. " | selectSuccess=" .. tostring(selectOk)
        .. " | jumpSuccess=" .. tostring(jumpOk)
        .. " | closeError=" .. tostring(closeErr or "")
        .. " | selectError=" .. tostring(selectErr or "")
        .. " | jumpError=" .. tostring(jumpErr or "")
    )
    return selectOk and jumpOk
end

function ShipFinderCurrentNativeIssueRoutes()
    if type(ShipFinderNativeIssueRouteCache) ~= "table" then
        ShipFinderNativeIssueRouteCache = ShipFinderNativeIssueRouteSnapshot()
    end
    return ShipFinderNativeIssueRouteCache
end

function CombinedRoot:IsAttentionShip(object)
    if object == nil then return false end
    local route = object.TradeRouteVehicle
    local assigned = route and route.IsAssignedOnTradeRoute == true
    local military = object.Unit and object.Unit.IsMilitaryUnit == true
    local routeName = route and route.RouteName or nil
    return assigned
        and not military
        and routeName ~= nil
        and ShipFinderCurrentNativeIssueRoutes()[
            ShipFinderNativeRouteKey(routeName)
        ] ~= nil
end

function CombinedRoot:GetPublicCategoryShips(category, selectedRouteName)
    local records = {}
    for _, object in pairs(
        Scripts:GetObjectGroupByProperty(Properties.ShipModuleOwner) or {}
    ) do
        local rawName = object.Nameable and object.Nameable.Name
        if rawName ~= nil then
            local name = tostring(rawName)
            local route = object.TradeRouteVehicle
            local assigned = route and route.IsAssignedOnTradeRoute == true
            local paused = route and route.IsPaused == true
            local military = object.Unit and object.Unit.IsMilitaryUnit == true
            local routeName = route and route.RouteName or nil
            local include = false

            if category == 1 then
                include = assigned and not paused
            elseif category == 2 then
                include = self:IsAttentionShip(object)
            elseif category == 4 then
                include = military
            elseif category == 5 then
                include = not military and not assigned
            elseif category == 6 then
                include = assigned
                    and not paused
                    and routeName ~= nil
                    and selectedRouteName ~= nil
                    and tostring(routeName) == tostring(selectedRouteName)
            end

            if include then
                records[#records + 1] = {
                    name = name,
                    key = string.lower(name) .. "|" .. tostring(object.ID),
                    object = object,
                    routeName = routeName and tostring(routeName) or nil,
                }
            end
        end
    end

    table.sort(records, function(a, b) return a.key < b.key end)
    return records
end

function CombinedRoot:PublicCategoryRow(slot)
    local category = Variables:GetVariable("S3C") or 0
    local page = Variables:GetVariable("S3Q") or 0
    local records = self:GetPublicCategoryShips(
        category,
        ShipFinderSelectedRouteName
    )
    local record = records[page * 3 + slot]
    if record == nil then return "" end
    if category == 2 and record.routeName ~= nil then
        return "★ " .. record.name .. " — ▶ " .. record.routeName
    end
    return "★ " .. record.name
end

function CombinedRoot:PublicCategoryMore(de)
    local category = Variables:GetVariable("S3C") or 0
    local page = Variables:GetVariable("S3Q") or 0
    local records = self:GetPublicCategoryShips(
        category,
        ShipFinderSelectedRouteName
    )
    if #records > (page + 1) * 3 then
        local fr = not de and tostring(ShipFinderUILanguage or "") == "fr"
        return de and "Mehr Schiffe ▶"
            or (fr and "Plus de navires ▶" or "More ships ▶")
    end
    return ""
end

local function currentFleetSnapshot()
    local snapshot = {
        total = 0,
        civilian = 0,
        assigned = 0,
        assignedCivilian = 0,
        independent = 0,
        warships = 0,
        paused = 0,
        routeCount = 0,
        activeRouteCount = 0,
        nativeWarningRouteCount = 0,
        representedWarningRouteCount = 0,
        warningRoutesWithoutLiveShip = 0,
        singleShipRoutes = 0,
        multiShipRoutes = 0,
        maxShipsOnRoute = 0,
    }

    local nativeIssueRoutes = ShipFinderCurrentNativeIssueRoutes()
    local routes = {}
    local activeRoutes = {}
    local representedWarningRoutes = {}
    local routeShipCounts = {}

    for _ in pairs(nativeIssueRoutes or {}) do
        snapshot.nativeWarningRouteCount = snapshot.nativeWarningRouteCount + 1
    end

    for _, object in pairs(
        Scripts:GetObjectGroupByProperty(Properties.ShipModuleOwner) or {}
    ) do
        local name = object.Nameable and object.Nameable.Name
        if name ~= nil then
            snapshot.total = snapshot.total + 1

            local tradeRoute = object.TradeRouteVehicle
            local assigned = tradeRoute
                and tradeRoute.IsAssignedOnTradeRoute == true
            local paused = tradeRoute and tradeRoute.IsPaused == true
            local routeName = tradeRoute and tradeRoute.RouteName or nil
            local military = object.Unit
                and object.Unit.IsMilitaryUnit == true

            if military then
                snapshot.warships = snapshot.warships + 1
            else
                snapshot.civilian = snapshot.civilian + 1
            end

            if assigned then
                snapshot.assigned = snapshot.assigned + 1

                if not military then
                    snapshot.assignedCivilian =
                        snapshot.assignedCivilian + 1
                end

                if routeName ~= nil then
                    local routeText = tostring(routeName)
                    routes[routeText] = true
                    routeShipCounts[routeText] =
                        (routeShipCounts[routeText] or 0) + 1

                    if not paused then
                        activeRoutes[routeText] = true
                    end

                    local issueKey = ShipFinderNativeRouteKey(routeText)
                    if nativeIssueRoutes[issueKey] ~= nil then
                        representedWarningRoutes[issueKey] = true
                    end
                end
            end

            if not military and not assigned then
                snapshot.independent = snapshot.independent + 1
            end

            if not military
                and assigned
                and routeName ~= nil
                and nativeIssueRoutes[
                    ShipFinderNativeRouteKey(routeName)
                ] ~= nil
            then
                snapshot.paused = snapshot.paused + 1
            end
        end
    end

    for _ in pairs(routes) do
        snapshot.routeCount = snapshot.routeCount + 1
    end

    for _ in pairs(activeRoutes) do
        snapshot.activeRouteCount = snapshot.activeRouteCount + 1
    end

    for _ in pairs(representedWarningRoutes) do
        snapshot.representedWarningRouteCount =
            snapshot.representedWarningRouteCount + 1
    end

    snapshot.warningRoutesWithoutLiveShip = math.max(
        0,
        snapshot.nativeWarningRouteCount
            - snapshot.representedWarningRouteCount
    )

    for _, count in pairs(routeShipCounts) do
        if count == 1 then
            snapshot.singleShipRoutes = snapshot.singleShipRoutes + 1
        elseif count > 1 then
            snapshot.multiShipRoutes = snapshot.multiShipRoutes + 1
        end

        if count > snapshot.maxShipsOnRoute then
            snapshot.maxShipsOnRoute = count
        end
    end

    return snapshot
end


function CombinedRoot:FleetOverviewParchmentText(de)
    local ok, result = pcall(function()
        local s = currentFleetSnapshot()
        local assignedPct = 0
        local independentPct = 0

        if s.civilian > 0 then
            assignedPct = math.floor(
                (s.assignedCivilian * 100 / s.civilian) + 0.5
            )
            independentPct = math.floor(
                (s.independent * 100 / s.civilian) + 0.5
            )
        end

        local fr = not de and tostring(ShipFinderUILanguage or "") == "fr"

        if de then
            return "FLOTTENZUSAMMENFASSUNG\n\n"
                .. "Aktuelle Provinz/Sitzung • "
                .. tostring(s.total) .. " Schiffe\n"
                .. "Strg+Alt+0: Zurueck zum Ship Finder-Menue\n\n"

                .. "FLOTTENSTRUKTUR\n"
                .. "Zivile Schiffe: " .. tostring(s.civilian) .. "\n"
                .. "  Zugewiesen: " .. tostring(s.assignedCivilian)
                .. " (" .. tostring(assignedPct) .. "%)\n"
                .. "  Unabhängig: " .. tostring(s.independent)
                .. " (" .. tostring(independentPct) .. "%)\n"
                .. "Kriegsschiffe: " .. tostring(s.warships) .. "\n\n"

                .. "ROUTENZUWEISUNG\n"
                .. "Vertretene Routen: " .. tostring(s.routeCount) .. "\n"
                .. "Routen mit 1 Schiff: "
                .. tostring(s.singleShipRoutes) .. "\n"
                .. "Routen mit mehreren Schiffen: "
                .. tostring(s.multiShipRoutes) .. "\n"
                .. "Größte Routenzuweisung: "
                .. tostring(s.maxShipsOnRoute) .. " Schiffe\n\n"

                .. "⚠ HANDLUNGSBEDARF\n"
                .. "Schiffe auf Warnrouten: " .. tostring(s.paused) .. "\n"
                .. "Warnrouten mit sichtbaren Schiffen: "
                .. tostring(s.representedWarningRouteCount) .. "\n"
                .. "Warnrouten ohne sichtbares Schiff: "
                .. tostring(s.warningRoutesWithoutLiveShip) .. "\n\n"

                .. "Nur aktuelle Provinz/Sitzung - nicht reichsweit."
        end

        if fr then
            return "RÉSUMÉ DE LA FLOTTE\n\n"
                .. "Province/session actuelle • "
                .. tostring(s.total) .. " navires\n"
                .. "Ctrl+Alt+0 : retour au menu Ship Finder\n\n"

                .. "COMPOSITION DE LA FLOTTE\n"
                .. "Navires civils : " .. tostring(s.civilian) .. "\n"
                .. "  Affectés : " .. tostring(s.assignedCivilian)
                .. " (" .. tostring(assignedPct) .. "%)\n"
                .. "  Indépendants : " .. tostring(s.independent)
                .. " (" .. tostring(independentPct) .. "%)\n"
                .. "Navires de guerre : " .. tostring(s.warships) .. "\n\n"

                .. "AFFECTATION AUX ROUTES COMMERCIALES\n"
                .. "Routes représentées : " .. tostring(s.routeCount) .. "\n"
                .. "Routes avec 1 navire : "
                .. tostring(s.singleShipRoutes) .. "\n"
                .. "Routes avec plusieurs navires : "
                .. tostring(s.multiShipRoutes) .. "\n"
                .. "Affectation maximale à une route : "
                .. tostring(s.maxShipsOnRoute) .. " navires\n\n"

                .. "⚠ NÉCESSITANT VOTRE ATTENTION\n"
                .. "Navires sur des routes signalées : " .. tostring(s.paused) .. "\n"
                .. "Routes signalées avec des navires visibles : "
                .. tostring(s.representedWarningRouteCount) .. "\n"
                .. "Routes signalées sans navire visible : "
                .. tostring(s.warningRoutesWithoutLiveShip) .. "\n\n"

                .. "Province/session actuelle uniquement — pas à l’échelle de l’Empire."
        end

        return "FLEET SUMMARY\n\n"
            .. "Current province/session • "
            .. tostring(s.total) .. " live ships\n"
            .. "Ctrl+Alt+0: Back to Ship Finder menu\n\n"

            .. "FLEET COMPOSITION\n"
            .. "Civilian ships: " .. tostring(s.civilian) .. "\n"
            .. "  Assigned: " .. tostring(s.assignedCivilian)
            .. " (" .. tostring(assignedPct) .. "%)\n"
            .. "  Independent: " .. tostring(s.independent)
            .. " (" .. tostring(independentPct) .. "%)\n"
            .. "Warships: " .. tostring(s.warships) .. "\n\n"

            .. "ROUTE ALLOCATION\n"
            .. "Routes represented: " .. tostring(s.routeCount) .. "\n"
            .. "Routes with 1 ship: "
            .. tostring(s.singleShipRoutes) .. "\n"
            .. "Routes with multiple ships: "
            .. tostring(s.multiShipRoutes) .. "\n"
            .. "Largest route allocation: "
            .. tostring(s.maxShipsOnRoute) .. " ships\n\n"

            .. "⚠ NEEDING ATTENTION\n"
            .. "Ships on warning routes: " .. tostring(s.paused) .. "\n"
            .. "Warning routes with visible ships: "
            .. tostring(s.representedWarningRouteCount) .. "\n"
            .. "Warning routes without a visible ship: "
            .. tostring(s.warningRoutesWithoutLiveShip) .. "\n\n"

            .. "Current province/session only - not empire-wide."
    end)

    if ok then return result end

    system.log(
        "[Ship Finder Fleet Analysis 1.4.36] SUMMARY ERROR | "
        .. tostring(result)
    )
    local fr = not de and tostring(ShipFinderUILanguage or "") == "fr"
    return de
        and "Flottenzusammenfassung konnte nicht geladen werden."
        or (fr and "Le résumé de la flotte n’a pas pu être chargé."
            or "Fleet Summary could not be loaded.")
end

function CombinedRoot:FleetSummaryText(de)
    local ok, result = pcall(function()
        local s = currentFleetSnapshot()
        local fr = not de and tostring(ShipFinderUILanguage or "") == "fr"
        if de then
            return "Nur aktuelle Provinz/Sitzung - nicht reichsweit.\n\n"
                .. "Aktuell verfügbare Schiffe: " .. tostring(s.total) .. "\n"
                .. "Zugewiesene Schiffe: " .. tostring(s.assigned) .. "\n"
                .. "Unabhängige zivile Schiffe: " .. tostring(s.independent) .. "\n"
                .. "Kriegsschiffe: " .. tostring(s.warships) .. "\n"
                .. "Zivile Schiffe auf Routen mit nativen Warnungen: " .. tostring(s.paused) .. "\n"
                .. "Vertretene Routen: " .. tostring(s.routeCount) .. "\n"
                .. "Aktive Routen in Flotte nach Route: "
                .. tostring(s.activeRouteCount)
                .. "\n\nKennzahlen können sich überschneiden."
        end
        if fr then
            return "Province/session actuelle uniquement — pas à l’échelle de l’Empire.\n\n"
                .. "Navires disponibles : " .. tostring(s.total) .. "\n"
                .. "Navires affectés : " .. tostring(s.assigned) .. "\n"
                .. "Navires civils indépendants : " .. tostring(s.independent) .. "\n"
                .. "Navires de guerre : " .. tostring(s.warships) .. "\n"
                .. "Navires civils sur des routes signalées par le jeu : " .. tostring(s.paused) .. "\n"
                .. "Routes représentées : " .. tostring(s.routeCount) .. "\n"
                .. "Routes actives dans Flotte par route : "
                .. tostring(s.activeRouteCount)
                .. "\n\nLes statistiques peuvent se chevaucher."
        end
        return "Current province/session only - not empire-wide.\n\n"
            .. "Live ships: " .. tostring(s.total) .. "\n"
            .. "Assigned ships: " .. tostring(s.assigned) .. "\n"
            .. "Independent non-military ships: " .. tostring(s.independent) .. "\n"
            .. "Warships: " .. tostring(s.warships) .. "\n"
            .. "Non-military ships on native-warning routes: " .. tostring(s.paused) .. "\n"
            .. "Routes represented: " .. tostring(s.routeCount) .. "\n"
            .. "Active routes in Fleet by Route: "
            .. tostring(s.activeRouteCount)
            .. "\n\nMetrics can overlap."
    end)

    if ok then return result end
    system.log("[Ship Finder Fleet Summary 1.4.5] ERROR | " .. tostring(result))
    local fr = not de and tostring(ShipFinderUILanguage or "") == "fr"
    return de
        and "Flottenübersicht konnte nicht geladen werden."
        or (fr and "Le résumé de la flotte n’a pas pu être chargé."
            or "Fleet summary could not be loaded.")
end

function CombinedRoot:FleetSummaryRow(row, de)
    local fr = not de and tostring(ShipFinderUILanguage or "") == "fr"
    local ok, result = pcall(function()
        local s = currentFleetSnapshot()
        if row == 1 then
            return de
                and ("Schiffe: " .. tostring(s.total)
                    .. "   |   Zugewiesen: " .. tostring(s.assigned))
                or (fr
                    and ("Navires : " .. tostring(s.total)
                        .. "   |   Affectés : " .. tostring(s.assigned))
                    or ("Live ships: " .. tostring(s.total)
                        .. "   |   Assigned: " .. tostring(s.assigned)))
        elseif row == 2 then
            return de
                and ("Unabhängig: " .. tostring(s.independent)
                    .. "   |   Kriegsschiffe: " .. tostring(s.warships))
                or (fr
                    and ("Indépendants : " .. tostring(s.independent)
                        .. "   |   Navires de guerre : " .. tostring(s.warships))
                    or ("Independent: " .. tostring(s.independent)
                        .. "   |   Warships: " .. tostring(s.warships)))
        elseif row == 3 then
            return de
                and ("Zivile Schiffe auf Routen mit nativen Warnungen: " .. tostring(s.paused))
                or (fr
                    and ("Navires civils sur des routes signalées par le jeu : " .. tostring(s.paused))
                    or ("Non-military ships on native-warning routes: " .. tostring(s.paused)))
        end
        return de
            and ("Vertretene Routen: " .. tostring(s.routeCount)
                .. "   |   Aktiv: " .. tostring(s.activeRouteCount))
            or (fr
                and ("Routes représentées : " .. tostring(s.routeCount)
                    .. "   |   Actives : " .. tostring(s.activeRouteCount))
                or ("Routes represented: " .. tostring(s.routeCount)
                    .. "   |   Active: " .. tostring(s.activeRouteCount)))
    end)

    if ok then return result end
    system.log("[Ship Finder Fleet Summary Row 1.4.6] ERROR | " .. tostring(result))
    return de and "Flottenkennzahl nicht verfügbar."
        or (fr and "Statistique de flotte indisponible."
            or "Fleet metric unavailable.")
end

function CombinedRoot:CategoryFirstPageText(de)
    local fr = not de and tostring(ShipFinderUILanguage or "") == "fr"
    local ok, result = pcall(function()
        local category = Variables:GetVariable("S3C") or 0
        local s = currentFleetSnapshot()
        if category == 2 and s.paused == 0 then
            return de
                and "Keine Schiffe benötigen aktuell Aufmerksamkeit"
                or (fr and "Aucun navire ne nécessite actuellement votre attention"
                    or "No ships currently need attention")
        elseif category == 4 and s.warships == 0 then
            return de
                and "Keine Kriegsschiffe in dieser Provinz/Sitzung"
                or (fr and "Aucun navire de guerre dans cette province/session"
                    or "No warships in this province/session")
        elseif category == 5 and s.independent == 0 then
            return de
                and "Keine unabhängigen zivilen Schiffe in dieser Provinz/Sitzung"
                or (fr and "Aucun navire civil indépendant dans cette province/session"
                    or "No independent non-military ships in this province/session")
        end
        return de and "▲ Erste Schiffe"
            or (fr and "▲ Premiers navires" or "▲ First ships")
    end)

    if ok then return result end
    system.log("[Ship Finder Category First Page 1.4.6] ERROR | " .. tostring(result))
    return de and "▲ Erste Schiffe"
        or (fr and "▲ Premiers navires" or "▲ First ships")
end

function CombinedRoot:ShipCategoryDescription(de)
    local fr = not de and tostring(ShipFinderUILanguage or "") == "fr"
    local ok, result = pcall(function()
        local category = Variables:GetVariable("S3C") or 0
        local s = currentFleetSnapshot()
        if category == 2 then
            if s.paused == 0 then
                return de
                    and "Kein zugewiesenes ziviles Schiff befindet sich aktuell auf einer Route mit einer nativen Warnung. Unabhängige Schiffe gelten nicht automatisch als Problem."
                    or (fr
                        and "Aucun navire civil affecté ne se trouve actuellement sur une route signalée par le jeu. Les navires indépendants ne sont pas automatiquement considérés comme un problème."
                        or "No assigned non-military ship is currently on a route with a native warning. Independent ships are not automatically treated as a fault.")
            end
            return de
                and (tostring(s.paused) .. " zugewiesene zivile Schiffe befinden sich auf Routen mit nativen Warnungen.")
                or (fr
                    and (tostring(s.paused) .. " navires civils affectés se trouvent sur des routes signalées par le jeu.")
                    or (tostring(s.paused) .. " assigned non-military ship(s) are on routes with native warnings."))
        elseif category == 4 then
            return de
                and (tostring(s.warships) .. " Kriegsschiffe in der aktuellen Provinz/Sitzung.")
                or (fr
                    and (tostring(s.warships) .. " navires de guerre dans la province/session actuelle.")
                    or (tostring(s.warships) .. " warship(s) in the current province/session."))
        elseif category == 5 then
            return de
                and (tostring(s.independent) .. " unabhängige zivile Schiffe in der aktuellen Provinz/Sitzung.")
                or (fr
                    and (tostring(s.independent) .. " navires civils indépendants dans la province/session actuelle.")
                    or (tostring(s.independent) .. " independent non-military ship(s) in the current province/session."))
        end
        return de
            and "Wähle ein Schiff aus der aktuellen Provinz."
            or (fr and "Choisissez un navire dans la province actuelle."
                or "Choose a ship from the current province.")
    end)

    if ok then return result end
    system.log("[Ship Finder Category Description 1.4.5] ERROR | " .. tostring(result))
    return de and "Schiffsbericht nicht verfügbar."
        or (fr and "Rapport de navire indisponible."
            or "Ship report unavailable.")
end

function CombinedRoot:Open()
    system.log("[Ship Finder 1.5.0] Open")
    self:_sf1425ResetAttentionMenuBridge()
    self:_sf1432ResetFleetOverviewBridge()
    ShipFinderAttentionRealRouteCache = nil

    ShipFinderAttentionWarningDetailCache = {}

    if ShipFinderAttentionWarningStatesProbe ~= nil then
        ShipFinderAttentionWarningStatesProbe.active = false
        ShipFinderAttentionWarningStatesProbe.queue = {}
        ShipFinderAttentionWarningStatesProbe.index = 0
        ShipFinderAttentionWarningStatesProbe.phase = "idle"
        ShipFinderAttentionWarningStatesProbe.focusedName = nil
    end
    -- Clear any stale Attention parchment state before opening the main menu.
    if ShipFinderAttentionParchmentTest ~= nil then
        ShipFinderAttentionParchmentTest.active = false
        ShipFinderAttentionParchmentTest.pendingOpen = false
        ShipFinderAttentionParchmentTest.opening = false
        ShipFinderAttentionParchmentTest.visible = {}
    end
    directOpenPending = false
    directOpenAttempt = 0
    ShipFinderAttentionScanRequested = false
    ShipFinderNativeIssueRouteCache = ShipFinderNativeIssueRouteSnapshot()
    ShipFinderPersonalLabelCache = {}

    if ShipFinderIslandUI
        and ShipFinderIslandUI.tryFastResume
        and ShipFinderIslandUI.tryFastResume()
    then
        return true
    end

    system.log(
        "[Ship Finder 1.5.0] FAST MENU"
        .. " | tradeRouteUIScan=false"
        .. " | attentionScan=on-demand"
    )

    ntOpenShipFinderMenu()

    return true
end

return CombinedRoot
