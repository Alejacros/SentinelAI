print("[Sentinel AI] Cargando PoliceAIManager...")

PoliceAIManager = {
    Active = false,
    Requested = false,

    Vehicle = nil,
    Driver = nil,
    Passenger = nil,
    Officers = {},

    State = "IDLE",
    ArrivalStartedAt = 0,
    LastTaskAt = 0
}

local SUPPORT_GROUP = "police_ai_support"

local ARRIVAL_DELAY_MS = 3500
local ARRIVAL_TIMEOUT_MS = 30000

local officerModels = {
    "s_m_y_cop_01",
    "s_f_y_cop_01"
}

local function notify(message, color)
    Sentinel.Notify(
        "CENTRAL",
        message,
        color or {80, 180, 255}
    )
end

local function getSceneCenter()
    local layout =
        SceneBuilder
        and SceneBuilder.GetLayout
        and SceneBuilder.GetLayout()
        or nil

    if layout and layout.center then
        return layout.center
    end

    if PlayerData
        and PlayerData.CurrentDispatch
        and PlayerData.CurrentDispatch.location then

        return PlayerData.CurrentDispatch.location
    end

    return GetEntityCoords(PlayerPedId())
end

local function getActiveThreat()
    if not SceneDirector then
        return nil
    end

    local suspect = SceneDirector.Suspect

    if suspect
        and DoesEntityExist(suspect)
        and not IsEntityDead(suspect) then

        return suspect
    end

    return nil
end

local function configureOfficer(officer)
    if not officer
        or not DoesEntityExist(officer) then

        return
    end

    SetEntityInvincible(officer, true)
    SetEntityCanBeDamaged(officer, false)
    SetPedCanRagdoll(officer, false)

    SetBlockingOfNonTemporaryEvents(
        officer,
        true
    )

    SetPedAsCop(officer, true)

    SetPedRelationshipGroupHash(
        officer,
        GetHashKey("COP")
    )

    SetPedDropsWeaponsWhenDead(
        officer,
        false
    )

    GiveWeaponToPed(
        officer,
        GetHashKey("WEAPON_COMBATPISTOL"),
        120,
        false,
        true
    )

    SetPedAccuracy(officer, 24)
    SetPedCombatAbility(officer, 2)
    SetPedCombatRange(officer, 2)
    SetPedCombatMovement(officer, 2)

    SetPedFleeAttributes(
        officer,
        0,
        false
    )
end

local function createOfficerBlip(officer, label)
    if not officer
        or not DoesEntityExist(officer) then

        return
    end

    EntityManager.CreateEntityBlip(
        officer,
        {
            name = label,
            sprite = 1,
            colour = 3,
            scale = 0.75,
            shortRange = false,
            group = SUPPORT_GROUP
        }
    )
end

local function createVehicleBlip(vehicle)
    if not vehicle
        or not DoesEntityExist(vehicle) then

        return
    end

    EntityManager.CreateEntityBlip(
        vehicle,
        {
            name = "Adam-21",
            sprite = 56,
            colour = 3,
            scale = 0.85,
            shortRange = false,
            group = SUPPORT_GROUP
        }
    )
end

local function getRoadSpawnPosition(center)
    local angle =
        math.rad(math.random(0, 359))

    local distance =
        math.random(85, 120) + 0.0

    local candidate = vector3(
        center.x + math.cos(angle) * distance,
        center.y + math.sin(angle) * distance,
        center.z
    )

    if SpawnPointManager
        and SpawnPointManager.FindSafeVehiclePosition then

        local position, heading =
            SpawnPointManager.FindSafeVehiclePosition(
                candidate
            )

        if position then
            return position, heading or 0.0
        end
    end

    return candidate, 0.0
end

local function spawnOfficer(
    modelName,
    coords,
    heading
)
    local officer =
        EntityManager.SpawnPed({
            model = modelName,
            coords = coords,
            heading = heading or 0.0,
            blockEvents = true,
            invincible = true,
            canRagdoll = false,
            group = SUPPORT_GROUP
        })

    if officer then
        configureOfficer(officer)

        PoliceAIManager.Officers[
            #PoliceAIManager.Officers + 1
        ] = officer
    end

    return officer
end

