local Fast = {}

local PREFIX = "[Ship Finder Island Filter Fast Scan 1.4.9 Native Route Attention]"

Fast.active = false
Fast.phase = "idle"
Fast.buttons = {}
Fast.current = 0
Fast.index = {}
Fast.routeCount = 0
Fast.activeRouteCount = 0
Fast.activeRouteIDs = {}
Fast.activeRouteNames = {}
Fast.routeRowsByID = {}
Fast.coveredRouteIDs = {}
Fast.acceptedIslands = 0
Fast.baselineSignature = ""
Fast.allRouteCount = 0
Fast.routeIslandMap = {}
Fast.resultIndex = nil
Fast.resultRouteCount = 0
Fast.resultRouteIslandMap = nil
Fast.rejectReason = nil
Fast.popupOpenedByUs = false
Fast.pendingStatus = nil
Fast.repairRoutes = {}
Fast.repairIndex = 0
Fast.repairVerifiedRouteIDs = {}
Fast.scanTiming = nil
Fast.filterTiming = nil
Fast.repairTiming = nil

local function log(text)
    system.log(PREFIX .. " | " .. tostring(text))
end

-- Capture several clocks because Anno builds do not expose one documented,
-- guaranteed high-resolution wall clock to Lua. Log timestamps remain the
-- authoritative wall-time evidence; these deltas make slow phases searchable.
local function timingSnapshot()
    local snapshot = { wall = nil, cpu = nil, play = nil }

    pcall(function()
        if os and type(os.time) == "function" then snapshot.wall = os.time() end
    end)
    pcall(function()
        if os and type(os.clock) == "function" then snapshot.cpu = os.clock() end
    end)
    pcall(function()
        snapshot.play = tonumber(Game and Game.PlayTime or nil)
    end)

    return snapshot
end

local function timingDeltaText(startSnapshot)
    local now = timingSnapshot()
    local wall = startSnapshot and startSnapshot.wall and now.wall
        and (now.wall - startSnapshot.wall) or nil
    local cpu = startSnapshot and startSnapshot.cpu and now.cpu
        and (now.cpu - startSnapshot.cpu) or nil
    local play = startSnapshot and startSnapshot.play and now.play
        and (now.play - startSnapshot.play) or nil

    return "elapsedWallSec=" .. tostring(wall)
        .. " | elapsedCpuSec=" .. tostring(cpu)
        .. " | elapsedPlayTimeRaw=" .. tostring(play)
end

local function getSceneParts()
    local scene = ui and ui.Scenes and ui.Scenes.TradeRoute or nil
    local overview = scene and scene.TradeOverview or nil
    local filter = overview and overview.FilterData or nil
    local islandList = filter and filter.IslandListData or nil
    local buttons = islandList and islandList.IslandListData or nil
    local rows = overview and overview.OverviewListData
        and overview.OverviewListData.ArrayData or nil
    return scene, overview, filter, islandList, buttons, rows
end

local function safeArraySize(array, helperName)
    if array == nil then return -1 end
    local helper = halo and halo[helperName] or nil
    if helper and helper.GetSize then
        local size = -1
        pcall(function() size = helper.GetSize(array) end)
        return size
    end
    return -1
end

local function safeArrayElement(array, helperName, index)
    if array == nil then return nil end
    local helper = halo and halo[helperName] or nil
    if helper and helper.GetElement then
        local value = nil
        pcall(function() value = helper.GetElement(array, index) end)
        return value
    end
    local value = nil
    pcall(function() value = array[index] end)
    return value
end

local function buttonText(button)
    local text = nil
    pcall(function()
        text = button.Data and button.Data.TextData and button.Data.TextData.Text or nil
    end)
    if text == nil or tostring(text) == "" then
        pcall(function()
            text = button.Data and button.Data.Text or nil
        end)
    end
    return text and tostring(text) or ""
end

local function buttonIsSelected(button)
    local selected = false
    pcall(function()
        selected = button.States and button.States.IsSelected == true
    end)
    return selected
end

