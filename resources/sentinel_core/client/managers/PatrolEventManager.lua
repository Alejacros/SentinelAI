print("[Sentinel AI] Cargando PatrolEventManager...")

PatrolEventManager = {
    Active = false,
    Event = nil,
    Entity = nil,
    Vehicle = nil,
    Blip = nil,

    NextEventAt = 0,
    InteractionLocked = false
}

local EVENT_GROUP = "patrol_micro_event"

-- Para probar rápido. Después podemos aumentarlo.
local MIN_EVENT_DELAY = 35000
local MAX_EVENT_DELAY = 70000

local EVENT_DURATION = 180000

local eventDefinitions = {
    {
        id = "STRANDED_DRIVER",
        title = "Conductor varado",
        description =
            "Un ciudadano parece tener problemas con su vehículo.",

        pedModel = "a_m_m_business_01",
        vehicleModel = "blista",

        reward = 4
    },

    {
        id = "CITIZEN_HELP",
        title = "Ciudadano solicita ayuda",
        description =
            "Una persona intenta llamar la atención de la patrulla.",

        pedModel = "a_f_y_business_01",
        vehicleModel = nil,

        reward = 3
    },

    {
        id = "SUSPICIOUS_VEHICLE",
        title = "Vehículo sospechoso",
        description =
            "Central solicita verificar un vehículo estacionado.",

        pedModel = "a_m_y_hipster_01",
        vehicleModel = "primo",

        reward = 5
    }
}

local function notify(title, message, color)
    Sentinel.Notify(
        title,
        message,
        color or {90, 190, 255}
    )
end

local function showHelp(message)
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandDisplayHelp(
        0,
        false,
        true,
        -1
    )
end

local function scheduleNextEvent()
    PatrolEventManager.NextEventAt =
        GetGameTimer()
        + math.random(
            MIN_EVENT_DELAY,
            MAX_EVENT_DELAY
        )
end

local function isPatrolAvailable()
    return PlayerData
        and PlayerData.OnDuty == true
        and PlayerData.DispatchState == "WAITING"
        and not MissionManager.Active
end

local function getSpawnCenter()
    local playerPed = PlayerPedId()
    local playerCoords =
        GetEntityCoords(playerPed)

    local angle =
        math.rad(math.random(0, 359))

    local radius =
        math.random(55, 90) + 0.0

    return vector3(
        playerCoords.x
            + math.cos(angle) * radius,

        playerCoords.y
            + math.sin(angle) * radius,

        playerCoords.z
    )
end

local function getSafeVehiclePosition(center)
    if SpawnPointManager
        and type(
            SpawnPointManager.FindSafeVehiclePosition
        ) == "function" then

        return SpawnPointManager
            .FindSafeVehiclePosition(center)
    end

    return center, 0.0
end

local function getSafePedPosition(
    center,
    blockedPositions
)
    if SpawnPointManager
        and type(
            SpawnPointManager.FindSafePedPosition
        ) == "function" then

        return SpawnPointManager
            .FindSafePedPosition(
                center,
                2.0,
                7.0,
                blockedPositions or {}
            )
    end

    return center
end

local function removeBlip()
    if PatrolEventManager.Blip
        and DoesBlipExist(
            PatrolEventManager.Blip
        ) then

        RemoveBlip(
            PatrolEventManager.Blip
        )
    end

    PatrolEventManager.Blip = nil
end

function PatrolEventManager.Clear(
    scheduleAgain
)
    removeBlip()

    if EntityManager
        and type(
            EntityManager.CleanupGroup
        ) == "function" then

        EntityManager.CleanupGroup(
            EVENT_GROUP,
            true
        )
    else
        if PatrolEventManager.Entity
            and DoesEntityExist(
                PatrolEventManager.Entity
            ) then

            DeleteEntity(
                PatrolEventManager.Entity
            )
        end

        if PatrolEventManager.Vehicle
            and DoesEntityExist(
                PatrolEventManager.Vehicle
            ) then

            DeleteEntity(
                PatrolEventManager.Vehicle
            )
        end
    end

    PatrolEventManager.Active = false
    PatrolEventManager.Event = nil
    PatrolEventManager.Entity = nil
    PatrolEventManager.Vehicle = nil
    PatrolEventManager.InteractionLocked = false

    if scheduleAgain ~= false then
        scheduleNextEvent()
    end
