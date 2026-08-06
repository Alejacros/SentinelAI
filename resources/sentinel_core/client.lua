local menuVisible = false

CreateThread(function()

    Wait(3000)

    TriggerEvent('chat:addMessage', {
        color = {0,170,255},
        args = {
            "Sentinel AI",
            "Bienvenida. Pulsa F1 para abrir Sentinel."
        }
    })

    while true do

        Wait(0)

        if IsControlJustPressed(0,288) then
            menuVisible = not menuVisible
        end

        if menuVisible then

            DrawRect(
                0.5,
                0.35,
                0.30,
                0.25,
                0,
                0,
                0,
                180
            )

            SetTextFont(4)
            SetTextScale(0.55,0.55)
            SetTextColour(255,255,255,255)
            SetTextCentre(true)

            BeginTextCommandDisplayText("STRING")
            AddTextComponentSubstringPlayerName("SENTINEL AI")
            EndTextCommandDisplayText(0.5,0.25)

        end

    end

end)