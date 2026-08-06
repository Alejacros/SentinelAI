SaveManager = {
    Loaded = false,
    Loading = false,
    SaveQueued = false,
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

local function buildSavePayload()
    return {
        xp = PlayerData.XP or 0,

        completedCases =
            PlayerData.CompletedCases or 0,

        history = GetCaseHistory()
            or {}
    }
end

function SaveProgress(forceSave)
    if SaveManager.Loading
        or not SaveManager.Loaded then

        return false
    end

    local now = GetGameTimer()

    if not forceSave
        and now - SaveManager.LastSaveAt < 1000 then

        if not SaveManager.SaveQueued then
            SaveManager.SaveQueued = true

            CreateThread(function()
                Wait(1200)

                SaveManager.SaveQueued = false
                SaveProgress(true)
            end)
        end

        return false
    end

    SaveManager.LastSaveAt = now

    TriggerServerEvent(
        "sentinel:server:saveProfile",
        buildSavePayload()
    )

    return true
end

local function applyProfile(profile)
    SaveManager.Loading = true

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
        SaveProgress(false)
    end
)

AddEventHandler(
    "sentinel:historyUpdated",
    function()
        SaveProgress(false)
    end
)

RegisterCommand(
    "saveprogress",
    function()
        if SaveProgress(true) then
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

    TriggerServerEvent(
        "sentinel:server:requestProfile"
    )
end)

CreateThread(function()
    while true do
        Wait(60000)

        if SaveManager.Loaded then
            SaveProgress(true)
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

        if SaveManager.Loaded then
            TriggerServerEvent(
                "sentinel:server:saveProfile",
                buildSavePayload()
            )
        end
    end
)