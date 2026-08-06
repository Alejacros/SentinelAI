print("[Sentinel AI] Cargando MissionManager...")

MissionManager = {
    Active = false,
    Cleaning = false,
    MissionId = 0,
    StartedAt = 0,
    LastEndReason = nil
}

local function notify(message, color)
    Sentinel.Notify(
        "SENTINEL",
        message,
        color or {90, 190, 255}
    )
end

local function safeCall(name, callback)
    if type(callback) ~= "function" then
        return false
    end

    local success, result =
        pcall(callback)

    if not success then
        print(
            ("[MissionManager] ERROR en %s: %s")
                :format(
                    name,
                    tostring(result)
                )
        )

        return false
    end

    return true
end

local function removeSceneBlip()
    if not PlayerData then
        return
    end

    if PlayerData.SceneBlip
        and DoesBlipExist(PlayerData.SceneBlip) then

        RemoveBlip(PlayerData.SceneBlip)
    end

    PlayerData.SceneBlip = nil
end

local function removeDispatchBlip()
    if not PlayerData then
        return
    end

    if PlayerData.DispatchBlip
        and DoesBlipExist(PlayerData.DispatchBlip) then

        RemoveBlip(PlayerData.DispatchBlip)
    end

    PlayerData.DispatchBlip = nil
    SetWaypointOff()
end

local function cleanupCustody()
    if not CustodySystem then
        return
    end

    if CustodySystem.StationBlip
        and DoesBlipExist(
            CustodySystem.StationBlip
        ) then

        RemoveBlip(
            CustodySystem.StationBlip
        )
    end

    CustodySystem.Active = false
    CustodySystem.Escorting = false
    CustodySystem.Suspect = nil
    CustodySystem.Vehicle = nil
    CustodySystem.StationBlip = nil
end

local function cleanupManagers(reason)
    safeCall(
        "EvidenceManager.Remove",
        function()
            if EvidenceManager
                and type(EvidenceManager.Remove)
                    == "function" then

                EvidenceManager.Remove()

            elseif type(RemoveActiveEvidence)
                == "function" then

                RemoveActiveEvidence()
            end
        end
    )

    safeCall(
        "InteractionManager.Reset",
        function()
            if InteractionManager
                and type(InteractionManager.Reset)
                    == "function" then

                InteractionManager.Reset()
            end
        end
    )

    safeCall(
        "PoliceAIManager.Clear",
        function()
            if PoliceAIManager
                and type(PoliceAIManager.Clear)
                    == "function" then

                PoliceAIManager.Clear()
            end
        end
    )

    safeCall(
        "CleanupCrimeScene",
        function()
            if type(CleanupCrimeScene)
                == "function" then

                CleanupCrimeScene()
            end
        end
    )

    safeCall(
        "CleanupDynamicScene",
        function()
            if type(CleanupDynamicScene)
                == "function" then

                CleanupDynamicScene()
            end
        end
    )

    safeCall(
        "SceneBuilder.Reset",
        function()
            if SceneBuilder
                and type(SceneBuilder.Reset)
                    == "function" then

                SceneBuilder.Reset()
            end
        end
    )

    safeCall(
        "BodyCamManager.Stop",
        function()
            if BodyCamManager
                and BodyCamManager.Active
                and type(BodyCamManager.Stop)
                    == "function" then

                BodyCamManager.Stop(
                    reason or "Misión finalizada."
                )
            end
        end
    )

    safeCall(
        "ProcedureManager.Reset",
        function()
            if ProcedureManager
                and type(ProcedureManager.Reset)
                    == "function" then

                ProcedureManager.Reset()
            end
        end
    )

    safeCall(
        "UseOfForceManager.Reset",
        function()
            if UseOfForceManager
                and type(UseOfForceManager.Reset)
                    == "function" then

                UseOfForceManager.Reset()
            end
        end
    )

    safeCall(
        "CustodySystem",
        cleanupCustody
    )

    safeCall(
        "SuspectSystem",
        function()
            if SuspectSystem then
                SuspectSystem.Entity = nil
                SuspectSystem.State = "NONE"
                SuspectSystem.PreviousDirectorState = nil
                SuspectSystem.OutcomeRecorded = false
                SuspectSystem.LastOrderAt = 0
                SuspectSystem.OrderCount = 0
            end
        end
    )

    removeSceneBlip()
    removeDispatchBlip()
