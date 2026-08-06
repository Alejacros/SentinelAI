CreateThread(function()

    Wait(3000)

    TriggerEvent('chat:addMessage', {
        color = {0, 170, 255},
        multiline = true,
        args = {
            "Sentinel AI",
            "Bienvenida. Sentinel AI está listo."
        }
    })

end)