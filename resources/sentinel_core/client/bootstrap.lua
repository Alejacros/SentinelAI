Sentinel = {
    Name = "Sentinel AI",
    Version = "0.2.0-prealpha",
    Ready = false
}

function Sentinel.Notify(title, message, color)
    TriggerEvent("chat:addMessage", {
        color = color or {0, 170, 255},
        multiline = true,
        args = {
            title or Sentinel.Name,
            message
        }
    })
end

CreateThread(function()
    Wait(2000)

    Sentinel.Ready = true

    print(("[%s] Cliente iniciado - versión %s"):format(
        Sentinel.Name,
        Sentinel.Version
    ))

    Sentinel.Notify(
        Sentinel.Name,
        "Sistema listo. Pulsa F1 para abrir Sentinel."
    )
end)

CreateThread(function()
    while true do
        Wait(1000)

        if PlayerData and PlayerData.OnDuty then
            ClearPlayerWantedLevel(PlayerId())
            SetPlayerWantedLevel(PlayerId(), 0, false)
            SetPlayerWantedLevelNow(PlayerId(), false)
        end
    end
end)