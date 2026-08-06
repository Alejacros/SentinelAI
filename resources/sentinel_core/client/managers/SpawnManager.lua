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

    NetworkResurrectLocalPlayer(
        stationSpawn.x,
        stationSpawn.y,
        stationSpawn.z,
        stationSpawn.w,
        true,
        false
    )

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