SceneDirector = {
    State = "IDLE",
    Variant = nil,
    Objective = nil,
    Entities = {},
    Blips = {},
    StartedAt = 0
}

local function notify(message)
    Sentinel.Notify(
        "CENTRAL",
        message,
        {255, 170, 60}
    )
end

local function loadModel(model)
    if not IsModelInCdimage(model)
        or not IsModelValid(model) then

        return false
    end

    RequestModel(model)

    local timeout = GetGameTimer() + 7000

    while not HasModelLoaded(model) do
        Wait(50)

        if GetGameTimer() >= timeout then
            return false
        end
    end

    return true
end

local function registerEntity(entity)
    if entity
        and entity ~= 0
        and DoesEntityExist(entity) then

        SceneDirector.Entities[
            #SceneDirector.Entities + 1
        ] = entity
    end

    return entity
end

local function registerBlip(blip)
    if blip and DoesBlipExist(blip) then
        SceneDirector.Blips[
            #SceneDirector.Blips + 1
        ] = blip
    end

    return blip
end

local function createPed(modelName, coords, heading)
    local model = GetHashKey(modelName)

    if not loadModel(model) then
        return nil
    end

    RequestCollisionAtCoord(
        coords.x,
        coords.y,
        coords.z
    )

    local ped = CreatePed(
        4,
        model,
        coords.x,
        coords.y,
        coords.z,
        heading or 0.0,
        false,
        false
    )

    if ped == 0 or not DoesEntityExist(ped) then
        SetModelAsNoLongerNeeded(model)
        return nil
    end

    SetEntityAsMissionEntity(ped, true, true)
    SetModelAsNoLongerNeeded(model)

    return registerEntity(ped)
end

local function createVehicle(modelName, coords, heading)
    local model = GetHashKey(modelName)

    if not loadModel(model) then
        return nil
    end

    local vehicle = CreateVehicle(
        model,
        coords.x,
        coords.y,
        coords.z,
        heading or 0.0,
        false,
        false
    )

    if vehicle == 0
        or not DoesEntityExist(vehicle) then

        SetModelAsNoLongerNeeded(model)
        return nil
    end

    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleOnGroundProperly(vehicle)

    SetModelAsNoLongerNeeded(model)

    return registerEntity(vehicle)
end

