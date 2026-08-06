IncidentVariantManager = {
    ActiveVariant = nil,
    Entities = {}
}

local VARIANT_GROUP = "incident_variants"

local originalStartDynamicScene = StartDynamicScene
local originalCleanupDynamicScene = CleanupDynamicScene

local function notify(message, color)
    Sentinel.Notify(
        "CENTRAL",
        message,
        color or {255, 170, 60}
    )
end

local function setDirectorState(state, objective)
    SceneDirector.State = state
    SceneDirector.Objective = objective
    SceneDirector.StartedAt = GetGameTimer()

    if objective then
        notify(objective)
    end
end

local function getCenter(dispatch)
    local layout =
        SceneBuilder
        and SceneBuilder.GetLayout
        and SceneBuilder.GetLayout()
        or nil

    if layout and layout.center then
        return layout.center
    end

    return dispatch.location
end

local function findPedPosition(
    center,
    minimumRadius,
    maximumRadius,
    blockedPositions
)
    if SpawnPointManager
        and SpawnPointManager.FindSafePedPosition then

        return SpawnPointManager.FindSafePedPosition(
            center,
            minimumRadius,
            maximumRadius,
            blockedPositions or {}
        )
    end

    return center
end

local function spawnPed(options)
    options = options or {}
    options.group = VARIANT_GROUP

    local ped =
        EntityManager.SpawnPed(options)

    if ped then
        IncidentVariantManager.Entities[
            #IncidentVariantManager.Entities + 1
        ] = ped
    end

    return ped
end

local function spawnVehicle(options)
    options = options or {}
    options.group = VARIANT_GROUP

    local vehicle =
        EntityManager.SpawnVehicle(options)

    if vehicle then
        IncidentVariantManager.Entities[
            #IncidentVariantManager.Entities + 1
        ] = vehicle
    end

    return vehicle
end

local function createBlip(
    entity,
    name,
    colour,
    sprite
)
    return EntityManager.CreateEntityBlip(
        entity,
        {
            name = name,
            colour = colour or 1,
            sprite = sprite or 84,
            scale = 1.0,
            shortRange = false,
            group = VARIANT_GROUP
        }
    )
end

