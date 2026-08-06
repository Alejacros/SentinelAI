local witnessModels = {
    "a_m_m_business_01",
    "a_f_y_business_01",
    "a_m_y_business_02",
    "a_f_y_tourist_01"
}

local function loadModel(model)
    RequestModel(model)

    while not HasModelLoaded(model) do
        Wait(0)
    end
end

function CleanupCrimeScene()
    if PlayerData.SceneBlip and DoesBlipExist(PlayerData.SceneBlip) then
        RemoveBlip(PlayerData.SceneBlip)
    end

    if PlayerData.SceneNPC and DoesEntityExist(PlayerData.SceneNPC) then
        local npc = PlayerData.SceneNPC

        FreezeEntityPosition(npc, false)
        SetBlockingOfNonTemporaryEvents(npc, false)
        SetEntityInvincible(npc, false)

        ClearPedTasks(npc)
        TaskWanderStandard(npc, 10.0, 10)
        SetEntityAsNoLongerNeeded(npc)
    end

    PlayerData.SceneBlip = nil
    PlayerData.SceneNPC = nil
end

function SpawnCrimeScene(dispatch)
    if not dispatch or not dispatch.location then
        Sentinel.Notify(
            "ERROR",
            "No fue posible crear la escena.",
            {255, 80, 80}
        )
        return
    end

    CleanupCrimeScene()

    local location = dispatch.location
    local modelName = witnessModels[math.random(#witnessModels)]
    local model = GetHashKey(modelName)

    loadModel(model)

    local npc = CreatePed(
        4,
        model,
        location.x,
        location.y,
        location.z - 1.0,
        180.0,
        false,
        false
    )

    SetEntityAsMissionEntity(npc, true, true)
    FreezeEntityPosition(npc, true)
    SetBlockingOfNonTemporaryEvents(npc, true)
    SetEntityInvincible(npc, true)

    local blip = AddBlipForEntity(npc)

    SetBlipSprite(blip, 280)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 1.0)
    SetBlipAsShortRange(blip, false)

    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Testigo")
    EndTextCommandSetBlipName(blip)

    PlayerData.SceneNPC = npc
    PlayerData.SceneBlip = blip

    SetModelAsNoLongerNeeded(model)

    Sentinel.Notify(
        "CENTRAL",
        "Persona de interés localizada. Busque el icono rojo.",
        {255, 220, 0}
    )
end