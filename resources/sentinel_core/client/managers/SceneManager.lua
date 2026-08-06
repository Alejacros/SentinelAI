function SpawnCrimeScene()

    local npc = Config.Scene.NPC

    local model = GetHashKey(npc.model)

    RequestModel(model)

    while not HasModelLoaded(model) do
        Wait(0)
    end

    local ped = CreatePed(
        4,
        model,
        npc.coords.x,
        npc.coords.y,
        npc.coords.z - 1.0,
        npc.coords.w,
        true,
        false
    )

    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetEntityInvincible(ped, true)

    PlayerData.SceneNPC = ped

end