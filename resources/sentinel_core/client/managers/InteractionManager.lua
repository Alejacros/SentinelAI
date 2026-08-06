local interactionLocked = false

local witnessStatements = {
    "Vi un vehículo salir a toda velocidad hacia el norte.",
    "Escuché un fuerte impacto y después vi a alguien escapar.",
    "La persona involucrada parecía muy nerviosa.",
    "No vi su rostro, pero llevaba ropa oscura."
}

local function showInteractionHelp()
    BeginTextCommandDisplayHelp("STRING")

    AddTextComponentSubstringPlayerName(
        "Pulsa ~INPUT_CONTEXT~ para hablar con el testigo."
    )

    EndTextCommandDisplayHelp(
        0,
        false,
        true,
        -1
    )
end

local function interviewWitness()
    if interactionLocked then
        return
    end

    interactionLocked = true
    PlayerData.DispatchState = "EVIDENCE"

    local statement =
        witnessStatements[math.random(#witnessStatements)]

    Sentinel.Notify(
        "TESTIGO",
        statement,
        {255, 255, 0}
    )

    Sentinel.Notify(
        "CENTRAL",
        "Revise el área y recoja la evidencia.",
        {0, 255, 120}
    )

    local evidenceCreated = SpawnEvidence()

    if not evidenceCreated then
        PlayerData.DispatchState = "REPORT"

        CleanupCrimeScene()
        CompleteCurrentDispatch()
    end

    interactionLocked = false
end

CreateThread(function()
    while true do
        local sleep = 500

        if PlayerData.SceneNPC
            and DoesEntityExist(PlayerData.SceneNPC)
            and PlayerData.DispatchState == "ON_SCENE" then

            local npcCoords =
                GetEntityCoords(PlayerData.SceneNPC)

            local playerCoords =
                GetEntityCoords(PlayerPedId())

            local distance =
                #(playerCoords - npcCoords)

            if distance <= 40.0 then
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
                    0.5,
                    0.5,
                    0.5,
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

                if distance <= 2.5 then
                    showInteractionHelp()

                    if IsControlJustPressed(0, 38) then
                        interviewWitness()
                    end
                end
            end
        end

        Wait(sleep)
    end
end)