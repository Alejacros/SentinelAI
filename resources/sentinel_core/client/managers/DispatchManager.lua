local dispatchDelay = 15000
local nextDispatchAt = nil

local lastDispatchIndex = nil
local lastLocationByType = {}

local scenePrepared = false
local sceneSpawned = false

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

    scenePrepared = false
    sceneSpawned = false

    if SceneBuilder then
        SceneBuilder.Reset()
    end
end

local function selectDifferentIndex(count, previousIndex)
    if count <= 1 then
        return 1
    end

    local selectedIndex

    repeat
        selectedIndex = math.random(1, count)
    until selectedIndex ~= previousIndex

    return selectedIndex
end

local function buildDispatchInstance(definition)
    if type(definition) ~= "table" then
        return nil
    end

    local locations = definition.locations

    if type(locations) ~= "table"
        or #locations == 0 then

        if definition.location then
            return {
                code = definition.code,
                type = definition.type,
                title = definition.title,
                location = definition.location,
                locationIndex = 1
            }
        end

        return nil
    end

    local previousLocation =
        lastLocationByType[definition.type]

    local locationIndex =
        selectDifferentIndex(
            #locations,
            previousLocation
        )

    lastLocationByType[definition.type] =
        locationIndex

    return {
        code = definition.code or "000",
        type = definition.type or "GENERIC",
        title = definition.title
            or "Incidente sin identificar",

        location = locations[locationIndex],
        locationIndex = locationIndex
    }
end

local function selectRandomDispatch()
    if type(Dispatches) ~= "table"
        or #Dispatches == 0 then

        return nil
    end

    local dispatchIndex =
        selectDifferentIndex(
            #Dispatches,
            lastDispatchIndex
        )

    lastDispatchIndex = dispatchIndex

    return buildDispatchInstance(
        Dispatches[dispatchIndex]
    )
end

local function sendRandomDispatch()
    local selectedDispatch =
        selectRandomDispatch()

    if not selectedDispatch then
        Sentinel.Notify(
            "ERROR",
            "No hay incidentes válidos configurados.",
            {255, 80, 80}
        )

        PlayerData.DispatchState = "WAITING"

        nextDispatchAt =
            GetGameTimer() + dispatchDelay

        return false
    end

    PlayerData.CurrentDispatch =
        selectedDispatch

    PlayerData.DispatchState =
        "PENDING"

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

    return true
end

local function createDispatchBlip(incident)
    local blip = AddBlipForCoord(
        incident.location.x,
        incident.location.y,
        incident.location.z
    )

    SetBlipSprite(blip, 280)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 0.9)
    SetBlipAsShortRange(blip, false)
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
end

local function prepareScene(incident)
    CreateThread(function()
        local layout =
            SceneBuilder.Build(incident)

        scenePrepared = layout ~= nil

        if scenePrepared then
            Sentinel.Notify(
                "CENTRAL",
                "Escena validada. Unidades continúan en ruta.",
                {90, 190, 255}
            )
        end
    end)
end

local function acceptDispatch()
    local incident =
        PlayerData.CurrentDispatch

    if not incident
        or not incident.location then

        return false
    end

    if not CreateCurrentCase(incident) then
        Sentinel.Notify(
            "ERROR",
            "No fue posible crear el expediente.",
            {255, 80, 80}
        )

        return false
    end

    PlayerData.DispatchState =
        "EN_ROUTE"

    scenePrepared = false
    sceneSpawned = false

    createDispatchBlip(incident)
    prepareScene(incident)

    Sentinel.Notify(
        "CENTRAL",
        "Expediente creado. GPS actualizado.",
        {0, 255, 120}
    )

    return true
end

function CompleteCurrentDispatch()
    if PlayerData.DispatchState ~= "REPORT" then
        return false
    end

    resetDispatch()

    if PlayerData.OnDuty then
        PlayerData.DispatchState =
            "WAITING"

        nextDispatchAt =
            GetGameTimer() + dispatchDelay

        Sentinel.Notify(
            "CENTRAL",
            "Informe recibido. Disponible para otro despacho.",
            {0, 255, 120}
        )
    else
        PlayerData.DispatchState =
            "OFF_DUTY"
    end

    return true
end

CreateThread(function()
    while true do
        Wait(250)

        if PlayerData.DispatchState
            == "OFF_DUTY" then

            resetDispatch()

            if GetCurrentCase
                and GetCurrentCase() then

                CancelCurrentCase()
            end

        elseif PlayerData.DispatchState
            == "WAITING" then

            if not nextDispatchAt then
                nextDispatchAt =
                    GetGameTimer()
                    + dispatchDelay
            end

            if GetGameTimer()
                >= nextDispatchAt then

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

        if PlayerData.DispatchState
                == "PENDING"
            and IsControlJustPressed(
                0,
                246
            ) then

            acceptDispatch()
        end
    end
end)

CreateThread(function()
    while true do
        Wait(250)

        if PlayerData.DispatchState
                == "EN_ROUTE"
            and PlayerData.CurrentDispatch then

            local playerCoords =
                GetEntityCoords(
                    PlayerPedId()
                )

            local incidentCoords =
                PlayerData.CurrentDispatch.location

            local distance =
                #(playerCoords - incidentCoords)

            if distance <= 180.0
                and not scenePrepared then

                prepareScene(
                    PlayerData.CurrentDispatch
                )
            end

            if distance <= 150.0
                and scenePrepared
                and not sceneSpawned then

                sceneSpawned =
                    SpawnCrimeScene(
                        PlayerData.CurrentDispatch,
                        true
                    ) ~= false
            end

            if distance <= 25.0 then
                removeDispatchBlip()

                PlayerData.DispatchState =
                    "ON_SCENE"

                if not sceneSpawned then
                    if not scenePrepared then
                        SceneBuilder.Build(
                            PlayerData.CurrentDispatch
                        )

                        scenePrepared = true
                    end

                    sceneSpawned =
                        SpawnCrimeScene(
                            PlayerData.CurrentDispatch,
                            false
                        ) ~= false
                end

                if ActivateCrimeScene then
                    ActivateCrimeScene()
                end

                Sentinel.Notify(
                    "CENTRAL",
                    "Unidad en escena. Evalúe la situación.",
                    {0, 255, 0}
                )
            end
        end
    end
end)