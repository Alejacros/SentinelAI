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

        xp = 0,

        startedAt = getGameDateTime(),
        completedAt = nil,

        startedTimer = GetGameTimer(),
        durationSeconds = 0
    }

    SentinelCase.NextId = SentinelCase.NextId + 1

    print(
        ("[Sentinel AI] Caso #%d creado.")
            :format(SentinelCase.Current.id)
    )

    return true
end

function GetCurrentCase()
    return SentinelCase.Current
end

function AddWitnessToCurrentCase(statement)
    if not SentinelCase.Current then
        print("[Sentinel AI] ERROR: no existe un caso actual.")
        return false
    end

    SentinelCase.Current.witness = statement
    SentinelCase.Current.state = "EVIDENCE"

    return true
end

function AddEvidenceToCurrentCase(evidenceName)
    if not SentinelCase.Current then
        print(
            "[Sentinel AI] ERROR: no existe un caso para guardar evidencia."
        )

        return false
    end

    table.insert(
        SentinelCase.Current.evidence,
        evidenceName
    )

    return true
end

function CompleteCase(xpAmount)
    if not SentinelCase.Current then
        print(
            "[Sentinel AI] ERROR: CompleteCase sin caso actual."
        )

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

    local archived, result = pcall(
        ArchiveCase,
        completedCase
    )

    if not archived then
        print(
            "[Sentinel AI] ERROR archivando caso: "
                .. tostring(result)
        )

        Sentinel.Notify(
            "ERROR",
            "Falló el almacenamiento del caso. Revise F8.",
            {255, 80, 80}
        )

        return false
    end

    if result ~= true then
        print(
            "[Sentinel AI] ERROR: ArchiveCase devolvió false."
        )

        return false
    end

    SentinelCase.Current = nil

    return true
end

function CancelCurrentCase()
    SentinelCase.Current = nil
end