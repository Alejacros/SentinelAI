local function drawHudText(text, x, y, scale)
    SetTextFont(4)
    SetTextScale(scale, scale)
    SetTextColour(255, 255, 255, 255)
    SetTextOutline()

    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

local function getDispatchLabel()
    local labels = {
        OFF_DUTY = "Fuera de servicio",
        WAITING = "Esperando despacho",
        PENDING = "Despacho pendiente",
        EN_ROUTE = "En ruta",
        ON_SCENE = "En escena",
        EVIDENCE = "Buscando evidencia",
        REPORT = "Procesando informe"
    }

    return labels[PlayerData.DispatchState] or "Sin estado"
end

CreateThread(function()
    while true do
        local sleep = 500

        if PlayerData.OnDuty then
            sleep = 0

            DrawRect(
                0.875,
                0.17,
                0.22,
                0.22,
                0,
                0,
                0,
                180
            )

            drawHudText(
                "SENTINEL AI",
                0.775,
                0.075,
                0.38
            )

            drawHudText(
                "Rango: " .. PlayerData.Rank,
                0.775,
                0.115,
                0.29
            )

            drawHudText(
                "XP: " .. PlayerData.XP,
                0.775,
                0.145,
                0.29
            )

            drawHudText(
                "Casos: " .. PlayerData.CompletedCases,
                0.775,
                0.175,
                0.29
            )

            drawHudText(
                "Unidad: " .. (PlayerData.Unit or "Sin asignar"),
                0.775,
                0.205,
                0.29
            )

            drawHudText(
                "Estado: " .. getDispatchLabel(),
                0.775,
                0.235,
                0.29
            )
        end

        Wait(sleep)
    end
end)