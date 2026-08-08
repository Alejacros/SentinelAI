MDTManager = {
    Opened = false,
    Focused = false,
    Mode = "PDA"
}

function MDTManager.SetFocus(enabled)
    MDTManager.Focused = enabled == true
    SetNuiFocus(MDTManager.Focused, MDTManager.Focused)
end

function MDTManager.IsOpen()
    return MDTManager.Opened == true
end

function MDTManager.Open(mode, snapshot)
    MDTManager.Opened = true
    MDTManager.Mode = mode or "PDA"
    MDTManager.SetFocus(MDTManager.Mode ~= "DRIVER_SAFE")

    SendNUIMessage({
        action = "terminal:open",
        mode = MDTManager.Mode,
        data = snapshot or {}
    })

    return true
end

function MDTManager.Update(domain, data)
    if not MDTManager.Opened then
        return false
    end

    if domain == "mode" or domain == "context" then
        SendNUIMessage({
            action = "terminal:mode",
            data = data or {}
        })

        if data and data.modules then
            SendNUIMessage({
                action = "terminal:modules",
                data = data.modules
            })
        end
    elseif domain == "alerts" then
        SendNUIMessage({
            action = "terminal:alert",
            data = data or {}
        })
    else
        SendNUIMessage({
            action = "terminal:update",
            domain = domain,
            data = data or {}
        })
    end

    return true
end

function MDTManager.Close()
    if not MDTManager.Opened then
        return false
    end

    MDTManager.Opened = false
    MDTManager.SetFocus(false)

    SendNUIMessage({action = "terminal:close"})
    return true
end

RegisterCommand("sentinel_tablet", function()
    if IsControlPressed(0, 21) then
        WidgetLayoutManager.ToggleEditor()
        return
    end

    if not WidgetLayoutManager.IsEditing() then
        PoliceTerminalManager.Toggle()
    end
end, false)

RegisterKeyMapping(
    "sentinel_tablet",
    "Abrir Sentinel Police Terminal",
    "keyboard",
    "F7"
)

RegisterNUICallback("closeMdt", function(_, callback)
    PoliceTerminalManager.Close()
    callback({ok = true})
end)

RegisterNUICallback("requestMdtData", function(_, callback)
    callback(PoliceTerminalManager.GetSnapshot())
end)

RegisterNUICallback("terminal:openModule", function(data, callback)
    local ok, reason = PoliceTerminalManager.OpenModule(
        data and data.moduleId
    )

    callback({ok = ok == true, error = reason})
end)

RegisterNUICallback("terminal:action", function(data, callback)
    local ok, reason = PoliceTerminalManager.ExecuteAction(
        data and data.actionId,
        data and data.payload
    )

    callback({ok = ok == true, error = reason})
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        MDTManager.Opened = false
        MDTManager.SetFocus(false)
    end
end)
