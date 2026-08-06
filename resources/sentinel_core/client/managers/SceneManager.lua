local witnessModels = {
    "a_m_m_business_01",
    "a_f_y_business_01",
    "a_m_y_business_02",
    "a_f_y_tourist_01"
}

local sceneDormant = false
local dynamicSceneStarted = false

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
    local visible, screenX, screenY =
        World3dToScreen2d(
            coords.x,
            coords.y,
            coords.z
        )

    if not visible then
        return
    end

    SetTextScale(0.36, 0.36)
    SetTextFont(4)
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
        SetEntityInvincible(npc, false)
        SetEntityCanBeDamaged(npc, true)
        SetPedCanRagdoll(npc, true)
        SetBlockingOfNonTemporaryEvents(npc, false)

        ClearPedTasks(npc)
        TaskWanderStandard(npc, 10.0, 10)
        SetEntityAsNoLongerNeeded(npc)
    end

    PlayerData.SceneBlip = nil
    PlayerData.SceneNPC = nil

    sceneDormant = false
    dynamicSceneStarted = false

    if CleanupDynamicScene then
        CleanupDynamicScene()
    end
end

function SpawnCrimeScene(dispatch, dormant)
    if PlayerData.SceneNPC
        and DoesEntityExist(PlayerData.SceneNPC) then

        return true
    end

    local witnessPosition =
        SceneBuilder.GetWitnessPosition()

    local layout =
        SceneBuilder.GetLayout()

    if not witnessPosition or not layout then
        layout = SceneBuilder.Build(dispatch)
        witnessPosition =
            layout
            and layout.witness
            and layout.witness.position
            or nil
    end

    if not witnessPosition then
        return false
    end

    local modelName =
        witnessModels[math.random(#witnessModels)]

    local model =
        GetHashKey(modelName)

    if not loadModel(model) then
        return false
    end

    RequestCollisionAtCoord(
        witnessPosition.x,
        witnessPosition.y,
        witnessPosition.z
    )

    local npc = CreatePed(
        4,
        model,
        witnessPosition.x,
        witnessPosition.y,
        witnessPosition.z,
        layout.witness.heading or 0.0,
        false,
        false
    )

    if npc == 0
        or not DoesEntityExist(npc) then

        SetModelAsNoLongerNeeded(model)
        return false
    end

    SetEntityAsMissionEntity(
        npc,
        true,
        true
    )

    SetEntityInvincible(npc, true)
    SetEntityCanBeDamaged(npc, false)
    SetPedCanRagdoll(npc, false)
    SetBlockingOfNonTemporaryEvents(npc, true)
    FreezeEntityPosition(npc, true)

    local blip =
        AddBlipForEntity(npc)

    SetBlipSprite(blip, 280)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 1.10)
    SetBlipAsShortRange(blip, false)

    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Testigo")
    EndTextCommandSetBlipName(blip)

    PlayerData.SceneNPC = npc
    PlayerData.SceneBlip = blip

    sceneDormant = dormant == true

    SetEntityVisible(
        npc,
        not sceneDormant,
        false
    )

    SetModelAsNoLongerNeeded(model)

    if not sceneDormant then
        ActivateCrimeScene()
    end

    return true
end

function ActivateCrimeScene()
    if not PlayerData.SceneNPC
        or not DoesEntityExist(PlayerData.SceneNPC) then

        return false
    end

    SetEntityVisible(
        PlayerData.SceneNPC,
        true,
        false
    )

    TaskStartScenarioInPlace(
        PlayerData.SceneNPC,
        "WORLD_HUMAN_STAND_IMPATIENT",
        0,
        true
    )

    sceneDormant = false

    if not dynamicSceneStarted
        and PlayerData.CurrentDispatch then

        StartDynamicScene(
            PlayerData.CurrentDispatch
        )

        dynamicSceneStarted = true
    end

    Sentinel.Notify(
        "CENTRAL",
        "Testigo localizado. Busque el marcador amarillo.",
        {255, 220, 0}
    )

    return true
end

CreateThread(function()
    while true do
        local sleep = 500

        if not sceneDormant
            and PlayerData.SceneNPC
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
                    0.0, 0.0, 0.0,
                    0.0, 180.0, 0.0,
                    0.55, 0.55, 0.55,
                    255, 220, 0, 255,
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