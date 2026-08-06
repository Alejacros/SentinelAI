CreateThread(function()

    Wait(3000)

    TriggerEvent("chat:addMessage", {
        color = {0,170,255},
        args = {
            "Sentinel AI",
            "Bienvenida. Pulsa F1 para abrir Sentinel."
        }
    })

end)