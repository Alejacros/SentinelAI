local interactionLocked = false
local warningCooldown = 0

local witnessStatements = {
    "Vi un vehículo salir a toda velocidad hacia el norte.",
    "Escuché un fuerte impacto y después vi a alguien escapar.",
    "La persona involucrada parecía muy nerviosa.",
    "No vi su rostro, pero llevaba ropa oscura."
}

local function showHelp(message)
    BeginTextCommandDisplayHelp("STRING")

    AddTextComponentSubstringPlayerName(
        message
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

    if not IsDynamicSceneSafe() then
        local currentTime = GetGameTimer()

        if currentTime >= warningCooldown then
            warningCooldown =
                currentTime + 3000

            Sentinel.Notify(
                "CENTRAL",
                GetDynamicSceneObjective(),
                {255, 100, 80}
            )
        end

        return
    end

    interactionLocked = true

    local statement =
        witnessStatements[
            math.random(#witnessStatements)
        ]

    if not AddWitnessToCurrentCase(statement) then
        Sentinel.Notify(
            "ERROR",
            "No existe un expediente activo.",
            {255, 80, 80}
        )

        interactionLocked = false
        return
    end

    PlayerData.DispatchState = "EVIDENCE"

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

    local evidenceCreated =
        SpawnEvidence()

    if not evidenceCreated then
        PlayerData.DispatchState = "REPORT"

        CompleteCase(0)
        CleanupCrimeScene()
        CompleteCurrentDispatch()
    end

    interactionLocked = false
end

CreateThread(function()
    while true do
        local sleep = 500

        if PlayerData.DispatchState
                == "ON_SCENE"
            and PlayerData.SceneNPC
            and DoesEntityExist(
                PlayerData.SceneNPC
            ) then

            local npcCoords =
                GetEntityCoords(
                    PlayerData.SceneNPC
                )

            local playerCoords =
                GetEntityCoords(
                    PlayerPedId()
                )

            local distance =
                #(playerCoords - npcCoords)

            if distance <= 40.0 then
                sleep = 0

                if distance <= 2.8 then
                    if IsDynamicSceneSafe() then
                        showHelp(
                            "Pulsa ~INPUT_CONTEXT~ para hablar con el testigo."
                        )
                    else
                        showHelp(
                            "La escena no es segura. Controle la situación."
                        )
                    end

                    if IsControlJustPressed(
                        0,
                        38
                    ) then

                        interviewWitness()
                    end
                end
            end
        end

        Wait(sleep)
    end
end)