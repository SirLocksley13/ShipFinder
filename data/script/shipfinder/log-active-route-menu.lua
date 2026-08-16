local rows = 0
local arr = ui
    and ui.Scenes
    and ui.Scenes.TradeRoute
    and ui.Scenes.TradeRoute.TradeOverview
    and ui.Scenes.TradeRoute.TradeOverview.OverviewListData
    and ui.Scenes.TradeRoute.TradeOverview.OverviewListData.ArrayData
    or nil

if arr then
    for i = 0, 511 do
        local row = arr[i]
        if row ~= nil then
            rows = rows + 1
        end
    end
end

system.log(
    "[Ship Finder Active Routes 1.1.0] opening native route-group menu"
    .. " | nativeOverviewRows=" .. tostring(rows)
)
