VehicleManager = {
    GarageMenuOpen = false,
    SelectedVehicle = 1,
    AvailableFleet = {},
    ActiveGarageId = nil,
    VehicleState = "NONE",
    VehicleBlip = nil,
    GarageBlips = {},
    ActiveVehicleData = nil,
    StolenSince = nil,
    LastKnownPosition = nil,
    PreRecoveryState = nil,
    RecoverySequence = 0,
    UnitCleanupInProgress = false
}

local STOLEN_GRACE_PERIOD = 10000
local ENGINE_DAMAGED_THRESHOLD = 500.0
local ENGINE_DISABLED_THRESHOLD = 100.0
local BODY_DAMAGED_THRESHOLD = 500.0
local RECOVERY_DISTANCE = 150.0
local RECOVERY_DELAY = 12000
local UNIT_BLIP_COLOR = 3
local STOLEN_BLIP_COLOR = 1
local GARAGE_BLIP_COLOR = 38

local function showHelpText(message)
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

local function hasRequiredRank(minimumRank)
    return IsRankAtLeast(
        GetEffectivePlayerRank(),
        minimumRank
    )
end

local function getAvailableSpawnPoint(garage)
    if not garage or type(garage.spawnPoints) ~= "table" then
        return nil
    end

    for _, spawnPoint in ipairs(garage.spawnPoints) do
        if not IsAnyVehicleNearPoint(
            spawnPoint.x,
            spawnPoint.y,
            spawnPoint.z,
            3.0
        ) then
            return spawnPoint
        end
    end

    return nil
end

function VehicleManager.GetGarageById(id)
    if type(PoliceGarages) ~= "table" then
        return nil
    end

    for _, garage in ipairs(PoliceGarages) do
        if garage.id == id then
            return garage
        end
    end

    return nil
end


function VehicleManager.GetNearestGarage()
    if type(PoliceGarages) ~= "table" then
        return nil, math.huge
    end

    local playerPosition = GetEntityCoords(PlayerPedId())
    local nearestGarage = nil
    local nearestDistance = math.huge

    for _, garage in ipairs(PoliceGarages) do
        local distance = #(playerPosition - garage.interaction)

        if distance < nearestDistance then
            nearestGarage = garage
            nearestDistance = distance
        end
    end

    return nearestGarage, nearestDistance
end


function VehicleManager.GetActiveGarage()
    return VehicleManager.GetGarageById(
        VehicleManager.ActiveGarageId
    )
end

local function getPatrolFleet()
    return type(PoliceFleet) == "table"
        and type(PoliceFleet.PATROL) == "table"
        and PoliceFleet.PATROL
        or {}
end

