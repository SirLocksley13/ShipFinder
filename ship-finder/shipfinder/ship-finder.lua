local ShipFinder = {}

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

-- Temporary proof-of-concept entry point.
-- The future search interface will pass player-entered text to FindShip.
function ShipFinder:FindTestShip()
    self:FindShip("heir")
end

return ShipFinder
