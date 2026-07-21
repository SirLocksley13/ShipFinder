local CombinedRoot = {}

local PERSONAL_STORYLINE = 2035000
local PUBLIC_STORYLINE = 2035050

local function hasPersonalNamingConvention()
    local objects = Scripts:GetObjectGroupByProperty(Properties.ShipModuleOwner) or {}

    for _, object in pairs(objects) do
        local nameable = object.Nameable
        local rawName = nameable and nameable.Name
        if rawName ~= nil then
            local name = tostring(rawName)
            if string.match(name, "^[LlAa]_[^_]+_[^_]+_%d+$") then
                return true
            end
        end
    end

    return false
end

function CombinedRoot:Load()
    system.log("[Ship Finder Unified Menu 1.0.0] Lua loaded and Ctrl+Alt+F ready")
end

function CombinedRoot:Open()
    system.log("[Ship Finder Unified Menu 1.0.0] Open entered")

    -- Safe Lua-table cache clearing only.
    -- Do not call Variables:SetVariable here; that API is not proven.
    ShipFinderPersonalLabelCache = {}
    ShipFinderAlphabeticalDynamicCache = nil

    system.log("[Ship Finder Unified Menu 1.0.0] caches cleared | session=" .. tostring((GameSession and GameSession.SessionGUID) or 0))

    local ok, personalOrError = pcall(hasPersonalNamingConvention)
    local personal = false

    if ok then
        personal = personalOrError == true
        system.log(
            "[Ship Finder Unified Menu 1.0.0] detection completed"
            .. " | personalNaming=" .. tostring(personal)
        )
    else
        system.log(
            "[Ship Finder Unified Menu 1.0.0] detection error"
            .. " | " .. tostring(personalOrError)
            .. " | falling back to public menu"
        )
    end

    ShipFinderPersonalMode = personal

    local storyline = personal and PERSONAL_STORYLINE or PUBLIC_STORYLINE

    system.log(
        "[Ship Finder Unified Menu 1.0.0] opening storyline"
        .. " | storyline=" .. tostring(storyline)
    )

    GovernorDecision:CheatStartGovernorDecisionForCurrentPlayerNet(storyline)

    system.log("[Ship Finder Unified Menu 1.0.0] storyline call returned")
    return true
end


return CombinedRoot