local function spawnSupportUnit()
    local center =
        getSceneCenter()

    local spawnPosition, heading =
        getRoadSpawnPosition(center)

    local vehicle =
        EntityManager.SpawnVehicle({
            model = "police",
            coords = spawnPosition,
            heading = heading,
            engineOn = true,
            group = SUPPORT_GROUP
        })

    if not vehicle
        or not DoesEntityExist(vehicle) then

        return false
    end

    PoliceAIManager.Vehicle = vehicle

    SetVehicleSiren(vehicle, true)
    SetVehicleHasMutedSirens(vehicle, false)

    SetVehicleDoorsLocked(
        vehicle,
        1
    )

    createVehicleBlip(vehicle)

    local driver =
        spawnOfficer(
            officerModels[1],
            spawnPosition,
            heading
        )

    local passenger =
        spawnOfficer(
            officerModels[2],
            spawnPosition,
            heading
        )

    if not driver then
        return false
    end

    PoliceAIManager.Driver = driver
    PoliceAIManager.Passenger = passenger

    SetPedIntoVehicle(
        driver,
        vehicle,
        -1
    )

    if passenger then
        SetPedIntoVehicle(
            passenger,
            vehicle,
            0
        )
    end

    PoliceAIManager.State = "DRIVING"
    PoliceAIManager.ArrivalStartedAt =
        GetGameTimer()

    TaskVehicleDriveToCoordLongrange(
        driver,
        vehicle,
        center.x,
        center.y,
        center.z,
        22.0,
        786603,
        12.0
    )

    notify(
        "Adam-21 aproximándose con luces y sirena."
    )

    return true
end

local function findFootDeploymentPosition(
    center,
    index
)
    if SpawnPointManager
        and SpawnPointManager.FindSafePedPosition then

        return SpawnPointManager.FindSafePedPosition(
            center,
            8.0 + index,
            14.0 + index,
            {}
        )
    end

    return vector3(
        center.x + 4.0 + index,
        center.y + 4.0,
        center.z
    )
end

