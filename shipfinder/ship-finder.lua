local ShipFinder = {}

ShipFinder.lastAlphabeticalShipId = nil

local alphabeticalCatalogueBySession = {
    [3245] = 2003000,
    [6627] = 2003002,
}

local sirLocksleyCatalogueBySession = {
    [3245] = 2015000,
    [6627] = 2015002,
}

function ShipFinder:Load()
    system.log("[Ship Finder] Lua loaded and shortcut function ready")
end

function ShipFinder:FindShip(searchText)
    if searchText == nil or searchText == "" then
        system.log("[Ship Finder] Search text is empty")
        return false
    end

    local normalizedSearch = string.lower(tostring(searchText))

    system.log(
        "[Ship Finder] Search started"
        .. " | Search: " .. tostring(searchText)
        .. " | Session: " .. tostring(GameSession.SessionGUID)
    )

    local ships =
        Scripts:GetObjectGroupByProperty(Properties.ShipModuleOwner)

    if ships == nil then
        system.log("[Ship Finder] Ship query returned nil")
        return false
    end

    for _, object in pairs(ships) do
        if object.Nameable ~= nil then
            local shipName = tostring(object.Nameable.Name)
            local normalizedName = string.lower(shipName)

            local matchPosition = string.find(
                normalizedName,
                normalizedSearch,
                1,
                true
            )

            if matchPosition ~= nil then
                local shipId = object.ID

                system.log(
                    "[Ship Finder] Match found"
                    .. " | Search: " .. tostring(searchText)
                    .. " | Name: " .. shipName
                    .. " | ID: " .. tostring(shipId)
                )

                Selection:SelectByID(shipId)
                Scripts:JumpToObject(shipId)

                system.log(
                    "[Ship Finder] Selection and jump completed"
                )

                return true
            end
        end
    end

    system.log(
        "[Ship Finder] No matching ship found"
        .. " | Search: " .. tostring(searchText)
    )

    return false
end

function ShipFinder:GetShipsSortedByName()
    local objects =
        Scripts:GetObjectGroupByProperty(Properties.ShipModuleOwner)
    local ships = {}

    if objects == nil then
        return ships
    end

    for _, object in pairs(objects) do
        if object.Nameable ~= nil then
            table.insert(ships, {
                id = object.ID,
                name = tostring(object.Nameable.Name),
            })
        end
    end

    local function naturalSortKey(name)
        local normalized = string.lower(name)
        local key = string.gsub(normalized, "%d+", function(number)
            return string.format("%020d", tonumber(number))
        end)

        return key
    end

    table.sort(ships, function(left, right)
        local leftName = naturalSortKey(left.name)
        local rightName = naturalSortKey(right.name)

        if leftName == rightName then
            return left.id < right.id
        end

        return leftName < rightName
    end)

    return ships
end

-- The shortcut module keeps its cursor as an object ID. Rebuilding the list on
-- every call handles new, renamed, or destroyed ships without stale references.
function ShipFinder:NavigateAlphabeticalShips(step)
    local ships = self:GetShipsSortedByName()

    if #ships == 0 then
        system.log("[Ship Finder] No named ships found")
        self.lastAlphabeticalShipId = nil
        return false
    end

    local nextIndex = step > 0 and 1 or #ships

    if self.lastAlphabeticalShipId ~= nil then
        for index, ship in ipairs(ships) do
            if ship.id == self.lastAlphabeticalShipId then
                nextIndex = index + step
                break
            end
        end
    end

    if nextIndex > #ships then
        nextIndex = 1
    elseif nextIndex < 1 then
        nextIndex = #ships
    end

    local ship = ships[nextIndex]
    self.lastAlphabeticalShipId = ship.id

    system.log(
        "[Ship Finder] Alphabetical ship selected"
        .. " | Position: " .. tostring(nextIndex) .. "/" .. tostring(#ships)
        .. " | Name: " .. ship.name
        .. " | ID: " .. tostring(ship.id)
    )

    Selection:SelectByID(ship.id)
    Scripts:JumpToObject(ship.id)

    return true
end

function ShipFinder:FindNextAlphabeticalShip()
    return self:NavigateAlphabeticalShips(1)
end

function ShipFinder:FindPreviousAlphabeticalShip()
    return self:NavigateAlphabeticalShips(-1)
end

function ShipFinder:OpenCatalogueForCurrentSession(catalogues, catalogueName)
    local session = GameSession.SessionGUID
    local storyline = catalogues[session]

    if storyline == nil then
        system.log(
            "[Ship Finder] No " .. catalogueName .. " catalogue for session"
            .. " | Session: " .. tostring(session)
        )
        return false
    end

    GovernorDecision:CheatStartGovernorDecisionForCurrentPlayerNet(storyline)
    return true
end

function ShipFinder:OpenAlphabeticalCatalogue()
    return self:OpenCatalogueForCurrentSession(
        alphabeticalCatalogueBySession,
        "alphabetical"
    )
end

function ShipFinder:OpenSirLocksleyCatalogue()
    return self:OpenCatalogueForCurrentSession(
        sirLocksleyCatalogueBySession,
        "Sir Locksley"
    )
end

return ShipFinder
