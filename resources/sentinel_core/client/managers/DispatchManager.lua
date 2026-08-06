local dispatchMessage = false

CreateThread(function()

    while true do

        Wait(1000)

        if PlayerData.OnDuty and not PlayerData.DispatchActive then

            Wait(15000)

            if PlayerData.OnDuty and not PlayerData.DispatchActive then

                dispatchMessage = true

                TriggerEvent("chat:addMessage",{

                    color={255,80,80},

                    args={

                        "📻 CENTRAL",

                        "Código 211. Posible robo en Strawberry. Pulsa Y para aceptar."

                    }

                })

            end

        end

    end

end)

CreateThread(function()

    while true do

        Wait(0)

        if dispatchMessage then

            if IsControlJustPressed(0,246) then -- Y

                dispatchMessage = false

                PlayerData.DispatchActive = true

                SetNewWaypoint(
                    Config.Dispatch.Location.x,
                    Config.Dispatch.Location.y
                )

                TriggerEvent("chat:addMessage",{

                    color={0,255,120},

                    args={

                        "CENTRAL",

                        "GPS actualizado. Diríjase al incidente."

                    }

                })

            end

        end

    end

end)