local function deployFallbackOnFoot()
    local center =
        getSceneCenter()

    for index = 1, 2 do
        local position =
            findFootDeploymentPosition(
                center,
                index
            )

        local model =
            officerModels[
                ((index - 1) % #officerModels) + 1
            ]

        local officer =
            spawnOfficer(
                model,
                position,
                0.0
            )

        if officer then
            createOfficerBlip(
                officer,
                ("Adam-21 Oficial %d"):format(index)
            )
        end
    end

    if #PoliceAIManager.Officers > 0 then
        PoliceAIManager.Active = true
        PoliceAIManager.State = "DEPLOYED"

        notify(
            "Adam-21 desplegado a pie.",
            {80, 220, 140}
        )

        return true
    end

    return false
end

local function exitVehicleAndDeploy()
    if PoliceAIManager.State == "DEPLOYED" then
        return
    end

    local vehicle =
        PoliceAIManager.Vehicle

    if vehicle
        and DoesEntityExist(vehicle) then

        SetVehicleSiren(vehicle, false)
        SetVehicleHasMutedSirens(vehicle, true)

        SetVehicleHandbrake(
            vehicle,
            true
        )

        SetVehicleEngineOn(
            vehicle,
            true,
            true,
            false
        )
    end

    for index, officer in ipairs(
        PoliceAIManager.Officers
    ) do
        if officer
            and DoesEntityExist(officer) then

            ClearPedTasksImmediately(officer)

            if IsPedInAnyVehicle(
                officer,
                false
            ) then

                TaskLeaveVehicle(
                    officer,
                    vehicle,
                    256
                )
            end

            createOfficerBlip(
                officer,
                ("Adam-21 Oficial %d"):format(index)
            )
        end
    end

    PoliceAIManager.Active = true
    PoliceAIManager.State = "DEPLOYING"

    CreateThread(function()
        Wait(1800)

        if PoliceAIManager.State
            == "DEPLOYING" then

            PoliceAIManager.State =
                "DEPLOYED"

            notify(
                "Adam-21 en escena. Oficiales desplegados.",
                {80, 220, 140}
            )
        end
    end)
end

local function suspectIsAttacking(
    suspect,
    officer
)
    if not suspect
        or not DoesEntityExist(suspect) then

        return false
    end

    if IsPedShooting(suspect) then
        return true
    end

    if IsPedInCombat(
        suspect,
        PlayerPedId()
    ) then
        return true
    end

    if officer
        and DoesEntityExist(officer)
        and IsPedInCombat(
            suspect,
            officer
        ) then

        return true
    end

    return false
end

local function handleDeployedOfficer(
    officer,
    index
)
    if not officer
        or not DoesEntityExist(officer)
        or IsEntityDead(officer) then

        return
    end

    local threat =
        getActiveThreat()

    local directorState =
        SceneDirector
        and SceneDirector.State
        or "IDLE"

    if directorState == "ACTIVE_THREAT"
        and threat then

        if suspectIsAttacking(
            threat,
            officer
        ) then

            TaskCombatPed(
                officer,
                threat,
                0,
                16
            )
        else
            TaskAimGunAtEntity(
                officer,
                threat,
                2500,
                false
            )
        end

        return
    end

    if directorState == "SUSPECT_FLEEING"
        and threat then

        TaskGoToEntity(
            officer,
            threat,
            -1,
            5.0,
            3.2,
            0.0,
            0
        )

        return
    end

    if directorState
        == "SUSPECT_SURRENDERED"
        and threat then

        ClearPedTasks(officer)

        TaskAimGunAtEntity(
            officer,
            threat,
            2500,
            false
        )

        return
    end

    if directorState
        == "ACTIVE_DISTURBANCE" then

        local center =
            getSceneCenter()

        TaskGoStraightToCoord(
            officer,
            center.x,
            center.y,
            center.z,
            2.0,
            5000,
            0.0,
            1.0
        )

        return
    end

    if directorState == "SAFE"
        or directorState == "IDLE" then

        ClearPedTasks(officer)

        local horizontalOffset =
            index == 1 and -1.6 or 1.6

        TaskFollowToOffsetOfEntity(
            officer,
            PlayerPedId(),
            horizontalOffset,
            -2.5,
            0.0,
            1.4,
            -1,
            2.0,
            true
        )
    end
end

function PoliceAIManager.RequestSupport()
    if PoliceAIManager.Active
        or PoliceAIManager.Requested
        or PoliceAIManager.State
            ~= "IDLE" then

        return false
    end

    PoliceAIManager.Requested = true
    PoliceAIManager.State = "REQUESTED"

    notify(
        "Adam-21 asignado como unidad de apoyo."
    )

    CreateThread(function()
        Wait(ARRIVAL_DELAY_MS)

        if not PlayerData
            or PlayerData.DispatchState
                ~= "ON_SCENE"
            or not PlayerData.CurrentDispatch then

            PoliceAIManager.Requested = false
            PoliceAIManager.State = "IDLE"
            return
        end

        PoliceAIManager.State = "SPAWNING"

        local spawned =
            spawnSupportUnit()

        if not spawned then
            PoliceAIManager.Clear()
            deployFallbackOnFoot()
        end

        PoliceAIManager.Requested = false
    end)

    return true
end

function PoliceAIManager.Clear()
    if EntityManager then
        EntityManager.CleanupGroup(
            SUPPORT_GROUP,
            true
        )
    end

    PoliceAIManager.Active = false
    PoliceAIManager.Requested = false

    PoliceAIManager.Vehicle = nil
    PoliceAIManager.Driver = nil
    PoliceAIManager.Passenger = nil
    PoliceAIManager.Officers = {}

    PoliceAIManager.State = "IDLE"
    PoliceAIManager.ArrivalStartedAt = 0
    PoliceAIManager.LastTaskAt = 0
end

local function shouldRequestSupport()
    if not PlayerData
        or PlayerData.DispatchState
            ~= "ON_SCENE"
        or not PlayerData.CurrentDispatch
        or PoliceAIManager.Active
        or PoliceAIManager.Requested
        or PoliceAIManager.State
            ~= "IDLE" then

        return false
    end

    local dispatchType =
        PlayerData.CurrentDispatch.type

    if dispatchType ~= "ROBBERY"
        and dispatchType ~= "DISTURBANCE" then

        return false
    end

    if not SceneDirector then
        return false
    end

    local supportedStates = {
        ACTIVE_THREAT = true,
        SUSPECT_FLEEING = true,
        ACTIVE_DISTURBANCE = true
    }

    return supportedStates[
        SceneDirector.State
    ] == true
end

CreateThread(function()
    while true do
        Wait(500)

        if shouldRequestSupport() then
            PoliceAIManager.RequestSupport()
        end

        if PoliceAIManager.State
            == "DRIVING"
            and PoliceAIManager.Vehicle
            and DoesEntityExist(
                PoliceAIManager.Vehicle
            ) then

            local center =
                getSceneCenter()

            local vehicleCoords =
                GetEntityCoords(
                    PoliceAIManager.Vehicle
                )

            local distance =
                #(vehicleCoords - center)

            local timedOut =
                GetGameTimer()
                - PoliceAIManager.ArrivalStartedAt
                >= ARRIVAL_TIMEOUT_MS

            if distance <= 22.0
                or timedOut then

                exitVehicleAndDeploy()
            end
        end

        if PoliceAIManager.State
            == "DEPLOYED" then

            local now =
                GetGameTimer()

            if now
                - PoliceAIManager.LastTaskAt
                >= 1800 then

                PoliceAIManager.LastTaskAt =
                    now

                for index, officer in ipairs(
                    PoliceAIManager.Officers
                ) do
                    handleDeployedOfficer(
                        officer,
                        index
                    )
                end
            end
        end

        if PoliceAIManager.State
                ~= "IDLE"
            and (
                not PlayerData
                or not PlayerData.OnDuty
                or PlayerData.DispatchState
                    == "OFF_DUTY"
                or PlayerData.DispatchState
                    == "WAITING"
            ) then

            PoliceAIManager.Clear()
        end
    end
end)

AddEventHandler(
    "onResourceStop",
    function(resourceName)
        if resourceName
            ~= GetCurrentResourceName() then

            return
        end

        PoliceAIManager.Clear()
    end
)

print("[Sentinel AI] PoliceAIManager listo.")