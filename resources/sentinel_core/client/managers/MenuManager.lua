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
    TriggerServerEvent("sentinel:server:dispatch:setDuty", true, PlayerData.Unit)
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
    TriggerServerEvent("sentinel:server:dispatch:setDuty", false)

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
