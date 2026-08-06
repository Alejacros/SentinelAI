print("[Sentinel AI] Cargando CaseReviewManager...")

CaseReviewManager = {}

local function notify(message, color)
    Sentinel.Notify(
        "EXPEDIENTE",
        message,
        color or {90, 190, 255}
    )
end

local function normalizeText(value, fallback)
    if value == nil or tostring(value) == "" then
        return fallback or "No registrado"
    end

    return tostring(value)
end

local function getHistory()
    if type(GetCaseHistory) ~= "function" then
        return {}
    end

    local history = GetCaseHistory()

    return type(history) == "table"
        and history
        or {}
end

local function getLatestCase()
    local history = getHistory()

    return history[1]
end

local function findCase(caseId)
    if type(GetCaseById) == "function" then
        local caseData = GetCaseById(caseId)

        if caseData then
            return caseData
        end
    end

    for _, caseData in ipairs(getHistory()) do
        if tonumber(caseData.id) == tonumber(caseId) then
            return caseData
        end
    end

    return nil
end

local function getSuspectSummary(caseData)
    local suspect = caseData.suspect

    if type(suspect) ~= "table" then
        return "Sin sospechoso registrado"
    end

    local outcomeLabels = {
        ARRESTED = "Arrestado",
        NEUTRALIZED = "Neutralizado",
        ESCAPED = "Escapó",
        SURRENDERED = "Se rindió"
    }

    local custodyLabels = {
        DELIVERED = "Entregado en comisaría"
    }

    local outcome =
        outcomeLabels[suspect.outcome]
        or normalizeText(
            suspect.outcome,
            "Sin resultado"
        )

    local custody =
        custodyLabels[suspect.custody]
        or normalizeText(
            suspect.custody,
            nil
        )

    if custody ~= "No registrado" then
        return outcome .. " | " .. custody
    end

    return outcome
end

local function getForceSummary(caseData)
    local force = caseData.useOfForce

    if type(force) ~= "table" then
        return "No registrado"
    end

    local resultLabels = {
        JUSTIFIED = "Justificado",
        UNDER_REVIEW = "Bajo revisión",
        UNKNOWN = "Resultado indeterminado"
    }

    local shooterLabels = {
        SUSPECT = "Sospechoso",
        PLAYER = "Agente",
        BACKUP = "Unidad de apoyo",
        NONE = "Sin disparos"
    }

    local result =
        resultLabels[force.result]
        or normalizeText(
            force.result,
            "No evaluado"
        )

    local firstShot =
        shooterLabels[force.firstShotBy]
        or normalizeText(
            force.firstShotBy,
            "Desconocido"
        )

    return result
        .. " | Primer disparo: "
        .. firstShot
end

local function getProcedureSummary(caseData)
    local procedure = caseData.procedure

    if type(procedure) ~= "table" then
        return "Sin evaluación"
    end

    return string.format(
        "%s — %d/100 | %s",
        normalizeText(
            procedure.grade,
            "N/A"
        ),
        tonumber(procedure.score) or 0,
        normalizeText(
            procedure.description,
            "Sin descripción"
        )
    )
end