end

local function createEventBlip(coords, title)
    local blip =
        AddBlipForCoord(
            coords.x,
            coords.y,
            coords.z
        )

    SetBlipSprite(blip, 280)
    SetBlipColour(blip, 5)
    SetBlipScale(blip, 0.8)
    SetBlipAsShortRange(blip, false)

    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(title)
    EndTextCommandSetBlipName(blip)

    PatrolEventManager.Blip = blip
end

local function configureCitizen(ped)
    if not ped
        or not DoesEntityExist(ped) then

        return
    end

    SetEntityInvincible(ped, true)
    SetEntityCanBeDamaged(ped, false)
    SetPedCanRagdoll(ped, false)

    SetBlockingOfNonTemporaryEvents(
        ped,
        true
    )

    TaskStartScenarioInPlace(
        ped,
        "WORLD_HUMAN_STAND_MOBILE",
        0,
        true
    )
end

local function spawnPatrolEvent()
    if PatrolEventManager.Active
        or not isPatrolAvailable() then

        return false
    end

    local definition =
        eventDefinitions[
            math.random(#eventDefinitions)
        ]

    local center =
        getSpawnCenter()

    local vehiclePosition, vehicleHeading =
        getSafeVehiclePosition(center)

    local blockedPositions = {}

    if vehiclePosition then
        blockedPositions[
            #blockedPositions + 1
        ] = vehiclePosition
    end

    local pedPosition =
        getSafePedPosition(
            vehiclePosition or center,
            blockedPositions
        )

    local vehicle = nil

    if definition.vehicleModel then
        vehicle =
            EntityManager.SpawnVehicle({
                model =
                    definition.vehicleModel,

                coords =
                    vehiclePosition,

                heading =
                    vehicleHeading or 0.0,

                engineOn = false,
                group = EVENT_GROUP
            })

        if vehicle
            and DoesEntityExist(vehicle) then

            SetVehicleEngineHealth(
                vehicle,
                definition.id
                    == "STRANDED_DRIVER"
                    and 250.0
                    or 850.0
            )

            SetVehicleDoorsLocked(
                vehicle,
                1
            )
        end
    end

    local ped =
        EntityManager.SpawnPed({
            model = definition.pedModel,
            coords = pedPosition,
            heading =
                vehicleHeading or 0.0,

            blockEvents = true,
            invincible = true,
            canRagdoll = false,
            group = EVENT_GROUP
        })

    if not ped
        or not DoesEntityExist(ped) then

        PatrolEventManager.Clear(true)
        return false
    end

    configureCitizen(ped)

    PatrolEventManager.Active = true

    PatrolEventManager.Event = {
        id = definition.id,
        title = definition.title,
        description =
            definition.description,

        reward =
            tonumber(definition.reward) or 0,

        startedAt = GetGameTimer()
    }

    PatrolEventManager.Entity = ped
    PatrolEventManager.Vehicle = vehicle

    createEventBlip(
        GetEntityCoords(ped),
        definition.title
    )

    notify(
        "CENTRAL",
        definition.description
            .. "\nIncidente menor marcado en el GPS.",
        {255, 200, 80}
    )

    print(
        "[Sentinel AI] Microevento creado: "
            .. definition.id
    )

    return true
end

local function resolveStrandedDriver()
    notify(
        "CIUDADANO",
        "Gracias, agente. Ya solicité asistencia mecánica.",
        {80, 220, 140}
    )

    if PatrolEventManager.Vehicle
        and DoesEntityExist(
            PatrolEventManager.Vehicle
        ) then

        SetVehicleHazardLights(
            PatrolEventManager.Vehicle,
            true
        )
    end
end

local function resolveCitizenHelp()
    local responses = {
        "La persona solicitó indicaciones y agradeció la ayuda.",
        "El ciudadano reportó actividad sospechosa en el sector.",
        "La persona perdió sus documentos y recibió orientación.",
        "El ciudadano pidió acompañamiento hasta una zona segura."
    }

    notify(
        "CIUDADANO",
        responses[
            math.random(#responses)
        ],
        {80, 220, 140}
    )
end

local function resolveSuspiciousVehicle()
    local outcomes = {
        {
            message =
                "El vehículo no presenta novedades. Propietario verificado.",

            bonus = 0
        },

        {
            message =
                "La matrícula no coincide con el vehículo. Informe remitido a central.",

            bonus = 2
        },

        {
            message =
                "Se encontraron daños recientes. Vehículo marcado para investigación.",

            bonus = 2
        }
    }

    local outcome =
        outcomes[
            math.random(#outcomes)
        ]

    notify(
        "CENTRAL",
        outcome.message,
        {80, 220, 140}
    )

    return outcome.bonus or 0
end

local function completeEvent()
    if PatrolEventManager.InteractionLocked
        or not PatrolEventManager.Active
        or not PatrolEventManager.Event then

        return
    end

    PatrolEventManager.InteractionLocked =
        true

    local event =
        PatrolEventManager.Event

    local bonusXP = 0

    if event.id == "STRANDED_DRIVER" then
        resolveStrandedDriver()

    elseif event.id == "CITIZEN_HELP" then
        resolveCitizenHelp()

    elseif event.id
        == "SUSPICIOUS_VEHICLE" then

        bonusXP =
            resolveSuspiciousVehicle()
    end

    local totalXP =
        (event.reward or 0)
        + bonusXP

    if totalXP > 0
        and type(AwardXP) == "function" then

        AwardXP(totalXP)
    end

    notify(
        "CENTRAL",
        (
            "Incidente menor atendido. +%d XP"
        ):format(totalXP),
        {80, 220, 140}
    )

    if BodyCamManager
        and BodyCamManager.Active
        and type(
            BodyCamManager.Log
        ) == "function" then

        BodyCamManager.Log(
            "Microevento atendido: "
                .. tostring(event.title)
                .. ".",
            "PATROL"
        )
    end

    CreateThread(function()
        Wait(1800)
        PatrolEventManager.Clear(true)
    end)
end

RegisterCommand(
    "patrolevent",
    function()
        if PatrolEventManager.Active then
            notify(
                "SENTINEL",
                "Ya existe un microevento activo.",
                {255, 180, 0}
            )

            return
        end

        if not isPatrolAvailable() then
            notify(
                "SENTINEL",
                "Debe estar patrullando y sin despacho activo.",
                {255, 180, 0}
            )

            return
        end

        spawnPatrolEvent()
    end,
    false
)

CreateThread(function()
    scheduleNextEvent()

    while true do
        Wait(1000)

        if PatrolEventManager.Active then
            if not isPatrolAvailable() then
                PatrolEventManager.Clear(true)

            elseif PatrolEventManager.Event
                and GetGameTimer()
                    - PatrolEventManager.Event.startedAt
                    >= EVENT_DURATION then

                notify(
                    "CENTRAL",
                    "El incidente menor fue atendido por otra unidad.",
                    {150, 150, 150}
                )

                PatrolEventManager.Clear(true)
            end

        elseif isPatrolAvailable()
            and GetGameTimer()
                >= PatrolEventManager.NextEventAt then

            spawnPatrolEvent()
            scheduleNextEvent()
        end
    end
end)

CreateThread(function()
    while true do
        local sleep = 500

        if PatrolEventManager.Active
            and PatrolEventManager.Entity
            and DoesEntityExist(
                PatrolEventManager.Entity
            ) then

            local pedCoords =
                GetEntityCoords(
                    PatrolEventManager.Entity
                )

            local playerCoords =
                GetEntityCoords(
                    PlayerPedId()
                )

            local distance =
                #(playerCoords - pedCoords)

            if distance <= 45.0 then
                sleep = 0

                DrawMarker(
                    2,
                    pedCoords.x,
                    pedCoords.y,
                    pedCoords.z + 2.0,

                    0.0, 0.0, 0.0,
                    0.0, 180.0, 0.0,

                    0.45,
                    0.45,
                    0.45,

                    255,
                    200,
                    40,
                    255,

                    false,
                    true,
                    2,
                    false,
                    nil,
                    nil,
                    false
                )

                if distance <= 3.0 then
                    showHelp(
                        "Pulsa ~INPUT_CONTEXT~ para atender la situación."
                    )

                    if IsControlJustPressed(
                        0,
                        38
                    ) then

                        completeEvent()
                    end
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

        PatrolEventManager.Clear(false)
    end
)

print("[Sentinel AI] PatrolEventManager listo.")