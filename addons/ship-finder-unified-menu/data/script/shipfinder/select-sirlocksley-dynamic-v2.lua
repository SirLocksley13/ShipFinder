-- Diagnostic live personal-catalogue click handler.
-- This build preserves the existing selection logic and adds staged logging only.

local diagnosticStage = "00 script start"
system.log("[Ship Finder Personal Diagnostic] 00 script loaded")

local ok, diagnosticError = pcall(function()
    diagnosticStage = "01 handler entered"
    system.log("[Ship Finder Personal Diagnostic] 01 handler entered")

    local category = Variables:GetVariable("S3C") or 0
    local firstIndex = Variables:GetVariable("S3F") or 0
    local firstPage = Variables:GetVariable("S3P") or 0
    local secondIndex = Variables:GetVariable("S3S") or 0
    local secondPage = Variables:GetVariable("S3R") or 0
    local page = Variables:GetVariable("S3Q") or 0
    local slot = Variables:GetVariable("S3L") or 0

    diagnosticStage = "02 variables read"
    system.log(
        "[Ship Finder Personal Diagnostic] 02 variables read | S3C=" .. tostring(category)
        .. " S3F=" .. tostring(firstIndex)
        .. " S3P=" .. tostring(firstPage)
        .. " S3S=" .. tostring(secondIndex)
        .. " S3R=" .. tostring(secondPage)
        .. " S3Q=" .. tostring(page)
        .. " S3L=" .. tostring(slot)
    )

    local objects = Scripts:GetObjectGroupByProperty(Properties.ShipModuleOwner) or {}

    diagnosticStage = "03 fleet query completed"
    local objectCount = 0
    for _ in pairs(objects) do
        objectCount = objectCount + 1
    end
    system.log("[Ship Finder Personal Diagnostic] 03 fleet query completed | objects=" .. tostring(objectCount))

    local function parseTrade(name)
        return string.match(tostring(name), "^([LlAa])_([^_]+)_([^_]+)_(%d+)$")
    end

    local function classify(object, name)
        local route = object.TradeRouteVehicle
        local assigned = route and route.IsAssignedOnTradeRoute or false
        local paused = route and route.IsPaused or false

        local _, first = parseTrade(name)
        if first ~= nil then
            if assigned and not paused then return 1 end
            return 2
        end
        local lower = string.lower(name)
        if string.match(lower, "^runner%s") or string.match(lower, "%srunner$") then return 3 end
        local unit = object.Unit
        if unit and unit.IsMilitaryUnit then return 4 end
        return 5
    end

    local function naturalKey(name)
        return string.gsub(string.lower(tostring(name)), "%d+", function(number)
            return string.rep("0", math.max(0, 20 - #number)) .. number
        end)
    end

    local records = {}
    for _, object in pairs(objects) do
        local nameable = object.Nameable
        local rawName = nameable and nameable.Name
        if rawName ~= nil then
            local name = tostring(rawName)
            local _, first, second, routeNumber = parseTrade(name)
            table.insert(records, {
                object = object,
                name = name,
                category = classify(object, name),
                firstKey = first and string.lower(first) or nil,
                secondKey = second and string.lower(second) or nil,
                routeNumber = tonumber(routeNumber) or 0,
                naturalKey = naturalKey(name)
            })
        end
    end

    diagnosticStage = "04 records built"
    system.log("[Ship Finder Personal Diagnostic] 04 records built | records=" .. tostring(#records))

    local candidates = {}
    for _, record in ipairs(records) do
        if record.category == category then
            table.insert(candidates, record)
        end
    end

    diagnosticStage = "05 candidates filtered"
    system.log("[Ship Finder Personal Diagnostic] 05 candidates filtered | category=" .. tostring(category) .. " candidates=" .. tostring(#candidates))

    local selected = nil
    diagnosticStage = "06 sorting started"
    system.log("[Ship Finder Personal Diagnostic] 06 sorting started")

    if category <= 2 then
        table.sort(candidates, function(a, b)
            local ak = a.firstKey .. "|" .. a.secondKey .. "|" .. string.format("%020d", a.routeNumber) .. "|" .. tostring(a.object.ID)
            local bk = b.firstKey .. "|" .. b.secondKey .. "|" .. string.format("%020d", b.routeNumber) .. "|" .. tostring(b.object.ID)
            return ak < bk
        end)

        diagnosticStage = "06A route sorting completed"
        system.log("[Ship Finder Personal Diagnostic] 06A route sorting completed")

        local currentFirst = ""
        local currentSecond = ""
        local firstOrdinal = 0
        local secondOrdinal = 0
        local row = 0
        local targetRow = (page * 2) + slot
        for _, record in ipairs(candidates) do
            if record.firstKey ~= currentFirst then
                currentFirst = record.firstKey
                currentSecond = ""
                firstOrdinal = firstOrdinal + 1
                secondOrdinal = 0
            end
            if firstOrdinal == firstIndex then
                if record.secondKey ~= currentSecond then
                    currentSecond = record.secondKey
                    secondOrdinal = secondOrdinal + 1
                    row = 0
                end
                if secondOrdinal == secondIndex then
                    row = row + 1
                    if row == targetRow then
                        selected = record
                        break
                    end
                elseif secondOrdinal > secondIndex then
                    break
                end
            elseif firstOrdinal > firstIndex then
                break
            end
        end
    else
        table.sort(candidates, function(a, b)
            local ak = string.lower(a.name) .. "|" .. tostring(a.object.ID)
            local bk = string.lower(b.name) .. "|" .. tostring(b.object.ID)
            return ak < bk
        end)

        diagnosticStage = "06B general sorting completed"
        system.log("[Ship Finder Personal Diagnostic] 06B general sorting completed")
        selected = candidates[(page * 3) + slot]
    end

    diagnosticStage = "07 selection reconstructed"
    local selectedName = selected and selected.name or "<none>"
    local selectedId = selected and tostring(selected.object.ID) or "<none>"
    system.log(
        "[Ship Finder Personal Diagnostic] 07 selection reconstructed | selected="
        .. selectedName .. " objectId=" .. selectedId
    )

    system.log("[Ship Finder Personal Dynamic] Click | S3C=" .. tostring(category) .. " S3F=" .. tostring(firstIndex) .. " S3P=" .. tostring(firstPage) .. " S3S=" .. tostring(secondIndex) .. " S3R=" .. tostring(secondPage) .. " S3Q=" .. tostring(page) .. " S3L=" .. tostring(slot) .. " selected=" .. selectedName)
    if selected == nil then
        diagnosticStage = "07A no selection"
        system.log("[Ship Finder Personal Diagnostic] 07A no selection; jump skipped")
        return
    end

    diagnosticStage = "08 jump started"
    system.log("[Ship Finder Personal Diagnostic] 08 jump started | objectId=" .. selectedId)
    Selection:SelectByID(selected.object.ID)

    diagnosticStage = "08A selection completed"
    system.log("[Ship Finder Personal Diagnostic] 08A selection completed")
    Scripts:JumpToObject(selected.object.ID)

    diagnosticStage = "09 jump completed"
    system.log("[Ship Finder Personal Diagnostic] 09 jump completed")
end)

if not ok then
    system.log(
        "[Ship Finder Personal Diagnostic] ERROR after " .. tostring(diagnosticStage)
        .. " | " .. tostring(diagnosticError)
    )
end
