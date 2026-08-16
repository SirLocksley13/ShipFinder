-- Generated dynamic-catalogue click handler. Labels and selection use identical filtering and sorting.
local group = Variables:GetVariable("ShipFinderAlphabeticalDynamicGroup") or 0
local page = Variables:GetVariable("ShipFinderAlphabeticalDynamicPage") or 0
local slot = Variables:GetVariable("ShipFinderAlphabeticalDynamicSlot") or 0
local objects = Scripts:GetObjectGroupByProperty(Properties.ShipModuleOwner) or {}
local ships = {}

local function isInSelectedGroup(object)
    if object.Nameable == nil then
        return false
    end

    local first = string.upper(string.sub(tostring(object.Nameable.Name), 1, 1))
    if group >= 1 and group <= 26 then
        return first == string.char(64 + group)
    end

    return group == 27 and not string.match(first, "^[A-Z]$")
end

for _, object in pairs(objects) do
    if isInSelectedGroup(object) then
        table.insert(ships, object)
    end
end

local function naturalSortKey(name)
    return string.gsub(string.lower(tostring(name)), "%d+", function(number)
        return string.format("%020d", tonumber(number))
    end)
end

table.sort(ships, function(left, right)
    local leftKey = naturalSortKey(left.Nameable.Name)
    local rightKey = naturalSortKey(right.Nameable.Name)
    if leftKey == rightKey then
        return left.ID < right.ID
    end
    return leftKey < rightKey
end)

local index = (page * 4) + slot
local ship = ships[index]
if ship == nil then
    system.log(
        "[Ship Finder Internal Alphabetical] Empty row selected"
        .. " | Group: " .. tostring(group)
        .. " | Page: " .. tostring(page)
        .. " | Slot: " .. tostring(slot)
    )
    return
end

system.log(
    "[Ship Finder Internal Alphabetical] Selecting live catalogue ship"
    .. " | Group: " .. tostring(group)
    .. " | Page: " .. tostring(page)
    .. " | Slot: " .. tostring(slot)
    .. " | Name: " .. tostring(ship.Nameable.Name)
    .. " | ID: " .. tostring(ship.ID)
)

Selection:SelectByID(ship.ID)
Scripts:JumpToObject(ship.ID)