local function getEvidenceSummary(caseData)
    if type(caseData.evidence) ~= "table"
        or #caseData.evidence == 0 then

        return "Ninguna"
    end

    local names = {}

    for index, evidenceName in ipairs(
        caseData.evidence
    ) do
        if index > 8 then
            names[#names + 1] = "..."
            break
        end

        names[#names + 1] =
            tostring(evidenceName)
    end

    return table.concat(names, ", ")
end

local function getBodyCamSummary(caseData)
    local bodycam = caseData.bodycam

    if type(bodycam) ~= "table" then
        return "Sin grabación"
    end

    local entries =
        type(bodycam.entries) == "table"
        and #bodycam.entries
        or 0

    return string.format(
        "%d eventos | %d segundos",
        entries,
        tonumber(bodycam.durationSeconds) or 0
    )
end

local function printNotes(caseData)
    local procedure = caseData.procedure

    if type(procedure) ~= "table"
        or type(procedure.notes) ~= "table"
        or #procedure.notes == 0 then

        print("[EXPEDIENTE] Observaciones: ninguna.")
        return
    end

    print("[EXPEDIENTE] Observaciones:")

    for _, note in ipairs(procedure.notes) do
        print(
            "  - " .. tostring(note)
        )
    end
end

local function printBodyCam(caseData)
    local bodycam = caseData.bodycam

    if type(bodycam) ~= "table"
        or type(bodycam.entries) ~= "table"
        or #bodycam.entries == 0 then

        print("[BODYCAM] Sin eventos registrados.")
        return
    end

    print("---------- BODYCAM ----------")

    for _, entry in ipairs(bodycam.entries) do
        print(
            ("[%s] [%s] %s"):format(
                normalizeText(
                    entry.time,
                    "--:--:--"
                ),
                normalizeText(
                    entry.category,
                    "GENERAL"
                ),
                normalizeText(
                    entry.text,
                    ""
                )
            )
        )
    end

    print("-----------------------------")
end

function CaseReviewManager.PrintCase(caseData)
    if type(caseData) ~= "table" then
        notify(
            "No se encontró el expediente.",
            {255, 180, 0}
        )

        return false
    end

    print("")
    print("==========================================")
    print(
        ("SENTINEL — EXPEDIENTE #%04d"):format(
            tonumber(caseData.id) or 0
        )
    )
    print("==========================================")

    print(
        "Código: "
            .. normalizeText(
                caseData.code,
                "000"
            )
    )

    print(
        "Incidente: "
            .. normalizeText(
                caseData.title,
                "Sin identificar"
            )
    )

    print(
        "Inicio: "
            .. normalizeText(
                caseData.startedAt,
                "Sin registro"
            )
    )

    print(
        "Cierre: "
            .. normalizeText(
                caseData.completedAt,
                "Sin registro"
            )
    )

    print(
        "Duración: "
            .. tostring(
                tonumber(
                    caseData.durationSeconds
                ) or 0
            )
            .. " segundos"
    )

    print(
        "XP: "
            .. tostring(
                tonumber(caseData.xp) or 0
            )
    )

    print(
        "Sospechoso: "
            .. getSuspectSummary(caseData)
    )

    print(
        "Testimonio: "
            .. normalizeText(
                caseData.witness,
                "No registrado"
            )
    )

    print(
        "Evidencia: "
            .. getEvidenceSummary(caseData)
    )

    print(
        "Procedimiento: "
            .. getProcedureSummary(caseData)
    )

    print(
        "Uso de fuerza: "
            .. getForceSummary(caseData)
    )

    print(
        "BodyCam: "
            .. getBodyCamSummary(caseData)
    )

    printNotes(caseData)
    printBodyCam(caseData)

    print("==========================================")
    print("")

    local procedure =
        caseData.procedure

    local grade =
        type(procedure) == "table"
        and procedure.grade
        or "N/A"

    local score =
        type(procedure) == "table"
        and tonumber(procedure.score)
        or 0

    notify(
        (
            "Caso #%04d | Código %s\n"
            .. "Nota %s — %d/100\n"
            .. "%s"
        ):format(
            tonumber(caseData.id) or 0,
            normalizeText(
                caseData.code,
                "000"
            ),
            normalizeText(
                grade,
                "N/A"
            ),
            score,
            getSuspectSummary(caseData)
        ),
        {170, 140, 255}
    )

    return true
end

function CaseReviewManager.OpenLatest()
    return CaseReviewManager.PrintCase(
        getLatestCase()
    )
end

function CaseReviewManager.OpenById(caseId)
    return CaseReviewManager.PrintCase(
        findCase(caseId)
    )
end

RegisterCommand(
    "lastcase",
    function()
        CaseReviewManager.OpenLatest()
    end,
    false
)

RegisterCommand(
    "casebrief",
    function(_, args)
        local caseId =
            tonumber(args and args[1])

        if not caseId then
            notify(
                "Uso: /casebrief ID",
                {255, 180, 0}
            )

            return
        end

        CaseReviewManager.OpenById(caseId)
    end,
    false
)

RegisterCommand(
    "casecount",
    function()
        notify(
            (
                "Expedientes archivados: %d"
            ):format(
                #getHistory()
            ),
            {90, 190, 255}
        )
    end,
    false
)

print("[Sentinel AI] CaseReviewManager listo.")