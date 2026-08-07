SentinelCase = SentinelCase or {
    Current = nil,
    NextId = 1
}

local function getGameDateTime()
    return string.format(
        "Día %02d/%02d - %02d:%02d",
        GetClockDayOfMonth(),
        GetClockMonth() + 1,
        GetClockHours(),
        GetClockMinutes()
    )
end

function CreateCurrentCase(dispatch)
    if type(dispatch) ~= "table" then
        print("[Sentinel AI] ERROR: despacho inválido.")
        return false
    end

    SentinelCase.Current = {
        id = SentinelCase.NextId,
        code = dispatch.code or "000",
        title = dispatch.title or "Incidente sin identificar",
        state = "ACTIVE",

        witness = nil,
        evidence = {},

        suspect = {
            outcome = nil,
            custody = nil
        },

        xp = 0,
        startedAt = getGameDateTime(),
        completedAt = nil,
        startedTimer = GetGameTimer(),
        durationSeconds = 0
    }

    SentinelCase.NextId = SentinelCase.NextId + 1

    print(
        ("[Sentinel AI] Expediente #%04d creado: Código %s - %s")
            :format(
                SentinelCase.Current.id,
                SentinelCase.Current.code,
                SentinelCase.Current.title
            )
    )

    return true
end

function GetCurrentCase()
    return SentinelCase.Current
end

function AddWitnessToCurrentCase(statement)
    if not SentinelCase.Current then
        return false
    end

    SentinelCase.Current.witness = statement
    SentinelCase.Current.state = "EVIDENCE"

    return true
end

function AddEvidenceToCurrentCase(evidenceName)
    if not SentinelCase.Current then
        return false
    end

    SentinelCase.Current.evidence =
        SentinelCase.Current.evidence or {}

    table.insert(
        SentinelCase.Current.evidence,
        evidenceName
    )

    return true
end

function AddSuspectOutcomeToCurrentCase(outcome)
    if not SentinelCase.Current then
        return false
    end

    SentinelCase.Current.suspect =
        SentinelCase.Current.suspect or {}

    SentinelCase.Current.suspect.outcome = outcome

    return true
end

function AddCustodyOutcomeToCurrentCase(outcome)
    if not SentinelCase.Current then
        return false
    end

    SentinelCase.Current.suspect =
        SentinelCase.Current.suspect or {}

    SentinelCase.Current.suspect.custody = outcome

    return true
end

function CompleteCase(xpAmount)
    if not SentinelCase.Current then
        Sentinel.Notify(
            "ERROR",
            "No existe un caso activo para archivar.",
            {255, 80, 80}
        )

        return false
    end

    local completedCase = SentinelCase.Current

    completedCase.state = "COMPLETED"
    completedCase.xp = tonumber(xpAmount) or 0
    completedCase.completedAt = getGameDateTime()

    completedCase.durationSeconds = math.max(
        0,
        math.floor(
            (
                GetGameTimer()
                - (completedCase.startedTimer or GetGameTimer())
            ) / 1000
        )
    )

    if type(ArchiveCase) ~= "function" then
        print("[Sentinel AI] ERROR: ArchiveCase no está disponible.")

        Sentinel.Notify(
            "ERROR",
            "El sistema de historial no está disponible.",
            {255, 80, 80}
        )

        return false
    end

    local success, archived = pcall(
        ArchiveCase,
        completedCase
    )

    if not success or archived ~= true then
        print(
            "[Sentinel AI] ERROR archivando caso: "
                .. tostring(archived)
        )

        return false
    end

    PlayerData.CompletedCases =
        PlayerData.CompletedCases + 1

    SentinelCase.Current = nil

    return true
end

function CancelCurrentCase()
    SentinelCase.Current = nil
end