function VehicleManager.GetAvailableFleetForCurrentRank()
    local availableFleet = {}

    for _, vehicleData in ipairs(getPatrolFleet()) do
        if hasRequiredRank(vehicleData.minRank) then
            availableFleet[#availableFleet + 1] = vehicleData
        end
    end

    return availableFleet
end

local function getNextFleetUnlock()
    local playerLevel = GetRankIndex(GetEffectivePlayerRank()) or 0
    local nextVehicle = nil
    local nextLevel = math.huge

    for _, vehicleData in ipairs(getPatrolFleet()) do
        local requiredLevel = GetRankIndex(vehicleData.minRank)

        if requiredLevel
            and requiredLevel > playerLevel
            and requiredLevel < nextLevel then

            nextVehicle = vehicleData
            nextLevel = requiredLevel
        end
    end

    return nextVehicle
end

local function getFleetVehicleByModel(modelName)
    for _, vehicleData in ipairs(getPatrolFleet()) do
        if vehicleData.model == modelName then
            return vehicleData
        end
    end

    return nil
end

local function removeVehicleBlip()
    if VehicleManager.VehicleBlip
        and DoesBlipExist(VehicleManager.VehicleBlip) then

        RemoveBlip(VehicleManager.VehicleBlip)
    end

    VehicleManager.VehicleBlip = nil
end

local function createVehicleBlip(vehicle)
    removeVehicleBlip()

    local blip = AddBlipForEntity(vehicle)

    SetBlipSprite(blip, 56)
    SetBlipColour(blip, UNIT_BLIP_COLOR)
    SetBlipScale(blip, 0.85)
    SetBlipAsShortRange(blip, false)

    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName("Unidad policial asignada")
    EndTextCommandSetBlipName(blip)

    VehicleManager.VehicleBlip = blip
end

local function updateVehicleBlip(state)
    local blip = VehicleManager.VehicleBlip

    if state == "DESTROYED" then
        removeVehicleBlip()
        return
    end

    if blip and DoesBlipExist(blip) then
        SetBlipColour(
            blip,
            state == "STOLEN"
                and STOLEN_BLIP_COLOR
                or UNIT_BLIP_COLOR
        )
    end
end

local function setVehicleState(state)
    if VehicleManager.VehicleState == state then
        return
    end

    VehicleManager.VehicleState = state
    updateVehicleBlip(state)

    if state == "DAMAGED" then
        Sentinel.Notify(
            "CENTRAL",
            "Tu unidad presenta daños importantes.",
            {255, 180, 0}
        )
    elseif state == "DISABLED" then
        Sentinel.Notify(
            "CENTRAL",
            "Unidad fuera de servicio. Solicita asistencia.",
            {255, 80, 80}
        )
    elseif state == "STOLEN" then
        Sentinel.Notify(
            "CENTRAL",
            "Posible hurto de unidad policial. Vehículo marcado en GPS.",
            {255, 80, 80}
        )
    elseif state == "DESTROYED" then
        Sentinel.Notify(
            "CENTRAL",
            "Unidad policial destruida.",
            {255, 80, 80}
        )
    end
end

function VehicleManager.ClearActiveUnit(reason, expectedVehicle)
    if expectedVehicle
        and PlayerData.Vehicle ~= expectedVehicle then

        return false
    end

    VehicleManager.RecoverySequence =
        VehicleManager.RecoverySequence + 1
    removeVehicleBlip()

    PlayerData.Vehicle = nil
    VehicleManager.ActiveVehicleData = nil
    VehicleManager.StolenSince = nil
    VehicleManager.LastKnownPosition = nil
    VehicleManager.PreRecoveryState = nil
    VehicleManager.VehicleState = "NONE"
    VehicleManager.UnitCleanupInProgress = false

    return true
end

local function removeGarageBlips()
    for _, blip in pairs(VehicleManager.GarageBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end

    VehicleManager.GarageBlips = {}
end

local function createGarageBlips()
    removeGarageBlips()

    if type(PoliceGarages) ~= "table" then
        return
    end

    for _, garage in ipairs(PoliceGarages) do
        local blip = AddBlipForCoord(
            garage.interaction.x,
            garage.interaction.y,
            garage.interaction.z
        )

        SetBlipSprite(blip, 357)
        SetBlipColour(blip, GARAGE_BLIP_COLOR)
        SetBlipScale(blip, 0.75)
        SetBlipAsShortRange(blip, true)

        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName(
            "Garaje policial - " .. garage.label
        )
        EndTextCommandSetBlipName(blip)

        VehicleManager.GarageBlips[garage.id] = blip
    end
end

function VehicleManager.HasActivePoliceVehicle()
    return PlayerData.Vehicle ~= nil
end

function VehicleManager.SpawnPoliceVehicle(
    modelName,
    coords,
    heading
)
    if VehicleManager.HasActivePoliceVehicle() then
        return false, "vehicle_already_active"
    end

    local spawnPoint = coords

    if not spawnPoint then
        spawnPoint = getAvailableSpawnPoint(
            VehicleManager.GetActiveGarage()
        )
    end

    if not spawnPoint then
        return false, "spawn_blocked"
    end

    local model = GetHashKey(tostring(modelName or ""))

    if not IsModelInCdimage(model)
        or not IsModelAVehicle(model) then

        return false, "invalid_vehicle_model"
    end

    RequestModel(model)

    local timeoutAt = GetGameTimer() + 10000

    while not HasModelLoaded(model)
        and GetGameTimer() < timeoutAt do

        Wait(100)
    end

    if not HasModelLoaded(model) then
        return false, "vehicle_model_timeout"
    end

    local vehicle = CreateVehicle(
        model,
        spawnPoint.x,
        spawnPoint.y,
        spawnPoint.z,
        heading or spawnPoint.w or 0.0,
        true,
        false
    )

    SetModelAsNoLongerNeeded(model)

    if not vehicle
        or vehicle == 0
        or not DoesEntityExist(vehicle) then

        return false, "vehicle_spawn_failed"
    end

    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleHasBeenOwnedByPlayer(vehicle, true)
    SetVehicleOnGroundProperly(vehicle)
    SetVehicleEngineOn(vehicle, true, true, false)
    SetVehRadioStation(vehicle, "OFF")

    PlayerData.Vehicle = vehicle
    VehicleManager.ActiveVehicleData =
        getFleetVehicleByModel(tostring(modelName))
    VehicleManager.StolenSince = nil
    VehicleManager.LastKnownPosition = GetEntityCoords(vehicle)
    createVehicleBlip(vehicle)
    setVehicleState("ACTIVE")

    return true, vehicle
end

function VehicleManager.LocatePoliceVehicle()
    local vehicle = PlayerData.Vehicle

    if not vehicle
        or vehicle == 0
        or not DoesEntityExist(vehicle) then

        return false
    end

    local position = GetEntityCoords(vehicle)

    VehicleManager.LastKnownPosition = position
    SetNewWaypoint(position.x, position.y)

    Sentinel.Notify(
        "CENTRAL",
        "GPS actualizado con la ubicación de tu unidad.",
        {90, 190, 255}
    )

    return true
end

local function getVehicleOccupantType(vehicle)
    local maxPassengers = GetVehicleMaxNumberOfPassengers(vehicle)

    for seat = -1, maxPassengers do
        local occupant = GetPedInVehicleSeat(vehicle, seat)

        if occupant and occupant ~= 0 then
            if occupant == PlayerPedId() then
                return "local_player"
            elseif IsPedAPlayer(occupant) then
                return "other_player"
            else
                return "npc"
            end
        end
    end

    return nil
end

local function getVehicleConditionState(vehicle, fallbackState)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return "DESTROYED"
    end

    local engineHealth = GetVehicleEngineHealth(vehicle)
    local bodyHealth = GetVehicleBodyHealth(vehicle)

    if IsEntityDead(vehicle)
        or GetEntityHealth(vehicle) <= 0
        or engineHealth <= -300.0 then

        return "DESTROYED"
    elseif engineHealth <= ENGINE_DISABLED_THRESHOLD then
        return "DISABLED"
    elseif engineHealth < ENGINE_DAMAGED_THRESHOLD
        or bodyHealth < BODY_DAMAGED_THRESHOLD then

        return "DAMAGED"
    end

    return fallbackState == "DAMAGED" and "DAMAGED" or "ACTIVE"
end

local function validateUnitRecovery(vehicle, pending)
    if VehicleManager.UnitCleanupInProgress then
        return false, "unit_operation_pending"
    end

    if PlayerData.Vehicle ~= vehicle then
        return false, "unit_changed"
    end

    if not vehicle then
        return false, "no_active_vehicle"
    end

    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return false, "vehicle_missing"
    end

    local operationalState = pending
        and VehicleManager.PreRecoveryState
        or VehicleManager.VehicleState

    if operationalState ~= "ACTIVE"
        and operationalState ~= "DAMAGED" then

        return false, "invalid_state"
    end

    local actualState = getVehicleConditionState(
        vehicle,
        operationalState
    )

    if actualState ~= "ACTIVE" and actualState ~= "DAMAGED" then
        return false, actualState:lower()
    end

    local occupantType = getVehicleOccupantType(vehicle)

    if occupantType then
        return false, occupantType
    end

    local distance = #(
        GetEntityCoords(PlayerPedId()) - GetEntityCoords(vehicle)
    )

    if distance <= RECOVERY_DISTANCE then
        return false, "vehicle_nearby"
    end

    return true
end

local function cancelUnitRecovery(sequence)
    if VehicleManager.VehicleState ~= "RECOVERY_PENDING"
        or sequence ~= VehicleManager.RecoverySequence then

        return false
    end

    local vehicle = PlayerData.Vehicle
    local restoredState = getVehicleConditionState(
        vehicle,
        VehicleManager.PreRecoveryState
    )

    VehicleManager.RecoverySequence =
        VehicleManager.RecoverySequence + 1
    VehicleManager.PreRecoveryState = nil
    VehicleManager.UnitCleanupInProgress = false
    VehicleManager.VehicleState = restoredState
    updateVehicleBlip(restoredState)

    Sentinel.Notify(
        "CENTRAL",
        "Recuperación de unidad cancelada.",
        {255, 180, 0}
    )

    return true
end

function VehicleManager.RequestUnitRecovery()
    local vehicle = PlayerData.Vehicle

    if VehicleManager.VehicleState == "RECOVERY_PENDING" then
        return false, "recovery_pending"
    end

    local valid, errorCode = validateUnitRecovery(vehicle, false)

    if not valid then
        return false, errorCode
    end

    VehicleManager.PreRecoveryState = VehicleManager.VehicleState
    VehicleManager.RecoverySequence =
        VehicleManager.RecoverySequence + 1

    local sequence = VehicleManager.RecoverySequence

    setVehicleState("RECOVERY_PENDING")

    Sentinel.Notify(
        "CENTRAL",
        "Recuperación logística solicitada.",
        {90, 190, 255}
    )

    CreateThread(function()
        local finishAt = GetGameTimer() + RECOVERY_DELAY

        while GetGameTimer() < finishAt do
            Wait(500)

            if sequence ~= VehicleManager.RecoverySequence
                or VehicleManager.VehicleState
                    ~= "RECOVERY_PENDING" then

                return
            end

            local stillValid = validateUnitRecovery(vehicle, true)

            if not stillValid then
                cancelUnitRecovery(sequence)
                return
            end
        end

        local stillValid = validateUnitRecovery(vehicle, true)

        if not stillValid then
            cancelUnitRecovery(sequence)
            return
        end

        VehicleManager.UnitCleanupInProgress = true
        NetworkRequestControlOfEntity(vehicle)

        local controlTimeoutAt = GetGameTimer() + 2000

        while DoesEntityExist(vehicle)
            and not NetworkHasControlOfEntity(vehicle)
            and GetGameTimer() < controlTimeoutAt do

            NetworkRequestControlOfEntity(vehicle)
            Wait(50)
        end

        if DoesEntityExist(vehicle) then
            SetEntityAsMissionEntity(vehicle, true, true)
            DeleteVehicle(vehicle)
        end

        if DoesEntityExist(vehicle) then
            VehicleManager.UnitCleanupInProgress = false
            cancelUnitRecovery(sequence)
            return
        end

        if not VehicleManager.ClearActiveUnit(
            "recovered",
            vehicle
        ) then
            VehicleManager.UnitCleanupInProgress = false
            return
        end

        Sentinel.Notify(
            "CENTRAL",
            "Unidad recuperada. Puedes solicitar otra patrulla.",
            {90, 190, 255}
        )
    end)

    return true
end

function VehicleManager.CanTransportSuspects()
    return VehicleManager.HasActivePoliceVehicle()
        and VehicleManager.ActiveVehicleData ~= nil
        and VehicleManager.ActiveVehicleData.canTransportSuspects == true
end

function VehicleManager.GetTransportCapacity()
    if not VehicleManager.CanTransportSuspects() then
        return 0
    end

    return math.max(
        0,
        tonumber(VehicleManager.ActiveVehicleData.transportCapacity) or 0
    )
end

function VehicleManager.GetSnapshot()
    local vehicle = PlayerData.Vehicle
    local exists = vehicle
        and vehicle ~= 0
        and DoesEntityExist(vehicle)
        or false
    local coords = exists and GetEntityCoords(vehicle) or nil

    return {
        assigned = vehicle ~= nil,
        handle = vehicle,
        exists = exists,
        model = VehicleManager.ActiveVehicleData
            and VehicleManager.ActiveVehicleData.model
            or nil,
        label = VehicleManager.ActiveVehicleData
            and VehicleManager.ActiveVehicleData.label
            or nil,
        role = VehicleManager.ActiveVehicleData
            and VehicleManager.ActiveVehicleData.role
            or nil,
        state = VehicleManager.VehicleState,
        engineHealth = exists and GetVehicleEngineHealth(vehicle) or nil,
        bodyHealth = exists and GetVehicleBodyHealth(vehicle) or nil,
        transportCapacity = VehicleManager.GetTransportCapacity(),
        canTransportSuspects =
            VehicleManager.CanTransportSuspects(),
        coords = coords and {
            x = coords.x,
            y = coords.y,
            z = coords.z
        } or nil,
        recoveryPending =
            VehicleManager.VehicleState == "RECOVERY_PENDING"
    }
end

function VehicleManager.ReturnPoliceVehicle()
    if not VehicleManager.HasActivePoliceVehicle() then
        return false, "no_active_vehicle"
    end

    local vehicle = PlayerData.Vehicle

    if VehicleManager.UnitCleanupInProgress then
        return false, "unit_operation_pending"
    end

    if VehicleManager.VehicleState == "RECOVERY_PENDING" then
        cancelUnitRecovery(VehicleManager.RecoverySequence)
    end

    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return false, "vehicle_unavailable"
    end

    VehicleManager.UnitCleanupInProgress = true

    local ped = PlayerPedId()

    if GetVehiclePedIsIn(ped, false) == vehicle then
        TaskLeaveVehicle(ped, vehicle, 0)

        local leaveTimeoutAt = GetGameTimer() + 3000

        while GetVehiclePedIsIn(ped, false) == vehicle
            and GetGameTimer() < leaveTimeoutAt do

            Wait(50)
        end
    end

    NetworkRequestControlOfEntity(vehicle)

    local timeoutAt = GetGameTimer() + 2000

    while not NetworkHasControlOfEntity(vehicle)
        and GetGameTimer() < timeoutAt do

        NetworkRequestControlOfEntity(vehicle)
        Wait(50)
    end

    SetEntityAsMissionEntity(vehicle, true, true)
    DeleteVehicle(vehicle)

    if DoesEntityExist(vehicle) then
        VehicleManager.UnitCleanupInProgress = false
        return false, "vehicle_delete_failed"
    end

    VehicleManager.ClearActiveUnit("returned", vehicle)

    return true
end

local function abandonPoliceVehicle()
    local vehicle = PlayerData.Vehicle

    if not vehicle then
        return false, "no_active_vehicle"
    end

    if VehicleManager.UnitCleanupInProgress then
        return false, "unit_operation_pending"
    end

    local entityMissing = vehicle == 0 or not DoesEntityExist(vehicle)

    if not entityMissing
        and VehicleManager.VehicleState ~= "DESTROYED"
        and VehicleManager.VehicleState ~= "DISABLED" then

        return false, "vehicle_not_abandonable"
    end

    VehicleManager.UnitCleanupInProgress = true

    if not entityMissing then
        NetworkRequestControlOfEntity(vehicle)

        local timeoutAt = GetGameTimer() + 2000

        while not NetworkHasControlOfEntity(vehicle)
            and GetGameTimer() < timeoutAt do

            NetworkRequestControlOfEntity(vehicle)
            Wait(50)
        end

        SetEntityAsMissionEntity(vehicle, true, true)
        DeleteVehicle(vehicle)
    end

    VehicleManager.ClearActiveUnit("abandoned", vehicle)

    Sentinel.Notify(
        "GARAJE",
        "Unidad dada de baja. Puedes solicitar reemplazo en el garaje.",
        {90, 190, 255}
    )

    return true
end

local function closeGarageMenu()
    if VehicleManager.GarageMenuOpen then
        SendNUIMessage({action = "garage:close"})
    end

    VehicleManager.GarageMenuOpen = false
    VehicleManager.SelectedVehicle = 1
    VehicleManager.AvailableFleet = {}
    VehicleManager.ActiveGarageId = nil
end

local function updateGarageUi(action)
    local garage = VehicleManager.GetActiveGarage()
    local nextUnlock = getNextFleetUnlock()
    local vehicles = {}

    for _, vehicleData in ipairs(VehicleManager.AvailableFleet) do
        vehicles[#vehicles + 1] = {
            label = vehicleData.label,
            model = vehicleData.model,
            role = vehicleData.role,
            transportCapacity =
                tonumber(vehicleData.transportCapacity) or 0
        }
    end

    SendNUIMessage({
        action = action or "garage:update",
        data = {
            station = garage and garage.label or "Sin estación",
            currentUnit = VehicleManager.HasActivePoliceVehicle()
                and ((VehicleManager.ActiveVehicleData
                    and VehicleManager.ActiveVehicleData.model
                    or "Unidad") .. " — " .. VehicleManager.VehicleState)
                or "Ninguna",
            vehicles = vehicles,
            selectedIndex = VehicleManager.SelectedVehicle,
            nextUnlock = nextUnlock
                and (nextUnlock.label .. " — " .. nextUnlock.minRank)
                or nil
        }
    })
end

function VehicleManager.RefreshGarageFleetForEffectiveRank()
    if not VehicleManager.GarageMenuOpen then
        return false
    end

    VehicleManager.AvailableFleet =
        VehicleManager.GetAvailableFleetForCurrentRank()
    VehicleManager.SelectedVehicle = 1

    if #VehicleManager.AvailableFleet == 0 then
        closeGarageMenu()
        return false
    end

    updateGarageUi()
    return true
end

local function openGarageMenu(garage)
    if not PlayerData.OnDuty
        or not garage
        or VehicleManager.HasActivePoliceVehicle() then

        return false
    end

    if PoliceTerminalManager
        and PoliceTerminalManager.IsOpen
        and PoliceTerminalManager.IsOpen() then

        PoliceTerminalManager.Close()
    end

    local availableFleet =
        VehicleManager.GetAvailableFleetForCurrentRank()

    if #availableFleet == 0 then
        Sentinel.Notify(
            "GARAJE",
            "No hay vehículos disponibles para tu rango.",
            {255, 180, 0}
        )
        return false
    end

    VehicleManager.ActiveGarageId = garage.id
    VehicleManager.SelectedVehicle = 1
    VehicleManager.AvailableFleet = availableFleet
    VehicleManager.GarageMenuOpen = true
    updateGarageUi("garage:open")

    return true
end

CreateThread(function()
    local previousDutyState = false

    while true do
        local onDuty = PlayerData.OnDuty == true

        if previousDutyState ~= onDuty then
            previousDutyState = onDuty

            if onDuty then
                createGarageBlips()
            else
                removeGarageBlips()
            end
        end

        Wait(500)
    end
end)

CreateThread(function()
    while true do
        local vehicle = PlayerData.Vehicle

        if not vehicle then
            if VehicleManager.VehicleState ~= "NONE" then
                setVehicleState("NONE")
            end

            Wait(1000)
        elseif VehicleManager.VehicleState == "RECOVERY_PENDING" then
            Wait(500)
        elseif vehicle == 0 or not DoesEntityExist(vehicle) then
            VehicleManager.StolenSince = nil
            setVehicleState("DESTROYED")
            Wait(1000)
        else
            local playerPed = PlayerPedId()
            local engineHealth = GetVehicleEngineHealth(vehicle)
            local bodyHealth = GetVehicleBodyHealth(vehicle)
            local driver = GetPedInVehicleSeat(vehicle, -1)
            local playerInside = IsPedInVehicle(
                playerPed,
                vehicle,
                false
            )

            VehicleManager.LastKnownPosition = GetEntityCoords(vehicle)

            local stolen = false

            if driver ~= 0
                and driver ~= playerPed
                and not playerInside then

                if not VehicleManager.StolenSince then
                    VehicleManager.StolenSince = GetGameTimer()
                elseif GetGameTimer()
                    - VehicleManager.StolenSince
                    >= STOLEN_GRACE_PERIOD then

                    stolen = true
                end
            else
                VehicleManager.StolenSince = nil
            end

            if IsEntityDead(vehicle)
                or GetEntityHealth(vehicle) <= 0
                or engineHealth <= -300.0 then

                setVehicleState("DESTROYED")
            elseif engineHealth <= ENGINE_DISABLED_THRESHOLD then
                setVehicleState("DISABLED")
            elseif stolen then
                setVehicleState("STOLEN")
            elseif engineHealth < ENGINE_DAMAGED_THRESHOLD
                or bodyHealth < BODY_DAMAGED_THRESHOLD then

                setVehicleState("DAMAGED")
            else
                setVehicleState("ACTIVE")
            end

            Wait(1000)
        end
    end
end)

CreateThread(function()
    while true do
        local sleep = 500

        if PlayerData.OnDuty then
            local garage, distance =
                VehicleManager.GetNearestGarage()

            if garage and distance < 18.0 then
                sleep = 0

                DrawMarker(
                    36,
                    garage.interaction.x,
                    garage.interaction.y,
                    garage.interaction.z + 0.80,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    0.75,
                    0.75,
                    0.75,
                    54,
                    142,
                    190,
                    115,
                    false,
                    false,
                    2,
                    false,
                    nil,
                    nil,
                    false
                )

                if distance < 2.2
                    and not VehicleManager.GarageMenuOpen then

                    if VehicleManager.HasActivePoliceVehicle() then
                        local activeVehicle = PlayerData.Vehicle
                        local canAbandon =
                            VehicleManager.VehicleState == "DESTROYED"
                            or VehicleManager.VehicleState == "DISABLED"
                            or activeVehicle == 0
                            or not DoesEntityExist(activeVehicle)
                        local unitAtGarage =
                            activeVehicle ~= 0
                            and DoesEntityExist(activeVehicle)
                            and #(
                                GetEntityCoords(activeVehicle)
                                    - garage.interaction
                            ) < 10.0

                        if canAbandon then
                            showHelpText(
                                "Pulsa ~INPUT_CONTEXT~ para dar de baja la unidad."
                            )
                        elseif unitAtGarage then
                            showHelpText(
                                "Pulsa ~INPUT_CONTEXT~ para devolver la patrulla."
                            )
                        elseif VehicleManager.VehicleState == "ACTIVE"
                            or VehicleManager.VehicleState == "DAMAGED" then

                            showHelpText(
                                "Ya tienes una unidad asignada. Pulsa ~INPUT_CONTEXT~ para localizarla.~n~/recoverunit si quedó lejos y deseas solicitar recuperación."
                            )
                        else
                            showHelpText(
                                "Ya tienes una unidad asignada. Pulsa ~INPUT_CONTEXT~ para localizarla."
                            )
                        end
                    else
                        showHelpText(
                            "Pulsa ~INPUT_CONTEXT~ para acceder al garaje policial."
                        )
                    end

                    if IsControlJustPressed(0, 38) then
                        if VehicleManager.HasActivePoliceVehicle() then
                            local activeVehicle = PlayerData.Vehicle
                            local canAbandon =
                                VehicleManager.VehicleState == "DESTROYED"
                                or VehicleManager.VehicleState == "DISABLED"
                                or activeVehicle == 0
                                or not DoesEntityExist(activeVehicle)
                            local unitAtGarage =
                                activeVehicle ~= 0
                                and DoesEntityExist(activeVehicle)
                                and #(
                                    GetEntityCoords(activeVehicle)
                                        - garage.interaction
                                ) < 10.0

                            if canAbandon then
                                abandonPoliceVehicle()
                            elseif unitAtGarage then

                                if VehicleManager.ReturnPoliceVehicle() then
                                    Sentinel.Notify(
                                        "GARAJE",
                                        "Patrulla devuelta correctamente.",
                                        {90, 190, 255}
                                    )
                                else
                                    Sentinel.Notify(
                                        "ERROR",
                                        "No fue posible devolver la patrulla.",
                                        {255, 80, 80}
                                    )
                                end
                            else
                                Sentinel.Notify(
                                    "GARAJE",
                                    "Ya tienes una unidad asignada.",
                                    {255, 180, 0}
                                )

                                VehicleManager.LocatePoliceVehicle()
                            end
                        else
                            openGarageMenu(garage)
                        end
                    end
                end
            end
        elseif VehicleManager.GarageMenuOpen then
            closeGarageMenu()
        end

        Wait(sleep)
    end
