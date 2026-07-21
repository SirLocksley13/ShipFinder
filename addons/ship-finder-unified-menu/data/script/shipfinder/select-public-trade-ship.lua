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
            include = (not assigned) or paused
        elseif category == 4 then
            include = military
        elseif category == 5 then
            include = not military
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
