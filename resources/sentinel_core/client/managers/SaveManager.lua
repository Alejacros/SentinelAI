SaveManager = {
    Loaded = false,
    Loading = false,
    SaveQueued = false,
    SaveQueuedReason = nil,
    LastSaveAt = 0
}

local function calculateNextCaseId(history)
    local highestId = 0

    for _, caseData in ipairs(history or {}) do
        local caseId =
            tonumber(caseData.id) or 0

        if caseId > highestId then
            highestId = caseId
        end
    end

    return highestId + 1
end

local function hasValidCharacter()
    return PlayerData.CharacterLoaded == true
        and CharacterManager
        and type(CharacterManager.IsCreated) == "function"
        and CharacterManager.IsCreated(PlayerData.Character)
end

local function buildSavePayload(operation, reason)
    return {
        operation = operation,
        reason = reason,

        clientState = {
            loaded = SaveManager.Loaded == true,
            characterLoaded = PlayerData.CharacterLoaded == true
        },

        xp = PlayerData.XP or 0,

        completedCases =
            PlayerData.CompletedCases or 0,

        history = GetCaseHistory()
            or {},

        character = PlayerData.Character
    }
end

function SaveProgress(forceSave, reason, options)
    reason = tostring(reason or "UNSPECIFIED")
    options = type(options) == "table" and options or {}
    local operation = options.profileCreate == true
        and "PROFILE_CREATE"
        or "PROFILE_UPDATE"

    if SaveManager.Loading
        or not SaveManager.Loaded
        or PlayerData.CharacterLoaded ~= true
        or not hasValidCharacter() then

        print((
            "[Sentinel AI] SAVE REJECTED | operation=%s | reason=%s | loaded=%s | characterLoaded=%s | xp=%s | completedCases=%s | hasCharacter=%s"
        ):format(
            operation,
            reason,
            tostring(SaveManager.Loaded == true),
            tostring(PlayerData.CharacterLoaded == true),
            tostring(PlayerData.XP or 0),
            tostring(PlayerData.CompletedCases or 0),
            tostring(hasValidCharacter())
        ))

        return false
    end

    local now = GetGameTimer()

    if not forceSave
        and now - SaveManager.LastSaveAt < 1000 then

        if not SaveManager.SaveQueued then
            SaveManager.SaveQueued = true
            SaveManager.SaveQueuedReason = reason

            CreateThread(function()
                Wait(1200)

                SaveManager.SaveQueued = false
                local queuedReason = SaveManager.SaveQueuedReason
                    or "QUEUED_UPDATE"
                SaveManager.SaveQueuedReason = nil
                SaveProgress(true, queuedReason, options)
            end)
        end

        return false
    end

    SaveManager.LastSaveAt = now

    print((
        "[Sentinel AI] SAVE REQUEST | operation=%s | reason=%s | loaded=%s | characterLoaded=%s | xp=%s | completedCases=%s | hasCharacter=true"
    ):format(
        operation,
        reason,
        tostring(SaveManager.Loaded == true),
        tostring(PlayerData.CharacterLoaded == true),
        tostring(PlayerData.XP or 0),
        tostring(PlayerData.CompletedCases or 0)
    ))

    TriggerServerEvent(
        "sentinel:server:saveProfile",
        buildSavePayload(operation, reason)
    )

    return true
end

local function applyProfile(profile)
    SaveManager.Loading = true
    PlayerData.CharacterLoaded = false

    profile = type(profile) == "table"
        and profile
        or {}

    local xp = math.max(
        0,
        tonumber(profile.xp) or 0
    )

    local completedCases = math.max(
        0,
        tonumber(
            profile.completedCases
        ) or 0
    )

    local history = type(profile.history)
            == "table"
        and profile.history
        or {}

    PlayerData.Character =
        type(profile.character) == "table"
        and profile.character
        or nil

    SetCaseHistory(history)

    ApplyCareerProgress(
        xp,
        completedCases
    )

    if SentinelCase then
        SentinelCase.Current = nil

        SentinelCase.NextId =
            calculateNextCaseId(history)
    end

    SaveManager.Loading = false
    SaveManager.Loaded = true
    PlayerData.CharacterLoaded = true

    print((
        "[Sentinel AI] PROFILE LOAD | loaded=true | characterLoaded=true | xp=%s | completedCases=%s | hasCharacter=%s"
    ):format(
        tostring(PlayerData.XP or 0),
        tostring(PlayerData.CompletedCases or 0),
        tostring(hasValidCharacter())
    ))

    TriggerEvent(
        "sentinel:characterProfileLoaded",
        PlayerData.Character
    )

    Sentinel.Notify(
        "SENTINEL",
        (
            "Perfil cargado: %d XP y %d casos."
        ):format(
            PlayerData.XP,
            PlayerData.CompletedCases
        ),
        {90, 190, 255}
    )
end

RegisterNetEvent(
    "sentinel:client:loadProfile",
    function(profile)
        applyProfile(profile)
    end
)

RegisterNetEvent(
    "sentinel:client:profileSaved",
    function(saved)
        TriggerEvent(
            "sentinel:profileSaveResult",
            saved == true
        )

        if not saved then
            Sentinel.Notify(
                "ERROR",
                "No fue posible guardar el progreso.",
                {255, 80, 80}
            )
        end
    end
)

AddEventHandler(
    "sentinel:careerUpdated",
    function()
        SaveProgress(false, "CAREER_UPDATED")
    end
)

AddEventHandler(
    "sentinel:historyUpdated",
    function()
        SaveProgress(false, "HISTORY_UPDATED")
    end
)

RegisterCommand(
    "saveprogress",
    function()
        if SaveProgress(true, "MANUAL_COMMAND") then
            Sentinel.Notify(
                "SENTINEL",
                "Guardado manual solicitado.",
                {90, 190, 255}
            )
        end
    end,
    false
)

RegisterCommand(
    "reloadprofile",
    function()
        SaveManager.Loaded = false
        SaveManager.Loading = true
        PlayerData.CharacterLoaded = false

        TriggerServerEvent(
            "sentinel:server:requestProfile"
        )
    end,
    false
)

CreateThread(function()
    while not NetworkIsSessionStarted() do
        Wait(500)
    end

    Wait(2000)

    SaveManager.Loading = true
    PlayerData.CharacterLoaded = false

    TriggerServerEvent(
        "sentinel:server:requestProfile"
    )
end)

CreateThread(function()
    while true do
        Wait(60000)

        if SaveManager.Loaded then
            SaveProgress(true, "PERIODIC_AUTOSAVE")
        end
    end
end)

AddEventHandler(
    "onResourceStop",
    function(resourceName)
        if resourceName
            ~= GetCurrentResourceName() then

            return
        end

        SaveProgress(true, "RESOURCE_STOP")
    end
)