end)

RegisterCommand("locateunit", function()
    if not VehicleManager.LocatePoliceVehicle() then
        Sentinel.Notify(
            "CENTRAL",
            "No tienes una unidad policial localizable.",
            {255, 180, 0}
        )
    end
end, false)

RegisterCommand("recoverunit", function()
    local requested, errorCode =
        VehicleManager.RequestUnitRecovery()

    if requested then
        return
    end

    local messages = {
        no_active_vehicle = "No tienes una unidad policial asignada.",
        vehicle_missing = "La unidad no existe. Usa /abandonunit para darla de baja.",
        vehicle_nearby = "La unidad está demasiado cerca para recuperación logística.",
        local_player = "Sal de la unidad antes de solicitar recuperación.",
        other_player = "Otro jugador está utilizando la unidad.",
        npc = "La unidad está ocupada. Se mantiene activa la vigilancia por posible hurto.",
        invalid_state = "El estado actual de la unidad no permite recuperación.",
        disabled = "La unidad está fuera de servicio. Usa /abandonunit.",
        destroyed = "La unidad está destruida. Usa /abandonunit.",
        recovery_pending = "Ya existe una recuperación logística pendiente.",
        unit_operation_pending = "Ya hay una operación sobre la unidad en curso."
    }

    Sentinel.Notify(
        "CENTRAL",
        messages[errorCode]
            or "No fue posible solicitar la recuperación de la unidad.",
        {255, 180, 0}
    )
end, false)

