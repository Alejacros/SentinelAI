local dispatchDelay = 15000
local nextDispatchAt = nil

local function removeDispatchBlip()
    if PlayerData.DispatchBlip
        and DoesBlipExist(PlayerData.DispatchBlip) then

        RemoveBlip(PlayerData.DispatchBlip)
    end

    PlayerData.DispatchBlip = nil
    SetWaypointOff()
end

local function resetDispatch()
    removeDispatchBlip()

    PlayerData.CurrentDispatch = nil
    nextDispatchAt = nil
end

local function sendRandomDispatch()
    if not Dispatches or #Dispatches == 0 then
        Sentinel.Notify(
            "ERROR",
            "No hay incidentes configurados.",
            {255, 80, 80}
        )

        return
    end

    local selectedDispatch =
        Dispatches[math.random(#Dispatches)]

    PlayerData.CurrentDispatch = selectedDispatch
    PlayerData.DispatchState = "PENDING"

    Sentinel.Notify(
        "CENTRAL",
        (
            "Código %s - %s\nPulsa Y para aceptar."
        ):format(
            selectedDispatch.code,
            selectedDispatch.title
        ),
        {255, 80, 80}
    )
end

local function acceptDispatch()
    local incident = PlayerData.CurrentDispatch

    if not incident then
        Sentinel.Notify(
            "ERROR",
            "No existe un despacho para aceptar.",
            {255, 80, 80}
        )

        return
    end

    -- Aquí se crea oficialmente el caso.
    local caseCreated = CreateCurrentCase(incident)

    if not caseCreated then
        Sentinel.Notify(
            "ERROR",
            "No fue posible crear el expediente del caso.",
            {255, 80, 80}
        )

        return
    end

    PlayerData.DispatchState = "EN_ROUTE"

    local blip = AddBlipForCoord(
        incident.location.x,
        incident.location.y,
        incident.location.z
    )

    SetBlipSprite(blip, 280)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 0.9)
    SetBlipRoute(blip, true)
    SetBlipRouteColour(blip, 1)

    BeginTextCommandSetBlipName("STRING")

    AddTextComponentString(
        ("Código %s - %s"):format(
            incident.code,
            incident.title
        )
    )

    EndTextCommandSetBlipName(blip)

    PlayerData.DispatchBlip = blip

    SetNewWaypoint(
        incident.location.x,
        incident.location.y
    )

    Sentinel.Notify(
        "CENTRAL",
        "Caso creado. GPS actualizado. Diríjase al incidente.",
        {0, 255, 120}
    )

    local currentCase = GetCurrentCase()

    if currentCase then
        print(
            (
                "[Sentinel AI] Expediente #%04d activo: Código %s - %s"
            ):format(
                currentCase.id,
                currentCase.code,
                currentCase.title
            )
        )
    end
end

function CompleteCurrentDispatch()
    if PlayerData.DispatchState ~= "REPORT" then
        return false
    end

    resetDispatch()

    if PlayerData.OnDuty then
        PlayerData.DispatchState = "WAITING"
        nextDispatchAt = GetGameTimer() + dispatchDelay

        Sentinel.Notify(
            "CENTRAL",
            "Informe recibido. Disponible para otro despacho.",
            {0, 255, 120}
        )
    else
        PlayerData.DispatchState = "OFF_DUTY"
    end

    return true
end

CreateThread(function()
    while true do
        Wait(250)

        if PlayerData.DispatchState == "OFF_DUTY" then
            resetDispatch()

            if GetCurrentCase() then
                CancelCurrentCase()
            end

        elseif PlayerData.DispatchState == "WAITING" then
            if not nextDispatchAt then
                nextDispatchAt =
                    GetGameTimer() + dispatchDelay
            end

            if GetGameTimer() >= nextDispatchAt then
                nextDispatchAt = nil
                sendRandomDispatch()
            end
        else
            nextDispatchAt = nil
        end
    end
end)

CreateThread(function()
    while true do
        Wait(0)

        if PlayerData.DispatchState == "PENDING"
            and IsControlJustPressed(0, 246) then -- Y

            acceptDispatch()
        end
    end
end)

CreateThread(function()
    while true do
        Wait(500)

        if PlayerData.DispatchState == "EN_ROUTE"
            and PlayerData.CurrentDispatch then

            local playerCoords =
                GetEntityCoords(PlayerPedId())

            local incidentCoords =
                PlayerData.CurrentDispatch.location

            local distance =
                #(playerCoords - incidentCoords)

            if distance <= 20.0 then
                removeDispatchBlip()

                PlayerData.DispatchState = "ON_SCENE"

                Sentinel.Notify(
                    "CENTRAL",
                    "Unidad en escena. Investigue el incidente.",
                    {0, 255, 0}
                )

                SpawnCrimeScene(
                    PlayerData.CurrentDispatch
                )
            end
        end
    end
end)