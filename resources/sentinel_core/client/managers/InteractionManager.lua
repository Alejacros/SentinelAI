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
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

local function canInterviewWitness()
    if not PlayerData
        or not PlayerData.SceneNPC
        or not DoesEntityExist(PlayerData.SceneNPC) then

        return false
    end

    if PlayerData.DispatchState == "EVIDENCE"
        or PlayerData.DispatchState == "REPORT"
        or PlayerData.DispatchState == "TRANSPORT" then

        return false
    end

    if not SceneDirector then
        return true
    end

    local safeStates = {
        IDLE = true,
        SAFE = true,
        SUSPECT_ARRESTED = true
    }

    if safeStates[SceneDirector.State] then
        return true
    end

    if IsSuspectArrested
        and IsSuspectArrested() then

        return true
    end

    local suspectState =
        GetSuspectState
        and GetSuspectState()
        or "NONE"

    local resolvedSuspectStates = {
        NONE = true,
        ARRESTED = true,
        NEUTRALIZED = true,
        ESCAPED = true
    }

    return resolvedSuspectStates[suspectState] == true
end

local function interviewWitness()
    if interactionLocked then
        return
    end

    if not canInterviewWitness() then
        local now = GetGameTimer()

        if now >= warningCooldown then
            warningCooldown = now + 3000

            local objective =
                GetDynamicSceneObjective
                and GetDynamicSceneObjective()
                or "Controle la situación antes de entrevistar al testigo."

            Sentinel.Notify(
                "CENTRAL",
                objective,
                {255, 100, 80}
            )
        end

        return
    end

    interactionLocked = true

    local statement =
        witnessStatements[math.random(#witnessStatements)]

    if not AddWitnessToCurrentCase(statement) then
        Sentinel.Notify(
            "ERROR",
            "No existe un expediente activo para guardar el testimonio.",
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

    local evidenceCreated = SpawnEvidence()

    if not evidenceCreated then
        Sentinel.Notify(
            "ERROR",
            "No fue posible generar la evidencia.",
            {255, 80, 80}
        )

        PlayerData.DispatchState = "ON_SCENE"
        interactionLocked = false
        return
    end

    interactionLocked = false
end

CreateThread(function()
    while true do
        local sleep = 500

        if PlayerData
            and PlayerData.SceneNPC
            and DoesEntityExist(PlayerData.SceneNPC) then

            local npc =
                PlayerData.SceneNPC

            local npcCoords =
                GetEntityCoords(npc)

            local playerCoords =
                GetEntityCoords(PlayerPedId())

            local distance =
                #(playerCoords - npcCoords)

            if distance <= 35.0 then
                sleep = 0

                if distance <= 3.0 then
                    if canInterviewWitness() then
                        showHelp(
                            "Pulsa ~INPUT_CONTEXT~ para hablar con el testigo."
                        )
                    else
                        showHelp(
                            "La escena no es segura. Controle la situación primero."
                        )
                    end

                    if IsControlJustPressed(0, 38) then
                        interviewWitness()
                    end
                end
            end
        end

        Wait(sleep)
    end
end)