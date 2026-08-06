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
        print("[Sentinel AI] ERROR: ArchiveCase recibió datos inválidos.")
        return false
    end

    local archivedCase = deepCopy(caseData)

    table.insert(CaseHistory, 1, archivedCase)

    print(
        ("[Sentinel AI] Caso #%s archivado. Total: %d")
            :format(
                tostring(archivedCase.id),
                #CaseHistory
            )
    )

    Sentinel.Notify(
        "ARCHIVO",
        ("Caso #%04d almacenado en el historial."):format(
            archivedCase.id or 0
        ),
        {90, 190, 255}
    )

    return true
end

function GetCaseHistory()
    return CaseHistory
end

function GetCaseHistoryCount()
    return #CaseHistory
end

function ClearCaseHistory()
    CaseHistory = {}
end

RegisterCommand("historydebug", function()
    Sentinel.Notify(
        "DEV",
        ("Casos guardados en memoria: %d"):format(
            #CaseHistory
        ),
        {255, 180, 0}
    )

    for _, caseData in ipairs(CaseHistory) do
        print(
            ("[Sentinel AI] #%s | %s | %s | %s XP")
                :format(
                    tostring(caseData.id),
                    tostring(caseData.code),
                    tostring(caseData.title),
                    tostring(caseData.xp)
                )
        )
    end
end, false)