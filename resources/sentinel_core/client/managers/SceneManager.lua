local witnessModels = {
    "a_m_m_business_01",
    "a_f_y_business_01",
    "a_m_y_business_02",
    "a_f_y_tourist_01"
}

local function loadModel(model)
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

local function drawWorldText(coords, text)
    local visible, screenX, screenY = World3dToScreen2d(
        coords.x,
        coords.y,
        coords.z
    )

    if not visible then
        return
    end

    SetTextScale(0.36, 0.36)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(255, 220, 0, 255)
    SetTextCentre(true)
    SetTextOutline()

    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(screenX, screenY)
end

function CleanupCrimeScene()
    if PlayerData.SceneBlip
        and DoesBlipExist(PlayerData.SceneBlip) then

        RemoveBlip(PlayerData.SceneBlip)
    end

    if PlayerData.SceneNPC
        and DoesEntityExist(PlayerData.SceneNPC) then

        local npc = PlayerData.SceneNPC

        FreezeEntityPosition(npc, false)
        SetBlockingOfNonTemporaryEvents(npc, false)
        SetEntityInvincible(npc, false)
        SetPedCanRagdoll(npc, true)

        ClearPedTasks(npc)
        TaskWanderStandard(npc, 10.0, 10)
        SetEntityAsNoLongerNeeded(npc)
    end

    PlayerData.SceneBlip = nil
    PlayerData.SceneNPC = nil

    CleanupDynamicScene()
end

function SpawnCrimeScene(dispatch)
    if not dispatch or not dispatch.location then
        Sentinel.Notify(
            "ERROR",
            "No fue posible crear la escena.",
            {255, 80, 80}
        )

        return false
    end

    CleanupCrimeScene()

    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    local spawnPosition = GetOffsetFromEntityInWorldCoords(
        playerPed,
        0.0,
        4.0,
        0.0
    )

    local modelName =
        witnessModels[math.random(#witnessModels)]

    local model = GetHashKey(modelName)

    if not loadModel(model) then
        Sentinel.Notify(
            "ERROR",
            "No fue posible cargar al testigo.",
            {255, 80, 80}
        )

        return false
    end

    RequestCollisionAtCoord(
        spawnPosition.x,
        spawnPosition.y,
        playerCoords.z
    )

    local npc = CreatePed(
        4,
        model,
        spawnPosition.x,
        spawnPosition.y,
        playerCoords.z,
        GetEntityHeading(playerPed) + 180.0,
        false,
        false
    )

    if npc == 0 or not DoesEntityExist(npc) then
        Sentinel.Notify(
            "ERROR",
            "No fue posible crear al testigo.",
            {255, 80, 80}
        )

        return false
    end

    SetEntityAsMissionEntity(npc, true, true)

    SetEntityCoordsNoOffset(
        npc,
        spawnPosition.x,
        spawnPosition.y,
        playerCoords.z,
        false,
        false,
        false
    )

    SetEntityInvincible(npc, true)
    SetEntityCanBeDamaged(npc, false)
    SetBlockingOfNonTemporaryEvents(npc, true)
    SetPedCanRagdoll(npc, false)
    FreezeEntityPosition(npc, true)

    TaskStartScenarioInPlace(
        npc,
        "WORLD_HUMAN_STAND_IMPATIENT",
        0,
        true
    )

    local blip = AddBlipForEntity(npc)

    SetBlipSprite(blip, 280)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 1.15)
    SetBlipAsShortRange(blip, false)

    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Testigo")
    EndTextCommandSetBlipName(blip)

    PlayerData.SceneNPC = npc
    PlayerData.SceneBlip = blip

    SetModelAsNoLongerNeeded(model)

    Sentinel.Notify(
        "CENTRAL",
        "Testigo localizado. Busque el icono rojo y el marcador amarillo.",
        {255, 220, 0}
    )

    StartDynamicScene(dispatch)

    return true
end

CreateThread(function()
    while true do
        local sleep = 500

        if PlayerData.SceneNPC
            and DoesEntityExist(PlayerData.SceneNPC) then

            local npcCoords =
                GetEntityCoords(PlayerData.SceneNPC)

            local playerCoords =
                GetEntityCoords(PlayerPedId())

            local distance =
                #(playerCoords - npcCoords)

            if distance <= 80.0 then
                sleep = 0

                DrawMarker(
                    2,
                    npcCoords.x,
                    npcCoords.y,
                    npcCoords.z + 2.2,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    180.0,
                    0.0,
                    0.55,
                    0.55,
                    0.55,
                    255,
                    220,
                    0,
                    255,
                    false,
                    true,
                    2,
                    false,
                    nil,
                    nil,
                    false
                )

                drawWorldText(
                    vector3(
                        npcCoords.x,
                        npcCoords.y,
                        npcCoords.z + 1.25
                    ),
                    "TESTIGO"
                )
            end
        end

        Wait(sleep)
    end
end)