RegisterCommand("abandonunit", function()
    local abandoned, errorCode = abandonPoliceVehicle()

    if not abandoned then
        Sentinel.Notify(
            "GARAJE",
            errorCode == "vehicle_not_abandonable"
                and "Solo puedes dar de baja una unidad destruida o fuera de servicio."
                or "No tienes una unidad policial para dar de baja.",
            {255, 180, 0}
        )
    end
end, false)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    closeGarageMenu()
    VehicleManager.RecoverySequence =
        VehicleManager.RecoverySequence + 1
    VehicleManager.PreRecoveryState = nil
    VehicleManager.UnitCleanupInProgress = false
    removeVehicleBlip()
    removeGarageBlips()
end)

CreateThread(function()
    while true do
        if not VehicleManager.GarageMenuOpen then
            Wait(250)
        else
            Wait(0)

            local fleet = VehicleManager.AvailableFleet
            local activeGarage = VehicleManager.GetActiveGarage()
            local distanceToGarage = activeGarage
                and #(
                    GetEntityCoords(PlayerPedId())
                        - activeGarage.interaction
                )
                or math.huge

            if not PlayerData.OnDuty
                or VehicleManager.HasActivePoliceVehicle()
                or #fleet == 0
                or distanceToGarage > 3.5 then

                closeGarageMenu()
            else
                if IsControlJustPressed(0, 172) then
                    VehicleManager.SelectedVehicle =
                        VehicleManager.SelectedVehicle - 1

                    if VehicleManager.SelectedVehicle < 1 then
                        VehicleManager.SelectedVehicle = #fleet
                    end

                    updateGarageUi()
                elseif IsControlJustPressed(0, 173) then
                    VehicleManager.SelectedVehicle =
                        VehicleManager.SelectedVehicle + 1

                    if VehicleManager.SelectedVehicle > #fleet then
                        VehicleManager.SelectedVehicle = 1
                    end

                    updateGarageUi()
                elseif IsControlJustPressed(0, 191) then
                    local selected = fleet[
                        VehicleManager.SelectedVehicle
                    ]

                    if not hasRequiredRank(selected.minRank) then
                        Sentinel.Notify(
                            "GARAJE",
                            "Tu rango no permite retirar esta unidad.",
                            {255, 180, 0}
                        )
                    else
                        local spawned, errorCode =
                            VehicleManager.SpawnPoliceVehicle(
                                selected.model
                            )

                        if spawned then
                            closeGarageMenu()

                            Sentinel.Notify(
                                "GARAJE",
                                selected.label .. " lista para servicio.",
                                {90, 190, 255}
                            )
                        else
                            Sentinel.Notify(
                                "ERROR",
                                errorCode == "spawn_blocked"
                                    and "Todas las plazas del garaje están ocupadas."
                                    or "No fue posible retirar la patrulla.",
                                {255, 80, 80}
                            )
                        end
                    end
                elseif IsControlJustPressed(0, 177)
                    or IsControlJustPressed(0, 322) then

                    closeGarageMenu()
                end
            end
        end
    end
end)
