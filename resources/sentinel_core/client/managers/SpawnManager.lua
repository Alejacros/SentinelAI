local stationSpawn = vector4(441.2, -981.9, 30.7, 90.0)

local function spawnAtStation()
    local ped = PlayerPedId()

    DoScreenFadeOut(500)

    while not IsScreenFadedOut() do
        Wait(0)
    end

    RequestCollisionAtCoord(
        stationSpawn.x,
        stationSpawn.y,
        stationSpawn.z
    )

    SetFocusPosAndVel(
        stationSpawn.x,
        stationSpawn.y,
        stationSpawn.z,
        0.0,
        0.0,
        0.0
    )

    SetEntityCoordsNoOffset(
        ped,
        stationSpawn.x,
        stationSpawn.y,
        stationSpawn.z,
        false,
        false,
        false
    )

    FreezeEntityPosition(ped, true)

    local collisionTimeout =
        GetGameTimer() + 10000

    while not HasCollisionLoadedAroundEntity(ped)
        and GetGameTimer() < collisionTimeout do

        RequestCollisionAtCoord(
            stationSpawn.x,
            stationSpawn.y,
            stationSpawn.z
        )

        Wait(100)
    end

    NetworkResurrectLocalPlayer(
        stationSpawn.x,
        stationSpawn.y,
        stationSpawn.z,
        stationSpawn.w,
        true,
        false
    )

    ped = PlayerPedId()

    SetEntityCoordsNoOffset(
        ped,
        stationSpawn.x,
        stationSpawn.y,
        stationSpawn.z,
        false,
        false,
        false
    )

    SetEntityHeading(ped, stationSpawn.w)
    SetEntityCollision(ped, true, true)
    SetEntityVisible(ped, true, false)
    FreezeEntityPosition(ped, false)

    ClearFocus()

    ClearPedTasksImmediately(ped)
    ClearPedBloodDamage(ped)
    SetEntityHealth(ped, GetEntityMaxHealth(ped))

    Wait(500)
    DoScreenFadeIn(500)
end

CreateThread(function()
    while not NetworkIsSessionStarted() do
        Wait(500)
    end

    Wait(1500)

    spawnAtStation()

    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()

    print("[Sentinel AI] Pantalla de carga cerrada. Spawn inicial completado.")
end)

CreateThread(function()
    while true do
        Wait(500)

        local ped = PlayerPedId()

        if IsEntityDead(ped) then
            Wait(2000)
            spawnAtStation()
        end
    end
end)
