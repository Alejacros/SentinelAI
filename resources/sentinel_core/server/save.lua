local RESOURCE_NAME = GetCurrentResourceName()
local SAVE_FILE = "data/profiles.json"

local profiles = {}

local function loadProfiles()
    local rawData = LoadResourceFile(
        RESOURCE_NAME,
        SAVE_FILE
    )

    if not rawData or rawData == "" then
        profiles = {}

        SaveResourceFile(
            RESOURCE_NAME,
            SAVE_FILE,
            "{}",
            -1
        )

        print(
            "[Sentinel AI] Base de perfiles creada."
        )

        return
    end

    local success, decoded =
        pcall(json.decode, rawData)

    if not success
        or type(decoded) ~= "table" then

        profiles = {}

        print(
            "[Sentinel AI] ERROR: profiles.json inválido."
        )

        return
    end

    profiles = decoded

    print(
        "[Sentinel AI] Perfiles cargados correctamente."
    )
end

local function saveProfiles()
    local success, encoded =
        pcall(json.encode, profiles)

    if not success or not encoded then
        print(
            "[Sentinel AI] ERROR codificando perfiles."
        )

        return false
    end

    local successWrite, result =
        pcall(
            SaveResourceFile,
            RESOURCE_NAME,
            SAVE_FILE,
            encoded,
            -1
        )

    if not successWrite then
        print(
            "[Sentinel AI] ERROR escribiendo profiles.json: "
                .. tostring(result)
        )

        return false
    end

    return true
end

local function getPlayerIdentifier(sourceId)
    local license =
        GetPlayerIdentifierByType(
            sourceId,
            "license"
        )

    if license then
        return license
    end

    local fivem =
        GetPlayerIdentifierByType(
            sourceId,
            "fivem"
        )

    if fivem then
        return fivem
    end

    return ("player:%s"):format(
        tostring(sourceId)
    )
end

local function sanitizeHistory(history)
    if type(history) ~= "table" then
        return {}
    end

    local cleanHistory = {}

    for index, caseData in ipairs(history) do
        if index > 100 then
            break
        end

        if type(caseData) == "table" then
            local evidence = {}

            for evidenceIndex, evidenceName
                in ipairs(caseData.evidence or {}) do

                if evidenceIndex > 20 then
                    break
                end

                evidence[#evidence + 1] =
                    tostring(evidenceName)
            end

            cleanHistory[#cleanHistory + 1] = {
                id = tonumber(caseData.id) or index,
                code = tostring(caseData.code or "000"),
                title = tostring(caseData.title or "Incidente"),
                state = "COMPLETED",
                witness = tostring(caseData.witness or ""),
                evidence = evidence,
                suspect = type(caseData.suspect) == "table"
                    and caseData.suspect
                    or {},
                xp = tonumber(caseData.xp) or 0,
                startedAt = tostring(caseData.startedAt or ""),
                completedAt = tostring(caseData.completedAt or ""),
                durationSeconds =
                    tonumber(caseData.durationSeconds) or 0
            }
        end
    end

    return cleanHistory
end

local function sanitizeProfile(payload)
    payload = type(payload) == "table"
        and payload
        or {}

    return {
        xp = math.max(
            0,
            tonumber(payload.xp) or 0
        ),

        completedCases = math.max(
            0,
            tonumber(payload.completedCases) or 0
        ),

        history = sanitizeHistory(
            payload.history
        ),

        updatedAt = os.time()
    }
end

RegisterNetEvent(
    "sentinel:server:requestProfile",
    function()
        local sourceId = source

        local identifier =
            getPlayerIdentifier(sourceId)

        local profile =
            profiles[identifier]

        if type(profile) ~= "table" then
            profile = {
                xp = 0,
                completedCases = 0,
                history = {},
                updatedAt = os.time()
            }

            profiles[identifier] = profile
            saveProfiles()
        end

        TriggerClientEvent(
            "sentinel:client:loadProfile",
            sourceId,
            profile
        )
    end
)

RegisterNetEvent(
    "sentinel:server:saveProfile",
    function(payload)
        local sourceId = source

        local identifier =
            getPlayerIdentifier(sourceId)

        profiles[identifier] =
            sanitizeProfile(payload)

        local saved = saveProfiles()

        TriggerClientEvent(
            "sentinel:client:profileSaved",
            sourceId,
            saved
        )
    end
)

AddEventHandler(
    "onResourceStop",
    function(resourceName)
        if resourceName ~= RESOURCE_NAME then
            return
        end

        saveProfiles()
    end
)

loadProfiles()