local function pressButton(button)
    if button == nil then return false, "button-nil" end
    local states = nil
    pcall(function() states = button.States end)
    if states == nil then return false, "states-nil" end
    local fn = nil
    pcall(function() fn = states.EventPrimary end)
    if type(fn) ~= "function" then return false, "EventPrimary-unavailable" end
    local ok, result = pcall(function()
        return states:EventPrimary()
    end)
    return ok, result
end

local function activeShipsForRoute(routeName)
    local ships = {}
    for _, object in pairs(Scripts:GetObjectGroupByProperty(Properties.ShipModuleOwner) or {}) do
        local tr = object.TradeRouteVehicle
        if tr
            and tr.IsAssignedOnTradeRoute
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
            pcall(function() shipIDText = tostring(object.ID) end)
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

local function harvestActiveRouteRows(rows, activeNames)
    local found = {}
    local signatureParts = {}
    if rows == nil then return found, "" end

    local seenAny = false
    local emptyTail = 0
    for i = 0, 511 do
        local row = nil
        pcall(function() row = rows[i] end)
        if row ~= nil and string.find(tostring(row), "weak null", 1, true) == nil then
            seenAny = true
            emptyTail = 0
            local routeID, routeName = nil, nil
            pcall(function() routeID = row.RouteID end)
            pcall(function()
                routeName = row.NameData and row.NameData.Text or nil
            end)
            if type(routeID) == "number"
                and routeID >= 0
                and routeName ~= nil
                and (activeNames == nil or activeNames[tostring(routeName)])
            then
                found[routeID] = {
                    row = row,
                    routeID = routeID,
                    routeName = tostring(routeName),
                    overviewIndex = i,
                }
                signatureParts[#signatureParts + 1] = tostring(routeID)
            end
        elseif seenAny then
            emptyTail = emptyTail + 1
        end
        if seenAny and emptyTail >= 16 then break end
    end

    table.sort(signatureParts)
    return found, table.concat(signatureParts, ",")
end

local function countTable(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

local function rememberRouteIsland(routeRec, islandName)
    if routeRec == nil or islandName == nil or tostring(islandName) == "" then
        return
    end

    local routeID = routeRec.routeID
    if type(routeID) ~= "number" or routeID < 0 then
        return
    end

    local rec = Fast.routeIslandMap[routeID]
    if rec == nil then
        rec = {
            routeID = routeID,
            routeName = tostring(routeRec.routeName or ""),
            islands = {},
        }
        Fast.routeIslandMap[routeID] = rec
    end

    rec.routeName = tostring(routeRec.routeName or rec.routeName or "")
    rec.islands[tostring(islandName)] = true
end

local function rememberFilteredRouteIslands(islandName, routeRows)
    for _, routeRec in pairs(routeRows or {}) do
        rememberRouteIsland(routeRec, islandName)
    end
end

local function addIslandResult(name, routeRows)
    local rec = {
        name = name,
        routes = {},
        ships = {},
        shipSeen = {},
    }

    local routeCount = 0
    for routeID, route in pairs(routeRows or {}) do
        if Fast.activeRouteIDs[routeID] then
            routeCount = routeCount + 1
            rec.routes[#rec.routes + 1] = {
                routeID = routeID,
                routeName = route.routeName,
            }

            for _, ship in ipairs(activeShipsForRoute(route.routeName)) do
                local key = ship.name .. "|" .. ship.objectKey
                if not rec.shipSeen[key] then
                    rec.shipSeen[key] = true
                    rec.ships[#rec.ships + 1] = ship
                end
            end
        end
    end

    table.sort(rec.routes, function(a, b)
        return string.lower(a.routeName) < string.lower(b.routeName)
    end)
    table.sort(rec.ships, function(a, b)
        return string.lower(a.name) < string.lower(b.name)
    end)

    -- A real island filter must narrow the active route set.  Native UIs often
    -- include a synthetic "All" entry; a result identical to the baseline is
    -- therefore deliberately ignored rather than indexed as an island.
    if routeCount > 0 and routeCount < Fast.activeRouteCount then
        Fast.index[name] = rec
        Fast.acceptedIslands = Fast.acceptedIslands + 1
        Fast.routeCount = Fast.routeCount + routeCount
        for _, route in ipairs(rec.routes) do
            Fast.coveredRouteIDs[route.routeID] = true
        end
        return true, routeCount, #rec.ships
    end

    return false, routeCount, #rec.ships
end

local function closeFilterPopupIfNeeded()
    local _, _, filter = getSceneParts()
    if filter == nil then return end
    local visible = false
    pcall(function() visible = filter.IsPopupVisible == true end)
    if visible and Fast.popupOpenedByUs then
        local fn = nil
        pcall(function() fn = filter.CloseButtonEvent end)
        if type(fn) == "function" then
            pcall(function() filter:CloseButtonEvent() end)
        end
    end
end

local function clearSelectedButtons()
    for _, rec in ipairs(Fast.buttons or {}) do
        if buttonIsSelected(rec.button) then
            pressButton(rec.button)
        end
    end
end

function Fast:Load()
    log("helper loaded")
end

function Fast:IsActive()
    return self.active == true
end


local function expectedStationCount(routeID)
    local route = nil
    local okRoute = pcall(function()
        route = TradeRoute:GetRoute(routeID)
    end)
    if not okRoute or route == nil then return -1 end

    local count = 0
    for stationID = 0, 31 do
        local station = nil
        local okStation = pcall(function()
            station = route:GetStation(stationID)
        end)
        if okStation and station ~= nil then
            local valid = false
            pcall(function() valid = station:isValid() end)
            if valid then count = count + 1 end
        end
    end
    return count
end

local function discoveredMembershipCount(routeID)
    local count = 0
    for _, rec in pairs(Fast.index or {}) do
        for _, route in ipairs(rec.routes or {}) do
            if route.routeID == routeID then
                count = count + 1
                break
            end
        end
    end
    return count
end

local function focusRouteByID(routeID)
    if type(routeID) ~= "number" or routeID < 0 then
        return false, "invalid-route-id"
    end

    local ok, result = pcall(function()
        return TradeRoute:ShowRouteUI(routeID)
    end)

    return ok, result
end

local function readFocusedRouteStations()
    local selection = ui
        and ui.Scenes
        and ui.Scenes.TradeRoute
        and ui.Scenes.TradeRoute.TradeGoodSelection
        or nil

    local data = selection and selection.TradeRouteGoodData or nil
    local helper = halo
        and halo["PhoenixArray<halo::CTradeRouteGoodData>"]
        or nil

    local size = -1
    local entries = {}

    if data and helper and helper.GetSize then
        pcall(function()
            size = helper.GetSize(data)
        end)
    end

    if size > 0 and helper and helper.GetElement then
        for i = 0, size - 1 do
            local entry = nil
            pcall(function()
                entry = helper.GetElement(data, i)
            end)

            if entry ~= nil then
                local islandName, stationID = nil, nil
                pcall(function() islandName = entry.IslandName end)
                pcall(function() stationID = entry.StationID end)

                if islandName ~= nil and tostring(islandName) ~= "" then
                    entries[#entries + 1] = {
                        name = tostring(islandName),
                        stationID = stationID,
                    }
                end
            end
        end
    end

    return size, entries
end

local function mergeRouteStations(routeRec, entries)
    if routeRec == nil then return end

    for _, entry in ipairs(entries or {}) do
        local islandName = tostring(entry.name or "")
        if islandName ~= "" then
            rememberRouteIsland(routeRec, islandName)
            local rec = Fast.index[islandName]
            if rec == nil then
                rec = {
                    name = islandName,
                    routes = {},
                    ships = {},
                    shipSeen = {},
                }
                Fast.index[islandName] = rec
            end

            local hasRoute = false
            for _, r in ipairs(rec.routes or {}) do
                if r.routeID == routeRec.routeID then
                    hasRoute = true
                    break
                end
            end

            if not hasRoute then
                rec.routes[#rec.routes + 1] = {
                    routeID = routeRec.routeID,
                    routeName = routeRec.routeName,
                }
            end

            for _, ship in ipairs(activeShipsForRoute(routeRec.routeName)) do
                local key = ship.name .. "|" .. ship.objectKey
                if not rec.shipSeen[key] then
                    rec.shipSeen[key] = true
                    rec.ships[#rec.ships + 1] = ship
                end
            end
        end
    end
end

function Fast:GetResult()
    return self.resultIndex, self.resultRouteCount, self.resultRouteIslandMap
end

function Fast:Start()
    self.scanTiming = timingSnapshot()
    self.filterTiming = nil
    self.repairTiming = nil
    self.active = false
    self.phase = "idle"
    self.buttons = {}
    self.current = 0
    self.index = {}
    self.routeCount = 0
    self.activeRouteCount = 0
    self.activeRouteIDs = {}
    self.activeRouteNames = {}
    self.routeRowsByID = {}
    self.coveredRouteIDs = {}
    self.acceptedIslands = 0
    self.baselineSignature = ""
    self.allRouteCount = 0
    self.routeIslandMap = {}
    self.resultIndex = nil
    self.resultRouteCount = 0
    self.resultRouteIslandMap = nil
    self.rejectReason = nil
    self.popupOpenedByUs = false
    self.pendingStatus = nil
    self.repairRoutes = {}
    self.repairIndex = 0
    self.repairVerifiedRouteIDs = {}

    local _, overview, filter, islandList, buttons, rows = getSceneParts()
    if overview == nil or filter == nil or islandList == nil or buttons == nil or rows == nil then
        log(
            "START REJECT | reason=filter-surface-unavailable"
            .. " | " .. timingDeltaText(self.scanTiming)
        )
        return false
    end

    for _, object in pairs(Scripts:GetObjectGroupByProperty(Properties.ShipModuleOwner) or {}) do
        local tr = object.TradeRouteVehicle
        if tr and tr.IsAssignedOnTradeRoute and tr.RouteName ~= nil then
            self.activeRouteNames[tostring(tr.RouteName)] = true
        end
    end

    local allBaselineRows = harvestActiveRouteRows(rows, nil)
    self.allRouteCount = countTable(allBaselineRows)

    local baselineRows, baselineSignature = harvestActiveRouteRows(rows, self.activeRouteNames)
    self.routeRowsByID = baselineRows
    self.baselineSignature = baselineSignature
    for routeID in pairs(baselineRows) do
        self.activeRouteIDs[routeID] = true
    end
    self.activeRouteCount = countTable(self.activeRouteIDs)

    if self.activeRouteCount < 1 then
        log(
            "START REJECT | reason=no-active-routes-visible"
            .. " | " .. timingDeltaText(self.scanTiming)
        )
        return false
    end

    local visible = false
    pcall(function() visible = filter.IsPopupVisible == true end)
    if not visible then
        local fn = nil
        pcall(function() fn = filter.FilterButtonEvent end)
        if type(fn) == "function" then
            local ok, result = pcall(function() return filter:FilterButtonEvent() end)
            self.popupOpenedByUs = ok
            log("POPUP OPEN | success=" .. tostring(ok) .. " | result=" .. tostring(result))
        end
    end

    self.active = true
    self.phase = "enumerate"
    log(
        "START"
        .. " | activeRoutes=" .. tostring(self.activeRouteCount)
        .. " | allRoutes=" .. tostring(self.allRouteCount)
        .. " | baselineSignature=" .. tostring(self.baselineSignature)
        .. " | strategy=native island filter inversion"
    )
    return true
end

function Fast:Tick()
    if not self.active then return self.pendingStatus end

    local _, overview, filter, islandList, buttons, rows = getSceneParts()
    if overview == nil or filter == nil or islandList == nil or buttons == nil or rows == nil then
        self.rejectReason = "filter-surface-lost"
        clearSelectedButtons()
        closeFilterPopupIfNeeded()
        self.phase = "restore-reject"
        return nil
    end

    if self.phase == "enumerate" then
        local size = safeArraySize(buttons, "PhoenixArray<halo::CButtonData>")
        if size < 1 then
            -- Some native list models populate one event-loop turn after opening.
            self.current = self.current + 1
            if self.current < 3 then
                log(
                    "ENUMERATE WAIT | tick=" .. tostring(self.current)
                    .. " | size=" .. tostring(size)
                    .. " | " .. timingDeltaText(self.scanTiming)
                )
                return nil
            end
            self.rejectReason = "island-buttons-empty"
            clearSelectedButtons()
            closeFilterPopupIfNeeded()
            self.phase = "restore-reject"
            return nil
        end

        self.buttons = {}
        for i = 0, size - 1 do
            local button = safeArrayElement(buttons, "PhoenixArray<halo::CButtonData>", i)
            if button ~= nil then
                local name = buttonText(button)
                if name ~= "" then
                    self.buttons[#self.buttons + 1] = {
                        arrayIndex = i,
                        button = button,
                        name = name,
                    }
                end
            end
        end

        log("ENUMERATE | nativeButtons=" .. tostring(size) .. " | namedButtons=" .. tostring(#self.buttons))
        if #self.buttons < 2 then
            self.rejectReason = "too-few-named-island-buttons"
            clearSelectedButtons()
            closeFilterPopupIfNeeded()
            self.phase = "restore-reject"
            return nil
        end

        -- Normalize any player filter state, then select the first native island
        -- in the same event-loop turn.  Only the final state needs to rebuild.
        clearSelectedButtons()
        self.current = 1
        local ok, result = pressButton(self.buttons[self.current].button)
        log(
            "SELECT"
            .. " | n=" .. tostring(self.current)
            .. " | arrayIndex=" .. tostring(self.buttons[self.current].arrayIndex)
            .. " | island=" .. tostring(self.buttons[self.current].name)
            .. " | success=" .. tostring(ok)
            .. " | result=" .. tostring(result)
        )
        self.filterTiming = timingSnapshot()
        if not ok then
            self.rejectReason = "first-filter-click-failed"
            clearSelectedButtons()
            closeFilterPopupIfNeeded()
            self.phase = "restore-reject"
            return nil
        end
        self.phase = "read"
        return nil
    end

    if self.phase == "read" then
        local currentRec = self.buttons[self.current]
        if currentRec == nil then
            self.rejectReason = "current-filter-record-missing"
            clearSelectedButtons()
            closeFilterPopupIfNeeded()
            self.phase = "restore-reject"
            return nil
        end

        local allFilteredRows = harvestActiveRouteRows(rows, nil)
        local allFilteredCount = countTable(allFilteredRows)
        if allFilteredCount > 0
            and self.allRouteCount > 0
            and allFilteredCount < self.allRouteCount
        then
            rememberFilteredRouteIslands(currentRec.name, allFilteredRows)
        end

        local filteredRows, signature = harvestActiveRouteRows(rows, self.activeRouteNames)
        local invalidRoute = nil
        for routeID in pairs(filteredRows) do
            if not self.activeRouteIDs[routeID] then
                invalidRoute = routeID
                break
            end
        end
        if invalidRoute ~= nil then
            self.rejectReason = "filtered-route-not-in-baseline:" .. tostring(invalidRoute)
            clearSelectedButtons()
            closeFilterPopupIfNeeded()
            self.phase = "restore-reject"
            return nil
        end

        local accepted, routeCount, shipCount = addIslandResult(currentRec.name, filteredRows)
        log(
            "FILTER"
            .. " | n=" .. tostring(self.current)
            .. " | island=" .. tostring(currentRec.name)
            .. " | selected=" .. tostring(buttonIsSelected(currentRec.button))
            .. " | routes=" .. tostring(routeCount)
            .. " | allRoutes=" .. tostring(allFilteredCount)
            .. " | ships=" .. tostring(shipCount)
            .. " | accepted=" .. tostring(accepted)
            .. " | signature=" .. tostring(signature)
            .. " | " .. timingDeltaText(self.filterTiming)
            .. " | total." .. timingDeltaText(self.scanTiming)
        )

        -- Turn off the current filter and turn on the next one before returning.
        -- That keeps the cost to one native rebuild per island rather than two.
        pressButton(currentRec.button)
        self.current = self.current + 1
        local nextRec = self.buttons[self.current]
        if nextRec ~= nil then
            local ok, result = pressButton(nextRec.button)
            log(
                "SELECT"
                .. " | n=" .. tostring(self.current)
                .. " | arrayIndex=" .. tostring(nextRec.arrayIndex)
                .. " | island=" .. tostring(nextRec.name)
                .. " | success=" .. tostring(ok)
                .. " | result=" .. tostring(result)
            )
            self.filterTiming = timingSnapshot()
            if not ok then
                self.rejectReason = "filter-click-failed:" .. tostring(self.current)
                clearSelectedButtons()
                closeFilterPopupIfNeeded()
                self.phase = "restore-reject"
                return nil
            end
            return nil
        end

        closeFilterPopupIfNeeded()
        log(
            "FILTER LOOP COMPLETE"
            .. " | filters=" .. tostring(#self.buttons)
            .. " | " .. timingDeltaText(self.scanTiming)
        )
        self.phase = "validate"
        return nil
    end

    if self.phase == "validate" then
        local covered = countTable(self.coveredRouteIDs)
        local indexedIslands = countTable(self.index)

        self.repairRoutes = {}

        for routeID in pairs(self.activeRouteIDs) do
            local expected = expectedStationCount(routeID)
            local discovered = discoveredMembershipCount(routeID)

            if expected > 0 and discovered < expected then
                self.repairRoutes[#self.repairRoutes + 1] = {
                    routeID = routeID,
                    expected = expected,
                    discovered = discovered,
                    route = self.routeRowsByID[routeID],
                }
            end
        end

        table.sort(self.repairRoutes, function(a, b)
            return a.routeID < b.routeID
        end)

        local baseComplete =
            covered == self.activeRouteCount
            and indexedIslands >= 2
            and self.acceptedIslands == indexedIslands

        log(
            "VALIDATE"
            .. " | activeRoutes=" .. tostring(self.activeRouteCount)
            .. " | coveredRoutes=" .. tostring(covered)
            .. " | indexedIslands=" .. tostring(indexedIslands)
            .. " | acceptedIslands=" .. tostring(self.acceptedIslands)
            .. " | deficientRoutes=" .. tostring(#self.repairRoutes)
            .. " | baseComplete=" .. tostring(baseComplete)
            .. " | " .. timingDeltaText(self.scanTiming)
        )

        if baseComplete and #self.repairRoutes == 0 then
            self.resultIndex = self.index
            self.resultRouteCount = self.activeRouteCount
            self.resultRouteIslandMap = self.routeIslandMap
            self.pendingStatus = "accepted"
            self.active = false
            self.phase = "done"

            log(
                "FAST ACCEPT"
                .. " | islands=" .. tostring(indexedIslands)
                .. " | activeRoutes=" .. tostring(self.activeRouteCount)
                .. " | rebuilds=" .. tostring(#self.buttons)
                .. " | targetedRepairs=0"
                .. " | strictStationCoverage=true"
                .. " | " .. timingDeltaText(self.scanTiming)
            )

            return "accepted"
        end

        if baseComplete and #self.repairRoutes > 0 then
            self.repairIndex = 1
            local repair = self.repairRoutes[1]
            local ok, result = focusRouteByID(repair.routeID)
            self.repairTiming = timingSnapshot()

            log(
                "REPAIR FOCUS BY ID"
                .. " | n=1"
                .. " | total=" .. tostring(#self.repairRoutes)
                .. " | routeID=" .. tostring(repair.routeID)
                .. " | routeName=" .. tostring(repair.route and repair.route.routeName)
                .. " | discovered=" .. tostring(repair.discovered)
                .. " | expected=" .. tostring(repair.expected)
                .. " | success=" .. tostring(ok)
                .. " | result=" .. tostring(result)
            )

            if ok then
                self.phase = "repair-read"
                return nil
            end
        end

        self.rejectReason =
            "coverage-or-repair-start-failed:"
            .. tostring(covered)
            .. "/"
            .. tostring(self.activeRouteCount)

        self.phase = "restore-reject"
        return nil
    end

    if self.phase == "repair-read" then
        local repair = self.repairRoutes[self.repairIndex]

        if repair == nil then
            self.rejectReason = "repair-record-missing"
            self.phase = "restore-reject"
            return nil
        end

        local size, entries = readFocusedRouteStations()

        local editRouteName = nil
        pcall(function()
            local edit = TradeRoute and TradeRoute.UIEditRoute or nil
            if edit ~= nil then
                local valid = true
                pcall(function() valid = edit:isValid() end)
                if valid then
                    editRouteName = tostring(edit.Name)
                end
            end
        end)

        local expectedRouteName =
            repair.route and tostring(repair.route.routeName) or nil

        local completeRead =
            size == repair.expected
            and #entries == repair.expected
            and editRouteName == expectedRouteName

        log(
            "REPAIR READ"
            .. " | n=" .. tostring(self.repairIndex)
            .. " | total=" .. tostring(#self.repairRoutes)
            .. " | routeID=" .. tostring(repair.routeID)
            .. " | routeName=" .. tostring(repair.route and repair.route.routeName)
            .. " | size=" .. tostring(size)
            .. " | expected=" .. tostring(repair.expected)
            .. " | editRouteName=" .. tostring(editRouteName)
            .. " | expectedRouteName=" .. tostring(expectedRouteName)
            .. " | completeRead=" .. tostring(completeRead)
            .. " | " .. timingDeltaText(self.repairTiming)
            .. " | total." .. timingDeltaText(self.scanTiming)
        )

        if not completeRead then
            self.rejectReason =
                "repair-read-incomplete:"
                .. tostring(repair.routeID)
                .. ":"
                .. tostring(size)
                .. "/"
                .. tostring(repair.expected)

            self.phase = "restore-reject"
            return nil
        end

        mergeRouteStations(repair.route, entries)
        -- Route topology records distinct island membership, while the native
        -- station collection records every stop. A route may legitimately stop
        -- at the same island more than once. Once the focused read returned the
        -- exact native station count for the expected route, its topology is
        -- complete even when the distinct-island count is smaller.
        self.repairVerifiedRouteIDs[repair.routeID] = true

        self.repairIndex = self.repairIndex + 1
        local nextRepair = self.repairRoutes[self.repairIndex]

        if nextRepair ~= nil then
            local ok, result = focusRouteByID(nextRepair.routeID)
            self.repairTiming = timingSnapshot()

            log(
                "REPAIR NEXT BY ID"
                .. " | n=" .. tostring(self.repairIndex)
                .. " | total=" .. tostring(#self.repairRoutes)
                .. " | routeID=" .. tostring(nextRepair.routeID)
                .. " | routeName=" .. tostring(nextRepair.route and nextRepair.route.routeName)
                .. " | success=" .. tostring(ok)
                .. " | result=" .. tostring(result)
            )

            if not ok then
                self.rejectReason =
                    "repair-focus-failed:"
                    .. tostring(nextRepair.routeID)
                self.phase = "restore-reject"
            end

            return nil
        end

        local remaining = 0

        for routeID in pairs(self.activeRouteIDs) do
            local expected = expectedStationCount(routeID)
            local discovered = discoveredMembershipCount(routeID)

            if expected > 0
                and discovered < expected
                and not self.repairVerifiedRouteIDs[routeID]
            then
                remaining = remaining + 1
            end
        end

        if remaining == 0 then
            self.resultIndex = self.index
            self.resultRouteCount = self.activeRouteCount
            self.resultRouteIslandMap = self.routeIslandMap
            self.pendingStatus = "accepted"
            self.active = false
            self.phase = "done"

            log(
                "FAST ACCEPT"
                .. " | islands=" .. tostring(countTable(self.index))
                .. " | activeRoutes=" .. tostring(self.activeRouteCount)
                .. " | rebuilds=" .. tostring(#self.buttons)
                .. " | targetedRepairs=" .. tostring(#self.repairRoutes)
                .. " | topologyRoutes=" .. tostring(countTable(self.routeIslandMap))
                .. " | strictStationCoverage=true"
                .. " | " .. timingDeltaText(self.scanTiming)
            )

            return "accepted"
        end

        self.rejectReason =
            "post-repair-station-coverage-mismatch:"
            .. tostring(remaining)

        self.phase = "restore-reject"
        return nil
    end

    if self.phase == "restore-reject" then
        -- One full UI turn after clearing filters ensures the proven sequential
        -- fallback sees the normal unfiltered route list rather than stale rows.
        self.pendingStatus = "rejected"
        self.active = false
        self.phase = "done"
        log(
            "FAST REJECT | reason=" .. tostring(self.rejectReason)
            .. " | fallback=proven sequential scan"
            .. " | " .. timingDeltaText(self.scanTiming)
        )
        return "rejected"
    end

    return nil
end

return Fast
