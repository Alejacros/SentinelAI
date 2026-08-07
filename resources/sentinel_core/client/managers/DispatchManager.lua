print("[Sentinel AI] Cargando DispatchManager...")

local dispatchDelay = 15000
local nextDispatchAt = nil

local lastDispatchIndex = nil
local lastLocationByType = {}

local scenePreparing = false
local scenePrepared = false
local sceneSpawned = false

-- =========================================================
-- LIMPIEZA DEL DESPACHO
-- =========================================================

local function removeDispatchBlip()
    if PlayerData
        and PlayerData.DispatchBlip
        and DoesBlipExist(PlayerData.DispatchBlip) then

        RemoveBlip(PlayerData.DispatchBlip)
    end

    if PlayerData then
        PlayerData.DispatchBlip = nil
    end

    SetWaypointOff()
end

local function resetSceneRuntime()
    scenePreparing = false
    scenePrepared = false
    sceneSpawned = false

    if SceneBuilder
        and type(SceneBuilder.Reset) == "function" then

        SceneBuilder.Reset()
    end
end

local function resetDispatch()
    removeDispatchBlip()
    resetSceneRuntime()

    if PlayerData then
        PlayerData.CurrentDispatch = nil
    end

    nextDispatchAt = nil
end

function ResetDispatchRuntime()
    resetDispatch()
    return true
end

