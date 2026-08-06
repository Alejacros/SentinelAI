print("[Sentinel AI] Cargando ProcedureManager...")

ProcedureManager = {
    Active = false,
    CaseId = nil,
    StartedAt = 0,
    ArrivedAt = 0,
    FinishedAt = 0,

    LastDispatchState = nil,
    LastSuspectState = nil,

    Checklist = {},
    Evaluated = false
}

local DEFAULT_CHECKLIST = {
    dispatchAccepted = false,
    arrivedOnScene = false,
    responseSeconds = 0,

    threatResolved = false,
    suspectArrested = false,
    suspectEscaped = false,
    suspectNeutralized = false,

    witnessInterviewed = false,
    evidenceCollected = false,

    custodyStarted = false,
    detaineeDelivered = false,

    forceUsed = false,
    forceResult = "NONE"
}

local function deepCopy(value)
    if type(value) ~= "table" then
        return value
    end

    local result = {}

    for key, item in pairs(value) do
        result[key] = deepCopy(item)
    end

    return result
end

local function notify(message, color)
    Sentinel.Notify(
        "EVALUACIÓN",
        message,
        color or {90, 190, 255}
    )
end

local function getCurrentCaseSafe()
    if type(GetCurrentCase) ~= "function" then
        return nil
    end

    return GetCurrentCase()
end

local function getSuspectStateSafe()
    if type(GetSuspectState) ~= "function" then
        return "NONE"
    end

    return GetSuspectState() or "NONE"
end

local function resetChecklist()
    ProcedureManager.Checklist =
        deepCopy(DEFAULT_CHECKLIST)
end

local function beginEvaluation()
    if ProcedureManager.Active then
        return false
    end

    local currentCase = getCurrentCaseSafe()

    ProcedureManager.Active = true
    ProcedureManager.Evaluated = false
    ProcedureManager.StartedAt = GetGameTimer()
    ProcedureManager.ArrivedAt = 0
    ProcedureManager.FinishedAt = 0

    ProcedureManager.CaseId =
        currentCase and currentCase.id or nil

    ProcedureManager.LastSuspectState = "NONE"

    resetChecklist()

    ProcedureManager.Checklist.dispatchAccepted = true

    print(
        "[Sentinel AI] Evaluación de procedimiento iniciada."
    )

    return true
end

local function recordArrival()
    if not ProcedureManager.Active
        or ProcedureManager.Checklist.arrivedOnScene then

        return
    end

    ProcedureManager.ArrivedAt = GetGameTimer()

    ProcedureManager.Checklist.arrivedOnScene = true

    ProcedureManager.Checklist.responseSeconds =
        math.max(
            0,
            math.floor(
                (
                    ProcedureManager.ArrivedAt
                    - ProcedureManager.StartedAt
                ) / 1000
            )
        )

    print(
        (
            "[Sentinel AI] Tiempo de respuesta: %d segundos."
        ):format(
            ProcedureManager.Checklist.responseSeconds
        )
    )
end

local function monitorSuspectState()
    if not ProcedureManager.Active then
        return
    end

    local state = getSuspectStateSafe()

    if state == ProcedureManager.LastSuspectState then
        return
    end

    ProcedureManager.LastSuspectState = state

    if state == "ARRESTED" then
        ProcedureManager.Checklist.threatResolved = true
        ProcedureManager.Checklist.suspectArrested = true

    elseif state == "NEUTRALIZED" then
        ProcedureManager.Checklist.threatResolved = true
        ProcedureManager.Checklist.suspectNeutralized = true

    elseif state == "ESCAPED" then
        ProcedureManager.Checklist.threatResolved = true
        ProcedureManager.Checklist.suspectEscaped = true
    end
end

local function monitorCaseData()
    if not ProcedureManager.Active then
        return
    end

    local currentCase = getCurrentCaseSafe()

    if not currentCase then
        return
    end

    if currentCase.witness
        and tostring(currentCase.witness) ~= "" then

        ProcedureManager.Checklist.witnessInterviewed = true
    end

    if type(currentCase.evidence) == "table"
        and #currentCase.evidence > 0 then

        ProcedureManager.Checklist.evidenceCollected = true
    end

    if type(currentCase.suspect) == "table" then
        local custody =
            currentCase.suspect.custody

        if custody == "DELIVERED" then
            ProcedureManager.Checklist.custodyStarted = true
            ProcedureManager.Checklist.detaineeDelivered = true
        end
    end

    if type(currentCase.useOfForce) == "table" then
        ProcedureManager.Checklist.forceUsed =
            currentCase.useOfForce.used == true

        ProcedureManager.Checklist.forceResult =
            currentCase.useOfForce.result or "UNKNOWN"
    end
end

local function monitorCustody()
    if not ProcedureManager.Active then
        return
    end

    if CustodySystem
        and CustodySystem.Active then

        ProcedureManager.Checklist.custodyStarted = true
    end
end

