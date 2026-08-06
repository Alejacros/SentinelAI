SceneDirector = {
    State = "IDLE",
    Variant = nil,
    Objective = nil,
    Suspect = nil,
    Fighters = nil,
    StartedAt = 0
}

local SCENE_GROUP = "dynamic_scene"

local function notify(message)
    Sentinel.Notify(
        "CENTRAL",
        message,
        {255, 170, 60}
    )
end

local function setSceneState(state, objective)
    SceneDirector.State = state
    SceneDirector.Objective = objective
    SceneDirector.StartedAt = GetGameTimer()

    if objective then
        notify(objective)
    end
end

local function selectVariant(dispatchType)
    local definitions =
        ScenarioDefinitions[dispatchType]

    if not definitions
        or #definitions == 0 then

        return nil
    end

    return definitions[
        math.random(#definitions)
    ]
end

local function createSuspectBlip(
    suspect,
    name
)
    return EntityManager.CreateEntityBlip(
        suspect,
        {
            name = name,
            sprite = 84,
            colour = 1,
            scale = 0.95,
            group = SCENE_GROUP
        }
    )
end

local function spawnArmedRobbery(dispatch)
    local location = dispatch.location

    local suspect = EntityManager.SpawnPed({
        model = "g_m_y_mexgoon_02",

        coords = vector3(
            location.x + 8.0,
            location.y + 3.0,
            location.z
        ),

        heading = 180.0,
        blockEvents = true,
        group = SCENE_GROUP
    })

    if not suspect then
        setSceneState(
            "SAFE",
            "No se encontró al sospechoso. Entreviste al testigo."
        )

        return
    end

    SceneDirector.Suspect = suspect

    GiveWeaponToPed(
        suspect,
        GetHashKey("WEAPON_PISTOL"),
        60,
        false,
        true
    )

    SetPedAccuracy(suspect, 18)
    SetPedCombatAbility(suspect, 1)
    SetPedCombatRange(suspect, 1)
    SetPedCombatMovement(suspect, 2)
    SetPedFleeAttributes(
        suspect,
        0,
        false
    )

    createSuspectBlip(
        suspect,
        "Sospechoso armado"
    )

    setSceneState(
        "ACTIVE_THREAT",
        "Sospechoso armado localizado. Controle la amenaza."
    )

    CreateThread(function()
        Wait(2000)

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

local function spawnFleeingRobbery(dispatch)
    local location = dispatch.location

    local suspect = EntityManager.SpawnPed({
        model = "g_m_y_ballaeast_01",

        coords = vector3(
            location.x + 8.0,
            location.y - 3.0,
            location.z
        ),

        heading = 90.0,
        blockEvents = true,
        group = SCENE_GROUP
    })

    if not suspect then
        setSceneState(
            "SAFE",
            "El sospechoso escapó. Entreviste al testigo."
        )

        return
    end

    SceneDirector.Suspect = suspect

    createSuspectBlip(
        suspect,
        "Sospechoso huyendo"
    )

    setSceneState(
        "SUSPECT_FLEEING",
        "Sospechoso huyendo. Intente alcanzarlo."
    )

    TaskSmartFleePed(
        suspect,
        PlayerPedId(),
        250.0,
        -1,
        false,
        false
    )
end

local function spawnRobbery(
    dispatch,
    variant
)
    if variant.id == "armed_suspect" then
        spawnArmedRobbery(dispatch)

    elseif variant.id
        == "fleeing_suspect" then

        spawnFleeingRobbery(dispatch)

    else
        setSceneState(
            "SAFE",
            "Los sospechosos escaparon. Entreviste al testigo."
        )
    end
end

local function spawnActiveFight(dispatch)
    local location = dispatch.location

    local personOne =
        EntityManager.SpawnPed({
            model = "a_m_y_hipster_01",

            coords = vector3(
                location.x + 6.0,
                location.y + 1.5,
                location.z
            ),

            heading = 90.0,
            group = SCENE_GROUP
        })

    local personTwo =
        EntityManager.SpawnPed({
            model = "a_m_m_skater_01",

            coords = vector3(
                location.x + 3.5,
                location.y + 1.5,
                location.z
            ),

            heading = 270.0,
            group = SCENE_GROUP
        })

    if not personOne or not personTwo then
        setSceneState(
            "SAFE",
            "La pelea terminó. Entreviste al testigo."
        )

        return
    end

    SceneDirector.Fighters = {
        personOne,
        personTwo
    }

    EntityManager.CreateEntityBlip(
        personOne,
        {
            name = "Persona involucrada",
            sprite = 280,
            colour = 47,
            group = SCENE_GROUP
        }
    )

    EntityManager.CreateEntityBlip(
        personTwo,
        {
            name = "Persona involucrada",
            sprite = 280,
            colour = 47,
            group = SCENE_GROUP
        }
    )

    setSceneState(
        "ACTIVE_DISTURBANCE",
        "Pelea activa. Controle a los involucrados."
    )

    TaskCombatPed(
        personOne,
        personTwo,
        0,
        16
    )

    TaskCombatPed(
        personTwo,
        personOne,
        0,
        16
    )

    CreateThread(function()
        Wait(12000)

        for _, fighter in ipairs(
            SceneDirector.Fighters or {}
        ) do
            if DoesEntityExist(fighter)
                and not IsEntityDead(fighter) then

                ClearPedTasksImmediately(fighter)

                TaskHandsUp(
                    fighter,
                    7000,
                    PlayerPedId(),
                    -1,
                    true
                )
            end
        end

        if SceneDirector.State
            == "ACTIVE_DISTURBANCE" then

            setSceneState(
                "SAFE",
                "La pelea fue controlada. Entreviste al testigo."
            )
        end
    end)
end

local function spawnDisturbance(
    dispatch,
    variant
)
    if variant.id == "active_fight" then
        spawnActiveFight(dispatch)
        return
    end

    setSceneState(
        "ACTIVE_DISTURBANCE",
        "Discusión activa. Mantenga segura la escena."
    )

    CreateThread(function()
        Wait(7000)

        if SceneDirector.State
            == "ACTIVE_DISTURBANCE" then

            setSceneState(
                "SAFE",
                "La situación está controlada. Entreviste al testigo."
            )
        end
    end)
end

local function spawnAccident(dispatch)
    local location = dispatch.location

    local damagedVehicle =
        EntityManager.SpawnVehicle({
            model = "blista",

            coords = vector3(
                location.x + 7.0,
                location.y + 3.0,
                location.z
            ),

            heading = 120.0,
            engineOn = false,
            group = SCENE_GROUP
        })

    if damagedVehicle then
        SetVehicleEngineHealth(
            damagedVehicle,
            180.0
        )

        SetVehicleBodyHealth(
            damagedVehicle,
            350.0
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

    local injured =
        EntityManager.SpawnPed({
            model = "a_m_y_business_03",

            coords = vector3(
                location.x + 5.0,
                location.y + 5.0,
                location.z
            ),

            invincible = true,
            canRagdoll = false,
            group = SCENE_GROUP
        })

    if injured then
        SetEntityHealth(injured, 130)

        TaskStartScenarioInPlace(
            injured,
            "WORLD_HUMAN_STUPOR",
            0,
            true
        )
    end

    local ambulance =
        EntityManager.SpawnVehicle({
            model = "ambulance",

            coords = vector3(
                location.x - 9.0,
                location.y - 4.0,
                location.z
            ),

            heading = 45.0,
            engineOn = true,
            group = SCENE_GROUP
        })

    if ambulance then
        SetVehicleSiren(
            ambulance,
            true
        )
    end

    local paramedic =
        EntityManager.SpawnPed({
            model = "s_m_m_paramedic_01",

            coords = vector3(
                location.x + 4.0,
                location.y + 4.0,
                location.z
            ),

            heading = 180.0,
            invincible = true,
            canRagdoll = false,
            group = SCENE_GROUP
        })

    if paramedic then
        TaskStartScenarioInPlace(
            paramedic,
            "CODE_HUMAN_MEDIC_TEND_TO_DEAD",
            0,
            true
        )
    end

    setSceneState(
        "SAFE",
        "Escena médica activa. Entreviste al testigo."
    )
end

function IsDynamicSceneSafe()
    return SceneDirector.State == "SAFE"
        or SceneDirector.State == "IDLE"
        or SceneDirector.State
            == "SUSPECT_ARRESTED"
end

function GetDynamicSceneObjective()
    return SceneDirector.Objective
        or "Evalúe la escena."
end

function StartDynamicScene(dispatch)
    CleanupDynamicScene()

    if not dispatch or not dispatch.type then
        setSceneState(
            "SAFE",
            "Entreviste al testigo."
        )

        return
    end

    local variant =
        selectVariant(dispatch.type)

    SceneDirector.Variant = variant

    if not variant then
        setSceneState(
            "SAFE",
            "Entreviste al testigo."
        )

        return
    end

    if dispatch.type == "ROBBERY" then
        spawnRobbery(dispatch, variant)

    elseif dispatch.type == "DISTURBANCE" then
        spawnDisturbance(
            dispatch,
            variant
        )

    elseif dispatch.type
        == "TRAFFIC_ACCIDENT" then

        spawnAccident(dispatch)

    else
        setSceneState(
            "SAFE",
            "Entreviste al testigo."
        )
    end
end

function CleanupDynamicScene()
    EntityManager.CleanupGroup(
        SCENE_GROUP,
        false
    )

    SceneDirector.State = "IDLE"
    SceneDirector.Variant = nil
    SceneDirector.Objective = nil
    SceneDirector.Suspect = nil
    SceneDirector.Fighters = nil
    SceneDirector.StartedAt = 0
end

CreateThread(function()
    while true do
        Wait(500)

        if SceneDirector.State
            == "ACTIVE_THREAT" then

            local suspect =
                SceneDirector.Suspect

            if not suspect
                or not DoesEntityExist(suspect)
                or IsEntityDead(suspect) then

                setSceneState(
                    "SAFE",
                    "Amenaza neutralizada. Entreviste al testigo."
                )
            end

        elseif SceneDirector.State
            == "SUSPECT_FLEEING" then

            local suspect =
                SceneDirector.Suspect

            if not suspect
                or not DoesEntityExist(suspect)
                or IsEntityDead(suspect) then

                setSceneState(
                    "SAFE",
                    "Sospechoso neutralizado. Entreviste al testigo."
                )

            else
                local distance = #(
                    GetEntityCoords(PlayerPedId())
                    - GetEntityCoords(suspect)
                )

                if distance >= 120.0 then
                    setSceneState(
                        "SAFE",
                        "El sospechoso escapó. Entreviste al testigo."
                    )
                end
            end
        end
    end
end)