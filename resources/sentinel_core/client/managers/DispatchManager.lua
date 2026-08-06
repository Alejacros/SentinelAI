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
    CleanupCrimeScene()

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

    PlayerData.CurrentDispatch =
        Dispatches[math.random(#Dispatches)]

    PlayerData.DispatchState = "PENDING"

    local incident = PlayerData.CurrentDispatch

    Sentinel.Notify(
        "📻 CENTRAL",
        ("Código %s - %s\nPulsa Y para aceptar."):format(
            incident.code,
            incident.title
        ),
        {255, 80, 80}
    )
end

local function acceptDispatch()
    local incident = PlayerData.CurrentDispatch

    if not incident then
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
        "GPS actualizado. Diríjase al incidente.",
        {0, 255, 120}
    )
end

function CompleteCurrentDispatch()
    if PlayerData.DispatchState ~= "REPORT" then
        return
    end

    resetDispatch()

    if PlayerData.OnDuty then
        PlayerData.DispatchState = "WAITING"
        nextDispatchAt = GetGameTimer() + dispatchDelay

        Sentinel.Notify(
            "CENTRAL",
            "Informe recibido. Queda disponible para otro despacho.",
            {0, 255, 120}
        )
    else
        PlayerData.DispatchState = "OFF_DUTY"
    end
end

CreateThread(function()
    while true do
        Wait(250)

        if PlayerData.DispatchState == "OFF_DUTY" then
            resetDispatch()
        elseif PlayerData.DispatchState == "WAITING" then
            if not nextDispatchAt then
                nextDispatchAt = GetGameTimer() + dispatchDelay
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