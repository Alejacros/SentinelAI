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
    local character = PlayerData.Character
    local appearance = type(character) == "table"
        and character.appearance
        or nil
    local bodyModel = type(appearance) == "table"
        and appearance.bodyModel
        or nil
    local modelUniforms = bodyModel
        and PoliceUniforms[bodyModel]
        or nil
    local dutyOutfit = modelUniforms
        and modelUniforms.PATROL
        or nil

    if not dutyOutfit then
        Sentinel.Notify(
            "ERROR",
            "No existe un uniforme PATROL para esta base corporal.",
            {255, 80, 80}
        )

        return false
    end

    local civilianOutfit =
        AppearanceManager.CaptureOutfit()

    if not civilianOutfit then
        Sentinel.Notify(
            "ERROR",
            "No fue posible capturar la ropa civil.",
            {255, 80, 80}
        )

        return false
    end

    PlayerData.CivilianOutfit = civilianOutfit

    if not AppearanceManager.ApplyOutfit(dutyOutfit) then
        AppearanceManager.ApplyOutfit(civilianOutfit)
        PlayerData.DutyOutfit = nil

        Sentinel.Notify(
            "ERROR",
            "No fue posible aplicar el uniforme policial.",
            {255, 80, 80}
        )

        return false
    end

    PlayerData.DutyOutfit = dutyOutfit
    PlayerData.OnDuty = true
    PlayerData.DispatchState = "WAITING"

    AssignRandomUnit()
    ClearPlayerWantedLevel(PlayerId())
    SetPlayerWantedLevel(PlayerId(), 0, false)
    SetPlayerWantedLevelNow(PlayerId(), false)

    Sentinel.Notify(
        "CENTRAL",
        "Unidad " .. PlayerData.Unit .. " asignada. Permanezca atento.",
        {0, 255, 120}
    )

    return true
end

local function stopDuty()
    if VehicleManager.HasActivePoliceVehicle() then
        Sentinel.Notify(
            "CENTRAL",
            "Devuelve la unidad antes de finalizar el turno.",
            {255, 180, 0}
        )

        return false
    end

    local civilianOutfit = PlayerData.CivilianOutfit

    if type(civilianOutfit) ~= "table" then
        local character = PlayerData.Character
        local appearance = type(character) == "table"
            and character.appearance
            or nil
        local appearanceData = type(appearance) == "table"
            and appearance.data
            or nil

        if type(appearanceData) == "table" then
            civilianOutfit = {
                components = appearanceData.components,
                props = appearanceData.props
            }
        end
    end

    if type(civilianOutfit) ~= "table"
        or not AppearanceManager.ApplyOutfit(
            civilianOutfit
        ) then

        Sentinel.Notify(
            "ERROR",
            "No fue posible restaurar la ropa civil.",
            {255, 80, 80}
        )

        return false
    end

    PlayerData.CivilianOutfit = civilianOutfit
    PlayerData.DutyOutfit = nil
    PlayerData.OnDuty = false
    PlayerData.DispatchState = "OFF_DUTY"
    PlayerData.Unit = nil

    Sentinel.Notify(
        "CENTRAL",
        "Patrulla finalizada.",
        {255, 180, 0}
    )

    return true
end

MenuManager = MenuManager or {}

function MenuManager.StartDuty()
    return startDuty()
end

function MenuManager.StopDuty()
    return stopDuty()
end

CreateThread(function()
    while true do
        Wait(0)

        -- TODO: retirar F1 cuando el flujo de turno en Police OS
        -- quede validado como interfaz principal.
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
