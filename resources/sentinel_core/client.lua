CreateThread(function()

    Wait(3000)

    TriggerEvent('chat:addMessage', {
        color = {0, 170, 255},
        args = {
            "Sentinel AI",
            "Bienvenida. Sentinel AI está listo."
        }
    })

    while true do

        Wait(0)

        if IsControlJustPressed(0, 288) then -- F1

            TriggerEvent('chat:addMessage', {
                color = {255, 255, 0},
                args = {
                    "Sentinel AI",
                    "Has pulsado F1."
                }
            })

        end

    end

end)