local function configureCivilian(ped)
    if not ped then
        return
    end

    SetEntityInvincible(ped, true)
    SetEntityCanBeDamaged(ped, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
end

local function configureSuspect(
    suspect,
    armed
)
    if not suspect then
        return
    end

    SetBlockingOfNonTemporaryEvents(
        suspect,
        true
    )

    SetPedCombatAbility(suspect, 1)
    SetPedCombatMovement(suspect, 1)
    SetPedCombatRange(suspect, 1)

    if armed then
        GiveWeaponToPed(
            suspect,
            GetHashKey("WEAPON_PISTOL"),
            48,
            false,
            true
        )

        SetPedAccuracy(suspect, 12)
    end

    SceneDirector.Suspect = suspect
end

local function weightedChoice(options)
    local totalWeight = 0

    for _, option in ipairs(options) do
        totalWeight =
            totalWeight + (option.weight or 1)
    end

    local roll = math.random() * totalWeight
    local accumulated = 0

    for _, option in ipairs(options) do
        accumulated =
            accumulated + (option.weight or 1)

        if roll <= accumulated then
            return option
        end
    end

    return options[#options]
end

local function getPreparedTemplate()
    if not SceneBuilder
        or type(SceneBuilder.GetLayout) ~= "function" then

        return nil
    end

    local layout =
        SceneBuilder.GetLayout()

    if type(layout) ~= "table"
        or type(layout.template) ~= "table" then

        return nil
    end

    return layout.template
end

local function logSelectedTemplate(
    dispatchType,
    templateId
)
    print(
        (
            "[IncidentVariantManager] %s -> plantilla %s"
        ):format(
            tostring(dispatchType),
            tostring(templateId or "FALLBACK")
        )
    )
end

-- =========================================================
-- ROBOS
-- =========================================================

local function robberyArmedSuspect(dispatch)
    local center = getCenter(dispatch)

    local suspectPosition =
        SceneBuilder.GetSuspectPosition()
        or findPedPosition(
            center,
            7.0,
            14.0,
            {}
        )

    local victimPosition =
        findPedPosition(
            center,
            3.0,
            8.0,
            {suspectPosition}
        )

    local suspect = spawnPed({
        model = "g_m_y_mexgoon_02",
        coords = suspectPosition,
        heading = 180.0,
        blockEvents = true
    })

    local victim = spawnPed({
        model = "a_f_y_business_02",
        coords = victimPosition,
        heading = 0.0,
        invincible = true,
        canRagdoll = false
    })

    if not suspect then
        setDirectorState(
            "SAFE",
            "El sospechoso escapó antes de su llegada."
        )

        return
    end

    configureSuspect(suspect, true)
    createBlip(
        suspect,
        "Sospechoso armado",
        1,
        84
    )

    if victim then
        configureCivilian(victim)

        TaskHandsUp(
            victim,
            -1,
            suspect,
            -1,
            true
        )
    end

    setDirectorState(
        "ACTIVE_THREAT",
        "Sospechoso armado con una víctima. Ordene la rendición con G."
    )

    CreateThread(function()
        Wait(5500)

        if DoesEntityExist(suspect)
            and not IsEntityDead(suspect)
            and SceneDirector.State
                == "ACTIVE_THREAT" then

            TaskCombatPed(
                suspect,
                PlayerPedId(),
                0,
                16
            )
        end
    end)
end

local function robberyFleeingSuspect(dispatch)
    local center = getCenter(dispatch)

    local suspectPosition =
        SceneBuilder.GetSuspectPosition()
        or findPedPosition(
            center,
            7.0,
            15.0,
            {}
        )

    local suspect = spawnPed({
        model = "g_m_y_ballaeast_01",
        coords = suspectPosition,
        heading = 90.0,
        blockEvents = true
    })

    if not suspect then
        setDirectorState(
            "SAFE",
            "El sospechoso escapó."
        )

        return
    end

    configureSuspect(suspect, false)

    createBlip(
        suspect,
        "Sospechoso huyendo",
        1,
        84
    )

    setDirectorState(
        "SUSPECT_FLEEING",
        "Sospechoso huyendo con mercancía robada. Persígalo y use G."
    )

    TaskSmartFleePed(
        suspect,
        PlayerPedId(),
        180.0,
        -1,
        false,
        false
    )
end

local function robberyGetawayDriver(dispatch)
    local center = getCenter(dispatch)

    local suspectPosition =
        findPedPosition(
            center,
            8.0,
            16.0,
            {}
        )

    local vehiclePosition, vehicleHeading =
        SceneBuilder.GetVehiclePosition()

    if not vehiclePosition then
        vehiclePosition, vehicleHeading =
            SpawnPointManager
                .FindSafeVehiclePosition(center)
    end

    local vehicle = spawnVehicle({
        model = "primo",
        coords = vehiclePosition,
        heading = vehicleHeading,
        engineOn = true
    })

    local suspect = spawnPed({
        model = "g_m_m_armboss_01",
        coords = suspectPosition,
        heading = vehicleHeading,
        blockEvents = true
    })

    if not suspect then
        setDirectorState(
            "SAFE",
            "El conductor del vehículo de escape desapareció."
        )

        return
    end

    configureSuspect(suspect, false)

    createBlip(
        suspect,
        "Conductor sospechoso",
        1,
        84
    )

    if vehicle then
        SetVehicleDoorsLocked(vehicle, 1)
    end

    setDirectorState(
        "SUSPECT_FLEEING",
        "Conductor del vehículo de escape localizado. Deténgalo con G."
    )

    TaskSmartFleePed(
        suspect,
        PlayerPedId(),
        180.0,
        -1,
        false,
        false
    )
end

local function robberySuspectsGone()
    setDirectorState(
        "SAFE",
        "Los responsables escaparon. Entreviste al testigo y busque evidencia."
    )
end

local function startRobberyVariant(dispatch)
    local template =
        getPreparedTemplate()

    local templateId =
        template and template.id or nil

    local handlers = {
        STORE_ESCAPE =
            robberyFleeingSuspect,

        ARMED_WITH_VICTIM =
            robberyArmedSuspect,

        GETAWAY_DRIVER =
            robberyGetawayDriver,

        SUSPECTS_GONE =
            robberySuspectsGone,

        -- Compatibilidad temporal:
        -- todavía usamos un solo sospechoso principal.
        TWO_SUSPECTS =
            robberyArmedSuspect
    }

    local handler =
        templateId
        and handlers[templateId]
        or nil

    if not handler then
        local fallback =
            weightedChoice({
                {
                    id = "ARMED_WITH_VICTIM",
                    weight = 32,
                    start = robberyArmedSuspect
                },
                {
                    id = "STORE_ESCAPE",
                    weight = 30,
                    start = robberyFleeingSuspect
                },
                {
                    id = "GETAWAY_DRIVER",
                    weight = 23,
                    start = robberyGetawayDriver
                },
                {
                    id = "SUSPECTS_GONE",
                    weight = 15,
                    start = robberySuspectsGone
                }
            })

        templateId = fallback.id
        handler = fallback.start
    end

    IncidentVariantManager.ActiveVariant =
        templateId

    logSelectedTemplate(
        dispatch.type,
        templateId
    )

    handler(dispatch)
end

-- =========================================================
-- DISTURBIOS
-- =========================================================

local function disturbanceFight(dispatch)
    local center = getCenter(dispatch)
    local firstPosition =
        findPedPosition(center, 4.0, 9.0, {})

    local secondPosition =
        findPedPosition(
            center,
            4.0,
            9.0,
            {firstPosition}
        )

    local first = spawnPed({
        model = "a_m_y_hipster_01",
        coords = firstPosition,
        heading = 90.0
    })

    local second = spawnPed({
        model = "a_m_m_skater_01",
        coords = secondPosition,
        heading = 270.0
    })

    if not first or not second then
        setDirectorState(
            "SAFE",
            "La pelea terminó antes de su llegada."
        )

        return
    end

    createBlip(
        first,
        "Persona involucrada",
        47,
        280
    )

    createBlip(
        second,
        "Persona involucrada",
        47,
        280
    )

    setDirectorState(
        "ACTIVE_DISTURBANCE",
        "Dos personas se encuentran peleando. Asegure la escena."
    )

    TaskCombatPed(first, second, 0, 16)
    TaskCombatPed(second, first, 0, 16)

    CreateThread(function()
        Wait(10000)

        for _, fighter in ipairs({
            first,
            second
        }) do
            if DoesEntityExist(fighter)
                and not IsEntityDead(fighter) then

                ClearPedTasksImmediately(fighter)

                TaskHandsUp(
                    fighter,
                    8000,
                    PlayerPedId(),
                    -1,
                    true
                )
            end
        end

        if SceneDirector.State
            == "ACTIVE_DISTURBANCE" then

            setDirectorState(
                "SAFE",
                "La pelea terminó. Entreviste al testigo."
            )
        end
    end)
end

local function disturbanceKnifeThreat(dispatch)
    local center = getCenter(dispatch)

    local suspectPosition =
        findPedPosition(center, 6.0, 12.0, {})

    local victimPosition =
        findPedPosition(
            center,
            3.0,
            7.0,
            {suspectPosition}
        )

    local suspect = spawnPed({
        model = "a_m_m_hillbilly_01",
        coords = suspectPosition,
        heading = 180.0,
        blockEvents = true
    })

    local victim = spawnPed({
        model = "a_f_y_tourist_01",
        coords = victimPosition,
        heading = 0.0,
        invincible = true,
        canRagdoll = false
    })

    if not suspect then
        setDirectorState(
            "SAFE",
            "La persona armada abandonó el lugar."
        )

        return
    end

    SetBlockingOfNonTemporaryEvents(
        suspect,
        true
    )

    GiveWeaponToPed(
        suspect,
        GetHashKey("WEAPON_KNIFE"),
        1,
        false,
        true
    )

    SceneDirector.Suspect = suspect

    createBlip(
        suspect,
        "Persona armada",
        1,
        84
    )

    if victim then
        configureCivilian(victim)

        TaskHandsUp(
            victim,
            -1,
            suspect,
            -1,
            true
        )
    end

    setDirectorState(
        "ACTIVE_THREAT",
        "Persona armada con cuchillo. Mantenga distancia y ordene rendición con G."
    )
end

local function disturbanceCrowd(dispatch)
    local center = getCenter(dispatch)
    local positions = {}
    local people = {}

    for index = 1, 4 do
        local position =
            findPedPosition(
                center,
                3.0,
                10.0,
                positions
            )

        positions[#positions + 1] =
            position

        local model =
            index % 2 == 0
            and "a_f_y_hipster_02"
            or "a_m_y_hipster_02"

        local person = spawnPed({
            model = model,
            coords = position,
            heading = math.random(0, 359) + 0.0,
            invincible = true
        })

        if person then
            people[#people + 1] = person

            TaskStartScenarioInPlace(
                person,
                "WORLD_HUMAN_STAND_MOBILE",
                0,
                true
            )
        end
    end

    setDirectorState(
        "ACTIVE_DISTURBANCE",
        "Grupo alterado en vía pública. Evalúe la situación."
    )

    CreateThread(function()
        Wait(7500)

        if SceneDirector.State
            == "ACTIVE_DISTURBANCE" then

            for _, person in ipairs(people) do
                if DoesEntityExist(person) then
                    ClearPedTasks(person)

                    TaskWanderStandard(
                        person,
                        10.0,
                        10
                    )
                end
            end

            setDirectorState(
                "SAFE",
                "El grupo se dispersó. Entreviste al testigo."
            )
        end
    end)
end

local function startDisturbanceVariant(dispatch)
    local template =
        getPreparedTemplate()

    local templateId =
        template and template.id or nil

    local handlers = {
        STREET_FIGHT =
            disturbanceFight,

        KNIFE_THREAT =
            disturbanceKnifeThreat,

        CROWD_ARGUMENT =
            disturbanceCrowd
    }

    local handler =
        templateId
        and handlers[templateId]
        or nil

    if not handler then
        local fallback =
            weightedChoice({
                {
                    id = "STREET_FIGHT",
                    weight = 40,
                    start = disturbanceFight
                },
                {
                    id = "KNIFE_THREAT",
                    weight = 30,
                    start = disturbanceKnifeThreat
                },
                {
                    id = "CROWD_ARGUMENT",
                    weight = 30,
                    start = disturbanceCrowd
                }
            })

        templateId = fallback.id
        handler = fallback.start
    end

    IncidentVariantManager.ActiveVariant =
        templateId

    logSelectedTemplate(
        dispatch.type,
        templateId
    )

    handler(dispatch)
end

-- =========================================================
-- ACCIDENTES
-- =========================================================

local function spawnAccidentBase(dispatch)
    local center = getCenter(dispatch)

    local vehiclePosition, vehicleHeading =
        SceneBuilder.GetVehiclePosition()

    if not vehiclePosition then
        vehiclePosition, vehicleHeading =
            SpawnPointManager
                .FindSafeVehiclePosition(center)
    end

    local damagedVehicle = spawnVehicle({
        model = "blista",
        coords = vehiclePosition,
        heading = vehicleHeading,
        engineOn = false
    })

    if damagedVehicle then
        SetVehicleEngineHealth(
            damagedVehicle,
            180.0
        )

        SetVehicleBodyHealth(
            damagedVehicle,
            320.0
        )

        SetVehicleDoorBroken(
            damagedVehicle,
            0,
            true
        )

        SetVehicleTyreBurst(
            damagedVehicle,
            0,
            true,
            1000.0
        )
    end

    return center,
        vehiclePosition,
        vehicleHeading,
        damagedVehicle
end

local function accidentMedicalResponse(dispatch)
    local center, vehiclePosition =
        spawnAccidentBase(dispatch)

    local injuredPosition =
        findPedPosition(
            vehiclePosition or center,
            2.0,
            5.0,
            {}
        )

    local paramedicPosition =
        findPedPosition(
            vehiclePosition or center,
            2.0,
            5.0,
            {injuredPosition}
        )

    local injured = spawnPed({
        model = "a_m_y_business_03",
        coords = injuredPosition,
        heading = 0.0,
        invincible = true,
        canRagdoll = false
    })

    local paramedic = spawnPed({
        model = "s_m_m_paramedic_01",
        coords = paramedicPosition,
        heading = 180.0,
        invincible = true,
        canRagdoll = false
    })

    if injured then
        configureCivilian(injured)
        SetEntityHealth(injured, 130)

        TaskStartScenarioInPlace(
            injured,
            "WORLD_HUMAN_STUPOR",
            0,
            true
        )
    end

    if paramedic then
        configureCivilian(paramedic)

        TaskStartScenarioInPlace(
            paramedic,
            "CODE_HUMAN_MEDIC_TEND_TO_DEAD",
            0,
            true
        )
    end

    setDirectorState(
        "SAFE",
        "Servicios médicos atienden a una persona herida."
    )
end

local function accidentDrunkDriver(dispatch)
    local center =
        select(1, spawnAccidentBase(dispatch))

    local driverPosition =
        findPedPosition(
            center,
            5.0,
            10.0,
            {}
        )

    local driver = spawnPed({
        model = "a_m_m_bevhills_02",
        coords = driverPosition,
        heading = 90.0,
        blockEvents = true
    })

    if not driver then
        setDirectorState(
            "SAFE",
            "El conductor abandonó el lugar."
        )

        return
    end

    SceneDirector.Suspect = driver

    createBlip(
        driver,
        "Conductor involucrado",
        5,
        84
    )

    SetPedMovementClipset(
        driver,
        "move_m@drunk@verydrunk",
        1.0
    )

    setDirectorState(
        "SUSPECT_FLEEING",
        "Posible conductor ebrio intenta abandonar la escena. Deténgalo con G."
    )

    TaskSmartFleePed(
        driver,
        PlayerPedId(),
        100.0,
        -1,
        false,
        false
    )
end

local function accidentMinorCollision(dispatch)
    spawnAccidentBase(dispatch)

    setDirectorState(
        "SAFE",
        "Colisión sin amenaza activa. Entreviste al testigo."
    )
end

local function startAccidentVariant(dispatch)
    local template =
        getPreparedTemplate()

    local templateId =
        template and template.id or nil

    local handlers = {
        MINOR_COLLISION =
            accidentMinorCollision,

        INJURED_DRIVER =
            accidentMedicalResponse,

        DRUNK_DRIVER =
            accidentDrunkDriver
    }

    local handler =
        templateId
        and handlers[templateId]
        or nil

    if not handler then
        local fallback =
            weightedChoice({
                {
                    id = "INJURED_DRIVER",
                    weight = 40,
                    start = accidentMedicalResponse
                },
                {
                    id = "DRUNK_DRIVER",
                    weight = 25,
                    start = accidentDrunkDriver
                },
                {
                    id = "MINOR_COLLISION",
                    weight = 35,
                    start = accidentMinorCollision
                }
            })

        templateId = fallback.id
        handler = fallback.start
    end

    IncidentVariantManager.ActiveVariant =
        templateId

    logSelectedTemplate(
        dispatch.type,
        templateId
    )

    handler(dispatch)
end 

-- =========================================================
-- API
-- =========================================================

function GetActiveIncidentVariant()
    return IncidentVariantManager.ActiveVariant
end

function CleanupIncidentVariant()
    EntityManager.CleanupGroup(
        VARIANT_GROUP,
        false
    )

    IncidentVariantManager.ActiveVariant = nil
    IncidentVariantManager.Entities = {}
end

function StartDynamicScene(dispatch)
    CleanupIncidentVariant()

    if originalCleanupDynamicScene then
        originalCleanupDynamicScene()
    end

    if not dispatch or not dispatch.type then
        setDirectorState(
            "SAFE",
            "Evalúe la escena y entreviste al testigo."
        )

        return
    end

    if dispatch.type == "ROBBERY" then
        startRobberyVariant(dispatch)

    elseif dispatch.type == "DISTURBANCE" then
        startDisturbanceVariant(dispatch)

    elseif dispatch.type
        == "TRAFFIC_ACCIDENT" then

        startAccidentVariant(dispatch)

    elseif originalStartDynamicScene then
        originalStartDynamicScene(dispatch)

    else
        setDirectorState(
            "SAFE",
            "Evalúe la escena y entreviste al testigo."
        )
    end
end

function CleanupDynamicScene()
    CleanupIncidentVariant()

    if originalCleanupDynamicScene then
        originalCleanupDynamicScene()
    end
end