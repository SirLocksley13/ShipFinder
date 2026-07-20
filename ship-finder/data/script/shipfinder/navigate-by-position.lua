-- Governor decision actions run in a separate Lua environment from the
-- shortcut module, so this adapter rebuilds the same read-only ship view and
-- reads its cursor from Anno's condition-variable manager.
local objects = Scripts:GetObjectGroupByProperty(Properties.ShipModuleOwner)
local ships = {}

if objects ~= nil then
    for _, object in pairs(objects) do
        if object.Nameable ~= nil then
            table.insert(ships, {
                id = object.ID,
                name = tostring(object.Nameable.Name),
            })
        end
    end
end

table.sort(ships, function(left, right)
    local leftName = string.lower(left.name)
    local rightName = string.lower(right.name)

    if leftName == rightName then
        return left.id < right.id
    end

    return leftName < rightName
end)

if #ships == 0 then
    system.log("[Ship Finder] Advisor navigation found no named ships")
else
    local position = Variables:GetVariable("ShipFinderPosition") or 0
    local index = ((position - 1) % #ships) + 1

    local ship = ships[index]

    system.log(
        "[Ship Finder] Advisor ship selected"
        .. " | Position: " .. tostring(index) .. "/" .. tostring(#ships)
        .. " | Name: " .. ship.name
        .. " | ID: " .. tostring(ship.id)
        .. " | Cursor: " .. tostring(position)
    )

    Selection:SelectByID(ship.id)
    Scripts:JumpToObject(ship.id)
end
