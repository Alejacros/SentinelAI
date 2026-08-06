print("[Sentinel AI] Cargando UseOfForceManager...")

UseOfForceManager = {
    Suspect = nil,
    FirstShotBy = "NONE",
    OfficerFired = false,
    SuspectFired = false,
    BackupFired = false,
    Evaluated = false,
    LastCaseId = nil
}

local function notify(message, color)
    Sentinel.Notify(
        "ASUNTOS INTERNOS",
        message,
        color or {255, 180, 0}
    )
end

local function getCurrentCaseSafe()
    if type(GetCurrentCase) ~= "function" then
        return nil
    end

    return GetCurrentCase()
end

local function getActiveSuspectSafe()
    if type(GetActiveSuspect) == "function" then
        local suspect = GetActiveSuspect()

        if suspect
            and DoesEntityExist(suspect) then

            return suspect
        end
    end

    if SceneDirector
        and SceneDirector.Suspect
        and DoesEntityExist(SceneDirector.Suspect) then

        return SceneDirector.Suspect
    end

    return nil
end

local function resetTracking(suspect)
    UseOfForceManager.Suspect = suspect
    UseOfForceManager.FirstShotBy = "NONE"
    UseOfForceManager.OfficerFired = false
    UseOfForceManager.SuspectFired = false
    UseOfForceManager.BackupFired = false
    UseOfForceManager.Evaluated = false

    local currentCase = getCurrentCaseSafe()

    UseOfForceManager.LastCaseId =
        currentCase and currentCase.id or nil
end

local function registerFirstShot(shooter)
    if UseOfForceManager.FirstShotBy ~= "NONE" then
        return
    end

    UseOfForceManager.FirstShotBy = shooter

    print(
        "[Sentinel AI] Primer disparo registrado: "
            .. tostring(shooter)
    )
end

local function didBackupFire()
    if not PoliceAIManager
        or type(PoliceAIManager.Officers) ~= "table" then

        return false
    end

    for _, officer in ipairs(PoliceAIManager.Officers) do
        if officer
            and DoesEntityExist(officer)
            and IsPedShooting(officer) then

            return true
        end
    end

    return false
end

local function storeForceReport(result)
    local currentCase = getCurrentCaseSafe()

    if not currentCase then
        print(
            "[Sentinel AI] No existe expediente para guardar uso de fuerza."
        )

        return false
    end

    currentCase.useOfForce = {
        used = UseOfForceManager.OfficerFired
            or UseOfForceManager.BackupFired,

        firstShotBy =
            UseOfForceManager.FirstShotBy,

        officerFired =
            UseOfForceManager.OfficerFired,

        backupFired =
            UseOfForceManager.BackupFired,

        suspectFired =
            UseOfForceManager.SuspectFired,

        suspectKilled = true,

        result = result,

        recordedAt = GetGameTimer()
    }

    return true
end

local function evaluateForce()
    if UseOfForceManager.Evaluated then
        return
    end

    UseOfForceManager.Evaluated = true

    local result
    local message
    local color

    if UseOfForceManager.FirstShotBy == "SUSPECT" then
        result = "JUSTIFIED"

        message =
            "Uso de fuerza preliminarmente justificado: "
            .. "el sospechoso inició el ataque."

        color = {80, 220, 140}

    elseif UseOfForceManager.FirstShotBy == "PLAYER"
        or UseOfForceManager.FirstShotBy == "BACKUP" then

        result = "UNDER_REVIEW"

        message =
            "Uso de fuerza enviado a revisión: "
            .. "la policía realizó el primer disparo."

        color = {255, 180, 0}

    else
        result = "UNKNOWN"

        message =
            "Sospechoso fallecido. No fue posible determinar "
            .. "quién disparó primero."

        color = {255, 180, 0}
    end

    storeForceReport(result)
    notify(message, color)

    print(
        (
            "[Sentinel AI] Uso de fuerza | "
            .. "Primer disparo: %s | Resultado: %s"
        ):format(
            UseOfForceManager.FirstShotBy,
            result
        )
    )
end

local function monitorShots(suspect)
    local playerPed = PlayerPedId()

    if IsPedShooting(suspect) then
        UseOfForceManager.SuspectFired = true
        registerFirstShot("SUSPECT")
    end

    if IsPedShooting(playerPed) then
        UseOfForceManager.OfficerFired = true
        registerFirstShot("PLAYER")
    end

    if didBackupFire() then
        UseOfForceManager.BackupFired = true
        registerFirstShot("BACKUP")
    end
end

function UseOfForceManager.GetReport()
    local currentCase = getCurrentCaseSafe()

    return currentCase
        and currentCase.useOfForce
        or nil
end

function UseOfForceManager.Reset()
    resetTracking(nil)
    UseOfForceManager.LastCaseId = nil
end

RegisterCommand(
    "forcedebug",
    function()
        local report =
            UseOfForceManager.GetReport()

        if report then
            notify(
                (
                    "Primer disparo: %s | Resultado: %s"
                ):format(
                    report.firstShotBy or "NONE",
                    report.result or "UNKNOWN"
                ),
                {170, 140, 255}
            )

            return
        end

        notify(
            (
                "Seguimiento activo | Primer disparo: %s"
            ):format(
                UseOfForceManager.FirstShotBy
            ),
            {170, 140, 255}
        )
    end,
    false
)

CreateThread(function()
    while true do
        local sleep = 500

        local suspect =
            getActiveSuspectSafe()

        if suspect then
            sleep = 0

            if UseOfForceManager.Suspect ~= suspect then
                resetTracking(suspect)

                print(
                    "[Sentinel AI] Seguimiento de uso de fuerza iniciado."
                )
            end

            if not IsEntityDead(suspect) then
                monitorShots(suspect)

            elseif not UseOfForceManager.Evaluated then
                evaluateForce()
            end

        elseif PlayerData
            and (
                PlayerData.DispatchState == "WAITING"
                or PlayerData.DispatchState == "OFF_DUTY"
            ) then

            if UseOfForceManager.Suspect then
                UseOfForceManager.Reset()
            end
        end

        Wait(sleep)
    end
end)

AddEventHandler(
    "onResourceStop",
    function(resourceName)
        if resourceName ~= GetCurrentResourceName() then
            return
        end

        UseOfForceManager.Reset()
    end
)

print("[Sentinel AI] UseOfForceManager listo.")