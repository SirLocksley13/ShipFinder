local gi = Variables:GetVariable("S3G") or 1
local rp = Variables:GetVariable("S3RP") or 0
local rs = Variables:GetVariable("S3RS") or 1

local states = nil
local notification = nil
local lookupOk, lookupErr = pcall(function()
    local scene = ui and ui.Scenes and ui.Scenes.GovernorRequests or nil
    local data = scene and scene.SceneData or nil
    notification = data and data.Notification and data.Notification[0] or nil
    states = notification and notification.ButtonData and notification.ButtonData.States or nil
end)

if not lookupOk or states == nil then
    system.log("[Ship Finder Multi Route 1.1.0] FINAL NO REQUEST"
        .." | groupSlot="..tostring(gi)
        .." | routePage="..tostring(rp)
        .." | routeSlot="..tostring(rs)
        .." | lookupSuccess="..tostring(lookupOk)
        .." | notificationPresent="..tostring(notification ~= nil)
        .." | statesPresent="..tostring(states ~= nil)
        .." | error="..tostring(lookupErr or "")
        .." | action=end-without-ui-change")
    return
end

local focusOk, focusErr = pcall(function()
    return states:RequestFocus()
end)

local closeOk, closeErr = pcall(function()
    Scripts:PopUI()
end)

local primaryOk, primaryErr = pcall(function()
    return states:EventPrimary()
end)

system.log("[Ship Finder Multi Route 1.1.0] OPEN"
    .." | groupSlot="..tostring(gi)
    .." | routePage="..tostring(rp)
    .." | routeSlot="..tostring(rs)
    .." | focusSuccess="..tostring(focusOk)
    .." | closeSuccess="..tostring(closeOk)
    .." | primarySuccess="..tostring(primaryOk)
    .." | focusError="..tostring(focusErr or "")
    .." | closeError="..tostring(closeErr or "")
    .." | primaryError="..tostring(primaryErr or ""))
