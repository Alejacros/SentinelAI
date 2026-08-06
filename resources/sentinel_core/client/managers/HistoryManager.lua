CaseHistory = CaseHistory or {}

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

function ArchiveCase(caseData)
    if type(caseData) ~= "table" then
        print(
            "[Sentinel AI] ArchiveCase recibió datos inválidos."
        )

        return false
    end

    table.insert(
        CaseHistory,
        1,
        deepCopy(caseData)
    )

    while #CaseHistory > 100 do
        table.remove(
            CaseHistory,
            #CaseHistory
        )
    end

    Sentinel.Notify(
        "ARCHIVO",
        (
            "Caso #%04d almacenado."
        ):format(
            tonumber(caseData.id) or 0
        ),
        {90, 190, 255}
    )

    TriggerEvent(
        "sentinel:historyUpdated",
        CaseHistory
    )

    return true
end

function SetCaseHistory(history)
    CaseHistory = {}

    if type(history) ~= "table" then
        return
    end

    for _, caseData in ipairs(history) do
        if type(caseData) == "table" then
            CaseHistory[
                #CaseHistory + 1
            ] = deepCopy(caseData)
        end
    end
end

function GetCaseHistory()
    return CaseHistory
end

function GetCaseHistoryCount()
    return #CaseHistory
end

function GetCaseById(caseId)
    for _, caseData in ipairs(
        CaseHistory
    ) do
        if tonumber(caseData.id)
            == tonumber(caseId) then

            return caseData
        end
    end

    return nil
end

function ClearCaseHistory()
    CaseHistory = {}

    TriggerEvent(
        "sentinel:historyUpdated",
        CaseHistory
    )
end

RegisterCommand(
    "historydebug",
    function()
        Sentinel.Notify(
            "DEV",
            (
                "Casos guardados: %d"
            ):format(
                #CaseHistory
            ),
            {255, 180, 0}
        )
    end,
    false
)