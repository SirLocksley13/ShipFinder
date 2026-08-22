
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

system.log("[Ship Finder Public Category] handler entered")

local category = Variables:GetVariable("S3C") or 0
local page = Variables:GetVariable("S3Q") or 0
local slot = Variables:GetVariable("S3L") or 1
local records = nil
local queryOk, queryError = pcall(function()
    if category == 2 then
        -- The Patch 2.0 native-warning query is repeated in this Action script
        -- context. The module method can abort here even though it works while
        -- building the menu. Querying again also guarantees fresh live objects.
        local issues = {}
        local manager = TradeRoute and TradeRoute.get and TradeRoute.get() or nil
        for _, issue in pairs(
            (manager and manager.TradeRoutesWithIssues) or {}
        ) do
            local valid = issue ~= nil
            local issueName = nil
            pcall(function()
                if issue.isValid then valid = issue:isValid() end
            end)
            pcall(function() issueName = issue.Name end)
            if valid and issueName ~= nil then
                local key = string.lower(
                    tostring(issueName):gsub("^%s+", ""):gsub("%s+$", "")
                )
                issues[key] = true
            end
        end

        records = {}
        for _, object in pairs(
            Scripts:GetObjectGroupByProperty(Properties.ShipModuleOwner) or {}
        ) do
            local name = object.Nameable and object.Nameable.Name
            local route = object.TradeRouteVehicle
            local assigned = route and route.IsAssignedOnTradeRoute == true
            local routeName = route and route.RouteName or nil
            local military = object.Unit
                and object.Unit.IsMilitaryUnit == true
            local issueKey = routeName and string.lower(
                tostring(routeName):gsub("^%s+", ""):gsub("%s+$", "")
            ) or nil

            if name ~= nil
                and assigned
                and not military
                and issueKey ~= nil
                and issues[issueKey] == true
            then
                local textName = tostring(name)
                records[#records + 1] = {
                    name = textName,
                    key = string.lower(textName) .. "|" .. tostring(object.ID),
                    object = object,
                }
            end
        end
        table.sort(records, function(a, b) return a.key < b.key end)
    elseif category == 4 or category == 5 then
        -- Warships and Independent Ships must also be queried locally in the
        -- Action-script context. ShipFinderCombinedRoot is unavailable here,
        -- even though the same module methods work while building the menu.
        records = {}
        for _, object in pairs(
            Scripts:GetObjectGroupByProperty(Properties.ShipModuleOwner) or {}
        ) do
            local rawName = object.Nameable and object.Nameable.Name
            if rawName ~= nil then
                local route = object.TradeRouteVehicle
                local assigned = route
                    and route.IsAssignedOnTradeRoute == true
                local military = object.Unit
                    and object.Unit.IsMilitaryUnit == true
                local include = (category == 4 and military)
                    or (category == 5 and not military and not assigned)

                if include then
                    local name = tostring(rawName)
                    records[#records + 1] = {
                        name = name,
                        key = string.lower(name)
                            .. "|" .. tostring(object.ID),
                        object = object,
                    }
                end
            end
        end
        table.sort(records, function(a, b) return a.key < b.key end)
    else
        local selectedNativeRouteName = nil
        if category == 6 then
            selectedNativeRouteName = getSelectedNativeRouteName()
        end
        records = ShipFinderCombinedRoot:GetPublicCategoryShips(
            category,
            selectedNativeRouteName
        )
    end
end)

if not queryOk then
    system.log(
        "[Ship Finder Public Category] query ERROR"
        .. " | category=" .. tostring(category)
        .. " | error=" .. tostring(queryError)
    )
    return
end

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
    local nativeID = selected.object.ID
    local selectOk, selectError = pcall(function()
        Selection:SelectByID(nativeID)
    end)
    local jumpOk, jumpError = pcall(function()
        Scripts:JumpToObject(nativeID)
    end)

    if selectOk and jumpOk then
        system.log(
            "[Ship Finder Public Category] jump completed"
            .. " | objectId=" .. tostring(nativeID)
            .. " | freshQuery=true"
        )
    else
        system.log(
            "[Ship Finder Public Category] jump ERROR"
            .. " | objectId=" .. tostring(nativeID)
            .. " | selectSuccess=" .. tostring(selectOk)
            .. " | jumpSuccess=" .. tostring(jumpOk)
            .. " | selectError=" .. tostring(selectError or "")
            .. " | jumpError=" .. tostring(jumpError or "")
        )
    end
end