end

function MissionManager.StartMission()
    if MissionManager.Cleaning then
        return false
    end

    if MissionManager.Active then
        MissionManager.EndMission(
            "Reinicio preventivo antes de una nueva misión.",
            true
        )
    end

    MissionManager.Active = true
    MissionManager.MissionId =
        MissionManager.MissionId + 1

    MissionManager.StartedAt =
        GetGameTimer()

    MissionManager.LastEndReason = nil

    print(
        ("[MissionManager] Misión #%d iniciada.")
            :format(
                MissionManager.MissionId
            )
    )

    return true
end

function MissionManager.EndMission(
    reason,
    preserveDispatchState
)
    if MissionManager.Cleaning then
        return false
    end

    MissionManager.Cleaning = true

    reason =
        reason or "Misión finalizada."

    print(
        "[MissionManager] Finalizando misión: "
            .. tostring(reason)
    )

    cleanupManagers(reason)

    if type(CancelCurrentCase)
        == "function" then

        CancelCurrentCase()
    end

    if PlayerData then
        PlayerData.SceneNPC = nil
        PlayerData.SceneBlip = nil
        PlayerData.CurrentDispatch = nil

        if not preserveDispatchState then
            PlayerData.DispatchState =
                PlayerData.OnDuty
                and "WAITING"
                or "OFF_DUTY"
        end
    end

    MissionManager.Active = false
    MissionManager.StartedAt = 0
    MissionManager.LastEndReason = reason
    MissionManager.Cleaning = false

    print(
        "[MissionManager] Limpieza completada."
    )

    return true
end

function MissionManager.AbortMission(reason)
    if not MissionManager.Active
        and (
            not PlayerData
            or not PlayerData.CurrentDispatch
        ) then

        notify(
            "No existe un incidente activo.",
            {255, 180, 0}
        )

        return false
    end

    MissionManager.EndMission(
        reason or "Incidente cancelado por la agente."
    )

    notify(
        "Incidente cancelado. Unidad disponible.",
        {255, 180, 0}
    )

    return true
end

function MissionManager.GetStatus()
    return {
        active = MissionManager.Active,
        cleaning = MissionManager.Cleaning,
        missionId = MissionManager.MissionId,

        elapsedSeconds =
            MissionManager.Active
            and math.floor(
                (
                    GetGameTimer()
                    - MissionManager.StartedAt
                ) / 1000
            )
            or 0,

        lastEndReason =
            MissionManager.LastEndReason
    }
end

RegisterCommand(
    "cancelincident",
    function()
        MissionManager.AbortMission(
            "Incidente cancelado manualmente."
        )
    end,
    false
)

RegisterCommand(
    "resetmission",
    function()
        MissionManager.EndMission(
            "Reinicio técnico de la misión."
        )

        notify(
            "Estado de misión reiniciado.",
            {90, 190, 255}
        )
    end,
    false
)

RegisterCommand(
    "missionstatus",
    function()
        local status =
            MissionManager.GetStatus()

        notify(
            status.active
                and (
                    "Misión #"
                    .. tostring(status.missionId)
                    .. " activa durante "
                    .. tostring(status.elapsedSeconds)
                    .. " segundos."
                )
                or "No existe una misión activa.",
            {170, 140, 255}
        )
    end,
    false
)

CreateThread(function()
    local previousOnDuty = nil

    while true do
        Wait(500)

        if PlayerData then
            local onDuty =
                PlayerData.OnDuty == true

            if previousOnDuty == nil then
                previousOnDuty = onDuty

            elseif previousOnDuty
                and not onDuty then

                if MissionManager.Active
                    or PlayerData.CurrentDispatch then

                    MissionManager.EndMission(
                        "Fin de turno."
                    )
                end
            end

            previousOnDuty = onDuty
        end
    end
end)

AddEventHandler(
    "onResourceStop",
    function(resourceName)
        if resourceName
            ~= GetCurrentResourceName() then

            return
        end

        if MissionManager.Active then
            cleanupManagers(
                "Recurso detenido."
            )
        end
    end
)

print("[Sentinel AI] MissionManager listo.")