-- =========================================================
-- SELECCIÓN DE INCIDENTES
-- =========================================================

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
                code = definition.code or "000",
                type = definition.type or "GENERIC",
                title = definition.title
                    or "Incidente sin identificar",

                location = definition.location,
                locationIndex = 1
            }
        end

        return nil
    end

    local dispatchType =
        definition.type or "GENERIC"

    local previousLocation =
        lastLocationByType[dispatchType]

    local locationIndex =
        selectDifferentIndex(
            #locations,
            previousLocation
        )

    lastLocationByType[dispatchType] =
        locationIndex

    return {
        code = definition.code or "000",
        type = dispatchType,

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

        if PlayerData then
            PlayerData.DispatchState = "WAITING"
        end

        nextDispatchAt =
            GetGameTimer() + dispatchDelay

        return false
    end

    resetSceneRuntime()

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

-- =========================================================
-- GPS Y PREPARACIÓN DE ESCENA
-- =========================================================

local function createDispatchBlip(incident)
    if not incident
        or not incident.location then

        return false
    end

    removeDispatchBlip()

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

    return true
end

local function prepareScene(incident)
    if scenePreparing
        or scenePrepared then

        return false
    end

    if not SceneBuilder
        or type(SceneBuilder.Build) ~= "function" then

        print(
            "[Sentinel AI] ERROR: SceneBuilder.Build no está disponible."
        )

        return false
    end

    scenePreparing = true

    CreateThread(function()
        local success, layout =
            pcall(
                SceneBuilder.Build,
                incident
            )

        scenePreparing = false

        if not success then
            scenePrepared = false

            print(
                "[Sentinel AI] ERROR preparando escena: "
                    .. tostring(layout)
            )

            Sentinel.Notify(
                "ERROR",
                "No fue posible preparar la escena.",
                {255, 80, 80}
            )

            return
        end

        scenePrepared = layout ~= nil

        if scenePrepared then
            Sentinel.Notify(
                "CENTRAL",
                "Escena validada. Unidades continúan en ruta.",
                {90, 190, 255}
            )
        else
            print(
                "[Sentinel AI] SceneBuilder no devolvió un diseño válido."
            )
        end
    end)

    return true
end

-- =========================================================
-- ACEPTAR DESPACHO
-- =========================================================

local function cleanupStaleMission(incident)
    if not MissionManager
        or MissionManager.Active ~= true
        or type(MissionManager.EndMission) ~= "function" then

        return
    end

    print(
        "[Sentinel AI] Se detectó una misión anterior activa. "
            .. "Realizando limpieza preventiva."
    )

    MissionManager.EndMission(
        "Nueva misión aceptada"
    )

    PlayerData.CurrentDispatch = incident

    if type(GetCurrentCase) == "function"
        and GetCurrentCase()
        and type(CancelCurrentCase) == "function" then

        CancelCurrentCase()
    end
end

local function acceptDispatch()
    local incident =
        PlayerData.CurrentDispatch

    if not incident
        or not incident.location then

        Sentinel.Notify(
            "ERROR",
            "No existe un despacho válido para aceptar.",
            {255, 80, 80}
        )

        return false
    end

    cleanupStaleMission(incident)

    if type(CreateCurrentCase) ~= "function" then
        Sentinel.Notify(
            "ERROR",
            "El sistema de expedientes no está disponible.",
            {255, 80, 80}
        )

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

    if MissionManager
        and type(MissionManager.StartMission) == "function" then

        MissionManager.StartMission()
    end

    PlayerData.CurrentDispatch = incident
    PlayerData.DispatchState = "EN_ROUTE"

    resetSceneRuntime()

    createDispatchBlip(incident)
    prepareScene(incident)

    Sentinel.Notify(
        "CENTRAL",
        "Expediente creado. GPS actualizado.",
        {0, 255, 120}
    )

    local currentCase =
        type(GetCurrentCase) == "function"
        and GetCurrentCase()
        or nil

    if currentCase then
        print(
            (
                "[Sentinel AI] Expediente #%04d activo | "
                .. "Código %s | Ubicación %d"
            ):format(
                tonumber(currentCase.id) or 0,
                tostring(incident.code or "000"),
                tonumber(incident.locationIndex) or 1
            )
        )
    end

    return true
end

-- =========================================================
-- FINALIZAR DESPACHO
-- =========================================================

function CompleteCurrentDispatch()
    if not PlayerData
        or PlayerData.DispatchState ~= "REPORT" then

        return false
    end

    resetDispatch()

    if PlayerData.OnDuty then
        PlayerData.DispatchState = "WAITING"

        nextDispatchAt =
            GetGameTimer() + dispatchDelay

        Sentinel.Notify(
            "CENTRAL",
            "Informe recibido. Disponible para otro despacho.",
            {0, 255, 120}
        )
    else
        PlayerData.DispatchState = "OFF_DUTY"
    end

    if MissionManager then
        MissionManager.Active = false
        MissionManager.StartedAt = 0
    end

    return true
end

-- =========================================================
-- CONTROL DE SERVICIO Y GENERACIÓN DE LLAMADAS
-- =========================================================

CreateThread(function()
    while true do
        Wait(250)

        if PlayerData then
            local dispatchState =
                PlayerData.DispatchState

            if dispatchState == "OFF_DUTY" then
                resetDispatch()

                if type(GetCurrentCase) == "function"
                    and GetCurrentCase()
                    and type(CancelCurrentCase) == "function" then

                    CancelCurrentCase()
                end

            elseif dispatchState == "WAITING" then
                local microEventActive =
                    PatrolEventManager
                    and PatrolEventManager.Active == true

                if microEventActive then
                    nextDispatchAt =
                        GetGameTimer() + 10000
                else
                    if not nextDispatchAt then
                        nextDispatchAt =
                            GetGameTimer() + dispatchDelay
                    end

                    if GetGameTimer() >= nextDispatchAt then
                        nextDispatchAt = nil
                        sendRandomDispatch()
                    end
                end

            else
                nextDispatchAt = nil
            end
        end
    end
end)

-- =========================================================
-- TECLA Y PARA ACEPTAR
-- =========================================================

CreateThread(function()
    while true do
        Wait(0)

        if PlayerData
            and PlayerData.DispatchState == "PENDING"
            and IsControlJustPressed(0, 246) then

            acceptDispatch()
        end
    end
end)

-- =========================================================
-- APROXIMACIÓN Y ACTIVACIÓN DE ESCENA
-- =========================================================

CreateThread(function()
    while true do
        Wait(250)

        if PlayerData
            and PlayerData.DispatchState == "EN_ROUTE"
            and PlayerData.CurrentDispatch
            and PlayerData.CurrentDispatch.location then

            local incident =
                PlayerData.CurrentDispatch

            local playerCoords =
                GetEntityCoords(PlayerPedId())

            local incidentCoords =
                incident.location

            local distance =
                #(playerCoords - incidentCoords)

            if distance <= 180.0
                and not scenePrepared
                and not scenePreparing then

                prepareScene(incident)
            end

            if distance <= 150.0
                and scenePrepared
                and not sceneSpawned then

                if type(SpawnCrimeScene) == "function" then
                    sceneSpawned =
                        SpawnCrimeScene(
                            incident,
                            true
                        ) ~= false
                else
                    print(
                        "[Sentinel AI] ERROR: SpawnCrimeScene no está disponible."
                    )
                end
            end

            if distance <= 25.0 then
                removeDispatchBlip()

                PlayerData.DispatchState =
                    "ON_SCENE"

                if not sceneSpawned then
                    if not scenePrepared then
                        if SceneBuilder
                            and type(SceneBuilder.Build) == "function" then

                            local success, layout =
                                pcall(
                                    SceneBuilder.Build,
                                    incident
                                )

                            scenePreparing = false
                            scenePrepared =
                                success and layout ~= nil

                            if not success then
                                print(
                                    "[Sentinel AI] ERROR preparando "
                                        .. "escena al llegar: "
                                        .. tostring(layout)
                                )
                            end
                        end
                    end

                    if type(SpawnCrimeScene) == "function" then
                        sceneSpawned =
                            SpawnCrimeScene(
                                incident,
                                false
                            ) ~= false
                    end
                end

                if type(ActivateCrimeScene) == "function" then
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

AddEventHandler(
    "onResourceStop",
    function(resourceName)
        if resourceName ~= GetCurrentResourceName() then
            return
        end

        resetDispatch()
    end
)

print("[Sentinel AI] DispatchManager listo.")