local function calculateScore()
    local checklist =
        ProcedureManager.Checklist

    local score = 50
    local notes = {}

    if checklist.arrivedOnScene then
        score = score + 10
    else
        notes[#notes + 1] =
            "No se registró llegada a escena."
    end

    if checklist.responseSeconds > 0
        and checklist.responseSeconds <= 120 then

        score = score + 10

    elseif checklist.responseSeconds > 240 then
        score = score - 5

        notes[#notes + 1] =
            "Tiempo de respuesta elevado."
    end

    if checklist.threatResolved then
        score = score + 10
    end

    if checklist.suspectArrested then
        score = score + 15

    elseif checklist.suspectEscaped then
        score = score - 10

        notes[#notes + 1] =
            "El sospechoso escapó."

    elseif checklist.suspectNeutralized then
        score = score + 2
    end

    if checklist.witnessInterviewed then
        score = score + 10
    else
        notes[#notes + 1] =
            "No se registró entrevista."
    end

    if checklist.evidenceCollected then
        score = score + 10
    else
        notes[#notes + 1] =
            "No se aseguró evidencia."
    end

    if checklist.suspectArrested then
        if checklist.detaineeDelivered then
            score = score + 10
        else
            score = score - 10

            notes[#notes + 1] =
                "Detenido no entregado."
        end
    end

    if checklist.forceUsed then
        if checklist.forceResult == "JUSTIFIED" then
            score = score + 5

        elseif checklist.forceResult == "UNDER_REVIEW" then
            score = score - 15

            notes[#notes + 1] =
                "Uso de fuerza bajo revisión."

        elseif checklist.forceResult == "UNKNOWN" then
            score = score - 5
        end
    end

    score = math.max(
        0,
        math.min(100, score)
    )

    return score, notes
end

local function getGrade(score)
    if score >= 95 then
        return "S", "Actuación ejemplar"

    elseif score >= 85 then
        return "A", "Procedimiento sobresaliente"

    elseif score >= 75 then
        return "B", "Buen procedimiento"

    elseif score >= 60 then
        return "C", "Actuación aceptable"

    elseif score >= 45 then
        return "D", "Procedimiento deficiente"
    end

    return "F", "Actuación crítica"
end

local function attachEvaluationToCase(
    score,
    grade,
    description,
    notes
)
    local currentCase = getCurrentCaseSafe()

    if not currentCase then
        return false
    end

    currentCase.procedure = {
        score = score,
        grade = grade,
        description = description,
        notes = deepCopy(notes),
        checklist =
            deepCopy(ProcedureManager.Checklist),

        evaluatedAt = GetGameTimer()
    }

    return true
end

local function evaluateCase()
    if not ProcedureManager.Active
        or ProcedureManager.Evaluated then

        return false
    end

    monitorCaseData()
    monitorCustody()
    monitorSuspectState()

    ProcedureManager.Evaluated = true
    ProcedureManager.FinishedAt = GetGameTimer()

    local score, notes =
        calculateScore()

    local grade, description =
        getGrade(score)

    attachEvaluationToCase(
        score,
        grade,
        description,
        notes
    )

    local color = {90, 190, 255}

    if score >= 85 then
        color = {80, 220, 140}

    elseif score < 60 then
        color = {255, 100, 80}
    end

    notify(
        (
            "Calificación %s — %d/100\n%s"
        ):format(
            grade,
            score,
            description
        ),
        color
    )

    print(
        (
            "[Sentinel AI] Procedimiento evaluado | "
            .. "Nota %s | %d/100"
        ):format(
            grade,
            score
        )
    )

    for _, note in ipairs(notes) do
        print(
            "[Sentinel AI] Observación: "
                .. note
        )
    end

    return true
end

function ProcedureManager.GetCurrentEvaluation()
    local currentCase = getCurrentCaseSafe()

    if currentCase
        and currentCase.procedure then

        return currentCase.procedure
    end

    if not ProcedureManager.Evaluated then
        return nil
    end

    local score, notes =
        calculateScore()

    local grade, description =
        getGrade(score)

    return {
        score = score,
        grade = grade,
        description = description,
        notes = notes,
        checklist =
            deepCopy(ProcedureManager.Checklist)
    }
end

function ProcedureManager.Reset()
    ProcedureManager.Active = false
    ProcedureManager.CaseId = nil
    ProcedureManager.StartedAt = 0
    ProcedureManager.ArrivedAt = 0
    ProcedureManager.FinishedAt = 0

    ProcedureManager.LastDispatchState = nil
    ProcedureManager.LastSuspectState = nil

    ProcedureManager.Evaluated = false

    resetChecklist()
end

RegisterCommand(
    "procedure",
    function()
        local evaluation =
            ProcedureManager.GetCurrentEvaluation()

        if not evaluation then
            notify(
                "No existe una evaluación disponible.",
                {255, 180, 0}
            )

            return
        end

        notify(
            (
                "Calificación %s — %d/100\n%s"
            ):format(
                evaluation.grade,
                evaluation.score,
                evaluation.description
            ),
            {170, 140, 255}
        )
    end,
    false
)

CreateThread(function()
    resetChecklist()

    while true do
        Wait(250)

        if PlayerData then
            local state =
                PlayerData.DispatchState

            if state ~= ProcedureManager.LastDispatchState then
                local previousState =
                    ProcedureManager.LastDispatchState

                ProcedureManager.LastDispatchState =
                    state

                if state == "EN_ROUTE"
                    and not ProcedureManager.Active then

                    beginEvaluation()

                elseif state == "ON_SCENE" then
                    recordArrival()

                elseif state == "EVIDENCE" then
                    ProcedureManager.Checklist
                        .witnessInterviewed = true

                elseif state == "TRANSPORT" then
                    ProcedureManager.Checklist
                        .custodyStarted = true

                elseif state == "REPORT" then
                    evaluateCase()

                elseif state == "WAITING"
                    and previousState ~= "WAITING" then

                    if ProcedureManager.Active
                        and not ProcedureManager.Evaluated then

                        evaluateCase()
                    end

                    ProcedureManager.Active = false
                end
            end

            if ProcedureManager.Active then
                monitorSuspectState()
                monitorCaseData()
                monitorCustody()
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

        ProcedureManager.Reset()
    end
)

print("[Sentinel AI] ProcedureManager listo.")