local function createEntityBlip(
    entity,
    name,
    colour,
    sprite
)
    local blip = AddBlipForEntity(entity)

    SetBlipSprite(blip, sprite or 1)
    SetBlipColour(blip, colour or 1)
    SetBlipScale(blip, 0.9)
    SetBlipAsShortRange(blip, false)

    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(name)
    EndTextCommandSetBlipName(blip)

    return registerBlip(blip)
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

    if not definitions or #definitions == 0 then
        return nil
    end

    return definitions[math.random(#definitions)]
end

local function spawnArmedRobbery(dispatch)
    local location = dispatch.location

    local suspect = createPed(
        "g_m_y_mexgoon_02",
        vector3(
            location.x + 8.0,
            location.y + 3.0,
            location.z
        ),
        180.0
    )

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
    SetPedFleeAttributes(suspect, 0, false)
    SetBlockingOfNonTemporaryEvents(suspect, true)

    createEntityBlip(
        suspect,
        "Sospechoso armado",
        1,
        84
    )

    setSceneState(
        "ACTIVE_THREAT",
        "Sospechoso armado localizado. Controle la amenaza."
    )

    CreateThread(function()
        Wait(2000)

        if DoesEntityExist(suspect)
            and not IsEntityDead(suspect) then

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

    local suspect = createPed(
        "g_m_y_ballaeast_01",
        vector3(
            location.x + 8.0,
            location.y - 3.0,
            location.z
        ),
        90.0
    )

    if not suspect then
        setSceneState(
            "SAFE",
            "El sospechoso escapó. Entreviste al testigo."
        )

        return
    end

    SceneDirector.Suspect = suspect

    SetBlockingOfNonTemporaryEvents(
        suspect,
        true
    )

    createEntityBlip(
        suspect,
        "Sospechoso huyendo",
        1,
        84
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

local function spawnRobbery(dispatch, variant)
    if variant.id == "armed_suspect" then
        spawnArmedRobbery(dispatch)

    elseif variant.id == "fleeing_suspect" then
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

    local personOne = createPed(
        "a_m_y_hipster_01",
        vector3(
            location.x + 6.0,
            location.y + 1.5,
            location.z
        ),
        90.0
    )

    local personTwo = createPed(
        "a_m_m_skater_01",
        vector3(
            location.x + 3.5,
            location.y + 1.5,
            location.z
        ),
        270.0
    )

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

    SetBlockingOfNonTemporaryEvents(
        personOne,
        true
    )

    SetBlockingOfNonTemporaryEvents(
        personTwo,
        true
    )

    createEntityBlip(
        personOne,
        "Persona involucrada",
        47,
        280
    )

    createEntityBlip(
        personTwo,
        "Persona involucrada",
        47,
        280
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

        if DoesEntityExist(personOne) then
            ClearPedTasks(personOne)
            TaskHandsUp(
                personOne,
                7000,
                PlayerPedId(),
                -1,
                true
            )
        end

        if DoesEntityExist(personTwo) then
            ClearPedTasks(personTwo)
            TaskHandsUp(
                personTwo,
                7000,
                PlayerPedId(),
                -1,
                true
            )
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

local function spawnDisturbance(dispatch, variant)
    if variant.id == "active_fight" then
        spawnActiveFight(dispatch)
        return
    end

    setSceneState(
        "ACTIVE_DISTURBANCE",
        "Discusión activa. Mantenga la seguridad de la escena."
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

    local damagedVehicle = createVehicle(
        "blista",
        vector3(
            location.x + 7.0,
            location.y + 3.0,
            location.z
        ),
        120.0
    )

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

    local injured = createPed(
        "a_m_y_business_03",
        vector3(
            location.x + 5.0,
            location.y + 5.0,
            location.z
        ),
        0.0
    )

    if injured then
        SetEntityHealth(injured, 130)
        SetEntityInvincible(injured, true)
        SetEntityCanBeDamaged(
            injured,
            false
        )

        SetBlockingOfNonTemporaryEvents(
            injured,
            true
        )

        TaskStartScenarioInPlace(
            injured,
            "WORLD_HUMAN_STUPOR",
            0,
            true
        )
    end

    local ambulance = createVehicle(
        "ambulance",
        vector3(
            location.x - 9.0,
            location.y - 4.0,
            location.z
        ),
        45.0
    )

    if ambulance then
        SetVehicleSiren(ambulance, true)
        SetVehicleEngineOn(
            ambulance,
            true,
            true,
            false
        )
    end

    local paramedic = createPed(
        "s_m_m_paramedic_01",
        vector3(
            location.x + 4.0,
            location.y + 4.0,
            location.z
        ),
        180.0
    )

    if paramedic then
        SetEntityInvincible(paramedic, true)
        SetEntityCanBeDamaged(
            paramedic,
            false
        )

        SetBlockingOfNonTemporaryEvents(
            paramedic,
            true
        )

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

    local variant = selectVariant(
        dispatch.type
    )

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
        spawnDisturbance(dispatch, variant)

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
    for _, blip in ipairs(
        SceneDirector.Blips or {}
    ) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end

    for _, entity in ipairs(
        SceneDirector.Entities or {}
    ) do
        if DoesEntityExist(entity) then
            if IsEntityAPed(entity) then
                SetBlockingOfNonTemporaryEvents(
                    entity,
                    false
                )

                ClearPedTasks(entity)
                SetEntityAsNoLongerNeeded(entity)

            elseif IsEntityAVehicle(entity) then
                SetVehicleSiren(entity, false)
                SetEntityAsNoLongerNeeded(entity)
            end
        end
    end

    SceneDirector.State = "IDLE"
    SceneDirector.Variant = nil
    SceneDirector.Objective = nil
    SceneDirector.Entities = {}
    SceneDirector.Blips = {}
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
                local playerCoords =
                    GetEntityCoords(
                        PlayerPedId()
                    )

                local suspectCoords =
                    GetEntityCoords(suspect)

                if #(playerCoords - suspectCoords)
                    >= 120.0 then

                    setSceneState(
                        "SAFE",
                        "El sospechoso escapó. Entreviste al testigo."
                    )
                end
            end
        end
    end
end)