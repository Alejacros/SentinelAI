local mdtOpen = false

local statusLabels = {
    OFF_DUTY = "Fuera de servicio",
    WAITING = "Esperando despacho",
    PENDING = "Despacho pendiente",
    EN_ROUTE = "En ruta",
    ON_SCENE = "En escena",
    EVIDENCE = "Buscando evidencia",
    REPORT = "Procesando informe"
}

local function serializeHistory()
    local result = {}
    local history = GetCaseHistory() or {}

    for index, caseData in ipairs(history) do
        result[index] = {
            id = caseData.id or index,
            code = caseData.code or "000",
            title = caseData.title or "Incidente",
            state = caseData.state or "COMPLETED",
            witness = caseData.witness or "",
            evidence = caseData.evidence or {},
            xp = caseData.xp or 0,
            startedAt = caseData.startedAt or "",
            completedAt = caseData.completedAt or "",
            durationSeconds = caseData.durationSeconds or 0
        }
    end

    return result
end

local function buildMdtData()
    local dispatch = nil

    if PlayerData.CurrentDispatch then
        dispatch = {
            code = PlayerData.CurrentDispatch.code,
            title = PlayerData.CurrentDispatch.title
        }
    end

    local history = serializeHistory()

    return {
        rank = PlayerData.Rank or "Cadete",
        unit = PlayerData.Unit or "Sin asignar",
        xp = PlayerData.XP or 0,
        completedCases = PlayerData.CompletedCases or 0,

        status = statusLabels[PlayerData.DispatchState]
            or "Sin estado",

        dispatch = dispatch,
        caseHistory = history,
        caseHistoryCount = #history
    }
end

local function sendMdtData(action)
    local data = buildMdtData()

    print(
        ("[Sentinel AI] Enviando MDT: %d casos archivados.")
            :format(data.caseHistoryCount)
    )

    SendNUIMessage({
        action = action,
        data = data
    })
end

local function openMdt()
    if mdtOpen then
        return
    end

    mdtOpen = true

    SetNuiFocus(true, true)
    sendMdtData("open")
end

local function closeMdt()
    if not mdtOpen then
        return
    end

    mdtOpen = false

    SetNuiFocus(false, false)

    SendNUIMessage({
        action = "close"
    })
end

RegisterCommand("sentinel_tablet", function()
    if mdtOpen then
        closeMdt()
    else
        openMdt()
    end
end, false)

RegisterKeyMapping(
    "sentinel_tablet",
    "Abrir tablet policial Sentinel MDT",
    "keyboard",
    "F7"
)

RegisterNUICallback("closeMdt", function(_, callback)
    closeMdt()

    callback({
        ok = true
    })
end)

RegisterNUICallback("requestMdtData", function(_, callback)
    callback(buildMdtData())
end)

CreateThread(function()
    while true do
        Wait(500)

        if mdtOpen then
            sendMdtData("update")
        end
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        SetNuiFocus(false, false)
    end
end)