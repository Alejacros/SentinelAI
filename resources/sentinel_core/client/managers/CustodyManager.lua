CustodySystem = {
    Active = false,
    Escorting = false,
    Suspect = nil,
    Vehicle = nil,
    StationBlip = nil
}

local stationLocation = vector3(
    441.20,
    -981.90,
    30.70
)

local function notify(message, color)
    Sentinel.Notify(
        "CUSTODIA",
        message,
        color or {90, 190, 255}
    )
end

local function showHelp(message)
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

local function removeStationBlip()
    if CustodySystem.StationBlip
        and DoesBlipExist(CustodySystem.StationBlip) then

        RemoveBlip(CustodySystem.StationBlip)
    end

    CustodySystem.StationBlip = nil
    SetWaypointOff()
end

local function createStationRoute()
    removeStationBlip()

    local blip = AddBlipForCoord(
        stationLocation.x,
        stationLocation.y,
        stationLocation.z
    )

    SetBlipSprite(blip, 60)
    SetBlipColour(blip, 3)
    SetBlipScale(blip, 0.9)
    SetBlipRoute(blip, true)
    SetBlipRouteColour(blip, 3)

    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Entrega de detenido")
    EndTextCommandSetBlipName(blip)

    CustodySystem.StationBlip = blip

    SetNewWaypoint(
        stationLocation.x,
        stationLocation.y
    )
end

local function makeSuspectFollow()
    local suspect = CustodySystem.Suspect

    if not suspect
        or not DoesEntityExist(suspect) then

        return false
    end

    FreezeEntityPosition(suspect, false)
    ClearPedTasksImmediately(suspect)

    SetEnableHandcuffs(suspect, true)
    SetBlockingOfNonTemporaryEvents(suspect, true)
    SetPedCanRagdoll(suspect, false)
    SetEntityInvincible(suspect, true)

    TaskFollowToOffsetOfEntity(
        suspect,
        PlayerPedId(),
        0.0,
        -1.2,
        0.0,
        1.3,
        -1,
        1.2,
        true
    )

    CustodySystem.Escorting = true

    notify(
        "El detenido lo seguirá. Acérquelo a la patrulla."
    )

    return true
end

local function placeSuspectInVehicle()
    local suspect = CustodySystem.Suspect
    local playerPed = PlayerPedId()

    if not suspect
        or not DoesEntityExist(suspect) then

        return false
    end

    local vehicle = GetVehiclePedIsIn(
        playerPed,
        false
    )

    if vehicle == 0 then
        notify(
            "Suba a la patrulla antes de ingresar al detenido.",
            {255, 180, 0}
        )

        return false
    end

    local distance = #(
        GetEntityCoords(playerPed)
        - GetEntityCoords(suspect)
    )

    if distance > 10.0 then
        notify(
            "El detenido está demasiado lejos.",
            {255, 180, 0}
        )

        return false
    end

    ClearPedTasksImmediately(suspect)

    local seat = 2

    if not IsVehicleSeatFree(vehicle, seat) then
        seat = 1
    end

    if not IsVehicleSeatFree(vehicle, seat) then
        notify(
            "No hay un asiento disponible en la patrulla.",
            {255, 80, 80}
        )

        makeSuspectFollow()
        return false
    end

    SetPedIntoVehicle(
        suspect,
        vehicle,
        seat
    )

    CustodySystem.Vehicle = vehicle
    CustodySystem.Escorting = false

    createStationRoute()

    notify(
        "Detenido asegurado. Trasládelo a la comisaría.",
        {80, 220, 140}
    )

    return true
end

local function completeCustody()
    if not CustodySystem.Active then
        return
    end

    local suspect = CustodySystem.Suspect

    if suspect and DoesEntityExist(suspect) then
        ClearPedTasksImmediately(suspect)
        FreezeEntityPosition(suspect, false)

        SetEntityAsMissionEntity(
            suspect,
            true,
            true
        )

        DeleteEntity(suspect)
    end

    removeStationBlip()

    AddCustodyOutcomeToCurrentCase(
        "DELIVERED"
    )

    local earnedXP = 40

    PlayerData.DispatchState = "REPORT"

    if CompleteCase(earnedXP) then
        AwardXP(earnedXP)
    end

    CleanupCrimeScene()
    CompleteCurrentDispatch()

    CustodySystem.Active = false
    CustodySystem.Escorting = false
    CustodySystem.Suspect = nil
    CustodySystem.Vehicle = nil

    notify(
        "Detenido entregado. Caso cerrado.",
        {80, 220, 140}
    )
end

function StartCustodyTransport()
    if CustodySystem.Active then
        return false
    end

    local suspect =
        GetActiveSuspect()

    if not suspect
        or not DoesEntityExist(suspect)
        or not IsSuspectArrested() then

        return false
    end

    local playerCoords =
        GetEntityCoords(PlayerPedId())

    -- Si terminó arrestado en un techo, patio cerrado
    -- o desnivel extraño, lo llevamos cerca de la agente.
    if SpawnPointManager
        and SpawnPointManager.IsPedAccessible
        and not SpawnPointManager.IsPedAccessible(
            suspect,
            playerCoords
        ) then

        Sentinel.Notify(
            "CUSTODIA",
            "Reubicando al detenido en una zona accesible.",
            {255, 180, 0}
        )

        SpawnPointManager.RescuePed(
            suspect,
            playerCoords
        )

        Wait(250)
    end

    CustodySystem.Active = true
    CustodySystem.Suspect = suspect

    PlayerData.DispatchState =
        "TRANSPORT"

    makeSuspectFollow()

    return true
end

function IsCustodyTransportActive()
    return CustodySystem.Active
end

CreateThread(function()
    while true do
        local sleep = 500

        if CustodySystem.Active
            and CustodySystem.Suspect
            and DoesEntityExist(CustodySystem.Suspect) then

            sleep = 0

            local playerPed = PlayerPedId()
            local suspect = CustodySystem.Suspect

            local playerCoords =
                GetEntityCoords(playerPed)

            local suspectCoords =
                GetEntityCoords(suspect)

            local suspectDistance =
                #(playerCoords - suspectCoords)

            local vehicle =
                GetVehiclePedIsIn(playerPed, false)

            if CustodySystem.Escorting then
                if vehicle ~= 0
                    and suspectDistance <= 10.0 then

                    showHelp(
                        "Pulsa ~INPUT_CONTEXT~ para subir al detenido a la patrulla."
                    )

                    if IsControlJustPressed(0, 38) then
                        placeSuspectInVehicle()
                    end

                elseif suspectDistance <= 3.0 then
                    showHelp(
                        "El detenido lo está siguiendo. Suba a la patrulla."
                    )
                end
            end

            local stationDistance = #(
                playerCoords - stationLocation
            )

            if stationDistance <= 18.0
                and not CustodySystem.Escorting then

                showHelp(
                    "Pulsa ~INPUT_CONTEXT~ para entregar al detenido."
                )

                if IsControlJustPressed(0, 38) then
                    completeCustody()
                end
            end
        end

        Wait(sleep)
    end
end)

AddEventHandler(
    "onResourceStop",
    function(resourceName)
        if resourceName
            ~= GetCurrentResourceName() then

            return
        end

        removeStationBlip()
    end
)
