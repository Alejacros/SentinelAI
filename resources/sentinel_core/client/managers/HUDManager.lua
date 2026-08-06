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
        TRANSPORT = "Trasladando detenido",
        REPORT = "Procesando informe"
    }

    return labels[PlayerData.DispatchState] or "Sin estado"
end

local function shouldShowHud()
    if not PlayerData then
        return false
    end

    if PlayerData.OnDuty then
        return true
    end

    return PlayerData.DispatchState
        and PlayerData.DispatchState ~= "OFF_DUTY"
end

CreateThread(function()
    while true do
        local sleep = 500

        if shouldShowHud() then
            sleep = 0

            DrawRect(
                0.875,
                0.17,
                0.22,
                0.22,
                0,
                0,
                0,
                190
            )

            drawHudText(
                "SENTINEL AI",
                0.775,
                0.075,
                0.38
            )

            drawHudText(
                "Rango: " .. (PlayerData.Rank or "Cadete"),
                0.775,
                0.115,
                0.29
            )

            drawHudText(
                "XP: " .. tostring(PlayerData.XP or 0),
                0.775,
                0.145,
                0.29
            )

            drawHudText(
                "Casos: "
                    .. tostring(PlayerData.CompletedCases or 0),
                0.775,
                0.175,
                0.29
            )

            drawHudText(
                "Unidad: "
                    .. (PlayerData.Unit or "Sin asignar"),
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