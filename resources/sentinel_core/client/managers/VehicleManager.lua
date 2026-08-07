VehicleManager = {
    GarageMenuOpen = false,
    SelectedVehicle = 1
}

local GARAGE_POSITION =
    vector3(454.60, -1017.40, 28.40)

local VEHICLE_SPAWN_POINTS = {
    vector4(438.42, -1018.30, 27.76, 90.43),
    vector4(438.45, -1022.10, 27.83, 90.00),
    vector4(438.48, -1026.00, 27.90, 90.00)
}

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

local function getAvailableSpawnPoint()
    for _, spawnPoint in ipairs(VEHICLE_SPAWN_POINTS) do
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

local function getPatrolFleet()
    return type(PoliceFleet) == "table"
        and type(PoliceFleet.PATROL) == "table"
        and PoliceFleet.PATROL
        or {}
end

function VehicleManager.HasActivePoliceVehicle()
    local vehicle = PlayerData.Vehicle

    if vehicle
        and vehicle ~= 0
        and DoesEntityExist(vehicle) then

        return true
    end

    PlayerData.Vehicle = nil
    return false
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
        spawnPoint = getAvailableSpawnPoint()
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

    return true, vehicle
end

function VehicleManager.ReturnPoliceVehicle()
    if not VehicleManager.HasActivePoliceVehicle() then
        return false, "no_active_vehicle"
    end

    local vehicle = PlayerData.Vehicle
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

    PlayerData.Vehicle = nil

    return true
end

local function closeGarageMenu()
    VehicleManager.GarageMenuOpen = false
    VehicleManager.SelectedVehicle = 1
end

local function openGarageMenu()
    if not PlayerData.OnDuty
        or VehicleManager.HasActivePoliceVehicle() then

        return false
    end

    VehicleManager.SelectedVehicle = 1
    VehicleManager.GarageMenuOpen = true

    return true
end

local function drawGarageMenu()
    local fleet = getPatrolFleet()
    local menuHeight = 0.18 + (#fleet * 0.055)

    DrawRect(
        0.5,
        0.35,
        0.44,
        menuHeight,
        0,
        0,
        0,
        210
    )

    drawText("GARAJE POLICIAL", 0.5, 0.245, 0.50, true)
    drawText("Categoría: PATROL", 0.5, 0.285, 0.30, true)

    for index, vehicleData in ipairs(fleet) do
        local unlocked = hasRequiredRank(vehicleData.minRank)
        local selected = index == VehicleManager.SelectedVehicle
        local prefix = selected and "~b~> " or "  "
        local state = unlocked and "~g~DISPONIBLE" or "~r~BLOQUEADO"
        local label = (
            "%s%s | %s | Requiere: %s"
        ):format(
            prefix,
            vehicleData.label,
            state,
            vehicleData.minRank
        )

        drawText(
            label,
            0.31,
            0.315 + (index * 0.05),
            0.30,
            false
        )
    end

    drawText(
        "[ARRIBA/ABAJO] Seleccionar  [ENTER] Retirar  [ESC] Cerrar",
        0.5,
        0.345 + (#fleet * 0.05),
        0.27,
        true
    )
end

CreateThread(function()
    while true do
        local sleep = 500

        if PlayerData.OnDuty then
            local ped = PlayerPedId()
            local playerPosition = GetEntityCoords(ped)
            local distance = #(playerPosition - GARAGE_POSITION)

            if distance < 25.0 then
                sleep = 0

                DrawMarker(
                    1,
                    GARAGE_POSITION.x,
                    GARAGE_POSITION.y,
                    GARAGE_POSITION.z - 1.0,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    1.8,
                    1.8,
                    0.4,
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
                        showHelpText(
                            "Pulsa ~INPUT_CONTEXT~ para devolver la patrulla."
                        )
                    else
                        showHelpText(
                            "Pulsa ~INPUT_CONTEXT~ para acceder al garaje policial."
                        )
                    end

                    if IsControlJustPressed(0, 38) then
                        if VehicleManager.HasActivePoliceVehicle() then
                            local activeVehicle = PlayerData.Vehicle
                            local playerVehicle = GetVehiclePedIsIn(
                                ped,
                                false
                            )

                            if playerVehicle ~= activeVehicle then
                                Sentinel.Notify(
                                    "GARAJE",
                                    "Acerca tu patrulla al garaje para devolverla.",
                                    {255, 180, 0}
                                )
                            elseif VehicleManager.ReturnPoliceVehicle() then
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
                            openGarageMenu()
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

CreateThread(function()
    while true do
        if not VehicleManager.GarageMenuOpen then
            Wait(250)
        else
            Wait(0)

            local fleet = getPatrolFleet()
            local distanceToGarage = #(
                GetEntityCoords(PlayerPedId())
                    - GARAGE_POSITION
            )

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
