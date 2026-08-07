DevManager = {
    TestVehicle = nil,
    TestVehicleModel = nil,
    VehicleLabOpen = false,
    VehicleCategoryIndex = 1,
    VehicleModelIndex = 1,
    NoclipEnabled = false,
    RankOverride = nil
}

local godMode = true
local lastSafePosition = nil

local DEV_VEHICLE_CANDIDATES = {
    {model = "police", label = "Police Cruiser", category = "PATROL", suggestedRole = "PATROL"},
    {model = "police2", label = "Police Cruiser II", category = "PATROL", suggestedRole = "PATROL"},
    {model = "police5", label = "Police Cruiser V", category = "PATROL", suggestedRole = "PATROL"},
    {model = "sheriff", label = "Sheriff Cruiser", category = "PATROL", suggestedRole = "PATROL"},
    {model = "police4", label = "Unmarked Cruiser", category = "UNMARKED", suggestedRole = "UNMARKED"},
    {model = "fbi", label = "FIB Sedan", category = "FEDERAL", suggestedRole = "FEDERAL"},
    {model = "fbi2", label = "FIB SUV", category = "FEDERAL", suggestedRole = "FEDERAL"},
    {model = "riot", label = "Police Riot", category = "TACTICAL", suggestedRole = "TACTICAL"},
    {model = "riot2", label = "RCV Armored", category = "ARMORED", suggestedRole = "ARMORED"},
    {model = "police3", label = "Police Interceptor", category = "INTERCEPTOR", suggestedRole = "INTERCEPTOR"},
    {model = "sheriff2", label = "Sheriff SUV", category = "SUV", suggestedRole = "SUPERVISOR"},
    {model = "pranger", label = "Park Ranger", category = "SUV", suggestedRole = "SUPERVISOR"},
    {model = "pbus", label = "Police Prison Bus", category = "TRANSPORT", suggestedRole = "TRANSPORT"},
    {model = "policet", label = "Police Transporter", category = "TRANSPORT", suggestedRole = "TRANSPORT"},
    {model = "policeb", label = "Police Bike", category = "MOTORCYCLE", suggestedRole = "MOTORCYCLE"},
    {model = "policeold1", label = "Legacy Police Cruiser", category = "CANDIDATES", suggestedRole = "PATROL"},
    {model = "policeold2", label = "Legacy Police Rancher", category = "CANDIDATES", suggestedRole = "SUV"}
}

local VEHICLE_LAB_CATEGORIES = {
    {id = "PATROL", models = {}},
    {id = "UNMARKED", models = {}},
    {id = "FEDERAL", models = {}},
    {id = "TACTICAL", models = {}},
    {id = "ARMORED", models = {}},
    {id = "INTERCEPTOR", models = {}},
    {id = "SUV", models = {}},
    {id = "TRANSPORT", models = {}},
    {id = "MOTORCYCLE", models = {}},
    {id = "SERVICE", models = {}},
    {id = "CANDIDATES", models = {}}
}

