print("[Sentinel AI] Cargando BodyCamManager...")

BodyCamManager = {
    Active = false,
    StartedAt = 0,
    Entries = {},

    LastDispatchState = nil,
    LastSuspectState = nil,
    LastFirstShotBy = "NONE",
    LastCaseId = nil
}

local MAX_ENTRIES = 100

local dispatchLabels = {
    OFF_DUTY = "Unidad fuera de servicio.",
    WAITING = "Unidad disponible para nuevos despachos.",
    PENDING = "Nuevo despacho recibido.",
    EN_ROUTE = "Despacho aceptado. Unidad en ruta.",
    ON_SCENE = "Unidad llegó a la escena.",
    EVIDENCE = "Fase de recolección de evidencia iniciada.",
    TRANSPORT = "Traslado de detenido iniciado.",
    REPORT = "Informe operativo en procesamiento."
}

local suspectLabels = {
    HOSTILE = "Sospechoso hostil identificado.",
    FLEEING = "Sospechoso inició la huida.",
    SURRENDERED = "Sospechoso se rindió.",
    ARRESTED = "Sospechoso esposado y bajo custodia.",
    NEUTRALIZED = "Sospechoso neutralizado.",
    ESCAPED = "Sospechoso escapó del perímetro."
}

local function getClock()
    return string.format(
        "%02d:%02d:%02d",
        GetClockHours(),
        GetClockMinutes(),
        GetClockSeconds()
    )
end

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

local function addEntry(text, category)
    if not BodyCamManager.Active then
        return false
    end

    local entry = {
        time = getClock(),
        elapsedSeconds = math.max(
            0,
            math.floor(
                (GetGameTimer() - BodyCamManager.StartedAt) / 1000
            )
        ),
        category = category or "GENERAL",
        text = tostring(text or "")
    }

    BodyCamManager.Entries[
        #BodyCamManager.Entries + 1
    ] = entry

    while #BodyCamManager.Entries > MAX_ENTRIES do
        table.remove(BodyCamManager.Entries, 1)
    end

    print(
        ("[BODYCAM] %s | %s | %s"):format(
            entry.time,
            entry.category,
            entry.text
        )
    )

    return true
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

local function attachRecordingToCurrentCase()
    local currentCase = getCurrentCaseSafe()

    if not currentCase then
        return false
    end

    currentCase.bodycam = {
        startedAt = BodyCamManager.StartedAt,
        durationSeconds = math.max(
            0,
            math.floor(
                (GetGameTimer() - BodyCamManager.StartedAt) / 1000
            )
        ),
        entries = deepCopy(BodyCamManager.Entries)
    }

    return true
end

function BodyCamManager.Start()
    if BodyCamManager.Active then
        return false
    end

    BodyCamManager.Active = true
    BodyCamManager.StartedAt = GetGameTimer()
    BodyCamManager.Entries = {}

    BodyCamManager.LastDispatchState =
        PlayerData and PlayerData.DispatchState or nil

    BodyCamManager.LastSuspectState = "NONE"
    BodyCamManager.LastFirstShotBy = "NONE"

    local currentCase = getCurrentCaseSafe()

    BodyCamManager.LastCaseId =
        currentCase and currentCase.id or nil

    addEntry(
        "Grabación iniciada.",
        "SYSTEM"
    )

    if PlayerData and PlayerData.CurrentDispatch then
        addEntry(
            ("Código %s - %s."):format(
                PlayerData.CurrentDispatch.code or "000",
                PlayerData.CurrentDispatch.title or "Incidente"
            ),
            "DISPATCH"
        )
    end

    Sentinel.Notify(
        "BODYCAM",
        "Grabación iniciada.",
        {90, 190, 255}
    )

    return true
end

function BodyCamManager.Stop(reason)
    if not BodyCamManager.Active then
        return false
    end

    if reason then
        addEntry(
            reason,
            "SYSTEM"
        )
    end

    addEntry(
        "Grabación finalizada.",
        "SYSTEM"
    )

    attachRecordingToCurrentCase()

    BodyCamManager.Active = false

    Sentinel.Notify(
        "BODYCAM",
        "Grabación finalizada.",
        {150, 150, 150}
    )

    return true
end

function BodyCamManager.Log(text, category)
    return addEntry(text, category)
end

function BodyCamManager.GetEntries()
    return deepCopy(
        BodyCamManager.Entries
    )
end

