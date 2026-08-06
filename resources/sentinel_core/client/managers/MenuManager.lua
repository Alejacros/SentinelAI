local menuVisible = false

local function drawText(text, x, y, scale)
    SetTextFont(4)
    SetTextScale(scale, scale)
    SetTextColour(255, 255, 255, 255)
    SetTextCentre(true)
    SetTextOutline()

    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

local function startDuty()
    PlayerData.OnDuty = true
    PlayerData.DispatchState = "WAITING"

    AssignRandomUnit()
    SpawnPoliceVehicle()
    ClearPlayerWantedLevel(PlayerId())
    SetPlayerWantedLevel(PlayerId(), 0, false)
    SetPlayerWantedLevelNow(PlayerId(), false)

    Sentinel.Notify(
        "CENTRAL",
        "Unidad " .. PlayerData.Unit .. " asignada. Permanezca atento.",
        {0, 255, 120}
    )
end

local function stopDuty()
    PlayerData.OnDuty = false
    PlayerData.DispatchState = "OFF_DUTY"
    PlayerData.Unit = nil

    Sentinel.Notify(
        "CENTRAL",
        "Patrulla finalizada.",
        {255, 180, 0}
    )
end

CreateThread(function()
    while true do
        Wait(0)

        if IsControlJustPressed(0, 288) then -- F1
            menuVisible = not menuVisible
        end

        if menuVisible then
            DrawRect(0.5, 0.35, 0.30, 0.28, 0, 0, 0, 190)

            drawText("SENTINEL AI", 0.5, 0.245, 0.55)

            if PlayerData.OnDuty then
                drawText("ESTADO: EN SERVICIO", 0.5, 0.315, 0.38)
                drawText("[E] Finalizar patrulla", 0.5, 0.375, 0.34)
            else
                drawText("ESTADO: FUERA DE SERVICIO", 0.5, 0.315, 0.38)
                drawText("[E] Iniciar patrulla", 0.5, 0.375, 0.34)
            end

            drawText("[ESC] Cerrar", 0.5, 0.425, 0.30)

            if IsControlJustPressed(0, 38) then -- E
                if PlayerData.OnDuty then
                    stopDuty()
                else
                    startDuty()
                end
            end

            if IsControlJustPressed(0, 322) then -- ESC
                menuVisible = false
            end
        end
    end
end)