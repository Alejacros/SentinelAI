local RESOURCE_NAME = GetCurrentResourceName()
local SAVE_FILE = "data/profiles.json"

print(
    ("[Sentinel AI] RUNTIME PATH | resource=%s | path=%s | save=%s")
        :format(
            tostring(RESOURCE_NAME),
            tostring(GetResourcePath(RESOURCE_NAME)),
            tostring(SAVE_FILE)
        )
)

local profiles = {}

print(
    "[Sentinel AI] Perfil persistente: "
        .. SAVE_FILE
)

local function countProfiles()
    local count = 0

    for _ in pairs(profiles) do
        count = count + 1
    end

    return count
end

local function writeProfiles(encoded)
    local successWrite, result =
        pcall(
            SaveResourceFile,
            RESOURCE_NAME,
            SAVE_FILE,
            encoded,
            -1
        )

    if not successWrite or not result then
        print(
            "[Sentinel AI] ERROR escribiendo profiles.json: "
                .. tostring(result)
        )

        return false
    end

    print(
        "[Sentinel AI] profiles.json guardado correctamente."
    )

    return true
end

local function loadProfiles()
    local rawData = LoadResourceFile(
        RESOURCE_NAME,
        SAVE_FILE
    )

    if not rawData or rawData == "" then
        profiles = {}

        if writeProfiles("{}") then
            print(
                "[Sentinel AI] Base de perfiles creada."
            )
        end

        print(
            ("[Sentinel AI] Perfiles cargados: %d")
                :format(countProfiles())
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
        ("[Sentinel AI] Perfiles cargados: %d")
            :format(countProfiles())
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

    return writeProfiles(encoded)
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