for _, candidate in ipairs(DEV_VEHICLE_CANDIDATES) do
    for _, category in ipairs(VEHICLE_LAB_CATEGORIES) do
        if category.id == candidate.category then
            category.models[#category.models + 1] = candidate
            break
        end
    end
end

-- Clases internas de GTA utilizadas solo para diagnóstico DEV.
-- No representan categorías operativas de Sentinel.
local VEHICLE_CLASS_NAMES = {
    [0] = "Compacts",
    [1] = "Sedans",
    [2] = "SUVs",
    [3] = "Coupes",
    [4] = "Muscle",
    [5] = "Sports Classics",
    [6] = "Sports",
    [7] = "Super",
    [8] = "Motorcycles",
    [9] = "Off-road",
    [10] = "Industrial",
    [11] = "Utility",
    [12] = "Vans",
    [13] = "Cycles",
    [14] = "Boats",
    [15] = "Helicopters",
    [16] = "Planes",
    [17] = "Service",
    [18] = "Emergency",
    [19] = "Military",
    [20] = "Commercial",
    [21] = "Trains"
}

-- Arquitectura futura, deliberadamente no implementada en este sprint:
-- VehicleEquipmentManager abstraerá equipamiento embarcado (radar, ANPR,
-- dashcam, MDT, radio y spotlight). EmergencyVehicleManager abstraerá sirena,
-- luces, PA, horn, takedowns, alley lights y traffic advisor. VehicleManager
-- no dependerá directamente de proveedores externos como Luxart.
-- Categorías objetivo: PATROL SEDAN, PATROL SUV, INTERCEPTOR, SUPERVISOR,
-- UNMARKED, DETECTIVE, FEDERAL / INTELLIGENCE, TACTICAL, ARMORED,
-- PRISONER TRANSPORT, MOTOR UNIT y COMMAND.

local function isDevMode()
    return Config and Config.DevMode == true
end

function GetEffectivePlayerRank()
    if isDevMode() and DevManager.RankOverride then
        return DevManager.RankOverride
    end

    return PlayerData and PlayerData.Rank or "Cadete"
end

local function notify(message)
    if Sentinel and Sentinel.Notify then
        Sentinel.Notify("DEV", message, {255, 180, 0})
    end
end

local function applyGodMode()
    local player = PlayerId()
    local ped = PlayerPedId()

    SetPlayerInvincible(player, godMode)
    SetEntityInvincible(ped, godMode)
    SetEntityCanBeDamaged(ped, not godMode)

    if godMode then
        ClearPedBloodDamage(ped)
        SetEntityHealth(ped, GetEntityMaxHealth(ped))
    end
end

local function teleportSafely(x, y, fallbackZ)
    local ped = PlayerPedId()

    DoScreenFadeOut(300)

    while not IsScreenFadedOut() do
        Wait(0)
    end

    RequestCollisionAtCoord(x, y, fallbackZ)

    -- Primero subimos al jugador para cargar el terreno.
    SetEntityCoordsNoOffset(
        ped,
        x,
        y,
        1000.0,
        false,
        false,
        false
    )

    FreezeEntityPosition(ped, true)

    local groundFound = false
    local groundZ = fallbackZ

    -- Probamos varias alturas mientras carga la colisión.
    for height = 1000, 0, -25 do
        RequestCollisionAtCoord(x, y, height)

        local found, z = GetGroundZFor_3dCoord(
            x,
            y,
            height + 0.0,
            false
        )

        if found then
            groundFound = true
            groundZ = z + 1.0
            break
        end

        Wait(25)
    end

    if not groundFound then
        groundZ = fallbackZ + 1.0
    end

    SetEntityCoordsNoOffset(
        ped,
        x,
        y,
        groundZ,
        false,
        false,
        false
    )

    local timeout = GetGameTimer() + 3000

    while not HasCollisionLoadedAroundEntity(ped)
        and GetGameTimer() < timeout do

        RequestCollisionAtCoord(x, y, groundZ)
        Wait(50)
    end

    FreezeEntityPosition(ped, false)
    ClearPedTasksImmediately(ped)

    Wait(200)
    DoScreenFadeIn(300)

    return groundFound
end

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

local function getVehicleDisplayName(model)
    local displayKey = GetDisplayNameFromVehicleModel(model)

    if not displayKey or displayKey == "" or displayKey == "CARNOTFOUND" then
        return "No disponible"
    end

    local label = GetLabelText(displayKey)

    if not label or label == "" or label == "NULL" then
        return displayKey
    end

    return label
end

local function isVehicleModelAvailable(modelName)
    local model = GetHashKey(tostring(modelName or ""))

    return IsModelInCdimage(model)
        and IsModelValid(model)
        and IsModelAVehicle(model), model
end

local function requestVehicleModel(model)
    RequestModel(model)

    local timeoutAt = GetGameTimer() + 10000

    while not HasModelLoaded(model)
        and GetGameTimer() < timeoutAt do

        Wait(100)
    end

    return HasModelLoaded(model)
end

local function deleteTestVehicle()
    local vehicle = DevManager.TestVehicle

    if not vehicle or vehicle == 0 then
        DevManager.TestVehicle = nil
        DevManager.TestVehicleModel = nil
        return false
    end

    if DoesEntityExist(vehicle) then
        local ped = PlayerPedId()

        if IsPedInVehicle(ped, vehicle, false) then
            TaskLeaveVehicle(ped, vehicle, 16)
            Wait(200)
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
    end

    DevManager.TestVehicle = nil
    DevManager.TestVehicleModel = nil

    return true
end


local function spawnTestVehicle(modelName)
    if not isDevMode() then
        return false, "dev_disabled"
    end

    modelName = tostring(modelName or ""):lower()

    if modelName == "" then
        return false, "missing_model"
    end

    local available, model = isVehicleModelAvailable(modelName)

    if not available then
        return false, "invalid_model"
    end

    if not requestVehicleModel(model) then
        return false, "model_timeout"
    end

    deleteTestVehicle()

    local ped = PlayerPedId()
    local spawnPosition = GetOffsetFromEntityInWorldCoords(
        ped,
        0.0,
        5.0,
        0.5
    )
    local heading = GetEntityHeading(ped)
    local vehicle = CreateVehicle(
        model,
        spawnPosition.x,
        spawnPosition.y,
        spawnPosition.z,
        heading,
        true,
        false
    )

    SetModelAsNoLongerNeeded(model)

    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return false, "spawn_failed"
    end

    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleHasBeenOwnedByPlayer(vehicle, true)
    SetVehicleOnGroundProperly(vehicle)
    SetVehicleEngineOn(vehicle, true, true, false)
    SetVehRadioStation(vehicle, "OFF")
    SetPedIntoVehicle(ped, vehicle, -1)

    DevManager.TestVehicle = vehicle
    DevManager.TestVehicleModel = modelName

    return true, vehicle
end


local function getCurrentTestVehicle()
    local vehicle = DevManager.TestVehicle

    if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
        return vehicle
    end

    return nil
end


local function repairTestVehicle()
    local vehicle = getCurrentTestVehicle()

    if not vehicle then
        return false
    end

    SetVehicleFixed(vehicle)
    SetVehicleDeformationFixed(vehicle)
    SetVehicleEngineHealth(vehicle, 1000.0)
    SetVehicleBodyHealth(vehicle, 1000.0)
    SetVehiclePetrolTankHealth(vehicle, 1000.0)
    SetVehicleDirtLevel(vehicle, 0.0)

    return true
end


local function getPossibleVehicleRole(vehicle, modelName)
    local seats = GetVehicleModelNumberOfSeats(GetEntityModel(vehicle))
    local normalizedModel = tostring(modelName or ""):lower()

    for _, candidate in ipairs(DEV_VEHICLE_CANDIDATES) do
        if candidate.model == normalizedModel then
            return candidate.suggestedRole
        end
    end

    if normalizedModel:find("riot", 1, true)
        or normalizedModel:find("insurgent", 1, true) then

        return "TACTICAL"
    elseif normalizedModel:find("fbi", 1, true)
        or normalizedModel:find("unmark", 1, true) then

        return "UNMARKED"
    elseif normalizedModel:find("suv", 1, true)
        or normalizedModel:find("tahoe", 1, true) then

        return "SUV"
    elseif seats >= 6
        or normalizedModel:find("bus", 1, true)
        or normalizedModel:find("transport", 1, true) then

        return "TRANSPORT"
    elseif normalizedModel:find("interceptor", 1, true)
        or normalizedModel:find("charger", 1, true) then

        return "INTERCEPTOR"
    end

    return "PATROL"
end


local function printVehicleInfo(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then
        notify("No hay un vehículo DEV activo.")
        return false
    end

    local model = GetEntityModel(vehicle)
    local modelName = DevManager.TestVehicleModel or tostring(model)
    local vehicleClass = GetVehicleClass(vehicle)
    local seats = GetVehicleModelNumberOfSeats(model)
    local maxPassengers = GetVehicleMaxNumberOfPassengers(vehicle)
    local coords = GetEntityCoords(vehicle)
    local emergencyClass = vehicleClass == 18
    local hasSiren = emergencyClass

    print("====================================")
    print("[Sentinel AI] DEV VEHICLE INFO")
    print(("spawn=%s | hash=%s"):format(modelName, tostring(model)))
    print(("display=%s"):format(getVehicleDisplayName(model)))
    print(("class=%s (%s)"):format(
        tostring(vehicleClass),
        VEHICLE_CLASS_NAMES[vehicleClass] or "Unknown"
    ))
    print(("seats=%s | maxPassengers=%s"):format(
        tostring(seats),
        tostring(maxPassengers)
    ))
    print(("engineHealth=%.2f | bodyHealth=%.2f"):format(
        GetVehicleEngineHealth(vehicle),
        GetVehicleBodyHealth(vehicle)
    ))
    print(("speed=%.2f m/s | estimatedMaxSpeed=%.2f m/s"):format(
        GetEntitySpeed(vehicle),
        GetVehicleEstimatedMaxSpeed(vehicle)
    ))
    print(("acceleration=%.4f | braking=%.4f | traction=%.4f"):format(
        GetVehicleAcceleration(vehicle),
        GetVehicleMaxBraking(vehicle),
        GetVehicleMaxTraction(vehicle)
    ))
    print(("coords=vector3(%.2f, %.2f, %.2f)"):format(
        coords.x, coords.y, coords.z
    ))
    print(("heading=%.2f"):format(GetEntityHeading(vehicle)))
    print(("nativeSiren=%s | emergencyClass=%s | emergencyLights=%s"):format(
        tostring(hasSiren),
        tostring(emergencyClass),
        tostring(hasSiren or emergencyClass)
    ))
    print(("potentialTransport=%s"):format(tostring(seats > 2)))
    print(("Possible role: %s"):format(
        getPossibleVehicleRole(vehicle, modelName)
    ))
    print("====================================")

    notify("Información técnica impresa en F8.")
    return true
end

local function getSelectedLabModel()
    local category = VEHICLE_LAB_CATEGORIES[
        DevManager.VehicleCategoryIndex
    ]

    if not category then
        return nil, nil
    end

    return category, category.models[DevManager.VehicleModelIndex]
end


local function drawVehicleLab()
    local category, candidate = getSelectedLabModel()
    local modelName = candidate and candidate.model or nil

    DrawRect(0.5, 0.38, 0.56, 0.36, 0, 0, 0, 220)
    drawText("SENTINEL AI - VEHICLE LAB", 0.5, 0.215, 0.48, true)
    drawText(
        ("Categoría: < %s >"):format(category.id),
        0.5,
        0.265,
        0.34,
        true
    )

    if not modelName then
        drawText("CANDIDATES está vacía.", 0.5, 0.335, 0.34, true)
    else
        local available, model = isVehicleModelAvailable(modelName)
        local status = available
            and "~g~VÁLIDO"
            or "~r~NO DISPONIBLE"
        local class = available
            and GetVehicleClassFromName(model)
            or -1
        local seats = available
            and GetVehicleModelNumberOfSeats(model)
            or 0

        drawText(("Spawn: %s"):format(modelName), 0.27, 0.315, 0.32, false)
        drawText(
            ("Nombre: %s | GTA: %s"):format(
                candidate.label,
                available and getVehicleDisplayName(model) or "No disponible"
            ),
            0.27,
            0.355,
            0.30,
            false
        )
        drawText(
            ("Hash: %s | Estado: %s"):format(tostring(model), status),
            0.27,
            0.395,
            0.30,
            false
        )
        drawText(
            ("Clase: %s (%s) | Asientos: %s | Rol: %s"):format(
                tostring(class),
                VEHICLE_CLASS_NAMES[class] or "Unknown",
                tostring(seats),
                candidate.suggestedRole
            ),
            0.27,
            0.435,
            0.30,
            false
        )
    end

    drawText(
        "↑ ↓ modelo   ← → categoría   ENTER spawnear",
        0.5,
        0.505,
        0.27,
        true
    )
    drawText(
        "R reparar   DEL eliminar   ESC cerrar",
        0.5,
        0.54,
        0.27,
        true
    )
end


local function closeVehicleLab()
    DevManager.VehicleLabOpen = false
end


local function setNoclipEnabled(enabled)
    DevManager.NoclipEnabled = enabled == true

    local ped = PlayerPedId()

    FreezeEntityPosition(ped, DevManager.NoclipEnabled)
    SetEntityCollision(ped, not DevManager.NoclipEnabled, true)

    if not DevManager.NoclipEnabled then
        SetEntityVisible(ped, true, false)
    end
end


local function getCameraDirection()
    local rotation = GetGameplayCamRot(2)
    local pitch = math.rad(rotation.x)
    local yaw = math.rad(rotation.z)
    local horizontal = math.abs(math.cos(pitch))

    return vector3(
        -math.sin(yaw) * horizontal,
        math.cos(yaw) * horizontal,
        math.sin(pitch)
    )
end


RegisterCommand("devcar", function(_, args)
    if not isDevMode() then
        return
    end

    local modelName = args[1]
    local spawned, errorCode = spawnTestVehicle(modelName)

    if spawned then
        notify(("Vehículo DEV creado: %s"):format(modelName))
    else
        notify(("No fue posible crear el vehículo (%s)."):format(
            errorCode
        ))
    end
end, false)

RegisterCommand("devvehicles", function()
    if not isDevMode() then
        return
    end

    DevManager.VehicleLabOpen = not DevManager.VehicleLabOpen
    DevManager.VehicleCategoryIndex = 1
    DevManager.VehicleModelIndex = 1
end, false)

RegisterCommand("devcarinfo", function()
    if not isDevMode() then
        return
    end

    printVehicleInfo(getCurrentTestVehicle())
end, false)

RegisterCommand("devcarfleet", function()
    if not isDevMode() then
        return
    end

    local vehicle = getCurrentTestVehicle()

    if not vehicle then
        notify("No hay un vehículo DEV activo.")
        return
    end

    local modelName = DevManager.TestVehicleModel
        or tostring(GetEntityModel(vehicle))
    print("{")
    print('    id = "TODO",')
    print('    label = "TODO",')
    print(("    model = \"%s\","):format(modelName))
    print('    minRank = "Cadete",')
    print("    canTransportSuspects = true,")
    print("    transportCapacity = 2,")
    print('    role = "PATROL"')
    print("}")

    notify("Plantilla PoliceFleet impresa en F8.")
end, false)

RegisterCommand("devcardelete", function()
    if not isDevMode() then
        return
    end

    notify(
        deleteTestVehicle()
            and "Vehículo DEV eliminado."
            or "No hay un vehículo DEV activo."
    )
end, false)

RegisterCommand("devcarfix", function()
    if not isDevMode() then
        return
    end

    notify(
        repairTestVehicle()
            and "Vehículo DEV reparado."
            or "No hay un vehículo DEV activo."
    )
end, false)

RegisterCommand("devcoords", function()
    if not isDevMode() then
        return
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    print(("vector3(%.2f, %.2f, %.2f)"):format(
        coords.x, coords.y, coords.z
    ))
    print(("vector4(%.2f, %.2f, %.2f, %.2f)"):format(
        coords.x, coords.y, coords.z, heading
    ))
    notify("Coordenadas impresas en F8.")
end, false)

RegisterCommand("devgarage", function(_, args)
    if not isDevMode() then
        return
    end

    local requestedId = tostring(args[1] or ""):upper()
    local aliases = {
        MISSION = "MISSION_ROW",
        CENTRAL = "CENTRAL",
        SANDY = "SANDY",
        PALETO = "PALETO"
    }
    local garage = VehicleManager
        and VehicleManager.GetGarageById
        and VehicleManager.GetGarageById(aliases[requestedId])

    if not garage then
        notify("Usa /devgarage mission|central|sandy|paleto.")
        return
    end

    teleportSafely(
        garage.interaction.x,
        garage.interaction.y,
        garage.interaction.z
    )
    notify(("Teletransporte DEV: %s."):format(garage.label))
end, false)

RegisterCommand("devtp", function()
    if not isDevMode() then
        return
    end

    local waypoint = GetFirstBlipInfoId(8)

    if not DoesBlipExist(waypoint) then
        notify("Marca primero un destino en el mapa.")
        return
    end

    local coords = GetBlipInfoIdCoord(waypoint)
    teleportSafely(coords.x, coords.y, coords.z)
    notify("Teletransporte al waypoint completado.")
end, false)

RegisterCommand("devheal", function()
    if not isDevMode() then
        return
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    NetworkResurrectLocalPlayer(
        coords.x,
        coords.y,
        coords.z,
        GetEntityHeading(ped),
        true,
        false
    )

    ClearPedTasksImmediately(ped)
    ClearPedBloodDamage(ped)
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    notify("Salud restaurada.")
end, false)

RegisterCommand("devnoclip", function()
    if not isDevMode() then
        return
    end

    setNoclipEnabled(not DevManager.NoclipEnabled)
    notify(
        DevManager.NoclipEnabled
            and "Noclip activado."
            or "Noclip desactivado."
    )
end, false)

local DEV_RANK_ALIASES = {
    cadete = "Cadete",
    oficial = "Oficial",
    oficial2 = "Oficial II",
    cabo = "Cabo",
    sargento = "Sargento",
    subteniente = "Subteniente",
    teniente = "Teniente",
    capitan = "Capitan",
    mayor = "Mayor",
    general = "General",
    brigadier = "Brigadier General",
    comandante = "Comandante General"
}

local function refreshGarageAfterRankOverride()
    if VehicleManager
        and VehicleManager.RefreshGarageFleetForEffectiveRank then

        VehicleManager.RefreshGarageFleetForEffectiveRank()
    end
end

RegisterCommand("devrank", function(_, args)
    if not isDevMode() then
        return
    end

    local alias = tostring(args[1] or ""):lower()

    if alias == "" then
        print(("Rango real: %s"):format(PlayerData.Rank))
        print(("Rango DEV efectivo: %s"):format(
            GetEffectivePlayerRank()
        ))
        notify(("Rango real: %s | efectivo: %s"):format(
            PlayerData.Rank,
            GetEffectivePlayerRank()
        ))
        return
    end

    if alias == "reset" then
        DevManager.RankOverride = nil
        refreshGarageAfterRankOverride()
        notify("Usando rango real nuevamente.")
        return
    end

    local rankName = DEV_RANK_ALIASES[alias]

    if not rankName or not GetRankIndex(rankName) then
        notify("Alias de rango inválido. Usa /devrank sin argumentos.")
        return
    end

    DevManager.RankOverride = rankName
    refreshGarageAfterRankOverride()
    notify(("Rango temporal cambiado a %s."):format(rankName))
end, false)

RegisterCommand("devstate", function()
    if not isDevMode() then
        return
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local garage = VehicleManager
        and VehicleManager.GetActiveGarage
        and VehicleManager.GetActiveGarage()
    local vehicle = PlayerData.Vehicle
    local vehicleExists = vehicle
        and vehicle ~= 0
        and DoesEntityExist(vehicle)
        or false
    local distanceToVehicle = vehicleExists
        and #(coords - GetEntityCoords(vehicle))
        or nil
    local vehicleDriver = vehicleExists
        and GetPedInVehicleSeat(vehicle, -1)
        or 0
    local characterModel = PlayerData.Character
        and PlayerData.Character.appearance
        and PlayerData.Character.appearance.bodyModel
        or GetEntityModel(ped)

    print("====================================")
    print("[Sentinel AI] DEV STATE")
    print(("Rank real: %s"):format(tostring(PlayerData.Rank)))
    print(("Rank efectivo: %s"):format(GetEffectivePlayerRank()))
    print(("XP: %s"):format(tostring(PlayerData.XP)))
    print(("OnDuty: %s"):format(tostring(PlayerData.OnDuty)))
    print(("DispatchState: %s"):format(
        tostring(PlayerData.DispatchState)
    ))
    print(("VehicleState: %s"):format(
        tostring(VehicleManager and VehicleManager.VehicleState)
    ))
    print(("PreRecoveryState: %s"):format(
        tostring(VehicleManager and VehicleManager.PreRecoveryState)
    ))
    print(("RECOVERY_PENDING: %s"):format(tostring(
        VehicleManager
            and VehicleManager.VehicleState == "RECOVERY_PENDING"
            or false
    )))
    print(("Active vehicle: %s | exists=%s"):format(
        tostring(vehicle),
        tostring(vehicleExists)
    ))
    print(("Distance to vehicle: %s"):format(
        distanceToVehicle
            and ("%.2f m"):format(distanceToVehicle)
            or "N/A"
    ))
    print(("Vehicle driver: %s | player=%s"):format(
        tostring(vehicleDriver),
        tostring(vehicleDriver ~= 0 and IsPedAPlayer(vehicleDriver))
    ))
    print(("Active garage: %s"):format(
        garage and garage.label or "Ninguno"
    ))
    print(("Character model: %s"):format(
        tostring(characterModel)
    ))
    print(("Coords: vector4(%.2f, %.2f, %.2f, %.2f)"):format(
        coords.x,
        coords.y,
        coords.z,
        GetEntityHeading(ped)
    ))
    print("====================================")
    notify("Estado DEV impreso en F8.")
end, false)

RegisterCommand("devhelp", function()
    if not isDevMode() then
        return
    end

    print("====================================")
    print("SENTINEL AI - HERRAMIENTAS DEV")

    for _, commandData in ipairs(SentinelCommands or {}) do
        if commandData.devOnly then
            local usage = commandData.usage
                and (" " .. commandData.usage)
                or ""

            print(("/%s%s - %s"):format(
                commandData.command,
                usage,
                commandData.description
            ))
        end
    end

    print("")
    print("CONTROLES DE /devvehicles")
    print("↑ ↓ vehículo")
    print("← → categoría")
    print("ENTER crear")
    print("R reparar")
    print("DEL eliminar")
    print("ESC cerrar")
    print("====================================")

    notify("Ayuda DEV impresa en F8.")
end, false)

RegisterCommand("god", function()
    if not isDevMode() then
        return
    end

    godMode = not godMode
    applyGodMode()

    notify(
        godMode
            and "Modo dios activado."
            or "Modo dios desactivado."
    )
end, false)

RegisterCommand("heal", function()
    if not isDevMode() then
        return
    end

    local ped = PlayerPedId()

    NetworkResurrectLocalPlayer(
        GetEntityCoords(ped),
        GetEntityHeading(ped),
        true,
        false
    )

    ClearPedTasksImmediately(ped)
    ClearPedBloodDamage(ped)
    SetEntityHealth(ped, GetEntityMaxHealth(ped))

    notify("Salud restaurada.")
end, false)

RegisterCommand("savepos", function()
    if not isDevMode() then
        return
    end

    local ped = PlayerPedId()

    lastSafePosition = {
        coords = GetEntityCoords(ped),
        heading = GetEntityHeading(ped)
    }

    notify("Posición de desarrollo guardada.")
end, false)

RegisterCommand("back", function()
    if not isDevMode() then
        return
    end

    if not lastSafePosition then
        notify("Primero usa /savepos.")
        return
    end

    teleportSafely(
        lastSafePosition.coords.x,
        lastSafePosition.coords.y,
        lastSafePosition.coords.z
    )

    SetEntityHeading(
        PlayerPedId(),
        lastSafePosition.heading
    )

    notify("Regresaste a la posición guardada.")
end, false)

RegisterCommand("tpdispatch", function()
    if not isDevMode() then
        return
    end

    if not PlayerData
        or not PlayerData.CurrentDispatch
        or not PlayerData.CurrentDispatch.location then

        notify("No hay un despacho activo.")
        return
    end

    if PlayerData.DispatchState ~= "EN_ROUTE"
        and PlayerData.DispatchState ~= "ON_SCENE" then

        notify("Primero acepta el despacho con Y.")
        return
    end

    local location = PlayerData.CurrentDispatch.location

    local groundFound = teleportSafely(
        location.x,
        location.y,
        location.z
    )

    if groundFound then
        notify("Teletransportada al incidente.")
    else
        notify(
            "Teletransporte realizado usando la altura configurada."
        )
    end
end, false)

CreateThread(function()
    while true do
        if not isDevMode() or not DevManager.VehicleLabOpen then
            Wait(250)
        else
            Wait(0)
            drawVehicleLab()

            local category = VEHICLE_LAB_CATEGORIES[
                DevManager.VehicleCategoryIndex
            ]

            if IsControlJustPressed(0, 174) then
                DevManager.VehicleCategoryIndex =
                    DevManager.VehicleCategoryIndex - 1

                if DevManager.VehicleCategoryIndex < 1 then
                    DevManager.VehicleCategoryIndex =
                        #VEHICLE_LAB_CATEGORIES
                end

                DevManager.VehicleModelIndex = 1
            elseif IsControlJustPressed(0, 175) then
                DevManager.VehicleCategoryIndex =
                    DevManager.VehicleCategoryIndex + 1

                if DevManager.VehicleCategoryIndex
                    > #VEHICLE_LAB_CATEGORIES then

                    DevManager.VehicleCategoryIndex = 1
                end

                DevManager.VehicleModelIndex = 1
            elseif #category.models > 0
                and IsControlJustPressed(0, 172) then

                DevManager.VehicleModelIndex =
                    DevManager.VehicleModelIndex - 1

                if DevManager.VehicleModelIndex < 1 then
                    DevManager.VehicleModelIndex = #category.models
                end
            elseif #category.models > 0
                and IsControlJustPressed(0, 173) then

                DevManager.VehicleModelIndex =
                    DevManager.VehicleModelIndex + 1

                if DevManager.VehicleModelIndex > #category.models then
                    DevManager.VehicleModelIndex = 1
                end
            elseif IsControlJustPressed(0, 191) then
                local _, candidate = getSelectedLabModel()
                local modelName = candidate and candidate.model or nil

                if not modelName then
                    notify("La categoría seleccionada está vacía.")
                else
                    local spawned, errorCode =
                        spawnTestVehicle(modelName)

                    notify(
                        spawned
                            and ("Vehículo DEV creado: %s"):format(
                                modelName
                            )
                            or ("Modelo no disponible (%s)."):format(
                                errorCode
                            )
                    )
                end
            elseif IsControlJustPressed(0, 45) then
                notify(
                    repairTestVehicle()
                        and "Vehículo DEV reparado."
                        or "No hay un vehículo DEV activo."
                )
            elseif IsControlJustPressed(0, 214) then
                notify(
                    deleteTestVehicle()
                        and "Vehículo DEV eliminado."
                        or "No hay un vehículo DEV activo."
                )
            elseif IsControlJustPressed(0, 177)
                or IsControlJustPressed(0, 322) then

                closeVehicleLab()
            end
        end
    end
end)

CreateThread(function()
    while true do
        if not isDevMode() then
            if DevManager.NoclipEnabled then
                setNoclipEnabled(false)
            end

            if DevManager.VehicleLabOpen then
                closeVehicleLab()
            end

            Wait(250)
        elseif not DevManager.NoclipEnabled then
            Wait(250)
        else
            Wait(0)

            local ped = PlayerPedId()
            local position = GetEntityCoords(ped)
            local forward = getCameraDirection()
            local right = vector3(forward.y, -forward.x, 0.0)
            local speed = IsControlPressed(0, 21) and 2.0 or 0.5
            local movement = vector3(0.0, 0.0, 0.0)

            if IsControlPressed(0, 32) then
                movement = movement + forward
            end

            if IsControlPressed(0, 33) then
                movement = movement - forward
            end

            if IsControlPressed(0, 34) then
                movement = movement - right
            end

            if IsControlPressed(0, 35) then
                movement = movement + right
            end

            if IsControlPressed(0, 22) then
                movement = movement + vector3(0.0, 0.0, 1.0)
            end

            if IsControlPressed(0, 36) then
                movement = movement - vector3(0.0, 0.0, 1.0)
            end

            SetEntityVelocity(ped, 0.0, 0.0, 0.0)
            SetEntityCoordsNoOffset(
                ped,
                position.x + movement.x * speed,
                position.y + movement.y * speed,
                position.z + movement.z * speed,
                false,
                false,
                false
            )
        end
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    closeVehicleLab()
    deleteTestVehicle()
    setNoclipEnabled(false)
    DevManager.RankOverride = nil
    godMode = false

    local player = PlayerId()
    local ped = PlayerPedId()

    SetPlayerInvincible(player, false)
    SetEntityInvincible(ped, false)
    SetEntityCanBeDamaged(ped, true)
    FreezeEntityPosition(ped, false)
    SetEntityCollision(ped, true, true)
end)

CreateThread(function()
    while true do
        Wait(500)

        if isDevMode() and godMode then
            applyGodMode()

            ClearPlayerWantedLevel(PlayerId())
            SetPlayerWantedLevel(PlayerId(), 0, false)
            SetPlayerWantedLevelNow(PlayerId(), false)
        end
    end
end)
