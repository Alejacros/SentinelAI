local devMode = true
local godMode = true
local lastSafePosition = nil

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

RegisterCommand("god", function()
    if not devMode then
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
    if not devMode then
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
    if not devMode then
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
    if not devMode then
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
    if not devMode then
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
        Wait(500)

        if devMode and godMode then
            applyGodMode()

            ClearPlayerWantedLevel(PlayerId())
            SetPlayerWantedLevel(PlayerId(), 0, false)
            SetPlayerWantedLevelNow(PlayerId(), false)
        end
    end
end)