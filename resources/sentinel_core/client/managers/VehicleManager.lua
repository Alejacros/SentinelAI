VehicleManager = {
    GarageMenuOpen = false,
    SelectedVehicle = 1,
    ActiveGarageId = nil,
    VehicleState = "NONE",
    VehicleBlip = nil,
    GarageBlips = {},
    ActiveVehicleData = nil,
    StolenSince = nil,
    LastKnownPosition = nil
}

local STOLEN_GRACE_PERIOD = 10000
local ENGINE_DAMAGED_THRESHOLD = 500.0
local ENGINE_DISABLED_THRESHOLD = 100.0
local BODY_DAMAGED_THRESHOLD = 500.0
local UNIT_BLIP_COLOR = 3
local STOLEN_BLIP_COLOR = 1
local GARAGE_BLIP_COLOR = 38

local rankOrder = {
    Cadete = 1,
    Oficial = 2,
    ["Oficial II"] = 3,
    Cabo = 4,
    Sargento = 5,
    Subteniente = 6,
    Teniente = 7,
    Capitan = 8,
    Mayor = 9,
    General = 10,
    ["Brigadier General"] = 11,
    ["Comandante General"] = 12
}

local function drawText(text, x, y, scale, centered)
    SetTextFont(4)
    SetTextScale(scale, scale)
    SetTextColour(255, 255, 255, 255)
    SetTextOutline()
    SetTextCentre(centered == true)

    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

local function showHelpText(message)
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

local function hasRequiredRank(minimumRank)
    local playerLevel = rankOrder[PlayerData.Rank] or 0
    local requiredLevel = rankOrder[minimumRank] or math.huge

    return playerLevel >= requiredLevel
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

local function clearVehicleRuntime()
    removeVehicleBlip()

    PlayerData.Vehicle = nil
    VehicleManager.ActiveVehicleData = nil
    VehicleManager.StolenSince = nil
    VehicleManager.LastKnownPosition = nil
    VehicleManager.VehicleState = "NONE"
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

function VehicleManager.ReturnPoliceVehicle()
    if not VehicleManager.HasActivePoliceVehicle() then
        return false, "no_active_vehicle"
    end

    local vehicle = PlayerData.Vehicle

    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return false, "vehicle_unavailable"
    end

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
        return false, "vehicle_delete_failed"
    end

    clearVehicleRuntime()

    return true
end

local function abandonPoliceVehicle()
    local vehicle = PlayerData.Vehicle

    if not vehicle then
        return false, "no_active_vehicle"
    end

    local entityMissing = vehicle == 0 or not DoesEntityExist(vehicle)

    if not entityMissing
        and VehicleManager.VehicleState ~= "DESTROYED"
        and VehicleManager.VehicleState ~= "DISABLED" then

        return false, "vehicle_not_abandonable"
    end

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

    clearVehicleRuntime()

    Sentinel.Notify(
        "GARAJE",
        "Unidad dada de baja. Puedes solicitar reemplazo en el garaje.",
        {90, 190, 255}
    )

    return true
end

local function closeGarageMenu()
    VehicleManager.GarageMenuOpen = false
    VehicleManager.SelectedVehicle = 1
    VehicleManager.ActiveGarageId = nil
end

local function openGarageMenu(garage)
    if not PlayerData.OnDuty
        or not garage
        or VehicleManager.HasActivePoliceVehicle() then

        return false
    end

    VehicleManager.ActiveGarageId = garage.id
    VehicleManager.SelectedVehicle = 1
    VehicleManager.GarageMenuOpen = true

    return true
end

local function drawGarageMenu()
    local fleet = getPatrolFleet()
    local garage = VehicleManager.GetActiveGarage()
    local menuHeight = 0.22 + (#fleet * 0.075)

    DrawRect(
        0.5,
        0.35,
        0.50,
        menuHeight,
        0,
        0,
        0,
        210
    )

    drawText("GARAJE POLICIAL", 0.5, 0.225, 0.50, true)
    drawText(
        ("%s | Categoría: PATROL"):format(
            garage and garage.label or "Sin estación"
        ),
        0.5,
        0.265,
        0.30,
        true
    )

    for index, vehicleData in ipairs(fleet) do
        local unlocked = hasRequiredRank(vehicleData.minRank)
        local selected = index == VehicleManager.SelectedVehicle
        local prefix = selected and "~b~> " or "  "
        local state = unlocked and "~g~DISPONIBLE" or "~r~BLOQUEADO"
        local label = ("%s%s"):format(
            prefix,
            vehicleData.label
        )

        local y = 0.285 + (index * 0.07)

        drawText(label, 0.275, y, 0.32, false)
        drawText(
            ("Rango requerido: %s  |  %s"):format(
                vehicleData.minRank,
                state
            ),
            0.295,
            y + 0.028,
            0.25,
            false
        )
    end

    drawText(
        "↑ ↓ seleccionar   ENTER retirar   ESC cerrar",
        0.5,
        0.335 + (#fleet * 0.07),
        0.27,
        true
    )
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
            local ped = PlayerPedId()
            local garage, distance =
                VehicleManager.GetNearestGarage()

            if garage and distance < 25.0 then
                sleep = 0

                DrawMarker(
                    36,
                    garage.interaction.x,
                    garage.interaction.y,
                    garage.interaction.z - 1.0,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    1.2,
                    1.2,
                    1.2,
                    40,
                    120,
                    255,
                    150,
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
                        local playerHasActiveVehicle =
                            activeVehicle ~= 0
                            and DoesEntityExist(activeVehicle)
                            and GetVehiclePedIsIn(ped, false)
                                == activeVehicle

                        if canAbandon then
                            showHelpText(
                                "Pulsa ~INPUT_CONTEXT~ para dar de baja la unidad."
                            )
                        elseif playerHasActiveVehicle then
                            showHelpText(
                                "Pulsa ~INPUT_CONTEXT~ para devolver la patrulla."
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

                            if canAbandon then
                                abandonPoliceVehicle()
                            elseif GetVehiclePedIsIn(ped, false)
                                == activeVehicle then

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

    removeVehicleBlip()
    removeGarageBlips()
end)

CreateThread(function()
    while true do
        if not VehicleManager.GarageMenuOpen then
            Wait(250)
        else
            Wait(0)

            local fleet = getPatrolFleet()
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
                drawGarageMenu()

                if IsControlJustPressed(0, 172) then
                    VehicleManager.SelectedVehicle =
                        VehicleManager.SelectedVehicle - 1

                    if VehicleManager.SelectedVehicle < 1 then
                        VehicleManager.SelectedVehicle = #fleet
                    end
                elseif IsControlJustPressed(0, 173) then
                    VehicleManager.SelectedVehicle =
                        VehicleManager.SelectedVehicle + 1

                    if VehicleManager.SelectedVehicle > #fleet then
                        VehicleManager.SelectedVehicle = 1
                    end
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
