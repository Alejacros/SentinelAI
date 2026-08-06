print("[Sentinel AI] Cargando InteractionManager...")

InteractionManager = {
    Locked = false,
    WitnessInterviewed = false,
    WarningCooldown = 0
}

local witnessStatements = {
    "Vi a una persona salir corriendo del lugar.",
    "Escuché gritos y luego observé al sospechoso escapar.",
    "La persona involucrada parecía muy nerviosa.",
    "No pude ver bien su rostro, pero llevaba ropa oscura.",
    "Vi un vehículo alejarse a gran velocidad.",
    "Todo ocurrió muy rápido. Creo que había más de una persona."
}

local function notify(title, message, color)
    Sentinel.Notify(
        title,
        message,
        color or {255, 255, 255}
    )
end

local function showHelp(message)
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

local function getWitness()
    if not PlayerData then
        return nil
    end

    local witness = PlayerData.SceneNPC

    if witness
        and witness ~= 0
        and DoesEntityExist(witness) then

        return witness
    end

    return nil
end

local function getSuspectStateSafe()
    if type(GetSuspectState) == "function" then
        return GetSuspectState() or "NONE"
    end

    return "NONE"
end

local function sceneHasUnresolvedThreat()
    local suspectState = getSuspectStateSafe()

    local resolvedSuspectStates = {
        NONE = true,
        ARRESTED = true,
        NEUTRALIZED = true,
        ESCAPED = true
    }

    if resolvedSuspectStates[suspectState] then
        return false
    end

    if type(IsSuspectArrested) == "function"
        and IsSuspectArrested() then

        return false
    end

    if not SceneDirector then
        return false
    end

    local dangerousDirectorStates = {
        ACTIVE_THREAT = true,
        SUSPECT_FLEEING = true,
        ACTIVE_DISTURBANCE = true
    }

    return dangerousDirectorStates[
        SceneDirector.State
    ] == true
end

local function canInterviewWitness()
    if InteractionManager.WitnessInterviewed then
        return false
    end

    if not getWitness() then
        return false
    end

    if not PlayerData then
        return false
    end

    -- Solo permitimos la entrevista durante la fase de escena.
    if PlayerData.DispatchState ~= "ON_SCENE" then
        return false
    end

    return not sceneHasUnresolvedThreat()
end

local function removeWitnessIndicators()
    if PlayerData.SceneBlip
        and DoesBlipExist(PlayerData.SceneBlip) then

        RemoveBlip(PlayerData.SceneBlip)
    end

    PlayerData.SceneBlip = nil
end

local function spawnEvidenceSafely()
    print(
        "[Sentinel AI] Solicitando evidencia | "
            .. "EvidenceManager = "
            .. type(EvidenceManager)
            .. " | SpawnEvidence = "
            .. type(SpawnEvidence)
    )

    if EvidenceManager
        and type(EvidenceManager.Spawn) == "function" then

        return EvidenceManager.Spawn()
    end

    if type(SpawnEvidence) == "function" then
        return SpawnEvidence()
    end

    notify(
        "ERROR",
        "El sistema de evidencia no está disponible.",
        {255, 80, 80}
    )

    print(
        "[Sentinel AI] ERROR: no existe EvidenceManager.Spawn ni SpawnEvidence."
    )

    return false
end

local function interviewWitness()
    if InteractionManager.Locked
        or InteractionManager.WitnessInterviewed then

        return
    end

    if not canInterviewWitness() then
        local now = GetGameTimer()

        if now >= InteractionManager.WarningCooldown then
            InteractionManager.WarningCooldown =
                now + 2500

            if sceneHasUnresolvedThreat() then
                local objective =
                    type(GetDynamicSceneObjective) == "function"
                    and GetDynamicSceneObjective()
                    or "Controle la amenaza antes de entrevistar al testigo."

                notify(
                    "CENTRAL",
                    objective,
                    {255, 100, 80}
                )
            end
        end

        return
    end

    InteractionManager.Locked = true

    local statement =
        witnessStatements[
            math.random(#witnessStatements)
        ]

    if type(AddWitnessToCurrentCase) ~= "function"
        or not AddWitnessToCurrentCase(statement) then

        notify(
            "ERROR",
            "No existe un expediente activo para registrar el testimonio.",
            {255, 80, 80}
        )

        print(
            "[Sentinel AI] ERROR: no fue posible guardar el testimonio."
        )

        InteractionManager.Locked = false
        return
    end

    InteractionManager.WitnessInterviewed = true
    PlayerData.DispatchState = "EVIDENCE"

    removeWitnessIndicators()

    notify(
        "TESTIGO",
        statement,
        {255, 255, 0}
    )

    notify(
        "CENTRAL",
        "Testimonio registrado. Busque y recoja la evidencia.",
        {0, 255, 120}
    )

    local evidenceCreated =
        spawnEvidenceSafely()

    print(
        "[Sentinel AI] Resultado al generar evidencia: "
            .. tostring(evidenceCreated)
    )

    if not evidenceCreated then
        InteractionManager.WitnessInterviewed = false
        PlayerData.DispatchState = "ON_SCENE"

        notify(
            "ERROR",
            "La evidencia no pudo generarse. Puede volver a entrevistar al testigo.",
            {255, 80, 80}
        )
    end

    InteractionManager.Locked = false
end

function InteractionManager.Reset()
    InteractionManager.Locked = false
    InteractionManager.WitnessInterviewed = false
    InteractionManager.WarningCooldown = 0
end

CreateThread(function()
    while true do
        local sleep = 500
        local witness = getWitness()

        if witness
            and not InteractionManager.WitnessInterviewed then

            local witnessCoords =
                GetEntityCoords(witness)

            local playerCoords =
                GetEntityCoords(PlayerPedId())

            local distance =
                #(playerCoords - witnessCoords)

            if distance <= 35.0 then
                sleep = 0

                if distance <= 3.0 then
                    if PlayerData.DispatchState ~= "ON_SCENE" then
                        showHelp(
                            "Espere a que la escena esté activa."
                        )

                    elseif sceneHasUnresolvedThreat() then
                        showHelp(
                            "La escena no es segura. Controle la amenaza primero."
                        )

                    else
                        showHelp(
                            "Pulsa ~INPUT_CONTEXT~ para hablar con el testigo."
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

CreateThread(function()
    local previousDispatchState = nil

    while true do
        Wait(500)

        if PlayerData then
            local currentState =
                PlayerData.DispatchState

            if currentState ~= previousDispatchState then
                if currentState == "WAITING"
                    or currentState == "OFF_DUTY"
                    or currentState == "EN_ROUTE" then

                    InteractionManager.Reset()
                end

                previousDispatchState =
                    currentState
            end
        end
    end
end)

AddEventHandler(
    "onResourceStop",
    function(resourceName)
        if resourceName ~= GetCurrentResourceName() then
            return
        end

        InteractionManager.Reset()
    end
)

print("[Sentinel AI] InteractionManager listo.")