function BodyCamManager.GetSnapshot()
    return {
        active = BodyCamManager.Active == true,
        startedAt = BodyCamManager.StartedAt,
        entryCount = #BodyCamManager.Entries,
        entries = BodyCamManager.GetEntries()
    }
end

function BodyCamManager.AttachToCurrentCase()
    return attachRecordingToCurrentCase()
end

function BodyCamManager.Reset()
    BodyCamManager.Active = false
    BodyCamManager.StartedAt = 0
    BodyCamManager.Entries = {}

    BodyCamManager.LastDispatchState = nil
    BodyCamManager.LastSuspectState = nil
    BodyCamManager.LastFirstShotBy = "NONE"
    BodyCamManager.LastCaseId = nil
end

function BodyCamManager.Print()
    print("========== SENTINEL BODYCAM ==========")

    if #BodyCamManager.Entries == 0 then
        print("Sin registros disponibles.")
    end

    for _, entry in ipairs(
        BodyCamManager.Entries
    ) do
        print(
            ("[%s] [%s] %s"):format(
                entry.time or "--:--:--",
                entry.category or "GENERAL",
                entry.text or ""
            )
        )
    end

    print("======================================")
end

local function monitorDispatchState()
    if not PlayerData then
        return
    end

    local currentState =
        PlayerData.DispatchState

    if currentState ==
        BodyCamManager.LastDispatchState then

        return
    end

    local previousState =
        BodyCamManager.LastDispatchState

    BodyCamManager.LastDispatchState =
        currentState

    if currentState == "EN_ROUTE"
        and not BodyCamManager.Active then

        BodyCamManager.Start()

        addEntry(
            dispatchLabels.EN_ROUTE,
            "DISPATCH"
        )

        return
    end

    if not BodyCamManager.Active then
        return
    end

    local label =
        dispatchLabels[currentState]

    if label then
        addEntry(
            label,
            "DISPATCH"
        )
    end

    if currentState == "EVIDENCE" then
        addEntry(
            "Testimonio registrado.",
            "INVESTIGATION"
        )

    elseif currentState == "TRANSPORT" then
        addEntry(
            "Detenido asegurado para traslado.",
            "CUSTODY"
        )

    elseif currentState == "REPORT" then
        attachRecordingToCurrentCase()

    elseif currentState == "WAITING"
        and previousState ~= "WAITING" then

        BodyCamManager.Stop(
            "Caso cerrado y unidad nuevamente disponible."
        )
    end
end

local function monitorSuspectState()
    if not BodyCamManager.Active then
        return
    end

    local currentState =
        getSuspectStateSafe()

    if currentState ==
        BodyCamManager.LastSuspectState then

        return
    end

    BodyCamManager.LastSuspectState =
        currentState

    local label =
        suspectLabels[currentState]

    if label then
        addEntry(
            label,
            "SUSPECT"
        )
    end
end

local function monitorUseOfForce()
    if not BodyCamManager.Active
        or not UseOfForceManager then

        return
    end

    local firstShotBy =
        UseOfForceManager.FirstShotBy
        or "NONE"

    if firstShotBy == "NONE"
        or firstShotBy ==
            BodyCamManager.LastFirstShotBy then

        return
    end

    BodyCamManager.LastFirstShotBy =
        firstShotBy

    local labels = {
        SUSPECT =
            "Primer disparo realizado por el sospechoso.",

        PLAYER =
            "Primer disparo realizado por la agente.",

        BACKUP =
            "Primer disparo realizado por la unidad de apoyo."
    }

    addEntry(
        labels[firstShotBy]
            or ("Primer disparo: " .. firstShotBy),
        "USE_OF_FORCE"
    )
end

RegisterCommand(
    "bodycam",
    function()
        BodyCamManager.Print()
    end,
    false
)

RegisterCommand(
    "bodycamstatus",
    function()
        Sentinel.Notify(
            "BODYCAM",
            BodyCamManager.Active
                and (
                    "Grabando: "
                    .. tostring(#BodyCamManager.Entries)
                    .. " eventos."
                )
                or "BodyCam inactiva.",
            {90, 190, 255}
        )
    end,
    false
)

CreateThread(function()
    while true do
        Wait(250)

        monitorDispatchState()
        monitorSuspectState()
        monitorUseOfForce()
    end
end)

AddEventHandler(
    "onResourceStop",
    function(resourceName)
        if resourceName ~= GetCurrentResourceName() then
            return
        end

        if BodyCamManager.Active then
            attachRecordingToCurrentCase()
        end
    end
)

print("[Sentinel AI] BodyCamManager listo.")
